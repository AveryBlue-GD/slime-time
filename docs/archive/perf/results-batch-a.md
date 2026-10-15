# Perf batch A: results (2026-10-13)

> Archived: applied optimizations, batch A (2026-10-13); the live rules are in [../../architecture.md](../../architecture.md) "Performance" and the audits in [../../perf/](../../perf/).

The safe items from [cpu.md](../../perf/cpu.md), [rendering.md](../../perf/rendering.md) and [startup-memory-web.md](../../perf/startup-memory-web.md),
applied with **identical output**. Baseline = `1bc2b12`; after = this batch's commits. Apple M3, headless,
`--fixed-fps 60` (dummy renderer: script, layout, text shaping and canvas recording only; GPU not included).
Steady = mean frame over 300 frames after a 30-frame warm-up.

## Frame time and load time

| Measurement | Before | After |
|---|---|---|
| Skins screen, rainbow (steady frame) | 12.84 ms | **1.52 ms** (item 1 alone: 4.36) |
| Hub, rainbow | 7.67 ms | **0.81 ms** |
| Level select, rainbow | 8.53 ms | **0.94 ms** (item 1 alone: 2.35) |
| Title, rainbow | 1.57 ms | **0.23 ms** |
| Level 10 autopilot, rainbow | 4.39 ms | **0.75 ms** |
| Skins screen, Stopwatch / hub, Lime (unaffected skins) | 0.098 / 0.068 ms | 0.096 / 0.070 ms |
| Menu open, warm (scene change + 2 frames; level select / skins / settings / upgrades) | 38.8 / 37.3 / 34.6 / 36.6 ms | **11.1 / 12.2 / 9.0 / 11.6 ms** |
| Level 10 retry: main `_ready` (2nd+ build) | 39.5 ms | **11.2 ms** |
| Randomizer seed 5 retry: main `_ready` (2nd+ build) | 30.3 ms | **15.3 ms** |
| Story intro (steady frame) | 0.386 ms | 0.392 ms (within noise) |
| Web export `index.pck` (same tree, filter only) | 4,835,444 B | **4,825,672 B**; no `build/` files left in it |

## What changed (all pixel-identical)

1. **Rainbow re-theme batching** (`skin_text.gd`, `goo_box.gd`, `ui_kit.gd`): SkinText holds its theme's change signal
   while it edits colours and goo, then emits once; `GooBox.set_goo_color` does the same for every theme
   `UIKit.make_theme` registers; the global label/goo part runs once per frame when SkinTexts share the same rainbow
   time (a SkinText with a different time still runs it, so "last wins" is kept).
2. **GooBox layout cache + runs** (`goo_box.gd`): the goo layout depends only on (canvas item, size), so it is built
   once and replayed with the current shades; opaque goo is drawn as same-shade horizontal runs (about 2.9x fewer
   rects over the test set); translucent shades fall back to the original 1 px writes in order.
3. **Caches** (`levels.gd`, `game.gd`, `maze_tiles.gd`, `menu_backdrop.gd`): story mazes per (level, hard), story coin
   cells, the last randomizer maze (game gets `duplicate(true)` copies; checked that breaking a wall in a copy does not
   reach the cache), tile sets per theme (dungeon + last level theme), and the backdrop's tile cells.
4. **Small items**: shared additive light material + one light texture per size (`fx.gd`); one shared station skin
   material in the hub; RotateHint re-checks on window resize / touch instead of polling; backdrop `clip_contents`
   off; story emitters compute heroes/torches once per step; export exclude filter (`build/*`, `walls.png`,
   `fillets.png`, `button_*.png`, none referenced); shader warm-up under the title's opaque backdrop (fog, trail,
   hub room, rainbow hat, colour wheel, additive). The warm-up's gain can't be measured headless (it targets
   first-use compiles on WebGL).

## Verification

- **Pixel diffs:** a baseline worktree of `1bc2b12` and the new tree rendered the same 40 frames with
  `--fixed-fps 60`, a fixed global seed and the menu backdrop's wall-clock drift pinned to the frame count
  (it follows `Time.get_ticks_msec`): title, title rainbow, hub, hub rainbow, skins (rainbow at frames 30/61/150,
  Stopwatch, Chameleon), settings, level select, upgrades, levels 1/5/10 autopilot (frames 40/200/400), level 10
  rainbow, randomizer seed 5, story intro (frames 60/300/600/900), pause menu. Baseline vs baseline: 0 px; after
  each item: **0 differing pixels in all 40 frames**.
- GooBox: 1,080 box/state/size/colour/position cases rasterized old vs new: 0 mismatches.
- Caches: all 20 story mazes, 10 coin lists, a randomizer maze and the backdrop cells equal to fresh builds.
- `./tools/test_all.sh`: 40 suites, 0 failed. Web export builds; the exported pck smoke-runs title, hub, skins and
  level 10 headless.

## Skipped

- **Pausing off-screen coins:** a paused coin can't resume on exactly the same spin frame (catching up a summed delta
  rounds differently from adding it frame by frame, and a wall clock would also keep spinning through pauses), and the
  per-coin cost is microseconds. Not worth a possible frame shift.
- Skipping `add_theme_color_override` for labels whose 8-bit colour is unchanged (rendering.md #3): the float tint
  still reaches the text shader, so it is not provably identical.
