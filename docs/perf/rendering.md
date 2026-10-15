# Rendering performance audit (fidelity-preserving)

Scope: Godot 4.7.2, `gl_compatibility`, base 320x180 with `viewport` stretch and integer scale; desktop, web/itch
(WebGL2, **threads off**, so scripts and render prep share one main thread), low-end Android browsers.
Goal: higher frame rate with **pixel-identical** output (or, where marked, output that differs only by float
rounding at exact boundaries). Anything that would change the look is listed under **FIDELITY RISK - do not
apply** at the end.

This is a read-only audit. Nothing in the game was changed. The numbers are worked out from the code, not
profiled; the "how to verify" section at the end says how to confirm each one.

---

## 0. The big picture: where frame time goes

**GPU fill is not the bottleneck.** With `window/stretch/mode="viewport"`, every canvas item, the HUD included,
is drawn into a **320x180 = 57,600 px** target, then one nearest-neighbour blit scales it to the window. In
gameplay the shaded passes are:

| Pass (gameplay) | Coverage at 320x180 | Per-pixel work |
|---|---|---|
| Floor + Walls + Fillets TileMapLayers | ~1.6x | 1 tap, batched per atlas |
| Trail sprite (`trail.gdshader`, whole-maze quad) | 1.0x | 1 tap + discard, 5 taps on goo cells |
| Trail glow (additive linear copy) | 1.0x | 1 bilinear tap, additive blend |
| **Fog** (`fog.gdshader`) | 1.0x | **13 taps + 13 decodes + 3 value-noise (12 `sin`) = about 470 ALU** |
| Outer fog (same shader, 1x1 texture, `hole`) | 1.0x | discard inside the maze; the full fog cost where it shows |
| HUD vignette (`atmosphere.gdshader`) | 1.0x | bayer + smoothstep + **2 unused value-noise (8 `sin`)** |
| Slime light / chalice / coin glows (additive) | ~0.25x | 1 tap |
| Window blit | native resolution, e.g. 1920x1080 | 1 nearest tap |

That comes to about 6-7 full-screen equivalents, about 380k fragments a frame (about 23 Mfrag/s at 60 fps).
The fog's about 27 M ALU a frame (about 1.6 GALU/s) is a few percent of even a Mali-G52-class GPU. Shader
micro-optimisations are therefore **low priority** (items 7-9, 12) unless a profile shows the GPU is the limit.

**What does cost frame time, especially on web/Android:**
1. **Full-size texture uploads** of the fog and trail images, up to about 1.6 MB a frame (items 1-2).
2. **Thousands of 1x1 canvas rect commands** from `GooBox`, which the renderer walks and streams into its
   instance buffer every frame (item 4).
3. **With the rainbow skin:** `SkinText` re-themes the whole UI tree about 20 times a frame and makes every goo
   box re-run its GDScript `_draw` every frame (items 3-4). This affects the gameplay HUD too.

Already good, so leave it alone: no `hint_screen_texture`, no `BackBufferCopy`, no `CanvasGroup`, no
`clip_children`, no Light2D/CanvasModulate, no extra SubViewports in game. All textures are imported lossless
(`compress/mode=0`) with no mipmaps. Nearest filtering is the default. One shared `text_drips` material.
`ImageTexture.update()` is used (no re-allocation). Particles are CPU-side and capped (10-28). There is no HDR 2D
and no MSAA.

---

## 1. Ranked findings

Format: **file:line - issue - fidelity-preserving fix - expected gain - risk - effort**

### #1 `scripts/game.gd:900-906` (`_flush_textures`) + `:701-702` - fog and trail are re-uploaded whole every time one cell changes  [web/Android: HIGH]
- **Issue:** `ImageTexture.update(fog_image)` / `update(trail_image)` send the *entire* RGBA8 image (Godot 4 has
  no sub-rect update for `ImageTexture` on GL Compatibility). Image size is (maze tiles + 2 border) x 8 cells:
  - L1 (12x7 cells): 216x136 = **117 KB** per texture
  - L10 (26x14): 440x248 = **436 KB**
  - randomizer max (36x20): 600x344 = **826 KB**

  Fog uploads happen at least 16 times a second even while standing still (see #2). While gliding over new
  ground, `_paint_cells` (`:816-821`) dirties **both** textures on most physics frames, so worst case about
  60 x 1.65 MB = **~100 MB/s** goes through `texSubImage2D`. On WebGL that is copied out of the wasm heap and
  through Chrome's GPU-process command buffer. On tiled mobile GPUs, re-uploading a texture the previous frame
  is still sampling can also force a driver copy or stall.
- **Fix (pixel-identical):** split the fog and trail images into **chunks**, for example 64x64 cells
  (128x128 px), each with its own `ImageTexture` and Sprite2D. Give each chunk a **2-cell apron** copied from its
  neighbours, because the fog's 13-tap kernel reaches 2 cells out. On the maze's outer edge, fill the apron with
  the edge cell's value so it matches today's clamp-to-edge sampling. Each chunk sprite uses
  `region_enabled` / `region_rect` to show only its inner 64x64 cells, while the shader can still sample the
  apron. Then upload only dirty chunks. When a write lands in an apron cell, mark the neighbouring chunk dirty
  too. In the shader, work out `world_px` per chunk: either the chunk's own `origin`/`map_size` uniforms, or
  `MODEL_MATRIX * VERTEX` in `vertex()` so one material can be shared. The trail glow child stays one per trail
  chunk.
- **Gain:** a paint or relight disc (9-31 px radius) touches at most 2x2 chunks of 68x68x4 = 18.5 KB, so
  **at most 74 KB a frame (typically 18-37 KB) instead of 0.23-1.65 MB**, 10-45x less upload. Cost: visible draws
  go from 3 to at most 4x3 chunks x 3 layers = 36. That is still cheap. 128-cell chunks would give 12 draws and
  about 3-12x less upload.
- **Risk:** medium. Get the apron and edge-clamp right or the soft fog edge seams at chunk borders. Check with a
  frame diff before/after (see verification). `fog_alpha_at` and every `fog_image` user must go through a chunk
  lookup or keep a CPU master image.
- **Effort:** M-L.

### #2 `scripts/game.gd:835-856` (`_relight`) - fog is re-uploaded 16 times a second just to refresh "still lit" timestamps  [HIGH when idle or charging]
- **Issue:** on every new fog tick (1/16 s), `_relight` rewrites the lit tick of every revealed cell within
  `LIGHT_RADIUS` (+ `light_reach`), up to 21x21 = 441 cells, and sets `fog_dirty`. The slime always stands on
  revealed cells, so the fog uploads at **at least 16 Hz forever**, including while standing, charging a leap or
  sitting in a pause-free HUD moment. But a cell whose stored age is under `FADE_AFTER[0]` (1.5 s) renders
  exactly the same whether its age is 0.06 s or 1.4 s: same `fade_alpha.x` band, wall shade and reveal fade.
- **Fix (pixel-identical):** keep writing the CPU image as now, but split the dirty flag in two:
  - `fog_dirty` (upload this frame): set for paint/reveal writes, and for relight writes where the cell's
    *old* stored age is at least `FADE_AFTER[0] - margin` (the cell visibly brightens).
  - `fog_dirty_lazy` (refresh only): set for relight writes where the old age was below that. Upload only when
    `elapsed >= lazy_deadline`, where the deadline is the oldest pending stale lit time + (1.5 s - margin).
    Use a margin of about 0.25 s.

  The GPU copy of a lazily refreshed cell then always has an age below 1.5 s, so the shader output is
  bit-identical. Any upload flushes both, because the CPU image already holds the newest values. Also read the
  pixel once at `:853-854`: `get_pixelv` is called twice per cell. That is a CPU-only win.
- **Gain:** idle and charging fog uploads go from **16/s to about 1/s** (0.23-0.83 MB each). That also removes
  most of the upload stalls on low-end Android. When moving onto old, faded trail the uploads stay, because that
  change is visible.
- **Risk:** low-medium. Must keep the invariant "no cell's GPU age crosses 1.5 s through a skipped upload".
  Test with `test_hard_mode.gd` (hard-mode refog at `fade_after.w`) and the lockstep-fade tests.
- **Effort:** S-M. Stacks with #1.

### #3 `scripts/ui/skin_text.gd:28-61` - with the rainbow skin, the whole UI is re-themed about 20 times every frame (menus AND the gameplay HUD)  [HIGH for rainbow users]
- **Issue:** `_process` calls `recolor()` every frame when rainbow is on. Each frame that does:
  - `GooBox.set_goo_color(...)` (`goo_box.gd:41-52`): the color changes every frame, so every live GooBox
    `emit_changed()`s. **7 of them sit in the Theme** (`ui_kit.gd:33-37, 61-62`: 5 button states + Panel +
    PanelContainer), so that is 7 Theme `changed` emissions.
  - 10 x `theme.set_color` (`:55-57`), 2 slider StyleBoxFlat edits (`:51-54`) and 2 focus-border edits
    (`:59-61`): each one emits Theme `changed` again.

  That is about **21 full `NOTIFICATION_THEME_CHANGED` propagations over the theme owner's subtree per frame**.
  Each one invalidates every control's theme cache, re-measures minimum sizes and re-shapes Label text. On top
  of that, every visible goo box re-runs its GDScript `_draw` (see #4), and every `skin_text` label gets its own
  `add_theme_color_override` (one re-shape each). `hud.gd:188` attaches a SkinText in gameplay, so rainbow
  players pay this during play too.
- **Fix (pixel-identical):** wrap `recolor()` in `theme.set_block_signals(true)` ...
  `theme.set_block_signals(false); theme.emit_changed()`. The final theme state is the same and controls get
  **one** propagation instead of about 21. Also skip `add_theme_color_override` when the 8-bit color hasn't
  changed: compare `Color.to_rgba32()`, because the rasterised color can only change when the 8-bit value does.
- **Gain:** about 20x fewer theme propagations per frame with rainbow on. On a 40-60-control menu this is likely
  several ms a frame on web.
- **Risk:** low. Confirm that panels using `add_theme_stylebox_override` (not the theme) still repaint; they
  listen to their own stylebox, which still emits.
- **Effort:** S.

### #4 `scripts/ui/goo_box.gd:96-161` (`_draw`) - goo frames are drawn as one `canvas_item_add_rect` per pixel  [menus, pause, hub prompt: MED-HIGH]
- **Issue:** every goo pixel is its own 1x1 rect command, plus a lambda call. Estimated: about **450 rects per
  13 px button**, **about 2,000-2,500 per panel**. A typical settings or level-select screen comes to about
  **8-13k rect commands**. Godot 4's GL Compatibility canvas renderer walks every command of every visible item
  **every frame** and streams one instance (about 128 B) per rect, so about 1-1.6 MB of instance data a frame
  goes through `glBufferSubData`, plus the CPU walk. With rainbow (#3) the whole GDScript `_draw` also re-runs
  every frame for every box: RNG, lambdas and thousands of RS calls.
- **Fix (pixel-identical):** build each box's pixels into a small grid first, letting later writes win exactly
  as now. Then emit **horizontal runs** of equal color as one rect each (outline rows and columns become a single
  rect; band rows are long runs). Cache the run list per `(item id, size, kind, state)` and replay it with the
  current shade colors, so a recolor never re-runs the RNG or the lump layout. All goo shades and `DRIED` are
  opaque (alpha 1), so drawing the resolved grid gives the same pixels as the overdraw order does today. The
  panel face rect (alpha 235) is still drawn first, under the runs.
- **Gain:** about **5-10x fewer canvas commands** in every menu frame, and rainbow redraws become a cheap replay.
- **Risk:** low. Check against a capture of a few buttons, panels and the hover/disabled states.
- **Effort:** M.

### #5 `scripts/game.gd:762-786` + `assets/shaders/fog.gdshader:97-112` - the outer fog runs a full-screen fragment pass that mostly discards, and its 13-tap blur samples a 1x1 texture
- **Issue (a):** `outer_fog` is one quad over the maze plus a 512 px margin. Inside the maze, every screen pixel
  launches a fragment just to run the `hole` test and `discard`: **+57,600 fragments a frame**, and discard
  disables some tile-GPU optimisations.
- **Issue (b):** where it does show (near the maze edges, `EDGE_FOG`), it runs all 13 `cell_alpha` taps on a
  1x1 `UNREVEALED` texture. That always gives (4+8+4+4)/20 = exactly 1.0.
- **Fix (b), pixel-identical:** add `uniform bool solid` (true only on the outer material), and
  `float alpha = solid ? 1.0 : <13-tap blur>;`. That branch is uniform, so it never diverges. Everything after
  it (dither, `far_dim` step, vignette) gives the same result for alpha = 1.0.
- **Fix (a), near-identical:** replace the one hole quad with **4 strip sprites** (top/bottom/left/right of the
  maze rect) sharing the outer material. Compute `world_px` from a `vertex()` varying
  (`(MODEL_MATRIX * vec4(VERTEX, 0, 1)).xy`) instead of `UV*map_size+origin`. Then the `hole` test and its
  discard go away.
- **Gain:** one full-screen pass less, and 13 taps less per outer-fog pixel. Small on desktop, measurable on
  fill-limited phones.
- **Risk:** (b) none. (a) very low: `world_px` changes by float rounding only. It is floored at pixel centres
  (.5), so dither and noise cells can't flip. The smoothstep falloff only moves by about 1e-5.
- **Effort:** S (b), S-M (a).

### #6 `assets/shaders/atmosphere.gdshader:46-50` (used by `hud.gd:73-84`, `hub.gd:304-312`) - the vignette-only overlays still compute two value-noise layers
- **Issue:** with `mist_strength = 0` (gameplay HUD, hub), every pixel still evaluates 8 sine hashes, and the
  result is multiplied by 0.
- **Fix (pixel-identical):** `float mist_alpha = 0.0; if (mist_strength > 0.0) { ...noise...; mist_alpha = ...; }`.
  Today's value is `band * 0.45 * 0.0 = 0.0` exactly, so the later `mix` and `max` see the same inputs.
- **Gain:** about 60% of that pass's ALU on 57,600 px. Small; S, so worth taking.
- **Risk:** none. **Effort:** S.

### #7 `assets/shaders/fog.gdshader:114-137` - noise is computed for pixels that end up fully transparent
- **Issue:** the 3 value-noise layers (12 `sin`) and the color `mix` run even where the final alpha is 0 (the lit
  area around the slime).
- **Fix (pixel-identical):** move the falloff and vignette alpha math (`:129-134`) before the noise, then
  `if (alpha <= 0.0) { COLOR = vec4(0.0); } else { noise -> rgb -> vignette mix }`. With Godot's mix blend
  (`SRC_ALPHA, ONE_MINUS_SRC_ALPHA` / `ONE, ONE_MINUS_SRC_ALPHA`), a source alpha of 0 leaves the destination
  unchanged whatever the rgb, so the output is identical.
- **Gain:** skips about 90 ALU on the clear area (about 10-20% of the screen in play). Small.
- **Risk:** none. **Effort:** S.

### #8 `scripts/fx.gd:11-31` (`make_light`) - every light gets its own material and its own generated texture, which breaks batching
- **Issue:** each call makes a new `CanvasItemMaterial` (ADD) and a new `GradientTexture2D`. Callers:
  - every coin, up to **31 per level** (`coin.gd:35`)
  - every glimmer (`game.gd:572`), plus a second additive material on the Glimmer node itself (`:569-571`)
  - chalice (`chalice.gd:18`), ticket (`ticket_pickup.gd:27`), slime light (`game.gd:735`)
  - **7 hub pools** (`hub.gd:204`, all 68x32 and identical)

  Different material and texture RIDs mean one draw per glow, plus a texture build and GPU allocation at
  runtime for each glimmer spawn.
- **Fix (pixel-identical):** one static shared ADD `CanvasItemMaterial`, and a static cache of
  `GradientTexture2D` keyed by `(width, height)`. The texture only depends on its size; tint and strength stay in
  `modulate`. The glow sprites then batch: the 7 hub pools become 1 draw, and on-screen coin glows become 1.
- **Gain:** fewer draws and state changes, no texture generation at runtime. Small but free.
- **Risk:** none, as long as nothing mutates a light's material or texture afterwards. Today only `modulate` is
  changed. **Effort:** S.

### #9 `scripts/hub.gd:165, 201, 258-261` - 9 identical `ShaderMaterial`s for the stations and rotor
- **Issue:** `_skin_material()` builds a new `slime_skin` material per station and the rotor, all with the same
  parameters. Each is its own uniform buffer and its own material switch.
- **Fix (pixel-identical):** build it once in `_build_room` / `_build_stations` and share it. The stations use
  different textures, so they still draw separately, but the material state is shared.
- **Gain:** small. **Risk:** none (no per-station `set_shader_parameter` exists). **Effort:** S.

### #10 `scripts/coin.gd:65-67`, `scripts/chalice.gd:24-27` - per-frame `_process` for every coin, on or off screen
- **Issue:** up to 31 coins update `region_rect` at 10 Hz each, even when far off screen or fogged. Each change
  rebuilds that canvas item's commands.
- **Fix:** let a `VisibleOnScreenEnabler2D` (or a camera-distance check) pause it, but derive the frame from a
  global clock (`Time.get_ticks_msec()` + the coin's random offset) so the spin phase is the same as if it had
  kept running. **Pixel-identical** with the global-clock variant.
- **Gain:** small CPU on web. **Risk:** none. **Effort:** S.

### #11 `scripts/ui/menu_backdrop.gd:21` - `clip_contents = true` on a full-screen control
- **Issue:** this sets up a canvas clip rect (which starts a new batch) on a control that always covers the whole
  viewport. The tiles it clips are off screen anyway.
- **Fix (pixel-identical while the backdrop stays full-rect):** `clip_contents = false`.
- **Gain:** tiny. **Risk:** if the backdrop is ever used smaller than the screen, it would bleed. **Effort:** S.

### #12 `assets/shaders/hub_room.gdshader:110-115` - uniform-only trig recomputed per pixel
- **Issue:** `cos(-turn)` and `sin(-turn)` are evaluated per fragment, 57,600 times. Many mobile compilers do
  not hoist uniform-only expressions.
- **Fix (near-identical):** pass `turn_cs = vec2(cos(turn), sin(turn))` as a uniform, set from `_place_all`
  and the turn tween. CPU vs GPU float32 `cos` can differ in the last bit, so a pixel exactly on a tile edge
  could in theory flip. That is visually indistinguishable but not provably bit-identical.
- **Gain:** tiny. **Risk:** very low. **Effort:** S. Optional.

### #13 `project.godot` `[rendering]` - no `renderer/rendering_method.mobile` override (future Android export)
- **Issue:** there is no Android preset today, but Godot's default for mobile is the **Mobile (Vulkan)**
  renderer. An APK would run a different, untested renderer, which is slower to start on low-end devices and
  has different blending/precision paths.
- **Fix:** `renderer/rendering_method.mobile="gl_compatibility"`. That is the same renderer as web, so the same
  look as today.
- **Gain:** consistency and a known-good path. **Risk:** none for desktop/web. **Effort:** S.

### Minor / not worth doing now
- `game.gd:426-438` sets 7 shader parameters per frame on 2 materials: 2 small uniform-buffer updates.
  Negligible.
- `ambient.gd` (10-28 CPUParticles2D) and `Fx.make_drips` (10): negligible. **Do not** switch to GPUParticles2D:
  transform-feedback particles on GL Compatibility/WebGL are less robust.
- The trail glow (`game.gd:746-757`) is a whole-screen additive pass that adds 0 on empty pixels. A shader
  `discard` would need its own bilinear math (see the fidelity list), so leave it.
- `story_screen.gd` redraws hundreds of immediate-mode rects per frame. That only happens on the story cards;
  revisit only if those screens stutter on phones.
- `hud.gd:473-487`, `hub.gd:511-529`: per-frame modulate and region sets mostly early-return when unchanged.
  Fine.

---

## 2. Summary table (ranked by expected gain on web/Android)

| # | Where | Gain | Fidelity | Risk | Effort |
|---|---|---|---|---|---|
| 1 | Chunked fog/trail textures with apron | upload 0.23-1.65 MB/frame -> <=74 KB | identical | med | M-L |
| 2 | Lazy relight uploads + single `get_pixelv` | idle fog uploads 16/s -> ~1/s | identical | low-med | S-M |
| 3 | Block theme signals during rainbow `recolor` | ~21 -> 1 theme propagations/frame | identical | low | S |
| 4 | GooBox run-merge + cached layout | 5-10x fewer rect commands in menus | identical | low | M |
| 5 | Outer fog: `solid` skip + 4 strips | -1 full-screen pass, -13 taps on edge fog | (b) identical, (a) near | very low | S / S-M |
| 6 | atmosphere: skip mist when strength 0 | ~60% of that pass | identical | none | S |
| 7 | fog: skip noise where alpha = 0 | ~10-20% of the fog noise cost | identical | none | S |
| 8 | Shared light material + texture cache | batching, no runtime texture builds | identical | none | S |
| 9 | Hub: one shared skin material | small | identical | none | S |
| 10 | Coins: pause offscreen, global-clock frame | small CPU | identical | none | S |
| 11 | Backdrop `clip_contents` off | tiny | identical | low | S |
| 12 | hub_room trig as uniforms | tiny | near-identical | very low | S |
| 13 | `rendering_method.mobile = gl_compatibility` | consistency | identical | none | S |

Suggested order: **3, 6, 7, 5b, 8, 9** (all S and bit-identical, one sitting), then **2**, then **4**, then
**1** (the big one for large randomizer mazes on phones).

---

## 3. FIDELITY RISK - do not apply

These were considered and rejected because they change the look, even slightly:
- **Coarser fog grid** (`FOG_CELL` 4) or a smaller fog texture: changes the reveal edge.
- **13 -> 9-tap fog kernel** (proposed in `docs/archive/advisor/graphics-shading.md` §6): changes the soft edge.
- **Sine-free hash / cheaper noise** in fog, atmosphere, hub_room or goo_wipe: a different mist pattern. Only
  worth it as a deliberate art change, for mediump precision on phones, not for speed.
- **Uploading the fog only on fog ticks**, or deferring trail uploads a frame: delays the reveal by up to about
  62 ms.
- **Palette-index (R8/RG8) trail texture**: shrinks uploads 2-4x, but the linear glow copy would need manual
  bilinear in a shader, and GPU filter-weight precision differs.
- **Throttling the rainbow recolor to 30 Hz**: steppier hue cycling (about 6/255 per step).
- **Driving rainbow label color by `modulate` instead of `font_color`**: also tints the dark drop shadow, and
  `text_drips` uses the vertex tint to tell shadows apart.
- **Lowering the web canvas resolution** (`html/canvas_resize_policy`, devicePixelRatio) or letting the browser
  upscale: blurs or unevenly scales the pixels.
- **Stretch mode `canvas_items`**: renders at window resolution. That is both slower and breaks the pixel grid.
- **Dropping the HUD vignette pass** in favour of the fog shader's vignette: different layering over the trail.
- **Caching the hub room into a texture**: the mist and rainbow animate every frame, so it would need an extra
  pass anyway.
- **Turning on web threads**: not a look change, but it needs cross-origin isolation (breaks on some
  hosts/Safari) and is out of scope here.

---

## 4. How to verify (for whoever implements)

- **Pixel identity:** render the same deterministic run before and after each change and diff the frames.
  Use `--fixed-fps 60`, a fixed level/seed, and the autopilot `tests/demo.tscn`, capturing frames N, 2N, 3N.
  Expect 0 differing pixels, except items 5a and 12 (expect 0, tolerate a handful of 1-LSB pixels).
  Cover the rainbow skin, hard mode (refog), the hub turning, and a menu with hover/disabled buttons.
- **Cost:** in a debug build, read `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`,
  `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `TIME_PROCESS` and `TIME_PHYSICS_PROCESS`.
  - For #1/#2: count `ImageTexture.update` calls and bytes per second.
  - For #3/#4: count `NOTIFICATION_THEME_CHANGED` and rect commands per frame.
  - On the web build: profile in Chrome DevTools (Performance panel, GPU and main thread) on a mid Android phone
    via remote debugging, on a 36x20 randomizer maze, standing still and while exploring.
- Re-run `./tools/test_all.sh`. `test_hard_mode`, the lockstep-fade tests and `test_hub_skins` cover the touched
  paths.
