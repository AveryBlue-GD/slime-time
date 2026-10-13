extends SceneTree

## Touch control checks with simulated finger events: the joystick glides the slime and snaps to
## 8 directions (with a dead zone), the jump button charges and launches, the pause button
## pauses, a keyboard hides the controls, and the rotate hint shows only for upright touchscreens.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_touch.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
const RotateHint := preload("res://scripts/ui/rotate_hint.gd")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = "user://test_save.cfg"
	progress.force_touch = true
	progress.levels_cleared = 1
	progress.skin_notices_seen.clear()

	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	current_scene = game
	await physics_frame
	var touch: TouchControls = game.get_node("TouchControls")
	_check(touch.visible, "touch controls show (forced on for the test)")

	# Joystick: put a thumb down on the left, drag toward an open corridor.
	var open_dir := StartDirs.open_dir(game.maze, game.maze.start)
	var drag := Vector2(open_dir) * 16.0
	var action := StartDirs.action(open_dir)
	var start: Vector2 = game.slime.position
	_touch(0, Vector2(50, 130), true)
	_drag(0, Vector2(50, 130) + drag)
	await _frames(2)
	_check(Input.is_action_pressed(action) and _pressed_moves() == 1, "dragging the joystick presses %s only" % action)
	await _frames(30)
	_check(game.slime.position.distance_to(start) > 8.0, "the slime glides (%.0f px)" % game.slime.position.distance_to(start))
	_drag(0, Vector2(50, 130) + Vector2(15, 14))
	await _frames(1)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down"), "a diagonal drag snaps to a diagonal")
	_drag(0, Vector2(50, 130) + Vector2(4, 4))
	await _frames(1)
	_check(_pressed_moves() == 0, "a tiny wiggle inside the dead zone does nothing")
	_drag(0, Vector2(50, 130) + Vector2(16, 3))
	await _frames(1)
	_check(Input.is_action_pressed("move_right") and _pressed_moves() == 1, "slightly-off drags snap to a straight line (lane assist keeps working)")
	_touch(0, Vector2(66, 133), false)
	await _frames(1)
	_check(_pressed_moves() == 0, "lifting the thumb stops the slime")

	# Jump: hold on the right half, then let go.
	await _frames(40)
	_touch(1, Vector2(282, 142), true)
	await _frames(30)
	_check(game.slime.state == Slime.State.CHARGING, "holding JUMP charges (%.0f%%)" % game.slime.charge)
	_touch(1, Vector2(282, 142), false)
	await _frames(2)
	_check(game.slime.is_airborne() or game.slime.state == Slime.State.STUNNED or game.slime.state == Slime.State.GLIDE and game.slime.last_jump_traveled > 0.0,
		"releasing JUMP leaps")
	await _frames(60)

	# Pause button.
	_touch(2, Vector2(309, 41), true)
	await process_frame
	await process_frame
	_check(paused and game.pause_menu.visible, "the pause button opens the pause menu")
	game.pause_menu.resume()
	_touch(2, Vector2(309, 41), false)

	# A keyboard hides the touch controls.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_check(not touch.visible, "using a keyboard hides the touch controls")
	key.pressed = false
	Input.parse_input_event(key)
	current_scene = null
	game.free()

	_check(RotateHint.should_show(Vector2i(390, 844), true) and not RotateHint.should_show(Vector2i(844, 390), true)
		and not RotateHint.should_show(Vector2i(390, 844), false), "rotate hint: only for upright touchscreens")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


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


func _pressed_moves() -> int:
	var count := 0
	for action in TouchControls.MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			count += 1
	return count


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
