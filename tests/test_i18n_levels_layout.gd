extends "res://tests/suite_base.gd"

## Layout in every locale (i18n chunk G1, docs/ui-rules.md section 10) of the LEVEL SELECT (normal and
## hard), its HEAT panel, the MAP TABLE and the map view, with the gate on and the locale's fallback font
## installed. Arabic is skipped (its mirroring is chunk I). Measured from the built controls' rects and
## their texts' widths / line heights, per locale:
## - Level select: one page (two rows) where the two rows, the info panel and the bottom row fit
##   between the title's line box and row 176 (English and Indonesian), else two pages of one row with
##   < / > beside the title (symmetric, clear of the title's letters, the paging showing 1-5 / 6-10);
##   the grid centred, under the title's line box and GAP_M over the info panel; the panel centred,
##   inside EDGE, GRID_GAP over the bottom row, its lines and checkbox inside it; HEAT mirroring BACK
##   (ending on row 176 and EDGE from the right, as wide as its text); the tiles' digits on the slimy
##   font's own 14 / 9 px line boxes (no script fallback pushing them down).
## - HEAT panel: inside the screen (EDGE from the sides), centred; the title PANEL_PAD under its top,
##   DONE (centred, fits its word) PANEL_PAD over its bottom; six toggles inside it, none overlapping,
##   each name inside its toggle (one line, the smaller script size, or two lines), the +N under the
##   name; the screen behind hidden while a resized panel is open (and shown again after).
## - Map table: the grid under the title (its shadow row), BOTTOM_GAP over the bottom row, five rows on
##   one page or balanced pages; each name inside its tile (two lines at most) and the % under it inside
##   the tile; the hint centred on BACK's text line; HARD ending EDGE from the right, inside the screen.
## - Map view: the name line above the map area, the map inside it, the % line on BACK's text line, BACK
##   / PAPER fitting their words on the bottom row; the select hidden behind the view while it is open.
## - English: the source rects pinned (grid (34, 22), info panel (14, 113) 292x48, checkbox (25, 145),
##   HEAT (264, 164) 52x13, HEAT panel RECT / TOGGLE, map tiles 155x26 from (4, 21), MAP_AREA, hint
##   (48, 167) 224x10, view BACK 40x13).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 120000 -s res://tests/test_i18n_levels_layout.gd

const Report := preload("res://tests/i18n_report.gd")
const SCREEN := Rect2(0, 0, 320, 180)

var progress: Node
var language: Node
var _code := ""


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		if code == "ar":
			continue
		_code = code
		language.set_locale(code)
		for hard in [false, true]:
			await _level_select(hard)
		await _maps()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	progress.hard_mode = false
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	for i in 3:
		await process_frame
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size)


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


## The width of the widest line of `control`'s text in its own font.
func _text_w(control: Control) -> float:
	var font: Font = control.get_theme_font("font")
	var size: int = control.get_theme_font_size("font_size")
	var widest := 0.0
	for line in String(control.get("text")).split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest


func _no_overlaps(rects: Array, what: String) -> void:
	var ok := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)):
				ok = false
	_check(ok, _tag(what + ": none overlapping"))


# ------------------------------------------------------------------ level select

func _level_select(hard: bool) -> void:
	progress.hard_mode = hard
	var ls := await _open("res://scenes/level_select.tscn")
	var tag := "level select " + ("hard" if hard else "normal")
	var english := UIKit.locale() == "en"
	var grid := _rect(ls.grid)
	var panel := _rect(ls.info_panel)
	var box := _rect(ls.hard_mode_box)
	var source_fit: bool = UIKit.button_h() == UIKit.BUTTON_H and UIKit.line_h() == UIKit.TEXT_BODY
	_check(ls.pages == (1 if source_fit else 2), _tag(tag + ": %d page(s)" % ls.pages))
	if english:
		_check(grid.position == Vector2(34, 22) and panel == Rect2(14, 113, 292, 48) and box.position == Vector2(25, 145),
			_tag(tag + ": the English rects (grid %s, panel %s, checkbox %s)" % [grid, panel, box]))
	_check(absf(grid.get_center().x - 160.0) <= 0.5 and absf(panel.get_center().x - 160.0) <= 0.5,
		_tag(tag + ": grid and panel centred (%s, %s)" % [grid, panel]))
	_check(grid.position.y >= UIKit.title_bottom() and grid.end.y + UIKit.GAP_M <= panel.position.y,
		_tag(tag + ": the grid under the title's line box, GAP_M over the panel (%s, %s)" % [grid, panel]))
	_check(panel.position.x >= UIKit.EDGE and panel.end.x <= 320 - UIKit.EDGE and panel.end.y == UIKit.bottom_row_y() - ls.GRID_GAP,
		_tag(tag + ": the panel inside EDGE, GRID_GAP over the bottom row (%s)" % panel))
	_check(panel.encloses(box) and box.position.x - panel.position.x >= UIKit.GAP_L - 0.5 and panel.end.x - box.end.x >= UIKit.GAP_L - 0.5,
		_tag(tag + ": the checkbox inside the panel, GAP_L from its sides (%s)" % box))
	var box_text_h := UIKit.text_block_h(ls.hard_mode_box.text.count("\n") + 1)
	_check(panel.end.y - (box.get_center().y + box_text_h / 2.0) >= UIKit.GAP_M,
		_tag(tag + ": the checkbox's text GAP_M over the panel's bottom (%s)" % box))
	var info: Label = ls.info
	var lines_h := UIKit.text_block_h(2)
	_check(info.position.y >= panel.position.y + ls.INFO_PAD and info.position.y + lines_h + UIKit.GAP_L <= box.position.y + 0.5
		and _text_w(info) <= panel.size.x - 2 * UIKit.GAP_M, _tag(tag + ": the info lines inside the panel, over the checkbox"))
	var heat: Button = ls.heat_button
	if hard:
		var heat_rect := _rect(heat)
		_check(heat_rect.end == Vector2(320 - UIKit.EDGE, 177) and heat_rect.size.x == UIKit.button_w(heat.text, 52) and heat_rect.size.y == UIKit.button_h(),
			_tag(tag + ": HEAT mirrors BACK, as wide as its text (%s)" % heat_rect))
		if english:
			_check(heat_rect == Rect2(264, 164, 52, 13), _tag(tag + ": HEAT at the English rect"))
	# Tiles: the shown page; digits on the slimy font's own line boxes.
	var shown: Array[int] = []
	var digits_ok := true
	for i in ls.level_buttons.size():
		var tile: Button = ls.level_buttons[i]
		if not tile.visible:
			continue
		shown.append(i + 1)
		var number: Label = tile.get_node("Number")
		digits_ok = digits_ok and number.size.y == 14.0 and number.get_theme_font("font").get_height(UIKit.FONT_BIG) == 14.0
		for child in tile.get_children():
			if child is Label and child != number:
				var time := child as Label
				digits_ok = digits_ok and time.get_theme_font("font").get_height(UIKit.FONT) == 7.0 and time.get_combined_minimum_size().y == 7.0
	_check(digits_ok, _tag(tag + ": tile digits on the slimy font's line boxes (14 / 9 px)"))
	if ls.pages == 1:
		_check(shown.size() == 10 and ls.page_prev == null, _tag(tag + ": every tile on one page, no arrows"))
	else:
		_check(shown == [1, 2, 3, 4, 5], _tag(tag + ": page 1 shows 1-5 (%s)" % [shown]))
		_pager(ls.page_prev, ls.page_next, Loc.t("levels.title", "LEVEL SELECT"), tag)
		ls.page_next.pressed.emit()
		await _frames(2)
		var second: Array[int] = []
		for i in ls.level_buttons.size():
			if ls.level_buttons[i].visible:
				second.append(i + 1)
		_check(second == [6, 7, 8, 9, 10] and ls.page_next.disabled and not ls.page_prev.disabled
			and absf(_rect(ls.grid).get_center().x - 160.0) <= 0.5, _tag(tag + ": > shows 6-10, centred (%s)" % [second]))
		ls.page_prev.pressed.emit()
		await _frames(1)
		# Keyboard: right past the row's end flips to the next page, left back.
		ls.level_buttons[4].grab_focus()
		_tap_key(KEY_RIGHT)
		await _frames(2)
		var on_six: bool = ls.level_buttons[5].has_focus() and ls.page == 1 and not ls.level_buttons[4].visible
		_tap_key(KEY_LEFT)
		await _frames(2)
		_check(on_six and ls.level_buttons[4].has_focus() and ls.page == 0 and ls.level_buttons[4].visible,
			_tag(tag + ": right from 5 flips to 6, left from 6 back to 5"))
	if hard:
		await _heat_panel(ls)
	ls.free()


## < and > beside the title: the same size and height, EDGE from the sides, clear of the title's letters.
func _pager(prev: Button, next: Button, title: String, tag: String) -> void:
	var a := _rect(prev)
	var b := _rect(next)
	var title_w := UIKit.text_w(title, UIKit.FONT_BIG)
	_check(a.position.x == UIKit.EDGE and b.end.x == 320 - UIKit.EDGE and a.size == b.size and a.position.y == b.position.y
		and a.size.y == UIKit.button_h(), _tag(tag + ": < and > symmetric (%s, %s)" % [a, b]))
	_check(a.end.x + UIKit.GAP_M <= 160.0 - title_w / 2.0 and b.position.x - UIKit.GAP_M >= 160.0 + title_w / 2.0
		and a.position.y >= UIKit.title_top() - 2 and a.end.y <= UIKit.title_bottom(), _tag(tag + ": the arrows clear of the title (%d px wide)" % title_w))
	_check(prev.disabled and not next.disabled, _tag(tag + ": page 1: < off, > on"))


func _heat_panel(ls: Control) -> void:
	var hp: Control = ls.heat_panel
	hp.open(ls, ls.heat_button)
	await _frames(2)
	var rect: Rect2 = hp.rect
	if UIKit.locale() == "en":
		_check(rect == hp.RECT and hp.toggle_size == Vector2(hp.TOGGLE), _tag("HEAT panel: the English RECT / TOGGLE"))
	_check(rect.position.x >= UIKit.EDGE and rect.end.x <= 320 - UIKit.EDGE and rect.position.y >= 2 and rect.end.y <= 178
		and absf(rect.get_center().x - 160.0) <= 0.5, _tag("HEAT panel: inside the screen, centred (%s)" % rect))
	_check(hp.title.position.y - rect.position.y == UIKit.PANEL_PAD and rect.end.y - _rect(hp.done_button).end.y == UIKit.PANEL_PAD,
		_tag("HEAT panel: title PANEL_PAD under the top, DONE PANEL_PAD over the bottom"))
	var done := _rect(hp.done_button)
	_check(absf(done.get_center().x - rect.get_center().x) <= 0.5 and done.size.x == UIKit.button_w(hp.done_button.text, 50),
		_tag("HEAT panel: DONE centred, fitting its word (%s)" % done))
	var rects: Array[Rect2] = []
	var names_ok := true
	for id: String in hp.toggles:
		var toggle: Button = hp.toggles[id]
		var t := _rect(toggle)
		rects.append(t)
		var name_label: Label = toggle.get_node("Name")
		var points: Label = toggle.get_node("Points")
		var lines := name_label.get_line_count() if name_label.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
		var w := _text_w(name_label) if lines == 1 else name_label.size.x
		names_ok = names_ok and lines <= 2 and name_label.position.x + w <= t.size.x - hp.NAME_PAD + 0.5
		names_ok = names_ok and points.position.y >= name_label.position.y + name_label.get_combined_minimum_size().y \
			and points.position.y + 9 <= t.size.y
	_check(names_ok, _tag("HEAT panel: every name inside its toggle (two lines at most), the +N under it"))
	var inside := true
	for t in rects:
		inside = inside and rect.grow(-UIKit.GAP_M).encloses(t)
	_check(inside, _tag("HEAT panel: the toggles inside the panel"))
	_no_overlaps(rects + [_rect(hp.about), done], "HEAT panel toggles, line and DONE")
	var behind_hidden: bool = not ls.grid.visible and not ls.info.visible
	_check(behind_hidden == not hp.english, _tag("HEAT panel: the screen behind hidden only for a resized panel"))
	hp.close()
	await _frames(1)
	_check(ls.grid.visible and ls.info.visible and ls.heat_button.has_focus(), _tag("HEAT panel: closed, the screen back, focus on HEAT"))


# ------------------------------------------------------------------ maps

func _maps() -> void:
	progress.hard_mode = false
	var ms := await _open("res://scenes/maps.tscn")
	var english := UIKit.locale() == "en"
	var grid := _rect(ms.grid)
	_check(grid.position.y >= UIKit.title_bottom() - 1 and grid.end.y <= UIKit.bottom_row_y() - ms.BOTTOM_GAP and grid.position.x == UIKit.EDGE
		and grid.end.x == 320 - UIKit.EDGE, _tag("map table: the grid under the title, over the bottom row (%s)" % grid))
	# One page: from the title's shadow row (English's five rows fill the room). On pages (fix pass F3b): the
	# first page's rows centred in that room (+-0.5 px), not leaving the band under them empty.
	var room := Rect2(0, UIKit.title_bottom() - 1, 320, ms.grid_area_h())
	var gap_above := grid.position.y - room.position.y
	var gap_below := room.end.y - grid.end.y
	if ms.pages == 1:
		_check(grid.position.y == UIKit.title_bottom() - 1, _tag("map table: one page from the title's shadow row (%s)" % grid))
	else:
		_check(gap_above >= 0 and absf(gap_above - gap_below) <= 1.0, _tag("map table: the paged rows centred between the title and the bottom row (%d / %d)" % [gap_above, gap_below]))
	if english:
		_check(ms.tile_size == ms.TILE_SIZE and grid.position == Vector2(4, 21) and ms.pages == 1, _tag("map table: the English tiles and grid"))
	var visible_rows := 0
	var tiles_ok := true
	for tile: Button in ms.tiles:
		if not tile.visible:
			continue
		var name_label: Label = tile.get_meta("name_label")
		var lines := name_label.get_line_count() if name_label.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
		var w := _text_w(name_label) if lines == 1 else name_label.size.x
		tiles_ok = tiles_ok and lines <= 2 and name_label.position.x + w <= tile.size.x - ms.TEXT_PAD + 0.5
		for child in tile.get_children():
			if child is Label and child != name_label:
				var percent := child as Label
				tiles_ok = tiles_ok and percent.position.y >= name_label.position.y + UIKit.text_block_h(lines) \
					and percent.position.y + percent.get_combined_minimum_size().y + UIKit.TEXT_DRIP <= tile.size.y - 2
		visible_rows += 1
	visible_rows = ceili(visible_rows / 2.0)
	_check(tiles_ok, _tag("map table: every name inside its tile (two lines at most), the % under it inside the tile"))
	_check(visible_rows == ms.rows_per_page and (ms.pages == 1) == (ms.rows_per_page == 5), _tag("map table: %d rows a page, %d pages" % [visible_rows, ms.pages]))
	var hint := _rect(ms.hint_label)
	var back := _rect(ms.back_button)
	_check(hint.get_center().x == 160.0 and hint.position.y == ms.text_line_y() and hint.position.x == back.end.x + UIKit.GAP_M,
		_tag("map table: the hint centred on BACK's text line (%s)" % hint))
	var box := _rect(ms.hard_box)
	_check(box.end.x == 320 - UIKit.EDGE and box.end.y <= 180 and box.position.x > hint.position.x + (hint.size.x + _text_w(ms.hint_label)) / 2.0,
		_tag("map table: HARD ends EDGE from the right, inside the screen, clear of the hint (%s)" % box))
	if english:
		_check(hint == Rect2(48, 167, 224, 10), _tag("map table: the English hint rect"))
	if ms.pages > 1:
		_pager(ms.page_prev, ms.page_next, Loc.t("maps.title", "MAP TABLE"), "map table")
		ms.page_next.pressed.emit()
		await _frames(2)
		var levels: Array[int] = []
		for tile: Button in ms.tiles:
			if tile.visible:
				levels.append(tile.get_meta("level"))
		levels.sort()
		_check(levels == ms.page_levels(1) and levels[-1] == 10, _tag("map table: > shows the last page (%s)" % [levels]))
		ms.page_prev.pressed.emit()
		await _frames(1)
	await _map_view(ms)
	ms.free()


func _map_view(ms: Control) -> void:
	ms.open_view(3)
	await _frames(2)
	var area: Rect2 = Rect2(ms.map_area)
	var title := _rect(ms.view_title)
	_check(ms.view_title.position.y + UIKit.line_h() + 3 <= area.position.y and area.end.y <= UIKit.bottom_row_y() - 2,
		_tag("map view: the name line over the map area, the area over the bottom row (%s)" % area))
	_check(area.encloses(_rect(ms.view_map)), _tag("map view: the map inside its area"))
	_check(_text_w(ms.view_title) <= title.size.x and title.position.y >= 1 + ms.view_title_y() - 3, _tag("map view: the name fits its line"))
	var line := _rect(ms.view_line)
	var back := _rect(ms.view_back)
	_check(line.position.y == ms.text_line_y() and line.get_center().x == 160.0 and _text_w(ms.view_line) <= line.size.x,
		_tag("map view: the %% line centred on BACK's text line (%s)" % line))
	_check(back.size == UIKit.back_size() and back.end.y == 177 and back.position.x == UIKit.EDGE, _tag("map view: BACK fits its word on the bottom row (%s)" % back))
	if UIKit.locale() == "en":
		_check(area == Rect2(ms.MAP_AREA) and back == Rect2(4, 164, 40, 13), _tag("map view: the English MAP_AREA and BACK"))
	_check(not ms.grid.visible and not ms.back_button.visible and ms.view_root.visible, _tag("map view: the select hidden behind it"))
	ms.close_view()
	await _frames(1)
	_check(ms.grid.visible and ms.back_button.visible and not ms.view_root.visible, _tag("map view: closed, the select back"))
