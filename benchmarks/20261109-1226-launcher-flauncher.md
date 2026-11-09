# Benchmark `launcher-flauncher` — 2026-11-09 12:29

- Firmware: `TCL/G03_4K_GB/BeyondTV4:11/RP1A.200622.001/AR11:user/release-keys`
- Launcher: `me.efesser.flauncher/.MainActivity`
- Applied wave: 5 · enabled packages: 88 · uptime: 4902 min
- Quick run (to compare launchers): no app launch timings, 1 multitask round · settle: 30s

## Memory, idle on Home (MB)

| | Before | After |
|---|---:|---:|
| **MemAvailable** | **678** | **346** |
| Free swap | 439 | 384 |
| **Unreclaimable** (Persistent + Visible + Perceptible) | **274** | **340** |
| PSS · Native | 261 | 259 |
| PSS · System | 123 | 111 |
| PSS · Persistent | 102 | 100 |
| PSS · Persistent Service | 39 | 33 |
| PSS · Foreground | 59 | 63 |
| PSS · Visible | 102 | 86 |
| PSS · Perceptible | 31 | 121 |
| PSS · A Services | 52 | 23 |
| PSS · Home | 0 | 0 |
| PSS · Previous | 0 | 123 |
| PSS · B Services | 19 | 115 |
| PSS · Cached | 86 | 268 |
| Cached processes | 8 | 11 |
| Processes | 289 | 303 |

## Launcher `me.efesser.flauncher`, idle on Home

- Memory: **48 MB** PSS, all its processes (19 MB of it in swap)
- CPU over 10 s: launcher 42.6 %, surfaceflinger 34.8 % (high surfaceflinger = the launcher keeps redrawing)

## Multitask

- **Apps still in memory after opening 7 in a row: median 6 of 7** (rounds: 6)

## Back to Home

- Median: 78 ms
- Launcher had been killed (COLD): 0 of 5 returns

## Low-memory kills during the run: 1

(Not counting the 13 force-stops the benchmark does itself. Reasons: tguard-kill = TCL TGuard, omm-kill-cached = TCL, lmk = Android.)

<details><summary>Raw data</summary>

```
home HOT 118
home HOT 77
home HOT 78
home HOT 84
home HOT 77
multitask round 1: 6/7 alive: tv ninja android androidtv immich vending 
--- low-memory kills (count process reason)
      1 com.tcl.partnercustomizer empty for 5516s
--- memory before
MemAvailable 678
SwapFree 439
bucket:Native 261
bucket:System 123
bucket:Persistent 102
bucket:Persistent Service 39
bucket:Foreground 59
bucket:Visible 102
bucket:Perceptible 31
bucket:A Services 52
bucket:B Services 19
bucket:Cached 86
CachedProcs 8
Processes 289
--- memory after
MemAvailable 346
SwapFree 384
bucket:Native 259
bucket:System 111
bucket:Persistent 100
bucket:Persistent Service 33
bucket:Foreground 63
bucket:Visible 86
bucket:Perceptible 121
bucket:A Services 23
bucket:Previous 123
bucket:B Services 115
bucket:Cached 268
CachedProcs 11
Processes 303
```
</details>
