extends SceneTree

## Phase 3 checks: all 10 levels are beatable by a perfect glide using about the level's
## target share of slime, difficulty rises, tiles are varied but deterministic, every wall
## collides, and progress saves/loads.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_phase3.gd

const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")
const PROGRESS := preload("res://scripts/progress.gd")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0


func _initialize() -> void:
	var stats := []
	for level in range(1, Levels.COUNT + 1):
		var game := await _spawn(level)
		var target: float = Levels.get_config(level).target * 100.0
		var info := {
			steps = game.maze.goal_steps,
			dead_ends = MazeGenerator.dead_end_count(game.maze),
			broken = _broken_share(game),
		}
		var damage_kinds := {}
		for tile: Vector2i in game.wall_damage:
			damage_kinds[game.wall_damage[tile]] = true
		var floor_kinds := {}
		for tile: Vector2i in game.floor_layer.get_used_cells():
			if not game.is_wall_tile(tile):
				floor_kinds[game.floor_layer.get_cell_atlas_coords(tile).x] = true

		game.add_child(AUTOPILOT.new())
		for i in 60 * 180:
			if game.finished:
				break
			await physics_frame
		var used: float = 100.0 - game.slime_remaining
		_check(game.finished and game.slime_remaining > 0.0,
			"level %2d: %dx%d cells, path %2d cells, %2d dead ends, perfect run uses %.1f%% (target %.0f%%)"
			% [level, game.maze.cells.x, game.maze.cells.y, info.steps, info.dead_ends, used, target])
		_check(absf(used - target) < 4.0, "level %2d: slime used is within 4%% of the target" % level)
		_check(game.won and game.run_time <= game.par_time, "level %2d: the autopilot beats par from the %s start (%.1f s, par %.1f s)"
			% [level, SpawnPicker.KIND_NAMES[game.maze.spawn_kind], game.run_time, game.par_time])
		_check(damage_kinds.size() >= 3 and floor_kinds.size() >= 4,
			"level %2d: varied tiles (%d wall damage levels, %d floor types, %.0f%% broken walls)"
			% [level, damage_kinds.size(), floor_kinds.size(), info.broken * 100.0])
		stats.append(info)
		game.free()

	_check(stats[-1].steps > stats[0].steps * 2, "path to the chalice grows (%d -> %d cells)" % [stats[0].steps, stats[-1].steps])
	_check(stats[-1].dead_ends > stats[0].dead_ends * 3, "dead ends grow (%d -> %d)" % [stats[0].dead_ends, stats[-1].dead_ends])
	_check(stats[-1].broken > stats[0].broken * 3, "broken walls grow (%.0f%% -> %.0f%%)" % [stats[0].broken * 100.0, stats[-1].broken * 100.0])

	# Hard mode: different mazes, every one beatable by a perfect run with no upgrades, and every
	# one needing 85%+ of the slime.
	var settings: Node = root.get_node("Progress")
	settings.hard_mode = true
	for level in range(1, Levels.COUNT + 1):
		var hard := await _spawn(level)
		hard.add_child(AUTOPILOT.new())
		for i in 60 * 180:
			if hard.finished:
				break
			await physics_frame
		var used: float = 100.0 - hard.slime_remaining
		_check(hard.won and used >= 85.0,
			"hard level %2d: a perfect run wins using %.1f%% of the slime" % [level, used])
		hard.free()
	settings.hard_mode = false

	var a := await _spawn(5)
	var b := await _spawn(5)
	var same: bool = a.maze.walls == b.maze.walls
	for tile: Vector2i in a.floor_layer.get_used_cells():
		same = same and a.floor_layer.get_cell_atlas_coords(tile) == b.floor_layer.get_cell_atlas_coords(tile) \
			and a.wall_layer.get_cell_atlas_coords(tile) == b.wall_layer.get_cell_atlas_coords(tile)
	_check(same, "a level looks the same every time it's played")
	var source: TileSetAtlasSource = a.wall_layer.tile_set.get_source(0)
	var all_collide := true
	for row in 12:
		for column in 16:
			all_collide = all_collide and source.get_tile_data(Vector2i(column, row), 0).get_collision_polygons_count(0) == 1
	_check(all_collide, "every wall variant (even broken ones) blocks movement")
	a.free()
	b.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var progress: Node = PROGRESS.new()
	progress.save_path = TEST_SAVE
	progress.complete_level(3)
	var reloaded: Node = PROGRESS.new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.levels_cleared == 3 and reloaded.highest_unlocked == 4 and reloaded.current_level == 4,
		"clearing level 3 saves and unlocks level 4")
	reloaded.complete_level(10)
	_check(reloaded.levels_cleared == 10 and reloaded.current_level == 1, "beating level 10 records it and returns to level 1")
	progress.free()
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn(level: int) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	await physics_frame
	return game


func _broken_share(game: Node2D) -> float:
	var broken := 0
	for tile: Vector2i in game.wall_damage:
		if game.wall_damage[tile] == 3:
			broken += 1
	return float(broken) / game.wall_damage.size()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
