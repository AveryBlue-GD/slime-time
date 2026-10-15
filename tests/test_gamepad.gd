extends "res://tests/suite_base.gd"

## The fixed default gamepad layout (owner decision D4, Platform.PAD_BUTTONS; docs/spring-cleaning/phase5-platform.md):
## the pad layer survives every key binding change, real InputEventJoypadButton / InputEventJoypadMotion events
## move and leap the slime (the stick snapped to 8 directions), pause and back out, use hub stations, switch tabs
## with LB / RB (upgrades, wardrobe, hat wheel), move the focus in menus, cancel a key rebind wait, hide the touch
## controls, and make prompts name pad buttons instead of keys.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_gamepad.gd

const StartDirs := preload("res://tests/start_dirs.gd")

var progress: Node
var events: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	events = root.get_node("PlatformEvents")
	progress.save_path = throwaway_save()
	progress.enable_story_complete()
	_layer()
	await _stick()
	await _level()
	await _hub()
	await _menus()
	await _rebind()
	_prompts()
	Platform.reset_overrides()
	_result()
	quit(1 if failures else 0)


func _button(button: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(button: JoyButton, hold := 2) -> void:
	_button(button, true)
	for i in hold:
		await physics_frame
		await process_frame
	_button(button, false)
	await physics_frame
	await process_frame


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _has_button(action: String, button: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false


func _layer_complete() -> bool:
	for action: String in Platform.PAD_BUTTONS:
		for button: JoyButton in Platform.PAD_BUTTONS[action]:
			if not _has_button(action, button):
				return false
	return true


func _layer() -> void:
	_check(_layer_complete(), "every action has its pad button after startup")
	_check(InputMap.action_get_events("jump").size() == 2, "jump: the key and pad A, nothing twice")
	progress.set_binding("jump", KEY_J)
	_check(_layer_complete(), "changing a key keeps the pad layer")
	progress.reset_bindings()
	_check(_layer_complete(), "RESET KEYS keeps the pad layer")
	progress.apply_bindings()
	progress.apply_bindings()
	_check(InputMap.action_get_events("menu").size() == 3, "menu: Esc, P and START, never added twice (%d)" % InputMap.action_get_events("menu").size())
	_check(_has_button("ui_accept", JOY_BUTTON_A) and _has_button("ui_cancel", JOY_BUTTON_B) and _has_button("ui_down", JOY_BUTTON_DPAD_DOWN),
		"menus: A accepts, B cancels, the D-pad moves (ui_*)")
	var stick_nav := false
	for e in InputMap.action_get_events("ui_down"):
		stick_nav = stick_nav or (e is InputEventJoypadMotion and e.axis == JOY_AXIS_LEFT_Y)
	_check(stick_nav, "menus: the left stick moves the focus (ui_down has the stick)")
	_check(InputMap.has_action("tab_prev") and InputMap.has_action("tab_next"), "LB / RB tab actions exist")
	var expect := {jump = JOY_BUTTON_A, interact = JOY_BUTTON_X, menu = JOY_BUTTON_START, restart = JOY_BUTTON_BACK,
		ability_rifle = JOY_BUTTON_LEFT_SHOULDER, ability_splat = JOY_BUTTON_Y, ability_kaze = JOY_BUTTON_RIGHT_SHOULDER}
	for action: String in expect:
		_check(_has_button(action, expect[action]), "%s on pad button %d" % [action, expect[action]])


func _moves() -> Array[String]:
	var out: Array[String] = []
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		if Input.is_action_pressed(action):
			out.append(action)
	return out


func _stick() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.9)
	await process_frame
	_check(_moves() == ["move_right"] and is_equal_approx(Input.get_action_strength("move_right"), 1.0), "stick right: move_right at full strength")
	_axis(JOY_AXIS_LEFT_Y, 0.2)
	await process_frame
	_check(_moves() == ["move_right"], "a little off straight snaps to straight (lanes keep working)")
	_axis(JOY_AXIS_LEFT_Y, 0.85)
	await process_frame
	_check(_moves() == ["move_down", "move_right"], "stick down-right: a diagonal")
	_axis(JOY_AXIS_LEFT_X, 0.1)
	_axis(JOY_AXIS_LEFT_Y, 0.1)
	await process_frame
	_check(_moves().is_empty(), "inside the dead zone: nothing held")
	_axis(JOY_AXIS_LEFT_X, -0.9)
	await process_frame
	events.release_held_inputs()
	_check(_moves().is_empty() and events.stick_dir == Vector2.ZERO, "backgrounding lets go of the stick")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await process_frame
	_check(_moves().is_empty(), "the right stick moves nothing")
	_axis(JOY_AXIS_RIGHT_X, 0.0)


func _level() -> void:
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 2
	root.add_child(game)
	current_scene = game
	await _physics_frames(20)
	progress.force_touch = true
	game.touch_controls.visible = true
	var dir := StartDirs.open_dir(game.maze, game.maze.start)
	var start: Vector2 = game.slime.position
	var axis := JOY_AXIS_LEFT_X if dir.x != 0 else JOY_AXIS_LEFT_Y
	_axis(axis, float(dir.x + dir.y))
	await _physics_frames(30)
	_axis(axis, 0.0)
	_check(game.slime.position.distance_to(start) > 8.0, "the stick glides the slime (%.0f px)" % game.slime.position.distance_to(start))
	_button(JOY_BUTTON_A, true)
	await _physics_frames(30)
	_check(game.slime.state == Slime.State.CHARGING, "holding A charges a leap")
	_button(JOY_BUTTON_A, false)
	await _physics_frames(2)
	_check(game.slime.is_airborne() or game.slime.last_jump_traveled > 0.0 or game.slime.state == Slime.State.STUNNED, "letting go of A leaps")
	_check(not game.touch_controls.visible, "a pad button hides the touch controls")
	progress.force_touch = false
	await _physics_frames(60)
	await _tap(JOY_BUTTON_START)
	_check(game.pause_menu.visible and paused, "START pauses")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var focus := root.gui_get_focus_owner()
	_check(focus != null and game.pause_menu.is_ancestor_of(focus) and focus != game.pause_menu.buttons[0], "D-pad down moves the pause menu's focus")
	await _tap(JOY_BUTTON_B)
	_check(not game.pause_menu.visible and not paused, "B resumes (back)")
	await _tap(JOY_BUTTON_START)
	await _tap(JOY_BUTTON_START)
	_check(not game.pause_menu.visible and not paused, "START again resumes")
	progress.upgrades = {}
	progress.dev_coins = 0
	await _tap(JOY_BUTTON_BACK)
	await _physics_frames(5)
	_check(not is_instance_valid(game) or game.restart_prompt.visible or game.run_time < 1.0, "VIEW restarts (R)")
	current_scene = null
	paused = false
	for node in root.get_children():
		if node is Node2D and node.scene_file_path == "res://scenes/main.tscn":
			node.free()
	if is_instance_valid(game):
		game.free()
	await process_frame


func _hub() -> void:
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(5)
	Platform.last_input = Platform.INPUT_KEYS
	_check(hub._use_key() == "F", "hub hint names the key on a keyboard")
	Platform.last_input = Platform.INPUT_PAD
	_check(hub._use_key() == "X", "hub hint names X after pad input")
	_near(hub, "coins")
	await _tap(JOY_BUTTON_X)
	_check(hub.coin_board.visible, "X uses the station next to the slime (coin bag)")
	_check(hub.board_hint.text == "B TO CLOSE", "coin board hint names B on a pad (%s)" % hub.board_hint.text)
	await _tap(JOY_BUTTON_B)
	_check(not hub.coin_board.visible, "B closes the coin board")
	progress.tickets = 300
	_near(hub, "wheel")
	await _tap(JOY_BUTTON_X)
	_check(hub.hat_wheel.visible and hub.hat_wheel.tab == "wheel", "X opens the hat wheel")
	_check(not hub.hat_wheel.close_button.visible, "no touch BACK on the overlay with a pad")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(hub.hat_wheel.tab == "shop", "RB: SHOP")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(hub.hat_wheel.tab == "wheel", "LB: WHEEL")
	var focus := root.gui_get_focus_owner()
	_check(focus != null and hub.hat_wheel.is_ancestor_of(focus), "the focus is inside the overlay")
	var spins: int = progress.spins
	await _tap(JOY_BUTTON_A)  # A presses the focused SPIN button (a pad player can spin)
	_check(progress.spins == spins + 1 or not progress.can_spin_hats(), "A presses the focused SPIN")
	for i in 400:
		await process_frame
		if not hub.hat_wheel.spinning:
			break
	await _tap(JOY_BUTTON_B)
	_check(not hub.hat_wheel.visible, "B closes the hat wheel")
	await _physics_frames(3)
	current_scene = null
	hub.free()
	await process_frame


func _near(hub: Node2D, id: String) -> void:
	var st: Dictionary = hub._station(id)
	var at: Vector2 = st.sprite.position + (Vector2.ZERO if st.flat else Vector2(0, -2))
	var radius: float = hub._footprint(st)
	for a in 8:
		var dir := Vector2.from_angle(a * PI / 4.0)
		var edge := 1.0 / sqrt(pow(dir.x / radius, 2.0) + pow(dir.y / (radius * 0.5), 2.0))
		var spot := at + dir * (edge + Slime.RADIUS + 3.0)
		if not hub._on_floor(spot):
			continue
		hub.slime.position = spot
		hub.near = {}
		hub._update_near()
		if hub.near.get("id", "") == id:
			return


func _menus() -> void:
	var upgrades: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(upgrades)
	current_scene = upgrades
	await process_frame
	var tabs: Array[String] = upgrades._tab_pages()
	_check(upgrades.page == "coins", "upgrades open on COINS")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(tabs.size() < 2 or upgrades.page == tabs[1], "RB: the next tab (%s)" % upgrades.page)
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(upgrades.page == "coins", "LB: back to COINS")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(tabs.size() < 2 or upgrades.page == tabs[-1], "LB wraps to the last tab")
	Platform.last_input = Platform.INPUT_PAD
	progress.tickets_lifetime = maxi(progress.tickets_lifetime, 1)
	upgrades.show_page("abilities")
	_check(upgrades.hint.text.begins_with("PAD LB Y RB"), "ability hint on a pad: %s" % upgrades.hint.text)
	current_scene = null
	upgrades.free()

	var skins: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(skins)
	current_scene = skins
	await process_frame
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(skins.page == "hats", "wardrobe RB: HATS")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(skins.page == "trails", "wardrobe LB twice: TRAILS (wraps)")
	current_scene = null
	skins.free()

	var settings: Control = load("res://scenes/controls.tscn").instantiate()
	root.add_child(settings)
	current_scene = settings
	await process_frame
	var before := root.gui_get_focus_owner()
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var after := root.gui_get_focus_owner()
	_check(before != null and after != null and after != before, "D-pad moves the focus on SETTINGS")
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await process_frame
	await process_frame
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await process_frame
	_check(root.gui_get_focus_owner() != after, "the left stick moves the focus too")
	current_scene = null
	settings.free()
	await process_frame


func _rebind() -> void:
	var page: Control = load("res://scenes/key_controls.tscn").instantiate()
	root.add_child(page)
	current_scene = page
	await process_frame
	page._start_rebind("jump")
	_check(page.waiting_for == "jump", "a rebind waits for a key")
	await _tap(JOY_BUTTON_B)
	_check(page.waiting_for == "" and progress.bindings.jump == KEY_SPACE, "B cancels the wait (a pad can't give a key), nothing changed")
	_check(root.gui_get_focus_owner() == page.key_buttons.jump, "the focus goes back to that key button")
	page._start_rebind("jump")
	await _tap(JOY_BUTTON_A)
	_check(page.waiting_for == "" and progress.bindings.jump == KEY_SPACE, "A cancels too, never binds a pad button as a key")
	current_scene = null
	page.free()
	await process_frame


func _prompts() -> void:
	Platform.last_input = Platform.INPUT_PAD
	_check(Platform.prompt_for("interact", "F") == "X" and Platform.prompt_for("jump", "SPACE") == "A", "pad prompts: X, A")
	Platform.last_input = Platform.INPUT_KEYS
	_check(Platform.prompt_for("interact", "F") == "F", "keyboard prompts: the key")
	Platform.note_input(_pad_event())
	_check(Platform.using_pad(), "a pad button press marks the pad as in use")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_A
	Platform.note_input(key)
	_check(Platform.last_input == Platform.INPUT_KEYS, "a key press goes back to key prompts")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.15
	Platform.note_input(drift)
	_check(Platform.last_input == Platform.INPUT_KEYS, "stick drift does not switch the prompts")


func _pad_event() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	return e
