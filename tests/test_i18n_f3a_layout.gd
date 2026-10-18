extends "res://tests/suite_base.gd"

## Fix pass F3a (docs/i18n/review/fixes-F3a.md): the wardrobe, upgrades, hat wheel SHOP, HEAT panel and
## hub (coin board digits, notice) rows, checked in every locale (Arabic included) from the built
## controls and the Language ink metrics (ink_top / ink_bottom):
## - wardrobe: the 16 px title on every page; title, JELLY, the page button, the grid, the status / rule
##   lines, the stage and BACK none overlapping and inside the screen; the rule line's last ink 2+ rows
##   over the stage's frame (Arabic ى / ي under it before); JELLY / the page button clear of the title;
## - upgrades: the 16 px title, GAP_M+ clear of the tabs and the balance pod; every ABILITIES row's name
##   inking from row PANEL_INK_TOP (6) and its tag's last ink at h - PANEL_INK_BOTTOM or higher (English: one
##   more clear row, h - 5, and the panel 30 tall; Thai's name from row 5, the first under the lumps);
## - hat wheel SHOP: each tile's price on its name's text row (the price box at the name's top - 1);
## - HEAT panel: a 2x icon in every toggle whose name fits beside it; every name's room ends
##   BUTTON_TEXT_PAD from its toggle's edge;
## - hub: the coin board's digits on the CJK names' middle (ink_drop rows lower); the notice between the
##   stations on its rows and clear of the wheel.
## English pinned: the wardrobe and upgrades title / tab / pod rects, the SHOP's first price box.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_f3a_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

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
	progress.tickets = 60
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		await _wardrobe()
		await _upgrades()
		await _hub()
		await _heat_panel()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
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


func _rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size)


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


func _ink() -> Vector2i:
	var m := UIKit.metrics()
	return Vector2i(int(m.get("ink_top", 0)), int(m.get("ink_bottom", 8)))


func _overlaps(rects: Array) -> String:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)):
				return "%s x %s" % [rects[i], rects[j]]
	return ""


# ------------------------------------------------------------------ wardrobe

func _wardrobe() -> void:
	var skins := await _open("res://scenes/skins.tscn")
	var title: Label = skins._title
	for page: String in skins.PAGES:
		skins.show_page(page)
		await _frames(2)
		_check(title.get_theme_font_size("font_size") == UIKit.FONT_BIG, _tag("wardrobe %s: the 16 px title" % page))
		var grid: Control = {"skins": skins._skin_grid, "hats": skins._hat_grid, "trails": skins._trail_grid}[page]
		var stage := _rect(skins.showcase) if skins.showcase.visible else Rect2(skins.custom_panel.global_position, Vector2(0, 0))
		var title_ink := Rect2(160 - UIKit.text_w(title.text, UIKit.FONT_BIG) / 2.0, title.global_position.y, UIKit.text_w(title.text, UIKit.FONT_BIG), 1)
		var back: Button = null
		for child in skins.get_children():
			if child is Button and child.text == Loc.t("common.back", "BACK"):
				back = child
		var rects: Array = [_rect(grid), title_ink, _rect(skins.page_button), _rect(back)]
		if skins.jelly_button.visible:
			rects.append(_rect(skins.jelly_button))
		if skins.showcase.visible:
			rects.append(stage)
			var rule_last: float = skins._rule.global_position.y + _ink().y
			var clear_rows := 1 if skins.layout_plan.get("snug", false) else 2  # (snug: by the deepest ink any translation has)
			_check(rule_last + clear_rows < stage.position.y, _tag("wardrobe %s: rule line's last ink row %d, %d+ rows over the stage (%d)" % [page, rule_last, clear_rows, stage.position.y]))
			_check(SCREEN.encloses(stage), _tag("wardrobe %s: stage inside the screen %s" % [page, stage]))
		var status_first: float = skins.status.global_position.y + _ink().x
		_check(status_first >= _rect(grid).end.y + UIKit.GAP_XS, _tag("wardrobe %s: status ink GAP_XS+ under the grid" % page))
		var o := _overlaps(rects)
		_check(o == "", _tag("wardrobe %s: title, grid, buttons and stage apart %s" % [page, o]))
		for r: Rect2 in rects:
			_check(SCREEN.encloses(r), _tag("wardrobe %s: %s inside the screen" % [page, r]))
		if _code == "en":
			_check(_rect(grid).position.y == skins.GRID_TOP and _rect(skins.page_button).position == Vector2(276, 164),
				_tag("wardrobe %s: the English layout" % page))
	skins.free()


# ------------------------------------------------------------------ upgrades

func _upgrades() -> void:
	var upg := await _open("res://scenes/upgrades.tscn")
	upg.show_page("abilities")
	await _frames(2)
	var title: Label = null
	for child in upg.get_children():
		if child is Label and child.get_theme_font_size("font_size") == UIKit.FONT_BIG:
			title = child
	_check(title != null and title.get_theme_font("font") != UIKit.font_for(UIKit.FONT), _tag("upgrades: the 16 px title"))
	if title:
		var w := UIKit.text_w(title.text, UIKit.FONT_BIG)
		var r := _rect(title)
		var ink := Rect2(r.position.x + (r.size.x - w) / 2.0, r.position.y, w, 14)
		var tabs := _rect(upg.coins_tab).merge(_rect(upg.abilities_tab))
		var pod: Control = upg.coin_label.get_parent().get_parent()
		_check(not ink.grow(UIKit.GAP_M - 0.5).intersects(tabs) and not ink.grow(UIKit.GAP_M - 0.5).intersects(_rect(pod)),
			_tag("upgrades: the title GAP_M+ clear of the tabs %s and the pod %s (%s)" % [tabs, _rect(pod), ink]))
		if _code == "en":
			_check(absf(ink.get_center().x - 160.0) <= 0.5, _tag("upgrades: the English title centred"))
	var plan: Dictionary = upg._ability_plan
	var ink := _ink()
	if plan.small_font == null:
		var name_first: int = plan.inset_top + ink.x
		var tag_last: int = plan.inset_top + plan.tag_pitch + ink.y
		_check(name_first >= UIKit.PANEL_INK_TOP - 1 and tag_last <= plan.panel_h - UIKit.PANEL_INK_BOTTOM,  # (row 5: under the lumps, Thai)
			_tag("upgrades abilities: ink rows %d .. %d of %d, clear of the goo" % [name_first, tag_last, plan.panel_h]))
		if UIKit.locale() == "en":
			_check(plan.panel_h == 30 and tag_last == plan.panel_h - 5, _tag("upgrades abilities: English 30 px rows, 1 clear row over the lumps"))
	var rows: Array = []
	for id: String in upg.ability_rows:
		var row: Dictionary = upg.ability_rows[id]
		if (row.name as Label).is_visible_in_tree():
			rows.append(Rect2(row.name.global_position.x - 30, row.name.global_position.y - plan.inset_top, 300, plan.panel_h))
	var o := _overlaps(rows + [_rect(upg.back)])
	_check(o == "", _tag("upgrades abilities: rows and BACK apart %s" % o))
	upg.free()


# ------------------------------------------------------------------ hub: coin board, SHOP, notice

func _hub() -> void:
	var hub := await _open("res://scenes/hub.tscn")
	hub.set_physics_process(false)
	hub.open_coin_board()
	await _frames(2)
	var drop := int(UIKit.metrics().get("ink_drop", 0))
	var two_columns: bool = hub.board_numbers[0].position.y != hub.board_names[0].position.y or hub.board_numbers[5].position.x > 160
	if two_columns:
		_check(hub.board_numbers[0].position.y == hub.board_names[0].position.y + drop and hub.board_rows[0].position.y == hub.board_names[0].position.y + drop,
			_tag("coin board: the digits %d row(s) under the names' line top" % drop))
	hub.close_coin_board()
	hub.open_hat_wheel()
	await _frames(2)
	hub.hat_wheel.show_tab("shop")
	await _frames(2)
	var ok := true
	for id: String in hub.hat_wheel.shop_tiles:
		var tile: Button = hub.hat_wheel.shop_tiles[id]
		var name_label: Label = tile.get_child(0)
		var right: Control = tile.get_child(1)
		if not hub.hat_wheel._two_line_names:
			ok = ok and right.position.y == name_label.position.y - (0 if UIKit.tall_script() else 1)
		if _code == "en" and id == hub.hat_wheel.shop_tiles.keys()[0]:
			_check(right.position == Vector2(94, 2), _tag("hat wheel SHOP: the English price box"))
	_check(ok, _tag("hat wheel SHOP: every price on its name's text row"))
	hub.free()
	progress.tree_refund_notice = 888
	hub = await _open("res://scenes/hub.tscn")
	var notice: Control = hub.tree_notice
	var box := _rect(notice)
	var wheel_top: float = hub.rotor.position.y + hub.rotor.offset.y
	var clear := true
	for station: Dictionary in hub.stations:  # (by their resting ink since fix pass R3: test_i18n_r3_layout)
		if station.flat:
			continue
		var rest: Array = [0] if not station.anims.is_empty() else range(maxi(1, station.frames))
		var cols: Vector2 = hub._station_ink_cols(station, int(box.position.y), int(box.end.y), rest)
		if cols.x > cols.y or (cols.x <= 160.0 and cols.y >= 160.0):
			continue  # (no ink on its rows, or the station straight behind it)
		clear = clear and (cols.y < box.position.x or cols.x >= box.end.x)
	_check(clear and box.end.y <= wheel_top, _tag("hub notice %s clear of the stations and the wheel (top %d)" % [box, wheel_top]))
	hub.free()
	progress.tree_refund_notice = 0


# ------------------------------------------------------------------ HEAT panel

func _heat_panel() -> void:
	progress.hard_mode = true
	var ls := await _open("res://scenes/level_select.tscn")
	var hp: Control = ls.heat_panel
	hp.open(ls, ls.heat_button)
	await _frames(2)
	if not hp.english:
		var ok := true
		var icons_ok := true
		for id: String in hp.toggles:
			var toggle: Button = hp.toggles[id]
			var name_label: Label = toggle.get_node("Name")
			var icon: Control = toggle.get_node("Icon")
			var lines := name_label.get_line_count() if name_label.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
			var font: Font = name_label.get_theme_font("font")
			var w := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FONT).x if lines == 1 else name_label.size.x
			ok = ok and name_label.position.x + w <= toggle.size.x - UIKit.BUTTON_TEXT_PAD + 0.5
			var fits_2x: bool = UIKit.text_w(name_label.text, UIKit.FONT, font) <= toggle.size.x - hp._geo.name_x - UIKit.BUTTON_TEXT_PAD
			icons_ok = icons_ok and (icon.scale.x == 2 or not fits_2x)
		_check(ok, _tag("HEAT panel: every name BUTTON_TEXT_PAD+ from its toggle's edge"))
		_check(icons_ok, _tag("HEAT panel: a 2x icon wherever the name fits beside it"))
	hp.close()
	ls.free()
	progress.hard_mode = false
