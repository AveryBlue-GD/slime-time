extends Control

## Start page: continue, level select, randomizer, skins, controls, quit.

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, "SLIME TIME")
	var preview := UIKit.make_slime_preview(Progress.skin_color(), 2)
	preview.position = Vector2(160, 42)
	add_child(preview)

	var menu := VBoxContainer.new()
	menu.position = Vector2(100, 66)
	menu.custom_minimum_size = Vector2(120, 0)
	menu.add_theme_constant_override("separation", 2)
	add_child(menu)

	var fresh: bool = Progress.levels_cleared == 0 and Progress.current_level == 1
	var play_text := "NEW GAME" if fresh else "CONTINUE - LEVEL %d" % Progress.current_level
	buttons = [
		UIKit.make_button(play_text, _on_play),
		UIKit.make_button("LEVEL SELECT", func() -> void: UIKit.go(get_tree(), "res://scenes/level_select.tscn")),
		UIKit.make_button("RANDOMIZER", _on_randomizer),
		UIKit.make_button("SKINS", func() -> void: UIKit.go(get_tree(), "res://scenes/skins.tscn")),
		UIKit.make_button("CONTROLS", func() -> void: UIKit.go(get_tree(), "res://scenes/controls.tscn")),
		UIKit.make_button("QUIT", func() -> void: get_tree().quit()),
	]
	for button in buttons:
		menu.add_child(button)
	buttons[0].grab_focus()

	var hint := UIKit.make_label("%d/%d LEVELS CLEARED" % [Progress.levels_cleared, Levels.COUNT], 8, UIKit.TEXT_DIM)
	hint.position = Vector2(4, 168)
	add_child(hint)


func _on_play() -> void:
	Progress.start_story(Progress.current_level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _on_randomizer() -> void:
	Progress.start_random()
	UIKit.go(get_tree(), UIKit.GAME_SCENE)
