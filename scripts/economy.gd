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
## Doubled from 5, 4, 3, 2, 1 (owner, 2026-10-22: less grind), with the ability prices doubled too;
## the 6th attempt and every later one pay 1.
const RANDOM_ATTEMPT_PAY: Array[int] = [10, 8, 6, 4, 2, 1]
## Randomizer wins that pay tickets per UTC day, while RANDOM_DAILY_CAP is on.
const RANDOM_PAID_PER_DAY := 5
## ONE switch for that daily cap. Off (owner, 2026-10-22: no daily limit on ticket payouts): every
## fresh randomizer win pays its attempt's tickets (a seed still pays once a day, replays 1). True
## again restores the 5-a-day cap; the day's count is kept in the save either way.
## `random_cap_force` (-1 follow the const, 0 off, 1 on) is a test hook, like `descent_force`.
const RANDOM_DAILY_CAP := false
static var random_cap_force := -1


static func random_daily_cap_on() -> bool:
	return RANDOM_DAILY_CAP if random_cap_force < 0 else random_cap_force == 1
## Randomizer mazes end at the story's chalice again (owner, 2026-10-22), paying the same tickets by
## attempt; false brings back the gold ticket voucher goal (TicketGoal). Each maze also hides
## RANDOM_TICKETS ticket pickups (RandomTickets: seeded dead ends, under the fog like story coins),
## RANDOM_TICKET_PAY each when touched; a maze's taken pickups stay gone on its retries (in memory, per
## seed code), a typed / replayed seed has none, and an assisted or dev-toggled run's pay nothing.
const RANDOM_CHALICE := true
## IMP-02 (economy integrity). PICKUPS_ON_WIN: a random maze's ticket pickups are HELD during the run
## and paid only with the chalice win (a dry-up, restart, NEW MAZE or leaving loses the held ones; a taken
## pickup stays gone on the maze's retries). False = pay on touch, as before.
const PICKUPS_ON_WIN := true
## PAY_BY_LENGTH: a random win's table pay (RANDOM_ATTEMPT_PAY) is scaled by the maze's length factor
## (Progress.random_length_factor: the seed's route in cells over the route of a typical maze, usage
## median 578 permille, at the same MORE SLIME level, so upgrades alone don't raise it), clamped to
## LENGTH_PAY_MIN..LENGTH_PAY_MAX, rounded, at least 1; a HARD maze pays the flat HARD_LENGTH_FACTOR (its
## route is always the hard target), so a first-try hard win pays as much as a long normal maze; the replay / seed-paid / no-MORE-SLIME caps
## still apply after it. False = the table as is.
const PAY_BY_LENGTH := true
const LENGTH_TYPICAL_PERMILLE := 578  # (the usage median, Levels.USAGE_QUANTILES)
const LENGTH_PAY_MIN := 0.4
const LENGTH_PAY_MAX := 1.5
const HARD_LENGTH_FACTOR := 1.4  # (IMP2-04: hard random mazes paid 10 against up to 14 for long normal ones)
## ABANDON_COUNTS: NEW MAZE or leaving for the hub after at least one move in a random maze counts as a
## spent attempt: the next maze starts at the abandoned one's attempt count + 1 (up to the last pay tier);
## a win resets it, and the first maze (or one after a win) starts at attempt 1. False = always 1.
const ABANDON_COUNTS := true
## IMP-06 DAILY_MAZE: the randomizer portal offers a DAILY MAZE (one seed per UTC day from Progress.daily_seed,
## normal mode, MORE SLIME 0 so it is the same for everyone), best time, a win streak and a 10-ticket bonus at
## every 7th day of it. The first win of a day pays like attempt 1; later wins that day pay nothing. False = no
## daily option. Hidden in the demo.
const DAILY_MAZE := true
## Owner default (Q1, 2026-10-23): winning the daily again the same UTC day counts toward randoms_won / win achievements (false = it doesn't).
const REPEAT_DAILY_COUNTS := false
const DAILY_STREAK_STEP := 7
const DAILY_STREAK_BONUS := 10
## IMP2-05: the first daily win of a UTC day pays this many tickets (one wheel spin), exempt from the no-MORE-SLIME cap and the
## length factor; repeats pay 0. DAILY_EPOCH_DAY = the UTC day number (days since 1970) of "DAILY #1" (2026-11-01).
## One automatic streak saver per DAILY_SAVER_DAYS days: missing exactly one day keeps the streak.
const DAILY_WIN_TICKETS := 20
const DAILY_EPOCH_DAY := 20758
const DAILY_SAVER_DAYS := 7

## IMP-07 ACHIEVEMENTS: the hub menu's ACHIEVEMENTS page (scripts/achievements.gd), an unlock toast for each goal and
## the pooled MEDAL MILESTONES (IMP2-03: Achievements.MILESTONES at 15 / 30 / 45 / 60 medals earned, any tier, normal + hard,
## each a named cosmetic, or MEDAL_MILESTONE_TICKETS tickets = one wheel spin when it is already owned). About 8 goals
## also grant a cosmetic (Achievements.REWARDS). Off: no page, no toasts, no milestone pay.
const ACHIEVEMENTS := true
const MEDAL_MILESTONE_TICKETS := 20
## Test hooks for the three (-1 follow the const, 0 off, 1 on), like `random_cap_force`.
static var pickups_on_win_force := -1
static var pay_by_length_force := -1
static var abandon_counts_force := -1


static func daily_maze() -> bool:
	return DAILY_MAZE and not Demo.on()


static func pickups_on_win() -> bool:
	return PICKUPS_ON_WIN if pickups_on_win_force < 0 else pickups_on_win_force == 1


static func pay_by_length() -> bool:
	return PAY_BY_LENGTH if pay_by_length_force < 0 else pay_by_length_force == 1


static func abandon_counts() -> bool:
	return ABANDON_COUNTS if abandon_counts_force < 0 else abandon_counts_force == 1


## Standing still drains the meter (owner, 2026-10-22; Game._idle_drain): IDLE_DRAIN percent a second
## in any level once the slime has moved (not charging, not in training, never in the hub, paused or
## while a SLIME SENSE peek is up). `idle_drain_force` (-1 follow the const, 0 off, 1 on) is a test
## hook: suite_base turns it off for every suite (their meter maths predate it); test_phase1 tests it.
const IDLE_DRAIN_ON := true
const IDLE_DRAIN := 0.5
static var idle_drain_force := -1
## Chill lane (IMP-01): standing still drains nothing for the first IDLE_GRACE seconds of being still
## (moving resets it), nothing at all while aiming an ability, and R always restarts the run at once
## (R_ALWAYS_RESTARTS: no RESTART / UPGRADES prompt; spending stays on the dry-up screen).
## SETTINGS RELAXED (Progress.relaxed) turns idle drain off; such a run earns no medals, records or tickets
## (see Progress.complete_random / Game.no_credit for what it still counts toward).
## ONE ASSIST (IMP2-07): RELAXED is the single assist: no idle drain AND +25% slime (+2% per dry-up on that level, max +50%),
## offered after 3 dry-ups (2 on L8-L10) as "RELAXED?" (story levels, never on hard; YES = RELAXED for that level only). False = the old +10% reserve offer and a plain RELAXED.
const ONE_ASSIST := true
## Does a RELAXED random win count toward randoms_won (pastel / rainbow / rand_10 / rand_50 rewards, NEXT UNLOCK)?
## Owner default (Lead, 2026-10-24): no, it pays more slime but is not a "real" win. Coins found in story still count.
const RELAXED_COUNTS_WINS := false
static var one_assist_force := -1  # (test hook: -1 follow the const, 0 off, 1 on)
static func one_assist() -> bool:
	return ONE_ASSIST if one_assist_force < 0 else one_assist_force == 1
const IDLE_GRACE := 4.0
const R_ALWAYS_RESTARTS := true
static var r_always_force := -1  # (test hook: -1 follow the const, 0 off = the old RESTART / UPGRADES prompt, 1 on)


static func r_always_restarts() -> bool:
	return R_ALWAYS_RESTARTS if r_always_force < 0 else r_always_force == 1


static func idle_drain_on() -> bool:
	return IDLE_DRAIN_ON if idle_drain_force < 0 else idle_drain_force == 1
## Share of randomizer mazes (seeded per maze) given a second way to the goal (MazeGenerator.
## add_second_route; owner, 2026-10-22: usually, not always; some have one through their own loops).
const RANDOM_SECOND_ROUTE_SHARE := 0.85
const RANDOM_TICKETS := 5  # always this many (owner, 2026-10-22; TicketPickup.cells_for)
## Test hook: pickups per maze instead of RANDOM_TICKETS (-1 = the const; suites that check the attempt
## pod's chalice number alone set 0).
static var random_tickets_force := -1


static func random_tickets() -> int:
	return RANDOM_TICKETS if random_tickets_force < 0 else random_tickets_force
const RANDOM_TICKET_PAY := 1
## A win with no MORE SLIME bought, or on a typed / replayed seed, pays at most this.
const TICKETS_NO_SLIME_CAP := 1
const TICKETS_REPLAY_CAP := 1

## ---------------------------------------------------------------- tickets: the hat wheel (C.1)
## The first spin is free, then every spin costs SPIN_COST (owner, 2026-10-22: a flat 20; SPIN_STEP /
## SPIN_COST_MAX still allow a rising price): 0, 20, 20 ... = 520 for all 27 prizes (26 paid spins).
const SPIN_COST := 20
const SPIN_STEP := 0
const SPIN_COST_MAX := 20
## Hats are never sold (owner, 2026-10-21: the TAILOR's direct buy is gone). The SHOP's DYES sell a
## won hat in another color (Hats.dyes_for: all 12 hats, 10-11 dyes each incl. PRISM and RAINBOW, 123 in all) for
## DYE_PRICE tickets each, about one day's paid randomizer wins; the flowing RAINBOW dye costs
## DYE_RAINBOW_PRICE, the PRISM dye (it turns through the colors as one) DYE_PRISM_PRICE (owner, 2026-10-21).
const DYE_PRICE := 10
const DYE_RAINBOW_PRICE := 99
const DYE_PRISM_PRICE := 50
## The wheel's odds, the one rarity table (Progress.wheel_weight reads it; Hats.LIST's own `weight`
## field is not used for the wheel): every hat weighs WHEEL_WEIGHT, a WHEEL_RARE one
## WHEEL_RARE_WEIGHT, and the flowing (rainbow) hat gets Hats.PITY_STEP more per spin that missed
## it (Progress.rainbow_pity). A hat's chance = its weight / the sum over the hats still on the wheel.
## The wheel also gives every non-earned trail (Cosmetics.wheel_ids: 15, none sold), weighed the
## same way: PULSE, GHOST and PIXEL are rare like the three rare hats, the other twelve common.
## With all 12 hats and 15 trails on the wheel and no pity (21 x 1 + 6 x 0.3 = 22.8):
##   9 common hats + 12 common trails: 4.39 % each (92.11 %)
##   propeller, raincloud, rainbow, pulse, ghost, pixel: 1.32 % each (7.89 % for the rare ones)
## A save's FIRST spin (spins == 0: a fresh save, RESET PROGRESS, a new epoch, a code that never
## spun) is still random but never rare: it picks among the non-rare hats left, at their weights
## (1 / 9 = 11.11 % each), so wiping a save to farm free spins can't win a rare hat.
const WHEEL_WEIGHT := 1.0
const WHEEL_RARE_WEIGHT := 0.3
const WHEEL_RARE: Array[String] = ["rainbow", "propeller", "raincloud", "pulse", "ghost", "pixel"]

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
## IMP-04: a save from a NEWER game version is backed up (save.newer.cfg) and never overwritten (saving off for the
## session); false = the old behaviour (read what fits, overwrite it on the next save).
const SAVE_NEWER_GUARD := true
## IMP-04: a short once-per-session notice when a save fails, a damaged save was set aside, a newer save is
## protected or the demo isn't saving (Progress.notices, shown by Transition).
const SAVE_NOTICES := true
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


## ---------------------------------------------------------------- DIAGONAL LEAP on / off (owner, 2026-10-22)
## ONE switch for leaping diagonally. Off (removed for now): a leap aimed between two directions goes
## along the stronger axis (an exact diagonal goes along x), and the charge pose faces that way too;
## gliding still moves in 8 directions. True again restores diagonal leaps (corner ricochets,
## Slime._slip_past_corner skipping them) exactly as before. `diagonal_leap_force` (-1 follow the
## const, 0 off, 1 on) is a test hook, like `descent_force`.
const DIAGONAL_LEAP := false
static var diagonal_leap_force := -1


static func diagonal_leap_on() -> bool:
	return DIAGONAL_LEAP if diagonal_leap_force < 0 else diagonal_leap_force == 1


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


## ---------------------------------------------------------------- LIGHT & LIFE (BM-09 test, 2026-10-24)
## ONE switch for the lighting polish inside the fog shader (scripts/light_life.gd, fog.gdshader): the
## lit pocket tinted by the theme and the skin with a dithered falloff, rim light on walls beside fresh
## trail, glints on fresh trail that fade with age, a few more theme motes (cap 40), faint pixel god-rays
## from the goal through the fog within 12 tiles, and a win "sunrise" (a light ring, a 2-frame hit-stop).
## The deep fog stays near-black. false = the old look exactly (pixel-identical). `--nolightlife`
## (debug builds) sets `lightlife_force` = 0; suites force it off (tests/suite_base.gd) unless they test it.
const LIGHT_LIFE_TEST := true
static var lightlife_force := -1


static func light_life_on() -> bool:
	return LIGHT_LIFE_TEST if lightlife_force < 0 else lightlife_force == 1


## ---------------------------------------------------------------- LURKERS (BM-01 test, 2026-10-24)
## Pale, blind creatures in the fog of 1 random / daily maze in LURKERS_ONE_IN (seeded, so the daily is the same for
## everyone), 2-3 each (scripts/lurkers.gd). Only their eye glints show through the fog; the body shows in the light.
## Three one-rule hunters on the maze grid: CRAWLER -> the slime, SNIFFER -> the trail (3 cells behind the slime),
## LANTERN-EATER -> the brightest lit cell near the slime. Dormant until the slime is within LURKER_WAKE_DIST px.
## Standing still past IDLE_GRACE = stealth (they wander). Contact: LURKER_HIT percent of the meter, a one-tile
## knockback, LURKER_INVULN s of safety (LURKER_INVULN_TOUCH on touch); never kills. SLIME SPLAT stuns them, a leap
## landing on one bonks it. Those mazes pay LURKER_PAY x. Never in story / hard story / training / the tutorial /
## the demo / RELAXED runs / with SETTINGS CALM DARK on. `--nolurkers` (debug builds) sets `lurkers_force` = 0,
## `--lurkers` = 2 (every random maze, for testing); suites force it off (tests/suite_base.gd) unless they test it.
const LURKERS_TEST := true
static var lurkers_force := -1
const LURKER_ONE_IN := 3
const LURKER_WAKE_DIST := 96.0
const LURKER_SPEED := 38.0
const LURKER_HIT := 15.0
const LURKER_INVULN := 1.0
const LURKER_INVULN_TOUCH := 1.5
const LURKER_CONTACT_DIST := 5.0
const LURKER_NEAR_MISS_DIST := 8.0
const LURKER_SLOWMO := 0.3
const LURKER_PAY := 1.25
const LURKER_STUN_SPLAT := 4.0
const LURKER_STUN_BONK := 2.0


static func lurkers_on() -> bool:
	return LURKERS_TEST if lurkers_force < 0 else lurkers_force >= 1


## ---------------------------------------------------------------- GOO ORCHESTRA (BM-08 test, 2026-10-24)
## Level music as three synced layers (assets/music/orch_*.ogg from tools/make_music.py): BASE always, PULSE
## while the slime moves, TENSION on a low meter or after the chalice is first seen within 12 tiles, each faded
## over 0.5 s (Music); the music ducks ~5 dB for 0.3 s under splat, coin and win sounds; a short sting when the
## chalice is first seen (once per attempt) and one over the win; each coin within 2 s of the last one plays a
## semitone higher (cap +6). Each theme plays the layers at its own pitch (Music.ORCH_THEME_PITCH). On the
## web one pre-mixed bed (the IMP-05 one) plays instead of three streams. false = the IMP-05 bed exactly.
## `--noorchestra` (debug builds) sets `orchestra_force` = 0; suites force it off (tests/suite_base.gd).
const ORCHESTRA_TEST := true
const ORCH_COIN_WINDOW := 2.0
const ORCH_COIN_MAX := 6
static var orchestra_force := -1


static func orchestra_on() -> bool:
	return ORCHESTRA_TEST if orchestra_force < 0 else orchestra_force == 1


## ---------------------------------------------------------------- BOARDS & GHOSTS (BM-03, local only, no network)
## Your own top BOARD_TOP times for each day's DAILY MAZE and each ISO week's WEEKLY MAZE (a seed from the week, MORE SLIME
## WEEKLY_SLIME, no abilities, so it is the same for everyone), a BOARDS page (the hub's daily sign, SETTINGS), the best run of
## the day / week recorded at GHOST_HZ (positions only, at most GHOST_MAX samples) and replayed as a translucent slime
## on later attempts with a "+1.2s" split at the chalice. Every post goes out as `board_daily` / `board_weekly` through
## PlatformEvents.progress_event for a future Steam / Game Center backend. RELAXED runs post nothing; hidden in the demo.
## `--noboards` (debug builds) sets `boards_force` = 0; suites force it off (tests/suite_base.gd) unless they test it.
const BOARDS_TEST := true
static var boards_force := -1
const BOARD_TOP := 5
const WEEKLY_SLIME := 3
const GHOST_HZ := 10
const GHOST_MAX := 3000


static func boards_on() -> bool:
	return (BOARDS_TEST if boards_force < 0 else boards_force == 1) and daily_maze() and not Demo.on()


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
## IMP-03: 8 px text (body, buttons, HUD, coach) renders without drips; only 16 px titles drip.
## false = the old look everywhere.
const CLEAN_SMALL_TEXT := true
## IMP2-01: the 1.8 s launch card (scripts/ui/intro_card.gd) on every cold launch except the first-ever one
## (the story intro plays then); false = the title opens as before.
const INTRO_CARD := true
## IMP-05: the unrevealed fog is near-black (Dark / Normal fog looks; Bright keeps its lighter mist, and is
## the default on touch devices). false = the old murky mid-tone.
const DARK_FOG := true
## IMP-05: a sparse quiet music bed under the level ambience (Settings: LEVEL MUSIC, saved). false = silent levels.
const LEVEL_MUSIC := true
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


## Doubled along with the doubled payouts (owner, 2026-10-22): first ability 30 tickets = about 5
## wins; SPLAT costs the same as the RIFLE (owner, 2026-10-22); all four maxed (RIFLE, SPLAT, SLIMAKAZE, SLIME SENSE) = 190 + 190 + 280 + 190 = 850.
const ABILITIES := {
	"rifle": {costs = [30, 60, 100], charges = [1, 1, 1], slime = 2.0},
	"splat": {costs = [30, 60, 100], charges = [1, 1, 1], slime = 4.0},
	"kaze": {costs = [50, 90, 140], charges = [1, 1, 1], slime = 30.0},
	# SLIME SENSE (owner, 2026-10-22): peeks at the maze's map mid-run (Game.toggle_run_map), 1 / 2 / 3
	# per attempt by level; free, and the meter doesn't drain while it is up.
	"sense": {costs = [30, 60, 100], charges = [1, 2, 3], slime = 0.0},
}
## Abilities PASS OVER WALLS (owner buff, 2026-10-15): the rifle shot pierces them, the bomb is
## lobbed over them, the SLIMAKAZE splatter lands in the corridors beyond (only the dash stops at a
## wall). The per-level numbers below are indexed by ability level - 1 (L1 / L2 / L3).
## SLIME RIFLE: the goo shot's speed (px/s) and range (tiles past the slime's own, by level); it
## flies straight through walls, stopping only at the range or the maze's outer edge.
const RIFLE_SPEED := 480.0
const RIFLE_RANGE := [12, 16, 20]  # owner, 2026-10-22: further (was 8, 11, 14)
## SLIME SPLAT: lobbed exactly this many tiles ahead (by level; over walls, clamped inside the maze),
## in the air this long (s), bursts over the (2 x AREA + 1)^2 tiles around where it lands (a wall
## tile too), its glow fading over GLOW_TIME s.
const SPLAT_RANGE := [2, 3, 4]  # owner, 2026-10-22: a shorter throw (was 4, 5, 6)
const SPLAT_FLIGHT := 0.4
const SPLAT_AREA := 2  # owner, 2026-10-22: a bigger blast, 5x5 (was 1, 3x3)
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
	"blueprint": 25, "night": 25, "goldleaf": 40,
	# Paper bundles (owner, 2026-10-21): a dye-colored sheet, walls and route; the flowing ones like the hat dyes.
	"cherry_paper": 30, "tangerine_paper": 30, "butter_paper": 30, "clover_paper": 30, "cobalt_paper": 30,
	"plum_paper": 30, "bubblegum_paper": 30, "prism_paper": 50,
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

