#!/usr/bin/env bash
# Temporarily re-enable TCL's updater to check for (and install) a firmware update,
# then disable it again. The updater stays disabled the rest of the time (config/packages.conf, wave 4).
#
#   scripts/firmware-update.sh
#
# Steps: enable updater → reboot so its services start → open the update screen on the TV →
# wait for you to press Enter (install the update on the TV if there is one; the TV reboots) →
# re-apply config/ (disables the updater again) → collect.sh + doctor.sh to record the new firmware.
source "$(dirname "$0")/lib.sh"
ensure_connected

UPDATER=(com.tcl.ttvs com.tcl.versionUpdateApp)
UPDATE_ACTIVITY="com.tcl.versionUpdateApp/com.tcl.ttvs.versionUpdateApp.core.UI.SystemUpdateActivity"

log "current firmware: $(tv_shell getprop ro.build.display.id) / $(tv_shell getprop ro.software.version_id 2>/dev/null)"
for p in "${UPDATER[@]}"; do
  tv_shell pm enable "$p" >/dev/null && log "enabled $p"
done
reboot_tv 360
sleep 30

log "opening the system update screen on the TV"
tv_shell am start -n "$UPDATE_ACTIVITY" >/dev/null 2>&1 \
  || tv_shell am start -a android.settings.SYSTEM_UPDATE_SETTINGS >/dev/null 2>&1 || true

echo
echo "  On the TV: check for updates and install one if offered (the TV will reboot)."
echo "  Then come back here and press Enter to disable the updater again."
read -r _

wait_for_boot 900
applied="$(cat "$REPO_ROOT/state/applied-wave" 2>/dev/null || echo 0)"
log "re-applying config/ up to wave $applied (disables the updater again)"
"$REPO_ROOT/scripts/apply.sh" --wave "$applied" --apply || true
"$REPO_ROOT/scripts/collect.sh"
"$REPO_ROOT/scripts/doctor.sh" || warn "doctor found differences — if the firmware changed, review 'git diff inventory/'"
