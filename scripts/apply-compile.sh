#!/usr/bin/env bash
# Ensure the ART compilation mode in config/compile.conf.
# App updates and OTAs reset compilation; re-running this script restores it.
# Compiles one package at a time: dex2oat needs RAM and this TV has little.
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

dexopt_status() {
  tv_shell dumpsys package dexopt | awk -v p="[$1]" '$1 == p {f=1; next} f && /status=/ {
    match($0, /status=[a-z-]+/); print substr($0, RSTART + 7, RLENGTH - 7); exit }'
}

log "compile (waves <= $MAX_WAVE)"
all="$(tv_shell pm list packages -u | sed 's/^package://')"
while read -r pkg mode; do
  [[ -z "$pkg" ]] && continue
  [[ "$mode" =~ ^(speed|speed-profile|verify|quicken)$ ]] || die "config/compile.conf: bad mode '$mode' for $pkg"
  if ! grep -qxF "$pkg" <<<"$all"; then
    report skip "$pkg" "not installed"; continue
  fi
  cur="$(dexopt_status "$pkg")"
  if [[ "$cur" == "$mode" ]]; then
    report ok "$pkg" "$mode"; continue
  fi
  report change "$pkg" "${cur:-unknown} -> $mode"
  if [[ $APPLY -eq 1 ]]; then
    tv_shell cmd package compile -m "$mode" -f "$pkg" >/dev/null
    if [[ "$(dexopt_status "$pkg")" == "$mode" ]]; then
      record_change "compile $pkg ${cur:-unknown} -> $mode"
    else
      report fail "$pkg" "status is $(dexopt_status "$pkg") after compiling"
    fi
  fi
done < <(conf_wave_lines "$CONFIG_DIR/compile.conf")

print_totals
