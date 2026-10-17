extends "res://tests/suite_base.gd"

## Fix pass R2 (docs/i18n/review/fixes-R2.md), checked in every locale (Arabic included) from the built
## controls, their texts' widths and the Language ink metrics:
## - HEAT panel: each toggle's icon drawn (its texture at its scale) inside its toggle, ICON_X - 1 or more
##   from both sides, mirrored too (Arabic: the 2x icons were mirrored at their 1x width, 9 px too far
##   right, over the toggle's frame); a one-line name keeps NAME_ROOM_PAD more than BUTTON_TEXT_PAD from
##   the edge wherever two lines fit (es NIEBLA VORAZ: 2 clear columns);
## - Devanagari buttons: 22 px, margins 3 / 2 (the lowest marks 1 clear row over the bottom border), the
##   LANGUAGE screen's row metric unchanged (21: the untrimmed native name);
## - map view: the name line's first ink (its marks) on row 3 or lower for every level and mode, the map
##   area under that line; English: MAP_AREA and row 3 for every map;
## - map table: every one-line tile name within name_room() (NAME_WRAP_PAD more than TEXT_PAD), and a name
##   that does not fit wrapped;
## - settings: the VOLUME slider at least VOLUME_SLIDER_MIN wherever the columns fit (de LAUTSTÄRKE: 42);
##   the SAVE CODE / RESET titles in the 16 px font in every Latin-script locale (pseudo: 8 px before),
##   a two-line RESET title's lines each inside the panel's text room.
## English pinned: the HEAT icons' drawn rects, MAP_AREA, the settings columns and slider (66 px).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_r2_layout.gd

const Report := preload("res://tests/i18n_report.gd")
const Lang := preload("res://scripts/language.gd")

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
	progress.maps = {}
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			progress.maps[progress.survey_key(level, hard)] = Survey.full(Levels.story_maze(level, hard), 30.0)
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		_buttons()
		await _heat_panel()
		await _maps()
		await _settings()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	progress.hard_mode = false
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


# ------------------------------------------------------------------ buttons

func _buttons() -> void:
	var m := UIKit.metrics()
	var b := UIKit.button_v_margins()
	var bh := UIKit.button_h()
	if UIKit.tall_script() and Lang.LINE_TRIM.has(_code):
		_check(b.x + int(m.ink_bottom) <= bh - 1 - UIKit.BOTTOM_INK_ROOM and b.x + int(m.ink_top) >= UIKit.GOO_INK_ROW,
			_tag("trimmed line: ink rows %d .. %d in a %d px button, 1 clear row over the border" % [b.x + int(m.ink_top), b.x + int(m.ink_bottom), bh]))
	if _code == "hi":
		_check(bh == 22 and b == Vector2i(3, 2) and int(Lang.metrics("hi").button_h) == 21,
			_tag("Devanagari button 22 (3 / 2), the LANGUAGE row metric 21 (%d, %s)" % [bh, b]))
	if _code == "en":
		_check(bh == 13 and b == Vector2i(3, 3), _tag("English button unchanged"))


# ------------------------------------------------------------------ HEAT panel

func _heat_panel() -> void:
	progress.hard_mode = true
	var ls: Node = await _open("res://scenes/level_select.tscn")
	var hp: Control = ls.heat_panel
	hp.open(ls, ls.heat_button)
	await _frames(2)
	UIKit.mirror_now(hp)
	var icons_ok := true
	var bad := ""
	for id: String in hp.toggles:
		var toggle: Button = hp.toggles[id]
		var icon: TextureRect = toggle.get_node("Icon")
		var drawn := Rect2(icon.global_position, Vector2(icon.texture.get_size()) * icon.scale)
		var box := toggle.get_global_rect().grow(-(hp.ICON_X - 1))
		if not box.encloses(drawn) or not box.encloses(icon.get_global_rect()):
			icons_ok = false
			bad = "%s icon %s in %s (box %s)" % [id, drawn, toggle.get_global_rect(), icon.size]
		if _code == "en" and id == "dim" and drawn != Rect2(toggle.get_global_rect().position + Vector2(5, 8), Vector2(18, 18)):
			icons_ok = false
			bad = "English DIM icon moved: %s" % drawn
	_check(icons_ok, _tag("HEAT: every icon drawn inside its toggle%s (%s)" % [" (mirrored)" if UIKit.rtl() else "", "ok" if bad == "" else bad]))
	if not hp.english and hp._geo.name_font == null and hp._geo.one_x.is_empty():
		var room: float = hp.toggle_size.x - hp._geo.name_x - UIKit.BUTTON_TEXT_PAD
		var two_fit: bool = hp._panel_h(UIKit.text_block_h(2), UIKit.tall_script()) <= UIKit.SCREEN.y - 2 * UIKit.EDGE
		var names_ok := true
		for id: String in hp.toggles:
			var name_label: Label = hp.toggles[id].get_node("Name")
			var lines := name_label.get_line_count() if name_label.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
			var one_word := not name_label.text.contains(" ")
			if lines == 1 and two_fit and not one_word and UIKit.text_w(name_label.text) > room - hp.NAME_ROOM_PAD:
				names_ok = false
		_check(names_ok, _tag("HEAT: a one-line name keeps BUTTON_TEXT_PAD + NAME_ROOM_PAD where two lines fit"))
	hp.close()
	await _frames(1)
	ls.free()
	progress.hard_mode = false
	await _frames(1)


# ------------------------------------------------------------------ maps

func _maps() -> void:
	var ms: Control = await _open("res://scenes/maps.tscn")
	var titles_ok := true
	var bad := ""
	for hard in [false, true]:
		ms.hard = hard
		for level in range(1, Levels.COUNT + 1):
			ms.open_view(level)
			var marks := UIKit.mark_rows(ms.view_title.text)
			var first_ink: float = ms.view_title.position.y - marks
			var area: Rect2i = ms.map_area
			var ok: bool = first_ink >= ms.VIEW_TITLE_INK and area.position.y == ms.view_title.position.y + UIKit.line_h() + 3 \
				and Rect2(area).encloses(Rect2(ms.view_map.position, ms.view_map.size))
			if _code == "en":
				ok = ok and area == ms.MAP_AREA and ms.view_title.position.y == 3
			if not ok and bad == "":
				bad = "L%d%s: title y %d marks %d area %s" % [level, " hard" if hard else "", ms.view_title.position.y, marks, area]
			titles_ok = titles_ok and ok
			ms.close_view()
	_check(titles_ok, _tag("map view: every name's marks from row 3, the map area under its line (%s)" % ("ok" if bad == "" else bad)))
	ms.hard = false
	ms._fill_grid()
	await _frames(1)
	var names_ok := true
	var name_bad := ""
	for tile: Button in ms.tiles:
		var name_label: Label = tile.get_meta("name_label")
		var w := UIKit.text_w(name_label.text)
		var wrapped: bool = name_label.autowrap_mode != TextServer.AUTOWRAP_OFF and name_label.get_line_count() > 1
		if (w > ms.name_room() and not wrapped) or name_label.size.x > ms.name_room() + 0.5:
			names_ok = false
			name_bad = "%s %d px (room %d)" % [name_label.text, w, ms.name_room()]
	_check(names_ok, _tag("map table: every one-line name within name_room (%s)" % ("ok" if name_bad == "" else name_bad)))
	ms.free()
	await _frames(1)


# ------------------------------------------------------------------ settings

func _settings() -> void:
	var page: Control = await _open("res://scenes/controls.tscn")
	var slider: HSlider = page.volume_slider
	var max_col := floori((UIKit.SCREEN.x - 2 * UIKit.EDGE - UIKit.GAP_L) / 2.0)
	_check(slider.size.x >= page.VOLUME_SLIDER_MIN or page.col_w == max_col,
		_tag("VOLUME slider %d px (min %d, column %d)" % [slider.size.x, page.VOLUME_SLIDER_MIN, page.col_w]))
	if _code == "en":
		_check(slider.size.x == 66 and page.col_w == 120, _tag("English slider 66, columns 120"))
	if not UIKit.tall_script():
		var big := [false, false]
		for i in 2:
			var panel: Control = page.code_panel if i == 0 else page.reset_confirm
			for child in panel.get_children():
				if child is Label and child.get_theme_font_size("font_size") == UIKit.FONT_BIG:
					big[i] = true
					for line: String in (child as Label).text.split("\n"):
						var rect: Rect2 = panel.get_meta("panel_rect")
						_check(UIKit.text_w(line, UIKit.FONT_BIG) <= rect.size.x - 2 * page.PANEL_TEXT_PAD,
							_tag("%s title line '%s' inside the panel's text room" % ["SAVE CODE" if i == 0 else "RESET", line]))
		_check(big[0] and big[1], _tag("SAVE CODE / RESET titles in the 16 px font (%s)" % [big]))
	page.free()
	await _frames(1)
