extends Node

## Shows one story card for screenshots:
## ./tools/screenshot.sh --frames 70 --scene res://tests/demo_story.tscn --story=intro:3
## (--story=finale:1 for the finale; the card number counts from 0.)


func _ready() -> void:
	var which := "intro"
	var card := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--story="):
			var parts := arg.trim_prefix("--story=").split(":")
			which = parts[0]
			card = int(parts[1]) if parts.size() > 1 else 0
	Story.mode = which
	var screen: Control = preload("res://scenes/story.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.show_card(card)
