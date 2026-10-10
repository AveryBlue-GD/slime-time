class_name UIKit
extends RefCounted

## Shared look and helpers for the menu screens (320x180 base resolution, 8 px text).

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

const BG := Color8(26, 28, 44)
const BUTTON := Color8(51, 44, 64)
const BUTTON_HOVER := Color8(86, 108, 134)
const BUTTON_PRESSED := Color8(37, 113, 121)
const BUTTON_DISABLED := Color8(40, 34, 52)
const TEXT := Color8(244, 244, 244)
const TEXT_DIM := Color8(148, 176, 194)
const TEXT_OFF := Color8(86, 108, 134)
const GOLD := Color8(255, 205, 117)


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 8
	theme.set_stylebox("normal", "Button", _box(BUTTON))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_OFF)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("slider", "HSlider", _box(BUTTON))
	theme.set_stylebox("grabber_area", "HSlider", _box(BUTTON_PRESSED))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(BUTTON_HOVER))
	return theme


## Full-screen menu root: theme, background, and a title at the top.
static func setup_screen(root: Control, title: String) -> void:
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	if title != "":
		var label := make_label(title, 16, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.offset_top = 2
		label.offset_bottom = 22


static func make_label(text: String, font_size := 8, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func make_button(text: String, on_press: Callable, min_size := Vector2(0, 13)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.pressed.connect(func() -> void:
		var sfx := button.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -6.0))
	button.pressed.connect(on_press)
	return button


## Bottom-left BACK button that returns to the title.
static func add_back_button(root: Control) -> Button:
	var button := make_button("BACK", func() -> void: go(root.get_tree(), TITLE_SCENE), Vector2(40, 13))
	button.position = Vector2(4, 164)
	root.add_child(button)
	return button


## "VOLUME" label + slider wired to Progress.volume (plays a bubble so you can hear the level).
static func make_volume_slider(width := 90.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := make_label("VOLUME", 8, TEXT_DIM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(width, 10)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	var progress: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Progress")
	slider.value = progress.volume if progress else 0.8
	slider.value_changed.connect(func(value: float) -> void:
		if progress:
			progress.set_volume(value)
		var sfx := slider.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click"))
	row.add_child(slider)
	row.set_meta("slider", slider)
	return row


## Idle slime preview in the given color (2 = double size).
static func make_slime_preview(color: Color, scale := 1) -> AnimatedSprite2D:
	var preview := AnimatedSprite2D.new()
	preview.sprite_frames = Slime.load_sprite_frames()
	preview.material = Skins.make_material(color)
	preview.scale = Vector2(scale, scale)
	preview.play("idle")
	return preview


static func go(tree: SceneTree, scene: String) -> void:
	tree.change_scene_to_file(scene)


static func _box(color: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
		box.draw_center = false
	return box
