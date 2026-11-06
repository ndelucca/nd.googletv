#!/usr/bin/env bash
# Ensure every package listed in config/packages.conf is disabled for user 0.
# Uses `pm disable-user` only (reversible with `pm enable`), never uninstall.
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

log "packages (waves <= $MAX_WAVE)"
all="$(tv_shell pm list packages -u | sed 's/^package://')"
disabled="$(tv_shell pm list packages -d | sed 's/^package://')"
home="$(current_home_pkg)"

while read -r pkg _; do
  [[ -z "$pkg" ]] && continue
  if is_protected "$pkg"; then
    report fail "$pkg" "protected package listed in config/packages.conf — refusing"; continue
  fi
  if [[ "$pkg" == "$home" ]]; then
    report fail "$pkg" "is the current HOME launcher — refusing"; continue
  fi
  if ! grep -qxF "$pkg" <<<"$all"; then
    report skip "$pkg" "not installed"; continue
  fi
  if grep -qxF "$pkg" <<<"$disabled"; then
    report ok "$pkg" "disabled"; continue
  fi

  report change "$pkg" "disable"
  if [[ $APPLY -eq 1 ]]; then
    tv_shell pm disable-user --user 0 "$pkg" >/dev/null
    if tv_shell pm list packages -d | grep -qxF "package:$pkg"; then
      record_change "package disable $pkg"
    else
      report fail "$pkg" "still enabled after pm disable-user"
    fi
  fi
done < <(conf_wave_lines "$CONFIG_DIR/packages.conf")

print_totals
