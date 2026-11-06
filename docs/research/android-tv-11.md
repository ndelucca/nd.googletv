# Research: Android TV 11 optimization over ADB (no root)

_Web research compiled on 2026-11-06. **[I]** marks inference with no source. Some AOSP code was read directly from the `android11-release` branch. Source material for [`../PLAN.md`](../PLAN.md)._

Note: launcherx, dreamx and the "tungsten" setup wizard mean this is a Google TV-capable build. [tv-home](https://github.com/mihirgupta0900/tv-home/wiki) was tested on exactly this kind of device (TCL Google TV, Android 11).

**Source keys**
- **[U]** UAD-ng list with category (Recommended / Advanced / Expert / Unsafe): [uad_lists.json](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/blob/main/resources/assets/uad_lists.json), [category definitions](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/wiki/Debloat-lists), [FAQ](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/wiki/FAQ)
- **[G]** TCL debloat script (`pm uninstall --user 0`): https://gist.github.com/0x4f53/27bee9a0069f7bd6a2aa9eb60bb10d1e
- **[H]** tv-home, tested on TCL Google TV Android 11: https://github.com/mihirgupta0900/tv-home/wiki
- **[C]** Chromium-dev thread on disabling mediashell: https://groups.google.com/a/chromium.org/g/chromium-dev/c/2-cYdGUfnlE
- **[AC]** Mic stops working when the Google app is disabled: https://forums.androidcentral.com/threads/tv-microphone-issue-when-disabling-google-app.1062689
- **[DTV]** Voice remote fixed by re-enabling the Android TV Remote app: https://forums.directv.com/conversations/watching-streaming/voice-remote-doesnt-work/662959801385e45099cde0ac
- **[AV]** Aerial Views README: https://github.com/theothernt/AerialViews
- **[SRC:x]** AOSP `https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android11-release/<path>`: AMC = `services/core/java/com/android/server/am/ActivityManagerConstants.java`, CAO = `.../am/CachedAppOptimizer.java`, DCS = `packages/SettingsProvider/.../DeviceConfigService.java`, PMS = `services/core/java/com/android/server/pm/PackageManagerService.java`, PMSC = `.../pm/PackageManagerShellCommand.java`, AMSC = `.../am/ActivityManagerShellCommand.java`, BDOS = `.../pm/BackgroundDexOptService.java`, USM = `core/java/android/app/usage/UsageStatsManager.java`, SMS = `services/core/java/com/android/server/StorageManagerService.java`, Settings = `core/java/android/provider/Settings.java`

## 1. Google / AOSP package verdicts (`pm disable-user --user 0`)

### SAFE

| Package | Purpose | Side effect | Source |
|---|---|---|---|
| android.autoinstalls.config.google.gtvpai | Play Auto-Install config | None after setup | Not in [U]; siblings Recommended [I] |
| com.google.android.onetimeinitializer | First-run initializer | None | [U] Recommended; [G] |
| com.google.android.feedback | Feedback / crash reporting | No "send feedback" | [U] Recommended; [G] |
| com.google.android.play.games | Play Games | Games needing Play Games sign-in break | [U] Recommended; [G] |
| com.google.android.videos | Google TV / Play Movies | Purchases app gone | [U] Recommended; [G] |
| com.google.android.youtube.tvmusic | YouTube Music | App gone | [U] Recommended; [G] |
| com.google.android.sss.authbridge | Phone-assisted setup | Setup via phone | [U] Recommended; [G] |
| com.android.dreams.basic | AOSP Clock/Colors screensavers | Those gone; Aerial Views has its own dream | [U] Advanced; [G]; [AV] |
| com.google.android.apps.tv.dreamx | Ambient mode (Backdrop) | Safe only once `screensaver_components` points at Aerial Views [I] | [U] Recommended; [AV] |
| com.google.android.apps.mediashell | Chromecast built-in | TV no longer a cast target (incl. Jellyfin/Immich/YouTube phone apps) | [U] Expert; [G]; [C] |
| com.google.android.marvin.talkback | Accessibility Suite | No screen reader | [U] Advanced; [G] |
| com.google.android.syncadapters.calendar | Calendar sync | None on a TV | [U] Advanced; [G] |
| com.android.camera2 / com.android.messaging | Camera / SMS | None on a TV | [U]; [G] |
| com.android.printspooler | Printing | No printing | [U] Expert; [G] |
| org.chromium.webview_shell | WebView test browser | None | [U] Recommended |
| com.android.hotspot2.osulogin | Passpoint sign-up | None | [U] Advanced |
| com.android.vpndialogs | VPN consent dialog | VPN apps can't connect | [U] Expert |
| com.android.soundpicker | Ringtone picker | None | [U] Expert |
| com.android.cts.ctsshim / com.android.dynsystem | CTS shim / DSU | None, no gain either | [U] Advanced / Expert |
| com.google.android.partnersetup | Partner customization | "Probably safe" | [U] Advanced; [G] |

### CAUTION

| Package | Purpose | Side effect | Source |
|---|---|---|---|
| com.google.android.apps.nbu.smartconnect.tv | Undocumented | Unknown | Not in [U]; [G] removes it on TCL |
| com.google.android.tv.remote.service | Android TV Remote service | Breaks the Google TV phone-app remote; on some devices the BT voice remote mic | [U] Recommended; [G] keeps; [DTV] |
| com.google.android.katniss | Google app for TV (search, voice) | Mic/search button stops; voice input in other apps probably too [I] | [U] Advanced; [G] keeps; [AC] |
| com.google.android.tv.assistant | Google Assistant | No Assistant; disable with katniss to remove voice completely [I] | Not in [U]; [G] keeps |
| com.google.android.tungsten.setupwraith | TV setup wizard | Fixes Home hijack after disabling the stock launcher [H]; broke volume on a Sony [U]. Check `device_provisioned`/`user_setup_complete` = 1 [I] | [U] Expert; [H] |
| com.google.android.tts | Text-to-speech | TalkBack/TTS break | [U] Advanced |
| com.google.android.youtube.tv | YouTube | User's choice | [U] Recommended |
| com.android.providers.calendar / .contacts / .userdictionary | Content providers | Little gain; contacts broke Bluetooth on one device | [U] Expert; [G] |
| com.android.captiveportallogin | Captive-portal login | Hotel-style Wi-Fi breaks | [U] Advanced |
| com.android.backupconfirm / .sharedstoragebackup / .wallpaperbackup | Backup helpers | Breaks adb backup; use `bmgr` instead | [U] Expert / Advanced |
| com.android.pacprocessor / .proxyhandler / .htmlviewer / .companiondevicemanager / .se / .settings.intelligence | Proxy, HTML viewer, companion, secure element, Settings search | Little gain; Settings search can crash | [U] Expert / Advanced |
| com.google.android.tv.frameworkpackagestubs | Stub activities | App intents may fail [I] | [U] Expert |

### KEEP

| Package | Why | Source |
|---|---|---|
| com.android.shell | ADB itself | [U] Unsafe |
| com.android.systemui / com.android.tv.settings | Core UI | [U] Unsafe |
| com.google.android.gms / .gsf / com.android.vending | Streaming apps depend on them | [U] Expert |
| com.google.android.webview | Login and web screens in apps | [U] Expert |
| com.google.android.ext.services / .permissioncontroller | Mainline; bootloop on 11+ | [U] Unsafe |
| com.android.location.fused | Bootloop reported on a TCL | [U] Expert; [G] comments |
| com.google.android.inputmethod.latin | On-screen keyboard (TCL IME also present) | [U] Advanced |
| com.android.providers.tv | TV input framework / channels DB | [U] Unsafe |
| com.android.bluetooth / .inputdevices / .externalstorage | Remote / input / USB | [U] Expert |
| com.android.certinstaller / .keychain / .localtransport / .networkstack.inprocess / .statementservice / .providers.downloads / .providers.media / .cts.priv.ctsshim | Wi-Fi, TLS, downloads, OTA | [U] Unsafe / Expert |
| com.google.android.apps.tv.launcherx | Leave disabled, never uninstall: fallback home | [U] Expert |

### `disable-user` vs `uninstall --user 0`

- **disable-user** keeps APK + data, reversed with `pm enable <pkg>`. UAD: "Safest". Android 11 lets the shell set whole packages to DISABLED_USER [SRC:PMS].
- **uninstall --user 0** wipes data (unless `-k`), APK stays in /system, reversed with `cmd package install-existing <pkg>`. UAD: "more likely to trigger instability".
- **Factory reset** restores both [U FAQ].
- **OTA:** reports conflict on whether OTAs bring packages back ([1](https://lemmy.ndlug.org/post/379587/1125931), [2](https://community.e.foundation/t/firmware-updates-removing-systemapps-without-root/15669/5)). Re-check after every OTA.
- **Storage:** neither frees /system. For a disabled app that Play updated, `pm uninstall-system-updates <pkg>` reclaims the /data copy [SRC:PMSC]. Never for gms, webview, vending.
- **Use disable-user only.**

## 2. ADB settings tweaks

**a) Animations** — impact high (perceived), risk low.
```
settings put global window_animation_scale 0.5
settings put global transition_animation_scale 0.5
settings put global animator_duration_scale 0.5
```
- `animator_duration_scale 0` makes `ValueAnimator.areAnimatorsEnabled()` return false ([docs](https://developer.android.com/reference/android/animation/ValueAnimator#areAnimatorsEnabled())); apps may skip animations and spinners/focus-zoom can freeze [I].
- Window and transition at 0 is fine; keep the animator at 0.5. Keys persist [Settings].

**b) Cached-process limit** — impact low–med, risk med.
- `settings put global activity_manager_constants max_cached_processes=N` does nothing on Android 11; only DeviceConfig is read [SRC:AMC].
- Works: `device_config put activity_manager max_cached_processes 16` (default 32).
- AOSP says on RAM-tight devices lmkd should kill and the system should "never" rely on this limit [SRC:AMC]. Lowering it = more cold starts.
- Developer options "Background process limit" is in-memory only, lost on reboot [SRC:AMC].
- Android 11 `device_config` has no sync-disable [SRC:DCS]; values survive reboot but Play services may overwrite [I]. Re-verify.

**c) Cached-apps freezer** — impact med if supported, risk med.
```
settings put global cached_apps_freezer enabled   # then reboot
device_config put activity_manager_native_boot use_freezer true
```
- [source.android.com](https://source.android.com/docs/core/perf/cached-apps-freezer). Android 11 enables it only if `/dev/freezer/frozen/freezer.killable` contains 1, otherwise silently off [SRC:CAO]. Likely absent on a Realtek 4.x kernel [I].
- Verify: `dumpsys activity settings | grep -iE 'use_freezer|use_compaction|max_cached'`.

**d) App compaction** — impact low–med, experimental. `device_config put activity_manager use_compaction true` (default false, uses `/proc/<pid>/reclaim`) [SRC:CAO]. Only helps with zram [I].

**e) zram** — if `getprop persist.sys.zram_enabled` is non-empty, `settings put global zram_enabled 1` + reboot toggles it [SRC:SMS]. (This TV already has 1 GB zram active.)

**f) Scanning** — impact low, risk low.
```
settings put global wifi_scan_always_enabled 0
settings put global ble_scan_always_enabled 0
settings put global wifi_networks_available_notification_on 0
```

**g) Package verification** — `settings put global verifier_verify_adb_installs 0` (ADB installs only). `package_verifier_enable` isn't read by the Android 11 framework [SRC:PMS]; use the Play Protect toggle in Play Store.

**h) Usage & diagnostics** — UI only: Settings > Device Preferences > Usage & Diagnostics ([TCL](https://support.tcl.com/how-to-change-your-android-os-tv-settings-645)).

**i) Backup** — `bmgr enable false`. Auto Backup starts app processes in the background ([docs](https://developer.android.com/identity/data/testingbackup)). Cost: no cloud backup.

**j) Avoid** — `always_finish_activities 1` (every app switch recreates screens) [I]; leave `app_standby_enabled` default.

## 3. ART / dexopt

- **Check first:** `dumpsys package dexopt | grep -A3 '\[<pkg>\]'` (status=verify|quicken|speed-profile|speed).
- **speed-profile** (`cmd package compile -m speed-profile -f <pkg>`): cheap, hot code only. Google's choice for low-RAM ATV "to reduce RAM and storage" ([atv_lowram_defaults.mk](https://android.googlesource.com/device/google/atv/+/refs/heads/master/products/atv_lowram_defaults.mk)).
- **speed** (`cmd package compile -m speed -f <pkg>`): compiles everything, no JIT ([docs](https://source.android.com/docs/core/runtime/jit-compiler)). Bigger oat files; heavy dex2oat CPU/RAM while compiling — with ~380 MB free, compile one app at a time [I]. Lost on every app update / OTA [I]. Impact med for Kotlin/Java apps.
- **Background job:** normally runs idle + charging ([docs](https://source.android.com/docs/core/runtime/configure)); a deep-suspending TV may rarely get it [I] → run `cmd package bg-dexopt-job` after updates. Android 11 downgrades unused apps when storage is low [SRC:BDOS].
- **Targets:** Jellyfin, Spotify, Disney+, Max, Paramount+, Crunchyroll, Immich, `com.android.tv.settings`; `com.android.systemui` if not already `speed`.
- **FLauncher gains almost nothing:** Flutter, Dart already AOT-compiled ([XDA](https://www.xda-developers.com/flauncher-android-tv/)) [I].
- **Avoid** gms, vending, and `-a`. **Revert:** `cmd package compile --reset <pkg>`. **Measure:** `df -h /data`, `am start -W` before/after.

## 4. Other levers

- **Background restriction** — impact med. `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore` ([docs](https://developer.android.com/topic/performance/power/test-power)): no FGS from background, no alarms, no jobs ([docs](https://developer.android.com/topic/performance/background-optimization)). Apply to Disney+, Max, Paramount+, Crunchyroll, YouTube, YouTube Music. **Not** to Spotify (background playback), Aerial Views, FLauncher, Jellyfin if playing audio in background [I].
- **Standby buckets** — low value: bucket limits don't apply while charging ([docs](https://developer.android.com/topic/performance/power/power-details)); a TV is "always plugged" (healthd); restricted bucket "not enabled in R" [SRC:USM].
- **BOOT_COMPLETED** — the shell can't disable components on Android 11 ("Shell cannot change component state") [SRC:PMS]; only whole packages. Background restriction blocks BOOT_COMPLETED only on 13+. TCL's `APP_AUTO_START` appop is the OEM autostart gate [AV].
- **kill / trim** — `am kill-all` only to normalize benchmarks [SRC:AMSC]; `pm trim-caches 999G` frees storage only.
- **Screensaver** — 1080p SDR clips over 4K HDR [I]; or `settings put secure screensaver_enabled 0`.
- **Play Store auto-update** — UI only ([docs](https://support.google.com/androidtv/answer/6121463)). Update manually, then `bg-dexopt-job` [I].
- **Logging** — `logcat -G 256K` until reboot; `setprop persist.log.tag W` persists and drops V/D/I logs system-wide (`system/core/liblog/logger_write.cpp`), but hides ActivityManager "Displayed" lines → apply only after benchmarking. Revert: `setprop persist.log.tag ""`.
- **`wm size` / `wm density`** — not recommended: weak, conflicting evidence ([1](https://forums.dolphin-emu.org/Thread-here-s-a-why-to-boost-fps-on-a-nexus-9-resolution-change?pid=391461), [2](https://forum.pine64.org/printthread.php?tid=7132), [3](https://support.targetr.net/hc/en-gb/articles/360005182778)); blurry UI, layout breakage [I].

## 5. Measurement

```sh
grep -E 'MemTotal|MemAvailable|Swap' /proc/meminfo; cat /proc/pressure/memory
dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM|Lost RAM|ZRAM'
dumpsys procstats --hours 24
dumpsys activity lru; dumpsys activity exit-info <pkg>
logcat -b events -d | grep -cE 'am_kill|killinfo'
CMP=$(cmd package resolve-activity --brief -c android.intent.category.LEANBACK_LAUNCHER <pkg> | tail -1)
am start -S -W -n "$CMP"            # cold: TotalTime/WaitTime; omit -S for warm
dumpsys gfxinfo <pkg> reset
input keyevent KEYCODE_DPAD_RIGHT ...  # repeatable navigation
dumpsys gfxinfo <pkg> | grep -E 'Total frames|Janky|percentile|Missed Vsync|Slow UI'
dumpsys package dexopt; df -h /data
# boot: reboot, poll sys.boot_completed, then: cat /proc/uptime; logcat -b events -d | grep -E 'boot_progress|wm_boot_animation_done'
```
- **Flutter caveat:** gfxinfo doesn't see Flutter frames (FLauncher). Use `dumpsys SurfaceFlinger --timestats -enable -clear` then `--timestats -dump` [I].
- **Boot chart** without root: `touch /data/bootchart/enabled` + reboot ([docs](https://source.android.com/docs/core/perf/boot-times)).
- **Method:** ≥5 runs, median; settle 3 min after boot; one variable at a time [I].

## 6. Idempotency and safety

- **Check before changing:** `pm list packages -d`; `-u` vs installed; `settings get` returns `null` when unset → restore with `settings delete`, not `put`; `device_config get`, `cmd appops get`, dexopt status.
- **Snapshot per build fingerprint** (settings lists, `device_config list activity_manager[_native_boot]`, disabled/removed packages, appops, dexopt, HOME resolution) — `scripts/collect.sh` covers this.
- **Restore:** `pm enable` / `cmd package install-existing`; `settings put|delete`; `device_config delete`; `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND allow`; `cmd package compile --reset`; `wm size reset`. Fallback home: `pm enable com.google.android.apps.tv.launcherx`, then `cmd package set-home-activity me.efesser.flauncher/.MainActivity`.
- **Never-disable list in the script:** shell, systemui, tv.settings, gms, gsf, vending, webview, permissioncontroller, ext.services, inputmethod.latin, bluetooth, providers.tv, location.fused.
- **After an OTA:** detect by `ro.build.fingerprint` change → re-snapshot, diff disabled/removed lists, re-apply. Expect `speed` compilation reset and possibly packages re-enabled. Re-check `device_config` and network ADB [I].
