extends SceneTree

## Phase 2 checks: charging roots and aims the slime, clean jumps are cheap and leave no
## trail in the air, wall splats cost the penalty, stun, and stain the wall.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 -s res://tests/test_phase2.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0
var landed_hit := -1  # -1 = not landed yet, 0 = clean, 1 = wall


func _initialize() -> void:
	_check(Slime.jump_distance_for(0.0) == 16.0 and Slime.jump_distance_for(100.0) == 128.0,
		"charge 0-100 maps to 1-8 tiles")

	# Charging with real input: holds still, aims, fills to ~50% in 0.75 s, launches on release.
	var game := await _spawn()
	var open_right: bool = Vector2i.RIGHT in MazeGenerator.open_neighbors(game.maze, game.maze.start)
	var open_action := "move_right" if open_right else "move_down"
	var open_dir := Vector2.RIGHT if open_right else Vector2.DOWN
	var start: Vector2 = game.slime.position
	Input.action_press("jump")
	Input.action_press(open_action)
	await _wait(0.75)
	_check(game.slime.state == Slime.State.CHARGING, "holding jump charges")
	_check(absf(game.slime.charge - 50.0) < 4.0, "charge fills to ~50%% in 0.75 s (%.1f)" % game.slime.charge)
	_check(game.slime.position.distance_to(start) < 0.5, "slime holds still while charging")
	_check(game.slime.facing == open_dir, "movement keys aim while charging")
	Input.action_release("jump")
	await physics_frame
	Input.action_release(open_action)
	_check(game.slime.is_airborne(), "releasing jump launches")
	game.free()

	# Clean jump down a straight corridor three cells long (placed wherever the maze has one).
	game = await _spawn()
	var run := _find_straight_run(game, 3)
	var run_dir: Vector2 = Vector2(run.dir)
	start = MazeGenerator.cell_center(run.cell, 16)
	game.slime.position = start
	game.last_slime_pos = start
	var distance := 3.0 * MazeGenerator.CELL_SPAN * 16.0
	game.slime.facing = run_dir
	game.slime.launch((distance / 16.0 - 1.0) / 7.0 * 100.0)
	await _wait_for_landing()
	var expected_cost: float = distance / 16.0 * game.slime_cost_per_tile * game.JUMP_COST_FACTOR
	_check(landed_hit == 0, "jump within the open corridor lands cleanly (%.0f px)" % distance)
	_check(absf(game.slime.position.distance_to(start) - distance) < 1.0, "lands at the charged distance")
	_check(absf(game.last_jump_cost - expected_cost) < 0.01, "clean jump costs half of gliding (%.2f%%)" % game.last_jump_cost)
	_check(absf(game.slime_remaining - (100.0 - expected_cost)) < 0.01, "no glide cost is charged in the air")
	_check(game.fog_alpha_at(start + run_dir * distance / 2.0) == 1.0, "no trail is left mid-air")
	_check(game.fog_alpha_at(game.slime.position) == 0.0, "landing leaves a goo splat")
	game.free()

	# Full-power jump straight into the wall above the start.
	game = await _spawn()
	start = game.slime.position
	game.slime.facing = Vector2.UP
	game.slime.launch(100.0)
	await _wait_for_landing()
	var glide_cost: float = start.distance_to(game.slime.position) / 16.0 * game.slime_cost_per_tile
	_check(landed_hit == 1, "jumping into a wall splats")
	_check(absf(game.slime.position.y - (16.0 + Slime.RADIUS)) < 0.5, "slime stops against the wall (y = %.1f)" % game.slime.position.y)
	var flown: float = start.distance_to(game.slime.position)
	_check(absf(game.last_jump_cost - (flown / 16.0 * game.slime_cost_per_tile * 0.5 + game.SPLAT_PENALTY_MAX)) < 0.01,
		"full-power splat costs the distance flown plus the %d%% max penalty (%.2f%%)" % [game.SPLAT_PENALTY_MAX, game.last_jump_cost])
	_check(game.splat_penalty(16.0) == game.SPLAT_PENALTY_MIN, "a tiny hop into a wall only adds the %d%% min penalty" % game.SPLAT_PENALTY_MIN)
	_check(game.last_jump_cost > glide_cost, "splat costs more than gliding there (%.2f%% vs %.2f%%)" % [game.last_jump_cost, glide_cost])
	_check(game.fog_alpha_at(Vector2(start.x, 14.0)) == 0.0, "splat stains the wall with goo")
	_check(game.slime.state == Slime.State.STUNNED, "splat stuns the slime")
	await _wait(0.5)
	_check(game.slime.state == Slime.State.GLIDE, "slime recovers after the stun")
	game.free()

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	landed_hit = -1
	await physics_frame
	game.slime.jump_landed.connect(func(_d: float, hit: bool, _n: Vector2) -> void: landed_hit = 1 if hit else 0)
	return game


## First cell (and direction, right or down) where the maze runs straight for `steps` cells.
func _find_straight_run(game: Node2D, steps: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var cell := Vector2i(x, y)
				var ok := true
				for i in steps:
					ok = ok and (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell)
					cell += dir
				if ok:
					return {cell = Vector2i(x, y), dir = dir}
	push_error("no straight run of %d cells" % steps)
	return {}


func _wait_for_landing() -> void:
	landed_hit = -1
	for i in 180:
		if landed_hit != -1:
			return
		await physics_frame


func _wait(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
