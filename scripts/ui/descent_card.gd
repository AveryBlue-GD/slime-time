class_name DescentCard
extends CanvasLayer

## The DESCENT cards over a floor (built by game.gd on first use):
## - the BOON card after a cleared floor: FLOOR n CLEARED, the meter carried + the next refill, the
##   pot (+ this floor's tickets), three boon tiles (icon, name, two short lines, how many held) to
##   pick one of, then DESCEND (or CASH OUT +N to bank the whole pot and end the run);
## - the SUMMARY after the run ends (dry-up, CASH OUT): why it ended, the floor reached, the best
##   floor, the run time and the day's paid slot it used (PAID RUN n/2), the tickets banked (and why
##   fewer), milestone bonuses, the boons held,
##   then NEW RUN / HUB.
## Keyboard: arrows move between the tiles and buttons, Enter / Space picks; a tile picks the boon
## and moves the focus to DESCEND. Touch / mouse: tap a tile, then DESCEND. Esc opens the pause menu
## (the game's), whose QUIT TO HUB here cashes out. The tree pauses under the pause menu, and so does
## this card (it is the game's child).

const TILE := Vector2(96, 78)
const TILE_Y := 47.0
## The FLOOR n CLEARED title's line top (its capitals' ink from row 4).
const TITLE_Y := 4.0
const TILE_XS: Array[float] = [10.0, 112.0, 214.0]
## The buttons: button_h() tall on the result rows' line (UIKit.choice_y()); the card's two take the
## tile width (one under each outer tile), the summary's two are the standard choice row.
const BUTTON := Vector2(96, UIKit.BUTTON_H)
## The summary panel's English width (x 40..280); a wider translated line widens it (_fit_summary).
const SUMMARY_W := 240.0
const DIM := Color(0.06, 0.06, 0.1, 0.82)
## A tile face's side room (GAP_L: a line as wide as the room keeps the panel inset clear of the tile's
## stripes; wider lines wrap), and the room the 1x icon takes before the name (8 + GAP_S).
const FACE_PAD := float(UIKit.GAP_L)
const INLINE_ICON := 11.0

var game: Node
var root: Control
var boons_root: Control
var summary_root: Control
## The boon card's parts.
var title: Label
var meter_label: Label
var pot_label: Label
var status: Label
var tiles: Array[Button] = []
var tile_ids: Array[String] = []
var cash_button: Button
var descend_button: Button
var picked := ""
## The summary's parts.
var summary_title: Label
var summary_lines: VBoxContainer
var summary_panel: Panel
var new_run_button: Button
var hub_button: Button
var _skin_text: SkinText
var _group := ButtonGroup.new()
## PICK ONE shows on the status line (until a pick) instead of over the tiles: a taller script.
var _pick_in_status := false


func _ready() -> void:
	layer = 15  # over the HUD (and its message), under the pause menu (20)
	root = Control.new()
	root.theme = UIKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dim := ColorRect.new()  # swallows clicks on the level behind
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_build_boons()
	_build_summary()
	_skin_text = UIKit.add_skin_text(root)
	UIKit.mirror_root(root)  # (right-to-left languages: flipped once built, docs/ui-rules.md 10.2)
	visible = false


# ---------------------------------------------------------------- the boon card

func _build_boons() -> void:
	boons_root = Control.new()
	boons_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boons_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boons_root)
	title = _centered(boons_root, "", 16, UIKit.GOLD, TITLE_Y)
	# The meter carried + the next floor's refill on the left, the pot on the right.
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.position = Vector2(10, 27)
	boons_root.add_child(info)
	info.add_child(UIKit.make_icon("drop", Color8(148, 226, 112)))
	meter_label = UIKit.make_label("", UIKit.FONT, UIKit.TEXT)
	info.add_child(meter_label)
	var pot_row := HBoxContainer.new()
	pot_row.add_theme_constant_override("separation", 3)
	pot_row.alignment = BoxContainer.ALIGNMENT_END
	pot_row.position = Vector2(150, 27)
	pot_row.size = Vector2(160, 10)
	boons_root.add_child(pot_row)
	pot_row.add_child(UIKit.make_icon("ticket", Color.WHITE))
	pot_label = UIKit.make_label("", UIKit.FONT, UIKit.GOLD)
	pot_row.add_child(pot_label)
	var pick := _centered(boons_root, Loc.t("descent.pick_one", "PICK ONE"), 8, UIKit.TEXT_DIM, 37.0)
	pick.name = "PickHint"
	for i in TILE_XS.size():
		var tile := UIKit.make_button("", _on_tile.bind(i), TILE)
		tile.toggle_mode = true
		tile.button_group = _group
		tile.position = Vector2(TILE_XS[i], TILE_Y)
		tile.size = TILE
		boons_root.add_child(tile)
		tiles.append(tile)
	status = _centered(boons_root, "", 8, UIKit.TEXT_DIM, 133.0)
	cash_button = UIKit.make_button(Loc.t("descent.cash_out", "CASH OUT"), _on_cash_out, Vector2(BUTTON.x, UIKit.button_h()))
	cash_button.position = Vector2(TILE_XS[0], UIKit.choice_y())
	boons_root.add_child(cash_button)
	descend_button = UIKit.make_button(Loc.t("descent.descend", "DESCEND"), _on_descend, Vector2(BUTTON.x, UIKit.button_h()))
	descend_button.position = Vector2(TILE_XS[2], UIKit.choice_y())
	boons_root.add_child(descend_button)
	# Focus: the tiles in a row; down from any tile to the buttons; up back to the tiles.
	for i in tiles.size():
		var t := tiles[i]
		t.focus_neighbor_left = t.get_path_to(tiles[(i + tiles.size() - 1) % tiles.size()])
		t.focus_neighbor_right = t.get_path_to(tiles[(i + 1) % tiles.size()])
		t.focus_neighbor_bottom = t.get_path_to(cash_button if i == 0 else descend_button)
		t.focus_neighbor_top = t.get_path_to(t)
	cash_button.focus_neighbor_top = cash_button.get_path_to(tiles[0])
	cash_button.focus_neighbor_right = cash_button.get_path_to(descend_button)
	cash_button.focus_neighbor_left = cash_button.get_path_to(descend_button)
	descend_button.focus_neighbor_top = descend_button.get_path_to(tiles[2])
	descend_button.focus_neighbor_left = descend_button.get_path_to(cash_button)
	descend_button.focus_neighbor_right = descend_button.get_path_to(cash_button)
	cash_button.focus_neighbor_bottom = cash_button.get_path_to(cash_button)
	descend_button.focus_neighbor_bottom = descend_button.get_path_to(descend_button)


## Shows the boon card for `run` (Progress.descent_run, its floor just cleared) with `offers`.
func show_boons(run: Dictionary, offers: Array) -> void:
	UIKit.relayout(root)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	visible = true
	_hide_hud()
	boons_root.visible = true
	summary_root.visible = false
	picked = ""
	tile_ids.assign(offers)
	var floor_no: int = run.get("floor", 1)
	title.text = Loc.t("descent.floor_cleared", "FLOOR {floor} CLEARED", {floor = floor_no})
	var refill := Descent.floor_refill(floor_no + 1, run.get("boons", {}))
	meter_label.text = Loc.t("descent.meter", "{now}%  NEXT FLOOR +{next}%", {now = ceili(float(run.get("meter", 0.0))), next = roundi(refill)})
	var practice := ""
	var progress: Node = get_node_or_null("/root/Progress")
	if progress:
		var due: Dictionary = progress.descent_payout(true)
		practice = str(due.cap)
		cash_button.text = Loc.t("descent.cash_out_gain", "CASH OUT +{count}", {count = due.tickets})
	# i18n: pot pod, max 130px, 1 line; the spaces are spacing, not words
	var pot_args := {pot = int(run.get("pot", 0)), gain = int(run.get("gain", 0))}
	match practice:
		"practice":
			pot_label.text = Loc.t("descent.pot_practice", "POT {pot} (+{gain})  PRACTICE", pot_args)
		"dev":
			pot_label.text = Loc.t("descent.pot_dev", "POT {pot} (+{gain})  NO TICKETS", pot_args)
		"slime":
			pot_label.text = Loc.t("descent.pot_slime", "POT {pot} (+{gain})  PAYS 1", pot_args)
		_:
			pot_label.text = Loc.t("descent.pot", "POT {pot} (+{gain})", pot_args)
	_fit_card_buttons()
	_layout_boons(run.get("boons", {}))
	status.text = ""
	if _pick_in_status:
		status.text = Loc.t("descent.pick_one", "PICK ONE")
	_skin_text.recolor()
	if not tiles.is_empty() and tiles[0].visible:
		tiles[0].grab_focus()
	else:
		descend_button.grab_focus()


## The boon card's rows from the top: the title, the meter / pot line, PICK ONE, the tiles, the status
## line and the buttons (UIKit.choice_y(), ending on the choice rows' line). English: title 4, info 27,
## PICK ONE 37, tiles 47 (78 tall), status 133, buttons 153. A taller script's lines take more room:
## gaps of GAP_XS, PICK ONE shown on the status line until a pick, the tiles as tall as what is left.
## Each tile's face: its content centred in the tile, every tile starting on the same row: the 2x icon
## over the lines (English), or (when that is too tall) the 1x icon over them, or in front of the name
## (the lines on dense_pitch()), and if even that is too tall the script's smaller font.
func _layout_boons(held: Dictionary) -> void:
	var tall := UIKit.tall_script()
	var line := UIKit.line_h()
	var box_h := maxi(10, line)
	var gap := UIKit.GAP_XS if tall else 3
	var title_h := UIKit.title_h()
	# A title with marks (ÉTAGE, CONCLUÍDO, ЭТАЖ) starts lower by them, so they draw from row 4 as the
	# English capitals do (not cut by the top of the screen); everything under it moves down with it.
	var marks := float(UIKit.ink_above(title.text, UIKit.FONT_BIG))
	var title_y := TITLE_Y + marks
	var info_y := title_y + title_h + gap
	_pick_in_status = tall
	var tiles_y := info_y + line + gap if tall else TILE_Y + marks
	var buttons_y := float(UIKit.choice_y())
	# (the tiles and the status line move down with the title, into the room over the buttons; the tiles
	# give up only the rows that are not there, keeping 4 clear rows over the status line's marks)
	var status_y := minf(133.0, buttons_y - gap - line) if tall else minf(133.0 + marks, buttons_y - 4.0 - line)
	var tile_h := status_y - gap - tiles_y if tall \
		else minf(TILE.y, status_y - 4.0 - float(UIKit.metrics().get("ink_above", 0)) - tiles_y)
	_set_y(title, title_y, title_h)
	if meter_label.get_parent().position.y != info_y:
		meter_label.get_parent().position.y = info_y
		pot_label.get_parent().position.y = info_y
	var pick := boons_root.get_node("PickHint") as Label
	pick.visible = not _pick_in_status
	_set_y(pick, info_y + 10.0, box_h)
	_set_y(status, status_y, box_h)
	# The faces: try each style until every tile's content fits its height.
	var styles := ["icon over", "small icon over", "icon inline", "smaller"]
	# (the slimy font's marks above and drips below must stay inside the tile; a taller script's line
	# box holds its own)
	var m := UIKit.metrics()
	var ink := 0.0 if tall else float(m.get("ink_above", 0)) + float(m.get("ink_below", 0))
	var style := ""
	var font: Font = null
	var content := 0.0
	var best := {}
	for each: String in styles:
		if tall and each == "icon over":
			continue  # (a taller script's four lines never fit under a 2x icon)
		var each_font: Font = null
		if each == "smaller":
			var language: Node = get_node_or_null("/root/Language")
			each_font = language.small_font(UIKit.locale()) if language and language.has_method("small_font") else null
			if each_font == null:
				continue
		var h := 0.0
		for id in tile_ids:
			h = maxf(h, _face_h(id, held, each, each_font))
		if best.is_empty() or h < best.h:
			best = {style = each, font = each_font, h = h}
		if h + ink <= tile_h:
			best = {style = each, font = each_font, h = h}
			break
	style = best.style
	font = best.font
	content = best.h
	var top := floorf((tile_h - content) / 2.0)
	if not tall:  # (a face that nearly fills the tile: its first line's marks stay under the goo lumps, row 3+)
		var above := float(m.get("ink_above", 0))
		top = maxf(top, minf(above + float(UIKit.GAP_S), tile_h - content - float(m.get("ink_below", 0)) - float(UIKit.GAP_S)))
	for i in tiles.size():
		var tile := tiles[i]
		tile.button_pressed = false
		for child in tile.get_children():
			child.queue_free()
		tile.visible = i < tile_ids.size()
		if tile.size.y != tile_h or tile.position.y != tiles_y:
			tile.custom_minimum_size = Vector2(TILE.x, tile_h)
			tile.size = tile.custom_minimum_size
			tile.position.y = tiles_y
		if tile.visible:
			_fill_tile(tile, tile_ids[i], held, top, style, font)


## Sets a label's top and height (only when they change: setting them shapes the text at once, and the
## English card must make its RIDs in the same order as before).
func _set_y(label: Label, y: float, h: float) -> void:
	if label.position.y != y:
		label.position.y = y
	if label.size.y != h:
		label.size.y = h


## The face's lines: the name, the two short lines and HAVE n (if any).
func _face_texts(id: String, held: Dictionary) -> Array[String]:
	var lines: Array = Descent.about(id)
	var out: Array[String] = [Descent.display_name(id), lines[0], lines[1]]
	var note := _have_note(id, held)
	if note != "":
		out.append(note)
	return out


## How many lines `text` takes in a tile (two when it is wider than the tile's text room).
func _lines_of(text: String, font: Font, first: bool, style: String) -> int:
	var room := _text_room(first, style)
	var w := UIKit.text_w(text, UIKit.FONT, font) if font else UIKit.text_w(text)
	return 1 if w <= room else UIKit.wrapped_lines(text, room, UIKit.FONT, font)


## The width a face's line may take (the name loses the inline icon's room).
func _text_room(first: bool, style: String) -> float:
	return TILE.x - 2 * FACE_PAD - (INLINE_ICON if first and _inline(style) else 0.0)


func _inline(style: String) -> bool:
	return style == "icon inline" or style == "smaller"


## Line heights / pitch for a face style.
func _face_metrics(style: String, font: Font) -> Vector2:
	if style == "smaller" and font:
		var h := font.get_height(UIKit.FONT)
		return Vector2(h, h)
	if style == "icon over":
		return Vector2(UIKit.line_h(), UIKit.line_pitch())
	return Vector2(UIKit.line_h(), UIKit.dense_pitch())


## The room the icon takes above the lines: the 2x icon and a 5 px gap, the 1x icon and GAP_S, or none.
func _icon_room(style: String) -> float:
	return 21.0 if style == "icon over" else (8.0 + UIKit.GAP_S if style == "small icon over" else 0.0)


## The height of a tile's content in `style` (English: 52 without HAVE, 64 with it).
func _face_h(id: String, held: Dictionary, style: String, font: Font) -> float:
	var m := _face_metrics(style, font)
	var h := _icon_room(style)
	var texts := _face_texts(id, held)
	for i in texts.size():
		var n := _lines_of(texts[i], font, i == 0, style)
		h += n * m.x + (n - 1) * (m.y - m.x)
		if i < texts.size() - 1:
			h += m.y - m.x
	return h


## A tile's face from row `top`: the icon (2x or 1x over the lines, or 1x before the name), the name,
## two short lines and how many are held (stacking boons), each centred, wrapped onto two lines if wider.
func _fill_tile(tile: Button, id: String, held: Dictionary, top: float, style := "icon over", font: Font = null) -> void:
	var m := _face_metrics(style, font)
	var texts := _face_texts(id, held)
	var y := top
	if not _inline(style):
		var scale := 2 if style == "icon over" else 1
		var icon := BoonIcons.make(id, scale)
		icon.position = Vector2((TILE.x - 8 * scale) / 2.0, top)
		tile.add_child(icon)
		y += _icon_room(style)
	for i in texts.size():
		var label := UIKit.make_label(texts[i], UIKit.FONT, [UIKit.GOLD, UIKit.TEXT, UIKit.TEXT, UIKit.TEXT_DIM][i])
		if font:
			label.add_theme_font_override("font", font)
		var n := _lines_of(texts[i], font, i == 0, style)
		var room := _text_room(i == 0, style)
		if i == 0 and _inline(style):
			# The 1x icon in front of the name (on its first line), the pair centred.
			var w := minf(UIKit.text_w(texts[i], UIKit.FONT, font) if font else UIKit.text_w(texts[i]), room)
			var x := floorf((TILE.x - INLINE_ICON - w) / 2.0)
			var icon := BoonIcons.make(id, 1)
			icon.position = Vector2(x, y + floorf((m.x - 8.0) / 2.0))
			tile.add_child(icon)
			_span(tile, label, y, n, m, Rect2(x + INLINE_ICON, 0, w, 0))
		elif n > 1:
			_span(tile, label, y, n, m, Rect2(FACE_PAD, 0, room, 0))
		else:
			_span(tile, label, y, n, m)
		y += n * m.x + (n - 1) * (m.y - m.x) + (m.y - m.x)


func _span(tile: Control, label: Label, y: float, lines := 1, m := Vector2(7, 12), span := Rect2()) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if lines > 1:  # (before it is in the tree: its minimum width is then never its one-line width)
		label.autowrap_mode = UIKit.autowrap_mode()
		label.add_theme_constant_override("line_spacing", int(m.y - m.x))
	tile.add_child(label)  # (sized once in the tree: off it the label measures with the default font)
	label.position = Vector2(span.position.x if span.size.x > 0 else 0.0, y)
	var h := maxf(10, lines * m.x + (lines - 1) * (m.y - m.x)) if lines > 1 or m.x > 7 else 10.0
	label.size = Vector2(span.size.x if span.size.x > 0 else TILE.x, h)


## CASH OUT / DESCEND: under the outer tiles, 96 wide in English, equal widths from the longer text
## (growing inward), button_h() tall on the choice rows' line.
func _fit_card_buttons() -> void:
	var widths := UIKit.tab_widths([cash_button.text, descend_button.text], int(BUTTON.x))
	for b: Button in [cash_button, descend_button]:
		UIKit.note_text_w(b, [cash_button.text, descend_button.text], int(BUTTON.x))
	if widths[0] != int(cash_button.custom_minimum_size.x):
		for b: Button in [cash_button, descend_button]:
			b.custom_minimum_size = Vector2(widths[0], UIKit.button_h())
			b.size = b.custom_minimum_size
		descend_button.position.x = TILE_XS[2] + TILE.x - widths[0]


## "HAVE n/max" for a stacking boon (or "HAVE n" for an unlimited one already held), else "".
func _have_note(id: String, held: Dictionary) -> String:
	var top: int = int(Descent.boon(id).get("max", 1))
	var have := Descent.held(held, id)
	if top > 1:
		return Loc.t("descent.have_max", "HAVE {have}/{max}", {have = have, max = top})
	elif top <= 0 and have > 0:
		return Loc.t("descent.have", "HAVE {have}", {have = have})
	return ""


func _on_tile(i: int) -> void:
	if i >= tile_ids.size():
		return
	picked = tile_ids[i]
	tiles[i].button_pressed = true
	status.text = Loc.t("descent.confirm", "{name}  -  DESCEND?", {name = Descent.display_name(picked)})
	descend_button.grab_focus()


func _on_descend() -> void:
	if picked == "":
		status.text = Loc.t("descent.pick_first", "PICK A BOON FIRST")
		if not tiles.is_empty():
			tiles[0].grab_focus()
		return
	if game and game.has_method("descend_with"):
		game.descend_with(picked)


func _on_cash_out() -> void:
	if game and game.has_method("cash_out"):
		game.cash_out()


# ---------------------------------------------------------------- the run summary

func _build_summary() -> void:
	summary_root = Control.new()
	summary_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_root.visible = false
	root.add_child(summary_root)
	summary_panel = UIKit.add_panel(summary_root, Rect2((UIKit.SCREEN.x - SUMMARY_W) / 2.0, 28, SUMMARY_W, 116))  # (fitted in show_summary)
	summary_title = _centered(summary_root, Loc.t("descent.run_over", "RUN OVER"), 16, UIKit.GOLD, 8.0)
	summary_lines = VBoxContainer.new()
	summary_lines.add_theme_constant_override("separation", UIKit.line_spacing())  # a line_pitch() pitch (12 in English)
	summary_lines.position = Vector2((UIKit.SCREEN.x - SUMMARY_W) / 2.0, 38)
	summary_lines.custom_minimum_size = Vector2(SUMMARY_W, 0)
	summary_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_root.add_child(summary_lines)
	# NEW RUN / HUB: the choice row (CHOICE_SIZE in English; equal widths from the longer word, the
	# pair centred CHOICE_GAP apart, its bottom edge on the choice rows' line).
	var texts := [Loc.t("descent.new_run", "NEW RUN"), Loc.t("descent.hub", "HUB")]
	var w: int = UIKit.tab_widths(texts, int(UIKit.CHOICE_SIZE.x))[0]
	new_run_button = UIKit.make_button(texts[0], _on_new_run, Vector2(w, UIKit.button_h()))
	new_run_button.position = Vector2(160 - UIKit.CHOICE_GAP / 2 - w, UIKit.choice_y())
	summary_root.add_child(new_run_button)
	hub_button = UIKit.make_button(texts[1], _on_hub, Vector2(w, UIKit.button_h()))
	hub_button.position = Vector2(160 + UIKit.CHOICE_GAP / 2, UIKit.choice_y())
	summary_root.add_child(hub_button)
	for b: Button in [new_run_button, hub_button]:
		UIKit.note_text_w(b, texts, int(UIKit.CHOICE_SIZE.x))
		var other: Button = hub_button if b == new_run_button else new_run_button
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)


## Shows the end of the run: `result` = Progress.end_descent's.
func show_summary(result: Dictionary) -> void:
	UIKit.relayout(root)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	visible = true
	_hide_hud()
	boons_root.visible = false
	summary_root.visible = true
	for child in summary_lines.get_children():
		child.queue_free()
	var floor_no: int = result.get("floor", 1)
	var cashed: bool = result.get("cashed", false)
	summary_title.text = Loc.t("descent.cashed_out", "CASHED OUT") if cashed else Loc.t("descent.run_over", "RUN OVER")
	# i18n: summary lines, max 200px, 1 line each; the spaces are spacing, not words
	if cashed:
		_line(Loc.n("descent.cleared", "CLEARED {count} FLOOR", "CLEARED {count} FLOORS", int(result.get("cleared", 0))), UIKit.TEXT)
	else:
		_line(Loc.t("descent.dried_up", "DRIED UP ON FLOOR {floor}", {floor = floor_no}), UIKit.TEXT)
	var best_args := {floor = int(result.get("best_floor", floor_no))}
	if result.get("new_best", false):
		_line(Loc.t("descent.best_new", "BEST FLOOR {floor}   NEW BEST!", best_args), UIKit.GOLD)
	else:
		_line(Loc.t("descent.best", "BEST FLOOR {floor}", best_args), UIKit.TEXT_DIM)
	var time_args := {time = UIKit.format_time(float(result.get("time", 0.0)))}
	var time_text := Loc.t("descent.time", "TIME {time}", time_args)
	if int(result.get("slot", 0)) > 0:  # the day's paid slot the run used (taken on floor 1)
		time_args.merge({slot = int(result.slot), total = Economy.DESCENT_PAID_PER_DAY})
		time_text = Loc.t("descent.time_paid", "TIME {time}   PAID RUN {slot}/{total}", time_args)
	_line(time_text, UIKit.TEXT_DIM)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tickets: int = result.get("tickets", 0)
	row.add_child(UIKit.make_icon("ticket", Color.WHITE if tickets > 0 else Color(0.55, 0.55, 0.6)))
	var pot: int = result.get("pot", 0)
	var ticket_text := ""
	# i18n: ticket row, max 200px, 1 line; the leading spaces are spacing, not words
	match result.get("cap", ""):
		"practice":
			ticket_text = Loc.n("descent.tickets_practice", "+{count} TICKET  PRACTICE ({paid} PAID RUNS A DAY)", "+{count} TICKETS  PRACTICE ({paid} PAID RUNS A DAY)", tickets, {paid = Economy.DESCENT_PAID_PER_DAY})
		"dev":
			ticket_text = Loc.n("descent.tickets", "+{count} TICKET", "+{count} TICKETS", tickets) + "  DEV TOGGLES"  # dev-only: stays English
		"slime":
			ticket_text = Loc.n("descent.tickets", "+{count} TICKET", "+{count} TICKETS", tickets)  # no MORE SLIME bought: capped, but no reason line that nudges toward an upgrade (D12)
		_:
			if not cashed and pot > 0:
				ticket_text = Loc.n("descent.tickets_half", "+{count} TICKET  HALF THE POT ({pot})", "+{count} TICKETS  HALF THE POT ({pot})", tickets, {pot = pot})
			else:
				ticket_text = Loc.n("descent.tickets", "+{count} TICKET", "+{count} TICKETS", tickets)
	row.add_child(UIKit.make_label(ticket_text, UIKit.FONT, Color8(255, 226, 150) if tickets > 0 else UIKit.TEXT_DIM))
	summary_lines.add_child(row)
	for bonus: Array in result.get("bonuses", []):
		_line(Loc.t("descent.bonus", "FLOOR {floor} BONUS +{count}", {floor = bonus[0], count = bonus[1]}), UIKit.GOLD)
	var held: Dictionary = result.get("boons", {})
	if not held.is_empty():
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 2)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in Descent.IDS:
			for n in mini(Descent.held(held, id), 3):
				strip.add_child(BoonIcons.make(id))
		summary_lines.add_child(strip)
	_fit_summary()
	_skin_text.recolor()
	new_run_button.grab_focus()


## The panel hugs its lines (PANEL_PAD above and below; the last line's drips inside the pad), and
## the title + panel are centered as one block between the top of the screen and the buttons.
func _fit_summary() -> void:
	var lines_height := 0.0
	var count := 0
	var first := ""
	var widest := 0.0
	for child: Control in summary_lines.get_children():
		if child.is_queued_for_deletion():
			continue
		if count == 0 and child is Label:
			first = (child as Label).text
		widest = maxf(widest, child.get_combined_minimum_size().x)
		count += 1
	# A line wider than the English panel's text room (a translation) widens the panel, centred, up to
	# the screen's text column; one still wider breaks onto two lines.
	var panel_w := clampf(widest + 2 * UIKit.GAP_L, SUMMARY_W, UIKit.SCREEN.x - 2 * UIKit.EDGE)
	_fit_rows(panel_w - 2 * UIKit.GAP_L)
	for child: Control in summary_lines.get_children():
		if not child.is_queued_for_deletion():
			lines_height += child.get_combined_minimum_size().y
	lines_height += maxf(count - 1, 0) * UIKit.line_spacing()
	# The first line's marks (KHÔ CẠN Ở TẦNG) go under the panel's goo lump row, not on it.
	var marks := float(UIKit.accent_room() if UIKit.ink_above(first) > 0 else 0)
	var panel_h := UIKit.PANEL_PAD * 2 + lines_height + marks
	var panel_x := roundf((UIKit.SCREEN.x - panel_w) / 2.0)
	if summary_panel.position.x != panel_x or summary_panel.size.x != panel_w:
		summary_panel.position.x = panel_x
		summary_panel.size.x = panel_w
		summary_lines.position.x = panel_x
		summary_lines.custom_minimum_size.x = panel_w
	# The title's box (16 px: 14 rows + 4 px drips + 2 shadow in English) and a 6 px gap: 26.
	var title_block := UIKit.title_h() + 6.0
	var block_top := floorf((UIKit.choice_y() - 4.0 - (title_block + panel_h)) / 2.0)
	summary_title.position.y = block_top
	summary_panel.position.y = block_top + title_block
	summary_panel.size.y = panel_h
	summary_lines.position.y = summary_panel.position.y + UIKit.PANEL_PAD + marks
	summary_lines.size.y = 0


## Breaks every summary text wider than `room` onto two balanced lines (centred); the ticket row's
## text keeps its icon beside its first line.
func _fit_rows(room: float) -> void:
	for child: Control in summary_lines.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.get_combined_minimum_size().x <= room:
			continue
		var label: Label = child as Label
		var extra := 0.0
		if label == null:
			for part in child.get_children():
				if part is Label:
					label = part
				elif part is Control:
					extra += (part as Control).get_combined_minimum_size().x + float(child.get_theme_constant("separation"))
		if label and not "\n" in label.text:
			label.text = UIKit.break_line(label.text, int(room - extra))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## The HUD's pods would show through the card's dim sheet under its title and pot line: hidden while
## a card is up (the card leads to a new floor or out of the level, so it never needs them back).
func _hide_hud() -> void:
	var hud: CanvasLayer = game.get("hud") if game else null
	if hud:
		hud.visible = false


func _line(text: String, color: Color) -> void:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lines.add_child(label)


func _on_new_run() -> void:
	if game and game.has_method("new_descent_run"):
		game.new_descent_run()


func _on_hub() -> void:
	if game and game.has_method("go_to_hub"):
		game.go_to_hub()


# ---------------------------------------------------------------- helpers

func _centered(parent: Control, text: String, font_size: int, color: Color, y: float) -> Label:
	var label := UIKit.make_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	label.position = Vector2(0, y)
	label.size = Vector2(320, UIKit.title_h() if font_size == 16 else maxi(10, UIKit.line_h()))
	return label


## The card's modal part (focus must stay inside it): the boon card or the summary.
func modal() -> Control:
	return summary_root if summary_root.visible else boons_root
