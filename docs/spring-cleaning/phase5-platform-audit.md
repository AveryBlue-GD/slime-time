# Spring cleaning phase 5: platform audit (platform-porter, 2026-10-15)

This is the audit half of phase 5, on branch `spring-cleaning`. It is read-only: no game file changed. It covers
the owner's next targets: **iOS + Android native ports**, **Steam (Windows / macOS / Linux, Steam Deck)**, and
**web** (already shipped). The frame-rate goal is a stable 60 fps on low-end and mobile hardware, scaling smoothly
to 120/144/240 Hz on better machines. Platform code must stay separable, and no new features are added now.

**Method.** I grepped `scripts/` for `OS.` / `DisplayServer.` / `Input.` / `JavaScriptBridge` / `FileAccess` /
`DirAccess` / `user://` / `quit` / `NOTIFICATION_*` / key constants / prompt strings / `mouse_entered`. I read
`project.godot`, `export_presets.cfg`, `touch_controls.gd`, `rotate_hint.gd`, the save code in `progress.gd`,
`hub.gd`, `hat_wheel.gd`, `game.gd` input and timers, and the perf/QA docs. Test exports were made in a **scratch
copy** at `/private/tmp/claude-501/plat/proj`, with `custom_user_dir_name` changed so the real `SlimeTime_R1` save
was never touched and nothing was added to the repo:

| Scratch export | Result |
|---|---|
| Linux x86_64 (minimal preset) | **OK**: `SlimeTime.x86_64`, 78.8 MB, pck embedded. No project changes needed. |
| Android (`package/unique_name` only) | Refused: "A valid Java SDK path is required", "A valid Android SDK path is required". This Mac has no JDK, no Android SDK, and the editor's debug keystore file (`~/Library/Application Support/Godot/keystores/debug.keystore`) does not exist. A release keystore is also needed. |
| iOS (bundle id only) | Refused: "App Store Team ID not specified". With a dummy Team ID it got as far as writing the Xcode project, the pck (5.29 MB) and **`MoltenVK.xcframework`** (that is, the Mobile/Vulkan renderer, see B4), then failed at "Making .xcarchive" because only the Command Line Tools are installed, not full Xcode. The generated plist has **`UIInterfaceOrientationLandscapeLeft` only for iPhone and `LandscapeRight` only for iPad** (see H5). `icon.ico` was also packed into the iOS pck. |

The 4.7.2 export templates are already installed for every platform: android_*.apk, android_source.zip, ios.zip,
linux_*, macos.zip, web_*, windows_*.

Severity: **blocker** = the port can't ship or fails store review; **high** = players will hit it, or the
owner's stated goal is missed; **medium** = noticeable or needed before launch; **low** = polish or verify only.
Effort: S < 2 h, M = half a day to a day, L = more. **Fix now** = do it in the implementation half (no new
features; desktop and web behavior unchanged unless stated). **Port-time** = needs accounts, SDKs or devices, or an
owner decision.

## Ranked findings

### Blockers

| # | Finding (evidence) | Sev | Effort | Proposed fix | When |
|---|---|---|---|---|---|
| B1 | **Android back button quits the app from any screen.** `project.godot` has no `application/config/quit_on_go_back`, and its default is true. Nothing anywhere handles `NOTIFICATION_WM_GO_BACK_REQUEST` (no `_notification` in `scripts/` except `touch_controls.gd:108`). Every screen already treats `menu` / `ui_cancel` as back (`hub.gd:713-740`, `pause_menu.gd:240`, `level_select.gd:181`, `controls.gd:424`, `heat_panel.gd:166`, `map_select.gd:267`, ...), so the mapping is the only thing missing. | blocker (Android) | S | Set `application/config/quit_on_go_back=false` (Android-only setting, no desktop effect). In a small `Platform` autoload, turn `NOTIFICATION_WM_GO_BACK_REQUEST` into a pressed + released `ui_cancel` `InputEventAction` (in a level, `menu`). Add a test that sends the notification and checks the pause menu opens and the hub goes back. | fix now |
| B2 | **No gamepad for gameplay or the hub.** Every `[input]` action is keyboard only (`project.godot:44-90`). `Progress.apply_bindings()` **erases every event** and re-adds keys only (`progress.gd:2301-2309`), so a pad mapping in project.godot would be wiped anyway. Menus work on a pad only through Godot's default `ui_*` actions (D-pad / stick / A / B). A pad player cannot move in the hub, so cannot get past it. This blocks controller-only Steam Deck play (Deck Verified) and, later, phones with Bluetooth pads. | blocker (Steam Deck) / high (Steam) | M | Keep keys as they are. In `apply_bindings`, after the keys, re-add a fixed default pad layer from one table (for example in a `Platform`/`InputGlyphs` seam): left stick + D-pad = move, A = jump, X = interact, Start = menu, Back/View = restart, LB / Y / RB = abilities. B stays `ui_cancel` (back). Not remappable for now. Hide the touch controls on `InputEventJoypadButton` as well as keys (`touch_controls.gd:88-91`). Add a test that pad events survive `apply_bindings` and move the slime. **Owner call:** this is small and testable, but it is new input support. | fix now (bindings) / port-time (glyphs, remap) |
| B3 | **No Linux, Android or iOS preset, and no toolchain for the mobile ones.** `export_presets.cfg` has Windows, Web and macOS only (`:3`, `:45`, `:81`). Linux exports cleanly (see above). Android needs a JDK 17 path, an Android SDK path, a release keystore (and a debug keystore for test installs), `package/unique_name`, min/target SDK (Godot defaults are fine), no permissions (the game uses none), adaptive icons, `screen/immersive_mode` (default on) and `user_data_backup/allow` (M7). iOS needs an Apple Developer Team ID, **full Xcode**, provisioning, a 1024 icon, a launch screen and the bundle id. | blocker (port) | S (Linux) / M+ (mobile) | **Now:** add a `Linux` preset, the same as the Windows one (`exclude_filter` as Windows, `binary_format/embed_pck=true`, x86_64), exported to `build/linux/SlimeTime.x86_64`. **Port-time:** install Xcode, JDK 17 and the Android SDK, create the keystore (kept outside the repo), get a Team ID, then add the mobile presets. Add `icon.ico` to the mobile and Linux `exclude_filter`. | Linux now; mobile port-time |
| B4 | **High-refresh judder (owner goal).** Movement runs only in `_physics_process` at the default 60 ticks (`slime.gd:427`, `move_and_slide` `:551`; hub room turn `hub.gd:731-739`; run timer `game.gd:531-547`). `project.godot` has no `[physics]` section, so no physics interpolation, and nothing sets `vsync` or `max_fps`. The camera smooths on idle frames toward a target that moves at 60 Hz (`slime.tscn:33-34`, `game.gd:683-701`). On 120/144/240 Hz screens the slime and the hub advance in uneven 2-3-frame steps (144/60 = 2.4). 60 Hz screens are fine. `docs/perf/startup-memory-web.md:247` flagged interpolation as a fidelity risk with `snap_2d_transforms_to_pixel`, pending the owner's say-so. | high (Steam, 120 Hz phones) | M | Turn on `physics/common/physics_interpolation=true`. Call `reset_physics_interpolation()` wherever things teleport: level start, retry, spawn, hub `_place_all` after `turn_room`, `camera.reset_smoothing()` sites. Keep the snap (interpolated positions still land on whole pixels at render). Check with a `--write-movie` capture at a forced 144 fps (`--fixed-fps 144` with interpolation shows the cadence) and run the tests. Tests use `--fixed-fps 60`, so the simulation is unchanged. Timers stay correct (they are physics delta). **Needs owner sign-off** on the look. On mobile, also consider `Engine.max_fps = 60` for battery (port-time). | fix now (with sign-off) |

### High

| # | Finding (evidence) | Sev | Effort | Proposed fix | When |
|---|---|---|---|---|---|
| H1 | **No app lifecycle handling.** No `NOTIFICATION_APPLICATION_PAUSED/RESUMED/FOCUS_OUT/FOCUS_IN` or `WM_WINDOW_FOCUS_OUT` anywhere. On desktop, alt-tab and the **Steam overlay (Shift+Tab)** leave a level running: the run clock and the RACE countdown keep going (`game.gd:538-544`). On mobile, a finger held when the app is backgrounded may never send its release. TouchControls only lets go on `NOTIFICATION_PAUSED` / `EXIT_TREE` (`touch_controls.gd:108-111`), so the joystick or JUMP can come back stuck. | high | S-M | In the `Platform` autoload, on app paused or focus out: if a level is running and not finished, open its pause menu (the same path as `menu`, `game.gd:2166-2169`), and tell TouchControls to `_release_all()`. Do nothing on resume (the player taps RESUME). Desktop and web behavior changes only by "auto-pause when you leave". Add a test (send the notification, check the pause menu is open and no action is held). | fix now |
| H2 | **QUIT on native mobile.** The hub hides the QUIT trapdoor on the web only (`hub.gd:217-223`). It calls `get_tree().quit()` (`hub.gd:484-485`), which iOS does not support (and the HIG forbids). On Android it is redundant. | high (iOS review) | S | `Platform.can_quit()` = desktop only. Use it in place of the `web` check at `hub.gd:217` (the station count already handles 8 vs 9). Covered by the existing nav fuzz `--nav-variant=web` path. | fix now |
| H3 | **Desktop-only settings on mobile.** FULLSCREEN is enabled off-web (`Progress.fullscreen_available` returns true when not web, `progress.gd:445-447`; `controls.gd:72-73`), but it is meaningless on a native phone. The CONTROLS page is keyboard remapping only and says "ARROWS ALWAYS MOVE - ESC OR P PAUSES - F11 FULLSCREEN" (`key_controls.gd:56-57`). The F11 action is `project.godot:81`. | high (mobile) | S | `Platform.has_window_fullscreen()` = desktop + web-with-API: disable FULLSCREEN on mobile the same way as on iPhone Safari (`qa-web-report.md` O4, disabled not hidden, so the layout doesn't change). Disable the CONTROLS button on mobile without a keyboard (or keep it and accept it as harmless: owner/ui-polisher call). | fix now |
| H4 | **Hat wheel overlay on touch.** `open_hat_wheel` (`hub.gd:686-691`) does **not** set `_touch_controls.menu_open`, unlike the quit and portal menus (`hub.gd:466-471`, `530-540`). So every tap in the right half while the WHEEL tab is open is also a JUMP press, and `hub.gd:722-731` turns that into `hat_wheel.spin()` (a **paid** spin, `hat_wheel.gd:317-324`). The overlay also has no visible CLOSE: on touch the only way out is the 15x13 px pause glyph drawn over it (touch layer 15 vs overlay layer 2) or a stray JUMP when spinning isn't possible. The coin board (`hub.gd:737-741`) has the same pattern, but there it is harmless (it closes). **Needs a touch repro to confirm** (the touch-down JUMP comes before the button's release). | high (tickets spent by accident) | S | Set `menu_open = true/false` in `open_hat_wheel` / `close_hat_wheel` and spin only via the SPIN button on touch. Add a small BACK/CLOSE button to the overlay (visual change: hand the art/placement to ui-polisher). Extend `test_touch.gd`: a right-half tap on the WHEEL tab must not change `Progress.tickets`. | fix now |
| H5 | **Orientation.** `display/window/handheld/orientation` is unset (default: one landscape side). The scratch iOS plist has iPhone LandscapeLeft only and iPad LandscapeRight only, so a player holding the phone the other way gets it upside down / stuck. On native mobile the OS locks orientation, so the rotate cover (`rotate_hint.gd:72-73`) never shows there. It stays useful on the web. | high (mobile) | S | `display/window/handheld/orientation=4` (sensor landscape: both landscape sides). No effect on desktop or web. Keep `RotateHint` as is. | fix now |
| H6 | **Renderer on mobile.** `renderer/rendering_method.mobile` is unset (`project.godot:95` sets only the desktop/web value), so native Android/iOS would run the **Mobile (Vulkan / MoltenVK)** renderer, which is untested here. The scratch iOS export bundled MoltenVK. Every shader was written and QA'd against gl_compatibility / WebGL2 (`docs/perf/rendering.md` #13). | high | S | Add `renderer/rendering_method.mobile="gl_compatibility"`. This is the same path as the web build, so it looks the same. No desktop or web effect. | fix now |
| H7 | **Descent run lost when a phone kills the app.** The paid daily slot is used and saved at run start (`progress.gd:1515-1516`). The run and its pot live only in memory (`Progress.descent_run`, by design). Mobile OSes kill background apps freely, so the player loses the pot and the slot. | high (mobile) | M | Owner decision: either persist the run on `APPLICATION_PAUSED` (a save-format addition) or refund the slot on an unfinished run at the next launch. Not touched now. | port-time (owner) |

### Medium

| # | Finding (evidence) | Sev | Effort | Proposed fix | When |
|---|---|---|---|---|---|
| M1 | **Safe areas.** `DisplayServer.get_display_safe_area` is used nowhere. Integer scaling mostly hides this: the 320x180 view is scaled to the largest whole multiple and letterboxed (`project.godot:34-35`, aspect default `keep`). iPhone 15 Pro 2556x1179 → 6x = 1920x1080, side bars 318 px (wider than the 177 px notch inset), top/bottom bars 49 px. A 2400x1080 Android → 6x, full height, side bars 240 px. 1600x720 → 4x, side bars 160 px. iPad 2048x1536 → 6x. iPhone SE 1334x750 → 4x. So **notches and rounded corners land in the letterbox on every size checked**. What remains: on full-height fits, the home indicator or gesture pill overlaps the bottom ~2 game px, and the floating joystick can start within ~20 px of the bottom edge (`touch_controls.gd:129`), where iOS and Android edge gestures live. Letterbox touches already count (JUMP catches the right letterbox, and the joystick clamps). | medium | S-M | Port-time, on devices: check the iOS `display/window/ios/hide_home_indicator` / `suppress_ui_gesture` project settings (both should be on). If edge swipes interfere, add `Platform.safe_rect()` (safe area mapped into the 320x180 view) and clamp the joystick and pause to it. | port-time |
| M2 | **Keyboard-only prompts.** "KEYS 1 2 3 - RANDOM MAZES + DESCENT" also shows on touch (`upgrades_screen.gd:38`, `:477`). The key_controls note is H3. The web paste fallback says "CTRL+V" (`controls.gd:209`; it is Cmd+V in Mac browsers). The tutorial cues and hub prompts have touch variants but no pad variant (`tutorial_cues.gd:101-111`, `hub.gd:663`, `:682`). | medium | S now / M glyphs | Add one seam, `Platform.prompt_for(action) -> String` (key name / "TAP ..." / pad name), and route the four call sites through it. Now: the touch text for the ability hint. Pad glyphs (Xbox/PS/Deck art) come with B2 at port time. | fix now (seam + touch text) |
| M3 | **CHAMELEON color wheel needs a pointer.** It reads only mouse button and motion (`color_wheel.gd:51-54`), with no focus or keyboard/pad steps. Touch works through mouse emulation. A controller-only Deck player can't pick a custom color (the Deck trackpad can). | medium (Deck) | M | Port-time: when focused, D-pad left/right steps the hue and up/down steps the saturation (no visual change). | port-time |
| M4 | **Fullscreen isn't remembered.** Every launch opens a 1280x720 window (`project.godot:32-33`). The state is read live and not saved (`progress.gd:457-462`). Steam and Deck players expect it to stick. | medium (Steam) | S | Port-time: an optional `[settings] fullscreen` key (old saves lack it → windowed, so no epoch/version change), applied in `Progress._ready` on desktop only. | port-time |
| M5 | **Rainbow-skin UI recolor every frame.** `skin_text.gd:34-41` runs it once per frame, deduped, but `docs/perf/measurements.md:183-197` estimated 40-120 ms per frame in the hub on a phone, from the earlier measurement. This is the largest known mobile CPU risk. GPU fill is small, because the `viewport` stretch renders 320x180 and then upscales: fog plus vignette is about 1-2 ms on a mobile GPU (`measurements.md:181-184`). CPUParticles are at most 28 (fine). | medium | M | Re-measure the hub and skins screen with rainbow (perf-profiler) on the current code. If still heavy, throttle the recolor (for example to 20 Hz, an owner-visible change) or recolor by shader. Profile on a low-end Android device at port time. | measure now / fix port-time |
| M6 | **Save-code text entry on Steam Deck.** `code_in` is a plain LineEdit (`controls.gd:155-181`). Godot shows no Steam on-screen keyboard. PASTE (`DisplayServer.clipboard_get`, `controls.gd:192-193`) and COPY work everywhere natively. iOS shows its own paste-permission prompt (fine). | medium (Deck) | S | Port-time: with Steamworks, call `ShowFloatingGamepadTextInput` when `code_in` gains focus on the Deck (behind the Platform seam). | port-time |
| M7 | **Storage and backup.** `user://` = `SlimeTime_R1` on desktop/web. On Android and iOS Godot uses the app's own data dir (the custom dir name is ignored there), which is fine. Android `user_data_backup/allow` defaults off, so progress isn't restored on a new phone. iOS `user://` is in Documents, which iCloud backs up (fine: the save is about 10 KB, no size limits matter). Web, mobile and Steam saves are separate stores. **Save codes are the cross-platform transfer path** (already shipped). | medium | S | Port-time: `user_data_backup/allow=true` in the Android preset. Mention save codes on the store pages. | port-time |
| M8 | **Bundle id `com.slimetime.game`** (`export_presets.cfg:108`) becomes permanent once uploaded to the App Store, Play or the Mac App Store, and should be a reverse-DNS domain the owner controls. | medium | S | Owner picks the id before the first store upload. Use the same id for iOS, Android and macOS. | port-time |
| M9 | **Icons and store art.** `icon.png` is 64x64. iOS needs a 1024 marketing icon plus the set Godot generates. Android needs a 432x432 adaptive foreground/background (+ monochrome). The launch screen is Godot's storyboard (bg color + image). | medium | S-M | Port-time: a nearest-neighbor upscale step in `tools/make_placeholder_art.py` (16x → 1024) and adaptive layers. Never filter. | port-time |

### Low (verified OK or polish)

| # | Finding (evidence) | Note |
|---|---|---|
| L1 | Dev keys F1/F2 (`game.gd:2189-2190`), F10 (`autoplay.gd:27`), "DEV (F1 / F2)" (`pause_menu.gd:99`) | Only with `--unlock-all` / `--autoplay`, which release builds ignore (`progress.gd:412-424`). The pause menu's DEV buttons cover touch. Fine. |
| L2 | Hover: `hat_wheel.gd:450-451`, `heat_panel.gd:101-102` | Each `mouse_entered` is paired with `focus_entered`, so pad and touch get the same description. With touch, mouse emulation can leave a sticky hover look (cosmetic). |
| L3 | Right-click: only `story_screen.gd:133` (skip a shot, same as left/tap/key/pad) | Fine. |
| L4 | `NOTIFICATION_OS_MEMORY_WARNING` not handled | pck 5.3 MB, small heap. Ignore unless device tests show kills. |
| L5 | Time logic | The run timer and RACE use physics delta (`game.gd:538`), so they stop while the app is suspended (mobile) or the tab is hidden (web). Daily UTC caps use the wall clock, with clock-back and far-future guards (`progress.gd:1294`, `1331`, `1343`, `1590`). OK. |
| L6 | Save flush | Every change saves at once, atomically (`progress.gd:949-1006`, with retry). The web flushes IndexedDB on `visibilitychange` / `pagehide` (`tools/web_shell.html:155-193`). Nothing extra is needed on a mobile background (except H7). |
| L7 | Texture compression | `import_etc2_astc=true` (`project.godot:97`) is already set (needed for macOS arm64). Every texture is lossless with no VRAM compression, so ETC2/ASTC only adds import variants. Don't change it (perf F13). |
| L8 | Audio focus / ducking | Godot pauses audio on Android pause. On iOS, check the `audio/general/ios/session_category` default on a device: Ambient respects the mute switch and lets music apps play, which is right for this game. There are no bus effects. |
| L9 | Steam Deck display 1280x800 | 4x = 1280x720 with 40 px bars (16:10), legible (5x7 font = 28 px). 1440x900 Macs also get 4x with wide borders. An optional non-integer "fill" mode is a later owner call. |
| L10 | Scattered platform checks | `OS.has_feature("web")` sits in 7 places (`progress.gd:257`, `:446`; `hub.gd:217`; `controls.gd:192`, `:227`, `:271`; `key_controls.gd:56`; `sfx.gd:37`; `autoplay.gd:80`; `dev_log.gd:24`). Folded into the Platform seam below. |

## The seam to add now (no new features)

`scripts/platform.gd`, `class_name Platform`, mostly static, plus one small autoload node for notifications
(or fold the notifications into `Progress`):

- `is_web()`, `is_mobile()` (`OS.has_feature("mobile")`), `is_desktop()`, `is_steam()` (a `steam` custom feature
  on a future Steam preset; false now), `can_quit()`, `has_window_fullscreen()`, `prompt_for(action)`. `--web-ui` and
  `--touch` keep working as previews.
- Lifecycle: `NOTIFICATION_WM_GO_BACK_REQUEST` → `ui_cancel` / `menu` (B1). `APPLICATION_PAUSED` / `FOCUS_OUT` →
  `paused_by_os` signal, which `game.gd` and `TouchControls` listen to (H1).
- **Later hooks with no code now:** achievements will attach to a single `Progress.milestone(id)` signal emitted
  from `record_clear` (`:1412`), `collect_coin` (`:1764`), `win_hat` (`:2086`), `clear_descent_floor` (`:1500`) /
  `end_descent` (`:1636`), and the heat tiers. A `SteamBackend` (GodotSteam GDExtension, included only in a preset
  with `custom_features="steam"`; the Web preset keeps `variant/extensions_support=false`) listens and calls
  `setAchievement`. Mobile store hooks (Game Center / Play Games) are another backend on the same signal.

## Steam specifics

- **Cloud saves need no code:** use Steam Auto-Cloud on `save.cfg`. Roots: Windows `%APPDATA%/SlimeTime_R1`, macOS
  `~/Library/Application Support/SlimeTime_R1`, Linux `~/.local/share/SlimeTime_R1`. Sync only `save.cfg`, not
  `*.tmp`, `test_save_run_*` or the corrupt backups (`progress.gd:31-33`, `:601-606`).
- **Overlay:** works with gl_compatibility (OpenGL) on Windows, macOS and Linux once GodotSteam is in. It needs the
  pause-on-focus-out from H1.
- **Steam Deck:** blocked by B2 (no pad). Then M3, M6, M4. The display is fine (L9). The Windows build also runs under
  Proton, but ship the native Linux build (B3).
- **Store assets.** Existing tools: `tools/promo/make_promo.ps1` (**Windows/PowerShell only**, renders the cover
  630x500 and 5 shots at 1280x720), `tools/screenshot.sh` (`--write-movie` PNG frames, any `--scene`),
  `tests/demo_*.tscn` (record run, story, overview, jelly, hats...), and the story intro (already the "launch
  trailer"). Steam needs: header 920x430, small capsule 462x174, main capsule 1232x706, vertical 748x896, library
  capsule 600x900, library hero 3840x1240, library logo, and screenshots at 1920x1080 (= 320x180 x6, an exact
  integer). The trailer can come from Godot's movie maker (`--write-movie out.avi`, MJPEG + audio) over the demo scenes at
  a 1920x1080 window. Port-time: a `.sh` twin of make_promo plus capsule scenes in `tools/promo/`. Don't re-render
  until the owner asks (CLAUDE.md).

## Implementation-half checklist (fix now, in order)

1. `Platform` seam + replace the scattered web checks (L10). No behavior change, and add tests.
2. B1 back button (`quit_on_go_back=false` + GO_BACK → `ui_cancel` / `menu`).
3. H6 `rendering_method.mobile="gl_compatibility"` and H5 `handheld/orientation=4` (project settings only).
4. H2 quit hidden on mobile, H3 fullscreen / CONTROLS on mobile, M2 `prompt_for` + touch ability hint.
5. H1 auto-pause on focus out / app paused + TouchControls release.
6. H4 hat wheel `menu_open` (+ CLOSE button via ui-polisher) + touch test.
7. B3 Linux preset (`icon.ico` excluded).
8. B2 default pad layer (owner call) and B4 physics interpolation (owner sign-off): both need a movie check.

**Port-time (needs accounts, SDKs, devices or owner decisions):** Xcode + Team ID + provisioning; JDK 17 + Android
SDK + keystore; mobile presets; bundle id (M8); icons and launch screen (M9); Android backup flag (M7); iOS home
indicator / gestures and safe-area check (M1); Descent persistence (H7); fullscreen persistence (M4); color wheel on
pad (M3); Deck keyboard (M6); pad glyphs and remapping; Steamworks + achievements backend + Auto-Cloud; store
capsules and trailer; low-end Android and iPhone profiling (M5, battery, thermals); `max_fps` on mobile.
