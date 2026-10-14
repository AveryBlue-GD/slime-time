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
