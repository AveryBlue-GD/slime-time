# Hat audit (Mad Hatter pass)

> Archived hat audit (scale/fit pass, hats live in upgrades v2 batch 2); the hats are still placeholders, the current hat rules live in [../architecture.md](../architecture.md) and [../handoff.md](../handoff.md).

Owner's note: "some of the scaling and details on the hats seem off". Every hat was rendered on
10 skins (lime, ocean, grape, Inkky, frost, ember, rainbow, a custom teal, solid lime, Stopwatch)
x 7 poses (idle, glide, charge, launch, air, land, splat), on every frame of 14 animations, at 2x
(title / skins showcase), on the hat wheel and on the skins screen's hats page.

- Diagnostic: `tests/demo_hat_audit.tscn` (writes 320x180 contact sheets; see its header), then
  `python3 -I tools/upscale_png.py`.
- Shots: `docs/polish-shots/hats_before_*.png` / `hats_after_*.png` (lineup, big, frames_tophat,
  skins_viking, skins_chef, wheel, hatspage; all 4x).
- Checks: `tests/test_hat_fit.gd`.

## Findings (before)

Set-wide
- **Splat squeeze**: in `splat_e/w` frames 0-2 the body is a 6-11 px column, but the hat stayed the
  ~14-20 px "narrow" version: a lollipop, brims 5+ px past the head.
- **Celebrate frame 0**: a loose gold sparkle above the head was read as the head top, so the hat
  jumped 6 px right (and 2 px up) for that frame. Same risk from goo flecks in splats.
- **Half-pixel jitter**: head_point kept half pixels (glide 10.0 / 10.5 / 9.5) and the hat rounded
  half away from zero while the sprite snaps half up, so the hat could slip a pixel against the body.
- **Width popping**: three widths with coarse thresholds (<=12 / >=16): every glide cycle flipped one
  frame to the full charge-wide hat (+3.5 px brim).
- **Fit model**: a guessed ellipse dome, flat-topped "hugging" bands that were widest *above* the
  head (beanie, cap, viking, propeller read as mushrooms / berets).
- **Eyes**: in charge frame 2 and the diagonal-away frames (eyes 2-3 px under the head top) brims and
  caps covered the eyes.
- **Pixel craft**: one near-black outline (30,20,22) for every hat regardless of material; flat
  hand-picked ramps without hue shift; noise patterns ((x+y)%3 knit dither, scattered polka dots,
  scattered stars, alternating pleat dither, dotted brim stitching).
- **Off the head** (hat wheel, a popped-off hat in flight): the underside cut-out for the dome left
  hollow bowls (crown and viking as open rings, beanie/cap missing their bottoms).

Per hat
- **Top hat**: brim ~3.5 px past the head (wide: 4.5); otherwise solid. Blocky diagonal shading.
- **Beanie**: a flat beret wider than the head; dithered knit noise; cuff merged into the body.
- **Party hat**: stripes + polka dots = noise at 1x; stretched version 11 px tall (touched the frame top).
- **Baseball cap**: a blue blob; a 1 px bill out to the side with dotted stitching; too wide.
- **Cowboy hat**: brim 3.5-5 px past the head; curl tips jaggy. Identity good.
- **Chef hat**: a lumpy marshmallow / tooth: puffs merged into one blob; dithered pleats.
- **Wizard hat**: good identity; random scattered stars (noise); brim 3.5 px past.
- **Viking helmet**: a pale flat slab covering the head to the eyes; 1 px wire horns that broke into
  dots; nose guard invisible; at wide the horns stuck out ~5 px.
- **Propeller cap**: OK colors; propeller only 1 px of colored dots; mushrooming crown.
- **Crown**: 5 uneven points that read as zigzag noise at 1x; tiny at normal width vs tall when
  narrow (inconsistent scale); hollow off the head.
- **Rainbow hat**: arch and clouds read; animation (stepped hue flow) fine. Hollow inside when loose.

## What changed

- `tools/make_hats.py`: measures the slime's head from its sheet (largest body blob; per width
  class: median dome profile, slimmest widest-row for brims); five fitted widths + a LOOSE row
  (off-head shape with its dark lining showing); `cap()` hugs the dome instead of mushrooming;
  per-hat outline derived from its material (cool, very dark, never black); hue-shifted 4-shade
  ramps; dome / cylinder / brim lighting; noise removed. Redrawn: beanie (rounded knit dome + ribbed
  cuff + pompom), party hat (two clean bands + rim), cap (forward bill with dark underside),
  chef hat (three creased puffs + pleated band), viking (darker steel dome, brass riveted rim, crest,
  thick tapered horns), crown (3 points over velvet, centered 2 px ruby), propeller (readable
  2-blade propeller on a stem). Brims 2-3 px past the head including the outline. `--check` mode.
- `scripts/slime.gd`: head_point / head_width use the largest 4-connected body blob (sparkles and
  flecks ignored); head_point x whole pixels (+-0.5 -> 0); `eye_points`.
- `scripts/hats.gd`: widths NARROW / NORMAL / WIDE / SQUEEZED / BROAD / LOOSE, `width_for` bands
  (<=11, 12, 13-14, 15-16, >=17), `Hats.lift`: lifts a hat 1-3 px only in the frames whose eyes would
  be covered (about 6% of hat-frames, mostly charge and diagonal-away).
- `scripts/hat.gd`: snaps like the renderer (half up), applies the lift, LOOSE while flying.
- `scripts/ui/hat_wheel.gd`: wheel shows the LOOSE row.

## Still imperfect

- The lift means a hat bobs up 1-2 px in a few charge / diagonal frames (better than covering eyes).
- SQUEEZED hats are small and simple (no horns, single gem) - they show for 2-3 splat frames.
- Center details (cap seam, viking crest, propeller stem) are 1 px on an even-width head, so half a
  pixel off center; brims and crowns are symmetric.
- The hat wheel draws the rainbow hat without its flowing shader (unchanged).

## Live release check (upgrades v2 batch 2, 2026-10-15)

Hats are live for real players, so every place they now show was checked: the prize wheel's
wedges (and right after a win), the SHOP's HATS section (the TAILOR), the wardrobe's HATS page,
the hub slime, in-game on all 6 trail styles (skin goo, ink, glow, gold, candy, starry) with lime,
Inkky, ocean, Stopwatch, rainbow and a custom color, at 2x (title / skins), and every splat frame.
Shots (4x): `docs/polish-shots/hats2_before_*.png` / `hats2_after_*.png` (lineup, big, squeezed,
wheel_won, shop, wardrobe, hub, ingame_trails). Pages `squeezed` and `ui_*` were added to
`tests/demo_hat_audit.tscn` (`--only=squeezed,ui`).

Findings
- **Wheel**: the rainbow hat sat static on its wedge (no flow). A win only said YOU WON THE X! (the
  hat wasn't shown on you anywhere until the overlay closed).
- **SHOP / TAILOR**: hat tiles are name + price only - 45-80 tickets for a hat you can't see. The
  13 px tiles have a 9 px face, too small for a hat icon (hats are 8-13 px tall).
- **Viking**: horns were 1 px hooks; at WIDE (charging, landing) they flattened into `[ ]` brackets;
  SQUEEZED had none (a grey bullet). Crest 1 px, half a pixel off center.
- **Propeller cap**: 4 panels split by x, so red was a sliver on the left; a little bill stuck out
  to the left (lopsided); the propeller sat flat on top like a lid; stem 1 px off center.
- **Baseball cap**: a blue bowl; 1 px seam off center; the deepest hat over the face, so the most
  eye lifts (29 hat-frames, up to 3 px) - it bobbed on every diagonal glide.
- **Bob**: lifts are monotone through the charge animations (the hat holds while the body squashes,
  never pops up), but in the looping diagonal glides the beanie, viking and cap jumped 1 px up for
  one frame of every cycle (NARROW hats reached a row further down the stretched head).
- **Party hat**: 1 px tip and pompom half a pixel right of center. **Squeezed crown**: a cup.
- Fine as is: hub (y-sort, scale), in-game on every trail style and skin (trails stay under the
  hat; Stopwatch face and rainbow skin don't clash), wardrobe tiles and locked silhouettes, title.

Fixes
- `tools/make_hats.py`: viking horns are pixel crescents out of the helmet's shoulders (HORNS:
  big / low for WIDE / small for SQUEEZED), 2 px crest; propeller cap panels are wedges meeting at
  the top, no side bill, 2 px button + stem, the blades caught mid-turn over it; baseball cap is
  shallower with a shadowed band, a curved visor and a 2 px badge and button; party cone centered
  (2 px tip / pompom); squeezed crown has three prongs; `cap()` no longer reaches further down a
  stretched (NARROW) head.
- Lifts: {0: 1801, 1: 96, 2: 15, 3: 2} -> {0: 1850, 1: 53, 2: 11} hat-frames; no hat moves up
  against the body in any glide / idle / charge / land loop any more.
- `scripts/hats.gd`: `flow_step` / `flow_texture`: the flowing hat's hue turn done on the CPU, same
  math and steps as `rainbow_hat.gdshader`, for draw calls that can't take the shader.
- `scripts/ui/hat_wheel.gd`: the wheel draws the rainbow hat with `flow_texture` (redrawn when the
  step changes); try-on slimes in your skin wearing the hat: 2x either side of the wheel after a
  win, 1x either side of the description for the focused TAILOR hat (no layout, price or store
  changes).

Still imperfect
- The baseball cap reads as a cap at 2x, more of a sailor cap at 1x; a front-on bill at 14 px is
  a compromise (it can't overhang the eyes).
- 1-2 px lifts remain in charge frame 2 / diagonal charges (held, never a pop-up).
