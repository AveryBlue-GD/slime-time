extends Node

## Screenshot scenarios for the demo's top ability row and TRY THE FULL GAME (owner, 2026-10-23), with `--shot=`:
##   row   the FULL GAME PREVIEW maze on touch, the ability tutorial on its first line (the others dimmed)
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
		"row":
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
	if shot == "row" and _frame == 3:
		game._close_preview_card()
	elif shot == "win" and _frame == 3:
		game._on_goal_body_entered(game.slime)
