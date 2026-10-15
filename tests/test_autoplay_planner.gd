extends SceneTree

## The --autoplay bot's route planner (scripts/autoplay/autoplay_planner.gd), on paper (no physics):
## every planned run is a real walk through open cells from the start, fits the meter with the
## safety margin, collects the coins it names, never touches the chalice early, ends at the chalice
## when it says so; the campaign on paper (with the upgrades bought in order) finds all 165 coins;
## upgrade priority; the meter matches the game's own. And the --autoplay flag is inert without it.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_autoplay_planner.gd

var failures := 0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	# --- Every level, every coin still to find, at MORE SLIME 0 / 4 / 7: one run each.
	for level in range(1, Levels.COUNT + 1):
		var maze := Levels.story_maze(level)
		var coins := Levels.story_coin_cells(level)
		for slime_level in [0, 4, 7]:
			var meter := AutoplayPlanner.level_meter_tiles(level, false, slime_level)
			var plan := AutoplayPlanner.plan_coin_run(maze, coins, meter)
			var problem := _route_problem(maze, plan)
			_check(problem == "" and plan.tiles <= AutoplayPlanner.budget(meter) and not plan.coins.is_empty(),
				"L%2d SLIME %2d: %2d/%2d coins in one run, %5.1f of %5.1f tiles, %s%s" % [level, slime_level,
				plan.coins.size(), coins.size(), plan.tiles, meter, "ends at the chalice" if plan.ends_at_goal else "open (restart)",
				"" if problem == "" else " PROBLEM: " + problem])
		var fast := AutoplayPlanner.fastest_run(maze)
		_check(fast.cells[0] == maze.start and fast.cells[-1] == maze.goal and fast.cells.size() == maze.goal_steps + 1,
			"L%2d: the clean run is the shortest route (%d steps)" % [level, maze.goal_steps])
	print("  (planning 30 runs took %d ms)" % (Time.get_ticks_msec() - started))

	# --- The meter the planner assumes is the game's own (Game._ready), with and without upgrades.
	var main: PackedScene = load("res://scenes/main.tscn")
	var progress: Node = root.get_node("Progress")
	for setup in [[3, false, 0], [9, false, 7], [10, true, 0]]:
		progress.hard_mode = setup[1]
		progress.upgrades = {slime = setup[2]}
		var game: Node2D = main.instantiate()
		game.level = setup[0]
		root.add_child(game)
		await process_frame
		var real := AutoplayPlanner.meter_tiles(game.slime_cost_per_tile)
		var paper := AutoplayPlanner.level_meter_tiles(setup[0], setup[1], setup[2])
		_check(absf(real - paper) < 0.01, "L%d %s SLIME %d: planner meter %.2f tiles = game meter %.2f"
			% [setup[0], "hard" if setup[1] else "normal", setup[2], paper, real])
		game.free()
	progress.hard_mode = false
	progress.upgrades = {}

	# --- A route never passes the chalice before its end, even when coins lie past it on the way.
	var maze3 := Levels.story_maze(3)
	var plan3 := AutoplayPlanner.plan_coin_run(maze3, Levels.story_coin_cells(3), 1.0e6)
	_check(plan3.ends_at_goal and plan3.coins.size() == Levels.COINS[2] and _route_problem(maze3, plan3) == "",
		"an unlimited meter: one run takes every coin of L3 and ends on the chalice")
	var tiny := AutoplayPlanner.plan_coin_run(maze3, Levels.story_coin_cells(3), 40.0)
	_check(tiny.tiles <= AutoplayPlanner.budget(40.0) and not tiny.coins.is_empty() and not tiny.ends_at_goal
		and _route_problem(maze3, tiny) == "",
		"a short meter: the run shrinks to the coins that fit and ends open (%d coins, %.1f tiles)" % [tiny.coins.size(), tiny.tiles])

	# --- Upgrade priority: MORE SLIME first, saving up for it; then SPEED, then BRIGHTNESS.
	_check(AutoplayPlanner.next_purchase({}, 1) == "slime", "1 coin buys MORE SLIME 1")
	_check(AutoplayPlanner.next_purchase({slime = 3}, 8) == "", "8 coins wait for MORE SLIME 4 (costs 9), no SPEED (6) meanwhile")
	_check(AutoplayPlanner.next_purchase({slime = 3}, 9) == "slime", "9 coins buy MORE SLIME 4")
	_check(AutoplayPlanner.next_purchase({slime = 7}, 8) == "speed", "MORE SLIME maxed: SPEED next")
	_check(AutoplayPlanner.next_purchase({slime = 7, speed = 4}, 12) == "brightness", "then BRIGHTNESS")
	_check(AutoplayPlanner.next_purchase({slime = 7, speed = 4, brightness = 3}, 99) == "", "all maxed: nothing")

	# --- The whole normal campaign on paper: every coin, every upgrade maxed.
	var campaign := AutoplayPlanner.simulate_campaign()
	var lines: Array[String] = []
	var missed := 0
	var total_runs := 0
	for row: Dictionary in campaign.levels:
		lines.append("L%d %d runs (%d open)" % [row.level, row.runs, row.open_runs])
		missed += row.coins_missed
		total_runs += row.runs + 1
	print("  campaign: " + ", ".join(lines))
	_check(campaign.coins == Levels.total_coins() and missed == 0,
		"the campaign on paper finds all %d coins (%d)" % [Levels.total_coins(), campaign.coins])
	var maxed := true
	for id in AutoplayPlanner.PURCHASE_ORDER:
		maxed = maxed and int(campaign.upgrades.get(id, 0)) == Upgrades.max_level(id)
	_check(maxed, "and buys every upgrade to the top (%s)" % str(campaign.upgrades))
	_check(total_runs <= 45, "normal campaign: %d runs in all (coin runs + one clean run per level)" % total_runs)

	# --- Inert without the flag: no driver, normal speed, the web build never runs it.
	_check(root.get_node_or_null("Autoplay") == null and Engine.time_scale == 1.0,
		"without --autoplay there is no Autoplay driver and time runs at 1x")
	_check(not Autoplay.requested(PackedStringArray([])) and not Autoplay.requested(PackedStringArray(["--unlock-all"])),
		"Autoplay.requested is false without the flag")
	_check(Autoplay.requested(PackedStringArray(["--autoplay", "--speed=8"])), "and true with --autoplay")

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## "" if `plan` is a walkable route: starts at the start, each step to an open neighbour, the
## chalice only as the very last cell (and only if it ends there), every named coin on the way.
func _route_problem(maze: Dictionary, plan: Dictionary) -> String:
	var cells: Array = plan.cells
	if cells.is_empty() or cells[0] != maze.start:
		return "doesn't start at the start"
	for i in range(1, cells.size()):
		if not cells[i] in MazeGenerator.open_neighbors(maze, cells[i - 1]):
			return "step %d is not an open neighbour" % i
		if cells[i] == maze.goal and i < cells.size() - 1:
			return "passes the chalice at step %d" % i
	if plan.ends_at_goal != (cells[-1] == maze.goal):
		return "ends_at_goal doesn't match the last cell"
	for coin: Vector2i in plan.coins:
		if not coin in cells:
			return "coin %s is not on the route" % coin
	var steps_tiles := (cells.size() - 1) * MazeGenerator.CELL_SPAN - (AutoplayPlanner.GRAB_TILES if plan.ends_at_goal else 0.0)
	if absf(steps_tiles - plan.tiles) > 0.01:
		return "length %.2f != the cells' %.2f" % [plan.tiles, steps_tiles]
	return ""


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
