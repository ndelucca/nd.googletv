#!/usr/bin/env bash
# Ensure the HOME launcher in config/home.conf (last entry within the wave limit wins).
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

home_component() {
  tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1
}

log "home launcher (waves <= $MAX_WAVE)"
want="$(conf_wave_lines "$CONFIG_DIR/home.conf" | awk 'NF {c=$1} END {print c}')"
if [[ -z "$want" ]]; then
  report skip "home" "nothing configured"
else
  pkg="${want%%/*}"
  cur="$(home_component)"
  if [[ "$cur" == "$want" ]]; then
    report ok "home" "$want"
  elif ! tv_shell pm list packages -e | grep -qxF "package:$pkg"; then
    report fail "home" "$pkg is not installed or is disabled"
  else
    report change "home" "$cur -> $want"
    if [[ $APPLY -eq 1 ]]; then
      tv_shell cmd package set-home-activity --user 0 "$want" >/dev/null
      if [[ "$(home_component)" == "$want" ]]; then
        record_change "home $cur -> $want"
      else
        report fail "home" "resolve-activity still returns $(home_component)"
      fi
    fi
  fi
fi

print_totals
