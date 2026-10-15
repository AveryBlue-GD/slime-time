extends "res://tests/suite_base.gd"

## SpawnPicker (scripts/spawn_picker.gd): class odds 33 / 30 / 37 over 10k seeds (also after the
## minimum-route rule), determinism, integer-only RNG, the 60% minimum route, every maze solvable
## with the goal (story chalice / randomizer ticket) and the story coins reachable from the start.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_spawn_picker.gd

const SEEDS := 10000
const MAZES := 40
const TOLERANCE := 0.02



func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false

	# --- The class roll alone over 10k seeds
	var rolled := [0, 0, 0]
	for i in SEEDS:
		rolled[SpawnPicker.roll_kind(1 + i * 7919)] += 1
	_check_odds(rolled, "rolled class")

	# --- The final class after the minimum-route rule (10k picks over 40 real randomizer mazes)
	var mazes: Array[Dictionary] = []
	for i in MAZES:
		var s := 3000 + i * 104729
		mazes.append(MazeGenerator.generate_noise(Levels.random_config(s).cells, s))
	var final := [0, 0, 0]
	var short_route := 0
	var wrong_cell := 0
	var fallbacks := 0
	for i in SEEDS:
		var maze: Dictionary = mazes[i % MAZES]
		var pick := SpawnPicker.pick(maze, 1 + i * 7919)
		final[pick.kind] += 1
		if pick.kind != pick.rolled:
			fallbacks += 1
		if pick.steps * 100 < SpawnPicker.MIN_ROUTE_PCT * pick.diameter:
			short_route += 1
		if not SpawnPicker.in_kind(pick.start, maze.cells, pick.kind):
			wrong_cell += 1
	_check_odds(final, "final class (min-route rule applied, %d fallbacks)" % fallbacks)
	_check(short_route == 0, "every start-to-chalice route is at least %d%% of the longest route" % SpawnPicker.MIN_ROUTE_PCT)
	_check(wrong_cell == 0, "every start lies in its class (EDGE d=0, NEAR d=1..2)")

	# --- Class definitions
	var c := Vector2i(10, 6)
	_check(SpawnPicker.edge_depth(Vector2i(0, 3), c) == 0 and SpawnPicker.edge_depth(Vector2i(9, 5), c) == 0
		and SpawnPicker.edge_depth(Vector2i(1, 1), c) == 1 and SpawnPicker.edge_depth(Vector2i(4, 2), c) == 2,
		"edge depth: cells from the nearest side")
	_check(SpawnPicker.cells_of(SpawnPicker.Kind.EDGE, c).size() == 2 * 10 + 2 * 4 and SpawnPicker.cells_of(SpawnPicker.Kind.ANY, c).size() == 60,
		"EDGE = the 28-cell outer ring of a 10x6 maze, ANY = all 60 cells")

	# --- Determinism + integer-only RNG (same picks on web and desktop)
	var a := MazeGenerator.generate_random(Vector2i(20, 12), 777)
	var b := MazeGenerator.generate_random(Vector2i(20, 12), 777)
	_check(a.start == b.start and a.goal == b.goal and a.spawn_kind == b.spawn_kind, "same seed: same start, chalice and class")
	var source := FileAccess.get_file_as_string("res://scripts/spawn_picker.gd")
	_check(not "randf" in source and not "randfn" in source and not "float" in source and not "/ 100.0" in source,
		"the picker uses integer RNG draws and integer comparisons only")
	_check(SpawnPicker.roll_kind(1) == SpawnPicker.roll_kind(1) and _golden(), "pinned picks still match (guards against drift)")

	# --- Randomizer mazes: solvable, the goal (where the ticket stands) reachable
	var bad := 0
	for i in 150:
		var s := 50000 + i * 31
		var cfg := Levels.random_config(s)
		var maze := MazeGenerator.generate_random(cfg)
		var reach := MazeGenerator.distances_from(maze, maze.start)
		if not MazeGenerator.is_completable(maze) or maze.start == maze.goal or not reach.has(maze.goal):
			bad += 1
	_check(bad == 0, "150 randomizer seeds: always solvable, the ticket goal reachable (%d bad)" % bad)

	# --- Story levels (normal + hard): solvable, the chalice and every coin reachable, classes mixed
	var kinds := [0, 0, 0]
	var story_ok := true
	for hard in [false, true]:
		for level in range(1, Levels.COUNT + 1):
			var maze := Levels.story_maze(level, hard)
			var reach := MazeGenerator.distances_from(maze, maze.start)
			story_ok = story_ok and MazeGenerator.is_completable(maze) and reach.has(maze.goal)
			if hard:  # hard levels ask for an exact route (Levels.hard_route_cells), like the randomizer
				story_ok = story_ok and maze.goal_steps == Levels.get_config(level, true).route
			else:
				story_ok = story_ok and maze.goal_steps * 100 >= SpawnPicker.MIN_ROUTE_PCT * maze.diameter
			story_ok = story_ok and maze.spawn_kind == Levels.get_config(level, hard).spawn
			if not hard:
				kinds[maze.spawn_kind] += 1
				for cell in Levels.coin_cells(maze, level, Levels.get_config(level).seed):
					story_ok = story_ok and reach.has(cell) and cell != maze.start and cell != maze.goal
				if maze.spawn_kind == SpawnPicker.Kind.ANY and level > 1:
					story_ok = story_ok and SpawnPicker.edge_depth(maze.start, maze.cells) >= 3  # visibly interior
	_check(story_ok, "story levels: solvable, chalice and coins reachable, route >= %d%% (hard: its exact route), the configured class" % SpawnPicker.MIN_ROUTE_PCT)
	_check(kinds[0] >= 3 and kinds[1] >= 3 and kinds[2] >= 3, "the 10 levels mix edge / near-edge / interior starts %s" % [kinds])

	_result()
	quit(0 if failures == 0 else 1)


## A few picks on a fixed maze, pinned so an engine or code change that moves them is noticed.
func _golden() -> bool:
	var maze := MazeGenerator.generate_noise(Vector2i(20, 12), 4242)
	var got := []
	for s in [1, 2, 3, 99, 123456]:
		var p := SpawnPicker.pick(maze, s)
		got.append([p.kind, p.start])
	var want := [[2, Vector2i(13, 3)], [1, Vector2i(7, 9)], [0, Vector2i(0, 4)], [2, Vector2i(14, 0)], [0, Vector2i(0, 3)]]
	if str(got) != str(want):
		print("    golden picks now: ", got)
		return false
	return true


func _check_odds(counts: Array, what: String) -> void:
	var total: float = counts[0] + counts[1] + counts[2]
	var want := [0.33, 0.30, 0.37]
	var ok := true
	for k in 3:
		ok = ok and absf(counts[k] / total - want[k]) <= TOLERANCE
	_check(ok, "%s: EDGE %.1f%% NEAR %.1f%% ANY %.1f%% (want 33/30/37 +-%d)" % [what, counts[0] * 100.0 / total, counts[1] * 100.0 / total, counts[2] * 100.0 / total, TOLERANCE * 100])


