extends SceneTree

## Randomizer extras: random (seeded) spawn cells, the ticket pickup's placement odds and
## reachability, maze size growing with MORE SLIME, and save/story compatibility.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_random_tickets.gd

const SEEDS := 300

var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false

	# --- Deterministic: the same seed gives the same maze, start, chalice and ticket
	var cfg := Levels.random_config(4242)
	var a := MazeGenerator.generate_random(cfg)
	var b := MazeGenerator.generate_random(cfg)
	_check(a.walls == b.walls and a.start == b.start and a.goal == b.goal and a.goal_steps == b.goal_steps, "same seed: same maze, start and chalice")
	var cost_a: float = cfg.tile_cost
	_check(TicketSpawn.pick(a, 4242, cost_a) == TicketSpawn.pick(b, 4242, cost_a), "same seed: same ticket cell")
	_check(Levels.random_config(4242).cells == Levels.random_config(4242).cells, "same seed: same size")

	# --- Many seeds: spawn variety, route length, ticket odds, reachability
	var starts := {}
	var corner := 0
	var wrong_route := 0
	var no_ticket := 0
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
		var maze := MazeGenerator.generate_random(c)
		starts[maze.start] = true
		if maze.start == Vector2i.ZERO:
			corner += 1
		all_connected = all_connected and MazeGenerator.is_completable(maze)
		var cost: float = c.tile_cost
		if maze.goal_steps != c.route:
			wrong_route += 1
		var cell := TicketSpawn.pick(maze, s, cost)
		if cell == TicketSpawn.NONE:
			no_ticket += 1
			continue
		var dist_start := MazeGenerator.distances_from(maze, maze.start)
		var dist_goal := MazeGenerator.distances_from(maze, maze.goal)
		var f: float = dist_start[cell] * 2 * cost / 100.0
		var trip: float = (dist_start[cell] + dist_goal[cell]) * 2 * cost / 100.0
		worst_trip = maxf(worst_trip, trip)
		min_f = minf(min_f, f)
		max_f = maxf(max_f, f)
		if trip > maxf(TicketSpawn.ROUTE_LIMIT, maze.goal_steps * 2 * cost / 100.0) + 0.0001 or cell == maze.start or cell == maze.goal:
			unreachable += 1
		bands[clampi(int((f - 0.1) / 0.1), 0, 4) if f >= 0.2 else 0] += 1
		total += 1
	_check(all_connected, "every random-start maze is fully connected")
	_check(starts.size() >= SEEDS * 0.5, "spawn varies across seeds (%d distinct starts in %d)" % [starts.size(), SEEDS])
	_check(corner < SEEDS * 0.2, "the old top-left corner is no longer the usual start (%d/%d)" % [corner, SEEDS])
	_check(wrong_route == 0, "the start-chalice route is the length the seed's usage asks for (%d off)" % wrong_route)
	_check(unreachable == 0 and worst_trip <= Levels.RANDOM_MAX_USAGE + 0.01, "the ticket is always within budget: start -> ticket -> chalice <= 92%% of the meter, or the route itself when longer (worst %.0f%%)" % (worst_trip * 100))
	_check(no_ticket < SEEDS * 0.02, "almost every maze has a ticket (%d without)" % no_ticket)
	_check(min_f >= TicketSpawn.MIN_FRACTION - 0.0001 and max_f <= TicketSpawn.MAX_FRACTION + 0.0001, "the ticket is %d%%-%d%% of the meter from the start (saw %.0f%%-%.0f%%)" % [TicketSpawn.MIN_FRACTION * 100, TicketSpawn.MAX_FRACTION * 100, min_f * 100, max_f * 100])
	print("ticket distance bands (<20, 20-30, 30-40, 40-50, 50+ pct of meter): ", bands, " of ", total)
	_check(bands[0] > 0, "near spawns (10-20%%) are rare but possible (%d of %d)" % [bands[0], total])
	_check(bands[0] < total * 0.12, "...and rare (<12%%: %.1f%%)" % (bands[0] * 100.0 / total))
	_check(bands[3] + bands[4] > bands[0] * 3 and bands[3] + bands[4] > bands[1], "far spots (40%%+) are much more common than near ones")

	# --- The weight curve itself
	_check(TicketSpawn.weight(0.1) < TicketSpawn.weight(0.2) and TicketSpawn.weight(0.2) < TicketSpawn.weight(0.4) and TicketSpawn.weight(0.4) < TicketSpawn.weight(0.6),
		"weights rise with distance")

	# --- Size scales with MORE SLIME (the route is u x the meter, and the meter grows)
	var last_area := 0
	var rising := true
	for level in range(0, Upgrades.MAX_LEVEL + 1):
		var area := 0
		for i in 40:
			var cells := Levels.random_cells(5000 + i, level)
			area += cells.x * cells.y
			rising = rising and cells.x <= Levels.RANDOM_MAX_CELLS.x and cells.y <= Levels.RANDOM_MAX_CELLS.y and cells.x >= Levels.RANDOM_MIN_CELLS.x and cells.y >= Levels.RANDOM_MIN_CELLS.y
		rising = rising and area >= last_area
		last_area = area
	_check(rising, "mazes get bigger with each MORE SLIME level, within %s .. %s" % [Levels.RANDOM_MIN_CELLS, Levels.RANDOM_MAX_CELLS])
	var small := Levels.random_cells(777, 0)
	var big := Levels.random_cells(777, 10)
	_check(big.x * big.y > small.x * small.y * 1.4, "level 10 is a much bigger maze than level 0 (%s -> %s)" % [small, big])
	_check(Levels.random_config(777, true, 10).cells == Levels.random_cells(777, 0, true), "hard mode has no upgrades, so no growth")

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
	var want: float = Levels.random_usage(4242) * 100.0
	_check(absf(used - want) < 1.5, "a perfect run uses the seed's usage of the (fixed) meter: %.1f%% (u %.1f%%)" % [used, want])
	_check(game.ticket != null and game.ticket.cell == TicketSpawn.pick(game.maze, 4242, cfg.tile_cost), "the ticket pickup sits in the seeded cell")
	# A ticket cell chosen for a higher MORE SLIME level can be out of reach on the player's smaller meter
	var cost: float = game.slime_cost_per_tile
	var fits_all := true
	var detour := Vector2i(-1, -1)
	for option in TicketSpawn.candidates(game.maze, cost):
		fits_all = fits_all and TicketSpawn.trip_fits(game.maze, option.cell, cost)
		if option.trip > MazeGenerator.distances_from(game.maze, game.maze.start)[game.maze.goal] * MazeGenerator.CELL_SPAN * cost / 100.0 + 0.02:
			detour = option.cell
	_check(fits_all, "every candidate cell fits the meter it was chosen for")
	if detour != Vector2i(-1, -1):
		_check(not TicketSpawn.trip_fits(game.maze, detour, cost * 3.0), "a side-branch ticket is dropped when the player's meter is far smaller (3x cost per tile)")
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



func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
