extends CanvasLayer

## In-game pause menu (Esc): resume, restart, sound on/off, volume, quit to the title. In a
## randomizer maze it also shows the maze's SEED (press it to copy the number or type another
## one: that maze is rebuilt, the same for anyone with the seed). Runs while the tree is paused;
## everything else in the level freezes. In the SPLASHDOWN training maze QUIT TO HUB reads SKIP TRAINING:
## the training ends (Progress.finish_training(true), through game.leave_training) and the hub opens. That is
## the SETTINGS replay only: on the first run the button is hidden, so the maze is played to its chalice.

## The button column (100 wide, 13 px buttons 3 apart) on its panel, centered under PAUSED.
const PANEL_X := 100
const PANEL_W := 120
const COLUMN_W := 100
## The VOLUME box's rows past its label and slider: 6 + label + 6 + slider + 6 (UIKit.volume_slider_width).
const VOLUME_BOX_EXTRA := 18
## English's SEED text cutoff: the column less its 4 px text margins (kept from before BUTTON_TEXT_PAD).
const SEED_TEXT_MAX_EN := COLUMN_W - 8
const MENU_TOP := 63
## PAUSED's line box top (30 in English: under the HUD's first row of pods), and the gap from its box
## to the panel (MENU_TOP = 30 + 20 + 5 + PANEL_PAD).
const TITLE_Y := 30
const TITLE_TO_PANEL := 5
## The Descent note's line top (150 in English), and the lowest row anything may reach.
const NOTE_Y := 150
## English's rows from the Descent panel's bottom edge (four buttons: row 132) to the note's first ink
## (row 150): every language keeps them (a footnote, not a line squeezed under the panel's lumps).
const NOTE_ROOM := NOTE_Y - (MENU_TOP + 3 * UIKit.GAP_S + 4 * UIKit.BUTTON_H + UIKit.PANEL_PAD)
const BOTTOM := 176
## Two columns (a taller script's buttons that no longer fit one column): COLUMN_W each, GAP_L apart.
const COLUMN_GAP := UIKit.GAP_L

var buttons: Array[Button] = []
var wishlist_button: Button
var sound_button: Button
var volume_row: PanelContainer
## The button column's width: COLUMN_W, or wider for a VOLUME label that would leave the slider shorter
## than English's (fix pass R1, as the settings columns in R2: LAUTSTÄRKE left 22 px of slider).
var _col_w := COLUMN_W
var seed_button: Button
var seed_edit: LineEdit
var _panel: Panel
## DESCENT: RESTART is hidden (a floor can't be replayed: the meter carries over) and this line says
## what QUIT TO HUB does to the run (mid-floor: banks half the pot; on the boon card: cashes out).
var restart_button: Button
var descent_note: Label
## Dev mode only (built only then): FULL BRIGHT, NO DRAIN and PASTEL switches (Game.set_dev_bright /
## set_dev_no_drain, also F1 / F2 in the level; Game.set_dev_pastel), on their own panel to the right.
var dev_panel: Control
var bright_button: Button
var drain_button: Button
var pastel_button: Button
var dev_map_button: Button
var dev_drain_button: Button
## What had keyboard focus when the menu opened (e.g. a dry-up / win choice): it gets it back on
## resume. And the level's controls kept out of focus while the menu is open (UIKit.lock_focus).
var _return_focus: Control
var _focus_lock := {}
var _title: Label
var _menu: GridContainer
var _last_row: VBoxContainer
var _last_index := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.theme = UIKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# i18n: max 110px, 16 px font
	var title := UIKit.make_label(Loc.t("pause.title", "PAUSED"), UIKit.FONT_BIG, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, _title_y())
	title.size = Vector2(320, UIKit.title_h())
	root.add_child(title)
	_title = title

	_col_w = _column_w(root)
	_panel = UIKit.add_panel(root, Rect2(PANEL_X, MENU_TOP - UIKit.PANEL_PAD, PANEL_W, 0))
	var menu := GridContainer.new()
	menu.columns = 1
	menu.position = Vector2(PANEL_X + 10, MENU_TOP)
	menu.custom_minimum_size = Vector2(_col_w, 0)
	menu.add_theme_constant_override("v_separation", UIKit.GAP_S)
	menu.add_theme_constant_override("h_separation", COLUMN_GAP)
	root.add_child(menu)
	_menu = menu
	sound_button = UIKit.make_button("", _toggle_sound)
	restart_button = UIKit.make_button(Loc.t("pause.restart", "RESTART"), _restart)
	buttons = [
		UIKit.make_button(Loc.t("pause.resume", "RESUME"), resume),
		restart_button,
		sound_button,
		UIKit.make_button(Loc.t("pause.quit_hub", "QUIT TO HUB"), _quit),
	]
	for button in buttons:
		menu.add_child(button)
	volume_row = UIKit.make_volume_slider(UIKit.volume_slider_width(root, _col_w, ["sfx"]))  # 6 + SFX + 6 + slider + 6 = the 100 px button column (levels play no music: only the SFX slider here)
	menu.add_child(volume_row)
	menu.move_child(volume_row, 3)
	seed_button = UIKit.make_button("", _edit_seed)
	seed_button.visible = false
	menu.add_child(seed_button)
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(100, UIKit.button_h())
	seed_edit.max_length = 13
	seed_edit.placeholder_text = Loc.t("pause.new_seed", "NEW SEED")  # i18n: max 92px, 1 line
	seed_edit.add_theme_font_size_override("font_size", UIKit.FONT)
	seed_edit.material = UIKit.text_material()
	UIKit.add_touch_target(seed_edit)
	seed_edit.visible = false
	seed_edit.text_submitted.connect(_submit_seed)
	seed_edit.focus_exited.connect(func() -> void: _refocus.call_deferred())
	menu.add_child(seed_edit)
	# The demo's quiet WISHLIST (only with a store page to open: Demo.store_url()).
	# i18n: pause menu button (demo build, opens the store page), max 92px, 1 line
	wishlist_button = UIKit.make_button(Loc.t("demo.wishlist", "WISHLIST"), Demo.open_wishlist)
	wishlist_button.visible = false
	menu.add_child(wishlist_button)
	descent_note = UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	descent_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	descent_note.position = Vector2(0, NOTE_Y)
	descent_note.size = Vector2(320, 10)
	descent_note.visible = false
	root.add_child(descent_note)
	_refresh_sound()
	var progress := get_node_or_null("/root/Progress")
	if progress and progress.dev_tools:
		_build_dev_panel(root)
	UIKit.add_skin_text(root)
	UIKit.mirror_root(root)  # (right-to-left languages: flipped once built, docs/ui-rules.md 10.2)


func _build_dev_panel(root: Control) -> void:
	dev_panel = UIKit.add_panel(root, Rect2(320 - UIKit.EDGE - 88, MENU_TOP - UIKit.PANEL_PAD, 88, 66))
	var column := VBoxContainer.new()
	column.position = dev_panel.position + Vector2(6, 5)
	column.custom_minimum_size = Vector2(76, 0)
	column.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(column)
	var title := UIKit.make_label("DEV (F1 / F2)", UIKit.FONT, UIKit.TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	bright_button = UIKit.make_button("", func() -> void: _dev_toggle("set_dev_bright", "dev_bright"))
	drain_button = UIKit.make_button("", func() -> void: _dev_toggle("set_dev_no_drain", "dev_no_drain"))
	column.add_child(bright_button)
	pastel_button = UIKit.make_button("", func() -> void: _dev_pastel())
	column.add_child(drain_button)
	column.add_child(pastel_button)
	# MAP: this maze's map (the whole of it with BRIGHT on); DRAIN: empty the meter now (a dry-up).
	dev_map_button = UIKit.make_button("MAP", _dev_map)  # i18n: ignore (dev mode only panel)
	column.add_child(dev_map_button)
	dev_drain_button = UIKit.make_button("DRAIN NOW", _dev_drain)  # i18n: ignore (dev mode only panel)
	column.add_child(dev_drain_button)
	dev_panel.size.y = 5 + column.get_combined_minimum_size().y + 5
	_refresh_dev()


func _dev_map() -> void:
	var game := get_parent()
	if game.has_method("open_dev_map"):
		game.open_dev_map()


func _dev_drain() -> void:
	var game := get_parent()
	if game.has_method("dev_drain"):
		resume()
		game.dev_drain()


func _dev_toggle(setter: String, flag: String) -> void:
	var game := get_parent()
	if game.has_method(setter):
		game.call(setter, not game.get(flag))
	_refresh_dev()


func _dev_pastel() -> void:
	var game := get_parent()
	if game.has_method("set_dev_pastel"):
		game.set_dev_pastel(not Skins.pastel)
	_refresh_dev()


func _refresh_dev() -> void:
	if dev_panel == null:
		return
	var game := get_parent()
	var bright: bool = game.get("dev_bright") == true
	var no_drain: bool = game.get("dev_no_drain") == true
	bright_button.text = "BRIGHT: " + ("ON" if bright else "OFF")
	drain_button.text = "NO DRAIN: " + ("ON" if no_drain else "OFF")  # i18n: ignore (dev mode only panel)
	pastel_button.text = "PASTEL: " + ("ON" if Skins.pastel else "OFF")  # i18n: ignore (dev mode only panel)


func open() -> void:
	UIKit.relayout(_menu)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	visible = true
	var game := get_parent()
	var random: bool = game.has_method("is_random") and game.is_random()
	seed_button.visible = random and not Demo.on()  # (the demo deals its own new random mazes: no typed seeds)
	wishlist_button.visible = Demo.wishlist_shown()
	seed_edit.visible = false
	var hud: Node = game.get("hud")
	if hud and hud.has_method("cover_area_texts"):
		hud.cover_area_texts()  # (they would show through around PAUSED; back on close)
	# i18n: pause menu button, max 92px, 1 line (the training maze's QUIT TO HUB: leaves the tutorial maze)
	buttons[3].text = Loc.t("pause.skip_training", "SKIP TRAINING") if _training() else Loc.t("pause.quit_hub", "QUIT TO HUB")
	# The first training run can't be left early (owner, 2026-10-27): no SKIP TRAINING; the SETTINGS replay keeps it.
	var locked := _training_locked()
	buttons[3].visible = not locked
	var descent: bool = game.get("descent") == true
	restart_button.visible = not descent
	descent_note.visible = false
	var progress := get_node_or_null("/root/Progress")
	if descent and progress and progress.descent_active():
		descent_note.visible = true
		# i18n: max 300px, 1 line, under the panel
		descent_note.text = Loc.t("pause.quit_cashes", "QUITTING CASHES OUT THE POT") if game.won else Loc.t("pause.quit_banks", "QUITTING BANKS HALF THE POT")
	_layout(5 + (1 if seed_button.visible else 0) - (1 if descent else 0) + (1 if wishlist_button.visible else 0) - (1 if locked else 0), hud)
	if random:
		seed_button.text = seed_text(Levels.seed_code(game.random_seed, game.seed_level))
	get_tree().paused = true
	_refresh_sound()
	_refresh_dev()
	var owner_now := get_viewport().gui_get_focus_owner()
	_return_focus = owner_now if owner_now and not is_ancestor_of(owner_now) else null
	buttons[0].grab_focus()
	if _focus_lock.is_empty():
		_focus_lock = UIKit.lock_focus(get_parent(), self)
	_sfx("pause")


## Lays the menu out for `count` buttons (docs/ui-rules.md section 10): PAUSED, then the panel
## PANEL_PAD around the stack, in one column at MENU_TOP in English; a taller script whose column no
## longer fits above the bottom row (and the Descent note) gets two columns of COLUMN_W on a wider
## panel. PAUSED keeps clear of the HUD pods beside it (a long translation steps down to the 8 px
## font), and the Descent note sits at NOTE_Y or NOTE_ROOM under the panel (its first ink). With the
## note, PAUSED's room over its line box is its own letters' marks (PAUSE, PAUSA: none), not the
## locale's; where one column still leaves the note less than NOTE_ROOM, the panel goes TITLE_TO_PANEL
## under the title's ink instead of its line box, then a taller script's title rises until its first
## ink is on TITLE_Y (English's first ink row; CJK: 6 empty rows on top), then two columns.
func _layout(count: int, hud: Node) -> void:
	var title_y := _title_slot(hud)
	var menu_top := title_y + UIKit.title_h() + TITLE_TO_PANEL + UIKit.PANEL_PAD  # MENU_TOP in English
	var note_h := UIKit.line_h() + int(UIKit.metrics().ink_below) + int(UIKit.metrics().ink_above) + UIKit.GAP_M if descent_note.visible else 0
	var columns := 1
	if menu_top + _stack_h(count, 1) + UIKit.PANEL_PAD > BOTTOM - note_h:
		columns = 2
	elif descent_note.visible:
		var ink := _note_ink()
		var lowest_panel_end := BOTTOM - NOTE_ROOM + ink.x - ink.y  # (the note's last ink on BOTTOM at the most)
		var title_texts: Array[String] = [_title.text]
		var font := _title.get_theme_font("font")
		var own := _title_slot(hud, true)
		var plans: Array[Vector2i] = [Vector2i(own, own + UIKit.title_h() + TITLE_TO_PANEL + UIKit.PANEL_PAD)]
		# (the title's last ink row, its shadow included, under its line top)
		var ink_end := UIKit.title_ink_end(title_texts, font) - UIKit.title_top()
		plans.append(Vector2i(own, own + ink_end + 1 + TITLE_TO_PANEL + UIKit.PANEL_PAD))
		if UIKit.tall_script():
			var lifted := _title_slot(hud, true, UIKit.ink_rows(title_texts, font, UIKit.FONT_BIG).x)
			plans.append(Vector2i(lifted, lifted + ink_end + 1 + TITLE_TO_PANEL + UIKit.PANEL_PAD))
		columns = 2
		for plan in plans:
			if plan.y + _stack_h(count, 1) + UIKit.PANEL_PAD <= lowest_panel_end:
				title_y = plan.x
				menu_top = plan.y
				columns = 1
				break
	_menu.columns = columns
	# Two columns and an odd count: the last button sits alone, centred under the pairs (_last_row).
	if _last_row and _last_row.get_child_count() > 0:
		var back_in: Control = _last_row.get_child(0)
		_last_row.remove_child(back_in)
		_menu.add_child(back_in)
		_menu.move_child(back_in, _last_index)
	if _last_row:
		_last_row.visible = false
	if columns == 2 and count % 2 == 1:
		if _last_row == null:  # (made only when needed: a new node made earlier would reseed every goo lump after it)
			_last_row = VBoxContainer.new()
			_menu.get_parent().add_child(_last_row)
		var shown := _menu.get_children().filter(func(c: Node) -> bool: return (c as Control).visible)
		var last: Control = shown[-1]
		_last_index = last.get_index()
		_menu.remove_child(last)
		_last_row.add_child(last)
		_last_row.visible = true
	var width := _col_w * columns + COLUMN_GAP * (columns - 1)
	var panel_w := PANEL_W + width - COLUMN_W
	var panel_x := UIKit.center_x(panel_w)  # PANEL_X in English
	# A wider panel keeps GAP_XS under the HUD pods it would reach (when the bottom has the room).
	if hud and hud.has_method("pod_rects"):
		var lowest := 0.0
		for pod: Rect2 in hud.pod_rects():
			if pod.position.x < panel_x + panel_w and pod.end.x > panel_x:
				lowest = maxf(lowest, pod.end.y + UIKit.GAP_XS)
		var room := BOTTOM - note_h - UIKit.PANEL_PAD - _stack_h(count, columns)
		if menu_top - UIKit.PANEL_PAD < lowest and lowest + UIKit.PANEL_PAD <= room:
			menu_top = int(lowest) + UIKit.PANEL_PAD
	_menu.position = Vector2(panel_x + (panel_w - width) / 2.0, menu_top)
	_menu.custom_minimum_size = Vector2(width, 0) if columns == 1 else Vector2.ZERO
	for child in _menu.get_children():
		(child as Control).custom_minimum_size.x = _col_w if columns > 1 else (child as Control).custom_minimum_size.x
		if _col_w > COLUMN_W and child is Button:  # (wider than English for the VOLUME box: noted, docs/ui-rules.md 10.1)
			UIKit.note_text_w(child, [(child as Button).text], _col_w)
	_menu.size = Vector2.ZERO
	if _last_row and _last_row.visible:
		var rows := ceili(count / 2.0)
		_last_row.position = Vector2(UIKit.center_x(_col_w), menu_top + (rows - 1) * (UIKit.button_h() + UIKit.GAP_S))
		_last_row.size = Vector2(_col_w, UIKit.button_h())
	_panel.position = Vector2(panel_x, menu_top - UIKit.PANEL_PAD)
	_panel.size = Vector2(panel_w, UIKit.PANEL_PAD * 2 + _stack_h(count, columns))
	var panel_bottom := int(_panel.position.y + _panel.size.y)
	var note_ink := _note_ink()
	descent_note.position.y = clampi(maxi(NOTE_Y, panel_bottom + NOTE_ROOM - note_ink.x), 0, BOTTOM - note_ink.y)
	_title.position = Vector2(0, title_y)
	_title.size = Vector2(UIKit.SCREEN.x, UIKit.title_h())


## The Descent note's first and last inked rows from its line top: the marks its own letters carry over
## the line box and the drips under it (slimy font), or the script's ink (Language ink_top / ink_bottom).
func _note_ink() -> Vector2i:
	var m := UIKit.metrics()
	if UIKit.tall_script():
		return Vector2i(int(m.ink_top), int(m.ink_bottom))
	return Vector2i(-UIKit.ink_above(descent_note.text), UIKit.line_h() + int(m.ink_below) - 1)


## PAUSED's line box top: _title_y(), or GAP_XS under the HUD pods beside it when the title (a long
## translation, or a pod grown by one) would not fit between their columns. With `own_marks`, the title's
## own marks set its room over the line box (UIKit.mark_rows: 0 for PAUSE) instead of the locale's; `lift`
## raises the line box by that many of its empty top rows (a taller script's glyphs start under its top).
func _title_slot(hud: Node, own_marks := false, lift := 0) -> int:
	var above := int(UIKit.metrics().title_above)  # (the accents' rows over the line box)
	if own_marks and not UIKit.tall_script():
		above = UIKit.mark_rows(_title.text, UIKit.FONT_BIG)
	var y := _title_y() - int(UIKit.metrics().title_above) + above - lift
	if hud == null or not hud.has_method("pod_rects"):
		return y
	var pods: Array[Rect2] = hud.pod_rects()
	var title_w := UIKit.text_w(_title.text, UIKit.FONT_BIG)
	for i in pods.size():  # (each step moves under one more pod)
		var margin := 0.0
		var lowest := float(y)
		for pod: Rect2 in pods:
			if pod.position.y < y + UIKit.title_h() and pod.end.y + UIKit.GAP_XS > y - above:
				var left := pod.get_center().x < UIKit.SCREEN.x / 2.0
				margin = maxf(margin, pod.end.x + UIKit.GAP_XS if left else UIKit.SCREEN.x - pod.position.x + UIKit.GAP_XS)
				lowest = maxf(lowest, pod.end.y + UIKit.GAP_XS + above)
		if title_w <= UIKit.SCREEN.x - 2.0 * margin:
			return y
		y = int(lowest)
	return y


## The button column's width (COLUMN_W in English): wide enough for the VOLUME label and a slider as long
## as English's (COLUMN_W - VOLUME_BOX_EXTRA - VOLUME), while two such columns still fit inside EDGE.
func _column_w(root: Control) -> int:
	var english := COLUMN_W - VOLUME_BOX_EXTRA - ceili(UIKit.font_for(UIKit.FONT).get_string_size("VOLUME", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FONT).x)  # i18n: ignore (English's label, measured for its slider length)
	var label := COLUMN_W - VOLUME_BOX_EXTRA - int(floorf(UIKit.volume_slider_width(root, COLUMN_W, ["sfx"])))
	var widest := floori((UIKit.SCREEN.x - 2 * UIKit.EDGE - (PANEL_W - COLUMN_W) - COLUMN_GAP) / 2.0)
	return clampi(VOLUME_BOX_EXTRA + label + english, COLUMN_W, widest)


## The button stack's height for `count` buttons in `columns` columns.
func _stack_h(count: int, columns: int) -> int:
	var rows := ceili(count / float(columns))
	return rows * UIKit.button_h() + (rows - 1) * UIKit.GAP_S


## PAUSED's line box top: TITLE_Y, lower by the title's accent room.
func _title_y() -> int:
	return TITLE_Y + UIKit.title_top() - UIKit.TITLE_Y


func resume() -> void:
	visible = false
	get_tree().paused = false
	var hud: Node = get_parent().get("hud")
	if hud and hud.has_method("uncover_area_texts"):
		hud.uncover_area_texts()
	UIKit.unlock_focus(_focus_lock)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()  # e.g. the dry-up / win choice that had it
	_return_focus = null


## Esc in the seed box only stops editing it (the LineEdit takes the first Esc; the next one closes
## the box): if that leaves nothing focused, RESUME gets it so keys and the controller still work.
func _refocus() -> void:
	if visible and is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		buttons[0].grab_focus()


## The SEED button's text: "SEED 123-4", or just the code when that would not fit the column with
## the button's text margins: English keeps its 4 px each side (SEED_TEXT_MAX_EN, 92 px), a translation
## UIKit.BUTTON_TEXT_PAD (90 px; `시드 1453026489-0` filled the button to 1 clear column each side).
## A 10-digit seed: "SEED 4294967295-7" is 102 px, so it shows the code alone in every language.
func seed_text(code: String) -> String:
	var font: Font = seed_button.get_theme_font("font")
	# i18n: {code} = a seed code like 123-4 (up to 17 chars); max 92px, else the code alone is shown
	var text := Loc.t("pause.seed", "SEED {code}", {code = code})
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > seed_text_max():
		return code
	return text


## The widest SEED text that still shows "SEED": English's old 92 px, a translation's 90 px.
static func seed_text_max() -> int:
	if UIKit.locale() == UIKit.Lang.SOURCE_LOCALE:
		return SEED_TEXT_MAX_EN
	return COLUMN_W - 2 * UIKit.BUTTON_TEXT_PAD


## The seed button: swaps to a box holding the seed (selected, so it can be copied) to type over.
func _edit_seed() -> void:
	seed_edit.text = Levels.seed_code(get_parent().random_seed, get_parent().seed_level)
	seed_button.visible = false
	seed_edit.visible = true
	seed_edit.grab_focus()
	seed_edit.select_all()


## A seed typed in: rebuilds that maze (the same one for everybody with that number). Anything
## that isn't a seed (empty, letters, 0) just closes the box.
func _submit_seed(text: String) -> void:
	var code := Levels.parse_seed_code(text)
	var value := code.x
	if value == 0:
		seed_edit.visible = false
		seed_button.visible = true
		seed_button.grab_focus()
		return
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.random_seed = value
		progress.random_level = code.y  # -1 (a plain number): the game uses the player's own level
		progress.random_seed_fresh = false  # a typed seed pays at most 1 ticket
	resume()
	DevLog.route(get_tree(), "typed seed", get_parent())
	get_tree().reload_current_scene()


## The seed number from text (a plain number or a "12345-2" code): 1 to 2,000,000,000 (what the
## randomizer picks from), else 0. A typed code keeps its MORE SLIME level (see Levels.parse_seed_code).
static func parse_seed(text: String) -> int:
	return Levels.parse_seed_code(text).x


func _restart() -> void:
	resume()
	if _training():
		get_parent().retry("pause RESTART")  # i18n: ignore (DevLog route name; the next training attempt: full meter, the coin kept)
		return
	DevLog.route(get_tree(), "pause RESTART", get_parent())
	get_tree().reload_current_scene()


## True when the menu is over the SPLASHDOWN training maze (game.gd `training`).
func _training() -> bool:
	return get_parent().get("training") == true


## True over the first (not replayed) training run: SKIP TRAINING is hidden and does nothing.
func _training_locked() -> bool:
	var progress := get_node_or_null("/root/Progress")
	return _training() and not (progress != null and progress.training_replay)


func _quit() -> void:
	if _training_locked():
		return
	var training := _training()
	DevLog.log_event(get_tree(), "skip training (pause)" if training else "quit to hub (pause)", get_parent())
	if get_parent().has_method("quit_descent"):
		get_parent().quit_descent()  # DESCENT: the run is banked as it stands (see game.quit_descent)
	var transition := get_node_or_null("/root/Transition")
	var target := UIKit.HUB_SCENE
	if get_parent().get("preview") == true:
		target = get_parent().preview_exit()  # (the demo's preview maze: QUIT goes on to the end screen)
	if training:
		if transition != null and transition.busy:
			return  # a screen change is already underway (the win row's HUB): the training ends once
		target = get_parent().leave_training(true)
	if transition == null or transition.busy:
		resume()
		UIKit.go(get_tree(), target)
		return
	# The level stays paused under the wipe (Transition.go unpauses as it swaps the scene): nothing
	# runs meanwhile, no win or dry-up can happen and the result buttons can't be pressed.
	visible = false
	_return_focus = null
	UIKit.go(get_tree(), target)


func _toggle_sound() -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.sound_on = not progress.sound_on
		progress.save_progress()
	_refresh_sound()


func _refresh_sound() -> void:
	var progress := get_node_or_null("/root/Progress")
	# i18n: max 92px, 1 line; the two states are whole strings
	if not progress or progress.sound_on:
		sound_button.text = Loc.t("settings.sound.on", "SOUND: ON")
	else:
		sound_button.text = Loc.t("settings.sound.off", "SOUND: OFF")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if seed_edit.visible:  # Esc first closes the seed box
			_submit_seed("")
		else:
			resume()


## Touch / web: tapping or clicking anywhere outside the seed box closes it (like Esc).
func _input(event: InputEvent) -> void:
	if not (visible and seed_edit.visible):
		return
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if pressed and not seed_edit.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		_submit_seed("")


func _sfx(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name)
