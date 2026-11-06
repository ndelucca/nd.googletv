#!/usr/bin/env bash
# Objective before/after measurements, written to benchmarks/<date>-<label>.md.
#
# It OPENS AND CLOSES APPS ON THE TV SCREEN for ~12 minutes, so run it when nobody is watching:
#   scripts/benchmark.sh <label> --yes [--runs N]
#
# Measures:
#   memory     idle on Home with the test apps closed (before) and after the run: MemAvailable, swap, PSS per priority bucket
#              (Persistent/Visible/Perceptible = RAM the system can't reclaim), cached apps
#   launch     cold start of each app (am start -W TotalTime, median of N) and warm-start state
#   home       time to get back to the launcher and whether it had been killed (COLD)
#   multitask  open every user app in a row, go Home, count how many are still in memory
#   kills      low-memory kills during the run
#
# Note: am start -W stops at the app's first frame (often a splash), so launch times are
# best used to compare runs, not as "time until usable".
source "$(dirname "$0")/lib.sh"

label=""; RUNS=5; YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)  YES=1 ;;
    --runs) RUNS="$2"; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) [[ -z "$label" ]] && label="$1" || die "unexpected argument: $1" ;;
  esac
  shift
done
[[ -n "$label" ]] || die "usage: $(basename "$0") <label> --yes [--runs N]"
[[ $YES -eq 1 ]] || die "this opens apps on the TV screen for ~12 minutes; re-run with --yes when nobody is watching"
[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || die "label may only contain letters, digits, . _ -"
ensure_connected

LAUNCH_APPS=(com.google.android.youtube.tv com.netflix.ninja com.spotify.tv.android)
MULTI_APPS=(com.google.android.youtube.tv com.netflix.ninja com.spotify.tv.android org.jellyfin.androidtv
            com.crunchyroll.crunchyroid nl.giejay.android.tv.immich com.android.vending)
MULTI_ROUNDS=3
SETTLE="${SETTLE:-60}"   # seconds idle on Home before measuring memory
BUCKETS=(Native System Persistent "Persistent Service" Foreground Visible Perceptible "A Services" Home Previous "B Services" Cached)

tv_shell input keyevent KEYCODE_WAKEUP || true
sleep 2
wake="$(tv_shell dumpsys power | sed -nE 's/.*mWakefulness=([A-Za-z]+).*/\1/p' | head -n1)"
[[ "$wake" == "Awake" ]] || die "the TV screen is not on (wakefulness: ${wake:-?}); turn it on first"

# am_start <args...> → "<LaunchState> <TotalTime ms>"
am_start() {
  local o s t
  o="$(tv_shell am start -W "$@" 2>&1)"
  s="$(sed -n 's/^LaunchState: //p' <<<"$o" | awk '{print $1}')"
  t="$(sed -n 's/^TotalTime: //p' <<<"$o")"
  echo "${s:-?} ${t:-NA}"
}
home() { am_start -a android.intent.action.MAIN -c android.intent.category.HOME; }
app_component() {
  tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN \
    -c android.intent.category.LEANBACK_LAUNCHER "$1" | tail -n1 | grep '/' || true
}
median() {
  grep -E '^[0-9]+$' | sort -n | awk '{a[NR]=$1} END {
    if (NR == 0) { print "NA"; exit }
    print (NR % 2) ? a[(NR + 1) / 2] : int((a[NR / 2] + a[NR / 2 + 1]) / 2) }'
}
# mem_snapshot <file>: "key value" lines (MB) for MemAvailable, SwapFree, each OOM bucket, cached count.
mem_snapshot() {
  local mi dm
  mi="$(tv_shell cat /proc/meminfo)"
  dm="$(tv_shell dumpsys -t 60 meminfo)"
  {
    awk '/^MemAvailable:/ {print "MemAvailable", int($2/1024)} /^SwapFree:/ {print "SwapFree", int($2/1024)}' <<<"$mi"
    # Bucket lines ("  123,456K: Visible") have no "(pid"; process lines do.
    awk '/^Total PSS by OOM adjustment/ {f=1; next}
         f && /^Total PSS by category/ {exit}
         f && !/\(pid/ && /K: / {kb=$1; gsub(/[,K:]/, "", kb); name=$0; sub(/^ *[0-9,]+K: /, "", name)
                                 printf "bucket:%s %d\n", name, int(kb/1024); cur=name; next}
         f && /\(pid/ && cur == "Cached" {n++}
         END {print "CachedProcs", n+0}' <<<"$dm"
    echo "Processes $(tv_shell ps -A | wc -l)"
  } >"$1"
}
val() { awk -v k="$2" '{v=$NF; $NF=""; sub(/ $/, ""); if ($0 == k) {print v; f=1}} END {if (!f) print 0}' "$1"; }
unreclaimable() {
  local f="$1" sum=0 b
  for b in Persistent "Persistent Service" Visible Perceptible; do sum=$((sum + $(val "$f" "bucket:$b"))); done
  echo "$sum"
}

out="$REPO_ROOT/benchmarks/$(date +%Y%m%d-%H%M)-$label.md"
mkdir -p "$(dirname "$out")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
raw="$tmp/raw"; : >"$raw"
t0="$(tv_shell "date '+%m-%d %H:%M:%S.000'")"

# Start from the same state every time: test apps closed, so "before" measures only the system.
for pkg in "${MULTI_APPS[@]}"; do tv_shell am force-stop "$pkg"; done
log "settling on Home for ${SETTLE}s"
home >/dev/null; sleep "$SETTLE"
mem_snapshot "$tmp/mem0"

declare -A COLD WARMSTATE
home_times=(); home_cold=0; home_total=0
go_home() {
  local hs ht
  read -r hs ht < <(home); home_times+=("$ht"); home_total=$((home_total + 1))
  [[ "$hs" == "COLD" ]] && home_cold=$((home_cold + 1))
  echo "home $hs $ht" >>"$raw"
}

for pkg in "${LAUNCH_APPS[@]}"; do
  comp="$(app_component "$pkg")"
  if [[ -z "$comp" ]]; then warn "$pkg has no launcher activity, skipped"; continue; fi
  log "$pkg: $RUNS cold + $RUNS warm starts"
  for _ in $(seq 1 "$RUNS"); do
    read -r _ t < <(am_start -S -n "$comp"); COLD[$pkg]+="$t "; echo "cold $pkg $t" >>"$raw"
    sleep 5; go_home; sleep 3
  done
  for _ in $(seq 1 "$RUNS"); do
    # Warm = the process survived; "UNKNOWN" means the task was just brought to front (also warm).
    read -r s t < <(am_start -n "$comp"); WARMSTATE[$pkg]+="$s "; echo "warm $pkg $s $t" >>"$raw"
    sleep 5; go_home; sleep 3
  done
done

log "multitask: open ${#MULTI_APPS[@]} apps in a row, $MULTI_ROUNDS rounds"
survivors=()
for r in $(seq 1 "$MULTI_ROUNDS"); do
  opened=()
  for pkg in "${MULTI_APPS[@]}"; do tv_shell am force-stop "$pkg"; done
  sleep 3
  for pkg in "${MULTI_APPS[@]}"; do
    comp="$(app_component "$pkg")"; [[ -z "$comp" ]] && continue
    tv_shell am start -n "$comp" >/dev/null 2>&1 || continue
    opened+=("$pkg"); sleep 8
  done
  home >/dev/null; sleep 10
  alive=0; alive_list=""
  for pkg in "${opened[@]}"; do
    if tv_shell pidof "$pkg" >/dev/null 2>&1; then alive=$((alive + 1)); alive_list+="${pkg##*.} "; fi
  done
  survivors+=("$alive")
  echo "multitask round $r: $alive/${#opened[@]} alive: $alive_list" >>"$raw"
done
multi_total="${#opened[@]}"

home >/dev/null
log "settling on Home for ${SETTLE}s"
sleep "$SETTLE"
mem_snapshot "$tmp/mem1"
# am_kill also logs this script's own force-stops ("stop <pkg> due to ..."); count those apart.
kill_log="$(tv_shell "logcat -b events -d -T '$t0'" 2>/dev/null | grep ' am_kill ' || true)"
stops="$(grep -c ',stop ' <<<"$kill_log" || true)"
kills="$(grep -vc ',stop ' <<<"$kill_log" || true)"
[[ -n "$kill_log" ]] || kills=0
kill_reasons="$(grep -v ',stop ' <<<"$kill_log" | sed -nE 's/.*am_kill *: \[[0-9]+,[0-9]+,([^,]+),[0-9]+,(.*)\]$/\1 \2/p' | sort | uniq -c | sort -rn)"

{
  echo "# Benchmark \`$label\` — $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "- Firmware: \`$(tv_shell getprop ro.build.fingerprint)\`"
  echo "- Launcher: \`$(tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1)\`"
  echo "- Applied wave: $(cat "$REPO_ROOT/state/applied-wave" 2>/dev/null || echo 0) · enabled packages: $(tv_shell pm list packages -e | wc -l) · uptime: $(tv_shell cat /proc/uptime | awk '{printf "%d min", $1/60}')"
  echo "- Runs: $RUNS launches per app, $MULTI_ROUNDS multitask rounds · settle: ${SETTLE}s"
  echo
  echo "## Memory, idle on Home (MB)"
  echo
  echo "| | Before | After |"
  echo "|---|---:|---:|"
  echo "| **MemAvailable** | **$(val "$tmp/mem0" MemAvailable)** | **$(val "$tmp/mem1" MemAvailable)** |"
  echo "| Free swap | $(val "$tmp/mem0" SwapFree) | $(val "$tmp/mem1" SwapFree) |"
  echo "| **Unreclaimable** (Persistent + Visible + Perceptible) | **$(unreclaimable "$tmp/mem0")** | **$(unreclaimable "$tmp/mem1")** |"
  for b in "${BUCKETS[@]}"; do
    echo "| PSS · $b | $(val "$tmp/mem0" "bucket:$b") | $(val "$tmp/mem1" "bucket:$b") |"
  done
  echo "| Cached processes | $(val "$tmp/mem0" CachedProcs) | $(val "$tmp/mem1" CachedProcs) |"
  echo "| Processes | $(val "$tmp/mem0" Processes) | $(val "$tmp/mem1" Processes) |"
  echo
  echo "## Multitask"
  echo
  echo "- **Apps still in memory after opening $multi_total in a row: median $(printf '%s\n' "${survivors[@]}" | median) of $multi_total** (rounds: ${survivors[*]})"
  echo
  echo "## App launch"
  echo
  echo "| App | Cold, median ms | Warm launches that found the app alive |"
  echo "|---|---:|---:|"
  for pkg in "${LAUNCH_APPS[@]}"; do
    [[ -n "${COLD[$pkg]:-}" ]] || continue
    warm_ok="$(tr ' ' '\n' <<<"${WARMSTATE[$pkg]}" | grep -cE '^(HOT|WARM|UNKNOWN)$' || true)"
    echo "| \`$pkg\` | $(tr ' ' '\n' <<<"${COLD[$pkg]}" | median) | $warm_ok of $RUNS |"
  done
  echo
  echo "## Back to Home"
  echo
  echo "- Median: $(printf '%s\n' "${home_times[@]}" | median) ms"
  echo "- Launcher had been killed (COLD): $home_cold of $home_total returns"
  echo
  echo "## Low-memory kills during the run: $kills"
  echo
  echo "(Not counting the $stops force-stops the benchmark does itself. Reasons: tguard-kill = TCL TGuard, omm-kill-cached = TCL, lmk = Android.)"
  echo
  echo "<details><summary>Raw data</summary>"
  echo
  echo '```'
  cat "$raw"
  echo "--- low-memory kills (count process reason)"; echo "${kill_reasons:-none}"
  echo "--- memory before"; cat "$tmp/mem0"
  echo "--- memory after";  cat "$tmp/mem1"
  echo '```'
  echo "</details>"
} >"$out"

log "results: ${out#"$REPO_ROOT"/}"
sed -n '/^## Memory/,/^## Low-memory/p' "$out"
