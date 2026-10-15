extends "res://tests/suite_base.gd"

## Touch control checks with simulated finger events: the joystick glides the slime and snaps to
## 8 directions (with a dead zone), the jump button charges and launches, the pause button
## pauses, a keyboard hides the controls, and the rotate hint shows only for upright touchscreens.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_touch.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
const RotateHint := preload("res://scripts/ui/rotate_hint.gd")

var progress: Node


var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
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
	_send_touch(0, Vector2(50, 130), true)
	_send_drag(0, Vector2(50, 130) + drag)
	await _physics_frames(2)
	_check(Input.is_action_pressed(action) and _pressed_moves() == 1, "dragging the joystick presses %s only" % action)
	await _physics_frames(30)
	_check(game.slime.position.distance_to(start) > 8.0, "the slime glides (%.0f px)" % game.slime.position.distance_to(start))
	_send_drag(0, Vector2(50, 130) + Vector2(15, 14))
	await _physics_frames(1)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down"), "a diagonal drag snaps to a diagonal")
	_send_drag(0, Vector2(50, 130) + Vector2(4, 4))
	await _physics_frames(1)
	_check(_pressed_moves() == 0, "a tiny wiggle inside the dead zone does nothing")
	_send_drag(0, Vector2(50, 130) + Vector2(16, 3))
	await _physics_frames(1)
	_check(Input.is_action_pressed("move_right") and _pressed_moves() == 1, "slightly-off drags snap to a straight line (lane assist keeps working)")
	_send_touch(0, Vector2(66, 133), false)
	await _physics_frames(1)
	_check(_pressed_moves() == 0, "lifting the thumb stops the slime")

	# Jump: hold on the right half, then let go.
	await _physics_frames(40)
	_send_touch(1, Vector2(282, 142), true)
	await _physics_frames(30)
	_check(game.slime.state == Slime.State.CHARGING, "holding JUMP charges (%.0f%%)" % game.slime.charge)
	_send_touch(1, Vector2(282, 142), false)
	await _physics_frames(2)
	_check(game.slime.is_airborne() or game.slime.state == Slime.State.STUNNED or game.slime.state == Slime.State.GLIDE and game.slime.last_jump_traveled > 0.0,
		"releasing JUMP leaps")
	await _physics_frames(60)

	# Pause button.
	_send_touch(2, Vector2(309, 41), true)
	await process_frame
	await process_frame
	_check(paused and game.pause_menu.visible, "the pause button opens the pause menu")
	game.pause_menu.resume()
	_send_touch(2, Vector2(309, 41), false)

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

	# The cover pauses the game under it and puts the pause state back (web QA pass).
	var hint: CanvasLayer = root.get_node("RotateHint")
	var holder := Node.new()
	root.add_child(holder)
	current_scene = holder
	paused = false
	hint.set_shown(true)
	_check(hint.visible and paused, "rotate hint: covering pauses the game")
	await process_frame
	paused = false  # e.g. a goo wipe finishing under the cover
	await process_frame
	await process_frame
	_check(paused, "rotate hint: stays paused while covering")
	hint.set_shown(false)
	_check(not hint.visible and not paused, "rotate hint: turning sideways resumes a running game")
	paused = true  # the pause menu was open
	hint.set_shown(true)
	hint.set_shown(false)
	_check(paused, "rotate hint: an open pause menu stays paused")
	hint.set_shown(true)
	var other := Node.new()
	root.add_child(other)
	current_scene = other
	hint.set_shown(false)
	_check(not paused, "rotate hint: a screen that changed under the cover starts unpaused")
	current_scene = null
	other.free()
	holder.free()
	paused = false

	await _hat_wheel_taps()
	_result()
	quit(1 if failures else 0)


## Audit H4: on a touchscreen, a tap anywhere on the hat wheel overlay (the right half was JUMP, and JUMP used to
## spin) never takes a paid spin; only the SPIN button does. The overlay has a BACK button on touch.
func _hat_wheel_taps() -> void:
	progress.enable_story_complete()
	progress.force_touch = true
	progress.saving_enabled = false
	progress.tickets = 200
	progress.spins = 4  # paid spins now
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	hub.open_hat_wheel()
	await _physics_frames(2)
	var wheel = hub.hat_wheel  # (untyped: HatWheel compiles only once the autoloads exist)
	_check(wheel.visible and wheel.tab == "wheel" and wheel.close_button.visible, "touch: the hat wheel opens with a BACK button")
	_check(hub._touch_controls.menu_open, "touch: the touch controls stand down under the overlay")
	var tickets: int = progress.tickets
	var spins: int = progress.spins
	for at: Vector2 in [Vector2(250, 100), Vector2(290, 150), Vector2(170, 90), Vector2(300, 60), Vector2(230, 140)]:
		_send_touch(0, at, true)
		await _physics_frames(3)
		_send_touch(0, at, false)
		await _physics_frames(3)
	_check(progress.tickets == tickets and progress.spins == spins and not wheel.spinning,
		"touch: taps on the wheel's right half never spin (tickets %d -> %d)" % [tickets, progress.tickets])
	_check(not Input.is_action_pressed("jump"), "touch: no JUMP held under the overlay")
	var back_at: Vector2 = wheel.close_button.get_global_rect().get_center()
	_send_touch(0, back_at, true)
	await _physics_frames(2)
	_send_touch(0, back_at, false)
	await _physics_frames(3)
	_check(not wheel.visible and not hub._touch_controls.menu_open and progress.tickets == tickets, "touch: BACK closes the overlay, nothing spent")
	current_scene = null
	hub.free()
	progress.force_touch = false
	await process_frame


func _pressed_moves() -> int:
	var count := 0
	for action in TouchControls.MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			count += 1
	return count


