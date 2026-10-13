class_name MazeGenerator
extends RefCounted

## "Growing tree" maze. Each maze cell is a single open tile with 1-tile walls between cells,
## so corridors are exactly one tile wide and the tile grid is (cells * 2 + 1).
## The same seed gives the same maze.
## branching 0 always extends the newest corridor (long winding paths, few dead ends);
## higher values sometimes branch from older cells instead (more side passages and dead ends).

## Open tiles per cell side, and tiles from one cell to the next (open + wall).
const OPEN := 1
const CELL_SPAN := OPEN + 1
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## Returns {size: Vector2i (tiles), cells: Vector2i, walls: PackedByteArray (1 = wall, row-major),
## start: Vector2i (cell), goal: Vector2i (cell farthest from start), goal_steps: int (cells)}.
static func generate(cells: Vector2i, maze_seed: int, branching := 0.0) -> Dictionary:
	var size := cells * CELL_SPAN + Vector2i.ONE
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	walls.fill(1)

	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed

	var start := Vector2i.ZERO
	var visited := {start: true}
	var active: Array[Vector2i] = [start]
	_open_cell(walls, size, start)

	while not active.is_empty():
		var index := active.size() - 1
		if rng.randf() < branching:
			index = rng.randi_range(0, active.size() - 1)
		var cell := active[index]
		var options: Array[Vector2i] = []
		for dir in DIRS:
			var next := cell + dir
			if _inside(next, cells) and not visited.has(next):
				options.append(next)
		if options.is_empty():
			active.remove_at(index)
			continue
		var chosen := options[rng.randi_range(0, options.size() - 1)]
		visited[chosen] = true
		_open_cell(walls, size, chosen)
		_open_between(walls, size, cell, chosen)
		active.append(chosen)

	var maze := {size = size, cells = cells, walls = walls, start = start}
	var distances := distances_from(maze, start)
	var goal := start
	for cell: Vector2i in distances:
		if distances[cell] > distances[goal]:
			goal = cell
	maze.goal = goal
	maze.goal_steps = distances[goal]
	return maze


## Randomizer maze shaped by a noise field. Always completable:
## 1. A spanning tree is grown over every cell, so every cell connects to every other.
##    The tree prefers to extend toward the neighbor where the noise is highest, so corridors
##    follow the noise's ridges and flow in long organic curves instead of a regular weave.
## 2. Extra walls are knocked out where a second noise layer is high, adding loops
##    (only ever removing walls, which can't disconnect anything).
## 3. The start-to-goal path is checked with a breadth-first search before returning.
static func generate_noise(cells: Vector2i, maze_seed: int) -> Dictionary:
	var size := cells * CELL_SPAN + Vector2i.ONE
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	walls.fill(1)

	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	var flow := FastNoiseLite.new()
	flow.seed = maze_seed
	flow.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	flow.frequency = 0.09
	var loops := FastNoiseLite.new()
	loops.seed = maze_seed ^ 0x5f3759df
	loops.frequency = 0.15

	var start := Vector2i.ZERO
	var visited := {start: true}
	var active: Array[Vector2i] = [start]
	_open_cell(walls, size, start)
	while not active.is_empty():
		# Branch from an older cell where the noise is low, keep extending where it's high.
		var index := active.size() - 1
		if rng.randf() < 0.35 - 0.3 * flow.get_noise_2dv(Vector2(active[index])):
			index = rng.randi_range(0, active.size() - 1)
		var cell := active[index]
		var best := Vector2i(-1, -1)
		var best_score := -INF
		for dir in DIRS:
			var next := cell + dir
			if not _inside(next, cells) or visited.has(next):
				continue
			var score := flow.get_noise_2dv(Vector2(next)) + rng.randf() * 0.35
			if score > best_score:
				best_score = score
				best = next
		if best.x < 0:
			active.remove_at(index)
			continue
		visited[best] = true
		_open_cell(walls, size, best)
		_open_between(walls, size, cell, best)
		active.append(best)

	for y in cells.y:
		for x in cells.x:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next := cell + dir
				if _inside(next, cells) and loops.get_noise_2dv(Vector2(cell) + Vector2(dir) * 0.5) > 0.45 \
						and rng.randf() < 0.6:
					_open_between(walls, size, cell, next)

	var maze := {size = size, cells = cells, walls = walls, start = start}
	var distances := distances_from(maze, start)
	var goal := start
	for cell: Vector2i in distances:
		if distances[cell] > distances[goal]:
			goal = cell
	maze.goal = goal
	maze.goal_steps = distances[goal]
	assert(is_completable(maze), "noise maze %d is not fully connected" % maze_seed)
	return maze


## How much of the maze's longest route (its diameter) the start-to-chalice route must be at least.
const SPAWN_MIN_ROUTE := 0.75
## Seeded tries at a start cell before settling for the best one found.
const SPAWN_TRIES := 24


## Randomizer maze with a random start: the noise maze above, then a start cell picked from the
## seed among the cells whose farthest cell is at least SPAWN_MIN_ROUTE of the longest route in the
## maze (so the slime starts in an outer area, never next to the chalice), and the chalice is the
## cell farthest from it. Same seed, same maze, same start. Adds `ref_steps` (cells): the longest
## route, which the slime budget is calibrated on, so a shorter route here only leaves slack.
static func generate_random(cells: Vector2i, maze_seed: int) -> Dictionary:
	var maze := generate_noise(cells, maze_seed)
	var far := distances_from(maze, maze.goal)  # maze.goal is the cell farthest from the corner
	var diameter := 0
	for cell: Vector2i in far:
		diameter = maxi(diameter, far[cell])
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed ^ 0x2545f491
	var best_start := Vector2i.ZERO
	var best_goal: Vector2i = maze.goal
	var best_steps := 0
	for i in SPAWN_TRIES:
		var start := Vector2i(rng.randi_range(0, cells.x - 1), rng.randi_range(0, cells.y - 1))
		var reach := distances_from(maze, start)
		var goal := start
		for cell: Vector2i in reach:
			if reach[cell] > reach[goal]:
				goal = cell
		if reach[goal] > best_steps:
			best_steps = reach[goal]
			best_start = start
			best_goal = goal
		if reach[goal] >= SPAWN_MIN_ROUTE * diameter:
			break
	maze.start = best_start
	maze.goal = best_goal
	maze.goal_steps = best_steps
	maze.ref_steps = maxi(diameter, best_steps)
	return maze


## True when every cell (and so the goal) can be reached from the start.
static func is_completable(maze: Dictionary) -> bool:
	var reached := distances_from(maze, maze.start)
	return reached.size() == maze.cells.x * maze.cells.y and reached.has(maze.get("goal", maze.start))


## Pixel position of the middle of a cell's open area.
static func cell_center(cell: Vector2i, tile_size: int) -> Vector2:
	return (Vector2(cell * CELL_SPAN + Vector2i.ONE) + Vector2.ONE * OPEN / 2.0) * tile_size


static func is_wall(maze: Dictionary, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= maze.size.x or tile.y >= maze.size.y:
		return true
	return maze.walls[tile.y * maze.size.x + tile.x] == 1


## Cells from `from` to `to` along open passages (inclusive).
static func shortest_path(maze: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			break
		for next in open_neighbors(maze, cell):
			if not came_from.has(next):
				came_from[next] = cell
				queue.append(next)
	var path: Array[Vector2i] = [to]
	while path[0] != from:
		path.push_front(came_from[path[0]])
	return path


## Number of cells with exactly one opening (excluding the start).
static func dead_end_count(maze: Dictionary) -> int:
	var count := 0
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			if cell != maze.start and open_neighbors(maze, cell).size() == 1:
				count += 1
	return count


static func distances_from(maze: Dictionary, from: Vector2i) -> Dictionary:
	var distances := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in open_neighbors(maze, cell):
			if not distances.has(next):
				distances[next] = distances[cell] + 1
				queue.append(next)
	return distances


static func open_neighbors(maze: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base := cell * CELL_SPAN + Vector2i.ONE
	for dir in DIRS:
		var between := base + Vector2i(OPEN if dir.x > 0 else (-1 if dir.x < 0 else 0),
			OPEN if dir.y > 0 else (-1 if dir.y < 0 else 0))
		if _inside(cell + dir, maze.cells) and not is_wall(maze, between):
			result.append(cell + dir)
	return result


static func _inside(cell: Vector2i, cells: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells.x and cell.y < cells.y


static func _open_cell(walls: PackedByteArray, size: Vector2i, cell: Vector2i) -> void:
	for dy in OPEN:
		for dx in OPEN:
			walls[(cell.y * CELL_SPAN + 1 + dy) * size.x + cell.x * CELL_SPAN + 1 + dx] = 0


static func _open_between(walls: PackedByteArray, size: Vector2i, a: Vector2i, b: Vector2i) -> void:
	if a.x != b.x:
		var x := maxi(a.x, b.x) * CELL_SPAN
		for dy in OPEN:
			walls[(a.y * CELL_SPAN + 1 + dy) * size.x + x] = 0
	else:
		var y := maxi(a.y, b.y) * CELL_SPAN
		for dx in OPEN:
			walls[y * size.x + a.x * CELL_SPAN + 1 + dx] = 0
