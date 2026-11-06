#!/usr/bin/env bash
# Ensure the app-op modes in config/appops.conf
# (e.g. RUN_ANY_IN_BACKGROUND, or TCL's APP_AUTO_START autostart gate).
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

# Prints the effective package mode of <op> ("allow", "ignore", "deny", "default"...).
appop_get() {
  local out
  out="$(tv_shell cmd appops get "$1" "$2" 2>&1)"
  if [[ "$out" =~ Default\ mode:\ ([a-z_]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$out" =~ $2:\ ([a-z_]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

log "appops (waves <= $MAX_WAVE)"
all="$(tv_shell pm list packages -u | sed 's/^package://')"
while read -r pkg op mode; do
  [[ -z "$pkg" ]] && continue
  if ! grep -qxF "$pkg" <<<"$all"; then
    report skip "$pkg $op" "not installed"; continue
  fi
  cur="$(appop_get "$pkg" "$op")"
  if [[ "$cur" == "$mode" ]]; then
    report ok "$pkg $op" "$mode"; continue
  fi
  report change "$pkg $op" "$cur -> $mode"
  if [[ $APPLY -eq 1 ]]; then
    tv_shell cmd appops set "$pkg" "$op" "$mode"
    if [[ "$(appop_get "$pkg" "$op")" == "$mode" ]]; then
      record_change "appop $pkg $op $cur -> $mode"
    else
      report fail "$pkg $op" "mode did not stick"
    fi
  fi
done < <(conf_wave_lines "$CONFIG_DIR/appops.conf")

# Android saves app-op changes to disk up to 30 min later; a reboot before that loses them.
if [[ $APPLY -eq 1 && $N_CHANGE -gt 0 ]]; then tv_shell cmd appops write-settings >/dev/null; fi

print_totals
