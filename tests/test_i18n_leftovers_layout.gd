extends "res://tests/suite_base.gd"

## Leftover pass L2 (docs/i18n/review/leftovers.md): the rows fixed last, in every locale (Arabic included):
## - upgrades ABILITIES: in a taller script every tag's own ink (a slimy digit's drips counted: UIKit.ink_rows
##   with drips) ends on row h - PANEL_INK_BOTTOM - 1 or higher (zh_TW `3X3爆破`, hi `बम 3X3` were on the
##   lump rows' edge), and stays 2 clear rows under its name's ink;
## - result panels: a taller script's last row (digits' drips) ends on h - PANEL_INK_BOTTOM or higher
##   (zh_TW `第2次 = +4` was on the lumps); the panel ends GAP_XS over the banner title's own marks
##   (pseudo `[_ÑÉW RÉÇÖRĐ!__]`: 6 rows over its line box, they were on the panel's bottom goo);
## - key controls: the widest action label GAP_L clear of its key wherever both columns still fit
##   (SALTAR (MANTÉN) was 4 px from SPACE);
## - hat wheel SHOP: GAP_L between a grown tile's longest name and its price (ru КЕПКА-ПРОПЕЛЛЕР);
## - pause SEED button: its text keeps BUTTON_TEXT_PAD each side (ko / zh_CN filled it to 1 clear column);
## - SAVE CODE (English): no page label left under the panel's band rows (the SETTINGS title's drips
##   showed through its top band), the page's buttons kept as English had them.
## English pinned: key controls label column 84, SAVE CODE panel rect, the L3 result panel.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_leftovers_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")

var progress: Node
var language: Node
var _code := ""


func _initialize() -> void:
	Economy.descent_force = 1
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
		await _abilities()
		await _results()
		await _keys()
		await _shop()
		await _pause_seed()
		await _save_code()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
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


## The first / last row `label`'s text inks (drips included), in screen rows.
func _ink(label: Label) -> Vector2i:
	var texts: Array[String] = [label.text]
	var rows := UIKit.ink_rows(texts, label.get_theme_font("font"), UIKit.FONT, true)
	return rows + Vector2i(int(label.global_position.y), int(label.global_position.y))


# ------------------------------------------------------------------ upgrades ABILITIES

func _abilities() -> void:
	var upg := await _open("res://scenes/upgrades.tscn")
	upg.show_page("abilities")
	await _frames(2)
	var plan: Dictionary = upg._ability_plan
	if UIKit.tall_script():
		for id: String in upg.ability_rows:
			var row: Dictionary = upg.ability_rows[id]
			var name_label: Label = row.name
			if not name_label.is_visible_in_tree():
				continue
			var panel_end := int(name_label.global_position.y) - int(plan.inset_top) + int(plan.panel_h)
			var tag := _ink(row.tag)
			var name_ink := _ink(name_label)
			_check(tag.y <= panel_end - UIKit.PANEL_INK_BOTTOM - 1 or tag.x - name_ink.y - 1 <= 2,
				_tag("ABILITIES %s: tag ink ends %d, 1 clear row over the lumps (panel end %d)" % [id, tag.y, panel_end]))
			_check(tag.x - name_ink.y - 1 >= 2, _tag("ABILITIES %s: tag ink 2+ rows under the name's (%d .. %d)" % [id, name_ink.y, tag.x]))
	upg.free()


# ------------------------------------------------------------------ results

func _results() -> void:
	for c: Dictionary in [{level = 3}, {random = true}]:
		seed(20261017)
		var game: Node
		if c.get("random", false):
			progress.start_random()
			game = await _spawn_game({})
		else:
			progress.start_story(c.level)
			game = await _spawn_game({level = c.level})
		game._on_goal_body_entered(game.slime)
		if c.get("random", false):
			game.hud.show_rewards({tickets = 4, attempt = 2, cap = "replay"})
		else:
			game.hud.show_rewards({tier = 3, best = 3, new_best = true})
			game.hud.show_record(13.6)
		game._offer_next_steps()
		await _frames(3)
		var hud = game.hud
		var panel := _rect(hud._message_panel)
		var last: Control = hud._rewards_row2 if hud._rewards_row2 and hud._rewards_row2.visible else hud.rewards_row
		if UIKit.tall_script():
			for l: Node in last.get_children():
				if l is Label and not l.is_queued_for_deletion():
					var ink := _ink(l)
					_check(ink.y <= int(panel.end.y) - UIKit.PANEL_INK_BOTTOM,
						_tag("result %s last row: ink ends %d, over the bottom lumps (panel end %d)" % [c, ink.y, panel.end.y]))
		if hud.record_banner.visible:
			var title: Label = hud._banner_title
			var size := UIKit.FONT_BIG if hud._banner_words.vertical else UIKit.FONT
			var marks_top := title.global_position.y - UIKit.mark_rows(title.text, size)
			_check(panel.end.y + UIKit.GAP_XS <= marks_top + 0.5,
				_tag("result L3: panel ends %d, GAP_XS over the banner title's marks (%d)" % [panel.end.y, marks_top]))
		if _code == "en" and not c.get("random", false):
			_check(panel == Rect2(92, 53, 136, 54), _tag("English L3 result panel pinned %s" % panel))
		game.free()


# ------------------------------------------------------------------ key controls

func _keys() -> void:
	var page: Control = await _open("res://scenes/key_controls.tscn")
	var widest := 0
	for grid: GridContainer in page.grids:
		for i in range(0, grid.get_child_count(), 2):
			widest = maxi(widest, UIKit.text_w((grid.get_child(i) as Label).text))
	var room := int(UIKit.SCREEN.x) - 2 * UIKit.EDGE
	var key_min := UIKit.button_w(page.press_key_text(), 0)
	var fits_gap: bool = 2 * (maxi(page.LABEL_WIDTH, widest + UIKit.GAP_L - page.GAP) + page.GAP + key_min) + page.COLUMN_GAP <= room
	var gap: int = page.label_w + page.GAP - widest
	_check(gap >= UIKit.GAP_L or not fits_gap, _tag("CONTROLS: widest label %d px, %d px to its key" % [widest, gap]))
	if _code == "en":
		_check(page.label_w == page.LABEL_WIDTH and page.key_w == page.KEY_WIDTH, _tag("CONTROLS: English columns 84 / 64"))
	page.free()


# ------------------------------------------------------------------ hat wheel SHOP

func _shop() -> void:
	var hub := await _open("res://scenes/hub.tscn")
	hub.set_physics_process(false)
	hub.open_hat_wheel()
	await _frames(2)
	var wheel = hub.hat_wheel
	wheel.show_tab("shop")
	await _frames(2)
	if wheel.tile_size.x > wheel.TILE.x and not wheel._two_line_names:
		var max_w := floorf((wheel.PANEL.size.x - 2 * wheel.GRID_MIN_INSET - wheel.GRID_GAP) / 2.0)
		for id: String in wheel.shop_tiles:
			var need: int = wheel.TILE_PAD + UIKit.text_w(wheel._name_of(id)) + UIKit.GAP_L + wheel._right_w(id) + wheel.TILE_PAD
			var room: float = wheel.tile_size.x - wheel.TILE_PAD - UIKit.text_w(wheel._name_of(id)) - wheel._right_w(id) - wheel.TILE_PAD
			_check(room >= UIKit.GAP_L or need > max_w, _tag("SHOP %s: %d px between name and price" % [id, room]))
	hub.free()


# ------------------------------------------------------------------ pause SEED

func _pause_seed() -> void:
	seed(20261017)
	progress.start_random()
	var game := await _spawn_game({})
	game.pause_menu.open()
	await _frames(2)
	var button: Button = game.pause_menu.seed_button
	var w := UIKit.text_w(button.text)
	_check(w + 2 * UIKit.BUTTON_TEXT_PAD <= button.size.x, _tag("pause SEED: %s (%d px) keeps BUTTON_TEXT_PAD in %d" % [button.text, w, button.size.x]))
	game.pause_menu.resume()
	game.free()


# ------------------------------------------------------------------ SAVE CODE (English ghosts)

func _save_code() -> void:
	if _code != "en":
		return
	var page: Control = await _open("res://scenes/controls.tscn")
	page._open_codes()
	await _frames(2)
	var rect: Rect2 = page.code_panel.get_meta("panel_rect")
	var top_band := Rect2(rect.position, Vector2(rect.size.x, UIKit.PANEL_INK_TOP))
	var bottom_band := Rect2(rect.end - Vector2(rect.size.x, UIKit.PANEL_INK_TOP), Vector2(rect.size.x, UIKit.PANEL_INK_TOP))
	var buttons := 0
	for child in page.get_children():
		if child is Label and child.visible:
			var r := Rect2(child.position, child.size)
			_check(not r.intersects(top_band) and not r.intersects(bottom_band), _tag("SAVE CODE: label %s not under the panel's band rows" % child.text))
		elif child is Button and child.visible:
			buttons += 1
	_check(buttons > 0, _tag("SAVE CODE: the page's buttons keep their English ghosts"))
	page._close_codes()
	page.free()
