#!/usr/bin/env bash
# Bring the TV to the state described in config/, up to a given wave.
#
#   scripts/apply.sh                    dry-run of every wave in config/
#   scripts/apply.sh --wave 1           dry-run of waves 0..1
#   scripts/apply.sh --wave 1 --apply   backup, then apply waves 0..1
#
# Idempotent: re-running only touches what drifted. Rollback: scripts/rollback.sh <backup dir>.
source "$(dirname "$0")/lib.sh"
parse_apply_args "$@"
ensure_connected

args=(--wave "$MAX_WAVE"); [[ $APPLY -eq 1 ]] && args+=(--apply)

if [[ $APPLY -eq 1 ]]; then
  backup_dir="$("$REPO_ROOT/scripts/backup.sh" "wave$MAX_WAVE")"
  export CHANGES_LOG="$backup_dir/changes.log"
  : >"$CHANGES_LOG"
  echo "${backup_dir#"$REPO_ROOT"/}" >"$REPO_ROOT/state/last-backup"
fi

rc=0
# apps first (a new launcher must exist), then home (packages never disables the HOME in use).
# appops before settings: enabling an accessibility service binds it at once, and TCL's
# APP_AUTO_START gate refuses that bind (and the system never retries) unless the op is allowed.
for step in apps home packages appops settings compile; do
  "$REPO_ROOT/scripts/apply-$step.sh" "${args[@]}" || rc=1
done

if [[ $APPLY -eq 1 ]]; then
  if [[ ! -s "$CHANGES_LOG" ]]; then
    rm -rf "$backup_dir"; rm -f "$REPO_ROOT/state/last-backup"
    log "nothing changed — the TV already matches config/ (backup discarded)"
  else
    log "$(wc -l <"$CHANGES_LOG") changes recorded in ${CHANGES_LOG#"$REPO_ROOT"/}"
  fi
  # Remember the highest wave applied so doctor.sh knows what "in sync" means.
  if [[ $rc -eq 0 && "$MAX_WAVE" -gt "$(cat "$REPO_ROOT/state/applied-wave" 2>/dev/null || echo 0)" ]]; then
    echo "$MAX_WAVE" >"$REPO_ROOT/state/applied-wave"
    log "state/applied-wave = $MAX_WAVE"
  fi
  if [[ -s "${CHANGES_LOG}" ]]; then
    log "next: restart the TV, run the checklist in docs/PLAN.md, then scripts/benchmark.sh and scripts/collect.sh"
    log "undo: scripts/rollback.sh ${backup_dir#"$REPO_ROOT"/} --apply"
  fi
fi
exit $rc
