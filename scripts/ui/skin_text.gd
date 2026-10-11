class_name SkinText
extends Node

## Colors text from the equipped skin: titles get a bright version of the skin color, body text a
## pale tint, hints a muted one. Applies to every label in the "skin_text" group (UIKit.make_label
## and the HUD put them there) and to button text and the selected-button outline in
## `theme_owner`'s theme.
## With the rainbow skin the colors keep cycling, offset by each label's position so the rainbow
## sweeps across the screen.

const GROUP := "skin_text"
const ROLE_TITLE := "title"
const ROLE_TEXT := "text"
const ROLE_DIM := "dim"
const RAINBOW_SPEED := 0.2
const BUTTON_COLORS := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]

## Control whose theme's button colors should follow the skin (optional).
var theme_owner: Control
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	recolor.call_deferred()


func _process(delta: float) -> void:
	if _is_rainbow():
		_time += delta
		recolor()


## Re-applies colors (call after the skin changes).
func recolor() -> void:
	var rainbow := _is_rainbow()
	var base := _skin_color()
	for node in get_tree().get_nodes_in_group(GROUP):
		var label := node as Label
		if label == null:
			continue
		var color_base := base
		if rainbow:
			color_base = rainbow_color(_time, label.global_position.x)
		label.add_theme_color_override("font_color", color_for(label.get_meta("role", ROLE_TEXT), color_base))
	# Button and panel frames are goo in the skin's color.
	GooBox.set_goo_color(rainbow_color(_time, 160.0) if rainbow else base)
	if theme_owner and theme_owner.theme:
		var button_base := rainbow_color(_time, 160.0) if rainbow else base
		# Slider fills are goo too.
		for area in ["grabber_area", "grabber_area_highlight"]:
			var fill := theme_owner.theme.get_stylebox(area, "HSlider") as StyleBoxFlat
			if fill:
				fill.bg_color = button_base if area == "grabber_area" else Skins.shades(button_base).light
		for color_name: String in BUTTON_COLORS:
			theme_owner.theme.set_color(color_name, "Button", color_for(ROLE_TEXT, button_base))
			theme_owner.theme.set_color(color_name, "CheckBox", color_for(ROLE_TEXT, button_base))
		# The outline around the selected (focused) button glows in the skin's title color.
		for type in ["Button", "CheckBox"]:
			var focus := theme_owner.theme.get_stylebox("focus", type) as StyleBoxFlat
			if focus:
				focus.border_color = color_for(ROLE_TITLE, button_base)


## Text color for a role, built from a skin color (kept bright enough to read on dark).
static func color_for(role: String, skin: Color) -> Color:
	match role:
		ROLE_TITLE:
			return Color.from_hsv(skin.h, minf(skin.s, 0.75), maxf(skin.v, 0.95))
		ROLE_DIM:
			return Color.from_hsv(skin.h, skin.s * 0.35, 0.72)
		_:
			return Color.from_hsv(skin.h, skin.s * 0.3, 0.97)


static func rainbow_color(time: float, x: float) -> Color:
	return Color.from_hsv(fposmod(time * RAINBOW_SPEED + x / 640.0, 1.0) * 0.83, 0.75, 1.0)


func _skin_color() -> Color:
	var progress := get_node_or_null("/root/Progress")
	return progress.skin_color() if progress else Skins.get_preset(Skins.DEFAULT).color


func _is_rainbow() -> bool:
	var progress := get_node_or_null("/root/Progress")
	return progress != null and progress.is_rainbow()
