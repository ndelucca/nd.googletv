#!/usr/bin/env bash
# Snapshot of everything the apply-*.sh scripts can change, so rollback.sh can restore it.
# Usage: backup.sh [label]   → prints the backup directory on stdout.
# apply.sh calls it automatically before applying a wave.
source "$(dirname "$0")/lib.sh"
ensure_connected
# shellcheck disable=SC2034  # read by conf_wave_lines in lib.sh
MAX_WAVE=99   # back up every managed item, not just one wave

label="${1:-manual}"
dir="$REPO_ROOT/backups/$(date +%Y%m%d-%H%M%S)-$label"
mkdir -p "$dir"

tv_shell getprop ro.build.fingerprint >"$dir/fingerprint.txt"
tv_shell pm list packages -d | sed 's/^package://' | LC_ALL=C sort >"$dir/disabled.txt"
tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
  | tail -n1 >"$dir/home.txt"

# "<namespace> <key> <current value>" for every managed setting ("null" = unset)
while read -r ns key _; do
  case "$ns" in
    device_config:*) v="$(tv_shell device_config get "${ns#device_config:}" "$key")" ;;
    *)               v="$(tv_shell settings get "$ns" "$key")" ;;
  esac
  printf '%s %s %s\n' "$ns" "$key" "$v"
done < <(conf_wave_lines "$CONFIG_DIR/settings.conf") >"$dir/settings.txt"

# "<package> <op> <current mode>"
while read -r pkg op _; do
  out="$(tv_shell cmd appops get "$pkg" "$op" 2>&1)"
  if   [[ "$out" =~ Default\ mode:\ ([a-z_]+) ]]; then m="default"
  elif [[ "$out" =~ $op:\ ([a-z_]+) ]];           then m="${BASH_REMATCH[1]}"
  else m="unknown"; fi
  printf '%s %s %s\n' "$pkg" "$op" "$m"
done < <(conf_wave_lines "$CONFIG_DIR/appops.conf") >"$dir/appops.txt"

# "<package> <dexopt status>"
dexopt="$(tv_shell dumpsys package dexopt)"
while read -r pkg _; do
  s="$(awk -v p="[$pkg]" '$1 == p {f=1; next} f && /status=/ {
        match($0, /status=[a-z-]+/); print substr($0, RSTART + 7, RLENGTH - 7); exit }' <<<"$dexopt")"
  printf '%s %s\n' "$pkg" "${s:-unknown}"
done < <(conf_wave_lines "$CONFIG_DIR/compile.conf") >"$dir/compile.txt"

# "<package> <installed versionCode | absent>" for every app in apps.conf
while read -r pkg _; do
  v="$(tv_shell pm list packages --show-versioncode "$pkg" | sed -nE "s/^package:${pkg//./\\.} versionCode:([0-9]+)$/\1/p")"
  printf '%s %s\n' "$pkg" "${v:-absent}"
done < <(conf_wave_lines "$CONFIG_DIR/apps.conf") >"$dir/apps.txt"

# Apps that packages.conf uninstalls: "<package> <versionCode>", plus a copy of their APKs in
# apks/<package>/ (kept out of git by .gitignore) so rollback.sh can reinstall them. App data is not kept.
: >"$dir/uninstall.txt"
while read -r pkg action _; do
  [[ "$action" == "uninstall" ]] || continue
  paths="$(tv_shell pm path "$pkg" 2>/dev/null | sed -n 's/^package://p' || true)"
  [[ -z "$paths" ]] && continue   # already gone
  v="$(tv_shell pm list packages --show-versioncode "$pkg" | sed -nE "s/^package:${pkg//./\\.} versionCode:([0-9]+)$/\1/p")"
  mkdir -p "$dir/apks/$pkg"
  while read -r p; do
    tv_adb pull "$p" "$dir/apks/$pkg/" >/dev/null || die "could not copy $p — not uninstalling without a backup"
  done <<<"$paths"
  printf '%s %s\n' "$pkg" "${v:-unknown}" >>"$dir/uninstall.txt"
done < <(conf_wave_lines "$CONFIG_DIR/packages.conf")

log "backup written to ${dir#"$REPO_ROOT"/}"
echo "$dir"
