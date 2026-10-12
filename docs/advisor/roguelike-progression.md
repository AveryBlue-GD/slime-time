# Roguelike / roguelite elements and progression: research and audit for Slime Time

Author: game-advisor. Read-only audit; no game code was changed. Date: 2026-10-12.
Code read: `scripts/progress.gd`, `scripts/upgrades.gd`, `scripts/hats.gd`, `scripts/levels.gd`, `scripts/maze_generator.gd`, `scripts/hub.gd`, `scripts/ui/hat_wheel.gd`, parts of `scripts/game.gd`, plus CLAUDE.md, docs/game-design.md, docs/handoff.md.

Source honesty: the GDC Vault talks (Slay the Spire "Metrics Driven Design", Dead Cells "What the F*n!?", Hades) are paywalled or returned 403, and the Hades GDC transcript fetch failed. Where a claim comes from a page I actually fetched, the URL is in the Sources list at the end. Where it came only from a search snippet or from my general knowledge, I say so inline ("general knowledge" / "secondary"). Nothing below is copied text; everything is paraphrased.

---

## 0. TL;DR

1. Slime Time already has the skeleton of a roguelite meta layer (coins, a refundable upgrade tree, skins/hats as rewards, a hub) but the economy is **closed and finite**: 165 coins = exactly the full tree, each coin is one-time, randomizer mazes and hard mode pay nothing. Once the tree is maxed (or if you only play randomizer/hard) there is **no income, no sink and no reason to return**. That is the single biggest gap, and it is exactly why the hat wheel is "dev only until a currency exists".
2. The fix is a **second, renewable, cosmetic-only currency** (working name GLOBS) earned from clean play (first clears, medals, hard clears, randomizer, a daily maze) and spent on the hat wheel and later on other cosmetics. Keep **coins** as the finite power currency. Never let globs buy power and never let coins buy hats (the genre research below is clear that power-for-grind is what players resent, while cosmetic grind is welcomed).
3. The game has **no in-run decisions** besides routing. The cheapest high-value roguelite layer is a small run-scoped choice system (dead-end shrines offering 1-of-3 small boons, usually with a trade-off) layered on the randomizer first, because randomizer mazes are already seeded, verified solvable and have no coins.
4. Everything proposed is save-compatible: new ConfigFile sections with defaults, no change to existing keys, container prefix `SLIME1-` kept. One risk to manage: an **older build re-saving a newer save drops the new sections** (details in section 5).
5. Top-ranked ideas: (1) Glob currency + priced hat wheel, (2) level medals (par time, no-splat, all coins), (3) glob pickups in randomizer mazes, (4) Daily Maze with a date-derived seed, (5) Shrines/boons, (6) Heat-style hard-mode modifiers, (7) mercy/God-Mode-style retry assist. Full ranked list of 16 in section 6.

---

## 1. What the best games do (research findings)

### 1.1 Run structure and the retry loop

- **Hades.** Death is framed as story progress, not punishment; every run feeds narrative, dialogue and permanent upgrades, and Kasavin said replayability was a foremost goal, with content that adapts to player progress. (Secondary: the amara transcript fetch 403'd; see analysis pieces in Sources; Inverse interview fetched.) The key retry-loop innovation is **God Mode**: it does not weaken enemies, it makes the player tougher, starting at 20% damage reduction and adding 2% per death up to 80%. Kasavin's stated reason: roguelikes need many deaths to reach their variety, so soften the sting without removing the loop; and he cautioned this style is tied to Hades' structure and does not copy-paste to other games.
- **Dead Cells.** Death is made bookkeeping: cells are banked at "the Collector" **between biomes**, so a run that dies before the deposit loses them, which creates a tense "bank it or push on" moment. Blueprints must be carried out of the level to keep them. Runs are short and the unlocks widen options (new weapons, routes) more than they inflate stats. (Wikipedia fetch + search snippets.) The GDC 2019 talk title and the thesis "make the player's life easier, the game feels harder but fairer" are from the GDC listing only (secondary).
- **Slay the Spire.** No stat meta-power; progression is **unlocks + knowledge** (new cards/relics/characters earned from runs, complete or failed). Per Wikipedia, it does have "elements of metaprogression" in unlock points, so the common claim "StS has none" is slightly too strong. Enemy **intents are shown**, so decisions are made with visible information and the player learns patterns across runs; the act boss is revealed at the start of each act (LessWrong review).
- **Loop Hero.** Two-layer structure: an expedition loop, and a camp you retreat to. Retreating keeps resources; dying mid-fight costs 70% of them. Per the developer interview, the camp exists so that losses are never punishing and players are not afraid to experiment. (Wikipedia + Destructoid search snippet.)
- **Vampire Survivors.** Short run, gold carried out, spent on many **small** stat bonuses that can be **fully refunded** at any time; finishing a stage at the time limit pays bonus gold; most unlocks come from small challenge goals. Power comes in many small steps, not a few big jumps. (Substack analysis + Wikipedia.) Analysis claims the cumulative bonus is roughly 2.5x damage and 2x health, yet players credit their own skill. Treat the numbers as one blogger's estimate.
- **Rogue Legacy.** Gold is forcibly spent between runs ("Charon takes it"); each manor purchase **raises every other upgrade's price**. Critics: feels like a tax late game, the benefits get minimal when costs balloon, and the fixed character strength makes runs feel less consequential (Game Wisdom, Steam threads, Game Informer snippet).
- **Brotato / Dome Keeper / Noita / Risk of Rain / Isaac / Spelunky** are mostly in-run power games (see 1.3).

**Lesson for us:** a failed attempt must yield *something* (information, a little currency, mercy), and the cheapest way is to make the *information* the progress. Our levels are fixed-seed mazes, so a second attempt already benefits from the player's own memory of the map; that is "knowledge progression" for free and is why a dry-up does not feel wasted.

### 1.2 Meta-progression versus in-run power

- Recurring community critique of heavy stat meta-progression: losing stops teaching you anything (just grind more), wins feel unearned, the baseline keeps shifting so fundamentals are hard to learn, and playtime is padded by repetition (forum synthesis; a design-blog guideline suggests keeping individual meta upgrades modest; the "+10% max" figure is that blog's rule of thumb, not a standard). The best-regarded alternative models: **Slay the Spire** (meta only teaches/unlocks), **Hades weapons** (mostly side-grades), **Balatro** (unlocks by play, stakes as the ladder).
- Defence of stat meta: it is a safety net for weaker players (Rogue Legacy 2 commenters) and rising prices reward early purchases; small, many, refundable steps feel like growth rather than grind (Vampire Survivors).
- Dome Keeper's design lead stresses strong, **noticeable** upgrades (visual/audio change, big jumps) while keeping each mechanic simple; the main critique from reviews is that low resource totals funnel everyone into the same "essential" upgrades (Shacknews snippet).

**Lesson for us:** our tree is exactly the "three obviously-good, linear stat bonuses" pattern. A fully maxed tree is a solved state (no decisions). Power should stay as is (it is capped, refundable and balanced against budgets); *new* progression should be options, cosmetics, ladders and information.

### 1.3 Upgrade / boon / relic design and synergy

- **Hades boons.** Large pool, tags that combine (duo boons, general knowledge), and Supergiant iterated boons through Early Access, replacing ones that were too niche and moving good ideas into weapon aspects ("not too precious", Kasavin; Hades 2 early-access coverage, secondary).
- **Slay the Spire relics.** Mostly random and a big source of power; the designers explicitly prioritise fun, big moments over perfect balance (LessWrong review); the GDC talk is about using metrics, and warns metrics can mislead (GDC listing).
- **Isaac.** Every floor guarantees at least one item, and each boss gives a stat item, so the character **visibly grows** each run; the combinatorial item space was hard to test and shipped under-tested (postmortem on Game Developer).
- **Risk of Rain 2.** Items stack without limit with item-specific formulas (linear, hyperbolic, hard-capped); difficulty scales with time, with a player-chosen clock speed (Drizzle 50%, Monsoon 150%). Artifacts are unlockable run modifiers. (Wikipedia + wiki snippets.)
- **Brotato.** Danger levels are a ladder unlocked by winning at the previous one; each rung is cumulative and adds structural changes (new enemies, elites/hordes, a second boss), not only stat multipliers; separate accessibility sliders (damage, HP, speed) are an orthogonal axis. (Brotato wiki fetched.)
- **Vampire Survivors.** Evolutions require a specific weapon plus a specific passive, which gives *readable* synergy goals; level-ups are frequent so a reward lands every ~20 s rather than every few minutes (Substack analysis, secondary).
- **Noita.** Between-biome "Holy Mountain" shops where you edit wands and choose perks; reroll for money was added later; persistent progress is unlocks and knowledge, not stats (Wikipedia + wiki snippets).

**Lesson for us:** a boon system only needs ~8-12 well-differentiated boons to start producing "build" feelings, *if* each one interacts with a core verb. Our verbs are: glide cost, leap (charge jump), trail/light reach, fog fade, coins. Boons should hook those verbs (see idea 5).

### 1.4 Randomness versus fairness, and seeds

- **Spelunky.** Each level is generated from a 4x4 grid of hand-made room templates linked by a **guaranteed critical path** that never needs bombs/ropes; the rest of the level is random. Yu is quoted (in a design analysis) as trying to "limit the luck involved" at high level. The same analysis argues dark levels with unseen hazards are the one place randomness reads as unfair (Game Developer analysis + GMTK summary). Daily Challenge: one shared seed, 24-hour rollover, one attempt, leaderboard, and the shop gambling wheel is locked so luck cannot skew scores (Spelunky wiki snippet).
- **Slay the Spire.** Rare-card odds use a counter that starts at -5%, rises 1% per common rolled, resets on a rare, and caps at +40%; the first floor of each act never offers a rare (wiki, secondary). That is a textbook **soft pity timer**: variance is real but bounded.
- **Dailies.** "Shared seed + 24-hour rollover" is the near-universal rule. Design variants: one attempt (higher stakes, rewards players who value each life) versus unlimited attempts (puzzle-like, welcoming, easier to exploit via videos). Dead Cells' daily needs milestone progress and pays blueprints for the 1st, 5th and 10th daily; Slay the Spire cut its daily modifiers from 4 to 3 because combos became unwinnable (The 24-hour ticket, Game Developer; search snippets for the specifics).
- **Implementation (relevant to Godot):** make the run depend on one integer seed and a dedicated `RandomNumberGenerator`; one stray global `randi()` or a clock read breaks determinism. Daily seed from the date, share code = the seed, no server required (solodevstack article).

**Lesson for us:** the maze generator already takes `maze_seed` and builds a verified spanning tree, so our fairness invariant is built in: *a perfect glide always fits the budget, because the budget comes from the true shortest path*. Any new randomness (boons, glob placement) must (a) use its own RNG derived from the maze seed so existing mazes and coin placements do not change, and (b) never break "perfect play wins with zero boons".

### 1.5 Currencies, sinks and unlock pacing

- **Hades** splits currency by purpose: Darkness (Mirror talents, permanent power), Chthonic Keys (unlock gates and talent tiers; the Mirror tiers cost 5, 10, 20, 30 keys per pair of talents; resetting the Mirror costs just one key, so experimenting is cheap), Nectar (keepsakes / relationships), Gemstones and Diamonds (House renovations, many purely cosmetic, some very expensive). Guides advise not taking gem rewards when only cosmetic renovations remain, which shows the cosmetic sink is a *lower-priority, optional* tier, not the main motivator. The Mirror opens only after the first boss and starts with one free point (general guide sources, secondary).
- **Enter the Gungeon.** Hegemony Credits are earned mostly from **bosses** (doubled for a no-damage kill), and spent in a hub shop to add items to the future pool; the whole shop catalogue costs ~1,800 credits; stock rotates once a row is bought out (wiki, secondary). Notable: the best source is *mastery* (flawless boss), not time spent.
- **Dead Cells** gates daily runs and Boss Stem Cell ladders behind progress (Wikipedia + wiki snippets).
- **Vampire Survivors**: refundable stat purchases, escalating price per rank (10% of base per rank per one snippet), extra level-ups past maxed items pay gold.
- **Pitfalls:** price escalation as "tax" (Rogue Legacy), forced spending of leftovers (Rogue Legacy), cosmetic-only leftovers being low-value (Hades gems), time-sink framing of grind.

**Lesson for us:** use one currency per *purpose*. We have coins (power, finite, refundable). Add one for cosmetics/collection (renewable). Use pity-style protection for the rare hat. Keep prices flat (no Rogue Legacy tax).

### 1.6 Hub design

- Hades' House is where unlocks, NPC relationships, weapon swaps and cosmetics live; the Mirror is the *first* hub object to unlock, after the first boss. Loop Hero's camp and Dead Cells' Collector/Tube similarly make the between-run space a place with visible, tangible changes. Gungeon's Breach shows purchases as *new stock on shelves*.
- Our hub (round rotating room, stations around the rim) already has the structure; it lacks (a) visible *state change* from progress (the room never looks different), and (b) a reason to stop at 4 of the 8 stations.

### 1.7 Cosmetics as reward

- Hades renovations and Dead Cells skins are tied to currencies earned late or through challenge; cosmetics are safest as a **sink for surplus currency** and a **trophy for mastery** (Hades Heat unlocks decorative items, per Wikipedia). Our game already does this well: skins unlock per level, solid versions per hard clear, rainbow per all coins, hats per wheel.

### 1.8 Risk/reward choices

- Darkest Dungeon (secondary, forum-sourced): the **torch level is a dial**: dimmer means more loot per curio but more surprise, stress and enemy accuracy; the dial can be changed mid-run and is used tactically (snuff it after a fight). This maps almost perfectly onto our fog/light-reach mechanic (see idea 7).
- Dome Keeper: the timer vs. greed tension (how much to carry, where to dig) is the core; reviewers complain only about low variety later.
- Spelunky: "much more risk than reward in nearly every inch" and powerups reduce risk (design analysis).
- Loop Hero: retreat-or-continue decision with a 70% loss on death.

### 1.9 Hard modes

- **Stackable budget** (Hades Pact of Punishment / Heat: 15 modifiers, each with ranks costing 1-3 heat; each heat point gives another chance at rare resources; unlocked after the first win; a guide advises raising heat one point at a time so tier rewards are not skipped).
- **Ordered ladders** (Slay the Spire Ascension up to 20, cumulative; Brotato Danger 0-5 + Nightmare, cumulative and unlocked by winning on the previous; Monster Train covenants 25 levels; Balatro stakes per deck).
- **Orthogonal assist sliders** (Brotato; Rogue Legacy 2 House Rules; Hades God Mode).
- Pitfalls: top rungs becoming gatekeeping; "challenge" that is just the AI cheating (Monster Train thread, one player's view); stacked modifiers creating unwinnable combos (StS Daily cut modifier count).

### 1.10 Death/retry, achievements, replay value

- **Near-miss and "one more run"** (Vampire Survivors, researcher commentary in The Conversation, secondary): a failed run that was close to the next unlock is the engine. Our dry-up "restart" is instant already (good).
- **Achievements** as side-objectives that make players sample everything (VS analysis).
- **Replay** comes from: seeds/dailies, difficulty ladders, mastery rewards (par times / flawless kills), and unlock horizons beyond the ending (Isaac's post-ending chapter).

---

## 2. Audit of Slime Time (what exists today)

| Area | Current state | Roguelite verdict |
|---|---|---|
| Run structure | One fixed-seed maze per story level (10); randomizer = fresh noise maze per win; dry-up restarts the same maze. | Fixed-seed levels = learnable puzzle (good, fair). No in-run choices at all. |
| In-run economy | Slime meter (budget derived from the true shortest path; level targets 45% to 99%); leap costs; coins at dead ends (seeded pick). | Strong risk/reward already: a detour for a coin spends meter. No pickups other than coins. |
| Meta currency | Coins: 6,9,7,12,14,17,20,22,27,31 = 165 = `Upgrades.full_tree_cost()`. `Progress.coins()` = found - spent. | **Closed.** Maxed after full coin completion. Zero income afterwards. |
| Upgrades | Slime (+10%/lvl), Speed (+5%/lvl), Brightness (+2.5px reach/lvl); level n costs n; 10 levels; refundable; dev-only wall power. | Linear stats, 3 obvious picks, no choice once maxed. Refundability is a strength (matches VS). |
| Randomizer | Opens after level 10; seeded, noise maze, 0.85 target, no coins, `randoms_won` counter only. | Infinite content with **zero reward** other than a counter. Biggest wasted asset. |
| Hard mode | Bool; own seeds (`HARD_SEEDS`), targets 0.89-1.00, no upgrades, no coins, own records, clears unlock solid skins. | A single rung. Rewards are cosmetic-only, which is fine, but there is no gradient and no currency income. |
| Hats | 11 placeholder hats, wheel removes won hats (sampling without replacement), rainbow weight 0.3; `Hats.available=false`, `can_spin_hats()` = dev only. | Great mechanic, no faucet. |
| Skins | Per-level unlocks, rainbow by all coins, solid by hard clears, custom after level 10. | Strong cosmetic ladder, already tied to mastery. |
| Records | `best_times` per level and per mode (+100 offset). | Records exist but pay nothing and have no target (no par). |
| Hub | 8 stations incl. coin board (per-level coin counts). | No visible state change; no medal/completion screen beyond coins. |
| Save | `ConfigFile` sections with type-safe readers (`_int/_float/_bool/_strings/_ints`), save code `SLIME1-` + gzip base64 of the whole file, max 65,536 chars; `reset_progress()`; tests/tools start from fresh defaults. | Forward-friendly. See section 5. |

### Concrete findings

1. **Closed coin economy.** `Levels.COINS` total 165 equals the tree cost on purpose (nice puzzle: collect all to max). But it means coins cannot be the hat-wheel currency: a hat price in coins would compete with upgrades (players would feel punished) or require inflating coin counts (breaks the exact 165 identity and the rainbow-skin rule "every coin found").
2. **Randomizer and hard mode have no payoff loop.** Both are the game's replay content; neither pays anything.
3. **No decisions after the first minute.** After the player learns glide/leap, the only choices are route and whether to detour for a coin.
4. **Upgrade tree is a solved state.** 3 x 10 levels, costs linear, no trade-offs.
5. **Dry-up pays nothing but also costs nothing** (coins saved the moment they are grabbed, which is already the Dead Cells/Loop Hero "keep what you earned" principle). Good. But repeated deaths on level 8-10 (targets 88-99%) have no mercy valve; the only mercy is upgrades and the game's own tuning. Hades God Mode shows a pattern that suits a puzzle-ish game.
6. **Hat wheel mechanics are better than most gacha**: removal from pool means n spins to complete n hats (no duplicates), and the rainbow hat's weight 0.3 is a rare sliver. What is missing is only the currency and a pity rule so the last/rare hat does not feel scripted or tail-random.
7. **Mastery rewards exist as numbers** (best times) but have no thresholds, so there is nothing to chase beyond "faster than yourself".

---

## 3. Design principles that fit a dark maze/slime-meter game

1. **Fairness invariant:** with zero boons and zero upgrades, a perfect run is possible (the generator + budget already guarantees this on story levels with upgrades available, and randomizer verifies completability). Never add a mechanic that removes this.
2. **Power is finite and legible; cosmetics are renewable.** Coins = power, Globs = cosmetics/collection.
3. **Mastery pays, time-sink does not.** Faucets reward first clears, par times, no-splat, all-coins and hard clears, not minutes played.
4. **Information is progress.** Fixed mazes + fog mean memory is already the best upgrade. Do not add a "map reveal" meta upgrade that cheapens that.
5. **Seed discipline.** Every new random decision uses an RNG derived from `maze_seed` (for example `maze_seed ^ 0x...`) so shrine/glob placement is stable across retries of the same maze and existing level layouts and coin cells do not change.
6. **Light is the dial.** Our unique lever is how much of the maze you can see (fade timing, reach). Use it as the difficulty and reward dial (Darkest Dungeon torch precedent).
7. **Respect the platform:** no new shaders with run-time-indexed arrays; new art is 16x16 / 12x12 sprites; everything works at 320x180; web export size untouched (no big assets).

---

## 4. Currency design for the hat wheel

### 4.1 Proposal: GLOBS (cosmetic currency)

- **Name/fiction:** GLOBS (alternatives: GOOP, DROPS). A glob is a bead of crystallized goo. UI icon: a small blob distinct from the slime-meter drop icon and the round coins.
- **Where they come from (faucets).** All amounts are initial numbers to tune; each one-time award is keyed in the save so it cannot be farmed.

| Source | Amount | Repeatable? | Notes |
|---|---|---|---|
| First clear of story level N (normal) | +4 | once per level | 10 levels = 40 |
| Medal: PAR TIME | +2 | once per level per mode | par = shortest path at base speed x 1.25 (computed from the real shortest path, not hand-tuned) |
| Medal: CLEAN (no wall splat) | +2 | once | |
| Medal: ALL COINS in level | +2 | once | story only |
| First hard-mode clear of level N | +8 | once | 10 levels = 80 |
| Hard medals (par/clean) | +2 each | once | optional |
| Randomizer win | +2 | max 5 paid wins per day (UTC) | prevents grinding; unpaid wins still count for `randoms_won` |
| Glob pickups in randomizer mazes | 0-3 per maze | each maze | placed at dead ends like coins (idea 3) |
| Daily Maze | +6 + streak bonus (min(streak,7) x 1) | once per day | idea 4 |
| Beating a level record by >= 2% | +1 | repeatable, max once per level per day | |

  Story-only maximum (first clears + 3 medals) = 40 + 60 = 100 globs. Hard clears add 80+. Dailies add roughly 7-13 per day.

- **Price of a spin (sink):** **12 globs flat.** Reasoning: 11 hats x 12 = 132 globs to complete the wheel. A story-only completionist (100 globs, ~8 hats) gets most hats; the last few (including the rainbow hat) need hard mode, randomizer or dailies. That mirrors the Hades/Gungeon pattern that mastery content funds the endgame collection.
- **First spin is free** (one-time grant when level 2 is cleared, or on first hub visit after level 2). This teaches the wheel, as the Mirror's free first point does in Hades.
- **No escalating price.** Rogue Legacy's rising prices read as a tax. Flat price + shrinking pool + visible progress ("HATS 4/11") is cleaner.
- **Pity for the rainbow hat.** Currently `Hats.weight("rainbow") = 0.3` against 1.0 for others. Add a counter `spins_since_rainbow` that raises the rainbow weight by +0.15 per spin missed (soft pity, Slay the Spire precedent) and guarantees it on the last remaining spin if it is the only hat left (naturally true with removal). Store as `[hats] rainbow_pity`.
- **Duplicates:** impossible (removal), so no duplicate currency is needed. After the wheel is empty, the wheel becomes a **tailor**: spend globs on hat dyes (palette-swap shader, same one as skins, no run-time-indexed arrays) or the other cosmetic sinks in idea 9. That gives globs a permanent purpose and a use for surplus.
- **Never convert coins to globs or vice versa.** Keeps the "every coin found" identity and the rainbow-skin rule intact.
- **Atomic spin.** Move the pick and the payment into `Progress` (for example `spin_hat() -> String`): choose the hat, spend globs, call `win_hat(id)` and save **before** the animation starts, then animate to the chosen wedge. This prevents "paid but lost the hat" on a crash/tab close and keeps `HatWheel._pick` out of save logic. `HatWheel.spin()` currently decides inside the node (`scripts/ui/hat_wheel.gd` line ~125) and `can_spin_hats()` is dev-only (`scripts/progress.gd`).
- **Transparency in UI:** show the price and the balance on the wheel prompt and in the hat-wheel hint line (`refresh()` currently prints "SPINS COMING SOON"), plus odds (the wedges already show size = odds).
- **Dev mode:** keep `dev_tools` spins free, and give dev mode a pile of globs the same way `DEV_COINS` works.

### 4.2 Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| Spend coins on spins | Zero new systems | Competes with upgrades; finite 165 | Reject |
| Time-based free spin (daily) | Cheap, habit-forming | Pure time-sink; no mastery tie | Use only as part of Daily Maze |
| Medals only, no currency | Simplest | Hats become a checklist; no sink for later cosmetics | Medals feed the currency instead |
| Currency from slime left over at the chalice | Natural fit | Rewards over-upgrading (leftover scales with upgrades) | Reject as primary; maybe CLEAN medal only |

### 4.3 Pacing walkthrough (target player experience)

- Level 1-2 clear: first free spin; the hub wheel suddenly "ticks" in its idle animation, a station prompt says "FREE SPIN".
- Levels 3-6: first-clear + CLEAN medals fill 12 globs every ~2 levels: a new hat every couple of levels.
- Level 10 clear (about 100 globs): ~8 hats; randomizer unlocks and starts paying; hard mode becomes the way to finish the wheel.
- Late game: daily maze + glob pickups in randomizer mazes + hard medals; surplus goes to dyes/trails/decor.

---

## 5. Save-compatibility plan (applies to all ideas)

Current mechanics worth preserving:
- `_read()` uses type-safe readers and defaults, so **missing keys are harmless**; unknown keys/sections in a file are ignored. Old saves therefore load into new builds with all new fields at defaults.
- Save codes are `SLIME1-` + gzip(base64 of the ConfigFile text); `read_code` requires only `has_section("progress")`. Adding sections does not change the container.
- Code length cap: `MAX_SAVE_CODE_LENGTH := 65536` base64 chars. The current save is a few KB. **Do not store replays/ghosts/long arrays in the save**; put anything large in a separate file (for example `user://ghosts/`), otherwise the save code can exceed the cap.
- `reset_progress()` must clear every new field.
- Tests/tools start from fresh defaults (`_is_test_or_tool_run`); new tests should follow `tests/test_coins.gd`, `tests/test_hats.gd`, `tests/test_save_code.gd`.

Recommended additions:

```
[meta]      version = 2                 ; new; lets future migrations key off it (absent = 1)
[wallet]    globs = 0                   ; spendable balance
            globs_lifetime = 0          ; stat only
[hats]      owned = [...]               ; already exists
            rainbow_pity = 0            ; spins since last rainbow roll
            spins = 0                   ; stat
[medals]    level_1 = 0b111 ... level_10     ; bitmask per level, normal mode: par=1, clean=2, coins=4
            hard_level_1 ...                  ; same for hard mode (or level_101...)
[daily]     last_date = "2026-10-12"    ; UTC date of last claim
            streak = 3
            best_time = 91.4            ; for the current day
            claimed_seeds = []          ; cap length (e.g. last 14)
[stats]     leaps = 0, splats = 0, drys = 0, mazes = 0 ...   ; achievements
[ach]       unlocked = ["first_chalice", ...]
```

Risks and rules:
1. **Old build, new save.** A player opens the new save in an older build (for example an old itch web build or the Windows build that is still v2.2): `_read` ignores new sections, then the next `save_progress()` rewrites the file **without** them, silently deleting globs/medals. Mitigations: write `[meta] version`; in `_read`, if `version > SAVE_VERSION`, set a flag that stops the *old* build from overwriting? (cannot, old code is old). So the only real mitigation is process: ship the new web/Windows builds together, and mention save codes as the backup path (a code from the new build is safe to keep). Low risk because the game is a single-dev itch release.
2. **Balance derivation vs stored balance.** Coins are derived (found - spent), which is why refunds work. Globs are spent irreversibly (hat ownership is the proof), so store the **balance** and **lifetime** explicitly; derive nothing from `hats_owned` (the hat price can change later).
3. **Keyed one-time awards.** Medals bitmask and `first_clear` rely on `levels_cleared`/`hard_cleared` which already exist; do not pay the "first clear" bonus retroactively to existing players without telling them. Option: a one-time **retro grant** on first load of v2: `if version < 2: globs += 4 * levels_cleared + 8 * hard_cleared.size()` so existing players are not penalised. Mark `version = 2` after.
4. **Daily date logic:** use UTC (`Time.get_datetime_dict_from_system(true)`); store the date string; clamp clock tampering (a save code is already hand-editable, so do not treat daily as anti-cheat).
5. **Keep `coins_earned()`** exactly as is (it drives the rainbow skin and `Levels.COINS` min()).
6. **Readers:** add `_int/_strings/_ints` loaders for each new key; clamp bitmasks to 0-7; clamp `globs` to 0-99,999.

---

## 6. Ranked ideas (impact vs effort)

Effort: S = under a day, M = 1-3 days, L = a week or more. Impact is the expected improvement in retention/depth for the amount of work. Ranked best first.

| # | Idea | Effort | Impact | Why it fits |
|---|---|---|---|---|
| 1 | GLOBS currency + priced hat wheel (with pity and free first spin) | M | Very high | Unblocks the wheel, gives all other modes a payout |
| 2 | Level MEDALS: PAR TIME, CLEAN (no splat), ALL COINS | S-M | High | Mastery goals on existing content; feeds globs |
| 3 | Glob pickups in randomizer mazes (seeded, dead ends, glimmers) | S-M | High | Gives randomizer an income and a real risk/reward detour |
| 4 | DAILY MAZE (date-derived seed, one ranked attempt, streak) | M | High | Zero server; reuses randomizer; retention hook |
| 5 | SHRINES: 1-of-3 run-scoped boons in dead ends (randomizer first) | L | High | The missing in-run decision layer; no save impact |
| 6 | HEAT / "Fog Pact" modifiers layered on hard mode | M | High | Turns binary hard mode into a ladder with reward scaling |
| 7 | Mercy valve ("THIRST MERCY"): +2% budget per consecutive dry-up, cap +10%, opt-out | S | Med-High | God Mode precedent; protects levels 8-10 |
| 8 | Achievements + stat counters ("SLIME JOURNAL") | M | Medium | Sampling goals; feeds medals/globs |
| 9 | Cosmetic sinks beyond hats: trail styles, chalice skins, hat dyes, hub decor | M | Medium | Long-term sink for globs; uses existing palette shader |
| 10 | Seed codes for randomizer (display, share, enter) | S | Medium | Spelunky-style sharing; seeds already exist |
| 11 | MIRROR mazes (flip/rotate story mazes) as a replay tier | M | Medium | Cheap fresh learning on the 10 authored levels |
| 12 | Charms (equip 1-2 side-grade perks, unlocked by achievements) | M | Medium | Choice without power creep |
| 13 | "Sniff": active ping that costs meter (arrow to nearest coin/chalice for 2 s) | S-M | Medium | Pay-with-the-resource risk/reward |
| 14 | THE DESCENT: chained random mazes, shared meter carry-over, retreat-or-continue | L | High (late) | The true roguelike mode; depends on 5 and 3 |
| 15 | Light dial: voluntary "dim lantern" for a glob bonus (change mid-run) | M | Medium | Darkest Dungeon torch precedent on our core mechanic |
| 16 | Ghost replay of best time (stored outside the save) | L | Medium-low | Mastery chase; costs storage/complexity |

Details per idea follow. "Files" lists the expected touch points; "Save" lists new keys.

### 1. GLOBS currency + priced hat wheel (M, #1)

- **What:** section 4. Progress holds `globs`; `SPIN_COST := 12`; `can_spin_hats()` becomes `dev_tools or (globs >= SPIN_COST and not hats_left().is_empty() and Hats.available)`. Spin chooses with pity-adjusted weights, deducts, calls `win_hat`, saves; the wheel animates to the chosen hat.
- **Files:** `scripts/progress.gd` (wallet, `add_globs`, `spend_globs`, `spin_hat`, `reset_progress`, `_read/_write`), `scripts/hats.gd` (weights/pity), `scripts/ui/hat_wheel.gd` (price text, ask Progress for the result), `scripts/hub.gd` (`open_hat_wheel`, coin board gets a GLOBS line, prompt text), `scripts/hud.gd` or the end-of-level message (show "+4 GLOBS"), `tools/make_coins.py` or UI art tool (glob icon), tests: new `tests/test_globs.gd`, update `tests/test_hats.gd`, `tests/test_hub.gd`, `tests/test_save_code.gd`.
- **Save:** `[wallet] globs, globs_lifetime`, `[hats] rainbow_pity, spins`, `[meta] version`.
- **Risks:** hats are placeholders (`Hats.available=false`): ship the currency behind the same flag so players do not earn toward unusable hats (or show "COMING SOON" but still accrue globs, which is friendlier). Economy numbers need a playthrough tuning pass. Retro grant must be explained.

### 2. Level medals (S-M, #2)

- **What:** three optional objectives per level and per mode: PAR (finish within par seconds, par derived from the shortest path length and base glide speed), CLEAN (no wall splat), COINS (every coin in that level, story only). Show 3 pips on the level select and in the hub coin board; a medal pays globs once.
- **Why:** Gungeon's best faucet is mastery (flawless boss kills); our records already track time. Gives hard mode and replays targets without touching difficulty.
- **Files:** `scripts/progress.gd` (medal bitmask, award on `complete_level`), `scripts/game.gd` (count splats: `_on_jump_landed` already knows `hit_wall`; run timer `run_time` exists), `scripts/hud.gd` (end banner, existing NEW RECORD banner is the template), `scripts/ui/level_select.gd`, `scripts/hub.gd` coin board, `scripts/levels.gd` (par helper), tests: extend `tests/test_records.gd`.
- **Save:** `[medals] level_N = 0..7`, hard separate.
- **Risks:** par must be reachable at base stats on all 10 levels and not require upgrades (speed upgrade should not be mandatory); test it like the existing solvability test. Splat count must not count wall-power dev splats.

### 3. Glob pickups in randomizer mazes (S-M, #3)

- **What:** randomizer mazes get 1-3 globs at dead ends chosen from an RNG derived from the maze seed (so retries of the same maze are stable and "NEW MAZE" yields fresh placements). They reuse `Coin` (a new variant row/colour) and the existing glimmer system (`game.gd _spawn_glimmer`), so a glob far away sparkles through the fog. They are collected into a per-run counter and banked on **win** only (or banked immediately but halved if you dry up, Loop Hero style: keep 70%? simpler: banked on win).
- **Why:** the randomizer finally pays; each glob is a pure meter-for-reward detour, the game's core tension.
- **Files:** `scripts/game.gd` (`coin_cells`, `_place_coins`, `_pick_up_coins` generalised to a "pickup kind"), `scripts/coin.gd`, `assets/sprites/coins.png` via `tools/make_coins.py`, `scripts/hud.gd` (pod shows globs in randomizer, where the coins pod is currently hidden), `scripts/progress.gd`.
- **Save:** none beyond the wallet (pickups are per run, not persisted).
- **Risks:** randomizer budget target is 0.85; detours must be affordable but tempting. Keep globs off the shortest path (dead ends only) and cap at 3; check the solvability test still holds (pickups are optional). Do not use global `randf()`; derive `RandomNumberGenerator` from `config.seed`.

### 4. Daily Maze (M, #4)

- **What:** a button in the hub's portal (RANDOMIZER) or the title: today's UTC date -> integer seed -> `Levels.random_config(seed, hard)`, same maze for everyone. Rules: **first attempt of the day is ranked** (Cruel Dungeon style: practice afterwards, but only the first counts), scored by clear time and leftover meter; local best + streak; no server. Reward: globs + streak bonus + a daily medal. Optional: share string "DAILY 2026-10-12 1:31.4" and later a hosted leaderboard.
- **Why:** shared seeds make comparison fair (Spelunky), dailies give a reason to return (Dead Cells reports ~7,000 daily runs per day per the Game Developer article), and the infra is mostly in place (`Progress.random_seed`, deterministic generator).
- **Determinism check (important):** `generate_noise` uses `FastNoiseLite` plus `RandomNumberGenerator`. Same engine version gives the same result on the same platform; verify **web vs desktop** produce the same maze for the same seed by hashing the maze `walls` array in a headless test on both. If they differ, fall back to the non-noise `generate` (pure RNG) for dailies.
- **Files:** `scripts/progress.gd` (daily state, UTC date helper, `start_daily()`), `scripts/levels.gd` (`random_config`), `scripts/ui/*` (hub station text, a small result panel), `scripts/hub.gd` (`_use` for the portal), `scripts/game.gd` (mode flag `MODE_DAILY` alongside story/random, no regenerate-on-win), tests: `tests/test_daily.gd`.
- **Save:** `[daily] last_date, streak, best_time, claimed...`.
- **Risks:** clock tampering is not a concern (single player, no server), time zones (use UTC and show "NEXT IN 5H 12M"), and reusing the Randomizer's themes selection `Themes.for_seed` is deterministic already.

### 5. Shrines and boons (L, #5)

- **What:** 1-2 **shrines** per randomizer maze (later also some story levels, replacing a few coin dead ends is NOT recommended: keep the 165 identity): touching one pauses and offers 1 of 3 boons for the rest of the run. About 10 starter boons hooking our verbs:
  - GLIDE: "Slick Soles" (-8% meter per tile), "Sticky Feet" (reach +10px but speed -5%), "Thirsty Gains" (+20% speed, +10% meter cost).
  - LEAP: "Springy" (landing cost -25%), "Cushion" (splat penalty -50% but stun +0.2 s), "Bomb Leap" (splat damages walls; dev wall power becomes a real boon).
  - LIGHT/FOG: "Lantern Oil" (+reach, light fades slower), "Moth Memory" (explored areas never fade fully, trade: costs 3% meter), "Echo" (chalice pings once).
  - COINS/GLOBS: "Magpie" (glimmers reach farther), "Greed" (+1 glob per pickup, -5% meter).
  - Boons are **trade-offs** wherever possible (Darkest Dungeon / Brotato lesson: pure buffs collapse variety).
  - Offers are seeded from the maze seed + shrine cell, so retrying the same maze shows the same three choices (no save-scum, no luck variance on retries; Slay the Spire daily precedent). Optional reroll for 1 glob (Hades keys / Noita reroll precedent).
- **Fairness:** boons are run-scoped and the budget still derives from the shortest path, so skipping every shrine is always viable.
- **Files:** new `scripts/boons.gd` (data + stat modifiers, like `Upgrades`), `scripts/game.gd` (`_apply_upgrades` already multiplies cost/speed/reach; add a `boons` dictionary applied after upgrades), `scripts/hud.gd` (icons of held boons), a new `scenes/shrine` or `scripts/shrine.gd` (like `Coin`), `assets/sprites/shrine.png` via a new `tools/make_shrines.py`, pause menu listing boons, tests: `tests/test_boons.gd`.
- **Save:** none required (run state not persisted). Optionally a "boons seen" list for a journal.
- **Risks:** biggest tuning risk: boon stacking on the already-tuned budget math in `_apply_upgrades` (line ~757). Keep each boon small and make Heat/hard mode disable boons or give them different weights. Combinatorial testing: keep the first release to ~8 boons and no stacking duplicates (Isaac postmortem warning).

### 6. Heat / "Fog Pact" modifiers for hard mode (M, #6)

- **What:** keep the existing `hard_mode` bool as the preset for Heat 5 for save compatibility; add an optional modifier panel on the level select: pick any of ~6 modifiers (each with 1-3 ranks and a heat cost): FOG FADES FASTER (changes `FADE_AFTER` scale), THIRSTY (+X% cost per tile), NARROW TRAIL (`TRAIL_RADIUS`-), FEWER GLIMMERS, NO LEAP COST DISCOUNT, STINGY CHALICE (hide chalice reveal distance), SHORTER LIGHT. Heat sums to a number; globs/medals scale by tier (for example +25% per 5 heat), exactly one decision to make before each run (Hades Pact precedent). Unlock after the first level-10 clear.
- **Why:** hard mode today is a single rung; Brotato's cumulative ladders and Hades' stackable heat both extend replay value without new content. It also uses the dial that is unique to us: how much of the maze you can see.
- **Files:** `scripts/progress.gd` (heat selection saved; `hard_mode` kept), `scripts/levels.gd` (budget scaling per heat), `scripts/game.gd` (constants become instance values), `scripts/ui/level_select.gd` (panel), `shaders/fog.gdshader` uniforms if fade is changed (no arrays needed: scale the existing fade times), tests: extend `tests/test_hard_mode.gd`.
- **Save:** `[heat] picks = {id: rank}`, `[medals]` hard keys; existing `hard_mode`, `hard_cleared`, `best_times` (+100 offset) untouched. Records for heat runs should be separate keys (for example +200) to avoid mixing.
- **Risks:** stacked modifiers can produce unwinnable combos (StS Daily modifier cut). Add a solvability gate: Heat cost is capped so the effective budget never exceeds 100% of the shortest path (reuse the existing hard target math: `HARD_TARGETS` up to 1.0 already means a perfect run uses all of the meter).

### 7. Mercy valve ("THIRST MERCY") (S, #7)

- **What:** after each consecutive dry-up on the same level, quietly add +2% to the starting meter, up to +10%, reset on win or when leaving the level. It is visible (a small "+4% MERCY" tag in the HUD, off switch in settings) and **disabled in hard/heat/daily** so scores stay clean. Hades God Mode (20% +2% per death) is the template; the difference is that our version scales the *budget*, which is our native difficulty knob, rather than damage.
- **Why:** levels 8-10 have 88-99% targets; the worst failure mode is frustrated quitting. The earlier note on Rogue Legacy 2's House Rules shows that making players able to tune feel is welcomed.
- **Files:** `scripts/progress.gd` (non-saved `dry_streak` per level; a bool `mercy_on` saved), `scripts/game.gd` (`_apply_upgrades`/meter start), `scripts/hud.gd` tag, `scripts/ui/controls.gd` toggle, tests: `tests/test_pause_restart.gd`.
- **Save:** `[settings] mercy = true` (default true).
- **Risks:** cheapens records; exclude record-setting and medal eligibility when mercy was active that attempt, or mark the attempt as assisted.

### 8. Achievements + stat counters ("SLIME JOURNAL") (M, #8)

- 30-40 small goals: "Reach a chalice without leaping", "Win a level with under 3% meter left", "Splat 25 walls", "Find all coins in a level under 60 s", "Wear every hat", etc. Pay small globs; show in a hub station (the unused wardrobe mirror, or a new bookshelf).
- **Files:** new `scripts/achievements.gd`, `scripts/progress.gd` stats counters (`splats`, `leaps`, `drys`, `mazes`), hooks in `game.gd` (`_on_jump_landed`, `_dry_up`, `_on_chalice_body_entered`), UI scene, tests.
- **Save:** `[stats]`, `[ach] unlocked`.
- **Risks:** achievements must be toast-only, never blocking; counters should be capped. Danger of hollow checklist: tie each to a moment players already enjoy.

### 9. More cosmetic sinks (M, #9)

- Hat dyes (palette swap), trail styles (goo shapes/glow, using the existing trail blobs), chalice skins, hub decorations (Hades House-style renovations, changing the rotating room's look), jelly tints, footprints. Prices 15-60 globs. This is the permanent sink so globs never become dead like coins.
- **Files:** `scripts/skins.gd`/`scripts/hats.gd`/`scripts/ui/skins_screen.gd`, `assets/shaders/hub_room.gdshader` (uniform tint), `tools/make_*` art generators, `scripts/progress.gd`.
- **Save:** `[cosmetics] owned = [...]`, `selected_trail`, etc.
- **Risks:** art volume; start with one category (dyes). Avoid shaders that index arrays at run time.

### 10. Seed codes for randomizer (S, #10)

- Convert `random_seed` to a short code (base32, 6-7 chars), show it on the pause menu and win screen, and add an "ENTER SEED" field next to NEW MAZE. Same system powers the Daily share string.
- **Files:** `scripts/progress.gd` (`seed_to_code`, `code_to_seed`), `scripts/ui/pause_menu.gd`, `scripts/ui/level_select.gd`, tests.
- **Save:** none.
- **Risks:** seeds from `randi_range(1, 2_000_000_000)` fit in 31 bits (6 base32 chars). Web paste issue (see handoff) applies: use the existing PASTE button pattern.

### 11. Mirror mazes (M, #11)

- A "MIRRORED" toggle (unlocked after beating level 10 or hard level N) flips the maze horizontally (or rotates 180 degrees) before tiling. Player memory of the authored level is the thing it breaks, so each of the 10 levels gets a fresh learning phase and fresh records. Coins' dead-end picks follow the flipped maze if flipped before `coin_cells`.
- **Files:** `scripts/maze_generator.gd` (a `mirror(maze)` helper), `scripts/game.gd` (apply before fill), `scripts/ui/level_select.gd`, `scripts/progress.gd`, records keys (+300).
- **Save:** `[settings] mirror`, `[records]` extra keys.
- **Risks:** tile themes and fillets assume orientation (check `MazeTiles.fill` and `add_border`); chalice/start positions swap sides (fine). Coin cell keys are saved as "x,y" cell strings, so mirrored coin positions would map to different keys: store mirror runs with their own coin key space (or do not allow coins in mirrored mode to avoid corrupting `coins_found`). Simplest: mirrored mode has no coins.

### 12. Charms (M, #12)

- Equip 1 (later 2) charm from unlocked ones: side-grades like Hades keepsakes, each with a small effect: "Lucky Penny" (shows one more coin glimmer), "Dewdrop" (first leap each level is free), "Long Memory" (fade steps +20%), "Clingy" (splat knockback -30%). Unlocked by achievements/medals, not purchased.
- **Files:** new `scripts/charms.gd`, `scripts/progress.gd` (`charms_owned`, `charm_equipped`), `scripts/ui/skins_screen.gd` or a new hub station, `game.gd` modifiers, tests.
- **Save:** `[charms] owned, equipped`.
- **Risks:** overlaps with boons; do after #5 and decide which system owns which effect.

### 13. "Sniff" ping (S-M, #13)

- Pressing a key spends ~3% meter to show a short arrow toward the chalice or the nearest uncollected coin for 2 s (cooldown 20 s; limited count per level). A pure "pay with the resource" risk/reward decision, no new currency; it also helps new or stuck players without a menu.
- **Files:** `scripts/game.gd` (new input action, drawn arrow node), `scripts/progress.gd` bindings (new action in `DEFAULT_KEYS`), `scripts/hud.gd`, touch controls button, `project.godot` input map.
- **Save:** key binding only.
- **Risks:** can trivialise the fog fantasy; make it expensive, short, directional only (no map reveal), and off in hard/heat/daily.

### 14. THE DESCENT (L, #14)

- A true roguelike run built from existing parts: 5 chained randomizer mazes of rising size, one shared slime meter that refills only partially between mazes (for example +40% of what was spent, a "slime pool" room), one shrine between mazes, a retreat-or-continue choice at each pool (retreat banks all globs; death banks 50%, the Loop Hero model). Score = depth + meter left; best depth saved. Daily seed variant for free.
- **Files:** new `scripts/descent.gd` (run state), `scripts/game.gd` (accept a carry-over meter and a boon list), `scripts/ui/*` (pool screen), `scripts/progress.gd` (best depth), tests.
- **Save:** `[descent] best_depth, runs, ...`; run state not persisted.
- **Risks:** large scope; budget tuning for a carried-over meter is new; do #3 and #5 first.

### 15. Light dial (M, #15)

- Before or during a run, toggle DIM LANTERN: your own light reach and fade timings shrink (reuse the `light_reach` and `FADE_AFTER` knobs) for a glob multiplier on that level (for example x1.5), and you can brighten it again mid-run at no cost but lose the multiplier. Borrowing Darkest Dungeon's torch idea, which uses a single dial to trade safety for yield.
- **Files:** `scripts/game.gd`, `scripts/hud.gd`, `assets/shaders/fog.gdshader` (uniform only), `scripts/progress.gd`.
- **Save:** `[settings] dim_default`.
- **Risks:** overlaps with Heat (#6); merge them: DIM LANTERN is rank 0 of the Heat panel.

### 16. Ghost replay (L, #16)

- Record best run positions at ~10 Hz, delta-encode, and store in `user://ghosts/level_N.dat` (never in `save.cfg`; the save code cap is 65,536 chars). Draw a translucent slime. Mastery chase and teaching tool.
- **Risks:** web IndexedDB storage, file format churn, little value for the effort versus medals. Defer.

---

## 7. Recommended order of work

1. **Phase A (S+M, one sprint):** #1 Glob currency and wheel pricing + #2 medals + #10 seed codes. Result: the wheel works, every level has goals, the wheel can ship as soon as hats are real.
2. **Phase B (M):** #3 glob pickups in randomizer + #4 Daily Maze + #7 mercy valve. Result: all three replay modes pay out.
3. **Phase C (M-L):** #6 Heat + #8 achievements + #9 first cosmetic sink (hat dyes).
4. **Phase D (L):** #5 shrines/boons, then #12 charms, #14 Descent as the capstone.

Why this order: A and B require no new gameplay systems, only bookkeeping on top of what exists; they validate the economy before boons add variance. Boons (D) change the feel of the run and should only land once the currency loop is proven fun.

## 8. Risks to the game's feel (summary)

- **Power creep:** do not add new coin-bought power. A maxed tree already roughly doubles the slime and +50% speed; more power erodes the levels' tuned budgets (levels 8-10 sit at 88-99% of the meter without upgrades).
- **Grind perception:** keep faucets mastery-based, daily paid wins capped, and prices flat; show progress ("HATS 4/11", "GLOBS 7/12").
- **Fog fantasy:** any map-revealing aid (Sniff, magnets) must be short, costly and disabled in hard/daily.
- **Fairness:** daily and Heat runs must stay completable with zero boons and zero upgrades; add a test per mode, as `tests/test_phase3` does for story levels.
- **Placeholder hats:** the wheel's reward is currently placeholder art; accrue globs now but keep `Hats.available=false` until the hat list is final.
- **Save-code size and old builds:** see section 5.
- **Determinism on web:** verify noise-maze seeds across platforms before promising a shared Daily.
- **Scope:** the game is deliberately small and moody; prefer a few sharp systems (currency, medals, daily, shrines) over a sprawling meta layer.

---

## 9. Sources

Fetched pages (content read):
- Inverse, Hades God Mode interview: https://www.inverse.com/gaming/hades-god-mode-interview
- Can I Play That, Hades God Mode explained: https://caniplaythat.com/2021/08/11/hades-god-mode-explained-by-supergiant-games
- Supergiant Hades FAQ: https://www.supergiantgames.com/blog/hades-faq/
- RPG Site, Pact of Punishment / Heat: https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards
- Wikipedia: Hades https://en.wikipedia.org/wiki/Hades_(video_game), Dead Cells https://en.wikipedia.org/wiki/Dead_Cells, Slay the Spire https://en.wikipedia.org/wiki/Slay_the_Spire, Vampire Survivors https://en.wikipedia.org/wiki/Vampire_Survivors, Brotato https://en.wikipedia.org/wiki/Brotato, Spelunky https://en.wikipedia.org/wiki/Spelunky, Loop Hero https://en.wikipedia.org/wiki/Loop_Hero, Rogue Legacy 2 https://en.wikipedia.org/wiki/Rogue_Legacy_2, Balatro https://en.wikipedia.org/wiki/Balatro, Risk of Rain 2 https://en.wikipedia.org/wiki/Risk_of_Rain_2, Noita https://en.wikipedia.org/wiki/Noita_(video_game), Dome Keeper https://en.wikipedia.org/wiki/Dome_Keeper
- Substack, The Secret Sauce of Vampire Survivors: https://jboger.substack.com/p/the-secret-sauce-of-vampire-survivors
- Game Developer, A Spelunky game design analysis pt 2: https://www.gamedeveloper.com/design/a-spelunky-game-design-analysis-pt-2
- Game Developer, The 24-hour ticket: examining daily runs: https://www.gamedeveloper.com/design/the-24-hour-ticket-examining-daily-runs-
- Solodevstack, Daily challenges and shareable seeds, no server required: https://solodevstack.com/blog/daily-challenges-shareable-seeds-no-server
- Game Developer, Binding of Isaac postmortem: https://gamedeveloper.com/business/postmortem-mcmillen-and-himsl-s-i-the-binding-of-isaac-i-
- Game Developer, Dome Keeper (Road to the IGF): https://www.gamedeveloper.com/road-to-igf-2023/how-dome-keeper-focuses-on-systems-that-feed-into-one-another
- Game Wisdom, Rogue Legacy analysis: https://game-wisdom.com/analysis/rogue-legacy-genealogical-rogue-like
- LessWrong, Review: Slay the Spire: https://www.lesswrong.com/posts/MEimkSwwuRgiPaZaY/review-slay-the-spire
- Brotato Wiki, Dangers: https://brotato.wiki.spellsandguns.com/Dangers
- Bugnet, how to design a roguelite meta progression (qualitative only): https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression

Search-result summaries only (not opened in full; treat as secondary):
- GDC listing, Slay the Spire metrics talk: https://gdconf.com/news/learn-slay-spires-successful-metrics-driven-approach-game-balancing-gdc-2019 (404 on fetch; listing text via search)
- GDC listing, Dead Cells "What the F*n!?": https://gdconf.com/news/get-game-design-tips-and-tricks-dead-cells-dev-gdc-2019
- Destructoid, Closing the Loop (Loop Hero): https://destructoid.com/?p=265570 (fetch 403; interview details via search summary)
- Game Maker's Toolkit, How and why Spelunky makes its own levels (transcript fetch 403; search summary), and Darius Kazemi's generator lessons: https://tinysubversions.com/spelunkyGen2/
- Slay the Spire wiki card rewards (rare offset): https://slay-the-spire.fandom.com/wiki/Card_Rewards
- Enter the Gungeon wiki, Hegemony Credit and Breach: https://enterthegungeon.wiki.gg/wiki/Hegemony_Credit
- Dead Cells wiki, Boss Stem Cells: https://deadcells.wiki.gg/wiki/BSC and Daily Run: https://deadcells.fandom.com/wiki/Daily_Run
- Vampire Survivors "gambling psychology" commentary (Portsmouth/The Conversation): https://researchportal.port.ac.uk/en/publications/vampire-survivors-how-developers-used-gambling-psychology-to-crea/
- Hades currency guides: https://primagames.com/gaming/hades-items-guide-nectars-keys-ambrosia-titan-blood-and-more/2
- Rogue Legacy 2 House Rules (reviews): https://purexbox.com/reviews/xbox-series-x/rogue-legacy-2
- Roguelite meta-progression critique threads (forum synthesis): https://piefed.keyboardvagabond.com/c/games/p/232999/meta-progression-in-roguelites-was-fun-for-a-while-but-it-s-starting-to-f
- Darkest Dungeon light mechanic (Steam threads): https://steamcommunity.com/app/262060/discussions/0/350540973999489880
- Gacha pity systems overview: https://pulsegeek.com/articles/what-is-a-pity-counter-in-gacha-how-it-works/

General knowledge (not fetched): Hades duo-boon structure and Mirror refund behaviour beyond the cited guides; Don't Starve's hub/day cycle; Genshin-style pity details beyond the quoted summary; the without-replacement expected-spins arithmetic (n spins to complete n hats versus n x H(n) with replacement is standard math, also given in the gacha search summary).
