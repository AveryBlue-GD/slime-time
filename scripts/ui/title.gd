extends Control

## Start page: the big gooey logo (tinted to the equipped skin), then continue, level select,
## randomizer, skins + upgrades, (locked, with a lock icon, until all story levels are beaten), skins, controls, quit.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0
## The menu panel: buttons 13 px tall, 2 px apart, inside the goo frame's padding, centered in
## the 101 px between the logo and the tagline.
const BUTTON_HEIGHT := 13
const MENU_GAP := 2
const PANEL_PAD_TOP := 6
const PANEL_PAD_BOTTOM := 7
const MENU_AREA_TOP := 68
const MENU_AREA_HEIGHT := 101

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, "")
	# The logo is drawn in the slime sheet's goo shades, so the skin shader recolors it too.
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/sprites/title.png")
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	(logo.material as ShaderMaterial).set_shader_parameter("rainbow_width", LOGO_RAINBOW_WIDTH)
	(logo.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)  # the logo stays solid
	logo.position = Vector2(roundf((320 - logo.texture.get_width()) / 2.0), 2)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	for x in [52, 268]:
		var preview := UIKit.make_slime_preview(Progress.skin_color(), 2, Progress.is_rainbow())
		preview.position = Vector2(x, 118)
		add_child(preview)
		if Progress.selected_hat != Hats.NONE:  # the hat you're wearing, at the same 2x size
			var hat := Hat.new()
			hat.scale = preview.scale
			add_child(hat)
			hat.setup(Progress.selected_hat, preview)

	var panel := UIKit.add_panel(self, Rect2(92, 68, 136, 101))  # fitted to the rows below
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(120, 0)
	menu.add_theme_constant_override("separation", MENU_GAP)  # room for each button's goo drops
	add_child(menu)

	var fresh: bool = Progress.levels_cleared == 0 and Progress.current_level == 1
	var play_text := "NEW GAME" if fresh else "CONTINUE - LEVEL %d" % Progress.current_level
	buttons = [
		UIKit.make_button(play_text, _on_play),
		UIKit.make_button("LEVEL SELECT", func() -> void: UIKit.go(get_tree(), "res://scenes/level_select.tscn")),
		UIKit.make_button("RANDOMIZER", _on_randomizer),
		UIKit.make_button("SKINS", func() -> void: UIKit.go(get_tree(), "res://scenes/skins.tscn")),
		UIKit.make_button("UPGRADES", func() -> void: UIKit.go(get_tree(), "res://scenes/upgrades.tscn")),
		UIKit.make_button("SETTINGS", func() -> void: UIKit.go(get_tree(), "res://scenes/controls.tscn")),
		UIKit.make_button("QUIT", func() -> void: get_tree().quit()),
	]
	# SKINS and UPGRADES share a row, so the menu stays the same height.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 2)  # two equal halves of the menu's width
	for button in buttons:
		if button == buttons[3] or button == buttons[4]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(button)
			if button == buttons[3]:
				menu.add_child(pair)
		else:
			menu.add_child(button)
	# In a browser (phones included) QUIT would just leave a dead page; --web-ui previews that.
	if OS.has_feature("web") or "--web-ui" in OS.get_cmdline_user_args():
		buttons[-1].hide()
	_fit_menu(panel, menu)
	if not Progress.is_randomizer_unlocked():
		var random_button := buttons[2]
		random_button.disabled = true
		random_button.icon = load(UIKit.UI_DIR + "icon_lock.png")
		random_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		random_button.tooltip_text = "BEAT ALL %d LEVELS TO UNLOCK" % Levels.COUNT
		random_button.add_theme_color_override("icon_disabled_color", UIKit.TEXT_OFF)
	buttons[0].grab_focus()

	var hint := UIKit.make_label("ESCAPE THE FOG OR DRY TRYING!", 8, UIKit.TEXT_DIM)  # the tagline
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)  # centered under the menu
	hint.offset_top = 172
	hint.offset_bottom = 180


## Sizes the panel to the rows actually shown (5 without QUIT on the web, else 6) and centers it
## in the space between the logo and the tagline, so there's no empty gap at the bottom.
func _fit_menu(panel: Panel, menu: VBoxContainer) -> void:
	var rows := 0
	for row in menu.get_children():
		if row.visible:
			rows += 1
	var menu_height := rows * BUTTON_HEIGHT + (rows - 1) * MENU_GAP
	var panel_height := menu_height + PANEL_PAD_TOP + PANEL_PAD_BOTTOM
	panel.size.y = panel_height
	panel.position.y = MENU_AREA_TOP + roundi((MENU_AREA_HEIGHT - panel_height) / 2.0)
	menu.position = Vector2(100, panel.position.y + PANEL_PAD_TOP)


func _on_play() -> void:
	Progress.start_story(Progress.current_level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _on_randomizer() -> void:
	Progress.start_random()
	UIKit.go(get_tree(), UIKit.GAME_SCENE)
