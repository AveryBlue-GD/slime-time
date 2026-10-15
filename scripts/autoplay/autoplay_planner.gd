class_name AutoplayPlanner
extends RefCounted

## Route planning for the `--autoplay` bot (scripts/autoplay/autoplay.gd): an omniscient player who
## knows the maze graph. Pure functions on a story maze (MazeGenerator's Dictionary). Lengths are in
## tiles, like the slime meter: one cell step is MazeGenerator.CELL_SPAN tiles, and the last leg onto
## the chalice is GRAB_TILES shorter (the slime grabs it when their shapes touch).
##
## A coin run is a route start -> coins -> (chalice or anywhere) that fits the real meter with a
## safety margin: a nearest-neighbour tour over the coins left, improved with 2-opt and or-opt,
## then trimmed (the coin whose detour costs most goes first) until it fits, then topped up with
## any coin that still fits (cheapest insertion). It ends at the chalice when that collects as many
## coins as an open route would (an open run ends with a restart instead of a dry-up). Legs between
## stops never pass the chalice's cell (touching it would end the run early).

const GRAB_TILES := Levels.GRAB_REACH / Levels.TILE
## The bot plans with this share of the meter, minus SAFETY_TILES: its glide cuts corners (shorter
## than cell-center routes) but overshoots a little turning round in dead ends.
const SAFETY := 0.97
const SAFETY_TILES := 0.75
## Upgrade buying order: MORE SLIME to the top first (longer runs = more coins per run), then SPEED,
## then BRIGHTNESS. A smart player saves up for the next level of the first one not maxed.
const PURCHASE_ORDER: Array[String] = ["slime", "speed", "brightness"]
const INF_TILES := 1.0e9


## Tiles a full meter glides when one tile costs `slime_cost_per_tile` percent (Game's own value).
static func meter_tiles(slime_cost_per_tile: float) -> float:
	return 100.0 / slime_cost_per_tile


## The tiles the bot lets itself plan with a meter of `meter` tiles.
static func budget(meter: float) -> float:
	return meter * SAFETY - SAFETY_TILES


## A story level's meter in tiles, computed the way Game._ready does (route calibrated on the real
## start-to-chalice path, divided by MORE SLIME on normal mode), without building a game.
static func level_meter_tiles(level: int, hard: bool, slime_level: int) -> float:
	var maze := Levels.story_maze(level, hard)
	var path_tiles: float = maze.goal_steps * MazeGenerator.CELL_SPAN - GRAB_TILES
	var config := Levels.get_config(level, hard)
	var cost: float = config.target * 100.0 / path_tiles
	if config.has("meter_tiles"):  # hard levels: the meter is set directly, as in Game._ready
		cost = 100.0 / config.meter_tiles
	if not hard:
		cost /= Upgrades.slime_factor(slime_level)
	return meter_tiles(cost)


## The next upgrade to buy with `coins` in hand at the current `levels` ({id: level}), or "".
static func next_purchase(levels: Dictionary, coins: int) -> String:
	for id in PURCHASE_ORDER:
		var level: int = levels.get(id, 0)
		if level >= Upgrades.max_level(id):
			continue
		return id if coins >= Upgrades.cost(id, level) else ""  # save up for this one
	return ""


## The fastest clear: the shortest route from the start to the chalice (cells, inclusive).
static func fastest_run(maze: Dictionary) -> Dictionary:
	var cells := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	var none: Array[Vector2i] = []
	return {cells = cells, coins = none, ends_at_goal = true,
		tiles = maxi(cells.size() - 1, 0) * MazeGenerator.CELL_SPAN - GRAB_TILES}


## The run to play now to collect `coins_left` with a meter of `meter` tiles: {cells (waypoints,
## start first), coins (in pickup order), ends_at_goal, tiles}. Prefers a route that also reaches
## the chalice unless an open route collects more coins.
static func plan_coin_run(maze: Dictionary, coins_left: Array[Vector2i], meter: float) -> Dictionary:
	var graph := _Graph.new(maze, coins_left)
	var limit := budget(meter)
	var win := graph.best_route(true, limit)
	if win.order.size() == graph.coins.size():
		return graph.to_plan(win, true)
	var open := graph.best_route(false, limit)
	if open.order.size() > win.order.size():
		return graph.to_plan(open, false)
	return graph.to_plan(win, true)


## Plays the normal-mode campaign on paper (no physics): per level, coin runs with the meter the
## upgrades give, buying upgrades in PURCHASE_ORDER after every run, then one fastest clear. Returns
## {levels: [{level, runs, open_runs, tiles}], coins, upgrades, tiles}. Used by the tests and to
## estimate the autoplay's length.
static func simulate_campaign() -> Dictionary:
	var upgrades := {}
	var spent := 0
	var found := 0
	var total_tiles := 0.0
	var levels: Array[Dictionary] = []
	for level in range(1, Levels.COUNT + 1):
		var maze := Levels.story_maze(level)
		var left: Array[Vector2i] = Levels.story_coin_cells(level)
		var runs := 0
		var open_runs := 0
		var tiles := 0.0
		while not left.is_empty() and runs < 50:
			var meter := level_meter_tiles(level, false, upgrades.get("slime", 0))
			var plan := plan_coin_run(maze, left, meter)
			if plan.coins.is_empty():
				break
			runs += 1
			open_runs += 0 if plan.ends_at_goal else 1
			tiles += plan.tiles
			for cell: Vector2i in plan.coins:
				left.erase(cell)
				found += 1
			var id := next_purchase(upgrades, found - spent)
			while id != "":
				spent += Upgrades.cost(id, upgrades.get(id, 0))
				upgrades[id] = upgrades.get(id, 0) + 1
				id = next_purchase(upgrades, found - spent)
		tiles += fastest_run(maze).tiles
		total_tiles += tiles
		levels.append({level = level, runs = runs, open_runs = open_runs, tiles = tiles, coins_missed = left.size()})
	return {levels = levels, coins = found, upgrades = upgrades, tiles = total_tiles}


## The planning graph of one maze: the start, the coins left and the chalice, with breadth-first
## trees from each (the chalice's cell blocked, except for legs that end on it).
class _Graph:
	extends RefCounted

	var maze: Dictionary
	var coins: Array[Vector2i] = []
	## Distance matrix over points 0 = start, 1..n = coins, n+1 = the end (chalice, or 0 for open).
	var steps := []
	var to_goal := []  # tiles from point i onto the chalice
	var trees := []  # per point: {dist, parent} with the chalice blocked
	var goal_tree: Dictionary
	const END := -1

	func _init(maze_data: Dictionary, coins_left: Array[Vector2i]) -> void:
		maze = maze_data
		goal_tree = AutoplayPlanner.bfs(maze, maze.goal, Vector2i(-1, -1))
		var start_tree := AutoplayPlanner.bfs(maze, maze.start, maze.goal)
		trees.append(start_tree)
		for cell in coins_left:
			if start_tree.dist.has(cell) and cell != maze.goal:  # (a coin past the chalice can't be had)
				coins.append(cell)
				trees.append(AutoplayPlanner.bfs(maze, cell, maze.goal))
		var points: Array[Vector2i] = [maze.start]
		points.append_array(coins)
		for i in points.size():
			var row: Array[float] = []
			for j in points.size():
				row.append(float(trees[i].dist[points[j]]) * MazeGenerator.CELL_SPAN if trees[i].dist.has(points[j]) else AutoplayPlanner.INF_TILES)
			steps.append(row)
			to_goal.append(float(goal_tree.dist[points[i]]) * MazeGenerator.CELL_SPAN - AutoplayPlanner.GRAB_TILES)

	func leg(a: int, b: int, to_end: bool, end_goal: bool) -> float:
		if to_end:
			return to_goal[a] if end_goal else 0.0
		return steps[a][b]

	## Length of start -> order... -> end.
	func length(order: Array[int], end_goal: bool) -> float:
		var total := 0.0
		var at := 0
		for i in order:
			total += steps[at][i]
			at = i
		return total + leg(at, 0, true, end_goal)

	## {order (coin point indices 1..n), tiles}: as many coins as fit in `limit` tiles.
	func best_route(end_goal: bool, limit: float) -> Dictionary:
		var order: Array[int] = []
		var left: Array[int] = []
		for i in range(1, coins.size() + 1):
			left.append(i)
		var at := 0
		while not left.is_empty():  # nearest neighbour
			var best := left[0]
			for i in left:
				if steps[at][i] < steps[at][best]:
					best = i
			order.append(best)
			left.erase(best)
			at = best
		_improve(order, end_goal)
		var dropped: Array[int] = []
		while not order.is_empty() and length(order, end_goal) > limit:
			var worst := 0
			var worst_save := -AutoplayPlanner.INF_TILES
			for k in order.size():
				var save := _saving(order, k, end_goal)
				if save > worst_save:
					worst_save = save
					worst = k
			dropped.append(order[worst])
			order.remove_at(worst)
			_improve(order, end_goal)
		# Top up: the cheapest coin to slot in that still fits, again and again.
		var current := length(order, end_goal)
		while not dropped.is_empty():
			var pick := -1
			var pick_at := 0
			var pick_add := AutoplayPlanner.INF_TILES
			var seq: Array[int] = [0]
			seq.append_array(order)
			seq.append(END)
			for i in dropped:
				for k in range(1, seq.size()):  # between seq[k - 1] and seq[k]
					var add := d(seq[k - 1], i, end_goal) + d(i, seq[k], end_goal) - d(seq[k - 1], seq[k], end_goal)
					if current + add <= limit and add < pick_add:
						pick_add = add
						pick = i
						pick_at = k - 1
			if pick < 0:
				break
			order.insert(pick_at, pick)
			dropped.erase(pick)
			_improve(order, end_goal)
			current = length(order, end_goal)
		if order.is_empty() and end_goal and length(order, true) > limit:
			current = length(order, true)  # not even the bare route fits (never on a story level)
		return {order = order, tiles = current}

	## Tiles saved by leaving out order[k].
	func _saving(order: Array[int], k: int, end_goal: bool) -> float:
		var prev := 0 if k == 0 else order[k - 1]
		var cut: float = steps[prev][order[k]]
		if k == order.size() - 1:
			return cut + leg(order[k], 0, true, end_goal) - leg(prev, 0, true, end_goal)
		return cut + steps[order[k]][order[k + 1]] - steps[prev][order[k + 1]]

	## Tiles between points a and b of a route; b = END is the route's end (the chalice, or nothing).
	func d(a: int, b: int, end_goal: bool) -> float:
		return leg(a, 0, true, end_goal) if b == END else steps[a][b]

	## 2-opt (reverse a stretch) and or-opt (move one stop) until neither shortens the route.
	## Coin-to-coin distances are symmetric, so each move is priced by the edges it changes.
	func _improve(order: Array[int], end_goal: bool) -> void:
		var better := true
		var rounds := 0
		while better and rounds < 100:
			better = false
			rounds += 1
			var seq: Array[int] = [0]
			seq.append_array(order)
			seq.append(END)
			var n := order.size()
			for i in range(1, n + 1):
				for j in range(i + 1, n + 1):
					var delta := d(seq[i - 1], seq[j], end_goal) + d(seq[i], seq[j + 1], end_goal) \
						- d(seq[i - 1], seq[i], end_goal) - d(seq[j], seq[j + 1], end_goal)
					if delta < -0.001:
						var stretch := seq.slice(i, j + 1)
						stretch.reverse()
						for k in stretch.size():
							seq[i + k] = stretch[k]
						better = true
			for i in range(1, n + 1):
				var x := seq[i]
				var gain := d(seq[i - 1], x, end_goal) + d(x, seq[i + 1], end_goal) - d(seq[i - 1], seq[i + 1], end_goal)
				var rest := seq.duplicate()
				rest.remove_at(i)
				for k in range(1, rest.size()):  # between rest[k - 1] and rest[k]
					if k == i:
						continue  # its own place
					var add := d(rest[k - 1], x, end_goal) + d(x, rest[k], end_goal) - d(rest[k - 1], rest[k], end_goal)
					if add - gain < -0.001:
						rest.insert(k, x)
						seq = rest
						better = true
						break
			order.assign(seq.slice(1, seq.size() - 1))

	## The waypoint cells of a route: start, every cell along each leg, ending on the last coin or
	## on the chalice.
	func to_plan(route: Dictionary, end_goal: bool) -> Dictionary:
		var cells: Array[Vector2i] = [maze.start]
		var at := 0
		var picked: Array[Vector2i] = []
		for i: int in route.order:
			cells.append_array(_leg_cells(trees[at], coins[i - 1]))
			picked.append(coins[i - 1])
			at = i
		if end_goal:
			var here: Vector2i = cells[-1]
			while here != maze.goal:  # follow the chalice's tree from here onto it
				here = goal_tree.parent[here]
				cells.append(here)
		return {cells = cells, coins = picked, ends_at_goal = end_goal, tiles = length(route.order, end_goal)}

	## The cells after the tree's root up to `to` (inclusive).
	func _leg_cells(tree: Dictionary, to: Vector2i) -> Array[Vector2i]:
		var leg_cells: Array[Vector2i] = []
		var here := to
		while tree.parent.has(here):
			leg_cells.push_front(here)
			here = tree.parent[here]
		return leg_cells


## Breadth-first tree over the maze's open cells from `from`, never entering `blocked`:
## {dist: {cell: steps}, parent: {cell: the cell before it}} (the root has no parent).
static func bfs(maze: Dictionary, from: Vector2i, blocked: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var parent := {}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for next in MazeGenerator.open_neighbors(maze, cell):
			if next == blocked or dist.has(next):
				continue
			dist[next] = dist[cell] + 1
			parent[next] = cell
			queue.append(next)
	return {dist = dist, parent = parent}
