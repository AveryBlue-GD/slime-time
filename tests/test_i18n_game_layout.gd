extends "res://tests/suite_base.gd"

## Layout in every locale (i18n chunk G4, docs/ui-rules.md section 10) of the CAULDRON (upgrades, both
## pages), the WARDROBE (skins / hats / trails), VICTORY, the pause menu (story, random, Descent), the
## HUD (area name + story line under the pods) and the results (win with and without the record banner,
## dry-up, randomizer win), plus the touch JUMP circle, with the gate on and the locale's fallback font
## installed. Arabic is skipped (its mirroring is chunk I). Measured from the built controls' rects and
## their texts' widths / line heights, per locale:
## - Upgrades: the tabs in a row GAP_XS apart, each fitting its word; the title (16 px, or the 8 px font
##   on the tabs' text line) clear of the tabs and the balance pod; the row panels inside the content
##   area, GAP_S apart, each holding its buttons / name / pips; the hint between the last panel and the
##   bottom row (or on the bottom row, clear of BACK), never past the screen's sides.
## - Wardrobe: top to bottom without overlaps: title, grid, status line, rule line, stage (the stage
##   above the bottom row, or on it between BACK and the page button with JELLY in the top-left
##   corner; when BACK / the page button are too wide to flank it, the page button top right, JELLY's
##   mirror, fix pass F3a); BACK and the page button one width, mirrored, fitting their words; a taller
##   script's 16 px title by its glyphs' ink over the grid; everything on screen.
## - Victory: the text block, the slimes and the menu in that order, the menu ending by row 176 and
##   wide enough for its words.
## - Pause: PAUSED above the panel and clear of the HUD pods; the buttons inside the panel (one column,
##   or two in a taller script); the panel ending by row 176; the Descent note under it, on screen.
## - HUD: the area name and story line clear of every pod (TEXT_CLEARANCE), inside the screen.
## - Results: the message panel, the record banner and the choice row apart from each other and from
##   the HUD pods, all on screen; the choice buttons one width, fitting their words.
## - Touch JUMP: the word JUMP_TEXT_CLEAR inside the ring (jump_radius), its line box centred.
## - English: the source rects pinned (pause panel (100, 55) 120 wide, upgrades rows 26 / 30 apart from
##   row 28, the wardrobe grid at 23 / status 89 / rule 100 / stage 112, the victory menu (100, 112)).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_game_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const SCREEN := Rect2(0, 0, 320, 180)
const BOTTOM := 176.0
## The wardrobe's 16 px title, a taller script: the last row its glyphs ink over the three pages (the
## title's body + its 2 px shadow), measured on the rendered captures (CJK 25 + 2, zh_TW 29 + 2, Thai /
## Devanagari 18 + 2, Arabic 22 + 2).
const TITLE_INK_END := {"ja": 27, "ko": 27, "zh_CN": 27, "zh_TW": 31, "th": 20, "hi": 20, "ar": 24}

var progress: Node
var language: Node
var _code := ""
## Failed checks are printed one per locale and check name (not one per control).
var _seen := {}


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	Economy.descent_force = 1
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		if code == "ar":
			continue
		_code = code
		language.set_locale(code)
		await _upgrades()
		await _wardrobe()
		await _victory()
		await _pause()
		await _hud()
		await _results()
		_touch_jump()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	progress.hard_mode = false
	_result()
	quit(1 if failures else 0)


## One check per locale and name: prints the first failure's detail only.
func _ok(ok: bool, name: String, detail := "") -> void:
	var key := "%s|%s" % [_code, name]
	if ok:
		if not _seen.has(key):
			_seen[key] = true
		return
	if str(_seen.get(key, "")) == "failed":
		return
	_seen[key] = "failed"
	_check(false, "%s: %s %s" % [_code, name, detail])


func _report(name: String) -> void:
	var key := "%s|%s" % [_code, name]
	if _seen.get(key, true) is bool:
		print("  ok   %s: %s" % [_code, name])


# ------------------------------------------------------------------ screens

func _upgrades() -> void:
	for page in ["coins", "abilities"]:
		var upg: Control = await _open("res://scenes/upgrades.tscn")
		upg.show_page(page)
		await _frames(2)
		var tabs: Array[Control] = [upg.coins_tab, upg.abilities_tab]
		_ok(_rect(tabs[1]).position.x - _rect(tabs[0]).end.x == UIKit.GAP_XS, "upgrades tabs GAP_XS apart")
		for tab in tabs:
			_ok(_fits(tab as Button), "upgrades tab fits its word", (tab as Button).text)
		var pod := _rect(upg.coin_label.get_parent().get_parent())
		_ok(SCREEN.encloses(pod) and pod.end.x == 320 - UIKit.EDGE, "upgrades pod top right")
		var title := _title(upg)
		if title:
			var ink := _text_rect(title)
			_ok(not ink.intersects(_rect(tabs[1]).grow(1)) and not ink.intersects(pod.grow(1)), "upgrades title clear of the tabs and pod", str(ink))
		var page_root: Control = upg.coin_page if page == "coins" else upg.ability_page
		var panels := page_root.get_children().filter(func(c: Node) -> bool: return c is Panel).map(func(c: Control) -> Rect2: return _rect(c))
		var area := UIKit.content_rect()
		# The gap the rows must keep, from what is on screen (not from the plan): GAP_S whenever this page's
		# rows at their measured height, GAP_S apart, still fit the content area with the hint under them
		# (GAP_M + its lines) or on the bottom row; GAP_XS only where they do not (fix pass F3a, ABILITIES).
		var want_gap := UIKit.GAP_S
		if page == "abilities" and not panels.is_empty():
			var row_h: float = (panels[0] as Rect2).size.y
			var hint_r := _text_rect(upg.hint)
			var hint_in_row: bool = hint_r.position.y >= _rect(upg.back).position.y - 1
			var need := panels.size() * row_h + (panels.size() - 1) * UIKit.GAP_S + (0.0 if hint_in_row else UIKit.GAP_M + hint_r.size.y)
			if need > area.size.y:
				want_gap = UIKit.GAP_XS
		for i in panels.size():
			var p: Rect2 = panels[i]
			_ok(area.grow(0.5).encloses(p), "upgrades panels in the content area", str(p))
			if i > 0:
				_ok(p.position.y - (panels[i - 1] as Rect2).end.y == want_gap, "upgrades panels GAP_S apart (GAP_XS only where GAP_S rows do not fit)",
					"%s gap %d want %d" % [page, p.position.y - (panels[i - 1] as Rect2).end.y, want_gap])
		var rows: Dictionary = upg.rows if page == "coins" else upg.ability_rows
		var r := 0
		for id: String in rows:
			var row: Dictionary = rows[id]
			var p: Rect2 = panels[r]
			_ok(p.encloses(_rect(row.plus)), "upgrades + inside its panel", "%s %s" % [_rect(row.plus), p])
			_ok(p.encloses(_text_rect(row.name)), "upgrades name inside its panel", "%s %s" % [_text_rect(row.name), p])
			if row.has("tag"):
				# (a tag lifted over its name's empty rows by its slimy drips, leftover pass: only those rows may overlap)
				var lifted := maxf(0.0, row.name.position.y + float(upg._ability_plan.tag_pitch) - row.tag.position.y)
				_ok(p.encloses(_text_rect(row.tag)) and not _text_rect(row.tag).grow_side(SIDE_TOP, -lifted).intersects(_text_rect(row.name)), "upgrades tag under the name, inside its panel")
			r += 1
		var hint := _text_rect(upg.hint)
		var back := _rect(upg.back)
		_ok(SCREEN.encloses(hint), "upgrades hint on screen", str(hint))
		_ok(not hint.intersects(back) and not hint.intersects(panels[-1]), "upgrades hint clear of BACK and the rows", "%s %s %s" % [hint, back, panels[-1]])
		_ok(_fits(upg.back), "upgrades BACK fits its word")
		if _code == "en":
			_ok((panels[0] as Rect2).position.y == 26 and (panels[1] as Rect2).position.y - (panels[0] as Rect2).position.y == (26 if page == "coins" else 33),  # (ABILITIES: 30 px rows since fix pass F3a, the tags' drips off the goo)
				"upgrades English rows pinned")
		upg.free()
	for name in ["upgrades tabs GAP_XS apart", "upgrades tab fits its word", "upgrades pod top right", "upgrades title clear of the tabs and pod",
			"upgrades panels in the content area", "upgrades panels GAP_S apart (GAP_XS only where GAP_S rows do not fit)", "upgrades + inside its panel", "upgrades name inside its panel",
			"upgrades tag under the name, inside its panel", "upgrades hint on screen", "upgrades hint clear of BACK and the rows", "upgrades BACK fits its word"]:
		_report(name)


func _wardrobe() -> void:
	var skins: Control = await _open("res://scenes/skins.tscn")
	for page: String in skins.PAGES:
		skins.show_page(page)
		await _frames(2)
		var grid: Control = skins.grid_for(page)
		var title := _text_rect(skins._title)
		var g := _rect(grid)
		var status := _text_rect(skins.status)
		var rule := _text_rect(skins._rule)
		var back := _rect(skins.get_children().filter(func(c: Node) -> bool: return c is Button and c.text == Loc.t("common.back", "BACK"))[0])
		var page_b := _rect(skins.page_button)
		# (a taller script's 16 px title: its glyphs' ink, not its line box's empty rows, over the grid: fix pass F3a)
		var titles: Array[String] = []
		for which: String in skins.PAGES:
			titles.append(skins.page_title(which))
		# (a taller script's title: its last inked row, the 2 px shadow included, measured on the rendered
		# wardrobe titles (tools/i18n_capture.sh, all three pages) and pinned per script, R1)
		var title_end := title.end.y
		if UIKit.tall_script():
			var pinned: int = TITLE_INK_END[_code]
			_ok(UIKit.title_ink_end(titles, skins._title.get_theme_font("font")) == pinned, "wardrobe title ink end as measured",
				"%d measured %d" % [UIKit.title_ink_end(titles, skins._title.get_theme_font("font")), pinned])
			title_end = pinned + 1.0
		_ok(title_end <= g.position.y and g.end.y <= status.position.y and status.end.y <= rule.position.y,
			"wardrobe title, grid, status, rule in order", "%s %s %s %s" % [title, g, status, rule])
		if UIKit.button_h() == UIKit.BUTTON_H:  # (English metrics: BACK 40 as everywhere; the page button its widest page name's width, EDGE from the right)
			_ok(back.position.x == UIKit.EDGE and page_b.end.x == 320 - UIKit.EDGE and page_b.position.y == back.position.y, "wardrobe BACK / page button mirrored")
		elif skins.layout_plan.get("top_page", false):  # (fix pass F3a: the page button top right, JELLY's mirror; BACK its own width)
			_ok(back.position.x == UIKit.EDGE and page_b.end.x == 320 - UIKit.EDGE and page_b.position.y == UIKit.EDGE, "wardrobe BACK / page button mirrored, one width")
		else:
			_ok(back.size == page_b.size and back.position.x == UIKit.EDGE and page_b.end.x == 320 - UIKit.EDGE, "wardrobe BACK / page button mirrored, one width")
		_ok(_fits(skins.page_button), "wardrobe page button fits its word", skins.page_button.text)
		for r: Rect2 in [title, g, status, rule, back, page_b]:
			_ok(SCREEN.encloses(r), "wardrobe on screen", str(r))
		if page == "skins":
			var stage := _rect(skins.showcase)
			stage.size = SkinShowcase.STAGE_SIZE
			var jelly := _rect(skins.jelly_button)
			_ok(rule.end.y <= stage.position.y and stage.end.y <= BOTTOM, "wardrobe stage under the rule line, by row 176", "%s %s" % [rule, stage])
			_ok(not stage.intersects(back) and not stage.intersects(page_b) and not stage.intersects(jelly), "wardrobe stage clear of the buttons")
			_ok(not jelly.intersects(g) and not jelly.intersects(title), "wardrobe JELLY clear of the grid and title", "%s %s" % [jelly, title])
			_ok(_fits(skins.jelly_button), "wardrobe JELLY fits its word")
			# PASTEL (once the randomizer is open) sits right of JELLY, the two centred together.
			var pastel_on: bool = skins.pastel_button.visible
			if pastel_on and _code == "en":
				var pastel := _rect(skins.pastel_button)
				_ok(not stage.intersects(pastel) and not pastel.intersects(page_b) and pastel.position.x > jelly.end.x, "wardrobe PASTEL right of JELLY, clear of the stage and the page button")
				_ok(_fits(skins.pastel_button), "wardrobe PASTEL fits its word", skins.pastel_button.text)
			if _code == "en":
				var jelly_x: float = UIKit.center_x(jelly.size.x + UIKit.GAP_M + skins.pastel_button.size.x) if pastel_on else 120.0
				_ok(g.position.y == 23 and skins.status.offset_top == 89 and skins._rule.offset_top == 100 and stage.position.y == 112 and jelly.position == Vector2(jelly_x, 164),
					"wardrobe English rects pinned", str(jelly.position))
	skins.free()
	for name in ["wardrobe title, grid, status, rule in order", "wardrobe title ink end as measured", "wardrobe BACK / page button mirrored, one width", "wardrobe page button fits its word",
			"wardrobe on screen", "wardrobe stage under the rule line, by row 176", "wardrobe stage clear of the buttons",
			"wardrobe JELLY clear of the grid and title", "wardrobe JELLY fits its word"]:
		_report(name)
	for name in ["wardrobe PASTEL right of JELLY, clear of the stage and the page button", "wardrobe PASTEL fits its word"]:
		if _code == "en":
			_report(name)


func _victory() -> void:
	var victory: Control = await _open("res://scenes/victory.tscn")
	var lines: Label = victory.get_children().filter(func(c: Node) -> bool: return c is Label and c.get_theme_font_size("font_size") == UIKit.FONT)[0]
	var star: Node2D = victory.get_children().filter(func(c: Node) -> bool: return c is AnimatedSprite2D)[-1]
	var menu: Control = victory.buttons[0].get_parent()
	var text := _text_rect(lines)
	var m := _rect(menu)
	_ok(text.end.y + int(UIKit.metrics().ink_below) < star.position.y - 18 + 1, "victory text above the slimes", "%s star %s" % [text, star.position])
	_ok(star.position.y + 11 < m.position.y and m.end.y <= BOTTOM, "victory menu under the slimes, by row 176", "%s %s" % [star.position, m])
	_ok(SCREEN.encloses(text), "victory text on screen", str(text))
	for b: Button in victory.buttons:
		_ok(_fits(b), "victory buttons fit their words", b.text)
	if _code == "en":
		_ok(m.position == Vector2(100, 112) and m.size.x == 120 and star.position == Vector2(160, 80), "victory English rects pinned")
	victory.free()
	for name in ["victory text above the slimes", "victory menu under the slimes, by row 176", "victory text on screen", "victory buttons fit their words"]:
		_report(name)


func _pause() -> void:
	for kind in ["story", "random", "descent"]:
		var game: Node
		seed(20261017)
		if kind == "descent":
			progress.start_descent(77)
			game = await _spawn_game({})
		elif kind == "random":
			progress.start_random()
			game = await _spawn_game({})
		else:
			progress.start_story(3)
			game = await _spawn_game({level = 3})
		await _frames(2)
		var menu = game.pause_menu
		menu.open()
		await _frames(2)
		var panel := _rect(menu._panel)
		var title := _text_rect(menu._title)
		_ok(title.end.y <= panel.position.y and SCREEN.encloses(title), "pause PAUSED above the panel", "%s %s" % [title, panel])
		_ok(panel.end.y <= BOTTOM and panel.position.x >= UIKit.EDGE, "pause panel on screen, by row 176", str(panel))
		for pod: Rect2 in game.hud.pod_rects():
			_ok(not title.intersects(pod), "pause PAUSED clear of the HUD pods", "%s %s" % [title, pod])
		for child: Control in menu._menu.get_children():
			if child.visible:
				_ok(panel.encloses(_rect(child)), "pause buttons inside the panel", "%s %s" % [_rect(child), panel])
				if child is Button and child != menu.seed_button:
					_ok(_fits(child), "pause buttons fit their words", (child as Button).text)
		if menu.descent_note.visible:
			var note := _text_rect(menu.descent_note)
			_ok(note.position.y >= panel.end.y and note.end.y <= 180 and SCREEN.encloses(note), "pause Descent note under the panel", "%s %s" % [note, panel])
		if _code == "en":
			_ok(panel.position == Vector2(100, 55) and panel.size.x == 120, "pause English panel pinned")
		menu.resume()
		paused = false
		game.free()
	for name in ["pause PAUSED above the panel", "pause panel on screen, by row 176", "pause PAUSED clear of the HUD pods", "pause buttons inside the panel",
			"pause buttons fit their words", "pause Descent note under the panel"]:
		_report(name)


func _hud() -> void:
	for c: Dictionary in [{level = 1}, {level = 10}, {level = 7, hard = true}, {level = 8}]:
		var game := await _start(c)
		await _frames(3)
		var hud = game.hud
		for label: Label in [hud.area_label, hud.story_label]:
			if not label.visible or label.text == "":
				continue
			var ink := _text_rect(label)
			_ok(SCREEN.encloses(ink), "hud area texts on screen", "%s %s" % [label.text.left(20), ink])
			for pod: Rect2 in hud.pod_rects():
				_ok(not ink.intersects(pod), "hud area texts clear of the pods", "%s %s %s" % [label.text.left(20), ink, pod])
		game.free()
		progress.hard_mode = false
	for name in ["hud area texts on screen", "hud area texts clear of the pods"]:
		_report(name)


func _results() -> void:
	for c: Dictionary in [{level = 3, record = true}, {level = 10}, {level = 4, dry = true}, {random = true}]:
		var game := await _start(c)
		if c.get("dry", false):
			game._dry_up()
			game.hud.show_rewards({offer = true})
			game._offer_retry()
		else:
			game._on_goal_body_entered(game.slime)
			if c.get("random", false):
				game.hud.show_rewards({tickets = 4, attempt = 2, cap = "replay"})
			else:
				game.hud.show_rewards({tier = 3, best = 3, new_best = true})
			if c.get("record", false):
				game.hud.show_record(13.6)
			game._offer_next_steps()
		await _frames(3)
		var hud = game.hud
		var panel := _rect(hud._message_panel)
		var rects := {panel = panel}
		if hud.record_banner.visible:
			rects.banner = _rect(hud.record_banner.get_child(0))
		var row := Rect2()
		for b: Button in hud.choice_buttons:
			row = _rect(b) if row.size == Vector2.ZERO else row.merge(_rect(b))
			_ok(_fits(b), "result choices fit their words", b.text)
			_ok(_rect(b).size.x == _rect(hud.choice_buttons[0]).size.x, "result choices one width")
		rects.choices = row
		for key: String in rects:
			_ok(SCREEN.encloses(rects[key]), "result parts on screen", "%s %s" % [key, rects[key]])
		var keys := rects.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				_ok(not (rects[keys[i]] as Rect2).intersects(rects[keys[j]]), "result panel, banner and choices apart", "%s %s / %s %s" % [keys[i], rects[keys[i]], keys[j], rects[keys[j]]])
		for pod: Rect2 in hud.pod_rects():
			_ok(not panel.intersects(pod), "result panel clear of the HUD pods", "%s %s" % [panel, pod])
		game.free()
	for name in ["result choices fit their words", "result choices one width", "result parts on screen", "result panel, banner and choices apart",
			"result panel clear of the HUD pods"]:
		_report(name)


func _touch_jump() -> void:
	var font: Font = UIKit.font_for(UIKit.FONT)
	for key in ["touch.jump"]:
		var text := Loc.t(key, "JUMP")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := TouchControls.jump_radius(w, font.get_height(8))
		var corner := Vector2(w / 2.0 + TouchControls.JUMP_TEXT_CLEAR, minf(font.get_height(8), 9.0) / 2.0)
		_ok(corner.length() + 1.0 <= r and r <= 23.0, "touch JUMP inside its ring", "%s w %d r %d" % [text, w, r])
		var top := TouchControls.jump_baseline(font) - font.get_ascent(8)
		_ok(absf(top + font.get_height(8) / 2.0 - float(UIKit.metrics().get("ink_nudge", 0))) <= 1.0, "touch JUMP line box centred", "%s top %d" % [text, top])
		if _code == "en":
			_ok(r == TouchControls.JUMP_RADIUS and TouchControls.jump_baseline(font) == 3.0, "touch JUMP English pinned")
	_report("touch JUMP inside its ring")
	_report("touch JUMP line box centred")


# ------------------------------------------------------------------ helpers

func _start(c: Dictionary) -> Node:
	seed(20261017)
	progress.hard_mode = c.get("hard", false)
	if c.get("random", false):
		progress.start_random()
		return await _spawn_game({})
	progress.start_story(c.level)
	return await _spawn_game({level = c.level})


## The screen title (the 16 px label setup_screen made, maybe stepped down to 8 px by fit_text).
func _title(screen: Control) -> Label:
	for child in screen.get_children():
		if child is Label and child.text == Loc.t("upgrades.title", "UPGRADES"):
			return child
	return null


## A button holds its word: its width at least the text plus BUTTON_TEXT_PAD each side (or 2 px each
## side for the - / + glyph buttons), its height at least button_h().
func _fits(button: Button) -> bool:
	var w := UIKit.text_w(button.text)
	return button.size.x >= w + 2 * mini(UIKit.BUTTON_TEXT_PAD, 2) and button.size.y >= UIKit.button_h() - 0.5


## Where a Label's text is: its lines' widest width (centred / left / right as aligned) by its line
## boxes (+ the marks drawn above and the drips under them), in screen coordinates.
func _text_rect(label: Label) -> Rect2:
	var r := _rect(label)
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var lines := label.text.split("\n")
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		lines.resize(label.get_line_count())
	var w := 0.0
	for line in label.text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w = minf(w, r.size.x) if label.autowrap_mode != TextServer.AUTOWRAP_OFF else w
	var line_h := font.get_height(size)
	var h := lines.size() * line_h + (lines.size() - 1) * label.get_theme_constant("line_spacing")
	var x := r.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += floorf((r.size.x - w) / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - w
	var y := r.position.y
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y += floorf((r.size.y - h) / 2.0)
	var marks := UIKit.metrics()
	var small := size == UIKit.FONT
	var drips := float(marks.ink_below) if small else 2.0 * float(marks.ink_below)
	var above := float(marks.ink_above) if small else float(marks.title_above)  # (the 16 px font: twice the marks)
	return Rect2(x, y - above, w, h + above + drips)


func _rect(control: Control) -> Rect2:
	var xf := control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
