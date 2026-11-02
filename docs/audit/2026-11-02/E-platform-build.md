# Audit E: platform, audio, localization, build / test / export (read-only, 2026-11-02)

Branch `cleanup/audit-2026-11-02`. Files read in full: scripts/platform.gd, platform_events.gd, language.gd, loc.gd, music.gd, sfx.gd,
project.godot, export_presets.cfg (macOS / macOS Demo / macOS Steam / iOS read line by line, the others by section), .github/workflows/tests.yml,
tools/*.sh, tools/demo_export.gd, demo_paths.gd, make_ios_icon.gd, job_timeout.pl, the head of demo_smoke.gd, tests/suite_base.gd, .gitignore, .gitattributes.
Nothing was run (no Godot), and nothing in the repo was changed.

## 1. Map

**Autoloads** (project.godot:26-34). They are created in this order, and each `_ready` runs in the same order:
1. `Progress` (scripts/progress.gd:430). Asks a browser to keep its storage persistent, adds the `interact` and ability actions, picks the save
   (throwaway / in-memory / `REAL_SAVE_PATH`) from the debug flags (a release build keeps only `--touch` and `--web-ui`, `game_args`:641), loads the save,
   runs `apply_bindings()` (which then adds `Platform.apply_pad_layout()`) and `apply_volume()`, restores the saved fullscreen (desktop, real save
   only) and watches the window mode.
2. `Language` (language.gd:143). Turns auto-translate off on the root. The gate is ON (`Economy.LANGUAGES_TEST := true`, economy.gd:557), so
   `enable()` loads **all 17** `.po` files from `CATALOGS` and picks the locale: `--lang`, then the saved `[settings] language`, then the OS
   locale (not used: `LANGUAGES_FOLLOW_OS := false`), then `en`. It then installs the current locale's fallback font on pixel.fnt,
   pixel_big.fnt and the tabular copy, applies the CJK gap glyph, and pins the root to LTR.
3. `Sfx` (sfx.gd:28). Makes the `SFX` bus and loads 32 `assets/sounds/<name>.wav`, with 3 `AudioStreamPlayer` voices each (96 nodes).
4. `Music` (music.gd:75). Makes the `Music` bus, one stream player, 3 orchestra layer players and a sting player, all `PLAYBACK_TYPE_STREAM`.
   It follows `scene_changed` (hub loops on `HUB_SCENES`, the title loop and sting, the level bed or the 3-layer orchestra outside the web) and
   stops on other scenes.
5. `RotateHint` (CanvasLayer 100). A portrait touch window gets a "ROTATE YOUR DEVICE" cover and the tree is paused. It polls the window size
   every frame.
6. `Transition` (CanvasLayer 100). The goo wipe, plus physics interpolation only above ~72 fps.
7. `PlatformEvents` (platform_events.gd:43). `PROCESS_MODE_ALWAYS`. Sets `last_input`, sets `Engine.max_fps = 60` on the web and on phones
   (`Platform.frame_cap`), hooks `window_input` (last-device tracking and the stick snapped to 8 directions) and the web `visibilitychange`.
   It also handles back / close / focus / pause notifications.

**Platform seam.** `Platform` (class_name, statics only) is the only place that calls `OS.has_feature("web"|"ios"|"android"|"steam"|"demo")`.
`kind()` returns the override, else `--platform=` (debug builds only), else the feature tag. On top of it: `is_web` (also `--web-ui`),
`is_mobile_native`, `is_desktop`, `is_ipad` (`OS.get_model_name()` starts with "iPad"), `has_touch`, `can_quit` (desktop only),
`has_window_fullscreen`, `remembers_fullscreen`, `frame_cap`, `safe_rect` / `safe_rect_for` (maps the display safe area into the 320x180 view,
integer scale, centred), the pad table `PAD_BUTTONS`, and Steam (`steam_api()` through `Object.call`, so the file parses without
GodotSteam). `PlatformEvents` covers the lifecycle side: back = one `menu` tap; focus-out / pause = release inputs, flush the save, and
`pause_for_background()` on the current scene.

**Audio.** SFX: fixed voice pools, per-sound pitch / volume variation, deduped within a frame, coin-chain pitch and music ducking under the
orchestra flag; on the web the first gesture plays an inaudible click to unlock audio. Music: one `_level` fade controller, with `_apply_volume`
writing a value only when it changes (for the web). Ambience is per level in game.gd:875-890: `ambient_<theme>.wav` plus
`ambient_<theme>_<k>.wav` for k = 0.. while the file exists.

**Localization.** `Loc.t/n/fill` (static) use `TranslationServer` when `Economy.languages_on()`, with pseudo-localization, RTL isolates and
the CJK gap applied to the finished text. Catalogs are `.po` files loaded by path (language.gd:34-40, a fixed list so the code works inside a
.pck). Fallback fonts are fixed-size `.woff2` subsets.

**Commands** (bash). `./tools/godot.sh` ($GODOT, then /Applications/Godot.app, then ~/Applications, then PATH, then winget). `./tools/play.sh
[--dev|--story|--scene]`. `./tools/screenshot.sh` (`--write-movie` to .screens/latest.png). `./tools/test_all.sh [-j N] [suite...]`: every
`tests/test_*.gd` headless, `--fixed-fps 60 --quit-after 300000`, through `job_timeout.pl` (a process-group kill after JOB_TIMEOUT); nav_fuzz and
maze_golden are sharded; a log fails on a missing `RESULT: PASS` or on SCRIPT ERROR / USER ERROR; it runs under `caffeinate` on a Mac.
`./tools/build_demo.sh [--all]`: pck_check self-test, regenerates the demo and Steam presets (`demo_paths.gd --write-presets`), exports, checks
the packs against the cut list, smoke-runs the Windows and Web packs, and checks the real save's md5. `./tools/ios_build.sh [TEAM]`: patches
the Team ID, build stamp and bundle version into export_presets.cfg and project.godot (restored by an EXIT trap), runs `--export-debug "iOS"`
(Xcode project only), then `xcodebuild` and `devicectl install`. `./tools/i18n_capture.sh --gate`: per-locale captures plus the goo-ink gate.

**CI** (.github/workflows/tests.yml): ubuntu-latest, runs on every push and every PR. It caches and downloads the official 4.7.2 Linux
editor, runs `--headless --import || true`, then `./tools/test_all.sh` with `TIMES=1 KEEP_LOGS=test-logs`, and uploads the logs on failure.
There is no export job, no macOS / iOS job, and no `permissions:` block.

## 2. Mac / iOS

Below, **[repo]** means read in the files. **[confirm]** means it depends on Godot 4.7.2 engine defaults or behaviour that I did not verify
here (no Godot run, no docs fetched).

### HiDPI / Retina
- **[repo]** `display/window/dpi/allow_hidpi` is **not set** in project.godot, so the engine default applies (I believe it is `true` in Godot 4:
  **[confirm]**). The macOS presets set `display/high_res=true` (export_presets.cfg:117, NSHighResolutionCapable). Window
  `window_width_override=1280`, `window_height_override=720`, viewport 320x180, `stretch/mode="viewport"`, `scale_mode="integer"`.
- **[confirm]** Whether the 1280x720 override means points or backing pixels on a Retina Mac (windowed size 1280x720 pt = scale 8 in
  2560x1440 px, or a half-size window). Check it on the MacBook Pro.
- Integer scale `min(floor(W/320), floor(H/180))` at full-screen backing pixels (my arithmetic, same formula as `Platform.safe_rect_for`):
  | Display (px) | scale | image | bars (each side) |
  |---|---|---|---|
  | 1920x1080, 2560x1440, 3840x2160, 5120x2880 (16:9 externals / Studio Display) | 6 / 8 / 12 / 16 | exact fill | none |
  | MacBook Air 13" 2560x1664 | 8 | 2560x1440 | 0 / 112 top-bottom |
  | MacBook Air 15" 2880x1864 | 9 | 2880x1620 | 0 / 122 |
  | MacBook Pro 14" 3024x1964 (fullscreen sits below the notch, ~3024x1890) | 9 | 2880x1620 | 72 / ~135 |
  | MacBook Pro 16" 3456x2234 | 10 | 3200x1800 | 128 / 217 |
  | iPhone SE 3 1334x750 | 4 | 1280x720 | 27 / 15 |
  | iPhone 15 Pro 2556x1179 | 6 | 1920x1080 | 318 / 49.5 |
  | iPhone 16 Pro Max 2868x1320 | 7 | 2240x1260 | 314 / 30 |
  | iPad 10th gen 2360x1640 | 7 | 2240x1260 | 60 / 190 |
  | iPad mini 2266x1488 | 7 | 2240x1260 | 13 / 114 |
  | iPad Pro 13" 2752x2064 | 8 | 2560x1440 | 96 / 312 |

  On the 4:3-ish iPads, integer 16:9 scaling leaves roughly 23-30 % of the screen as black bars. That follows from the pixel-art rule, so it
  is not a bug, but the owner should see it before an iPad release. **[confirm]** Godot on iOS renders at native scale (the numbers above
  assume physical pixels).
- **Safe areas [repo]:** `Platform.safe_rect_for` (platform.gd:311) cuts the view only where the safe area reaches past the bars. On iPhone 15
  Pro the 318 px side bars already cover the Dynamic Island (inset 177 px), so only the home-indicator strip trims about 2.25 view px at the
  bottom (the tests use the same numbers). On iPhone 16 Pro Max (bars 314 px), sides are clear the same way. `display/window/ios/*` keys are
  **not** in project.godot, so `hide_home_indicator`, `suppress_ui_gesture` and `hide_status_bar` are engine defaults (phase5-platform.md says
  they were "checked" as true; **[confirm]** in 4.7.2).
- **[confirm]** iPadOS 26 resizable windows: if `UIRequiresFullScreen` is no longer honoured, a portrait-shaped window would bring up
  `RotateHint` (rotate_hint.gd:93 `touchscreen and h > w`) and pause the game, and a small window drops the integer scale. Check this on an
  iPad with iPadOS 26.

### Renderer
- **[repo]** `rendering/renderer/rendering_method="gl_compatibility"` and `rendering/renderer/rendering_method.mobile="gl_compatibility"`
  (project.godot:112-113). No `rendering/gl_compatibility/*` keys are set (no driver choice, no ANGLE fallback setting). So the GL driver is
  the 4.7.2 engine default on each platform. `textures/vram_compression/import_etc2_astc=true` is set (needed by the arm64 macOS slice and by
  iOS). Linux / Windows presets set `texture_format/s3tc_bptc=true` and `texture_format/etc2_astc=false`.
- **[confirm]** Which backend that default is: on macOS, the native OpenGL 3.3 driver (Apple's deprecated GL, itself layered on Metal) or
  ANGLE-on-Metal; on iOS, OpenGL ES 3.0 (deprecated by Apple) or ANGLE. Nothing in the repo selects ANGLE, so the brief's "via ANGLE" is
  not established by the project files. The Metal-native renderers (Forward+ / Mobile) are not used.

### macOS presets (`macOS`, `macOS Demo`, `macOS Steam`, export_presets.cfg:79-138, 248-307, 514-573)
- Bundle id `com.slimetime.game` (`.demo` for the demo; macOS Steam uses the same id as the itch build). Version: `short_version` and
  `version` are both `"1.0.0"`. Copyright `"(c) 2026 Dry Trying"`. Category `"Games"`. Min `10.13` (x86_64) / `11.00` (arm64), `universal`.
- Icon `res://icon.png` with **`application/icon_interpolation=4`** (filtered). icon.png is 256x256 RGBA (checked with `file`), not the 64x64
  that docs/spring-cleaning/phase5-platform.md M9 states. See E-02.
- Code signing: `codesign/codesign=3` with empty `codesign/identity` and empty `codesign/apple_team_id` (an ad-hoc signature, per
  docs/itch-release.md:83). `notarization/notarization=0`. `export/distribution_type=0`. All entitlements false,
  `codesign/entitlements/app_sandbox/enabled=false`, no custom entitlements file, no privacy strings (none needed: no camera, mic or location).
- What this means for a release. **Notarized (Developer ID):** set an identity, a team id and notarization; GodotSteam's dylib under the
  hardened runtime and library validation needs checking (**[confirm]**). **Mac App Store:** needs the sandbox on, `distribution_type` App
  Store, an installer identity, and a different `user://` (the sandbox container), which would not carry over saves from itch players. The
  itch build today needs the documented Gatekeeper workaround (itch-release.md:92-96).

### iOS preset (`iOS`, export_presets.cfg:605-647)
- `application/app_store_team_id="ABCDE12345"` is a placeholder that ios_build.sh:31 swaps in for the build only. Bundle id
  `com.averyblue.drytrying` (differs from macOS, see E-01). `application/short_version="1.0.0"`; `application/version="1"`, rewritten to a
  timestamp per build. `min_ios_version="15.0"`, `targeted_device_family=2` (iPhone and iPad), `architectures/arm64=true`,
  `export_project_only=true`, `export_method_release=0` / `debug=1`, `icon_interpolation=0`. `icons/icon_1024x1024` and
  `icons/app_store_1024x1024` both point to `assets/ios/icon_1024.png` (1024x1024 RGB, no alpha, checked). Files app and iTunes sharing off.
- Orientation comes from project.godot `window/handheld/orientation=4` (sensor landscape). Launch screen: `storyboard/use_custom_bg_color=true`,
  `custom_bg_color` = UIKit.BG, `image_scale_mode=0`.
- Not in the preset (engine defaults apply, **[confirm]**): `capabilities/*` (UIRequiredDeviceCapabilities), `privacy/*` usage strings and
  privacy manifest, provisioning profile UUIDs (automatic signing in Xcode is assumed), `ITSAppUsesNonExemptEncryption` (no
  `application/additional_plist_content`, so App Store Connect asks the export-compliance question on every upload).
- Store notes: `DisplayServer.clipboard_get()` (controls.gd:626, PASTE of a save code) brings up iOS's paste-permission alert, which is
  expected; check how it looks. By default an iPhone / iPad app is also offered on Apple Silicon Macs (E-13). On ProMotion iPhones,
  `Engine.max_fps = 60` plus vsync: check frame pacing on a device (**[confirm]**).

## 3. Findings

| id | sev | category | file:line | evidence | fix plan | behavior risk | conf |
|---|---|---|---|---|---|---|---|
| E-01 | medium | mac-ios | export_presets.cfg:108 vs :631 | macOS `application/bundle_identifier="com.slimetime.game"`; iOS `"com.averyblue.drytrying"`. phase5-platform.md M8: "same id for iOS, Android, macOS"; itch-release.md calls the macOS one a placeholder | Owner picks one reverse-DNS id they control; set it on the full macOS and iOS presets and regenerate the demo / Steam presets (`demo_paths.gd --write-presets`) | A new app identity on macOS (the save is keyed by `custom_user_dir_name`, so it stays) | high |
| E-02 | medium | mac-ios | export_presets.cfg:104 (+ :273, :539 generated) | macOS `application/icon="res://icon.png"` (256x256) with `application/icon_interpolation=4`: Godot upscales the pixel-art icon with filtering to the 512/1024 Retina icns sizes. The iOS preset already uses nearest (`=0`) and a 1024 nearest-neighbour icon | Point the macOS presets at `res://assets/ios/icon_1024.png` and set `icon_interpolation=0`, then regenerate the demo / Steam presets | Dock / Finder icon becomes crisp; nothing else changes | high (the 4 = Lanczos mapping is **[confirm]**) |
| E-03 | medium | hot-path | language.gd:213-216, 289-292 | With the gate ON, `enable()` → `_load_catalogs()` loads all 17 `.po` files (≈2.0 MB of text in locale/, `du`) on every launch, also for English players, the default. Not measured | Load only the current locale's catalog in `set_locale` (keep `load_catalog` for tests; unload the previous one) | Tests that count `loaded_catalogs()` would need updating; translations look the same | high that it happens; boot cost not measured |
| E-04 | medium | mac-ios | export_presets.cfg:111-112, 117-118 | `codesign/identity=""`, `codesign/apple_team_id=""`, `notarization/notarization=0`, `app_sandbox/enabled=false`, `distribution_type=0`. Documented as an ad-hoc choice for itch, but it blocks a warning-free or Mac App Store release, and macOS 15 removed the Control-click bypass | Before a paid / Steam / MAS release: Developer ID identity, team, notarization (and the sandbox only for the MAS) | Signing only; for the MAS, the save path moves into the container | high |
| E-05 | low | mac-ios | project.godot:90-94; progress.gd:665 | `toggle_fullscreen` is bound only to F11 (physical_keycode 4194342). macOS assigns F11 (fn+F11) to Mission Control's "Show Desktop" by default, so the key usually never reaches the game. The SETTINGS button and the green window button still work | Add the macOS convention Ctrl+Cmd+F (meta+ctrl F) as a second event for `toggle_fullscreen` on desktop | None elsewhere | medium |
| E-06 | low | bug | tools/test_all.sh:87, 129 | The Linux fallback is `$HOME/.local/share/godot/app_userdata/SlimeTime_R1`, but `use_custom_user_dir=true` puts user:// at `~/.local/share/SlimeTime_R1` (build_demo.sh:43 uses that path; phase5-platform.md "Linux ~/.local/share/SlimeTime_R1"). On Linux, the stale-file sweep and the per-job cleanup after a crash never run | Use `${XDG_DATA_HOME:-$HOME/.local/share}/SlimeTime_R1` | None (it only deletes test files of dead pids) | high |
| E-07 | low | hygiene | tools/ios_build.sh:28-48 | Rewrites the tracked project.godot (build stamp) and export_presets.cfg (the real Team ID, version, `skip_demo`) in place and restores them from `build/*.bak` in an EXIT trap. A SIGKILL, power loss or a concurrent editor save leaves the real Team ID / stamp in the working tree, where a commit could pick it up | Export from a temp copy of the project (or pass a generated override preset) instead of editing tracked files | None for the build | high |
| E-08 | low | hygiene | .github/workflows/tests.yml:4-6, 40 | `--import \|\| true` hides import failures (the tests then fail confusingly); `on: push` + `pull_request` runs twice for PR branches; no `permissions:` block; the Godot zip is not checksummed | Check the import exit code (or grep its log); limit `push` to main; add `permissions: contents: read`; verify the SHA-512 of the download | CI only | high |
| E-09 | low | dead-code | sfx.gd:7 | `jingle` is in `SOUNDS`, so jingle.wav is loaded with 3 players at boot, but the string "jingle" appears nowhere else in scripts/, scenes/ or tests/ (repo-wide grep: only sfx.gd, its .import and make_sounds.py) | Remove it from `SOUNDS` and delete the asset and its generator entry (or wire it to the gold-skin glide it was made for, make_sounds.py:228) | None | high |
| E-10 | low | unchecked-error | sfx.gd:83, 105-107 | `play()` / `stop()` read `_players[sound_name]` without `has()`; an unknown name gives a script error (`has_sound` exists but `play` does not use it) | Early-return with `push_warning` when `not _players.has(sound_name)` | None for valid names | high |
| E-11 | low | hygiene | language.gd:5-11; demo_export.gd:9 (tools) | The header says "Gate off (... the default)", but `LANGUAGES_TEST := true` since 2026-11-01; demo_export.gd still mentions "the catalogs while languages are off" | Update the comments | None | high |
| E-12 | low | hygiene | docs/spring-cleaning/phase5-platform.md (M9), docs/ios-personal-install.md "Notes" | Both say icon.png is 64x64 / "nearest-neighbor 16x"; icon.png is 256x256, so make_ios_icon.gd does a 4x upscale | Fix the docs | None | high |
| E-13 | low | mac-ios | platform.gd:79-80, 98-99 | If the iOS app is offered on Apple Silicon Macs (App Store Connect default for iPhone / iPad apps), `kind()` returns "ios" there: no QUIT, touch UI, `has_vibration()` true (the model name is not "iPad"), 60 fps cap. A native macOS build exists anyway | Opt out of "iPhone and iPad Apps on Apple Silicon Macs" in App Store Connect at release (or detect it in `Platform` later) | None | medium (what the engine reports on a Mac is **[confirm]**) |

Severity count: critical 0, high 0, medium 4, low 9.

### Unused assets (checked: every file in assets/ by literal path, file name and stem, plus the constructed patterns
`ambient_%s.wav` / `ambient_%s_%d.wav` (game.gd:875-889, sequential while the file exists), `themes/%s_%s.png` (themes.gd:75 with
walls / floors / fillets / border, maze_tiles.gd:341-365), `logo_%02d.png` (title.gd:14, `LOGO_VARIANTS := 12` → 00-11, 00 also in
intro_card.gd:23), `icon_%s.png` (ui_kit.gd:1345/1355, names from callers incl. hud.gd:888 `medal_off/bronze/silver/medal`), font pages
(pixel.fnt / pixel_big.fnt `page` lines name pixel_ext.png and pixel_big_ext.png), and the Sfx `SOUNDS` list against every call site)
- **assets/sounds/jingle.wav**: loaded by Sfx but never played (E-09). This is the only unreferenced runtime asset I am confident about.
- Every sprite, ui icon, hub sprite, theme atlas (10 themes x 4), logo variant, music track (12 `.ogg`; the `orch_*` files are excluded from
  Web on purpose), shader (13) and ambient wav (bed + contiguous 0..5/0..6) has a runtime reference. `assets/ios/icon_1024.png` is used only
  by the iOS preset (by design). The `OFL.txt` / `LICENSE.txt` / `SOURCE-*.txt` files next to the fonts are licence and provenance files: keep them.

### Unreferenced scripts
- None. The only scripts with no literal reference are `scripts/level_data/level_NN.gd` / `hard_NN.gd`, which levels.gd:24 loads by
  constructed path (`DATA_DIR`).
