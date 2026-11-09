#!/usr/bin/env bash
# Restore the TV to the state saved by backup.sh.
# Usage: rollback.sh <backups/dir> [--apply]     (dry-run without --apply)
source "$(dirname "$0")/lib.sh"
export LC_ALL=C   # comm needs the same collation as the sorted backup files

[[ $# -ge 1 && -d "$1" ]] || die "usage: $(basename "$0") <backups/dir> [--apply]"
dir="$(cd "$1" && pwd)"; shift
[[ "${1:-}" == "--apply" ]] && APPLY=1
ensure_connected

fp="$(tv_shell getprop ro.build.fingerprint)"
[[ "$fp" == "$(cat "$dir/fingerprint.txt")" ]] || warn "firmware changed since this backup (OTA?) — review before applying"

do_or_show() { [[ $APPLY -eq 1 ]] && "$@" >/dev/null; return 0; }

log "packages"
now="$(tv_shell pm list packages -d | sed 's/^package://' | LC_ALL=C sort)"
# disabled now but not in the backup → enable
while read -r p; do
  [[ -z "$p" ]] && continue
  report change "$p" "enable"; do_or_show tv_shell pm enable "$p"
done < <(comm -23 <(echo "$now") "$dir/disabled.txt")
# disabled in the backup but enabled now → disable again (never protected ones)
while read -r p; do
  [[ -z "$p" ]] && continue
  if is_protected "$p"; then report skip "$p" "protected"; continue; fi
  report change "$p" "disable"; do_or_show tv_shell pm disable-user --user 0 "$p"
done < <(comm -13 <(echo "$now") "$dir/disabled.txt")

log "uninstalled apps"
if [[ -f "$dir/uninstall.txt" ]]; then
  while read -r pkg was; do
    [[ -z "$pkg" ]] && continue
    if tv_shell pm list packages | grep -qxF "package:$pkg"; then report ok "$pkg" "installed"; continue; fi
    apks=("$dir/apks/$pkg"/*.apk)
    if [[ ! -f "${apks[0]}" ]]; then
      report skip "$pkg" "no APK in this backup (APKs stay out of git) — reinstall it from the Play Store"; continue
    fi
    report change "$pkg" "reinstall versionCode $was (its data was not kept)"
    [[ $APPLY -eq 1 ]] || continue
    if (( ${#apks[@]} > 1 )); then out="$(tv_adb install-multiple -r "${apks[@]}" 2>&1 || true)"
    else out="$(tv_adb install -r "${apks[0]}" 2>&1 || true)"; fi
    tv_shell pm list packages | grep -qxF "package:$pkg" || report fail "$pkg" "reinstall failed: $(tail -n1 <<<"$out")"
  done <"$dir/uninstall.txt"
fi

log "settings"
while read -r ns key val; do
  [[ -z "$ns" ]] && continue
  case "$ns" in
    device_config:*) cur="$(tv_shell device_config get "${ns#device_config:}" "$key")"
                     [[ "$cur" == "$val" ]] && { report ok "$ns $key" "$val"; continue; }
                     report change "$ns $key" "$cur -> $val"
                     if [[ "$val" == "null" ]]; then do_or_show tv_shell device_config delete "${ns#device_config:}" "$key"
                     else do_or_show tv_shell device_config put "${ns#device_config:}" "$key" "$val"; fi ;;
    *)               cur="$(tv_shell settings get "$ns" "$key")"
                     [[ "$cur" == "$val" ]] && { report ok "$ns $key" "$val"; continue; }
                     report change "$ns $key" "$cur -> $val"
                     if [[ "$val" == "null" ]]; then do_or_show tv_shell settings delete "$ns" "$key"
                     else do_or_show tv_shell settings put "$ns" "$key" "$val"; fi ;;
  esac
done <"$dir/settings.txt"

log "appops"
while read -r pkg op mode; do
  [[ -z "$pkg" || "$mode" == "unknown" ]] && continue
  out="$(tv_shell cmd appops get "$pkg" "$op" 2>&1)"
  if   [[ "$out" =~ Default\ mode: ]];      then cur="default"
  elif [[ "$out" =~ $op:\ ([a-z_]+) ]];     then cur="${BASH_REMATCH[1]}"
  else cur="unknown"; fi
  [[ "$cur" == "$mode" ]] && { report ok "$pkg $op" "$mode"; continue; }
  report change "$pkg $op" "$cur -> $mode"; do_or_show tv_shell cmd appops set "$pkg" "$op" "$mode"
done <"$dir/appops.txt"
[[ $APPLY -eq 1 ]] && tv_shell cmd appops write-settings >/dev/null   # persist now, not in 30 min

log "compile"
dexopt="$(tv_shell dumpsys package dexopt)"
while read -r pkg status; do
  [[ -z "$pkg" || "$status" == "unknown" ]] && continue
  cur="$(awk -v p="[$pkg]" '$1 == p {f=1; next} f && /status=/ {
          match($0, /status=[a-z-]+/); print substr($0, RSTART + 7, RLENGTH - 7); exit }' <<<"$dexopt")"
  [[ "$cur" == "$status" ]] && { report ok "$pkg" "$status"; continue; }
  report change "$pkg" "${cur:-unknown} -> $status"
  do_or_show tv_shell cmd package compile -m "$status" -f "$pkg"
done <"$dir/compile.txt"

log "home"
want="$(cat "$dir/home.txt")"
cur="$(tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1)"
if [[ "$cur" == "$want" ]]; then report ok "home" "$want"
else report change "home" "$cur -> $want"; do_or_show tv_shell cmd package set-home-activity --user 0 "$want"; fi

log "apps"
if [[ -f "$dir/apps.txt" ]]; then
  while read -r pkg was; do
    [[ -z "$pkg" ]] && continue
    now="$(tv_shell pm list packages --show-versioncode "$pkg" | sed -nE "s/^package:${pkg//./\\.} versionCode:([0-9]+)$/\1/p")"
    if [[ "$was" == "absent" && -n "$now" ]]; then
      report change "$pkg" "uninstall (not installed at backup time)"; do_or_show tv_adb uninstall "$pkg"
    elif [[ "$was" != "absent" && -n "$now" && "$now" != "$was" ]]; then
      report skip "$pkg" "versionCode $now, backup had $was (Android can't downgrade; reinstall by hand if needed)"
    else
      report ok "$pkg" "${now:-absent}"
    fi
  done <"$dir/apps.txt"
fi

print_totals
[[ $APPLY -eq 1 ]] && log "done — reboot the TV (Settings → System → Restart) to settle everything"
