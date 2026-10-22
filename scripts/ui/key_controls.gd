extends Control

## CONTROLS page (opened from SETTINGS): key remapping (click an action's key, then press the new
## key; Esc cancels; if the key was already used by another action, the two swap). BACK or Esc
## returns to SETTINGS. Two columns: moving and leaping on the left; restart, the hub's use key and the
## three ticket ABILITIES on the right.

## The actions in each column, top to bottom.
const COLUMNS := [["move_up", "move_down", "move_left", "move_right", "jump"],
	["restart", "interact", "ability_rifle", "ability_splat", "ability_kaze"]]  # (SLIME SENSE stays on M: the page's two columns hold five rows each)
## A column: a label LABEL_WIDTH wide, GAP, the key button KEY_WIDTH wide; the two columns
## COLUMN_GAP apart, centered: 2 x (84 + 4 + 64) + 8 = 312. Rows ROW_GAP apart from ROWS_TOP (8 under
## the title's line box); the note line at NOTE_TOP, NOTE_GAP over the bottom row. Other locales
## (_plan, docs/ui-rules.md section 10): a longer label widens the label column and narrows the key
## column (down to what PRESS KEY needs); when two columns still don't fit, one column per page. Rows
## follow button_h() under title_bottom(); when five rows and the note don't fit above the bottom row
## (even 4 px under the title and GAP_L over the bottom row), the rows split into pages (Thai,
## Devanagari, Traditional Chinese: 3 + 2), turned by a page button at the bottom right (1/2, 2/2).
const LABEL_WIDTH := 84
const KEY_WIDTH := 64
const GAP := 4
const COLUMN_GAP := 8
const ROWS_TOP := 30
const ROW_GAP := 4
const NOTE_TOP := 140
const NOTE_GAP := UIKit.BOTTOM_ROW_Y - NOTE_TOP - 10  # 14

var key_buttons := {}
var waiting_for := ""
var reset_keys_button: Button
var back_button: Button
## The line under the key rows: fixed keys on a keyboard, the fixed pad layout after pad input (Platform).
var note: Label
## This locale's layout (_plan; English: the constants, one page).
var label_w := LABEL_WIDTH
var key_w := KEY_WIDTH
var columns_per_page := 2
var rows_per_page := 5
var rows_top := ROWS_TOP
## The rows' gap (ROW_GAP in English; GAP_S where 4 px gaps are what keeps five rows off two pages:
## pseudo, Vietnamese, whose rows then also start GAP_S under the title's box).
var row_gap := ROW_GAP
var note_top := NOTE_TOP
var note_lines := 1
var pages := 1
var page := 0
## The column grids, and the page button (null on one page).
var grids: Array[GridContainer] = []
var page_button: Button


## The label of a rebindable action. i18n: max 76px (labels are 84 wide), 1 line.
static func action_name(action: String) -> String:
	match action:
		"move_up": return Loc.t("keys.move_up", "MOVE UP")
		"move_down": return Loc.t("keys.move_down", "MOVE DOWN")
		"move_left": return Loc.t("keys.move_left", "MOVE LEFT")
		"move_right": return Loc.t("keys.move_right", "MOVE RIGHT")
		"jump": return Loc.t("keys.jump", "JUMP (HOLD)")
		"restart": return Loc.t("keys.restart", "RESTART LEVEL")
		"interact": return Loc.t("keys.interact", "INTERACT (HUB)")
		"ability_rifle": return Loc.t("keys.ability_rifle", "SLIME SNIPER")
		"ability_splat": return Loc.t("keys.ability_splat", "GOO GRENADE")
		"ability_kaze": return Loc.t("keys.ability_kaze", "SLIMAKAZE")  # pun: slime + kamikaze
		"ability_sense": return Loc.t("keys.ability_sense", "SLIME SENSE")
	return action


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("keys.title", "CONTROLS"))  # i18n: max 296px, 16 px font
	_plan()
	for c in COLUMNS.size():
		var rows := GridContainer.new()
		rows.columns = 2
		rows.add_theme_constant_override("h_separation", GAP)
		rows.add_theme_constant_override("v_separation", row_gap)
		add_child(rows)
		grids.append(rows)
		for action: String in COLUMNS[c]:
			var label := UIKit.make_label(action_name(action))
			label.custom_minimum_size = Vector2(label_w, UIKit.button_h())
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_level_with_keys(label)
			rows.add_child(label)
			var button := UIKit.make_button("", func() -> void: _start_rebind(action), Vector2(key_w, UIKit.button_h()))
			if columns_per_page == 1:  # (one column per page: as wide as PRESS KEY needs, whatever key it shows)
				UIKit.note_text_w(button, [press_key_text()], KEY_WIDTH)
			rows.add_child(button)
			key_buttons[action] = button
	_place_grids()
	# Arrows move between the columns too (a GridContainer per column has no neighbors across).
	for r in COLUMNS[0].size():
		var left: Button = key_buttons[COLUMNS[0][r]]
		var right: Button = key_buttons[COLUMNS[1][r]]
		if columns_per_page == 2:
			left.focus_neighbor_right = left.get_path_to(right)
			right.focus_neighbor_left = right.get_path_to(left)
		else:  # (one column per page: nothing beside a key)
			for button: Button in [left, right]:
				button.focus_neighbor_right = button.get_path_to(button)
				button.focus_neighbor_left = button.get_path_to(button)
	_refresh()
	key_buttons.move_up.grab_focus()
	note = UIKit.make_label(note_text(), UIKit.FONT, UIKit.TEXT_DIM)
	PlatformEvents.input_kind_changed.connect(func(_kind: String) -> void: note.text = note_text())
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	note.offset_top = note_top
	note.offset_bottom = note_top + _note_h(note_lines)
	if note_lines > 1:
		note.autowrap_mode = UIKit.autowrap_mode()
		note.offset_left = UIKit.EDGE
		note.offset_right = -UIKit.EDGE
	# i18n: max 90px (98 wide, 4 px margins), 1 line
	var reset_text := Loc.t("keys.reset", "RESET KEYS")
	reset_keys_button = UIKit.make_button(reset_text, _on_reset, UIKit.button_size(reset_text, 98))
	UIKit.note_text_w(reset_keys_button, [reset_text], 98)
	add_child(reset_keys_button)
	reset_keys_button.size = reset_keys_button.custom_minimum_size
	UIKit.place_bottom_row(reset_keys_button, 0)
	back_button = UIKit.add_back_button(self, _back)  # (back to SETTINGS)
	if pages > 1:
		page_button = UIKit.make_button(_page_text(), func() -> void: show_page((page + 1) % pages), back_button.custom_minimum_size)
		UIKit.note_text_w(page_button, [back_button.text], int(UIKit.BACK_SIZE.x))  # (BACK's mirror)
		add_child(page_button)
		page_button.size = page_button.custom_minimum_size
		UIKit.place_bottom_row(page_button, 1)
	show_page(0)


## An action label on the key button's text line: the theme puts a button's line UIKit.button_v_margins()
## under its top (under the accents' rows, the drip rows kept below), while a label centres it on the
## row, which left the labels 2 px (accented, Thai), 3 px (Vietnamese) or 1 px (Devanagari) above the
## key text beside them (fix pass F3b). The same margins as an empty style; English (3 / 3, the centre
## already): no change.
static func _level_with_keys(label: Label) -> void:
	var margins := UIKit.button_v_margins()
	if margins.x == floori((UIKit.button_h() - UIKit.line_h()) / 2.0):
		return
	var style := StyleBoxEmpty.new()
	style.content_margin_top = margins.x
	style.content_margin_bottom = margins.y
	label.add_theme_stylebox_override("normal", style)


## The note's height on `lines` lines (English: 10, the 7 px line and its drips).
static func _note_h(lines: int) -> int:
	return UIKit.text_block_h(lines) + (0 if UIKit.tall_script() else UIKit.TEXT_DRIP + 1)


## This locale's widths, rows and pages (English: the constants, everything on one page).
func _plan() -> void:
	var widest := 0
	for column: Array in COLUMNS:
		for action: String in column:
			widest = maxi(widest, UIKit.text_w(action_name(action)))
	var key_min := UIKit.button_w(press_key_text(), 0)
	var room := int(UIKit.SCREEN.x) - 2 * UIKit.EDGE
	# The widest label keeps GAP_L from its key (SALTAR (MANTÉN) was GAP 4 from SPACE and read as one
	# string) where the keys can narrow for it and both columns still fit; else GAP. English: its labels are
	# all GAP_L + shorter than LABEL_WIDTH, unchanged.
	label_w = maxi(LABEL_WIDTH, widest + UIKit.GAP_L - GAP)
	if 2 * (label_w + GAP + key_min) + COLUMN_GAP > room:
		label_w = maxi(LABEL_WIDTH, widest)
	key_w = KEY_WIDTH
	columns_per_page = 2
	if 2 * (label_w + GAP + key_w) + COLUMN_GAP > room:
		key_w = maxi(key_min, (room - COLUMN_GAP) / 2 - GAP - label_w)
		if 2 * (label_w + GAP + key_w) + COLUMN_GAP > room:
			columns_per_page = 1
			key_w = maxi(key_min, KEY_WIDTH)
	# (the note changes with the input in use: the pad layout's line counts too)
	var note_w := maxi(UIKit.text_w(note_text()), UIKit.text_w(Loc.t("keys.note.pad", "PAD: A LEAP - X USE - START PAUSE - B BACK")))
	note_lines = 1 if note_w <= room else 2
	var count: int = COLUMNS[0].size()
	var fit := 0
	# (gaps close to the scale's next step, one at a time: under the title, over the bottom row, between rows)
	# (paged anyway: the 4 px rows of the third option)
	var options := [[ROWS_TOP - UIKit.TITLE_Y - 20, NOTE_GAP, ROW_GAP], [UIKit.GAP_M, NOTE_GAP, ROW_GAP],
		[UIKit.GAP_M, UIKit.GAP_L, ROW_GAP], [UIKit.GAP_M, UIKit.GAP_L, UIKit.GAP_S], [UIKit.GAP_S, UIKit.GAP_L, UIKit.GAP_S]]
	for option: Array in options + [options[2]]:
		rows_top = UIKit.title_bottom() + option[0]
		note_top = UIKit.bottom_row_y() - option[1] - _note_h(note_lines)
		row_gap = option[2]
		fit = UIKit.row_budget(note_top - UIKit.GAP_M - rows_top, UIKit.button_h(), row_gap)
		if fit >= count:
			break
	var row_pages := ceili(count / float(maxi(1, fit)))
	rows_per_page = ceili(count / float(row_pages))
	pages = row_pages * (3 - columns_per_page)
	_spread(row_pages > 1)


## Where the rows and the note go in the room the plan left (fix pass F3b). English keeps the note
## NOTE_GAP over the bottom row (29 px under the rows, 14 over BACK). Rows on pages (3 + 2) leave a band
## under the first page's rows: they are centred between the title's line box and the note, as the
## level select centres its one paged row. When the note would sit closer to the rows than to the bottom
## row (the accented locales' taller rows: 3 px under them, 14 over BACK), it is centred between the two
## instead, at least GAP_M over the bottom row (Vietnamese: five rows fill the room, and the note's stacked
## marks sat on the last key's goo drops). Ink counted: the note's own marks over its line, its drips under it.
func _spread(paged: bool) -> void:
	var marks: int = UIKit.mark_rows(note_text())  # (this line's own marks)
	var rows_h := rows_per_page * UIKit.button_h() + (rows_per_page - 1) * row_gap
	if paged:
		rows_top = UIKit.title_bottom() + floori((note_top - marks - UIKit.title_bottom() - rows_h) / 2.0)
		return
	var rows_end := rows_top + rows_h
	var note_end := note_top + _note_h(note_lines)
	if note_top - marks - rows_end < UIKit.bottom_row_y() - note_end:
		var centred := rows_end + marks + floori((UIKit.bottom_row_y() - rows_end - marks - _note_h(note_lines)) / 2.0)
		note_top = mini(centred, UIKit.bottom_row_y() - UIKit.GAP_M - _note_h(note_lines))  # (GAP_M over the bottom row at least)


## Where the column grids sit: both side by side (one column per page: the same centred place).
func _place_grids() -> void:
	var column := label_w + GAP + key_w
	var total := columns_per_page * column + (columns_per_page - 1) * COLUMN_GAP
	var x := int(UIKit.center_x(total))  # 4 in English
	for c in grids.size():
		grids[c].position = Vector2(x + (c % columns_per_page) * (column + COLUMN_GAP), rows_top)


## Shows page `which` (0 on one page): its rows, both columns or (one column per page) one of them.
func show_page(which: int) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	page = which
	var row_pages := pages / (3 - columns_per_page)
	var first_row := (page % row_pages) * rows_per_page
	var shown_column := page / row_pages
	for c in grids.size():
		var rows := grids[c]
		var column_on := columns_per_page == 2 or c == shown_column
		for r in COLUMNS[c].size():
			var on: bool = column_on and r >= first_row and r < first_row + rows_per_page
			rows.get_child(2 * r).visible = on
			rows.get_child(2 * r + 1).visible = on
		rows.visible = column_on
		rows.size = Vector2.ZERO  # (shrinks to the shown rows)
	if page_button:
		page_button.text = _page_text()
		# (the page button keeps the focus it was pressed with; a key that went away hands it to the page's first key)
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			key_buttons[COLUMNS[shown_column if columns_per_page == 1 else 0][first_row]].grab_focus()


func _page_text() -> String:
	return "%d/%d" % [page + 1, pages]


## The fixed controls, for the device in use: the gamepad layout after pad input (not remappable yet), else the
## keys that always work (browsers keep Esc in fullscreen, so there P; F11 only where fullscreen exists).
static func note_text() -> String:
	# i18n: footer, one line, max 300px; pad button names (A X START B) stay as printed on the pad
	if Platform.using_pad():
		return Loc.t("keys.note.pad", "PAD: A LEAP - X USE - START PAUSE - B BACK")
	# i18n: footer, one line, max 300px; the key names (ESC, P, F11) are the keyboard's, not translated
	if not Platform.has_window_fullscreen():
		if Platform.is_web():
			return Loc.t("keys.note.web", "ARROWS ALWAYS MOVE - P PAUSES")
		return Loc.t("keys.note.desktop", "ARROWS ALWAYS MOVE - ESC OR P PAUSES")
	if Platform.is_web():
		return Loc.t("keys.note.web_f11", "ARROWS ALWAYS MOVE - P PAUSES - F11 FULLSCREEN")
	return Loc.t("keys.note.desktop_f11", "ARROWS ALWAYS MOVE - ESC OR P PAUSES - F11 FULLSCREEN")


func _back() -> void:
	UIKit.go(get_tree(), "res://scenes/controls.tscn")


func _refresh() -> void:
	for action: String in key_buttons:
		key_buttons[action].text = Progress.key_name(Progress.bindings[action])


func _start_rebind(action: String) -> void:
	waiting_for = action
	_refresh()
	key_buttons[action].text = press_key_text()


func _on_reset() -> void:
	waiting_for = ""
	Progress.reset_bindings()
	_refresh()


func _input(event: InputEvent) -> void:
	if waiting_for == "":
		return
	if not (event is InputEventKey) and (event is InputEventJoypadButton or event.is_action("menu") or event.is_action("ui_cancel")) \
			and event.is_pressed():
		# A gamepad (or the system back button) can't give a key: it cancels the wait instead of trapping it.
		get_viewport().set_input_as_handled()
		var waited := waiting_for
		waiting_for = ""
		_refresh()
		key_buttons[waited].grab_focus()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	# Esc and P are reserved for pausing (P because browsers keep Esc in fullscreen).
	if key.physical_keycode not in [KEY_ESCAPE, KEY_P, 0]:
		Progress.set_binding(waiting_for, key.physical_keycode)
	var action := waiting_for
	waiting_for = ""
	_refresh()
	key_buttons[action].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if waiting_for == "" and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		_back()


## Every text a key button shows that a player can't change (its own key names are short): PRESS KEY.
static func press_key_text() -> String:
	return Loc.t("keys.press_key", "PRESS KEY")  # i18n: max 56px (key buttons are 64 wide), grows to 120px (button_w: the key buttons widen, one column a page), 1 line
