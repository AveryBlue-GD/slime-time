class_name UIKit
extends RefCounted

## Shared look and helpers for the menu screens (320x180 base resolution, 8 px text).

## The title screen (the main scene), and the hub every BACK leads to.
const TITLE_SCENE := "res://scenes/title.tscn"
const HUB_SCENE := "res://scenes/hub.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

const BG := Color8(26, 28, 44)
const BUTTON := Color8(51, 44, 64)
const BUTTON_PRESSED := Color8(37, 113, 121)
const TEXT := Color8(244, 244, 244)
const TEXT_DIM := Color8(148, 176, 194)
const TEXT_OFF := Color8(86, 108, 134)
const GOLD := Color8(255, 205, 117)
## Space between lines of text (the 2 px drips below each line + a 3 px gap).
const LINE_SPACING := 5

# ---- Layout rules (docs/ui-rules.md). Base pixels at 320x180; use these instead of literals. ----
const SCREEN := Vector2(320, 180)
## Menu chrome (BACK, tabs, corner buttons, balance pods) sits this far from the screen edges.
const EDGE := 4
## In-level HUD pods and the hub's ticket pod sit this far from the edges (HUD.POD_MARGIN); on a phone whose
## safe area cuts into the view (rounded corners, a notch without bars) further in: see hud_edge.
const HUD_EDGE := 3
## Top of the bottom-row buttons (BACK bottom left, the page's own action bottom right): 13 tall, B = 3.
const BOTTOM_ROW_Y := 164
## Screen titles (16 px font): the line box (0, TITLE_Y)..(320, TITLE_Y + 20).
const TITLE_Y := 2
## Font sizes: text and titles (titles use pixel_big.fnt, see use_big_font).
const FONT := 8
const FONT_BIG := 16
## The 8 px font's letter body and the drips that hang below it (the 16 px font doubles both).
const TEXT_BODY := 7
const TEXT_DRIP := 2
## Line pitch of multi-line text (7 + LINE_SPACING); dense lists (coin board, map tiles) use 11.
const LINE_PITCH := 12
const DENSE_PITCH := 11
## The spacing scale: every gap is one of these.
const GAP_XS := 2  # dense tiles, header items, stacked HUD pods
const GAP_S := 3   # stacked menu buttons (pitch 16), tile grids
const GAP_M := 4   # toggles, tabs, button to box, controls inside one row
const GAP_L := 8   # result choice row, columns, panel side insets
const GAP_XL := 12  # paired confirm buttons, text line pitch
## Component sizes.
const BUTTON_H := 13
const BACK_SIZE := Vector2(40, BUTTON_H)
const CHOICE_SIZE := Vector2(84, BUTTON_H)  # the result / summary choice row...
const CHOICE_GAP := GAP_L             # ...its gap...
const CHOICE_Y := 153                 # ...and its top (also the Descent card's buttons)
const TAB_H := 13
## HUD and hub pods: one line (an 8 px icon sets it) and two lines.
const POD_H := 14
const POD_H2 := 23
## Inside a goo panel: content (text top, first button) starts PANEL_PAD below the panel's top
## edge, and the last button's bottom edge (or the last text line's drips) ends PANEL_PAD above its
## bottom edge, clear of the goo lumps and the buttons' own drops.
const PANEL_PAD := 8
## Touch: a target should be TOUCH_MIN px tall and wide (44 pt at about 2 pt per game px on phones).
## While touch is in use (UIKit.touch_active), a TouchButton's hit area grows by HIT_PAD on every side (13 -> 23), shared
## with its neighbors by distance so hit areas never overlap (see TouchButton).
const TOUCH_MIN := 22
const HIT_PAD := 5
## The group of every control a touch can land on (TouchButtons and the other inputs on screen).
const TOUCH_GROUP := "ui_touch_targets"
## Pixel-art UI pieces from tools/make_ui_art.py.
const UI_DIR := "res://assets/ui/"

## True while the player is using touch: the last pointer event was a screen touch or drag (or the
## mouse event Godot makes from one); a real mouse turns it off. See note_pointer / touch_active.
static var touch_in_use := false
static var _text_material: ShaderMaterial
static var _tabular_font: FontFile
static var _drip_scene := -1


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT
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
	# Text boxes (the save code): a dark inset well, outlined brighter while you type in it.
	var well := _box(Color8(14, 14, 24), Color8(62, 74, 96))
	well.draw_center = true
	well.content_margin_top = 2
	well.content_margin_bottom = 1
	theme.set_stylebox("normal", "LineEdit", well)
	theme.set_stylebox("read_only", "LineEdit", well)
	var focused := well.duplicate() as StyleBoxFlat
	focused.border_color = TEXT_DIM
	theme.set_stylebox("focus", "LineEdit", focused)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_uneditable_color", "LineEdit", TEXT_DIM)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_OFF)
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", Color8(62, 74, 96))
	GooBox.track_theme(theme)
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
	box.content_margin_left = 4  # the frame is two px thick: dark outline + light rim (+ highlight on top)
	box.content_margin_right = 4
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Adds a framed panel covering `rect` (drawn behind whatever is added after it).
static func add_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


## The ticket store's BUY? confirm (hat wheel SHOP, upgrades TICKETS tab), added to `parent`: a dim
## sheet over the whole screen that swallows clicks and taps (so nothing behind the confirm can be
## pressed while it's open; the keyboard is locked by lock_focus) and the panel with its text, a
## price with a ticket icon, and BUY / BACK. Both start hidden. Returns {blocker, panel, label, price,
## buy, back}.
static func add_ticket_confirm(parent: Control, on_buy: Callable, on_back: Callable, price_tint: Color) -> Dictionary:
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.45)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	parent.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := add_panel(parent, Rect2(86, 60, 148, 58))
	panel.visible = false
	var label := make_label("", FONT, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 8)
	label.size = Vector2(148, 10)
	panel.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, 20)
	row.size = Vector2(148, 10)
	panel.add_child(row)
	var price := make_label("", FONT, price_tint)
	row.add_child(price)
	row.add_child(make_icon("ticket", Color.WHITE))
	var buy := make_button("BUY", on_buy, Vector2(48, BUTTON_H))
	buy.position = Vector2(20, 36)
	panel.add_child(buy)
	var back := make_button("BACK", on_back, Vector2(48, BUTTON_H))
	back.position = Vector2(buy.position.x + 48 + GAP_XL, 36)
	panel.add_child(back)
	return {blocker = blocker, panel = panel, label = label, price = price, buy = buy, back = back}


## An 8x8 UI icon ("drop", "clock", "lock", "check").
static func make_icon(icon_name: String, tint := TEXT) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(UI_DIR + "icon_%s.png" % icon_name)
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


## Holds a pod icon bigger than the 8x8 UI icons (the 7x9 HEAT flame, the 9x9 HEAT modifier icons)
## in an 8 px tall cell (its full width), the art centered on the cell's rows and allowed to hang 1 px
## over it, so a pod holding it keeps the standard POD_H height instead of growing to 15.
static func fit_icon(icon: TextureRect) -> Control:
	var art := Vector2(icon.texture.get_size())
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = Vector2(art.x, minf(art.y, 8.0))
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_FILL
	icon.position = Vector2(0, floorf((cell.custom_minimum_size.y - art.y) / 2.0))
	icon.size = art
	cell.add_child(icon)
	return cell


## The bounding box (in icon pixels) of an icon's visible pixels, so it can be centered by its ink
## rather than its 8x8 cell.
static func icon_ink_rect(icon_name: String) -> Rect2i:
	var img: Image = (load(UI_DIR + "icon_%s.png" % icon_name) as Texture2D).get_image()
	var used := img.get_used_rect()
	return used


## Full-screen menu root: theme, the drifting maze backdrop, a title at the top, and skin-colored
## text.
## Returns the SkinText node (call its recolor() after changing the skin).
static func setup_screen(root: Control, title: String) -> SkinText:
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(MenuBackdrop.new())
	if title != "":
		var label := make_label(title, FONT_BIG, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.offset_top = TITLE_Y
		label.offset_bottom = TITLE_Y + 20
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


static func make_label(text: String, font_size := FONT, color := TEXT) -> Label:
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
	if font_size == FONT_BIG:
		control.add_theme_font_override("font", load("res://assets/fonts/pixel_big.fnt"))


## The 8 px font with tabular digits: "1" takes a full digit cell (6 px, its ink centered in it) like
## every other digit, so a running time keeps its width and never jiggles (the HUD timer).
static func tabular_font() -> FontFile:
	if _tabular_font == null:
		var base: FontFile = load("res://assets/fonts/pixel.fnt")
		_tabular_font = base.duplicate(true)
		var size: Vector2i = _tabular_font.get_size_cache_list(0)[0]
		var one := "1".unicode_at(0)
		var zero := "0".unicode_at(0)
		var extra: float = _tabular_font.get_glyph_advance(0, size.x, zero).x - _tabular_font.get_glyph_advance(0, size.x, one).x
		_tabular_font.set_glyph_advance(0, size.x, one, _tabular_font.get_glyph_advance(0, size.x, zero))
		_tabular_font.set_glyph_offset(0, size, one, _tabular_font.get_glyph_offset(0, size, one) + Vector2(floorf(extra / 2.0), 0))
	return _tabular_font


## Shared material for text: every letter gets its own random goo drips (text_drips.gdshader).
static func text_material() -> ShaderMaterial:
	if _text_material == null:
		_text_material = ShaderMaterial.new()
		_text_material.shader = load("res://assets/shaders/text_drips.gdshader")
	# New drips every time a screen opens: a fresh seed the first time text is made in each scene.
	var tree := Engine.get_main_loop() as SceneTree
	var scene_id := tree.current_scene.get_instance_id() if tree and tree.current_scene else 0
	if scene_id != _drip_scene:
		_drip_scene = scene_id
		_text_material.set_shader_parameter("seed", float(randi() % 10000))
	return _text_material


static func make_button(text: String, on_press: Callable, min_size := Vector2(0, BUTTON_H)) -> Button:
	var button := TouchButton.new()
	button.text = text
	button.material = text_material()
	button.custom_minimum_size = min_size
	button.pressed.connect(func() -> void:
		var sfx := button.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -6.0))
	button.pressed.connect(on_press)
	return button


## Bottom-left BACK button that returns to the hub (BACK_SIZE at EDGE, BOTTOM_ROW_Y on every screen).
static func add_back_button(root: Control, on_press := Callable()) -> Button:
	var press := on_press if on_press.is_valid() else func() -> void: go(root.get_tree(), HUB_SCENE)
	var button := make_button("BACK", press, BACK_SIZE)
	root.add_child(button)
	place_bottom_row(button, -1)
	return button


## Puts `control` (sized) on the bottom row: side -1 = left edge, 1 = right edge, 0 = centered.
static func place_bottom_row(control: Control, side: int) -> void:
	var w := control.size.x
	var x := float(EDGE) if side < 0 else (SCREEN.x - EDGE - w if side > 0 else center_x(w))
	control.position = Vector2(x, BOTTOM_ROW_Y)


## The x that centers a box `width` wide on the screen (or in `span` starting at `from`), on a
## whole pixel.
static func center_x(width: float, from := 0.0, span := SCREEN.x) -> float:
	return from + roundf((span - width) / 2.0)


## Adds a label to `parent` FIRST and sizes it after: a label sized before it is in the themed tree
## measures with the default font and keeps that larger minimum size (it then sits off center).
static func add_label(parent: Node, text: String, rect: Rect2, font_size := FONT, color := TEXT,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := make_label(text, font_size, color)
	label.horizontal_alignment = align
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


## Tabs and other one-of-many buttons: the selected one gets its own look (darker, pressed-in face
## and the brighter hover goo) in every state, so hovering another tab never looks like selecting it.
static func set_selected(button: Button, on: bool) -> void:
	if on:
		var style := button_style("selected")
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
	button.set_meta("selected", on)


## True when menus should use touch hit areas: the player is touching the screen (touch_in_use), or
## the --touch debug flag. A desktop that merely has a touchscreen keeps exact hit areas for its mouse.
static func touch_active() -> bool:
	if touch_in_use:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var progress: Node = tree.root.get_node_or_null("Progress") if tree else null
	return progress != null and progress.get("force_touch") == true


## The HUD pods' distance from the screen's sides (x, mirrored) and top (y): HUD_EDGE, or 1 px clear of the
## safe area where it cuts deeper (Platform.safe_insets; never on desktop or the web, so those stay at 3).
static func hud_edge() -> Vector2i:
	var insets := Platform.safe_insets()
	return Vector2i(maxi(HUD_EDGE, maxi(insets.left, insets.right) + 1), maxi(HUD_EDGE, insets.top + 1))


## Tracks touch_in_use from every input event, before any node or the GUI sees it (the RotateHint
## autoload connects it to the root window's window_input). A tap reaches the GUI as a mouse event
## Godot makes from the touch (device DEVICE_ID_EMULATION), so it counts as touch too.
static func note_pointer(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_in_use = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		touch_in_use = event.device == InputEvent.DEVICE_ID_EMULATION


## Marks a non-TouchButton input (checkbox, slider box, text box) as a touch target, so grown
## button hit areas never reach into it.
static func add_touch_target(control: Control) -> void:
	control.add_to_group(TOUCH_GROUP)


## Keeps keyboard / controller focus inside `modal`, a panel open over `screen`: every other
## focusable control under `screen` stops taking focus (arrows, Tab and Shift+Tab skip it) until
## `unlock_focus` gets the returned map back. Grab the panel's focus before or after; either works.
static func lock_focus(screen: Node, modal: Node) -> Dictionary:
	var saved := {}
	_lock_focus(screen, modal, saved)
	return saved


static func _lock_focus(node: Node, modal: Node, saved: Dictionary) -> void:
	for child in node.get_children():
		if child == modal:
			continue
		var control := child as Control
		if control and control.focus_mode != Control.FOCUS_NONE:
			saved[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
		_lock_focus(child, modal, saved)


## Undoes `lock_focus` (controls freed meanwhile are skipped).
static func unlock_focus(saved: Dictionary) -> void:
	for control: Variant in saved:
		if is_instance_valid(control):
			(control as Control).focus_mode = saved[control]
	saved.clear()


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
	add_touch_target(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_theme_constant_override("separation", 6)
	var label := make_label("VOLUME", FONT, TEXT_DIM)
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
	var dragging := [false]  # applied live while dragging, saved once on release
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		dragging[0] = false
		if progress:
			progress.set_volume(slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		if progress:
			progress.set_volume(value, not dragging[0])
		var sfx := slider.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click"))
	row.add_child(slider)
	box.set_meta("slider", slider)
	return box


## Idle slime preview in the given color (2 = double size).
static func make_slime_preview(color: Color, scale := 1, rainbow := false, jelly: Variant = null, clock := false) -> AnimatedSprite2D:
	var preview := AnimatedSprite2D.new()
	preview.sprite_frames = Slime.load_sprite_frames()
	preview.material = Skins.make_material(color, rainbow, clock)
	if jelly != null:
		(preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if jelly else 0.0)
	preview.scale = Vector2(scale, scale)
	preview.play("idle")
	if clock:
		Stopwatch.attach(preview, true)
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
