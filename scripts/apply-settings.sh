#!/usr/bin/env bash
# Ensure the values in config/settings.conf.
# Namespaces: global | secure | system | device_config:<namespace>
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

setting_get() {
  local ns="$1" key="$2"
  case "$ns" in
    global|secure|system) tv_shell settings get "$ns" "$key" ;;
    device_config:*)      tv_shell device_config get "${ns#device_config:}" "$key" ;;
    *) die "unknown namespace '$ns' in config/settings.conf" ;;
  esac
}
setting_put() {
  local ns="$1" key="$2" val="$3"
  case "$ns" in
    global|secure|system) tv_shell settings put "$ns" "$key" "$val" ;;
    device_config:*)      tv_shell device_config put "${ns#device_config:}" "$key" "$val" ;;
  esac
}

log "settings (waves <= $MAX_WAVE)"
while read -r ns key val; do
  [[ -z "$ns" ]] && continue
  [[ -z "$val" ]] && die "config/settings.conf: missing value for $ns $key"
  cur="$(setting_get "$ns" "$key")"
  if [[ "$cur" == "$val" ]]; then
    report ok "$ns $key" "$val"; continue
  fi
  report change "$ns $key" "$cur -> $val"
  if [[ $APPLY -eq 1 ]]; then
    setting_put "$ns" "$key" "$val"
    if [[ "$(setting_get "$ns" "$key")" == "$val" ]]; then
      record_change "setting $ns $key $cur -> $val"
    else
      report fail "$ns $key" "value did not stick"
    fi
  fi
done < <(conf_wave_lines "$CONFIG_DIR/settings.conf")

print_totals
