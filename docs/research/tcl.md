# Research: TCL G03 / BeyondTV4 (R51MT05, LF1V652, AR11) debloat

_Web research compiled on 2026-11-06 for this exact firmware. Source material for [`../PLAN.md`](../PLAN.md)._

## What this TV actually is

Fingerprint `TCL/G03_4K_GB/BeyondTV4:11/RP1A.200622.001/AR11`, software `V8-R51MT05-LF1V652`, security patch 2024-12-05.

- Exact match for one cleanyourtv community list, tested on a 43C645, 55C645, 50C635 and 60C635 ([list](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43c645/debloat.txt), [README](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43c645/README.md)).
- A second list ran on the same build on a 50C641 (EU), 43P739 (Italy) and 65P735 (Kuwait) ([G03 list](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g03-google-tv/debloat.txt)).
- **It is a Google TV 11 build, not classic Android TV.** G03/R51MT05 is the Google TV firmware ([chipsets table](https://faserf.github.io/TCL-Discussion-Telegram/chipsets/)). With launcherx disabled it looks like Android TV, but Google TV behaviour still applies (see "TCL-specific performance tips").
- Same build on older firmware: the 55C725 and 65C655 Pro run LF1V620/AR09 ([55C725](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-55c725/README.md)).
- "BeyondTV6" product units (50C725K, 43P725, the UK AR05 "Smart TV Pro") use the same device name on a different firmware line. Their lists don't transfer directly.
- The model table puts P725/C725 on R51AT01, which conflicts with the above. The TV's About screen shows the real model.

**How much to trust this.** Most evidence comes from the Gathin23/cleanyourtv repo. It was created on 2026-10-17, most contributions are made with AI agents, and units were tested for one to eight days. Its reports are detailed and consistent, but short-term.

## Package verdicts

C645 = the exact-firmware list above; G03 = the second list on the same build.

| Package | Purpose | Verdict | Sources |
|---|---|---|---|
| com.tcl.tv | Live TV app. `TVActivity` is the screen that shows HDMI | **KEEP**. Disabling it means no HDMI can open | [C645](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43c645/debloat.txt), [tv-detox PR#82](https://github.com/Ansub/tv-detox/pull/82), [HN](https://news.ycombinator.com/item?id=45741036) |
| com.tcl.tvinput | Tuner and HDMI/AV input services | **KEEP** ("No Signal"). [chrissy-dev](https://github.com/chrissy-dev/debloat-tlc-android-tv) rates it "Safe", which is wrong | [43P725](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43p725/debloat.txt), [cobanov](https://tv.cobanov.dev/en/) |
| com.tvos | `/system/framework/tvos-framework-res.apk` (framework resources) | **KEEP**. chrissy-dev's table says Critical, yet its script and the [M0Rf30 gist](https://gist.github.com/M0Rf30/95ebdd28df927aaabeafb5e2fa403ca9) remove it | [75P635](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-75p635/debloat.txt), [G07](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g07-google-tv/debloat.txt) |
| com.tcl.system.server | Remote-key plumbing. Has a BootReceiver that re-enables packages at boot (seen on AR05) | **KEEP** (chrissy-dev's script removes it despite its own table) | [C645](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43c645/debloat.txt), [AR05 notes](https://github.com/Gathin23/cleanyourtv/blob/main/docs/devices/tcl-beyondtv4-uk-ar05.md) |
| com.tcl.settings | TCL picture/sound settings and quick panel | **KEEP** | C645, [50C725K](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-50c725k/debloat.txt) |
| com.tcl.tcl_bt_rcu_service | Bluetooth remote service | **KEEP** | C645, [cobanov](https://tv.cobanov.dev/en/) |
| com.tcl.autopair | Bluetooth remote auto-pairing | **KEEP** | C645, cobanov |
| com.tcl.suspension | Quick Panel / the Input key's source panel, not a "suspend" service | **KEEP**. Alone it caused a bootloop and factory reset on a 43S5400A (different platform). Two provisional lists disable it | [issue #2803](https://github.com/Gathin23/cleanyourtv/issues/2803), C645, cobanov; conflicting: [50P735](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-50p735/debloat.txt) |
| com.tcl.providers.config | TCL config provider | **KEEP**. Reported to drop Wi-Fi | [65C725](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-65c725/debloat.txt), cobanov |
| com.tcl.initsetup | First-run setup and channel install | **KEEP** (Wi-Fi role) | 65C725, C645, cobanov |
| com.tcl.factory.view | Factory app | **KEEP**, and never launch it | C645, [G06 US](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g06-us-google-tv/debloat.txt) |
| com.tcl.inputmethod.international | Default keyboard | **KEEP**, unless Gboard is set as default first | C645 |
| com.tcl.partnercustomizer | Promo rows plus TKey (remote shortcut) activities | **CAUTION**. Disabled fine on C645-list units; kept on the 50C641/43P739 for remote keys; 43P725 says don't disable (keycode 83, inputs) | C645, G03, 43P725 |
| com.tcl.dashboard | Quick-settings panel ("TCL Home") opened by the gear key. Running at idle | **CAUTION**. Disabled on C645-list units; you may lose the gear panel | C645, [55C725](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-55c725/debloat.txt) |
| com.tcl.ttvs | "TCSCore": BI, awareness and identifier services; T-Cast; on some builds the OTA updater | **CAUTION**. Off on the 60C635 and the 65P735 (8 days). The shared G03 list keeps it. Cobanov says the update menu stops working | C645, G03, [UAD-ng](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/blob/main/resources/assets/uad_lists.json), cobanov |
| com.tcl.versionUpdateApp | TCL firmware updater | **CAUTION**. Disabling freezes OTA | C645, G03 |
| com.tcl.micmanager | Remote microphone manager | **CAUTION**. Voice remote stops if disabled | C645 group 5, G03 |
| com.tcl.assistant | TCL voice service / Assistant bridge | **CAUTION** (voice) | C645, G03 |
| com.tcl.t_solo | "Listen alone" to Bluetooth headphones | **CAUTION**. Holds TV_INPUT_HARDWARE on AR05/AR09, so HDMI may break; off fine on AR11 (65P735). Check first | G03, [AR05 notes](https://github.com/Gathin23/cleanyourtv/blob/main/docs/devices/tcl-beyondtv4-uk-ar05.md) |
| com.tcl.keyhelp | Remote virtual-key help | **CAUTION**, minor. Off on the 43C645; kept on the 60C635 and 55C645 | C645 README |
| com.tcl.guard | TGuard: memory cleaner, "health", online support, usage tracking. Source of `tguard-kill-SystemApp` | **SAFE** on this firmware (the remote's Guard key 4140 then does nothing) | C645, G03, [UAD-ng](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/blob/main/resources/assets/uad_lists.json) ("Expert"), [55C641K blog](https://blog.waqasmohammad.com/tcl-55c641k-root-debloat/); chrissy-dev says Caution |
| com.tcl.bi | TCL BI analytics | **SAFE** | C645, G03, all lists |
| com.tcl.logkit | Log capture and upload | **SAFE** | C645, G03 |
| com.tcl.waterfall.overseas | "TCL Channel" content feed | **SAFE** on AR11. One report of a logo-hang bootloop on a 55P635 (R51AT01) | C645; conflicting: [0x4f53 gist](https://gist.github.com/0x4f53/27bee9a0069f7bd6a2aa9eb60bb10d1e) |
| com.tcl.smartalexa | Alexa bridge | **SAFE**. Some units re-enable it at boot | C645, G03 |
| com.tcl.overseasappshow | App promos. Running at idle | **SAFE** | C645, 43P725 |
| com.tcl.tv.tclhome_passive | Pushes TCL content at boot. Running at idle | **SAFE** | C645, G03 |
| com.tcl.usercenter | TCL account. Running at idle | **SAFE** | C645 group 4 |
| com.tcl.useragreement | EULA / privacy-consent proxy for ttvs | **SAFE** | C645, G07 |
| com.tcl.messagebox | Pushed TCL messages | **SAFE** | C645, G03 |
| com.tcl.esticker | Retail energy-label sticker | **SAFE** | C645, G03 |
| com.tcl.channelplus | TCL Live FAST channels (has its own TV input) | **SAFE** | C645, G03 |
| com.tcl.browser | TCL browser (~180 MB with data) | **SAFE**, unless the remote's Web key matters | C645, 50C725K |
| com.tcl.android.webview | TCL WebView build; Google WebView is the active provider | **SAFE** (tested off on the 43C645 and 55C725) | C645, 55C725 |
| com.tcl.gallery | USB photos and TCL screensaver | **SAFE** on AR11; check TV_INPUT_HARDWARE first | G03, AR05 notes |
| com.tcl.ui_mediaCenter | USB media player | **SAFE** if USB media isn't used (same check) | C645, G03 |
| com.tcl.ocean.instructions | e-manual | **SAFE** | C645, G03 |
| com.tcl.hearaid | Hearing test | **SAFE** (the shared G03 list keeps it) | C645 group 4 |
| com.tcl.magiconnectfree | T-Cast / MagiConnect phone app | **SAFE** if unused | G03 |
| com.tcl.miracast | Miracast sink. Running at idle | **SAFE** if screen mirroring isn't used (Chromecast is a separate package) | C645 group 3 |
| com.tcl.gamebar | Game-mode overlay | **SAFE** if no console | G03, 55C725 |
| com.tcl.tclchannel.overlay | — | No source found. *Inference:* a resource overlay for TCL Channel; it doesn't run, so nothing to gain | — |

**Other components:**
- **`sitatvservice`:** no source found. *Inference:* TCL's "Sita" TV middleware (the factory menu has a "9-Sita P mode" ([guide](https://faserf.github.io/TCL-Discussion-Telegram/reset-shop))). It's native, so it can't be turned off with pm. Keep it.
- **`omm-kill-cached`:** no source found. *Inference:* TCL's own memory killer inside system_server, so it can't be disabled.
- **`rtkm_scene` / `rtkm_ultraFace`:** nothing public found. *Inference:* Realtek's AI-scene and face-aware picture processing. Try Smart settings → Smart picture → Adaptive content / Adaptive brightness control Off ([StereoIndex](https://www.stereoindex.com/tech/tv/guide-how-to-set-up-a-tcl-tv/)) and any "AI-PQ"/AI picture toggle, then re-check with `top`. Unverified.

## Bricks, bootloops, broken features and recovery

**Bootloops and blank screens:**
- **com.tcl.suspension or com.android.location.fused** (43S5400A, Android TV 11): each one alone caused a bootloop, then recovery, then factory reset ([#2803](https://github.com/Gathin23/cleanyourtv/issues/2803)).
- **55P635:** waterfall.overseas and location.fused caused a hang on the Google TV logo. Disabling launcherx gave a blank screen. A user who removed too much, including the Play Store, had to reflash stock firmware twice ([0x4f53 gist comments](https://gist.github.com/0x4f53/27bee9a0069f7bd6a2aa9eb60bb10d1e)).
- **Grey or black screen after the logos, ADB unreachable** (65P635, C7L): only recovery factory reset or TCL support fixed it ([#962](https://github.com/Gathin23/cleanyourtv/issues/962), [#2432](https://github.com/Gathin23/cleanyourtv/issues/2432)).
- **G08, Android 14:** `com.android.sdksandbox` left it stuck on the logo. A cache wipe failed; factory reset fixed it ([#2557](https://github.com/Gathin23/cleanyourtv/issues/2557)).
- **Rooted 55C641K:** TGuard was linked to a reboot every ~88 s ([blog](https://blog.waqasmohammad.com/tcl-55c641k-root-debloat/)).

**Broken features:**
- **HDMI "No Signal":** disabling a media app that holds TV_INPUT_HARDWARE (AR05) left the port dead until a full restore plus a cold boot ([AR05 notes](https://github.com/Gathin23/cleanyourtv/blob/main/docs/devices/tcl-beyondtv4-uk-ar05.md)).
- **Inputs button gone, Wi-Fi drops, updates stop:** com.tcl.suspension removes the Inputs button; providers.config and initsetup drop Wi-Fi; ttvs makes the update menu fail silently ([cobanov](https://tv.cobanov.dev/en/)).
- **Losing Wi-Fi and ADB through setupwraith:** on several G03 units the saved Wi-Fi belongs to `com.google.android.tungsten.setupwraith`. Disabling it deletes that network, which also cuts off ADB ([G03](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g03-google-tv/debloat.txt), [43P725](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-43p725/debloat.txt)).
- **"Local network or server abnormal" in Software Update:** happens when `com.tcl.xian.StartandroidService` is off, because the updater can't get the device number ([TROUBLESHOOTING](https://github.com/Gathin23/cleanyourtv/blob/main/docs/TROUBLESHOOTING.md)).

**Recovery:**
- **If ADB still answers:** `pm enable <pkg>`, or `cmd package install-existing <pkg>` for something removed with `uninstall --user 0` ([PR#82](https://github.com/Ansub/tv-detox/pull/82)).
- **After a bad boot:** wait a few minutes and keep retrying `adb connect`. Leave USB debugging on and prefer Ethernet ([#962](https://github.com/Gathin23/cleanyourtv/issues/962)).
- **Recovery menu:** repeated failed boots dropped the 43S5400A into recovery on its own (#2803).
- **Forced USB flash:** format a FAT32/MBR stick with the IMG/PKG in the root, unplug the TV, hold its power button while plugging back in for 10–15 s. This wipes data, OTA zips can't fix a bootloop, and the image must be for this platform ([guide](https://faserf.github.io/TCL-Discussion-Telegram/guides)).
- **Before any factory reset:** re-enable setupwraith first ([G03](https://github.com/Gathin23/cleanyourtv/blob/main/examples/tcl-g03-google-tv/debloat.txt)).
- No TCL-specific safe-mode procedure was found.

## TCL-specific performance tips

- **Firmware:** LF1V652/AR11 with the 2024-12-05 patch is the newest EU/ME G03 build in every community report (C645 and G03 lists). [Lowyat](https://forum.lowyat.net/topic/4628777/+1280) lists the older V626 (Oct 2024) for C635/C725. This TV is probably current (medium confidence). To keep receiving updates, keep versionUpdateApp and ttvs.
- **Instant power on / Quick Start:**
  - TCL's own advice is to turn it on for speed ([TCL support](https://support.tcl.com/en_US/us-googletv-troubleshooting/fix-a-slow-or-laggy-tcl-google-tv)).
  - A TCL manual says it trades faster wake for higher standby power (X915 manual, via search snippet only).
  - One [XDA C725 owner](https://xdaforums.com/t/tcl-2021-android-google-tvs-p725-c725-c728-c825-x925.4255729/) fixed post-update problems by unplugging and switching Quick Start off (snippet; XDA blocked fetching).
  - *Inference:* keep it on, but do a real Settings → System → Restart now and then, as TCL suggests.
- **Assistant hotword (check this one):** on a BeyondTV4 UK unit, `com.google.android.katniss` held the microphone path permanently at about 28% of one core. `pm revoke com.google.android.katniss android.permission.RECORD_AUDIO` dropped it to 0.4%, but the remote's mic button stops working ([AR05 notes](https://github.com/Gathin23/cleanyourtv/blob/main/docs/devices/tcl-beyondtv4-uk-ar05.md)). Worth checking with `top`.
- **Packages that come back at boot:** on AR05, use `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore` instead of disabling. On AR11, lists stayed disabled after reboots (C645 README).
- **Effects of launcherx being disabled on G03:**
  - The remote's Netflix, YouTube, Prime and gear buttons stop working, because `TclPhoneWindowManager` sends broadcasts only launcherx answers. A key remapper is needed (C645 README, G03).
  - Setupwraith can claim Home. Before disabling it, check who owns the saved Wi-Fi: `dumpsys wifi | grep -o 'cname=[^ ]*'`.
- **TCL's auto-start block (TclAppBoot):** it refuses to start background services for sideloaded apps (screensavers, VPN, launcher helpers). `appops set <pkg> APP_AUTO_START allow` fixed it ([TROUBLESHOOTING](https://github.com/Gathin23/cleanyourtv/blob/main/docs/TROUBLESHOOTING.md)). A VPN was also killed on stock firmware; TGuard was one of two suspects (G03).
- **Biggest RAM wins on this exact build:** disable together what was tested together: overseasappshow, tclhome_passive, usercenter, guard, bi, logkit, browser, and ttvs/dashboard/miracast if the caveats are acceptable (C645 groups 1–4).
- **Animation scale 0.5×** ([blog](https://blog.waqasmohammad.com/tcl-55c641k-root-debloat/)).
- **Store mode:** set Location to Home and Store auto setting Off ([StereoIndex](https://www.stereoindex.com/tech/tv/guide-how-to-set-up-a-tcl-tv/)).
- **Service menus:** reached by highlighting Contrast and typing a code: 1950 (service/PQ), 9735 (factory), 6425 (maintenance; "Reset Shop" wipes everything), 9705, 6405 (hotel). Avoid changing values; a wrong setting "can … brick your TV" ([guides](https://faserf.github.io/TCL-Discussion-Telegram/guides), [reset-shop](https://faserf.github.io/TCL-Discussion-Telegram/reset-shop)).
- **Data collection:** turn off Google's Settings → Privacy → Usage & diagnostics ([SlashGear](https://www.slashgear.com/1802724/smart-tv-spying-features-turn-off-how-stop-data-collecting)). TCL's own consents sit under its user agreements (low confidence on the exact path). Disabling bi/ttvs/logkit/useragreement covers TCL's telemetry.

## Community debloat lists

- **[Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) (best match):**
  - Lists: [tcl-43c645](https://github.com/Gathin23/cleanyourtv/tree/main/examples/tcl-43c645) (exact build), [tcl-g03-google-tv](https://github.com/Gathin23/cleanyourtv/tree/main/examples/tcl-g03-google-tv), [tcl-55c725](https://github.com/Gathin23/cleanyourtv/tree/main/examples/tcl-55c725), [tcl-beyondtv4-uk](https://github.com/Gathin23/cleanyourtv/tree/main/examples/tcl-beyondtv4-uk).
  - Uses `pm disable-user`, with restore scripts and a guard against core packages.
  - Site page: [cleanyourtv.com 55C725](https://cleanyourtv.com/models/tcl-55c725/).
- **[chrissy-dev/debloat-tlc-android-tv](https://github.com/chrissy-dev/debloat-tlc-android-tv):** UK Freeview TCL. Uses `pm uninstall`, and contradicts itself (see table).
- **Gists:** [0x4f53](https://gist.github.com/0x4f53/27bee9a0069f7bd6a2aa9eb60bb10d1e) (has breakage reports); [M0Rf30](https://gist.github.com/M0Rf30/95ebdd28df927aaabeafb5e2fa403ca9) (removes gms/gsf/vending, dangerous); [llaumgui](https://gist.github.com/llaumgui/e39fdbafc920edacf42fdff6d8ab3a0a) (65C7K).
- **Lower relevance:**
  - [gaesa/TCLDebloater](https://github.com/gaesa/TCLDebloater): China models.
  - [seun-novodev toolkit](https://github.com/seun-novodev/android-tv-debloat-toolkit): generic; most of its TCL names aren't on this firmware.
  - [Ansub/tv-detox](https://github.com/Ansub/tv-detox) and [tv.cobanov.dev](https://tv.cobanov.dev/en/).
- **UAD-ng:** covers only com.tcl.guard and com.tcl.ttvs, both "Expert" and phone-oriented.

## Confidence

- **High:** the KEEP set (every source agrees, including on this exact build).
- **Medium:** the SAFE set (exact build, but a handful of units over days).
- **Low:** the native daemons, the privacy menu paths, and anything marked inference.
