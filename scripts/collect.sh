#!/usr/bin/env bash
# Read-only snapshot of the TV into inventory/. It never changes anything on the TV.
#
# Idempotent: inventory/ is fully regenerated on every run (built in a temp dir and
# swapped in at the end, so a failed run leaves the previous snapshot intact).
# Lists are sorted wherever order is meaningless, so `git diff inventory/` shows
# what changed on the TV between two runs.
#
# Layout:
#   device/    hardware, firmware, display, codecs, features (rarely changes)
#   packages/  installed apps and how they behave (boot, background, standby)
#   settings/  settings global/system/secure, device_config flags, overlays
#   runtime/   volatile state: memory, CPU, processes, kills, errors, usage
#   raw/       large unfiltered dumpsys outputs for deep dives
#   SUMMARY.md and packages.tsv are generated from the above by summarize.py
source "$(dirname "$0")/lib.sh"
require python3 sed sort awk

ensure_connected

OUT="$REPO_ROOT/inventory"
TMP="$(mktemp -d "$REPO_ROOT/.inventory.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# cap <relative file> <command run on the TV>
cap() {
  local f="$TMP/$1"; shift
  mkdir -p "$(dirname "$f")"
  if ! tv_shell "$@" 2>&1 | sanitize >"$f"; then
    warn "command failed (output kept): $*"
  fi
}
# Same as cap, sorted and without the "package:" prefix noise.
cap_sorted() {
  local f="$TMP/$1"; shift
  mkdir -p "$(dirname "$f")"
  if ! tv_shell "$@" 2>&1 | sanitize | sed -E 's/^package://' | LC_ALL=C sort >"$f"; then
    warn "command failed (output kept): $*"
  fi
}

# ---------------------------------------------------------------- device
log "device"
cap        device/getprop.txt        getprop
cap        device/kernel.txt         'uname -a; cat /proc/version'
cap        device/cpuinfo.txt        'cat /proc/cpuinfo'
cap        device/cpufreq.txt        'for c in /sys/devices/system/cpu/cpu[0-9]*; do
                                        f=$c/cpufreq
                                        echo "$(basename $c): governor=$(cat $f/scaling_governor) min=$(cat $f/cpuinfo_min_freq) max=$(cat $f/cpuinfo_max_freq)"
                                      done
                                      echo "available_governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)"
                                      echo "available_frequencies: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies 2>/dev/null)"'
cap        device/memory_config.txt  'grep -E "MemTotal|SwapTotal" /proc/meminfo
                                      echo "zram0 disksize: $(cat /sys/block/zram0/disksize)"
                                      echo "zram0 comp_algorithm: $(cat /sys/block/zram0/comp_algorithm)"
                                      getprop | grep -E "lmk|low_ram|dalvik.vm.heap|zram|swap"'
cap        device/display.txt        'wm size; wm density
                                      dumpsys SurfaceFlinger | grep -E "GLES|Refresh rate|refresh-rate|DisplayDevice"
                                      dumpsys display | grep -E "mDisplayModes|mActiveModeId|mDefaultModeId|HdrCapabilities|supportedModes|mUserPreferredModeId" | sort -u'
cap        device/storage.txt        'df -h 2>/dev/null | grep -vE "^(tmpfs|none)"'
cap        device/hdmi_cec.txt       'dumpsys hdmi_control'
cap_sorted device/features.txt       'pm list features'
cap_sorted device/libraries.txt      'pm list libraries'
for f in $(tv_shell 'ls /vendor/etc/ | grep -E "^(media_codecs|codec_resource).*\.xml$"'); do
  cap "device/media_codecs/$f" "cat /vendor/etc/$f"
done

# ---------------------------------------------------------------- packages
log "packages"
cap_sorted packages/all.txt               'pm list packages -f -u -U --show-versioncode -i'
cap_sorted packages/installed.txt         'pm list packages'
cap_sorted packages/system.txt            'pm list packages -s'
cap_sorted packages/third_party.txt       'pm list packages -3'
cap_sorted packages/enabled.txt           'pm list packages -e'
cap_sorted packages/disabled.txt          'pm list packages -d'
cap        packages/home_activities.txt   'cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
cap        packages/default_home.txt      'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
cap        packages/launcher_apps.txt     'cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER'
cap        packages/boot_receivers.txt    'for a in android.intent.action.BOOT_COMPLETED android.intent.action.LOCKED_BOOT_COMPLETED; do
                                             echo "## $a"; cmd package query-receivers --brief -a $a | grep "/"
                                           done'
cap        packages/dream_services.txt    'cmd package query-services --brief -a android.service.dreams.DreamService'
cap        packages/accessibility.txt     'cmd package query-services --brief -a android.accessibilityservice.AccessibilityService'
cap        packages/input_methods.txt     'ime list -a -s'
cap_sorted packages/standby_buckets.txt   'am get-standby-bucket'
cap_sorted packages/deviceidle_whitelist.txt 'cmd deviceidle whitelist'
# Timestamps (time=/rejectTime=) are stripped so the files only change when a mode changes.
# APP_AUTO_START is TCL's own autostart gate (TclAppBoot); "ignore" blocks background starts.
for op in RUN_ANY_IN_BACKGROUND APP_AUTO_START; do
  cap packages/appops_${op,,}.txt "for p in \$(pm list packages -u | cut -d: -f2 | sort); do
                                     echo \"\$p: \$(cmd appops get \$p $op 2>&1 | tr '\n' ' ')\"
                                   done | sed -E 's/; (time|rejectTime|duration)=[^ ]*//g'"
done
cap        packages/diskstats.txt         'dumpsys diskstats'
# ART compilation state per package (verify / speed-profile / speed).
tv_shell 'dumpsys -t 60 package dexopt' 2>/dev/null \
  | awk '/^  \[/{p=$1} /arm: \[status/{print p, $2, $3}' | LC_ALL=C sort >"$TMP/packages/dexopt.txt" || true

# ---------------------------------------------------------------- settings
log "settings"
cap_sorted settings/global.txt        'settings list global'
cap_sorted settings/system.txt        'settings list system'
cap_sorted settings/secure.txt        'settings list secure'
cap_sorted settings/device_config.txt 'device_config list'
cap        settings/overlays.txt      'cmd overlay list'
cap        settings/activity_manager.txt 'dumpsys activity settings'
cap        settings/backup.txt        'bmgr enabled'

# ---------------------------------------------------------------- runtime (volatile)
log "runtime"
cap runtime/uptime.txt          'uptime; echo "loadavg: $(cat /proc/loadavg)"'
cap runtime/meminfo_proc.txt    'cat /proc/meminfo'
cap runtime/zram.txt            'echo "mm_stat (orig compr mem_used mem_limit mem_max same_pages compacted huge): $(cat /sys/block/zram0/mm_stat)"'
cap runtime/meminfo_dumpsys.txt 'dumpsys -t 60 meminfo'
cap runtime/cpuinfo_dumpsys.txt 'dumpsys cpuinfo'
cap runtime/top.txt             'top -b -n 2 -d 3 -m 40'
cap runtime/ps.txt              'ps -A -o USER,PID,PPID,RSS,S,PCY,NAME'
cap runtime/procstats_24h.txt   'dumpsys -t 60 procstats --hours 24'
cap runtime/activity_lru.txt    'dumpsys activity lru'
cap runtime/services_running.txt 'dumpsys -t 60 activity services | grep -E "^[[:space:]]+\* ServiceRecord" | sed -E "s/ServiceRecord\{[0-9a-f]+ //; s/\}$//" | sort'
cap runtime/thermal.txt         'dumpsys thermalservice'
home_pkg="$(tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1 | cut -d/ -f1)"
cap runtime/gfxinfo_home.txt    "dumpsys gfxinfo $home_pkg"
# Aggregated usage only (per app totals); the per-event history is left out on purpose.
cap runtime/usage_yearly.txt    'dumpsys -t 60 usagestats | awk "/In-memory yearly stats/{y=1} /UsageStatsDatabase/{y=0} y && /timeRange|package=.*totalTimeUsed/"'
cap runtime/standby_states.txt  'dumpsys -t 60 usagestats | grep -E "^[[:space:]]+package=.* bucket="'
cap runtime/kills.txt           'logcat -b events -d | grep -E " (am_kill|killinfo|am_low_memory|am_proc_died|am_crash|am_anr) "'
cap runtime/logcat_crash.txt    'logcat -b crash -d'
# Error count by tag; noisy tags point to misbehaving components.
tv_shell 'logcat -b main,system -d -v brief "*:E"' 2>/dev/null \
  | sed -nE 's#^E/([^(]+)\(.*#\1#p' | sed -E 's/[[:space:]]+$//' \
  | sort | uniq -c | sort -rn | head -n 60 >"$TMP/runtime/logcat_error_tags.txt" || true

# ---------------------------------------------------------------- raw
log "raw dumps"
cap raw/dumpsys_package.txt      'dumpsys -t 60 package'
cap raw/dumpsys_display.txt      'dumpsys display'
cap raw/dumpsys_jobscheduler.txt 'dumpsys -t 60 jobscheduler'
cap raw/dumpsys_alarm.txt        'dumpsys -t 60 alarm'
cap raw/dumpsys_input.txt        'dumpsys input'
cap raw/dumpsys_activity_services.txt 'dumpsys -t 60 activity services'

# ---------------------------------------------------------------- summary
log "summary"
python3 "$REPO_ROOT/scripts/summarize.py" "$TMP"

rm -rf "$OUT"
mv "$TMP" "$OUT"
trap - EXIT
log "inventory written to $OUT ($(du -sh "$OUT" | cut -f1))"
