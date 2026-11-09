# Research: maintained, very light launchers (32-bit TCL G03)

_Web research compiled on 2026-11-06. Each candidate's release APK was downloaded and inspected (native-lib ABIs, manifest, dex SDK strings) without running it; every URL returned 200 with `curl -fsIL` that day. "(self)" = figure the project reports about itself; "(rival)" = measured by a competing launcher's author; "(inference)" = reasoning. Source material for [`../PLAN.md`](../PLAN.md)._

**32-bit filter:** no candidate failed. Plain Java/Kotlin APKs carry no native libs (install on any ABI); Flutter, Compose and Projectivy APKs ship `armeabi-v7a`.

Baseline on this TV: **FLauncher 0.18.0 ≈ 38 MB PSS + 12 MB swap** (measured 2026-11-06).

## Candidates

| Launcher | Package / HOME | Licence | Latest (date) / 2026 cadence | Tech, APK size | PSS | Network, telemetry, special perms | Features |
|---|---|---|---|---|---|---|---|
| **TV Launcher** ([repo](https://github.com/wiiguy/lightweight_androidtv_launcher), [F-Droid](https://f-droid.org/en/packages/com.tvlauncher/)) | `com.tvlauncher/.MainActivity` | FOSS (F-Droid) | 1.6.2 (GitHub 2026-10-07, F-Droid 2026-10-22); 8 releases since 2025-12-03 | Plain Kotlin Views, 1.25 MB | **25–30 MB** updater off, 30–40 MB default, 45–50 MB with Home override (self) | Internet only for a weekly GitHub update check; F-Droid build has no updater. Optional accessibility Home override | Reorder apps, gear → system settings. No categories, HDMI shortcut or Watch Next |
| **LtvLauncher** ([repo](https://github.com/leanbitlab-org/LtvLauncher)) | `com.leanbitlab.ltvL/.MainActivity` | GPL-3.0 | v2026.10.27; 25 releases in 2026; perf PRs Apr–Jul | Flutter, 9.7 MB v7a | Not published; likely ≥ FLauncher's 38 MB (inference) | No Firebase. Usage stats, Watch Next/EPG read, `WRITE_SETTINGS`, overlay, accessibility, notification-listener, dream services | Categories, HDMI/AV selector, Watch Next (toggle), key remap |
| **Plume** ([repo](https://github.com/aradhyas8/Plume_Launcher)) | `dev.plume/.MainActivity` | GPL-3.0 | 1.7.1 (2026-11-03); 11 releases since 2026-10-18 | Plain Views, 0.45 MB, "no third-party libraries and no background services" | 50–70 MB on a 1.8 GB Hisense Google TV (self) | Internet for self-updater and wallpaper/aerial downloads. Accessibility Home service | **Remaps TV/Netflix/Settings keys**, HDMI switch in top bar, Watch Next, hide apps |
| **Luncher** ([repo](https://github.com/CVasilakis/luncher)) | `com.luncher.launcher/.home.HomeActivity` | MIT | 1.0.0 (2026-11-01); 5 releases since 2026-10-08 | Plain Kotlin, 0.3 MB | "minimal", no number | **No permissions**, offline | Hide, reorder, rename |
| **Simple TV Launcher** ([repo](https://github.com/alescdb/LauncherTV)) | `org.cosinus.launchertv/.Launcher` | Apache-2.0 | 2.0.2 (2026-10-28); 3 releases in 2026; since 2017 | Plain Java, 2 MB | No figure | Wallpaper + network-state only | Folders, hidden apps, PIN |
| **just-a-launcher** ([repo](https://github.com/hungmi/just-a-launcher)) | `tw.hungmi.justalauncher/.MainActivity` | MIT | v0.9 (2026-09-24) | GridView, 35 KB, no text | **39 MB PSS incl. sub-processes and swap, 0 % idle CPU, 0 redraws/s** on a Cortex-A53 2 GB box (self) | No permissions | HDMI tile only if `com.google.android.tv.inputplayer` exists — probably not on TCL (inference) |
| Lite TV Launcher ([repo](https://github.com/anujmv/lite-tv-launcher)) | `dev.lite.launcher/.MainActivity` | GPL-3.0 | v1.0 (2026-10-19), only release | Plain Views, 44 KB | ~22 MB vs FLauncher ~43 and Google TV ~164 (self) | Offline | Hide, move, gear shortcut |
| Projectivy ([releases](https://github.com/spocky/miproja1/releases)) | `com.spocky.projengmenu/.ui.home.MainActivity` | Closed | 4.73 (2026-10-03) | Leanback + native libs, 11 MB | 78 MB animations off, 60 redraws/s default ([just-a-launcher](https://github.com/hungmi/just-a-launcher)); 65–70 MB ([Plume](https://github.com/aradhyas8/Plume_Launcher)) (rival) | **Firebase Analytics + Crashlytics, `AD_ID`, billing**. Accessibility | Categories, HDMI/AV shortcuts |
| ATV Launcher | Pro `ca.dstudio.atvlauncher.pro`, free `ca.dstudio.atvlauncher.free` | Closed | v0.1.41 (Sep 2026) | Play-only, not inspected | No data | — | — |

**Dropped:** osrosal FLauncher (dormant since 2025-07-27); LeanbackOnFire v1.63 (14 MB, Fire TV-oriented, Firebase, recommendations listener); Couchy (Compose, no release since 2026-08-01); nielsvanvelzen/tv-launcher and LineageOS Catapult (no APK releases); LaLauncher (toy); Wolf (unmaintained); CleanYourTV launcher `com.gathin.tvhome` (MIT, ~572 KB plain Java, no network, v3.4.0 2026-11-05, [repo](https://github.com/Gathin23/cleanyourtv)) — no release APK (built locally by its scripts), but **the only one with TCL G03 remote keys verified**.

**Framework cost on Cortex-A55 + Mali-G31 (inference):** plain Views start fastest; Flutter loads an engine + Dart snapshot and draws on its own thread (higher baseline); Compose pays runtime + JIT warm-up; blur, video wallpapers and always-running animations keep surfaceflinger busy (60 redraws/s measured on animated launchers).

## Can Google TV's launcherx be made light?

**No.** Measurements by competing launcher authors (no TCL-specific data):
- 183 MB PSS, 43 % of one core, surfaceflinger 32 %, 60 redraws/s on a 2 GB BenQ ([just-a-launcher](https://github.com/hungmi/just-a-launcher)).
- ~164 MB on a Xiaomi ([lite](https://github.com/anujmv/lite-tv-launcher)); ~93 MB + 22 MB helper on a Hisense ([Plume](https://github.com/aradhyas8/Plume_Launcher)).

**Apps only mode doesn't help:** it hides recommendations, turns off Search/Assistant and hides the Library ([Google](https://support.google.com/googletv/answer/10070784)); sponsored content can still appear ([TCL](https://support.tcl.com/en_US/google-tv-apps-only-mode)). Measured with it on: 175–190 MB, 39 % CPU, still 60 redraws/s, top ad carousel stays ([just-a-launcher](https://github.com/hungmi/just-a-launcher)).

The shell can't disable only launcherx's HOME activity ("Shell cannot change component state", [Troubleshooting](https://github.com/Gathin23/cleanyourtv/blob/main/docs/TROUBLESHOOTING.md)).

**Verdict:** launcherx stays at ~4–5× FLauncher's footprint even in Apps only mode. Keep it disabled.

## TCL remote keys without launcherx

Verified on G03/BeyondTV4 units ([debloat.txt header](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g03-google-tv/debloat.txt)):
- Netflix (HID 0x0c0051), YouTube (0x0c0057) and Prime (keycode 4099) are broadcasts only launcherx answers → do nothing while it's off.
- Gear = keycode 4077 (`TCL_SET`), only launcherx answered.
- Input keeps working through `com.tcl.suspension`.
- IR remotes use different scancodes (Netflix 758, YouTube 569, Prime 752). Identify with `getevent -lt`.
- **Fix verified on real remotes:** an accessibility key service mapping those keycodes to apps. Side effect: volume moved two steps per press until `consume_volume_keys` was set ([launcher.md #1100](https://github.com/Gathin23/cleanyourtv/blob/main/docs/launcher.md)).

**Key remappers** (accessibility services; plain Java, 32-bit OK (inference)):
- **Button Mapper** (`flar2.homebutton`, unverified): can remap Netflix, some functions fail on Google TV ([Android Central](https://androidcentral.com/how-remap-youtube-and-netflix-buttons-chromecast-google-tv)).
- **tvQuickActions** (`dev.vodik7.tvquickactions.free` / Pro): Netflix-key support "on some devices"; may need `APP_AUTO_START` ([AppGoblin](https://appgoblin.info/apps/dev.vodik7.tvquickactions.free)).
- On TCL: `appops set <pkg> APP_AUTO_START allow`. Users report remappers/launchers switching themselves off on TCL.
- A separate remapper = one more resident process; a launcher with built-in remap (Plume, LtvLauncher) avoids that (inference).

## Trial on this TV (2026-11-09): Plume won

Wave 6. Each candidate was installed by `scripts/apply-apps.sh`, made HOME by `apply-home.sh` and measured with `scripts/benchmark.sh --quick` (same TV state, ~7 min each; reports in [`../../benchmarks/`](../../benchmarks/)). "Idle" = sitting on Home, nothing pressed.

| | FLauncher 0.18.0 (before) | TV Launcher 1.6.2 (F-Droid) | **Plume 1.7.1** |
|---|---:|---:|---:|
| Memory, PSS of all its processes, idle | 48 MB (19 in swap) | **26 MB (9 in swap)**, measured by hand after the run | 39 MB (6 in swap) |
| CPU over 10 s idle: launcher / surfaceflinger | **42.6 % / 34.8 %** | 0.2 % / 0.1 % | 0.0 % / 0.0 % |
| Back to Home (median of 5) | 78 ms | 87 ms | 90 ms |
| Apps still in memory after opening 7 | 6/7 | 6/7 | 6/7 |
| Low-memory kills during the run | 1 | 0 | 0 |
| Netflix / YouTube / gear buttons | dead | dead | **work** (remapped by Plume) |

- **FLauncher redraws the screen 60 times a second while idle** (Flutter): a whole core between it and surfaceflinger, all day. That alone justified the change.
- Right after start, or after a heavy screen (TV Launcher's app picker, Plume's settings), PSS reads high (86 MB and 73 MB); it settles within minutes. Compare idle figures only.
- **Decision:** Plume, because it also fixes the remote's app buttons; TV Launcher was lighter but leaves them dead. FLauncher and TV Launcher were uninstalled (`config/packages.conf`, wave 6).

### TV Launcher notes (to try it again)

- Install: uncomment its line in `config/apps.conf` (pinned F-Droid APK, versionCode 10602, SHA-256 there), drop `6 com.tvlauncher uninstall` from `config/packages.conf`, set `com.tvlauncher/.MainActivity` in `config/home.conf`, run `scripts/wave.sh 6`.
- Starts with an **empty grid**: Add App → Select Apps → tick each app → Done. Done by hand with the remote (or `input keyevent` over ADB); the selection lives in its private data, so the scripts can't set it.
- Plain dark grid, no wallpaper, no clock. Gear tile → system settings. No HDMI shortcut, no rows, no key remap, no accessibility service, no network in the F-Droid build (no updater).
- To get the Netflix/YouTube/gear buttons with it you need a separate remapper (an extra resident process; see "TCL remote keys" above). Check it with `config/buttons.conf` + `scripts/verify.sh --ui`.
- No TCL quirks seen: no APP_AUTO_START needed (no services), survived the benchmark with 0 kills.

### Plume notes

- Settings used (Plume settings, top-right sliders icon): Shows row → **Never** (app grid only), Clock & weather Off (default), wallpaper "Arctic Aurora" (default, 4K; included in the PSS above), Home & remote → Home opens Plume.
- **Remote keys** (Plume settings → Home & remote → Remote keys → Add a key, press the button, Press → Open an app or input…): `Key 4062 (242)` → Netflix, `Key 4065 (245)` → YouTube, `Key 4077 (233)` → TV Settings. They live in Plume's private preferences: **if Plume's data is cleared or it is reinstalled, set them again** (with the real remote, or over ADB with the virtual remote below). `verify.sh --ui` fails if they're gone.
- Needs its accessibility service `dev.plume/dev.plume.HomeOverride` (settings.conf), `APP_AUTO_START allow` (appops.conf) and `WRITE_SECURE_SETTINGS` (apps.conf `grants=`, lets it turn its service back on).
- **Order matters:** enabling the service before `APP_AUTO_START` is allowed makes TCL refuse the bind (`TclAppBoot ... callee_does't_have_OP_AUTO_START_permission`) and Android never retries until the setting changes or the TV reboots. `apply.sh` now applies appops before settings.
- With remaps set Plume filters every key, but **holding volume still repeats normally** (40 → 17 with Plume vs 40 → 18 without, 1.5 s hold). The volume-hold caveat from other TVs doesn't apply here.
- Network: checks GitHub for a newer release when it's open (no scheduled job); installing one needs confirming on screen. `apply-apps.sh` pins 1.7.1 as the minimum.

## How the remote's app buttons work on this firmware

Found while testing (2026-11-09), from logcat and the `TclPhoneWindowManager` strings in `/system/framework/services.jar`:
- Netflix = keycode 4062 (`TCL_NETFLIX`, scan 242), YouTube = 4065 (`TCL_YOUTUBE`, scan 245), gear = 4077 (`TCL_SET`, scan 233). The remote (`TCL_RC902V_M8`, BLE, 0417:0304) uses `Generic.kl` and the generic HID driver; TCL's kernel maps consumer-page usages **0x51 → 242, 0x57 → 245, 0x55 → 233** (also 0x28b → 233).
- `TclPhoneWindowManager.handleCustomKey` → `startNetflix`/`startYouTube` sends a broadcast to launcherx's `GlobalButtonLaunch_Receiver` (Google TV platform path). With launcherx disabled nobody receives it: **the buttons stopped working in wave 0**, not because of anything later. The gear logs `Start tcl set short press` and opened TCL's dashboard through launcherx too.
- Accessibility key filters see these keys before `handleCustomKey`, so a remapping service (Plume) can take them.
- **`adb shell input keyevent` can't test this:** injected keys skip the accessibility input filter. Writing to `/dev/input` is blocked by SELinux. What works: a virtual HID device through `/dev/uhid` (the `shell` user is in the `uhid` group) created with the system `hid` tool, copying the real remote's identity (Bluetooth bus, 0417:0304). Its presses travel the same path as real ones. `scripts/lib.sh` has `vremote_start`/`vremote_press`/`vremote_stop`; `verify.sh --ui` uses them for `config/buttons.conf`.
- Don't name the virtual device `virtual-remote`: the system has a `virtual-remote.kl` that maps every key to 0.
- Usages were found without pressing anything: register a device whose descriptor covers a usage range and read the key bits it gets with `getevent -p`, narrowing the range.

## Ranking before the trial (web research)

1. **TV Launcher, F-Droid build** — `https://f-droid.org/repo/com.tvlauncher_10602.apk`. Lightest maintained option with published numbers (25–30 MB), plain Views, F-Droid-signed. Trade-offs: no categories or HDMI shortcut; Netflix/YouTube/Prime/gear keys need a remapper (extra process).
2. **Plume** — `https://github.com/aradhyas8/Plume_Launcher/releases/latest/download/Plume.apk`. Only one bundling HDMI switching + remote-key remap + Home service in a 0.4 MB library-free APK. Trade-offs: 50–70 MB self-reported (more than FLauncher), 3 weeks old, internet + self-updater.
3. **LtvLauncher** — `https://github.com/leanbitlab-org/LtvLauncher/releases/latest/download/LTvLauncher-armeabi-v7a-release.apk`. Most active, closest to FLauncher (categories), inputs + remap built in. Trade-offs: Flutter baseline, extra services; turn off Watch Next.

Also benchmark **just-a-launcher** (`https://github.com/hungmi/just-a-launcher/releases/latest/download/just-a-launcher.apk`) as the floor. CleanYourTV's launcher if willing to build it (only one verified with TCL G03 keys).

## Test protocol (side by side)

All candidates have different package names → install alongside FLauncher.

```bash
adb shell settings get secure enabled_accessibility_services > a11y.bak
C="me.efesser.flauncher/.MainActivity com.tvlauncher/.MainActivity dev.plume/.MainActivity com.leanbitlab.ltvL/.MainActivity tw.hungmi.justalauncher/.MainActivity"
for c in $C; do p=${c%%/*}; echo "== $p"
  adb shell cmd package set-home-activity --user 0 "$c"
  adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1
  for i in 1 2 3 4 5; do                       # cold start
    adb shell am start -a android.settings.SETTINGS >/dev/null; sleep 2
    adb shell am force-stop "$p"; sleep 2
    adb shell am start -W -n "$c" | grep -E 'TotalTime|WaitTime'; done
  sleep 60
  adb shell dumpsys meminfo --package "$p" | grep 'TOTAL PSS'   # includes sub-processes
  adb shell grep MemAvailable /proc/meminfo
  adb shell dumpsys gfxinfo "$p" reset >/dev/null
  for k in 22 22 22 22 21 21 21 21 20 19 20 19; do adb shell input keyevent $k; sleep 0.3; done
  adb shell dumpsys gfxinfo "$p" | grep -E 'Total frames|Janky|percentile'
  sleep 10; adb shell top -b -n 1 | grep -E "$p|surfaceflinger"   # idle CPU
done
```
- Flutter draws outside the standard renderer → `gfxinfo` undercounts for FLauncher/LtvLauncher; use `dumpsys SurfaceFlinger --latency "<layer>"` (layer from `dumpsys SurfaceFlinger --list | grep $p`) (inference).
- CleanYourTV's `tools/bench.py` measures key latency, jank, cold start, return-to-Home, idle CPU and PSS without installing anything on the TV ([README](https://github.com/Gathin23/cleanyourtv)).

**Rollback to FLauncher:**
```bash
adb shell cmd package set-home-activity --user 0 me.efesser.flauncher/.MainActivity
adb shell settings put secure enabled_accessibility_services "$(cat a11y.bak)"   # if "null": settings delete secure enabled_accessibility_services
adb uninstall <candidate>
adb shell input keyevent KEYCODE_HOME
# emergency only: adb shell pm enable com.google.android.apps.tv.launcherx
```
