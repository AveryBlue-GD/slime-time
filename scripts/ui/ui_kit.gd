class_name UIKit
extends RefCounted

## Shared look and helpers for the menu screens (320x180 base resolution, 8 px text).

## The title screen (the main scene), and the hub every BACK leads to.
const TITLE_SCENE := "res://scenes/title.tscn"
const HUB_SCENE := "res://scenes/hub.tscn"
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
## Space between lines of text (the 2 px drips below each line + a 3 px gap).
const LINE_SPACING := 5
## Pixel-art UI pieces from tools/make_ui_art.py.
const UI_DIR := "res://assets/ui/"

static var _text_material: ShaderMaterial


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 8
	# Beveled nine-slice buttons: hovering lifts the text 1 px, pressing pushes it down 1 px.
	theme.set_stylebox("normal", "Button", button_style("normal"))
	theme.set_stylebox("hover", "Button", button_style("hover"))
	theme.set_stylebox("pressed", "Button", button_style("pressed"))
	theme.set_stylebox("hover_pressed", "Button", button_style("pressed"))
	theme.set_stylebox("disabled", "Button", button_style("disabled"))
	theme.set_stylebox("focus", "Button", _focus_box())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_OFF)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "CheckBox", TEXT)
	theme.set_stylebox("focus", "CheckBox", _focus_box())
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	theme.set_icon("unchecked", "CheckBox", load(UI_DIR + "check_off.png"))
	theme.set_icon("checked", "CheckBox", load(UI_DIR + "check_on.png"))
	theme.set_constant("h_separation", "CheckBox", 4)
	theme.set_color("font_color", "Label", TEXT)
	# The font's line box is only the 7 px letter body (the drips hang below it), so lines are
	# spaced by the drips' 2 px plus the usual gap.
	theme.set_constant("line_spacing", "Label", LINE_SPACING)
	# A 1 px drop shadow keeps text readable over the drifting backdrop.
	theme.set_color("font_shadow_color", "Label", Color(BG, 0.9))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	var track := _box(Color8(30, 26, 40), Color8(26, 28, 44))
	track.draw_center = true
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(BUTTON_PRESSED))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(Color8(56, 183, 100)))
	theme.set_icon("grabber", "HSlider", load(UI_DIR + "grabber.png"))
	theme.set_icon("grabber_highlight", "HSlider", load(UI_DIR + "grabber_hover.png"))
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	return theme


## A goo-framed button ("normal", "hover", "pressed" or "disabled"; see GooBox). Hover brightens
## the goo and pressing darkens the face; the text never moves, so it stays clear of the goo.
static func button_style(state: String) -> StyleBox:
	return GooBox.make_button(state)


## The goo-framed panel behind groups of buttons and messages (`hud` = the plain, lighter HUD pod).
static func panel_style(hud := false) -> StyleBox:
	if not hud:
		var goo := GooBox.make_panel()
		goo.content_margin_top = 6  # below the goo band and its lumps
		goo.content_margin_bottom = 5
		return goo
	var box := StyleBoxTexture.new()
	box.texture = load(UI_DIR + "hud_pod.png")
	var margin := 3
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


## Adds a framed panel covering `rect` (drawn behind whatever is added after it).
static func add_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


## An 8x8 UI icon ("drop", "clock", "lock", "check").
static func make_icon(icon_name: String, tint := TEXT) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(UI_DIR + "icon_%s.png" % icon_name)
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


## Full-screen menu root: theme, the drifting maze backdrop, a title at the top, and skin-colored
## text.
## Returns the SkinText node (call its recolor() after changing the skin).
static func setup_screen(root: Control, title: String) -> SkinText:
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(MenuBackdrop.new())
	if title != "":
		var label := make_label(title, 16, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.offset_top = 2
		label.offset_bottom = 22
		label.add_theme_color_override("font_shadow_color", Color(BG, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 2)
	return add_skin_text(root)


## Adds a SkinText node so labels and the root's button text follow the equipped skin's color.
static func add_skin_text(root: Control) -> SkinText:
	var skin_text := SkinText.new()
	skin_text.theme_owner = root
	root.add_child(skin_text)
	return skin_text


static func make_label(text: String, font_size := 8, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.material = text_material()
	use_big_font(label, font_size)
	# The standard UI colors stand for roles that SkinText recolors from the equipped skin.
	var role: String = {GOLD: SkinText.ROLE_TITLE, TEXT: SkinText.ROLE_TEXT, TEXT_DIM: SkinText.ROLE_DIM}.get(color, "")
	if role != "":
		label.set_meta("role", role)
		label.add_to_group(SkinText.GROUP)
	return label


## 16 px text uses the 2x font, whose letter gaps are split evenly so centered titles sit exactly
## on center (the 8 px font, scaled up, would put them a pixel right).
static func use_big_font(control: Control, font_size: int) -> void:
	if font_size == 16:
		control.add_theme_font_override("font", load("res://assets/fonts/pixel_big.fnt"))


## Shared material for text: every letter gets its own random goo drips (text_drips.gdshader).
static func text_material() -> ShaderMaterial:
	if _text_material == null:
		_text_material = ShaderMaterial.new()
		_text_material.shader = load("res://assets/shaders/text_drips.gdshader")
	return _text_material


static func make_button(text: String, on_press: Callable, min_size := Vector2(0, 13)) -> Button:
	var button := Button.new()
	button.text = text
	button.material = text_material()
	button.custom_minimum_size = min_size
	button.pressed.connect(func() -> void:
		var sfx := button.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -6.0))
	button.pressed.connect(on_press)
	return button


## Bottom-left BACK button that returns to the title.
static func add_back_button(root: Control) -> Button:
	var button := make_button("BACK", func() -> void: go(root.get_tree(), HUB_SCENE), Vector2(40, 13))
	button.position = Vector2(4, 164)
	root.add_child(button)
	return button


## "VOLUME" label + slider wired to Progress.volume (plays a bubble so you can hear the level),
## inside a goo-framed box like a button's (the slider is the box's "slider" meta).
static func make_volume_slider(width := 90.0) -> PanelContainer:
	var box := PanelContainer.new()
	var style := GooBox.make_button("normal")
	style.content_margin_top = 2  # the 10 px slider fills the face between the goo bands
	style.content_margin_bottom = 1
	style.content_margin_left = 6  # clear of the goo at the sides
	style.content_margin_right = 6
	box.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	box.add_child(row)
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
	box.set_meta("slider", slider)
	return box


## Idle slime preview in the given color (2 = double size).
static func make_slime_preview(color: Color, scale := 1, rainbow := false, jelly: Variant = null) -> AnimatedSprite2D:
	var preview := AnimatedSprite2D.new()
	preview.sprite_frames = Slime.load_sprite_frames()
	preview.material = Skins.make_material(color, rainbow)
	if jelly != null:
		(preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if jelly else 0.0)
	preview.scale = Vector2(scale, scale)
	preview.play("idle")
	return preview


## Run time as m:ss.s (e.g. 1:02.3).
static func format_time(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


## Changes screens behind a goo wipe (instantly when the Transition autoload isn't there).
static func go(tree: SceneTree, scene: String) -> void:
	var transition := tree.root.get_node_or_null("Transition")
	if transition:
		transition.go(scene)
	else:
		tree.change_scene_to_file(scene)


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0), GOLD)
	box.set_expand_margin_all(1)
	return box


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
