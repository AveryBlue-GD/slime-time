extends "res://tests/suite_base.gd"

## Every screen in every language (docs/i18n/plan.md section 9.3, chunk F). For English, the 17
## translations and the pseudo locale, with the gate on, builds every screen / overlay / HUD state the
## test_ui_layout.gd harness reaches (title, level select normal / hard + HEAT panel, map table + map
## view, upgrades both pages, wardrobe pages, settings + save code + reset confirm, key controls,
## LANGUAGE, victory, the story intro cards, the hub + each station's prompt + quit / portal / resume /
## coin board / hat wheel + shop + the one-time notice, the HUD on story (+ every coin found) / hard + HEAT /
## assisted / randomizer levels and the Descent pot pod (wide gain / paid-run values), the
## win / dry-up / randomizer results with their rewards and choice rows, pause on story / random /
## Descent, the restart prompt, the Descent boon card and summary) and measures every visible Label
## and Button that shows text, with the font it really uses (the locale's fallback installed):
## - overflow: the widest line wider than the label, or than the button's content box (minus its
##   style margins and icon);
## - clip: the lines taller than the label / button content box;
## - grew: a button bigger than the same button in English beyond what the UIKit sizing helpers give
##   for its text in that locale (_growth: a width UIKit.noted_text_w recomputes from the texts the
##   screen sized it for, i.e. button_w / back_size / tab_widths / an equal-width group; a height of
##   the locale's button_h, plus a line pitch per extra line, or big_button_h for 16 px buttons). Such
##   deliberate widening is not a finding (counted per locale in the report's notes); accepted by
##   measurement only, never by node name;
## - offscreen: the text's ink box (or a button) not inside the 320x180 screen (the safe area);
## - overlap: a text's ink box over another text or another button (not its own parent / child).
## Each finding goes into docs/i18n/fit-report.screens.json + fit-report.md (tests/i18n_report.gd),
## "accepted" when English shows the same thing at the same node (the source layout), or when it is on
## the KNOWN list below. Node ids are stable paths (names, or Class + index for generated nodes).
## Not measured: text drawn with draw_string (tutorial key caps, the touch JUMP button), textures.
## ENFORCED for every locale (chunk G5; Arabic since chunk I's right-to-left mirroring): an open finding fails
## the suite. A mirrored (RTL) control's text is measured where Godot draws it: LEFT / RIGHT alignment and a
## button's icon side swap in a right-to-left layout.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_i18n_screens.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const ENFORCE := true
## Locales whose findings are reported but do not fail the suite (none since chunk I).
const REPORT_ONLY: Array[String] = []
const Lang := preload("res://scripts/language.gd")
const Report := preload("res://tests/i18n_report.gd")
const SCREEN := Rect2(0, 0, 320, 180)
## Known-acceptable findings in every locale: [state prefix, node id substring, kind, reason].
## Empty: everything English shows is accepted already, and deliberate widening is measured (_growth),
## not listed by node.
const KNOWN := []

var progress: Node
var language: Node
var issues: Array = []
## English per state and node id: {text, rect} (the baseline the other locales are compared with).
var english := {}
## English findings: "state|node|kind|other" -> true.
var english_issues := {}
## msgid -> msgctxt for texts without placeholders (to name the key of an English text).
var keys_by_text := {}
var states_seen := {}
var _code := ""
## Per locale: buttons wider than in English exactly as the UIKit sizing helpers make them for their
## text (not findings; counted in the report's notes).
var deliberate := {}


func _initialize() -> void:
	Economy.descent_force = 1  # Descent is switched off in the game (D11); its screens are still measured
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	for entry in Report.po_entries("res://locale/messages.pot"):
		if not entry.msgid.contains("{") and not keys_by_text.has(entry.msgid):
			keys_by_text[entry.msgid] = entry.ctx
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		_check(language.locale == code, "%s: locale set" % code)
		var before := states_seen.size()
		await _all_states()
		if code == "en":
			_check(states_seen.size() > 40, "en: %d screen states built" % states_seen.size())
		else:
			_check(states_seen.size() == before, "%s: the same screen states as English" % code)
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	var open := issues.filter(func(i: Dictionary) -> bool: return not i.acceptable)
	var counts := PackedStringArray()
	for code: String in Report.LOCALE_ORDER:
		if deliberate.has(code):
			counts.append("%s %d" % [code, deliberate[code]])
	Report.write("screens", issues, {
		states = "%d screen / overlay / HUD states per locale" % states_seen.size(),
		deliberate_widths = "buttons wider than in English exactly as UIKit's sizing helpers make them for their text (not findings): " + ", ".join(counts),
		enforced = ("every locale" if REPORT_ONLY.is_empty() else "every locale but %s" % ", ".join(REPORT_ONLY))
			+ (" (English-only mode: English fails, the other locales are reported)" if I18nMode.ENGLISH_ONLY else ""),
		measured = "every visible Label / Button with text: width and lines vs its box, ink inside 320x180, overlaps with other texts and buttons, buttons grown past their English size",
		not_measured = "draw_string text (tutorial key caps, touch JUMP), textures (logo), the web shell",
	})
	for code: String in Report.LOCALE_ORDER:
		var mine := open.filter(func(i: Dictionary) -> bool: return i.locale == code)
		if not mine.is_empty():
			print("  report %s: %d open (e.g. %s %s %s)" % [code, mine.size(), mine[0].screen, mine[0].kind, mine[0].text.left(24)])
	print("  screens report: %d open, %d accepted -> docs/i18n/fit-report.md" % [open.size(), issues.size() - open.size()])
	if ENFORCE:
		var failing := open.filter(func(i: Dictionary) -> bool: return not i.locale in REPORT_ONLY)
		# English-only mode (tests/i18n_mode.gd): English's own findings fail, the other locales' are reported (list + report)
		var english := failing.filter(func(i: Dictionary) -> bool: return i.locale == "en")
		var others := failing.filter(func(i: Dictionary) -> bool: return i.locale != "en")
		_check(english.is_empty(), "every English text fits its box (%d open)" % english.size())
		_check_locale(others.is_empty(), "every text fits its box in every locale (%d open%s)" % [failing.size(),
			"" if REPORT_ONLY.is_empty() else ", reported only: " + ", ".join(REPORT_ONLY)])
		if not failing.is_empty():
			for i: Dictionary in failing.slice(0, 20):
				print("    open %s | %s | %s | %s | %s" % [i.locale, i.screen, i.node, i.kind, i.text.left(30)])
	_result()
	quit(1 if failures else 0)


# ------------------------------------------------------------------ the states

func _all_states() -> void:
	seed(20261017)
	var title := await _open("res://scenes/title.tscn")
	await _scan("title", title)
	title.free()

	for hard in [false, true]:
		progress.hard_mode = hard
		var ls := await _open("res://scenes/level_select.tscn")
		await _scan("level select " + ("hard" if hard else "normal"), ls)
		if hard:
			ls.heat_panel.open(ls, ls.heat_button)
			await _frames(2)
			await _scan("level select HEAT panel", ls)
			ls.heat_panel.close()
		ls.free()
	progress.hard_mode = false

	var maps := await _open("res://scenes/maps.tscn")
	await _scan("map table", maps)
	maps.open_view(3)
	await _frames(2)
	await _scan("map view", maps)
	maps.free()

	for page in ["coins", "abilities"]:
		var upg := await _open("res://scenes/upgrades.tscn")
		upg.show_page(page)
		await _frames(2)
		await _scan("upgrades " + page, upg)
		upg.free()

	var skins := await _open("res://scenes/skins.tscn")
	for page: String in skins.PAGES:
		skins.show_page(page)
		await _frames(2)
		await _scan("wardrobe " + page, skins)
	skins.free()

	var settings := await _open("res://scenes/controls.tscn")
	await _scan("settings", settings)
	settings._open_codes()
	await _frames(2)
	await _scan("settings save code", settings)
	settings.free()
	settings = await _open("res://scenes/controls.tscn")
	settings._ask_reset()
	await _frames(2)
	await _scan("settings reset confirm", settings)
	settings.free()

	var keys := await _open("res://scenes/key_controls.tscn")
	await _scan("key controls", keys)
	keys.free()

	var lang_page := await _open("res://scenes/language.tscn")
	await _scan("language", lang_page)
	lang_page.free()

	var victory := await _open("res://scenes/victory.tscn")
	await _scan("victory", victory)
	victory.free()

	Story.mode = "intro"
	var story := await _open("res://scenes/story.tscn")
	for i in story.cards.size():
		story.show_card(i)
		await _frames(2)
		await _scan("story intro card %d" % i, story)
	story.free()

	await _hub()
	await _hud()
	await _results()
	await _pause_and_restart()
	await _descent()


func _hub() -> void:
	var hub := await _open("res://scenes/hub.tscn")
	await _scan("hub", hub)
	# (the hub's physics would put `near` back to where the slime stands, hiding the prompt before it is
	# measured: held meanwhile)
	hub.set_physics_process(false)
	for station: Dictionary in hub.stations:
		hub.near = station
		hub._show_prompt()
		await _frames(2)
		await _scan("hub prompt " + station.id, hub)
	hub.near = {}
	hub._show_prompt()
	hub.set_physics_process(true)
	hub.open_quit_menu()
	await _frames(2)
	await _scan("hub quit", hub)
	hub.close_quit_menu()
	hub.open_portal_menu()
	await _frames(2)
	await _scan("hub portal", hub)
	hub.close_portal_menu()
	progress.descent_resume = {seed = 5, floor = 12, cleared = 11, meter = 50.0, boons = {}, bladders = 0, pot = 30, time = 600.0,
		wind_used = false, slot = 1, bonuses = [], new_best = false, best_before = 0}
	hub.open_resume_menu()
	await _frames(2)
	await _scan("hub resume", hub)
	hub.close_resume_menu()
	progress.descent_resume = {}
	hub.open_coin_board()
	await _frames(2)
	await _scan("hub coin board", hub)
	hub.close_coin_board()
	hub.open_hat_wheel()
	await _frames(2)
	for tab in ["wheel", "shop"]:
		hub.hat_wheel.show_tab(tab)
		await _frames(2)
		await _scan("hat wheel " + tab, hub)
	hub.free()
	# The hub's one-time notice (upgrades reworked, coins returned), with a wide count.
	progress.tree_refund_notice = 888
	hub = await _open("res://scenes/hub.tscn")
	await _scan("hub notice", hub)
	hub.free()
	progress.tree_refund_notice = 0


func _hud() -> void:
	var cases: Array[Dictionary] = [
		{level = 1, tag = "L1"},
		{level = 10, tag = "L10"},
		{level = 7, hard = true, heat = 63, tag = "L7 hard HEAT 63"},
		{level = 8, assist = true, tag = "L8 assisted"},
		{random = true, tag = "randomizer"},
	]
	for c: Dictionary in cases:
		var game := await _start(c)
		if c.get("assist", false):
			game.hud.set_assist(true)
		await _frames(3)
		await _scan("hud " + c.tag, game)
		if c.tag == "L1":  # every coin found: the coins-left pod's other text
			game.hud.set_coins(165, 3, 3)
			await _frames(2)
			await _scan("hud L1 all found", game)
		game.free()
		progress.heat_mods = 0
		progress.hard_mode = false
	# Descent: the pot pod with a floor's gain and the paid-run line (wide sample values).
	seed(20261017)
	progress.start_descent(77)
	var descent := await _spawn_game({})
	await _frames(3)
	descent.hud.set_pot(888, "", 888, 8)
	await _frames(2)
	await _scan("hud descent pot", descent)
	descent.free()


func _results() -> void:
	# A story win: the game's own result text, then the medal row, the record banner and the choices.
	var game := await _start({level = 3})
	game._on_goal_body_entered(game.slime)
	game.hud.show_rewards({tier = 3, best = 3, new_best = true})
	game.hud.show_record(13.6)
	game._offer_next_steps()
	await _frames(3)
	await _scan("result win L3", game)
	game.free()
	game = await _start({level = 10})
	game._on_goal_body_entered(game.slime)
	game.hud.show_rewards({tier = 1, best = 3, new_best = false})
	game._offer_next_steps()
	await _frames(3)
	await _scan("result win L10", game)
	game.free()
	# Dried up three times on a level: the assist offer.
	game = await _start({level = 4})
	game._dry_up(true)
	game.hud.show_rewards({offer = true})
	game._offer_retry()
	await _frames(3)
	await _scan("result dry-up", game)
	game.free()
	game = await _start({random = true})
	game._on_goal_body_entered(game.slime)
	game.hud.show_rewards({tickets = 4, attempt = 2, cap = "replay"})
	game._offer_next_steps()
	await _frames(3)
	await _scan("result randomizer win", game)
	game.free()


func _pause_and_restart() -> void:
	for kind in ["story", "random", "descent"]:
		var game: Node
		if kind == "descent":
			seed(20261017)
			progress.start_descent(77)
			game = await _spawn_game({})
		else:
			game = await _start({level = 3} if kind == "story" else {random = true})
		game.pause_menu.open()
		await _frames(2)
		await _scan("pause " + kind, game)
		game.pause_menu.resume()
		if kind == "story":
			game.restart_prompt.open()
			await _frames(2)
			await _scan("restart prompt", game)
			game.restart_prompt.close()
		paused = false
		game.free()


func _descent() -> void:
	seed(20261017)
	progress.start_descent(77)
	var game := await _spawn_game({})
	game._ensure_card().show_boons(progress.descent_run, progress.descent_offers())
	await _frames(2)
	await _scan("descent boon card", game)
	game.descent_card.show_summary({floor = 2, cleared = 1, best_floor = 2, time = 61.0, tickets = 1, pot = 2, boons = {"gulp": 1}})
	await _frames(2)
	await _scan("descent summary", game)
	game.free()


func _start(c: Dictionary) -> Node:
	seed(20261017)  # the same random maze (and SEED text) in every locale and every run: a stable report
	progress.hard_mode = c.get("hard", false)
	progress.heat_mods = c.get("heat", 0)
	if c.get("random", false):
		progress.start_random()
		return await _spawn_game({})
	progress.start_story(c.level)
	return await _spawn_game({level = c.level})


# ------------------------------------------------------------------ measuring

## Measures every visible text of `node` in the current locale under the state name `state`.
func _scan(state: String, node: Node) -> void:
	states_seen[state] = true
	var items: Array[Dictionary] = []
	var buttons: Array[Dictionary] = []
	for c in _all(node):
		var control := c as Control
		if control == null or not control.is_visible_in_tree() or _alpha(control) < 0.05:
			continue
		var item := _measure(node, control)
		if item.is_empty():
			continue
		if control is Button:
			buttons.append(item)
		if item.text != "":
			items.append(item)
	for item in items:
		var base: Dictionary = english.get(state, {}).get(item.id, {})
		if _code == "en":
			if not english.has(state):
				english[state] = {}
			english[state][item.id] = {text = item.text, rect = item.rect}
		if item.text_w > item.box_w + 0.5:
			_issue(state, item, "overflow", base)
		if item.text_h > item.box_h + 0.5:
			_issue(state, item, "clip", base)
		# (A button may be UIKit.grow_h() taller than in English: the locale's standard button height.)
		if item.control is Button and not base.is_empty():
			var grew := _growth(item, base)
			if grew == "deliberate":
				deliberate[_code] = deliberate.get(_code, 0) + 1
			elif grew != "":
				_issue(state, item, "grew", base, "", "English %dx%d" % [base.rect.size.x, base.rect.size.y])
		if not SCREEN.encloses(item.ink.grow(-0.01)) or (item.control is Button and not SCREEN.encloses(item.rect)):
			_issue(state, item, "offscreen", base)
	# Overlaps: a text's ink over another text's ink or over another button (never its own parent / child).
	for i in items.size():
		var a: Dictionary = items[i]
		var others: Array[Dictionary] = []
		others.append_array(items.slice(i + 1))
		for b in buttons:
			if b.text == "":
				others.append(b)  # (buttons with text are in items already)
		for b: Dictionary in others:
			if a.control.is_ancestor_of(b.control) or b.control.is_ancestor_of(a.control):
				continue
			var b_box: Rect2 = b.ink if b.text != "" else b.rect
			if a.ink.grow(-0.5).intersects(b_box.grow(-0.5)):
				_issue(state, a, "overlap", english.get(state, {}).get(a.id, {}), b.id, b.text if b.text != "" else b.id)


## One control's text box: {control, id, text, rect (screen), ink (where the text is drawn), text_w,
## box_w, text_h, box_h}, or {} for controls that show no text and are not buttons.
func _measure(screen: Node, control: Control) -> Dictionary:
	var is_label := control is Label
	var is_button := control is Button
	if not is_label and not is_button:
		return {}
	var text: String = control.text.strip_edges()
	var rect := _rect(control)
	var item := {control = control, id = _id(screen, control), text = text, rect = rect, ink = rect,
		text_w = 0.0, box_w = rect.size.x, text_h = 0.0, box_h = rect.size.y}
	if text == "":
		return item if is_button else {}
	var font: Font = control.get_theme_font("font")
	var size: int = control.get_theme_font_size("font_size")
	var scale := control.get_global_transform_with_canvas().get_scale()
	var line_h := font.get_height(size)
	var lines: PackedStringArray = text.split("\n")
	var widest := 0.0
	var wraps: bool = is_label and (control as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	if wraps:
		# A wrapping label: only an unbreakable word can be too wide; its height is its line count.
		for word in text.replace("\n", " ").split(" ", false):
			widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		var count: int = (control as Label).get_line_count()
		var shown: int = (control as Label).max_lines_visible
		lines.resize(count if shown < 0 else mini(count, shown))
	else:
		for line in lines:
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var spacing: float = control.get_theme_constant("line_spacing") if is_label else 0.0
	var text_h := lines.size() * line_h + (lines.size() - 1) * spacing
	var box := Rect2(Vector2.ZERO, rect.size / scale)
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var valign := VERTICAL_ALIGNMENT_TOP
	var text_box_w := widest
	if is_label:
		var label := control as Label
		align = label.horizontal_alignment
		valign = label.vertical_alignment
		var style := label.get_theme_stylebox("normal")
		if style:
			box = Rect2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP), box.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT),
				box.size.y - style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM))
	else:
		var button := control as Button
		align = button.alignment
		valign = VERTICAL_ALIGNMENT_CENTER
		var style := button.get_theme_stylebox("normal")
		if style:
			box = Rect2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP), box.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT),
				box.size.y - style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM))
		if button.icon:
			var icon_w := float(button.icon.get_width()) + float(button.get_theme_constant("h_separation"))
			var icon_right := button.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT
			if control.is_layout_rtl() and button.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
				icon_right = not icon_right  # (Godot swaps the icon's side in a right-to-left layout)
			box.position.x += icon_w if not icon_right else 0.0
			box.size.x -= icon_w
	if wraps:
		text_box_w = maxf(widest, box.size.x)  # wrapped lines fill the box (or the long word sticks out)
	if control.is_layout_rtl():
		# (Godot draws LEFT-aligned text on the right in a right-to-left layout, and RIGHT on the left)
		if align == HORIZONTAL_ALIGNMENT_LEFT:
			align = HORIZONTAL_ALIGNMENT_RIGHT
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			align = HORIZONTAL_ALIGNMENT_LEFT
	var x := box.position.x
	match align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = box.position.x + (box.size.x - text_box_w) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = box.end.x - text_box_w
	var y := box.position.y
	match valign:
		VERTICAL_ALIGNMENT_CENTER:
			y = box.position.y + (box.size.y - text_h) / 2.0
		VERTICAL_ALIGNMENT_BOTTOM:
			y = box.end.y - text_h
	item.ink = Rect2(rect.position + Vector2(x, y) * scale, Vector2(text_box_w, text_h) * scale)
	item.text_w = widest
	item.box_w = box.size.x
	item.text_h = text_h
	item.box_h = box.size.y
	return item


## How a button compares with its English twin: "" (not bigger), "deliberate" (sized for its text by
## the UIKit helpers: its width exactly what UIKit.noted_text_w recomputes from the texts it was sized for
## (button_w / back_size / tab_widths / an equal-width group), its height the locale's button_h, a
## multi-line text's extra line pitches or a 16 px button's big_button_h), or "grew" (anything else).
## Accepted by measurement only, never by node name: a width the helpers would not give stays open.
func _growth(item: Dictionary, base: Dictionary) -> String:
	var control: Button = item.control
	var scale := control.get_global_transform_with_canvas().get_scale()
	var w: float = item.rect.size.x / scale.x
	var h: float = item.rect.size.y / scale.y
	var base_w: float = base.rect.size.x / scale.x
	var base_h: float = base.rect.size.y / scale.y
	var allowed_h := base_h + UIKit.grow_h()
	var lines := control.text.count("\n") + 1
	if control.autowrap_mode != TextServer.AUTOWRAP_OFF:
		lines = maxi(lines, UIKit.wrapped_lines(control.text, item.box_w, control.get_theme_font_size("font_size"), control.get_theme_font("font")))
	allowed_h += (lines - 1) * UIKit.line_pitch()
	if control.get_theme_font_size("font_size") == UIKit.FONT_BIG:
		allowed_h = maxf(allowed_h, UIKit.big_button_h(int(base_h)))
	var wider := w > base_w + 0.5
	var taller := h > allowed_h + 0.5
	if not wider and not taller:
		return ""
	if taller:
		return "grew"
	var noted := UIKit.noted_text_w(control)
	return "deliberate" if noted > 0 and absf(w - noted) < 0.5 else "grew"


func _issue(state: String, item: Dictionary, kind: String, base: Dictionary, other_id := "", other := "") -> void:
	var key := "%s|%s|%s|%s" % [state, item.id, kind, other_id]
	var issue := {test = "screens", screen = state, node = item.id, key = keys_by_text.get(base.get("text", item.text), ""),
		locale = _code, kind = kind, text = item.text, en_text = base.get("text", ""), text_w = item.text_w, box_w = item.box_w,
		text_h = item.text_h, box_h = item.box_h, other = other, acceptable = false, reason = ""}
	if _code == "en":
		english_issues[key] = true
		issue.acceptable = true
		issue.reason = "English source layout"
	elif english_issues.has(key):
		issue.acceptable = true
		issue.reason = "same in English"
	else:
		for known: Array in KNOWN:
			if state.begins_with(known[0]) and item.id.contains(known[1]) and kind == known[2]:
				issue.acceptable = true
				issue.reason = known[3]
				break
	issues.append(issue)


## A stable id for `control` under `screen`: its path of names, generated names (@Label@123) replaced
## by Class + index among its siblings, so the same node has the same id in every locale.
func _id(screen: Node, control: Node) -> String:
	var parts := PackedStringArray()
	var node := control
	while node != null and node != screen:
		var name := String(node.name)
		parts.append(("%s%d" % [node.get_class(), node.get_index()]) if name.begins_with("@") else name)
		node = node.get_parent()
	parts.reverse()
	return "/".join(parts)


func _alpha(control: CanvasItem) -> float:
	var a := 1.0
	var node: Node = control
	while node is CanvasItem:
		a *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return a * control.self_modulate.a


func _rect(control: Control) -> Rect2:
	var xf := control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all(child))
	return out


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
