extends Node

## Screenshot scenario: a first launch of a fresh save: the launch trailer, skipped with Esc,
## wiping into the title (PLAY). Never saves.
## ./tools/screenshot.sh --frames 150 --scene res://tests/demo_launch.tscn

func _ready() -> void:
	Progress.saving_enabled = false
	Progress.dev_tools = false
	Progress.levels_cleared = 0
	Progress.story_seen = 0
	Story.launched = false
	var helper := Node.new()  # outlives this scene
	helper.set_script(preload("res://tests/demo_launch_helper.gd"))
	get_tree().root.add_child.call_deferred(helper)
	get_tree().change_scene_to_file.call_deferred(UIKit.TITLE_SCENE)
