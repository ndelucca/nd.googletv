#!/usr/bin/env bash
# Benchmark under the same conditions as right after a wave, so runs are comparable:
# reboot → wait → verify --ui → benchmark.sh. Opens apps on the TV screen for ~17 minutes.
#
#   scripts/measure.sh <label>
source "$(dirname "$0")/lib.sh"
[[ $# -eq 1 ]] || die "usage: $(basename "$0") <label>"
ensure_connected

reboot_tv 360
sleep 60   # same settle time as wave.sh
"$REPO_ROOT/scripts/verify.sh" --ui || die "verification failed — not benchmarking"
"$REPO_ROOT/scripts/benchmark.sh" "$1" --yes
