extends Node

## Plays the story for screenshots and movies (never saves):
## ./tools/screenshot.sh --frames 70 --scene res://tests/demo_story.tscn --skin=lime --story=intro:3
## ./tools/godot.sh --path . --write-movie /tmp/story.avi --fixed-fps 30 --quit-after 800 res://tests/demo_story.tscn -- --skin=lime --story=intro
## --story=intro (or finale) plays the whole sequence from the first shot; intro:3 starts at shot 3
## (counting from 0) and plays on; --calm shows the Reduce Motion stills. Quits when it ends.


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.reduce_motion = false
	var which := "intro"
	var card := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--story="):
			var parts := arg.trim_prefix("--story=").split(":")
			which = parts[0]
			card = int(parts[1]) if parts.size() > 1 else 0
		elif arg == "--calm":
			Progress.reduce_motion = true
	Story.mode = which
	var screen: Control = preload("res://scenes/story.tscn").instantiate()
	screen.leave_on_finish = false
	screen.done.connect(func() -> void: get_tree().quit())
	add_child(screen)
	if Engine.get_write_movie_path() != "":
		screen.set_process_unhandled_input(false)  # a recording ignores stray keys and clicks
	if card > 0:
		screen.show_card(card)
