# Spring cleaning phase 5: platform readiness (platform-porter, 2026-10-16)

The implementation half of phase 5, on branch `spring-cleaning`, following the audit
([phase5-platform-audit.md](phase5-platform-audit.md)) and the owner's decisions ([decisions.md](decisions.md): D1 keep the
cutscenes, D4 a fixed default gamepad layout now, D5 interpolation (done in phase 4), D6 save the Descent run). No economy,
balance, save-epoch or cutscene change; desktop and web look and play the same except where noted ("Behavior changes").

Commits: `1c80a9b` seam + back + lifecycle + pad layer + platform UI, `9aa3bd8` pad A / B in menus + gamepad suite + nav
fuzz, `1d36fd8` safe areas, `8c44e2a` Descent resume (D6), `653ce9e` Linux preset, `853e66d` make_promo.sh, `726bee3`
Steam seam signal, `6e87d45` tutorial cues / Cmd+V, `44a379e` layout checks + captures.

## The seam

- **`scripts/platform.gd`** (`class_name Platform`, statics only): `kind()` ("desktop", "web", "ios", "android", "steam"),
  `is_web()` (also the `--web-ui` preview), `is_mobile_native()`, `is_ios()`, `is_android()`, `is_desktop()`, `is_steam()`
  (false until a Steam preset sets the `steam` feature), `has_js()` (real browser APIs, never overridden: every
  `JavaScriptBridge` call is guarded by it), `has_touch()`, `can_quit()`, `has_window_fullscreen()`,
  `remembers_fullscreen()`, `pauses_on_focus_loss()`, `safe_rect()` / `safe_rect_for()` / `safe_insets()`, the input
  device (`last_input`, `using_pad()`, `prompt_for(action, key_text)`), the pad table (`PAD_BUTTONS`, `apply_pad_layout()`,
  `snap8()`). **Test overrides:** `Platform.override = "ios"` (etc.), `safe_area_override`, `window_override`,
  `reset_overrides()`; in a debug build `-- --platform=ios` previews a platform's UI on the desktop (release builds
  ignore it like every debug flag).
- **`scripts/platform_events.gd`** (autoload `PlatformEvents`, process always): Android back, focus loss / background
  (+ the web page's `visibilitychange`), the left stick driver, the last-input tracker (`input_kind_changed`), and the
  Steam / store seam signal `progress_event(id, value)`.
- Every scattered platform check now goes through it: `OS.has_feature("web")` remains only in `platform.gd` (it was in
  `progress.gd` x2, `hub.gd`, `controls.gd` x3, `key_controls.gd`, `sfx.gd`, `autoplay.gd`, `dev_log.gd`);
  `DisplayServer.is_touchscreen_available` for the touch controls is `Platform.has_touch()`.

## Status of every finding

| # | Finding | Status | What was done / evidence |
|---|---|---|---|
| B1 | Android back quits the app | **fixed** | `application/config/quit_on_go_back=false`; `NOTIFICATION_WM_GO_BACK_REQUEST` -> one `menu` tap (pressed, released 2 physics frames later). Menus back out, a level pauses (back again resumes), the hub goes to the title, the title ignores it. iOS has no back button: every screen and overlay has a BACK / CLOSE / CANCEL / DONE / RESUME button (now incl. the hat wheel). `test_platform`: level, level select -> hub, hub -> title, title unchanged; nav fuzz `android_back` op |
| B2 / D4 | No gamepad | **fixed** (glyphs, remapping: port-time) | fixed layer from one table (below), re-added after every key change (`apply_bindings` no longer leaves pads without events); Godot 4.7's `ui_accept` / `ui_cancel` have no pad buttons, so A / B are added there; left stick snapped to 8 directions; LB / RB switch tabs; a pad press cancels a key-rebind wait; touch controls hide on pad input; prompts name pad buttons after pad input. `test_gamepad` (60 checks, real `InputEventJoypadButton` / `InputEventJoypadMotion`), nav fuzz pad ops |
| B3 | No Linux / mobile presets | **Linux fixed**; mobile **port-time** | `export_presets.cfg` preset 3 "Linux" (x86_64, pck embedded, the Windows filters + `icon.ico`) -> `build/linux/SlimeTime.x86_64`. Exports verified: Linux 78.7 MB, Windows 114.6 MB, macOS 64.4 MB zip, Web (index.*). Mobile preset settings below (not in the repo: they need SDKs, a keystore and a Team ID) |
| B4 / D5 | High-refresh judder | **fixed in phase 4** | untouched here (interpolation only above 60 fps, `Transition.follow_frame_rate`) |
| H1 | No lifecycle handling | **fixed** | `NOTIFICATION_APPLICATION_FOCUS_OUT` / `PAUSED` (+ web `visibilitychange`): a running level opens its pause menu (`game.pause_for_background`), so the run clock and the RACE countdown stop; every held action, the touch controls and the stick are let go; a failed save is retried (`Progress.flush_save`; every change is otherwise saved at once). Coming back releases inputs again and leaves the pause menu up. Not in headless runs or movie captures (`Platform.pauses_on_focus_loss`), not under `--autoplay`. `test_platform` (clock and RACE frozen 60-90 frames, inputs released, failed save retried), nav fuzz `background` op (BG-PAUSE / BG-CLOCK / BG-HELD) |
| H2 | QUIT on native mobile | **fixed** | trapdoor only where `Platform.can_quit()` (desktop, Steam); 8 stations elsewhere. `test_platform` per platform |
| H3 | Desktop-only settings on mobile | **fixed** | FULLSCREEN disabled (not hidden) on phones, F11 does nothing there; CONTROLS stays (a Bluetooth keyboard works) but its note follows the device: desktop unchanged, web "P PAUSES", phones without F11, pad "PAD: A LEAP - X USE - START PAUSE - B BACK". `test_platform` |
| H4 | Hat wheel spins from touch taps | **fixed** | JUMP no longer spins (only the interact key / SPIN button); the touch controls stand down under the overlay (`menu_open`, not drawn); a touch BACK in the header (the SHOP tab's mirror, 214,9 44x13); the hint drops "TAP JUMP TO SPIN". `test_touch` (taps all over the right half: tickets 200 -> 200; BACK closes), `test_ui_layout`; captures `phase5/hat_wheel_touch_before.png` / `_after.png` |
| H5 | One landscape side on iOS | **fixed** | `display/window/handheld/orientation=4` (sensor landscape). No desktop / web effect |
| H6 | Mobile renderer unset | **fixed** | `rendering/renderer/rendering_method.mobile="gl_compatibility"` (the web's renderer) |
| H7 / D6 | Descent lost on app kill | **fixed** | see "Descent resume" below. `test_descent_resume` (52 checks) |
| M1 | Safe areas | **fixed** (device check: port-time) | `Platform.safe_rect` maps `DisplayServer.get_display_safe_area()` into the view (integer scale, centered). Touch-grown hit areas stop at the safe area (iPhone: bottom row's margin ends at y 177.75, was 181), the floating joystick never opens in the home-indicator strip, HUD pods / hub ticket pod / touch pause move in only where the safe area cuts the sides or top (`UIKit.hud_edge`). Desktop and web: the whole view, letterbox touches still count, pods at 3. iOS `hide_home_indicator` and `suppress_ui_gesture` are on (Godot defaults, checked). `test_platform`: iPhone 15 Pro (2556x1179, safe 177,0 2202x1116) and a 16:9 phone with 4 px rounded-corner insets |
| M2 | Keyboard-only prompts | **fixed** | ability hint: keys / "PAD LB Y RB" / "TAP THEIR BUTTONS"; hub hints and the hat wheel name X on a pad; coin board "B TO CLOSE" (B now closes it); tutorial cues draw the d-pad and "A" on a pad; web paste hint says CMD+V in Mac / iOS browsers |
| M3 | Color wheel needs a pointer | touch **fixed**; pad **port-time** | the wheel is a registered touch target (a tile's grown margin never takes a finger on it). D-pad hue / saturation steps need it to take focus, which changes keyboard navigation on the skins screen: left for the Deck pass (the Deck's trackpad works meanwhile) |
| M4 | Fullscreen not remembered | **fixed** | desktop only: `[settings] fullscreen` (optional, written only when on; old saves read as windowed; kept by RESET PROGRESS) set by F11 / FULLSCREEN, applied on a normal player launch only (never in tools / tests / captures) |
| M5 | Rainbow recolor cost on phones | **remaining** (perf-profiler) | not touched; re-measure on a low-end Android device at port time |
| M6 | Save code entry on Steam Deck | **port-time** | a pad player can COPY and PASTE (and LOAD) with A; typing needs `ShowFloatingGamepadTextInput` (Steamworks) when `code_in` gains focus, behind `Platform.is_steam()`. On phones the OS keyboard opens on the box |
| M7 | Android backup | **port-time** | `user_data_backup/allow=true` in the Android preset (below) |
| M8 | Bundle id | **port-time** (owner) | pick a reverse-DNS id the owner controls before the first store upload; same id for iOS, Android, macOS |
| M9 | Icons / store art | **port-time** | `icon.png` is 64x64: needs a nearest-neighbor 16x upscale to 1024 (iOS marketing, Steam), Android adaptive 432x432 foreground / background / monochrome, Steam capsules. Never filtered |
| L1-L10 | | unchanged / **L10 fixed** | L10 (scattered checks) folded into the seam; L5 / L6 still hold (the run clock is physics delta; saves are immediate) |

### Behavior changes (desktop / web)
- A level pauses itself when the window loses focus (alt-tab, Steam overlay, another monitor); RESUME continues.
- The hat wheel's SPIN hint no longer offers JUMP on touch; touch hides the joystick / JUMP drawings under hub panels.
- Gamepads now work everywhere (before: only the D-pad in menus, nothing in levels or the hub).
- The fullscreen choice sticks on desktop.

## Gamepad layout (D4, fixed; glyphs and remapping later)

| Control | In a level / the hub | In menus |
|---|---|---|
| Left stick | move (snapped to 8 directions: lanes and straight leaps work as on keys) | move the focus |
| D-pad | move | move the focus |
| A (bottom) | leap (hold to charge) | press |
| B (right) | - (closes the pause menu) | back / close |
| X (left) | use the hub station / spin the hat wheel | - |
| Y (top) | ability 2 SLIME SPLAT | - |
| LB / RB | ability 1 SLIME RIFLE / ability 3 SLIMAKAZE | previous / next tab (cauldron, wardrobe pages, hat wheel) |
| START | pause / back (= Esc) | back (= Esc) |
| VIEW (Back / Select) | restart (= R) | - |

Abilities work only in randomizer mazes and Descent, as on keys. Cutscenes: any pad button advances a shot, START skips
(already the case for any `InputEventJoypadButton`). Text entry with a pad: the SAVE CODE panel's COPY / PASTE / LOAD
buttons; the CONTROLS page remaps keys only (a pad press cancels the wait).

## Descent resume (D6)

- **Saved points:** the run is saved as an optional `[descent_run]` section (`format = 1`) at every floor start (incl.
  floor 1) and right after every cleared floor (the boon card). Nothing is saved during a floor.
- **Relaunch:** the hub asks on arrival (and the portal's DESCENT asks instead of starting a run): DESCENT RUN SAVED,
  FLOOR n (CLEARED) - POT p, RESUME (focused) / QUIT RUN; Esc / B / back closes the prompt and keeps the run.
- **RESUME** plays that floor's start (same seed -> same maze, the saved meter, boons, backup bladders, pot, run time,
  SECOND WIND state, paid slot and milestone record) or, for a cleared floor, its boon card with the same three offers.
- **No reroll:** floor mazes and boon offers come from the run seed, the floor and the boons held, so a relaunch can't
  change them. The paid daily slot is taken once (it is part of the saved run). Milestone bonuses are paid once ever
  (saved mask), and the "floor bonus" notice is not repeated.
- **No double bank:** banking (CASH OUT, dry-up, QUIT TO HUB, QUIT RUN) removes the saved run in the same save; save codes
  never carry it (`_write(for_code)`), and a `[descent_run]` inside a pasted code is ignored, so a run can't be copied to
  a second device. Starting a new run while one is saved banks the saved one first (as a quit).
- **QUIT RUN** = quitting from the pause menu today: half the pot mid-floor, the whole pot on the boon card.
- **Validation:** read through the save allow-list like every save; another format, a seed or floor out of range, a
  cleared count that isn't floor or floor-1, an unknown boon, RUBBER BODY with GLASS SLIME, more boons than floors
  cleared, or a non-dictionary of boons drops the run; pot, meter, time, slot and bladders are clamped. Older saves have no
  section (no run). No save version / epoch change: older builds ignore the section.
- **Known trade-off (owner rule):** killing the app mid-floor returns to that floor's start, so a player who force-quits
  just before drying up gets that floor again (same maze, same starting meter) instead of banking half. Bounding it (e.g.
  one resume per floor, then QUIT RUN only) is a one-line rule in `Progress.resume_descent` if the owner wants it.

## Android preset (port-time; not in the repo)

Editor settings first: `export/android/java_sdk_path` (JDK 17), `export/android/android_sdk_path`, a debug keystore
(Editor > Editor Settings > Export > Android). Install the Android build template (Project > Install Android Build
Template; `android_source.zip` is already installed with the 4.7.2 templates). Then a preset:

```
[preset.N]
name="Android"
platform="Android"
exclude_filter="tests/*, tools/*, docs/*, _archive/*, .claude/*, build/*, icon.ico"
export_path="build/android/SlimeTime.aab"
[preset.N.options]
gradle_build/use_gradle_build=true
gradle_build/export_format=1            ; AAB for Play (0 = APK for test installs)
gradle_build/min_sdk=""                  ; template default (24)
gradle_build/target_sdk=""               ; template default (Play's current requirement)
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
keystore/release="<path outside the repo>"   ; or GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD env vars
keystore/release_user="<alias>"
keystore/release_password="<from env>"
version/code=1
version/name="1.0.0"
package/unique_name="<owner's reverse-DNS id>"   ; M8, same as iOS / macOS
package/name="Slime Time"
package/signed=true
package/app_category=2                   ; Game
package/retain_data_on_uninstall=false
launcher_icons/main_192x192="res://<icon 192>"
launcher_icons/adaptive_foreground_432x432="res://<fg 432>"
launcher_icons/adaptive_background_432x432="res://<bg 432>"
launcher_icons/adaptive_monochrome_432x432="res://<mono 432>"
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=true             ; M7: progress follows the player to a new phone
permissions/*=false                      ; the game needs none (no internet, no storage)
```
Project settings already set for it: `quit_on_go_back=false`, sensor landscape, `rendering_method.mobile=gl_compatibility`,
`import_etc2_astc=true`.

## iOS preset (port-time; not in the repo)

Needs full Xcode (not just the Command Line Tools), an Apple Developer Team ID and provisioning.

```
[preset.N]
name="iOS"
platform="iOS"
exclude_filter="tests/*, tools/*, docs/*, _archive/*, .claude/*, build/*, icon.ico"
export_path="build/ios/SlimeTime.ipa"
[preset.N.options]
application/app_store_team_id="<Team ID>"
application/bundle_identifier="<owner's reverse-DNS id>"   ; M8
application/export_method_release=0     ; App Store
application/export_method_debug=1       ; Development
application/provisioning_profile_uuid_release=""           ; or automatic signing in Xcode
application/targeted_device_family=2    ; iPhone and iPad
application/short_version="1.0.0"
application/version="1"
application/min_ios_version="14.0"
architectures/arm64=true
user_data/accessible_from_files_app=false
user_data/accessible_from_itunes_sharing=false
privacy/*_usage_description=""          ; no camera, mic, photos, location
icons/app_store_1024x1024="res://<icon 1024>"   ; M9 (nearest-neighbor upscale, no alpha)
storyboard/use_custom_bg_color=true
storyboard/custom_bg_color=Color(0.102, 0.11, 0.173, 1)   ; UIKit.BG = Color8(26, 28, 44)
storyboard/image_scale_mode=0
```
Project settings (already right): orientation 4 (both landscape sides; the plist gets LandscapeLeft and LandscapeRight
on iPhone and iPad), `display/window/ios/hide_home_indicator=true`, `suppress_ui_gesture=true` (the home swipe needs two
swipes, so bottom-row taps aren't stolen), `hide_status_bar=true`, `audio/general/ios/session_category=0` (Ambient:
respects the mute switch). `user://` is the app's Documents (iCloud-backed); the custom user dir name is ignored there.

## Steam seam plan (no Steam code yet)

1. **Signal (done):** `Progress.report_progress(id, value)` after the save points emit `PlatformEvents.progress_event`:
   `medal_normal` / `medal_hard` (medals in that mode, after `record_clear`), `coins` (story coins found), `hats` (hats
   owned), `heat` (HEAT total), `random_wins`, `descent_floor` (deepest floor, after a run banks). Dev and in-memory runs
   report nothing. Nothing listens yet.
2. **Steam build:** a "Steam (Windows / Linux / macOS)" set of presets duplicating the desktop ones with
   `custom_features="steam"` (so `Platform.is_steam()` is true) and the GodotSteam GDExtension in `addons/godotsteam/`
   excluded from every other preset (the Web preset keeps `variant/extensions_support=false`).
3. **Backend:** a `SteamBackend` node added by PlatformEvents only when `Platform.is_steam()`: `Steam.steamInitEx()`,
   map `progress_event` to achievements (e.g. `medal_normal >= 30` -> ALL GOLD, `coins >= 165`, `hats >= 11`,
   `heat >= 100`, `descent_floor >= 10 / 20`) with `setAchievement` + `storeStats`; `Steam.overlay_toggled(active)` ->
   `PlatformEvents.enter_background()` / `leave_background()` (the overlay doesn't take OS focus); on the Deck,
   `ShowFloatingGamepadTextInput` when the save-code box gains focus (M6).
4. **Cloud saves:** Steam Auto-Cloud, no code: roots Windows `%APPDATA%/SlimeTime_R1`, macOS
   `~/Library/Application Support/SlimeTime_R1`, Linux `~/.local/share/SlimeTime_R1`; pattern `save.cfg` only (not
   `*.tmp`, `test_save_run_*`, `*.corrupt*.cfg`). A saved Descent run travels with the save (it is one file); save codes
   still never carry it.
5. Mobile store hooks (Game Center, Play Games) are another backend on the same signal.

## Promo captures on the Mac

`./tools/promo/make_promo.sh [--out-dir DIR]` is the twin of `make_promo.ps1`: the same cover (630x500) and eight
1280x720 screenshots with the same names, scenes, frames and flags (default `~/Desktop/SlimeTime-itch-images`). Smoke-run
only (to a temp dir, 53 s): all nine files at the right sizes. Note for the next real render: `screenshot-6-new-record`
at frame 1050 shows the run before the NEW RECORD banner on this build (the frame may need moving; same in the .ps1).

## Gates

- `./tools/test_all.sh`: **76 suites, 0 failed** (73 before + `test_platform` 66 checks, `test_gamepad` 60,
  `test_descent_resume` 52; `test_touch`, `test_ui_layout`, `test_descent` extended).
- Navigation fuzzer: new ops `joy_dpad`, `joy_start`, `joy_x`, `joy_lb_rb`, `joy_view`, `joy_y`, `stick`, `android_back`,
  `background` (with BG-PAUSE / BG-CLOCK / BG-HELD checks), the resume prompt registered as a hub modal: all four shards
  clean, zero violations.
- Gameplay pixel-identical at 60 Hz: movie captures (every 20th frame) of the Descent demo, the story intro and the finale
  are byte-identical to the pre-phase-5 baseline (0 differing pixels); the autopilot level demos (L3, L8), the record run
  and the hub differ only by the run-to-run particle noise two baseline runs show between themselves (worst frame 331-428
  px of 921,600 vs 362-416 baseline).
- Cutscenes identical (intro and finale captures above); only the input that skips them is wider (pads already worked).
- Headless boot of title, hub, main, settings, controls: no errors.
- Exports: Web, Windows, macOS, Linux all build with the 4.7.2 templates (to a scratch dir; `build/` untouched).

## Remaining (not done, and why)

- Glyph art and remapping for pads (D4: later); pad control of the CHAMELEON wheel (M3).
- The iOS title screen (and its STORY replay) is reachable only at launch: the hub has no way back to it without Esc /
  START / Android back. Owner call whether phones need a hub route to the title.
- An app that goes to the background during the goo wipe into a level (about 0.3 s) starts that level unpaused.
- M5 rainbow recolor cost, low-end device profiling, `Engine.max_fps = 60` on phones for battery: port-time measurements.

## Port-time checklist

1. Bundle id (M8) for iOS, Android and macOS.
2. Icons: 1024 marketing icon, Android adaptive layers, Steam capsules / library art (M9), nearest-neighbor only.
3. Android: JDK 17, Android SDK, build template, release keystore outside the repo, the preset above (backup on), an
   internal-testing upload; check the back button on a device (B1) and immersive mode.
4. iOS: full Xcode, Team ID, provisioning, the preset above; on a device check the home indicator against the bottom row
   (M1), both landscape sides (H5), the mute switch, backgrounding mid-level (H1) and an app kill mid-Descent (D6).
5. Steam: Steamworks app, GodotSteam in a Steam-only preset, `SteamBackend` on `progress_event`, overlay -> pause, Auto-Cloud
   on `save.cfg`, Deck: controller-only playthrough, the save-code text box (M6), 1280x800 (L9), glyphs.
6. Profiling on a low-end Android phone and an older iPhone (M5, thermals, `max_fps`).
7. Store pages: mention save codes as the cross-platform transfer path.
