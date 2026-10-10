extends Control

## Grid of the 10 story levels. Locked levels can't be picked; cleared ones are marked.

var level_buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, "LEVEL SELECT")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(42, 34)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	for level in range(1, Levels.COUNT + 1):
		var status := ""
		if level <= Progress.levels_cleared:
			status = "CLEARED"
		elif level > Progress.highest_unlocked:
			status = "LOCKED"
		var button := UIKit.make_button("LV %d\n%s" % [level, status],
			func() -> void: _play(level), Vector2(44, 30))
		button.disabled = level > Progress.highest_unlocked
		grid.add_child(button)
		level_buttons.append(button)
	level_buttons[Progress.current_level - 1].grab_focus()

	var info := UIKit.make_label("CLEAR A LEVEL TO UNLOCK THE NEXT\nEACH CLEAR ALSO UNLOCKS A NEW SKIN", 8, UIKit.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 108)
	info.size = Vector2(320, 24)
	add_child(info)
	UIKit.add_back_button(self)


func _play(level: int) -> void:
	Progress.start_story(level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
