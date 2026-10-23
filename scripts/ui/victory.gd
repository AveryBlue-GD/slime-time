extends Control

## Shown after beating level 10: celebration, what was unlocked, and where to go next.

## The text column's width (a wider translated line wraps inside it).
const TEXT_W := 296
## The big slime's centre sits this far under the text block (its line boxes + drip rows): 80 in
## English; its ink ends STAR_INK_BELOW under its centre.
const STAR_BELOW_TEXT := 21
const STAR_INK_BELOW := 11
## The button column: MENU_W wide (wider for a longer translation) at MENU_Y, never past BOTTOM.
const MENU_W := 120
const MENU_Y := 112
const BOTTOM := 176

var buttons: Array[Button] = []


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("victory.title", "YOU ESCAPED!"))  # i18n: max 296px, 16 px font
	# The text block under the title: the clear line, a blank line, the unlock line (wrapped onto two
	# lines when a translation is wider than TEXT_W; a tall script drops the blank line and keeps a
	# GAP_M instead, so the slimes and the menu still fit above the bottom row).
	var cleared := Loc.t("victory.cleared", "ALL {count} MAZES CLEARED", {count = Levels.COUNT})  # i18n: max 296px
	# i18n: {skin} = the custom skin name (see skin.custom), max 296px; wraps onto 2 lines past that, lines 2; the joke is the Henry Ford quote
	var unlocked := Loc.t("victory.unlocked", "UNLOCKED: {skin} (ANY COLOR YOU LIKE)", {skin = Skins.display_name(Skins.CUSTOM)})
	var tall := UIKit.tall_script()
	var lines := UIKit.make_label(Loc.lines([cleared, unlocked] if tall else [cleared, "", unlocked]), UIKit.FONT, UIKit.TEXT)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lines)
	lines.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lines.offset_top = UIKit.title_bottom() + UIKit.GAP_M  # 26 in English
	var count := 0
	for line in [cleared, unlocked]:
		count += 1 if UIKit.text_w(line) <= TEXT_W else UIKit.wrapped_lines(line, TEXT_W)  # (text_w: no RIDs in English)
	if count > 2:  # (wraps inside the TEXT_W column, centred)
		lines.autowrap_mode = UIKit.autowrap_mode()
		lines.offset_left = (UIKit.SCREEN.x - TEXT_W) / 2.0
		lines.offset_right = -lines.offset_left
	var block_h := UIKit.text_block_h(count + (0 if tall else 1))
	lines.offset_bottom = lines.offset_top + block_h
	var texts := [Loc.t("victory.pick_color", "PICK YOUR COLOR"), Loc.t("victory.randomizer", "RANDOMIZER"), Loc.t("victory.hub", "HUB")]
	var menu_h := texts.size() * UIKit.button_h() + (texts.size() - 1) * UIKit.GAP_S
	# The slimes 2 rows (drips) + 21 under the block's line boxes (80 in English), the menu at MENU_Y
	# or GAP_XS under the big slime, always ending on the bottom row (row 176).
	var star_y := int(lines.offset_top) + block_h + int(UIKit.metrics().ink_below) + STAR_BELOW_TEXT
	# A tall script's two lines get GAP_M between them (the blank line's place) when that still fits.
	if tall and count == 2 and star_y + UIKit.GAP_M + STAR_INK_BELOW + 1 + UIKit.GAP_XS <= BOTTOM - menu_h:
		lines.add_theme_constant_override("line_spacing", UIKit.line_spacing() + UIKit.GAP_M)
		lines.offset_bottom += UIKit.GAP_M
		star_y += UIKit.GAP_M

	# Every skin hops along, with the new custom color in the middle.
	var colors: Array[Color] = []
	for preset: Dictionary in Skins.PRESETS:
		colors.append(preset.color)
	for i in colors.size():
		var hopper := UIKit.make_slime_preview(colors[i])
		# Five on each side, leaving the middle for the big custom-color slime.
		hopper.position = Vector2(30 + i * 24 if i < 5 else 194 + (i - 5) * 24, star_y + 2)
		hopper.play("celebrate")
		hopper.frame = i % 4
		add_child(hopper)
	var star := UIKit.make_slime_preview(Progress.custom_color, 2)
	star.position = Vector2(160, star_y)
	star.play("celebrate")
	star.modulate = Color(1.3, 1.3, 1.3)
	add_child(star)

	var menu := VBoxContainer.new()
	var menu_w: int = UIKit.tab_widths(texts, MENU_W)[0]  # (one width for the column, from the widest text)
	var menu_y := clampi(maxi(MENU_Y, star_y + STAR_INK_BELOW + 1 + UIKit.GAP_XS), 0, BOTTOM - menu_h)
	menu.position = Vector2(UIKit.center_x(menu_w), menu_y)
	menu.custom_minimum_size = Vector2(menu_w, 0)
	menu.add_theme_constant_override("separation", UIKit.GAP_S)
	add_child(menu)
	buttons = [
		UIKit.make_button(texts[0], func() -> void: _choose_custom()),
		UIKit.make_button(texts[1], func() -> void:
			Progress.start_random()
			UIKit.go(get_tree(), UIKit.GAME_SCENE)),
		UIKit.make_button(texts[2], func() -> void: UIKit.go(get_tree(), UIKit.HUB_SCENE)),
	]
	for button in buttons:
		menu.add_child(button)
		UIKit.note_text_w(button, texts, MENU_W)
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
	Progress.set_jelly(false)  # (the custom color has no jelly version: with jelly on, select_skin refused it)
	Progress.select_skin(Skins.CUSTOM)
	UIKit.go(get_tree(), "res://scenes/skins.tscn")
