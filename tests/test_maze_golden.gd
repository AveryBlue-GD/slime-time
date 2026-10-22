extends "res://tests/suite_base.gd"

## Maze determinism guard: every randomizer seed (2,000 seeds x MORE SLIME 0 / 4 / 7 and hard
## mode) and every story level must build exactly the maze, start, goal (chalice / randomizer ticket)
## and route it built before. The golden digests in tests/data/maze_golden.txt were written by this
## script from the code as it was before (first the BFS speed-ups, commit 194d2cc; rewritten without
## the old optional ticket pickup's fields from ec13940, the last build that had it, so the mazes
## are proven unchanged by the ticket-goal rework). Rewritten on purpose on 2026-10-14 when
## randomizer mazes stopped shrinking with the seed's usage u (sized for the 95% route of the MORE
## SLIME level instead): the MORE SLIME 0 / 5 / 10 lines changed (except seeds that were already at
## the max size); the story lines and the hard-mode lines (fixed u, so the same size) are
## byte-identical to before. Rewritten on purpose again on 2026-10-14 for the hard-mode rebalance
## (Levels.HARD_SLIME_MULT, docs/level-design.md section 7): only the 10 "story N hard" lines changed
## (bigger hard mazes, new routes and pars; built via Levels.build_story_maze); every story normal
## line and all 8,000 randomizer lines (hard randomizer included) are byte-identical. Rewritten on purpose on
## 2026-10-15 for the upgrades v2 coin tree (MORE SLIME 0-7, docs/design/upgrades-v2.md A2.5): the
## MORE SLIME 5 / 10 lines became 4 / 7. The level 7 lines carry exactly the old level 10 digests (same
## x2.0 factor, same mazes; only the label changed); the level 4 lines (x1.60, the old level 6 factor,
## which had no lines) are new; the story, level 0 and hard lines are byte-identical. Rewritten on purpose
## on 2026-10-22 for the second route to the goal (MazeGenerator.add_second_route, normal randomizer only):
## 3,812 of the MORE SLIME 0 / 4 / 7 lines changed; every story line and every hard line is byte-identical. Also checks every randomizer build is solvable, its ticket exactly the
## asked route (>= RANDOM_MIN_ROUTE) from the start, and its size at least the level's floor.
##   ./tools/godot.sh --path . --headless -s res://tests/test_maze_golden.gd -- --write-golden=/abs/path.txt
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_maze_golden.gd

const GOLDEN := "res://tests/data/maze_golden.txt"
const SEEDS := 2000
const LEVELS: Array[int] = [0, 4, 7, -1]  # -1 = hard mode
const STORY_LINES := Levels.COUNT * 2
## `-- --shard=K` (0-3): only the randomizer group LEVELS[K] (plus the story digests when K is 0), compared with that slice
## of the golden file. tools/test_all.sh runs the four shards in parallel; no argument = everything in one process.
var shard := -1

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
		elif a.begins_with("--shard="):
			shard = int(a.trim_prefix("--shard="))
	var lines := PackedStringArray()
	var times: Array[float] = []
	var unsound := 0
	if shard <= 0:
		for level in range(1, Levels.COUNT + 1):
			for hard in [false, true]:
				lines.append("story %d %s %s" % [level, "hard" if hard else "normal", _story_digest(level, hard)])
	for slime_level in LEVELS if shard < 0 else [LEVELS[shard]]:
		for i in SEEDS:
			var s := _seed(i)
			var t := Time.get_ticks_usec()
			var hard := slime_level < 0
			var config := Levels.random_config(s, hard, maxi(slime_level, 0))
			var maze := MazeGenerator.generate_random(config)
			times.append((Time.get_ticks_usec() - t) / 1000.0)
			lines.append("random %d %d %s" % [s, slime_level, _random_digest(config, maze)])
			if not _sound(config, maze, maxi(slime_level, 0), hard):
				unsound += 1
	times.sort()
	print("  randomizer build: mean %.2f ms, p99 %.1f ms, worst %.1f ms over %d builds" % [
		_mean(times), times[int(times.size() * 0.99)], times[-1], times.size()])
	_check(unsound == 0, "every randomizer build is solvable, at least its level's floor in size, its ticket the asked route (>= %d cells) away (%d not)" % [Levels.RANDOM_MIN_ROUTE, unsound])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("wrote ", lines.size(), " digests to ", out)
		quit(0)
		return

	var golden := FileAccess.get_file_as_string(golden_path).strip_edges().split("\n")
	if shard >= 0:  # this shard's slice: the story lines (shard 0) and its SEEDS randomizer lines
		var first := STORY_LINES + shard * SEEDS
		golden = golden.slice(0 if shard == 0 else first, first + SEEDS)
	_check(golden.size() == lines.size(), "golden file has every digest (%d of %d)" % [golden.size(), lines.size()])
	var bad := 0
	for i in mini(golden.size(), lines.size()):
		if golden[i] != lines[i]:
			if bad < 5:
				print("  differs: now '%s', golden '%s'" % [lines[i], golden[i]])
			bad += 1
	_check(bad == 0, "every story level and %d randomizer builds match the golden mazes, starts, goals and routes (%d differ)" % [SEEDS * (LEVELS.size() if shard < 0 else 1), bad])
	_result()
	quit(0 if failures == 0 else 1)


## Seeds spread over the whole range (small ones, and big ones like the game rolls).
static func _seed(i: int) -> int:
	return 1 + i if i < 500 else 1 + (i * 1103515245 + 12345) % 2000000000


static func _random_digest(config: Dictionary, maze: Dictionary) -> String:
	var goal_usage: float = MazeGenerator.distances_from(maze, maze.start)[maze.goal] * MazeGenerator.CELL_SPAN * config.tile_cost / 100.0
	return _digest([maze.walls.hex_encode(), maze.size, maze.cells, maze.start, maze.goal, maze.goal_steps,
		maze.spawn_kind, maze.spawn_rolled, maze.diameter, maze.get("noise_seed", -1), maze.route_target,
		snappedf(goal_usage, 0.000001)])


## A randomizer build's sanity: connected, ticket exactly `route` cells from the start (never under
## the minimum), size within the level's floor .. max.
static func _sound(config: Dictionary, maze: Dictionary, slime_level: int, hard: bool) -> bool:
	var low := Levels.random_floor_cells(slime_level, hard)
	return MazeGenerator.is_completable(maze) and maze.goal_steps == config.route and maze.goal_steps >= Levels.RANDOM_MIN_ROUTE \
		and MazeGenerator.distances_from(maze, maze.start).get(maze.goal, -1) == maze.goal_steps \
		and maze.cells.x >= low.x and maze.cells.y >= low.y and maze.cells.x <= Levels.RANDOM_MAX_CELLS.x and maze.cells.y <= Levels.RANDOM_MAX_CELLS.y


static func _story_digest(level: int, hard: bool) -> String:
	var maze := Levels.build_story_maze(level, hard)
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


