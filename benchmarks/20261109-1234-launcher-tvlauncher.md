# Benchmark `launcher-tvlauncher` — 2026-11-09 12:37

- Firmware: `TCL/G03_4K_GB/BeyondTV4:11/RP1A.200622.001/AR11:user/release-keys`
- Launcher: `com.tvlauncher/.MainActivity`
- Applied wave: 6 · enabled packages: 90 · uptime: 4910 min
- Quick run (to compare launchers): no app launch timings, 1 multitask round · settle: 30s

## Memory, idle on Home (MB)

| | Before | After |
|---|---:|---:|
| **MemAvailable** | **658** | **379** |
| Free swap | 524 | 429 |
| **Unreclaimable** (Persistent + Visible + Perceptible) | **289** | **375** |
| PSS · Native | 264 | 266 |
| PSS · System | 111 | 114 |
| PSS · Persistent | 98 | 101 |
| PSS · Persistent Service | 39 | 34 |
| PSS · Foreground | 95 | 34 |
| PSS · Visible | 90 | 95 |
| PSS · Perceptible | 62 | 145 |
| PSS · A Services | 37 | 25 |
| PSS · Home | 0 | 0 |
| PSS · Previous | 0 | 150 |
| PSS · B Services | 23 | 117 |
| PSS · Cached | 80 | 213 |
| Cached processes | 8 | 11 |
| Processes | 290 | 302 |

## Launcher `com.tvlauncher`, idle on Home

- Memory: **86 MB** PSS, all its processes (0 MB of it in swap)
- Note (added by hand): 86 MB was read right after its app picker (inflated). Measured by hand after the run, idle on Home: **26 MB** PSS (9 MB of it in swap). This report predates the before/after launcher table.
- CPU over 10 s: launcher 0.2 %, surfaceflinger 0.1 % (high surfaceflinger = the launcher keeps redrawing)

## Multitask

- **Apps still in memory after opening 7 in a row: median 6 of 7** (rounds: 6)

## Back to Home

- Median: 87 ms
- Launcher had been killed (COLD): 0 of 5 returns

## Low-memory kills during the run: 0

(Not counting the 13 force-stops the benchmark does itself. Reasons: tguard-kill = TCL TGuard, omm-kill-cached = TCL, lmk = Android.)

<details><summary>Raw data</summary>

```
home HOT 106
home HOT 100
home HOT 87
home HOT 83
home HOT 87
multitask round 1: 6/7 alive: tv ninja android androidtv immich vending 
--- low-memory kills (count process reason)
none
--- memory before
MemAvailable 658
SwapFree 524
bucket:Native 264
bucket:System 111
bucket:Persistent 98
bucket:Persistent Service 39
bucket:Foreground 95
bucket:Visible 90
bucket:Perceptible 62
bucket:A Services 37
bucket:B Services 23
bucket:Cached 80
CachedProcs 8
Processes 290
--- memory after
MemAvailable 379
SwapFree 429
bucket:Native 266
bucket:System 114
bucket:Persistent 101
bucket:Persistent Service 34
bucket:Foreground 34
bucket:Visible 95
bucket:Perceptible 145
bucket:A Services 25
bucket:Previous 150
bucket:B Services 117
bucket:Cached 213
CachedProcs 11
Processes 302
```
</details>
