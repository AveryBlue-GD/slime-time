extends "res://tests/suite_base.gd"

## The per-screen rules of the i18n fix pass F3b (docs/i18n/review/fixes-F3b.md, docs/ui-rules.md 10.1), in
## every locale, measured from the built controls (the rendered check is tools/i18n_capture.sh's goo-ink check):
## - SETTINGS: the LANGUAGE button's name on the theme's button text line (UIKit.button_v_margins), like
##   FOG beside it; the globe on the letter body (slimy font).
## - CONTROLS: every action label's line on its key button's text line; the note at least GAP_M under the
##   rows and GAP_L over the bottom row, centred between them when English's NOTE_GAP would crowd the rows;
##   rows on pages centred between the title's line box and the note (+-1 px); English rects pinned.
## - Title: ENTER's 16 px line from row 5 (English), its marks' first row on GOO_INK_ROW or lower, the drips
##   over the bottom outline; a taller script's glyphs from row GOO_INK_ROW; CJK ENTER / STORY ink centred
##   (+-1 px, glyph bitmaps measured here independently of title.gd); English rects pinned.
## - LANGUAGE: every slimy-font name's marks from GOO_INK_ROW, its drips over the bottom outline, the
##   slimy names of a row on one line; ENGLISH 2 px lower than before F3b (beside ESPAÑOL / PORTUGUÊS).
## - Level select: the info lines' first ink row on PANEL_INK_TOP or lower (English: INFO_PAD, unchanged).
## - Map table: each name's first ink row on GOO_INK_ROW or lower, the % line's drips over the tile's
##   bottom rows; English tiles unchanged.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_f3b_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")
const Lang := preload("res://scripts/language.gd")

## title.gd (loaded once the autoloads exist: it names them).
var Title: GDScript

var progress: Node
var language: Node
var _code := ""


func _initialize() -> void:
	await process_frame
	Title = load("res://scripts/ui/title.gd")
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		await _settings()
		await _keys()
		await _title()
		await _language()
		await _levels()
		await _maps()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	for i in 3:
		await process_frame
	return screen


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


## The top row of a one-line text's line box inside `control` (a Button or a Label), from its style's
## content margins and Godot's vertical centring of the line in what is left.
func _line_top(control: Control, line_h: float) -> float:
	var style := control.get_theme_stylebox("normal")
	var top := maxf(0.0, style.content_margin_top) if style else 0.0
	var bottom := maxf(0.0, style.content_margin_bottom) if style else 0.0
	return top + floorf((control.size.y - top - bottom - line_h) / 2.0)


## The rows a locale's 8 px ink reaches over the line box's top (marks: positive), or a taller script's
## first inked row under it (negative): -Language ink_top.
func _over() -> int:
	return -int(UIKit.metrics().get("ink_top", 0))


# ------------------------------------------------------------------ SETTINGS

func _settings() -> void:
	var page: Control = await _open("res://scenes/controls.tscn")
	var button: Button = page.language_button
	var label: Label = null
	var globe: TextureRect = null
	for child in button.get_children():
		if child is Label:
			label = child
		elif child is TextureRect:
			globe = child
	var line := float(UIKit.button_v_margins().x)
	var fog_line := _line_top(page.fog_button, UIKit.line_h())
	_check(label.position.y == line and label.size.y == UIKit.line_h() and fog_line == line,
		_tag("SETTINGS: the language name's line on row %d, as FOG's (%d)" % [label.position.y, fog_line]))
	if not UIKit.tall_script():
		_check(globe.position.y == label.position.y, _tag("SETTINGS: the globe on the name's letter body"))
	if _code == "en":
		_check(Rect2(button.position, button.size) == Rect2(164, 98, 120, 13) and label.position.y == 3 and globe.position.y == 3,
			_tag("SETTINGS: the English LANGUAGE button unchanged"))
	page.free()


# ------------------------------------------------------------------ CONTROLS

func _keys() -> void:
	var page: Control = await _open("res://scenes/key_controls.tscn")
	var level := true
	for grid: GridContainer in page.grids:
		for i in range(0, grid.get_child_count(), 2):
			var label := grid.get_child(i) as Label
			var key := grid.get_child(i + 1) as Button
			level = level and label.size.y == key.size.y and _line_top(label, UIKit.line_h()) == _line_top(key, UIKit.line_h())
	_check(level, _tag("CONTROLS: every action label on its key's text line"))
	var rows_h: int = page.rows_per_page * UIKit.button_h() + (page.rows_per_page - 1) * page.row_gap
	var rows_end: int = page.rows_top + rows_h
	var note: Label = page.note
	var marks: int = UIKit.mark_rows(note.text)
	var above := note.offset_top - marks - rows_end
	var below := UIKit.bottom_row_y() - note.offset_bottom
	# GAP_M under the rows' ink and GAP_L over the bottom row, or centred between them (+-1) where the room is
	# less (Vietnamese: five rows fill it; the note's stacked marks 3 rows clear of the keys' goo, 4 over BACK)
	var centred := absi(int(above) - int(below)) <= 1
	_check((above >= UIKit.GAP_M or centred) and (below >= UIKit.GAP_L or centred and below >= UIKit.GAP_M),
		_tag("CONTROLS: the note's ink %d under the rows, %d over the bottom row" % [above, below]))
	var paged: bool = page.pages / (3 - page.columns_per_page) > 1
	if paged:
		var over: int = page.rows_top - UIKit.title_bottom()
		var under: int = int(note.offset_top) - marks - rows_end
		_check(absi(over - under) <= 1, _tag("CONTROLS: the paged rows centred between the title and the note (%d / %d)" % [over, under]))
	elif _code != "en":
		_check(above >= below - 1 or below == UIKit.GAP_L,
			_tag("CONTROLS: the note no closer to the rows than to the bottom row (%d / %d)" % [above, below]))
	if _code == "en":
		_check(page.rows_top == 30 and note.offset_top == 140, _tag("CONTROLS: the English rows (30) and note (140) unchanged"))
	page.free()


# ------------------------------------------------------------------ title

func _title() -> void:
	var page: Control = await _open("res://scenes/title.tscn")
	var enter: Button = page.enter_button
	var h := int(enter.size.y)
	var top := int(_line_top(enter, float(UIKit.metrics().title_line_h)))
	if UIKit.tall_script():
		var ink: int = top + int(UIKit.BIG_INK_TOP.get(_code, UIKit.GOO_INK_ROW))
		_check(ink >= UIKit.GOO_INK_ROW, _tag("title: ENTER's glyphs from row %d" % ink))
	else:
		var marks: int = UIKit.mark_rows(enter.text, UIKit.FONT_BIG)
		_check(top - marks >= UIKit.GOO_INK_ROW and top + Title.BIG_LINE_INK + Title.ENTER_TEXT_BOTTOM <= h and top >= Title.ENTER_TEXT_TOP,
			_tag("title: ENTER's line on row %d of %d (marks %d): ink from row %d, drips over the outline" % [top, h, marks, top - marks]))
	if _code in Lang.GAP_LOCALES:
		for button: Button in [enter, page.story_button, page.quit_button]:
			var gaps := _ink_gaps(button)
			_check(absf(gaps.x - gaps.y) <= 1.0, _tag("title: %s's ink centred (%d / %d px)" % [button.text, gaps.x, gaps.y]))
	if _code == "en":
		_check(Rect2(enter.position, enter.size) == Rect2(72, 84, 176, 25) and top == 5
			and Rect2(page.story_button.position, page.story_button.size) == Rect2(4, 164, 40, 13)
			and Rect2(page.quit_button.position, page.quit_button.size) == Rect2(276, 164, 40, 13), _tag("title: the English ENTER / STORY / QUIT unchanged"))
	page.free()


## A button's clear columns left / right of its text's ink: Godot centres the shaped line's advance in the
## content box; the ink is the glyphs' bitmaps less the font cache's 1 px padding.
func _ink_gaps(button: Button) -> Vector2:
	var font: Font = button.get_theme_font("font")
	var size: int = button.get_theme_font_size("font_size")
	var style := button.get_theme_stylebox("normal")
	var server := TextServerManager.get_primary_interface()
	var shaped := server.create_shaped_text()
	server.shaped_text_add_string(shaped, button.text, font.get_rids(), size)
	var x := 0.0
	var first := INF
	var last := -INF
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		var rid: RID = glyph.font_rid
		if rid.is_valid() and int(glyph.index) != 0:
			var glyph_size: Vector2 = server.font_get_glyph_size(rid, Vector2i(size, 0), glyph.index)
			if glyph_size.x > 2.0:
				var left: float = x + glyph.offset.x + server.font_get_glyph_offset(rid, Vector2i(size, 0), glyph.index).x
				first = minf(first, left + 1.0)
				last = maxf(last, left + glyph_size.x - 1.0)
		x += glyph.advance
	server.free_rid(shaped)
	var content_w := button.size.x - style.content_margin_left - style.content_margin_right
	var start := style.content_margin_left + floorf((content_w - x) / 2.0)
	return Vector2(start + first, button.size.x - (start + last))


# ------------------------------------------------------------------ LANGUAGE

func _language() -> void:
	var page: Control = await _open("res://scenes/language.tscn")
	var codes := Lang.codes()
	var bad: Array[String] = []
	var row_tops := {}
	for i in codes.size():
		var code: String = codes[i]
		var top: int = page.name_top(code, i / page.COLUMNS)
		if top < 0:
			continue
		var button: Button = page.buttons[code]
		var h := int(button.size.y)
		var line := int(_line_top(button, UIKit.TEXT_BODY))
		var marks: int = UIKit.mark_rows(Lang.native_name(code))
		if line != top or line - marks < UIKit.GOO_INK_ROW or line + UIKit.TEXT_BODY + UIKit.TEXT_DRIP > h - 1:
			bad.append("%s line %d marks %d in %d" % [code, line, marks, h])
		var row: int = i / page.COLUMNS
		if row_tops.has(row) and row_tops[row] != line:
			bad.append("row %d: %s on %d, not %d" % [row, code, line, row_tops[row]])
		row_tops[row] = line
	_check(bad.is_empty(), _tag("LANGUAGE: the slimy names' marks under the lump row, drips over the outline, one line a row %s" % [bad]))
	_check(row_tops.get(0, -1) == 6, _tag("LANGUAGE: ENGLISH / ESPAÑOL / PORTUGUÊS on row 6 (ENGLISH 2 px lower than before F3b)"))
	page.free()


# ------------------------------------------------------------------ level select, map table

func _levels() -> void:
	for hard in [false, true]:
		progress.hard_mode = hard
		var ls: Control = await _open("res://scenes/level_select.tscn")
		var top: int = int(ls._info_top - ls.info_panel.position.y)  # (the two-line block's top: hard's one line sits in its middle)
		if _code == "en" or (_over() == 0 and not UIKit.tall_script()):
			_check(top == ls.INFO_PAD, _tag("level select: the info lines INFO_PAD under the panel's top (%d)" % top))
		else:
			_check(top - _over() >= UIKit.PANEL_INK_TOP, _tag("level select: the info lines' ink from panel row %d" % (top - _over())))
		ls.free()
	progress.hard_mode = false


func _maps() -> void:
	var ms: Control = await _open("res://scenes/maps.tscn")
	var ok := true
	for tile: Button in ms.tiles:
		var name_label: Label = tile.get_meta("name_label")
		ok = ok and name_label.position.y - _over() >= UIKit.GOO_INK_ROW
		for child in tile.get_children():
			if child is Label and child != name_label and not UIKit.tall_script():
				ok = ok and child.position.y + UIKit.TEXT_BODY + UIKit.TEXT_DRIP <= tile.size.y - UIKit.GOO_INK_ROW
	_check(ok, _tag("map table: names' ink from tile row %d, the %% line's drips over the bottom rows" % (ms._name_y - _over())))
	if _code == "en":
		_check(ms.tile_size == ms.TILE_SIZE and ms._name_y == 3 and ms._percent_y == 14 and ms.grid.position == Vector2(4, 21),
			_tag("map table: the English tiles unchanged"))
	ms.free()
