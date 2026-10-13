extends SceneTree

## Randomizer slime usage (docs/level-design.md section 5): each seed rolls a usage u (the share of
## the player's fixed meter a perfect run needs) from a bell over [0.10, 0.95]; the maze size,
## spawn, chalice and ticket follow it. Checks the distribution over 10k seeds, determinism,
## routes of exactly the asked length, size bounds, spawn class odds, tickets reachable or absent
## cleanly, seed-code portability, the result text, and real autopilot runs at low, middle and high u.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_random_usage.gd

const SEEDS := 10000
const MAZES := 600
const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false

	# --- The usage roll over 10k seeds
	var us: Array[int] = []
	var hist := []
	hist.resize(17)  # 0.10-0.15, 0.15-0.20 ... 0.90-0.95
	hist.fill(0)
	for i in SEEDS:
		var u := Levels.random_usage_permille(1 + i * 7919)
		us.append(u)
		hist[clampi((u - 100) / 50, 0, 16)] += 1
	us.sort()
	var low := us.filter(func(u: int) -> bool: return u <= 200).size() * 100.0 / SEEDS
	var high := us.filter(func(u: int) -> bool: return u >= 900).size() * 100.0 / SEEDS
	print("usage histogram (0.10-0.15 ... 0.90-0.95): ", hist)
	_check(us[0] >= 100 and us[-1] <= 950, "u stays within 0.10-0.95 (saw %.3f-%.3f)" % [us[0] / 1000.0, us[-1] / 1000.0])
	_check(absi(us[SEEDS / 2] - 578) <= 15, "median about 0.58 (%.3f)" % (us[SEEDS / 2] / 1000.0))
	_check(absi(us[SEEDS / 4] - 423) <= 20 and absi(us[SEEDS * 3 / 4] - 724) <= 20, "middle half about 0.42-0.72 (%.3f-%.3f)" % [us[SEEDS / 4] / 1000.0, us[SEEDS * 3 / 4] / 1000.0])
	_check(low >= 1.5 and low <= 3.5, "P(u <= 0.20) about 2.5%% (%.2f%%)" % low)
	_check(high >= 1.3 and high <= 3.5, "P(u >= 0.90) about 2.3%% (%.2f%%)" % high)
	var tiny := us.filter(func(u: int) -> bool: return u <= 120).size()
	var huge := us.filter(func(u: int) -> bool: return u >= 930).size()
	_check(tiny > 0 and tiny < SEEDS * 0.005 and huge > 0 and huge < SEEDS * 0.01, "the extremes are possible but very rare (%d of %d at u <= 0.12, %d at u >= 0.93)" % [tiny, SEEDS, huge])
	var peak: int = hist.max()
	_check(hist.find(peak) >= 7 and hist.find(peak) <= 11, "the bulk sits in the middle (peak bin %d)" % hist.find(peak))

	# --- Deterministic and integer-only (same on the web)
	_check(Levels.random_usage_permille(4242) == Levels.random_usage_permille(4242) and _golden(), "same seed: same usage and route (pinned values)")
	var source := FileAccess.get_file_as_string("res://scripts/levels.gd")
	var usage_src := source.substr(source.find("static func random_usage_permille"), 600)
	_check(not "randf" in usage_src, "the usage roll uses an integer draw only")
	_check(Levels.random_route_cells(4242, false, 3) == Levels.random_route_cells(4242, false, 3), "route cells are a pure function of seed + level")
	_check(Levels.random_usage(4242, true) == Levels.RANDOM_HARD_TARGET and Levels.random_route_cells(4242, true, 10) == Levels.random_route_cells(4242, true, 0), "hard mode: fixed 90%, no upgrade growth")

	# --- Route scales with the meter: MORE SLIME 10 asks for twice the route of level 0
	var ratio_ok := true
	for i in 200:
		var s := 77 + i * 131
		var r0 := Levels.random_route_cells(s, false, 0)
		var r10 := Levels.random_route_cells(s, false, 10)
		ratio_ok = ratio_ok and r0 >= Levels.RANDOM_MIN_ROUTE and (r0 <= Levels.RANDOM_MIN_ROUTE or absf(r10 * 1.0 / r0 - 2.0) < 0.2)
	_check(ratio_ok, "route = u x the meter: level 10's route is ~2x level 0's, never under %d cells" % Levels.RANDOM_MIN_ROUTE)

	# --- Real mazes at MORE SLIME 0, 5 and 10
	var kinds := [0, 0, 0]
	var fallbacks := 0
	var off_route := 0
	var too_big := 0
	var not_solvable := 0
	var ticket_bad := 0
	var no_ticket := 0
	var areas := [0, 0, 0]
	for i in MAZES:
		var s := 1 + i * 7919
		var level: int = [0, 5, 10][i % 3]
		var cfg := Levels.random_config(s, false, level)
		var maze := MazeGenerator.generate_random(cfg)
		areas[i % 3] += maze.cells.x * maze.cells.y
		kinds[maze.spawn_kind] += 1
		if maze.spawn_kind != maze.spawn_rolled:
			fallbacks += 1
		var reach := MazeGenerator.distances_from(maze, maze.start)
		if not MazeGenerator.is_completable(maze) or reach.get(maze.goal, -1) != maze.goal_steps:
			not_solvable += 1
		if absi(maze.goal_steps - cfg.route) > 2:
			off_route += 1
		if maze.cells.x < Levels.RANDOM_MIN_CELLS.x or maze.cells.y < Levels.RANDOM_MIN_CELLS.y or maze.cells.x > Levels.RANDOM_MAX_CELLS.x or maze.cells.y > Levels.RANDOM_MAX_CELLS.y:
			too_big += 1
		var ticket := TicketSpawn.pick(maze, s, cfg.tile_cost)
		if ticket == TicketSpawn.NONE:
			no_ticket += 1
		else:
			var unit: float = MazeGenerator.CELL_SPAN * cfg.tile_cost / 100.0
			var from_goal := MazeGenerator.distances_from(maze, maze.goal)
			var f: float = reach[ticket] * unit
			var trip: float = (reach[ticket] + from_goal[ticket]) * unit
			if f < TicketSpawn.MIN_FRACTION - 0.0001 or f > TicketSpawn.MAX_FRACTION + 0.0001 or trip > maxf(TicketSpawn.ROUTE_LIMIT, maze.goal_steps * unit) + 0.0001 or ticket == maze.start or ticket == maze.goal:
				ticket_bad += 1
	_check(not_solvable == 0, "%d mazes: every one solvable, the chalice exactly goal_steps from the start" % MAZES)
	_check(off_route == 0, "...the chalice at the intended route length +-2 (%d off)" % off_route)
	_check(too_big == 0, "...sizes within %s .. %s (avg area L0 %d, L5 %d, L10 %d)" % [Levels.RANDOM_MIN_CELLS, Levels.RANDOM_MAX_CELLS, areas[0] / (MAZES / 3), areas[1] / (MAZES / 3), areas[2] / (MAZES / 3)])
	_check(areas[0] < areas[1] and areas[1] < areas[2], "...mazes grow with MORE SLIME")
	_check(ticket_bad == 0, "...the ticket 10-60%% from the start and start->ticket->chalice within 92%% (or on the route) (%d bad)" % ticket_bad)
	_check(no_ticket <= MAZES / 50, "...almost always a ticket; none = cleanly absent (%d of %d)" % [no_ticket, MAZES])
	# 600 picks: +-5% (3.5 sd); the rule rarely needs a fallback (measured 0 in 1,200 mazes).
	var total := float(MAZES)
	_check(absf(kinds[0] / total - 0.33) <= 0.05 and absf(kinds[1] / total - 0.30) <= 0.05 and absf(kinds[2] / total - 0.37) <= 0.05,
		"spawn classes still about 33/30/37: EDGE %.1f%% NEAR %.1f%% ANY %.1f%% (%d fallbacks)" % [kinds[0] * 100 / total, kinds[1] * 100 / total, kinds[2] * 100 / total, fallbacks])
	_check(fallbacks <= MAZES / 20, "class fallbacks are rare (%d)" % fallbacks)

	# --- Ticket absent cleanly: no fitting cell -> NONE (an absurd cost leaves nothing within 60%)
	var small_maze := MazeGenerator.generate_random(Levels.random_config(4242))
	_check(TicketSpawn.pick(small_maze, 4242, 500.0) == TicketSpawn.NONE, "no fitting cell: no ticket (NONE), not a forced one")

	# --- Seed codes: the same "N-L" code gives the same maze for anyone; the meter stays the player's
	var code_seed := _seed_with(500, 650)
	var mine: Node2D = await _game(code_seed, 3, 3)
	var richer: Node2D = await _game(code_seed, 3, 8)
	var poorer: Node2D = await _game(code_seed, 3, 0)
	var same: bool = mine.maze.walls == richer.maze.walls and mine.maze.start == richer.maze.start and mine.maze.goal == richer.maze.goal \
		and mine.maze.walls == poorer.maze.walls and mine.maze.goal == poorer.maze.goal
	same = same and mine.ticket != null and richer.ticket != null and poorer.ticket != null and mine.ticket.cell == richer.ticket.cell and mine.ticket.cell == poorer.ticket.cell
	_check(same, "code %s: same maze, start, chalice and ticket at MORE SLIME 0, 3 and 8" % Levels.seed_code(code_seed, 3))
	var u := Levels.random_usage(code_seed)
	_check(absf(mine.perfect_usage - u) < 0.02, "the code's own level: a perfect run uses u (%.3f vs %.3f)" % [mine.perfect_usage, u])
	_check(absf(richer.perfect_usage - mine.perfect_usage * 1.3 / 1.8) < 0.01, "more slime than the code: a smaller share of a bigger meter (%.3f)" % richer.perfect_usage)
	_check(poorer.perfect_usage <= Levels.RANDOM_MAX_USAGE + 0.0001 and poorer.perfect_usage > mine.perfect_usage, "less slime than the code: more of the meter, capped at 95%% so it stays winnable (%.3f)" % poorer.perfect_usage)
	for g: Node2D in [mine, richer, poorer]:
		g.free()

	# --- The result line
	var g2: Node2D = await _game(code_seed, 0, 0)
	g2.slime_remaining = 77.0
	_check(g2.usage_text() == "USED 23% SLIME EFFICIENT!", "result: %s" % g2.usage_text())
	g2.slime_remaining = 40.0
	_check(g2.usage_text() == "USED 60% SLIME", "result: %s" % g2.usage_text())
	g2.hud.show_rewards({tickets = 1, ticket_found = false, no_ticket = true})
	_check("NO TICKET IN THIS MAZE +1" in g2.hud.rewards_texts, "the result says the maze had no ticket (%s)" % [g2.hud.rewards_texts])
	g2.hud.set_ticket(false, true)
	_check(g2.hud._ticket_label.text == "NONE HERE", "the HUD ticket pod says NONE HERE")
	g2.free()

	# --- Autopilot perfect runs: slime used within a few % of u (low, middle, high u; MORE SLIME 0 and 10)
	var runs := [[_seed_with(100, 125), 0], [_seed_with(240, 260), 0], [_seed_with(540, 560), 0], [_seed_with(930, 950), 0], [_seed_with(100, 130), 10], [_seed_with(925, 950), 10]]
	for run: Array in runs:
		var s: int = run[0]
		var level: int = run[1]
		var game: Node2D = await _game(s, level, level)
		game.add_child(AUTOPILOT.new())
		for i in 60 * 150:
			if game.finished:
				break
			await physics_frame
		var used: float = 100.0 - game.slime_remaining
		var want: float = Levels.random_usage(s) * 100.0
		_check(game.finished and game.slime_remaining > 0.0 and absf(used - want) <= 4.0,
			"autopilot seed %d (u %.2f, MORE SLIME %d, %dx%d, route %d): used %.1f%% (perfect %.1f%%)" % [s, want / 100.0, level, game.maze.cells.x, game.maze.cells.y, game.maze.goal_steps, used, game.perfect_usage * 100.0])
		game.free()

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


## The first seed (from 1, stepping 7919) whose usage lies in [lo, hi] permille.
func _seed_with(lo: int, hi: int) -> int:
	var s := 1
	while true:
		var u := Levels.random_usage_permille(s)
		if u >= lo and u <= hi:
			return s
		s += 7919
	return s


## A randomizer game for `maze_seed` built for the code's MORE SLIME level `code_level`, played by
## a player who owns `own_level`.
func _game(maze_seed: int, code_level: int, own_level: int) -> Node2D:
	progress.mode = progress.MODE_RANDOM
	progress.hard_mode = false
	progress.upgrades = {"slime": own_level}
	progress.random_seed = maze_seed
	progress.random_level = code_level
	var game: Node2D = MAIN.instantiate()
	game.random_seed = maze_seed
	root.add_child(game)
	await physics_frame
	return game


## Pinned usage and route values, so an engine or code change that moves them is noticed.
func _golden() -> bool:
	var got := []
	for s in [1, 2, 3, 4242, 123456]:
		got.append([Levels.random_usage_permille(s), Levels.random_route_cells(s, false, 0), Levels.random_route_cells(s, false, 10)])
	var want := [[371, 26, 51], [749, 51, 102], [406, 28, 56], [202, 14, 28], [498, 34, 68]]
	if str(got) != str(want):
		print("    golden usage now: ", got)
		return false
	return true


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
