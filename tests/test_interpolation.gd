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

	# --- The switch: on above 72 fps, off below 66 (each held for 0.5 s), kept in between; jitter fix off while on
	_check(not physics_interpolation and root.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
		"off at start, and the scene root opts out (interpolation is opt-in per node)")
	_feed(144, 0.3)
	_check(not physics_interpolation, "144 Hz frames for 0.3 s: not on yet (the switch waits 0.5 s)")
	_feed(144, 0.5)
	_check(physics_interpolation and Engine.physics_jitter_fix == 0.0, "144 Hz frames: on, no jitter fix")
	_feed(69, 1.0)
	_check(physics_interpolation, "69 Hz (between the thresholds): stays on")
	_feed(60, 1.0)
	_check(not physics_interpolation and Engine.physics_jitter_fix == 0.5, "60 Hz frames: off again, the default jitter fix back")
	_feed(69, 1.0)
	_check(not physics_interpolation, "69 Hz from below: stays off")

	# --- Hitches and slowdowns (QA phase 4, finding 2): a single long frame never flips the switch; a lasting
	# change flips it once. Each case starts settled at its refresh rate.
	for hz: int in [75, 90, 120, 144, 240]:
		var flips := 0
		for hitch: float in [0.032, 0.052, 0.077, 0.089, 0.114, 0.25]:
			_settle(hz)
			flips += _feed(hz, 0.4) + _feed_frames([hitch]) + _feed(hz, 1.0)
			_settle(hz)
			flips += _feed_frames([hitch, 1.0 / hz, hitch]) + _feed(hz, 1.0)  # two hitches close together
		_check(flips == 0, "%d Hz: single hitches of 32-250 ms never switch interpolation off (%d switches)" % [hz, flips])
		_settle(hz)
		var short := _feed(40, 0.3) + _feed(hz, 1.0)
		_settle(hz)
		var down := _feed(40, 2.0)
		var off_after_slowdown := not physics_interpolation
		var up := _feed(hz, 2.0)
		_check(short == 0 and down == 1 and off_after_slowdown and up == 1 and physics_interpolation,
			"%d Hz: a 0.3 s dip to 40 fps keeps it on (%d); a lasting one turns it off once (%d), its end on once (%d)" % [hz, short, down, up])
		_settle(hz)
		var crawl := _feed(12, 2.0)  # frames over the hitch length, for good: the game runs that slowly now
		_check(crawl == 1 and not physics_interpolation, "%d Hz -> 12 fps for good: off, once (%d)" % [hz, crawl])
	_settle(60)
	var jitter := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 36000:  # 10 minutes at 60 Hz: jitter, bursty pairs, hitches
		var frame := 1.0 / 60.0 + rng.randf_range(-0.003, 0.003)
		if i % 97 == 0:
			jitter += _feed_frames([0.008, 0.025])
		elif i % 1201 == 0:
			jitter += _feed_frames([rng.randf_range(0.03, 0.2)])
		else:
			jitter += _feed_frames([frame])
	_check(jitter == 0 and not physics_interpolation, "60 Hz, 10 minutes of jitter, bursty pairs and hitches: never switches (%d)" % jitter)

	# --- A switch mid-level carries the eased camera across (no snap onto the slime)
	var jumps := await _switch_run()
	_check(jumps.switches == 2 and jumps.at_switch <= jumps.elsewhere + 1.0,
		"switching off and on mid-glide: the camera eases on (worst change of its step %.1f px at a switch, %.1f px elsewhere)" % [jumps.at_switch, jumps.elsewhere])

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
	_settle(60)

	_result()
	quit(1 if failures else 0)


## Feeds `seconds` of frames at `hz` to the switch; returns how many times it flipped.
func _feed(hz: float, seconds: float) -> int:
	var frames: Array = []
	frames.resize(roundi(seconds * hz))
	frames.fill(1.0 / hz)
	return _feed_frames(frames)


func _feed_frames(frames: Array) -> int:
	var flips := 0
	for frame: float in frames:
		var was := physics_interpolation
		transition.follow_frame_rate(frame)
		flips += int(physics_interpolation != was)
	return flips


## Runs at `hz` until the switch has settled (on above 72 Hz, off at 60).
func _settle(hz: float) -> void:
	_feed(hz, 3.0)


## Level 1 on autopilot with interpolation on, then off and on again through the switch (sustained
## 40 fps, then 144 again) while the camera eases behind the gliding slime. Returns the worst change of
## the camera's per-frame step (px) on the frames right after each switch, and elsewhere.
func _switch_run() -> Dictionary:
	_settle(144)
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	game.add_child(load("res://tests/autopilot.gd").new())
	var out := {switches = 0, at_switch = 0.0, elsewhere = 0.0}
	var centers: Array[Vector2] = []
	var near := {}
	for i in 240:
		var hz := 40 if i >= 60 and i < 150 else 144
		var flips := _feed_frames([1.0 / hz])
		if flips:
			out.switches += flips
			for k in 3:
				near[centers.size() + k] = true
		await process_frame
		centers.append(game.camera.get_screen_center_position() - game.camera.offset)
	for i in range(2, centers.size()):
		var change := ((centers[i] - centers[i - 1]) - (centers[i - 1] - centers[i - 2])).length()
		if near.has(i) or near.has(i - 1):
			out.at_switch = maxf(out.at_switch, change)
		elif i > 20:
			out.elsewhere = maxf(out.elsewhere, change)
	game.free()
	_settle(60)
	await process_frame
	return out


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
