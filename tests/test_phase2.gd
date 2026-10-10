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
	var open_right: bool = not game.is_wall_tile(Vector2i(3, 1))
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

	# Clean jump along the open corridor.
	game = await _spawn()
	start = game.slime.position
	var free_px := _free_run(game, open_dir) - Slime.RADIUS - 1.0
	var distance := minf(free_px, 128.0)
	game.slime.facing = open_dir
	game.slime.launch((distance / 16.0 - 1.0) / 7.0 * 100.0)
	await _wait_for_landing()
	var expected_cost: float = distance / 16.0 * game.slime_cost_per_tile * game.JUMP_COST_FACTOR
	_check(landed_hit == 0, "jump within the open corridor lands cleanly (%.0f px)" % distance)
	_check(absf(game.slime.position.distance_to(start) - distance) < 1.0, "lands at the charged distance")
	_check(absf(game.last_jump_cost - expected_cost) < 0.01, "clean jump costs half of gliding (%.2f%%)" % game.last_jump_cost)
	_check(absf(game.slime_remaining - (100.0 - expected_cost)) < 0.01, "no glide cost is charged in the air")
	_check(game.fog_alpha_at(start + open_dir * distance / 2.0) == 1.0, "no trail is left mid-air")
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
	_check(absf(game.slime.position.y - 21.0) < 0.5, "slime stops against the wall (y = %.1f)" % game.slime.position.y)
	_check(absf(game.last_jump_cost - (128.0 / 16.0 * game.slime_cost_per_tile * 0.5 + game.SPLAT_PENALTY)) < 0.01,
		"splat costs the jump plus the %d%% penalty (%.2f%%)" % [game.SPLAT_PENALTY, game.last_jump_cost])
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


## Pixels from the start cell's center to the first wall along dir (2-tile-wide corridor).
func _free_run(game: Node2D, dir: Vector2) -> float:
	var step := Vector2i(dir)
	var side := Vector2i(step.y, step.x).abs()
	var tile := Vector2i(1, 1) + step
	while not game.is_wall_tile(tile) and not game.is_wall_tile(tile + side):
		tile += step
	var wall_edge := Vector2(tile * 16) if (step.x > 0 or step.y > 0) else Vector2((tile + Vector2i.ONE) * 16)
	var along: Vector2 = (wall_edge - game.slime.position) * dir
	return along.x + along.y


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
