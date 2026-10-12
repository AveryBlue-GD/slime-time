extends Node

## Screenshot scenario: a real story win (the slime is dropped on the chalice early), so the
## result shows the globs earned and the medals. Add --coins-all-found style flags as needed.
## ./tools/screenshot.sh --frames 200 --scene res://tests/demo_rewards.tscn --unlock-all --globs=27
const LEVEL := 3

var game: Node2D


func _ready() -> void:
	Progress.start_story(LEVEL)
	Progress.levels_cleared = LEVEL - 1
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = LEVEL
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	await get_tree().create_timer(1.0).timeout
	game.slime.position = game.chalice.position
	queue_free()
