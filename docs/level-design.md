# Level design: spawn picker, story layouts v4, calibration, save migration

Written 2026-10-13 (gameplay-dev). Code: `scripts/spawn_picker.gd`, `scripts/maze_generator.gd`
(`generate_level`, `generate_random`, `dead_end_depths`), `scripts/levels.gd` (`DATA`, `coin_cells`,
`coin_keys`, `level_par`, `legacy_par`), `scripts/progress.gd` (`_migrate_coins`, `_migrate_medals`).
Rollback tags from before this work: `v2-phase3`, `v2-before-advisor-polish`.

## 1. The spawn picker (`SpawnPicker`)

One shared, seeded, deterministic function for the randomizer and the story levels.

**Edge depth** of a cell: `d = min(x, y, w - 1 - x, h - 1 - y)` in cells (0 = on the outer ring).

| Class | Odds | Cells |
|---|---|---|
| EDGE | 33% | `d == 0`: the outer boundary ring of cells (corners included) |
| NEAR | 30% | `1 <= d <= 2` (`NEAR_DEPTH`): near the edge, not on it |
| ANY  | 37% | every cell of the maze, uniformly (so it can also land on/near the edge) |

Algorithm (`SpawnPicker.pick(maze, seed, kind = -1)`):
1. `rng.seed = seed ^ 0x2545f491`; `roll = rng.randi_range(0, 99)`: `< 33` EDGE, `< 63` NEAR, else ANY.
   The roll is always drawn; story levels pass a forced class instead of using it.
2. Longest route `L` = double-sweep BFS (exact on the loop-free story mazes, a close lower bound on
   the randomizer's looped mazes).
3. The class's cells (row-major) get a seeded Fisher-Yates shuffle (`randi_range` only). The first
   cell whose farthest cell is at least **60%** of `L` (`steps * 100 >= 60 * L`, integers) is the
   start; that farthest cell (ties: first in row-major order) is the **chalice**.
4. If no cell of the class qualifies, the next class is tried (EDGE -> NEAR -> ANY -> EDGE). ANY
   always succeeds (an end of the longest route qualifies).

Only integer RNG draws and integer comparisons, so web and desktop pick the same cell. Measured
over 10,000 seeds (40 real randomizer mazes): EDGE 33.0%, NEAR 29.9%, ANY 37.1%; 0 fallbacks
(the 60% rule never empties a class in practice); every route >= 60% of the longest.

**Randomizer:** `MazeGenerator.generate_random` = noise maze + `SpawnPicker.apply(maze, seed)`.
This replaces the old "random cell whose farthest cell is >= 75% of the longest route" rule.

## 2. Story levels v4 (`Levels.DATA`, `MazeGenerator.generate_level`)

Each level keeps its size, target, theme and coin count; the maze is rebuilt:
- **run**: the growing tree keeps going straight with chance `run` (0.30-0.45), so each solution
  route's longest straight is now 5-10 cells (was 3-6) where the 8-tile leap pays off.
- **loops** (L6-L10: 2, 3, 4, 5, 6): shortcut gaps between cells >= 10 cells apart along the
  passages, never next to a dead end (coins live there). Hard mode has none.
- **branching** lowered on several levels (advisor report: high branching = many 1-2 cell stubs).
- **coins** (`Levels.coin_cells`): dead ends >= 3 cells deep first, one per side branch of the
  solution route, then other deep ones, stubs only if a level runs out. 131 of the 165 coins now
  sit 3+ cells deep. `Levels.COINS` and the total 165 are unchanged.
- **spawn**: a forced class per level; the exact cell is drawn by `SpawnPicker` from the level's
  constant seed, so every player and every run sees the same start. ANY-class levels were seeded
  so the start is visibly interior (edge depth >= 3).
- Seeds were searched (normal and hard) so each new solution route stays within ~5% of the old
  layout's, keeping par times and the difficulty ramp.

| Lvl | cells | spawn class | start (edge depth) | route old -> new | dead ends | coins (3+ deep) |
|---|---|---|---|---|---|---|
| 1 | 10x6 | EDGE | (1,5) d0 | 22 -> 23 | 10 | 6 (5) |
| 2 | 12x7 | NEAR | (10,3) d1 | 30 -> 30 | 12 | 9 (8) |
| 3 | 13x8 | ANY (interior) | (3,4) d3 | 38 -> 40 | 15 | 7 (7) |
| 4 | 15x8 | EDGE | (0,3) d0 | 46 -> 45 | 21 | 12 (10) |
| 5 | 16x9 | NEAR | (1,7) d1 | 54 -> 56 | 21 | 14 (14) |
| 6 | 18x10 | ANY (interior) | (4,5) d4 | 62 -> 63 | 31 | 17 (12) |
| 7 | 20x11 | EDGE | (0,3) d0 | 70 -> 68 | 33 | 20 (16) |
| 8 | 22x12 | NEAR | (19,7) d2 | 80 -> 80 | 37 | 22 (16) |
| 9 | 24x13 | ANY (interior) | (3,5) d3 | 90 -> 91 | 43 | 27 (21) |
| 10 | 26x14 | EDGE | (3,0) d0 | 100 -> 95 | 41 | 31 (22) |

4 edge, 3 near-edge, 3 interior. Level 1 has no interior cells at all (6 rows: max depth 2).
Hard mode uses the same class per level on its own seeds (`HARD_SEEDS`, `HARD_BRANCHING`,
`HARD_RUN`), routes 25-96 cells (old 25-101). Overviews: `docs/polish-shots/spawn_level01..10.png`
and randomizer seeds `spawn_random_110/114` (EDGE), `101/107` (NEAR), `100/102` (ANY), made with
the debug scene `tests/demo_overview.tscn` (fog off, green ring = start, gold ring = chalice, cyan
dots = route; see its header for the command).

## 3. Difficulty calibration

- **Story:** `slime_cost_per_tile = target * 100 / route_tiles`, with `route_tiles` the real
  start-to-chalice route. So a perfect glide uses exactly the level's `target`, and the exploration
  allowance ratio (meter / solution route = 1 / target) is the level's original one, wherever the
  slime starts. Because routes stay within ~5% of the old ones, absolute slack is also near the old.
  Par = `Levels.par_for_path(route)` as before (now from the new route). The autopilot clears every
  level within 4% of its target and under par (`tests/test_phase3.gd`).
- **Randomizer:** now calibrated on the real route too (`target` 85%, hard 90%), instead of on the
  maze's longest route. With the old rule, a 60% route would have used only ~51% of the meter; now
  every perfect run uses 85% whatever the spawn class. This is a little tighter than before on
  average (old routes were 75-100% of the longest, so a perfect run used 64-85%).
- Tickets (`TicketSpawn`), par, medals, the tutorial cues and beacon, the camera, the hat and the
  fog reveal all read `maze.start` / `maze.goal`, so they follow the real start; nothing assumed
  the corner except some tests (now using `tests/start_dirs.gd`).

## 4. Save migration (`[meta] version` 4)

Story coin keys are `level + cell`, so a v1-3 save's keys name cells of the old mazes.
- **Coins** (`Progress._migrate_coins`, only when `version < 4`): each level keeps its COUNT of
  found coins (as counted before: valid strings, capped at `Levels.COINS`), re-mapped to the first
  N keys of `Levels.coin_keys(level)` (the deep-first priority order). `coins_earned` is unchanged,
  so `coins_spent` (upgrades) stays covered and nobody goes negative or loses an upgrade.
- **Medals:** stored v3 tiers are kept as they are (never downgraded, never recomputed). v1-2
  saves still turn best times into tiers, against the OLD layout's par (`Levels.legacy_par`, from
  the old route lengths `LEGACY_STEPS` / `LEGACY_HARD_STEPS`), so they get exactly the tiers they
  got before.
- **Records:** best times are kept as they are, normal and hard. They were set on the old layouts,
  so some may now be easier or harder to beat than the new par; nothing is recomputed downward.
- **Hard mode:** hard clears, hard records and hard tiers are kept the same way (hard has no coins).
- **Idempotent:** a pure function of the old data; reading the same old save twice gives the same
  result, and the next save is version 4, which is never migrated again.
- **Save codes:** `SLIME1-` codes go through `_read`, so old codes migrate the same way.
- **Hostile values:** wrong-typed version = treated as old (migrated); junk coin lists count 0,
  floods cap at the level's coins; upgrades still clamp to what was earned.
- A version 4 save loaded in an older build would read the new coin keys against old mazes (not
  handled, like the v3 note in handoff.md).

Tests: `tests/test_spawn_picker.gd` (odds, min route, determinism, integer-only, pinned picks,
solvable / chalice / ticket / coins reachable), `tests/test_layout_migration.gd` (partial coins per
level, spent upgrades, medals, hard data, idempotence, v2 times, old save codes, hostile values,
deep coins), plus updated `test_phase3` (autopilot under par), `test_random_tickets`,
`test_tickets` (version 4, legacy par) and the tests that assumed a corner start.
