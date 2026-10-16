class_name HeatPanel
extends Control

## The level select's HEAT panel (hard mode, upgrades v2 batch 4; Heat): six modifier toggles in a
## 3 x 2 grid (a code-drawn icon, the short name and its heat as a flame and +N), the running total
## (HEAT n/10) at the top, a line about the focused modifier and DONE. A toggle saves at once
## (Progress.set_heat_mods). BRITTLE is greyed out while GROUNDED is on (switching GROUNDED on drops
## it). Opened over the screen with the rest of it focus-locked (UIKit.lock_focus); DONE, Esc or
## a click outside the panel close it and give the focus back to the HEAT button.
## Other languages (docs/ui-rules.md section 10): when a name, the line or DONE doesn't fit the
## English toggles, or the lines are taller, the panel takes the screen's width (EDGE each side) and the
## height its lines need (centred), the toggles grow to 96 px (names that still don't fit: the script's
## smaller size, else two lines) and their rows follow the line heights; the screen behind is hidden
## while it is open (the English panel lies exactly over the tiles; a resized one would show them through
## at odd places). English keeps RECT / TOGGLE.

signal closed

## The title PANEL_PAD under the top edge, DONE PANEL_PAD over the bottom edge (docs/ui-rules.md).
const RECT := Rect2(22, 20, 276, 138)
const TOGGLE := Vector2i(84, 34)
const GAP := 4
const GRID_Y := 39
const ABOUT_Y := 119
const DONE_Y := 137
## The title's flame and text are centered as one group: the flame, then this gap, then the text ink.
const TITLE_GAP := 5
const ICON_SCALE := 2
const OFF_TINT := Color(0.55, 0.55, 0.62)
## The name's left edge in a toggle (after the 2x icon's 18 px cell, at x ICON_X) and the room kept
## right of it; the +N after the flame. The locale layout moves the icon and text 1 / 2 px left (the
## name GAP_XS after the icon) for 2 more px of name.
const ICON_X := 5
const NAME_X := 26
const NAME_PAD := 4
const POINTS_X := 35
const SHIFT_X := 2
const LevelSelect := preload("res://scripts/ui/level_select.gd")
const MapSelect := preload("res://scripts/ui/map_select.gd")
const HEAT_TINT := Color8(255, 170, 90)

var toggles := {}
var title: Label
var title_flame: TextureRect
var about: Label
var done_button: Button
var _saved_focus := {}
var _return_focus: Control
## The panel's frame and the toggles' size: RECT / TOGGLE with the English layout.
var rect := RECT
var toggle_size := Vector2(TOGGLE)
## True with the English layout (see _fits_english).
var english := true
## The locale layout's numbers (see _geometry).
var _geo := {}
## The screen's controls hidden while the resized panel is open.
var _hidden: Array[CanvasItem] = []


static func default_about() -> String:
	# i18n: the line under the toggles, max 224px (the English panel); grows to 296px (the wider panel), wraps onto 2 lines there, lines 2
	return Loc.t("heat.about_default", "WORKS ON LEVELS ALREADY BEATEN ON HARD")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the screen under it takes no clicks
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	english = _fits_english()
	_geo = _geometry()
	rect = _geo.rect
	toggle_size = _geo.toggle
	UIKit.add_panel(self, rect)

	title_flame = Heat.make_rect(Heat.flame(0))
	add_child(title_flame)
	title = UIKit.make_label("", UIKit.FONT, UIKit.GOLD)
	add_child(title)
	title.position = Vector2(rect.position.x, _geo.title_y)

	var left := rect.position.x + floorf((rect.size.x - (toggle_size.x * 3 + GAP * 2)) / 2.0)
	for i in Heat.IDS.size():
		var id: String = Heat.IDS[i]
		var button := _make_toggle(id)
		button.position = Vector2(left + (i % 3) * (toggle_size.x + GAP), _geo.grid_y + (i / 3) * (toggle_size.y + GAP))
		add_child(button)
		toggles[id] = button
		if _geo.name_lines > 1:  # (sized once in the themed tree: sized before, it keeps the default font's width)
			UIKit.wrap_label(button.get_node("Name"), Vector2(toggle_size.x - _geo.name_x - NAME_PAD, UIKit.text_block_h(2)))

	about = UIKit.make_label(default_about(), UIKit.FONT, UIKit.TEXT_DIM)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if english:
		about.clip_text = true  # (keeps the label at the panel's width: the text centers on the panel)
		about.position = Vector2(RECT.position.x, ABOUT_Y)
		about.size = Vector2(RECT.size.x, 9)
		add_child(about)
	else:  # every modifier's line fits (two lines where one is too long): nothing is clipped
		add_child(about)
		if _geo.about_lines > 1:
			about.autowrap_mode = UIKit.autowrap_mode()
		about.position = Vector2(rect.position.x + UIKit.PANEL_PAD, _geo.about_y)
		about.size = Vector2(rect.size.x - 2 * UIKit.PANEL_PAD, UIKit.text_block_h(_geo.about_lines))

	# i18n: max 42px (50 wide, 4 px margins), 1 line
	var done_text := Loc.t("heat.done", "DONE")
	var done_w := UIKit.button_w(done_text, 50)
	done_button = UIKit.make_button(done_text, close, Vector2(done_w, UIKit.button_h()))
	UIKit.note_text_w(done_button, [done_text], 50)
	done_button.position = Vector2(roundf(rect.get_center().x - done_w / 2.0), _geo.done_y)
	done_button.focus_entered.connect(func() -> void: about.text = default_about())
	add_child(done_button)
	refresh()


## True when the English panel holds this locale's texts: 7 px lines, 13 px buttons, every name within
## a toggle, every line within the panel, DONE within its 50 px.
static func _fits_english() -> bool:
	if UIKit.line_h() != UIKit.TEXT_BODY or UIKit.button_h() != UIKit.BUTTON_H:
		return false
	for id in Heat.IDS:
		if UIKit.text_w(Heat.display_name(id)) > TOGGLE.x - NAME_X - NAME_PAD:
			return false
	for text in about_texts():
		if UIKit.text_w(text) > RECT.size.x:
			return false
	return UIKit.button_w(Loc.t("heat.done", "DONE"), 50) == 50


## Every line the about label shows (the default, then each modifier's).
static func about_texts() -> Array[String]:
	var out: Array[String] = [default_about()]
	for id in Heat.IDS:
		out.append(Heat.about_text(id))
	return out


## The layout: {rect, toggle, title_y, grid_y, about_y, about_lines, done_y, icon_x, name_x, name_y,
## name_lines, name_font, points_y}. English: RECT, TOGGLE, GRID_Y, ABOUT_Y, DONE_Y. Otherwise the same
## rhythm from the locale's line heights: the title PANEL_PAD under the top, the toggles 4 under the
## title's line, the about line 8 under them, DONE GAP_L (+ the drips) under it, PANEL_PAD under DONE;
## the panel EDGE from the screen's sides and centred.
func _geometry() -> Dictionary:
	var g := {rect = RECT, toggle = Vector2(TOGGLE), title_y = RECT.position.y + UIKit.PANEL_PAD, grid_y = GRID_Y,
		about_y = ABOUT_Y, about_lines = 1, done_y = DONE_Y, icon_x = ICON_X, name_x = NAME_X, name_y = 7, name_lines = 1,
		name_font = null, points_y = 20, icon_scale = ICON_SCALE}
	if english:
		return g
	var tall := UIKit.tall_script()
	var lh := UIKit.line_h()
	var width := UIKit.SCREEN.x - 2 * UIKit.EDGE
	var toggle_w := floorf((width - 2 * UIKit.PANEL_PAD - 2 * GAP) / 3.0)
	g.icon_x = ICON_X - SHIFT_X / 2
	g.name_x = NAME_X - SHIFT_X
	var room: float = toggle_w - g.name_x - NAME_PAD
	# The names: one line; else the script's smaller size (Devanagari); else the icons at 1x, which leaves the
	# name 9 px more (Arabic: no smaller size, and two-line names would make the panel taller than the
	# screen); else two lines.
	var name_h := lh
	var widest := 0
	for id in Heat.IDS:
		widest = maxi(widest, UIKit.text_w(Heat.display_name(id)))
	var language_node := get_tree().root.get_node_or_null("Language")
	var has_small: bool = language_node != null and language_node.has_method("small_font") and language_node.small_font(UIKit.locale()) != null
	var name_x_1x: int = g.icon_x + 9 + (g.name_x - g.icon_x - 9 * ICON_SCALE)
	if widest > room and not has_small and widest <= toggle_w - name_x_1x - NAME_PAD:
		g.icon_scale = 1
		g.name_x = name_x_1x
		room = toggle_w - g.name_x - NAME_PAD
	if widest > room:
		var language := get_tree().root.get_node_or_null("Language")
		var small: Font = language.small_font(UIKit.locale()) if language and language.has_method("small_font") else null
		var small_widest := 0
		if small:
			for id in Heat.IDS:
				small_widest = maxi(small_widest, UIKit.text_w(Heat.display_name(id), UIKit.FONT, small))
		if small and small_widest <= room:
			g.name_font = small
			name_h = ceili(small.get_height(UIKit.FONT))
		else:
			g.name_lines = 2
			name_h = UIKit.text_block_h(2)
	g.name_y = 4 if tall else 7
	g.points_y = g.name_y + name_h + (2 if tall else 6)
	g.toggle = Vector2(toggle_w, g.points_y + 14)
	var about_lines := 1
	for text in about_texts():
		if UIKit.text_w(text) > width - 2 * UIKit.PANEL_PAD:
			about_lines = 2
	g.about_lines = about_lines
	# Top to bottom from 0, then centred.
	var title_y := UIKit.PANEL_PAD
	var grid_y := title_y + lh + 4
	var about_y := grid_y + 2 * int(g.toggle.y) + GAP + UIKit.GAP_L
	var done_y := about_y + UIKit.text_block_h(about_lines) + UIKit.GAP_L + (0 if tall else UIKit.TEXT_DRIP + 1)
	var h := done_y + UIKit.button_h() + UIKit.PANEL_PAD
	var top := maxi(UIKit.HUD_EDGE - 1, floori((UIKit.SCREEN.y - h) / 2.0))
	g.rect = Rect2(UIKit.EDGE, top, width, h)
	g.title_y = top + title_y
	g.grid_y = top + grid_y
	g.about_y = top + about_y
	g.done_y = top + done_y
	return g


## A modifier's toggle: its icon at 2x on the left, the name, and its heat (a flame + "+N") under it.
func _make_toggle(id: String) -> Button:
	var button := UIKit.make_button("", func() -> void: _flip(id), toggle_size)
	button.name = "Toggle_" + id
	button.size = toggle_size
	var icon := Heat.make_rect(Heat.icon(id))
	icon.name = "Icon"
	var scale: int = _geo.icon_scale
	icon.scale = Vector2(scale, scale)
	# Centered in an 18x18 cell (9x9 at 1x; RACE's art is 8x8, the others 9x9), the cell centred on the toggle's height.
	var cell := Vector2(9, 9) - Vector2(icon.texture.get_size())
	icon.position = Vector2(_geo.icon_x, floorf((toggle_size.y - 9.0 * scale) / 2.0)) + (cell * scale / 2.0).floor()
	button.add_child(icon)
	var name_label := UIKit.make_label(Heat.display_name(id), UIKit.FONT, UIKit.TEXT)
	name_label.name = "Name"
	name_label.position = Vector2(_geo.name_x, _geo.name_y)
	button.add_child(name_label)
	if _geo.name_font:
		name_label.add_theme_font_override("font", _geo.name_font)
	var flame := Heat.make_rect(Heat.flame(Economy.HEAT_TIERS[0]))
	flame.name = "Flame"
	flame.position = Vector2(_geo.name_x, _geo.points_y - 1)
	button.add_child(flame)
	var points := UIKit.make_label(Loc.t("heat.points", "+{points}", {points = Heat.heat_of(id)}), UIKit.FONT, HEAT_TINT)
	points.name = "Points"
	points.position = Vector2(_geo.name_x + POINTS_X - NAME_X, _geo.points_y)
	button.add_child(points)
	UIKit.use_plain_font(points)
	var check := UIKit.make_icon("check", UIKit.GOLD)
	check.name = "Check"
	check.position = Vector2(toggle_size.x - 13, toggle_size.y - 13)
	button.add_child(check)
	button.focus_entered.connect(func() -> void: about.text = Heat.about_text(id))
	button.mouse_entered.connect(func() -> void: about.text = Heat.about_text(id))
	return button


func _flip(id: String) -> void:
	var mask: int = Progress.heat_mods
	if Heat.blocked(mask, id):
		return
	Progress.set_heat_mods(Heat.toggle(mask, id))
	about.text = Heat.about_text(id)
	refresh()


## Redraws every toggle from Progress.heat_mods (on: full color + a check; off: greyed; BRITTLE
## disabled while GROUNDED is on) and the total.
func refresh() -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	var mask: int = Progress.heat_mods
	for id: String in toggles:
		var button: Button = toggles[id]
		var on := Heat.has(mask, id)
		button.disabled = Heat.blocked(mask, id)
		button.get_node("Check").visible = on
		var tint := Color.WHITE if on else OFF_TINT
		if button.disabled:
			tint = Color(OFF_TINT, 0.45)
		button.get_node("Icon").modulate = tint
		button.get_node("Flame").modulate = tint
		button.get_node("Name").modulate = tint
		button.get_node("Points").modulate = tint
	var heat := Heat.points(mask)
	# i18n: panel title; {points} = current heat, {max} = the top; max 120px, 1 line (a flame icon sits to its left)
	title.text = Loc.t("heat.title", "HEAT {points}/{max}", {points = heat, max = Economy.HEAT_MAX})
	title_flame.texture = Heat.flame(heat)
	# Flame + gap + text ink centered on the panel as one group (the label's ink starts 1 px in).
	var width: float = title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var flame_w := float(Heat.flame_size().x)
	var group := flame_w + TITLE_GAP + width - 1.0
	var left := UIKit.center_x(group, rect.position.x, rect.size.x)
	title_flame.position = Vector2(left, _geo.title_y - 1 + (UIKit.line_h() - UIKit.TEXT_BODY) / 2)
	title.position.x = left + flame_w + TITLE_GAP - 1.0
	title.size = Vector2(width, 9 if english else UIKit.line_h() + (0 if UIKit.tall_script() else UIKit.TEXT_DRIP))


## Opens the panel over `screen` (its other controls stop taking focus); `return_to` gets the focus
## back on close.
func open(screen: Control, return_to: Control) -> void:
	_return_focus = return_to
	refresh()
	visible = true
	_saved_focus = UIKit.lock_focus(screen, self)
	if not english:  # the resized panel: the screen behind is hidden (its title, tiles, lines, buttons)
		_hidden = UIKit.cover_behind(screen, [self])
	toggles[Heat.IDS[0]].grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	UIKit.uncover(_hidden)
	UIKit.unlock_focus(_saved_focus)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	# A click or tap outside the panel closes it.
	if event is InputEventMouseButton and event.pressed and not rect.has_point(event.position):
		accept_event()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
