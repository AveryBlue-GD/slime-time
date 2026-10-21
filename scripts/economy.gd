class_name Economy
extends RefCounted

## The one tuning table for the game's economy (docs/design/upgrades-v2.md, D.4): a balance pass
## edits the numbers here and nowhere else. Static constants only; Upgrades (and through it the
## game, the randomizer sizing, the upgrades screen and the autoplay planner) reads them.
## Batch 1 of upgrades v2 holds the core coin tree; later batches add the workshop, the store,
## Descent tables here.

## ---------------------------------------------------------------- core coin tree (spec A2.1)
## The tree's version, saved as [upgrades] tree. Saves without it hold levels of the old 3 x 10-level
## tree (level n cost n coins) and are remapped on load (Upgrades.migrate_level, Progress._migrate_tree);
## tree 2 saves hold levels bought at TREE2_COSTS and are repriced (Progress._migrate_prices). Any
## change to COIN_TRACKS costs must bump this and keep the previous table for that migration:
## coins in hand are DERIVED from the levels x these prices (Progress.coins_spent).
const TREE_VERSION := 3

## Each track: `costs[i]` = coins for level i + 1, `values[i]` = the effect AT level i + 1 (level 0
## is `base`). Few big breakpoints instead of 10 thin levels; the maxima equal the old tree's
## maxima (x2.0 meter, x1.5 speed, +25 px light), so the end-game calibrations are unchanged.
##   slime:      the MORE SLIME meter factor (the cost per tile is divided by it)
##   speed:      the glide speed (and acceleration) factor
##   brightness: extra reach (px) of the slime's own light, added to REVEAL_RADIUS and RELIGHT_RADIUS
##   power:      (dev only, never in the totals) the wall-damage factor of a splat, x the old
##               per-level formula; free in dev mode
## MORE SLIME is the premium track (80 of the 165 coins, 48%): its first four levels cost what they
## did in tree 2 (1, 4, 7, 9), so the meter at each early / mid story level is unchanged for a player
## who buys it first; the last three (12, 20, 27) are the late top-ups. SPEED (46) and BRIGHTNESS (39)
## got cheaper by the same 25 coins (docs/design/upgrades-v2.md A2.1 / A2.3).
const COIN_TRACKS := {
	"slime": {base = 1.0, costs = [1, 4, 7, 9, 12, 20, 27], values = [1.15, 1.30, 1.45, 1.60, 1.75, 1.90, 2.00]},
	"speed": {base = 1.0, costs = [6, 9, 13, 18], values = [1.12, 1.25, 1.37, 1.50]},
	"brightness": {base = 0.0, costs = [9, 12, 18], values = [8.0, 16.0, 25.0]},
	"power": {base = 0.0, costs = [0, 0, 0, 0], values = [2.5, 5.0, 7.5, 10.0]},
}

## Brightness radii (px). The slime's own light reveals unexplored floor (and the walls beside it)
## within REVEAL_RADIUS + reach of its center, and keeps already-revealed cells lit within
## RELIGHT_RADIUS + reach. With the reach above: reveal 9 / 17 / 25 / 34 px and relight
## 20 / 28 / 36 / 45 px; lit-disc area x3.6, x7.7, x14.3 of the base (+257%, +116%, +85% per step).
## REVEAL_RADIUS is also the goo trail's radius (Main.TRAIL_RADIUS), RELIGHT_RADIUS is
## Main.LIGHT_RADIUS (tests/test_upgrades_v2.gd checks they stay equal).
const REVEAL_RADIUS := 9.0
const RELIGHT_RADIUS := 20.0

## Tree 2's prices (TREE_VERSION 2, until the MORE SLIME repricing), only for migrating saves: the
## coins a tree 2 level held. Same track lengths and effects as COIN_TRACKS. 55 + 60 + 50 = 165.
const TREE2_COSTS := {
	"slime": [1, 4, 7, 9, 10, 12, 12],
	"speed": [8, 12, 16, 24],
	"brightness": [12, 16, 22],
}

## The old tree (before TREE_VERSION 2), only for migrating saves: OLD_TREE_LEVELS levels per track,
## level n cost n coins (an old level L holds L x (L + 1) / 2 coins).
const OLD_TREE_LEVELS := 10
## Old dev wall power did power x lerp(4, 12, charge) damage; the new factor x that formula equals
## it at old power = OLD_POWER_PER_LEVEL x new level, so old power maps to floor(old / 2.5).
const OLD_POWER_PER_LEVEL := 2.5

## ---------------------------------------------------------------- tickets: faucets (spec A.1)
## The randomizer pays by attempt at a maze: attempt 1, 2, 3 ... (later attempts pay the last).
const RANDOM_ATTEMPT_PAY: Array[int] = [5, 4, 3, 2, 1]
## Randomizer wins that pay tickets per UTC day.
const RANDOM_PAID_PER_DAY := 5
## A win with no MORE SLIME bought, or on a typed / replayed seed, pays at most this.
const TICKETS_NO_SLIME_CAP := 1
const TICKETS_REPLAY_CAP := 1

## ---------------------------------------------------------------- tickets: the hat wheel (C.1)
## The first spin is free, the second costs SPIN_COST, each later one SPIN_STEP more (spins already
## taken beyond the second), never above SPIN_COST_MAX: 0, 12, 14 ... 30 = 210 for all 11 hats.
const SPIN_COST := 12
const SPIN_STEP := 2
const SPIN_COST_MAX := 40
## Hats are never sold (owner, 2026-10-21: the TAILOR's direct buy is gone). The SHOP's DYES sell a
## won hat in another color (Hats.dyes_for: 9 dyeable hats, 9-10 dyes each, 84 in all) for
## DYE_PRICE tickets each, about one day's paid randomizer wins.
const DYE_PRICE := 10
## The wheel's odds, the one rarity table (Progress.wheel_weight reads it; Hats.LIST's own `weight`
## field is not used for the wheel): every hat weighs WHEEL_WEIGHT, a WHEEL_RARE one
## WHEEL_RARE_WEIGHT, and the flowing (rainbow) hat gets Hats.PITY_STEP more per spin that missed
## it (Progress.rainbow_pity). A hat's chance = its weight / the sum over the hats still on the wheel.
## With all 12 hats of today's LIST on the wheel and no pity (9 x 1 + 3 x 0.3 = 9.9):
##   tophat, beanie, party, cap, cowboy, chef, wizard, viking, crown: 10.10 % each (90.91 %)
##   propeller, raincloud, rainbow: 3.03 % each (9.09 % for the rare ones)
## A save's FIRST spin (spins == 0: a fresh save, RESET PROGRESS, a new epoch, a code that never
## spun) is still random but never rare: it picks among the non-rare hats left, at their weights
## (1 / 9 = 11.11 % each), so wiping a save to farm free spins can't win a rare hat.
const WHEEL_WEIGHT := 1.0
const WHEEL_RARE_WEIGHT := 0.3
const WHEEL_RARE: Array[String] = ["rainbow", "propeller", "raincloud"]

## ---------------------------------------------------------------- tickets: the WORKSHOP (B.2)
## Utility upgrades bought with tickets in the cauldron's TICKETS tab: 3 levels each, not
## refundable, off in hard mode, never change par, routes, u or seed codes. `costs[i]` = tickets for
## level i + 1, `values[i]` = the effect AT level i + 1 (level 0 = `base`).
##   wind:   SECOND WIND, the meter refills to this share (0-1) the first time it hits 0 in a run
##   charge: QUICK CHARGE, seconds for a full leap charge (Slime.CHARGE_TIME 1.5 at level 0)
##   sticky: STICKY, splat penalty factor; `stun` = the splat stun (s) (Slime.SPLAT_STUN 0.3)
##   magnet: MAGNET, coin pickup reach (px) for coins in plain sight (Coin.REACH 10 at level 0)
##   nose:   GOO NOSE, glimmers come `values` x as often; `reach` = how far they reach (px, 160)
## ONE switch for the whole ticket workshop (the cauldron's TICKETS tab and all five tracks). Off:
## nothing is offered or applied (Progress.workshop_level reads 0, workshop_open is false, no tab,
## no WIND tag, the hub '!' ignores it), but levels already in a save are KEPT and come back when
## this is true again. `workshop_force` (-1 follow the const, 0 off, 1 on) is a test hook.
const WORKSHOP_ENABLED := false
static var workshop_force := -1


static func workshop_on() -> bool:
	return WORKSHOP_ENABLED if workshop_force < 0 else workshop_force == 1


const WORKSHOP := {
	"wind": {base = 0.0, costs = [15, 30, 50], values = [0.15, 0.25, 0.35]},
	"charge": {base = 1.5, costs = [12, 25, 45], values = [1.2, 0.95, 0.7]},
	"sticky": {base = 1.0, costs = [12, 25, 45], values = [0.75, 0.55, 0.40], stun_base = 0.3, stun = [0.2, 0.12, 0.06]},
	"magnet": {base = 10.0, costs = [12, 25, 45], values = [18.0, 26.0, 34.0]},
	"nose": {base = 1.0, costs = [12, 25, 45], values = [1.4, 1.8, 2.3], reach_base = 160.0, reach = [200.0, 240.0, 300.0]},
}
## SECOND WIND refills the meter over this many seconds.
const WIND_REFILL_TIME := 0.4

## ---------------------------------------------------------------- DESCENT on / off (decision D11)
## ONE switch for the whole DESCENT run. Off (cut from the randomizer for now: too hard to first-try
## even one level): the randomizer portal starts a RANDOM MAZE directly (no mode menu), no run can start
## or resume (Progress.start_descent / resume_descent do nothing), no saved-run prompt, nothing in the
## hub, HUD or help text mentions it, and the ABYSS trail is hidden unless already owned. A saved
## [descent_run], [descent] stats and milestones are KEPT in the save untouched and come back when
## this is true again. `descent_force` (-1 follow the const, 0 off, 1 on) is a test hook, like
## `workshop_force`.
const DESCENT_ENABLED := false
static var descent_force := -1


static func descent_on() -> bool:
	return DESCENT_ENABLED if descent_force < 0 else descent_force == 1


## ---------------------------------------------------------------- SOFT BOUNCE test (owner A/B, 2026-10-16)
## ONE switch for the softer wall hit (docs/spring-cleaning/soft-bounce-test.md). Off (default): a leap
## that hits a wall splats as always (0.3 s stun, ricocheting knockback slide). On (Slime._soft_hit):
## a GLANCING hit (more than ~20 deg off head-on) squashes on the wall for a moment, then the slime
## slides on smoothly ALONG the wall with part of its speed and eases to a stop (no ricochets, no
## camera kick, a soft high 'plap'); a HEAD-ON hit keeps the splat with a shorter stun and a shorter,
## straight knockback. The slime cost and splat penalty are exactly today's; both slides are free,
## like today's knockback. `--softbounce` (debug builds only, like every launch flag) sets
## `softbounce_force` = 1; tests set it too.
const SOFT_BOUNCE_TEST := false
static var softbounce_force := -1


static func soft_bounce_on() -> bool:
	return SOFT_BOUNCE_TEST if softbounce_force < 0 else softbounce_force == 1


## A hit at least this square-on (cos of the angle between the leap and the wall's normal; cos 20 deg
## = 0.94) is head-on: a splat. Anything shallower glances off.
const SOFT_BOUNCE_HEAD_ON_COS := 0.94
## Glancing hit: the slime holds squashed on the wall this long (s), stunned this long in all (never
## longer than the STICKY-shortened splat stun), then slides along the wall at SOFT_BOUNCE_SPEED_SHARE
## of the leap's speed along the wall, braking evenly to a stop after SOFT_BOUNCE_SLIDE_PER_LEFT of the
## leap distance still left, clamped to SOFT_BOUNCE_SLIDE_MIN..MAX px. A wall ahead ends the slide
## (an inside corner: it just stops there).
const SOFT_BOUNCE_SQUASH := 0.05
const SOFT_BOUNCE_GLANCE_STUN := 0.1
const SOFT_BOUNCE_SPEED_SHARE := 0.6
const SOFT_BOUNCE_SLIDE_PER_LEFT := 0.35
const SOFT_BOUNCE_SLIDE_MIN := 16.0
const SOFT_BOUNCE_SLIDE_MAX := 32.0
## The glancing 'plap': the splat sound, quieter and higher.
const SOFT_BOUNCE_PLAP_DB := -9.0
const SOFT_BOUNCE_PLAP_PITCH := 1.45
## Goo droplets off the contact point on a glancing hit (count, speed px/s).
const SOFT_BOUNCE_DROPLETS := 6
const SOFT_BOUNCE_DROPLET_SPEED := 35.0
## Head-on hit: stun (s, never longer than the splat stun), the recover animation after it (s; today
## Slime.RECOVER_ANIM_TIME 0.15), and a straight knockback of SOFT_BOUNCE_HEAD_KNOCK x today's distance
## (Slime.BOUNCE_FACTOR x the leap left), at most SOFT_BOUNCE_HEAD_KNOCK_MAX px, braking at
## SOFT_BOUNCE_HEAD_DECEL px/s^2 (today's glide friction is 260: twice that is a snappier stop).
const SOFT_BOUNCE_HEAD_STUN := 0.18
const SOFT_BOUNCE_HEAD_RECOVER := 0.1
const SOFT_BOUNCE_HEAD_KNOCK := 0.5
const SOFT_BOUNCE_HEAD_KNOCK_MAX := 16.0
const SOFT_BOUNCE_HEAD_DECEL := 520.0


## ---------------------------------------------------------------- COIN CATCH test (owner A/B, 2026-10-16)
## ONE switch for the slower, readable coin pickup (docs/spring-cleaning/coin-catch-test.md). Off
## (default): today's pickup (the coin sound, the coin flies in / dissolves, the HUD counts it at once).
## On (CoinCatch, scripts/coin_catch.gd): the touched coin is tossed up over the slime with a glint and
## a gold sparkle, the slime squashes and hops to catch it (a cosmetic sprite offset only: the body,
## controls, collisions, timer and meter never notice), then the coin dissolves slowly inside it and
## the HUD's coin counter pops up by one at the end. The coin is credited and saved at touch time
## exactly as today; only the show is later. `--coincatch` (debug builds only, like every launch flag)
## sets `coincatch_force` = 1; tests set it too.
const COIN_CATCH_TEST := true
static var coincatch_force := -1


static func coin_catch_on() -> bool:
	return COIN_CATCH_TEST if coincatch_force < 0 else coincatch_force == 1


## ---------------------------------------------------------------- MAP COIN REVEAL (owner, 2026-10-18; on for everyone 2026-10-21)
## The MAP TABLE's trail maps never draw collected coins. An UNCOLLECTED coin is drawn on its map once
## a run has "revealed" it: its cell center came within the slime's light (its keep-lit light:
## Game.LIGHT_RADIUS 20 px + the BRIGHTNESS reach, 20 / 28 / 36 / 45 px) by straight-line distance,
## walls ignored (a brighter light finds coins through walls; F1 FULL BRIGHT reveals every coin).
## Revealed coins are kept per level/mode in the survey (`seen_coins`), merged over runs and saved as
## [maps] coins_N (docs/spring-cleaning/map-coin-reveal-test.md). Dev runs (F1 / F2 ones too) record
## their survey in memory for the session (dev saving stays off). `--nocoinreveal` (debug builds) sets
## `mapcoinreveal_force` = 0: off everywhere, for A/B.
const MAP_COIN_REVEAL_TEST := true
static var mapcoinreveal_force := -1


## Whether revealed (uncollected) coins are recorded and drawn on the maps; `dev` = Progress.dev_tools.
static func map_coin_reveal_on(dev: bool) -> bool:
	if mapcoinreveal_force == 0:
		return false
	return dev or MAP_COIN_REVEAL_TEST


## The slime's hop (seconds): an anticipation squash, the hop itself (up and down, at most
## COIN_CATCH_HOP_PX whole px), then a landing squash. The coin is caught COIN_CATCH_CATCH_SHARE of
## the way through the hop (just past its top).
const COIN_CATCH_SQUASH_TIME := 0.14
const COIN_CATCH_HOP_TIME := 0.34
const COIN_CATCH_LAND_TIME := 0.16
const COIN_CATCH_HOP_PX := 5.0
const COIN_CATCH_CATCH_SHARE := 0.6
## The toss: the coin arcs up to this many px above the slime's center (12-20 looks right), spinning
## this many times faster than it idles, trailing a few gold sparkles.
const COIN_CATCH_TOSS_HEIGHT := 18.0
const COIN_CATCH_TOSS_SPIN := 3.0
const COIN_CATCH_SPARKLES := 6
## A coin touched while a hop is under way joins it if at least this long (s) is left before its catch;
## otherwise the hop starts over for it.
const COIN_CATCH_MIN_TOSS := 0.16
## The dissolve (s) inside the slime: a jelly slime shows the coin sinking and fizzing smaller with
## bubbles rising; a solid one swallows it into its surface with a glint and a goo ripple.
const COIN_CATCH_DISSOLVE_TIME := 1.0
const COIN_CATCH_BUBBLES := 8
const COIN_CATCH_RIPPLE_TIME := 0.45
const COIN_CATCH_RIPPLE_PX := 8.0
## Reduce Motion: no toss, no hop: the coin dissolves where it lies, a little slower.
const COIN_CATCH_CALM_TIME := 1.2
## At most this many coins animate at once; one more finishes the oldest at once (its counter pop).
const COIN_CATCH_MAX := 3
## Sounds: the coin sound at the catch (today's, at today's volume) and a soft low fizz (coin_fizz)
## when the dissolve ends and the counter pops.
const COIN_CATCH_COIN_DB := -4.0
const COIN_CATCH_FIZZ_DB := -8.0


## ---------------------------------------------------------------- TUTORIAL test (SPLASHDOWN, owner 2026-10-18)
## Shipped (owner, 2026-10-18): on for everyone. ONE switch for the first-session tutorial
## (docs/tutorial/design.md): the SPLASHDOWN training maze right after the launch intro, then the
## hub tour; existing saves never get it (Progress.tutorial_due). Off: the old first launch exactly (intro,
## title PLAY, level 1), Progress.tutorial_due() / hub_tour_due() are always false, the training and
## hub bits (Progress.TUTORIAL_TRAINING / TUTORIAL_HUB) are never written, so saves are byte-identical.
## `--tutorial[=maze|hub]` (debug builds only, like every launch flag) sets `tutorial_force` = 1 on a
## clean in-memory fresh state (see Progress.enable_tutorial_test); tests set it too.
const TUTORIAL_TEST := true
static var tutorial_force := -1


static func tutorial_on() -> bool:
	return TUTORIAL_TEST if tutorial_force < 0 else tutorial_force == 1


## ---------------------------------------------------------------- LANGUAGES test (i18n, D15)
## ONE switch for the translations (docs/i18n/plan.md). Off (default): the `Language` autoload loads no
## translation, adds no font fallback and never touches the text direction, `Loc.t` / `Loc.n` return the
## English source text (= today's strings), SETTINGS has no LANGUAGE button and nothing new is saved.
## `--languages` (debug builds only, like every launch flag) sets `languages_force` = 1 (the saved choice
## or the OS locale); `--lang=xx` also forces locale xx for that run (`forced_locale`, never saved).
## Tests set both too.
const LANGUAGES_TEST := false
static var languages_force := -1
static var forced_locale := ""


static func languages_on() -> bool:
	return LANGUAGES_TEST if languages_force < 0 else languages_force == 1


## ---------------------------------------------------------------- tickets: ABILITIES (Abilities v1)
## Three active abilities bought with tickets in the cauldron's TICKETS tab (docs/design/upgrades-v2.md
## "Abilities v1"; names, icons and aiming in scripts/abilities.gd, the in-level effects in
## scripts/ability_runner.gd). 3 levels each, not refundable; every level gives exactly ONE use (`charges[i]` = 1; the
## levels only make it stronger) per
## attempt (refilled by every restart, new maze, next level or Descent floor). Each use costs `slime`
## percent of the meter (SLIME RIFLE / SLIME SPLAT are refused unless the meter holds MORE than that;
## SLIMAKAZE always fires and leaves the meter at 0, a dry-up on impact, when it holds that much or
## less). ON only in randomizer mazes and Descent (Abilities.allowed_in); OFF in every story level (normal, hard) and in the hard-mode randomizer.
## Never change par, routes, u, payouts or seed codes. `abilities_force` (-1 follow the const, 0 off,
## 1 on) is a test hook, like `workshop_force`.
const ABILITIES_ENABLED := true
static var abilities_force := -1


static func abilities_on() -> bool:
	return ABILITIES_ENABLED if abilities_force < 0 else abilities_force == 1


## First ability ~15 tickets = about one day's paid randomizer wins (~16 in ~18 min, A.2); all three
## maxed = 95 + 108 + 140 = 343.
const ABILITIES := {
	"rifle": {costs = [15, 30, 50], charges = [1, 1, 1], slime = 2.0},
	"splat": {costs = [18, 35, 55], charges = [1, 1, 1], slime = 4.0},
	"kaze": {costs = [25, 45, 70], charges = [1, 1, 1], slime = 30.0},
}
## Abilities PASS OVER WALLS (owner buff, 2026-10-15): the rifle shot pierces them, the bomb is
## lobbed over them, the SLIMAKAZE splatter lands in the corridors beyond (only the dash stops at a
## wall). The per-level numbers below are indexed by ability level - 1 (L1 / L2 / L3).
## SLIME RIFLE: the goo shot's speed (px/s) and range (tiles past the slime's own, by level); it
## flies straight through walls, stopping only at the range or the maze's outer edge.
const RIFLE_SPEED := 480.0
const RIFLE_RANGE := [8, 11, 14]
## SLIME SPLAT: lobbed exactly this many tiles ahead (by level; over walls, clamped inside the maze),
## in the air this long (s), bursts over the (2 x AREA + 1)^2 tiles around where it lands (a wall
## tile too), its glow fading over GLOW_TIME s.
const SPLAT_RANGE := [4, 5, 6]
const SPLAT_FLIGHT := 0.4
const SPLAT_AREA := 1
const SPLAT_GLOW_TIME := 1.5
## SLIMAKAZE: the dash's speed (px/s) to the first wall, the stun after the impact (s), the screen
## shake (px, s; none with Reduce Motion), and the splatter: every floor tile within RADIUS tiles (by
## level) of the impact tile (center to center, walls in between ignored) is goo'd and revealed with
## a chance falling from NEAR (at the impact) to FAR (at the edge), seeded by the maze, the impact
## tile and the use index this attempt (never the attempt).
const KAZE_SPEED := 640.0
const KAZE_STUN := 0.6
const KAZE_SHAKE := 6.0
const KAZE_SHAKE_TIME := 0.5
const KAZE_RADIUS := [6.0, 7.0, 8.0]
const KAZE_CHANCE_NEAR := 0.9
const KAZE_CHANCE_FAR := 0.4

## ---------------------------------------------------------------- tickets: cosmetics (C.2)
## Ticket prices of the v1 cosmetics (palette / pattern only; Cosmetics has their names and looks).
## 20 + 25 + 30 + 35 + 40 + 25 + 25 + 40 = 240.
const COSMETICS := {
	"ink": 20, "glow": 25, "gold": 30, "candy": 35, "starry": 40,
	"blueprint": 25, "night": 25, "goldleaf": 40,
}

## ---------------------------------------------------------------- DESCENT runs (C2)
## A Descent run chains randomizer-style floors built from one run seed: floor k's maze seed is
## run seed x DESCENT_FLOOR_SEED + k (no seed codes). Run seeds stay below DESCENT_SEED_MAX so a
## floor seed fits in 31 bits like the randomizer's.
const DESCENT_SEED_MAX := 2_000_000
const DESCENT_FLOOR_SEED := 1000
## Floor k's usage u (permille of the player's base meter a perfect glide to the exit needs):
## DESCENT_U_START + DESCENT_U_STEP x (k - 1), at most DESCENT_U_MAX (floor 12+), +- DESCENT_U_JITTER
## seeded jitter, kept within DESCENT_U_MIN .. DESCENT_U_MAX.
const DESCENT_U_START := 300
const DESCENT_U_STEP := 50
const DESCENT_U_MAX := 850
const DESCENT_U_JITTER := 50
const DESCENT_U_MIN := 250
## The meter carries from floor to floor; entering floor k adds the refill (percent of the meter) of
## the last row whose floor <= k, capped at a full meter: [from floor, + percent].
const DESCENT_REFILL := [[1, 60], [4, 50], [7, 40], [10, 35]]
## Goo drops per floor (deep dead ends, seeded like coins) and the meter each one gives (percent).
const DESCENT_DROPS := 2
const DESCENT_DROP_REFILL := 8.0
## Tickets each cleared floor adds to the run's pot: [from floor, + tickets]; the pot never exceeds
## DESCENT_POT_MAX. CASH OUT banks the whole pot, a dry-up (or quitting mid-floor) half, rounded down.
const DESCENT_POT_PER_FLOOR := [[1, 1], [4, 2], [7, 3], [10, 4]]
const DESCENT_POT_MAX := 30
## Runs per UTC day that pay; later runs are PRACTICE (pay 0). A run takes one of the day's paid
## slots (saved at once) when it first clears floor 1, so closing the game mid-run can't keep the
## slot; it banks into that slot later (even after midnight). A run that dries up or quits on floor 1
## (pot 0) takes no slot; a run that started with no slot left still pays if a new day has begun by
## the time it banks.
const DESCENT_PAID_PER_DAY := 2
## With no MORE SLIME bought a run banks at most this (not in dev mode).
const DESCENT_NO_SLIME_CAP := 1
## One-time bonuses for first reaching a floor: {floor: tickets} (10 + 15 + 20 + 25 = 70).
const DESCENT_MILESTONES := {5: 10, 10: 15, 15: 20, 20: 25}
## First reaching this floor also unlocks the ABYSS trail (an earned cosmetic, never sold).
const DESCENT_ABYSS_FLOOR := 10

## Boons: after each cleared floor the player picks 1 of 3 offers (seeded by run seed and floor;
## distinct; a boon held `max` times is no longer offered, max 0 = no limit; a boon is never offered
## while the boon named by its `excludes` is held). Run-scoped.
##   gulp     BIG GULP        `value` % of the meter added right away
##   tank     DEEP TANK       meter capacity + `value` (share) for the run
##   feather  FEATHER LEAP    leaps cost `value` of gliding the distance (game.JUMP_COST_FACTOR 0.5)
##   rubber   RUBBER BODY     splats cost no extra slime (the stun stays); never with GLASS SLIME
##                            (it would cancel GLASS's double splats: they exclude each other)
##   slick    SLICK           glide speed + `value` (share)
##   blaze    BLAZE           one more brightness step: light reach `value` px past BRIGHTNESS 3
##   sense    CHALICE SENSE   the exit shows within `value` px (game.CHALICE_REVEAL_DISTANCE 24)
##   bladder  BACKUP BLADDER  one more refill of `value` % when the meter hits 0 (after SECOND WIND)
##   thrift   THRIFT          each floor refill + `value` percent
##   greedy   GREEDY GOO      + `tickets` to the pot per cleared floor, capacity `value` (share); one
##                            stack only (capacity 0.90 stays above the deepest floors' u 0.85)
##   glass    GLASS SLIME     the banked pot x `pot`, splat penalties x `splat`; never with RUBBER BODY
const BOONS := {
	"gulp": {weight = 1.0, max = 0, value = 30.0},
	"tank": {weight = 0.8, max = 2, value = 0.15},
	"feather": {weight = 0.8, max = 1, value = 0.35},
	"rubber": {weight = 0.8, max = 1, value = 0.0, excludes = "glass"},
	"slick": {weight = 0.8, max = 2, value = 0.15},
	"blaze": {weight = 0.6, max = 1, value = 33.0},
	"sense": {weight = 0.5, max = 1, value = 96.0},
	"bladder": {weight = 0.5, max = 0, value = 25.0},
	"thrift": {weight = 0.8, max = 2, value = 15.0},
	"greedy": {weight = 0.5, max = 1, value = -0.10, tickets = 1},
	"glass": {weight = 0.4, max = 1, pot = 1.5, splat = 2.0, excludes = "rubber"},
}
## Boons offered after each floor.
const BOON_OFFERS := 3

