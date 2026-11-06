#!/usr/bin/env bash
# Apply one wave end to end, unattended:
#   apply (with backup) → reboot → wait for boot → verify (incl. UI) → on failure, roll back and re-verify.
#
#   scripts/wave.sh <N>           waves 0..N
#   NO_UI=1 scripts/wave.sh <N>   skip the on-screen part of the verification
#
# Exit code: 0 = applied and verified, 1 = failed and rolled back, 2 = failed and rollback also failed.
source "$(dirname "$0")/lib.sh"
[[ $# -eq 1 && "$1" =~ ^[0-9]+$ ]] || die "usage: $(basename "$0") <wave number>"
wave="$1"
ensure_connected

ui=(--ui); [[ -n "${NO_UI:-}" ]] && ui=()
mkdir -p "$REPO_ROOT/state"
rm -f "$REPO_ROOT/state/last-backup"

log "===== wave $wave: apply"
"$REPO_ROOT/scripts/apply.sh" --wave "$wave" --apply || die "apply failed before rebooting — check the output above"

if [[ ! -f "$REPO_ROOT/state/last-backup" ]]; then
  log "wave $wave: nothing to change"
  exit 0
fi
backup="$REPO_ROOT/$(cat "$REPO_ROOT/state/last-backup")"

log "===== wave $wave: reboot"
reboot_tv 360
sleep 60   # let boot-time services settle before judging

log "===== wave $wave: verify"
if "$REPO_ROOT/scripts/verify.sh" "${ui[@]}"; then
  log "wave $wave applied and verified"
  exit 0
fi

warn "===== wave $wave FAILED verification — rolling back to ${backup#"$REPO_ROOT"/}"
"$REPO_ROOT/scripts/rollback.sh" "$backup" --apply || true
# The wave did not stick: restore the previous applied-wave marker.
echo $((wave - 1)) >"$REPO_ROOT/state/applied-wave"
reboot_tv 360
sleep 60
if "$REPO_ROOT/scripts/verify.sh"; then
  warn "rolled back; the TV is healthy again (state/applied-wave = $((wave - 1)))"
  exit 1
fi
warn "rolled back (state/applied-wave = $((wave - 1))), but verification still fails — manual attention needed"
exit 2
