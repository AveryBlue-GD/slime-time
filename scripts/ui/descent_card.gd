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
const TILE_XS: Array[float] = [10.0, 112.0, 214.0]
## The buttons: 13 px tall on the result rows' line (UIKit.CHOICE_Y); the card's two take the tile
## width (one under each outer tile), the summary's two are the standard choice row.
const BUTTON_Y := float(UIKit.CHOICE_Y)
const BUTTON := Vector2(96, UIKit.BUTTON_H)
## The boon tiles' content (icon, name, two lines, HAVE n): its top row, and lower when no tile in
## the row has a HAVE line (then the three lines sit centered in the tile).
const TILE_TOP := 7.0
const TILE_TOP_SHORT := 13.0
const DIM := Color(0.06, 0.06, 0.1, 0.82)

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
	visible = false


# ---------------------------------------------------------------- the boon card

func _build_boons() -> void:
	boons_root = Control.new()
	boons_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boons_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boons_root)
	title = _centered(boons_root, "", 16, UIKit.GOLD, 4.0)
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
	cash_button = UIKit.make_button(Loc.t("descent.cash_out", "CASH OUT"), _on_cash_out, BUTTON)
	cash_button.position = Vector2(TILE_XS[0], BUTTON_Y)
	boons_root.add_child(cash_button)
	descend_button = UIKit.make_button(Loc.t("descent.descend", "DESCEND"), _on_descend, BUTTON)
	descend_button.position = Vector2(TILE_XS[2], BUTTON_Y)
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
	var top := TILE_TOP_SHORT
	for id in tile_ids:
		if _have_note(id, run.get("boons", {})) != "":
			top = TILE_TOP
	for i in tiles.size():
		var tile := tiles[i]
		tile.button_pressed = false
		for child in tile.get_children():
			child.queue_free()
		tile.visible = i < tile_ids.size()
		if tile.visible:
			_fill_tile(tile, tile_ids[i], run.get("boons", {}), top)
	status.text = ""
	_skin_text.recolor()
	if not tiles.is_empty() and tiles[0].visible:
		tiles[0].grab_focus()
	else:
		descend_button.grab_focus()


## A tile's face: the icon (2x), the name, two short lines and how many are held (stacking boons).
func _fill_tile(tile: Button, id: String, held: Dictionary, top := TILE_TOP) -> void:
	var icon := BoonIcons.make(id, 2)
	icon.position = Vector2((TILE.x - 16) / 2.0, top)
	tile.add_child(icon)
	var name_label := UIKit.make_label(Descent.display_name(id), UIKit.FONT, UIKit.GOLD)
	_span(tile, name_label, top + 21.0)
	var lines: Array = Descent.about(id)
	_span(tile, UIKit.make_label(lines[0], UIKit.FONT, UIKit.TEXT), top + 33.0)
	_span(tile, UIKit.make_label(lines[1], UIKit.FONT, UIKit.TEXT), top + 45.0)
	var note := _have_note(id, held)
	if note != "":
		_span(tile, UIKit.make_label(note, UIKit.FONT, UIKit.TEXT_DIM), top + 57.0)


## "HAVE n/max" for a stacking boon (or "HAVE n" for an unlimited one already held), else "".
func _have_note(id: String, held: Dictionary) -> String:
	var top: int = int(Descent.boon(id).get("max", 1))
	var have := Descent.held(held, id)
	if top > 1:
		return Loc.t("descent.have_max", "HAVE {have}/{max}", {have = have, max = top})
	elif top <= 0 and have > 0:
		return Loc.t("descent.have", "HAVE {have}", {have = have})
	return ""


func _span(tile: Control, label: Label, y: float) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(label)  # (sized once in the tree: off it the label measures with the default font)
	label.position = Vector2(0, y)
	label.size = Vector2(TILE.x, 10)


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
	summary_panel = UIKit.add_panel(summary_root, Rect2(40, 28, 240, 116))  # (fitted in show_summary)
	summary_title = _centered(summary_root, Loc.t("descent.run_over", "RUN OVER"), 16, UIKit.GOLD, 8.0)
	summary_lines = VBoxContainer.new()
	summary_lines.add_theme_constant_override("separation", UIKit.LINE_SPACING)  # a 12 px line pitch
	summary_lines.position = Vector2(40, 38)
	summary_lines.custom_minimum_size = Vector2(240, 0)
	summary_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_root.add_child(summary_lines)
	new_run_button = UIKit.make_button(Loc.t("descent.new_run", "NEW RUN"), _on_new_run, UIKit.CHOICE_SIZE)
	new_run_button.position = Vector2(160 - UIKit.CHOICE_GAP / 2 - UIKit.CHOICE_SIZE.x, BUTTON_Y)
	summary_root.add_child(new_run_button)
	hub_button = UIKit.make_button(Loc.t("descent.hub", "HUB"), _on_hub, UIKit.CHOICE_SIZE)
	hub_button.position = Vector2(160 + UIKit.CHOICE_GAP / 2, BUTTON_Y)
	summary_root.add_child(hub_button)
	for b: Button in [new_run_button, hub_button]:
		var other: Button = hub_button if b == new_run_button else new_run_button
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)


## Shows the end of the run: `result` = Progress.end_descent's.
func show_summary(result: Dictionary) -> void:
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
	for child: Control in summary_lines.get_children():
		if child.is_queued_for_deletion():
			continue
		lines_height += child.get_combined_minimum_size().y
		count += 1
	lines_height += maxf(count - 1, 0) * UIKit.LINE_SPACING
	var panel_h := UIKit.PANEL_PAD * 2 + lines_height
	const TITLE_BLOCK := 26.0  # the 16 px title (14 rows), its 4 px drips and a 8 px gap
	var block_top := floorf((BUTTON_Y - 4.0 - (TITLE_BLOCK + panel_h)) / 2.0)
	summary_title.position.y = block_top
	summary_panel.position.y = block_top + TITLE_BLOCK
	summary_panel.size.y = panel_h
	summary_lines.position.y = summary_panel.position.y + UIKit.PANEL_PAD
	summary_lines.size.y = 0


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
	label.size = Vector2(320, 20 if font_size == 16 else 10)
	return label


## The card's modal part (focus must stay inside it): the boon card or the summary.
func modal() -> Control:
	return summary_root if summary_root.visible else boons_root
