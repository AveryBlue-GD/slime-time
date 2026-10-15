# Spring cleaning phase 4: performance (implementation)

Date: 2026-10-16. Branch `spring-cleaning`, from the phase 3 state (`9f965f0`) to `0ac5186` plus this report. Implements the ranked
fixes of [phase4-perf-audit.md](phase4-perf-audit.md) and the owner's D3 (stable 60 fps floor, smooth 120/144/240 Hz) and D5
(physics interpolation, verified with side-by-side captures, whole pixels, revert if wrong).

All measuring ran from scratch copies in `/private/tmp/claude-501/p4i/` (a `git archive` of the phase 3 commit as the baseline
`base/`, copies of the working tree for each step) with a fake `HOME`, so no real save was read or written and no Godot process
of anyone else was touched. Same machine and tools as the audit (MacBook Pro M3, Godot 4.7.2, Compatibility renderer;
`perf/p4.gd`, `trans.gd`, `loadsplit.gd`, `pace.gd` + a new analyser that also counts hat reversals, `soak.gd`).

## Summary

| # | Item | Result | Visual change |
|---|---|---|---|
| 1 | Maze border on its own TileMapLayers | gameplay draw calls 96-128 -> 27-37, frame -0.2 to -0.5 ms | none (0 px) |
| 2a | Hat flight on physics ticks | 144 Hz: 310 one-frame hat reversals in 5 s -> 1 | none at 60 Hz |
| 2b | Physics interpolation above 60 Hz + pixel-locked camera | 120/144/240 Hz: 72/74/71 % -> 99.8/98.1/99.9 % of frames on the ideal pixel, twitches 25/33/22 per s -> 0 | intended smoothness above 60 Hz only; 60 Hz identical |
| 3 | Rainbow recolor without re-theming | hub 2.32 -> 0.94 ms, L10 rainbow 2.57 -> 1.69 ms, skins 2.76 -> 2.26 ms | none (0 px, 30 rainbow frames over time) |
| 4 | Tile fill cache for retries | fill + border 2.7 / 11.6 / 20.8 -> 0.09 / 0.31 / 0.66 ms (L1 / L10 / 36x20) | none (byte-identical tile data) |
| 5 | Descent goo-drop placement | 7.2-8.6 -> 1.3-1.5 ms per 36x20 floor | none (same cells) |
| 6 | Hub / level / story preloaded at boot | first covered stall: hub 98 -> 29 ms, first level 182 -> 37 ms, story 87 -> 9 ms; boot +0.37 s | none |
| 7 | goo_wipe (and the wipe sheet) warmed | first wipe frame 7.7 -> 0.9 ms | none |
| 8 | HUD attempt/pot pod rebuilt on change | `game._process` 6.0 -> 3.6 us (randomizer), 6.9 -> 3.8 us (Descent) | none |
| - | Upgrades buy guard on the engine clock | same 0.3 s; fixed-fps runs no longer depend on machine load | none |

Gates: `./tools/test_all.sh` **73 suites, 0 failed** (72 + the new `test_interpolation`), run after every commit; golden maze
test unchanged and passing; **99 gameplay/menu/cutscene frames at 60 Hz pixel-identical** to the phase 3 state (the 49 of
phase 3's set plus 31 hat-hop frames and 30 rainbow frames, cutscenes included: story intro 4 frames, finale 3); 800 captured
60 Hz frames byte-identical; headless boot of title / hub / main clean (only the engine's usual exit-time "N resources still in
use / ObjectDB leaked" pair, same as before); Web, Windows and macOS release exports build without errors.

## Pixel-diff method

`/private/tmp/claude-501/p4i/pix/` (the phase 3 harness, extended): `--fixed-fps 60`, seeded RNG, wall-clock drifts pinned to
the frame count, the root viewport saved at fixed frames. 49 shots of the phase 3 set (title, hub, skins rainbow / stopwatch /
custom, controls, keys, level select, upgrades, maps, levels 1/5/10, level 10 rainbow, randomizer, hard 3, Descent, autoplay
at 7 points, story intro, pause, victory, confirm dialogs, randomizer with abilities, story finale) + 31 frames of
`demo_hat_hops` (a hat popping off and landing) + 19 rainbow frames over time (controls, level select, upgrades, pause,
victory, hub x3, maps, hat wheel confirm, randomizer HUD). Base vs base: 0 px. Every step: **0 differing pixels in all 99**.

## 1. Maze border on its own layers (`maze_tiles.gd`, `main.tscn`, `game.gd`)

Every TileSetAtlasSource gets its own padded copy of its texture, so the border's two sources (the colliding ring and the
bedrock past it, same image) sharing the `Walls` layer with the wall atlas broke the batch at every texture switch. The ring
now goes on a `Border` layer and the bedrock on a `Bedrock` layer (collision off), both right after `Walls`; tiles never
overlap, so draw order cannot matter. The ambient motes stay right after the last of those layers, as before. Tests
(`test_border`, `test_coins`) read the new layers.

Draw calls and frame times (M3, uncapped, vsync off, `--fixed-fps 60`, 600 measured frames; avg / p95 / p99 / max ms):

| Scene | draw calls before -> after | before | after |
|---|---|---|---|
| L1 | 115.9 -> 33.1 | 1.21 / 1.34 / 1.57 / 9.0* | 1.03 / 1.11 / 1.18 / 8.9* |
| L5 | 127.7 -> 31.0 | 1.32 / 1.60 / 1.74 / 1.9 | 1.08 / 1.18 / 1.28 / 2.9 |
| L10 | 113.3 -> 30.1 | 1.43 / 1.73 / 1.80 / 1.9 | 1.17 / 1.28 / 1.39 / 1.5 |
| hard 10 + all HEAT | 111.4 -> 32.7 | 1.52 / 1.80 / 1.92 / 2.2 | 1.21 / 1.32 / 1.47 / 1.8 |
| randomizer 36x20 | 117.7 -> 27.4 | 1.74 / 1.99 / 2.04 / 2.3 | 1.24 / 1.37 / 1.49 / 1.6 |
| abilities | 109.0 -> 35.0 | 1.31 / 1.73 / 1.86 / 2.8 | 1.10 / 1.47 / 1.61 / 2.6 |
| Descent floors 1-10 | 35-121 -> 28-37 | 1.63-2.27 avg | 1.50-1.66 avg |

\* L1's single long frame is the level's first-frame outlier in both runs (script time 0.04 ms: outside the game).

Render CPU per frame fell from 0.37-0.53 to 0.20-0.24 ms in every level. On mobile WebGL (about 20-40 us per draw call, see the
audit) that is the expected 2-4 ms per frame.

## 2. High refresh

### 2a. Hat flight on physics ticks (`hat.gd`)

The hat measured the slime's speed per render frame: above 60 Hz the slime only moves on ticks, so that speed read 0 and then
2-4x, and the jolt swung the hat. The flight (speed, jolt, arc) now runs in `_physics_process`; `_process` only draws it. At
60 Hz the order of operations is the same as before (the hat processes after the slime).

| L10, a leap every 1.5 s (5 s) | 60 Hz | 144 Hz | 240 Hz |
|---|---|---|---|
| hat one-frame reversals >= 1 px, before | 4 (2 px) | 310 (up to 5 px) | 416 (up to 8 px) |
| after (hat fix, no interpolation) | 4 (2 px) | 1 (1 px) | - |
| after (with interpolation) | 4 (2 px) | 11 (1 px) | 8 (1 px) |

From the rendered pixels (a marker on the hat and one on the slime sprite, `hatpace.gd`): during flights at 144 Hz the hat
used to sit up to 5 px left or right of the body; now its x offset is 0 in every frame. The remaining 1 px steps are the
squash/stretch frames (same at 60 Hz).

### 2b. Physics interpolation (`project.godot`, `transition.gd`, `slime.gd`, `game.gd`, `hat.gd`, `hub.gd`, `slime.tscn`)

Settings: `[physics] common/physics_interpolation=true`; physics ticks stay **60** (jump arcs, drain, timers unchanged),
vsync stays **Enabled**, `max_fps` stays **0** (all three are the defaults, so the editor keeps them out of the file).

**Design, and the one deviation from the audit's plan:** at exactly 60 Hz (ticks aligned with frames) the interpolation
fraction is always 0, so interpolation draws every interpolated node one tick (16.7 ms) late and changes nothing else: the
frames are just the previous tick's. Measured: best-fit lag +1.0 tick at 60 Hz, and the fog hole 1 px off the sprite in 97 %
of frames unless it follows the interpolated position. So it is **switched on only while frames come faster than the ticks**
(`Transition.follow_frame_rate`: on above 72 fps, off below 66, smoothed frame time, unscaled by `Engine.time_scale`; never
in headless runs). On a 60 Hz display (and in every test, fixed-fps 60) the game runs exactly as before: no added latency,
pixel-identical. With it on, `Engine.physics_jitter_fix` is 0 (Godot's advice), otherwise its default 0.5.

- **Opt-in:** the scene root is set to interpolation OFF at startup; the `Slime` (level and hub) turns it ON (its sprite, shadow,
  drips, guide and tutorial cues follow it; none of them changes its own transform per frame). The `Camera2D` is OFF in
  `slime.tscn` (this also keeps Godot from forcing it to the physics callback). Hats are OFF (they place themselves).
  Ability projectiles, coins, drops and hub stations stay as they were (not interpolated: they step on ticks, as today).
- **Mirror of the renderer:** `Slime.drawn_shift()` takes the slime's and sprite's positions at `SceneTree.physics_frame` (the
  renderer's "previous" transforms) and lerps them with `Engine.get_physics_interpolation_fraction()`. The fog hole and the
  slime light use it (`game.gd`), the hat adds it to where it sits (and takes the hub slime's own share off, since there the
  hat is the slime's child), and the in-flight hat height is lerped between ticks too.
- **Pixel-locked camera** (only while interpolating): Camera2D smoothing off, camera top level;
  `follow = drawn slime + look-ahead.round()`, `smooth = smooth.lerp(follow, min(8 * delta, 1))` (Camera2D's own easing),
  `camera.global_position = follow.round() + (smooth - follow).round()`. Limits and shake are unchanged (Camera2D still applies
  them). Below the threshold the original Camera2D-child behaviour is restored exactly.
- **Resets** (`reset_physics_interpolation`): the slime after it is placed at the start cell (`game.gd`, every level start,
  restart, replay and Descent floor, since those reload the scene), the hub slime after it is placed (`hub.gd`), the slime after
  `AbilityRunner.flush` ends a SLIMAKAZE dash at once (a normal dash moves continuously in physics and needs none), and the
  whole tree whenever the switch flips. The slime mirrors every reset (`NOTIFICATION_RESET_PHYSICS_INTERPOLATION`). The game has
  no checkpoints or other teleports (searched: only menu previews and dev demo scenes set positions directly).

Pacing (`pace.gd`, level 1 autopilot, 5 s per case; physics 60 Hz; "pixel==ideal" = drawn pixel equals the ideal pixel on the
interpolated physics path; "twitch" = 1 px on-screen back-and-forth per second):

| | 60 Hz | 120 Hz | 144 Hz | 240 Hz |
|---|---|---|---|---|
| before: pixel==ideal / twitch / fog hole off sprite | 99.7 % / 5.0 / 0 % | 72.5 % / 25.4 / 0 % | 74.3 % / 33.0 / 0 % | 71.1 % / 22.2 / 0 % |
| after | **99.7 % / 5.0 / 0 %** (unchanged) | **99.8 % / 0 / 0 %** | **98.1 % / 0 / 0 %** | **99.9 % / 0 / 0 %** |
| best-fit lag behind the physics path | 0 -> 0 ticks | 0.3 -> 1.0 | 0.5 -> 1.1 | 0.4 -> 1.0 |

The lag row is the price of interpolation: above 60 Hz the slime is drawn up to one tick (avg about half a tick more than
before) behind the simulation; input is still read every tick. At 60 Hz the 5 twitches/s of the old camera remain on purpose
(fixing them would change 60 Hz frames; the pixel-locked camera could be used at 60 Hz too if the owner wants that).

Run, timers and records: `test_interpolation` runs the same 240-tick autopilot run with interpolation off and forced on and
gets the same slime position every tick and the same run time, meter and trail image; it also checks the switch thresholds,
the opt-in modes, that the fog hole / light sit on the drawn slime and the camera on whole pixels every frame, and the reset.

**Side-by-side captures** (Godot movie writer at `--fixed-fps 60` / `144`, left = before, right = after, 3x nearest-neighbour;
in `docs/spring-cleaning/perf/`, git-ignored like the other local videos, lossless H.264 4:4:4):

| File | What |
|---|---|
| `glide_144hz.mp4` | level 1, autopilot, top hat, 4.9 s at 144 fps (play on a 120/144 Hz screen) |
| `glide_144hz_quarter_speed.mp4` | the same frames at 36 fps: every rendered frame visible on any screen |
| `hops_144hz.mp4`, `hops_144hz_quarter_speed.mp4` | `demo_hat_hops` (leaps with a hat, bonks) at 144 Hz |
| `glide_60hz.mp4`, `hops_60hz.mp4` | the same at 60 Hz: the two halves are identical (all 420 + 380 PNG frames byte-identical) |
| `glide_144hz_frames_600-607.png` (committed) | 8 consecutive 144 Hz frames around the slime, before (top) / after |

What I looked for in them: pixel shimmer (none: walls, sprites and the hat stay on whole pixels, the world scrolls in whole
pixels), smearing (none: no blending, nearest filtering throughout), off-pixel sprites (none; hat x offset 0 in flight, the fog
hole on the sprite), the trail (painted on ticks, so above 60 Hz it can lead the drawn slime by under a tick; it stays under
the 14 px body, not visible in the frames), collision feel (unchanged by construction: physics is identical tick for tick).
Nothing looked wrong, so interpolation is **kept**, pending the owner's look at the captures (D5). To revert: set
`common/physics_interpolation=false` (the switch then has no effect and the camera stays the Camera2D child).

## 3. Rainbow recolor (`skin_text.gd`, `goo_box.gd`)

Attribution first (toggling each part off in a scratch copy): the cost was the theme change signal, not the color math. Every
frame `GooBox.set_goo_color` re-emitted each box's and each theme's `changed`, and `SkinText` held and re-emitted its theme's,
so every control under those themes was re-themed (re-layout, re-shaped text): +1.56 ms on the skins screen, +1.0 hub,
+0.46 L10. The label overrides cost +0.65 ms on the hub (47 labels, most hidden).

The rainbow's per-frame step (`recolor(shared, flow = true)`) now:
- changes the goo color and redraws only the controls that drew a goo box (`GooBox.tint`: boxes note the canvas items they
  draw into); no theme signal;
- sets the theme's button colors with its signals held and tells only the visible buttons (`NOTIFICATION_THEME_CHANGED`) and
  sliders (redraw); a hidden button is told the moment it shows (`visibility_changed`, before it draws);
- recolors visible group labels as before; a hidden label keeps the color it is due and gets it the moment it shows.

Skin changes and the first color of a screen still go through the old full path. 0 px difference in 30 rainbow frames over
time (menus, HUD, hub, pause, victory, hat wheel).

| Scene (avg / p99 ms) | before | after | same scene, plain skin |
|---|---|---|---|
| hub, rainbow | 2.32 / 2.79 | **0.94 / 1.25** | 0.76 / 1.09 |
| L10 rainbow, upgrades 7/4/3 | 2.57 / 3.07 | **1.69 / 2.00** | 1.36 / 1.63 |
| skins screen, rainbow | 2.76 / 3.07 | **2.26 / 2.52** | 1.10 / 1.28 |

Left: the skins screen still tells its 36 visible tile buttons about the new text color every frame (0.48 ms): a button's
text color only reaches it through its theme cache. Removing that needs the text tinted another way (a shader path or
`self_modulate`, which would also tint the labels' drop shadows), which is a visual risk; not done.

## 4. Tile fill cache (`maze_tiles.gd`)

The last maze's floor / wall / fillet layers and border / bedrock layers are kept as `tile_map_data` (plus the wall damage) and
copied back when the same maze is built again (retry, replay, restart, a new floor of the same maze), keyed by every input
including the whole wall layout. `test_border` checks a cached build against a fresh one byte for byte, every layer.

| fill + border, first build -> repeat (ms) | before | after |
|---|---|---|
| L1 | 9.9 -> 2.7 | 9.2 -> **0.09** |
| L10 | 19.0 -> 11.6 | 17.8 -> **0.31** |
| randomizer 36x20 | 29.6 -> 20.8 | 27.9 -> **0.66** |

Warm scene change to the same maze again (change -> first frame drawn, median of 5, `loadsplit.gd`): L10 26.5 -> 15.3 ms,
randomizer 28.9 -> 16.3, Descent 32.6 -> 17.0, L1 14.7 -> 11.2.

## 5. Descent goo drops (`maze_generator.gd`, `levels.gd`)

`MazeGenerator.cell_links` gives every cell's open sides as a bit mask in `DIRS` order; `dead_end_depths`, `shortest_path`
and `Levels.coin_cells`' branch search run on flat arrays with it, and the picking stops once enough cells are picked
(dictionary lookups instead of `Array.has`). Same cells in the same order: golden maze test, plus 20 story, 360 randomizer
and 15 Descent mazes compared with the old code (depths, coin cells, paths both ways, drop cells: identical).

| 36x20 Descent floor (ms) | before | after |
|---|---|---|
| dead_end_depths | 3.3-3.6 | 0.28-0.30 |
| shortest_path | 1.0-2.2 | 0.33-0.52 |
| Descent.drop_cells (all of it) | 7.0-8.6 | **1.29-1.48** |

## 6 + 7. First-use stalls (`title.gd`, `transition.gd`)

- **Preload:** the first title of a session loads `main.tscn`, `hub.tscn` and `story.tscn` (main first for a fresh save, whose
  PLAY opens level 1) before its first frame, and keeps them for the session. Plain loads on purpose: a threaded request
  (`load_threaded_request`) **deadlocked Godot 4.7.2** in the pixel harness when a scene change loaded the same scene while the
  worker was still on it (the main thread and a worker waiting on each other's mutex), and the web build has no threads. Not in
  headless runs. Cost: boot to the title's first frames 93 -> 468 ms on the M3 (under the boot splash / web loading bar).
- **Warm-up:** `goo_wipe` (and `atmosphere`, `slime_skin`, `text_drips`) added to the title's warm-up list. That alone did not
  remove the first wipe's stall: the sheet's own first draw was the cost, so `Transition.warm_up()` draws the sheet for one
  frame slid fully off the screen (every pixel discarded; 0 px difference in the title frames).

Through the real goo wipe (`trans2.gd`, first use in the session, worst frame in ms, 3 runs, median):

| Change | before | after |
|---|---|---|
| first wipe's first frame | 7.7 | **0.9** |
| title -> hub | 98.2 | **28.3** |
| -> L1 (first level) | 181.6 | **37.3** |
| -> story | 86.6 | **8.8** |
| -> level select / maps / upgrades / skins | 29 / 30 / 35 / 40 | same |
| -> L10 / randomizer / Descent (new mazes) | 47 / 45 / 35 | 43 / 45 / 32 |
| warm (pass 2) | 3-50 | same |

Cold scene change without the title (`loadsplit.gd`): hub 131 -> 30 ms, L1 229 -> 38, story 95 -> 11.

## 8. HUD pods (`game.gd`)

The attempt pod (randomizer) and pot pod (Descent) are re-derived on the first frame any of their inputs differs
(`_pod_inputs`: attempt, second wind, dev toggles, assist, finished/won, the UTC day, the day's paid counts and paid seeds, the
caps' inputs, the Descent pot / gain / slot / ended / tainted / result), instead of every frame. Same text, same pops (the
direct refreshes on start and on dev toggles stay). `game._process`: randomizer 5.9 -> 3.6 us, Descent 6.9 -> 3.8 us, L10
2.4 -> 2.3 us (the input key itself costs about 1.3 us).

## Wall clock in the upgrades screen (`upgrades_screen.gd`)

The 300 ms double-buy guard used `Time.get_ticks_msec`; it is now a `SceneTreeTimer` (0.3 s of engine time, ignoring time
scale), so fixed-fps runs (tests, nav fuzz) play out the same however loaded the machine is. `test_store` pins it (still
guarded after 0.2 s, free after 0.4 s). The other two wall-clock reads phase 2 listed (`Hats` rainbow flow, `MenuBackdrop`
drift) are purely visual and were left alone.

## Long session

Soak (`soak.gd`: hub -> story level 1-10, every third hard, autopilot -> restart -> hub -> randomizer MORE SLIME 0-7 ->
skins (rainbow every 4th) -> maps -> level select -> upgrades -> pause, repeated), on the final tree:

| Run | Length | Level starts | Nodes / orphans / resources | Objects | Static memory | Cycle time |
|---|---|---|---|---|---|---|
| headless, `--fixed-fps 60` (audit's setup) | 60.3 sim min (50 s wall; the audit's run took 172 s) | 192 | +0 / +0 / +0 | -8 | +1,988 KB (10.7 KB per start, the audit's 10.1: engine-internal, see audit section 5) | flat |
| windowed, uncapped (interpolation on) | 60 sim min | 153 | +0 / +0 / +0 | -2 | +184 KB | flat |
| **windowed, real time, 120 fps cap (interpolation on), 30.3 min wall** | 60.4 frames-min (30.3 min of play) | 162 | +0 / +0 / +0 | +14 (5,576-5,602 band, no trend) | +198 KB | 28.9-35.4 s, flat from first to last |

No script errors in any run; RSS levels off (242 -> 256 MB over the 30 minutes, +1 MB in the last 20). Worst frame per cycle
26-32 ms at 120 fps in the real-time run, all at scene changes under the wipe (the cycle changes scene about 9 times).

## Not done / notes

- **Web long tasks** were not re-measured in a browser this phase (the audit's Chromium probe stalls when the pane is hidden).
  The native gains map onto the web roughly 1:1 on the M3 (WASM about native speed for these loads, per the audit).
- `MazeGenerator._order` / `_visited` are still static scratch buffers (unsafe for building mazes on worker threads); nothing
  builds mazes on threads, so left as is.
- Ability projectiles, coins, goo drops and hub stations are not interpolated (they step on ticks above 60 Hz, as before).
  The hub room turn (`hub.gd`, physics) likewise. Candidates if the owner wants more smoothness there.
- The rainbow skins screen keeps about 1.2 ms over a plain skin (section 3).
- Boot is 0.37 s longer on the M3 (section 6); on a phone maybe 1-2 s more on the loading bar, against the same time taken
  off the first hub, level and story changes.

## QA follow-up (2026-10-16)

The four findings of [qa-phase4-review.md](qa-phase4-review.md), plus the promo frame from the phase 5 notes. Each fix has a
regression check that fails on the code before it. Measured from scratch copies (`git archive`) with a fake `HOME`.

| # | Finding | Fix | Check (fails before the fix) |
|---|---|---|---|
| 1 | Rainbow skin: the coin board's gold N/N counts showed the stale rainbow text color | `SkinText._label_shown` drops a due color instead of applying it when the label has left the skin-text group (the hub also drops it when it takes a count out). The hub's counts are the only labels that ever leave the group. | `test_hub`: rainbow hub, rainbow flows while the board is hidden, then every count is gold |
| 2 | One hitch turned interpolation off and on again, and each switch snapped the camera | See below | `test_interpolation`: hitches, slowdowns, 60 Hz jitter, camera continuity |
| 3 | First launch: no preload before the hand-off to the trailer (section 6 was wrong) | The booted title of a fresh save runs the preload before it changes to the story intro. These are the same plain loads as on every other boot, still under the boot screen. Section 6 is now true for every boot. | `test_story`: main, hub and story are loaded at the hand-off (before: none) |
| 4 | `MazeGenerator.shortest_path` with an unreachable target | Returns `[]` when the target is not reached or a cell is outside the maze. Callers already treat an empty route as none. `AutoplayPlanner.fastest_run` clamps its tile count. | `test_phase4`: walled-in and outside cells give `[]`. Before the fix: a made-up path through cell -1, then an endless loop. |
| - | Promo `screenshot-6-new-record` at frame 1050 caught the run before the win | Moved to frame 1150 in `make_promo.sh` and `make_promo.ps1`. The win lands at about frame 1084: the banner shows at once and the buttons 0.6 s later. | A full `make_promo.sh` render to a temp dir shows the banner, the result panel and the three buttons (not committed) |

**1, pixels.** Rainbow hub, `--story-complete --skin=rainbow`, frames 1-40, with the coin board opened at frame 12. Against
phase 3 (`9f965f0`):
- Before the fix: 546 px differ in each of frames 12-40, all in the count column.
- After the fix: **0 px in all 40 frames**.

**2, the switch** (`transition.gd`, `game.gd`):
- **Time-based.** The estimate must stay past the threshold, without a break, for `INTERPOLATION_SWITCH_HOLD` = 0.5 s before
  the switch flips. The thresholds are unchanged: on above 72 fps, off below 66.
- **Hitches.** A frame over 50 ms (`HITCH_FRAME`) counts as a hitch and is left out of the estimate. Only a run of 3 such
  frames in a row counts, because then the game really runs that slowly.
- **Camera carried across.** Turning on seeds the pixel camera's ease from Camera2D's eased view (its screen center less the
  shake offset). Turning off no longer calls `reset_smoothing()`: with smoothing off, Camera2D tracked the pixel camera's
  position every frame, so its own ease carries on from there.
- **At level start** the camera still starts on the slime, as before.

Measured windowed: level 5 on autopilot at `--fixed-fps` 60 / 75 / 90 / 120 / 144 / 240, 7 s per run. A scratch probe feeds
the switch a scripted frame-time sequence:
- **hitch:** single frames of 32, 52, 90, 120 and 250 ms;
- **slow:** 40 fps from 2.0 s to 4.5 s.

"Jump" is the worst change of the slime's on-screen step on the 3 frames after a switch. "Normal" is the same measure on
every other frame. The start-up switch on (in the first second) is left out.

| Refresh | hitch, before: switches / jump | hitch, after | slow, before: switches / jump | slow, after: switches / jump (normal) |
|---|---|---|---|---|
| 60 Hz | 0 | 0 | 0 | 0 |
| 75 Hz | 2 / 9.5 px | **0** | 2 / 7.9 px | **2 / 2.2 px** (2.3) |
| 90 Hz | 8 / 14.7 px | **0** | 2 / 3.7 px | **2 / 1.7 px** (2.3) |
| 120 Hz | 6 / 14.7 px | **0** | 2 / 4.8 px | **2 / 2.1 px** (2.3) |
| 144 Hz | 6 / 13.1 px | **0** | 2 / 3.9 px | **2 / 2.0 px** (2.3) |
| 240 Hz | 4 / 15.3 px | **0** | 2 / 3.6 px | **2 / 1.2 px** (2.0) |

Reading the table:
- In the slow case, the 2 switches are one off when the slowdown sets in and one on when it ends.
- The camera's own step at those switches is 0.8-1.8 px (2.0-2.2 px normal). Before the fix it was 3.4-13.8 px.
- At 60 Hz there are no switches in any case.
- 99 frames at 60 Hz, the phase 4 pixel set (gameplay, menus, cutscenes, hat hops, rainbow), are **byte-identical** to the
  commit before the fix.

`test_interpolation` covers:
- At 75 / 90 / 120 / 144 / 240 Hz:
  - single hitches of 32-250 ms (alone and in close pairs) never switch;
  - a 0.3 s dip to 40 fps does not switch;
  - a lasting dip switches off once and its end switches on once;
  - a fall to 12 fps for good switches off once.
- At 60 Hz, 10 minutes of jitter, bursty pairs and hitches never switch.
- In a mid-glide switch off and back on, the change in the camera's step stays within normal frames: 2.3 px vs 2.2 px. The
  old code jumped 12.3 px.

Trade-off: on a high-refresh screen, interpolation now turns on about 0.5 s after boot (on the title) instead of after a few
frames.

Gates:
- `./tools/test_all.sh`: **76 suites, 0 failed**.
- Web, Windows and macOS release exports build with 0 errors.
- A local web export with a fresh save runs the trailer, then the title, then PLAY into level 1 with no console errors. This
  is the preload-before-hand-off path.
