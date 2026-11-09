#!/usr/bin/env bash
# Objective before/after measurements, written to benchmarks/<date>-<label>.md.
#
# It OPENS AND CLOSES APPS ON THE TV SCREEN, so run it when nobody is watching:
#   scripts/benchmark.sh <label> --yes [--runs N]    full run, ~12 min: for system changes (waves)
#   scripts/benchmark.sh <label> --yes --quick       ~4 min: to compare launchers. Skips the app launch
#                                                    timings (they don't depend on the launcher), one
#                                                    multitask round, 30 s settle
#
# Measures:
#   memory     idle on Home with the test apps closed (before) and after the run: MemAvailable, swap, PSS per priority bucket
#              (Persistent/Visible/Perceptible = RAM the system can't reclaim), cached apps
#   launch     cold start of each app (am start -W TotalTime, median of N) and warm-start state
#   home       time to get back to the launcher and whether it had been killed (COLD)
#   multitask  open every user app in a row, go Home, count how many are still in memory
#   kills      low-memory kills during the run
#   launcher   the HOME app's own memory and idle CPU (and surfaceflinger's, to spot redraws)
#
# Note: am start -W stops at the app's first frame (often a splash), so launch times are
# best used to compare runs, not as "time until usable".
source "$(dirname "$0")/lib.sh"

label=""; RUNS=5; YES=0; QUICK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)  YES=1 ;;
    --runs) RUNS="$2"; shift ;;
    --quick) QUICK=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) [[ -z "$label" ]] && label="$1" || die "unexpected argument: $1" ;;
  esac
  shift
done
[[ -n "$label" ]] || die "usage: $(basename "$0") <label> --yes [--runs N | --quick]"
[[ $YES -eq 1 ]] || die "this opens apps on the TV screen for several minutes; re-run with --yes when nobody is watching"
[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || die "label may only contain letters, digits, . _ -"
ensure_connected

LAUNCH_APPS=(com.google.android.youtube.tv com.netflix.ninja com.spotify.tv.android)
MULTI_APPS=(com.google.android.youtube.tv com.netflix.ninja com.spotify.tv.android org.jellyfin.androidtv
            com.crunchyroll.crunchyroid nl.giejay.android.tv.immich com.android.vending)
MULTI_ROUNDS=3
SETTLE="${SETTLE:-60}"   # seconds idle on Home before measuring memory
if [[ $QUICK -eq 1 ]]; then RUNS=0; MULTI_ROUNDS=1; SETTLE="${SETTLE_QUICK:-30}"; fi
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
# Also close other installed (third-party) launchers, so one being tested doesn't pay for the last one.
home_pkg="$(current_home_pkg)"
for pkg in $(comm -12 \
    <(tv_shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME \
        | sed -nE 's#^ *([^/ ]+)/.*#\1#p' | LC_ALL=C sort -u) \
    <(tv_shell pm list packages -3 | sed 's/^package://' | LC_ALL=C sort -u)); do
  [[ "$pkg" != "$home_pkg" ]] && tv_shell am force-stop "$pkg"
done
log "settling on Home for ${SETTLE}s"
home >/dev/null; sleep "$SETTLE"
mem_snapshot "$tmp/mem0"

# The launcher itself, idle on Home: memory (all its processes, incl. swap) and CPU over 10 s.
# surfaceflinger's CPU shows whether the launcher keeps redrawing the screen (animations, video wallpaper).
# Measured before and after the run: right after a launcher starts its memory is inflated, after
# using other apps it is what it settles to.
launcher_stats() {   # → "pss_mb swap_mb cpu% surfaceflinger_cpu%"
  local mem pids
  mem="$(tv_shell dumpsys meminfo --package "$home_pkg" \
    | awk '/TOTAL PSS:/ {p += $3; s += $NF} END {printf "%d %d", p / 1024, s / 1024}')"
  pids="$(tv_shell pidof "$home_pkg" surfaceflinger | tr ' ' ',')"
  echo "$mem $(tv_shell top -b -n 2 -d 10 -p "$pids" -o %CPU,ARGS \
    | awk -v p="$home_pkg" '$1 ~ /^[0-9.]+$/ {c[$2] = $1}
        END {for (n in c) if (index(n, p) == 1) l += c[n]; printf "%.1f %.1f", l, c["surfaceflinger"]}')"
}
read -r l_pss l_swap l_cpu sf_cpu < <(launcher_stats)

declare -A COLD WARMSTATE
home_times=(); home_cold=0; home_total=0
go_home() {
  local hs ht
  read -r hs ht < <(home); home_times+=("$ht"); home_total=$((home_total + 1))
  [[ "$hs" == "COLD" ]] && home_cold=$((home_cold + 1))
  echo "home $hs $ht" >>"$raw"
}

if [[ $QUICK -eq 1 ]]; then
  # From a full-screen app (TV Settings is a side panel over the launcher, so it can't be used here).
  log "back to Home: 5 times from ${LAUNCH_APPS[0]}"
  comp="$(app_component "${LAUNCH_APPS[0]}")"
  for _ in 1 2 3 4 5; do
    tv_shell am start -n "$comp" >/dev/null 2>&1; sleep 5; go_home; sleep 2
  done
fi

for pkg in "${LAUNCH_APPS[@]}"; do
  [[ $RUNS -gt 0 ]] || break
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
read -r l_pss1 l_swap1 l_cpu1 sf_cpu1 < <(launcher_stats)
# am_kill also logs this script's own force-stops ("stop <pkg> due to ..."); count those apart.
kill_log="$(tv_shell "logcat -b events -d -T '$t0'" 2>/dev/null | grep ' am_kill ' || true)"
stops="$(grep -c ',stop ' <<<"$kill_log" || true)"
kills="$(grep -vc ',stop ' <<<"$kill_log" || true)"
[[ -n "$kill_log" ]] || kills=0
kill_reasons="$({ grep -v ',stop ' <<<"$kill_log" || true; } | sed -nE 's/.*am_kill *: \[[0-9]+,[0-9]+,([^,]+),[0-9]+,(.*)\]$/\1 \2/p' | sort | uniq -c | sort -rn)"

{
  echo "# Benchmark \`$label\` — $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "- Firmware: \`$(tv_shell getprop ro.build.fingerprint)\`"
  echo "- Launcher: \`$(tv_shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n1)\`"
  echo "- Applied wave: $(cat "$REPO_ROOT/state/applied-wave" 2>/dev/null || echo 0) · enabled packages: $(tv_shell pm list packages -e | wc -l) · uptime: $(tv_shell cat /proc/uptime | awk '{printf "%d min", $1/60}')"
  if [[ $QUICK -eq 1 ]]; then
    echo "- Quick run (to compare launchers): no app launch timings, $MULTI_ROUNDS multitask round · settle: ${SETTLE}s"
  else
    echo "- Runs: $RUNS launches per app, $MULTI_ROUNDS multitask rounds · settle: ${SETTLE}s"
  fi
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
  echo "## Launcher \`$home_pkg\`, idle on Home"
  echo
  echo "| | Before the run | After the run |"
  echo "|---|---:|---:|"
  echo "| **Memory, PSS of all its processes (MB)** | **$l_pss** | **$l_pss1** |"
  echo "| of which in swap (MB) | $l_swap | $l_swap1 |"
  echo "| CPU over 10 s, launcher | $l_cpu % | $l_cpu1 % |"
  echo "| CPU over 10 s, surfaceflinger (high = the launcher keeps redrawing) | $sf_cpu % | $sf_cpu1 % |"
  echo
  echo "## Multitask"
  echo
  echo "- **Apps still in memory after opening $multi_total in a row: median $(printf '%s\n' "${survivors[@]}" | median) of $multi_total** (rounds: ${survivors[*]})"
  echo
  if [[ $RUNS -gt 0 ]]; then
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
  fi
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
