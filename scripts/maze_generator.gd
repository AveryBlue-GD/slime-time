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
	_set_goal_farthest(maze, start)
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
	_set_goal_farthest(maze, start)
	assert(is_completable(maze), "noise maze %d is not fully connected" % maze_seed)
	return maze


## Randomizer maze (see Levels.random_config and docs/level-design.md section 5): a noise maze big
## enough that its longest route is at least ROOM_PCT % of `room`, the LONGEST route any seed asks
## for at this MORE SLIME level (growing the seed's start size step by step up to
## Levels.RANDOM_MAX_CELLS; at the max size, until it holds `room` itself, a few re-seeded noise
## fields are tried and the longest kept). The maze never depends on the seed's own u: only the
## start and the goal do. SpawnPicker then picks the start from the seed (33% outer edge, 30% near
## it, 37% anywhere; its farthest cell at least the route away) and puts the goal exactly `route`
## cells from it (a low-u seed's goal can be close to the start). Same seed and level, same maze,
## start and goal. Adds `spawn_kind`, `spawn_rolled`, `diameter` (the longest route),
## `route_target` (cells asked for; goal_steps is shorter only when even the biggest maze couldn't
## hold it) and `noise_seed`. A Vector2i `config` (old callers/tests) means {cells = it} with the
## old 60%-of-longest rule.
const ROOM_PCT := 115
const MAX_SIZE_TRIES := 4


static func generate_random(config: Variant, maze_seed := 0) -> Dictionary:
	if config is Vector2i:
		return SpawnPicker.apply(generate_noise(config, maze_seed), maze_seed)
	var route: int = config.route
	var room: int = maxi(int(config.get("room", route)), route)
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
		if d * 100 >= room * ROOM_PCT or (cells == top and d >= room):
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
	return SpawnPicker.apply(_grow_level(config), int(config.seed), int(config.get("spawn", -1)))


## A hard story level's maze (Levels.get_config(level, true), docs/level-design.md section 7): the
## growing tree of generate_level, built at `cells` and grown (+1/8 per side, at least 2 x 1) up to
## `max_cells` until its longest route is at least HARD_ROOM_PCT % of `route`; at the max size up to
## MAX_SIZE_TRIES re-seeded trees are tried and the longest kept. Then SpawnPicker.pick_farthest_at
## picks the start in the level's class (pick seed = the level's seed) whose farthest cell is exactly
## `route` cells away, and puts the chalice on that farthest cell (like every story level).
## Deterministic: same config, same maze. Adds `maze_seed` (the tree's seed) and `route_target`.
const HARD_ROOM_PCT := 115


static func generate_hard_level(config: Dictionary) -> Dictionary:
	var route: int = config.route
	var cells: Vector2i = config.cells
	var top: Vector2i = config.get("max_cells", cells)
	var tree := config.duplicate()
	var maze := {}
	var longest := -1
	var tries := 0
	while true:
		tree.cells = cells
		var attempt := _grow_level(tree)
		var d := SpawnPicker.diameter(attempt)
		if d > longest:
			maze = attempt
			longest = d
			maze.maze_seed = tree.seed
		if d * 100 >= route * HARD_ROOM_PCT:
			maze = attempt
			maze.maze_seed = tree.seed
			break
		if cells != top:
			cells = Vector2i(mini(cells.x + maxi(2, cells.x / 8), top.x), mini(cells.y + maxi(1, cells.y / 8), top.y))
		else:
			tries += 1
			if tries >= MAX_SIZE_TRIES:
				break
			tree.seed = (int(config.seed) * 31 + tries * 7919) % 2147483647
	SpawnPicker.apply(maze, int(config.seed), int(config.get("spawn", -1)), route, true)
	maze.route_target = route
	return maze


## generate_level's growing tree + loops, before the spawn pick (start = the corner placeholder).
static func _grow_level(config: Dictionary) -> Dictionary:
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
	return maze


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
		if _within_steps(maze, a, b, LOOP_MIN_SPAN):
			continue
		_open_between(maze.walls, maze.size, a, b)
		added += 1


## How deep each dead end is: cells from it back to the nearest junction (3+ openings) or the
## start, counting the dead end itself. {cell: depth}
static func dead_end_depths(maze: Dictionary) -> Dictionary:
	var links := cell_links(maze)
	var width: int = maze.cells.x
	var start: int = maze.start.y * width + maze.start.x
	var out := {}
	for i in links.size():  # row by row, like the cells
		if i == start or LINK_COUNT[links[i]] != 1:
			continue
		var depth := 1
		var prev := i
		var at := link_step(i, links[i], width)
		while at != start:
			var around := links[at]
			if LINK_COUNT[around] != 2:
				break
			depth += 1
			var next := link_step(at, around & ~_link_toward(at, prev, width), width)
			prev = at
			at = next
		out[Vector2i(i % width, i / width)] = depth
	return out


## Each cell's open sides as a bit mask in DIRS order (1 right, 2 left, 4 down, 8 up), by cell index
## (y * cells.x + x): what open_neighbors finds, for every cell at once on flat arrays.
static func cell_links(maze: Dictionary) -> PackedByteArray:
	var width: int = maze.cells.x
	var height: int = maze.cells.y
	var size_x: int = maze.size.x
	var walls: PackedByteArray = maze.walls
	var links := PackedByteArray()
	links.resize(width * height)
	for y in height:
		for x in width:
			var tile := (y * CELL_SPAN + 1) * size_x + x * CELL_SPAN + 1  # the cell's open tile
			var mask := 0
			if x + 1 < width and walls[tile + OPEN] != 1:
				mask |= 1
			if x > 0 and walls[tile - 1] != 1:
				mask |= 2
			if y + 1 < height and walls[tile + OPEN * size_x] != 1:
				mask |= 4
			if y > 0 and walls[tile - size_x] != 1:
				mask |= 8
			links[y * width + x] = mask
	return links


## How many sides a cell_links mask has open.
const LINK_COUNT: Array[int] = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4]


## The cell index past the first open side (DIRS order) in `mask`, from cell index `at`.
static func link_step(at: int, mask: int, width: int) -> int:
	if mask & 1:
		return at + 1
	if mask & 2:
		return at - 1
	if mask & 4:
		return at + width
	return at - width


## The cell_links bit from cell index `at` toward its neighbor `to`.
static func _link_toward(at: int, to: int, width: int) -> int:
	if to == at + 1:
		return 1
	if to == at - 1:
		return 2
	return 4 if to == at + width else 8


## True when every cell (and so the goal) can be reached from the start.
static func is_completable(maze: Dictionary) -> bool:
	var goal: Vector2i = maze.get("goal", maze.start)
	if not _inside(maze.start, maze.cells):  # (only the start itself is reached)
		return maze.cells.x * maze.cells.y == 1 and goal == maze.start
	return not distance_grid(maze, maze.start).has(-1) and _inside(goal, maze.cells)


## Pixel position of the middle of a cell's open area.
static func cell_center(cell: Vector2i, tile_size: int) -> Vector2:
	return (Vector2(cell * CELL_SPAN + Vector2i.ONE) + Vector2.ONE * OPEN / 2.0) * tile_size


static func is_wall(maze: Dictionary, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= maze.size.x or tile.y >= maze.size.y:
		return true
	return maze.walls[tile.y * maze.size.x + tile.x] == 1


## Cells from `from` to `to` along open passages (inclusive).
static func shortest_path(maze: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	# Breadth-first, neighbors in DIRS order (as open_neighbors), on flat arrays.
	var width: int = maze.cells.x
	var links := cell_links(maze)
	var came_from := PackedInt32Array()
	came_from.resize(links.size())
	came_from.fill(-1)
	var source := from.y * width + from.x
	var target := to.y * width + to.x
	came_from[source] = source
	var queue := PackedInt32Array([source])
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == target:
			break
		var mask := links[cell]
		for bit in [1, 2, 4, 8]:
			if mask & bit:
				var next := link_step(cell, bit, width)
				if came_from[next] < 0:
					came_from[next] = cell
					queue.append(next)
	var path: Array[Vector2i] = [to]
	var at := target
	while at != source:
		at = came_from[at]
		path.append(Vector2i(at % width, at / width))
	path.reverse()
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


## {cell: steps} for every cell reachable from `from`, in the order the breadth-first search
## reached them (see distance_grid, which is faster when a flat array will do).
static func distances_from(maze: Dictionary, from: Vector2i) -> Dictionary:
	if not _inside(from, maze.cells):
		return {from: 0}  # (outside cells have no open neighbors)
	var dist := _bfs(maze, from)
	var width: int = maze.cells.x
	var distances := {}
	for i in _visited:
		var index := _order[i]
		distances[Vector2i(index % width, index / width)] = dist[index]
	return distances


## Steps from `from` to every cell along the passages, indexed y * cells.x + x (-1 = unreachable).
static func distance_grid(maze: Dictionary, from: Vector2i) -> PackedInt32Array:
	return _bfs(maze, from)


## The cells the last _bfs reached, in visit order (the first _visited entries of _order).
static var _order := PackedInt32Array()
static var _visited := 0


## Breadth-first search over the cells, neighbors in DIRS order (right, left, down, up) like
## open_neighbors, on flat arrays; leaves the visit order in _order / _visited.
static func _bfs(maze: Dictionary, from: Vector2i) -> PackedInt32Array:
	var width: int = maze.cells.x
	var height: int = maze.cells.y
	var size_x: int = maze.size.x
	var walls: PackedByteArray = maze.walls
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	if _order.size() < width * height:
		_order.resize(width * height)
	var queue := _order
	var start := from.y * width + from.x
	dist[start] = 0
	queue[0] = start
	var head := 0
	var tail := 1
	while head < tail:
		var cell := queue[head]
		head += 1
		var x := cell % width
		var y := cell / width
		var steps := dist[cell] + 1
		var tile := (y * CELL_SPAN + 1) * size_x + x * CELL_SPAN + 1  # the cell's open tile
		if x + 1 < width and walls[tile + OPEN] != 1 and dist[cell + 1] < 0:
			dist[cell + 1] = steps
			queue[tail] = cell + 1
			tail += 1
		if x > 0 and walls[tile - 1] != 1 and dist[cell - 1] < 0:
			dist[cell - 1] = steps
			queue[tail] = cell - 1
			tail += 1
		if y + 1 < height and walls[tile + OPEN * size_x] != 1 and dist[cell + width] < 0:
			dist[cell + width] = steps
			queue[tail] = cell + width
			tail += 1
		if y > 0 and walls[tile - size_x] != 1 and dist[cell - width] < 0:
			dist[cell - width] = steps
			queue[tail] = cell - width
			tail += 1
	_visited = tail
	return dist


## Sets goal / goal_steps: the first cell, in search order, of those farthest from `from`.
static func _set_goal_farthest(maze: Dictionary, from: Vector2i) -> void:
	var dist := _bfs(maze, from)
	var goal := _order[0]
	for i in _visited:
		if dist[_order[i]] > dist[goal]:
			goal = _order[i]
	maze.goal = Vector2i(goal % maze.cells.x, goal / maze.cells.x)
	maze.goal_steps = dist[goal]


## True when b is fewer than `limit` steps from a along the passages: the same answer as
## distances_from(maze, a).get(b, 0) < limit on a connected maze (every maze is: the growing tree
## reaches every cell and loops only open walls), searching only that far.
static func _within_steps(maze: Dictionary, a: Vector2i, b: Vector2i, limit: int) -> bool:
	var width: int = maze.cells.x
	var height: int = maze.cells.y
	var size_x: int = maze.size.x
	var walls: PackedByteArray = maze.walls
	var target := b.y * width + b.x
	var first := a.y * width + a.x
	if first == target:
		return 0 < limit
	var dist := {first: 0}
	var queue := PackedInt32Array([first])
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var steps: int = dist[cell] + 1
		if steps >= limit:
			break  # BFS order: everything nearer has been seen
		var x := cell % width
		var y := cell / width
		var tile := (y * CELL_SPAN + 1) * size_x + x * CELL_SPAN + 1
		for next: int in [cell + 1 if x + 1 < width and walls[tile + OPEN] != 1 else -1,
				cell - 1 if x > 0 and walls[tile - 1] != 1 else -1,
				cell + width if y + 1 < height and walls[tile + OPEN * size_x] != 1 else -1,
				cell - width if y > 0 and walls[tile - size_x] != 1 else -1]:
			if next >= 0 and not dist.has(next):
				if next == target:
					return true
				dist[next] = steps
				queue.append(next)
	return false


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
