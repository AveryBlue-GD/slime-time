class_name Levels
extends RefCounted

## The 10 levels. Tune difficulty here.
## - cells:     maze size in cells (each cell is one open tile; corridors are 1 tile wide)
## - branching: 0 = long winding corridors, higher = more side branches and dead ends
## - target:    fraction of the slime meter a perfect glide to the chalice uses
## Seeds were picked so the path to the chalice grows steadily: 22, 26, 30 ... 66 cells.

const COUNT := 10

const DATA := [
	{cells = Vector2i(10, 6), seed = 1078, branching = 0.05, target = 0.60},
	{cells = Vector2i(11, 7), seed = 2016, branching = 0.10, target = 0.63},
	{cells = Vector2i(12, 7), seed = 3007, branching = 0.15, target = 0.66},
	{cells = Vector2i(13, 8), seed = 4003, branching = 0.20, target = 0.70},
	{cells = Vector2i(14, 8), seed = 5006, branching = 0.25, target = 0.73},
	{cells = Vector2i(16, 9), seed = 6012, branching = 0.30, target = 0.77},
	{cells = Vector2i(17, 10), seed = 7038, branching = 0.35, target = 0.80},
	{cells = Vector2i(18, 10), seed = 8042, branching = 0.40, target = 0.83},
	{cells = Vector2i(20, 11), seed = 9005, branching = 0.45, target = 0.87},
	{cells = Vector2i(22, 12), seed = 10012, branching = 0.50, target = 0.90},
]

## Coins hidden at dead ends in each story level (never in randomizer mazes). They add up to
## Upgrades.full_tree_cost() (165): finding every coin maxes the whole upgrade tree. Each level
## has at least this many dead ends.
const COINS: Array[int] = [6, 9, 7, 12, 14, 17, 20, 22, 27, 31]

## Wall damage weights (intact, cracked, crumbling, broken) for level 1 and level 10;
## levels in between blend from one to the other.
const DAMAGE_FIRST := [60.0, 30.0, 8.0, 2.0]
const DAMAGE_LAST := [15.0, 30.0, 30.0, 25.0]
## Wall style weights: plain, mossy, stained.
const WALL_STYLE := [70.0, 15.0, 15.0]
## Floor type weights for level 1 and level 10 (order matches FLOOR_TYPES in the art script,
## minus rubble, which is placed under broken walls).
const FLOOR_FIRST := [60.0, 10.0, 10.0, 6.0, 8.0, 2.0, 4.0]
const FLOOR_LAST := [30.0, 18.0, 12.0, 12.0, 10.0, 10.0, 8.0]


## Randomizer: a mid-sized noise maze with a mid-level slime budget and tile wear.
const RANDOM_TARGET := 0.75
const RANDOM_TILE_LEVEL := 6


static func get_config(level: int) -> Dictionary:
	return DATA[clampi(level, 1, COUNT) - 1]


static func random_config(maze_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	return {
		cells = Vector2i(rng.randi_range(14, 18), rng.randi_range(8, 10)),
		seed = maze_seed,
		target = RANDOM_TARGET,
		tile_level = RANDOM_TILE_LEVEL,
	}


static func damage_weights(level: int) -> PackedFloat32Array:
	return _blend(DAMAGE_FIRST, DAMAGE_LAST, level)


static func floor_weights(level: int) -> PackedFloat32Array:
	return _blend(FLOOR_FIRST, FLOOR_LAST, level)


static func _blend(first: Array, last: Array, level: int) -> PackedFloat32Array:
	var t := float(clampi(level, 1, COUNT) - 1) / (COUNT - 1)
	var out := PackedFloat32Array()
	for i in first.size():
		out.append(lerpf(first[i], last[i], t))
	return out
