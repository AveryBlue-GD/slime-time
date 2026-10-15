# Upgrades v2: core tree rework, ticket economy, Descent runs, hard-mode Heat (design spec)

Status: **IMPLEMENTED (all four batches, 2026-10-15); core tree REPRICED (tree 3, owner request 2026-10-15): MORE SLIME is the premium track at 80 of the 165 coins (1, 4, 7, 9, 12, 20, 27), SPEED 46 (6, 9, 13, 18), BRIGHTNESS 39 (9, 12, 18); see A2.1, A2.3 "Tree 3" and A2.4; the ticket WORKSHOP (B.2) is DISABLED for now behind `Economy.WORKSHOP_ENABLED := false` (owner request, 2026-10-15): no TICKETS tab, no effects, no WIND tag, no '!', saved levels kept; flip the const to bring it all back**; **ABILITIES v1 (three ticket abilities on the TICKETS tab, 2026-10-15): see "Abilities v1" below**; this file is now the design record. Deviations from the spec are listed in the next section (the long status note below has the batch-by-batch detail). Original status: design spec, 2026-10-14 (game-advisor). **Batch 1 (core tree rework, A2) is built (2026-10-15); batch 2 (hats
live, store, workshop, cosmetics v1: B.2, C.1-C.3) is built (2026-10-15); batch 3 (Descent, C2) is built (2026-10-15)**;
**batch 4 (Heat, C3) is built (2026-10-15)**: all four batches are done. Batch 4 decisions where this spec was
open or didn't fit (details: [../handoff.md](../handoff.md), "Upgrades v2, batch 4", and
[../level-design.md](../level-design.md) section 10): DIM's base relight is the code's 20 px (as the spec says) and it
also shrinks the lantern glow x0.6; FOG BITES halves the last fade step (so with DIM 5.4 -> 2.7 s); BRITTLE's "bounce
slide no longer free" = the knockback slide drains; GROUNDED switched on drops BRITTLE (BRITTLE is greyed out, not
selectable, while GROUNDED is on); RACE's countdown replaces the run timer (hourglass) and running out is a dry-up
(OUT OF TIME!); the HEAT button sits bottom right mirroring BACK (not beside the checkbox: no room) and opens a modal
panel; heat applies only to hard STORY levels with a plain hard clear (heat on an uncleared level = 0); claimed
bounties are derived from the best heat (no separate bitmask; `[heat] paid` for stats); heat runs share the hard
records/medals (no separate heat records); dev-toggled runs earn no bounty or best heat (dev mode pays unsaved); the
HUD shows a HEAT n pod with the modifier icons under the level name instead of `HARD  HEAT 6` in the level text; the
title crown is 5 white-hot flames over the logo; save keys as D.1 plus `[heat] paid`; the autoplay bot stays at heat
0 (no `--autoplay-heat`); the gate "hard autoplay at heat 10 on L1-3" is met by the test autopilot at heat 10 on all
10 levels (test_heat) and the 480-run sweep (bench_heat). Batch 3 decisions where this spec was open or didn't fit (details: [../handoff.md](../handoff.md),
"Upgrades v2, batch 3", and [../level-design.md](../level-design.md) section 9): the portal buttons read RANDOM MAZE /
DESCENT; floors use the randomizer's size (from the slime capacity; the owner's no-small-mazes rule) instead of
`1.25 x route + 12` / 14x8; u jitter is clamped to 0.25-0.85; the refill is that of the floor being entered; capacity
boons stack additively and keep the slime left in tiles; BIG GULP is added on DESCEND (with the refill, cap 100%);
BACKUP BLADDER adds a fixed 25% after SECOND WIND; BLAZE past BRIGHTNESS 3 = reach 33 (42 px); GLASS x1.5 applies
after halving, cap 30; a run that banks 0 uses no paying slot; dev mode pays unsaved (dev-toggled runs 0, carried
across floors); milestones pay on reaching the floor, outside the daily cap; best floor = floor reached; QUIT TO HUB on
the boon card = CASH OUT; pick = a tile then DESCEND; Descent ignores the HARD MODE setting. Batch 2
decisions where this spec was open or didn't fit (details: [../handoff.md](../handoff.md), "Upgrades v2, batch 2"): the
SHOP has three sections (HATS / TRAILS / PAPERS) instead of one grid; the workshop rows are 25 px apart from y 24; the
SECOND WIND HUD sign is a WIND tag under the meter; a TAILOR buy of a non-rainbow hat leaves the rainbow pity alone; dev
mode buys free and owns every cosmetic; GOLD trail alpha 185; the "!" shows per station (wheel / cauldron); MAGNET's
"revealed" = the coin's fog cell was ever revealed; the map select tiles ignore the paper. Batch 1 decisions where this spec was open: the tables live in
`scripts/economy.gd` (`Economy.COIN_TRACKS`), not in `Upgrades.LIST`; the upgrades screen shows "now -> next" (e.g.
`SLIME X1.45 -> X1.60`, `LIGHT 9 -> 17 PX  +257% AREA`) instead of "NEXT: ..."; old dev wall power maps by equal damage
(p -> floor(p / 2.5)); the notice reads UPGRADES REWORKED / COINS RETURNED +N and waits in the save
(`[upgrades] refund_notice`) until the hub shows it; seed codes accept L 0-10 and clamp 8-10 to 7, 11+ is not a code;
`--upgrades=` takes new-tree levels. The RECOMMENDED tag and the 1 s light-ring preview on buy were built in the review-fix pass (docs/archive/review-upgrades-b1.md status).
Measured story check: see [../playtime-estimate.md](../playtime-estimate.md) (upgrades v2 note) and
[../handoff.md](../handoff.md) (last section). Code is the source of truth for the
current numbers quoted (`scripts/upgrades.gd`, `scripts/progress.gd`, `scripts/game.gd`, `scripts/slime.gd`,
`scripts/levels.gd`, `scripts/hats.gd`); the difficulty priors come from [../playtime-estimate.md](../playtime-estimate.md)
and [../level-design.md](../level-design.md) sections 5-7. Background research: [../advisor/roguelike-progression.md](../archive/advisor/roguelike-progression.md),
[../advisor/maps.md](../advisor/maps.md), [../advisor/juice-audio-ui.md](../archive/advisor/juice-audio-ui.md).

## Abilities v1 (owner request 2026-10-15; built)

Three active ABILITIES bought with tickets in the cauldron's TICKETS tab (separate from COINS), switch
`Economy.ABILITIES_ENABLED := true` (test hook `abilities_force`); the old WORKSHOP stays off behind
`WORKSHOP_ENABLED := false` (with its hook on it returns on a third tab, TOOLS). Every number is in
`scripts/economy.gd` (`ABILITIES`, `RIFLE_*`, `SPLAT_*`, `KAZE_*`); rules `scripts/abilities.gd`, in-level effects
`scripts/ability_runner.gd`; tests `tests/test_abilities.gd`; shots `docs/polish-shots/abilities_*.png`.

| Ability (tag) | Effect | Slime per use | Price L1 / L2 / L3 | Charges L1 / L2 / L3 |
|---|---|---|---|---|
| SLIME RIFLE (SHOOTS GOO) | a goo shot (480 px/s) flies straight THROUGH walls for 8 / 11 / 14 tiles by level (stopping early at the maze's outer edge), revealing its own tile and every tile on its line: floor tiles (all fog cells, lit now) with the walls bordering them, and the walls it crosses; a thin goo streak on the floor tiles only | 2% (refused unless the meter holds more) | 15 / 30 / 50 | 1 / 1 / 1 |
| SLIME SPLAT (BOMB 3X3) | a goo bomb lobbed (0.4 s) OVER walls exactly 4 / 5 / 6 tiles ahead by level (clamped inside the maze; landing in a wall tile is fine), bursts: exactly the 3x3 tiles around it revealed and lit (clipped to the maze), a 1.5 s glow | 4% (refused unless the meter holds more) | 18 / 35 / 55 | 1 / 1 / 1 |
| SLIMAKAZE (WALL DASH) | the slime dashes (640 px/s, goo smear, no drain in flight; from off its lane it first slides sideways onto the lane, then goes straight) to the last floor tile before the first wall, splats (stun 0.6 s, shake 6 px / 0.5 s), then goo drops spray onto a random set of floor tiles (seeded by the maze, the impact tile and the use index this attempt: one rule in every mode, never the attempt, so a restart can't re-roll it) within 6 / 7 / 8 tiles by level, walls in between ignored, so it lands in the neighbouring corridors (chance 90% at the impact falling to 40% at the edge; the impact tile always); each is revealed with its bordering walls; the dash itself still stops at the first wall | 30%, taken on impact; always fires, so with <= 30% left the impact dries the slime up (SECOND WIND / BACKUP BLADDER still apply); a dash that reaches the chalice / ticket stops there and pays the 30% before the win: emptied, it is a dry-up, not a win (a SECOND WIND / BACKUP BLADDER that fires there lands its refill at once and it wins), and Descent carries the meter after the cost; refused (nothing spent) with a wall right ahead | 25 / 45 / 70 | 1 / 1 / 1 |

**Buff (owner, 2026-10-15: "far too weak"):** abilities now INTENTIONALLY reveal past walls - the rifle pierces them,
the bomb is lobbed over them, the SLIMAKAZE splatter reaches the corridors beyond (only the physical dash stops at a
wall). Per-level numbers: `Economy.RIFLE_RANGE` [8, 11, 14], `SPLAT_RANGE` [4, 5, 6], `KAZE_RADIUS` [6, 7, 8],
`KAZE_CHANCE_NEAR / FAR` 0.9 / 0.4 (was 5.5 tiles, 0.75 / 0.25, with the rifle and bomb stopped by walls). Nothing is
revealed outside the maze; a reveal over the goal's tile only shows the chalice / ticket (and marks it on the trail
map), never takes it. Balance: prices and costs are unchanged (charges: see Decisions, always 1); abilities stay optional ticket purchases, and
par, routes, u, seed codes and the randomizer payout are untouched (tested), so a buffed reveal can make a run faster
(records / medals, like SPEED) but never pays more. Shots: `docs/polish-shots/abilities2_before.png` and
`abilities2_rifle / _splat / _kaze.png` (all at level 3, level 4 start).

Decisions:
- **Keys:** remappable actions `ability_rifle` / `ability_splat` / `ability_kaze`, defaults **1 / 2 / 3** (no clash with
  WASD / arrows / Space / R / F / P / Esc / F11 / F1-F2), made at startup by Progress like `interact`; the CONTROLS page
  is two columns (10 rows). An older save whose keys already use 1-3 keeps its bindings; the abilities take the first
  free spare (`ABILITY_SPARE_KEYS`). Touch: a round button per owned ability in a cluster left of JUMP's zone, each ability on its own spot (SLIME RIFLE nearest, SLIMAKAZE farthest), firing on RELEASE only if the finger is still on it (slide off = cancel); with buttons shown JUMP catches x >= 228 (full height, letterbox included) and an 8 px dead band separates that zone from every button hit disc (`TouchControls.JUMP_ZONE_X` / `DEAD_RING`) (icon, lit when ready, dimmed once used).
- **Aim:** the slime's facing (last movement direction) snapped to the grid, larger axis wins, x on an exact diagonal.
  Usable only while gliding or standing (not charging, airborne, stunned, dashing; not after the run ends).
- **Charges** = exactly 1 per attempt at every level (owner, 2026-10-15: "a little too powerful"); the level tiers only make the ability STRONGER (range / radius, same numbers as before). A second press does nothing and costs nothing. Refilled by every restart, NEW MAZE, next level and Descent floor.
- **Prices:** first ability (RIFLE 15) ~ one day's paid randomizer wins (~16 in ~18 min, A.2); all three maxed 343.
- **Modes (owner, 2026-10-15: "randomizer and Descent only"):** ON only in randomizer mazes and Descent (per floor; no boon changes them; GLASS / RUBBER don't touch the
  SLIMAKAZE cost); OFF in every story level (normal, hard, HEAT: no HUD strip, no touch buttons, keys 1/2/3 do nothing, no tutorial hint) and in the hard-mode randomizer (hard mode plays without upgrades, as before). One rule: `Abilities.allowed_in(game)`. The TICKETS hint reads KEYS 1 2 3 - RANDOM MAZES + DESCENT. Assisted / dev rules unchanged (dev
  mode buys free; F2 NO DRAIN also skips ability costs). The autoplay bot never uses them.
- **Fairness:** par stays base-speed based and abilities don't move it, the route, u, seed codes or the randomizer payout
  (a win pays as before); medals and records can be earned with them (they are a paid utility, like SPEED). Their reveals
  are real reveals: fog bytes and survey tiles, so they count as seen on trail maps; one that lights the goal's tile shows the
  chalice / ticket (as seeing it does) and marks it on the trail map (`survey_goal`).
- **UI:** the TICKETS tab shows each ability's icon (code-drawn 8x8, BoonIcons palette), name, 2-3 word tag, 3 level pips,
  + and the price with the ticket icon; + opens a BUY <NAME> <N>? confirm (not refundable); locked until the first
  ticket; the hint names the keys. The HUD shows a pod under the meter with each owned ability's icon and its uses as
  pips. The COINS tab lost its effect lines (owner: "don't give explanations"): one line per track (name, bar, - / +,
  cost / MAX), RECOMMENDED under MORE SLIME's name until maxed; the BRIGHTNESS buy picture has no text.
- **Saves:** `[abilities] rifle/splat/kaze` (0-3, clamped, written only when > 0), the three keys under `[controls]`;
  RESET PROGRESS clears the levels (keys are preferences). No SAVE_VERSION bump (all optional with defaults).
- **Sounds:** `goo_shot`, `goo_lob`, `goo_burst`, `kaze` (tools/make_sounds.py; existing WAVs unchanged).

## Implemented: deviations from this spec

Everything below was built as specified except these (collected from the status note above and the per-batch sections of
[../handoff.md](../handoff.md); code and `scripts/economy.gd` are the source of truth for numbers):

- **Tree 3 repricing (after batch 4):** the A2.1 prices were changed to MORE SLIME 80 / SPEED 46 / BRIGHTNESS 39 (same lengths, effects and 165 total); tree 2 saves are repriced on load (A2.4); coin counters clamp at 0 on screen; `--upgrades=` without enough coins pads debug coins and `--coins=` works in any flag order.
- **Batch 1 (coin tree):** tables live in `Economy.COIN_TRACKS`, not `Upgrades.LIST`; the screen shows "now -> next" instead of "NEXT: ..."; old dev wall power p maps to floor(p / 2.5); the refund notice waits in the save until the hub shows it; typed seed levels 8-10 clamp to 7. The RECOMMENDED tag and 1 s light-ring preview were deferred, then built in the review-fix pass.
- **Batch 2 (store, workshop, cosmetics):** the SHOP has three sections (HATS / TRAILS / PAPERS) instead of one grid; workshop rows 25 px apart from y 24; SECOND WIND's HUD sign is a WIND tag under the meter; a TAILOR buy of a non-rainbow hat leaves the rainbow pity alone; dev mode buys free and owns every cosmetic; GOLD trail alpha 185; the "!" shows per station; MAGNET needs the coin's fog cell to have been revealed; map select tiles ignore the paper. Not built: the cauldron preview ring, hat dyes / wallpapers.
- **Batch 3 (Descent):** portal buttons read RANDOM MAZE / DESCENT (spec: QUICK MAZE); floors use the randomizer's size (from slime capacity) instead of route-sized floors; u jitter clamped 0.25-0.85; refill is that of the floor being entered; capacity boons stack additively; BIG GULP is added on DESCEND (cap 100%); BACKUP BLADDER adds a fixed 25% after SECOND WIND; BLAZE past BRIGHTNESS 3 = reach 33; GLASS x1.5 applies after halving (cap 30); a run that banks 0 uses no paying slot; milestones pay on reaching the floor, outside the daily cap; QUIT TO HUB on the boon card = CASH OUT; Descent ignores the HARD MODE setting; autoplay bot not extended.
- **Batch 4 (Heat):** DIM's relight is the code's 20 px and also shrinks the lantern x0.6; FOG BITES halves the last fade step; BRITTLE's slide drains; GROUNDED drops BRITTLE (greyed out while on); RACE replaces the run timer (hourglass) and running out is a dry-up (OUT OF TIME!, also for a leap still airborne at 0:00); THIRSTY also scales splats (review fix); HEAT button bottom right opens a modal panel; heat applies only to hard STORY levels with a plain hard clear; claimed bounties are derived from the best heat (plus `[heat] paid` for stats); no separate heat records; dev-toggled runs earn nothing; the HUD shows a HEAT n pod; the title crown is 5 white-hot flames; no `--autoplay-heat`.

Owner decisions this spec implements:
1. New upgrade types beyond Slime / Speed / Brightness.
2. Tickets matter (they buy real things, not only hat spins).
3. Hats unlocked for real players now (11 hats, wheel 12, 14, ... first spin free, rainbow pity).
4. Descent runs (roguelite chain of randomizer floors with boons).
5. Hard-mode Heat modifiers.
6. Balance rule for every upgrade: few BIG breakpoints, no 10-level tracks; minor tracks 3-4 levels, major 6-7.
   Brightness must become clearly visible per step.

Numbers marked *est.* are model estimates (no playtest data exists yet); everything else is measured from the code.

---

## 0. The recommendation in one table

| Layer | Currency | Contents | Where |
|---|---|---|---|
| Core tree (power) | **Coins** (finite, 165) | MORE SLIME 7 levels, SPEED 4, BRIGHTNESS 3 (re-costed so 165 still buys all) | Cauldron, COINS tab |
| Workshop (utility) | **Tickets** (renewable) | SECOND WIND, QUICK CHARGE, STICKY, MAGNET, GOO NOSE (3 levels each) | Cauldron, TICKETS tab |
| Hats | Tickets | Wheel (unchanged prices, 210 for all 11) + direct buy at a premium | Prize wheel, WHEEL tab |
| Cosmetics | Tickets | 5 trail styles, 3 map papers | Prize wheel, SHOP tab |
| Descent runs | pays tickets (own daily cap) | floors, 1-of-3 boons, cash-out pot | Randomizer portal, mode choice |
| Heat | pays tickets once per tier + badges | 6 hard-mode modifiers, heat 0-10 | Level select, HARD panel |

Hard mode still has **no upgrades** of either kind (it is the pure skill track; Heat is how it gets harder and pays).

---

## A. Economy structure

### A.1 What exists today (measured)

- **Coins:** 6, 9, 7, 12, 14, 17, 20, 22, 27, 31 per level = **165**; the tree is 3 x 10 levels, level n costs n,
  55 per track, 165 total; refundable; invariant "all coins = full tree".
- **Tickets:** only from randomizer wins: 5 / 4 / 3 / 2 / 1 by attempt; **5 paying wins per UTC day (25 max)**;
  a seed already paid today 0; typed/replayed seed max 1; no MORE SLIME bought max 1; assist/dev 0.
- **Hat wheel:** won hats leave the wheel, so **there are never duplicates**: 11 spins collect all 11 hats whatever
  the luck. Prices: spin 1 free, then 12 + 2 per spin taken after the second: 12, 14, ..., 30 for spin 11.
  **All 11 hats = 0 + (12 + 14 + ... + 30) = 210 tickets.** The 40 cap is never reached with 11 hats, and the
  rainbow pity only changes the *order* hats arrive in, not the total cost.

### A.2 Ticket income model (*est.*)

Randomizer time per attempt after the story (MORE SLIME max = 272-tile meter, SPEED ~2 = x1.25): a full meter is
272 / 5.6 = 48 s of gliding, x1.3 for pauses/look-around + ~4 s retry overhead = **~65 s per attempt**. With
median u 0.58 (allowance 1.72) in a big 36x20 maze whose goal direction is unknown, I assume the win comes on
attempt 1 / 2 / 3 / 4 / 5+ with 25 / 25 / 20 / 12 / 18 %:

- expected pay per win = 0.25x5 + 0.25x4 + 0.2x3 + 0.12x2 + 0.18x1 = **3.3 tickets**, ~3 attempts = **~3.5 min per win**
  (incl. hub/menus);
- uncapped rate = **~55 tickets per hour** of randomizer play, but the cap stops it at 5 paid wins:
  **~16 tickets per day in ~18 minutes** (typical), **25 per day** (perfect first attempts).

**The daily cap, not playtime, is the binding constraint.** "Hours to unlock" therefore means *hours of paid
play*, spread over days. I keep the cap (it is the anti-farm rule the whole payout table relies on) and add a
second, separately capped faucet (Descent) plus finite one-time bounties (Heat, Descent milestones), so a daily
player earns about twice what the randomizer alone gives:

| Faucet | Rule | Typical / day | Max / day | Finite pool |
|---|---|---|---|---|
| Randomizer quick maze | unchanged (5 paid wins) | 16 | 25 | - |
| Descent | 2 paid runs per UTC day, pot <= 30 each | 14 | 60 | - |
| Descent depth milestones | once each: floor 5 / 10 / 15 / 20 | - | - | 70 |
| Heat bounties | once per hard level per heat tier | - | - | 250 |
| **Total** | | **~30 / day in ~35 min** | 85 | 320 |

### A.3 Sinks and time-to-unlock targets

| Item | Tickets | Typical player (30/day) | Strong player (~60/day) |
|---|---|---|---|
| First workshop level (12) | 12 | first post-story session (~15 min of randomizer) | same session |
| First paid hat spin (12) | 12 | first session (spin 1 is free, any time) | same |
| All 11 hats via wheel | 210 | ~7 days (~4 h paid play) | ~3.5 days |
| Full workshop (5 x 3 levels) | 423 | ~14 days (**~8 h paid play**) | ~7 days |
| v1 cosmetics (5 trails + 3 papers) | 240 | ~8 days | ~4 days |
| **Everything in v1** | **873** | ~29 days, ~17 h paid; **~20 days** with Heat/milestone bounties | ~10-12 days |

This hits the owner's targets: first utility within ~20-30 min of randomizer play, full utility tree in ~6-10 h
of play (8 h), and the store stays meaningful for about a month of daily sessions.

### A.4 Why coins stay power and tickets buy utility (not power)

- Coins are finite and story-paced; the story calibration (`Levels.DATA` targets 45% -> 99%) assumes the median
  player converts coins into MORE SLIME (playtime model: SLIME ~5 by level 6, 10 by level 10). Keep that loop intact.
- Tickets start after the story (except the free spin and Heat bounties, which need hard clears). If tickets bought
  *meter*, the post-story randomizer (calibrated as u x meter) and the medal chase would inflate with grind.
  Workshop items are therefore **utility**: handling (charge time), forgiveness (splats), pickups, one emergency
  refill, and coin finding. None of them changes route calibration, par, or what a first story clear demands.
- The story is not trivialized: workshop items are mostly bought after level 10; SECOND WIND (the only one that adds
  effective slime) is disabled on story levels not yet cleared on normal; hard mode excludes the whole workshop.
- Never convert between coins and tickets (keeps "rainbow skin = every coin" and "tree = every coin").

---

## A2. Core coin tree rework (owner balance rule)

### A2.1 New tracks and exact costs

| Track | Kind | Levels | Effect per level (cumulative) | Cost per level | Track total |
|---|---|---|---|---|---|
| MORE SLIME | major (premium) | 7 | meter x1.15, 1.30, 1.45, 1.60, 1.75, 1.90, 2.00 | 1, 4, 7, 9, 12, 20, 27 | **80** |
| SPEED | minor | 4 | glide x1.12, 1.25, 1.37, 1.50 | 6, 9, 13, 18 | **46** |
| BRIGHTNESS | minor | 3 | reveal radius 17, 25, 34 px (base 9) | 9, 12, 18 | **39** |
| WALL POWER (dev only) | - | 4 | damage x2.5 per level of the old formula | 0 | - |
| **Total** | | | | | **165** |

These are the **tree 3** prices (owner request 2026-10-15: MORE SLIME clearly the most expensive track, 48% of the
coins). Tree 2 (the first v2 release) was MORE SLIME 1, 4, 7, 9, 10, 12, 12 = 55, SPEED 8, 12, 16, 24 = 60, BRIGHTNESS
12, 16, 22 = 50 (kept as `Economy.TREE2_COSTS` for the save migration). MORE SLIME 1-4 still cost 1, 4, 7, 9 (21), so
the early and mid story is untouched; only its last three steps (the late top-ups) got pricier. SPEED and BRIGHTNESS
are 25 coins cheaper together.

Maxima are unchanged (x2.0 meter, x1.5 speed, 34 px light) so **level 10 normal (allowance 1.01 base -> 2.02) and all
end-state calibrations are untouched**; only the path to them is coarser. `Upgrades.full_tree_cost()` still returns
165 and the rainbow/coin invariants hold.

Implementation: `Upgrades.LIST` entries get `levels`, `costs: Array[int]` and `values: Array[float]`;
`cost(id, level)`, `total_cost(id, level)`, `slime_factor(level)` = `values` lookup (level 0 = 1.0), `MAX_LEVEL` becomes
per-track `max_level(id)`. The upgrades screen draws as many pips as the track has (7 / 4 / 3), each pip wider
(10 px, 4 px gap) so a level reads as a chunk, and prints the next step's effect ("NEXT: x1.45 SLIME").

### A2.2 Brightness breakpoints (owner feedback: not visible enough)

Today: reveal radius = `TRAIL_RADIUS` 9 + 2.5 px per level and relight radius = `LIGHT_RADIUS` 20 + the same,
so one level adds 2.5 px (a sixth of a tile): invisible. New: 3 jumps of ~half a tile each.

| Level | Reach added | Reveal radius (px) | Relight radius (px) | Lit disc area vs base | Area gain this step | Look-ahead past the slime's edge |
|---|---|---|---|---|---|---|
| 0 | 0 | 9 | 20 | 1.0x | - | 0.1 tile |
| 1 | +8 | 17 | 28 | 3.6x | **+257%** | 0.6 tile |
| 2 | +16 | 25 | 36 | 7.7x | **+116%** | 1.1 tiles |
| 3 | +25 | 34 | 45 | 14.3x | **+85%** | 1.7 tiles |

Disc area is what you see at junctions, loops and rooms; in a 1-tile corridor the visible strip grows roughly
linearly (x2.1, then +47%, then +36%), which is still a clear "I see the next corner earlier" each step. Level 3
equals today's level 10, so no new power ceiling (a parallel corridor's floor starts 24 px from the corridor
center, so 34 px already peeks ~10 px into it today; going further would start showing neighbouring corridors,
which is why the cap stays at 34 and only Descent's run-scoped BLAZE boon reaches 42). Add a one-shot feedback on buy:
the cauldron preview draws the slime light ring at the new radius for 1 s. `Upgrades.light_reach(level)` becomes the
table `[0, 8, 16, 25]`; `game.gd` already uses `light_reach` for both radii and for the light sprite size.

### A2.3 Story difficulty check (playtime model mapped onto the new tracks)

The model's median player puts every coin into MORE SLIME first. Coins invested at each level start
(model) -> factor old vs new:

| Level start | Old SLIME level (coins in) | Old factor | New level (cum. cost) | New factor | Base allowance -> old / new |
|---|---|---|---|---|---|
| 2 | 1 (1) | 1.10 | 1 (1) | 1.15 | 1.92 -> 2.11 / 2.21 |
| 3 | 3 (6) | 1.30 | 2 (5), 1 banked | 1.30 | 1.72 -> 2.24 / 2.24 |
| 5 | 4 (10) | 1.40 | 2 (5), 5 banked | 1.30 | 1.43 -> 2.00 / 1.86 |
| 6 | 5 (15) | 1.50 | 3 (12), 3 banked | 1.45 | 1.32 -> 1.98 / 1.91 |
| 7 | 6 (21) | 1.60 | 4 (21) | 1.60 | 1.22 -> 1.95 / 1.95 |
| 8 | 7 (28) | 1.70 | 4 (21), 7 banked | 1.60 | 1.14 -> 1.94 / 1.82 |
| 9 | 9 (45) | 1.90 | 6 (43), 2 banked | 1.90 | 1.06 -> 2.01 / 2.01 |
| 10 | 10 (55) | 2.00 | 7 (55) | 2.00 | 1.01 -> 2.02 / 2.02 |

Worst deviation: **-7% of meter at level 5 and -6% at level 8**, both still with allowance >= 1.82 (the model's
attempts are flat above ~1.8). The model's "MORE SLIME ~5 by level 6 and ~10 by level 10" holds *in effect*
(x1.45 vs x1.5 at L6, x2.0 at L10). No change to `Levels.DATA` needed.

**Tree 3 (repriced, measured).** With the median coins found before each level and every coin put into MORE SLIME
first (allowance = `AutoplayPlanner.level_meter_tiles` / the shortest route; `tests/test_slime_pricing.gd` prints it):

| Level start | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Coins found (median) | 0 | 3 | 8 | 12 | 18 | 25 | 34 | 45 | 57 | 74 |
| Tree 2 SLIME level / allowance | 0 / 2.22 | 1 / 2.21 | 2 / 2.24 | 3 / 2.27 | 3 / 2.07 | 4 / 2.11 | 5 / 2.13 | 6 / 2.16 | 7 / 2.13 | 7 / 2.02 |
| Tree 3 SLIME level / allowance | 0 / 2.22 | 1 / 2.21 | 2 / 2.24 | 3 / 2.27 | 3 / 2.07 | 4 / 2.11 | 5 / 2.13 | 5 / 1.99 | 6 / 2.02 | 6 / 1.92 |
| Meter vs tree 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | -7.9% | -5.0% | -5.0% |

Levels 1-7 are identical; levels 8-10 start one MORE SLIME step lower and stay >= 1.92 (the flat line is ~1.8). On the
model's coins-invested column (0/1/6/6/10/15/21/28/45/55) tree 3 gives 2.22 / 2.21 / 2.24 / 2.03 / 1.86 / 1.91 / 1.95 /
1.82 / 1.86 / 1.92 (min 1.82, as tree 2). The test autopilot clears every normal level at the tree 3 median levels
(50-57% of the meter left) and the `--autoplay` bot still finds 165/165, buys 7 / 4 / 3 and golds all 20 levels.
Tree 3 buy order: L2 SLIME 1 -> L3 SLIME 2 -> L4 SLIME 3 -> (L5 saving) -> L6 SLIME 4 -> L7 SLIME 5 -> (L8 saving) ->
L9 SLIME 6 -> L10 saving for SLIME 7 (27), bought on the first coin hunt after the story; then SPEED and BRIGHTNESS.

**Typical buy order during the campaign** (coins found on the way, median: 3, 8, 12, 18, 25, 34, 45, 57, 74 before
levels 2-10): L2 SLIME 1 -> L3 SLIME 2 -> L4 SLIME 3 -> (L5 saving) -> L6 SLIME 4 -> L7 SLIME 5 -> L8 SLIME 6 ->
L9 SLIME 7 (max) -> L10 SPEED 1. Post-story coin hunts (~71 coins left) buy SPEED 2-4 and BRIGHTNESS 1-3. The
cauldron should mark MORE SLIME as RECOMMENDED until it is maxed (a dim tag), because skipping it is the model's
biggest risk for normal mode.

### A2.4 Migration of in-epoch saves (old 10-level tracks)

Pick: **map by coins invested, round down, remainder back in hand.** For each track, coins invested =
`old_level x (old_level + 1) / 2`; new level = the highest level whose cumulative new cost <= that. Coins in hand are
derived (`coins_earned - coins_spent`), so the remainder returns automatically and nobody can go negative.
Examples: SLIME 10 (55) -> 7; SLIME 5 (15) -> 3 (+3 coins); SPEED 10 (55) -> 3 (36) +19 coins; BRIGHTNESS 10 (55) -> 3
(50) +5. Gate it on a new key `[upgrades] tree = 2` (missing = old tree): pure function of the stored levels,
idempotent, runs before the existing "never spend more than found" check. A one-time hub notice: UPGRADES
REWORKED - N COINS RETURNED (only if N > 0). Save codes go through the same `_read`, so codes migrate too.

**Tree 3 repricing (`[upgrades] tree = 3`).** Coins in hand are derived from levels x the *current* prices, so a price
change would move every balance (a tree 2 SLIME 7 player with 2 in hand would read -23). Saves with `tree = 2` (and old
saves, after the tree 1 -> 2 step above) go through `Progress._migrate_prices`: each track first maps by the coins it
held at tree 2 prices, rounded down onto the new prices; then levels are bought back up to what the player had (MORE
SLIME, SPEED, BRIGHTNESS) while the coins found cover them. So a player keeps every level they can afford (a maxed tree
stays maxed), never ends below 0, and the coins freed (tree 2 spent - tree 3 spent, if positive) join the one-time
COINS RETURNED notice (e.g. SPEED 4 + BRIGHTNESS 3: +25; SLIME 7 at 57 found: SLIME 6, +2). Pure function of the
stored levels and coins found; written back as tree 3, so it never runs twice. Coin counters (HUD, cauldron, hub
board) also never display a negative number.

### A2.5 Knock-on code changes

- **Randomizer**: the meter is `RANDOM_METER_TILES x slime_factor(L)` and routes are u x that: unchanged in behavior,
  L is just 0-7 now. `random_cells` / `random_floor_cells` use `sqrt(slime_factor(L))` instead of
  `sqrt(1 + 0.1 L)` (same sizes at the same factor). **Seed codes `N-L`** now carry the new level 0-7; an old code
  with L 8-10 clamps to 7 (same x2.0 meter, same maze), L 1-7 builds the new level's maze (a different maze;
  acceptable, noted in release notes). `tests/data/maze_golden.txt`: rewrite the MORE SLIME 5 / 10 lines as 4 / 7.
- **No-MORE-SLIME ticket cap** unchanged (`upgrade_level("slime") <= 0`); SLIME 1 now costs 1 coin.
- **Autoplay** (`autoplay_planner.gd`): `next_purchase` uses `Upgrades.cost(id, level)` and `max_level(id)`;
  `PURCHASE_ORDER` unchanged. `test_autoplay_planner` thresholds re-measured (coin runs per level may drop by 0-1).
- **Par/medals**: par uses base speed (unchanged); max SPEED is still x1.5, so gold difficulty at the end is unchanged.

---

## B. New upgrades (the ticket WORKSHOP)

### B.1 Candidates evaluated

| Candidate | Verdict | Why |
|---|---|---|
| SECOND WIND (one refill at 0) | **v1** | Big, felt moment; self-balancing in the randomizer (costs one attempt step of payout) |
| QUICK CHARGE (leap charge time) | **v1** | Pure handling; no meter change; makes leaps a habit |
| STICKY (splat penalty and stun) | **v1** | Forgiveness for leap play; floor kept so blind leap-exploring stays costly |
| MAGNET (coin / goo-drop pull) | **v1** | Coin hunts (avg ~71 coins left after the story) and Descent goo drops |
| GOO NOSE (glimmers) | **v1** | Coin finding via the existing glimmer system; never shows the route |
| LINGER (slower fade-back) | v2 | Normal mode never fades to black, so the gain is small; reconsider with Heat DIM |
| RECYCLE (refund on own trail) | **reject** | Backtracking out of dead ends IS the core cost; this deletes it and breaks u calibration |
| LANTERN (light radius) | **reject** | Duplicates BRIGHTNESS; folded into its new breakpoints |
| SCOUT (map layers) | **reject** | maps.md: map layers are milestone rewards, never sold; tickets buy map *papers* only |
| SPRINT (glide acceleration) | **reject** | Indistinguishable from SPEED at 320x180 |
| SNIFF / compass to goal | **reject** | Tells you about places you have not been: removes discovery (maps.md -15 to -30% attempts) |

### B.2 v1 workshop specs (all minor tracks, 3 levels)

Common rules: bought with tickets in the cauldron's TICKETS tab, not refundable (tickets are renewable; no
respec needed), **off in hard mode** (incl. Heat), **on in normal story, randomizer and Descent**, never change
par, route, u or seed codes. Autoplay starts from a clean state (workshop 0) so the bot is unaffected; the planner
ignores the workshop.

**1. SECOND WIND** (costs 15 / 30 / 50 = 95)
- Effect: the first time the meter hits 0 in a run (on the ground), it gains **+15 / +25 / +35 %** of a meter (a fixed amount added over 0.4 s, not a refill target; slime spent meanwhile stays spent) instead of drying
  up; once per run (Descent: once per *run*, not per floor). Big visible moment: a goo gulp sound, a ring burst,
  the meter refills over 0.4 s.
- Story: only on levels already cleared on normal (coin hunts, medal replays); unavailable on a level's first clear
  and in hard mode. Medals/records allowed (it adds slime, not speed).
- Randomizer: allowed, but **firing it counts as one attempt for the payout** (`payout()` uses `attempt + 1`):
  a first-attempt win that used it pays 4. This keeps the u-based calibration honest: randomizer budgets do *not*
  account for it; the player pays for the extra slime with ticket value. The attempt pod updates live.
- HUD: a small drop icon at the meter's empty end; full color = ready, dim = used, hidden when not applicable.
- Save: `[workshop] wind`. Files: `game.gd` (`_dry_up` gate, `payout`), `hud.gd`. Effort S-M.

**2. QUICK CHARGE** (12 / 25 / 45 = 82)
- Effect: full charge time `Slime.CHARGE_TIME` 1.5 s -> **1.2 / 0.95 / 0.7 s** (-20 / -37 / -53%). Distances,
  costs and the landing guide are unchanged.
- Meter: none. Medals: leap-heavy replays get a little faster (as SPEED does today; par ignores both). Hard: off.
- Save: `[workshop] charge`. Files: `slime.gd` (`charge_time` var instead of the const), `jump_guide.gd`. Effort S.

**3. STICKY** (12 / 25 / 45 = 82)
- Effect: splat penalty x **0.75 / 0.55 / 0.40** (2-5% becomes 0.8-2% at level 3) and stun `SPLAT_STUN` 0.3 s ->
  **0.2 / 0.12 / 0.06 s**. The half-price leap cost on the distance flown stays, so leap-exploring blind still
  costs at least half a glide and reveals almost nothing.
- Meter: adds effective slime only on splats (*est.* +1-3% of a meter per randomizer attempt for an average leaper).
  Randomizer budgets do not account for it (small, skill-forgiveness). Hard: off.
- Save: `[workshop] sticky`. Files: `game.gd` (`splat_penalty` x factor), `slime.gd` (stun). Effort S.

**4. MAGNET** (12 / 25 / 45 = 82)
- Effect: coin pickup reach `Coin.REACH` 10 px -> **18 / 26 / 34 px**, only for coins on revealed floor with no wall
  tile on the straight line (one tile-raycast on the maze grid); the coin flies into the slime (existing
  `dissolve_into`). With jelly off the coin glides into the solid slime and pops. Level 3 grabs a coin in a 1-cell dead end from its mouth (saves ~4 tiles there and back).
  Also pulls Descent goo drops.
- Meter: indirect (shorter coin detours); story first clears barely affected (coins are optional). Hard: no coins.
- Save: `[workshop] magnet`. Files: `game.gd` (`_pick_up_coins`), `coin.gd`. Effort S.

**5. GOO NOSE** (12 / 25 / 45 = 82)
- Effect: fog glimmers (`GLIMMER_EVERY` 180-360 px traveled, reach 160 px) come **x1.4 / x1.8 / x2.3 as often** and
  reach **200 / 240 / 300 px**, and only ever pick coins that are on screen (the view plus 8 px), so every glimmer
  can be seen (measured visible glimmers/min, levels 0-3: 1.00 / 1.34 / 1.73 / 2.21x); they also mark Descent goo drops. Shows only coins/drops, never the route or goal.
- Save: `[workshop] nose`. Files: `game.gd` glimmer section. Effort S.

Workshop total: **423 tickets**.

### B.3 Interaction checklist (all workshop items)

| Concern | Rule |
|---|---|
| Randomizer calibration (u x meter) | unchanged; SECOND WIND pays like +1 attempt; STICKY not accounted |
| Par / medals | par from base speed (unchanged); no workshop item lowers par; medals stay comparable |
| Ticket caps | unchanged; no-MORE-SLIME cap still keys on the coin tree |
| Hard mode | all off (also Heat); HUD shows no workshop icons there |
| Assist | unchanged (ASSIST adds 10% and voids medals/tickets as now) |
| Autoplay | clean state, workshop 0; planner unchanged except the new coin cost table |
| HUD | only SECOND WIND has an icon; others are felt, not shown |
| Fog identity | nothing reveals unvisited corridors beyond BRIGHTNESS's capped 34 px; GOO NOSE shows coin twinkles only |

---

## C. Ticket store and sinks

### C.1 Hats go live

- Set `Hats.available = true`. The wheel's pricing stays as is: free, 12, 14, ..., 30 (**210 for all 11**; no dupes
  by construction, so no dupe handling is needed). The 40 cap stays as a safety constant (it matters only if hats
  are added: with 15 hats the last spin would cost 38).
- Rainbow pity stays (+0.15 weight per miss). Because the wheel shrinks, the rainbow hat is guaranteed by spin 11 at
  the latest; pity only makes it arrive earlier on average.
- **Direct buy (TAILOR)** in the SHOP tab: pick any hat still on the wheel for **45 tickets (rainbow 80)**, available
  after you have taken at least 3 spins (the wheel stays the main, cheaper path: average wheel spin ~21). A direct
  buy also counts as a spin taken (`spins += 1`) so mixing cannot dodge the price ramp; buying the rainbow hat resets
  `rainbow_pity`. Atomic like `spin_hat` (pay, win, save, then animate).
- The free first spin works from the first hub visit, so story players get one hat early (the wheel's hook);
  the next spins need tickets (post-story or Heat).

### C.2 v1 cosmetics (cheap: palette / procedural, no new sprite sheets)

| Item | Kind | Price | How it's made |
|---|---|---|---|
| INK trail | trail | 20 | goo uses the skin's `deep` shade, alpha 150 |
| GLOW trail | trail | 25 | `GOO_ALPHA` 170 and `TRAIL_GLOW` x2 |
| GOLD trail | trail | 30 | `CHALICE_GOLD` goo (ignores skin) |
| CANDY trail | trail | 35 | skin / white stripes every 12 px traveled (`_goo_color` by distance) |
| STARRY trail | trail | 40 | skin goo + 1 px white specks by fog-cell hash (deterministic, no textures) |
| BLUEPRINT paper | map | 25 | map_view palette swap (blue paper, white ink) |
| NIGHT paper | map | 25 | dark paper, skin-colored ink |
| GOLD LEAF paper | map | 40 | cream paper, gold ink, gold coin ticks |
| **Total** | | **240** | |

Earned (not sold) cosmetics: ABYSS trail (Descent floor 10), EMBER trail (Heat: every hard level at heat 7+).
The rainbow skin keeps its rainbow trail unless a trail style is equipped. v2 candidates: hat dyes (palette swap),
hub wallpapers (`hub_room.gdshader` uniforms), map stamps.

### C.3 Where the store lives (no 10th station)

- **Cauldron (UPGRADES)**: two tabs, COINS | TICKETS. The TICKETS tab shows the workshop (5 rows at 24 px:
  26 + 5 x 24 = 146, fits above the bottom buttons); locked with the hint EARN TICKETS IN THE RANDOMIZER until
  `tickets_lifetime > 0`. Coin pod and ticket pod top right follow the tab.
- **Prize wheel (HAT WHEEL)**: two tabs, WHEEL | SHOP. SHOP lists TAILOR hats, trails, papers as a 2-column grid of
  goo-framed tiles with price; buying asks once (BUY GOLD TRAIL? 30 TIX / BACK). The hub prompt shows the next spin
  price as now, or SHOP when every hat is owned.
- **Wardrobe**: a third page TRAILS (equip owned trails). **Map table**: a PAPER button on the map view cycles owned papers.
- Flow: earn at the portal -> hub ticket pod pops -> cauldron/wheel prompts show a small "!" when something is
  affordable (one rule: the cheapest unowned item <= balance).

---

## C2. Descent runs (owner direction 4)

### C2.1 Structure

- **Entry:** the randomizer portal opens a small choice panel: QUICK MAZE (today's mode) / DESCENT. Unlocked with the
  randomizer (all 10 levels). Normal mode only in v1 (hard Descent is a v2 idea).
- **A run** = floors 1, 2, 3 ... each a randomizer maze built from a run seed (`run_seed * 1000 + floor`), no seed
  codes (no replay farming). The goal is the chalice (exit), so floors read differently from ticket mazes.
- **The meter carries over.** A floor starts with what you had left plus a refill: **+60% floors 1-3, +50% 4-6,
  +40% 7-9, +35% 10+**, capped at 100%. A dry-up ends the run. This is the roguelite tension: a sloppy floor
  starves the next.
- **Floor scaling:** u = 0.30 + 0.05 x (floor - 1), +-0.05 seeded jitter, capped at 0.85 (floor 12+). Maze size:
  sized for this floor's route (`1.25 x route + 12`, the quick-maze formula applied to the floor's route instead of
  the 95% route), floor at 14x8, cap 36x20, so early floors are quick (~1 min) and deep ones are big.
  Theme cycles in story order: floor k uses `Themes.BY_LEVEL[(k - 1) % 10 + 1]` (dungeon ... volcanic), so depth is
  readable at a glance. Spawn classes as in the quick maze.
- **Goo drops:** each floor places 2 drops at deep dead ends (seeded, like coins), **+8% meter** each; MAGNET pulls
  them, GOO NOSE twinkles them.
- **Upgrades:** coin tree applies (meter = 136 tiles x slime factor, speed, brightness); workshop applies
  (SECOND WIND once per run). ASSIST does not exist in Descent.

### C2.2 Boons (choose 1 of 3 after each floor; run-scoped)

| Boon | Effect | Stacks | Weight |
|---|---|---|---|
| BIG GULP | refill +30% now | yes | 1.0 |
| DEEP TANK | meter capacity +15% for the run | 2x | 0.8 |
| FEATHER LEAP | leap cost 50% -> 35% of glide | no | 0.8 |
| RUBBER BODY | no splat penalty (stun stays); never with GLASS SLIME | no | 0.8 |
| SLICK | glide speed +15% | 2x | 0.8 |
| BLAZE | +1 brightness breakpoint (past level 3: 42 px) | no | 0.6 |
| CHALICE SENSE | the exit shows through fog within 6 tiles (default 1.5) | no | 0.5 |
| BACKUP BLADDER | one extra SECOND WIND-style refill to 25% | yes | 0.5 |
| THRIFT | floor refills +15 points | 2x | 0.8 |
| GREEDY GOO (trade-off) | +1 ticket per floor to the pot, capacity -10% | no (built: was 2x) | 0.5 |
| GLASS SLIME (trade-off) | pot x1.5 when banked, splats cost double; never with RUBBER BODY | no | 0.4 |

*Built change (review b3 fixes, 2026-10-15):* GREEDY GOO is one stack (two put capacity 0.80 under the deepest
floors' u 0.85), and RUBBER BODY / GLASS SLIME exclude each other (RUBBER cancelled GLASS's drawback).

Offers: 3 distinct, non-stackable boons already held are excluded (and RUBBER / GLASS while the other is held); seeded from the run seed and floor (same run,
same offers). Picking is a full-screen panel over the cleared floor (keyboard / touch: 3 big tiles + CASH OUT).

### C2.3 Rewards, daily cap, records

- **Pot:** each floor cleared adds **+1 (floors 1-3), +2 (4-6), +3 (7-9), +4 (10+)**; GREEDY/GLASS modify it; **max 30**.
- **Cash out** (button on the boon screen): end the run and bank the whole pot. **Dry-up:** bank half the pot
  (rounded down). Quitting mid-floor = a dry-up.
- **Daily:** **2 paid runs per UTC day** (separate counter from the randomizer's 5 wins; same forward-only day
  rollover). *Built (review b3 #3):* a run takes its paid slot when it first clears floor 1, saved at once, so
  closing the app mid-run can't keep the slot; it banks into that slot later (HUD / summary: PAID RUN n/2). A run
  ending on floor 1 takes none. Later runs show PRACTICE on the pot and pay 0. No-MORE-SLIME rule: pot
  capped at 1. Dev / dev-toggled runs: 0.
- **Milestones** (once ever): first reach floor 5 / 10 / 15 / 20 -> +10 / +15 / +20 / +25 tickets; floor 10 also
  unlocks the ABYSS trail.
- **Exploit check:** pay needs floors cleared; quitting early only loses; boons are seeded per run (no reroll by
  restarting the same run: a restart is a new run and uses a paid slot once it clears floor 1); 2 x 30 = 60/day is the
  ceiling and needs ~floor 9+ twice (*est.* ~25 min of excellent play).
- *est.* pacing: median run reaches floor 5-6 in ~8 min and banks ~7 (cash out) or ~4 (dry-up).
- **Records:** `best_floor` (and its time) on the portal prompt (DESCENT  BEST FLOOR 7) and the choice panel.

### C2.4 Save, files, effort

- `[descent] best_floor, best_time, runs, paid_day, paid_runs, milestones` (bitmask). No in-run state is saved
  (closing the game mid-run = dry-up rules on next launch are not needed: the run simply never banked).
- Files: `progress.gd` (counters, `complete_descent(pot, cashed)`), `levels.gd` (`descent_config(seed, floor)`),
  `game.gd` (floor chaining, carry-over meter, goo drops, boon effects as a `run_mods` Dictionary),
  new `scripts/descent.gd` (`Descent`: boon table, offers, pot math), new `scripts/ui/boon_picker.gd`,
  `hud.gd` (FLOOR n pod in place of the attempt pod, pot), `hub.gd` (portal choice panel). Effort **L**.

---

## C3. Hard-mode Heat modifiers (owner direction 5)

### C3.1 Modifiers

| Modifier | Heat | Effect | Winnability check |
|---|---|---|---|
| DIM | 1 | relight radius 20 -> 10 px, fade-back steps x0.6 | no meter change |
| BRITTLE | 1 | splat penalty x2, bounce slide no longer free (greyed out with GROUNDED) | walking unaffected |
| FOG BITES | 2 | dimmed cells return to full fog after 4.5 s instead of 9 | no meter change |
| GROUNDED | 2 | no leaps | perfect walk uses 78-88% (allowance 1.14-1.29) |
| THIRSTY | 2 | drain x1.08 | walk allowance 1.14/1.08 = **1.06** minimum (L1) - 1.19 (L10): still winnable by walking |
| RACE | 3 | a countdown of 1.3 x par (the silver line); 0 = dry-up | perfect walk = 74% of par |

Max heat = 10 (BRITTLE excluded with GROUNDED). Every combination stays winnable by a perfect walk (THIRSTY +
GROUNDED + RACE is the tightest: 6% slack, intended as the summit).

### C3.2 Toggle, rewards, records

- **Where:** level select with HARD MODE on: a HEAT button beside the checkbox opens a panel of 6 toggles with the
  running total (HEAT 6). A hard level's heat unlocks after its plain hard clear. Toggles are global (apply to any
  hard level). HUD shows `HARD  HEAT 6`.
- **Bounties (once per hard level per tier):** heat >= 2: +3, >= 4: +5, >= 7: +7, = 10: +10 tickets (25 per level,
  **250 total**, finite, no daily cap needed). Paid on the clear (`complete_heat(level, heat)` pays every newly
  crossed tier).
- **Badges:** the level tile shows a flame with the best heat tier (none / 2 / 4 / 7 / 10); the hub pod gets
  `HEAT n/100` (sum of best heat). Every hard level at heat 7+ unlocks the EMBER trail; all at heat 10 unlocks a
  title-screen flame crown on the logo (cheap: a palette tint).
- **Records/medals:** heat runs record hard times and hard medals normally (no modifier makes a run faster).
- **Tickets in hard randomizer:** unchanged; Heat is story-hard only in v1.
- Save: `[heat] level_N = best heat` (0-10); `[settings] heat_mods` (bitmask). Files: `level_select.gd`, new
  `scripts/heat.gd` (`Heat`: table, `points(mask)`, `tiers`), `game.gd` (apply), `hud.gd`, `progress.gd`. Effort **M**.

---

## D. Save format, tests, build plan, tuning

### D.1 Save additions (`SAVE_VERSION` 6; all optional with defaults)

| Section / key | Type | Default | Notes |
|---|---|---|---|
| `[upgrades] tree` | int | 1 (missing) | 2 = new tracks; < 2 triggers A2.4 migration |
| `[workshop] wind, charge, sticky, magnet, nose` | int 0-3 | 0 | clamped on read |
| `[cosmetics] owned` | string array | [] | allow-listed ids only |
| `[cosmetics] trail, paper` | string | "skin", "parchment" | fall back if not owned |
| `[hats] bought` | int | 0 | direct buys (stats only; `spins` already counts them) |
| `[descent] best_floor, best_time, runs, paid_day, paid_runs, milestones` | int/float | 0 | paid_* clamped like the randomizer's |
| `[heat] level_N` | int 0-10 | 0 | N = 1-10 |
| `[settings] heat_mods` | int bitmask | 0 | |
| `[wallet] tickets_spent` | int | 0 | for the stats line and sanity checks |

- **RELEASE_EPOCH stays 1** (all additive; the fresh-start policy is unchanged). Codes stay `SLIME2-`.
- **Migration:** only the coin-tree remap (A2.4); everything else defaults. Loading drops workshop levels and
  cosmetics only if malformed (tickets are not re-derivable, so no "could not have paid" check; clamp ranges instead).
- `save_text.gd` allow-list: add the new section and key names.
- Known risk (unchanged): an older build re-saving a newer save drops the new sections.

### D.2 Tests to write / update

- `test_upgrades_v2`: cost tables sum to 165; factor/speed/light tables; per-track max; buy/refund; migration table
  (every old 0-10 level per track -> expected new level + coins back; idempotent on a second read; save code path).
- `test_brightness`: reveal/relight radii per level in a real level (count revealed fog cells around a fixed path).
- `test_workshop`: each item's effect, hard mode off, SECOND WIND once per run, story-uncleared gate, randomizer
  payout shifts by one attempt, not refundable, ticket deduction atomic.
- `test_store`: wheel totals 210 for 11 spins; direct buy 45/80 after 3 spins, counts as a spin, rainbow pity reset;
  cosmetics buy/equip/fallback; dev mode free.
- `test_descent`: floor u/size/theme tables, carry-over refill, dry-up halves the pot, cash out, 2 paid runs/day,
  milestones once, no-MORE-SLIME cap, boons seeded per run, autopilot clears 3 floors.
- `test_heat`: each modifier applied, BRITTLE/GROUNDED exclusion, every heat combination winnable (perfect walk per
  hard level x worst mask), bounties pay once per tier.
- Update: `test_maze_golden` (MORE SLIME 4/7 lines), `test_tickets`, `test_random_usage`, `test_autoplay_planner`,
  `test_coins_upgrades`, `test_hats`, `test_save_codes`, `test_fresh_start`, `test_nav_fuzz` (new tabs/panels).

### D.3 Phased build plan

| Batch | Contents | Effort | Gate to ship |
|---|---|---|---|
| **1. Core tree rework** (DONE 2026-10-15) | per-track tables in `upgrades.gd`, brightness breakpoints, upgrades screen pips/next-effect line, migration + notice, randomizer size/code changes, golden rewrite, autoplay cost lookup, playtime model re-run | M (2-3 days) | all suites pass; autoplay story run completes; playtime median within +-5% |
| **2. Hats + store + workshop** (DONE 2026-10-15; review fixes applied, see docs/archive/review-upgrades-b2.md) | `Hats.available = true`, wheel tabs WHEEL/SHOP, TAILOR, 5 trails + 3 papers, cauldron TICKETS tab, 5 workshop items, HUD wind icon, save keys | L (4-5 days) | store/workshop tests; nav fuzz; screenshots of every new screen |
| **3. Descent** (DONE 2026-10-15) | portal choice, floor chain, boons, goo drops, pot/cash-out, daily cap, milestones, records | L (5-6 days) | descent tests; 20 autoplay runs reach floor >= 4 with no errors; web perf check (floor build <= 20 ms) |
| **4. Heat** (DONE 2026-10-15) | 6 modifiers, level-select panel, bounties, badges, EMBER trail | M (2-3 days) | winnability test over all masks; hard autoplay at heat 10 on L1-3 |
| **QA / balance** | qa-tester pass, web build check, first playtest with logging (tickets/day, workshop buy order, descent depth, heat usage) | ongoing | |

### D.4 Tuning after playtests: one constants table

Create `scripts/economy.gd` (`Economy`, static consts only) and move every number above into it, so a balance
pass edits one file:

```
COIN_TRACKS = {slime: {costs, values}, speed: {...}, brightness: {...}}
WORKSHOP = {wind: {costs: [15,30,50], values: [0.15,0.25,0.35]}, charge: {...}, sticky: {...}, magnet: {...}, nose: {...}}
RANDOM_ATTEMPT_PAY, RANDOM_PAID_PER_DAY, TICKETS_NO_SLIME_CAP, TICKETS_REPLAY_CAP   (moved from Progress)
SPIN_COST, SPIN_STEP, SPIN_COST_MAX, TAILOR_PRICE, TAILOR_RAINBOW_PRICE, TAILOR_AFTER_SPINS
COSMETICS = {id: price}
DESCENT_REFILL, DESCENT_U_START, DESCENT_U_STEP, DESCENT_U_MAX, DESCENT_POT_PER_FLOOR, DESCENT_POT_MAX,
DESCENT_PAID_PER_DAY, DESCENT_MILESTONES, DESCENT_DROP_REFILL, BOONS
HEAT_MODS, HEAT_TIERS, HEAT_BOUNTY
```

What to watch and which knob: tickets/day far below 30 -> raise Descent pot per floor (not the randomizer cap);
workshop bought before hats by most players and hats ignored -> lower TAILOR to 35; Descent median depth < 4 ->
raise early refills to +70%; nobody uses Heat above 4 -> raise the >= 7 bounty; story attempts on L5/L8 up vs the
model -> move SLIME 2->3 cost from 7 to 5 (cumulative 10).

---

## E. What the player experiences

**First hour (story).** Level 1 shows the cauldron's single cheap first step: SLIME 1 for 1 coin, "x1.15". Each buy
is a visible chunk (7 fat pips, not 10 thin ones). Around level 3 the hub prize wheel offers a FREE spin: the first
hat lands on your slime. By level 6 the player has SLIME 4 (x1.6 soon), the levels feel as before. Hard mode is
there for the curious; its first clears unlock HEAT on that level, a flame icon teasing later rewards.

**After the story (hours 1-3).** The portal opens with two doors: QUICK MAZE and DESCENT. Five quick mazes earn ~16
tickets; that's the first paid spin or the first workshop level (QUICK CHARGE 12: leaps snap out). The coin hunt
for the ~70 missing coins buys SPEED and BRIGHTNESS, whose 3 jumps each visibly widen the light. A first Descent run
gets to floor 5 (the theme changes every floor, so "I reached the Sunken Shrine" is the brag), picks FEATHER LEAP and
THRIFT, cashes out 7 tickets before the Toxic Tunnels, and earns the floor-5 milestone 10.

**Long term (days 2-30).** A daily ~35-minute habit: 5 quick mazes + 2 Descent runs, ~30 tickets. Hats complete in
about a week (wheel, or the TAILOR for the one you want now), the workshop in about two weeks (SECOND WIND changes
how Descent feels), trails and map papers after that. Skilled players chase Descent floor 10 (ABYSS trail), and
Heat: re-running hard levels with GROUNDED + THIRSTY + RACE for the heat-10 flames and 250 bounty tickets, the
game's mastery summit.
