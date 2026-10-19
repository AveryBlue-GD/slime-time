extends "res://tests/suite_base.gd"

## Hard-mode rebalance (2026-10-14, docs/level-design.md section 7): the per-level slime multiplier
## table (_col("slime_mult")), meters / routes / allowances hitting their targets, the bigger hard
## mazes (solvable, within HARD_MAX_CELLS, spawn class kept, more dead ends, deterministic and fast to
## build), par from the new routes, hard records and tiers in a save (pre-release codes refused,
## hostile values; the pre-v5 migration was removed in spring cleaning) and --story-complete's hard
## times on the new pars. The autopilot walking every hard level under par: tests/test_phase3.gd;
## the --autoplay bot: tests/test_autoplay.gd. Uses throwaway Progress nodes (never the real save).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hard_rebalance.gd

const PROGRESS := preload("res://scripts/progress.gd")
## Dead ends of the v4 hard mazes (docs/playtime-estimate.md before the rebalance): every new maze has more.
const V4_DEAD_ENDS: Array[int] = [8, 11, 12, 25, 20, 28, 34, 50, 67, 68]
const GRAB := Levels.GRAB_REACH / Levels.TILE



func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false
	_check_tables()
	_check_mazes()
	_check_migration()
	_check_story_complete()
	_result()
	quit(0 if failures == 0 else 1)


## One hard table as a column (index 0 = level 1), from the per-level files (Levels.hard_data).
static func _col(key: String) -> Array:
	var out := []
	for level in range(1, Levels.COUNT + 1):
		out.append(Levels.hard_data(level)[key])
	return out


func _check_tables() -> void:
	# The shipped curve: +10% per level (L1 x1.1 ... L10 x2.0). Editing HARD_SLIME_MULT on purpose
	# (e.g. a flat +10%) means updating this one pin; every other check follows the table.
	var progressive := _col("slime_mult").size() == Levels.COUNT
	for i in Levels.COUNT:
		progressive = progressive and is_equal_approx(_col("slime_mult")[i], 1.0 + 0.1 * (i + 1))
	_check(progressive, "HARD_SLIME_MULT is the progressive +10%%/level table %s" % [_col("slime_mult")])
	_check(_col("allowance").size() == Levels.COUNT and _col("v4_steps").size() == Levels.COUNT
		and _col("v4_target").size() == Levels.COUNT and _col("branching").size() == Levels.COUNT
		and _col("run").size() == Levels.COUNT, "every hard table has one entry per level")
	var rising := true
	for i in range(1, Levels.COUNT):
		rising = rising and _col("allowance")[i] >= _col("allowance")[i - 1]
	_check(rising and _col("allowance")[0] >= 1.08 and _col("allowance")[0] <= 1.15
		and _col("allowance")[-1] >= 1.25 and _col("allowance")[-1] <= 1.30,
		"the allowance rises with the level, ~1.1 at L1 to 1.25-1.30 at L10 %s" % [_col("allowance")])
	for level in range(1, Levels.COUNT + 1):
		var i := level - 1
		var config := Levels.get_config(level, true)
		var v4_meter: float = (_col("v4_steps")[i] * 2 - GRAB) / _col("v4_target")[i]
		var meter: float = config.meter_tiles
		var route_tiles: float = config.route * 2 - GRAB
		var allowance := meter / route_tiles
		# Ratio preserved, then the extra slack: route = v4 route x mult x (v4 usage x allowance)^-1.
		var expected_route: float = (_col("v4_steps")[i] * 2 - GRAB) * _col("slime_mult")[i] / (_col("v4_target")[i] * _col("allowance")[i])
		_check(is_equal_approx(meter, v4_meter * _col("slime_mult")[i]) and is_equal_approx(meter, Levels.hard_meter_tiles(level)),
			"hard %2d: meter %.1f tiles = v4 meter %.1f x %.1f" % [level, meter, v4_meter, _col("slime_mult")[i]])
		_check(allowance >= _col("allowance")[i] - 0.0001 and route_tiles * allowance <= (route_tiles + 2.0) * _col("allowance")[i] + 0.0001
			and absf(route_tiles / expected_route - 1.0) < 0.05 and is_equal_approx(config.target, route_tiles / meter),
			"hard %2d: route %d cells (%.1f tiles, wanted %.1f), allowance %.3f (table %.2f, within one cell), a perfect run uses %.1f%%"
			% [level, config.route, route_tiles, expected_route, allowance, _col("allowance")[i], config.target * 100.0])
	var normal := Levels.get_config(3)
	_check(not normal.has("meter_tiles") and not normal.has("route") and normal.cells == Levels.data(3).cells and normal.target == Levels.data(3).target,
		"normal-mode configs are unchanged (no hard fields)")


func _check_mazes() -> void:
	for level in range(1, Levels.COUNT + 1):
		var config := Levels.get_config(level, true)
		var maze: Dictionary = Levels.build_story_maze(level, true)
		var again := Levels.build_story_maze(level, true)
		var dist := MazeGenerator.distances_from(maze, maze.start)
		var base: Vector2i = Levels.data(level).cells
		var dead_ends := MazeGenerator.dead_end_count(maze)
		_check(MazeGenerator.is_completable(maze) and maze.goal_steps == config.route and dist.get(maze.goal, -1) == config.route
			and MazeGenerator.shortest_path(maze, maze.start, maze.goal).size() == config.route + 1,
			"hard %2d: %dx%d maze is solvable, the chalice exactly %d cells from the start" % [level, maze.cells.x, maze.cells.y, config.route])
		_check(maze.cells.x <= Levels.HARD_MAX_CELLS.x and maze.cells.y <= Levels.HARD_MAX_CELLS.y and maze.cells.x >= base.x and maze.cells.y >= base.y
			and maze.cells.x * maze.cells.y > base.x * base.y,
			"hard %2d: bigger than the level's normal %dx%d, within the %dx%d cap" % [level, base.x, base.y, Levels.HARD_MAX_CELLS.x, Levels.HARD_MAX_CELLS.y])
		_check(maze.spawn_kind == config.spawn and config.route > _col("v4_steps")[level - 1] and dead_ends > V4_DEAD_ENDS[level - 1],
			"hard %2d: %s start kept; route %d > v4 %d; %d dead ends > v4 %d" % [level, SpawnPicker.KIND_NAMES[config.spawn],
				config.route, _col("v4_steps")[level - 1], dead_ends, V4_DEAD_ENDS[level - 1]])
		_check(maze.get("goal_farthest", false) and SpawnPicker.farthest(maze, maze.start).steps == config.route,
			"hard %2d: the chalice is the start's farthest cell (end of a branch), as on every story level" % level)
		_check(again.walls == maze.walls and again.start == maze.start and again.goal == maze.goal, "hard %2d: the same maze every build" % level)
		var route_tiles: float = config.route * 2 - GRAB
		var walk: float = route_tiles * Levels.TILE / Levels.PAR_SPEED
		_check(is_equal_approx(Levels.level_par(level, true), Levels.par_for_path(route_tiles)) and walk < Levels.level_par(level, true),
			"hard %2d: par %.1f s = new route / base speed x 1.35 + 1 (walking it takes %.1f s)" % [level, Levels.level_par(level, true), walk])
	_check_budget("hard maze builds (headless): the slowest of 3 builds per level", 15.0, func() -> float:
		var worst := 0.0
		for level in range(1, Levels.COUNT + 1):
			for n in 3:
				var t := Time.get_ticks_usec()
				Levels.build_story_maze(level, true)
				worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
		return worst)


func _check_migration() -> void:
	var p := _fresh()
	p._read(_v5_save())
	_check(p.best_times[101] == 12.0 and p.best_times[105] == 30.0 and p.medals.get(101, 0) == 3 and p.medals.get(105, 0) == 2
		and p.hard_cleared == [1, 5, 10], "a version 5 save keeps its hard best times, tiers and clears")
	_check(p.best_times[1] == 14.0 and p.medals_for(1) == 3 and p.levels_cleared == 10 and p.coins_found[1] == ["9,9", "8,8"]
		and p.tickets == 12 and p.hats_owned == ["tophat"] and p.selected_skin == "mint", "normal records, coins, tickets, hats and skin are read")
	var written: ConfigFile = p._write()
	var r := _fresh()
	r._read(written)
	_check(written.get_value("meta", "version") == PROGRESS.SAVE_VERSION and r.best_times == p.best_times and r.medals == p.medals,
		"the next save is the current version and reads back unchanged")
	var old := _v5_save()
	old.set_value("meta", "version", 4)
	var code: String = PROGRESS.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(old.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var u := _fresh()
	_check(not u.load_code(code) and u.best_times.is_empty() and u.is_fresh_save(), "a pre-release v4 code (no release epoch) is refused: nothing migrates in")

	# A save with hard times but no [medals]: tiers come from the times against the current hard par.
	var bare := ConfigFile.new()
	bare.set_value("meta", "version", 5)
	bare.set_value("progress", "hard_cleared", [2, 3])
	bare.set_value("records", "level_102", Levels.level_par(2, true) * 1.2)
	bare.set_value("records", "level_103", Levels.level_par(3, true) * 0.9)
	var b := _fresh()
	b._read(bare)
	_check(b.medals.get(102, 0) == 2 and b.medals.get(103, 0) == 3 and b.best_times.has(102) and b.best_times.has(103),
		"a save without [medals]: hard tiers from the times vs the hard par (silver, gold), times kept")

	var bad := ConfigFile.new()
	bad.set_value("meta", "version", "five")
	bad.set_value("progress", "hard_cleared", [1, "x", 99])
	bad.set_value("records", "level_101", INF)
	bad.set_value("records", "level_102", "fast")
	bad.set_value("records", "level_103", -5.0)
	bad.set_value("medals", "level_101", 99)
	bad.set_value("medals", "level_102", -3)
	var h := _fresh()
	h._read(bad)
	var hard_times := 0
	for key: int in h.best_times:
		hard_times += 1 if key > PROGRESS.HARD_RECORDS else 0
	_check(hard_times == 0 and h.medals.get(101, 0) <= 3 and h.medals.get(102, 0) == 0, "hostile values: no hard time survives, tiers clamp")
	for node in [p, r, u, b, h]:
		node.free()


func _check_story_complete() -> void:
	var p := _fresh()
	p.enable_story_complete()
	var ok := true
	var worst := 0.0
	for level in range(1, Levels.COUNT + 1):
		var key: int = level + PROGRESS.HARD_RECORDS
		var par := Levels.level_par(level, true)
		var walk: float = (Levels.get_config(level, true).route * 2 - GRAB) * Levels.TILE / Levels.PAR_SPEED
		var best: float = p.best_times.get(key, -1.0)
		ok = ok and is_equal_approx(best, snappedf(par * PROGRESS.STORY_SILVER_PACE, 0.01)) and best > walk and p.medals.get(key, 0) == PROGRESS.TIER_SILVER
		worst = maxf(worst, best / par)
	_check(ok and p.hard_cleared.size() == Levels.COUNT and p.medals_total(true) == 20,
		"--story-complete: hard times at 1.15 x the NEW par (silver, slower than a perfect walk), 20/30 hard")
	p.free()


func _v5_save() -> ConfigFile:
	var f := ConfigFile.new()
	f.set_value("meta", "version", 5)
	f.set_value("progress", "levels_cleared", 10)
	f.set_value("progress", "highest_unlocked", 10)
	f.set_value("progress", "hard_cleared", [1, 5, 10])
	f.set_value("coins", "level_1", ["9,9", "8,8"])
	f.set_value("upgrades", "slime", 1)
	f.set_value("records", "level_1", 14.0)
	f.set_value("records", "level_2", 19.5)
	f.set_value("records", "level_101", 12.0)
	f.set_value("records", "level_105", 30.0)
	f.set_value("records", "level_110", 55.0)
	f.set_value("medals", "level_1", 3)
	f.set_value("medals", "level_101", 3)
	f.set_value("medals", "level_105", 2)
	f.set_value("medals", "level_110", 1)
	f.set_value("wallet", "globs", 12)
	f.set_value("hats", "owned", ["tophat"])
	f.set_value("skin", "selected", "mint")
	return f


func _fresh() -> Node:
	var node: Node = PROGRESS.new()
	node.saving_enabled = false
	return node

