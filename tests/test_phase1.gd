extends "res://tests/suite_base.gd"

## Phase 1 checks: trail reveals the black map, walls next to the trail show, gliding costs
## slime (idling doesn't), walls block, the chalice is reachable, and running dry loses.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 -s res://tests/test_phase1.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
const AUTOPILOT := preload("res://tests/autopilot.gd")

var last_result := -1  # -1 = not finished, 0 = lost, 1 = won


func _initialize() -> void:
	var game := await _spawn()
	var start: Vector2 = game.slime.position
	_check(game.fog_alpha_at(start) == 0.0, "floor under the slime is revealed at start")
	_check(game.fog_alpha_at(Vector2(game.maze.size * 16) - Vector2(8, 8)) == 1.0, "far corner starts black")
	var wall := StartDirs.wall_dir(game.maze, game.maze.start)
	_check(absf(game.fog_alpha_at(start + Vector2(wall) * 16.0) - game.WALL_FOG_ALPHA) < 0.01,
		"wall next to the trail is revealed (dimmed)")

	var open_dir := StartDirs.action(StartDirs.open_dir(game.maze, game.maze.start))
	await _hold(open_dir, 0.6)
	await _wait_seconds(1.0)
	var traveled: float = game.slime.position.distance_to(start)
	var used: float = 100.0 - game.slime_remaining
	_check(traveled > 10.0, "gliding moves the slime (%.1f px)" % traveled)
	_check(absf(used - traveled / 16.0 * game.slime_cost_per_tile) < 0.5, "slime used matches distance (%.2f%% for %.1f px)" % [used, traveled])
	_check(game.fog_alpha_at(game.slime.position) == 0.0, "trail reveals where the slime went")

	var before: float = game.slime_remaining
	await _wait_seconds(1.0)
	_check(game.slime_remaining == before, "with the idle drain off, standing still costs nothing")
	Economy.idle_drain_force = -1
	before = game.slime_remaining
	await _wait_seconds(2.0)
	var idle_used: float = before - game.slime_remaining
	_check(Economy.IDLE_DRAIN_ON and absf(idle_used - 2.0 * Economy.IDLE_DRAIN) < 0.1,
		"standing still drains %.1f%% a second (%.2f%% in 2 s)" % [Economy.IDLE_DRAIN, idle_used])
	Economy.idle_drain_force = 0

	game.slime.position = start  # back on the start, then push into the wall beside it
	await physics_frame
	await _hold(StartDirs.action(wall), 2.0)
	var pushed: float = (game.slime.position - start).dot(Vector2(wall))
	_check(pushed < 2.0, "the wall beside the start stops the slime (%.1f px into it)" % pushed)
	game.free()

	game = await _spawn()
	game.add_child(AUTOPILOT.new())
	await _wait_until_finished(game, 40.0)
	_check(last_result == 1, "autopilot reaches the chalice (%.1f%% slime left)" % game.slime_remaining)
	_check(game.slime_remaining > 0.0, "the level is beatable within the slime budget")
	game.free()

	game = await _spawn()
	game.slime_remaining = 0.3
	Input.action_press(open_dir)
	await _wait_until_finished(game, 3.0)
	Input.action_release(open_dir)
	_check(last_result == 0, "running out of slime dries the slime up")
	game.free()

	_result()
	quit(1 if failures else 0)


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	last_result = -1
	game.level_finished.connect(func(won: bool) -> void: last_result = 1 if won else 0)
	await physics_frame
	return game


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait_seconds(seconds)
	Input.action_release(action)


func _wait_until_finished(game: Node2D, timeout: float) -> void:
	for i in int(timeout * 60):
		if game.finished:
			return
		await physics_frame


