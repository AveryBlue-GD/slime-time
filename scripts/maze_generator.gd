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


## Randomizer maze (see Levels.random_config and docs/level-design.md section 5): a noise maze big
## enough that its longest route is at least ROOM_PCT % of the route the seed asks for (growing the
## seed's start size step by step up to Levels.RANDOM_MAX_CELLS; at the max size a few re-seeded
## noise fields are tried and the longest kept), then SpawnPicker picks the start from the seed
## (33% outer edge, 30% near it, 37% anywhere; its farthest cell at least the route away) and puts
## the chalice exactly `route` cells from it. Same seed and level, same maze, start and chalice.
## Adds `spawn_kind`, `spawn_rolled`, `diameter` (the longest route), `route_target` (cells asked
## for; goal_steps is shorter only when even the biggest maze couldn't hold it) and `noise_seed`.
## A Vector2i `config` (old callers/tests) means {cells = it} with the old 60%-of-longest rule.
const ROOM_PCT := 115
const MAX_SIZE_TRIES := 4


static func generate_random(config: Variant, maze_seed := 0) -> Dictionary:
	if config is Vector2i:
		return SpawnPicker.apply(generate_noise(config, maze_seed), maze_seed)
	var route: int = config.route
	var cells: Vector2i = config.cells
	var top := Levels.RANDOM_MAX_CELLS
	var noise_seed: int = config.seed
	var maze := {}
	var longest := 0
	var tries := 0
	while true:
		var attempt := generate_noise(cells, noise_seed)
		var d := SpawnPicker.diameter(attempt)
		if d > longest:
			maze = attempt
			longest = d
			maze.noise_seed = noise_seed
		if d * 100 >= route * ROOM_PCT or (cells == top and d >= route):
			maze = attempt
			maze.noise_seed = noise_seed
			break
		if cells != top:
			cells = Vector2i(mini(cells.x + maxi(2, cells.x / 8), top.x), mini(cells.y + maxi(1, cells.y / 8), top.y))
		else:
			tries += 1
			if tries >= MAX_SIZE_TRIES:
				break
			noise_seed = (config.seed * 31 + tries * 7919) % 2147483647
	SpawnPicker.apply(maze, config.seed, -1, route)
	maze.route_target = route
	return maze


## A story level's maze (see Levels.DATA and docs/level-design.md): a growing tree like `generate`
## that keeps going straight with chance `run` (longer corridors for the 8-tile leap), plus
## `loops` extra openings that join two far-apart parts of the maze (shortcuts, never next to a
## dead end so the coin dead ends survive), then a fixed spawn from SpawnPicker with the level's
## class (`spawn`) and seed, the chalice the farthest cell from it.
static func generate_level(config: Dictionary) -> Dictionary:
	var cells: Vector2i = config.cells
	var maze_seed: int = config.seed
	var branching: float = config.get("branching", 0.0)
	var run: float = config.get("run", 0.0)
	var size := cells * CELL_SPAN + Vector2i.ONE
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	walls.fill(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	var root := Vector2i(cells.x / 2, cells.y / 2)
	var heading := {root: Vector2i.ZERO}
	var active: Array[Vector2i] = [root]
	_open_cell(walls, size, root)
	while not active.is_empty():
		var index := active.size() - 1
		if rng.randf() < branching:
			index = rng.randi_range(0, active.size() - 1)
		var cell := active[index]
		var options: Array[Vector2i] = []
		for dir in DIRS:
			var next := cell + dir
			if _inside(next, cells) and not heading.has(next):
				options.append(next)
		if options.is_empty():
			active.remove_at(index)
			continue
		var chosen := options[rng.randi_range(0, options.size() - 1)]
		var ahead: Vector2i = cell + heading[cell]
		if heading[cell] != Vector2i.ZERO and ahead in options and rng.randf() < run:
			chosen = ahead
		heading[chosen] = chosen - cell
		_open_cell(walls, size, chosen)
		_open_between(walls, size, cell, chosen)
		active.append(chosen)
	var maze := {size = size, cells = cells, walls = walls, start = Vector2i.ZERO}
	_add_loops(maze, rng, int(config.get("loops", 0)))
	return SpawnPicker.apply(maze, maze_seed, int(config.get("spawn", -1)))


## Shortcut gaps must join cells at least this far apart along the passages.
const LOOP_MIN_SPAN := 10


static func _add_loops(maze: Dictionary, rng: RandomNumberGenerator, count: int) -> void:
	if count <= 0:
		return
	var options: Array[Vector2i] = []  # (cell index, 0 = right / 1 = down) packed as x = index, y = dir
	for y in maze.cells.y:
		for x in maze.cells.x:
			for d in 2:
				var next := Vector2i(x, y) + (Vector2i.RIGHT if d == 0 else Vector2i.DOWN)
				if _inside(next, maze.cells):
					options.append(Vector2i(y * maze.cells.x + x, d))
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := options[i]
		options[i] = options[j]
		options[j] = tmp
	var added := 0
	for option in options:
		if added >= count:
			break
		var a := Vector2i(option.x % maze.cells.x, option.x / maze.cells.x)
		var b := a + (Vector2i.RIGHT if option.y == 0 else Vector2i.DOWN)
		if b in open_neighbors(maze, a):
			continue
		if open_neighbors(maze, a).size() < 2 or open_neighbors(maze, b).size() < 2:
			continue  # keep dead ends (the coins live there)
		if distances_from(maze, a).get(b, 0) < LOOP_MIN_SPAN:
			continue
		_open_between(maze.walls, maze.size, a, b)
		added += 1


## How deep each dead end is: cells from it back to the nearest junction (3+ openings) or the
## start, counting the dead end itself. {cell: depth}
static func dead_end_depths(maze: Dictionary) -> Dictionary:
	var out := {}
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			if cell == maze.start or open_neighbors(maze, cell).size() != 1:
				continue
			var depth := 1
			var prev := cell
			var at: Vector2i = open_neighbors(maze, cell)[0]
			while at != maze.start:
				var around := open_neighbors(maze, at)
				if around.size() != 2:
					break
				depth += 1
				var next: Vector2i = around[0] if around[1] == prev else around[1]
				prev = at
				at = next
			out[cell] = depth
	return out


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
