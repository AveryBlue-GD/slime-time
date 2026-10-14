class_name Upgrades
extends RefCounted

## The upgrade tree, bought with coins found in the story mazes. Each track has its own number of
## levels and costs (Economy.COIN_TRACKS: MORE SLIME 7 levels, SPEED 4, BRIGHTNESS 3 - few big
## breakpoints, docs/design/upgrades-v2.md A2); the three regular tracks cost 55 + 60 + 50 = 165,
## exactly the coins hidden across all ten levels (Levels.COINS). Coins can be put in and taken
## back out at any time (Progress.buy_upgrade / refund_upgrade).
## "power" (breaking walls) is a dev-only experiment: shown and applied only in dev mode.

const LIST := [
	{id = "slime", name = "MORE SLIME"},
	{id = "speed", name = "SPEED"},
	{id = "brightness", name = "BRIGHTNESS"},
	{id = "power", name = "WALL POWER", dev = true},
]


static func _track(id: String) -> Dictionary:
	return Economy.COIN_TRACKS.get(id, {})


## How many levels the track has (0 for an unknown id).
static func max_level(id: String) -> int:
	var track := _track(id)
	return track.costs.size() if not track.is_empty() else 0


## Coins for the next level up from `level` (0 when there is none: maxed or unknown).
static func cost(id: String, level: int) -> int:
	var track := _track(id)
	if track.is_empty() or level < 0 or level >= track.costs.size():
		return 0
	return track.costs[level]


## Coins invested in an upgrade at `level` (clamped to the track).
static func total_cost(id: String, level: int) -> int:
	var track := _track(id)
	var total := 0
	if not track.is_empty():
		for i in clampi(level, 0, track.costs.size()):
			total += int(track.costs[i])
	return total


## Coins needed to max every regular (non-dev) upgrade.
static func full_tree_cost() -> int:
	var total := 0
	for upgrade: Dictionary in LIST:
		if not upgrade.get("dev", false):
			total += total_cost(upgrade.id, max_level(upgrade.id))
	return total


static func get_upgrade(id: String) -> Dictionary:
	for upgrade: Dictionary in LIST:
		if upgrade.id == id:
			return upgrade
	return {}


## The track's effect at `level` (clamped; level 0 = the track's base).
static func value(id: String, level: int) -> float:
	var track := _track(id)
	if track.is_empty():
		return 0.0
	var l := clampi(level, 0, track.values.size())
	return float(track.base) if l == 0 else float(track.values[l - 1])


## How much further the slime's slime goes (the cost per tile is divided by this).
static func slime_factor(level: int) -> float:
	return value("slime", level)


## slime_factor in hundredths (115 = x1.15), for the randomizer's integer route maths.
static func slime_percent(level: int) -> int:
	return roundi(slime_factor(level) * 100.0)


static func speed_factor(level: int) -> float:
	return value("speed", level)


## Extra reach (px) of the slime's own light: unexplored floor and walls this far beyond its
## goo trail are revealed, and lit areas stay lit this much further away (see Economy radii).
static func light_reach(level: int) -> float:
	return value("brightness", level)


## The slime light's reveal / relight radius (px) at a BRIGHTNESS level.
static func reveal_radius(level: int) -> float:
	return Economy.REVEAL_RADIUS + light_reach(level)


static func relight_radius(level: int) -> float:
	return Economy.RELIGHT_RADIUS + light_reach(level)


## Wall damage (wall health is 100) dealt by a splat at `power_level`; `charge` is 0-1, how hard
## the leap was charged.
static func wall_damage(power_level: int, charge: float) -> float:
	return value("power", power_level) * lerpf(4.0, 12.0, clampf(charge, 0.0, 1.0))


## ---------------------------------------------------------------- migration from the old tree

## Coins an old-tree level held (level n cost n coins).
static func old_total_cost(old_level: int) -> int:
	var l := clampi(old_level, 0, Economy.OLD_TREE_LEVELS)
	return l * (l + 1) / 2


## The new level for a track that stood at `old_level` on the old 10-level tree: the highest level
## whose cumulative new cost fits in the coins invested (rounded down; the rest goes back into the
## player's hand, since coins in hand are derived). Dev wall power (free now) maps by equal damage.
static func migrate_level(id: String, old_level: int) -> int:
	var old := clampi(old_level, 0, Economy.OLD_TREE_LEVELS)
	if id == "power":
		return mini(floori(old / Economy.OLD_POWER_PER_LEVEL), max_level(id))
	var invested := old_total_cost(old)
	var level := 0
	while level < max_level(id) and total_cost(id, level + 1) <= invested:
		level += 1
	return level
