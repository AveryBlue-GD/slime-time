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


## Randomizer (opens after the story, so players have upgrades): a noise maze with late-level tile
## wear; its size and slime budget come from the seed's usage roll (random_config, below).
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
## gliding speed (PAR_SPEED; upgrades don't move it) x PAR_SLACK plus PAR_EXTRA. Medal tiers are
## measured against it (game.gd passes its own speed).
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


## A story level's maze: a fresh deep copy of the cached build (the game may break walls in its own).
static func story_maze(level: int, hard := false) -> Dictionary:
	var key := clampi(level, 1, COUNT) + (100 if hard else 0)
	if not _maze_cache.has(key):
		_maze_cache[key] = MazeGenerator.generate_level(get_config(level, hard))
	return _maze_cache[key].duplicate(true)


## Story mazes are built from constants only, so each is built once (`story_maze` hands out deep
## copies: the game breaks walls in its own).
static var _maze_cache := {}
static var _coin_cell_cache := {}


## `coin_cells` of a normal-mode story level's own maze (cached; a copy).
static func story_coin_cells(level: int) -> Array[Vector2i]:
	level = clampi(level, 1, COUNT)
	if not _coin_cell_cache.has(level):
		_coin_cell_cache[level] = coin_cells(story_maze(level), level, get_config(level).seed)
	return _coin_cell_cache[level].duplicate()


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


## ---------------------------------------------------------------- randomizer sizing
## See docs/level-design.md section 5. Every randomizer maze rolls a USAGE u from its seed: the
## share of the player's slime meter a perfect run needs. The meter itself never changes for a
## player: a full meter glides RANDOM_METER_TILES tiles with no MORE SLIME (x Upgrades.slime_factor
## with it), and the maze's start-to-goal route is built to u x that capacity: a typical route
## (u ~0.58) grows with the slime the player can spend, a rare one is a 10% hop and a rare one a 95%
## marathon. The maze itself does not follow u: it is always sized for the 95% route of the level
## (random_cells), so a low-u seed just has its goal near the start. Hard mode keeps a fixed tight
## u (RANDOM_HARD_TARGET) and no upgrades.

## Tiles one full meter glides with no MORE SLIME. 136 = the old randomizer's median maze (route
## 58 cells at 85%), so a tile still costs what it used to at level 0.
const RANDOM_METER_TILES := 136
## Even a 10% maze has a real route.
const RANDOM_MIN_ROUTE := 6
## The quantiles of u in permille, every 1% of the seed roll (101 knots, linear in between): a
## Beta(2.1, 1.7) bell stretched over [0.10, 0.95]. Median 0.578, middle half 0.423-0.724,
## P(u <= 0.20) ~2.5%, P(u >= 0.90) ~2.3%; u = 0.10 itself needs roll 0 of 10,000.
const USAGE_QUANTILES: Array[int] = [100, 164, 190, 210, 227, 241, 255, 267, 279, 290, 300, 310, 320,
	329, 338, 347, 355, 363, 371, 379, 387, 394, 402, 409, 416, 423, 430, 437, 444, 450, 457, 463, 470,
	476, 483, 489, 495, 501, 507, 513, 519, 525, 531, 537, 543, 549, 555, 561, 567, 573, 578, 584, 590,
	596, 601, 607, 613, 619, 624, 630, 636, 642, 647, 653, 659, 665, 670, 676, 682, 688, 694, 700, 706,
	712, 718, 724, 730, 736, 742, 749, 755, 762, 768, 775, 782, 788, 796, 803, 810, 818, 825, 833, 842,
	850, 859, 869, 879, 891, 903, 919, 950]
const USAGE_SALT := 0x51e3d7
## No perfect run ever needs more than this (also caps a borrowed code above the player's level).
const RANDOM_MAX_USAGE := 0.95
## Maze size bounds (cells). The max is 1.5x the old max's area (the web build's fog texture
## stays under 600x330); the floor is the old base size 18 x 10, grown with MORE SLIME
## (random_floor_cells). RANDOM_MIN_CELLS is that floor at level 0.
const RANDOM_FLOOR_BASE := Vector2i(18, 10)
const RANDOM_MIN_CELLS := RANDOM_FLOOR_BASE
const RANDOM_MAX_CELLS := Vector2i(36, 20)


## The seed's usage in permille (100-950), from one integer roll; it depends on the seed only, so a
## seed keeps its character at every MORE SLIME level (the level scales the route, not u).
static func random_usage_permille(maze_seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed ^ USAGE_SALT
	var roll := rng.randi_range(0, 9999)
	var i := roll / 100
	if i >= 100:
		return USAGE_QUANTILES[100]
	return USAGE_QUANTILES[i] + (USAGE_QUANTILES[i + 1] - USAGE_QUANTILES[i]) * (roll % 100) / 100


static func random_usage(maze_seed: int, hard := false) -> float:
	return RANDOM_HARD_TARGET if hard else random_usage_permille(maze_seed) / 1000.0


## Tiles a full meter glides at a MORE SLIME level (the player's capacity).
static func random_capacity_tiles(slime_level: int) -> float:
	return RANDOM_METER_TILES * Upgrades.slime_factor(clampi(slime_level, 0, Upgrades.MAX_LEVEL))


## The start-to-chalice route (cells) a seed asks for at a MORE SLIME level: u x the capacity, the
## grab reach added back (a route of n cells is glided as 2n - 13/16 tiles), at least
## RANDOM_MIN_ROUTE. Integer maths only, so every platform gets the same number.
static func random_route_cells(maze_seed: int, hard := false, slime_level := 0) -> int:
	var level := 0 if hard else clampi(slime_level, 0, Upgrades.MAX_LEVEL)
	var permille := roundi(RANDOM_HARD_TARGET * 1000) if hard else random_usage_permille(maze_seed)
	return random_route_cells_for(permille, level)


## The route (cells) for a usage of `permille` at MORE SLIME `level` (see random_route_cells).
static func random_route_cells_for(permille: int, level: int) -> int:
	# u x 136 x (1 + level / 10) tiles, in 1/10000 tiles; + 0.8125 tiles of grab reach; / 2 tiles per cell, rounded.
	var tenthousandths := permille * RANDOM_METER_TILES * (10 + clampi(level, 0, Upgrades.MAX_LEVEL))
	return maxi(RANDOM_MIN_ROUTE, (tenthousandths + 8125 + 10000) / 20000)


## The longest route (cells) any seed asks for at a MORE SLIME level: u = RANDOM_MAX_USAGE (hard
## mode: its fixed u). Randomizer mazes are sized for this route, never for the seed's own u.
static func random_max_route_cells(slime_level := 0, hard := false) -> int:
	var level := 0 if hard else clampi(slime_level, 0, Upgrades.MAX_LEVEL)
	return random_route_cells_for(roundi((RANDOM_HARD_TARGET if hard else RANDOM_MAX_USAGE) * 1000), level)


## The smallest randomizer maze at a MORE SLIME level: the old base size (18 x 10) grown by
## sqrt(1 + 0.1 x level) per side, as the pre-usage randomizer did, within RANDOM_MAX_CELLS.
static func random_floor_cells(slime_level := 0, hard := false) -> Vector2i:
	var level := 0 if hard else clampi(slime_level, 0, Upgrades.MAX_LEVEL)
	var grow := sqrt(1.0 + 0.1 * level)
	return Vector2i(mini(roundi(RANDOM_FLOOR_BASE.x * grow), RANDOM_MAX_CELLS.x),
		mini(roundi(RANDOM_FLOOR_BASE.y * grow), RANDOM_MAX_CELLS.y))


## The size a randomizer maze starts from (MazeGenerator.generate_random grows it if its longest
## route falls short of the room it needs): aimed at a longest route of about 1.25 x the LONGEST
## route any seed asks for at this MORE SLIME level (random_max_route_cells) + 12 cells, so every
## maze is full size whatever its u; a low-u seed just puts its ticket closer to the start. Shape
## from the seed's two dice (18-24 by 10-13, the old base sizes, so a seed keeps its proportions),
## within random_floor_cells .. RANDOM_MAX_CELLS. Depends on the seed's dice and the level only.
static func random_cells(maze_seed: int, slime_level := 0, hard := false) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	var dice := Vector2(rng.randi_range(18, 24), rng.randi_range(10, 13))
	var room := random_max_route_cells(slime_level, hard)
	var side := (room * 1.25 + 12.0) / 4.6  # noise mazes' longest route is ~4.6 x sqrt(cells)
	var scale := side / sqrt(dice.x * dice.y)
	var low := random_floor_cells(slime_level, hard)
	return Vector2i(clampi(roundi(dice.x * scale), low.x, RANDOM_MAX_CELLS.x),
		clampi(roundi(dice.y * scale), low.y, RANDOM_MAX_CELLS.y))


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


## A randomizer maze's recipe: start size, seed, route (cells), usage u and the slime cost of one
## tile in percent of the meter at the code's MORE SLIME level (the player's own cost is that x
## the code's slime factor / the player's). `target` = u for older callers.
static func random_config(maze_seed: int, hard := false, slime_level := 0) -> Dictionary:
	var level := 0 if hard else clampi(slime_level, 0, Upgrades.MAX_LEVEL)
	var u := random_usage(maze_seed, hard)
	return {
		cells = random_cells(maze_seed, level, hard),
		seed = maze_seed,
		usage = u,
		target = u,
		route = random_route_cells(maze_seed, hard, level),
		room = random_max_route_cells(level, hard),
		slime_level = level,
		tile_cost = 100.0 / random_capacity_tiles(level),
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
