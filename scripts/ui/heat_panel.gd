class_name HeatPanel
extends Control

## The level select's HEAT panel (hard mode, upgrades v2 batch 4; Heat): six modifier toggles in a
## 3 x 2 grid (a code-drawn icon, the short name and its heat as a flame and +N), the running total
## (HEAT n/10) at the top, a line about the focused modifier and DONE. A toggle saves at once
## (Progress.set_heat_mods). BRITTLE is greyed out while GROUNDED is on (switching GROUNDED on drops
## it). Opened over the screen with the rest of it focus-locked (UIKit.lock_focus); DONE, Esc or
## a click outside the panel close it and give the focus back to the HEAT button.

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
const HEAT_TINT := Color8(255, 170, 90)
const DEFAULT_ABOUT := "WORKS ON LEVELS ALREADY BEATEN ON HARD"

var toggles := {}
var title: Label
var title_flame: TextureRect
var about: Label
var done_button: Button
var _saved_focus := {}
var _return_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the screen under it takes no clicks
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	UIKit.add_panel(self, RECT)

	title_flame = Heat.make_rect(Heat.flame(0))
	add_child(title_flame)
	title = UIKit.make_label("", 8, UIKit.GOLD)
	add_child(title)
	title.position = Vector2(RECT.position.x, RECT.position.y + UIKit.PANEL_PAD)

	var left := RECT.position.x + floorf((RECT.size.x - (TOGGLE.x * 3 + GAP * 2)) / 2.0)
	for i in Heat.IDS.size():
		var id: String = Heat.IDS[i]
		var button := _make_toggle(id)
		button.position = Vector2(left + (i % 3) * (TOGGLE.x + GAP), GRID_Y + (i / 3) * (TOGGLE.y + GAP))
		add_child(button)
		toggles[id] = button

	about = UIKit.make_label(DEFAULT_ABOUT, 8, UIKit.TEXT_DIM)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.clip_text = true  # (keeps the label at the panel's width: the text centers on the panel)
	about.position = Vector2(RECT.position.x, ABOUT_Y)
	about.size = Vector2(RECT.size.x, 9)
	add_child(about)

	done_button = UIKit.make_button("DONE", close, Vector2(50, 13))
	done_button.position = Vector2(roundf(RECT.get_center().x - 25.0), DONE_Y)
	done_button.focus_entered.connect(func() -> void: about.text = DEFAULT_ABOUT)
	add_child(done_button)
	refresh()


## A modifier's toggle: its icon at 2x on the left, the name, and its heat (a flame + "+N") under it.
func _make_toggle(id: String) -> Button:
	var button := UIKit.make_button("", func() -> void: _flip(id), Vector2(TOGGLE))
	button.name = "Toggle_" + id
	button.size = Vector2(TOGGLE)
	var icon := Heat.make_rect(Heat.icon(id))
	icon.name = "Icon"
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	# Centered in an 18x18 cell (RACE's art is 8x8, the others 9x9).
	var cell := Vector2(9, 9) - Vector2(icon.texture.get_size())
	icon.position = Vector2(5, 8) + (cell * ICON_SCALE / 2.0).floor()
	button.add_child(icon)
	var name_label := UIKit.make_label(Heat.NAMES[id], 8, UIKit.TEXT)
	name_label.name = "Name"
	name_label.position = Vector2(26, 7)
	button.add_child(name_label)
	var flame := Heat.make_rect(Heat.flame(Economy.HEAT_TIERS[0]))
	flame.name = "Flame"
	flame.position = Vector2(26, 19)
	button.add_child(flame)
	var points := UIKit.make_label("+%d" % Heat.heat_of(id), 8, HEAT_TINT)
	points.name = "Points"
	points.position = Vector2(35, 20)
	button.add_child(points)
	var check := UIKit.make_icon("check", UIKit.GOLD)
	check.name = "Check"
	check.position = Vector2(TOGGLE.x - 13, TOGGLE.y - 13)
	button.add_child(check)
	button.focus_entered.connect(func() -> void: about.text = Heat.ABOUT[id])
	button.mouse_entered.connect(func() -> void: about.text = Heat.ABOUT[id])
	return button


func _flip(id: String) -> void:
	var mask: int = Progress.heat_mods
	if Heat.blocked(mask, id):
		return
	Progress.set_heat_mods(Heat.toggle(mask, id))
	about.text = Heat.ABOUT[id]
	refresh()


## Redraws every toggle from Progress.heat_mods (on: full color + a check; off: greyed; BRITTLE
## disabled while GROUNDED is on) and the total.
func refresh() -> void:
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
	title.text = "HEAT %d/%d" % [heat, Economy.HEAT_MAX]
	title_flame.texture = Heat.flame(heat)
	# Flame + gap + text ink centered on the panel as one group (the label's ink starts 1 px in).
	var width: float = title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var flame_w := float(Heat.flame_size().x)
	var group := flame_w + TITLE_GAP + width - 1.0
	var left := UIKit.center_x(group, RECT.position.x, RECT.size.x)
	title_flame.position = Vector2(left, RECT.position.y + UIKit.PANEL_PAD - 1)
	title.position.x = left + flame_w + TITLE_GAP - 1.0
	title.size = Vector2(width, 9)


## Opens the panel over `screen` (its other controls stop taking focus); `return_to` gets the focus
## back on close.
func open(screen: Control, return_to: Control) -> void:
	_return_focus = return_to
	refresh()
	visible = true
	_saved_focus = UIKit.lock_focus(screen, self)
	toggles[Heat.IDS[0]].grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	UIKit.unlock_focus(_saved_focus)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	# A click or tap outside the panel closes it.
	if event is InputEventMouseButton and event.pressed and not RECT.has_point(event.position):
		accept_event()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
