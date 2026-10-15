extends "res://tests/suite_base.gd"

## Randomizer slime usage (docs/level-design.md section 5): each seed rolls a usage u (the share of
## the player's fixed meter a perfect run needs) from a bell over [0.10, 0.95]; only the start-to-
## ticket route follows it: the maze itself is full size whatever u is (sized for the longest route
## any seed asks for at the MORE SLIME level). Checks the distribution over 10k seeds, determinism,
## routes of exactly the asked length, size floor / independence from u / growth with MORE SLIME,
## tickets near the spawn (rare), spawn class odds, seed-code portability, the result text, and
## real autopilot runs (gliding to the ticket) at low, middle and high u.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_random_usage.gd

const SEEDS := 10000
const MAZES := 600
const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")

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
		var r10 := Levels.random_route_cells(s, false, 7)
		ratio_ok = ratio_ok and r0 >= Levels.RANDOM_MIN_ROUTE and (r0 <= Levels.RANDOM_MIN_ROUTE or absf(r10 * 1.0 / r0 - 2.0) < 0.2)
	_check(ratio_ok, "route = u x the meter: MORE SLIME 7's route (x2.0) is ~2x level 0's, never under %d cells" % Levels.RANDOM_MIN_ROUTE)

	# --- Size: never under the floor for the level, the same whatever u, growing with MORE SLIME
	# (random_cells is the start size; generate_random only ever grows it)
	var under_floor := 0
	var u_bound := 0
	var level_area := []
	for level in Upgrades.max_level("slime") + 1:
		var floor_cells := Levels.random_floor_cells(level)
		var room := Levels.random_max_route_cells(level)
		var area := 0
		for i in SEEDS:
			var s := 1 + i * 7919
			var cells := Levels.random_cells(s, level)
			area += cells.x * cells.y
			if cells.x < floor_cells.x or cells.y < floor_cells.y or cells.x > Levels.RANDOM_MAX_CELLS.x or cells.y > Levels.RANDOM_MAX_CELLS.y:
				under_floor += 1
			if Levels.random_config(s, false, level).room != room or Levels.random_route_cells(s, false, level) > room:
				u_bound += 1
		level_area.append(area / SEEDS)
	_check(under_floor == 0, "%d seeds x MORE SLIME 0-7: no maze under its level's floor (%s at 0 .. %s at 7) or over %s" % [SEEDS, Levels.random_floor_cells(0), Levels.random_floor_cells(7), Levels.RANDOM_MAX_CELLS])
	_check(u_bound == 0, "...every maze is sized for the 95% route of its level, so any u fits")
	var monotonic := true
	for level in range(1, level_area.size()):
		monotonic = monotonic and level_area[level] >= level_area[level - 1]
	_check(monotonic and level_area[-1] > level_area[0], "average area grows with MORE SLIME: %s" % [level_area])
	# Route targets across 10k seeds: never under the minimum, never over the 95% route, and short
	# (ticket near the spawn: route <= 20% of the meter) only at the rare rate of the u tail.
	var short_routes := 0
	var too_short := 0
	for i in SEEDS:
		var s := 1 + i * 7919
		var r := Levels.random_route_cells(s, false, 0)
		if r < Levels.RANDOM_MIN_ROUTE or r > Levels.random_max_route_cells(0):
			too_short += 1
		if r <= Levels.random_route_cells_for(200, 0):
			short_routes += 1
	_check(too_short == 0, "10k seeds: every route between %d cells and the 95%% route" % Levels.RANDOM_MIN_ROUTE)
	_check(short_routes >= SEEDS * 0.015 and short_routes <= SEEDS * 0.035, "tickets near the spawn (route <= 20%% of the meter) stay rare: %.2f%%" % (short_routes * 100.0 / SEEDS))

	# --- Real mazes at MORE SLIME 0, 4 and 7
	var kinds := [0, 0, 0]
	var fallbacks := 0
	var off_route := 0
	var too_big := 0
	var not_solvable := 0
	var near_spawn := 0
	var areas := [0, 0, 0]
	var low_u_area := [0, 0]
	for i in MAZES:
		var s := 1 + i * 7919
		var level: int = [0, 4, 7][i % 3]
		var cfg := Levels.random_config(s, false, level)
		var maze := MazeGenerator.generate_random(cfg)
		areas[i % 3] += maze.cells.x * maze.cells.y
		if level == 0 and cfg.usage < 0.3:
			low_u_area[0] += maze.cells.x * maze.cells.y
			low_u_area[1] += 1
		kinds[maze.spawn_kind] += 1
		if maze.spawn_kind != maze.spawn_rolled:
			fallbacks += 1
		var reach := MazeGenerator.distances_from(maze, maze.start)
		if not MazeGenerator.is_completable(maze) or reach.get(maze.goal, -1) != maze.goal_steps or maze.goal_steps < Levels.RANDOM_MIN_ROUTE:
			not_solvable += 1
		if absi(maze.goal_steps - cfg.route) > 2:
			off_route += 1
		if maze.diameter < cfg.room and maze.cells != Levels.RANDOM_MAX_CELLS:  # only the max size may fall a little short
			off_route += 1
		var floor_cells := Levels.random_floor_cells(level)
		if maze.cells.x < floor_cells.x or maze.cells.y < floor_cells.y or maze.cells.x > Levels.RANDOM_MAX_CELLS.x or maze.cells.y > Levels.RANDOM_MAX_CELLS.y:
			too_big += 1
		if absi(maze.goal.x - maze.start.x) + absi(maze.goal.y - maze.start.y) <= 4:
			near_spawn += 1
	_check(not_solvable == 0, "%d mazes: every one solvable, the ticket exactly goal_steps (>= %d) from the start" % [MAZES, Levels.RANDOM_MIN_ROUTE])
	_check(off_route == 0, "...the ticket at the intended route length +-2, the maze's longest route at least the 95%% route below the max size (%d off)" % off_route)
	_check(too_big == 0, "...sizes within the level's floor .. %s (avg area L0 %d, L4 %d, L7 %d)" % [Levels.RANDOM_MAX_CELLS, areas[0] / (MAZES / 3), areas[1] / (MAZES / 3), areas[2] / (MAZES / 3)])
	_check(areas[0] < areas[1] and areas[1] <= areas[2], "...mazes grow with MORE SLIME")
	_check(low_u_area[1] > 0 and low_u_area[0] / low_u_area[1] * 100 >= areas[0] / (MAZES / 3) * 95, "...low-u seeds (u < 0.30) get full-size mazes too (avg %d cells)" % (low_u_area[0] / maxi(low_u_area[1], 1)))
	_check(near_spawn > 0 and near_spawn <= MAZES / 20, "...a ticket within 4 cells of the spawn happens, rarely (%d of %d)" % [near_spawn, MAZES])
	# 600 picks: +-5% (3.5 sd); the rule rarely needs a fallback (measured 0 in 1,200 mazes).
	var total := float(MAZES)
	_check(absf(kinds[0] / total - 0.33) <= 0.05 and absf(kinds[1] / total - 0.30) <= 0.05 and absf(kinds[2] / total - 0.37) <= 0.05,
		"spawn classes still about 33/30/37: EDGE %.1f%% NEAR %.1f%% ANY %.1f%% (%d fallbacks)" % [kinds[0] * 100 / total, kinds[1] * 100 / total, kinds[2] * 100 / total, fallbacks])
	_check(fallbacks <= MAZES / 20, "class fallbacks are rare (%d)" % fallbacks)

	# --- Seed codes: the same "N-L" code gives the same maze for anyone; the meter stays the player's
	var code_seed := _seed_with(500, 650)
	var mine: Node2D = await _game(code_seed, 3, 3)
	var richer: Node2D = await _game(code_seed, 3, 8)
	var poorer: Node2D = await _game(code_seed, 3, 0)
	var same: bool = mine.maze.walls == richer.maze.walls and mine.maze.start == richer.maze.start and mine.maze.goal == richer.maze.goal \
		and mine.maze.walls == poorer.maze.walls and mine.maze.goal == poorer.maze.goal
	# the goal ticket stands on the code's goal cell for everyone
	same = same and mine.goal.position == richer.goal.position and mine.goal.position == poorer.goal.position and mine.goal is TicketGoal
	_check(same, "code %s: same maze, start and ticket at MORE SLIME 0, 3 and 8" % Levels.seed_code(code_seed, 3))
	var u := Levels.random_usage(code_seed)
	_check(absf(mine.perfect_usage - u) < 0.02, "the code's own level: a perfect run uses u (%.3f vs %.3f)" % [mine.perfect_usage, u])
	_check(absf(richer.perfect_usage - mine.perfect_usage * 1.3 / 1.8) < 0.01, "more slime than the code: a smaller share of a bigger meter (%.3f)" % richer.perfect_usage)
	_check(poorer.perfect_usage <= Levels.RANDOM_MAX_USAGE + 0.0001 and poorer.perfect_usage > mine.perfect_usage, "less slime than the code: more of the meter, capped at 95%% so it stays winnable (%.3f)" % poorer.perfect_usage)
	for g: Node2D in [mine, richer, poorer]:
		g.free()

	# --- The result line (ticket line only; no slime-usage commentary)
	var g2: Node2D = await _game(code_seed, 0, 0)
	g2.hud.show_rewards({tickets = 4, attempt = 2, cap = ""})
	_check(g2.hud.rewards_texts == ["TICKET! ATTEMPT 2 = +4"], "the result names the attempt and its payout (%s)" % [g2.hud.rewards_texts])
	g2.free()

	# --- Autopilot perfect runs: slime used within a few % of u (low, middle, high u; MORE SLIME 0, 4 and 7)
	var runs := [[_seed_with(100, 125), 0], [_seed_with(240, 260), 0], [_seed_with(540, 560), 0], [_seed_with(930, 950), 0], [_seed_with(100, 130), 4], [_seed_with(540, 560), 4], [_seed_with(100, 130), 7], [_seed_with(925, 950), 7]]
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

	_result()
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
		got.append([Levels.random_usage_permille(s), Levels.random_route_cells(s, false, 0), Levels.random_route_cells(s, false, 7)])
	var want := [[371, 26, 51], [749, 51, 102], [406, 28, 56], [202, 14, 28], [498, 34, 68]]
	if str(got) != str(want):
		print("    golden usage now: ", got)
		return false
	return true


