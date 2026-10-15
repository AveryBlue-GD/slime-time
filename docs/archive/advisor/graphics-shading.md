# Graphics, lighting, shading, color and art direction

> Archived advisor report (2026-10-12): its shading advice was implemented; the shaders are described in [../../architecture.md](../../architecture.md).

Advisor report for Slime Time (Godot 4.7, gl_compatibility, 320x180 integer scaling, web + Android, no run-time-indexed arrays).
Goes beyond `docs/archive/polish-research.md`: that file's fog-crush and glow advice has been implemented, and the owner now says the fog is "a bit too dark". This report starts from what the code does today.

**Source honesty.** The web search tool returned thin results this session. Fetched and confirmed: Godot 4.7 2D lights doc, SLYNYRD Pixelblog 1, Lospec dark palette list. Searches that returned no primary source: Noita lighting, Hollow Knight lighting, Don't Starve darkness numbers, Darkwood, HLD GDC. Anything about those games below is general knowledge or a secondary summary and is labeled as such. Shader numbers are my own working, to be tuned by eye.

---

## 1. What the code does today (audit of the dark-scene pipeline)

Measured from `assets/shaders/fog.gdshader`, `scripts/game.gd`, `scripts/hud.gd`, `scripts/themes.gd`:

| Layer | Value | Effect |
|---|---|---|
| Unexplored fog colour | `mix(fog_deep*0.35, fog_mist*0.22, band)`; Dungeon default = 7,7,12 up to 14,13,19 (8-bit) | about 3-6% luminance: effectively pure black on any phone screen or in daylight |
| Remembered path | `FADE_ALPHA` ends at 0.78, walls +0.3 of the remainder = 0.85 | remembered walls are at 15% brightness, floors 22% |
| Far dim | `far_dim 0.22` beyond `light_outer 90` px | lit ground is capped at 78% only past 90 px |
| Vignette #1 | in fog shader, `0.5` black mix at edges, **only on fogged pixels** | |
| Vignette #2 | HUD `atmosphere.gdshader`, strength 0.55, dithered, drawn over **everything incl. the lit trail** | the trail edges darken twice |
| Slime light | `slime_light`, 112 px, additive, strength 0.22, `z_index = 5` | **drawn under the Fog sprite (`z_index = 10`), so it is invisible wherever fog alpha is 1.** It only tints the already-lit cells. The "lantern" the polish report asked for does not currently exist on unexplored ground. |
| Reveal radius | `LIGHT_RADIUS 20`, `TRAIL_RADIUS 9` (+ `light_reach` upgrade) | about 1.25 tiles; this is the gameplay, keep it |

Diagnosis: the problem is not the reveal radius, it is (a) a black floor of 3-6% luminance with no ambient colour, (b) two stacked vignettes, (c) memory levels that go to 15-22%, and (d) the only light source is hidden behind the fog.

Other shader audit notes (details in the ranked list):
- `fog.gdshader` loops `for (i < LAYERS-1)` reading `fade_after[i]` / `fade_alpha[i]`: **uniform arrays indexed by a loop variable**, executed 13 times per fragment (13 taps x `cell_alpha`). WebGL2 usually accepts dynamic indexing of uniform arrays (a WebKit bug report shows it failing on Apple M1 backends, https://bugs.webkit.org/show_bug.cgi?id=234926; unverified for Android), but given the earlier Android blank-screen bug it is the single remaining risk pattern in the codebase. Unrolling is free.
- `hash()` uses `fract(sin(dot(p, ...)) * 43758.5)`, which loses precision on `mediump` mobile GPUs (visible as banding or repeating patterns). A sine-free hash is a drop-in.
- `slime_skin.gdshader`: 10 `distance()` compares per fragment, fine at sprite sizes. No arrays. Good.
- `atmosphere.gdshader` and the fog shader duplicate the noise/vignette code; fine, but the vignette must have one owner.
- No shader for the goo trail: it is a CPU image + linear-filtered additive copy (`_build_trail_glow`). It has no rim, no specular, no depth. That is the biggest art gap, since the trail is the game's hero asset.

---

## 2. Dark-game readability: how the references do it, and what to take

(General knowledge unless marked. The searches did not yield developer statements on lighting numbers.)

- **Hollow Knight**: darkness is a mood and a *value* choice, not black. Backgrounds sit in a narrow dark-to-mid value band, foreground silhouettes are the darkest, and characters carry the only high-contrast edge (white eyes/mask). Takeaway: keep the *unlit* world at a readable-but-dim 10-15% and make anything interactive 60-100%. A Steam reviewer complains about muted homogeneity even with brightness raised (secondary summary), the cautionary tale for our "too dark" feedback.
- **Don't Starve**: pitch black beyond the torch at night, but the circle edge is soft and warm, and a threat/info is communicated by sound and eyes in the dark. Klei forum posts mention the light radius being *increased* after players disliked "superdark" nights (fetched search result, Klei forum 2012 beta thread). Takeaway: soft banded falloff, warm-vs-cool contrast, and a larger radius than the designer's first instinct.
- **Hyper Light Drifter**: soft gradient light layered over a limited-palette pixel base, regional palettes, saturated colour kept in dark scenes so shadows stay coloured rather than grey (AV Club piece and Steam thread, via search snippets). Takeaway: dark = deep saturated hue, not desaturated black. Our fog colours are already hued but the 0.22 gain throws the hue away.
- **Darkwood**: limited field of view with tension from sound and shapes; the player is allowed to see ambient silhouettes (secondary: Rue Morgue, Engadget, PlayStation Blog snippets). Takeaway: ambient silhouettes are okay; fear and mystery come from *unknown content*, not unreadable pixels.
- **Noita**: soft additive light and glow over pixel material; no sourced technique this session.

**Rules distilled for Slime Time**
1. Three value tiers: *lit* (60-100%), *remembered* (25-45%), *unknown* (8-14% in the theme's shadow hue). Today they are 100 / 15-22 / 3-6. The jump to "unknown" is too steep and the "remembered" tier is nearly the same as unknown.
2. Mood comes from hue and the *ratio* between tiers, not from the absolute black. A black floor is a bug on OLED phones outdoors; leave 2-3 visible steps above black.
3. Keep an accessibility lever: a `Progress.fog_lift` setting (3 steps: Dark / Normal / Bright) feeding one uniform. Cheap, and it removes this argument forever.
4. Mystery: keep the *unknown* tier flat (no tile detail), but allow a faint coloured haze within ~2.5 tiles of the slime so the player senses space without seeing the maze. This is the "lantern" and it is gameplay-neutral (it adds colour, not information).

### Concrete recommendation: fog darkness and light radius

Change set ("Normal" setting). Tune by eye with screenshots at 1x:

| Parameter | Now | Recommended | Note |
|---|---|---|---|
| unexplored floor, band 0 | `fog_deep*0.35` | `fog_deep*0.75` | Dungeon: about 15,15,25 |
| unexplored floor, top band | `fog_mist*mist_gain`, gain 0.22 | gain 0.42 | Dungeon: about 26,26,37; Lava: 38,15,12 |
| `FADE_ALPHA` | `[0, .30, .50, .65, .78]` | `[0, .25, .42, .54, .64]` | remembered floor settles at 36% instead of 22% |
| `WALL_FOG_ALPHA` | 0.30 | 0.20 | remembered wall about 29% (walls still dimmer than floor, as the design says) |
| fog-shader vignette | 0.5 black | 0.30 | |
| HUD vignette strength | 0.55 | 0.30, and draw it only at the corners (raise `smoothstep` start from 0.45 to 0.60) | stop darkening the trail |
| `far_dim` / `light_inner` / `light_outer` | 0.22 / 26 / 90 | 0.14 / 32 / 120 | lit trail keeps more brightness at distance |
| reveal radius `LIGHT_RADIUS` | 20 | **keep 20** (and `TRAIL_RADIUS` 9) | core mechanic and balance; do not touch |
| lantern (existing `slime_light`) | 56 px radius, 0.22, below fog | **56 px radius, 0.12-0.16, above fog (`z_index = 11`)**, bands stay; scales with `light_reach` already | the 112 px texture matches the 2.5-3.5 tile "sense" radius, no new asset |

One-line fix with the biggest feel change: `slime_light.z_index = 11` in `game.gd` (line ~569). Check it does not draw over the HUD (the HUD is a CanvasLayer, so it will not) and re-test with the rainbow skin.

If the owner still wants it moodier, lower `slime_light` strength rather than the floor; the floor and memory tiers carry readability.

---

## 3. Lighting approaches for Godot 4 under our constraints

**Normal-mapped Light2D vs baked.**
- Godot's 2D lighting (fetched, https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html): `CanvasModulate` sets ambient, `PointLight2D` adds light, normal/specular maps via `CanvasTexture`, `LightOccluder2D` for shadows (shadow filter None is fastest and suits pixel art), lighting is computed at viewport resolution so it stays pixel-crisp, and additive sprites are the documented cheap alternative that cannot cast shadows or use normal maps. The page has no web or Compatibility caveats, so costs there are not documented; larger lights cost more pixels.
- Our world is lit by the **fog texture**, not by lights: every cell's brightness is already a function of time and distance. Real Light2D would fight it (CanvasModulate would multiply the same dark twice, and the fog overlay would hide any wall normal-map detail anyway).
- Verdict: **do not adopt Light2D / normal maps for mazes.** Use baked light (tile art lit from top-left plus baked AO tiles) and additive banded sprites (`Fx.make_light`). Normal-mapped light is only worth it for a hero case: the hub's 8-ish station sprites with 1-2 `PointLight2D` torches. Defer; item 17 below.
- Light flicker, colour per source (torch orange, chalice gold, coin metal) are all additive sprites with a `modulate` driven by a cheap noise. No shader.

**Cheap bloom.** Real bloom needs a blur chain; on web/Android skip it (the Compatibility renderer's glow is unverified here and multi-pass). Fake it: bright objects carry a pre-drawn halo (a radial banded additive sprite 2-3x their size, as chalice/coin already do); the trail's linear-filtered additive copy is already a one-tap bloom. Add a second copy at scale 2 with alpha 0.1 for a wider halo: one extra draw, no shader.

**Pixel-snapped light.** Docs suggest snapping `LIGHT_VERTEX` for pixel-art lighting; we avoid the issue by `.round()`ing positions (already done for `slime_light`).

---

## 4. Palette design

Fetched SLYNYRD Pixelblog 1: ramps shift hue about 20 degrees per step (positive shift warms as it brightens), brightness rises steadily and lightest steps stay below full, saturation peaks mid-ramp and drops at both ends, step sizes vary for even visual contrast, ramps that cross each other give cohesion, plus a desaturated neutral set. https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes

What this says about our art (from `tools/make_placeholder_art.py`): the goo ramp is already hue-shifted (yellow-green highlight 214,250,186 to teal outline 12,38,48), the stone ramp is a cool blue-grey, floor is violet. Good. Gaps: (1) the fog ignores the ramp idea (one flat hue), (2) accents: the only warm accents are the chalice/coins, (3) themes recolour but do not hue-shift lit-to-shadow.

**Per-theme ambient ramp proposal.** The fog's two colours become the *shadow end* of each theme's ramp, hue-shifted away from the tile highlight hue (shadows cool/purple, highlights warm) and with enough saturation to survive the new gain:

| Theme | deep (unknown floor) | mist (top band) | Shadow-hue logic |
|---|---|---|---|
| Dungeon | 24,22,42 | 70,66,104 | blue-violet shadows under grey stone |
| Mossy | 14,28,26 | 46,78,66 | teal shadow under green moss |
| Sandstone | 40,26,26 | 112,82,66 | rose-brown shadow, warm sand highlight |
| Sunken | 8,24,40 | 34,84,104 | cyan-blue |
| Sewers | 26,30,12 | 90,104,34 | olive; keep it sickly, avoid yellow glare |
| Catacombs | 30,22,28 | 88,70,76 | mauve bone-dust |
| Frozen | 16,24,48 | 82,112,156 | blue shadows, desaturated lit ice |
| Obsidian | 10,8,22 | 46,40,76 | violet-black; lowest gain (it is the "dark" level) |
| Crystal | 26,12,44 | 96,60,132 | magenta-violet |
| Volcanic | 36,12,12 | 120,44,32 | ember red-brown; add warm orange lantern tint |

These are starting points; the old values are 20-30% darker, matching the gain change in section 2. Do not apply both a colour lift and the gain change blindly: change gain first, then adjust.

**Limited-palette reality check.** Add `tools/palette_check.py`: for each theme render floor/wall/fog/trail swatches, print luma, and flag neighbours closer than 8% luma or 20 degrees hue; also a grayscale screenshot test (squint test). Lospec tag "dark" lists useful reference palettes (https://lospec.com/palette-list/tag/dark): `darkest16` (16, horror), `Abyssal Siren's Call` (24, cold gloomy, nice for Sunken/Frozen), `Waldgeist` (39, warm murky, for Catacombs/Sandstone), `Bastille-8`, `BloodMoon21` (9, red/purple, for Volcanic), `slimy 05` (5, dark desaturated green, for Sewers). Use them to sanity check ramps, not to replace our PAL.

---

## 5. Slime / jelly material, trail and goo

Current: palette swap + per-shade alpha for translucency (highlight 0.9, mid 0.42...), solid outline and eyes. Good base. Missing the three cues that sell jelly in pixel art: a **backlit inner glow**, a **moving specular glint**, and **edge thickness (rim darker at the silhouette, lighter just inside)**.

Approaches (all in `slime_skin.gdshader`, no arrays, no screen texture):
1. **Shine sweep.** Every ~3 s a diagonal band passes: `float s = fract(TIME*0.35); float d = abs(fract((p.x + p.y*0.7)/28.0) - s); if (d < 0.04 && shade in {1,2}) rgb = highlight;` where `p = floor(local_pos)`. Rim/body pixels only. S.
2. **Backlit crescent.** In the lower third of the sprite frame, remap shade 2 (mid) to shade 1 (light) on a Bayer-dithered edge, mimicking light passing through the jelly: `if (shade==2 && local_pos.y > low_y) { if (bayer4(floor(local_pos)) < k) rgb = light.rgb; }`. Needs the frame's bottom y (sprite is 20x20, so use `UV.y > 0.6`; in an AnimatedSprite2D UV spans the sheet frame region only if you use `REGION_RECT`; verify and fall back to `local_pos` which is already sprite-local). S/M.
3. **Refraction without screen texture.** Real refraction needs `hint_screen_texture`, which forces a backbuffer copy every frame on web; skip. Fake: tint the jelly alpha with the floor's own shade by lowering alpha (already) plus a **1 px displaced duplicate** of the sprite beneath it on the floor, offset (1,1) at 25% alpha, which reads as caustic/refracted shadow. S.
4. **Squash colour pulse.** When charging, raise `light` saturation slightly via a uniform `charge` (0-1): more tension, free. S.

**Trail rendering (biggest art win).** Add `assets/shaders/trail.gdshader` on `trail_sprite` (currently no material):
```gdshader
shader_type canvas_item;
uniform vec4 rim : source_color;      // dark outline shade
uniform vec4 body : source_color;     // mid
uniform vec4 lit : source_color;      // highlight
uniform float now;
float hash(vec2 p){ vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
void fragment() {
    vec2 t = TEXTURE_PIXEL_SIZE;           // one trail cell
    float a  = texture(TEXTURE, UV).a;
    if (a < 0.5) { discard; }
    float up = texture(TEXTURE, UV + vec2(0.0,-t.y)).a;
    float lf = texture(TEXTURE, UV + vec2(-t.x,0.0)).a;
    float dn = texture(TEXTURE, UV + vec2(0.0, t.y)).a;
    float rt = texture(TEXTURE, UV + vec2( t.x,0.0)).a;
    vec3 c = body.rgb;
    if (min(min(up,lf),min(dn,rt)) < 0.5) { c = rim.rgb; }                  // outline at the edge
    else if (up < 0.5 || lf < 0.5) { c = lit.rgb; }                          // top-left bevel highlight
    float g = hash(floor(UV / t));                                           // speckles/bubbles
    if (g > 0.985) { c = mix(c, vec3(1.0), 0.5 + 0.5*sin(now*3.0 + g*60.0)); } // twinkle
    COLOR = vec4(c, 1.0);
}
```
Works at the 2 px trail cell; texture must be sampled nearest. Cost: 5 taps on trail pixels only. The additive halo child stays. If the trail image already stores colours (skin shades, rainbow), keep them and only compute the edge/highlight masks (`c = TEXTURE.rgb`, mix toward `lit`/`rim` by 0.4). M. Impact high: the goo currently reads as a flat green rectangle (see `docs/polish-shots/after_l1.png`).

**Jelly slime on the trail:** a flowing "wet" highlight along the centre line is also possible by reading `up`/`lf` at 2 cells distance for a wider bevel (2-px bevel). Optional.

**Droplets/goo particles**: `Fx.burst` uses `CPUParticles2D`, good. Add 1-px squares only (scale 1) so they stay on the pixel grid; they are 1-2 now.

---

## 6. Walls, AO, parallax and fog layers

- **Baked AO tiles** (recommended): the project already has a neighbour-mask pipeline for fillets (`fillets.png`, 16 masks, z 2). Add `floor_ao.png` from `make_theme_art.py`: for each of 16 masks, a 3 px dithered band on the floor edge touching a wall (darkest at the wall, Bayer-dither falloff over 3 px), drawn as another layer under the fillets. Keeps wall faces untouched (silhouette stays readable; AO belongs in the floor, per general pixel-art practice; a forum report also found strong consistent floor/wall contrast fixes unclear walls). Also bake a 1 px top highlight onto each wall tile edge facing north. M. Impact high, mobile cost zero at runtime.
- **Fog layers / parallax**: the mist already has three noise layers in world space. Add parallax to one: sample `value_noise((pixel - view_center*0.25)/50.0 + drift)` so wisps slide against the walls as the camera pans. One extra noise lookup, S. Keep 4 bands max and dither; do not add more full-screen layers.
- **Fog edge**: today the 13-tap smoothing. A cheaper identical-looking smoother: precompute (CPU) the blurred alpha when cells change... the fog texture is rebuilt per frame though (`ImageTexture.create_from_image`, line ~545). Alternative: reduce to a 9-tap tent (centre 4, 4 axial 2, drop the 4 far-axial) with a small visual change. S, saves 4 `cell_alpha` calls per fragment (each does a floor + pack decode).
- **Memory of walls**: after the new `FADE_ALPHA` the walls are +0.2; consider drawing wall *tops* (the 2 px north edge) at 0.5 less fog so wall outlines hold in memory. Needs fog image wall bit already present: add `if wall and age > last_step: alpha = 0.55`. S.

---

## 7. Post-processing on web/Android

Rules: avoid anything that needs `hint_screen_texture` every frame (forces a backbuffer copy on the Compatibility renderer, noticeably expensive on mid Android). Fold effects into shaders we already pay for.
- **Vignette**: already in two places; keep one (fog shader for in-game, `atmosphere` for menus).
- **Colour grading**: bake into the fog/tint colours and the theme ramps; optionally one `CanvasModulate` on the world layer for a per-theme warm/cool multiply (free, set from `Themes`). S.
- **CRT / scanlines**: not recommended. Integer-scaled pixel art plus 1-px scanlines at 320x180 will moire at non-integer window sizes and cost a full-screen pass.
- **Chromatic aberration**: only as an *event* effect (splat, dry-up, 0.2 s): enable a `BackBufferCopy` + a one-tap-per-channel ColorRect for the duration, then remove it. S/M, cost only while active.
- **Dry-up grade**: lerp a `CanvasModulate` toward desaturated dull blue-grey as the slime meter drops under 15%, plus a slow red pulse in the HUD vignette's `deep` colour. Cheap and readable warning. S.

---

## 8. Theme effects (water, lava, ice, etc.)

Add one `assets/shaders/theme_fx.gdshader` on a full-screen ColorRect/Sprite2D at `z_index` 3 (above floor and trail, **below the Fog at z 10**, so fog masks it exactly like the floor), additive blend, `uniform int mode` branched with `if` (uniform branch, no arrays):
- Sunken Shrine: caustic shimmer: `sin` of two warped coordinate sums, thresholded to 2 bands, additive cyan at 0.10.
- Volcanic Vault: slow pulsing orange heat glow from a low-frequency noise (cell lava veins), plus ember specks (`hash(floor(p/4))` rising) at 0.15.
- Frozen Fortress: sparse glints that blink on a hash of `floor(p/6)` and `now`.
- Crystal Caverns: coloured twinkle points, 2 hues.
- Toxic Tunnels: rising bubbles (hash cells scrolling up, ring shape).
- Mossy: drifting spore dots. Sandstone: horizontal sand streaks. Catacombs: dust motes. Obsidian: faint violet veins. Dungeon: drips (the existing ambient sound events can trigger a ripple).
Cost: one extra full-screen fragment (about 4-6 ALU noise taps) at 320x180 = 57,600 px, trivial. Cap `CPUParticles2D` to 20-30 for embers/snow as polish-research says; this shader replaces most particle needs. M.

Also: because the fog image only knows cell state, tile-based effects (puddles shimmer) belong in the floor atlas variants plus a `sin`-based tint on the `FloorLayer` material (CanvasItem shader with a `uniform float now`), which is free.

**Screen transitions**: the goo wipe (`goo_wipe.gdshader`) is already distinctive. Add a *level-start lantern opening*: for 0.6 s animate the lantern strength and `light_outer` from 0 to normal in `Transition.reveal()` so the maze "wakes". S. Add a *win*: a quick gold additive flash from the chalice (`Fx.make_light(200, gold)` fading) before the choice buttons. S.

---

## 9. UI art

Current: GooBox 9-slice-ish goo frames, generated pixel font with shader drips, HUD pods. Suggestions:
- Give HUD text a 1 px dark shadow (theme font shadow offset (0,1), colour 0.6 alpha of `outline`) so text reads over the new brighter fog and the lit trail. S.
- Constrain accent colour: keep gold reserved for coins/chalice/NEW RECORD/title; skin colour for meter and goo. Mixed greens everywhere were called out in the earlier report; the skin-driven goo frames already improve it.
- Font: 5x7 slimy font is on-brand; keep. Title (16 px, 2x copy) is good.
- Low-slime HUD feedback: the meter segments blink at <15% and the vignette deep colour pulses red (see 7).
- 9-slice details: gold corner pips on pods (optional, matches earlier advice; low priority because goo frames already differentiate).

---

## 10. Ranked upgrade list (impact vs effort)

| # | Upgrade | Effort | Files | Impact | Mobile cost |
|---|---|---|---|---|---|
| 1 | **Fog lift** to owner's feedback: values in section 2 (floor gain, `FADE_ALPHA`, `WALL_FOG_ALPHA`, vignettes, far dim); add `fog_lift` setting uniform with Dark / Normal / Bright | S | `assets/shaders/fog.gdshader`, `scripts/game.gd` consts (`FADE_ALPHA`, `WALL_FOG_ALPHA`), `scripts/hud.gd` (vignette 0.55 to 0.30), `scripts/progress.gd` + settings screen | Very high (directly answers owner) | none |
| 2 | **Lantern above fog**: `slime_light.z_index` 5 to 11, strength 0.12-0.16, banded as now | S | `scripts/game.gd` (~line 569), `scripts/fx.gd` | Very high: first time the slime feels like a light source | one additive sprite, none |
| 3 | **One vignette owner**; hud vignette only at corners; fog shader vig 0.5 to 0.3 | S | `scripts/hud.gd`, `fog.gdshader`, `atmosphere.gdshader` | High | saves a full-screen dithered pass if the HUD one is dropped in-game |
| 4 | **Robustness pass on the fog shader**: unroll `fade_after[]`/`fade_alpha[]` into `vec4` + `float` uniforms (no loop, no indexing); sine-free hash; 13-tap to 9-tap | S | `fog.gdshader`, `game.gd` lines ~555, 606 (parameter names) | High for Android stability, fewer texture reads | lowers cost |
| 5 | **Trail shader** (rim outline, top-left bevel, twinkle specks, wet highlight) | M | new `assets/shaders/trail.gdshader`, `game.gd` `_build_trail_glow` area | Very high (hero asset) | 5 taps on trail pixels only |
| 6 | **Baked floor AO tiles** at walls + 1 px wall top highlight | M | `tools/make_theme_art.py`, `tools/make_placeholder_art.py`, `scripts/maze_tiles.gd` (new `AO_SOURCE` like fillets), theme atlases | High (volume, depth) | zero at runtime |
| 7 | **Per-theme ambient ramps** (table in section 4) + `tools/palette_check.py` | M | `scripts/themes.gd`, new `tools/palette_check.py` | High (theme identity beyond hue swap) | none |
| 8 | **Jelly upgrades**: shine sweep, backlit crescent, offset refraction shadow, charge pulse | S/M | `assets/shaders/slime_skin.gdshader`, `scripts/slime.gd` (uniform `charge`) | High (skin showcase) | negligible |
| 9 | **Theme FX overlay shader** (caustics, embers, frost glints, bubbles...) below the fog | M | new `assets/shaders/theme_fx.gdshader`, `game.gd` setup, `themes.gd` (`fx_mode`) | High (theme identity) | one full-screen additive pass; cheap |
| 10 | **Light sources with flicker + warm accent**: torches/coins/chalice halos via `Fx.make_light` with noise flicker, per-source tint, chalice halo wider; theme-tinted lantern for Volcanic/Frozen | S | `scripts/fx.gd`, `scripts/chalice.gd`, `scripts/coin.gd`, hub archway torches | Medium-high | additive sprites; keep under about 10 on screen |
| 11 | **Hub lighting**: darken floor 30-40%, add banded warm/cool pools under each station, drop speckle noise, keep station silhouettes distinct | M | `assets/shaders/hub_room.gdshader`, `scripts/hub.gd` | High (hub is first impression) | additive sprites, shader already runs |
| 12 | **Dry-up and low-slime grading**: `CanvasModulate` desaturating tint under 15% + red pulse vignette `deep` | S | `scripts/game.gd`, `scripts/hud.gd`, `atmosphere.gdshader` | Medium-high (readable danger) | none |
| 13 | **Parallax on one mist layer** and wall-top memory | S | `fog.gdshader` | Medium | 1 noise tap |
| 14 | **Level-start lantern opening + win flash** | S | `scripts/ui/transition.gd`, `game.gd`, `fx.gd` | Medium (polish) | none |
| 15 | **HUD text shadow + contrast** | S | `scripts/ui/ui_kit.gd`, `scripts/hud.gd` | Medium | none |
| 16 | **Event-only chromatic aberration** (splat, dry-up) via `BackBufferCopy` | S/M | new tiny shader, `game.gd` | Medium | only 0.2 s; backbuffer copy while active |
| 17 | **Normal-mapped torch light on hub stations only** (1-2 `PointLight2D`, `CanvasTexture` normals) | L | hub stations art tool (`tools/make_hub_art.py` emit normals), `scripts/hub.gd` | Medium; skip unless the hub rework wants extra depth | Light2D passes in Compatibility are documented only as "larger lights cost more"; test on the Android build before committing |
| 18 | **CanvasModulate per theme** (free colour grade) | S | `game.gd`, `themes.gd` | Medium-low | none |
| 19 | **Palette sanity: grayscale/contrast test screenshot** in the test suite | S | `tests/` + `tools/screenshot` | Medium (guards the "too dark" regressions) | none |
| 20 | **Wider bloom halo (second additive trail copy at 2x, alpha 0.1)** | S | `game.gd` `_build_trail_glow` | Low-medium | one extra draw |

Not recommended: CRT/scanline filter; real WorldEnvironment glow on web; screen-texture refraction on the slime; Light2D + normal maps on the maze.

### Suggested order
(1)+(2)+(3) in one change (30 minutes, then screenshot at 1x on all 10 themes and the hub). Then (4), then (5)+(6) as the "wow" pass, (7)+(9) for theme identity, (8)/(10)/(11) polish.

### Risks to feel
- Brightening the unknown tier too far removes the "reveal" magic. The guard: the unknown tier stays flat and hue-shifted with no tile detail, and the lantern adds colour only. Playtest the lantern at 0.10 / 0.14 / 0.18.
- A brighter fog narrows the contrast to the *remembered* tier; if floors read similar to unknown, increase the step between `FADE_ALPHA[3]` and `[4]`, not the floor gain.
- Hard mode relights from full fog (`fog_alpha_at`): any change to `FADE_ALPHA` must keep the `fog.gdshader`, `game._fog_alpha` and `fog_alpha_at` logic in sync (used for gameplay checks like glimmers); tests `test_hard_mode.gd` and lockstep-fade tests may need updated expected values.
- Every shader change must be re-checked on an Android WebGL build: no arrays indexed at run time, no `hint_screen_texture` in always-on passes, `highp` hash.

### Sources
- Godot 4.7 2D lights and shadows: https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html
- Godot canvas_item shader reference: https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html
- SLYNYRD Pixelblog 1: https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes
- Lospec dark palettes: https://lospec.com/palette-list/tag/dark
- WebKit dynamic uniform-array indexing bug: https://bugs.webkit.org/show_bug.cgi?id=234926
- Hyper Light Drifter palette/soft light notes (via search snippets): https://avclub.com/hyper-light-drifter-blended-past-and-present-to-become-1798255620 ; https://steamcommunity.com/app/257850/discussions/0/357284767236620083
- Klei forum on light radius (via search snippet): https://forums.kleientertainment.com/forums/topic/1151-dont-starve-updated/
- Darkwood design snippets: https://blog.eu.playstation.com/2019/05/01/darkwood-is-a-ps4-survival-horror-that-favours-creepy-atmosphere-over-cheap-jump-scares/ ; https://www.engadget.com/2013-05-29-darkwood-not-just-your-average-2d-roguelike-survival-horror-gam.html
- Hollow Knight, Noita, Don't Starve internals: general knowledge, not fetched.
