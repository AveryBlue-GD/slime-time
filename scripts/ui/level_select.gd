extends Control

## Grid of the 10 story levels (locked ones can't be picked; cleared ones are marked), plus the
## hard mode checkbox: in hard mode, explored areas that fully dim are swallowed by fog again.

var level_buttons: Array[Button] = []
var hard_mode_box: CheckBox


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
		if Progress.best_time(level) >= 0.0:
			status = UIKit.format_time(Progress.best_time(level))
		elif level <= Progress.levels_cleared:
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
	add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_top = 106
	info.offset_bottom = 128

	hard_mode_box = CheckBox.new()
	hard_mode_box.text = "HARD MODE - FOG RETURNS WHEN AREAS FULLY DIM"
	hard_mode_box.button_pressed = Progress.hard_mode
	hard_mode_box.toggled.connect(func(on: bool) -> void: Progress.set_hard_mode(on))
	hard_mode_box.position = Vector2(26, 136)
	add_child(hard_mode_box)
	UIKit.add_back_button(self)


func _play(level: int) -> void:
	Progress.start_story(level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
