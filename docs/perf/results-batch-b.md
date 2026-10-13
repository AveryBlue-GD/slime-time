# Perf batch B: results (2026-10-14)

The next safe items from [cpu.md](cpu.md) (#2, #3, #4) and [rendering.md](rendering.md) (#2, #5b, #6, #7), applied
with **identical output**. Baseline = `194d2cc` (a worktree of it); after = `0a9c3e3`, `01b47a8`, `f164f5c`,
`a357633`. Apple M3, headless `--fixed-fps 60` (dummy renderer: script work only, the GPU is not measured).

## Before / after

| Measurement | Before | After |
|---|---|---|
| Physics tick, L10 gliding, Brightness 10 (autopilot, mean / p95) | 1.16 / 1.55 ms | **0.19 / 0.33 ms** |
| same, randomizer seed 5 (600x344 fog), Brightness 10 | 1.17 ms | **0.19 ms** |
| same, L10, Brightness 0 | 0.163 ms | **0.070 ms** |
| Physics tick standing still, Brightness 10 | 0.25 ms | **0.075 ms** |
| Fog uploads standing still (L10 / randomizer max) | 16/s, 114 / 215 KB per frame | **~0.6/s, 6 / 11 KB per frame** |
| Fog + trail uploads while gliding over new ground | ~1 each per frame (843 KB L10, 1.59 MB max) | unchanged (every one is a visible change) |
| Randomizer build + ticket, MORE SLIME 10, 2,000 seeds: mean / p99 / worst | 22.7 / 86.7 / **896 ms** (seed 121) | **4.9 / 10.3 / 17.9 ms** |
| same, MORE SLIME 0: mean / p99 / worst | 7.2 / 16.5 / 25.1 ms | **1.8 / 3.6 / 6.5 ms** |
| Story mazes 1-10, first builds (L10) | 73.5 ms (18.7) | **13.1 ms (2.6)** |
| Level start `_ready`: story L10 / random 121 / 5 / 655672586 (MORE SLIME 10) | 48.8 / 898 / 58.5 / 107 ms | **26.2 / 35.1 / 29.3 / 44.7 ms** |
| Retry `_ready` (cached maze): story L10 / randomizer | 10.6 / 26 ms | 10.6 / **18 ms** (ticket BFS) |

## What changed

1. **Fog bookkeeping** (`game.gd`): fog and trail live in `PackedByteArray`s that `_relight`, `_reveal_light` and
   `_paint_cells` read once and write directly (`decode_u32`/`encode_u32`); each disc row is walked over its exact
   span (the original float test decides the ends; the inside of a row is always one run); a call with the same
   radius (same fog tick for `_relight`) skips the previous disc's spans. Textures upload from short-lived Images that
   share the bytes. `fog_image` / `trail_image` are now read-only snapshots.
2. **Upload gating** (`game.gd`): relight writes that only restart a cell still in the first fade band mark the fog
   lazily; it uploads at the next visible change or when the oldest held-back lit time is 1.25 s old (the shader
   can't tell the times apart before 1.5 s). Everything else still uploads the same frame.
3. **Mazes** (`maze_generator.gd`, `spawn_picker.gd`, `ticket_spawn.gd`): flat-array BFS with the same neighbour and
   visit order; `_add_loops` searches only 10 steps out; `SpawnPicker.pick` bounds every start's eccentricity from
   each search done (d(v,c) <= ecc(c) <= d(v,c) + ecc(v), seeded with the double-sweep ends and a central cell) and
   searches only when the bounds straddle the asked route. Same decisions, same RNG draws.
4. **Shaders**: outer fog `solid` skips the 13 taps (1x1 unrevealed texture: every tap is 1.0, blend exactly 1.0);
   fog skips the mist where the final alpha is 0 (mix blending leaves the pixel unchanged); atmosphere skips the mist
   when `mist_strength == 0` (HUD and hub vignettes). No arrays added.

## Verification

- **Pixel diffs** vs the `194d2cc` worktree, real renderer, fixed fps/seed: 51 frames (title, hub, hub rainbow, level
  select, L1/L5/L10 incl. mid-glide, L10 Brightness 10, L5 standing still with Brightness 10 (lazy uploads), L3 hard
  refog, L10 rainbow, randomizer seed 5 with the outer fog on screen, story, pause) + 242 dense frames (every 3rd
  frame, L4 standing still with Brightness 7 and L6 hard) + batch A's 40-frame set: **0 differing pixels** after each
  item. Base vs base: 0. A deliberately wrong outer-fog alpha changed 5,535 px per frame, so that path is on screen.
- `tests/test_fog_bytes.gd`: replays glides (jitter, standing still, Brightness changes, landings, stains, a broken
  wall, rainbow trail, the 4096 s time clamp) on L1, L10 and randomizer 5 against the old per-cell Image code kept in
  the test: fog and trail **byte-identical after every one of 5,078 steps**; also checks each frame that every cell of
  the uploaded fog is in the same fade band / refog state as the current one. Mutations (span off by one, lazy window
  30 ticks) make it fail.
- `tests/test_maze_golden.gd`: digests written by the `194d2cc` code (and re-checked passing on that worktree) for
  2,000 seeds x MORE SLIME 0/5/10 + hard and all 20 story mazes (walls, start, chalice, route, ticket, coin cells,
  par): **all 8,020 match**.
- `./tools/test_all.sh`: 42 suites, 0 failed (incl. phase 3's autopilot wins). Web export builds (`index.pck`
  4,830,248 B).

## Skipped

- **Partial (dirty-chunk) texture uploads:** `ImageTexture` has no sub-rect update in 4.7.2; the only partial path,
  `DrawableTexture2D.blit_rect`, is a GPU blit not proven bit-exact on Compatibility/WebGL, and chunked sprites with an
  apron (rendering.md #1) are a larger change. Gliding uploads are unchanged.
- Everything marked FIDELITY RISK (coarser fog grid, 9-tap kernel, cheaper hashes, palette trail, rainbow throttle,
  lower physics rate, outer fog as 4 strips).
