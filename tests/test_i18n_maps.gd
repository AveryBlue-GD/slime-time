extends "res://tests/suite_base.gd"

## The MAP TABLE in every language (docs/i18n/plan.md, docs/ui-rules.md section 10): English, the 17
## translations (Arabic mirrored) and the pseudo locale, with the gate on (Economy.languages_force), normal
## and hard. With synthetic surveys recorded for all 10 levels in both modes (a different % per level and
## mode, so a survey shown in the wrong mode is caught), per locale:
## - the table reaches exactly levels 1-10, once each, across its pages: turned with the < > arrows
##   (pressed and tapped), with the keys / d-pad (left / right past a page's outer column, mirrored in
##   Arabic: there the left key leads on), and each page reads in level order (the columns in the reading
##   direction, top to bottom); the pager's arrows disable at the ends;
## - each tile: its level's name, its own mode's % (never the other mode's), open, its picture the mode's
##   example preview (MapView.preview; the hard example maze differs from the normal one for every level);
## - the HARD switch: every tile switches to the hard survey / preview; HARD stays on across paging and
##   after returning from a map view (the view's level's page shown, its tile focused);
## - the map view for all 20 maps (10 levels x normal / hard): it opens, the title is the level's name
##   (+ the HARD suffix in hard), the line has that mode's %, the drawing is that mode's maze (its size,
##   and different from the other mode's drawing), coins only on normal maps; the title, map, % line, BACK
##   and PAPER inside the screen, the texts inside their boxes, nothing overlapping;
## - the select's layout: every visible tile inside the screen over the bottom row, no two overlapping,
##   names inside their tiles (two lines at most), the % under the name, pictures inside; BACK, the hint
##   and HARD on the bottom row, clear of each other; the arrows clear of the title's letters;
## - empty states: no surveys at all (every tile locked: dim, a lock, 0%, focus on BACK, paging still
##   works), only some levels surveyed per mode (exactly those open, in each mode), and a hard survey
##   stored under a normal level's key (a stale one: the tile stays locked, it never draws).
## Also, once: the survey keys of the two modes differ (Progress.survey_key), every hard maze differs from
## its normal maze, the preview cache keeps the modes apart.
## Throwaway save; the real save is never read or written (md5 checked).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_i18n_maps.gd

const Report := preload("res://tests/i18n_report.gd")
const SCREEN := Rect2(0, 0, 320, 180)

var progress: Node
var language: Node
var _code := ""
## [level][hard] -> the survey recorded for it.
var surveys := {}
## [level][hard] -> its %.
var percents := {}
var _fail_locales := {}


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.reset_progress()
	progress.dev_tools = false
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.maps_hint_seen = false
	progress.hard_mode = false
	# A map paper owned and worn: PAPER shows in the view and the % line is its long variant.
	var paper: String = Cosmetics.paper_ids()[1]
	progress.cosmetics_owned.append(paper)
	progress.equip_cosmetic(paper)
	for level in range(1, Levels.COUNT + 1):  # every coin found: the normal maps draw them, the hard ones never
		for cell in Levels.story_coin_cells(level):
			progress.collect_coin(level, cell)
	_test_separation()
	_seed_surveys()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		_check(language.locale == code, _tag("locale set"))
		var before := failures
		await _table(false)
		await _table(true)
		await _empty_states()
		if failures > before:
			_fail_locales[code] = failures - before
	language.set_locale("en")
	language.disable()
	await _frames(3)  # (the last screen's deferred mirroring and frees run first)
	Economy.languages_force = -1
	Economy.forced_locale = ""
	progress.hard_mode = false
	var summary := PackedStringArray()
	for code: String in Report.LOCALE_ORDER:
		summary.append("%s %s" % [code, "FAIL(%d)" % _fail_locales[code] if _fail_locales.has(code) else "pass"])
	print("  per locale: " + ", ".join(summary))
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched")
	_result()
	quit(1 if failures else 0)


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


# ------------------------------------------------------------------ the data

## The two modes never share a survey, a maze, an example maze or a preview.
func _test_separation() -> void:
	var keys := {}
	var mazes_differ := true
	var examples_differ := true
	var previews_differ := true
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			keys[progress.survey_key(level, hard)] = true
		var normal := Levels.story_maze(level, false)
		var hard_maze := Levels.story_maze(level, true)
		mazes_differ = mazes_differ and (normal.size != hard_maze.size or normal.walls != hard_maze.walls)
		examples_differ = examples_differ and MapView.example(level, false).maze.walls != MapView.example(level, true).maze.walls
		var theme := Themes.for_level(level)
		var a := MapView.preview(level, false, 50, 2, false, theme)
		var b := MapView.preview(level, true, 50, 2, false, theme)
		previews_differ = previews_differ and a != b and a.get_image().get_data() != b.get_image().get_data()
	_check(keys.size() == 2 * Levels.COUNT, "20 distinct survey keys (normal 1-10, hard %d-%d)" % [progress.survey_key(1, true), progress.survey_key(10, true)])
	_check(mazes_differ, "every hard maze differs from its normal maze")
	_check(examples_differ and previews_differ, "every level's hard example maze and preview differ from the normal ones (separately cached)")


## A survey for every level in both modes, each at its own % (normal 8L + 10, hard 98 - 5L, level 10 hard
## complete), routes varied: a best clear, a last try or none.
func _seed_surveys() -> void:
	progress.maps = {}
	var taken := {}
	var distinct := true
	for level in range(1, Levels.COUNT + 1):
		surveys[level] = {}
		percents[level] = {}
		for hard in [false, true]:
			var maze := Levels.story_maze(level, hard)
			var target := (98 - 5 * level) if hard else (8 * level + 10)
			var route: String = ["best", "try", ""][(level + int(hard)) % 3]
			var survey := Survey.full(maze, 30.0) if hard and level == 10 else _lit_survey(maze, target, route)
			progress.maps[progress.survey_key(level, hard)] = survey
			surveys[level][hard] = survey
			percents[level][hard] = roundi(Survey.completeness(survey, maze) * 100.0)
		distinct = distinct and percents[level][false] != percents[level][true]
		taken[percents[level][false]] = true
	_check(distinct and taken.size() == Levels.COUNT, "seeded 20 surveys, each level's two modes at different %% (%s)" % [percents])


## A survey of `maze` lit outward from the start until about `percent`% shows; `route` "best" / "try" / "".
func _lit_survey(maze: Dictionary, percent: int, route: String) -> Dictionary:
	var survey := Survey.blank(maze)
	var order: Array[Vector2i] = [maze.start]
	var reached := {maze.start: true}
	var i := 0
	while i < order.size():
		for next in MazeGenerator.open_neighbors(maze, order[i]):
			if not reached.has(next):
				reached[next] = true
				order.append(next)
		i += 1
	for cell in order:
		if Survey.completeness(survey, maze) * 100.0 >= percent - 0.5:
			break
		var t := cell * 2 + Vector2i.ONE
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				Survey.mark_seen(survey, t + Vector2i(dx, dy))
	if route != "":
		survey.moves = Survey.moves_along(MazeGenerator.shortest_path(maze, maze.start, maze.goal))
		survey.clear = route == "best"
		survey.best_ms = 20000 if survey.clear else 0
	survey.goal = Survey.is_seen(survey, maze.goal * 2 + Vector2i.ONE)
	return survey


# ------------------------------------------------------------------ the table

func _table(hard: bool) -> void:
	var mode := "hard" if hard else "normal"
	_restore_surveys()
	var ms := await _open()
	if hard:
		ms.hard_box.button_pressed = true
		await _frames(2)
		_check(ms.hard and not progress.hard_mode, _tag("HARD on: the hard maps, the game's mode untouched"))
	var ok := await _walk_pages(ms, hard, mode)
	_check(ok, _tag(mode + ": the pages walked"))
	await _paging_input(ms, hard, mode)
	await _select_layout(ms, mode)
	await _views(ms, hard, mode)
	if hard:
		# Off again: every tile back to the normal surveys.
		ms.hard_box.button_pressed = false
		await _frames(2)
		var back_ok: bool = not ms.hard
		for tile: Button in ms.tiles:
			var level: int = tile.get_meta("level")
			back_ok = back_ok and tile.get_meta("percent") == percents[level][false]
		_check(back_ok, _tag("HARD off: every tile back to its normal survey"))
	await _close(ms)


## Visits every page (from page 1 forward with >), checking each tile; true when levels 1-10 were each
## reached exactly once.
func _walk_pages(ms: Control, hard: bool, mode: String) -> bool:
	var seen: Array[int] = []
	var order_ok := true
	var tiles_ok := true
	var bad := ""
	_check(ms.page == 0 or ms.pages == 1, _tag(mode + ": opens on page 1 (the current level's)"))
	for p in ms.pages:
		var shown := _visible_levels(ms)
		seen.append_array(shown)
		var reading := _reading_order(ms)
		order_ok = order_ok and reading == ms.page_levels(p) and shown.size() == ms.page_levels(p).size()
		for tile: Button in ms.tiles:
			if not tile.visible:
				continue
			var why := _tile_problem(tile, hard)
			if why != "":
				tiles_ok = false
				bad = why
		if ms.pages > 1:
			_check(ms.page_prev.disabled == (p == 0) and ms.page_next.disabled == (p == ms.pages - 1),
				_tag(mode + ": page %d: the arrow that would leave the pages is off" % (p + 1)))
			_check(ms.hard == hard and ms.hard_box.button_pressed == hard, _tag(mode + ": page %d keeps HARD %s" % [p + 1, hard]))
			if p < ms.pages - 1:
				ms.page_next.pressed.emit()
				await _frames(2)
	var sorted := seen.duplicate()
	sorted.sort()
	var once := sorted == range(1, Levels.COUNT + 1)
	_check(once, _tag(mode + ": the %d page(s) show levels 1-10 exactly once (%s)" % [ms.pages, seen]))
	_check(order_ok, _tag(mode + ": each page reads in level order (columns in the reading direction)"))
	_check(tiles_ok, _tag(mode + ": every tile shows its name, its own mode's %% and picture (%s)" % ("ok" if bad == "" else bad)))
	# Back to page 1 with <.
	for p in ms.pages - 1:
		ms.page_prev.pressed.emit()
		await _frames(2)
	_check(ms.page == 0 and ms.hard == hard, _tag(mode + ": < back to page 1, HARD kept"))
	return once and order_ok and tiles_ok


## "" or what is wrong with `tile` in mode `hard`.
func _tile_problem(tile: Button, hard: bool) -> String:
	var level: int = tile.get_meta("level")
	var name_label: Label = tile.get_meta("name_label")
	var name := Themes.display_name(Themes.for_level(level))
	if name_label.text != name:
		return "level %d named %s" % [level, name_label.text]
	if tile.disabled:
		return "level %d locked" % level
	var want: int = percents[level][hard]
	var other: int = percents[level][not hard]
	var shown := _percent_text(tile)
	if tile.get_meta("percent") != want or shown != "%d%%" % want:
		return "level %d shows %s, not %d%%%s" % [level, shown, want, " (the other mode's)" if shown == "%d%%" % other else ""]
	var survey: Dictionary = surveys[level][hard]
	var route := 0
	if not (survey.moves as PackedByteArray).is_empty():
		route = 2 if survey.clear else 1
	var expected := MapView.preview(level, hard, want, route, false, Themes.for_level(level) if (tile.get_parent().get_parent() as Control).get("themed") else "")
	var other_preview := MapView.preview(level, not hard, want, route, false, Themes.for_level(level))
	var thumb := _thumb(tile)
	if thumb == null or thumb.texture != expected or thumb.texture == other_preview:
		return "level %d's picture is not its %s preview" % [level, "hard" if hard else "normal"]
	return ""


func _percent_text(tile: Button) -> String:
	for child in tile.get_children():
		if child is Label and child != tile.get_meta("name_label"):
			return (child as Label).text
	return ""


func _thumb(tile: Button) -> TextureRect:
	for child in tile.get_children():
		if child is TextureRect:
			return child
	return null


func _visible_levels(ms: Control) -> Array[int]:
	var out: Array[int] = []
	for tile: Button in ms.tiles:
		if tile.visible:
			out.append(tile.get_meta("level"))
	return out


## The visible tiles' levels as a reader meets them: the first column (left; right in a right-to-left
## layout) top to bottom, then the other.
func _reading_order(ms: Control) -> Array[int]:
	var items: Array = []
	for tile: Button in ms.tiles:
		if tile.visible:
			var r := _rect(tile)
			items.append([r.position.x * (-1.0 if UIKit.rtl() else 1.0), r.position.y, tile.get_meta("level")])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] - 0.5 or (absf(a[0] - b[0]) <= 0.5 and a[1] < b[1]))
	var out: Array[int] = []
	for item: Array in items:
		out.append(item[2])
	return out


## Keys, the d-pad and touch turn the pages; HARD survives it.
func _paging_input(ms: Control, hard: bool, mode: String) -> void:
	if ms.pages < 2:
		_check(ms.page_prev == null and _visible_levels(ms).size() == Levels.COUNT, _tag(mode + ": one page, no arrows"))
		return
	var rtl := UIKit.rtl()
	var forward := KEY_LEFT if rtl else KEY_RIGHT
	var backward := KEY_RIGHT if rtl else KEY_LEFT
	var first: Array[int] = ms.page_levels(0)
	var rows := ceili(first.size() / 2.0)
	# The top row's outer (second) column: the forward key turns to page 2, its top tile focused.
	var outer: Button = ms.tiles[first[rows] - 1]
	outer.grab_focus()
	await _frames(1)
	_tap_key(forward)
	await _frames(2)
	var second: Array[int] = ms.page_levels(1)
	var turned: bool = ms.page == 1 and ms.tiles[second[0] - 1].has_focus()
	_tap_key(backward)
	await _frames(2)
	var back: bool = ms.page == 0 and outer.has_focus()
	_check(turned and back, _tag(mode + ": %s from level %d's tile turns to page 2 (level %d focused), %s back (%s, %s)"
		% ["left" if rtl else "right", first[rows], second[0], "right" if rtl else "left", turned, back]))
	# The inner column's backward key on page 1 doesn't leave the pages; the inner key moves within the page.
	var inner: Button = ms.tiles[first[0] - 1]
	inner.grab_focus()
	_tap_key(backward)
	await _frames(2)
	_check(ms.page == 0, _tag(mode + ": %s from page 1's first column stays on page 1" % ("right" if rtl else "left")))
	# The d-pad (a joypad's left / right) the same way.
	outer.grab_focus()
	await _joy(JOY_BUTTON_DPAD_LEFT if rtl else JOY_BUTTON_DPAD_RIGHT)
	var pad_on: bool = ms.page == 1
	await _joy(JOY_BUTTON_DPAD_RIGHT if rtl else JOY_BUTTON_DPAD_LEFT)
	_check(pad_on and ms.page == 0, _tag(mode + ": the d-pad turns the pages too"))
	# Touch: tap > (drawn on the left in a mirrored layout) and < where they are on screen.
	await _tap(_rect(ms.page_next).get_center())
	var tapped_on: bool = ms.page == 1
	await _tap(_rect(ms.page_prev).get_center())
	_check(tapped_on and ms.page == 0 and ms.hard == hard, _tag(mode + ": tapping > and < turns the pages, HARD kept"))
	if rtl:
		_check(_rect(ms.page_next).position.x < 160 and _rect(ms.page_prev).position.x > 160, _tag(mode + ": mirrored: > on the left, < on the right"))


func _select_layout(ms: Control, mode: String) -> void:
	for p in ms.pages:
		if ms.pages > 1:
			UIKit.relayout(ms)
			ms._show_page(p)
			await _frames(1)
		var rects: Array[Rect2] = []
		var inside := true
		var names_ok := true
		var bad := ""
		for tile: Button in ms.tiles:
			if not tile.visible:
				continue
			var t := _rect(tile)
			rects.append(t)
			inside = inside and SCREEN.encloses(t) and t.end.y <= UIKit.bottom_row_y() - ms.BOTTOM_GAP and t.position.y >= UIKit.title_bottom() - 1
			var name_label: Label = tile.get_meta("name_label")
			var lines := name_label.get_line_count() if name_label.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
			var name_w := _text_w(name_label)
			var n := _rect(name_label)
			var room: float = ms.TILE_SIZE.x - ms.TEXT_X - ms.TEXT_PAD
			var fits := lines <= 2 and (name_w <= room + 0.5 if lines == 1 else n.size.x <= room + 0.5) and t.encloses(n)
			var pct: Label = null
			for child in tile.get_children():
				if child is Label and child != name_label:
					pct = child
			var pr := _rect(pct)
			fits = fits and pr.position.y >= n.position.y + UIKit.text_block_h(lines) and pr.end.y + UIKit.TEXT_DRIP <= t.end.y - 2 \
				and t.encloses(pr) and _text_w(pct) <= pr.size.x + 0.5
			var thumb := _rect(_thumb(tile))
			fits = fits and t.grow(-2).encloses(thumb) and not thumb.grow(-0.5).intersects(_ink(name_label)) and not thumb.grow(-0.5).intersects(_ink(pct))
			if not fits and bad == "":
				bad = "level %d" % tile.get_meta("level")
			names_ok = names_ok and fits
		_check(inside, _tag(mode + ": page %d's tiles inside the screen, between the title and the bottom row" % (p + 1)))
		_no_overlaps(rects, mode + ": page %d's tiles" % (p + 1))
		_check(names_ok, _tag(mode + ": page %d: names inside their tiles (two lines at most), the %% under them, the pictures clear (%s)" % [p + 1, "ok" if bad == "" else bad]))
	if ms.pages > 1:
		UIKit.relayout(ms)
		ms._show_page(0)
		await _frames(1)
	# The bottom row and the title row.
	var back := _rect(ms.back_button)
	var hint := _ink(ms.hint_label)
	var box := _rect(ms.hard_box)
	var bottom := [back, box] + ([hint] if ms.hint_label.text != "" else [])
	var on_screen := true
	for r: Rect2 in bottom:
		on_screen = on_screen and SCREEN.encloses(r)
	_check(on_screen and _text_w(ms.hint_label) <= ms.hint_label.size.x + 0.5 and _text_w(ms.back_button) <= back.size.x - 4,
		_tag(mode + ": BACK, the hint and HARD inside the screen, their texts inside their boxes"))
	_no_overlaps(bottom, mode + ": BACK, the hint and HARD")
	var title := _title_label(ms)
	var title_ink := _ink(title)
	_check(title != null and SCREEN.encloses(title_ink), _tag(mode + ": the title inside the screen"))
	if ms.pages > 1:
		_no_overlaps([title_ink, _rect(ms.page_prev), _rect(ms.page_next)], mode + ": the title and the arrows")


func _title_label(ms: Control) -> Label:
	var want := Loc.t("maps.title", "MAP TABLE")
	for child in ms.find_children("*", "Label", true, false):
		if (child as Label).text == want:
			return child
	return null


## Opens all 10 maps of the mode, checks each, and that closing keeps HARD and shows the level's page.
func _views(ms: Control, hard: bool, mode: String) -> void:
	var opened := 0
	var right := true
	var fits := true
	var returns := true
	var bad := ""
	var fit_bad := ""
	for level in range(1, Levels.COUNT + 1):
		ms.open_view(level)
		await _frames(2)
		if not ms.viewing or ms.viewed_level != level:
			bad = "level %d didn't open" % level
			right = false
			continue
		opened += 1
		var name := Themes.display_name(Themes.for_level(level))
		var title_ok: bool = ms.view_title.text == (Loc.t("maps.view_title_hard", "{name}  HARD", {name = name}) if hard else name)
		var line_ok: bool = ("%d" % percents[level][hard]) in ms.view_line.text and not ("%d%%" % percents[level][not hard]) in ms.view_line.text.replace("\u2068", "").replace("\u2069", "")
		var image: Image = ms.view_map.texture.get_image()
		var maze := Levels.story_maze(level, hard)
		var sizes := MapView.layout(maze.cells, ms.map_area.size, ms.themed)
		var want_size := MapView.map_size(maze.cells, sizes) + Vector2i.ONE * (MapView.FRAME * 2 if ms.themed else 0)
		var drawn := image.get_data()
		var same: bool = drawn == _render(ms, level, hard).get_data()
		var differs: bool = drawn != _render(ms, level, not hard).get_data()
		if not (title_ok and line_ok and image.get_size() == want_size and same and differs):
			right = false
			if bad == "":
				bad = "level %d: title %s, line %s, size %s/%s, its mode's drawing %s, differs from the other mode's %s" % [level, title_ok, line_ok,
					image.get_size(), want_size, same, differs]
		var why := _view_fit(ms)
		if why != "":
			fits = false
			if fit_bad == "":
				fit_bad = "level %d: %s" % [level, why]
		# Back to the select: HARD kept, the level's page shown and its tile focused.
		if level % 3 == 0:
			await _tap_key_cancel()
		else:
			ms.view_back.pressed.emit()
		await _frames(2)
		var tile: Button = ms.tiles[level - 1]
		if ms.viewing or ms.hard != hard or ms.hard_box.button_pressed != hard or not tile.visible or not tile.has_focus() \
				or not ms.grid.visible or (ms.page_prev != null and not ms.page_prev.visible):
			returns = false
	_check(opened == Levels.COUNT and right, _tag(mode + ": all 10 maps open, each titled, its own mode's %% and drawing (%s)" % ("ok" if bad == "" else bad)))
	_check(fits, _tag(mode + ": the view's title, map, line, BACK and PAPER fit, none overlapping (%s)" % ("ok" if fit_bad == "" else fit_bad)))
	_check(returns, _tag(mode + ": closing a map returns to its page with its tile focused, HARD kept"))
	# Every paper's % line fits between BACK and PAPER, centred (level 10's map).
	var worn: String = progress.map_paper
	var lines_ok := true
	var line_bad := ""
	for paper: String in Cosmetics.paper_ids():
		progress.map_paper = paper
		ms.open_view(10)
		await _frames(1)
		var line := _ink(ms.view_line)
		var clear := not line.grow(-0.5).intersects(_rect(ms.view_back).grow(-0.5)) and not line.grow(-0.5).intersects(_rect(ms.view_paper).grow(-0.5))
		if not (clear and SCREEN.encloses(line) and _text_w(ms.view_line) <= 320.0 - 2.0 * (UIKit.EDGE + _rect(ms.view_back).size.x + UIKit.GAP_M) \
				and absf(line.get_center().x - 160.0) <= 0.5):
			lines_ok = false
			line_bad = "%s: %s ink %s back %s paper %s w %s / %s" % [paper, ms.view_line.text, line, _rect(ms.view_back), _rect(ms.view_paper), _text_w(ms.view_line), UIKit.text_w(ms.view_line.text)]
		ms.close_view()
		await _frames(1)
	progress.map_paper = worn
	_check(lines_ok, _tag(mode + ": with every paper the %% line fits between BACK and PAPER (%s)" % ("ok" if line_bad == "" else line_bad)))


## The drawing of `level`'s map in mode `hard` as the view should show it (its survey on its maze, the
## found coins on normal maps only, the level's theme, the worn paper).
func _render(ms: Control, level: int, hard: bool) -> Image:
	var maze := Levels.story_maze(level, hard)
	var coins: Array[Vector2i] = []
	if not hard:
		for cell in Levels.story_coin_cells(level):
			if progress.has_coin(level, cell):
				coins.append(cell)
	var themed: bool = ms.themed
	var sizes := MapView.layout(maze.cells, ms.map_area.size, themed)
	return MapView.render(maze, surveys[level][hard], sizes, coins, Themes.for_level(level) if themed else "",
		progress.map_paper if themed else "", progress.skin_color())


## "" or what doesn't fit in the open view.
func _view_fit(ms: Control) -> String:
	var title := _ink(ms.view_title)
	var map := _rect(ms.view_map)
	var area := Rect2(ms.map_area)
	var line := _ink(ms.view_line)
	var back := _rect(ms.view_back)
	var paper := _rect(ms.view_paper)
	if not ms.view_paper.visible:
		return "PAPER hidden"
	for r: Rect2 in [title, map, line, back, paper]:
		if not SCREEN.encloses(r):
			return "%s offscreen" % r
	if _text_w(ms.view_title) > ms.view_title.size.x or _text_w(ms.view_line) > ms.view_line.size.x:
		return "a text wider than its line"
	if _text_w(ms.view_back) > back.size.x - 4 or _text_w(ms.view_paper) > paper.size.x - 4:
		return "BACK / PAPER's text wider than the button"
	if not area.encloses(map) or map.position != map.position.floor():
		return "the map %s outside its area %s" % [map, area]
	var rects := [title, area, line, back, paper]
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)):
				return "%s over %s" % [rects[i], rects[j]]
	if ms.grid.visible or ms.back_button.visible or ms.hard_box.visible:
		return "the select shows behind the view"
	return ""


# ------------------------------------------------------------------ empty states

func _empty_states() -> void:
	# No surveys at all: every tile locked in both modes.
	progress.maps = {}
	var ms := await _open()
	for hard in [false, true]:
		var mode := "hard" if hard else "normal"
		ms.hard_box.button_pressed = hard
		await _frames(2)
		var reached: Array[int] = []
		var locked := true
		for p in ms.pages:
			reached.append_array(_visible_levels(ms))
			for tile: Button in ms.tiles:
				if tile.visible:
					var lock := _thumb(tile).get_child_count() == 1
					locked = locked and tile.disabled and _percent_text(tile) == "0%" and lock \
						and (tile.get_meta("name_label") as Label).text == Themes.display_name(Themes.for_level(tile.get_meta("level")))
			if p < ms.pages - 1:
				ms.page_next.pressed.emit()
				await _frames(2)
		reached.sort()
		_check(reached == range(1, Levels.COUNT + 1) and locked, _tag("no surveys, %s: levels 1-10 all reached, all locked (a lock, 0%%, the name)" % mode))
		for p in ms.pages - 1:
			ms.page_prev.pressed.emit()
			await _frames(2)
		ms.open_view(4)
		_check(not ms.viewing, _tag("no surveys, %s: a locked map doesn't open" % mode))
	await _close(ms)
	progress.maps = {}
	ms = await _open()
	_check(ms.back_button.has_focus(), _tag("no surveys: focus on BACK"))
	await _close(ms)
	# Some levels surveyed: odd ones on normal, even ones on hard; a hard survey under level 2's normal key.
	progress.maps = {}
	for level in range(1, Levels.COUNT + 1):
		progress.maps[progress.survey_key(level, level % 2 == 0)] = surveys[level][level % 2 == 0]
	progress.maps[progress.survey_key(2, false)] = surveys[2][true]
	ms = await _open()
	for hard in [false, true]:
		ms.hard_box.button_pressed = hard
		await _frames(2)
		var open: Array[int] = []
		for tile: Button in ms.tiles:
			if not tile.disabled:
				open.append(tile.get_meta("level"))
		open.sort()
		var want: Array[int] = []
		for level in range(1, Levels.COUNT + 1):
			if (level % 2 == 0) == hard:
				want.append(level)
		_check(open == want, _tag("some surveyed, %s: exactly %s open (%s)%s" % ["hard" if hard else "normal", want, open,
			"" if hard else ", a hard survey under level 2's normal key stays locked"]))
	await _close(ms)
	_restore_surveys()


func _restore_surveys() -> void:
	progress.maps = {}
	for level: int in surveys:
		for hard: bool in surveys[level]:
			progress.maps[progress.survey_key(level, hard)] = surveys[level][hard]
	progress.current_level = 1


# ------------------------------------------------------------------ helpers

func _open() -> Control:
	progress.hard_mode = false
	var ms: Control = load("res://scenes/maps.tscn").instantiate()
	root.add_child(ms)
	current_scene = ms
	await _frames(3)
	return ms


func _close(ms: Control) -> void:
	current_scene = null
	ms.queue_free()
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The rect `control` covers on screen (mirrored where Godot draws it mirrored).
func _rect(control: Control) -> Rect2:
	var xf := control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


## Where `control`'s text is drawn: its widest line placed by its alignment (swapped in a mirrored
## layout), its lines' height.
func _ink(control: Control) -> Rect2:
	var r := _rect(control)
	var w := _text_w(control)
	var font: Font = control.get_theme_font("font")
	var lines := 1
	if control is Label and (control as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		lines = (control as Label).get_line_count()
		w = r.size.x
	else:
		lines = String(control.get("text")).count("\n") + 1
	var h := lines * font.get_height(control.get_theme_font_size("font_size"))
	var align: int = control.get("horizontal_alignment") if control is Label else (control as Button).alignment
	if control.is_layout_rtl() and align != HORIZONTAL_ALIGNMENT_CENTER:
		align = HORIZONTAL_ALIGNMENT_RIGHT if align == HORIZONTAL_ALIGNMENT_LEFT else HORIZONTAL_ALIGNMENT_LEFT
	var x := r.position.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x += (r.size.x - w) / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = r.end.x - w
	var y := r.position.y
	if control is Button or (control is Label and (control as Label).vertical_alignment == VERTICAL_ALIGNMENT_CENTER):
		y += (r.size.y - h) / 2.0
	return Rect2(x, y, w, minf(h, maxf(r.size.y, h)))


## The width of the widest line of `control`'s text in its own font.
func _text_w(control: Control) -> float:
	var font: Font = control.get_theme_font("font")
	var size: int = control.get_theme_font_size("font_size")
	var widest := 0.0
	for line in String(control.get("text")).split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest


func _no_overlaps(rects: Array, what: String) -> void:
	var hit := ""
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)) and hit == "":
				hit = "%s / %s" % [rects[i], rects[j]]
	_check(hit == "", _tag(what + ": none overlapping" + ("" if hit == "" else " (" + hit + ")")))


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * at  # touches arrive in window pixels
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _frames(2)


func _joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _tap_key_cancel() -> void:
	_tap_key(KEY_ESCAPE)
	await _frames(1)
