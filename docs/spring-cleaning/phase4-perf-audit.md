# Spring cleaning phase 4: performance audit (perf-profiler, audit half)

Date: 2026-10-15. Branch `spring-cleaning`; measured from a copy of `5aae6e8`. No game file changed between that commit and
`1deb6a6`, so the numbers hold for the current head. This was a read-only audit: every run used a scratch copy in
`/private/tmp/claude-501/perf_proj` with its own user dir (`slime_perf_p4`) and a fake `HOME`. The real repo and the
real saves were never touched, and no Godot process belonging to anyone else was stopped.

Owner targets: stable 60 fps on low-end PCs and low-to-mid mobile, smooth at 120/144/240 Hz on better rigs, no hitches,
no leaks, clean logs. Earlier audits are in [../perf/](../perf/) and the applied batches in
[../archive/perf/](../archive/perf/). This report checks their results and adds to them; it does not repeat them.

## Headline

1. **Steady frame cost is low everywhere on the M3.** Uncapped frames take 0.9-2.3 ms (p99 at most 3.5 ms) in every
   scene, with the rainbow skin as the exception. That leaves plenty of room for 60 Hz and enough for 144 Hz.
   **The rainbow skin still costs real time:** the skins screen takes 3.98 ms (vs about 1.2 ms for other menus), the
   hub 2.83 ms (vs 0.93), and L10 with full upgrades 3.07 ms (vs 1.81). On a low-to-mid phone that is roughly 20-50 ms
   per frame, so those screens would miss 60 fps.
2. **Draw calls went up to 96-128 per gameplay frame** (the 10-13 audit counted 33). Almost all of the extra calls come
   from one TileMapLayer (`Walls`) that mixes three texture atlases: the wall atlas and two border atlases. Splitting
   the border tiles into their own layers drops gameplay to **30 draw calls**, measured. This is the biggest new
   mobile/web win.
3. **High refresh is currently not smooth, and some of it is a bug.** Physics runs at 60 Hz with no interpolation, and
   the camera smoothing runs per render frame:
   - at 120-240 Hz the slime's drawn position is off its ideal path in 25-29 % of frames;
   - the slime twitches back and forth by 1 px on screen 22-30 times a second (5-7 times a second even at 60 Hz);
   - the hat wobbles ±2.5 px every frame during leaps, from a velocity computed per render frame in `hat.gd`.
   Physics interpolation plus a pixel-locked camera removes all three in the scratch experiments (0 twitches, 98-100 %
   of frames on the ideal pixel). The exact plan is in section 4.
4. **No leaks.** A 60-simulated-minute soak (192 level starts, about 1,900 scene changes) left nodes, objects,
   orphans and resources flat. Static memory grows **~1.5-2.7 KB per scene change of any kind**, in power-of-two steps.
   This is the old "~9 KB per level start" (one soak cycle is several scene changes), and it is engine-internal.
5. **The 27-minute nav-fuzz runs were the Mac sleeping, not the game.** Re-run here, the web and touch variants take
   58 s wall each. Details in section 7.

## 1. Method

- **Machine:** MacBook Pro M3, macOS 14.5, Godot 4.7.2 official, Compatibility renderer (OpenGL 4.1 on Metal).
- **Noise:** other agents' Godot processes were running at times (test shards, a UI project, a mutation run, with a
  load average of 7-14). Every scenario ran twice (batches A and B), and the table keeps the cleaner run.
  - The frames over 8.33 ms seen in the noisier batch had at most 0.8 ms of script and at most 1.1 ms of render CPU,
    so the time was spent outside the game. They came in bursts in time, and the same scenarios showed none in the
    other batch. They are not counted as game hitches.
- **Driver** (`perf/p4.gd`, a SceneTree script in the copy):
  - windowed real renderer, vsync off, `--fixed-fps 60` (same simulation every run), 120 warm-up and 600 measured
    frames;
  - frame wall time, script time (stamp nodes at priority ±1e6 for `_process` and summed `_physics_process`), render
    CPU (`viewport_get_measured_render_time_cpu` + frame setup);
  - draw calls, canvas items, nodes, objects, VRAM and texture memory, static memory, and the first 180 frames.
- **Other tools in the copy:**
  - `perf/trans.gd`: real goo-wipe transitions, cold and warm;
  - `perf/loadsplit.gd`: scene-change breakdown;
  - `perf/pace.gd` + `pace_an2.py`: frame pacing at 60/120/144/240 Hz with interpolation on or off;
  - `perf/soak.gd` / `soak2.gd`: long session and memory attribution;
  - `perf/dc.gd`: draw-call attribution;
  - `perf/micro_hot.gd`: µs per hot function;
  - `perf/webprobe.gd`: an autoload in a debug Web export, run in Chromium 152 on the same Mac.
- Logs are in `/private/tmp/claude-501/perf_logs4/` (scratch).

## 2. Per-scene numbers (native M3, uncapped, ms)

"script" = every node's `_process` + `_physics_process`. The UI work deferred to after `_process` (theme changes,
Control redraws) shows up as the gap between avg and script + render CPU.

| Scene | avg | p95 | p99 | max | script | render CPU | draw calls | canvas items | nodes | objects | VRAM MB | tex MB | static MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| title | 2.19 | 2.85 | 3.45 | 3.8 | 0.07 | 0.43 | 57 | 620 | 94 | 1,987 | 7.3 | 1.1 | 38.1 |
| hub (8 stations) | 0.93 | 1.46 | 2.21 | 2.9 | 0.05 | 0.15 | 27 | 35 | 247 | 2,333 | 14.3 | 2.1 | 40.6 |
| hub, rainbow | **2.83** | 3.37 | 4.24 | 4.9 | 0.76 | 0.20 | 27 | 35 | 247 | 2,335 | 14.3 | 2.1 | 40.6 |
| map table | 1.16 | 1.54 | 2.21 | 2.9 | 0.01 | 0.28 | 40 | 3,750 | 151 | 3,257 | 9.1 | 3.0 | 42.6 |
| upgrades | 1.16 | 1.56 | 2.17 | 5.0 | 0.00 | 0.28 | 44 | 3,493 | 189 | 3,336 | 9.1 | 2.9 | 42.6 |
| hat wheel (open) | 1.21 | 1.79 | 2.34 | 3.0 | 0.04 | 0.34 | 78 | 1,852 | 247 | 2,344 | 14.3 | 2.1 | 41.1 |
| level select | 1.21 | 1.56 | 2.10 | 5.1 | 0.00 | 0.32 | 52 | 4,224 | 208 | 3,377 | 9.1 | 3.0 | 42.6 |
| settings | 0.98 | 1.52 | 2.02 | 2.2 | 0.01 | 0.20 | 29 | 2,174 | 133 | 3,212 | 9.1 | 2.9 | 41.9 |
| skins, rainbow | **3.98** | 4.60 | 5.13 | 5.4 | 0.46 | 0.42 | 43 | 4,067 | 242 | 3,710 | 9.1 | 3.0 | 44.2 |
| story intro | 2.19 | 2.85 | 3.54 | 4.2 | 0.06 | 0.45 | 61 | 640 | 95 | 1,987 | 7.2 | 1.0 | 38.0 |
| story finale | 2.14 | 3.10 | 3.46 | 4.4 | 0.04 | 0.34 | 42 | 750 | 95 | 1,990 | 7.2 | 1.0 | 38.1 |
| L1 (autopilot) | 1.51 | 1.92 | 2.47 | 10.3* | 0.14 | 0.42 | **116** | 846 | 238 | 4,101 | 18.1 | 3.9 | 45.8 |
| L5 | 1.72 | 2.02 | 2.77 | 3.4 | 0.19 | 0.46 | **128** | 1,244 | 248 | 4,198 | 18.3 | 4.0 | 46.2 |
| L10 | 1.81 | 2.36 | 3.00 | 3.4 | 0.28 | 0.45 | **113** | 1,713 | 282 | 4,430 | 18.8 | 4.5 | 47.7 |
| L10, rainbow, upgrades 7/4/3 | **3.07** | 3.65 | 4.20 | 4.5 | 0.78 | 0.48 | 107 | 1,556 | 282 | 4,429 | 18.8 | 4.6 | 47.7 |
| hard 10 + all HEAT (36x20) | 1.87 | 2.19 | 2.95 | 3.8 | 0.35 | 0.45 | 111 | 1,387 | 222 | 4,779 | 19.5 | 5.2 | 49.8 |
| randomizer max (36x20, seed 5, MORE SLIME 7) | 1.95 | 2.27 | 3.02 | 3.8 | 0.38 | 0.47 | 118 | 1,643 | 213 | 4,789 | 19.5 | 5.3 | 49.8 |
| abilities (rifle/splat/kaze every 40 frames, 13 uses) | 1.68 | 2.32 | 3.05 | 3.6 | 0.23 | 0.40 | 109 | 598 | 254 | 4,826 | 19.6 | 5.3 | 50.0 |
| Descent floors 1-10 (upgrades 7/4/3) | 2.02-2.31 | 2.46-2.91 | 3.07-3.54 | 3.4-4.3 | 0.56-0.65 | 0.28-0.49 | 35-121 | 1,292-1,584 | 217-227 | ~4,830 | 19.6 | 5.3-5.4 | ~50.0 |

\* L1's single 10.3 ms frame had 0.13 ms of script: it was noise from outside the game.

Notes:
- The VRAM figures are the whole process: 7-9 MB in menus and the story, 14 MB in the hub, 18-20 MB in levels.
  Textures in use are 1-5.4 MB. The 36x20 mazes add about 1 MB of fog and trail images. Static memory is 38-50 MB in
  a debug build.
- **Descent physics runs about 0.3 ms higher** than the randomizer (0.57-0.65 vs 0.38). That comes from Brightness 3
  in the 7/4/3 upgrade set (fog relight discs), not from Descent itself. Floors 1-10 are flat; nothing grows with the
  floor number.
- **Abilities:** projectiles, bombs and dashes cost nothing measurable. No frame over 4 ms while firing.
- **GC:** GDScript is reference-counted, so there are no collector pauses to hunt. In clean runs, no gameplay scenario
  had a frame over 8.33 ms in its 600 measured frames.
- **Per-frame hot paths** (µs per call, `perf/micro_hot.gd`):
  - `game._process` 6.8 (L10), 9.8 (random), 11.4 (Descent);
  - `_refresh_attempt_pod` 8.3 per frame in the randomizer: it builds dictionaries and formats a string every frame;
  - `_refresh_descent_pod` 5.1;
  - `slime._physics_process` 2.8;
  - six `set_shader_parameter` calls 0.55 (a `&StringName` literal gains nothing).
  None of these matter natively. The pods are the only per-frame allocations worth tidying (×10-15 on web: about
  0.1 ms).

## 3. Loads, transitions and first-use stalls

Through the real goo wipe (`perf/trans.gd`, real time): the wipe always takes about 540 ms because it is a tween, so a
stall shows as **one long frame with the screen fully covered** (the goo freezes).

| Change | worst frame, first use in the session | worst frame, warm |
|---|---|---|
| title -> hub | 163 ms | 17 ms |
| -> level select / maps / upgrades / skins / settings | 46 / 55 / 65 / 79 / 46 ms | 22-31 ms |
| -> L1 (first level of the session) | **329 ms** (whole wipe 875 ms) | 24 ms |
| -> L10 | 91 ms | 69 ms |
| -> randomizer 36x20 | 89 ms | **105 ms** |
| -> Descent floor | 64 ms | 65 ms |
| -> story | 162 ms | 7 ms |

Breakdown (`perf/loadsplit.gd`, median of 5 warm runs; change call -> first frame drawn):
- hub 17 ms;
- skins / level select 29-30 ms: `_ready` is 9-11 ms, and the rest is the first layout and GooBox draws;
- L1 24 ms, L10 44 ms, randomizer 66 ms, Descent 76 ms.

Cold (first use): hub 205 ms, main.tscn 371 ms, story 154 ms. That is script compile plus resource load plus shader
compile.

Inside `game._ready` (instrumented copy, warm):
- **`MazeTiles.fill` + `add_border`** dominate: 2.0 + 2.3 ms (L1), 11 + 6.6 ms (L10), **21 + 10.4 ms** (36x20).
  This repeats on every retry, replay and new floor of the same maze.
- `_start_ambience` 2.4 ms;
- `_build_overlays` 0.5-1.1 ms;
- Descent `_place_drops` → `Descent.drop_cells` → `Levels.coin_cells` on a 36x20 maze: **~11 ms** per floor;
- a randomizer maze not yet built: about 10 ms (cached after that).

**Shader warm-up:** `scripts/ui/title.gd:79-100` warms fog, trail, hub_room, rainbow_hat, color_wheel and the additive
CanvasItemMaterial.
- It does **not** warm `goo_wipe` (so the first wipe's first frame compiles it), `atmosphere`, `slime_skin` or
  `text_drips`. The title draws those three itself, so they compile on the title's first frames, before any input.
- macOS GL caches no program binaries: the `shader_cache/` folders stay empty, so every session compiles again.
- WebGL on Windows (ANGLE → D3D) compiles slowest, and a test there is the real check.
- Fix: add `goo_wipe` to the warm-up list (title.gd:83). This is the only first-use compile still landing on a
  transition.

## 4. High refresh rate: measurements and the exact settings plan

Today the project has no `[physics]` section. That means `physics_interpolation=false`, `physics_jitter_fix=0.5`,
60 ticks, vsync enabled and `max_fps=0`, so **the game already renders at the monitor's rate** (120/144/240) with
physics at 60.

How it was measured: `perf/pace.gd` runs with `--fixed-fps F` (render rate F; physics stays at 60) and reads back every
rendered frame. A 1 px magenta marker sits on the slime and a cyan lattice in the world, both above everything, with
the HUD hidden. From those it gets the slime's drawn world position and screen position each frame. These are compared
with the ideal: the physics path interpolated at the frame's exact time, with the best constant latency fitted.
- **pixel==ideal**: the share of frames where the drawn pixel is the ideal pixel.
- **back-and-forth**: how often per second the slime's on-screen x or y reverses within two frames, i.e. a 1 px twitch
  against the screen.
- The run is level 1, autopilot gliding, 5 s per case.

| Configuration | 60 Hz | 120 Hz | 144 Hz | 240 Hz |
|---|---|---|---|---|
| **Today** (interp off, Camera2D smoothing per frame): pixel==ideal | 99.7 % | 72.5 % | 75.2 % | 71.1 % |
| same: on-screen back-and-forth | 5.0 /s | 25.4 /s | 30.2 /s | 22.2 /s |
| Interp on, camera unchanged: pixel==ideal / back-and-forth | 99.7 % / 7.4 | 99.8 % / 16.2 | 98.1 % / 31.4 | 99.9 % / 29.2 |
| Interp on + Camera2D `process_callback` physics (identical to the row above: the setting has no effect with interpolation on) | 99.7 % / 7.4 | - | 98.1 % / 31.4 | 99.9 % / 29.2 |
| Interp on + look-ahead and shake moved to `_physics_process` | 99.7 % / 5.0 | - | 98.1 % / 28.4 | 99.9 % / 30.0 |
| Interp off, whole camera in physics (60 Hz look everywhere) | 99.7 % / 7.4 | - | 74.3 % / **0** | 71.1 % / **0** |
| **Interp on + pixel-locked camera** (below) | **99.7 % / 0.2** | - | **98.1 % / 0** | **99.9 % / 0** |
| Interp off + pixel-locked camera | 99.7 % / **0** | - | 74.3 % / 32.6 | - |

Reading:
- **Without interpolation, high refresh shows the slime on a 60 Hz cadence**, held for 2-3 frames unevenly at
  144 Hz (judder).
- **The 1 px twitch comes from the camera.** Camera2D smoothing and `_look_ahead.round()` are rounded separately from
  the slime's own snapping, so the slime-to-screen offset flickers by 1 px whenever the two round differently.
- **Interpolation fixes the cadence but not the twitch. The pixel-locked camera fixes the twitch**, even at 60 Hz
  today (5/s → 0).
- **Pixel-locked camera** (scratch implementation in `perf/pace.gd` `PixelCam`):
  - turn off Camera2D smoothing and make the camera `top_level`;
  - each `_process`: `target = lerp(prev_tick_pos, cur_tick_pos, Engine.get_physics_interpolation_fraction()) + look_ahead`;
  - `smooth = smooth.lerp(target, min(8 * delta, 1))` (the same exponential as `position_smoothing_speed = 8`);
  - `camera.global_position = target.round() + (smooth - target).round()`.
  The camera's lag behind the slime stays the same smooth ease, but it moves in whole pixels in step with the slime's
  own pixels. The output is indistinguishable apart from the missing 1 px twitches.
- **Fog hole:** `game.gd:616-623` sets `slime_px` from the physics position. With interpolation on, it was 1 px off
  the drawn slime in 54-97 % of frames (0 % today). It must use the same interpolated position.
- **Hat bug (high refresh, with or without interpolation):** `hat.gd:87-96` `_fly` gets the slime's speed from
  per-render-frame deltas: `(slime_at - _slime_last) / delta`. Above 60 Hz the slime moves only on physics ticks, so
  that speed alternates between 0 and 2-4x the real speed, and `jolt` swings to ±MAX_JOLT. Measured in the engine at
  144 Hz on L10: **128 one-frame reversals of up to 5.2 px in 5 s** (0 at 60 Hz). A simulation gives ±4.6 px every
  frame during a 220 px/s leap at 120/144/240 Hz. Fix: update the speed and jolt in `_physics_process` (or only on
  frames where a physics tick happened), and keep the position follow per frame. No change at 60 Hz.
- **Not a problem:** the fog shader's `now` steps at 60 Hz (physics `elapsed`). That moves the mist by about 0.06 px
  per tick, which is invisible. Menus, the story, the transition wipe, the hub UI and the HUD are driven from
  `_process` and are smooth at any rate already.
- **Hub:** the room turn (`hub.gd:752-760`) animates in `_physics_process`. Without interpolation it steps at 60 Hz at
  144 Hz. If the hub stations get interpolation, `_place_all`'s `turn` (shader uniform + sprites) should be animated
  from `_process` (time-based) so the floor shader and the sprites stay in step.

### Settings plan (Godot 4.7.2)

`project.godot`:
```
[physics]
common/physics_interpolation=true
common/physics_jitter_fix=0.0        ; Godot's guidance when interpolation is on (the fraction handles pacing)
; common/physics_ticks_per_second stays 60 (more ticks changes feel and cost: FIDELITY RISK - do not apply)
; common/max_physics_steps_per_frame stays 8
[display]
; window/vsync/vsync_mode stays 1 (Enabled): render at the monitor's rate; no max_fps cap (application/run/max_fps=0)
[rendering]
; 2d/snap/snap_2d_transforms_to_pixel stays true (interpolated positions still land on whole pixels: measured 98-100 % on the ideal pixel)
```
- **Opt in, not opt out.** With the global switch on, every Node2D moved from `_process` would be interpolated between
  stale ticks and wobble. These include:
  - `menu_backdrop.gd:77`, `skin_showcase.gd:106`, `hat_wheel.gd:515`, `ticket_goal.gd:44`, the story screen's nodes;
  - `game.gd:616` `slime_light`;
  - the hat, the motes' follow, and the Glimmers.

  So set `physics_interpolation_mode = OFF` on the scene tree root at startup (in `Progress._ready` or `Transition`),
  and set `ON` only on what physics moves: the `Slime` (main + hub), the hub's station bodies and sprites, ability
  projectiles and dashes (`ability_runner.gd` inner classes move in `_physics_process`), and goo drops/coins if they
  are ever moved in physics.
- **Code changes that go with it:**
  1. **Pixel-locked camera** (above), replacing Camera2D smoothing in `scenes/slime.tscn:30-34` and
     `game.gd:683-700` (look-ahead and shake stay as they are, applied to the target).
  2. **`slime_px` / `slime_light` from the interpolated slime position** (`game.gd:616-623`), with `slime_light` set
     to interpolation OFF.
  3. **`hat.gd`:** OFF, follow the interpolated head point, and move `_fly`'s speed/jolt to physics ticks.
- **`reset_physics_interpolation()` after teleports:**
  - the slime after `game.gd:467` (start cell);
  - `hub.gd:314` (return position);
  - wherever a Descent or other flow repositions it without a scene reload;
  - the pixel cam's `prev/cur/smooth` together with `camera.reset_smoothing()` (`game.gd:492`).

  Retries, new mazes and floors reload the scene, so they start fresh.
- **Verification for the implementation half:**
  - 60 Hz pixel diffs of the existing fixed-seed frame sets should match except the removed 1 px twitch frames (show
    those to the owner);
  - re-run `perf/pace.gd` at 60/144/240: pixel==ideal ≥ 98 %, back-and-forth 0, fog hole on the sprite 100 %, hat
    reversals 0.
- **Rejected options:**
  - capping `max_fps` to 60 gives 2-3 frame judder on 144 Hz panels;
  - raising physics ticks to 120/144 changes jump arcs, drain timing and cost (**FIDELITY RISK - do not apply**);
  - VSync Adaptive could be offered on desktop later if low-end PCs drop to 30 when they miss vsync. Not needed now.
- **Frame budget at high refresh:** 240 Hz = 4.17 ms, 144 Hz = 6.9 ms. On the M3, gameplay p99 is 3.0 ms (fits 240);
  rainbow skins (p99 5.1) and the hub (p99 4.2) fit 144 but not 240.

## 5. Long session, leaks, logs

- **Soak** (`perf/soak.gd`, headless, 60.4 simulated minutes in 172 s, 64 cycles of:
  - hub → story level (1-10, every third on hard, autopilot) → R restart → hub;
  - randomizer (MORE SLIME 0-7) → pause;
  - skins (rainbow every 4th) → maps → level select → upgrades.

  Results:
  - 192 level starts;
  - **nodes +0, orphans +0, resources +0, objects -10**;
  - static memory +1,885 KB (10.1 KB per level start);
  - RSS 189 → 218 MB, levelling off after about 20 minutes;
  - the time per simulated minute is flat from the first to the last decade (2.5-3.2 s, depending on the level mix);
  - no slowdown.
- **The "~9 KB per level start" creep, re-measured and attributed** (`perf/soak2.gd`, 400 changes of one kind each,
  last 300 counted):

  | Kind of change | Static memory per change |
  |---|---|
  | L1 start | 1.65 KB |
  | L1 retry | 1.53 KB |
  | L10 | 1.57 KB |
  | randomizer, same seed | 1.61 KB |
  | randomizer, new seeds | 1.70 KB |
  | hub ↔ settings | 2.69 KB |
  | skins ↔ settings | -1.04 KB |

  - It grows in doubling steps (227 → 484 → 934 KB), which looks like an engine container resizing.
  - It is the same whatever the content, and objects, nodes and resources stay flat. No GDScript cache grows. The
    script-side caches were checked to be bounded in the qa-release report; the only unbounded one is
    `Progress.random_attempts`, at about 100 B per new maze, which is negligible.
  - Projection: a 4-hour session of about 2,000 scene changes adds roughly 3-5 MB. **No action.**
- **Logs:** no script errors in any run. The engine's exit-time "N ObjectDB instances leaked / N resources still in
  use" pair appears in headless runs and varies from run to run, as QA noted. It is exit-only and does not grow.

## 6. Web build (Chromium 152 on the M3, debug Web export, no threads)

`perf/webprobe.gd` cycled title → hub → level select → skins → L1 → L10 → random 36x20 → Descent → hub → L10 →
random → story → upgrades → maps, with 240 frames of autopilot play on each.

Steady frames:
- **every scene held vsync, 60 Hz** (avg 16.6 ms, max 18.0 ms), and no long task during play;
- the per-frame work time could not be read: a second run with that probe stalled because the hidden browser pane
  pauses `requestAnimationFrame`.

Main-thread long tasks (PerformanceObserver) appeared **only at scene changes**:

| Change | First use | Warm |
|---|---|---|
| title (first) | 616 ms | - |
| hub | 200 ms | 24 ms |
| level select | 96 ms | - |
| skins | 102 ms | - |
| L1 (main.tscn) | 359 ms | - |
| L10 | 31 ms | 47 ms |
| randomizer 36x20 | 126 ms | 84 ms |
| Descent | 99 ms | - |
| upgrades | 88 ms | - |
| maps | 87 ms | - |

On the M3, WASM is about native speed for these loads, so a mid phone at 4-8x slower than the M3 would see:
- **0.35-1 s** frozen cover on a new randomizer maze or Descent floor;
- **1.5-3 s** on the first level of a session;
- **2.5-5 s** for the first title.

Those are the web items to attack: the maze tile fill, drop cells, and preloading main.tscn during the title's idle
time (startup-memory-web.md F10).

## 7. The ~27-minute nav-fuzz web/touch runs

- QA's logs (`/private/tmp/claude-501/qa1/fuzz_*.log`) report the fuzzer's own elapsed time: 68-97 s for touch/web,
  127-175 s for default. Godot's clock (`Time.get_ticks_msec`) does not advance while macOS sleeps.
- The files' creation and modification times span **27-71 minutes** per batch. Every batch ended at one of the
  `DarkWake` events in `pmset -g log` for 2026-10-15 (18:57:55, 20:08:22, 20:40:49, 21:07:21).
- The Mac was in Deep Idle from about 18:2x until a lid/HID wake at 21:07:21, and only ran during the short dark
  wakes. The batches after 21:07 took 68-88 s wall each.
- Re-run here on the current tests: `--nav-variant=web` and `--nav-variant=touch` took **58 s wall each**, equal to
  the fuzzer's internal elapsed time. The 50 hub ↔ map cycles inside it kept nodes at 245 and objects at 5,751 →
  5,772.
- **Not game-side slowness.** Long unattended runs need the machine kept awake (the desktop app's keep-awake only
  holds while a session turn is active, and never with the lid closed).

## 8. Low-end estimates (assumptions stated)

Scaling from the M3 numbers above. These are estimates, not measurements.

Assumptions:
- **Low-end PC** (e.g. a 2015 dual-core i3 with Intel HD 4400, desktop GL): CPU/GDScript ×3-4, GPU fill ×15-20.
  The fill is tiny at 320x180; the only full-resolution pass is the final upscale blit.
- **Low-to-mid phone** (Snapdragon 6xx / Helio G8x, native Android GLES3 or Chrome WebGL2): GDScript ×8-12 native and
  ×10-15 web; render CPU ×6-10; about 20-40 µs per draw call (driver/ANGLE); GPU ×20-40; a 1-2 ms upscale blit to
  device resolution.

| Scene | Low-end PC | Low-to-mid phone (native / web) | 60 fps? |
|---|---|---|---|
| menus, hub (plain skins) | 3-5 ms | 6-10 / 8-14 ms | yes |
| gameplay L10 / randomizer max, 110-128 draw calls | 6-8 ms | 10-16 / 13-20 ms | phone web is borderline. With the tile split (30 draw calls): about 2-3 ms less → yes |
| L10 rainbow + full upgrades | 10-12 ms | 18-28 / 25-38 ms | **no on phones** |
| hub rainbow | 9-11 ms | 18-26 / 25-35 ms | **no on phones** |
| skins screen rainbow | 13-16 ms | 25-40 / 35-55 ms | **no** (PC borderline) |
| story intro | 6-8 ms | 10-14 / 12-18 ms | yes |
| scene changes (warm randomizer / first level) | 0.3 / 1 s | 0.5-1 / 1.5-3 s | a hitch under full cover |

## 9. Ranked optimizations (fidelity-preserving) for the implementation half

Format: **file:line** - issue - fix - measured or expected gain - risk - effort.

1. **`scripts/maze_tiles.gd:112-118` (`add_border`)** - border tiles from atlases 3 and 4 share the `Walls` layer with
   atlas 0, so batching breaks at every texture switch. L5 has 340 + 240 + 108 cells across three sources, and the
   `Walls` layer alone accounts for about 100 of 127 draw calls.
   - Fix: put the border sources on their own TileMapLayer(s) (same z, right after `Walls`). Collision stays where the
     ring's colliding tiles are.
   - Measured: **L5 127 → 30 and L10 96 → 30 draw calls**. Expected 2-4 ms per frame on mobile WebGL.
   - Risk: low-M. Draw order only matters where tiles overlap; confirm with the 0-px diff sets from batch A/B. Effort S-M.
   - Also check `MenuBackdrop` (level select 52 draw calls) for the same pattern.
2. **High-refresh plan** (section 4): interpolation opt-in, pixel-locked camera, interpolated `slime_px`/light, `hat.gd`
   speed per tick, the resets.
   - Measured: 1 px twitches 22-30/s → 0, frames on the ideal pixel 71-75 % → 98-100 % at 120-240 Hz, and 5/s → 0
     twitches at 60 Hz. Hat ±2.5 px flicker → 0.
   - Risk: M (camera feel: verify with the owner). Effort M.
   - **`hat.gd:87-96` alone is a standalone bug fix** (S, no risk at 60 Hz) and can ship first.
3. **Rainbow UI re-theme** (`skin_text.gd`, `goo_box.gd`; measurements.md #1/#5 option 2) - still +2.8 ms (skins),
   +1.9 ms (hub), +1.2 ms (L10) per frame on the M3 after batch A.
   - Fix: bake GooBox frames to palette-index textures recoloured by one shader uniform, and tint labels through
     `self_modulate`/vertex colour instead of theme or override changes.
   - Expected: those screens get back to about +0.2 ms, i.e. 25-55 ms → under 10 ms on phones.
   - Risk: M (pixel parity per state). Effort M-L.
4. **`scripts/maze_tiles.gd:52-118` + `game.gd:452-453` (tile fill on every start)** - 4.3 / 17.6 / 31.6 ms warm
   (L1 / L10 / 36x20), repeated on every retry/replay of the same maze.
   - Fix: cache the filled layers' `tile_map_data` (PackedByteArray) per (maze seed, size, theme, broken-wall-free)
     and assign it on a repeat build; for new mazes, profile `construction_at` noise per cell.
   - Expected: retries −17 to −32 ms native (×4-8 on phone web); warm randomizer change 66 → about 35 ms.
   - Risk: low (deterministic; compare tile data byte for byte). Effort S-M.
5. **`scripts/descent.gd:140-145` → `Levels.coin_cells`** - about 11 ms per Descent floor on 36x20 mazes. Fix: a
   lighter dead-end search for drops, or memoise per (seed, floor) for retries. Expected −8 to −11 ms per floor
   (×4-8 web). Risk: low (same cells; golden test). Effort S.
6. **Cold first loads** - main.tscn 371 ms native / 359 ms web on the first level, hub 205 / 200, title 616 ms web.
   - Fix: preload `main.tscn`, `hub.tscn` and `story.tscn` a few frames after the title shows (threaded request on
     desktop; deferred plain `load` on web while the title idles), as in startup-memory-web.md F10.
   - Expected: the first level's covered stall 329 → about 25 ms. Risk: low (about 1-2 MB more memory). Effort S-M.
7. **`scripts/ui/title.gd:83`** - add `goo_wipe` (and `atmosphere`, `slime_skin`, `text_drips` for completeness) to
   the warm-up list. The first transition's first frame compiles `goo_wipe` today. Expected: removes a first-wipe
   compile (largest on Windows ANGLE). Risk: none. Effort S.
8. **`game.gd:610-612` → `_refresh_attempt_pod` / `_refresh_descent_pod`** - 8.3 / 5.1 µs per frame of dictionaries
   and string formatting. Fix: recompute only when `attempt`, `wind_fired`, `dev_toggled`/`assisted`, the day or the
   pot changes (same text). Expected about 0.1 ms per frame on phone web. Risk: low (the pod must never go stale;
   keep a cheap change key). Effort S.
9. **Leave alone (measured negligible):** abilities fx, particles, coins, draw calls in menus (27-78), node and object
   counts (94-282 nodes), VRAM (7-20 MB), the exit-time leak lines, `&StringName` literals, and the static-memory
   creep of about 2 KB per scene change.

FIDELITY RISK - do not apply: physics ticks above 60, a render cap at 60 on high-refresh panels, throttling the
rainbow update, and lossy or VRAM texture compression (the earlier list in [../perf/](../perf/) still stands).
