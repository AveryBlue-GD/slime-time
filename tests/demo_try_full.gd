extends Node

## Screenshot scenarios for the demo's top ability row and TRY THE FULL GAME (owner, 2026-10-23), with `--shot=`:
##   row   the FULL GAME PREVIEW maze on touch, the ability tutorial on its first line (the others dimmed)
##   aim   the same, SLIME SNIPER's button held and dragged right: its aim guide (touch aiming)
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
		"row", "aim":
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
	if shot in ["row", "aim"] and _frame == 3:
		game._close_preview_card()
	elif shot == "aim" and _frame == 300:
		var tc: TouchControls = game.touch_controls
		_touch(tc, tc.slot_center(0), true)
		_drag(tc, tc.slot_center(0) + Vector2(40, 0))
	elif shot == "win" and _frame == 3:
		game._on_goal_body_entered(game.slime)


func _touch(tc: TouchControls, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = pos
	event.pressed = pressed
	tc._input(event)


func _drag(tc: TouchControls, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 2
	event.position = pos
	tc._input(event)
