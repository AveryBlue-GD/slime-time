# CPU performance pass (GDScript side) - 2026-10-13

Scope: every per-frame / per-tick script path, load-time maze work, and hitches. Goal: higher frame rate and no
hitches with **identical visuals and behavior**. Anything that would change look or feel is marked
**FIDELITY RISK - do not apply**. Companion reports: [rendering.md](rendering.md) (GPU, texture uploads) and
[startup-memory-web.md](startup-memory-web.md).

## How this was measured

- Headless Godot 4.7.2 on an Apple M3 (`--headless --fixed-fps 60`), dummy renderer: the numbers are **script,
  layout, text shaping and canvas-command recording only**. GPU work and texture uploads are not included (see
  rendering.md). Benchmarks live outside the repo in `/private/tmp/claude-501/bench_cpu/` (`bench_game.gd`,
  `bench_fog_fast.gd`, `bench_crescent.gd`, `bench_scene.gd`, `bench_rainbow.gd`, `bench_goobox.gd`,
  `bench_load.gd`, `bench_bfs.gd`, `tail.gd`, `bench_story.gd`, `bench_reload.gd`, `phys.gd`). Saving was off in
  every run; the real save was only read.
- **Phone estimate:** GDScript on a mid-range Android phone is roughly 4-8x slower than the M3, and the web (WASM)
  build a further ~1.5-2x. Treat "phone" numbers below as that multiplier applied to measured M3 numbers.
- "Identical" claims marked *verified* were checked byte-for-byte / pixel-for-pixel against the current code.

## Verification of the earlier perf pass

| Item | Status |
|---|---|
| Separate `fog_dirty` / `trail_dirty` flags (`game.gd:150-151`, `_flush_textures` 900-906) | Holds. |
| Gated `_relight` (`_relit_tick/_relit_cell/_relit_radius`, `game.gd:835-842`) | Holds, but the gate opens on every 2 px cell change, so while gliding it still runs on ~55% of physics ticks (measured avg 488 us/step at reach 25 vs 884 us per forced call). |
| Int fog helpers (`_fog_packed`, `_fog_lit_ticks`, `_fog_color_ticks`) | Hold in `_relight`, but `_relight` still reads the same pixel twice (853-854), and `_reveal_light` / `_paint_cells` still build a float `Color` via `_fog_color()` per cell. |

## Baseline (M3, headless)

| Situation | Mean frame | Notes |
|---|---|---|
| Gameplay L10, autopilot gliding, Brightness 0 | 0.24 ms | `_paint_goo` 51 us/tick, `_relight` ~100 us/tick |
| same, Brightness 5 (reach 12.5 px) | 0.66 ms | |
| same, Brightness 10 (reach 25 px) | **1.27 ms** | `_relight` 488 + `_reveal_light` 590 us/tick -> **~7-10 ms/tick on a phone** |
| Menus, normal skin (title/hub/level select/skins/upgrades/settings) | 0.04-0.07 ms | fine |
| Menus, **rainbow skin** | **1.6 (title) / 8.0 (hub) / 8.8 / 13.2 (skins) / 10.2 / 10.1 ms** | 150-200x the normal skin |
| Gameplay, **rainbow skin**, standing still | **4.4 ms** (vs 0.075) | |
| Story cinematics | 0.1-0.74 ms | worst: "run" 0.49, "search" 0.74 |
| Randomizer maze build, MORE SLIME 10 (1,500 seeds) | mean ~19 ms, p99 108 ms, **max 783 ms** | 16 of 1,500 seeds > 100 ms |
| Level retry/next (main `_ready`, L10) | 40-49 ms + 11 ms first frame | |
| Opening any menu (MenuBackdrop `_ready`) | 18.8 ms | |

Physics is not a problem: 1 active body, wall collision merged by `physics_quadrant_size = 16` (972 wall tiles),
`move_and_slide` ~1 us. Note `max_physics_steps_per_frame = 8`: on a slow device each extra catch-up tick re-runs
the fog work below, so a heavy tick can snowball. Do not lower the cap or the 60 Hz tick (**FIDELITY RISK - do not
apply**: slow motion / different feel); make the tick cheaper instead (findings 2-3).

---

## Ranked findings

### 1. Rainbow skin: `SkinText` re-themes the whole UI and redraws every goo frame, every frame
- **Where:** `scripts/ui/skin_text.gd:28-62` (`_process` -> `recolor`), `scripts/ui/goo_box.gd:43-53`
  (`set_goo_color` emits `changed` on **every** live GooBox), `goo_box.gd:96-152` (`_draw`).
- **Issue (measured breakdown, M3):**
  - `GooBox._draw` paints the frame as **one `canvas_item_add_rect` per pixel through a `Callable` lambda**
    (`put.call`, 106-107): a 90x13 button = 481 rects, **130 us**; a 200x120 panel = 2,319 rects, **590 us**.
    Rainbow makes every box redraw every frame (skins screen: 28 boxes).
  - `set_goo_color` -> each box's `changed` -> its Theme re-emits -> `NOTIFICATION_THEME_CHANGED` down the tree, once
    **per box**. GooBox part alone: 5.3 ms/frame (skins), 2.6 (hub), 1.5 (gameplay).
  - The theme edits in `recolor` (10 `theme.set_color` + 4 StyleBoxFlat colour changes) each propagate separately:
    7.6 ms/frame (skins), 4.7 (hub), 0.9 (gameplay).
  - Gameplay has **3 SkinText nodes** (HUD `hud.gd:188`, pause menu `pause_menu.gd:65`, restart prompt
    `restart_prompt.gd:42`), each doing the full group loop + `set_goo_color` every frame, even while hidden.
  - The label overrides themselves are cheap (0.14-0.45 ms).
- **Fidelity-preserving fix:**
  1. **GooBox geometry cache + run merging** (biggest lever). The lumps/drops/highlight pattern depends only on
     `(item id, size, state/kind)` (the RNG is seeded from those), not on the colour. Cache per box the list of
     `(rect, shade key)` built by replaying the current algorithm into a small grid (last write wins, as with the
     opaque rects now) and merging horizontal runs of the same shade; `_draw` then just replays the cached runs with
     the current shades. *Verified pixel-identical* (button and panel): 481 -> 107 rects and 2,319 -> 931 rects;
     replay **7.4 us vs 130 us (17x)** and **66 us vs 596 us (9x)**. Colours are opaque in `Skins.shades` and
     `DRIED`; keep the face rect first, as now (the panel face has alpha 235). Even the minimum version - inline
     `RenderingServer.canvas_item_add_rect` calls instead of `put.call` - removes the lambda dispatch per pixel.
  2. **Batch the theme edits** in `recolor`: `theme.set_block_signals(true)` (and on the two slider/focus
     StyleBoxFlats), apply all colours, unblock, then one `theme.emit_changed()`. All values land before the frame
     draws, so the result is identical. Measured for the colour part: 7.6 -> 2.5 ms (skins), 4.7 -> 0.44 (hub),
     0.91 -> 0.15 (gameplay); most of what is left is the GooBox redraw that fix 1 shrinks.
  3. **One recolor of the shared state per frame:** the group-label loop and `GooBox.set_goo_color` are global, so
     only the first SkinText to run in a frame needs to do them (guard with `Engine.get_process_frames()`); each node
     still updates its own `theme_owner`. Identical because the three gameplay SkinTexts are created in the same
     frame and share the same `_time` sequence (if one were ever created later, "first wins" instead of "last wins"
     would shift its hue phase: check before applying there).
  4. In `GooBox.set_goo_color`, emit once per affected Theme rather than once per box (track the themes
     `UIKit.make_theme()` builds; boxes used as direct overrides, e.g. the hub prompt, still emit their own).
- **Gain (estimate from the measured parts):** rainbow menus 8-13 ms -> ~1-2 ms/frame on M3 (phone: from
  ~40-100 ms, i.e. 10-25 fps, to a comfortable 60); rainbow gameplay 4.4 -> ~0.5 ms. Fix 1 also shortens the first
  frame of every menu for every skin (all boxes draw once on open, e.g. ~4-5 ms of the skins screen's first frame).
- **Do not:** recolor at a lower rate, or move the rainbow into the text shader / `modulate` (shadows and
  timing would change) - **FIDELITY RISK - do not apply**.
- **Risk:** low (1, 2), low-medium (3, 4). **Effort:** M.

### 2. Fog CPU per physics tick: `_relight`, `_reveal_light`, `_paint_cells` walk every cell of a disc through `get_pixelv` / `set_pixelv`
- **Where:** `scripts/game.gd:835-856` (`_relight`), `861-874` (`_reveal_light`), `801-821` (`_paint_cells`),
  per-cell helpers `is_wall_tile` (597 -> `maze_generator.gd:296`, two Dictionary lookups per call, 0.44 us),
  `_cell_pos`, `_fog_color`.
- **Issue:** each run visits the whole bounding square of the disc (radius 20 + reach for `_relight`, 9 + reach for
  `_reveal_light`) with several Variant calls per cell. At Brightness 10 that is ~2,100 + ~1,200 cells per tick:
  **relight 488 us + reveal 590 us + paint 51 us per tick (M3)**, i.e. ~7-10 ms per tick on a phone, and up to 8
  ticks per frame when the device falls behind. Brightness is an upgrade most late-game players own.
- **Fidelity-preserving fix (prototyped and verified):**
  1. Keep the fog (and trail) bytes in a persistent `PackedByteArray` as the source of truth and read/write bytes
     directly (`i = (cy * w + cx) * 4`); push them into the Image only in `_flush_textures`
     (`Image.set_data`, 12 us even for the 600x344 maximum). `fog_alpha_at` and tests read the bytes (or the Image
     after a flush). Colour8 round-trips exactly through RGBA8 (checked for all 256 values), so the bytes are the same.
  2. Per row, compute the exact span of cells inside the disc (sqrt estimate, then the ends fixed with the
     **original** float32 test `Vector2.distance_squared_to <= r*r` / `distance_to <= r`), instead of testing every
     cell. Tile of a cell = `(2*c - 15) >> 4` (exact integer form of `floor(_cell_pos / 16)`); read `maze.walls` /
     `maze.size` into locals once per call (re-read after `_break_wall`).
  3. "Crescent" updates: within one fog tick, `_relight` only needs cells that are new since its last run (all
     others already hold this tick); `_reveal_light` / gliding `_paint_cells` only need cells outside the previous
     disc of the same radius (revealed/painted cells never go back). Full passes only on a new tick or a radius change.
  4. Compute `_fog_color(elapsed, elapsed, false)` and the goo colours once per call, not per cell; read the pixel
     once in `_relight` (853-854 read it twice).
- **Verified:** replaying the real glide (L4 and L10, Brightness 0/5/10, 1,240-2,540 physics steps including a
  standing-still stretch) with steps 1-3 gives **byte-identical fog after every single step**.
- **Gain (measured, M3):** `_relight` 97 -> 53 us/tick (reach 0), 256 -> 92 (reach 12.5), 488 -> 149 (reach 25);
  `_reveal_light` fog part 247 -> 78 (12.5), 590 -> 135 (25). Total at Brightness 10: ~1.15 ms -> ~0.35 ms per tick
  (**3.3x**); phone: roughly 8 ms -> 2.5 ms per tick. (Caching the previous row spans instead of recomputing them
  would cut the crescent version further; not measured.)
- **Risk:** low-medium (pure refactor, but the fog is central: keep the byte-for-byte replay test as a unit test).
  **Effort:** M.
- **Do not:** move "still lit" into the shader with a slime-position uniform (cell-centre maths in mediump on phones
  could flip boundary cells) - **FIDELITY RISK - do not apply** unless proven exact.

### 3. Fog/trail texture uploads (CPU/driver side)
- **Where:** `game.gd:900-906`; triggered by finding 2 writes.
- **Issue:** `ImageTexture.update` re-sends the whole image: 184x120 (L1) to 440x248 (L10) to 600x344 (largest
  randomizer) RGBA8, i.e. 0.09-0.83 MB **each**. While gliding the trail changed on 99% of physics ticks in the
  benchmark, so both textures go up nearly every tick (up to ~1.65 MB/tick); while standing still `_relight` still
  dirties the fog 16 times a second. Not measurable headless (dummy renderer); covered in detail in
  rendering.md #1 and #2.
- **Fidelity-preserving fix (CPU side):** only set `fog_dirty` from `_relight` when the slime's cell or the radius
  changed, or when the last upload is more than ~1 s old. Cells inside the light disc have an age below 1.5 s
  (`FADE_AFTER[0]`) either way, so the shader shows the same first band, and any paint/reveal/cell change still
  uploads at once with exact data (rendering.md #2 describes the same idea in more detail). Moving-time uploads need
  chunked textures with an apron (rendering.md #1) - partial uploads via `DrawableTexture2D.blit_rect` exist in 4.7
  but are unproven on Compatibility/WebGL for bit-exact RGBA8 data: **FIDELITY RISK until verified bit-exact**.
- **Gain:** idle fog uploads 16/s -> ~1/s. **Risk:** low. **Effort:** S (throttle), L (chunks).

### 4. Randomizer maze build: worst-case hitches of 0.1-0.8 s (M3), seconds on a phone
- **Where:** `scripts/spawn_picker.gd:107-133` (`pick`: up to 24 BFS per class, then a full rescan),
  `spawn_picker.gd:83` (`farthest`), `139` (`cell_at_distance`), `maze_generator.gd:331-352` (`distances_from` /
  `open_neighbors`: Dictionary + a new Array per visited cell, ~2-3 us per cell), `ticket_spawn.gd:31-58`.
- **Issue:** at MORE SLIME 10 over 1,500 seeds: mean ~19 ms, p99 108 ms, **max 783 ms** (seed 1187783036), 626 ms,
  368 ms... The worst seed measured in detail spent 133 of 145 ms in `SpawnPicker.pick` (one `generate_noise` is only
  7.4 ms). This happens on every NEW MAZE **and every RESTART of the same maze** (game.gd:266 rebuilds it).
- **Fidelity-preserving fix:**
  1. An array BFS (`PackedInt32Array` distances indexed `y * cells.x + x`, int queue, neighbours read straight from
     `maze.walls` in the same RIGHT, LEFT, DOWN, UP order). *Verified:* identical distances on 195 BFS runs over
     36x20 mazes, **0.19 ms vs 1.57 ms per BFS (8.1x)**. Use it wherever the result is read row-major or by cell:
     `farthest`, `diameter`, `cell_at_distance`, `TicketSpawn.candidates/trip_fits`, `_add_loops`
     (`maze_generator.gd:255`), `dead_end_depths`. Where the code iterates the Dictionary in insertion order
     (`generate`/`generate_noise` goal pick: first cell with the max distance), iterate the BFS queue array in order
     instead - it is the same visit order.
  2. Keep the last built randomizer maze in a static cache keyed by `(seed, seed level, hard)` and hand out a deep
     copy (`duplicate(true)`: 0.002 ms; `_break_wall` mutates `maze.walls`, which copy-on-write keeps separate), so
     RESTART after a dry-up costs nothing.
- **Gain:** worst case ~783 -> ~100 ms (M3), typical 19 -> ~3-4 ms; retries ~0. **Risk:** low (deterministic,
  checkable against the existing seeds/tests: `test_random_usage`, `test_seed`, `test_random_tickets`).
  **Effort:** M (1), S (2).

### 5. Every retry / next level rebuilds the same story maze, tile set and coin list
- **Where:** `game.gd:271` (`generate_level`, 18.9 ms at L10, 14.8 at L8: `_add_loops` runs a full BFS per
  candidate), `maze_tiles.gd:116` (`make_tile_set`: 5.6-7.4 ms, 576 wall tiles each get a collision polygon),
  `game.gd:323` -> `Levels.coin_cells` (4 ms at L10).
- **Issue:** main `_ready` is 40-49 ms at L10 (M3, + 11 ms first frame), ~0.3-0.5 s on a phone, on every RESTART
  (the most common action after a dry-up) and NEXT LEVEL.
- **Fix:** static caches - story maze per `(level, hard)` (return `duplicate(true)`), TileSet per theme (layers can
  share it; `_break_wall` only changes cells), coin cells per level. All are pure functions of constants, so the
  result is identical. Fast BFS (finding 4) also makes the first build ~3x cheaper.
- **Gain:** ~28 of 40 ms per retry on M3 (~70%). **Risk:** low. **Effort:** S.

### 6. Every menu screen rebuilds the backdrop maze and its tile set
- **Where:** `scripts/ui/menu_backdrop.gd:18-50` (`MazeGenerator.generate` 3.4 ms + `make_tile_set` ~7 ms +
  `MazeTiles.fill`): **18.8 ms per screen open** on M3 (~100-150 ms phone hitch on every menu change).
- **Fix:** static cache of the backdrop maze (fixed seed `MAZE_SEED`) and the dungeon TileSet (shared with finding
  5). Identical. **Gain:** ~10-12 ms per menu open (M3). **Risk:** low. **Effort:** S.

### 7. Story cinematics allocate on every frame
- **Where:** `scripts/ui/story_screen.gd`: `_bayer` builds a 4-element Array literal per brick
  (768-769; ~240 bricks a frame in run/chase/crack), `_flame` an Array literal per flame (921-929), `_heroes()` builds
  3 Dictionaries and is called once per spark in `_emit` plus in `_draw` (777-805, 437-470), particles are
  Dictionaries read with `.get()` / `has()` (473-556, up to 220 parts, per 1/30 s substep).
- **Measured:** 0.27-0.74 ms/frame (M3) -> ~2-6 ms on a phone.
- **Fix:** const arrays for `_bayer`/flame heights (`const BAYER := [0.0, 0.5, 0.75, 0.25]`), compute `_heroes()` once
  per step/draw and reuse, a small typed inner class (or parallel PackedArrays) for particles with the same
  update order. Same RNG call order, so identical output.
- **Gain (estimate):** 20-40% of the story frame. **Risk:** low (keep RNG call order). **Effort:** S-M.
- **Do not** cap/reduce particles or substeps - **FIDELITY RISK - do not apply**.

### 8. `Fx.make_light` makes a new Gradient + GradientTexture2D + CanvasItemMaterial every call
- **Where:** `scripts/fx.gd:10-31`; called for each coin (`coin.gd`, up to 31 a level), the chalice, ticket, slime
  light, hub pools (`Fx.make_pool`, 7), and every glimmer (`game.gd:572`).
- **Issue:** each light is its own texture (generated and uploaded) and its own material, which also splits draw
  batches. Cheap headless (8 us), but it is load-time texture creation and GPU state churn on phones.
- **Fix:** cache textures by `(width, height)` and share one additive `CanvasItemMaterial`; per-light colour stays
  in `modulate`. Identical. **Gain:** small per frame, fewer textures/uploads at load. **Risk:** low. **Effort:** S.

### 9. One-time save migration builds all 20 story mazes
- **Where:** `progress.gd:346` (`_migrate_coins` -> `Levels.coin_keys`, 116 ms cold) and `_migrate_medals` ->
  `Levels.level_par` (114 ms cold for 20 mazes). Only for saves older than version 4, once (then written back).
- **Fix:** none needed beyond fast BFS (finding 4), which cuts it ~3x. **Effort:** none extra.

### 10. Small per-frame items (low value; apply only alongside other work)
- `hub.gd:518` `station == near` and `hub.gd:673` `best == near` are deep Dictionary compares (station dicts hold
  `anims`/`seq` arrays) every frame/tick; use `is_same(station, near)` in `_process` (identical, `near` is the same
  object). Keep `==` (or compare ids) in `_update_near`, where the rotor entry is a fresh dict each tick.
- `controls.gd:294` builds the FULLSCREEN label string every frame (Button ignores an equal text, so only the string
  allocation is wasted) - set it when it changes.
- `game.gd:977` `coins.duplicate()` every physics tick (3 us with 31 coins) - iterate backwards instead.
- `hat.gd:81,107` / `slime.gd:152,206` format two `"%s:%d"` keys per frame for the head-point caches - key by
  `anim` StringName + frame int in a nested dict.
- `hud.gd:295` / `hud.gd:193` format the timer and meter text every physics tick (1.65 us together) - fine as is.
- Allocation churn: GDScript is reference-counted (no GC pauses), so churn costs malloc time only; the items above
  are the only ones in hot paths.

## Not problems (checked)

Coins, chalice, ticket, hat, tutorial cues, jump guide, touch controls, ambient particles, `Sfx` (all sounds are
preloaded once in `_ready`; no first-play hitch), ambience bed loads (2-3 ms cold), `RotateHint`, `MenuBackdrop`
drift, HUD per-tick updates, physics shapes/bodies, `Glimmer` drawing: all well under 0.05 ms per frame on M3.

## Suggested order

1. Finding 1 (rainbow), fixes 1+2 - largest frame-rate win anywhere, small blast radius.
2. Finding 2 (fog bytes + spans + crescent) with the byte-for-byte replay as a test.
3. Findings 4 and 5 (fast BFS + caches) - removes the long randomizer hitches and makes retries instant.
4. Findings 6, 3 (throttle), 7, 8; then 10 as cleanup.
