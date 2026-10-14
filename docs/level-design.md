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
Since the usage rework (section 5) the randomizer passes a target `route` instead: a start qualifies
when its farthest cell is >= the route, and the chalice sits exactly `route` cells from it.

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
`HARD_RUN`), routes 25-96 cells (old 25-101). (Superseded for hard mode by section 7: bigger hard
mazes since save version 5.) Overviews: `docs/polish-shots/spawn_level01..10.png`
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
- **Randomizer (superseded by section 5):** now calibrated on the real route too (`target` 85%, hard 90%), instead of on the
  maze's longest route. With the old rule, a 60% route would have used only ~51% of the meter; now
  every perfect run uses 85% whatever the spawn class. This is a little tighter than before on
  average (old routes were 75-100% of the longest, so a perfect run used 64-85%).
- Tickets (`TicketSpawn`, retired in section 6), par, medals, the tutorial cues and beacon, the camera, the hat and the
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
- **Save codes:** pre-release `SLIME1-` codes are now refused outright (fresh-start policy, docs/itch-release.md).
- **Hostile values:** wrong-typed version = treated as old (migrated); junk coin lists count 0,
  floods cap at the level's coins; upgrades still clamp to what was earned.
- A version 4 save loaded in an older build would read the new coin keys against old mazes (not
  handled, like the v3 note in handoff.md).

Tests: `tests/test_spawn_picker.gd` (odds, min route, determinism, integer-only, pinned picks,
solvable / chalice / ticket / coins reachable), `tests/test_layout_migration.gd` (partial coins per
level, spent upgrades, medals, hard data, idempotence, v2 times, old save codes, hostile values,
deep coins), plus updated `test_phase3` (autopilot under par), `test_random_tickets`,
`test_tickets` (version 4, legacy par) and the tests that assumed a corner start.

## 5. Randomizer slime usage (2026-10-13)

Owner request: lots of variation in how much of the meter a perfect randomizer run needs, rare
extremes both ways, while each maze stays scaled to the slime the player can spend.
Code: `Levels.random_usage_permille / random_route_cells / random_cells / random_config`,
`MazeGenerator.generate_random(config)`, `SpawnPicker.pick(..., route)`, `TicketSpawn` (retired, section 6), `game.gd`
(`perfect_usage`, `usage_text`). Test: `tests/test_random_usage.gd`.

**The meter is fixed per player.** A full meter glides `RANDOM_METER_TILES` = 136 tiles with no
MORE SLIME (x `Upgrades.slime_factor`: 272 at level 10). 136 is the old randomizer's median maze
(58-cell route at 85%), so a tile costs what it used to at level 0. (Before, the cost per tile was
re-fitted to every maze, so upgraded players had a perfect run of only 85% / slime factor.)

**Usage u per seed.** One integer roll 0..9999 of a seeded `RandomNumberGenerator`
(`seed ^ USAGE_SALT`) is looked up in `USAGE_QUANTILES`: 101 permille knots (every 1% of the roll,
integer interpolation between) of a Beta(2.1, 1.7) bell stretched over [0.10, 0.95]. u depends on
the seed only; the MORE SLIME level of the code scales the route, not u. Measured over 10,000
seeds (1 + 7919 i):

| | target | measured |
|---|---|---|
| median | 0.55-0.60 | 0.582 |
| middle 50% | ~0.42-0.72 | 0.420-0.725 |
| P(u <= 0.20) | ~2-3% | 2.56% |
| P(u >= 0.90) | ~2-3% | 2.18% |
| P(u <= 0.12) / P(u >= 0.93) | very rare | 0.39% / 0.55% |
| range | [0.10, 0.95] | 0.100-0.948 (0.10 exactly = roll 0) |

```
u range    seeds
0.10-0.15   83 ####
0.15-0.20  164 ########
0.20-0.25  335 #################
0.25-0.30  454 #######################
0.30-0.35  561 ############################
0.35-0.40  643 ################################
0.40-0.45  663 #################################
0.45-0.50  771 #######################################
0.50-0.55  788 #######################################
0.55-0.60  861 ###########################################
0.60-0.65  878 ############################################
0.65-0.70  884 ############################################
0.70-0.75  825 #########################################
0.75-0.80  754 ######################################
0.80-0.85  642 ################################
0.85-0.90  476 ########################
0.90-0.95  218 ###########
```

**Route.** `route = max(6, round((u x 136 x (1 + 0.1 L) + 13/16) / 2))` cells (integer maths), L =
the seed code's MORE SLIME level; so a perfect glide uses u of that player's meter (+-1 cell of
rounding, under 1% at level 0). Minimum 6 cells (a 10% run at level 0 is 7 cells).

**Size (reworked 2026-10-14: no longer follows u).** The owner did not want short-route seeds to
make small mazes (they came out as small as 10x6). Now u only moves the goal: the maze is sized for
the LONGEST route any seed can ask for at the code's MORE SLIME level (`Levels.random_max_route_cells`,
the u = 0.95 route: 65 cells at level 0, 97 at 5, 130 at 10; hard mode its fixed 0.90 route) and the
seed's size dice, never for its own u. Start size aims at a longest route of `1.25 x that + 12`
cells (noise mazes' longest route ~ 4.6 x sqrt(cells)), shaped by the seed's 18-24 x 10-13 dice,
clamped to the level's floor (`random_floor_cells`: the old base 18 x 10 x sqrt(1 + 0.1 L) per side,
18x10 / 22x12 / 25x14 at 0 / 5 / 10) .. 36x20 (`RANDOM_MAX_CELLS`, unchanged for the web build).
`generate_random` grows it (+1/8 per side) until the longest route is >= 115% of that max route
(`config.room`), and at 36x20 tries up to 4 re-seeded noise fields until it holds the max route
itself. The goal is then simply the cell `route` cells from the start inside that big maze, so a
low-u seed's ticket can sit near the spawn. Route, meter (136 tiles x factor), spawn classes and
the u distribution are untouched. From MORE SLIME 4 on nearly every maze is 36x20.

Before / after over 2,000 seeds (the golden test's seeds; `tests/bench_random_size.gd`), area in
cells min / p10 / median / p90 / max (mean), share under the floor, build time mean / p99 / worst
(headless, Mac):

| MORE SLIME | before | after |
|---|---|---|
| 0 (floor 180) | 60 / 70 / 180 / 322 / 504 (189), 47.9% under; 1.5 / 3.1 / 5.9 ms | 400 / 405 / 408 / 420 / 532 (413), 0%; 3.2 / 6.1 / 6.5 ms |
| 5 (floor 264) | 60 / 126 / 351 / 640 / 720 (367), 33.9% under; 2.9 / 8.4 / 12.2 ms | 680 / 700 / 720 / 720 / 720 (715), 0%; 5.7 / 9.4 / 13.1 ms |
| 10 (floor 350) | 60 / 190 / 578 / 720 / 720 (516), 25.8% under; 4.2 / 9.5 / 16.7 ms | 720 everywhere (720), 0%; 7.3 / 17.2 / 18.1 ms |

Before, the mean area by u band at level 0 was 62 (u < 0.3) / 155 / 305 (u >= 0.7); now 416 / 413 /
413. Builds cost more on average (every maze is as big as the old u = 0.95 one) but the worst case
stays at the batch-B level (17.9 ms at MORE SLIME 10, docs/perf/results-batch-b.md): 18.1 ms.
Every build is solvable with its ticket exactly `route` (>= 6) cells away (8,000 builds checked by
`test_maze_golden`); the golden MORE SLIME 0/5/10 lines were rewritten (all seeds not already at
36x20 changed); the story and hard-mode lines are byte-identical. A route <= 20% of the meter (the
ticket near the spawn) stays rare: 2.95% of 10k seeds; within 4 cells (Manhattan) of the spawn: 4
of 600 real mazes.

**Spawn + chalice.** The 33/30/37 EDGE/NEAR/ANY roll and the class fallback are unchanged; the
minimum-route rule is now "farthest cell >= route" (relative to the target, not the diameter). The
chalice is a seeded pick among the cells exactly `route` cells from the start (always exists). If
no cell reached the route at all, the longest route would be used (never seen). Measured: 0 class
fallbacks in 1,200 mazes; EDGE 30.7 / NEAR 31.0 / ANY 38.3% over 600 (test tolerance +-5%).

**Ticket (superseded by section 6: the ticket is now the goal, on the chalice's cell).** Same rules (10-60% of the meter from the start, weight floor + (f / 0.6)^3, now cubed:
small low-u mazes have few far cells, and the square let 10-20% picks reach ~13%; now ~10%), the
fraction measured at the code's level. Start -> ticket -> chalice <= 92%, or, for a route longer
than 92% (u 0.93-0.95), on-route cells only (no detour). Short routes put it off the route, well
past the chalice. With no fitting cell there is no ticket: the HUD pod says NONE HERE and the win
says NO TICKET IN THIS MAZE +N (0 of 600 sampled mazes). Payout, daily cap (5 paid wins), seed
repeat rules and the no-MORE-SLIME 1-ticket cap are unchanged: a 10% maze pays exactly what a 90%
one does, so rerolling NEW MAZE for short ones only reaches the same daily cap faster.

**Par** uses the real route as before. **Hard mode** keeps a fixed u = 0.90, no upgrades (route
~62 cells), calibrated on the real route.

**Seed codes.** "N-L" builds the maze for level L: same u, route, size, start and goal (now the
ticket, section 6) for everyone. The player's own meter is used: a lower-level code leaves more slack; a higher-level
code needs more of the meter, capped at 95% (`RANDOM_MAX_USAGE`) so a borrowed code is always
winnable.

**HUD.** The randomizer win text is `TICKET CLAIMED!` / `TIME 0:41.2` / `SEED ...`; it says nothing
about how much slime the run used (the USED nn% SLIME / EFFICIENT! line was removed 2026-10-14).

Shots (`tests/demo_overview.tscn -- --unlock-all --usage=P [--upgrades=L,0,0]`): the old `usage_*`
shots show the u-sized mazes (u 0.10 was 10x6); since the size rework `docs/polish-shots/size_u100_ms0`
(u 0.10: 29x14, route 7, ticket a few cells from the spawn), `size_u200_ms0`, `size_u550_ms0`,
`size_u950_ms0`, `size_u100_ms10`, `size_u950_ms10` (36x20, route 129), and the HUD pod
`size_hud_attempt1` / `size_hud_attempt3`; the result screen `usage_result`.

## 6. The ticket is the randomizer's goal (2026-10-14)

Owner request: randomizer mazes (every randomizer mode, hard included) have no chalice; the gold
TICKET voucher is the end objective, and a win pays by how many attempts that maze took. Story
levels keep the chalice and are untouched. Code: `scripts/ticket_goal.gd` (`TicketGoal`),
`game.gd` (`goal`, `_make_goal`, `_count_attempt`, `_on_goal_body_entered`), `Progress`
(`RANDOM_ATTEMPT_PAY`, `random_attempts`, `begin_random_attempt`, `random_payout`,
`complete_random(assisted, seed, attempt)`), `hud.gd` (`set_attempt`, `show_rewards`).

**Where.** The ticket stands exactly where the chalice did: `maze.goal`, the cell `route` cells from
the start (section 5). The game frees the scene's Chalice node and puts a `TicketGoal` (Area2D, the
chalice's 6 px grab circle, so the meter calibration, par and perfect-run usage are unchanged) in
its place. The maze build (u, route, size, spawn class, start, goal, seed codes) is untouched:
`tests/test_maze_golden.gd` still matches every story level and 8,000 randomizer builds (its digest
dropped only the old pickup's fields, rewritten from the build just before this change).

**Look.** The 8x8 `assets/ui/icon_ticket.png` voucher over the fog with the chalice's pulsing 72 px
glow and a 1 px bob (off with Reduce Motion). Hidden until the slime is within 24 px. No glint and no
gold twinkle through the fog (both removed 2026-10-14 at the owner's request, for the chalice too:
it now stands on one frame of its sheet; the steady glow pulse stays). On the win it pops into gold sparks with the ticket
chime (the chalice fanfare stays in story levels); the message reads TICKET CLAIMED!. F1 FULL BRIGHT
shows it; the overview's gold ring marks it.

**Attempts.** Each start of the same maze is an attempt: the first start, every dry-up RESTART, R /
pause-menu restarts, REPLAY MAZE after a win and coming back from UPGRADES. Counted in memory only
(`Progress.random_attempts`, keyed by the seed code + H for hard mode, never saved); NEW MAZE (and
the hub portal, which rolls a new maze) clears it, so a new maze starts at 1. The HUD pod under the
maze name (two lines, right-aligned; since 2026-10-14, was `TRY 2  4 TIX`) reads `ATTEMPT 2` /
`TIX AVAILABLE 4` (no "/5" since 2026-10-14): the attempt and what a win would pay right now,
counting down 5, 4, 3, 2, then 1 from the 5th, with all caps applied (1 for a typed or replayed
seed or no MORE SLIME (not in dev mode, where everything is unlocked and 5-4-3-2-1 shows); dim 0 when nothing would be paid: daily limit, seed already paid today, dev
toggles, assist). It is derived every frame from `game.payout()`, the same function the win pays
from (dev mode pays the same, only unsaved). The pod
reaches y 40, so in randomizer mazes the area name shows at y 44 (`Hud.AREA_TOP_UNDER_ATTEMPT`) and
the touch pause button sits at y 44 (`TouchControls.PAUSE_Y_RANDOM`); `test_random_tickets` checks
it overlaps nothing. The single-line form did not fit at 320x180 (it ran into the area name).

**Payout** (`Progress.random_payout`): attempt 1 = 5 tickets, 2 = 4, 3 = 3, 4 = 2, 5th or later =
1. Kept safeguards: 5 paying wins per UTC day (forward-only rollover; 25 tickets a day at most); a
seed that already paid today pays 0; a typed or replayed seed pays at most 1 (REPLAYED SEED); no
MORE SLIME bought = at most 1 (MORE SLIME = MORE); assisted or dev-toggled runs pay 0; dev mode and
debug runs never save. The result row: ticket icon + `TICKET! ATTEMPT 2 = +4` (+ the cap reason),
or DAILY TICKET LIMIT REACHED / SEED ALREADY PAID TODAY / ASSIST / DEV TOGGLES; MORE SLIME = MORE shows only
when the no-upgrade cap really cut the payout. Removed: the optional ticket pickup (`TicketSpawn`, `TicketPickup`,
FIND IT / FOUND / NONE HERE pod, TICKET FOUND / NO TICKET IN THIS MAZE text) and the old payout
(win 1, pickup +2, under par +1).

Tests: `test_tickets` (table incl. 5th+ = 1, dry-up retry / R restart / replay count, NEW MAZE
resets, daily cap, paid-today, typed seed, zero upgrades, hard mode), `test_random_tickets` (no
chalice node, ticket on the goal cell, autopilot wins by reaching it, story keeps the chalice),
`test_dev_toggles`, `test_mercy` (assisted pays 0), `test_random_usage`, `test_maze_golden`.
Shots: `docs/polish-shots/ticketgoal_goal.png` (ticket + HUD pod), `ticketgoal_bright.png` (F1),
`ticketgoal_result_try1/3/6.png` (+5 / +3 / +1), `ticketgoal_result_noslime.png` (capped).

## 7. Hard-mode rebalance: more slime, bigger mazes, growing slack (2026-10-14, save version 5)

Owner request: +10% slime per hard level (progressive), mazes scaled up so the meter-to-route ratio
holds, plus extra forgiveness on the big late levels. Normal mode and the randomizer (hard included)
are unchanged: their golden lines are byte-identical. Code: `Levels` (`HARD_SLIME_MULT`,
`HARD_ALLOWANCE`, `HARD_BRANCHING`, `HARD_RUN`, `HARD_MAX_CELLS`, `HARD_V4_STEPS`/`HARD_V4_TARGETS`,
`hard_meter_tiles`, `hard_route_cells`, `hard_start_cells`, `build_story_maze`, `v4_hard_par`),
`MazeGenerator.generate_hard_level` (+ `_grow_level`, shared with `generate_level`),
`SpawnPicker.pick_farthest_at`, `game.gd` (`config.meter_tiles`), `Progress` (`SAVE_VERSION` 5,
`_migrate_hard_times`). Tests: `tests/test_hard_rebalance.gd`, `test_phase3` (autopilot walks every
hard level under par), `test_autoplay`, `test_maze_golden`, `test_spawn_picker`, `test_hard_mode`.

**How a hard level is built** (three tables, one entry per level, index 0 = level 1):
1. **Meter** = v4 hard meter x `HARD_SLIME_MULT[n]`. The v4 meter is the old hard maze's route /
   its old target (`HARD_V4_STEPS` / `HARD_V4_TARGETS`, frozen constants). **To change how much more
   slime hard mode gives, edit only `HARD_SLIME_MULT`**: shipped `[1.1, 1.2, ... 2.0]` (+10% per
   level); a flat +10% is `[1.1, 1.1, ... 1.1]`; the old meters are ten `1.0`. Routes, maze sizes,
   pars and the game's meter all follow automatically (then rewrite the 10 hard golden lines with
   `test_maze_golden.gd --write-golden=...` and update the pin in `test_hard_rebalance.gd`).
2. **Route** = meter / `HARD_ALLOWANCE[n]`, rounded down to whole cells (so the real allowance is
   the table's or up to one cell more). So route ~ v4 route x mult (ratio preserved) x
   (v4 usage x allowance)^-1 (the extra slack).
3. **Size**: starts at the normal level's size x sqrt(route / v4 route) per side; grows +1/8 per side
   until the tree's longest route is >= 115% of the route (`HARD_ROOM_PCT`), at most
   `HARD_MAX_CELLS` 36x20 (the randomizer's web cap; at the cap up to 4 re-seeded trees). The start
   is a cell of the level's spawn class whose **farthest cell is exactly the route** (seeded shuffle;
   the chalice is that farthest cell, the end of a branch, like every story level); if the class had
   none it would fall back to a seeded cell exactly `route` away (no level does; tested). Branching
   was retuned per level (very high branching gives short longest routes: L8-L10 at the old
   0.24-0.30 could not hold a 117-149 cell route in 36x20); every level has more dead ends than its
   v4 maze.

| Lvl | size (v4) | route cells (v4) | meter tiles (v4) | allowance table / real | perfect run uses | dead ends (v4) | par s (v4) |
|---|---|---|---|---|---|---|---|
| 1 | 12x7 (10x6) | 27 (25) | 60.8 (55.3) | 1.12 / 1.143 | 87.5% | 13 (8) | 17.0 (15.8) |
| 2 | 15x9 (12x7) | 37 (32) | 84.2 (70.2) | 1.13 / 1.151 | 86.9% | 25 (11) | 23.0 (20.0) |
| 3 | 16x10 (13x8) | 48 (39) | 110.3 (84.8) | 1.14 / 1.158 | 86.3% | 25 (12) | 29.6 (24.2) |
| 4 | 23x12 (15x8) | 64 (48) | 146.4 (104.6) | 1.15 / 1.151 | 86.9% | 48 (25) | 39.2 (29.6) |
| 5 | 21x12 (16x9) | 79 (57) | 184.5 (123.0) | 1.17 / 1.174 | 85.2% | 45 (20) | 48.2 (35.0) |
| 6 | 22x12 (18x10) | 90 (63) | 215.4 (134.6) | 1.19 / 1.202 | 83.2% | 40 (28) | 54.8 (38.6) |
| 7 | 27x14 (20x11) | 104 (71) | 252.7 (148.6) | 1.21 / 1.219 | 82.0% | 51 (34) | 63.2 (43.4) |
| 8 | 30x16 (22x12) | 117 (77) | 287.2 (159.6) | 1.23 / 1.232 | 81.2% | 63 (50) | 71.0 (47.0) |
| 9 | 33x18 (24x13) | 142 (93) | 359.0 (189.0) | 1.26 / 1.268 | 78.9% | 72 (67) | 86.0 (56.6) |
| 10 | 36x20 (26x14) | 149 (96) | 382.4 (191.2) | 1.28 / 1.287 | 77.7% | 116 (68) | 90.2 (58.4) |

Allowance before: 1.12 (L1) .. 1.00 (L10). L1 deliberately stays at today's 1.12 rather than the
owner's "about 1.08" example (that would have made L1 tighter than before, against "early levels
stay near today's feel"); it then rises to 1.28. **Par** = route tiles / 72 px/s x 1.35 + 1 s from
the new routes (`Levels.level_par`); a perfect walk is ~73% of par. Measured: the test autopilot
walks every hard level, no leaps, under par using 75.7-85.6% of the meter (`test_phase3`); the
`--autoplay` bot wins all 10 on its first attempt with GOLD, walking (12.3, 16.7, 21.9, 29.2, 36.1,
40.9, 47.4, 53.3, 65.0, 67.9 s vs par 17-90 s; 14-24% slime left).

**Build time** (headless, Mac): hard builds mean 3.2 ms, worst 8.6 ms (L10 36x20; built once per
session, cached); the randomizer is unchanged (mean ~4.8 ms, p99 13.3-13.6 ms, worst 17.9 ms as in
docs/perf/results-batch-b.md; one rerun showed a single 67 ms outlier while the machine was busy).
The new hard mazes are no bigger than randomizer mazes (36x20 cap), so the fog/tile/camera costs are
already covered by the randomizer's web measurements. Web export verified.

**Save migration (version 5, `Progress._migrate_hard_times`).** Old hard best times were set on the
shorter v4 mazes, so a save older than version 5 has its hard best times
(`records` level 101-110) dropped; `hard_cleared` and the stored hard medal tiers are kept (never
downgraded); normal records/tiers/clears, coins, upgrades, tickets, hats and skins are untouched.
Order: pre-v3 saves still turn their times into tiers first (against `legacy_par`); a v4 save with
hard times but no `[medals]` section gets tiers against the v4 hard par (`Levels.v4_hard_par`),
then the times go. Pure function of the old data (idempotent); the next save is version 5 and its
hard times are kept. Hostile values: non-numeric/INF times are ignored, wrong-typed version = old
(migrated), tiers clamp to 0-3. `--story-complete` sets hard times at 1.15 x the NEW par (silver),
so its state stays valid. A version 5 save opened in an older build keeps working but its hard
medals/times were earned on the new mazes (not handled, like the earlier version notes).

Shots (`tests/demo_overview.tscn -- --unlock-all --level=N --hard --skin=...`):
`docs/polish-shots/hard_before_l1/l5/l10.png` (v4) and `hard_after_l1/l5/l10.png`.

## 8. Trail maps: the MAP TABLE survey (trial, 2026-10-14)

Maps help a player study a story level they have already explored without spoiling what they haven't: the
map only ever shows what the fog has really revealed to them, so the first time through every level is still
discovered in the dark.

**What is recorded** (`Survey`, `scripts/survey.gd`; kept in `Progress.maps`, key = level, + 100 on hard):

| field | meaning |
| --- | --- |
| `w`, `h` | the maze's size in tiles (cells x 2 + 1); a survey of another size is ignored (shown locked) |
| `seen` | bitset, one bit per tile: revealed by the trail, the Brightness light or a wall coming into view, on any recorded attempt (OR-merged) |
| `start`, `moves` | the route: start cell + one 2-bit code per cell stepped (`MazeGenerator.DIRS` order), at most 2,000 |
| `clear`, `best_ms` | the route is the fastest unassisted clear (time in ms); else the last attempt that moved (LAST TRY) |
| `goal` | the chalice came within sight (`CHALICE_REVEAL_DISTANCE`) or was reached on a recorded attempt |

Found coins are not stored again: the map draws `coins_found` (only on seen tiles). The maze itself is rebuilt
from `Levels.story_maze` (cached), so a survey is a few hundred bytes. Packed layout (`Survey.pack`, base64
in `[maps] level_N`): version, flags, w, h, best_ms u32, start x/y, move count u16, the bitset, the moves 4 to
a byte. `Survey.unpack` refuses anything malformed (type, length, characters, version, sizes, count) and
clamps the rest (time <= 1 day, start inside the maze).

**When it is recorded** (`game.gd`): a story run that is the running scene, not in dev mode, records from its
first frame; it commits once, at its win or dry-up (`_finish`) or when it is left mid-way (`_exit_tree`:
restart, pause RESTART, QUIT TO HUB, UPGRADES). Assisted (slime reserve) and dev-toggled (F1 FULL BRIGHT /
F2 NO DRAIN) runs commit nothing; randomizer mazes never record (each seed is a fresh maze, there is nothing
to study twice). Rules: tiles always add up; a clear replaces the route only if it is faster than the stored
clear; without any clear, every attempt that moved replaces the faint last-attempt route.

**Cost:** the reveal loops already visit every newly revealed fog cell; each now also writes one byte
(`survey_tiles[tile] = 1`), and walls one byte the first time each is revealed. Per physics tick: two
`floori`, a parity test and a `Vector2i` compare (a byte appended when a new cell is entered). No per-frame
allocation; fog/trail bytes, their order and the rendered frames are unchanged (pixel diff, see handoff).

**Showing it** (`MapView`, maps v3 2026-10-14): a maze diagram in the level's themed palette (paper, ink,
fog from its tile palette) inside a 4 px frame in the theme's motif (`map_select.THEMED_MAPS = true`, the one
switch back to the plain parchment). Each seen cell is a block of paper floor; thin ink wall lines run between
cells wherever the maze has a wall (`MazeGenerator.is_wall` on the tile between them), with posts where lines
cross, so two corridors side by side (a route's hairpin) always keep a wall line between them. Spoilers: a
cell's floor only when its tile was seen; a wall line (or the floor of an open doorway in it) only when at least
one of the two cells it divides was seen (a wall next to seen floor is known; a doorway shows as a gap leading
into the dark); posts only at a seen cell's corners; unseen cells stay the fog color. The route is a 1 px line
through cell centers in one saturated red (`MapView.ROUTE`) whatever skin the slime wears (the skin is no
input to the maps at all); the last attempt is dashed (2 on, 2 off) and faded 30% toward the paper. Floors are
always an odd number of px (`SIZES`, [floor, wall] = 21+3 for level 1 down to 5+2 / 5+1 for 36x20 cells,
picked to fit 316x149 px with the frame), so the line runs exactly down the middle with floor either side.
Coins as gold discs, the start as a ring and the goal as an X in the ink, each only on seen cells. The view
shows only the name, the map and "NN% UNCOVERED".

**Select tiles** (`MapView.preview`): never the real map. Each tile shows a tiny made-up example maze
(`EXAMPLE_CELLS` 8x4 at 3+1 px with a 1 px frame in the theme's motif, 35x19 px), generated per level (hard
mode has its own) by a growing-tree maze from pure integer hashing of the level number, so it is the same for
every player and knows nothing of the real layout. It only shows what the player has: locked = dim sealed
frame round darkness plus a lock; otherwise floor(% x 32) of its cells lit (spreading breadth first from its
start, so progress is visible at a glance), the rest dark; its start-to-goal example route in red only when
the level has a recorded route (faint red for a last try, over lit cells only); a gold frame at 100%. Built
once per state and cached as textures; the screen has no per-frame work. Two different surveys at the same %
give identical tiles (`tests/test_maps.gd`).

**Save size** (measured in `tests/test_maps.gd`): save code 543 chars with no maps, 2,543 with all 20 levels
fully surveyed (full surveys compress to almost nothing), 19,447 in a worst case no player reaches (random
bits and 2,000-move routes everywhere); cap 65,536.
