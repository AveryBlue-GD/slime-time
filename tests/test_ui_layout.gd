extends "res://tests/suite_base.gd"

## UI layout rules (docs/ui-rules.md) on every screen the Phase 3 polish changed: every control
## inside the 320x180 screen, no two interactive controls overlapping, standard component sizes
## (13 px buttons, BACK 40x13 at (4, 164), 14 px pods), centered text on its screen's or panel's
## center line, and the specific fixes of docs/spring-cleaning/phase3-ui.md (HUD timer pod, pods vs
## the area name and story line on every level, level grid, quit / portal / pause / restart panel
## padding, the 10-digit SEED, the Descent summary, the hat wheel header, upgrade rows, map table
## bar, save code boxes). Geometric (headless has no renderer): rects come from the laid-out
## controls, text widths from the font. The rendered pixels were measured with the capture driver
## described in phase3-ui.md.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_ui_layout.gd

const SCREEN := Rect2(0, 0, 320, 180)
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = throwaway_save()
	progress.enable_story_complete()
	progress.tickets = 60
	await _menus()
	await _hub()
	await _hud()
	await _pause_and_restart()
	await _descent()
	_result()
	quit(1 if failures else 0)


# ------------------------------------------------------------------ menu screens

func _menus() -> void:
	var title := await _open("res://scenes/title.tscn")
	_check_screen(title, "title")
	_check_rect(title.story_button, Rect2(4, 164, 40, 13), "title: STORY on the bottom row")
	title.free()

	for hard in [false, true]:
		progress.hard_mode = hard
		var ls := await _open("res://scenes/level_select.tscn")
		var tag := "level select (%s)" % ("hard" if hard else "normal")
		_check_screen(ls, tag)
		var grid := _rect(ls.grid)
		_check(absf(grid.get_center().x - 160.0) <= 0.5, tag + ": grid centered (%s)" % grid)
		_check(ls.INFO_RECT.position.y - grid.end.y >= UIKit.GAP_M, tag + ": 4+ px between the grid and the info panel")
		if hard:
			_check_rect(ls.heat_button, Rect2(320 - 4 - 52, 164, 52, 13), tag + ": HEAT mirrors BACK")
			ls.heat_panel.open(ls, ls.heat_button)
			await _frames(2)
			_check_screen(ls.heat_panel, "HEAT panel")
			var panel: Rect2 = ls.heat_panel.RECT
			var flame: Rect2 = _rect(ls.heat_panel.title_flame)
			var text_w := _text_w(ls.heat_panel.title)
			var group := Rect2(flame.position.x, flame.position.y, ls.heat_panel.title.position.x + 1.0 + text_w - 1.0 - flame.position.x, 9)
			_check(absf(group.get_center().x - panel.get_center().x) <= 0.5, "HEAT panel: flame + title centered as a group (%s)" % group)
			_check(ls.heat_panel.title.position.y - panel.position.y == UIKit.PANEL_PAD, "HEAT panel: title PANEL_PAD under the top")
			_check(panel.end.y - _rect(ls.heat_panel.done_button).end.y == UIKit.PANEL_PAD, "HEAT panel: DONE PANEL_PAD over the bottom")
			ls.heat_panel.close()
		ls.free()
	progress.hard_mode = false

	var maps := await _open("res://scenes/maps.tscn")
	_check_screen(maps, "map table")
	var hint := _rect(maps.hint_label)
	_check(hint.get_center().x == 160.0 and hint.end.y <= 180.0, "map table: hint centered on the screen, on screen (%s)" % hint)
	var box := _rect(maps.hard_box)
	_check(box.end.x == 320.0 - UIKit.EDGE and box.end.y <= 180.0, "map table: HARD box ends EDGE from the right edge (%s)" % box)
	maps.open_view(3)
	await _frames(2)
	_check_screen(maps.view_root, "map view")
	maps.free()

	for page in ["coins", "abilities"]:
		var upg := await _open("res://scenes/upgrades.tscn")
		upg.show_page(page)
		await _frames(2)
		_check_screen(upg, "upgrades " + page)
		var pod: Control = upg.coin_label.get_parent().get_parent()
		var pr := _rect(pod)
		_check(pr.end.x == 320.0 - UIKit.EDGE and pr.position.y == UIKit.EDGE and pr.size.y == UIKit.POD_H, "upgrades: balance pod top right, 14 tall (%s)" % pr)
		_check(upg.coin_label.size.x == _text_w(upg.coin_label), "upgrades: balance label sized to its text (pads 4 / 4)")
		if page == "coins":
			for id: String in upg.rows:
				var row: Dictionary = upg.rows[id]
				_check(_rect(row.plus).position.x - _rect(row.minus).end.x == UIKit.GAP_M, "upgrades %s: - and + 4 px apart" % id)
		_check(upg.coins_tab.get_meta("selected", false) == (page == "coins"), "upgrades: the selected tab has the selected style")
		upg.free()

	var skins := await _open("res://scenes/skins.tscn")
	_check_screen(skins, "skins")
	skins.free()

	var settings := await _open("res://scenes/controls.tscn")
	_check_screen(settings, "settings")
	_check_rect(settings.reset_button, Rect2(320 - 4 - 92, 164, 92, 13), "settings: RESET PROGRESS on the bottom row, right")
	settings._open_codes()
	await _frames(2)
	_check_screen(settings.code_panel, "settings SAVE CODE panel")
	_check(settings.code_out.size.y == 13 and settings.code_in.size.y == 13, "save code boxes are 13 px tall (%s, %s)" % [settings.code_out.size, settings.code_in.size])
	settings.free()

	var keys := await _open("res://scenes/key_controls.tscn")
	_check_screen(keys, "controls")
	_check(_rect(keys.reset_keys_button).position.y == 164 and absf(_rect(keys.reset_keys_button).get_center().x - 160.0) <= 0.5, "controls: RESET KEYS centered on the bottom row")
	keys.free()


# ------------------------------------------------------------------ hub

func _hub() -> void:
	var hub := await _open("res://scenes/hub.tscn")
	_check(_rect(hub.ticket_pod).size.y == UIKit.POD_H, "hub: ticket pod is 14 tall")
	hub.open_quit_menu()
	await _frames(2)
	_check_screen(hub.quit_menu, "hub quit")
	_check_dialog(hub.quit_menu, hub.QUIT_PANEL, "hub quit")
	hub.close_quit_menu()
	hub.open_portal_menu()
	await _frames(2)
	_check_screen(hub.portal_menu, "hub portal")
	_check_dialog(hub.portal_menu, hub.PORTAL_PANEL, "hub portal")
	hub.close_portal_menu()
	# A saved Descent run's prompt (phase 5, D6).
	progress.descent_resume = {seed = 5, floor = 12, cleared = 11, meter = 50.0, boons = {}, bladders = 0, pot = 30, time = 600.0,
		wind_used = false, slot = 1, bonuses = [], new_best = false, best_before = 0}
	hub.open_resume_menu()
	await _frames(2)
	_check_screen(hub.resume_menu, "hub resume prompt")
	_check_dialog(hub.resume_menu, hub.RESUME_PANEL, "hub resume prompt")
	hub.close_resume_menu()
	progress.descent_resume = {}
	hub.open_coin_board()
	await _frames(2)
	_check_screen(hub.coin_board, "hub coin board")
	hub.close_coin_board()
	hub.open_hat_wheel()
	await _frames(2)
	for tab in ["wheel", "shop"]:
		hub.hat_wheel.show_tab(tab)
		await _frames(2)
		var wheel: Control = hub.hat_wheel
		_check_screen(wheel, "hat wheel " + tab)
		_check(_rect(wheel.wheel_tab).position.y + 3.0 == _rect(wheel.title).position.y and _rect(wheel.balance).position.y == _rect(wheel.title).position.y,
			"hat wheel: tabs, title and balance on one baseline")
		var panel: Rect2 = wheel.PANEL
		_check(_rect(wheel.wheel_tab).position.x - panel.position.x == panel.end.x - _rect(wheel._balance_icon).end.x,
			"hat wheel: the tab and the balance icon mirror their insets")
		_check(wheel.wheel_tab.get_meta("selected", false) == (tab == "wheel") and wheel.shop_tab.get_meta("selected", false) == (tab == "shop"), "hat wheel: selected tab style")
		wheel.show_close(true)  # touch: the header's BACK, the SHOP tab's mirror (phase 5, H4)
		await _frames(1)
		_check_screen(wheel, "hat wheel %s + touch BACK" % tab)
		_check(_rect(wheel.close_button).position.y == _rect(wheel.shop_tab).position.y
			and _rect(wheel.close_button).position.x - 160.0 == 160.0 - _rect(wheel.shop_tab).end.x
			and _rect(wheel.close_button).end.x + 4.0 <= _rect(wheel.balance).end.x - 5 * 6.0,
			"hat wheel: touch BACK mirrors the SHOP tab, 4 px clear of a 5-digit balance (%s)" % _rect(wheel.close_button))
		wheel.show_close(false)
	var tiles: Array = hub.hat_wheel.shop_tiles.values()
	if not tiles.is_empty():
		var left := INF
		var right := -INF
		for t: Control in tiles:
			left = minf(left, _rect(t).position.x)
			right = maxf(right, _rect(t).end.x)
		var panel: Rect2 = hub.hat_wheel.PANEL
		_check(left - panel.position.x == panel.end.x - right, "hat shop: grid centered in its panel (%s..%s)" % [left, right])
	hub.free()


## A hub dialog: centered on the screen, its labels' rects on the panel's span, content PANEL_PAD
## inside the top and bottom, 13 px buttons.
func _check_dialog(menu: Control, panel: Rect2, tag: String) -> void:
	_check(absf(panel.get_center().x - 160.0) <= 0.5 and absf(panel.get_center().y - 90.0) <= 1.0, tag + ": panel centered (%s)" % panel)
	var top := INF
	var bottom := -INF
	for c in _all(menu):
		if not c.is_visible_in_tree():
			continue
		if c is Label and c.text != "":
			var r := _rect(c)
			_check(r.position.x == panel.position.x and r.size.x == panel.size.x, tag + ": '%s' spans the panel (%s)" % [c.text, r])
			top = minf(top, r.position.y)
		elif c is Button:
			var r := _rect(c)
			top = minf(top, r.position.y)
			bottom = maxf(bottom, r.end.y)
	_check(top - panel.position.y == UIKit.PANEL_PAD and panel.end.y - bottom == UIKit.PANEL_PAD, tag + ": content PANEL_PAD inside (%s / %s)" % [top - panel.position.y, panel.end.y - bottom])


# ------------------------------------------------------------------ in-level HUD

func _hud() -> void:
	var cases: Array[Dictionary] = []
	for level in range(1, 11):
		cases.append({level = level, tag = "L%d" % level})
	cases.append({level = 7, hard = true, heat = 63, tag = "L7 hard, six HEAT modifiers"})
	cases.append({level = 5, hard = true, heat = 1, tag = "L5 hard, HEAT 1"})
	cases.append({level = 8, assist = true, tag = "L8 assisted"})
	cases.append({level = 8, dev = true, tag = "L8 dev badge"})
	cases.append({random = true, tag = "randomizer"})
	for c: Dictionary in cases:
		progress.hard_mode = c.get("hard", false)
		progress.heat_mods = c.get("heat", 0)
		if c.get("random", false):
			progress.start_random()
		else:
			progress.start_story(c.level)
		var game := await _spawn_game({level = c.get("level", 1)} if not c.get("random", false) else {})
		if c.get("assist", false):
			game.hud.set_assist(true)
		if c.get("dev", false):
			game.hud.set_dev_badge("BRIGHT NO DRAIN")
		await _frames(3)
		var hud: CanvasLayer = game.hud
		var pods := _visible_pods(hud)
		var rows := {}
		for p: Control in pods:
			var r := _rect(p)
			_check(SCREEN.encloses(r), c.tag + ": pod on screen (%s)" % r)
			var two_lines: bool = p == hud.attempt_pod
			_check(r.size.y == (UIKit.POD_H2 if two_lines else UIKit.POD_H), c.tag + ": pod %s is %d tall" % [r, r.size.y])
			if r.position.x < 160.0 and r.end.x > 160.0:
				continue  # the timer
			rows[r.position.y] = rows.get(r.position.y, 0) + 1
			for q: Control in pods:
				if q != p:
					_check(not r.intersects(_rect(q)), c.tag + ": pods don't overlap")
		for y: float in rows:
			_check([3.0, 19.0, 35.0, 51.0].has(y), c.tag + ": pods on the 16 px row grid (y %s)" % y)
		# The timer pod: on the screen's center, ink pads 4 / 4.
		var timer: Control = hud.time_label.get_parent().get_parent()
		var tr := _rect(timer)
		_check(int(tr.size.x) % 2 == 0 and tr.get_center().x == 160.0, c.tag + ": timer pod exactly centered (%s)" % tr)
		var icon := _rect(hud._clock_icon)
		var text_end := _rect(hud.time_label).position.x + _text_w(hud.time_label)
		_check(icon.position.x - tr.position.x == 4.0 and tr.end.x - text_end == 4.0, c.tag + ": timer ink pads 4 / 4 (%s / %s)" % [icon.position.x - tr.position.x, tr.end.x - text_end])
		# The area name and the story line (drips included) 2 px clear of every pod.
		for label: Label in [hud.area_label, hud.story_label]:
			if not label.visible or label.text == "":
				continue
			var w := _text_w(label)
			var ink := Rect2(roundf((320.0 - w) / 2.0), _rect(label).position.y, w, UIKit.TEXT_BODY + UIKit.TEXT_DRIP)
			for p: Control in pods:
				_check(not ink.grow(2.0).intersects(_rect(p)), c.tag + ": '%s' clear of pod %s" % [label.text.left(16), _rect(p)])
			_check(SCREEN.encloses(ink), c.tag + ": '%s' on screen" % label.text.left(16))
		game.free()
		progress.heat_mods = 0
	progress.hard_mode = false


func _visible_pods(hud: CanvasLayer) -> Array[Control]:
	var out: Array[Control] = []
	for bar: Control in [hud._left_bar, hud._right_bar]:
		for pod: Control in bar.get_children():
			if pod.visible:
				out.append(pod)
	out.append(hud.time_label.get_parent().get_parent())
	return out


# ------------------------------------------------------------------ pause menu, restart prompt

func _pause_and_restart() -> void:
	for kind in ["story", "random", "descent"]:
		if kind == "random":
			progress.start_random()
		elif kind == "descent":
			progress.start_descent(77)
		else:
			progress.start_story(3)
		var game := await _spawn_game({level = 3} if kind == "story" else {})
		if kind == "random":
			game.random_seed = 4294967295
			game.seed_level = 7
		var hud: CanvasLayer = game.hud
		var had_story: bool = hud.story_label.visible
		_check(hud.area_label.visible, "%s: the area name shows at the level start" % kind)
		game.pause_menu.open()
		await _frames(2)
		var menu: CanvasLayer = game.pause_menu
		_check_screen(menu.get_child(0), "pause (%s)" % kind)
		_check_stack_panel(menu._panel, menu.buttons[0].get_parent(), "pause (%s)" % kind)
		if kind == "random":
			var seed_b: Button = menu.seed_button
			_check(seed_b.size.x == 100.0 and _text_w(seed_b) <= 92.0, "pause: a 10-digit SEED fits its 100 px button (%s: %s px)" % [seed_b.text, _text_w(seed_b)])
		_check(not game.hud.area_label.visible and not game.hud.story_label.visible, "pause (%s): the area texts are hidden under it" % kind)
		menu.resume()
		_check_area_back(hud, had_story, "pause (%s) RESUME" % kind)
		if kind == "story":
			_check(had_story, "story: the story line shows at the level start")
			game.restart_prompt.open()
			await _frames(2)
			_check_screen(game.restart_prompt.get_child(0), "restart prompt")
			_check_stack_panel(_first(game.restart_prompt, "Panel"), game.restart_prompt.buttons[0].get_parent(), "restart prompt")
			_check(not hud.area_label.visible and not hud.story_label.visible, "restart prompt: the area texts are hidden under it")
			game.restart_prompt.close()
			_check_area_back(hud, had_story, "restart prompt CANCEL")
			# Once the fade has ended, closing a menu brings nothing back.
			hud._area_tween.custom_step(10.0)
			game.pause_menu.open()
			game.pause_menu.resume()
			_check(not hud.area_label.visible and not hud.story_label.visible, "pause after the fade: the area texts stay gone")
		paused = false
		game.free()


## A menu opened over the level start and closed again: the area name (and the story line, if it
## was up) show again at full alpha, and fade later (at least AREA_RESHOW_TIME from now).
func _check_area_back(hud: CanvasLayer, story: bool, tag: String) -> void:
	_check(hud.area_label.visible and hud.area_label.modulate.a == 1.0 and hud.story_label.visible == story,
		tag + ": the area texts are back (area %s, story %s)" % [hud.area_label.visible, hud.story_label.visible])
	_check(hud._area_tween != null and hud._area_tween.is_valid(), tag + ": their fade is still to come")


## A panel holding a VBox stack: PANEL_PAD above the first and below the last visible child.
func _check_stack_panel(panel: Control, stack: Control, tag: String) -> void:
	var top := INF
	var bottom := -INF
	for c: Control in stack.get_children():
		if c.visible:
			top = minf(top, _rect(c).position.y)
			bottom = maxf(bottom, _rect(c).end.y)
	var p := _rect(panel)
	_check(top - p.position.y == UIKit.PANEL_PAD and p.end.y - bottom == UIKit.PANEL_PAD, tag + ": stack PANEL_PAD inside its panel (%s / %s)" % [top - p.position.y, p.end.y - bottom])


# ------------------------------------------------------------------ Descent card and summary

func _descent() -> void:
	progress.start_descent(77)
	var game := await _spawn_game({})
	game._ensure_card().show_boons(progress.descent_run, progress.descent_offers())
	await _frames(2)
	var card: DescentCard = game.descent_card
	_check(not game.hud.visible, "Descent card: the HUD is hidden under it")
	_check_screen(card.boons_root, "Descent boon card")
	for b: Button in [card.cash_button, card.descend_button]:
		_check(_rect(b).size.y == 13 and _rect(b).position.y == UIKit.CHOICE_Y, "Descent card: %s 13 tall on the choice row" % b.text)
	card.show_summary({floor = 2, cleared = 1, best_floor = 2, time = 61.0, tickets = 1, pot = 2, boons = {"gulp": 1}})
	await _frames(2)
	_check_screen(card.summary_root, "Descent summary")
	var panel := _rect(card.summary_panel)
	var lines := _rect(card.summary_lines)
	_check(lines.position.y - panel.position.y == UIKit.PANEL_PAD and panel.end.y - lines.end.y == UIKit.PANEL_PAD, "Descent summary: panel hugs its lines (%s, %s)" % [panel, lines])
	var nr := _rect(card.new_run_button)
	var hb := _rect(card.hub_button)
	_check(nr.size == UIKit.CHOICE_SIZE and hb.size == UIKit.CHOICE_SIZE and hb.position.x - nr.end.x == UIKit.CHOICE_GAP and absf((nr.position.x + hb.end.x) / 2.0 - 160.0) <= 0.5,
		"Descent summary: the standard choice row (%s, %s)" % [nr, hb])
	game.free()


# ------------------------------------------------------------------ shared checks

## Every visible control of `screen` on the screen; interactive ones never overlapping; text
## buttons 13 tall; a bottom-row BACK at (4, 164) 40x13; centered labels on their screen's or
## panel's center line.
func _check_screen(screen: Node, tag: String) -> void:
	var interactive: Array[Control] = []
	for c in _all(screen):
		var control := c as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var r := _rect(control)
		if r.size.x <= 0.0 or r.size.y <= 0.0 or control is ColorRect or control.get_class() == "Control":
			continue
		_check(SCREEN.encloses(r), tag + ": %s '%s' on screen (%s)" % [control.get_class(), _name(control), r])
		if control is BaseButton or control is HSlider or control is LineEdit:
			interactive.append(control)
		if control is Button and not (control is CheckBox) and control.text != "" and control.get_theme_font_size("font_size") == 8:
			_check(r.size.y == UIKit.BUTTON_H, tag + ": button '%s' is 13 tall (%s)" % [control.text, r])
			if control.text == "BACK" and r.position.y >= 150.0:
				_check(r == Rect2(4, 164, 40, 13), tag + ": BACK at (4, 164) 40x13 (%s)" % r)
		if control is Label and control.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and control.text != "" and not control.get_parent() is Container:
			_check(_on_center_line(control), tag + ": '%s' on its screen's or panel's center line (%s)" % [control.text.left(20), r])
	for i in interactive.size():
		for j in range(i + 1, interactive.size()):
			if interactive[i].is_ancestor_of(interactive[j]) or interactive[j].is_ancestor_of(interactive[i]):
				continue
			_check(not _rect(interactive[i]).intersects(_rect(interactive[j])), tag + ": '%s' and '%s' don't overlap" % [_name(interactive[i]), _name(interactive[j])])


func _on_center_line(label: Label) -> bool:
	var cx := _rect(label).get_center().x
	if absf(cx - 160.0) <= 1.0:
		return true
	var node: Node = label.get_parent()
	while node:
		for sibling in node.get_children():
			if (sibling is Panel or sibling is PanelContainer or sibling is Button) and sibling.is_visible_in_tree() \
					and _rect(sibling).encloses(_rect(label).grow_individual(0, 0, 0, -1)) and absf(_rect(sibling).get_center().x - cx) <= 1.0:
				return true
		if node is Button or node is PanelContainer:
			return absf(_rect(node).get_center().x - cx) <= 1.0
		node = node.get_parent()
	return false


func _check_rect(control: Control, want: Rect2, label: String) -> void:
	_check(_rect(control) == want, label + " (%s)" % _rect(control))


func _name(control: Control) -> String:
	return control.text if "text" in control and control.get("text") is String and control.text != "" else String(control.name)


func _rect(control: Control) -> Rect2:
	return TouchButton.rect_of(control)


func _text_w(control: Control) -> float:
	return control.get_theme_font("font").get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all(child))
	return out


func _first(node: Node, cls: String) -> Control:
	for c in _all(node):
		if c.get_class() == cls:
			return c
	return null


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
