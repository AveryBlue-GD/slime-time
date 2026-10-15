extends "res://tests/suite_base.gd"

## Level 1's wordless cues react to the slime, not to the input device: the d-pad / WASD glyph
## and the JUMP / SPACE key fade the same way (same frames) after a move or a leap made with the
## keyboard or with the touch controls (real InputEventScreenTouch / ScreenDrag events through
## TouchControls, as on a phone), with the controls shown from the start (--touch / web UI) or
## only after the first touch; the screen is really cleared once a fade ends (one last redraw),
## the chalice beacon too, even when a long frame (a phone browser's hitch on the first glide) lands mid-fade, and both
## cues are stored in tutorial_seen. Nothing is written to disk.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_touch_cues.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
## Frames allowed for a full fade (1 / FADE_SPEED s = 20 frames) plus the first move and the redraw.
const FADE_FRAMES := 26

var progress: Node
var game: Node2D
var cues: TutorialCues


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = false

	var timings := {}
	for force_touch: bool in [false, true]:
		for device: String in ["keys", "touch"]:
			var mode := "%s, %s" % [device, "--touch UI" if force_touch else "normal UI"]
			timings[mode] = await _run(device, force_touch, mode)
	for force_touch: bool in [false, true]:
		var ui := "--touch UI" if force_touch else "normal UI"
		var keys: Vector2i = timings["keys, " + ui]
		var touch: Vector2i = timings["touch, " + ui]
		_check(keys == touch and keys.x > 0 and keys.y > 0,
			"%s: touch fades the move/jump cues in the same frames as keys (%s vs %s)" % [ui, touch, keys])

	for device: String in ["keys", "touch"]:
		await _beacon_case(device)
	await _hitch_case()
	_result()
	quit(1 if failures else 0)


## One fresh level 1: move, then leap, with one device. Returns the frames each glyph took to be
## gone from the screen (move, leap).
func _run(device: String, force_touch: bool, mode: String) -> Vector2i:
	await _start_level(force_touch)
	await _physics_frames(30)
	_check(cues.move_alpha > 0.3 and cues.drawn_alpha > 0.3, "%s: the move glyph shows on a fresh save" % mode)
	if force_touch:
		_check(cues._touch(), "%s: as a d-pad (touch controls up)" % mode)

	var dir := StartDirs.open_dir(game.maze, game.maze.start)
	var start: Vector2 = game.slime.position
	if device == "touch":
		_touch(0, Vector2(50, 130), true)
		_drag(0, Vector2(50, 130) + Vector2(dir) * 16.0)
	else:
		_key(StartDirs.action(dir), true)
	var move_frames := await _until_cleared(func() -> bool: return cues.move_alpha == 0.0)
	_check(game.slime.position.distance_to(start) > 4.0, "%s: the slime glided" % mode)
	_check(move_frames > 0, "%s: the move glyph faded and was cleared off the screen (%d frames)" % [mode, move_frames])
	_check(progress.has_seen_tutorial(Progress.TUTORIAL_MOVE), "%s: the move cue is stored as seen" % mode)
	if device == "touch":
		_touch(0, Vector2(66, 130), false)
		_check(game.touch_controls.visible, "%s: a touch brings the controls up" % mode)
	else:
		_key(StartDirs.action(dir), false)

	# Wandered without leaping and paused: the JUMP / SPACE key shows; one tap of JUMP fades it.
	await _physics_frames(30)
	cues.wandered = TutorialCues.WANDER_FOR_LEAP + 10.0
	cues.idle = TutorialCues.LEAP_PAUSE + 1.0
	await _physics_frames(30)
	_check(cues.leap_alpha > 0.3 and cues.drawn_alpha > 0.3, "%s: the jump key shows after wandering" % mode)
	if device == "touch":
		_touch(1, TouchControls.JUMP_CENTER, true)
	else:
		_key("jump", true)
	await _physics_frames(3)
	_check(game.slime.state == Slime.State.CHARGING, "%s: JUMP starts a charge" % mode)
	if device == "touch":
		_touch(1, TouchControls.JUMP_CENTER, false)
	else:
		_key("jump", false)
	var leap_frames := await _until_cleared(func() -> bool: return cues.leap_alpha == 0.0)
	_check(leap_frames > 0, "%s: the jump key faded and was cleared off the screen (%d frames)" % [mode, leap_frames + 3])
	_check(progress.has_seen_tutorial(Progress.TUTORIAL_LEAP), "%s: the leap cue is stored as seen" % mode)
	_check(int(progress._write().get_value("progress", "tutorial_seen", 0)) == Progress.TUTORIAL_MOVE | Progress.TUTORIAL_LEAP,
		"%s: the save written next carries both cues" % mode)
	await _end_level()
	return Vector2i(move_frames, leap_frames + 3)


## The chalice beacon (after standing still) goes on a move by either device and is cleared too.
func _beacon_case(device: String) -> void:
	await _start_level(device == "touch", Progress.TUTORIAL_MOVE | Progress.TUTORIAL_LEAP)
	await _physics_frames(10)
	cues.idle = TutorialCues.IDLE_FOR_BEACON + 1.0
	await _physics_frames(60)
	_check(cues.beacon_alpha > 0.3 and cues.drawn_alpha > 0.3, "beacon, %s: shows after standing still" % device)
	var dir := StartDirs.open_dir(game.maze, game.maze.start)
	if device == "touch":
		_touch(0, Vector2(50, 130), true)
		_drag(0, Vector2(50, 130) + Vector2(dir) * 16.0)
	else:
		_key(StartDirs.action(dir), true)
	var frames := await _until_cleared(func() -> bool: return cues.beacon_alpha == 0.0)
	_check(frames > 0, "beacon, %s: a move fades it and it is cleared off the screen (%d frames)" % [device, frames])
	if device == "touch":
		_touch(0, Vector2(50, 130), false)
	else:
		_key(StartDirs.action(dir), false)
	await _end_level()


## A long frame right after the first touch move must not skip the fade or leave the glyph drawn.
func _hitch_case() -> void:
	await _start_level(true)
	await _physics_frames(30)
	var dir := StartDirs.open_dir(game.maze, game.maze.start)
	_touch(0, Vector2(50, 130), true)
	_drag(0, Vector2(50, 130) + Vector2(dir) * 16.0)
	for i in 10:
		await physics_frame
		if cues._moved:
			break
	cues._process(0.5)  # a half-second stall, as on a phone browser's first glide
	_check(cues.move_alpha > 0.8, "a long frame doesn't skip the fade (alpha %.2f after it)" % cues.move_alpha)
	var frames := await _until_cleared(func() -> bool: return cues.move_alpha == 0.0)
	_check(frames > 0, "after a long frame the glyph still fades out and is cleared (%d frames)" % frames)
	await _physics_frames(20)
	_check(cues.drawn_alpha == 0.0, "nothing is left drawn")
	_touch(0, Vector2(50, 130), false)
	await _end_level()


func _start_level(force_touch: bool, seen := 0) -> void:
	progress.force_touch = force_touch
	progress.levels_cleared = 0
	progress.randoms_won = 0
	progress.tutorial_seen = seen
	progress.dry_ups = {}
	progress.start_story(1)
	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	current_scene = game
	await physics_frame
	cues = null
	for child in game.slime.get_children():
		if child is TutorialCues:
			cues = child
	if cues == null:
		_check(false, "level 1 has the teaching cues")
		quit(1)


func _end_level() -> void:
	current_scene = null
	game.free()
	await _physics_frames(2)


## Physics frames until `faded` holds and the last drawn frame shows nothing (0 = never).
func _until_cleared(faded: Callable) -> int:
	for i in FADE_FRAMES * 2 + 30:  # (the beacon fades at half speed)
		await physics_frame
		if faded.call() and cues.drawn_alpha == 0.0:
			return i + 1
	return 0


func _key(action: String, pressed: bool) -> void:
	for bound in InputMap.action_get_events(action):
		if bound is InputEventKey:
			var event := InputEventKey.new()
			event.physical_keycode = bound.physical_keycode
			event.keycode = bound.keycode
			event.pressed = pressed
			Input.parse_input_event(event)
			return


## Touch events arrive in window pixels; convert from the game's 320x180 view.
func _to_window(view_pos: Vector2) -> Vector2:
	return root.get_final_transform() * view_pos


func _touch(index: int, view_pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _to_window(view_pos)
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, view_pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _to_window(view_pos)
	Input.parse_input_event(event)


