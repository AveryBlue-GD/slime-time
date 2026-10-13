class_name TicketSpawn
extends RefCounted

## Where a randomizer maze hides its ticket voucher. Deterministic from the maze seed: the same seed
## always puts it in the same cell. The place is weighted by how much of the player's slime meter it
## costs to get there from the start along the shortest route (tiles x the slime cost per tile, which
## already includes MORE SLIME upgrades):
## - nearer than MIN_FRACTION (10%) or farther than MAX_FRACTION (60%) never gets one;
## - weight(f) = WEIGHT_FLOOR + (f / MAX_FRACTION)^2: 10% weighs 0.07, 30% 0.29, 60% 1.04, so the
##   close spots are rare (and have few cells) and the far ones the most common;
## - the whole trip start -> ticket -> chalice must fit in ROUTE_LIMIT (92%) of the meter, so
##   collecting it never makes winning impossible (picks lie on the route or on short side branches).
const MIN_FRACTION := 0.10
const MAX_FRACTION := 0.60
const ROUTE_LIMIT := 0.92
const WEIGHT_FLOOR := 0.04


static func weight(fraction: float) -> float:
	return WEIGHT_FLOOR + pow(fraction / MAX_FRACTION, 2.0)


## Cells that may hold the ticket, with their fraction of the meter from the start: {cell, f, trip}.
## `cost_per_tile` is the percent of the meter one tile costs (game.slime_cost_per_tile).
static func candidates(maze: Dictionary, cost_per_tile: float) -> Array[Dictionary]:
	var from_start := MazeGenerator.distances_from(maze, maze.start)
	var from_goal := MazeGenerator.distances_from(maze, maze.goal)
	var unit := MazeGenerator.CELL_SPAN * cost_per_tile / 100.0
	var out: Array[Dictionary] = []
	for cell: Vector2i in from_start:
		if cell == maze.start or cell == maze.goal:
			continue
		var f: float = from_start[cell] * unit
		var trip: float = (from_start[cell] + from_goal[cell]) * unit
		if f >= MIN_FRACTION and f <= MAX_FRACTION and trip <= ROUTE_LIMIT:
			out.append({cell = cell, f = f, trip = trip})
	return out


## The ticket's cell for this maze and seed (always one: with no fitting cell, a spot on the route).
static func pick(maze: Dictionary, maze_seed: int, cost_per_tile: float) -> Vector2i:
	var options := candidates(maze, cost_per_tile)
	if options.is_empty():
		var route := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
		return route[clampi(route.size() / 3, 1, maxi(route.size() - 2, 1))]
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
