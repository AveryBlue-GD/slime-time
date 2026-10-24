extends "res://tests/suite_base.gd"

## Touch hit areas (TouchButton, docs/ui-rules.md section 7). With a touchscreen (forced with
## Progress.force_touch, like --touch) a menu button's hit area is its drawn rect grown by
## UIKit.HIT_PAD, shared with its neighbors by distance, so:
## - a lone 13 px button (BACK, the result row, the upgrades - / +) can be hit over UIKit.TOUCH_MIN
##   (22 px, about 44 pt on a phone) in both directions, without changing its art;
## - no point of the screen is claimed by two targets (buttons, sliders, text boxes, checkboxes),
##   on every screen checked, and no button claims a point inside another target's own rect;
## - a real click (through the GUI input pipeline) in the grown margin presses the nearest button;
## - without touch the hit area is exactly the drawn rect, and "touch" means the last pointer event was
##   a touch (UIKit.note_pointer): a mouse on a touchscreen laptop gets exact hit areas.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_ui_touch.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = throwaway_save()
	progress.enable_story_complete()
	progress.tickets = 60

	progress.force_touch = false
	var upg: Node = await _open("res://scenes/upgrades.tscn")
	var plus: Button = upg.rows["slime"].plus
	var above := TouchButton.rect_of(plus).get_center() - Vector2(0, 9)
	_check(not _hits(plus, above), "no touch: the hit area is exactly the drawn button")
	# Touch in use = the last pointer event was a touch (a desktop with touchscreen hardware but a
	# mouse in hand keeps exact hit areas). Every window input goes through UIKit.note_pointer.
	_check(root.window_input.is_connected(UIKit.note_pointer), "the RotateHint autoload feeds window input to UIKit.note_pointer")
	var mouse := InputEventMouseMotion.new()
	mouse.position = above
	root.window_input.emit(mouse)
	_check(not UIKit.touch_active() and not _hits(plus, above), "a real mouse: exact hit areas")
	var touch := InputEventScreenTouch.new()
	touch.position = above
	touch.pressed = true
	root.window_input.emit(touch)
	_check(UIKit.touch_active() and _hits(plus, above), "a screen touch: grown hit areas")
	var tap := InputEventMouseButton.new()  # the mouse click Godot makes from that touch
	tap.device = InputEvent.DEVICE_ID_EMULATION
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = above
	root.window_input.emit(tap)
	_check(UIKit.touch_active(), "the mouse event emulated from a touch keeps touch in use")
	root.window_input.emit(mouse)
	_check(not UIKit.touch_active() and not _hits(plus, above), "the mouse again: exact hit areas again")
	var drag := InputEventScreenDrag.new()
	root.window_input.emit(drag)
	_check(UIKit.touch_active(), "a screen drag: touch in use")
	UIKit.touch_in_use = false
	upg.free()

	progress.force_touch = true
	_check(UIKit.touch_active(), "--touch makes the menus use touch hit areas")

	# The upgrades rows: - and + (16x13, 4 px apart) each get 22+ px both ways, never overlapping.
	upg = await _open("res://scenes/upgrades.tscn")
	for id: String in upg.rows:
		for key in ["minus", "plus"]:
			var b: Button = upg.rows[id][key]
			var span := _span(b)
			_check(span.x >= UIKit.TOUCH_MIN and span.y >= UIKit.TOUCH_MIN, "upgrades %s %s: hit area %s (drawn %s)" % [id, key, span, b.size])
	var back: Button = upg.back
	_check(_span(back).y >= UIKit.TOUCH_MIN, "upgrades BACK: hit area %s tall" % _span(back).y)
	_check_exclusive(upg, "upgrades COINS")
	# A real click 1 px right of the - button (in the gap, nearer to -) presses -, 3 px right (nearer +) presses +.
	upg._change("speed", true)  # (so - is enabled: one level to take back out)
	await _frames(1)
	plus = upg.rows["speed"].plus
	var minus: Button = upg.rows["speed"].minus
	var pressed := []
	minus.pressed.connect(func() -> void: pressed.append("minus"))
	plus.pressed.connect(func() -> void: pressed.append("plus"))
	var gap_y := TouchButton.rect_of(minus).get_center().y
	await _click(Vector2(TouchButton.rect_of(minus).end.x + 0.5, gap_y))
	await _click(Vector2(TouchButton.rect_of(plus).position.x - 0.5, gap_y))
	await _click(Vector2(TouchButton.rect_of(plus).get_center().x, TouchButton.rect_of(plus).position.y - 4.5))
	_check(pressed == ["minus", "plus", "plus"], "clicks in the grown margins press the nearest button (%s)" % [pressed])
	upg.show_page("abilities")
	await _frames(2)
	_check_exclusive(upg, "upgrades TICKETS")
	upg._buy_ability("splat")
	await _frames(2)
	if upg.confirm.visible:
		_check(_span(upg.confirm_buy).y >= UIKit.TOUCH_MIN and _span(upg.confirm_back).y >= UIKit.TOUCH_MIN, "the BUY? confirm's buttons get 22+ px")
		_check_exclusive(upg, "upgrades BUY confirm")
	upg.free()

	for path in ["res://scenes/level_select.tscn", "res://scenes/controls.tscn", "res://scenes/key_controls.tscn", "res://scenes/skins.tscn", "res://scenes/maps.tscn", "res://scenes/title.tscn"]:
		var screen: Node = await _open(path)
		_check_exclusive(screen, path.get_file())
		if path.ends_with("/controls.tscn") and not path.contains("key_"):
			_check_pitch([screen.sound_button, screen.motion_button, screen.fog_button], "settings left column")
			_check_pitch([screen.controls_button, screen.save_code_button, screen.relaxed_button], "settings right column")
		if path.ends_with("title.tscn"):
			for b: Button in [screen.story_button, screen.quit_button]:
				_check(_span(b).x >= UIKit.TOUCH_MIN and _span(b).y >= UIKit.TOUCH_MIN, "title %s: hit area %s" % [b.text, _span(b)])
		screen.free()

	var hub: Node = await _open("res://scenes/hub.tscn")
	hub.open_quit_menu()
	await _frames(2)
	for b: Button in [hub.quit_button, hub.back_button]:
		_check(_span(b).x >= UIKit.TOUCH_MIN and _span(b).y >= UIKit.TOUCH_MIN, "hub quit %s: hit area %s" % [b.text, _span(b)])
	_check_exclusive(hub, "hub quit")
	hub.close_quit_menu()
	hub.open_portal_menu()
	await _frames(2)
	_check(hub.portal_back.position.y - hub.maze_button.position.y >= UIKit.TOUCH_MIN, "portal: BACK is a touch pitch under the maze button")
	_check_exclusive(hub, "hub portal")
	hub.close_portal_menu()
	hub.open_hub_menu()
	await _frames(2)
	for b: Button in [hub.menu_back, hub.menu_achievements, hub.menu_settings, hub.menu_quit]:
		_check(_span(b).x >= UIKit.TOUCH_MIN and _span(b).y >= 16.0, "hub menu %s: hit area %s (a stack: its pitch tall)" % [b.text, _span(b)])
	_check_exclusive(hub, "hub menu")
	_check_pitch([hub.menu_back, hub.menu_achievements, hub.menu_settings, hub.menu_quit], "hub menu")
	hub.free()

	# In a level: the pause stack (pitch 16: each button gets its share of the 3 px gaps) and the
	# result row (lone buttons: 22+ px).
	progress.start_story(3)
	var game := await _spawn_game({level = 3})
	game.pause_menu.open()
	await _frames(2)
	_check_exclusive(game.pause_menu, "pause menu")
	_check_pitch(game.pause_menu.buttons, "pause menu")
	for b: Button in game.pause_menu.buttons:
		if b.is_visible_in_tree():
			_check(_span(b).y >= 16.0, "pause %s: hit area %s tall (its pitch)" % [b.text, _span(b).y])
	game.pause_menu.resume()
	paused = false
	game.hud.show_choices([["RESTART", func() -> void: pass], ["UPGRADES", func() -> void: pass]], 0)
	await _frames(2)
	for b: Button in game.hud.choice_buttons:
		_check(_span(b).x >= UIKit.TOUCH_MIN and _span(b).y >= UIKit.TOUCH_MIN, "result row %s: hit area %s" % [b.text, _span(b)])
	_check_exclusive(game.hud, "result row")
	game.free()
	progress.force_touch = false
	_result()
	quit(1 if failures else 0)


## The hit area of `b` along the lines through its center (whole pixels, pixel centers).
func _span(b: Control) -> Vector2:
	var r := TouchButton.rect_of(b)
	var c := (r.get_center() - Vector2(0.5, 0.5)).floor() + Vector2(0.5, 0.5)
	var w := 0
	for x in range(int(r.position.x) - 12, int(r.end.x) + 12):
		w += int(_hits(b, Vector2(x + 0.5, c.y)))
	var h := 0
	for y in range(int(r.position.y) - 12, int(r.end.y) + 12):
		h += int(_hits(b, Vector2(c.x, y + 0.5)))
	return Vector2(w, h)


## Every pixel of the screen is claimed by at most one visible, unlocked touch target under `screen`;
## no button claims a pixel inside another target's own rect.
func _check_exclusive(screen: Node, tag: String) -> void:
	var targets: Array[Control] = []
	for node in get_nodes_in_group(UIKit.TOUCH_GROUP):
		var c := node as Control
		if c and c.is_visible_in_tree() and (screen == c or screen.is_ancestor_of(c)) and not (c is BaseButton and c.focus_mode == Control.FOCUS_NONE):
			targets.append(c)
	var shared := 0
	var stolen := 0
	for y in 180:
		for x in 320:
			var p := Vector2(x + 0.5, y + 0.5)
			var claimers: Array[Control] = []
			for t in targets:
				if _hits(t, p):
					claimers.append(t)
			if claimers.size() > 1:
				shared += 1
				for t in claimers:
					for u in claimers:
						if t != u and TouchButton.rect_of(u).has_point(p) and not TouchButton.rect_of(t).has_point(p):
							stolen += 1
	_check(targets.size() >= 2 and shared == 0 and stolen == 0, "%s: %d touch targets, no pixel claimed twice (%d shared, %d inside another's rect)" % [tag, targets.size(), shared, stolen])


## Whether a touch at `p` (canvas pixels) lands on `t`: a TouchButton's own _has_point (what the GUI
## asks), else its drawn rect (sliders, text boxes, checkboxes).
func _hits(t: Control, p: Vector2) -> bool:
	var local := t.get_global_transform().affine_inverse() * p
	if t is TouchButton:
		return t._has_point(local)
	return Rect2(Vector2.ZERO, t.size).has_point(local)


## A left click at `at` (game view pixels) through the viewport's GUI input.
func _click(at: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## IMP3-04: with touch in use the visible buttons of one column sit at least TOUCH_MIN apart (top to top).
func _check_pitch(buttons: Array, tag: String) -> void:
	var tops := {}
	for b: Button in buttons:
		if b.is_visible_in_tree():
			var key := int(b.global_position.x)
			if not tops.has(key):
				tops[key] = []
			tops[key].append(b.global_position.y)
	var worst := 999.0
	for key in tops:
		var ys: Array = tops[key]
		ys.sort()
		for i in range(1, ys.size()):
			worst = minf(worst, ys[i] - ys[i - 1])
	_check(worst >= UIKit.TOUCH_MIN, "%s: button pitch %s >= %d on touch" % [tag, worst, UIKit.TOUCH_MIN])
