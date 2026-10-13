class_name TicketSpawn
extends RefCounted

## Where a randomizer maze hides its ticket voucher. Deterministic from the maze seed: the same seed
## always puts it in the same cell. The place is weighted by how much of the player's slime meter it
## costs to get there from the start along the shortest route (tiles x the slime cost per tile, which
## already includes MORE SLIME upgrades):
## - nearer than MIN_FRACTION (10%) or farther than MAX_FRACTION (60%) never gets one;
## - weight(f) = WEIGHT_FLOOR + (f / MAX_FRACTION)^3: 10% weighs 0.045, 30% 0.17, 60% 1.04, so the
##   close spots are rare (and have few cells) and the far ones the most common (cubed since the
##   usage rework: small low-usage mazes have few far cells, and squared let near picks reach ~13%);
## - the whole trip start -> ticket -> chalice must fit in ROUTE_LIMIT (92%) of the meter, so
##   collecting it never makes winning impossible (picks lie on the route or on short side branches).
##   On a short route (a low-usage maze) that leaves room for cells well off the route; on a route
##   longer than 92% (usage 0.93-0.95) only cells ON the route qualify (no detour at all).
## - with no fitting cell the maze has no ticket (pick returns NONE); the HUD and result say so.
const MIN_FRACTION := 0.10
const MAX_FRACTION := 0.60
const ROUTE_LIMIT := 0.92
const WEIGHT_FLOOR := 0.04
const NONE := Vector2i(-1, -1)


static func weight(fraction: float) -> float:
	var x := fraction / MAX_FRACTION
	return WEIGHT_FLOOR + x * x * x


## Cells that may hold the ticket, with their fraction of the meter from the start: {cell, f, trip}.
## `cost_per_tile` is the percent of the meter one tile costs (game.slime_cost_per_tile).
static func candidates(maze: Dictionary, cost_per_tile: float) -> Array[Dictionary]:
	var from_start := MazeGenerator.distance_grid(maze, maze.start)
	var from_goal := MazeGenerator.distance_grid(maze, maze.goal)
	var width: int = maze.cells.x
	var unit := MazeGenerator.CELL_SPAN * cost_per_tile / 100.0
	var limit := maxf(ROUTE_LIMIT, from_start[maze.goal.y * width + maze.goal.x] * unit + 0.000001)  # a 93-95% route: on-route cells only
	var out: Array[Dictionary] = []
	for y in maze.cells.y:  # row-major, so the pick never depends on dictionary order
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			var i: int = y * width + x
			if cell == maze.start or cell == maze.goal or from_start[i] < 0:
				continue
			var f: float = from_start[i] * unit
			var trip: float = (from_start[i] + from_goal[i]) * unit
			if f >= MIN_FRACTION and f <= MAX_FRACTION and trip <= limit:
				out.append({cell = cell, f = f, trip = trip})
	return out


## True when start -> `cell` -> chalice fits the meter at `cost_per_tile` (the same limit as candidates()).
static func trip_fits(maze: Dictionary, cell: Vector2i, cost_per_tile: float) -> bool:
	if not MazeGenerator._inside(cell, maze.cells):
		return false
	var from_start := MazeGenerator.distance_grid(maze, maze.start)
	var from_goal := MazeGenerator.distance_grid(maze, maze.goal)
	var width: int = maze.cells.x
	if from_start[cell.y * width + cell.x] < 0:
		return false
	var unit := MazeGenerator.CELL_SPAN * cost_per_tile / 100.0
	var limit := maxf(ROUTE_LIMIT, from_start[maze.goal.y * width + maze.goal.x] * unit + 0.000001)
	return (from_start[cell.y * width + cell.x] + from_goal[cell.y * width + cell.x]) * unit <= limit


## The ticket's cell for this maze and seed, or NONE when no cell fits the rules above.
static func pick(maze: Dictionary, maze_seed: int, cost_per_tile: float) -> Vector2i:
	var options := candidates(maze, cost_per_tile)
	if options.is_empty():
		return NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed ^ 0x7ad3c1
	var total := 0.0
	for option in options:
		total += weight(option.f)
	var roll := rng.randf() * total
	for option in options:
		roll -= weight(option.f)
		if roll <= 0.0:
			return option.cell
	return options[-1].cell


## The meter fraction (0-1) from the start to `cell` along the shortest route.
static func fraction_to(maze: Dictionary, cell: Vector2i, cost_per_tile: float) -> float:
	return MazeGenerator.distances_from(maze, maze.start)[cell] * MazeGenerator.CELL_SPAN * cost_per_tile / 100.0
