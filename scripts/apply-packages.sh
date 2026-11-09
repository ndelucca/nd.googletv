#!/usr/bin/env bash
# Ensure every package listed in config/packages.conf is disabled for user 0, or uninstalled when
# marked `uninstall`. System packages are only ever disabled (`pm disable-user`, reversible with
# `pm enable`); `uninstall` is refused for them and only works on apps the user installed.
# backup.sh keeps a copy of those APKs so rollback.sh can reinstall them (app data is lost).
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

log "packages (waves <= $MAX_WAVE)"
all="$(tv_shell pm list packages -u | sed 's/^package://')"
disabled="$(tv_shell pm list packages -d | sed 's/^package://')"
system="$(tv_shell pm list packages -s | sed 's/^package://')"
home="$(current_home_pkg)"

while read -r pkg action _; do
  [[ -z "$pkg" ]] && continue
  [[ "$action" == "uninstall" ]] || action="disable"
  if is_protected "$pkg"; then
    report fail "$pkg" "protected package listed in config/packages.conf — refusing"; continue
  fi
  if [[ "$pkg" == "$home" ]]; then
    report fail "$pkg" "is the current HOME launcher — refusing"; continue
  fi
  if [[ "$action" == "uninstall" ]]; then
    if ! grep -qxF "$pkg" <<<"$all"; then report ok "$pkg" "not installed"; continue; fi
    if grep -qxF "$pkg" <<<"$system"; then
      report fail "$pkg" "system package marked uninstall — only disabling is allowed"; continue
    fi
    report change "$pkg" "uninstall"
    if [[ $APPLY -eq 1 ]]; then
      tv_shell pm uninstall "$pkg" >/dev/null 2>&1 || true   # every user: it is not a system app
      if tv_shell pm list packages -u | grep -qxF "package:$pkg"; then
        report fail "$pkg" "still installed after pm uninstall"
      else
        record_change "package uninstall $pkg"
      fi
    fi
    continue
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
