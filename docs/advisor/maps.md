# Maps as a game mechanic: research, difficulty impact and an unlock plan for Slime Time

Author: game-advisor. Date: 2026-10-14. Read-only research; no game code was changed.
Read first: CLAUDE.md, docs/archive/game-design.md, docs/handoff.md, docs/level-design.md,
docs/playtime-estimate.md, docs/advisor/*.md (especially roguelike-progression.md, which warned
"do not add a map reveal meta upgrade that cheapens memory", and flow-level-design.md, which proposed
a 2 s retry ghost of the last attempt). Code checked: `scripts/upgrades.gd`, the dry-up/win buttons in
`scripts/game.gd` (lines ~1512-1569), `Progress._write` / `save_code`.

**Source tags.** [F] = I fetched the page and read it. [S] = search-result summary only (the page
itself was not read, often because the wiki returned 402/403). [GK] = my general knowledge, not
checked against a source in this session. All text is paraphrased; nothing is copied.

---

## 0. TL;DR

1. **The trail map is the right first step, and it is safer than it looks.** In Slime Time the
   first clear happens the moment the slime touches the chalice, so a "best route" line can only
   exist *after* the level is beaten. It has **zero effect on first-clear difficulty**; it only
   speeds up medal replays. The "revealed so far" layer is what touches difficulty, and it only
   replaces what the player is supposed to remember anyway (the playtime model already assumes
   perfect memory).
2. **My toy simulation (section 4)** says a revealed-area map cuts attempts by about **0-2% on
   normal levels with upgrades** and **5-12% on tight levels** (hard mode, or normal 8-10 without
   upgrades). It moves real players towards the model's "perfect memory" numbers, not below them.
   Hard-mode time drops by roughly **4-10 min of ~82 min** (median).
3. **The dangerous aids are the ones that tell you about places you have NOT been:** dead-end hints
   (-25 to -40% attempts), a chalice compass (-15 to -30%) and large "surveyor" reveals (-20 to
   -40% at 50% reveal). These remove discovery. Keep them out of first clears or price them as an
   assist that voids medals (like the existing ASSIST).
4. **Research lesson:** the games that handle maps best split them into separate, earned layers
   (Hollow Knight: map, quill, compass, pins are separate purchases; Zelda: map and compass are
   separate dungeon items), update the map only at a rest point (Hollow Knight benches), mark only
   places you have been (Hollow Knight pins, BotW stamps), and keep "where you are going" unknown.
   Lab research backs this: direction-only aids keep people's mental maps better than
   turn-by-turn routes.
5. **Do not price maps in coins.** 165 coins = exactly the full tree, which is a design rule. A
   coin-priced Cartographer tree would be a trap choice: on normal mode the map helps much less than
   the MORE SLIME it would cost. **Do not sell power for tickets** either (tickets are
   cosmetic-only by rule). Unlock map layers by **play milestones per level** (first attempt,
   first clear, coins found, medals, hard clear) and spend tickets only on **map cosmetics** (paper
   styles, ink, stamps).
6. **Recommended structure:** Trial = faint trail map + deepest attempt (before a clear) / best
   route (after). v1 = coin ticks, pins and stamps, dry-up "MAP" button, a medal-gated full blueprint
   and par comparison, per-theme map art, a hard-mode page that fades. v2 = all-attempts replay,
   pace splits, best-run ghost for medal chasing, shareable map image, a "study then run blind"
   challenge, map cosmetics on the ticket economy.

---

## 1. Where Slime Time stands (constraints that decide everything)

- **The fog is the identity.** "Escape the fog / or dry trying". The map starts black every attempt;
  the trail reveals it; lit cells fade back in steps (to a dim memory on normal, back to full fog in
  hard mode). Memory of a fixed maze is the main skill and the main progress between attempts
  (playtime-estimate.md assumption 1).
- **A win is the first touch of the chalice.** Hidden until within ~24 px. So information about the
  winning route never exists before the first clear. This is unusual and important: most
  "best route" ideas are post-clear by nature.
- **Retries skip the hub.** The dry-up screen offers RESTART / UPGRADES (plus ASSIST after 3 dry-ups,
  NEW MAZE in the randomizer). A hub-only map table is therefore studied only when the player chooses
  to leave (pause > QUIT TO HUB) or between sessions. That is a natural limit, similar to Hollow
  Knight's "update the map at a bench".
- **Economy.** 165 story coins = `Upgrades.full_tree_cost()` (3 x 55, level n costs n, refundable).
  Tickets come only from the randomizer (5/4/3/2/1 by attempt, 5 paying wins a day), are cosmetic only
  and buy hat spins (first free, then 12, 14 ... 40). Medals are time tiers vs par (gold <= par).
  Hard mode: no upgrades, no coins, own mazes (12x7 .. 36x20), allowance 1.14-1.29, fog returns.
- **Sizes.** Story mazes are 10x6 .. 26x14 cells, hard up to 36x20. At 4 px per cell a 36x20 map is
  144x80 px and fits the 320x180 screen with room for a frame and legend. Draw it at cell
  resolution, not the 2 px fog grid.

---

## 2. What other games do (research)

### 2.1 Layered, earned maps (metroidvanias, Zelda)

- **Hollow Knight.** Each area's map is bought from the cartographer Cornifer, whom you find by
  following his paper trail; the map he sells is incomplete. The **Quill** (120 Geo) lets you fill
  in what you explore; the **Wayward Compass** (220 Geo and a charm notch) shows where you are;
  **pins/markers** (benches, stag stations, shops) only show in areas you have visited. New
  exploration is drawn in only when you rest at a bench (or save/die). Players who want help buy all
  the tools; purists go without. [F superjump analysis; S wiki/guide snippets for prices; 30 Geo for
  the first map, all maps 1154 Geo from Cornifer, 1515 from the shop]
- **Silksong** moved all map tools to one early vendor (Shakra) to cut backtracking; the first map
  arrives about 30 minutes in. Some maps are pick-ups. [S]
- **Super Metroid.** Map stations reveal most, not all, of an area; revealed-but-unvisited rooms
  look different from visited ones. Brinstar's station shows nearly everything; Crateria's mostly
  repeats what you saw but exposes hidden rooms towards the Bombs; Norfair's points at an unexplored
  block and the boss. Showing bosses in advance builds anticipation; partial maps keep players
  forming their own mental map. [F Game Developer "The Invisible Hand of Super Metroid"; S fandom]
- **Zelda dungeons.** The dungeon **map** shows the layout (often omitting secret rooms); the
  **compass** shows chests and the boss. They are separate items found inside the dungeon. A fan
  critique argues the map should feel like a luxury earned through challenge. [S zeldadungeon wiki
  and forum]
- **Dead Cells Explorer's Rune.** Once most of a biome is explored (~90%), the whole map and its
  points of interest are revealed. Players found it nearly useless because it fires so late. [S]
- **Rogue Legacy.** The **Architect** locks the last castle layout for the next run but takes 40%
  of the gold you earn in it; reviewers call it a bad deal except for practising bosses. The
  **Spelunker/Miner** class shows chests on the unexplored map. [S]

### 2.2 No map, or a map you make yourself

- **Dark Souls** has no map; Miyazaki's stated aim is that players set their own goals and make
  their own discoveries; the world is built to read naturally as you walk through it. [S Rolling
  Stone/EDGE quotes via wiki]
- **Elden Ring.** Map fragments sit at Guide Steles and show terrain only; points of interest are
  discovered by looking. Players place up to 100 markers and 5 beacons (light pillars in the world
  that vanish when reached). [S wiki/guides]
- **Breath of the Wild.** Towers reveal terrain, not icons, so the player scouts and marks points
  themselves (stamps: player-defined meaning; pins: vanish on arrival). The **Hero's Path** (Master
  Trials DLC) draws your last 200 hours of movement as a green line with a timeline slider and marks
  deaths: the closest commercial cousin of our trail map. [F Stamen cartographer review; F GMTK
  essay on towers; S Hero's Path wiki]
- **Rain World** gives only a partial map of visited regions and no quest markers. [S, weak
  sources]
- **Etrian Odyssey.** The player draws the map on the DS touchscreen; an accurate map is how you
  get back to town to save, so mapping is the core skill. [S director's diary + reviews]
- **Ultima Underworld / Legend of Grimrock.** Automaps with free-form notes; Grimrock also has an
  "old school" mode with no automap and a compass item. Underworld's designer called the
  annotatable automap the feature he most wished got credit. [S]
- **Animal Well.** The Pencil (after 16 eggs) lets you draw routes and circle unreachable spots on
  the map; stamps exist too. [S]
- **Noita / Spelunky.** No map. Noita players install minimap mods. Spelunky's **Compass** puts an
  arrow to the exit on the HUD (and never points to secret exits); the Udjat Eye beeps faster near
  the Black Market. Derek Yu's stated aim is meaningful choices with real regret for bad ones.
  [S wiki; S GMTK]

### 2.3 Roguelikes: magic mapping and scouting

- **NetHack** scroll of magic mapping: maps the whole level (not secret doors unless blessed);
  cursed or confused reads show about 1/7 of the squares at random; some levels refuse mapping.
  About 4.5% of scrolls. [F nethackwiki]
- **Brogue** magic mapping: reveals layout, traps, secret doors, levers, not items or monsters; ~5%
  of scrolls, ~2.2 per run; players save them for deep levels. [F brogue.wiki] (Brogue draws
  magic-mapped cells differently from seen ones: [GK], not confirmed.)
- **Shattered Pixel Dungeon** has the same scroll (layout + secrets) and some levels that can't be
  mapped. [GK]
- **Darkest Dungeon.** The room/corridor graph is visible from the start; **scouting** (25% base,
  raised by torch light, trinkets, camping skills) reveals what is in the next rooms; secret rooms
  need a critical scout. Light is a risk dial. [S wiki]
- **Diablo / Diablo II automap.** A line drawing of walls you have seen, overlaid on play without
  pausing; D2 adds waypoints and exits and keeps it until the game session ends. [S Wikipedia
  mini-map + D2 wiki; F Wikipedia "Mini-map" for history]
- **Caves of Qud.** Locations are learned as "secrets" in a journal (trade them for water); the
  world map marks journal locations. Information is a currency. [S]
- **Civilization / 4X.** Explored terrain stays but shows as old parchment; units vanish under fog,
  so the map remembers things that may no longer be true; a Civ mod adds visual decay of old
  knowledge; GalCiv players asked for "age of information" indicators. [S forums; Civ VI parchment
  fog is also [GK]]

### 2.4 Knowledge as progression

- **Outer Wilds.** No stat progression; progress is knowledge. The ship log has a rumour web and a
  map view and flags locations that still hold unread clues, but never confirms a planet is "done".
  Beachum's pillar: explore because you are curious. [S MCV/Axios/GameSkinny quotes; the GDC 2020
  talk page exists but I could not read it]
- **Return of the Obra Dinn.** The logbook confirms correct fates only in sets of three to stop
  guessing. [F Wikipedia]
- **Tunic.** Manual pages (controls, items, maps, hints) are scattered in the world; finding and
  re-reading them is progress, and some hints only click on a later read. [F Superjump]
- **Hitman.** Per-location mastery unlocks new start points and shortcuts: the map gets richer the
  more you master it. [S]
- **Minit.** Knowledge and items carry over across 60-second lives. [GK]

### 2.5 Ghosts, replays and routes (mastery tools)

- **Super Meat Boy** plays every attempt at once after a clear, turning deaths into a reward and a
  record of learning. [S Wikipedia + McMillen article]
- **Mario Kart** staff ghosts (and expert staff ghosts unlocked by beating them) are built-in pace
  targets; **Trackmania** gives bronze/silver/gold/author medal times and, on PC, medal ghosts.
  [S Mario wiki; S community]
- Speedrun tools (LiveSplit, route maps) compare splits against a personal best; players ask for
  "ahead/behind at each checkpoint" in indie games. [S]

### 2.6 What research says about maps and mental maps

- **Habitual GPS use** went with worse spatial memory and fewer landmarks noticed when navigating
  without GPS (50 drivers; a 13-person 3-year follow-up showed steeper decline with more use);
  correlational, the authors caution. [F Dahmani & Bohbot 2020, Sci Rep]
- **Direction-only vs turn-by-turn.** People new to a campus who navigated with a direction-only
  audio beacon drew better sketch maps (error 86 vs 178) and pointed back to the start more
  accurately (17 vs 37 degrees) than those given turn-by-turn directions; experts showed no
  difference; small sample. [F Clemenson et al. 2021, Sci Rep]
- In games, a landmark-based verbal aid built spatial knowledge better than a minimap, while the
  minimap won on efficiency. [S Khan & Rahman, IJHCI 2017; PDF not readable here]
- Designers: Clair Obscur dropped the minimap because it makes exploration boring; critics describe
  "eyes glued to the minimap". thatgamecompany's GDC 2021 talk argues for designing spaces that
  form cognitive maps (landmarks, districts) instead of relying on map UI. [S interviews; F GDC
  Vault abstract]

---

## 3. Design lessons for a fog maze

### 3.1 When a map removes discovery and when it builds mastery

| Removes discovery | Builds mastery |
|---|---|
| Shows places you have **not** been (full reveal, survey, dead-end hints) | Shows places you **have** been, as you saw them |
| Points at the goal before you found it (compass, beacon) | Shows the goal only after you reached it |
| Is visible **during** play all the time (minimap: you play the map, not the world) | Is studied **between** attempts (bench, hub, dry-up screen) |
| Gives the route (turn-by-turn) | Gives feedback on your own route (where time was lost) |
| Is free and automatic from the start | Is earned per level and layered |

Rule of thumb from all of the above: **record, don't reveal; between runs, not during; direction,
not route; after the clear, anything goes.**

### 3.2 Limits that keep difficulty

1. **Only what you saw** (Hollow Knight pins, BotW towers without icons).
2. **Update at a rest point** (Hollow Knight benches): our map updates when an attempt ends.
3. **Per-level unlock after effort** (the trial's "after a first attempt"; Zelda's map inside the
   dungeon; Hitman per-location mastery).
4. **Fidelity and decay** (Civ parchment, Diablo II session maps, our own fade steps): faint blobs
   at first, crisp later; hard mode can forget.
5. **Cost in the run's own resource**: a map peek that costs slime (like Rogue Legacy's 40% gold
   tax) is a real trade-off; a map that costs nothing in-run is not.
6. **Imperfect information**: cursed NetHack mapping (1/7 random), Darkest Dungeon's scouting odds,
   Super Metroid stations missing rooms.
7. **Mapping as a skill**: player pins/notes (Grimrock, Animal Well, Etrian Odyssey) keep the
   player active, matching the "active navigation" finding.
8. **Post-clear gating**: anything strong (blueprint, par route, ghost) after a clear or a medal,
   when it can only help mastery.

### 3.3 Progression hooks that work without monetisation

- **Completion meters** (explored % per level, Outer Wilds' "more here" marker, Tunic pages).
- **Collections** (stamp sets, map styles per theme), bought with the renewable cosmetic currency.
- **Unlocks by milestone, not purchase** (Mario Kart expert ghosts, Hitman mastery).
- **Replays that celebrate failure** (Super Meat Boy, Hero's Path deaths).
- **Shareable artefacts** (a finished map image is a trophy and free marketing).

---

## 4. How much do map aids change difficulty? (toy simulation)

The project's Monte Carlo (playtime-estimate.md section 2) is kept outside the repo, so I wrote a
smaller cousin to measure **relative** effects only. Scratch script (not shipped):
`<scratchpad>/mapsim.py`, `mapsim2.py`.

**Model.** Perfect mazes from a growing-tree generator with straight runs (no loops, so close to hard
mode; normal 6-10 have 2-6 loops), start on the edge, chalice on the farthest cell. Meter = route x
allowance. Per attempt the player walks the tree depth-first from the start, skipping branches it
knows are goal-free, choosing unknown branches at random, "continuing where it was" first. Unknown
cells cost 1, known cells cost e (1.20 -> 1.04, learn 0.85, sd 0.05; hard 1.26 -> 1.10, as in the
project model). The win is the first touch of the chalice. **Forgetting:** each remembered dead
branch is forgotten with probability q on the next attempt (q 0.30, or 0.50 with the cells also
forgotten); a map studied between attempts is modelled as q 0.08-0.10. 250 mazes per row, the same
mazes for each aid. Allowances: N1 2.22, N5 2.0 and N10 2.02 (median MORE SLIME at that level), N10
without upgrades ~1.15 (1.01 plus some leaping), hard 5 1.17, hard 10 1.29.

**Mean attempts to first clear** (median in brackets):

| Aid | N1 | N5 | N10 | N10 no upgrades | Hard 5 | Hard 10 |
|---|---|---|---|---|---|---|
| Perfect memory (= project model) | 1.38 (1) | 1.69 (2) | 2.06 (2) | 5.79 (5) | 5.98 (6) | 4.96 (4) |
| Real memory, no map (q .30) | 1.39 | 1.70 | 2.06 | 6.26 (6) | 7.13 (7) | 5.23 (5) |
| Real memory, forgets cells too (q .50) | 1.40 | 1.69 | 2.05 | 5.85 | 6.32 | 5.11 |
| **Trail map** (q .08) | 1.38 | 1.70 | 2.05 | 5.77 (5) | 6.34 (6) | 5.17 (5) |
| Trail map + best-route ghost | same | same | same | same | same | same |
| + dead-end hints (stubs of 3 cells or less marked once their mouth is seen) | 1.19 | 1.39 (1) | 1.64 (1) | 4.13 (4) | 4.41 (4) | 3.64 (3) |
| + chalice compass bias (picks the branch pointing at the chalice) | 1.29 | 1.56 (1) | 1.76 | 4.65 (4) | 5.03 (5) | 3.91 (3) |
| + survey 25% of cells at start | 1.38 | 1.65 | 2.00 | 5.06 | 4.98 (4) | 4.70 |
| + survey 50% of cells at start | 1.32 | 1.62 | 1.86 | 4.74 (4) | 4.10 (4) | 4.12 |

What this says (and doesn't):
- **The trail map's effect is small**: ~0% on normal with upgrades (allowance ~2 is generous) and
  **-8% to -11% on tight levels** (hard 5, normal 10 without upgrades) against real memory, i.e.
  back to the project's perfect-memory numbers. The toy's forgetting is mild (a forgotten branch only
  costs a re-walk), so the real gap may be bigger; playtime-estimate.md guessed memory errors could
  add 25-50% to hard time. **Read the trail map's effect as "-5% to -25% of hard-mode attempts,
  most likely ~10%".**
- **Best route / ghost: exactly zero on first clears** (by construction: touching the chalice wins).
  Its value is medal replays, which the project model already puts at ~5 min in total for normal
  golds; on hard golds it saves more.
- **Information about unseen space is what moves difficulty**: dead-end hints -25 to -40%, compass
  -15 to -30%, survey 50% -20 to -40% on hard. Surveys under ~25% do little on normal (random cells
  rarely prove a whole branch empty) but already help a lot on hard.
- Absolute numbers are lower than the project model's (no leap/splat behaviour, no loops, no
  hesitation time); only compare rows.

**Converted to time with the project's per-level minutes** (median player, hard total ~82 min,
normal clears ~42 min, coin hunts ~25 min):

| Aid | Normal clears | Hard clears | Coin hunting |
|---|---|---|---|
| Trail map (revealed area) | ~0 to -1 min | **-4 to -10 min** | -3 to -8 min (no re-entering emptied dead ends; estimate) |
| Coin ticks on the map (found coins) | 0 | n/a | -2 to -5 min (estimate) |
| All coins shown after 75% of a level's coins | 0 | n/a | -5 to -10 min (the tail of the hunt) |
| Best route / ghost (post-clear) | 0 | 0 | 0; golds ~-1 to -3 min |
| Dead-end hints | -8 to -12 min | -20 to -30 min | large |
| Compass to chalice | -5 to -10 min | -15 to -25 min | 0 |
| Survey 50% | -3 to -6 min | -20 to -30 min | large |

The (c) "normal + hard" headline (~2.1 h median) would move to ~2.0 h with the trail map, and to
~1.6-1.7 h with dead-end hints or a compass. That is the scale of the risk.

---

## 5. Idea catalogue (24 ideas, ranked)

Columns: **Impact** on fun/retention (1-5), **Difficulty** change to first clears (none / low /
med / high), **Effort** S/M/L, **Save**, **Economy** (coins/tickets/medals/hard/randomizer),
**Fog risk** to the dark-fog identity (low/med/high). Ranked by impact vs risk vs effort.

| # | Idea | Impact | Difficulty | Effort | Save | Economy | Fog risk |
|---|---|---|---|---|---|---|---|
| 1 | **Trail map table (trial)**: per level, after a first attempt, the union of cells revealed in all attempts, drawn faint; deepest attempt line before a clear, best route after | 5 | low (hard -5..-10%) | M (in progress) | bitmask per level + route string | none; story only | low |
| 2 | **Map updates when an attempt ends** (never live) and the table says "NEW" on changed levels | 3 | none | S | none | none | low |
| 3 | **Coin ticks**: found coins marked at their dead ends; empty dead ends you visited shown as plain ends | 4 | none (hunts faster) | S | none (coins_found exists) | coins: speeds hunts | low |
| 4 | **Player pins and stamps** on the table (8-12 stamp icons, ~20 per level), shown in-run only as a faint mark on cells you have revealed this attempt | 4 | low | M | small list per level | tickets: extra stamp sets | low |
| 5 | **Dry-up MAP button** (the "bench"): the same view from the dry-up and pause screens | 4 | low (raises #1's effect) | S | none | none | low-med |
| 6 | **Explored % per level** on the table and level select; 100% = a stamp/badge; all 10 at 100% = a cosmetic (map-themed hat or skin trim) | 4 | none | S | derived | collection hook; hats | low |
| 7 | **Gold-medal blueprint**: after a level's gold medal, its full layout (crisp, every corridor) becomes viewable (post-clear study) | 3 | none | S | flag (derived from medals) | medals: new reason for gold | low |
| 8 | **Par comparison**: after gold (or silver), the shortest route drawn next to your best route, with the tiles you wasted | 3 | none | S | none (derived) | medals | low |
| 9 | **Fidelity levels**: faint cell blobs at first; crisp walls and theme tiles after the first clear; "inked" after all coins | 3 | none | S/M | derived | coins/medals as unlocks | low |
| 10 | **Per-theme map art** (dungeon parchment, iced vellum, obsidian slate, sand scroll...) and table frames | 3 | none | M | selected style | **tickets** (cosmetic) | low |
| 11 | **All-attempts replay** on the table (every attempt's line drawn growing at once, dry-ups as goo splats), Super Meat Boy style | 4 | none | M | last ~10 attempt routes per level (cells, 2 bits/step) | none | low |
| 12 | **Hard-mode page that fades**: shows only the last 2 attempts (older cells fade out), best route only after a hard clear | 3 | low (-3..-6% hard) | S | bitmask per hard level (+ age) | hard identity kept | low |
| 13 | **Best-run ghost in-run** (a translucent slime replaying your best clear), opt-in, only after a clear; medals still count | 3 | none (golds easier) | M | route + timestamps per level | medals: chase gold | low-med |
| 14 | **Par-pace marker**: a dot moving along YOUR best route at exactly par speed (shows ahead/behind) | 3 | none | S after #13 | none | medals | low |
| 15 | **Pace splits**: route split at junctions, each segment coloured faster/slower than your best (Trackmania checkpoints) | 2 | none | M | segment times per level | medals | low |
| 16 | **Shareable map image**: PNG of the finished map with route, time, medal, skin colours (desktop save; web download) | 3 | none | M | none | marketing | low (spoiler only) |
| 17 | **Coin finder after 75%**: once 75% of a level's coins are found, the rest show as faint glints on its map (Dead Cells rune, but early enough to matter) | 3 | none | S | derived | coins: shortens the tail | low |
| 18 | **Study then run blind** challenge: study the full blueprint 20 s, run with the normal fog, own stamp/medal | 2 | none (separate mode) | M | best per level | medals/cosmetic | low |
| 19 | **Map peek that costs slime** (v2 upgrade): open the trail map mid-run for e.g. 3% slime per look; off in hard mode | 2 | low-med | M | none | coins? see section 6 | med |
| 20 | **Randomizer seed map** (session only, never saved): the dry-up shows this seed's trail | 2 | low (+ticket payout a little) | S | none | tickets: payout by attempt rises slightly | low-med |
| 21 | **Surveyor in the randomizer**: spend one of the maze's TIX AVAILABLE to reveal 25% of it | 2 | med | M | none | tickets: trade payout for info (not the wallet) | med |
| 22 | **Chalice compass as a mercy assist** (after N dry-ups, voids medal/record like ASSIST; the L1-2 beacon already does this) | 2 | high when used | S | none | assist rules | med-high |
| 23 | **Dead-end hints** (marks stubs you haven't entered) | 1 | high | S | none | none | high |
| 24 | **Coin-priced Cartographer tree** in the cauldron (map tiers bought with story coins) | 1 | low-med | M | upgrade level | breaks 165 = full tree | med |

Further ideas considered and rejected: player-drawn maps (Etrian Odyssey; heavy UI for touch and
mouse, niche), map fragments from hard clears revealing normal levels (normal is already cleared by
then; no value), a full-reveal scroll in story levels (NetHack/Brogue; removes the core loop).

### Notes on the top items

**1. Trail map (trial).** Keep the trial exactly as scoped: revealed union + best route, per level
after the first attempt, at the hub table, not a blueprint. Draw at 4-5 px per cell (L1 10x6 = 50x30
px, hard 36x20 = 144x80) with the slime's start marked, the chalice only once reached, dead ends you
entered drawn as dead ends. Before a clear show the **deepest attempt's line** (closest you got),
after a clear the **best (fastest) clear route**. Show the attempt count and best time. In the
trial, keep it out of hard mode and the randomizer.

**3/6/17. Coins on the map** are the biggest "quality of life without difficulty" win: coins
persist through dry-ups, so the hunt (median ~20 min in the project model, which assumes the
player knows where coins are) is where real players waste the most time re-entering emptied dead
ends. Show found coins always. Never show unfound coins before 75% found.

**4. Pins and stamps.** Active navigation keeps the mental map (Clemenson 2021: direction cues
beat turn-by-turn; Elden Ring/BotW stamps). In-run, a stamp shows only as a tiny faint mark once its
cell is lit again, so it is a note to yourself, not a beacon through the fog. Elden Ring-style
beacons through the fog would be a compass in disguise: avoid.

**5. Dry-up MAP button.** Without it the table is only seen when the player goes back to the hub,
so the trail map barely matters. With it, the dry-up screen becomes the bench: the attempt ends,
the map updates, you study, you retry. That raises the effect to the 5-12% (tight levels) above.
Recommended for v1, not the trial, so the trial measures the table alone first.

**12. Hard mode.** Hard's identity is "the fog takes back what you leave". A hard page that only
shows the last two attempts' cells (older ones faded to nothing, matching the in-run fade to full
fog) keeps that identity while still letting the map help a little.

**13/14. Ghost and par-pace.** Gold is already "replay it cleanly once". A ghost mostly adds fun and
a race; make it opt-in and only after a clear. Do not draw a ghost on the shortest route (that is
the solution). Par-pace runs on the player's own route.

---

## 6. Economy fit

- **Coins (165 = full tree).** A coin-priced Cartographer tree breaks the invariant (rainbow skin =
  all coins found, the tree = all coins spent). It also misleads: on normal mode the map saves ~0
  attempts, while 10 coins kept in MORE SLIME is 1-2 levels, +10-20% meter, for a median player
  around level 6 (and the project model names skipped MORE SLIME as the main way normal mode gets
  much longer). Players who buy map tiers early
  would make the game harder for themselves. If the owner still wants a coin sink, the least harmful
  is a single refundable **QUILL** (5 coins) that enables the slime-costing map peek (#19), off in
  hard mode; the full tree then needs 170, so add one more coin somewhere or accept that maxing
  everything means refunding the quill.
- **Tickets (cosmetic only, 25/day max, spins 12-40).** Fit perfectly for **map cosmetics**: theme
  map styles (#10), stamp sets (#4), ink colours, a table trim. 10 styles at ~10 tickets each would
  be a second sink besides the hat wheel. Do **not** sell information (surveys) for tickets in story
  levels; that would make tickets buy power.
- **Randomizer surveyor (#21).** The only good form is spending the current maze's TIX AVAILABLE
  (5/4/3/2/1) to reveal part of it: you trade this maze's payout for help, never your wallet. It
  interacts with the daily cap (a surveyed win still uses one of the 5 paid wins), so it is
  self-limiting. Low priority.
- **Medals.** Medal-gated layers (blueprint at gold, par comparison at silver/gold) give the 30/30
  medal chase a new reward that is useless for first clears: a clean, risk-free hook.
- **Hard mode.** No map aids in hard runs except the fading page; hard clears unlock the hard
  page's best route. Hard golds could unlock the hard blueprint.
- **Assist/dev rules.** Anything that reveals unseen space during a run (compass, peek if it ever
  shows more than the trail) should mark the run like ASSIST: clears, no medal/record/tickets.

---

## 7. Recommended unlock structure (per story level)

| Milestone on that level | Map layer unlocked | Effect on first clear |
|---|---|---|
| First attempt ends | Trail map: faint revealed cells, deepest attempt line, attempt count | low |
| Each later attempt ends | Map updates (NEW tag) | low |
| First clear (bronze) | Best route line + time; crisp walls (fidelity 2); found coin ticks | none |
| Silver | Par comparison (your route vs the shortest, wasted tiles) | none |
| Gold | Full blueprint (every corridor) + opt-in best-run ghost and par-pace dot | none |
| 75% of the level's coins | Remaining coins glint on that level's map | none (hunt only) |
| All coins on the level | Inked style + a stamp on the level's tile | none |
| 100% explored | Explorer stamp; 10/10 levels = a cosmetic reward | none |
| Hard: first hard attempt | Hard page, fading (last 2 attempts only) | low |
| Hard clear | Hard best route; hard gold = hard blueprint | none |

Tickets buy map styles and stamp sets. Coins buy nothing map-related (optional QUILL aside).

---

## 8. Roadmap

**Trial (now).** Hub map table, story normal mode only: revealed union + deepest/best route after a
first attempt; updates at attempt end; no in-run aid; not in hard or the randomizer. Add to the dev
log: table opened (level, seconds viewed), then the next attempt's result, so we can see whether
studying changes attempts. Playtest question: do players go to the hub to look, and does the next
attempt avoid known dead ends?

**v1 (if the trial is liked).** Dry-up and pause MAP button (#5); coin ticks (#3); pins/stamps (#4);
fidelity by milestone (#9); medal layers (#7, #8); explored % (#6); 75% coin finder (#17); hard
fading page (#12); save format (section 9). Expected difficulty change: normal ~0, hard ~-5 to -12%
attempts. Re-run the playtime model with memory q set from playtest data.

**v2.** All-attempts replay (#11); ghost + par-pace (#13, #14); pace splits (#15); shareable image
(#16); theme map art and ticket store (#10); study-blind challenge (#18); maybe the slime-costing
peek (#19) and the randomizer session map (#20). Keep #22-#24 off the roadmap unless playtests show
players quitting on hard 8-10 (then the compass as an ASSIST-style mercy, never default).

---

## 9. Save implications

- **Size.** Revealed bitmask at cell level: normal mazes 1,852 cells = 232 bytes; hard 3,343 cells =
  418 bytes. Best routes as 2-bit directions: ~150 bytes (normal) + ~250 (hard). About 1 KB raw;
  gzip helps on sparse masks. The `SLIME1-` code (~500 chars now) could roughly double or triple.
  Options: keep maps in `save.cfg` (new optional `[maps]` section, defaulted) and either exclude them
  from save codes in the trial (maps rebuild by playing) or include them and accept longer codes.
- **Layout changes.** Story layouts changed once (save v4). Store each mask with a fingerprint of
  the maze (cell count + a hash of its walls); drop it if the maze changes, like `_migrate_coins`.
  Never key by cell coordinates alone.
- **Older builds** re-saving a newer save drop unknown sections (noted in roguelike-progression.md);
  maps would be lost, nothing else.
- **RESET PROGRESS** should clear maps; `--story-complete` and `--autoplay` should fill them (the
  autoplay planner knows the routes).
- **Attempt replays (#11)** need the last N attempt paths; cap N (10) and store only for the
  current level session if the save budget matters.

---

## 10. Risks and what to watch

- **Identity creep.** Every step from "record" towards "reveal" erodes "escape the fog". Hold the
  line: nothing shown about unseen cells before a clear.
- **Playing the map instead of the maze.** Keep maps between attempts; no minimap in-run.
- **Normal mode gets even gentler.** It is already gentle (2-4 attempts). The map won't change that
  much, but coin markers shorten the coin layer by ~5-15 min; that's fine (it removes tedium).
- **Hard mode tail.** The map helps hard most, which is where the slow profile spends ~1 h on hard
  8-10; that is a welcome effect, but make sure the fading page doesn't turn hard into "study, then
  execute" only.
- **Spoilers.** Shared images and blueprints spoil fixed story mazes; they are post-clear and the
  same as screenshots anyway.
- **Playtest data to collect:** table views per level, time spent, revisits of known dead ends with
  and without studying, attempts before/after the map unlocks, coin-hunt runs.

---

## Sources

Fetched [F]:
- Superjump, Getting Lost (by Design) in Hollow Knight: https://superjumpmagazine.com/getting-lost-by-design-in-hollow-knight
- Game Developer, The Invisible Hand of Super Metroid: https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid
- NetHack wiki, Scroll of magic mapping: https://nethackwiki.com/wiki/Scroll_of_magic_mapping
- Brogue wiki, Scroll of magic mapping: https://brogue.wiki/wiki/Scroll_of_magic_mapping
- Wikipedia, Mini-map: https://en.wikipedia.org/wiki/Mini-map
- Stamen, Cartographers play video games (BotW map review): https://stamen.com/cartographers-play-video-games-a-review-of-the-map-in-the-legend-of-zelda-breath-of-the-wild/
- GMTK, How Nintendo Solved Zelda's Open World Problem: https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world
- Superjump, Tunic Hides Its Secrets in Plain Sight: https://superjumpmagazine.com/tunic-hides-its-secrets-in-plain-sight
- Wikipedia, Return of the Obra Dinn: https://en.wikipedia.org/wiki/Return_of_the_Obra_Dinn
- Dahmani & Bohbot 2020, Habitual use of GPS negatively impacts spatial memory: https://pmc.ncbi.nlm.nih.gov/articles/PMC7156656/
- Clemenson et al. 2021, Rethinking GPS navigation: https://pmc.ncbi.nlm.nih.gov/articles/PMC8032695/
- GDC Vault, Stop Getting Lost: Make Cognitive Maps, Not Levels (abstract): https://gdcvault.com/play/1027206/Stop-Getting-Lost-Make-Cognitive

Search summaries only [S]:
- Hollow Knight tools and prices: https://hollowknight.wiki.fextralife.com/Wayward+Compass , https://hollowknight.wiki.fextralife.com/Map+and+Quill , https://www.ludo.guide/guide/hollow-knight/npcs-2
- Silksong maps: https://www.cheatcc.com/articles/how-to-find-a-map-in-hollow-knight-silksong/ , https://www.pushsquare.com/guides/hollow-knight-silksong-how-to-unlock-maps-and-where-to-find-shakra
- Metroid map: https://metroid.fandom.com/wiki/Map
- Zelda dungeon map/compass: https://www.zeldadungeon.net/wiki/Dungeon_Map , https://zeldadungeon.net/forum/threads/dungeon-map-and-compass.46721
- BotW Hero's Path: https://zeldadungeon.net/wiki/Hero's_Path , https://zeldawiki.wiki/wiki/Hero%27s_Path_Mode
- Elden Ring map and markers: https://eldenring.wiki.gg/wiki/Map , https://www.tomsguide.com/features/find-map-fragments-elden-ring
- Dark Souls / Miyazaki: https://www.siliconera.com/dark-souls-creator-discusses-difference-similarities-legend-zelda/
- Don't Starve Together map, Cartographer's Desk, Map Scroll: https://dontstarve.wiki.gg/wiki/Map/DST , https://dontstarve.fandom.com/wiki/Cartographer%27s_Desk , https://dontstarve.fandom.com/wiki/Map_Scroll
- Diablo automap: https://www.wowhead.com/diablo-2/guide/auto-map-guide-overlay
- Darkest Dungeon scouting: https://darkestdungeon.wiki.gg/wiki/Dungeon_map , https://darkestdungeon.wiki.gg/wiki/Secret_Room
- Caves of Qud secrets: https://wiki.cavesofqud.com/wiki/Secret
- Civilization fog decay mod / 4X fog: https://forums.civfanatics.com/threads/map-fog-of-war-decay-modmod.699860/ , https://wiki.galciv.com/index.php/Fog_of_War
- Dead Cells Explorer's Rune: https://deadcells.wiki.gg/wiki/Rune , https://destructoid.com/?p=244511
- Rogue Legacy Architect/Spelunker: https://en.wikipedia.org/wiki/Rogue_Legacy , https://www.hardcoregaming101.net/rogue-legacy/
- Spelunky Compass/Udjat Eye: https://spelunky.fandom.com/wiki/Spelunky_HD:Compass , https://primagames.com/gaming/spelunky-2-alien-compass-guide
- Etrian Odyssey: https://www.dampfkraft.com/games/etrian-odyssey-directors-diary.html , https://strategywiki.org/wiki/Etrian_Odyssey
- Grimrock / Ultima Underworld automap notes: https://www.gamebanshee.com/news/105961-legend-of-grimrock-development-update-v15-105961.html , https://gallery.ultimacodex.com/ultima-underworlds-auto-mapping-feature/
- Animal Well pencil: https://primagames.com/gaming/how-to-get-and-use-the-pencil-in-animal-well
- Outer Wilds: https://mcvuk.com/?p=208916 , https://www.axios.com/release-outer-wilds-echoes-of-the-eye-f721ba5f-ed94-4126-98cf-c7057d7fc190.html , https://www.gameskinny.com/culture/interview-8-questions-with-creative-director-and-producer-of-mobius-games-developer-of-outer-wilds/
- Hitman mastery: https://checkpointgaming.net/news/2018/10/hitman-2s-lead-designer-andreas-krogh-talks-progression-difficulty
- Super Meat Boy replay: https://en.wikipedia.org/wiki/Super_Meat_Boy , https://www.gamedeveloper.com/game-platforms/-i-super-meat-boy-i-s-mcmillen-explains-why-so-hard-
- Mario Kart / Trackmania ghosts: https://www.mariowiki.com/Ghost_(Mario_Kart_series) , https://tm.mania-exchange.com/blogs/entry/569/what-do-you-think-medal-times
- Minimap critiques: https://www.gfinityesports.com/article/the-mini-map-is-boring-so-clair-obscur-expedition-33-left-it-behind , https://www.popmatters.com/153477-2495894835.html
- Minimap vs landmark aid study: https://cs.brown.edu/~nkhan6/docs/khan_rahman_ijhci17.pdf
- Mobile maze hints: https://docs.crazygames.com/resources/monetizing-puzzle/
- Speedrun route tools: https://www.speedrun.com/posts/zg26u , https://itch.io/post/11637394
- Spelunky design (GMTK): https://amara.org/v/C3BFa ; Noita: https://noita.wiki.gg/wiki/Noita

General knowledge [GK]: Minit carry-over, Shattered Pixel Dungeon magic mapping, Brogue's display of
magic-mapped cells, Civ VI parchment fog style (also partly in a search snippet).
