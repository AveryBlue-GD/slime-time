# Flow, pacing, level design and onboarding: advisor report

Topic: moment-to-moment flow, difficulty curve, tension and release around the slime meter, level length and maze quality, teaching without text, retry loops, goal and reward pacing, session length.
Date: 2026-10-12. Author: game-advisor (read-only; no game code touched).

How to read the evidence: items marked **[fetched]** come from a page I actually read this session (URL in the Sources list). Items marked **[search]** come from a search result summary only. Items marked **[general knowledge]** are from my own background knowledge of the game and are not backed by a fetched page. Several primary sources (GMTK Spelunky transcript, Celeste GDC talk, Game Developer pages for Noita/Celeste) were blocked or thin, so I say so where it matters.

---

## 1. What comparable games do (findings)

### 1.1 Failure cost is the real difficulty dial

- **Super Meat Boy** **[fetched]**: McMillen's formula is difficulty = chance of dying x penalty for dying; the team removed lives, cut respawn time to almost nothing, kept levels "bite-sized" so the goal is always visible and the distance re-covered after death is small, and replays all your past deaths when you finally win, so failure reads as progress. Frustration was treated as the thing to remove "at all costs." An optional Dark World (unlocked by beating a level under par time) carries the extra-hard content so the main path stays gentle.
- **Celeste** **[fetched, forgiveness article]**: Thorson's stated principle is to fudge every timing and position window slightly in the player's favour (coyote time, jump buffering, corner correction, wide wall-jump window), which is why a very hard game feels kind. **[fetched, game-wisdom]** Checkpoint at the start of every room, hidden optional strawberries/B-sides carry the extra challenge, and a critic notes difficulty rises by lengthening rooms rather than adding variety, so "later chapters felt like they could have removed a few rooms." **[search]** Assist Mode can be changed at any time and is framed as an invitation, not a judgment.
- **Hades God Mode** **[fetched]**: +20% damage resistance on enable, +2% per death, cap 80%. Kasavin's goal was to "take the sting of failure" while still letting the player die enough to see runs differ; he says difficulty tools should be game-specific.
- **Minit** **[fetched]**: a 60-second life makes failure cost a minute; progress, items and discovered spawn houses persist, and Nijman frames the timer as a planning constraint ("how do I spend my next minute"). Puzzles were sized to how far you can travel in 60 s.
- **Dark Souls shortcuts** **[fetched]**: shortcuts and looping routes turn a one-way trip into an investment that survives failure; a world that circles back makes the hub a visible landmark and lowers the cost of repeating ground. Bycer's critique: when safe progress is erased (far bonfires, respawning enemies), risk tilts too far over reward and the player gets no places to breathe.
- **Hollow Knight** **[fetched]**: the map is a layered, optional aid (map, compass, markers sold separately), explored areas persist through death, and you can find the mapmaker by a humming sound and a paper trail. Effort spent on wayfinding is itself a choice.

### 1.2 Flow and pacing structure

- **Brotato** **[fetched]**: waves 20 s growing 5 s per wave up to 60 s, a shop between every wave, a fixed 20-wave run (under 30 min). The reviewer's point: difficulty self-corrects, because if a wave is too easy it ends and the next is harder, and if you struggle you die fast and the next run feels easy again.
- **Vampire Survivors** **[search]**: soft 15-30 minute limit, then an escalating Reaper; run goal sits just beyond most players' reach, which drives "one more run"; meta currency is earned even from a failed run.
- **Dome Keeper** **[search]**: a short calm dig phase then a timed wave; the tension is on the way home, not at the rock face. Steam players complain that the slow, identical opening of each run drags until a few upgrades land **[search, player threads]** (relevant: our level 1 has no upgrades and no variety).
- **Rain World** **[search]**: a hidden, randomised rain timer plus a food requirement create a routing problem ("how far can I go and still get back"); reviewers praise the tension but criticise opacity and getting lost.
- **Hades** **[fetched]**: death is progress (story, currency, unlocks), and the first unlocks widen options rather than just add power. Roguelite guides **[search]** advise staging mechanics through meta-progression so run one does not teach everything and paying out something even on an early death.
- **Super Mario Bros 1-1** **[search]**: wordless teaching by placement (a Goomba that forces the first jump, blocks that make a missed jump discover the reward).
- **Baba Is You** **[fetched]**: each level is built backwards from one interesting interaction; unintended solutions are kept when they teach the same lesson; playtesters are essential because designers go blind to shortcuts. **[search]** the overworld is only a level-select, not a puzzle space.
- **Donut County** **[fetched]**: each level has one gimmick that modifies the hole; no fail state, one button, no explicit tutorial was described. Length and pacing were not covered by the source.
- **A Short Hike** **[fetched]**: kept scope small on purpose, limited wandering and NPC chatter so the rhythm holds, and uses landmarks and collectables to pull curious players off the main path; getting a little lost is meant to be rewarding in itself.
- **Spelunky** **[fetched via search + a modding tutorial + a Persian GMTK adaptation]**: a fixed 4x4 grid of rooms, a guaranteed critical path that needs no equipment, hand-authored room templates with randomised fill, and hand-made recurring set pieces (idol, altar, shop, damsel) that force decisions. Yu admits players start to recognise repeated landmarks; "procedural but not random" (start near top, exit usually opposite) gives reliable expectations. Quick restart limits frustration **[fetched, Game Developer "Design lessons"]**. The Tunnel Man shortcut carries over between runs.
- **Noita** **[fetched]**: chose permadeath plus procedural worlds so players learn systems instead of memorising layouts; world built from hand-drawn Herringbone Wang tiles.

### 1.3 Maze-specific evidence

- **Algorithm character** **[fetched, Jamis Buck, Pullen]**: recursive backtracker (growing tree newest-only) gives few, long dead ends and long winding passages (about 10% dead ends); random-pick growing tree behaves like Prim (many short cul-de-sacs; 49% for growing forest); "run" (straight length) and "river" (long vs short dead ends) are separate dials; a braid maze (no dead ends) can be much harder than a perfect maze of the same size.
- **Maze games and designers** **[fetched, itch.io devlog "Making of Maze"]**: at junctions with no information, the outcome is luck rather than skill; the cost of a wrong choice is the backtrack to the last junction plus second-guessing; fixes were fewer junctions, rewarding dead ends with an item that advances you, revealing the exit before you enter, and a post-level shortcut that makes backtracking nearly free. **[search]** Players like a lingering trail so they can see which routes they already tried; they dislike long featureless corridors; dead ends should feel like information.
- **Fog of war as aid** **[search, itch.io comments]**: fog tells you where you have not been; it is the mental-map burden that makes mazes interesting, so offer ways to build the map without paper.

### 1.4 Takeaways distilled

1. Keep the retry loop shorter than the attempt (SMB, Minit, Spelunky quick restart).
2. Persist something through failure (Hollow Knight map, Minit items, Hades currency, Souls shortcuts); in Slime Time that something is coins (already persistent) and the player's own memory.
3. Give tools that raise the floor without lowering the ceiling (Celeste Assist, God Mode, Brotato self-correction), and keep the hard path available.
4. Tension needs a release: a refuge, a pickup, a landmark, a rest beat.
5. Mazes need decision quality, not just size: few meaningful junctions, dead ends that are informative or paid, landmarks that survive darkness.
6. Teach by placement and constraint in level 1, then twist.

---

## 2. Audit of Slime Time (measured, not guessed)

I ran the real generator headless (`MazeGenerator.generate` on `Levels.DATA`) and read `game.gd`, `levels.gd`, `maze_generator.gd`, `progress.gd`, `slime.gd`, `hud.gd`.

### 2.1 Story maze numbers

| Lvl | cells | path (cells) | path / maze | dead ends | stub dead ends (depth <= 2) | junctions on path | longest straight on path (cells) | no-upgrade target |
|---|---|---|---|---|---|---|---|---|
| 1 | 10x6 | 23 | 38% | 11 | 7 (64%) | 4 | 3 | 45% |
| 2 | 12x7 | 31 | 37% | 14 | 8 (57%) | 6 | 4 | 52% |
| 3 | 13x8 | 39 | 38% | 14 | 8 (57%) | 5 | 3 | 58% |
| 4 | 15x8 | 47 | 39% | 21 | 12 (57%) | 11 | 6 | 64% |
| 5 | 16x9 | 55 | 38% | 20 | 13 (65%) | 9 | 4 | 70% |
| 6 | 18x10 | 63 | 35% | 33 | 23 (70%) | 12 | 5 | 76% |
| 7 | 20x11 | 71 | 32% | 43 | 28 (65%) | 18 | 5 | 82% |
| 8 | 22x12 | 81 | 31% | 55 | 43 (78%) | 19 | 3 | 88% |
| 9 | 24x13 | 91 | 29% | 59 | 43 (73%) | 28 | 5 | 94% |
| 10 | 26x14 | 101 | 28% | 77 | 57 (74%) | 27 | 6 | 99% |

Randomizer (noise generator, 20x12, 5 seeds): path 43-75 cells, 36-50 dead ends, goal anywhere (not always far corner).

Derived facts:
- Slime max speed is 72 px/s, so a perfect L1 route (~46 tiles) takes about 10 s and a perfect L10 route (~202 tiles) about 45 s. Attempts, with exploration, probably run 30 s - 3 min. This is already in the Super Meat Boy / Minit comfort zone for *attempt length*; the weak links are the retry friction and the information the player carries into the next attempt.
- `slime_cost_per_tile = target * 100 / path_tiles` (`game.gd:205`), so the budget is always expressed against the single shortest path; exploration allowance = (1/target - 1) of the path: L1 about 2.2x the path length of free wandering, L5 0.43x, L8 0.14x, L10 about 0.01x (that is: none). The coins (slime upgrade up to +100% range) are what make L8-L10 humanly beatable, and coins sit at dead ends, so the core risk/reward loop is "spend slime to fetch the coin that buys more slime." That is a strong loop (it echoes Dome Keeper's dig-vs-return and Minit's persistence) and the audit below protects it.
- The solution path's straight runs max out at 3-6 cells (a cell is a tile pair, so 6 cells is about 11 tiles). The leap covers up to 8 tiles and is only fully usable in 0-10 places per level; at L1-L3 it is essentially never useful on the path. The leap is the game's skill-expression move and the maze almost never asks for it.
- The generator parameter `branching` (0.05 -> 0.50) mostly adds 1-2 cell *stubs*: at L10, 74% of dead ends are 2 cells deep or less; mean dead-end depth falls from 3.2 (L1) to 2.3 (L10). Long false branches (depth >= 5) are rare (L5 has one of depth 30, which is an outlier worth reusing deliberately). Buck/Pullen: high branching = many short cul-de-sacs, low river. So difficulty at the top comes from sheer junction count (27 on a 101-cell path), not from deceptive false trails.
- Story mazes are perfect mazes (no loops), so there is exactly one route and no shortcut ever appears; the noise generator adds loops only in the randomizer.
- Goal = farthest cell by path from start (0,0). On L3 and L4 the chalice is spatially 6 cells from the start (corner top row) although 39-47 steps away; the player will not see that.
- Coins: `coin_cells` takes a seeded shuffle of *all* dead ends, so coins land on 1-cell stubs as often as on deep branches, regardless of difficulty (`game.gd:772-787`).
- No level shows any in-game instruction. Level 1 begins with a title card (`show_area_name`) and the HUD; there is no teaching of glide, leap, the meter, the chalice, or coins. The leap's dotted landing marker (`jump_guide.gd`) exists only once a player has already discovered Space.
- Retry path: a dry-up waits `END_DELAY` 2.0 s, then `CHOICE_DELAY` 0.6 s, then shows RESTART / UPGRADES buttons; only then does `reload_current_scene` run with a goo wipe. Pressing R mid-run opens a confirm prompt (`restart_prompt.gd`). That is about 3 s + a click per failure on a level where a perfect attempt is 10 s.
- Randomizer dry-up shuffles to a *new* maze (`_dry_up` text "THE MAZE WILL SHUFFLE", `progress.new_random_maze`), although `docs/game-design.md` says "dying retries the same maze." The first retry therefore never lets the player apply what they learned.
- Low-meter feedback: below 20% the bar turns red and pulses (`hud.gd:13`). No audio escalation, no vignette push, no relief beat.
- Collected coins are saved at the moment of pickup (`progress.collect_coin` in `_pick_up_coins`), so a dry-up never loses coins. Good: failure is not punished by lost loot.

### 2.2 Strengths worth protecting

- Fade-memory design (1.5/3.5/6/9 s steps, never fully black) is a built-in mental-map aid, in line with the "fog tells you where you have not been" evidence.
- Fixed seeds per level make learning transferable across attempts (Souls/Meat Boy style), and a dry-up resets only the map, not coins.
- Perfect-run-based budgets guarantee beatability; nothing is luck-only.
- A new skin per cleared level plus run timer/records is a reward cadence every 10 s - 3 min of play, as frequent as Brotato's per-wave shop beat.
- Leniency exists already: `LANE_PULL` lane centering, `CORNER_LEEWAY` for leaps (Celeste-style forgiveness).

### 2.3 Risks / pain points found

1. Retry friction (about 3 s + button) vs a 10-45 s perfect run.
2. Level 1 is silent: the only teaching is the title card; a new player has to discover that moving costs slime, that the chalice is the goal and that Space leaps.
3. The final 3-4 levels demand near-perfect memory of a route the player has never been told (target 94-99% with only the trail's dim memory; max upgrades are essentially mandatory), a difficulty cliff versus the previous curve, with a +6 point step every level and no rest beat. This is by design ("level 10 needs a perfect run without upgrades"), but there is no flow-valve for a stuck player.
4. Dead-end quality: stubs dominate, so a wrong turn costs little information and little slime; the "risk" half of the coin loop is weaker than it looks, and deep false trails (the real cost) are rare.
5. Leap barely used on the critical path.
6. Randomizer retry discards learning; docs and code disagree.
7. Landmarks: every corridor is one tile wide and walls vary mostly by damage level, so after the 9 s fade there is nothing to say "I was here."

---

## 3. Ranked recommendations (impact vs effort)

Impact ratings: Very high / High / Medium. Effort: S (under half a day), M (1-2 days), L (several days). All keep 320x180 integer scaling, no run-time-indexed arrays in shaders, web build light.

### 1. Make retrying nearly instant (S, Very high)
- **Evidence**: Super Meat Boy (near-instant respawn, "keep levels short" **[fetched]**), Spelunky quick restart **[fetched]**, Minit (cost of failure = one minute) **[fetched]**.
- **Change**: shorten dry-up to about 0.9 s total (`END_DELAY` 2.0 -> about 0.8, `CHOICE_DELAY` 0.6 -> about 0.2 for dry-ups only; keep long delays for wins). Make the focused default button RESTART so Space/Enter/R retries in one press. Allow R mid-run to restart immediately when the player is not holding unspent coins or has already used the prompt before; keep the confirm prompt otherwise (the UPGRADES shortcut still matters). Keep the goo wipe (it already eases in).
- **Files**: `scripts/game.gd` (`END_DELAY`, `CHOICE_DELAY`, `_finish`, `_unhandled_input`), `scripts/ui/restart_prompt.gd`, `scripts/hud.gd` (`show_choices`).
- **Risks**: accidental restart (mitigate with a 0.3 s hold of R mid-run); tests that await the old delays (`test_next_steps.gd`, `test_phase5.gd`, `test_rainbow.gd`). Hard mode records unaffected.

### 2. First-launch path straight into Level 1 (S, Very high)
- **Evidence**: Short Hike scope/immediacy **[fetched]**, Celeste/SMB first screen is play, roguelite guidance to stage systems through unlocks **[search]**.
- **Change**: on a fresh save, the title's primary button starts Level 1 directly ("PLAY"); the hub (skins, hats, wheel, upgrades, randomizer portal) is introduced after the first chalice, e.g. "ENTER THE HUB" appears or flashes after L1 clear. Returning players keep the current title.
- **Files**: `scripts/ui/title.gd`, `scripts/progress.gd` (flag derived from `levels_cleared == 0`), `scripts/hub.gd` only if you want a first-visit pointer.
- **Risks**: users with existing saves unaffected; the hub's charm is part of the product, so keep it one button away on the title; tests that start from the title.

### 3. Silent teaching in Level 1 and Level 2 (M, Very high)
- **Evidence**: Mario 1-1 placement-as-lesson **[search]**, Baba Is You one-idea levels **[fetched]**, Donut County one gimmick per level **[fetched]**, Super Meat Boy "goal always in sight" **[fetched]**.
- **Change** (no text):
  - L1: the chalice is visible from the start through the fog (gold glow bloom), or its reveal distance is raised to about 6-8 tiles, so the goal is known on the first screen. L2+ revert to 1.5 tiles. Teaches "reach the cup" without words.
  - Show the real input once as a pulsing key/stick glyph over the slime for the first move and fade it on first movement; likewise show a SPACE glyph when the slime stands beside a long straight (see item 9) in L1 or L2, and fade it after the first charge. Touch: reuse touch icons.
  - Let L1's first corridor start already lit with a 3-cell pre-revealed trail so the "trail reveals the map" idea lands before the player moves.
  - Make the meter react visibly to the first moves (a tick-down pulse), which shows that moving costs slime.
- **Files**: `scripts/game.gd` (`CHALICE_REVEAL_DISTANCE`, `_physics_process`, `_build_overlays`), `scripts/hud.gd` (glyph pod), `scripts/jump_guide.gd`, `scripts/progress.gd` (new `tutorial_seen` flags, saved in `_write`/`_read`).
- **Risks**: exposing the chalice early in L1 changes `test_phase1/3` expectations that the chalice starts hidden; keep the effect as a distinct "beacon" node so the existing `chalice.visible` logic and tests remain. Over-teaching harms discovery; restrict to levels 1-2 and first-time flags.

### 4. Hades-style "slime reserve" assist, not a difficulty setting (S/M, High)
- **Evidence**: Hades God Mode (+20%, +2% per death, cap 80%) **[fetched]**, Celeste Assist Mode framed as an invitation **[search]**, Brotato self-correction **[fetched]**.
- **Change**: on a story level, each consecutive dry-up on the *same* level adds a small reserve to the next attempt (suggest +2% of the meter per fail, capped at +12% or so, cleared on a win and when leaving the level). Applied by dividing `slime_cost_per_tile` (like `Upgrades.slime_factor`). HUD shows a faint "+4%" next to the meter and the gold marker never appears in records. Off in hard mode. Offer a "no assists" toggle in settings. Reserve is invisible until the second fail.
- **Files**: `scripts/game.gd` (`_apply_upgrades`, `retry`), `scripts/progress.gd` (non-saved `fail_streak`, and saved `assists_enabled`), `scripts/hud.gd`, `scripts/ui/controls.gd` (toggle).
- **Risks**: undermines "level 10 needs a perfect run." Fix by capping it so it cannot beat the target alone (e.g., never beyond +12% on a 99% level) and by not letting assisted clears set a *record* (`record_time` stays unassisted). Quiet design choice: tell the user in handoff.

### 5. Re-shape the difficulty curve into a sawtooth with a softened last step (S, High)
- **Evidence**: Celeste critique that rooms lengthen instead of varying **[fetched]**, Brotato elite/rest cadence **[fetched]**, Bycer's "tension needs matching relief" **[fetched]**.
- **Change** (data only in `Levels.DATA`): keep the overall climb but make each theme-introducing level (L4, L7 and L10) a notch gentler than a straight line and place the twist there. For example targets 0.45, 0.52, 0.58, 0.66 (new twist), 0.64 (breather), 0.72, 0.80 (twist), 0.78 (breather), 0.90, 0.97. Revisit `HARD_TARGETS` separately; hard mode is the 100% perfectionist track and need not follow this.
- **Files**: `scripts/levels.gd`, `tests/test_phase3.gd` (monotonic target and "path grows" assertions), possibly `docs/game-design.md` text.
- **Risks**: the user set the 99% L10 target intentionally; frame this as an option. Changes to targets do not touch coin keys or saves.

### 6. Pay for risk: deepen and place dead ends and coins deliberately (M, High)
- **Evidence**: Buck/Pullen on river/run **[fetched]**, "Making of Maze" dead-end rewards and junction cost **[fetched]**, Spelunky "force decisions" **[fetched]**.
- **Change**: (a) add a post-pass in `MazeGenerator.generate` that guarantees 1-3 *decoy branches* of depth >= 5 branching off the solution path in the last half (the current L5 depth-30 branch proves it feels good), (b) weight `coin_cells` toward deeper dead ends (depth >= 3) and allow at most one coin per branch, leaving stubs empty so the coin count per level is unchanged but each coin costs real slime, (c) optionally flag the deepest dead end per level as a "jackpot" holding two coins.
- **Files**: `scripts/maze_generator.gd`, `scripts/game.gd` (`coin_cells`), `tests/test_coins.gd`, `tests/test_phase3.gd` ("dead ends grow" check).
- **Risks**: **saves**. `Progress.coin_key(cell)` stores found coins by level + cell. Changing the maze (new decoys) or coin cells silently invalidates a player's collected-coin list and upgrade purchases. Version it: apply the new pass to new `Levels.DATA` fields only when `maze_version >= 2`, or keep coin selection stable by migrating the key set. At minimum, ship (b) only when old save keys are remapped or coins found are credited by count instead of cell. Treat this as the riskiest item in the report.

### 7. Give the dark places names: landmarks that survive the fade (M, High)
- **Evidence**: Spelunky recurring set pieces and Yu's note on recognisable landmarks **[fetched]**, Dark Souls "Firelink as a visible reference point" **[fetched]**, Hollow Knight diegetic signs **[fetched]**, A Short Hike landmarks pull exploration **[fetched]**.
- **Change**: per level seed, choose 4-6 junction/dead-end cells and give each a themed, high-contrast prop or tile (statue, brazier, bone pile, crystal, drip basin) that stays visible at the dimmest memory level. Reuse the existing theme/atlas pipeline (`MazeTiles.fill` already picks variants), but reduce random variant noise near landmarks so they read. Optionally let a landmark emit a slow glow that survives as a "dim memory" in the fog texture.
- **Files**: `scripts/maze_tiles.gd`, `scripts/themes.gd`, `tools/make_theme_art.py`, `assets/` atlases.
- **Risks**: art cost (10 themes); busy walls can fight the polish-research push for darker fog. Start with two or three props per theme.

### 8. A chalice cue: sound and gold glimmer through the fog (S, High)
- **Evidence**: SMB goal-in-sight **[fetched]**, Hollow Knight hum-based locating **[fetched]**, Dark Souls hub visibility **[fetched]**, Rain World's cost of total opacity **[search]**.
- **Change**: reuse `Glimmer` (`game.gd:421`): when the slime comes within about 110 px of the chalice (not path distance), add a rarer gold twinkle and a very faint rising shimmer sound, no direction. At 24 px it still reveals fully. Because L3 and L4 put the chalice spatially close to the start behind a long path, the tease becomes a good tension beat ("it is right there") without telling the route.
- **Files**: `scripts/game.gd` (`_physics_process`, `_spawn_glimmer`), `scripts/sfx.gd`, `tools/make_sounds.py`.
- **Risks**: a beacon could ruin the "hidden chalice" mood; keep it faint and distance-gated. Keep `CHALICE_REVEAL_DISTANCE` untouched so tests pass.

### 9. Leap lanes: give the skill move something to do (M, High)
- **Evidence**: Celeste's forgiveness and feel focus **[fetched]**; Pullen on "run" as an independent texture dial **[fetched]**.
- **Change**: after generation, carve 1-3 "galleries" per level from L2 on, a straight 5-8 cell corridor made by removing the interior walls of a row/column where two parallel dead-end corridors already sit nearby, and place one of the optional coins at the end. A full-power leap along it costs half the glide, so players who master charge timing gain slime; splat penalties still punish a mis-timed leap. Add the first one to L2 (leap teaching, see item 3).
- **Files**: `scripts/maze_generator.gd` (new `add_galleries(maze, rng)`), `scripts/levels.gd` (config field `galleries`), `tests/test_phase3.gd`.
- **Risks**: shortens the shortest path, so `goal_steps` and every target must be recomputed (the budget formula already derives from the path, so playtests shift automatically but "feel" shifts). Run order: generate -> add galleries -> choose goal -> compute path. Changes seeds' mazes, so the same save/coin-key caveat as item 6 applies. Only do both in one release.

### 10. Tension curve: escalate the meter's last quarter and add a relief beat (S, Medium/High)
- **Evidence**: Rain World timer anxiety **[search]**, Dome Keeper tension on the way home **[search]**, Bycer's relief argument **[fetched]**.
- **Change**: at 35% start a slow heartbeat/low pulse in the ambient bus (existing `_update_ambience`), tighten the vignette (`atmosphere.gdshader` uniform), and at 20% add the existing red pulse. After a coin pickup or when the chalice reveals, release: vignette opens and the ambient lifts for about 1.5 s. Silence the heartbeat during the dry-up.
- **Files**: `scripts/game.gd` (`_update_ambience`, `_process`), `scripts/hud.gd`, `assets/shaders/atmosphere.gdshader`, `tools/make_sounds.py`.
- **Risks**: audio fatigue on a 3-minute attempt; keep it very low in volume (user's standing preference: low, dark, faint). Don't change shader arrays (Android fix).

### 11. Echo of the last attempt on retry (M, Medium/High)
- **Evidence**: Super Meat Boy's death replay **[fetched]**, Hollow Knight retaining map progress through death **[fetched]**, "trail of tried routes" request **[search]**.
- **Change**: when retrying the *same* story level, keep a downsampled bitmask of cells the slime lit and paint them for about 2 s at the very dimmest memory level (the existing `FADE_ALPHA` last step), then let them fade out; or just mark visited dead-end mouths with a faint scratch. It teaches what you tried without handing over the map; the real map stays black.
- **Files**: `scripts/game.gd` (`_build_overlays`, `_dry_up`), `scripts/progress.gd` (in-memory only, not saved), `assets/shaders/fog.gdshader` (uses the existing packed fog image).
- **Risks**: undermines the core "map starts black" fantasy for L8-L10 if too strong; make it 1.5-2 s, only on retries, and off in hard mode.

### 12. Fix the randomizer retry rule (S, Medium)
- **Evidence**: the design doc says "dying retries the same maze"; roguelite guidance that early deaths should teach **[search]**.
- **Change**: after a dry-up offer RETRY SAME and NEW MAZE (default RETRY SAME the first time, then NEW MAZE after two fails, as a gentle rubber band). Update the dry-up text.
- **Files**: `scripts/game.gd` (`_dry_up`, `_offer_retry`, `retry`), `scripts/progress.gd` (`new_random_maze` call moves), `tests/test_rainbow.gd`.
- **Risks**: none significant; check the test that exercises the "dry-up moves on to a new random maze" flow.

### 13. Make the coin economy readable at the moment of success (S, Medium)
- **Evidence**: Hades reward-on-failure/earn-something-always **[fetched, search]**, Dome Keeper upgrade-gated early game **[search]**.
- **Change**: on the win text add "COINS 4/6" (and a fanfare tick if all found); on a dry-up show "COINS +2 KEPT." Show UPGRADES as a pulsing choice the first time the player holds >= 1 coin, so the first purchase (1+2+3 = 6 coins buys MORE SLIME level 3, +30%) happens after L1.
- **Files**: `scripts/game.gd` (`_on_chalice_body_entered`, `_dry_up`), `scripts/hud.gd`, `scripts/ui/upgrades_screen.gd`.
- **Risks**: text length in the 320x180 message panel; wins already show multiple lines (time/best/unlocks).

### 14. Add loops to late story mazes (braiding) as a seeded option (M/L, Medium)
- **Evidence**: Pullen's braid maze point (harder, no dead ends) and Dark Souls loops **[fetched]**; "post-level shortcut" idea **[fetched]**.
- **Change**: from L6 onward optionally remove 3-6% of walls, preferring spots that join two long branches, creating a shortcut for players who know the maze. `shortest_path` and `goal_steps` still hold because they use BFS after generation. Hard mode could skip it to stay tight.
- **Files**: `scripts/maze_generator.gd` (a `braid` argument, `generate` signature), `scripts/levels.gd`.
- **Risks**: invalidates coin keys and seeds (see item 6); dead-end counts drop, coin supply per level (`Levels.COINS`) is asserted to be at most the number of dead ends (`test_coins.gd`), so check that the minimum dead ends still exceed the coin counts (L1 has 11 dead ends for 6 coins; braiding may cut below that).

### 15. Gentle session structure and "one more try" hooks (S, Medium)
- **Evidence**: Vampire Survivors near-miss and meta currency **[search]**, Brotato fixed-length runs **[fetched]**, Minit **[fetched]**.
- **Change**: surface a "best %" memory per level (how close to the chalice you got: a ghost marker on the level-select tile such as "REACHED 80%"), reveal the next level's name/theme on the level-select tile as a teaser, and keep the REPLAY/NEXT/HUB trio on win. A session is naturally 10-20 minutes (3-5 levels) and each level resets to a hub exit, so avoid adding sessions-long gates.
- **Files**: `scripts/progress.gd` (`best_progress` per level), `scripts/ui/level_select.gd`.
- **Risks**: another save key (harmless; `_int` defaults).

### 16. Teach the dry-up (S, Medium)
- **Evidence**: Hades "death is progress" **[fetched]**, SMB "positive feedback on every failure" **[fetched]**.
- **Change**: the "DRIED UP" message gains a second line of one of the learnings, wordless where possible: show a small chalice icon with a "distance left" bar fill (how far along the true path you got) and the coins you kept. Hide it in hard mode.
- **Files**: `scripts/game.gd` (`_dry_up`), `scripts/hud.gd`.
- **Risks**: calculating "how far along the path" needs the player's nearest path cell; BFS data is available via `MazeGenerator.shortest_path`.

---

## 4. What I would do first (a four-step plan)

1. Items 1, 2, 12 and 13 (S, a day): faster retry, a first-launch straight into play, randomizer retry fix and coin feedback. These change feel immediately and touch no mazes or saves.
2. Items 3 and 8 (M): L1 beacon and glyph teaching, chalice shimmer. Keeps hidden-chalice mood for L3+.
3. Items 4, 5 and 10 (S/M): the assist reserve, the sawtooth targets, the tension curve. These tune flow without touching maze data.
4. Items 6, 7, 9, 14 (M/L): the maze-shape changes and landmarks, done together in a single versioned release because they change seeds and invalidate coin keys. Decide the save-migration plan before starting.

## 5. Cross-cutting guardrails

- Never change `Levels.DATA` seeds, `branching` or generator behaviour without a save plan: `Progress.coin_key` is keyed by level and cell, and upgrades are bought with those coins.
- Keep `Levels.COINS` <= dead ends per level (`tests/test_coins.gd` asserts dead-end placement).
- Any new shader work: no run-time-indexed arrays, compute dither arithmetically (the Android WebGL fix in `docs/handoff.md`).
- Keep the 320x180 integer grid: place glyphs and landmarks on whole pixels.
- Keep sounds low, dark and faint (standing user preference).
- Records and the rainbow/solid-skin unlock rules must ignore the assist (item 4) and echo (item 11).

## 6. Sources

Fetched this session (content read):
- Postmortem: Team Meat's Super Meat Boy, Game Developer: https://www.gamedeveloper.com/audio/postmortem-team-meat-s-i-super-meat-boy-i-
- McMillen on "Why So Hard?", Game Developer: https://www.gamedeveloper.com/game-platforms/-i-super-meat-boy-i-s-mcmillen-explains-why-so-hard-
- Maddy Thorson, Celeste and Forgiveness: https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html
- Game Wisdom, Celeste analysis: https://game-wisdom.com/analysis/celeste
- Design Lessons from Spelunky, Game Developer: https://www.gamedeveloper.com/design/design-lessons-from-spelunky
- Modding Spelunky's level generator (Kazemi): https://www.tinysubversions.com/2010/01/tutorial-modding-spelunkys-level-generator/index.html
- GMTK Spelunky level video, Persian adaptation: https://www.digikala.com/mag/gmtk-spelunky-levels/
- Hades God Mode explained: https://caniplaythat.com/2021/08/11/hades-god-mode-explained-by-supergiant-games
- First Person Scholar, Hades: https://www.firstpersonscholar.com/there-is-no-escape/
- SUPERJUMP, Hollow Knight map design: https://www.superjumpmagazine.com/getting-lost-by-design-in-hollow-knight/
- Road to the IGF, A Short Hike: https://www.gamedeveloper.com/disciplines/road-to-the-igf-adam-robinson-yu-s-i-a-short-hike-i-
- Road to the IGF, Baba Is You: https://www.gamedeveloper.com/disciplines/road-to-the-igf-hempuli-oy-s-i-baba-is-you-i-
- Road to the IGF, Noita: https://www.gamedeveloper.com/game-platforms/road-to-the-igf-nolla-games-i-noita-i-
- Donut County interview, Indie Games Plus: https://indiegamesplus.com/donut-county-developer-talks-about-the-nunances-of-hole-based-play/
- Brotato review (Adrian Hon): https://adrianhon.substack.com/p/brotato
- Minit, GamesBeat: https://gamesbeat.com/minit-turns-you-into-a-classic-adventurer-60-seconds-at-a-time/
- Cutting Through the Fog of Dark Souls, Game Developer: https://www.gamedeveloper.com/design/cutting-through-the-fog-of-dark-souls-part-one-
- Dark Souls 1 interconnected level design, TheGamer: https://www.thegamer.com/dark-souls-1-fromsoftwares-magnum-opus-of-interconnected-level-design/
- Jamis Buck, maze algorithm recap: https://weblog.jamisbuck.org/2011/2/7/maze-generation-algorithm-recap
- Walter Pullen, maze algorithms: http://www.astrolog.org/labyrnth/algrithm.htm
- The Making of Maze (itch.io devlog): https://itch.io/devlog/136905/article-update-the-making-of-maze.amp
- Being Lost on Purpose, mazes in video games: https://gamedevdairy.substack.com/p/being-lost-on-purpose-mazes-in-video

Search-result summaries only (not read in full): Celeste GDC 2017 level design talk listing (https://gamedeveloper.com/design/video-the-level-design-of-i-celeste-i-), Vampire Survivors coverage (https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613), Dome Keeper Steam threads (https://steamcommunity.com/app/1637320/discussions/0/3391798553498876065), Rain World reviews (https://game-wisdom.com/?p=19630), Mario 1-1 silent pedagogy lesson (https://pinnguaq.com/learn/mario-maker-level-design-basics/), Celeste Assist Mode (https://www.vice.com/en/article/celeste-difficulty-assist-mode), Loop Hero (https://en.wikipedia.org/wiki/Loop_Hero), flOw/DDA (https://en.wikipedia.org/wiki/Flow_(video_game)), Don't Starve interviews (https://game-wisdom.com/?p=3185), roguelite meta-progression guide (https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression).

Not found / blocked: Game Maker's Toolkit Spelunky transcript (amara.org returned 403), gamedev.net Spelunky XBLA entry (403), a Baba Is You tutorial-design talk (none located), a Return of the Obra Dinn onboarding devlog, any Bippinbits or Four Quarters design postmortem. For those games I rely on general knowledge only where noted and have not made load-bearing claims from them.
