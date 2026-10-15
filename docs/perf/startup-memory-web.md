# Startup, memory, assets, audio and Web export: performance review

Date: 2026-10-13. Godot 4.7.2, branch `v2` at `e368448`. This review was read-only: no game files were changed.
All timings come from headless runs on an Apple M3 (native, CPU only). Web/WASM GDScript is usually
2-4x slower, so web figures are estimates. Scripts are in `/private/tmp/claude-501/perf_tools/`.
The Web build used for the size figures was exported to `/private/tmp/claude-501/perf_web/`.

Rule for every fix below: it must not change how the game looks or sounds. Anything that would is
marked **FIDELITY RISK - do not apply**.

## Headline numbers

| What | Measured |
|---|---|
| Web export total | 44.7 MB raw (`index.wasm` 39.5 MB, `index.pck` 4.85 MB, `index.js` 0.28 MB); 14.2 MB as a zip (`-9`) |
| Over the wire with gzip | wasm 10.05 MB, pck 3.97 MB, js 0.07 MB, so about **14.1 MB** in total |
| What fills the pck | 97 QOA audio samples 3.96 MB (**82 %**): ambient beds 2.15 MB, ambient one-offs 1.69 MB, SFX 0.13 MB. 69 textures 0.43 MB, 45 scripts 0.30 MB, everything else about 0.1 MB |
| Headless start to 2 frames of the title | 0.35 s (native) |
| First (cold) scene loads | main 98-116 ms, story 62-66 ms, hub 41-47 ms, skins 29 ms, title/level select/controls/upgrades/victory 11-19 ms. A second load is under 1 ms (the resources stay cached) |
| `_ready` of the game scene | level 1 16 ms, level 5 22 ms, **level 10 45 ms** (its maze alone takes 20 ms), random #4242 16 ms |
| Menu screen `_ready` (level select, skins, controls, upgrades, victory) | 22-25 ms each, about 17 ms of it the menu backdrop maze (see F3) |
| Node counts after load | title 15, hub 114 (41 Label), main 113-173 (level 10: 70 Sprite2D), skins 134, level select 67, controls 44, upgrades 64, victory 26 |
| Texture memory if every PNG were loaded | 7.6 MB RGBA8. A level only loads its own theme's 256x576 wall atlas (0.6 MB) plus small sheets, so about 1.5 MB in use |
| Autoload `Sfx` | 20 sounds x 3 voices = **60** AudioStreamPlayers. Building them (loads already cached) took 7.3 ms |

The game draws at 320x180 and scales up the whole viewport (stretch mode `viewport`), so the GPU
shades only 57,600 pixels per frame. GPU fill is not the bottleneck: **CPU (GDScript) time, shader
compiles on first use, and the download size are.**

## Biggest files in the Web export

| # | File (inside `index.pck` unless noted) | Bytes | Note |
|---|---|---:|---|
| 1 | `index.wasm` (engine, outside pck) | 39,514,754 | 10.05 MB gzipped; standard template with 3D and every module |
| 2 | `index.pck` (all game data) | 4,850,336 | 3.97 MB gzipped |
| 3-12 | `ambient_<theme>.wav` x10 (24 s beds, QOA) | 214,567 each = 2,145,670 | 44 % of the pck. A level uses only its own theme's bed |
| 13 | `index.js` (outside pck) | 279,815 | |
| 14-15 | `ambient_crystal_6`, `ambient_crystal_2` | 55,727 each | |
| 16 | `scripts/ui/story_screen.gdc` | 47,737 | the largest script |
| 17-19 | `ambient_catacombs_0/2/5` | 42,351 each | |
| 20-22 | `ambient_crystal_1/3/4` | 40,567 each | |
| 23 | `mossy_walls.png` ctex (the largest texture) | 39,304 | the 10 theme wall atlases total 344 KB |
| 24 | `scripts/game.gdc` | 38,248 | |
| 25 | `scripts/progress.gdc` | 23,751 | |
| - | `build/web/index.png` + 2 icons (ctex + .import) | about 15,600 | **an old export inside the project, imported and shipped again** (see F7) |
| - | `assets/sprites/walls.png` ctex, `assets/sprites/fillets.png` ctex | 11,228 + 270 | unused by the game (see F7) |

By type: `.sample` 3,961,687 (97 files) · `.ctex` 425,852 (69) · `.gdc` 300,780 (45) · `.gdshader`
35,503 (9) · `.import` 29,936 (169) · `.scn` 11,967 (12) · fonts 9,755.

The exclude filter already works: no `tests/`, `tools/`, `docs/` or `.claude/` files are in the
pck. `docs/` has a `.gdignore`; `.screens/` is hidden, so Godot skips it.

## Ranked findings

Format: **file:line** - issue - fidelity-preserving fix - gain (measured or estimated) - risk - effort.

### F1. Web download: the engine is 88 % of the bytes (L effort, biggest win)
- **export_presets.cfg:44-46 / Web preset** - the stock `web_nothreads_release` template includes the
  3D renderer, 3D physics, navigation, and the full text server with ICU/HarfBuzz. The game is pure 2D,
  draws its text with bitmap `.fnt` fonts and uses the `gl_compatibility` renderer.
- Fix: build a custom Web export template with a build profile (Project > Tools > Engine Compilation
  Configuration Editor, which detects the classes the game uses) plus `disable_3d=yes`,
  `module_text_server_adv_enabled=no module_text_server_fb_enabled=yes`, and switch off unused modules
  (navigation, openxr, csg, gridmap). Keep `noise`: the game uses FastNoiseLite. Then set
  `custom_template/release`. The engine renders exactly the same; only unused code is removed.
- Gain (estimated from typical 2D-only Godot 4 builds): wasm about 39.5 → 20-25 MB raw, about
  10 → 5-6 MB gzipped. That is **30-35 % less to download in total**, and the browser compiles the
  wasm faster, so time to first frame drops too.
- Risk: M. Needs the emscripten toolchain. Every scene must be smoke-tested, because a class the
  profile wrongly removes fails at run time. Keep text_server_adv if any non-Latin text is planned.
- Effort: L.

### F2. Web hosting: make sure the wasm is served compressed (S)
- 44.7 MB raw versus 14.1 MB gzipped. If the host (itch) does not send `Content-Encoding: gzip/br` for
  `.wasm` and `.pck`, players download 3x more.
- Fix: check one load in the browser's DevTools Network panel (look at the response headers and the
  transferred size). If the host serves the files uncompressed, compression has to be set up on the
  hosting side; the files themselves don't change.
- Gain: up to about 30 MB less to download if it is uncompressed today. Risk: none. Effort: S
  (checking only).

### F3. Every menu screen rebuilds the same backdrop maze and TileSet (S-M)
- **scripts/ui/menu_backdrop.gd:41-42** (`MazeGenerator.generate(MAZE_CELLS, MAZE_SEED, 0.3)` +
  `MazeTiles.fill`), reached through **scripts/ui/ui_kit.gd:140** from every menu screen.
  **scripts/maze_tiles.gd:36 + 116-135**: `fill` calls `make_tile_set`, which builds 3 atlas sources and
  **576 collision polygons** every time, even for the backdrop's collision-free layers.
- Measured (native): backdrop maze 3.3 ms + `MazeTiles.fill` 14.1 ms (TileSet 4.8 ms warm / 7.7 ms
  cold) = **about 17 ms per menu screen**, of the 22-25 ms `_ready` time. On the web expect 40-70 ms of
  frozen frame on every screen change. It happens under the goo cover, so it shows as a stall at full
  cover.
- Fix (output stays identical, because everything is deterministic):
  1. `static var _maze` cache in MenuBackdrop (fixed seed and size).
  2. Cache the TileSet per theme in a `static var _tile_sets := {}` in `MazeTiles.make_tile_set`. Don't
     change the shared TileSet afterwards; `_break_wall` only changes cells. Check that before sharing.
  3. Optional: cache the filled layers' `tile_map_data` (a PackedByteArray) for the backdrop and assign
     it instead of 2,257 `set_cell` calls.
- Gain: about 15 ms native and about 40-60 ms web per menu change; also about 5 ms on every level
  load or restart from the TileSet cache. Risk: low. Effort: S (1+2), M (3).

### F4. Restarts and next levels rebuild a deterministic story maze (S)
- **scripts/game.gd:271** `MazeGenerator.generate_level(config)` runs on every `retry()` /
  `replay()` / `reload_current_scene()` (**game.gd:1269-1325**). Level 10 measured **20 ms** of a
  45 ms `_ready`; levels 8-9 take 16-20 ms. **scripts/levels.gd:123-124** `story_maze` builds the same
  mazes again for pars and coin keys, with nothing shared.
- Fix: memoize `Levels.story_maze(level, hard)` in a static dict and have game.gd take
  `story_maze(...).duplicate(true)` (deep copy, because walls can break during play). The random mode
  can cache the last seed+level the same way, so REPLAY MAZE / dry-up retries skip generation (seed
  101 at slime level 7 took 15.5 ms, seed 99999 took 22.6 ms).
- Gain: about 15-20 ms native (40-60 ms web) on every restart of the later levels. The R-key restart
  happens mid-run, so the stall is felt. Risk: low (only if the copy is not a deep copy). Effort: S.
- Note: `Levels.level_par` (20 mazes, **107 ms** cold) and `Levels.coin_keys` (10 mazes, **102 ms**
  cold) only run while migrating an old save (`progress.gd:353, 394`), and both are already cached. No
  action needed. Keep it that way: never call them from a menu that every player opens.

### F5. Rainbow skin: every goo frame and every label redraws on every frame (M-L)
- **scripts/ui/skin_text.gd:28-31** runs `recolor()` on every frame with the rainbow skin. That calls
  **goo_box.gd:42-53** `set_goo_color` → `emit_changed()` on every live GooBox, so every button and
  panel runs **goo_box.gd:96-153** `_draw` again: one `canvas_item_add_rect` per pixel through a GDScript
  lambda. It also changes theme colors (`skin_text.gd:50-60`, a theme-changed cascade) and every label's
  `font_color` override (the label's text is re-shaped).
- Measured (native, headless): a 64x13 button takes 0.11 ms per redraw, 120x13 takes 0.18 ms, a
  200x100 panel 0.60 ms, a 280x150 panel 0.82 ms. A menu with about 11 buttons and 2 panels costs about
  **3 ms of CPU per frame** just for the goo frames. On WASM, expect **9-15 ms per frame, most of a
  60 fps budget**, plus the label re-shaping. Only the rainbow skin is affected: with any other skin
  `set_goo_color` returns early.
- Fixes that keep the look:
  1. Cache each box's pixel list (position + shade key) by (canvas item id, size, state). A recolor
     then only issues the rects, with no RNG or lump maths.
  2. Better: bake each box once into a small index image (one channel = shade id) and draw it as a
     single texture with a 6-color palette shader. A recolor becomes a uniform update with no redraw.
     The pixels are identical, because filtering is nearest.
  3. Skip `recolor` work for nodes that aren't visible (`is_visible_in_tree()`).
- Do not throttle the rainbow update rate (for example to 15 Hz). **FIDELITY RISK - do not apply**:
  the color flow would visibly step.
- Gain: about 3 ms → under 0.3 ms native per frame on rainbow menus (estimate, about 10 ms on web).
  Risk: M (visual parity must be checked with screenshots). Effort: M (1, 3) / L (2).

### F6. Shaders compile on first use, and on the web that is a visible hitch (M)
- Nine `.gdshader` files plus the CanvasItemMaterial blend-mode variants (additive light, motes,
  trail glow). The `gl_compatibility` renderer compiles each one the first time something draws with
  it, and WebGL has no persistent shader cache. The first entry to a level compiles `fog` (6.3 KB,
  loops and noise), `trail`, `atmosphere`, `slime_skin`, the additive variants and `rainbow_hat`. The
  first hub visit compiles `hub_room` (7.1 KB). On Windows browsers (ANGLE → D3D11) these compiles often
  take tens to hundreds of ms each.
- Fix: in the title scene (or the Transition autoload), draw a 1x1 ColorRect/Sprite2D with each
  material for 2 frames, placed under the opaque backdrop (2D does no occlusion culling, so it still
  draws). Done once per session, it leaves nothing visible on screen.
- Gain (estimate, not measurable headless): removes a 50-300 ms first-entry hitch on the web, mostly
  hidden under the goo wipe today but felt as a long cover. Risk: low. Effort: M.

### F7. The Web build ships files it doesn't need (S)
- **export_presets.cfg:46** `exclude_filter="tests/*, tools/*, docs/*, .claude/*"` misses `build/*`.
  An earlier export in `build/web/` is inside the project folder, so Godot imports
  `index.png`, `index.icon.png` and `index.apple-touch-icon.png` and ships them again in the pck
  (about 15.6 KB). It also rescans the build output on every editor or headless start.
- (Resolved 2026-10-15: these unused files were deleted in spring cleaning.) Unused assets that were still exported: `assets/sprites/walls.png` (pre-theme level art, 11.2 KB ctex;
  the game loads `themes/dungeon_walls.png`), `assets/sprites/fillets.png` (byte-identical to
  `themes/dungeon_fillets.png`), `assets/ui/button_{normal,hover,pressed,disabled}.png` (GooBox replaced
  them). The generators in `tools/` still write them; check before deleting.
- Fix: add `build/*` to both presets' exclude filters (and/or put an empty `build/.gdignore` there), and
  exclude or remove the unused PNGs.
- Gain: about 27 KB of pck and fewer files to import. Small, but free. Risk: none. Effort: S.

### F8. Web audio: the first play of each sound decodes it on the main thread (S-M)
- The Web build has no threads, so Godot 4.7 uses **Sample** playback: on its *first* play, each
  stream is decoded from QOA to float PCM and handed to WebAudio as an AudioBuffer. That first play
  lands mid-game: the first jump, coin or splat, every ambient one-off as it first comes up, and the
  24 s bed at level start (529,200 samples).
- **scripts/game.gd:449-470** loads the bed and all 6-8 one-offs while the level loads (native: 3 ms
  per theme, cheap), but they are only registered as samples when they first play (**game.gd:490-493**,
  mid-run).
- Fix: right after loading, call `AudioServer.register_stream_as_sample(stream)` (Godot 4.3+, marked
  experimental) for the bed and the one-offs while the goo wipe covers the screen, and for the 20 SFX
  once `Sfx` unlocks audio on the first input (**sfx.gd:36-43**). The sound doesn't change, because the
  same buffers are only made earlier.
- Gain (estimate): removes 1-10 ms decode hitches during play on the web. Risk: low (the API is marked
  experimental). Check that sound on/off and the volume still apply. Effort: S.
- Memory note: in sample mode a theme's bed is 24 s x 22,050 x 4 bytes = **2.1 MB** of float PCM in
  WebAudio, plus about 1.5-2.5 MB for its one-offs and about 1.2 MB for the SFX. That is about 5 MB per
  level. It is freed when the level scene is freed (the arrays drop their references). No action needed.

### F9. Audio data size: already efficient, and the remaining savings would change the sound (FIDELITY RISK)
- All 97 WAVs are already **mono, 22,050 Hz, 16-bit**, imported with QOA (`compress/mode=2`, about
  71 kbps). The sources are 19 MB of WAV; the pck holds 3.96 MB.
- Options that would make the pck smaller but change the sound: Ogg Vorbis at about 40-48 kbps
  (beds 214 → about 130 KB each, about -1.5 MB of pck), shorter bed loops, a lower sample rate, 8-bit.
  **FIDELITY RISK - do not apply.**
- Option with no fidelity change: put each theme's ambience (about 380 KB) in its own small `.pck`
  and load it with `ProjectSettings.load_resource_pack` when the level is chosen. The initial
  download gets about 3.5 MB smaller (about 25 % of today's gzip total), at the cost of a short fetch
  per new theme. Risk: M (offline play, failed fetches, itch paths). Effort: L. Only worth it after F1.
- The loop point is set at run time (**game.gd:453-455**) on the shared cached stream. That is
  harmless; putting `edit/loop_mode=2` and `loop_end` in the bed `.import` files would be tidier but
  changes nothing.

### F10. Cold first loads of the big scenes (M)
- First loads, native: `main.tscn` **98-116 ms** (compiles game.gd, hud.gd, slime.gd and the rest),
  `story.tscn` **62-66 ms** (story_screen.gd, 1,544 lines), `hub.tscn` **41-47 ms**. Later loads are
  under 1 ms because the scripts stay cached. **transition.gd:45** loads synchronously after the cover
  closes, so the whole first load is a frozen, fully covered frame. On the web, expect 200-350 ms the
  first time a level opens.
- Fix (desktop): call `ResourceLoader.load_threaded_request(scene)` when the cover *starts*
  (`transition.gd:33`), then `change_scene_to_packed(ResourceLoader.load_threaded_get(scene))`, so
  loading overlaps the 0.22 s cover animation. Web (no threads): the same API falls back to
  synchronous loading. There, preload `main.tscn` and `story.tscn` during the title's idle time
  instead (one call deferred a few frames after the title shows).
- Gain: hides about 100 ms on desktop. On the web it moves about 300 ms off the first level start to a
  moment where the title is static. Risk: low-M (more memory: about 1-2 MB resident). Effort: M.

### F11. Fog and trail textures are re-uploaded whole (frame stability, M-L)
- **scripts/game.gd:900-906** `_flush_textures` calls `ImageTexture.update` on the full fog and trail
  images whenever they are dirty: every frame while gliding, and 16 times a second (`FOG_TICKS`) while
  standing still, because `_relight` (**game.gd:835-858**) restamps the cells around the slime. Level 10
  is 440x248 RGBA8 = 436 KB per image, so up to **873 KB of texSubImage2D per frame** (about 52 MB/s).
  Desktop doesn't mind; low-end phones in WebGL can lose 1-3 ms per frame and get uneven frame times.
- Fixes that keep the look: (a) update only the dirty rows. That needs a texture per horizontal band,
  and the fog shader samples neighbors, so the bands would need a 1-cell overlap: **check parity
  carefully, otherwise FIDELITY RISK**. (b) Cheap and safe: skip the `_relight` write when the fade
  table says nothing would change visually. Only valid if the decoded alpha is the same; otherwise
  **FIDELITY RISK**.
- Gain: estimated 0.5-3 ms per frame on mobile web. Risk: M. Effort: M-L. Profile on a phone first;
  this may already be covered by the rendering review (`docs/perf/rendering.md`).

### F12. Small per-frame or startup work in autoloads (S, small gain)
- **scripts/ui/rotate_hint.gd:28-29** calls `DisplayServer.window_get_size()` and
  `is_touchscreen_available()` (a JS call on the web) in `_process` on every frame, on every device. It
  also builds a whole `UIKit.make_theme()` (3.0 ms measured) plus a label at startup, even on desktop.
  Fix: on non-touch devices, `set_process(false)` and build the cover lazily the first time it is
  needed. On touch devices, react to `get_viewport().size_changed` instead of polling. Gain: about
  3 ms startup and a few µs per frame. Risk: none. Effort: S.
- **scripts/sfx.gd:20-30** creates 60 AudioStreamPlayers and loads 20 WAVs eagerly (7.3 ms with the
  loads cached; the cold loads add a little more at boot). Idle players cost nothing to mix. Fix if
  wanted: one voice per sound at boot, and more added when all are busy (same overlap behaviour). Gain:
  about 3-5 ms of boot and about 40 fewer nodes. Risk: low. Effort: S. Low priority.
- `UIKit.make_theme()` (3 ms) is called by 7 places, once per screen or popup. Theme colors are
  mutated per screen by SkinText, so a shared theme would need care. Gain: about 3 ms per screen.
  Effort: S-M, low priority.

### F13. Project and export settings (checked, mostly right)
- Correct already: `gl_compatibility`, nearest filtering, every texture lossless with no mipmaps
  (pixel art must stay lossless; **any VRAM or lossy compression is a FIDELITY RISK - do not apply**),
  `script_export_mode=2` (compressed binary tokens), threads off (best itch compatibility), GDExtension
  support off (smaller), no bus effects (fine with Web Sample playback).
- Low-processor mode, lower physics ticks or a lower max FPS: no. The menus and hub animate all the
  time, and lower physics ticks would change the feel. **FIDELITY RISK - do not apply.**
- `physics/common/physics_interpolation`: would smooth movement on 120 Hz displays, but it changes how
  motion looks with `snap_2d_transforms_to_pixel`. **FIDELITY RISK - do not apply** without the
  user's say-so.
- `vram_texture_compression/for_desktop=true` on the Web preset changes nothing (no texture uses VRAM
  compression), so it is harmless.

## Suggested order
1. F2 (check compression on itch) and F7 (exclude filters): minutes, no risk.
2. F3 and F4 (caching mazes and TileSets): small code, deterministic, removes most stalls on screen
   changes and restarts.
3. F8 and F12: small, removes web audio first-play hitches and per-frame waste.
4. F6 and F10: hide first-time hitches (shader compiles, cold scene loads).
5. F5 if the rainbow skin is common; F1 (custom template) for the biggest download win; F11 after
   profiling on a phone.

## Side effect of this review (please read)
At 20:05:10 local time, the save at
`~/Library/Application Support/Godot/app_userdata/Slime Time/save.cfg` was rewritten. My first headless
probe instantiated `main.tscn` without turning off saving, and `Progress.equip_first_run_skin`
(`progress.gd:957`) saves. Another agent was also running game scenes at that moment. The file now
holds a fresh test-default state (levels_cleared=0, story_seen=3). If this Mac had real progress,
restore it from the user's copy (the handoff mentions `Desktop/SlimeTime-for-Mac/save.cfg` on
OneDrive). All later probes were load-only and left the file untouched.

The same risk exists in the repo: when a script under `res://tests/` runs, `Progress` skips loading
the save (`progress.gd:178-181`) but leaves `saving_enabled` on. So any test that plays a level, such as
`test_phase1.gd` (which has no save_path or saving guard), can overwrite the real save. Suggested
follow-up: set `saving_enabled = false` (or point `save_path` at a test file) whenever
`_is_test_or_tool_run()` is true.
