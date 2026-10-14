class_name Economy
extends RefCounted

## The one tuning table for the game's economy (docs/design/upgrades-v2.md, D.4): a balance pass
## edits the numbers here and nowhere else. Static constants only; Upgrades (and through it the
## game, the randomizer sizing, the upgrades screen and the autoplay planner) reads them.
## Batch 1 of upgrades v2 holds the core coin tree; later batches add the workshop, the store,
## Descent and Heat tables here.

## ---------------------------------------------------------------- core coin tree (spec A2.1)
## The tree's version, saved as [upgrades] tree. Saves without it (or with a lower one) still hold
## levels of the old 3 x 10-level tree (level n cost n coins) and are remapped on load
## (Upgrades.migrate_level, Progress._migrate_tree).
const TREE_VERSION := 2

## Each track: `costs[i]` = coins for level i + 1, `values[i]` = the effect AT level i + 1 (level 0
## is `base`). Few big breakpoints instead of 10 thin levels; the maxima equal the old tree's
## maxima (x2.0 meter, x1.5 speed, +25 px light), so the end-game calibrations are unchanged.
##   slime:      the MORE SLIME meter factor (the cost per tile is divided by it)
##   speed:      the glide speed (and acceleration) factor
##   brightness: extra reach (px) of the slime's own light, added to REVEAL_RADIUS and RELIGHT_RADIUS
##   power:      (dev only, never in the totals) the wall-damage factor of a splat, x the old
##               per-level formula; free in dev mode
const COIN_TRACKS := {
	"slime": {base = 1.0, costs = [1, 4, 7, 9, 10, 12, 12], values = [1.15, 1.30, 1.45, 1.60, 1.75, 1.90, 2.00]},
	"speed": {base = 1.0, costs = [8, 12, 16, 24], values = [1.12, 1.25, 1.37, 1.50]},
	"brightness": {base = 0.0, costs = [12, 16, 22], values = [8.0, 16.0, 25.0]},
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
## TAILOR (the SHOP's direct buy): any hat still on the wheel for TAILOR_PRICE (the rainbow hat
## TAILOR_RAINBOW_PRICE), once TAILOR_AFTER_SPINS spins have been taken. A buy counts as a spin.
const TAILOR_PRICE := 45
const TAILOR_RAINBOW_PRICE := 80
const TAILOR_AFTER_SPINS := 3

## ---------------------------------------------------------------- tickets: the WORKSHOP (B.2)
## Utility upgrades bought with tickets in the cauldron's TICKETS tab: 3 levels each, not
## refundable, off in hard mode, never change par, routes, u or seed codes. `costs[i]` = tickets for
## level i + 1, `values[i]` = the effect AT level i + 1 (level 0 = `base`).
##   wind:   SECOND WIND, the meter refills to this share (0-1) the first time it hits 0 in a run
##   charge: QUICK CHARGE, seconds for a full leap charge (Slime.CHARGE_TIME 1.5 at level 0)
##   sticky: STICKY, splat penalty factor; `stun` = the splat stun (s) (Slime.SPLAT_STUN 0.3)
##   magnet: MAGNET, coin pickup reach (px) for coins in plain sight (Coin.REACH 10 at level 0)
##   nose:   GOO NOSE, glimmers come `values` x as often; `reach` = how far they reach (px, 160)
const WORKSHOP := {
	"wind": {base = 0.0, costs = [15, 30, 50], values = [0.15, 0.25, 0.35]},
	"charge": {base = 1.5, costs = [12, 25, 45], values = [1.2, 0.95, 0.7]},
	"sticky": {base = 1.0, costs = [12, 25, 45], values = [0.75, 0.55, 0.40], stun_base = 0.3, stun = [0.2, 0.12, 0.06]},
	"magnet": {base = 10.0, costs = [12, 25, 45], values = [18.0, 26.0, 34.0]},
	"nose": {base = 1.0, costs = [12, 25, 45], values = [1.5, 2.0, 3.0], reach_base = 160.0, reach = [200.0, 240.0, 300.0]},
}
## SECOND WIND refills the meter over this many seconds.
const WIND_REFILL_TIME := 0.4

## ---------------------------------------------------------------- tickets: cosmetics (C.2)
## Ticket prices of the v1 cosmetics (palette / pattern only; Cosmetics has their names and looks).
## 20 + 25 + 30 + 35 + 40 + 25 + 25 + 40 = 240.
const COSMETICS := {
	"ink": 20, "glow": 25, "gold": 30, "candy": 35, "starry": 40,
	"blueprint": 25, "night": 25, "goldleaf": 40,
}
