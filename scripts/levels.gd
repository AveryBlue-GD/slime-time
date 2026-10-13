class_name Levels
extends RefCounted

## The 10 levels. Tune difficulty here. See docs/level-design.md.
## - cells:     maze size in cells (each cell is one open tile; corridors are 1 tile wide)
## - branching: 0 = long winding corridors, higher = more side branches and dead ends
## - run:       chance a corridor keeps going straight (long straights for the 8-tile leap)
## - loops:     shortcut gaps joining far-apart parts of the maze (late levels only)
## - spawn:     the start's class (SpawnPicker.Kind: 0 EDGE, 1 NEAR, 2 ANY); the exact cell is drawn by
##              SpawnPicker from the level's seed, so every player gets the same start
## - target:    fraction of the slime meter a perfect glide to the chalice uses, with no upgrades
## Seeds were searched (docs/level-design.md) so the path to the chalice stays close to the
## pre-v4 layout's (22, 30, 38 ... 100 cells) and each level has enough deep dead ends for its coins.
## Balanced around the upgrades (More Slime doubles the range at level 10): the first levels
## are easy with no upgrades at all, while level 10 can only be beaten without upgrades by an
## essentially perfect run (a perfect glide uses 99% of the meter).

const COUNT := 10

const DATA := [
	{cells = Vector2i(10, 6), seed = 1118, branching = 0.05, run = 0.35, loops = 0, spawn = 0, target = 0.45},
	{cells = Vector2i(12, 7), seed = 2136, branching = 0.06, run = 0.45, loops = 0, spawn = 1, target = 0.52},
	{cells = Vector2i(13, 8), seed = 3306, branching = 0.15, run = 0.45, loops = 0, spawn = 2, target = 0.58},
	{cells = Vector2i(15, 8), seed = 4071, branching = 0.20, run = 0.45, loops = 0, spawn = 0, target = 0.64},
	{cells = Vector2i(16, 9), seed = 5053, branching = 0.25, run = 0.45, loops = 0, spawn = 1, target = 0.70},
	{cells = Vector2i(18, 10), seed = 6206, branching = 0.18, run = 0.45, loops = 2, spawn = 2, target = 0.76},
	{cells = Vector2i(20, 11), seed = 7132, branching = 0.21, run = 0.45, loops = 3, spawn = 0, target = 0.82},
	{cells = Vector2i(22, 12), seed = 8131, branching = 0.12, run = 0.40, loops = 4, spawn = 1, target = 0.88},
	{cells = Vector2i(24, 13), seed = 9283, branching = 0.14, run = 0.40, loops = 5, spawn = 2, target = 0.94},
	{cells = Vector2i(26, 14), seed = 10383, branching = 0.10, run = 0.30, loops = 6, spawn = 0, target = 0.99},
]

## Solution paths (cells) of the pre-v4 layouts (corner start), normal and hard. Saves from before
## version 3 turn best times into medal tiers against the par of the layout they were set on.
const LEGACY_STEPS: Array[int] = [22, 30, 38, 46, 54, 62, 70, 80, 90, 100]
const LEGACY_HARD_STEPS: Array[int] = [25, 31, 39, 48, 57, 64, 72, 81, 92, 101]

## Hard mode plays different mazes (same sizes, their own seeds) on a much tighter budget: a
## perfect run (even cutting every corner) always needs 85% or more of the slime, and upgrades
## are switched off.
const HARD_SEEDS: Array[int] = [51089, 52223, 53226, 54019, 55041, 56205, 57062, 58160, 59062, 60900]
## Hard mazes' own shape: branching and run per level (searched like DATA, no loops).
const HARD_BRANCHING: Array[float] = [0.05, 0.06, 0.05, 0.20, 0.15, 0.18, 0.11, 0.24, 0.27, 0.30]
const HARD_RUN: Array[float] = [0.35, 0.45, 0.40, 0.45, 0.30, 0.45, 0.40, 0.45, 0.30, 0.45]
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
		config.branching = HARD_BRANCHING[clampi(level, 1, COUNT) - 1]
		config.run = HARD_RUN[clampi(level, 1, COUNT) - 1]
		config.loops = 0  # hard mode stays a tight single-route maze
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


## Par for a story level (cached; builds its maze once), without playing the level.
static func level_par(level: int, hard := false) -> float:
	var key := level + (100 if hard else 0)
	if not _par_cache.has(key):
		_par_cache[key] = par_for_path(story_maze(level, hard).goal_steps * MazeGenerator.CELL_SPAN - GRAB_REACH / TILE)
	return _par_cache[key]


## Par of a level's pre-v4 layout (used only to migrate best times from saves older than version 3
## into tiers, exactly as before).
static func legacy_par(level: int, hard := false) -> float:
	var steps: Array[int] = LEGACY_HARD_STEPS if hard else LEGACY_STEPS
	return par_for_path(steps[clampi(level, 1, COUNT) - 1] * MazeGenerator.CELL_SPAN - GRAB_REACH / TILE)


## A story level's maze, freshly built (the game may break walls in its own copy).
static func story_maze(level: int, hard := false) -> Dictionary:
	return MazeGenerator.generate_level(get_config(level, hard))


## Coins sit in dead ends this deep or deeper first (see coin_cells).
const COIN_DEEP := 3
static var _coin_key_cache := {}


## The cells holding a story level's coins, in priority order (the first Levels.COINS[level] of
## the level's dead ends, never the start or the chalice). Picked from the level's seed, so they
## are always the same:
## 1. dead ends at least COIN_DEEP cells deep, one per side branch of the solution route (a branch
##    = the route cell it hangs off), in seeded-shuffle order;
## 2. then other deep dead ends; 3. then the short stubs, only if a level runs out.
static func coin_cells(maze: Dictionary, level: int, maze_seed: int) -> Array[Vector2i]:
	var depths := MazeGenerator.dead_end_depths(maze)
	var ends: Array[Vector2i] = []
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			if depths.has(cell) and cell != maze.goal:
				ends.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed * 13 + 5
	for i in range(ends.size() - 1, 0, -1):  # a seeded shuffle
		var j := rng.randi_range(0, i)
		var swap := ends[i]
		ends[i] = ends[j]
		ends[j] = swap
	# Which route cell each cell's branch hangs off (multi-source BFS from the solution route).
	var attach := {}
	var queue: Array[Vector2i] = []
	for cell in MazeGenerator.shortest_path(maze, maze.start, maze.goal):
		attach[cell] = cell
		queue.append(cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in MazeGenerator.open_neighbors(maze, cell):
			if not attach.has(next):
				attach[next] = attach[cell]
				queue.append(next)
	var picked: Array[Vector2i] = []
	var branches := {}
	for pass_no in 3:
		for cell in ends:
			if cell in picked:
				continue
			var deep: bool = depths[cell] >= COIN_DEEP
			if pass_no == 0 and (not deep or branches.has(attach[cell])):
				continue
			if pass_no == 1 and not deep:
				continue
			picked.append(cell)
			branches[attach[cell]] = true
	return picked.slice(0, COINS[clampi(level, 1, COUNT) - 1])


## The coin keys (Progress.coin_key) of a normal-mode story level, in coin_cells order (cached).
static func coin_keys(level: int) -> Array[String]:
	level = clampi(level, 1, COUNT)
	if not _coin_key_cache.has(level):
		var keys: Array[String] = []
		for cell in coin_cells(story_maze(level), level, get_config(level).seed):
			keys.append("%d,%d" % [cell.x, cell.y])
		_coin_key_cache[level] = keys
	return _coin_key_cache[level]


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


## A seed code as shown and typed: "12345-2" = seed 12345 built for MORE SLIME level 2.
static func seed_code(maze_seed: int, slime_level: int) -> String:
	return "%d-%d" % [maze_seed, clampi(slime_level, 0, Upgrades.MAX_LEVEL)]


## Reads a typed seed code: Vector2i(seed, level). A plain number gives level -1 (the player's own
## level); anything that isn't a code gives Vector2i.ZERO.
static func parse_seed_code(text: String) -> Vector2i:
	var parts := text.strip_edges().split("-")
	if parts.size() < 1 or parts.size() > 2 or not parts[0].is_valid_int():
		return Vector2i.ZERO
	var value := parts[0].to_int()
	if value < 1 or value > 2_000_000_000:
		return Vector2i.ZERO
	var level := -1
	if parts.size() == 2:
		if not parts[1].is_valid_int() or parts[1].begins_with("+"):
			return Vector2i.ZERO
		level = parts[1].to_int()
		if level < 0 or level > Upgrades.MAX_LEVEL:
			return Vector2i.ZERO
	return Vector2i(value, level)


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
