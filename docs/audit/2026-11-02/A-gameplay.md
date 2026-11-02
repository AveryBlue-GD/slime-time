# Audit A: gameplay core (read-only, 2026-11-02, branch cleanup/audit-2026-11-02)

Scope (all read in full): scripts/game.gd, slime.gd, maze_generator.gd, maze_tiles.gd, levels.gd, level_data/*.gd,
lurkers.gd, light_life.gd, fx.gd, coin.gd, coin_catch.gd, chalice.gd, goo_drop.gd, ghost_racer.gd, ticket_goal.gd,
ticket_pickup.gd, spawn_picker.gd, jump_guide.gd, ambient.gd, themes.gd, scenes/main.tscn, slime.tscn, chalice.tscn,
assets/shaders/*.gdshader. Nothing was run; every caller claim below was checked with a repo-wide grep (scripts/, scenes/, tests/, tools/, bench/).

## 1. Map

**Scene tree (main.tscn).** `Main` (Node2D, game.gd) holds the TileMapLayers Floor, Walls, Border (colliding ring), Bedrock
(collision off), then `Trail` (Sprite2D z1), `Fillets` (z2), `Fog` (Sprite2D z10), the `Chalice` instance (Area2D z11,
CircleShape r6), the `Slime` instance (CharacterBody2D z11, circle r7, children Shadow, AnimatedSprite2D `Sprite`, JumpGuide, Camera2D),
and three CanvasLayers: HUD (hud.gd), PauseMenu (PROCESS_MODE_ALWAYS), TouchControls. Built at runtime: `outer_fog`, `slime_light` (z11),
the `Ambient` motes (absolute z9), coins / tickets / goo drops (z6, under the fog), `Lurkers` (bodies z6, `EyeLayer` z12),
`GhostRacer` sprite (z10), glimmers (z11), `RestartPrompt`, `AbilityRunner`/`AbilityCoach`, `Hat`, Fx particles (absolute z12).

**Per file.**
- `game.gd` (3,539 lines): everything about one run. `_ready` picks the mode (training / Descent / randomizer incl. daily, weekly,
  demo preview / story), gets the maze (`Levels.story_maze` deep copy, or static `_random_cache` via `MazeGenerator.generate_random`,
  or `Training.build_maze`), calibrates `slime_cost_per_tile` from the route (`goal_steps`), applies upgrades / workshop / Descent boons,
  assist / RELAXED, skin + trail look, tiles (`MazeTiles.fill` + `add_border`), ambience, overlays, coins, tickets, drops, goal, hat,
  abilities, tutorial cues, camera limits, first paint, lurkers, ghost. Also: the fog/trail reveal engine (lines ~1105-1664),
  coins / magnet / glimmers, randomizer attempts and pay (`payout`, `_pod_inputs`), Descent, survey (trail maps), result flow
  (`_on_goal_body_entered`, `_dry_up`, `_dry_hold`, `_finish`, `_offer_retry`, `_offer_next_steps`), dev toggles F1/F2.
- `slime.gd`: movement state machine GLIDE / CHARGING / AIRBORNE / STUNNED / DASH; sprite-frame building from slime_sheet.json,
  pixel measurements (`head_point`, `_body_rows`, `body_box`, cached in static `_heads`), physics-interpolation helpers
  (`_mark_tick` on `SceneTree.physics_frame`, `drawn_shift`), hit feedback, SLIMAKAZE afterimages.
- `maze_generator.gd`: growing-tree (`generate`, `_grow_level` + `_add_loops`), noise maze (`generate_noise`), randomizer sizing loop
  (`generate_random` + `add_second_route` via bridge finding), hard levels (`generate_hard_level`); flat-array BFS `_bfs`
  (static scratch `_order`/`_visited`), `cell_links`, `shortest_path`, `dead_end_depths`.
- `spawn_picker.gd`: start/goal pick per seed and class with the `_Reach` eccentricity-bound cache. `levels.gd` + `level_data/*.gd`:
  level recipes loaded by path (demo-safe), hard tables, randomizer route/size maths, pars, coin cells, static caches.
- `maze_tiles.gd`: tile variant fill with a one-entry static cache, border ring/bedrock, TileSet build (collision squares) cached per theme.
- `lurkers.gd`: BM-01 grid hunters (static rules + per-run node), contact damage, push, near-miss slow-mo (toggles the game's and
  slime's physics processing), `EyeLayer` drawn over the fog.
- `light_life.gd`: fog-shader uniforms for LIGHT & LIFE. `fx.gd`: shared dithered light sprites (texture cache per size + one
  `light_dither` material), particle bursts, drips, story halos. `ambient.gd`: per-theme CPUParticles2D motes following the view.
- `coin.gd`, `chalice.gd`, `goo_drop.gd`, `ticket_goal.gd`, `ticket_pickup.gd`: pickups/goals, each with a `_process` animation and a
  `Fx.make_light` glow. `coin_catch.gd`: the catch show (child of the slime, physics priority 1). `ghost_racer.gd`: daily / weekly /
  story ghost record + replay. `jump_guide.gd`: charge meter and landing dots. `themes.gd`: theme ids, names, atlas paths, fog colours.

**Game loop.** Physics 60 Hz. Tree order runs `Main._physics_process` before the Slime's, so game logic reads the slime position from
the previous tick: `_relight` (always) -> early out when finished / preview card / hold -> survey step, run clock, ghost, drain
(ground distance x cost; airborne free, knockback free), `_paint_goo` + `_reveal_light`, `lurkers.step`, pickups (coins, tickets, drops,
coin reveal), glimmer distance, goal reveal (24 px), refills, HUD meter, low-slime heartbeat, orchestra, dry-up / SECOND WIND / bladder.
`_process` (render rate): attempt/pot pod diff, fog uniforms (`now`, `slime_px`, `view_center`) on both fog materials, motes follow,
LIGHT & LIFE frame (hit-stop countdown, sunrise), camera lead (pixel-locked camera when the slime is interpolated), ambience, shake,
then `_flush_textures`.

**Rendering.** Fog and trail are RGBA8 images, one texel per 2 px cell, covering maze + 1-tile border; the CPU source of truth is
`_fog_bytes` / `_trail_bytes` (PackedByteArray). Writes: `_paint_cells` (goo + reveal, exact disc spans via `_disc_runs`, crescent skip
for repeated radius), `_relight` (restart lit time, lazy upload window `LAZY_RELIGHT_TICKS`), `_reveal_light`, `_reveal_wall`/`_fill_fog`,
`reveal_tile` (abilities). `_flush_textures` re-uploads the whole image with `ImageTexture.update` when dirty / lazy-due. `fog.gdshader`
decodes per cell (13-tap soft edge, Bayer dither, falloff, vignette, contact shadow, mist noise, LIGHT & LIFE, lights-out);
`outer_fog` is the same shader on a 1x1 texture (`solid`, `hole` discard). `trail.gdshader` bevels the goo; a child Sprite2D with
`trail_glow.gdshader` adds the halo (same texture). Lights use `light_dither.gdshader` (additive, world-locked Bayer). The slime uses
`slime_skin.gdshader` (palette swap, rainbow, jelly, clock, hit/rim/ghost). Draw order by z: tiles 0 < trail 1 < fillets 2 < pickups,
lurker bodies 6 < motes 9 < fog 10 (+ ghost racer 10, added later) < slime / chalice / ticket goal / lantern / glimmers 11 < hat,
eyes, particles 12 < float text 13; HUD on its CanvasLayer.

**Input.** The slime polls `Input.get_vector(move_*)` and `jump` each physics tick (charge on press, buffered 0.5 s while stunned /
airborne, launch on release). `game._unhandled_input`: `menu` -> pause menu, `restart` -> replay / retry / RestartPrompt, F1/F2 dev
toggles. `_dry_hold` polls jump / ui_accept / interact. Abilities are AbilityRunner's (out of scope).

**Physics / collision.** Walls: TileSet physics layer 0, a full 16x16 square on every wall atlas tile and on the border ring (bedrock
none). Gliding: `move_and_slide` with lane centring; knockback: `_ricochet` (`move_and_collide` up to 4 hits, `wall_bounce`) or the
soft-bounce slide; leaps: `_fly` steps `move_and_collide` along `_jump_dir` with `_slip_past_corner` (`test_move`, up to 3 px), landing ->
`jump_landed` -> game cost / stain / shake / wall damage / lurker bonk. Hit detection: goal = Area2D `body_entered` (chalice or
TicketGoal r6); coins / tickets / drops = distance checks in game (`Coin.REACH` 10 px, MAGNET reach with `clear_line` tile raycast);
lurkers = distance (`LURKER_CONTACT_DIST`) in `Lurkers.step`, push via `slime.move_and_collide`.

**Assets.** `preload`: shaders, slime sheet + json, coins.png, icon_ticket.png, lurkers.png. `load` by path: theme atlases
(`Themes.atlas_path`), level_data scripts (demo-safe), ambience WAVs (`ResourceLoader.exists` probe loop), demo end script.

**Data flow.** Reads from Progress: mode / seeds / current level, hard_mode, upgrades + workshop levels, skin / jelly / trail / hat,
reduce_motion, fog_brightness, sound_on, relaxed, dev flags, coins found, random attempt keys. Writes to Progress: `collect_coin`
(saved at once), `take_random_ticket`, `begin_random_attempt` + `random_moved` (+ `save_progress`), `record_clear` / `complete_level`,
`complete_random`, `record_daily` / `post_board` / `pay_weekly`, `record_survey` / `record_random_map`, `dry_ups`, Descent run updates,
`record_ghost`. Economy: tuning constants and test switches (`*_on()`). HUD: level text, area banner, meter, timer, coins pods,
attempt / pot pods, messages, choice rows, rewards, flash messages, vignette, dev badge.

## 2. Findings

Earlier perf audits, status for this area (not re-reported as new findings):

| Earlier item | Status |
|---|---|
| cpu #2 fog bytes + exact spans + crescent | fixed (`_fog_bytes`, `_disc_runs`, game.gd:1341-1509) |
| cpu #3 / rendering #2 idle relight uploads | fixed (lazy relight, game.gd:207-213, 1424-1426, 1649-1650) |
| cpu #4 array BFS + randomizer maze cache | fixed (`MazeGenerator._bfs` 624, `game._random_cache` 1935) |
| cpu #5 story maze / TileSet / coin caches | fixed (`Levels._maze_cache`, `MazeTiles._tile_sets`, `_fill_cache`, `story_coin_cells`) |
| cpu #8 / rendering #8 shared light texture + material | fixed (fx.gd:86-128); remnant = A-10 |
| rendering #5b outer fog `solid`; #6 atmosphere mist skip; #7 fog skip noise at alpha 0 | fixed (fog.gdshader:152, 241; atmosphere.gdshader:197) |
| rendering #1 whole-image fog/trail uploads (`_flush_textures`, game.gd:1655-1663) | **still open** (needs measurement on web/Android) |
| rendering #5a outer fog full-screen pass that discards inside the maze (fog.gdshader:147-150) | **still open** |
| rendering #10 every coin's `_process` (coin.gd:79-81) | **still open** (low) |
| rendering #12 hub_room per-pixel `cos/sin(-turn)` (hub_room.gdshader:131) | **still open** (low, hub only) |
| cpu #10 `coins.duplicate()` per tick (game.gd:2034; also tickets 1995, drops 2411) and `"%s:%d"` keys in `Slime.head_point` (slime.gd:233) | **still open** (low) |

New findings:

| id | sev | category | file:line | evidence | fix plan | behavior risk | conf |
|---|---|---|---|---|---|---|---|
| A-01 | medium | bug | scripts/game.gd:1591-1599, scripts/lurkers.gd:456 | Lurker stealth is `game._still_time > Economy.IDLE_GRACE`, but `_still_time` only grows inside `_idle_drain` after its drain gates: it returns before `_still_time += delta` when `relaxed_run` (1597), `dev_no_drain`, `not Economy.idle_drain_on()`, a SLIME SENSE peek, or before the first move (1592). Hard mode always has lurkers "even with RELAXED" (economy.gd:389-391, `Lurkers.allowed`), so a RELAXED player can never use the documented "stand still = stealth" rule. | Track stillness on its own counter (in `_physics_process` or Lurkers) not tied to the drain gates; keep the drain on `_still_time` as now. Or move the `_still_time += delta` above the relaxed/aim return and keep the drain check after it. | changes gameplay feel (stealth starts working under RELAXED / NO DRAIN) | high |
| A-02 | medium | bug | scripts/slime.gd:847-849 | The SLIMAKAZE afterimage takes `mat.duplicate()` of the skin `ShaderMaterial`, whose shades are vec4 colour params set by `Skins.apply_to`. game.gd:1298-1299 records that in this Godot version `ShaderMaterial.duplicate()` "drops color parameters, from both copies", which is why `_build_outer_fog` copies params by hand. If that holds here, the afterimage outline falls back to the shader default and the slime's own material may lose its skin colours after the first dash. No test covers it (grep: no check on skin params after a dash). | Build the ghost material like `_build_outer_fog`: `Skins.make_material(color, rainbow, clock)` (or copy params), then set `ghost`. First verify with one headless check of `sprite.material.get_shader_parameter("mid")` before/after `dash()`. | changes output only if the quirk applies (then fixes a visible bug) | low (needs a 1-line check) |
| A-03 | low | bug | scripts/game.gd:2862-2880 | `_dry_hold` loops on `await get_tree().process_frame` and `t += get_process_delta_time()`. Both keep ticking while the tree is paused, and the pause menu is PROCESS_MODE_ALWAYS (pause_menu.gd:71). Pausing in the 0.9 s hold lets it finish under the menu: DRIED UP and its pop-in run while paused, and the menu's ui_accept press also counts as "skip". | `if get_tree().paused: continue` before adding to `t`, and ignore the skip keys while paused. | none while unpaused | high |
| A-04 | low | bug (confirm intent) | scripts/ghost_racer.gd:304,308; scenes/main.tscn (Fog z_index = 10) | Ghost sprite `z_index = slime.z_index - 1` = 10, the same as the Fog, and it is added to Main after Fog, so tree order draws it over the fog. The pale ghost shows the best run's route through unexplored fog. The archived advisor note (docs/archive/advisor/juice-audio-ui.md:185) names that exact risk. Header says only "one frame below the slime". | Ask the owner. If it should hide in fog, use z 6-9 (under the fog, like coins) or show it only inside the lit radius. | changes output | high (mechanism) |
| A-05 | low | hygiene / bug | scripts/ambient.gd:15-17, scripts/game.gd:1265, 1960 | Motes are absolute z 9 (`z_as_relative = false`). The comments say "under coins" (ambient.gd:15) and "under trail, chalice and slime" (game.gd:1265), but coins, tickets, goo drops and lurker bodies are z 6 and the trail z 1, so motes draw over all of them. `move_child(motes, bedrock+1)` has no effect on order across different z. | Decide the intended layer. Either fix the comments and drop the `move_child`, or set Z below 6 if motes should pass under pickups. | none (comments) / changes output (if Z moves) | high |
| A-06 | low | bug | scripts/lurkers.gd:407, 588 | The near-miss slow-mo ends on the wall clock (`Time.get_ticks_msec() + LURKER_SLOWMO*1000`), while its frame skipping runs in a pausable `_process`. Pausing during the 0.3 s window ends it at once on resume. It is also not deterministic under `--fixed-fps` runs. | Count it down with the accumulated `_clock_wall` (already summed per frame) instead of ticks_msec. | changes gameplay feel slightly (only across a pause) | high |
| A-07 | low | hot-path | scripts/game.gd:1502, 1505, 1507 | `_disc_runs` appends each row with `runs.append_array([cy, lo, hi])`: a temporary Array literal per row, for 2-3 calls per gliding tick (paint r9, reveal r9+reach, relight r20+reach on a cell change: about 10-45 rows each). | Three `runs.push_back()` calls (or pre-size and write by index). Same output. Needs measurement. | none | high |
| A-08 | low | hot-path | scripts/game.gd:1521-1526 | `_rgba8` encodes a colour with `Image.set_pixel` + `get_data().decode_u32(0)` (a fresh 4-byte PackedByteArray each call). `_paint_cells` calls it 3x per call (1344-1346), `_reveal_light` once, and each newly revealed wall once more through `_fill_fog`. | Memoize the last few Color->u32 results, or compute the fog bytes with integer maths as `_relight` already does (1410-1411). Don't switch to `Color.to_rgba32` without a byte check: rounding may differ from `set_pixel`. Needs measurement. | none | medium |
| A-09 | low | hot-path | scripts/fx.gd:222, 230, 239 | Every `Fx.burst` (each landing, splat, ricochet, coin, ticket, drop) allocates a new Gradient via `stepped_ramp()` / `twinkle_ramp()` and, with rainbow, `rainbow_gradient()`. `_shrink_curve` and `star_texture` are already cached the same way. | Cache the three gradients in statics. Nothing mutates them after creation (grep: only assigned to particles). Needs measurement. | none | high |
| A-10 | low | hot-path | scripts/game.gd:1076-1080 | Each `Glimmer` builds its own `CanvasItemMaterial` (ADD) for its pixel arms, on top of the shared light. Leftover of rendering #8: a per-spawn allocation that breaks batching between glimmers. | One static shared ADD material for Glimmer. | none | high |
| A-11 | low | hot-path | scripts/lurkers.gd:389-393 | `EyeLayer.queue_redraw()` runs every frame for the whole run, even when every lurker is dormant (nothing drawn). That forces a canvas-item rebuild per frame. | Redraw only when some lurker `eyes_open()` or is stunned (or when that set changes). | none | high |
| A-12 | low | dead-code | scripts/fx.gd:194, 249-256 | `Fx.crust_flakes`, `Fx.afterimage_colors` and `Fx.DUST_BRIGHT` have no references anywhere in scripts / scenes / tests / tools. | Delete. | none | high |
| A-13 | low | dead-code | scripts/slime.gd:803-804 | `Slime.is_hurt()` has zero references repo-wide. | Delete. | none | high |
| A-14 | low | dead-code | scripts/game.gd:1135-1141, 1193-1194 | `_fog_packed`, `_fog_lit_ticks` ("Allocation-free field readers for per-cell loops") and `_cell_pos` have no production callers since the byte refactor; only tests use them (test greps: 2 / 1 / 3 hits). | Move them to the test helpers, or mark them test-only and fix the stale comment. | none | high |
| A-15 | low | duplication | scripts/game.gd:2033-2039 vs 2410-2416 (and 1994-1996) | The MAGNET pickup rule (`d > coin_reach`, then `d > Coin.REACH and not (is_revealed_at and clear_line)`) is copied between coins and goo drops; tickets repeat the loop shape. | One `_in_pickup_reach(pos, at)` helper (and iterate backwards instead of `duplicate()`, which also closes cpu #10). | none | high |
| A-16 | low | duplication | scripts/game.gd:931-933 vs 1861-1863 | The slime + hat screen rect (`SLIME_SCREEN_HALF`, `HAT_SCREEN_H`, `+ 4 / + 8` px) is built twice. | Extract `_body_rect_at(at)`. | none | high |
| A-17 | low | duplication | assets/shaders/fog.gdshader:73, light_dither.gdshader:13, atmosphere.gdshader:19, goo_wipe.gdshader:22 (+ hash / value_noise in fog, atmosphere, goo_wipe, hub_room) | `bayer4`, `hash` and `value_noise` are copy-pasted. intro_fog.gdshader:40 defines a different matrix under the same name `bayer4`. | A shared `.gdshaderinc` for the identical copies. Rename intro_fog's helper. Pixel-identical. | none | high |
| A-18 | low | magic-number | scripts/levels.gd:184-188, 201-203; scripts/ticket_goal.gd:11 | `weekly_par` hardcodes `acc := 420.0 * f` and `PAR_SPEED := 72.0` (copies of `Slime.acceleration` / `max_speed`, slime.gd:89-90). `GRAB_REACH := 13.0` = chalice radius 6 (chalice.tscn) + `Slime.RADIUS`, and `TicketGoal.GRAB_RADIUS := 6.0` repeats the chalice radius. game.gd:492 derives the reach from the real shape, so the copies can drift apart. | Reference `Slime.RADIUS` and one shared GRAB_RADIUS const. Keep the 72 / 420 values but name them as Slime constants. | none | high |
| A-19 | low | magic-number | assets/shaders/fog.gdshader:175 | The vignette half-extent `vec2(176.0, 100.0)` is hardcoded (the same numbers as `Ambient.REACH`, ambient.gd:14). It is tied to the 320x180 base. | A uniform with that default. | none | high |
| A-20 | low | unchecked-error | scripts/game.gd:876-880 | `var stream := load(bed_path) as AudioStreamWAV` is dereferenced at once (`loop_mode`, `get_length`). `ResourceLoader.exists` doesn't guarantee a WAV that loads, so a failed load or a non-WAV bed is a null crash on level start. It also rewrites loop settings on the shared cached resource every level (the .import has `edit/loop_mode=0`). | Null-check. Better, set the loop in the WAVs' import settings and drop the runtime mutation. | none | high |
| A-21 | medium | architecture | scripts/game.gd:1105-1664 (+ 189-228) | game.gd is 3,539 lines. The fog/trail reveal engine (bytes, disc spans, relight / lazy upload, wall reveal, `fog_alpha_at`, `is_revealed_at`, flush) is a self-contained ~560-line unit with its own state, mixed in with training, Descent, pay, survey and result flow. The still-open chunked upload (rendering #1) would land in the middle of it. | Extract to a `RevealMap` class (RefCounted) owned by game. Keep the game's public API (`fog_alpha_at`, `is_revealed_at`, `reveal_tile`, `paint_streak`, `fog_image`) as thin forwards for tests and abilities. | none | high |
| A-22 | low | architecture | scripts/lurkers.gd:421-430, 456, 621 | Lurkers reach into game privates: `_still_time` (stealth, root of A-01), `_hitstop_frames`, `run_time` (+= lost slow-mo time), `last_slime_pos`, `hud.set_time`. | Small game API (`is_still_for(s)`, `add_run_time(s)`, `slime_moved_externally()`). | none | high |

Severity count: critical 0, high 0, medium 3 (A-01, A-02, A-21), low 19.
