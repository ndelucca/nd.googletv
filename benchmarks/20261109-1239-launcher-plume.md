# Benchmark `launcher-plume` — 2026-11-09 12:42

- Firmware: `TCL/G03_4K_GB/BeyondTV4:11/RP1A.200622.001/AR11:user/release-keys`
- Launcher: `dev.plume/.MainActivity`
- Applied wave: 6 · enabled packages: 90 · uptime: 4915 min
- Quick run (to compare launchers): no app launch timings, 1 multitask round · settle: 30s

## Memory, idle on Home (MB)

| | Before | After |
|---|---:|---:|
| **MemAvailable** | **695** | **390** |
| Free swap | 497 | 368 |
| **Unreclaimable** (Persistent + Visible + Perceptible) | **262** | **354** |
| PSS · Native | 264 | 262 |
| PSS · System | 108 | 109 |
| PSS · Persistent | 101 | 96 |
| PSS · Persistent Service | 39 | 34 |
| PSS · Foreground | 83 | 48 |
| PSS · Visible | 85 | 88 |
| PSS · Perceptible | 37 | 136 |
| PSS · A Services | 31 | 26 |
| PSS · Home | 0 | 0 |
| PSS · Previous | 0 | 143 |
| PSS · B Services | 19 | 116 |
| PSS · Cached | 111 | 238 |
| Cached processes | 8 | 12 |
| Processes | 291 | 307 |

## Launcher `dev.plume`, idle on Home

| | Before the run | After the run |
|---|---:|---:|
| **Memory, PSS of all its processes (MB)** | **73** | **39** |
| of which in swap (MB) | 0 | 6 |
| CPU over 10 s, launcher | 0.0 % | 0.0 % |
| CPU over 10 s, surfaceflinger (high = the launcher keeps redrawing) | 0.0 % | 0.0 % |

## Multitask

- **Apps still in memory after opening 7 in a row: median 6 of 7** (rounds: 6)

## Back to Home

- Median: 90 ms
- Launcher had been killed (COLD): 0 of 5 returns

## Low-memory kills during the run: 0

(Not counting the 13 force-stops the benchmark does itself. Reasons: tguard-kill = TCL TGuard, omm-kill-cached = TCL, lmk = Android.)

<details><summary>Raw data</summary>

```
home HOT 115
home HOT 90
home HOT 90
home HOT 87
home HOT 88
multitask round 1: 6/7 alive: tv ninja android androidtv immich vending 
--- low-memory kills (count process reason)
none
--- memory before
MemAvailable 695
SwapFree 497
bucket:Native 264
bucket:System 108
bucket:Persistent 101
bucket:Persistent Service 39
bucket:Foreground 83
bucket:Visible 85
bucket:Perceptible 37
bucket:A Services 31
bucket:B Services 19
bucket:Cached 111
CachedProcs 8
Processes 291
--- memory after
MemAvailable 390
SwapFree 368
bucket:Native 262
bucket:System 109
bucket:Persistent 96
bucket:Persistent Service 34
bucket:Foreground 48
bucket:Visible 88
bucket:Perceptible 136
bucket:A Services 26
bucket:Previous 143
bucket:B Services 116
bucket:Cached 238
CachedProcs 12
Processes 307
```
</details>
