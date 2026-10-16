extends Control

## Shown after beating level 10: celebration, what was unlocked, and where to go next.

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("victory.title", "YOU ESCAPED!"))  # i18n: max 296px, 16 px font
	var lines := UIKit.make_label(Loc.lines([
		Loc.t("victory.cleared", "ALL {count} MAZES CLEARED", {count = Levels.COUNT}),  # i18n: max 296px
		"",
		# i18n: {skin} = the custom skin name (see skin.custom), max 296px; the joke is the Henry Ford quote
		Loc.t("victory.unlocked", "UNLOCKED: {skin} (ANY COLOR YOU LIKE)", {skin = Skins.display_name(Skins.CUSTOM)}),
	]), UIKit.FONT, UIKit.TEXT)
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
	menu.add_theme_constant_override("separation", UIKit.GAP_S)
	add_child(menu)
	buttons = [
		UIKit.make_button(Loc.t("victory.pick_color", "PICK YOUR COLOR"), func() -> void: _choose_custom()),
		UIKit.make_button(Loc.t("victory.randomizer", "RANDOMIZER"), func() -> void:
			Progress.start_random()
			UIKit.go(get_tree(), UIKit.GAME_SCENE)),
		UIKit.make_button(Loc.t("victory.hub", "HUB"), func() -> void: UIKit.go(get_tree(), UIKit.HUB_SCENE)),
	]
	for button in buttons:
		menu.add_child(button)
	buttons[0].grab_focus()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("unlock")


## Esc / P / B (menu, ui_cancel) go back to the hub, like every other screen's BACK.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UIKit.go(get_tree(), UIKit.HUB_SCENE)


func _choose_custom() -> void:
	Progress.select_skin(Skins.CUSTOM)
	UIKit.go(get_tree(), "res://scenes/skins.tscn")
