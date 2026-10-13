class_name SpawnPicker
extends RefCounted

## Where the slime starts, shared by the randomizer (a pick per seed) and the story levels (one
## fixed pick per level, from the level's own constant seed and a class chosen in Levels.DATA).
## See docs/level-design.md.
##
## Spawn classes, by a cell's EDGE DEPTH d = min(x, y, w - 1 - x, h - 1 - y) (cells from the
## maze's outer boundary; 0 = on the boundary ring):
## - EDGE (33%): a cell with d == 0 (the outer ring of cells, corners included)
## - NEAR (30%): a cell with 1 <= d <= NEAR_DEPTH (2): close to the edge, not on it
## - ANY  (37%): any cell of the maze, uniformly (it can land on the edge too)
## Which class: one integer roll 0..99 of a seeded RandomNumberGenerator (< 33 EDGE, < 63 NEAR,
## else ANY). Within the class the cells (row-major) get a seeded Fisher-Yates shuffle and the
## first one whose farthest cell is at least MIN_ROUTE_PCT % of the maze's longest route wins;
## that farthest cell is the chalice. If no cell of the class qualifies, the next class is tried
## (EDGE -> NEAR -> ANY -> EDGE); ANY always has one (an end of the longest route).
## Only integer RNG calls (randi_range) and integer comparisons are used, so the web build and the
## desktop build pick exactly the same cell for the same seed.
##
## Randomizer mazes ask for a ROUTE length instead (Levels.random_route_cells: the seed's usage x
## the player's meter). Then a start qualifies when its farthest cell is at least `route` cells away
## (the minimum-route rule is relative to the target, not the maze's longest route), and the
## chalice is a seeded pick among the cells exactly `route` cells from it (BFS distances are
## contiguous, so one always exists). Class order and fallbacks are as above; if no cell at all
## reaches `route` (the maze is too small: MazeGenerator.generate_random grows it first, so this is
## rare), the longest route is used instead.

enum Kind { EDGE, NEAR, ANY }

const KIND_NAMES: Array[String] = ["EDGE", "NEAR", "ANY"]
## Roll thresholds out of 100: EDGE below 33, NEAR below 63, ANY the rest (37).
const EDGE_PCT := 33
const NEAR_PCT := 30
## Route mode: BFS-scanned starts per class before the full scan.
const SCAN_LIMIT := 24
const NEAR_DEPTH := 2
## The start-to-chalice route must be at least this share (percent) of the longest route.
const MIN_ROUTE_PCT := 60
const SALT := 0x2545f491


## Cells between `cell` and the nearest side of the maze (0 = on the outer ring).
static func edge_depth(cell: Vector2i, cells: Vector2i) -> int:
	return mini(mini(cell.x, cell.y), mini(cells.x - 1 - cell.x, cells.y - 1 - cell.y))


## The class a seed rolls (before the minimum-route rule).
static func roll_kind(pick_seed: int) -> int:
	return _kind_for_roll(_rng(pick_seed).randi_range(0, 99))


static func _kind_for_roll(roll: int) -> int:
	if roll < EDGE_PCT:
		return Kind.EDGE
	if roll < EDGE_PCT + NEAR_PCT:
		return Kind.NEAR
	return Kind.ANY


static func in_kind(cell: Vector2i, cells: Vector2i, kind: int) -> bool:
	match kind:
		Kind.EDGE:
			return edge_depth(cell, cells) == 0
		Kind.NEAR:
			var d := edge_depth(cell, cells)
			return d >= 1 and d <= NEAR_DEPTH
	return true


## The cells of a class, row-major.
static func cells_of(kind: int, cells: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in cells.y:
		for x in cells.x:
			if in_kind(Vector2i(x, y), cells, kind):
				out.append(Vector2i(x, y))
	return out


## The cell farthest from `from` along the passages, and how far: {cell, steps}. Ties go to the
## first cell in row-major order, so it never depends on dictionary order.
static func farthest(maze: Dictionary, from: Vector2i) -> Dictionary:
	var dist := MazeGenerator.distances_from(maze, from)
	var best := from
	var steps := 0
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			var d: int = dist.get(cell, -1)
			if d > steps:
				steps = d
				best = cell
	return {cell = best, steps = steps}


## The maze's longest route in cells (double-sweep BFS: exact on the loop-free story mazes, a
## close lower bound on the randomizer's looped ones).
static func diameter(maze: Dictionary) -> int:
	var a: Dictionary = farthest(maze, Vector2i.ZERO)
	return farthest(maze, a.cell).steps


## Picks the start. `kind` -1 rolls the class from the seed; 0-2 forces it (story levels).
## `route` > 0 asks for a chalice exactly that many cells from the start (randomizer).
## Returns {start, goal, steps, kind (the class used), rolled (the class asked for), diameter}.
static func pick(maze: Dictionary, pick_seed: int, kind := -1, route := -1) -> Dictionary:
	var rng := _rng(pick_seed)
	var roll := rng.randi_range(0, 99)  # always drawn, so a forced class leaves the shuffle the same
	var rolled := kind if kind >= 0 and kind <= Kind.ANY else _kind_for_roll(roll)
	var longest := diameter(maze)
	# Route mode scans only the first SCAN_LIMIT shuffled starts of each class (each costs a BFS);
	# only if none of them has a long enough route does a second pass scan them all, as before.
	for pass_no in (2 if route > 0 else 1):
		var limit: int = SCAN_LIMIT if route > 0 and pass_no == 0 else 1 << 30
		for i in 3:
			var k := (rolled + i) % 3
			var options := cells_of(k, maze.cells)
			for j in range(options.size() - 1, 0, -1):  # seeded Fisher-Yates, integer draws only
				var swap := rng.randi_range(0, j)
				var tmp := options[j]
				options[j] = options[swap]
				options[swap] = tmp
			for n in mini(options.size(), limit):
				var cell := options[n]
				var far: Dictionary = farthest(maze, cell)
				if route > 0:
					if far.steps >= route:
						return {start = cell, goal = cell_at_distance(maze, cell, route, rng), steps = route, kind = k, rolled = rolled, diameter = longest}
				elif far.steps * 100 >= MIN_ROUTE_PCT * longest:
					return {start = cell, goal = far.cell, steps = far.steps, kind = k, rolled = rolled, diameter = longest}
	# Unreachable (an end of the longest route always qualifies); keep a sane answer anyway.
	var end: Dictionary = farthest(maze, Vector2i.ZERO)
	var back: Dictionary = farthest(maze, end.cell)
	return {start = end.cell, goal = back.cell, steps = back.steps, kind = Kind.ANY, rolled = rolled, diameter = longest}


## A seeded pick among the cells exactly `steps` cells from `from` (row-major order, one integer draw).
static func cell_at_distance(maze: Dictionary, from: Vector2i, steps: int, rng: RandomNumberGenerator) -> Vector2i:
	var dist := MazeGenerator.distances_from(maze, from)
	var ring: Array[Vector2i] = []
	for y in maze.cells.y:
		for x in maze.cells.x:
			if dist.get(Vector2i(x, y), -1) == steps:
				ring.append(Vector2i(x, y))
	return ring[rng.randi_range(0, ring.size() - 1)]


## Puts a pick into the maze dictionary (start, goal, goal_steps, spawn_kind, spawn_rolled, diameter).
static func apply(maze: Dictionary, pick_seed: int, kind := -1, route := -1) -> Dictionary:
	var result := pick(maze, pick_seed, kind, route)
	maze.start = result.start
	maze.goal = result.goal
	maze.goal_steps = result.steps
	maze.spawn_kind = result.kind
	maze.spawn_rolled = result.rolled
	maze.diameter = result.diameter
	return maze


static func _rng(pick_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = pick_seed ^ SALT
	return rng
