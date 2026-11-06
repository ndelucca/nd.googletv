#!/usr/bin/env bash
# Shared helpers for every script in this repo. Source it, don't run it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
# shellcheck source=../tv.conf
source "$REPO_ROOT/tv.conf"
TV_SERIAL="$TV_HOST:$TV_PORT"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
warn() { printf '\033[1;33m[%s] WARN:\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31m[%s] ERROR:\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

require() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing dependency: $cmd"
  done
}

# adb bound to the TV. stdin is closed so loops reading from stdin keep working.
tv_adb()   { adb -s "$TV_SERIAL" "$@" </dev/null; }
tv_shell() { adb -s "$TV_SERIAL" shell "$@" </dev/null; }

# Idempotent: does nothing if the TV is already connected and authorized.
ensure_connected() {
  require adb
  local state i
  state="$(adb -s "$TV_SERIAL" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] && return 0

  log "connecting to $TV_SERIAL"
  adb disconnect "$TV_SERIAL" >/dev/null 2>&1 || true
  adb connect "$TV_SERIAL" >/dev/null 2>&1 || true

  for i in $(seq 1 15); do
    state="$(adb -s "$TV_SERIAL" get-state 2>/dev/null || true)"
    case "$state" in
      device) log "connected to $TV_SERIAL"; return 0 ;;
      unauthorized)
        [[ $i -eq 1 ]] && warn "TV is asking for authorization: accept the 'Allow debugging' dialog on screen (tick 'Always allow')" ;;
    esac
    sleep 2
  done

  warn "could not connect to $TV_SERIAL (state: ${state:-offline})"
  warn "ADB services visible via mDNS (the TV's IP may have changed; update tv.conf):"
  adb mdns services 2>/dev/null | grep -E '_adb' >&2 || warn "  none found"
  die "TV not reachable"
}

# Wait until the TV is reachable over ADB and has finished booting (after a reboot/OTA).
wait_for_boot() {
  local timeout="${1:-300}" start=$SECONDS
  log "waiting for the TV to boot (up to ${timeout}s)"
  while (( SECONDS - start < timeout )); do
    if [[ "$(adb -s "$TV_SERIAL" get-state 2>/dev/null || true)" != "device" ]]; then
      adb connect "$TV_SERIAL" >/dev/null 2>&1 || true
    elif [[ "$(tv_shell getprop sys.boot_completed 2>/dev/null)" == "1" ]]; then
      log "TV booted after $(( SECONDS - start ))s"
      return 0
    fi
    sleep 5
  done
  die "TV did not come back within ${timeout}s"
}

# Reboot the TV and wait until it is usable again.
# Uses the framework's clean shutdown (like Settings → Restart), so pending writes such as
# app-op changes are saved; `adb reboot` is only the fallback if that didn't reboot.
boot_id() { timeout 15 adb -s "$TV_SERIAL" shell cat /proc/sys/kernel/random/boot_id 2>/dev/null </dev/null || true; }
reboot_tv() {
  local before; before="$(boot_id)"
  log "rebooting the TV"
  tv_shell svc power reboot >/dev/null 2>&1 || true
  sleep 30
  if [[ -n "$before" && "$(boot_id)" == "$before" ]]; then
    warn "clean reboot did not happen, falling back to adb reboot"
    tv_adb reboot || true
    sleep 20
  fi
  adb disconnect "$TV_SERIAL" >/dev/null 2>&1 || true
  wait_for_boot "${1:-300}"
  [[ -z "$before" || "$(boot_id)" != "$before" ]] || warn "the TV does not seem to have rebooted"
  tv_shell input keyevent KEYCODE_WAKEUP || true
}

# Mask data that identifies the owner or the device before it lands in git.
sanitize() {
  sed -E \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/<email>/g' \
    -e 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/<mac>/g' \
    -e 's/^(\[[^]]*(serial|ssid|imei|deviceid|device_id|uuid|tvname)[^]]*\]: )\[.+\]$/\1[<redacted>]/I' \
    -e 's/^((android_id|bluetooth_address|bluetooth_name|device_name|advertising_id)=).*/\1<redacted>/'
}

# ============================================================== apply framework
#
# Every apply-*.sh script follows the same contract:
#   - reads its desired state from config/*.conf (first column = wave)
#   - compares with the TV and only touches what differs (idempotent)
#   - dry-run unless --apply is given; --apply requires --wave N
#   - applies every wave <= N, so waves are cumulative
#   - each change is appended to $CHANGES_LOG when set (apply.sh sets it)

APPLY=0
MAX_WAVE=""
N_OK=0; N_CHANGE=0; N_SKIP=0; N_FAIL=0

# Packages that must never be disabled, whatever config/ says: they break HDMI,
# the remote, Wi-Fi, ADB or boot. Sources in docs/research/.
PROTECTED_BUILTIN=(
  android com.android.shell com.android.systemui com.android.tv.settings
  com.android.providers.settings com.android.providers.tv com.android.providers.media.module
  com.android.bluetooth com.android.location.fused com.android.networkstack.inprocess
  com.google.android.gms com.google.android.gsf com.android.vending com.google.android.webview
  com.google.android.permissioncontroller com.google.android.ext.services com.google.android.ext.shared
  com.google.android.inputmethod.latin
  com.tvos com.tcl.tv com.tcl.tvinput com.tcl.system.server com.tcl.settings com.tcl.suspension
  com.tcl.providers.config com.tcl.initsetup com.tcl.tcl_bt_rcu_service com.tcl.autopair
  com.tcl.factory.view com.tcl.inputmethod.international
)

parse_apply_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) APPLY=1 ;;
      --wave)  [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "--wave needs a number"; MAX_WAVE="$2"; shift ;;
      -h|--help)
        echo "usage: $(basename "$0") [--wave N] [--apply]"
        echo "  without --apply only shows what would change (dry-run)"
        echo "  --wave N  limits to waves <= N (required with --apply)"
        exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
    shift
  done
  [[ $APPLY -eq 1 && -z "$MAX_WAVE" ]] && die "--apply requires --wave N (apply one wave at a time, see docs/PLAN.md)"
  [[ -z "$MAX_WAVE" ]] && MAX_WAVE=99
  return 0
}

# conf_lines <file>: entries without comments/blank lines, single-spaced.
conf_lines() {
  [[ -f "$1" ]] || return 0
  sed -E 's/#.*//; s/[[:space:]]+/ /g; s/^ //; s/ $//' "$1" | grep -v '^$' || true
}

# conf_wave_lines <file>: entries whose wave <= MAX_WAVE, wave column removed.
conf_wave_lines() {
  conf_lines "$1" | awk -v max="$MAX_WAVE" '$1 ~ /^[0-9]+$/ && $1 <= max { $1=""; sub(/^ /,""); print }'
}

is_protected() {
  local p="$1"
  { printf '%s\n' "${PROTECTED_BUILTIN[@]}"; conf_lines "$CONFIG_DIR/protected.conf"; } | grep -qxF "$p"
}

current_home_pkg() {
  tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
    | tail -n1 | cut -d/ -f1
}

# report <ok|change|skip|fail> <item> [detail]
report() {
  local status="$1" item="$2" detail="${3:-}" label color
  case "$status" in
    ok)     N_OK=$((N_OK + 1));         label="ok";      color=32 ;;
    change) N_CHANGE=$((N_CHANGE + 1)); label=$([[ $APPLY -eq 1 ]] && echo "changed" || echo "would"); color=33 ;;
    skip)   N_SKIP=$((N_SKIP + 1));     label="skip";    color=36 ;;
    fail)   N_FAIL=$((N_FAIL + 1));     label="FAIL";    color=31 ;;
  esac
  printf '  \033[%sm%-8s\033[0m %s%s\n' "$color" "$label" "$item" "${detail:+  — $detail}"
}

# record_change <text>: append to the change log of the current apply run.
record_change() {
  [[ -n "${CHANGES_LOG:-}" ]] && printf '%s\t%s\n' "$(date '+%F %T')" "$*" >>"$CHANGES_LOG"
  return 0
}

# print_totals: one summary line; returns non-zero if anything failed.
# Set TOTALS_LABEL for checks that never change anything (prints ok/skipped/failed only).
print_totals() {
  if [[ -n "${TOTALS_LABEL:-}" ]]; then
    printf '  -- %s: %d ok, %d skipped, %d failed\n' "$TOTALS_LABEL" "$N_OK" "$N_SKIP" "$N_FAIL"
    [[ $N_FAIL -eq 0 ]]; return
  fi
  local mode; mode=$([[ $APPLY -eq 1 ]] && echo "applied" || echo "dry-run")
  printf '  -- %s: %d ok, %d %s, %d skipped, %d failed\n' \
    "$mode" "$N_OK" "$N_CHANGE" "$([[ $APPLY -eq 1 ]] && echo changed || echo to change)" "$N_SKIP" "$N_FAIL"
  [[ $N_FAIL -eq 0 ]]
}
