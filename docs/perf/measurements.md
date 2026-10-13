# Frame-time measurements (profiling pass) - 2026-10-13

Measured, not estimated, where frame time goes in Slime Time (Godot 4.7.2, `gl_compatibility`, 320x180 base with
`viewport` stretch), so optimizations can target real hotspots without touching the look. Companion audits from
reading the code: [cpu.md](cpu.md), [rendering.md](rendering.md), [startup-memory-web.md](startup-memory-web.md).
Branch `v2` at `e368448`. No repo file was changed; all instrumentation lived in a scratch copy.

**Headline:** on this machine every normal scene runs at about 1-1.6 ms a frame. The GPU fill is tiny because the
game draws only 320x180 = 57,600 px per frame. The real costs are on the CPU: GDScript work and Godot UI/theme
churn. Ranked by measured cost:

1. The **rainbow skin's per-frame UI recolor**: +5 ms per frame in levels, +8 ms in the hub, +15 ms on the skins
   screen, on an M3.
2. **Full re-upload of the fog and trail textures nearly every frame.** This grows with maze area: 0.19 ms CPU and
   1.65 MB per frame on a 36x20 randomizer maze.
3. **GDScript fog bookkeeping** (`_relight`, `_paint_cells`, `_reveal_light`): 0.15 ms per frame, or 1.2 ms per frame
   with Brightness 10.
4. The **story intro's immediate-mode `_draw`**: 0.4 ms average, 0.9 ms p95.
5. **GooBox frames** drawn as one 1x1 rect per pixel: 120 µs of GDScript per box per redraw, and 5,400 of the skins
   screen's 8,250 canvas items.

On the GPU, the **fog shader** is about 60% of gameplay fill (about 15x a plain sprite per pixel). The **atmosphere
vignette** computes mist noise even when the mist is off (4x a plain sprite). Both are cheap in absolute terms at
320x180.

---

## 1. Methodology

**Machine:** MacBook Pro, Apple M3 (10-core GPU), macOS 14.5. Godot 4.7.2 official, OpenGL 4.1 on Metal,
Compatibility renderer. **Noise caveat:** the owner's dev build (`Godot --path slime-time -- --unlock-all`) was
running throughout at about 45% CPU, and was deliberately left alone. Wall-clock frame times therefore have about
±0.3 ms of noise and occasional 8-15 ms OS-scheduling spikes. All the conclusions below rest on deltas that are
well above that noise, or on direct in-script timers that don't suffer from it.

**Isolation:** the project was rsynced to `/private/tmp/claude-501/proj_copy` (no `.git`, `build`, `docs`). Its
`project.godot` got `config/use_custom_user_dir=true` (`slime_perf_copy`), so no run could read or write the real
save. Every run also passed debug flags that disable saving.

**Driver** (`/private/tmp/claude-501/proj_copy/perf/driver.gd`, a `SceneTree` script run with
`Godot --path proj_copy --fixed-fps 60 -s res://perf/driver.gd -- --perf-target=... <game flags>`):
- Vsync is turned off, so frames run uncapped. `--fixed-fps 60` keeps the simulation identical from run to run.
  120 warm-up frames are followed by 400-600 measured frames.
- Per frame it records:
  - wall-clock frame time;
  - node `_process` time and summed `_physics_process` time, timed by two stamp nodes at priority -1e6 and +1e6;
  - render CPU (`viewport_get_measured_render_time_cpu` plus `get_frame_setup_time_cpu`);
  - `RENDER_TOTAL_DRAW_CALLS/OBJECTS/PRIMITIVES_IN_FRAME`;
  - `OBJECT_NODE_COUNT`, `RENDER_VIDEO_MEM_USED` and `RENDER_TEXTURE_MEM_USED`;
  - the load frame;
  - every frame over 8 ms.
- **Instrumented copy:** in the copy only, `game.gd` `_physics_process`, `_process`, `_flush_textures`, `_relight`
  and `_paint_goo` got µs timers and texture-upload counters. `hub.gd` got process timers, and the story screen's
  `StageArt._draw`/`Layer._draw` and `GooBox._draw` got per-frame µs/count meters. `skin_text.gd` got environment
  switches that skip each recolor step.
- **A/B toggles** apply after warm-up without editing game logic: hide or strip the material of items by shader
  name, hide additive items, particles, tilemaps, labels or the menu backdrop, and named switches for fog, outer fog,
  trail glow, slime light, motes, HUD, hub pools and hub room.
- **Scenarios:**
  - title;
  - hub with all 8 stations (`--unlock-all`);
  - `tests/demo.tscn` autopilot mid-run on L1 (lime), L5 (grape) and L10 (ember);
  - **randomizer seed 5 at MORE SLIME 10**, which gives the maximum 36x20 cells (73x41 tiles, fog image 600x344).
    This seed was found by scanning `Levels.random_cells(seed, 10)`; seeds 2, 5, 8, 15 and 16 all hit 36x20.
    Code `5-10`, `--upgrades=10,0,0`;
  - the story intro (`scenes/story.tscn`, 1,800 frames);
  - the skins screen with Stopwatch;
  - an "effects" run: L10, rainbow skin with `--all-coins`, upgrades 10/10/10, and a forced leap/splat every 25
    frames.
- **GPU:** the Compatibility renderer reports no GPU timers. Both `viewport_get_measured_render_time_gpu` and the
  movie writer's "GPU render time" print 0.00. GPU cost was therefore measured in two ways:
  - **Stress mode:** the canvas is rendered at 8x (window 2560x1440, `CONTENT_SCALE_MODE_CANVAS_ITEMS`), so every
    fragment cost is multiplied by 64 and becomes visible in wall time. A/B toggles were interleaved over 3 reps,
    and the medians are reported.
  - **Microbenchmark** (`perf/micro.gd`): 8 full-screen layers of one shader at 2560x1440 minus 0 layers, giving
    ms per full-screen layer. Each shader is expressed in "plain-sprite units" (1 unit = one opaque textured
    full-screen sprite).
- **Phone and web estimates** are extrapolations, labelled as such. They use x8-15 for CPU/GDScript (WASM without
  threads on a mid-range Android core versus native M3) and x20-40 for GPU (mobile GPU versus M3).

## 2. Baselines (native 320x180, vsync off, M3)

"script" = node `_process` + `_physics_process` (inside the stamps). "render CPU" = Godot's canvas render prep.
Deferred UI work (theme propagation, Control redraws, StyleBox `_draw`) falls *outside* both, so a gap between
frame time and script + render CPU means UI churn. The max column excludes the load frame. The load column is the
scene-change frame.

| Scenario | avg ms | p50 | p95 | p99 | max | script ms | render CPU ms | draw calls | canvas objs | prims | nodes | VRAM MB | load ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Title | 0.97 | 0.75 | 2.30 | 5.5 | 9.5 | 0.004 | 0.15 | 14 | 2,127 | 4,268 | 86 | 9.1 | 61 |
| Hub, 8 stations | 1.03 | 0.76 | 2.29 | 8.2 | 17.2 | 0.04 | 0.14 | 25 | 33 | 66 | 185 | 14.2 | 63 |
| Level 1 (21x13 tiles) | 1.17 | 0.96 | 2.47 | 5.0 | 12.7 | 0.20 | 0.20 | 33 | 850 | 1,745 | 196 | 17.4 | 74 |
| Level 5 (33x19) | 1.27 | 1.04 | 3.21 | 4.9 | 8.6 | 0.24 | 0.21 | 34 | 1,198 | 2,435 | 212 | 17.6 | 85 |
| Level 10 (53x29) | 1.48 | 1.21 | 3.85 | 5.5 | 9.2 | 0.30 | 0.23 | 35 | 1,681 | 3,435 | 246 | 18.2 | 120 |
| Randomizer 36x20 cells (73x41) | 1.63 | 1.36 | 4.21 | 5.1 | 9.6 | 0.38 | 0.20 | 27 | 1,255 | 2,554 | 186 | 18.8 | 133 |
| Story intro (30 s) | 1.84 | 1.66 | 4.50 | 5.7 | 18.3 | 0.03 (+0.41 `_draw`) | 0.25 | 39 | 972 | 2,779 | 81 | 7.1 | 27 |
| Skins screen, Stopwatch | 1.47 | 1.16 | 4.06 | 5.5 | 8.6 | 0.08 | **0.40** | 43 | **8,251** | **16,516** | 218 | 9.0 | 78 |
| L10, ember skin + a leap/splat every 25 frames | 1.11 | - | 2.54 | - | 4.3 | 0.23 | 0.18 | 32 | 1,064 | 2,226 | 247 | 18.2 | - |
| **Effects: L10 rainbow + upgrades 10/10/10 + leaps** | **7.39** | 6.92 | 10.3 | 11.1 | 14.3 | 1.51 | 0.20 | 28 | 1,039 | 2,175 | 185 | 18.2 | 113 |
| **Hub, rainbow** | **8.87** | 8.70 | 11.0 | 12.1 | 12.5 | 0.50 | 0.15 | 25 | 33 | 66 | 185 | 14.2 | - |
| **Level 10, rainbow** | **6.00** | 5.80 | 8.31 | 9.3 | 11.2 | 0.73 | 0.21 | 27 | 1,670 | 3,413 | 184 | 18.1 | - |
| **Skins screen, rainbow** | **16.66** | 16.6 | 17.5 | 17.8 | 20.4 | 0.34 (+3.74 GooBox `_draw`) | 0.40 | 43 | 8,247 | 16,508 | 205 | 9.0 | 78 |
| Title, rainbow | 3.25 | 2.67 | 6.51 | 7.1 | 13.4 | 0.07 (+0.33 GooBox) | 0.17 | 14 | 2,127 | 4,268 | 86 | 9.1 | 62 |
| Level 1, Stopwatch skin | 1.30 | - | 2.60 | - | 15.2 | 0.18 | 0.19 | - | - | - | - | - | - |

### Gameplay script breakdown (ms per frame, from the instrumented copy)

| Scenario | game `_physics_process` | of which `_relight` | `_paint_goo` | game `_process` | of which `_flush_textures` | fog / trail uploads |
|---|---|---|---|---|---|---|
| L1 (fog image 184x120) | 0.149 | 0.091 | 0.049 | 0.024 | 0.023 | - |
| L5 (280x168) | 0.163 | 0.095 | 0.057 | 0.046 | 0.047 | - |
| L10 (440x248) | 0.164 | 0.094 | 0.057 | 0.098 | 0.102 | - |
| Randomizer 36x20 (600x344) | 0.162 | 0.093 | 0.058 | 0.168 | **0.190** | **705 / 699 of 721 frames** |
| L10 + Brightness/Slime/Speed 10 | **1.193** | **0.532** | 0.054 | 0.100 | 0.095 | - |

With Brightness 10, `_reveal_light` (inside physics, not separately timed) takes the remaining ~0.6 ms.

Stopwatch is cheap everywhere (L1 1.30 ms, hub 0.98 ms), and the skins screen with Stopwatch is in line with the
other menus. Only the rainbow skin has the per-frame UI cost.

### Load and hitches
- **Scene-change frame:**
  - title 61 ms, hub 63 ms;
  - L1 74 ms, L5 85 ms, L10 120 ms, randomizer 36x20 133 ms (+ about 40-50 ms on the next frame);
  - story 27 ms.
  Maze generation alone (headless) is 0.8 ms for L1, 2.4 ms for L5, 18.8 ms for L10 and 21.7 ms for the 36x20
  randomizer. The rest is `_ready` (tile fill, overlays) and the first render.
- **First-render hitch:** the first frames after a level loads report 44-76 ms of render CPU (shader/material and
  tilemap setup). It was 7.9 ms at frame 9 of L5 in another run.
- **Mid-run spikes:** 8-30 ms frames appear at similar times in every level run (about 2 s and 4.5 s in). They show
  ~0 script time and ~0.2 ms render CPU, so the time goes outside every measured block. They could not be pinned to
  game code, and the concurrently running dev build is the likeliest cause. Re-check on an idle machine before
  acting on them.

## 3. GPU cost (fill), measured two ways

### Microbenchmark: cost of one full-screen layer per shader
Measured at 2560x1440 (3.69 MP); 1 unit = a plain textured sprite = 0.144 ms per layer at 3.69 MP.

| Shader (as used) | ms per full-screen layer @3.69 MP | units | Where / coverage at 320x180 |
|---|---|---|---|
| `fog.gdshader`, lit cells (13 taps, each decoding a cell, + 3 sin-hash value noises) | 2.13 | **14.8** | maze fog: whole view, every gameplay frame |
| `fog.gdshader`, unrevealed cells | 1.47 | **10.2** | same; outer fog covers the view beyond the maze |
| `goo_wipe.gdshader` | 0.78 | 5.4 | only during scene transitions |
| `hub_room.gdshader` | 0.63 | 4.4 | hub: whole view |
| `atmosphere.gdshader`, mist on **or off** (the noise is computed anyway) | 0.58 | **4.0** | HUD vignette in levels, hub vignette, menu mist: whole view |
| `slime_skin.gdshader` (gloss, jelly) | 0.42 | 2.9 | slime sprite only (~20x20 px) |
| `trail.gdshader` (90% painted) | 0.265 | 1.8 | maze rect (discard where unpainted) |
| trail glow (additive, linear) | 0.135 | 0.9 | maze rect |
| plain sprite | 0.144 | 1.0 | tiles, sprites |

### In-scene A/B at 8x scale (64x the fragments)
Median of 3 interleaved reps, wall ms; base cost of the window at this size is about 2.4 ms. The level is L10 in
ember.

| Level 10 toggle | p50 ms | delta vs none |
|---|---|---|
| none | 4.98 | - |
| fog (inner + outer) hidden | 2.79 | **-2.19** |
| HUD hidden (vignette + pods + text) | 3.88 | -1.10 |
| outer fog only hidden | 4.19 | -0.79 |
| tilemaps hidden (floor, walls, fillets) | 4.28 | -0.70 |
| HUD vignette (`atmosphere`) hidden | 4.33 | -0.65 |
| labels hidden | 4.47 | -0.51 |
| motes hidden | 4.59 | -0.39 (within noise) |
| trail glow hidden | 4.62 | -0.36 |
| trail shader removed | 4.68 | -0.30 |
| slime skin shader removed | 4.82 | -0.16 |
| text drips shader removed | 4.88 | -0.09 |
| slime light hidden | 4.97 | ~0 |

| Hub toggle | p50 ms | delta |
|---|---|---|
| none | 2.76 | - |
| `hub_room` hidden | 2.15 | -0.61 |
| vignette (`atmosphere`) hidden | 2.18 | -0.58 |
| slime_skin removed / labels hidden / pools hidden | 2.87-3.11 | ~0 (noise) |

**Reading.**
- **Gameplay** fill is about 22-25 units per frame. The fog (inner + outer) is about 13-15 units, roughly 60%. The
  HUD vignette is 4 units (about 17%). Tiles are about 2, trail + glow about 2.7, everything else under 1.
- At the real 320x180 that is about 55 µs per frame on the M3, so a mobile GPU at 20-40x slower spends about
  1-2 ms. Fill is **not** a frame-rate problem today, but the fog is where any GPU savings are.
- **Hub** is about 9 units (`hub_room` 4.4 + vignette 4). Hub pools, particles (motes at most 28, CPUParticles),
  the slime light and the trail glow have no measurable cost.
- **Draw calls are low everywhere (14-43).** Batching works; draw-call reduction is not worth pursuing.

## 4. Ranked hotspots (with evidence)

1. **Rainbow skin: `SkinText._process` → `recolor()` every frame.**
   - **Measured cost on the M3:** hub +8.1 ms (8.87 vs 0.76 ms p50), L10 +5.0 ms, skins screen +15 ms (16.7 ms per
     frame, about 60 fps max), title +2.3 ms.
   - **Split by switching each step off:**
     - `theme.set_color` ×10 per frame on the shared theme: about 5 ms in the hub, 2.3 ms in a level. Each call
       propagates `THEME_CHANGED` and relayout through the Control tree.
     - `GooBox.set_goo_color` → `emit_changed` on every live box: about 2 ms in the hub, 0.9 ms in a level, and
       3.74 ms of GooBox `_draw` for 31 boxes on the skins screen.
     - `add_theme_color_override` on every label: about 0.7 ms plus 0.4 ms of script.
   - Almost all of it lands outside `_process`, as deferred notifications and redraws.
   - **Phone/web estimate:** 40-120 ms per frame in the hub, 120-250 ms on the skins screen, so single-digit fps.
     This is the worst problem in the game for anyone wearing rainbow.
2. **Fog + trail textures re-uploaded in full almost every frame** (`_flush_textures` → `ImageTexture.update`).
   - Both images were uploaded in 705 and 699 of 721 frames while moving.
   - Each upload is the whole image: 600x344x4 = 825 KB, so **1.65 MB per frame (about 99 MB/s)** on a 36x20
     randomizer maze.
   - CPU cost grows with area: 0.023 ms (L1), 0.047 ms (L5), 0.10 ms (L10), 0.19 ms (36x20), plus driver and GPU
     transfer that isn't visible here.
   - On mobile WebGL a full `texSubImage2D` of that size is typically several ms, and it is paid every frame.
3. **GDScript fog bookkeeping per physics frame.**
   - `_relight` runs on every 2 px cell change, not just once per fog tick (16 Hz). It walks a (2r/2)² square with
     two `get_pixelv` per cell: 0.09 ms at r = 20.
   - With Brightness 10 (r = 45, 5x the cells), physics takes 1.19 ms: relight 0.53 ms plus `_reveal_light` about
     0.6 ms.
   - `_paint_cells` costs 0.05 ms.
   - **Phone/web estimate:** 1.5-2.5 ms normally, 10-18 ms per frame at Brightness 10.
4. **Story intro: everything redrawn in GDScript every frame** (`StageArt._draw`, `Layer._draw`, about 220
   `draw_*` call sites; bricks, arches and floors are re-issued each frame).
   - **Measured:** 0.41 ms average, 0.90 ms p95 of `_draw` per frame, the largest steady script cost of any
     non-rainbow scene.
   - **Phone/web estimate:** 4-13 ms.
5. **GooBox frames: one `canvas_item_add_rect` per pixel**, through a `Callable` per pixel.
   - **Measured:** about 120 µs of GDScript per box per redraw (3.74 ms for 31 boxes). Hiding labels and buttons on
     the skins screen drops canvas objects from 8,251 to 2,860 and primitives from 16,516 to 5,720, and halves
     render CPU (0.40 → 0.17 ms).
   - Every redraw re-runs the loops: screen open, hover or focus changes, and (rainbow) every frame. This shows up
     as open/hover hitches on phones (about 30-55 ms for a full screen of boxes).
6. **Fog shader fill** (GPU): 14.8 units for lit cells and 10.2 for unrevealed cells, covering the whole view twice
   over (inner + outer, where the outer one discards inside the hole). It is about 60% of gameplay fill. Each
   fragment does 13 taps, each running the full `cell_alpha` decode, plus 3 value noises (12 `sin` hashes).
7. **Atmosphere vignette computes the mist noise even when `mist_strength = 0`** (in-game HUD and hub). That is
   4.0 units for the whole view, where about 1.2 would do. It is about 17% of gameplay fill and about 45% of the
   hub's.
8. **Load:** 61-133 ms native per scene change, plus 44-76 ms of first-render render CPU in levels. Maze generation
   is 19-22 ms on big mazes. Phone/web estimate: 0.5-2 s per level load, with a visible hitch on the first frames.
9. **Not hotspots (measured, keep as they are):**
   - motes (max 28 CPU particles);
   - hub light pools;
   - the slime light;
   - the trail glow sprite (0.9 units);
   - `slime_skin` (only the slime's pixels);
   - draw calls (14-43);
   - node counts (81-248);
   - VRAM (7-19 MB native; the 36x20 fog/trail images add about 1.6 MB);
   - the Stopwatch skin.

## 5. Recommended optimizations (fidelity-preserving), in priority order

1. **Rainbow recolor without theme churn** (removes 5-15 ms on the M3):
   - Set the theme's Button/CheckBox font colors to white once.
   - Tint text through `self_modulate`, or the vertex `COLOR` that `text_drips` already passes through as `tint`.
     The color math (`color_for`) stays exactly the same.
   - Never call `theme.set_color` or `add_theme_color_override` per frame.
   - For goo frames: draw each box once in **palette indices** and recolor with a shared shader uniform, the same
     trick as `slime_skin.gdshader`. Rainbow then becomes one uniform write per frame and zero redraws.
   - Also skip `emit_changed` for boxes that are not visible.
2. **Upload only what changed:**
   - Split the fog and trail images into chunks, for example 64x64 cells, each its own `ImageTexture` + sprite. Give
     each fog chunk a 2-cell apron so the 13-tap blur is unchanged, and update only dirty chunks. That is about
     16-32 KB per frame instead of 1.65 MB, and the output is pixel-identical.
   - The cheaper interim fix: track a dirty rect and skip the upload entirely when no texel changed. Today the fog
     is re-uploaded on every relight call, even when only `_relit_cell` moved.
3. **Fog bookkeeping:**
   - Keep `_relight` to fog-tick changes (16 Hz, the shader's own time resolution). When the cell changes within a
     tick, process only the newly entered crescent.
   - Operate on a `PackedByteArray` (`get_data`/`set_data` per chunk) instead of `get_pixelv`/`set_pixelv` per
     cell. Do the same for `_reveal_light`.
   - Output is identical because the stored values are the same.
4. **Story intro:** bake each shot's static background (bricks, arches, floor, chambers) once into a texture or a
   `CanvasItem` drawn only when the shot changes. Scroll it by transform, and redraw only the animated parts
   (heroes, pops, lights, fades).
5. **GooBox:** generate each box's frame once into an `Image` → `ImageTexture` (cached by size, seed and state) and
   draw it with one `draw_texture`. Same pixels, about 500 fewer canvas items per box, and no per-pixel `Callable`.
6. **Fog shader** (GPU, same output):
   - Outer fog: when `hole.z > 0` every cell is unrevealed (the texture is 1x1), so `alpha = 1.0` and the 13 taps
     can be skipped.
   - Compute the falloff/vignette alpha first, and skip the mist noise where the final alpha is 0 (revealed ground
     near the slime). In that case `rgb` is irrelevant.
   - For more savings without a look change: evaluate `cell_alpha` once per fog cell in a small pre-pass at
     fog-texture resolution (4x fewer fragments), then blur that.
   - **Also flag:** `fog`, `atmosphere` and `hub_room` use the `fract(sin(dot(p, ...)) * 43758.5)` hash. On mediump
     mobile GPUs this hash bands or freezes. The sin-free hash already used in `trail.gdshader` keeps the look and
     is safer and cheaper.
7. **Atmosphere vignette:** `if (mist_strength > 0.0)` around the two noise calls (a uniform branch). With mist off
   the result is identical, and the HUD and hub vignette drop from about 4 to about 1.2 units.
8. **Load / first frame:**
   - Generate the maze during the goo-wipe cover.
   - Pre-warm each level material (fog, trail, glow, skin, coin, chalice, burst) by drawing it once while the wipe
     covers the screen, so the 44-76 ms of first-use render setup happens out of sight.
9. **Leave alone:** particles, pools, lights, trail glow, draw-call batching, node counts. They are measured as
   negligible.

## 6. Reproducing
Everything is in `/private/tmp/claude-501/proj_copy/perf/` (scratch; it will not survive a reboot):
- `run.sh TAG <args>` runs the driver;
- `baselines.sh 0|8` does all the scenarios at native or 8x stress;
- `ab.sh SCALE NAME "toggles" REPS <args>` with `abtable.py PREFIX` does interleaved A/B;
- `micro.gd` is the per-shader GPU microbenchmark;
- `find_seed.gd` finds max-size randomizer seeds;
- `loadtime.gd` times maze generation.

Raw logs (one `PERFJSON` line each) are in `/private/tmp/claude-501/perf_logs/`. Example:
`Godot --path proj_copy --fixed-fps 60 -s res://perf/driver.gd -- --perf-target=random --perf-seed=5 --unlock-all --upgrades=10,0,0 --skin=lime`.
