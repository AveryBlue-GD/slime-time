extends Node

## Screenshot scenarios for the demo's top ability row and TRY THE FULL GAME (owner, 2026-10-23), with `--shot=`:
##   row   the FULL GAME PREVIEW maze on touch, the ability tutorial on its first line (the others dimmed)
##   aim   the same, SLIME SNIPER's button tapped and the joystick aimed right: its aim guide, JUMP's gold ring (touch
##         aiming: JUMP fires it); --frames 315 catches the ring's on phase
##   cancel  the same, then JUMP held and dragged onto the X beside it (lit: letting go there calls the aim off)
##   win   level 4's chalice: TRY THE FULL GAME (focused) beside CONTINUE
##   end   the END OF THE DEMO screen with TRY THE FULL GAME
## ./tools/screenshot.sh --frames 200 --scene res://tests/demo_try_full.tscn --demo --touch --shot=row

var shot := "row"
var game: Node2D
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	Progress.saving_enabled = false
	Progress.tutorial_seen = 3
	Progress.story_seen |= Progress.STORY_INTRO
	Progress.levels_cleared = Demo.LEVELS - 1
	Progress.highest_unlocked = Demo.LEVELS
	match shot:
		"row", "aim", "cancel":
			Progress.levels_cleared = Demo.LEVELS
			Progress.start_random()
		"end":
			Progress.levels_cleared = Demo.LEVELS
			add_child(load(DemoEnd.SCENE).instantiate())
			return
		_:
			Progress.start_story(Demo.LEVELS)
	game = load(UIKit.GAME_SCENE).instantiate()
	_become.call_deferred()


## The game is the current scene (its result row only shows for the running scene).
func _become() -> void:
	get_tree().root.add_child(game)
	get_tree().current_scene = game


func _physics_process(_delta: float) -> void:
	_frame += 1
	if game == null:
		return
	if shot in ["row", "aim", "cancel"] and _frame == 3:
		game._close_preview_card()
	elif shot in ["aim", "cancel"] and _frame == 300:
		var tc: TouchControls = game.touch_controls
		_touch(tc, tc.slot_center(0), true)
		_touch(tc, tc.slot_center(0), false)
		Input.action_press("move_right")
	elif shot in ["aim", "cancel"] and _frame == 306:
		Input.action_release("move_right")
	elif shot == "cancel" and _frame == 310:
		var tc: TouchControls = game.touch_controls
		_touch(tc, TouchControls.JUMP_CENTER, true, 3)
		var drag := InputEventScreenDrag.new()
		drag.index = 3
		drag.position = tc.cancel_center()
		tc._input(drag)
	elif shot == "win" and _frame == 3:
		game._on_goal_body_entered(game.slime)


func _touch(tc: TouchControls, pos: Vector2, pressed: bool, index := 2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	tc._input(event)

