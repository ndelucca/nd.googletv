# Research: launcher, screensaver and apps

_Web research compiled on 2026-11-06. "(inference)" marks reasoning rather than a source. "Checked" means the URL was tested with curl that day. Source material for [`../PLAN.md`](../PLAN.md)._

## 1. FLauncher

**The original is dead.** Upstream: [gitlab.com/flauncher/flauncher](https://gitlab.com/flauncher/flauncher) (GPLv3, Flutter).
- Last commit 2023-03-03. Last release **0.18.0 on 2023-04-21**, one APK for all ABIs ([GitLab API](https://gitlab.com/api/v4/projects/26632151/releases)).
- Download: `https://gitlab.com/flauncher/flauncher/-/releases/0.18.0/downloads/flauncher-0.18.0.apk` (checked).
- `https://github.com/flauncher/flauncher/releases/latest/download/flauncher.apk` (used in the old `TCL_TV_Setup_Guide.md`, since removed) is **not real**: 404, and `github.com/flauncher/flauncher` itself is 404 (checked).

**Forks:**

| Fork | Status | Package / home activity | Latest armeabi-v7a |
|---|---|---|---|
| [osrosal/flauncher](https://github.com/osrosal/flauncher) (formerly CocoCR300) | v2025.07.001 (2025-07-27), dormant since | Same `me.efesser.flauncher/.MainActivity` | `https://github.com/osrosal/flauncher/releases/latest/download/flauncher-armeabi-v7a-release.apk` (checked) |
| [leanbitlab-org/LtvLauncher](https://github.com/leanbitlab-org/LtvLauncher) (fork of osrosal) | **Very active**: v2026.10.27, last push 2026-11-05 | `com.leanbitlab.ltvL/.MainActivity` | `https://github.com/leanbitlab-org/LtvLauncher/releases/latest/download/LTvLauncher-armeabi-v7a-release.apk` (checked) |
| [cyanonoob/flauncher](https://github.com/cyanonoob/flauncher) | "Private use only, no support" | — | — |

- **osrosal:** Flutter 3.7.5 → 3.24.5; Firebase Analytics/Crashlytics and Unsplash removed ([CHANGELOG](https://raw.githubusercontent.com/osrosal/flauncher/master/CHANGELOG.md)). Same package but a different signing key: the original must be uninstalled first, which **erases settings and categories** ([#13](https://github.com/osrosal/flauncher/issues/13), on a TCL TV). Maintainer declined to rename ([#12](https://github.com/osrosal/flauncher/issues/12)).
- **LtvLauncher:** different package, installs alongside; switch HOME to it, nothing carries over (inference). Adds a Watch Next row, Wi-Fi widget and its own screensaver service — probably more RAM (inference).
- **Memory:** no credible measurements found. Listicles claim ~50–96 MB, unsourced. On this TV FLauncher 0.18.0 measured **~38–39 MB PSS** (see `inventory/`).

**Recommendation:** staying on 0.18.0 costs nothing except updates. If switching: osrosal (same package, wipe, dormant) or LtvLauncher (maintained, separate package). Measure with `dumpsys meminfo <pkg>` before committing.

## 2. Lightweight launchers and disabling the stock launcher

No rigorous benchmarks for 2 GB devices exist; evidence is community opinion.

| Launcher | Package | Evidence |
|---|---|---|
| FLauncher / forks | above | Usually called the lightweight choice. A Lemmy user went back to it because Projectivy "uses a lot more resources (cache + RAM)" ([Lemmy](https://lemmy.manganiello.tech/post/529037/674880), snippet only) |
| Projectivy | `com.spocky.projengmenu` | Dev acknowledged memory leaks in 4.63; trims cache under memory pressure (snippet only). Most features |
| ATV Launcher | Pro: `ca.dstudio.atvlauncher.pro` | Listicle-level claims only |
| Wolf Launcher | — | ATV Launcher fork, "No Longer Being Updated" ([TROYPOINT](https://troypoint.com/wolf-launcher/)) |
| TV Launcher (F-Droid) | `com.tvlauncher/.MainActivity` | Author self-reports **~30–40 MB PSS** (45–50 MB with optional accessibility Home override). v1.6.2, 2026-10-22 ([F-Droid](https://f-droid.org/en/packages/com.tvlauncher/), [repo](https://github.com/wiiguy/lightweight_androidtv_launcher)) |

- **"No launcher":** HOME falls back to setupwraith or Settings — not usable; a minimal launcher is the floor (inference).
- **Which package:** classic Android TV uses `com.google.android.tvlauncher`; Google TV uses `com.google.android.apps.tv.launcherx`. Also disable `com.google.android.tungsten.setupwraith`, otherwise it can take HOME back ([osrosal README](https://github.com/osrosal/flauncher), [cobanov](https://tv.cobanov.dev/en/)). On this TV both are already disabled.

**Reported breakages after disabling launcherx/setupwraith:**
- **Cast** stopped after a reboot on a Chromecast with Google TV; came back when re-enabled ([#48](https://github.com/osrosal/flauncher/issues/48)).
- **YouTube remote key** stopped on Chromecast with Google TV (README).
- **Inputs on TCL Google TV:** one owner could only switch inputs from the stock launcher ([lemm.ee](https://lemm.ee/post/41420743), snippet only).
- **Home button on TCL** reverted to stock over time (r/AndroidTV mirror, snippet only).

**`com.google.android.tvrecommendations`:** not installed on this TV. (Only an anecdotal claim that disabling removes the Play Next row.)

**Safe order of operations** ([mustafa.net](https://mustafa.net/2026/11/01/replace-google-tv-launcher-without-root/)):
1. `cmd package set-home-activity --user 0 me.efesser.flauncher/.MainActivity`
2. Verify: `cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME`
3. Only then `pm disable-user --user 0` the stock packages.
4. Reboot; test the physical Home button, Inputs and Cast.

## 3. Aerial Views screensaver

- **Component:** `com.neilturner.aerialviews/.ui.screensaver.DreamActivity` ([README](https://github.com/theothernt/AerialViews)).
- **Latest:** 1.8.5 (2026-10-02), installed here. Asset name includes the version: `https://github.com/theothernt/AerialViews/releases/download/1.8.5/aerial-views-1.8.5.apk` (checked).
- **1.8.4 added "option to reduce playback buffers and RAM usage"** ([release](https://github.com/theothernt/AerialViews/releases/tag/1.8.4)); 1.8.5 adds recovery from decoder errors.
- **Quality options** ([arrays.xml](https://raw.githubusercontent.com/theothernt/AerialViews/master/app/src/main/res/values/arrays.xml)): Apple 1080p H.264 / 1080p HEVC / 1080p HEVC DV / 4K HEVC / 4K HEVC DV; Amazon 1080p / 4K HEVC; Community 1080p H.264 / 1080p HEVC / 4K HEVC.
- **For this SoC:** 1080p SDR (no Dolby Vision) with reduce-buffers on; HEVC is hardware-decoded, H.264 as fallback if it stutters (inference).
- **TCL-specific, important:** needs the Auto Launch permission or the screensaver may not start: `appops set com.neilturner.aerialviews APP_AUTO_START allow` (README). **Confirmed on this TV:** 12 × `Unable to bind dream service … bindService failed` in logcat and `APP_AUTO_START: ignore`.
- **Tested on this TV (2026-11-06):**
  - The gate (`TclAppBoot`, policy in `/vendor/etc/AppBootPolicy.conf`, read-only) only blocks *starting* the app's process. If Aerial Views is already running, the dream binds even with `ignore`. To test it realistically, `am force-stop` the app first.
  - **The appop is lost on `adb reboot`.** Android writes app-op changes to `/data/system/appops.xml` up to 30 min later, and `adb reboot` skips the framework shutdown. Fix: `cmd appops write-settings` right after `appops set`, and reboot with `svc power reboot` (clean shutdown). Verified: after both, `allow` survives the reboot and the dream starts from a stopped process.

```
settings put secure screensaver_components com.neilturner.aerialviews/.ui.screensaver.DreamActivity
settings put secure screensaver_enabled 1
settings put system screen_off_timeout 600000   # screensaver start delay
settings put secure sleep_timeout -1            # never sleep (or ms)
```
(From the README and [Buzzblender's docs](https://buzzblender.gitbook.io/buzzblender-docs/docs-ko/adb), which also list `screensaver_activate_on_sleep 1`.)

## 4. Apps

**SmartTube (YouTube alternative):**
- Build environment compromised in Nov 2025: versions **30.43–30.47** affected; new signing key from **30.55** ([BleepingComputer](https://bleepingcomputer.com/news/security/smarttube-youtube-app-for-android-tv-breached-to-push-malicious-update)).
- Packages: `org.smarttube.stable`, `org.smarttube.beta`, `app.smarttube.fdroid` ([build.gradle](https://raw.githubusercontent.com/yuliskov/SmartTube/master/smarttubetv/build.gradle)). Old ones to remove if present: `com.teamsmart.videomanager.tv`, `com.liskovsoft.smarttubetv.beta`.
- Maintained: stable 32.68s (2026-10-20), beta 32.70 (2026-11-05).
- Downloads: `https://github.com/yuliskov/SmartTube/releases/download/32.68s/SmartTube_stable_32.68_armeabi-v7a.apk` (checked); F-Droid `app.smarttube.fdroid` 32.68, versionCode 2458.
- Codecs: README says AVC is "only for old or slow hardware", VP9 at high resolutions "might be slow on cheap TV boxes", AV1 needs hardware support. Try VP9 1080p first, then AVC (inference).
- No benchmark vs stock `com.google.android.youtube.tv` found. Google's Cobalt runtime (used by YouTube on TVs) is built for a small memory footprint ([Cobalt](https://developers.google.com/youtube/cobalt/docs/overview)). On this TV stock YouTube measured **~250 MB PSS** while playing.

**Spotify (`com.spotify.tv.android`):** users report it growing to 1–2 GB of storage and freezing on older TVs until force-stopped ([1](https://community.spotify.com/t5/Android/Android-TV-App-Huge-Data-Demand-Bringing-Storage-to-Its-Limit/td-p/7540243), [2](https://community.spotify.com/t5/Android/Android-TV-Spotify-Application-freezing-issue/td-p/4820787)). On this TV: ~793 MB data + 138 MB cache. Clear cache periodically (inference).

**Jellyfin (`org.jellyfin.androidtv`):**
- Stable **v0.19.10** (2026-08-16), installed here. Beta v0.20.0-beta.4 adds audio passthrough auto-detection.
- **libVLC removed in v0.17.0** ([PR #3639](https://github.com/jellyfin/jellyfin-androidtv/pull/3639)); ExoPlayer (or an external player) only.
- ExoPlayer doesn't CPU-decode: MPEG-2 live TV needs server transcoding ([forum](https://forum.jellyfin.org/printthread.php?tid=7841)).
- Set max bitrate manually; "Auto" can force transcoding ([forum](https://forum.jellyfin.org/t-solved-direct-play-issues-for-fire-tv-stick-4k-max)).

**Disney+, Max, Crunchyroll:** no credible reports of heavy background services. Disney+ has a profile toggle to turn off background video/autoplay ([Android Central](https://www.androidcentral.com/how-disable-autoplay-and-background-video-disney-plus)).

## 5. Scripted, idempotent APK installs

(inference, from [aapt2](https://developer.android.com/tools/aapt2), [adb](https://developer.android.com/tools/adb) and [apksigner](https://developer.android.com/tools/apksigner) docs)

```
pkg=$(aapt2 dump packagename f.apk)
new=$(aapt2 dump badging f.apk | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
cur=$(adb shell pm list packages --show-versioncode "$pkg" | sed -n "s/^package:$pkg versionCode://p")
[ -z "$cur" ] || [ "$new" -gt "$cur" ] && adb install -r f.apk
```
- `--show-versioncode` is in on-device `pm` help, not in Google's docs (works on this TV).
- **Check the signer before installing:** `apksigner verify --print-certs` on the new APK and on the installed copy (`pm path`). Different SHA-256 → install fails (the FLauncher-fork / old-SmartTube case).
- **Latest version sources:** GitHub API `releases/latest`; the `releases/latest/download/<asset>` alias (always 302 — use `curl -fL`); F-Droid API `https://f-droid.org/api/v1/packages/<pkg>` → `suggestedVersionCode`, file `https://f-droid.org/repo/<pkg>_<vc>.apk` (checked); [apkeep](https://github.com/EFForg/apkeep) `-d f-droid` (verifies signatures).
- **Recommendation:** pin explicit armeabi-v7a URLs and gate every install on versionCode + signer match.
