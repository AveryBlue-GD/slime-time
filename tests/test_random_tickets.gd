extends SceneTree

## Randomizer extras: random (seeded) spawn cells, the ticket pickup's placement odds and
## reachability, maze size growing with MORE SLIME, and save/story compatibility.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_random_tickets.gd

const SEEDS := 300
const TARGET := Levels.RANDOM_TARGET

var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false

	# --- Deterministic: the same seed gives the same maze, start, chalice and ticket
	var cfg := Levels.random_config(4242)
	var a := MazeGenerator.generate_random(cfg.cells, 4242)
	var b := MazeGenerator.generate_random(cfg.cells, 4242)
	_check(a.walls == b.walls and a.start == b.start and a.goal == b.goal and a.goal_steps == b.goal_steps, "same seed: same maze, start and chalice")
	var cost_a := _cost(a)
	_check(TicketSpawn.pick(a, 4242, cost_a) == TicketSpawn.pick(b, 4242, cost_a), "same seed: same ticket cell")
	_check(Levels.random_config(4242).cells == Levels.random_config(4242).cells, "same seed: same size")

	# --- Many seeds: spawn variety, route length, ticket odds, reachability
	var starts := {}
	var corner := 0
	var min_route := 1.0
	var bands := [0, 0, 0, 0, 0]  # <20%, 20-30, 30-40, 40-50, 50-60+
	var total := 0
	var unreachable := 0
	var worst_trip := 0.0
	var min_f := 1.0
	var max_f := 0.0
	var all_connected := true
	for i in SEEDS:
		var s := 1000 + i * 7919
		var c := Levels.random_config(s)
		var maze := MazeGenerator.generate_random(c.cells, s)
		starts[maze.start] = true
		if maze.start == Vector2i.ZERO:
			corner += 1
		all_connected = all_connected and MazeGenerator.is_completable(maze)
		var cost := _cost(maze)
		min_route = minf(min_route, maze.goal_steps * 1.0 / maze.diameter)
		var cell := TicketSpawn.pick(maze, s, cost)
		var dist_start := MazeGenerator.distances_from(maze, maze.start)
		var dist_goal := MazeGenerator.distances_from(maze, maze.goal)
		var f: float = dist_start[cell] * 2 * cost / 100.0
		var trip: float = (dist_start[cell] + dist_goal[cell]) * 2 * cost / 100.0
		worst_trip = maxf(worst_trip, trip)
		min_f = minf(min_f, f)
		max_f = maxf(max_f, f)
		if trip > TicketSpawn.ROUTE_LIMIT + 0.0001 or cell == maze.start or cell == maze.goal:
			unreachable += 1
		bands[clampi(int((f - 0.1) / 0.1), 0, 4) if f >= 0.2 else 0] += 1
		total += 1
	_check(all_connected, "every random-start maze is fully connected")
	_check(starts.size() >= SEEDS * 0.5, "spawn varies across seeds (%d distinct starts in %d)" % [starts.size(), SEEDS])
	_check(corner < SEEDS * 0.2, "the old top-left corner is no longer the usual start (%d/%d)" % [corner, SEEDS])
	_check(min_route >= SpawnPicker.MIN_ROUTE_PCT / 100.0 - 0.001, "the start-chalice route is at least %d%% of the longest route (min %.2f)" % [SpawnPicker.MIN_ROUTE_PCT, min_route])
	_check(unreachable == 0 and worst_trip <= TicketSpawn.ROUTE_LIMIT + 0.0001, "the ticket is always within budget: start -> ticket -> chalice <= %d%% of the meter (worst %.0f%%)" % [TicketSpawn.ROUTE_LIMIT * 100, worst_trip * 100])
	_check(min_f >= TicketSpawn.MIN_FRACTION - 0.0001 and max_f <= TicketSpawn.MAX_FRACTION + 0.0001, "the ticket is %d%%-%d%% of the meter from the start (saw %.0f%%-%.0f%%)" % [TicketSpawn.MIN_FRACTION * 100, TicketSpawn.MAX_FRACTION * 100, min_f * 100, max_f * 100])
	print("ticket distance bands (<20, 20-30, 30-40, 40-50, 50+ pct of meter): ", bands, " of ", total)
	_check(bands[0] > 0, "near spawns (10-20%%) are rare but possible (%d of %d)" % [bands[0], total])
	_check(bands[0] < total * 0.12, "...and rare (<12%%: %.1f%%)" % (bands[0] * 100.0 / total))
	_check(bands[3] + bands[4] > bands[0] * 3 and bands[3] + bands[4] > bands[1], "far spots (40%%+) are much more common than near ones")

	# --- The weight curve itself
	_check(TicketSpawn.weight(0.1) < TicketSpawn.weight(0.2) and TicketSpawn.weight(0.2) < TicketSpawn.weight(0.4) and TicketSpawn.weight(0.4) < TicketSpawn.weight(0.6),
		"weights rise with distance")

	# --- Size scales with MORE SLIME
	var last_area := 0
	var rising := true
	for level in range(0, Upgrades.MAX_LEVEL + 1):
		var area := 0
		for i in 40:
			var cells := Levels.random_cells(5000 + i, level)
			area += cells.x * cells.y
			rising = rising and cells.x <= Levels.RANDOM_MAX_CELLS.x and cells.y <= Levels.RANDOM_MAX_CELLS.y and cells.x >= 18 and cells.y >= 10
		rising = rising and area >= last_area
		last_area = area
	_check(rising, "mazes get bigger with each MORE SLIME level, within 18x10 .. 30x16")
	var small := Levels.random_cells(777, 0)
	var big := Levels.random_cells(777, 10)
	_check(small == Levels.random_config(777).cells and big.x * big.y > small.x * small.y * 1.5, "level 0 keeps the old size; level 10 is ~2x the area (%s -> %s)" % [small, big])
	_check(Levels.random_config(777, true, 10).cells == small, "hard mode has no upgrades, so no growth")

	# --- Story levels: a fixed spawn per level (the level's class, drawn from its own seed); par from the real route
	for level in range(1, Levels.COUNT + 1):
		var c := Levels.get_config(level)
		var m := Levels.story_maze(level)
		var again := Levels.story_maze(level)
		_check(m.start == again.start and m.goal == again.goal and m.spawn_kind == c.spawn, "story level %d: always the same %s start %s" % [level, SpawnPicker.KIND_NAMES[c.spawn], m.start])
	_check(is_equal_approx(Levels.level_par(1), Levels.par_for_path(Levels.story_maze(1).goal_steps * 2 - 13.0 / 16.0)), "story par uses the real start-to-chalice route")

	# --- Real game: the slime starts on the maze's start, the budget and par use the real start
	progress.mode = progress.MODE_RANDOM
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	game.random_seed = 4242
	root.add_child(game)
	await physics_frame
	_check(game.slime.position == MazeGenerator.cell_center(game.maze.start, 16) and game.maze.start == a.start, "the slime spawns on the seeded start cell %s" % game.maze.start)
	var real_tiles: float = game.maze.goal_steps * 2 - 13.0 / 16.0
	_check(is_equal_approx(game.par_time, Levels.par_for_path(real_tiles, game.slime.max_speed)), "par is measured along the real start-to-chalice route")
	var used: float = real_tiles * game.slime_cost_per_tile
	_check(absf(used - TARGET * 100.0) < 0.01, "the meter is calibrated on the real route: a perfect run uses %d%% (%.1f%%)" % [TARGET * 100, used])
	_check(game.ticket != null and game.ticket.cell == TicketSpawn.pick(game.maze, 4242, game.slime_cost_per_tile), "the ticket pickup sits in the seeded cell")
	game.queue_free()
	await process_frame

	# --- Save compatibility: an old save (no new keys) loads; the spins counter sets the wheel price
	var old := ConfigFile.new()
	old.set_value("meta", "version", 3)
	old.set_value("wallet", "globs", 40)
	old.set_value("hats", "spins", 4)
	var loaded: Node = preload("res://scripts/progress.gd").new()
	loaded._read(old)
	_check(loaded.tickets == 40 and loaded.spins == 4 and loaded.spin_cost() == 18, "an old save loads; 4 spins taken -> the next costs 18")
	var empty := ConfigFile.new()
	var fresh: Node = preload("res://scripts/progress.gd").new()
	fresh._read(empty)
	_check(fresh.spins == 0 and fresh.spin_cost() == 0, "a save with no spins: the first spin is free")
	loaded.free()
	fresh.free()

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


## Slime cost per tile as game.gd computes it (no upgrades; grab reach 13 px): on the real route.
func _cost(maze: Dictionary) -> float:
	var ref: float = maze.goal_steps * MazeGenerator.CELL_SPAN - Levels.GRAB_REACH / Levels.TILE
	return TARGET * 100.0 / ref


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
