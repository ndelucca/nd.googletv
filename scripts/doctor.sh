#!/usr/bin/env bash
# Health check: does the TV still match config/ up to the last applied wave?
# Run after a firmware/app update, once a week, or whenever something feels off.
# Read-only. Exit code 1 if anything needs attention.
source "$(dirname "$0")/lib.sh"
ensure_connected

applied="$(cat "$REPO_ROOT/state/applied-wave" 2>/dev/null || echo 0)"
rc=0

log "firmware"
live_fp="$(tv_shell getprop ro.build.fingerprint)"
known_fp="$(sed -nE 's/^\[ro\.build\.fingerprint\]: \[(.*)\]$/\1/p' "$REPO_ROOT/inventory/device/getprop.txt" 2>/dev/null || true)"
if [[ -z "$known_fp" ]]; then
  report skip "fingerprint" "no inventory yet — run scripts/collect.sh"
elif [[ "$live_fp" == "$known_fp" ]]; then
  report ok "fingerprint" "$live_fp"
else
  report fail "fingerprint" "OTA detected: $known_fp -> $live_fp. Run collect.sh, review the diff, then apply.sh"
  rc=1
fi

log "protected packages"
disabled="$(tv_shell pm list packages -d | sed 's/^package://')"
bad=0
while read -r p; do
  [[ -z "$p" ]] && continue
  if grep -qxF "$p" <<<"$disabled"; then report fail "$p" "PROTECTED package is disabled — run: adb shell pm enable $p"; bad=1; fi
done < <({ printf '%s\n' "${PROTECTED_BUILTIN[@]}"; conf_lines "$CONFIG_DIR/protected.conf"; } | sort -u)
[[ $bad -eq 0 ]] && report ok "protected" "none disabled" || rc=1

log "disabled packages not managed by config/packages.conf"
managed="$(MAX_WAVE=99 conf_wave_lines "$CONFIG_DIR/packages.conf" | awk '{print $1}')"
unmanaged=0
while read -r p; do
  [[ -z "$p" ]] && continue
  grep -qxF "$p" <<<"$managed" || { report skip "$p" "disabled on the TV but not in config — add it or enable it"; unmanaged=1; }
done <<<"$disabled"
[[ $unmanaged -eq 0 ]] && report ok "unmanaged" "none"

print_totals >/dev/null || true
echo
log "drift against config/ (waves <= $applied, the last applied wave)"
for step in apps home packages appops settings compile; do
  out="$("$REPO_ROOT/scripts/apply-$step.sh" --wave "$applied" 2>&1)" || rc=1
  echo "$out" | grep -vE '^\s+\S*ok\S*\s' || true
  grep -qE 'would|FAIL' <<<"$out" && rc=1
done

echo
if [[ $rc -eq 0 ]]; then
  log "all good: the TV matches config/ up to wave $applied"
else
  warn "attention needed (see above). To re-apply: scripts/apply.sh --wave $applied --apply"
fi
exit $rc
