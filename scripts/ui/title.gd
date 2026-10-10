extends Control

## Start page: the big gooey logo (tinted to the equipped skin), then continue, level select,
## randomizer, skins, controls, quit.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, "")
	# The logo is drawn in the slime sheet's goo shades, so the skin shader recolors it too.
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/sprites/title.png")
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	(logo.material as ShaderMaterial).set_shader_parameter("rainbow_width", LOGO_RAINBOW_WIDTH)
	logo.position = Vector2(roundf((320 - logo.texture.get_width()) / 2.0), 2)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	for x in [52, 268]:
		var preview := UIKit.make_slime_preview(Progress.skin_color(), 2, Progress.is_rainbow())
		preview.position = Vector2(x, 118)
		add_child(preview)

	var menu := VBoxContainer.new()
	menu.position = Vector2(100, 76)
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
