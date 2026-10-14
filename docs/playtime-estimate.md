# Playtime estimate (story campaign, normal + hard)

How long a **first-time human** takes to beat Slime Time as it is now (2026-10-14, save layout v4),
excluding the randomizer and hats. Grounded in the game's own data (measured headless from
`Levels` / `MazeGenerator` / `Upgrades`) plus a transparent behaviour model run as a Monte Carlo
over the real story mazes. **No playtest data yet** — treat these as priors to check against one.

## Headline

| Goal | Fast player | Median player | Slow player | Headline range |
|---|---|---|---|---|
| (a) Clear all 10 levels on normal | 30-34 min | **~45 min** (44-49) | 67-74 min | **30-75 min** |
| (b) Normal + all 165 coins | ~50 min | **~67 min** (66-68) | 97-100 min | **50-100 min** |
| (c) Normal + all 10 hard levels | 74-80 min | **~2 h** (116-125 min) | 4.7-5.2 h* | **1.25-5+ h** |
| (d) Everything: normal, hard, 165 coins, 30/30 normal golds | 94-98 min | **~2.4 h** (141-148 min) | 5.2-5.7 h* | **1.5-6 h** |

Fast / median / slow = p25 / median / p75 of 300 simulated runs of each profile (columns are the
profile's own p25-p75). *About 20% of slow players hit the 80-attempt cap on **hard level 10** (a
real player would likely quit or need many sessions), so the slow hard numbers are a floor.

**Three key assumptions** (each moves the result most):
1. **Retries learn the maze.** Story mazes are fixed, so a retry walks the remembered part (at
   1.02-1.35x the shortest distance, improving with each attempt) and carries on exploring where
   the last attempt ended. The map itself is dark again on every attempt; the memory is the player's.
2. **Time per attempt ≈ the meter** (attempts end by drying up), stretched by pauses: exploring
   unknown corridors takes 1.15-1.7x the perfect glide time, known corridors 1.05-1.3x (standing
   still doesn't drain). Plus 2.8 s of game delay + 1-4 s reaction per dry-up.
3. **Hard mode is an execution test.** Allowance 1.00-1.12 means the winning run must be nearly the
   exact route; it becomes feasible only through learning plus **leaps** on known straights (half
   price per tile). Hard mode has no upgrades and no coins; its dominant cost is hard 8-10.

## 1. Measured level data

Tiles are 16 px; one maze cell step = 2 tiles; route tiles = 2 x route cells - 13/16 (grab reach).
Base glide 72 px/s = 4.5 tiles/s. Meter = route / target (`Game`: `slime_cost_per_tile = target x
100 / path_tiles`), so **allowance = meter / route = 1 / target**, wherever the start is.

| Mode | Lv | Cells | Dead ends | Route tiles | Target | Meter tiles | Meter s | Allowance | Allow. w/ leaps* | Perfect s | Par s | Whole maze / meter | Coins | Coin tour / meter; runs at SLIME 0,5,10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| normal | 1 | 10x6 | 10 | 45.2 | 0.45 | 100.4 | 22.3 | 2.22 | 2.94 | 10.0 | 14.6 | 2.35 | 6 | 1.55 / 2,2,1 |
| normal | 2 | 12x7 | 12 | 59.2 | 0.52 | 113.8 | 25.3 | 1.92 | 2.98 | 13.2 | 18.8 | 2.92 | 9 | 2.07 / 3,2,2 |
| normal | 3 | 13x8 | 15 | 79.2 | 0.58 | 136.5 | 30.3 | 1.72 | 2.43 | 17.6 | 24.8 | 3.02 | 7 | 1.30 / 2,1,1 |
| normal | 4 | 15x8 | 21 | 89.2 | 0.64 | 139.4 | 31.0 | 1.56 | 2.21 | 19.8 | 27.8 | 3.42 | 12 | 2.31 / 3,2,2 |
| normal | 5 | 16x9 | 21 | 111.2 | 0.70 | 158.8 | 35.3 | 1.43 | 1.91 | 24.7 | 34.4 | 3.60 | 14 | 2.56 / 4,2,2 |
| normal | 6 | 18x10 | 31 | 125.2 | 0.76 | 164.7 | 36.6 | 1.32 | 1.75 | 27.8 | 38.6 | 4.35 | 17 | 2.73 / 4,3,2 |
| normal | 7 | 20x11 | 33 | 135.2 | 0.82 | 164.9 | 36.6 | 1.22 | 1.81 | 30.0 | 41.6 | 5.31 | 20 | 3.66 / 5,3,3 |
| normal | 8 | 22x12 | 37 | 159.2 | 0.88 | 180.9 | 40.2 | 1.14 | 1.48 | 35.4 | 48.8 | 5.82 | 22 | 3.85 / 10,4,3 |
| normal | 9 | 24x13 | 43 | 181.2 | 0.94 | 192.8 | 42.8 | 1.06 | 1.41 | 40.3 | 55.4 | 6.45 | 27 | 4.12 / 11,5,3 |
| normal | 10 | 26x14 | 41 | 189.2 | 0.99 | 191.1 | 42.5 | 1.01 | 1.33 | 42.0 | 57.8 | 7.60 | 31 | 5.42 / 8,5,3 |
| hard | 1 | 10x6 | 8 | 49.2 | 0.89 | 55.3 | 12.3 | 1.12 | 1.62 | 10.9 | 15.8 | 4.27 | - | - |
| hard | 2 | 12x7 | 11 | 63.2 | 0.90 | 70.2 | 15.6 | 1.11 | 1.59 | 14.0 | 20.0 | 4.73 | - | - |
| hard | 3 | 13x8 | 12 | 77.2 | 0.91 | 84.8 | 18.8 | 1.10 | 1.63 | 17.2 | 24.2 | 4.86 | - | - |
| hard | 4 | 15x8 | 25 | 95.2 | 0.91 | 104.6 | 23.2 | 1.10 | 1.53 | 21.2 | 29.6 | 4.55 | - | - |
| hard | 5 | 16x9 | 20 | 113.2 | 0.92 | 123.0 | 27.3 | 1.09 | 1.50 | 25.2 | 35.0 | 4.65 | - | - |
| hard | 6 | 18x10 | 28 | 125.2 | 0.93 | 134.6 | 29.9 | 1.08 | 1.44 | 27.8 | 38.6 | 5.32 | - | - |
| hard | 7 | 20x11 | 34 | 141.2 | 0.95 | 148.6 | 33.0 | 1.05 | 1.47 | 31.4 | 43.4 | 5.89 | - | - |
| hard | 8 | 22x12 | 50 | 153.2 | 0.96 | 159.6 | 35.5 | 1.04 | 1.47 | 34.0 | 47.0 | 6.59 | - | - |
| hard | 9 | 24x13 | 67 | 185.2 | 0.98 | 189.0 | 42.0 | 1.02 | 1.38 | 41.2 | 56.6 | 6.58 | - | - |
| hard | 10 | 26x14 | 68 | 191.2 | 1.00 | 191.2 | 42.5 | 1.00 | 1.33 | 42.5 | 58.4 | 7.59 | - | - |

\* "Allow. w/ leaps": the allowance if every straight run of the route (minus 1 tile before each
corner) is leapt at half price (`JUMP_COST_FACTOR` 0.5, no splat) — the theoretical ceiling.
Straights are 46-71% of the routes. "Whole maze / meter": tiles to walk every corridor of the maze
(each edge twice) per meter — 2-8 meters, so nobody explores a whole level in one attempt.
"Coin tour": a greedy nearest-neighbour tour start -> every coin (dead-end cells) in one run, per
meter. "Runs": coins are **kept the moment they're touched, even on a dry-up**, so a greedy
multi-run plan (each run chains nearest coins until the meter is out) needs this many runs with
MORE SLIME 0 / 5 / 10. Every coin is reachable from the start on one meter at SLIME 0.

Other facts that matter:
- **Par** = route tiles at 72 px/s x 1.35 + 1 s; gold <= par, silver <= 1.3 x par, bronze any
  unassisted clear. A perfect glide is 74% of par; a median replay of a known route is ~1.2x the
  perfect time, so gold is mostly a "replay it cleanly once" task (SPEED upgrades make it easier,
  par ignores them).
- **Economy:** 165 coins (6, 9, 7, 12, 14, 17, 20, 22, 27, 31 per level) = exactly the full upgrade
  tree (3 upgrades x 55; level n costs n coins, refundable). MORE SLIME +10% meter / level
  (x2 at 10, which costs 55); SPEED +5% / level (x1.5); BRIGHTNESS +2.5 px light reach / level.
  The first 15 coins buy MORE SLIME 5 (x1.5). Level 10 normal (allowance 1.01) is essentially
  unwinnable without upgrades or leaps; with MORE SLIME 10 it's 2.02.
- **Hard mode** (open from the level select once levels are unlocked): different mazes, same sizes,
  no loops, allowance 1.00-1.12, **no upgrades, no coins, no slime reserve (assist)**, and explored
  areas fog over again after ~9 s. Its medals are separate and don't count toward 30/30.
- **Retry overhead:** `END_DELAY` 2.0 s + `DRY_CHOICE_DELAY` 0.25 s + the goo wipe (0.22 + 0.32 s),
  then a button press. Normal mode offers the +10% slime reserve after 3 dry-ups on a level
  (no medal/record).

## 2. The behaviour model

A Monte Carlo over the exported story mazes (graph of open cells). Per attempt the simulated
player starts with a full meter and:
- walks **known** cells to the nearest unexplored opening (a retry first heads to where the last
  attempt ended: depth-first, like a person continuing "where I was"), paying `e` x the distance,
  reduced by leaps on known straights (`1 - 0.5 x straight share x leap use`);
- **explores** unknown cells one step at a time (1.0x), picking at random among near-equal
  openings; it sees the chalice only on arrival (it reveals at 24 px), coins are collected on
  touch;
- ends at the chalice (win) or when the meter is empty (dry-up). Knowledge of the maze's cells
  carries over to the next attempt; dead ends found are never re-entered (perfect topological
  memory — optimistic; `e` absorbs some of that).
- `e` starts at e0 and falls towards e_min with each attempt (x `learn` per attempt), with
  per-attempt noise; leap use grows from 0 to the profile's max (`1 - 0.7^attempts`). Hard mode adds
  +0.06 to `e` (fog returns, so backtracking in the dark is messier).
- Coins found are spent before each level, MORE SLIME first (share of coins: 100 / 80 / 60%).
- (b) hunts the missing coins right after each clear (same knowledge; the chalice is avoided;
  runs end on dry-ups, coins persist). (d) adds gold replays of each normal level not already gold
  (known route, SPEED 10 bought with all coins by then).
- Time: explore tiles x h_exp + known tiles x h_known at 4.5 tiles/s, + per dry-up 2.8 s + react,
  + per level UI (banner, win screen, level select, shopping), + one-off story/tutorial/hub time
  (1.5 / 4 / 8 min) and 0.3-2 min to find and switch on hard mode. Attempt cap 80 per level.

| Profile | e0 -> e_min (sd) | learn | Leap use | h_exp / h_known | React s | UI s/level | Takes the reserve after |
|---|---|---|---|---|---|---|---|
| fast | 1.10 -> 1.02 (0.03) | 0.75 | 60% | 1.15 / 1.05 | 1 | 20 | never |
| median | 1.20 -> 1.04 (0.05) | 0.85 | 35% | 1.35 / 1.15 | 2 | 45 | 6 dry-ups |
| slow | 1.35 -> 1.07 (0.07) | 0.90 | 10% | 1.7 / 1.3 | 4 | 90 | 3 dry-ups |

### Per-level results (median profile; attempts p25/median/p75, minutes median)

| Lv | Normal attempts | Normal min | MORE SLIME lv at start | Coins found on the way | + coin hunt runs | Normal+hunt min | Hard attempts | Hard min |
|---|---|---|---|---|---|---|---|---|
| 1 | 2/2/3 | 1.6 | 0 | 3 of 6 | 2 | 2.4 | 4/5/6 | 2.3 |
| 2 | 2/3/3 | 2.2 | 1 | 5 of 9 | 2 | 3.1 | 5/6/7 | 3.0 |
| 3 | 2/2/3 | 2.3 | 3 | 4 of 7 | 1 | 3.5 | 7/7/8 | 3.9 |
| 4 | 2/3/3 | 3.0 | 3 | 6 of 12 | 2 | 4.4 | 7/8/8 | 5.0 |
| 5 | 2/3/3 | 3.5 | 4 | 7 of 14 | 2 | 5.1 | 5/6/7 | 4.5 |
| 6 | 3/3/4 | 4.1 | 5 | 9 of 17 | 2 | 6.1 | 8/10/10 | 7.3 |
| 7 | 3/3/4 | 4.4 | 6 | 11 of 20 | 2 | 7.2 | 8/9/10 | 7.4 |
| 8 | 3/4/5 | 6.3 | 7 | 12 of 22 | 2 | 9.6 | 11/13/16 | 10.8 |
| 9 | 3/4/6 | 7.7 | 9 | 17 of 27 | 3 | 11.3 | 11/12/13 | 11.6 |
| 10 | 3/4/5 | 7.2 | 10 | 20 of 31 | 2 | 10.5 | 16/18/21 | 17.1 |

Fast profile: normal 2-4 attempts per level, hard 4-10 (hard 10: ~8.5 min). Slow profile: normal
2-5 (taking the reserve on 60-80% of levels 6-10), hard 13-58 attempts per level, hard 8-10 alone
~2 h, and ~19% never clear hard 10 within 80 attempts.

What drives it:
- **Normal mode is gentle**: incidental coins buy MORE SLIME fast enough (median SLIME 5 by level 6,
  10 by level 10) that late allowances (1.0-1.14 base) become ~1.8-2.0, so attempts stay at 3-5.
  Without upgrades levels 8-10 would be hard-mode-like. A player who ignores the upgrades shop is the
  main way normal mode gets much longer than the table.
- **Coins add ~20 min** (median): about half the coins are picked up on the way; the rest need
  1-3 dedicated runs per level because they persist through dry-ups.
- **Hard mode roughly doubles to triples the total.** Allowance ~1.0-1.1 with no upgrades means
  every hard level needs the route learnt and then executed nearly perfectly, with leaps; attempts
  grow with maze size (median 5 -> 18). Hard 10 (allowance exactly 1.00 — winnable only by leaping
  some straights or cutting corners) is the single biggest time sink and the main quit risk.
- **Gold medals add little** (~5 min median): a clean replay of a known route usually beats par.

## 3. Biggest uncertainties

1. **Maze memory between attempts.** The model remembers every dead end perfectly. Real players
   (map black again on every retry, no minimap) will re-enter branches; that raises attempts on the
   large levels, most on hard 8-10. Could add 25-50% to hard time.
2. **Leap mastery on hard.** Hard 9-10 depend on leaping known straights without splatting (a splat
   costs 2-5% of the meter). Whether median players discover and trust this is unknown; if not,
   hard 10 is nearly impossible (allowance 1.00) and many will quit.
3. **Upgrade shopping.** The model buys MORE SLIME with every coin. Players who don't visit the
   cauldron (or buy SPEED/BRIGHTNESS first) face levels 8-10 at allowance ~1.0-1.15.
4. **Exploration style.** Random choice at junctions vs. a "head away from the start" heuristic (the
   chalice is always on the cell farthest from the start), wall-following, or using glimmers.
5. **Idle time** (pauses, reading the HUD, looking at the hub, breaks) — the h factors are guesses.
6. **Hard-mode motivation**: how many players attempt hard at all, and after how many hard-10
   failures they stop. The slow-profile figures are a floor because of the attempt cap.

## 4. What a playtest should measure

Log per level and mode (the dev attempts log in `scripts/dev_log.gd` covers part of this):
- attempts to first clear, time per attempt, and the share ending in a dry-up vs a quit/restart;
- tiles travelled per attempt vs the meter, and revisits of already-explored dead ends (memory);
- leaps used per attempt, splats, and leap share of the winning run (especially hard 8-10);
- coins at first clear, coin-hunt runs afterwards, when/what upgrades are bought;
- reserve (ASSIST) offers taken; first-clear medal tier and replays to gold;
- wall-clock time in menus/hub/story screens; total session lengths and where players stop.
Two or three first-time players through normal + hard would replace most of the guesses above.

## How this was computed

Headless scripts kept outside the repo (scratch, not shipped): a GDScript that prints the table in
section 1 from `Levels.get_config`, `Levels.story_maze`, `Levels.story_coin_cells`,
`Levels.level_par` and `MazeGenerator` (BFS distances, dead ends, shortest path), a second one that
exports all 20 story mazes as graphs (JSON), and a Python Monte Carlo (300 runs per profile per
scenario, fixed seed) implementing section 2. Re-measure after any change to `Levels.DATA`,
`HARD_*`, `COINS`, `Upgrades` or the par formula.
