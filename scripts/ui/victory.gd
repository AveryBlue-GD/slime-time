extends Control

## Shown after beating level 10: celebration, what was unlocked, and where to go next.

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, "YOU ESCAPED!")
	var lines := UIKit.make_label("ALL %d MAZES CLEARED\n\nUNLOCKED: ANY SKIN YOU WANT" % Levels.COUNT, 8, UIKit.TEXT)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lines)
	lines.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lines.offset_top = 26
	lines.offset_bottom = 56

	# Every skin hops along, with the new custom color in the middle.
	var colors: Array[Color] = []
	for preset: Dictionary in Skins.PRESETS:
		colors.append(preset.color)
	for i in colors.size():
		var hopper := UIKit.make_slime_preview(colors[i])
		# Five on each side, leaving the middle for the big custom-color slime.
		hopper.position = Vector2(30 + i * 24 if i < 5 else 194 + (i - 5) * 24, 82)
		hopper.play("celebrate")
		hopper.frame = i % 4
		add_child(hopper)
	var star := UIKit.make_slime_preview(Progress.custom_color, 2)
	star.position = Vector2(160, 80)
	star.play("celebrate")
	star.modulate = Color(1.3, 1.3, 1.3)
	add_child(star)

	var menu := VBoxContainer.new()
	menu.position = Vector2(100, 112)
	menu.custom_minimum_size = Vector2(120, 0)
	menu.add_theme_constant_override("separation", 3)
	add_child(menu)
	buttons = [
		UIKit.make_button("PICK YOUR COLOR", func() -> void: _choose_custom()),
		UIKit.make_button("RANDOMIZER", func() -> void:
			Progress.start_random()
			UIKit.go(get_tree(), UIKit.GAME_SCENE)),
		UIKit.make_button("TITLE", func() -> void: UIKit.go(get_tree(), UIKit.TITLE_SCENE)),
	]
	for button in buttons:
		menu.add_child(button)
	buttons[0].grab_focus()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("unlock")


func _choose_custom() -> void:
	Progress.select_skin(Skins.CUSTOM)
	UIKit.go(get_tree(), "res://scenes/skins.tscn")
