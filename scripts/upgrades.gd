class_name Upgrades
extends RefCounted

## The upgrade tree, bought with coins found in the story mazes. Each upgrade has MAX_LEVEL
## levels; level n costs n coins, so one maxed upgrade costs 55 and the three regular ones 165,
## exactly the coins hidden across all ten levels (Levels.COINS). Coins can be put in and taken
## back out at any time (Progress.buy_upgrade / refund_upgrade).
## "power" (breaking walls) is a dev-only experiment: shown and applied only in dev mode.

const MAX_LEVEL := 10

const LIST := [
	{id = "slime", name = "MORE SLIME", about = "+10% SLIME TO SPEND PER LEVEL"},
	{id = "speed", name = "SPEED", about = "+5% GLIDING SPEED PER LEVEL"},
	{id = "brightness", name = "BRIGHTNESS", about = "LIGHT UP MORE OF THE MAZE AROUND YOU"},
	{id = "power", name = "WALL POWER", about = "SPLATS DAMAGE WALLS (DEV ONLY)", dev = true},
]


## Coins for the next level up from `level`.
static func cost(level: int) -> int:
	return level + 1


## Coins invested in an upgrade at `level`.
static func total_cost(level: int) -> int:
	return level * (level + 1) / 2


## Coins needed to max every regular (non-dev) upgrade.
static func full_tree_cost() -> int:
	var total := 0
	for upgrade: Dictionary in LIST:
		if not upgrade.get("dev", false):
			total += total_cost(MAX_LEVEL)
	return total


static func get_upgrade(id: String) -> Dictionary:
	for upgrade: Dictionary in LIST:
		if upgrade.id == id:
			return upgrade
	return {}


## How much further the slime's slime goes (the cost per tile is divided by this).
static func slime_factor(level: int) -> float:
	return 1.0 + 0.1 * level


static func speed_factor(level: int) -> float:
	return 1.0 + 0.05 * level


## Extra reach (px) of the slime's own light: unexplored floor and walls this far beyond its
## goo trail are revealed, and lit areas stay lit this much further away.
static func light_reach(level: int) -> float:
	return 2.5 * level


## Wall damage (wall health is 100) dealt by a splat at `power_level`; `charge` is 0-1, how hard
## the leap was charged.
static func wall_damage(power_level: int, charge: float) -> float:
	return power_level * lerpf(4.0, 12.0, clampf(charge, 0.0, 1.0))
