extends SceneTree

## Maze determinism guard: every randomizer seed (2,000 seeds x MORE SLIME 0 / 5 / 10 and hard
## mode) and every story level must build exactly the maze, start, goal (chalice / randomizer ticket)
## and route it built before. The golden digests in tests/data/maze_golden.txt were written by this
## script from the code as it was before (first the BFS speed-ups, commit 194d2cc; rewritten without
## the old optional ticket pickup's fields from ec13940, the last build that had it, so the mazes
## are proven unchanged by the ticket-goal rework):
##   ./tools/godot.sh --path . --headless -s res://tests/test_maze_golden.gd -- --write-golden=/abs/path.txt
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_maze_golden.gd

const GOLDEN := "res://tests/data/maze_golden.txt"
const SEEDS := 2000
const LEVELS: Array[int] = [0, 5, 10, -1]  # -1 = hard mode

var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
	var out := ""
	var golden_path := GOLDEN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--write-golden="):
			out = a.trim_prefix("--write-golden=")
		elif a.begins_with("--golden="):
			golden_path = a.trim_prefix("--golden=")
	var lines := PackedStringArray()
	var times: Array[float] = []
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			lines.append("story %d %s %s" % [level, "hard" if hard else "normal", _story_digest(level, hard)])
	for slime_level in LEVELS:
		for i in SEEDS:
			var s := _seed(i)
			var t := Time.get_ticks_usec()
			var digest := _random_digest(s, slime_level)
			times.append((Time.get_ticks_usec() - t) / 1000.0)
			lines.append("random %d %d %s" % [s, slime_level, digest])
	times.sort()
	print("  randomizer build: mean %.2f ms, p99 %.1f ms, worst %.1f ms over %d builds" % [
		_mean(times), times[int(times.size() * 0.99)], times[-1], times.size()])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("wrote ", lines.size(), " digests to ", out)
		quit(0)
		return

	var golden := FileAccess.get_file_as_string(golden_path).strip_edges().split("\n")
	_check(golden.size() == lines.size(), "golden file has every digest (%d of %d)" % [golden.size(), lines.size()])
	var bad := 0
	for i in mini(golden.size(), lines.size()):
		if golden[i] != lines[i]:
			if bad < 5:
				print("  differs: now '%s', golden '%s'" % [lines[i], golden[i]])
			bad += 1
	_check(bad == 0, "every story level and %d randomizer builds match the golden mazes, starts, goals and routes (%d differ)" % [SEEDS * LEVELS.size(), bad])
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


## Seeds spread over the whole range (small ones, and big ones like the game rolls).
static func _seed(i: int) -> int:
	return 1 + i if i < 500 else 1 + (i * 1103515245 + 12345) % 2000000000


static func _random_digest(s: int, slime_level: int) -> String:
	var hard := slime_level < 0
	var config := Levels.random_config(s, hard, maxi(slime_level, 0))
	var maze := MazeGenerator.generate_random(config)
	var goal_usage: float = MazeGenerator.distances_from(maze, maze.start)[maze.goal] * MazeGenerator.CELL_SPAN * config.tile_cost / 100.0
	return _digest([maze.walls.hex_encode(), maze.size, maze.cells, maze.start, maze.goal, maze.goal_steps,
		maze.spawn_kind, maze.spawn_rolled, maze.diameter, maze.get("noise_seed", -1), maze.route_target,
		snappedf(goal_usage, 0.000001)])


static func _story_digest(level: int, hard: bool) -> String:
	var maze := MazeGenerator.generate_level(Levels.get_config(level, hard))
	var depths := MazeGenerator.dead_end_depths(maze)
	var depth_list := []
	for y in maze.cells.y:
		for x in maze.cells.x:
			depth_list.append(depths.get(Vector2i(x, y), 0))
	return _digest([maze.walls.hex_encode(), maze.start, maze.goal, maze.goal_steps, maze.spawn_kind,
		maze.spawn_rolled, maze.diameter, depth_list, Levels.coin_cells(maze, level, Levels.get_config(level, hard).seed),
		MazeGenerator.shortest_path(maze, maze.start, maze.goal), Levels.level_par(level, hard)])


static func _digest(parts: Array) -> String:
	return var_to_str(parts).md5_text().substr(0, 12)


static func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
