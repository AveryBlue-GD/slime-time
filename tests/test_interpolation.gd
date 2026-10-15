extends "res://tests/suite_base.gd"

## Physics interpolation (high refresh, spring cleaning phase 4): on only while frames come faster than
## the 60 Hz ticks (Transition), opt-in per node (the slime; the scene root, the camera and hats are off),
## and never a change to the simulation: the same run tick for tick with it on or off. Nodes placed by
## hand each frame (fog hole, light, hat, pixel-locked camera) follow where the slime is drawn.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_interpolation.gd

var progress: Node
var transition: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = throwaway_save()
	progress.tutorial_seen = 3
	transition = root.get_node("Transition")

	# --- The switch: on above 72 fps, off below 66, kept in between; jitter fix off while on
	_check(not physics_interpolation and root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
		"off at start, and the scene root opts out (interpolation is opt-in per node)")
	for i in 60:
		transition.follow_frame_rate(1.0 / 144.0)
	_check(physics_interpolation and Engine.physics_jitter_fix == 0.0, "144 Hz frames: on, no jitter fix")
	for i in 60:
		transition.follow_frame_rate(1.0 / 69.0)
	_check(physics_interpolation, "69 Hz (between the thresholds): stays on")
	for i in 60:
		transition.follow_frame_rate(1.0 / 60.0)
	_check(not physics_interpolation and Engine.physics_jitter_fix == 0.5, "60 Hz frames: off again, the default jitter fix back")
	for i in 60:
		transition.follow_frame_rate(1.0 / 69.0)
	_check(not physics_interpolation, "69 Hz from below: stays off")

	# --- The same run tick for tick, interpolated or not
	var off := await _run(false)
	var on := await _run(true)
	_check(off.ticks.size() == 240 and off.ticks[-1] != off.ticks[0], "the autopilot run moves the slime (%s -> %s)" % [off.ticks[0], off.ticks[-1]])
	_check(off.ticks == on.ticks, "slime positions are the same every tick with interpolation on")
	_check(off.end == on.end, "timer, meter and trail are the same at the end (%s)" % [off.end])
	_check(on.modes == [Node.PHYSICS_INTERPOLATION_MODE_ON, Node.PHYSICS_INTERPOLATION_MODE_OFF, true, false],
		"the slime opts in; its camera opts out; with interpolation on the camera is pixel-locked (top level, no Camera2D smoothing)")
	_check(on.drawn_ok, "the fog hole and the light sit on the drawn slime, the camera on whole pixels, every frame")
	_check(off.shift_zero, "without interpolation the slime is drawn where it is (no shift)")
	_check(on.reset_ok, "a teleport plus reset_physics_interpolation draws the slime at once where it lands")
	physics_interpolation = false
	transition.follow_frame_rate(1.0 / 60.0)

	_result()
	quit(1 if failures else 0)


func _run(interpolate: bool) -> Dictionary:
	physics_interpolation = interpolate
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	game.add_child(load("res://tests/autopilot.gd").new())
	var check := Checker.new()
	check.game = game
	game.add_child(check)
	var out := {ticks = []}
	for i in 240:
		await physics_frame
		out.ticks.append(game.slime.position)
	await process_frame
	out.drawn_ok = check.drawn_ok and check.frames >= 240
	out.shift_zero = check.shift_zero
	out.end = [game.run_time, game.elapsed, game.slime_remaining, hash(game.trail_image.get_data())]
	out.modes = [game.slime.physics_interpolation_mode, game.camera.physics_interpolation_mode, game.camera.top_level,
		game.camera.position_smoothing_enabled]
	game.slime.position += Vector2(32, 0)
	game.slime.reset_physics_interpolation()
	out.reset_ok = game.slime.drawn_shift() == Vector2.ZERO
	game.free()
	await process_frame
	return out


## Processes after everything else in a frame: checks what is about to be drawn.
class Checker extends Node:
	var game: Node2D
	var frames := 0
	var drawn_ok := true
	var shift_zero := true

	func _ready() -> void:
		process_priority = 1000000

	func _process(_delta: float) -> void:
		frames += 1
		var drawn: Vector2 = game.slime.position + game.slime.sprite.position + game.slime.drawn_shift()
		drawn_ok = drawn_ok and game.slime_light.position == drawn.round() \
			and game.camera.global_position == game.camera.global_position.round()
		shift_zero = shift_zero and game.slime.drawn_shift() == Vector2.ZERO
