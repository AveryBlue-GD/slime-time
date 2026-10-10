class_name MazeGenerator
extends RefCounted

## "Growing tree" maze. Each maze cell is a 2x2-tile open area with 1-tile walls between
## cells, so the tile grid is (cells * 3 + 1). The same seed gives the same maze.
## branching 0 always extends the newest corridor (long winding paths, few dead ends);
## higher values sometimes branch from older cells instead (more side passages and dead ends).

const CELL_SPAN := 3
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
	var distances := _distances_from(maze, start)
	var goal := start
	for cell: Vector2i in distances:
		if distances[cell] > distances[goal]:
			goal = cell
	maze.goal = goal
	maze.goal_steps = distances[goal]
	return maze


## Pixel position of the middle of a cell's 2x2 open area.
static func cell_center(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(cell * CELL_SPAN + Vector2i(2, 2)) * tile_size


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
		for next in _open_neighbors(maze, cell):
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
			if cell != maze.start and _open_neighbors(maze, cell).size() == 1:
				count += 1
	return count


static func _distances_from(maze: Dictionary, from: Vector2i) -> Dictionary:
	var distances := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next in _open_neighbors(maze, cell):
			if not distances.has(next):
				distances[next] = distances[cell] + 1
				queue.append(next)
	return distances


static func _open_neighbors(maze: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var base := cell * CELL_SPAN + Vector2i.ONE
	for dir in DIRS:
		var between := base + Vector2i(2 if dir.x > 0 else (-1 if dir.x < 0 else 0),
			2 if dir.y > 0 else (-1 if dir.y < 0 else 0))
		if _inside(cell + dir, maze.cells) and not is_wall(maze, between):
			result.append(cell + dir)
	return result


static func _inside(cell: Vector2i, cells: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells.x and cell.y < cells.y


static func _open_cell(walls: PackedByteArray, size: Vector2i, cell: Vector2i) -> void:
	for dy in 2:
		for dx in 2:
			walls[(cell.y * CELL_SPAN + 1 + dy) * size.x + cell.x * CELL_SPAN + 1 + dx] = 0


static func _open_between(walls: PackedByteArray, size: Vector2i, a: Vector2i, b: Vector2i) -> void:
	if a.x != b.x:
		var x := maxi(a.x, b.x) * CELL_SPAN
		for dy in 2:
			walls[(a.y * CELL_SPAN + 1 + dy) * size.x + x] = 0
	else:
		var y := maxi(a.y, b.y) * CELL_SPAN
		for dx in 2:
			walls[y * size.x + a.x * CELL_SPAN + 1 + dx] = 0
