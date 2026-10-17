extends "res://tests/suite_base.gd"

## Layout of the hub's overlays, the hat wheel, the restart prompt and the Descent card in every
## language (i18n chunk G3, docs/ui-rules.md section 10), measured from the nodes:
## - English (gate off): the panels keep their English rects (QUIT_PANEL, PORTAL_PANEL, RESUME_PANEL,
##   BOARD), the prompt its bottom edge, the SHOP one page of 138 x 13 tiles, the wheel CENTER / RADIUS.
## - Every locale but Arabic (mirrored by chunk I): each panel inside the screen; every text's line box
##   inside its panel / tile, never over another text or a button; paired buttons equal, fitting their
##   words, mirrored in their panel; the coin board's rows clear of each other (two columns when ten
##   rows don't fit); the hat wheel's header on one text row, the wheel between the header and the
##   result line, the SHOP's tiles above the status lines, every item on exactly one page; the restart
##   prompt's panel under its title; the Descent tiles' lines inside their tiles, the status line above
##   the buttons, the summary panel above its buttons.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_i18n_hub_layout.gd

const Lang := preload("res://scripts/language.gd")
const SCREEN := Rect2(0, 0, 320, 180)

var progress: Node
var language: Node
var _code := "en"


func _initialize() -> void:
	Economy.descent_force = 1  # (Descent is off in the game, D11; its screens are still laid out)
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	_code = "gate off"
	await _hub(true)
	await _game(true)
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in ["en"] + Lang.codes().slice(1) + [Lang.PSEUDO]:
		if code == "ar":
			continue  # (right-to-left: chunk I)
		_code = code
		language.set_locale(code)
		await _hub(code == "en")
		await _game(code == "en")
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	_result()
	quit(1 if failures else 0)


# ------------------------------------------------------------------ the hub

func _hub(english: bool) -> void:
	seed(20261017)
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await _frames(3)
	hub.set_physics_process(false)
	hub.set_process(false)
	for station: Dictionary in hub.stations:
		hub.near = station
		hub._show_prompt()
		var r := _rect(hub.prompt)
		# (English's bottom edge, row 174; a taller prompt grows down first, to 3 rows above the screen's
		# bottom, keeping its top on English's row 156 as long as it can, then up)
		var bottom: float = hub.PROMPT_Y + hub.PROMPT_H
		if r.size.y > hub.PROMPT_H:
			bottom = minf(hub.PROMPT_Y + r.size.y, 180.0 - hub.PROMPT_LOW)
		_check(SCREEN.encloses(r) and r.end.y == bottom and r.end.y + 2 <= 180.0 and absf(r.get_center().x - 160.0) <= 0.5,
			"%s: prompt %s centred, inside the screen (its drops too), bottom edge on row %d" % [_code, station.id, bottom])
	hub.near = {}
	hub._show_prompt()

	hub.open_quit_menu()
	await _frames(1)
	_dialog(hub.quit_menu, [hub.quit_button, hub.back_button], "quit")
	if english:
		_check(_panel_rect(hub.quit_menu) == hub.QUIT_PANEL, "%s: quit panel is QUIT_PANEL" % _code)
	hub.close_quit_menu()

	hub.open_portal_menu()
	await _frames(1)
	_dialog(hub.portal_menu, [hub.maze_button, hub.descent_button], "portal", false)
	var panel := _panel_rect(hub.portal_menu)
	for b: Button in [hub.maze_button, hub.descent_button, hub.portal_back]:
		_check(absf(_rect(b).get_center().x - panel.get_center().x) <= 0.5, "%s: portal %s centred in the panel" % [_code, b.text])
	_check(_rect(hub.portal_back).end.y == panel.end.y - UIKit.PANEL_PAD, "%s: portal BACK PANEL_PAD above the bottom" % _code)
	if english:
		_check(panel == hub.PORTAL_PANEL, "%s: portal panel is PORTAL_PANEL" % _code)
	hub.close_portal_menu()

	progress.descent_resume = {seed = 5, floor = 12, cleared = 11, meter = 50.0, boons = {}, bladders = 0, pot = 30, time = 600.0,
		wind_used = false, slot = 1, bonuses = [], new_best = false, best_before = 0}
	hub.open_resume_menu()
	await _frames(1)
	_dialog(hub.resume_menu, [hub.resume_button, hub.resume_quit], "resume")
	if english:
		_check(_panel_rect(hub.resume_menu) == hub.RESUME_PANEL, "%s: resume panel is RESUME_PANEL" % _code)
	hub.close_resume_menu()
	progress.descent_resume = {}

	hub.open_coin_board()
	await _frames(1)
	_coin_board(hub, english)
	hub.close_coin_board()

	hub.open_hat_wheel()
	await _frames(1)
	await _hat_wheel(hub.hat_wheel, english)
	hub.free()


## A dialog: its panel inside the screen (EDGE in), its texts inside the panel and clear of each
## other and of the buttons, the buttons fitting their words, inside the panel, PANEL_PAD above its
## bottom; `pair`: equal widths, mirrored insets.
func _dialog(menu: Control, buttons: Array, tag: String, pair := true) -> void:
	var panel := _panel_rect(menu)
	_check(SCREEN.grow(-UIKit.EDGE).encloses(panel), "%s: %s panel %s inside the screen" % [_code, tag, panel])
	var texts := _texts(menu)
	_inside(texts, panel, "%s %s" % [_code, tag])
	_apart(texts, _buttons(menu), "%s %s" % [_code, tag])
	for b: Button in buttons:
		_check(_rect(b).size.x >= UIKit.text_w(b.text) + 2 * UIKit.BUTTON_TEXT_PAD and _rect(b).size.y == UIKit.button_h(),
			"%s: %s button %s fits its word, button_h() tall" % [_code, tag, b.text])
	if pair:
		var a := _rect(buttons[0])
		var b := _rect(buttons[1])
		_check(a.size == b.size and a.position.x - panel.position.x == panel.end.x - b.end.x and a.position.y == b.position.y
			and a.end.y == panel.end.y - UIKit.PANEL_PAD,
			"%s: %s buttons equal, mirrored, PANEL_PAD above the bottom (%s / %s in %s)" % [_code, tag, a, b, panel])


func _coin_board(hub: Node, english: bool) -> void:
	var panel := _panel_rect(hub.coin_board)
	_check(SCREEN.grow(-UIKit.EDGE).encloses(panel), "%s: coin board %s inside the screen" % [_code, panel])
	if english:
		_check(panel == hub.BOARD, "%s: coin board is BOARD" % _code)
	var texts := _texts(hub.coin_board)
	_inside(texts, panel, "%s coin board" % _code)
	_apart(texts, [], "%s coin board" % _code)
	var columns := {}
	for i in Levels.COUNT:
		var name_box := _text_box(hub.board_names[i])
		var count_box := _text_box(hub.board_rows[i])
		var icon := _rect(hub.board_icons[i])
		columns[hub.board_numbers[i].position.x] = true
		_check(name_box.end.x <= count_box.position.x - 2 and count_box.end.x <= icon.position.x and panel.encloses(icon),
			"%s: coin board row %d: name, count, coin in order inside the board" % [_code, i + 1])
	# (one column when title, ten rows, total and hint fit 172 px with GAP_M under the hint: hub.gd)
	var one_column := 7 + UIKit.line_h() + 7 + UIKit.dense_pitch() * Levels.COUNT + 2 + UIKit.line_pitch() + UIKit.line_h() + UIKit.GAP_M <= 172
	_check(columns.size() == (1 if one_column else 2), "%s: coin board in %d column(s)" % [_code, columns.size()])


func _hat_wheel(wheel: Control, english: bool) -> void:
	for tab in ["wheel", "shop"]:
		wheel.show_tab(tab)
		await _frames(1)
		var panel: Rect2 = wheel.PANEL
		var text_y := _rect(wheel.wheel_tab).position.y + UIKit.button_v_margins().x
		_check(_rect(wheel.title).position.y == text_y and _rect(wheel.balance).position.y == text_y,
			"%s: hat wheel %s: tabs, title and balance on one text row" % [_code, tab])
		_check(_rect(wheel.wheel_tab).size == _rect(wheel.shop_tab).size and _rect(wheel.wheel_tab).size.x >= UIKit.text_w(wheel.shop_tab.text) + 8
			and _rect(wheel.wheel_tab).size.x >= UIKit.text_w(wheel.wheel_tab.text) + 8, "%s: hat wheel tabs equal, fitting their words" % _code)
		var header := [wheel.wheel_tab, wheel.shop_tab]
		if wheel.title.visible:
			_apart([_text_box(wheel.title)], header.map(_rect), "%s hat wheel %s title" % [_code, tab])
		if tab == "wheel":
			var c: Vector2 = wheel.wheel_center
			var r: float = wheel.wheel_radius
			var top := _rect(wheel.wheel_tab).end.y
			_check(c.y - r - 10.0 >= top and c.y + r + 4.0 <= _text_box(wheel.result).position.y, "%s: the wheel between the header and the result line" % _code)
			_check(_text_box(wheel.result).end.y <= _rect(wheel.spin_button).position.y and panel.encloses(_rect(wheel.spin_button))
				and _rect(wheel.spin_button).size.x >= UIKit.text_w(wheel.spin_button.text) + 8, "%s: SPIN under the result line, fitting its text" % _code)
			if english:
				_check(c == wheel.CENTER and r == wheel.RADIUS, "%s: the wheel at CENTER, RADIUS" % _code)
			continue
		for section: String in wheel.SECTIONS:
			wheel.show_section(section, false)
			await _frames(1)
			var ids: Array[String] = wheel._section_ids()
			var seen := {}
			for p in wheel.pages:
				wheel._show_page(p, ids)
				var tiles: Array = []
				for id: String in ids:
					var tile: Button = wheel.shop_tiles[id]
					if tile.visible:
						seen[id] = seen.get(id, 0) + 1
						tiles.append(_rect(tile))
						_check(tile.size.x >= 4 + 3 + 4 + _min_name_w(wheel, id), "%s: %s tile %s holds its name" % [_code, section, id])
				var ok := true
				for i in tiles.size():
					ok = ok and panel.grow(-UIKit.GAP_M).encloses(tiles[i]) and tiles[i].end.y <= wheel.status_y - UIKit.GAP_XS
					for j in range(i + 1, tiles.size()):
						ok = ok and not tiles[i].intersects(tiles[j])
				_check(ok, "%s: %s page %d: tiles inside the panel, above the status lines, apart" % [_code, section, p])
			_check(seen.size() == ids.size() and seen.values().all(func(n: int) -> bool: return n == 1), "%s: %s: every item on exactly one page" % [_code, section])
			if wheel.pages > 1:
				# Down from the first page's last row turns to the next page, up from its first row back.
				wheel._show_page(0, ids)
				var last: Button = wheel.shop_tiles[ids[wheel.rows_per_page * 2 - 2]]
				last.grab_focus()
				var down := InputEventAction.new()
				down.action = "ui_down"
				down.pressed = true
				wheel._on_tile_input(down, last)
				var focused := root.gui_get_focus_owner()
				_check(wheel.page == 1 and focused != null and focused.visible, "%s: %s: down past the last row shows page 2" % [_code, section])
				var up := InputEventAction.new()
				up.action = "ui_up"
				up.pressed = true
				wheel._on_tile_input(up, focused)
				_check(wheel.page == 0, "%s: %s: up past page 2's first row shows page 1" % [_code, section])
				_check(wheel.prev_page.visible and wheel.next_page.visible and _rect(wheel.prev_page).end.x <= _rect(wheel.section_buttons.hats).position.x
					and _rect(wheel.next_page).position.x >= _rect(wheel.section_buttons.papers).end.x, "%s: PREV / NEXT either side of the section row" % _code)
			if english:
				_check(wheel.pages == 1 and wheel.tile_size == wheel.TILE, "%s: %s: one page of TILE tiles" % [_code, section])
			_inside([_text_box(wheel.status), _text_box(wheel.status_line)], panel, "%s %s status" % [_code, section])
		wheel.show_section("hats", false)


## The narrowest a tile's name can be shown: its text, or its longest word when it wraps.
func _min_name_w(wheel: Control, id: String) -> int:
	var name: String = wheel._name_of(id)
	if not wheel._two_line_names:
		return UIKit.text_w(name)
	var w := 0
	for word in name.split(" "):
		w = maxi(w, UIKit.text_w(word))
	return w


# ------------------------------------------------------------------ in a level

func _game(english: bool) -> void:
	seed(20261017)
	progress.start_story(3)
	var game: Node = await _spawn_game({level = 3})
	await _frames(2)
	game.restart_prompt.open()
	await _frames(1)
	var prompt_root: Control = game.restart_prompt.get_child(0)
	var panel := _panel_rect(prompt_root)
	var title: Label = null
	for c in prompt_root.get_children():
		if c is Label:
			title = c
	_check(SCREEN.grow(-UIKit.EDGE).encloses(panel) and _rect(title).end.y <= panel.position.y, "%s: restart panel inside the screen, under its title" % _code)
	var widths := {}
	for b: Button in game.restart_prompt.buttons:
		widths[_rect(b).size.x] = true
		_check(panel.grow(-UIKit.PANEL_PAD + 0.5).encloses(_rect(b)) and _rect(b).size.y == UIKit.button_h() and _rect(b).size.x >= UIKit.text_w(b.text) + 8,
			"%s: restart %s inside the panel, button_h() tall, fitting its word" % [_code, b.text])
	_check(widths.size() == 1, "%s: restart buttons equal widths" % _code)
	if english:
		_check(panel == Rect2(100, 52, 120, 61), "%s: restart panel at (100, 52) 120x61" % _code)
	game.restart_prompt.close()
	game.free()

	seed(20261017)
	progress.start_descent(77)
	game = await _spawn_game({})
	await _frames(2)
	var card: DescentCard = game._ensure_card()
	var held := {"gulp": 1, "tank": 1}  # (stacking boons: their HAVE lines too)
	var run: Dictionary = progress.descent_run.duplicate()
	for boons: Dictionary in [{}, held]:
		run.boons = boons
		card.show_boons(run, Descent.IDS.slice(0, 3) if boons.is_empty() else ["tank", "gulp", "sense"])
		await _frames(1)
		var buttons := [_rect(card.cash_button), _rect(card.descend_button)]
		_check(buttons[0].size == buttons[1].size and buttons[0].position.x == 10 and buttons[1].end.x == 310
			and buttons[0].end.y == UIKit.CHOICE_Y + UIKit.BUTTON_H, "%s: card buttons equal, under the outer tiles, ending on the choice row" % _code)
		var status := _text_box(card.status)
		_check(status.end.y <= buttons[0].position.y, "%s: card status line above the buttons" % _code)
		for tile: Button in card.tiles:
			if not tile.visible:
				continue
			var t := _rect(tile)
			_check(t.end.y <= status.position.y and t.position.y >= _text_box(card.meter_label).end.y, "%s: tile between the info line and the status line" % _code)
			var boxes: Array = []
			for c in tile.get_children():
				if c is Label:
					boxes.append(_text_box(c))
				elif c is TextureRect:
					boxes.append(_rect(c))
			_inside(boxes, t, "%s card tile" % _code)
			_apart(boxes, [], "%s card tile" % _code)
		if english:
			_check(_rect(card.tiles[0]) == Rect2(10, 47, 96, 78), "%s: card tiles at (10, 47) 96x78" % _code)
	card.show_summary({floor = 2, cleared = 1, best_floor = 2, time = 61.0, tickets = 1, pot = 2, boons = {"gulp": 1}})
	await _frames(2)
	var sum_panel := Rect2(card.summary_panel.global_position, card.summary_panel.size)
	var b1 := _rect(card.new_run_button)
	var b2 := _rect(card.hub_button)
	_check(SCREEN.encloses(sum_panel) and sum_panel.end.y <= b1.position.y and _text_box(card.summary_title).end.y <= sum_panel.position.y,
		"%s: summary panel under its title, above its buttons" % _code)
	_check(b1.size == b2.size and absf((b1.position.x + b2.end.x) / 2.0 - 160.0) <= 0.5 and b1.end.y == UIKit.CHOICE_Y + UIKit.BUTTON_H
		and b1.size.x >= UIKit.text_w(card.new_run_button.text) + 8, "%s: summary buttons equal, centred, ending on the choice row" % _code)
	game.free()


# ------------------------------------------------------------------ helpers

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


## The first Panel under `menu` (its frame).
func _panel_rect(menu: Control) -> Rect2:
	for c in menu.get_children():
		if c is Panel:
			return _rect(c)
	return Rect2()


## Where a label's text is drawn: its lines' boxes (the font's line height), aligned in the label.
func _text_box(label: Label) -> Rect2:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var lines := maxi(1, label.get_line_count()) if label.autowrap_mode != TextServer.AUTOWRAP_OFF else label.text.count("\n") + 1
	var h := lines * font.get_height(size) + (lines - 1) * label.get_theme_constant("line_spacing")
	var w := 0.0
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		w = label.size.x
	else:
		for line in label.text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var r := _rect(label)
	var x := r.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - w) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = r.end.x - w
	var y := r.position.y
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y += (r.size.y - h) / 2.0
	return Rect2(x, y, w, h)


## Every visible label with text under `node` (not inside a button), as text boxes.
func _texts(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Button:
			continue
		if c is Label and c.is_visible_in_tree() and c.text.strip_edges() != "":
			out.append(_text_box(c))
		if c is Control and c.is_visible_in_tree():
			out.append_array(_texts(c))
	return out


func _buttons(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(_rect(c))
		elif c is Control:
			out.append_array(_buttons(c))
	return out


func _inside(boxes: Array, area: Rect2, tag: String) -> void:
	var bad := boxes.filter(func(b: Rect2) -> bool: return not area.grow(0.01).encloses(b))
	_check(bad.is_empty(), "%s: %d texts inside %s%s" % [tag, boxes.size(), area, "" if bad.is_empty() else " (out: %s)" % [bad]])


func _apart(boxes: Array, others: Array, tag: String) -> void:
	var hits := 0
	for i in boxes.size():
		var a: Rect2 = boxes[i].grow(-0.5)
		for j in range(i + 1, boxes.size()):
			if a.intersects(boxes[j].grow(-0.5)):
				hits += 1
		for o: Rect2 in others:
			if a.intersects(o.grow(-0.5)):
				hits += 1
	_check(hits == 0, "%s: texts clear of each other and the buttons (%d overlaps)" % [tag, hits])
