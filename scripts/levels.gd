class_name Levels
extends RefCounted

## The 10 levels. Tune difficulty here.
## - cells:     maze size in cells (each cell is one open tile; corridors are 1 tile wide)
## - branching: 0 = long winding corridors, higher = more side branches and dead ends
## - target:    fraction of the slime meter a perfect glide to the chalice uses, with no upgrades
## Seeds were picked so the path to the chalice grows steadily: 22, 30, 38 ... 100 cells.
## Balanced around the upgrades (More Slime doubles the range at level 10): the first levels
## are easy with no upgrades at all, while level 10 can only be beaten without upgrades by an
## essentially perfect run (a perfect glide uses 99% of the meter).

const COUNT := 10

const DATA := [
	{cells = Vector2i(10, 6), seed = 1078, branching = 0.05, target = 0.45},
	{cells = Vector2i(12, 7), seed = 2019, branching = 0.10, target = 0.52},
	{cells = Vector2i(13, 8), seed = 3071, branching = 0.15, target = 0.58},
	{cells = Vector2i(15, 8), seed = 4003, branching = 0.20, target = 0.64},
	{cells = Vector2i(16, 9), seed = 5018, branching = 0.25, target = 0.70},
	{cells = Vector2i(18, 10), seed = 6041, branching = 0.30, target = 0.76},
	{cells = Vector2i(20, 11), seed = 7057, branching = 0.35, target = 0.82},
	{cells = Vector2i(22, 12), seed = 8070, branching = 0.40, target = 0.88},
	{cells = Vector2i(24, 13), seed = 9256, branching = 0.45, target = 0.94},
	{cells = Vector2i(26, 14), seed = 10366, branching = 0.50, target = 0.99},
]

## Hard mode plays different mazes (same sizes, their own seeds) on a much tighter budget: a
## perfect run (even cutting every corner) always needs 85% or more of the slime, and upgrades
## are switched off.
const HARD_SEEDS: Array[int] = [51001, 52007, 53000, 54014, 55006, 56021, 57017, 58001, 59027, 60855]
const HARD_TARGETS: Array[float] = [0.89, 0.90, 0.91, 0.91, 0.92, 0.93, 0.95, 0.96, 0.98, 1.0]
const RANDOM_HARD_TARGET := 0.9

## Coins hidden at dead ends in each story level (never in randomizer mazes). They add up to
## Upgrades.full_tree_cost() (165): finding every coin maxes the whole upgrade tree. Each level
## has at least this many dead ends.
const COINS: Array[int] = [6, 9, 7, 12, 14, 17, 20, 22, 27, 31]


## Coins hidden across the whole story (finding them all unlocks the rainbow skin).
static func total_coins() -> int:
	var total := 0
	for n in COINS:
		total += n
	return total

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


## Randomizer (opens after the story, so players have upgrades): a large noise maze with a
## late-level slime budget and tile wear.
const RANDOM_TARGET := 0.85
const RANDOM_TILE_LEVEL := 6


static func get_config(level: int, hard := false) -> Dictionary:
	var config: Dictionary = DATA[clampi(level, 1, COUNT) - 1]
	if hard:
		config = config.duplicate()
		config.seed = HARD_SEEDS[clampi(level, 1, COUNT) - 1]
		config.target = HARD_TARGETS[clampi(level, 1, COUNT) - 1]
	return config


## Par time (seconds) for a maze whose solution is `path_tiles` tiles: the path at the slime's BASE
## gliding speed (PAR_SPEED; upgrades don't move it) x PAR_SLACK plus PAR_EXTRA. Medal tiers and
## the randomizer's under-par ticket bonus are measured against it (game.gd passes its own speed).
const PAR_SPEED := 72.0
const PAR_SLACK := 1.35
const PAR_EXTRA := 1.0
## How far short of the chalice's center the slime grabs it (chalice radius 6 + slime radius 7), px.
const GRAB_REACH := 13.0
const TILE := 16

static var _par_cache := {}


static func par_for_path(path_tiles: float, speed := PAR_SPEED) -> float:
	return path_tiles * TILE / speed * PAR_SLACK + PAR_EXTRA


## Par for a story level (cached; builds its maze once). Used to turn an old save's best times
## into medal tiers without playing the level.
static func level_par(level: int, hard := false) -> float:
	var key := level + (100 if hard else 0)
	if not _par_cache.has(key):
		var config := get_config(level, hard)
		var maze := MazeGenerator.generate(config.cells, config.seed, config.branching)
		_par_cache[key] = par_for_path(maze.goal_steps * MazeGenerator.CELL_SPAN - GRAB_REACH / TILE)
	return _par_cache[key]


## Randomizer mazes grow with the slime the player can spend: the base size (18-24 x 10-13 cells)
## is multiplied by sqrt(Upgrades.slime_factor), so the area, and about the path, grows with the
## meter (x1.0 with no MORE SLIME, x1.41 per side at level 10), up to RANDOM_MAX_CELLS (that is
## 1040x560 px of maze, about 1.5x story level 10's area, which the web build handles).
const RANDOM_MAX_CELLS := Vector2i(30, 16)


## Randomizer maze size for a seed and a MORE SLIME level. The two dice are rolled first, whatever
## the level, so one seed keeps its character at every level.
static func random_cells(maze_seed: int, slime_level := 0) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	var base := Vector2i(rng.randi_range(18, 24), rng.randi_range(10, 13))
	var grow := sqrt(Upgrades.slime_factor(clampi(slime_level, 0, Upgrades.MAX_LEVEL)))
	return Vector2i(mini(roundi(base.x * grow), RANDOM_MAX_CELLS.x), mini(roundi(base.y * grow), RANDOM_MAX_CELLS.y))


static func random_config(maze_seed: int, hard := false, slime_level := 0) -> Dictionary:
	return {
		cells = random_cells(maze_seed, 0 if hard else slime_level),
		seed = maze_seed,
		target = RANDOM_HARD_TARGET if hard else RANDOM_TARGET,
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
