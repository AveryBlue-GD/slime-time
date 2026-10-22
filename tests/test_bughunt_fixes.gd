extends "res://tests/suite_base.gd"

## Fixes from the 2026-10-22 bug hunt: (1) loading a save code from before a hat-wheel spin and spinning
## again lands the same hat (no free re-rolls); (2) a run that ends while a SLIME SENSE peek is open
## closes the peek, so the result is never hidden under the map, and going to the background mid-peek
## leaves a focused pause menu; (3) a leap being charged when the app loses focus is dropped, never fired
## on RESUME; (4) no remap can put two actions on one key: the arrows and F11 are refused, and SLIME SENSE
## (not on the CONTROLS page) never has its key swapped away. Never touches a real save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_bughunt_fixes.gd

const MAIN := preload("res://scenes/main.tscn")
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = throwaway_save("bughunt")
	progress.saving_enabled = false
	_wheel_rerolls()
	_bindings()
	await _charge_on_focus_loss()
	await _win_under_peek()
	await _background_mid_peek()
	_result()
	quit(0)


func _state(levels := {}) -> void:
	progress.reset_progress()
	progress.reset_bindings()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.hard_mode = false
	progress.abilities = levels.duplicate()


func _wheel_rerolls() -> void:
	_state()
	progress.tickets = 200
	progress.spins = 1  # (past the first spin, so rare hats are on the wheel)
	var code: String = progress.save_code()
	var first: String = progress.spin_hat()
	var same := first != ""
	for i in 30:
		progress.load_code(code)
		same = same and progress.spin_hat() == first
	_check(same, "loading a code from before a spin and spinning again lands the same hat (%s), 30 times" % first)
	var second: String = progress.spin_hat()
	_check(second != "" and second != first, "the next spin goes on to another hat (%s)" % second)
	# A code from before the wheel had a seed rolls the same way every time it is loaded.
	progress.load_code(code)
	var file: ConfigFile = progress._write(true)
	file.erase_section_key("hats", "seed")
	var old_code: String = progress.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(
			file.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	progress.load_code(old_code)
	var old_first: String = progress.spin_hat()
	progress.load_code(old_code)
	_check(old_first != "" and progress.spin_hat() == old_first, "...also for a code saved before the wheel had a seed (%s)" % old_first)
	progress.reset_progress()
	_check(progress.wheel_seed == 0, "RESET PROGRESS drops the wheel's seed")


func _bindings() -> void:
	_state()
	progress.set_binding("interact", KEY_M)
	_check(progress.bindings.interact == KEY_F and progress.bindings.ability_sense == KEY_M,
		"binding USE to M is refused: SLIME SENSE keeps M and USE keeps F")
	progress.set_binding("jump", KEY_M)
	_check(progress.bindings.jump == KEY_SPACE and progress.bindings.ability_sense == KEY_M, "...the same for JUMP")
	for key: int in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_F11]:
		progress.set_binding("restart", key)
		progress.set_binding("jump", key)
	_check(progress.bindings.restart == KEY_R and progress.bindings.jump == KEY_SPACE, "the arrow keys and F11 can't be bound to an action")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_UP
	ev.pressed = true
	_check(ev.is_action("move_up") and not ev.is_action("restart"), "...so Up only moves")
	progress.set_binding("restart", KEY_SPACE)
	_check(progress.bindings.restart == KEY_SPACE and progress.bindings.jump == KEY_R, "listed actions still swap keys as before")
	var file := ConfigFile.new()
	file.set_value("controls", "restart", KEY_UP)
	file.set_value("controls", "jump", KEY_F11)
	SaveFile._read_bindings(progress, file)
	_check(progress.bindings.restart == KEY_R and progress.bindings.jump == KEY_SPACE, "a save with a reserved key reads that action back on its default")
	progress.reset_bindings()


func _spawn(random := false) -> Node2D:
	progress.mode = progress.MODE_RANDOM if random else progress.MODE_STORY
	progress.current_level = 1
	var game: Node2D = MAIN.instantiate()
	if random:
		progress.random_seed = 9004
		game.random_seed = 9004
	else:
		game.level = 1
	root.add_child(game)
	current_scene = game
	await physics_frame
	await physics_frame
	return game


func _stop(game: Node2D) -> void:
	for a in InputMap.get_actions():
		Input.action_release(a)
	paused = false
	current_scene = null
	game.free()
	await process_frame


func _charge_on_focus_loss() -> void:
	_state()
	var game := await _spawn()
	await _physics_frames(5)
	Input.action_press("jump")
	await _physics_frames(30)
	var charging: bool = game.slime.state == Slime.State.CHARGING
	var events := root.get_node("PlatformEvents")
	events.enter_background(true)
	await _physics_frames(10)
	events.leave_background()
	game.pause_menu.resume()
	await _physics_frames(5)
	_check(charging and paused == false and game.slime.state == Slime.State.GLIDE,
		"a leap charging when the app loses focus is dropped, not fired on RESUME (state %d)" % game.slime.state)
	await _stop(game)


func _win_under_peek() -> void:
	_state({sense = 3})
	var game := await _spawn(true)
	game._spawn_at = Vector2.INF
	game.toggle_run_map()
	_check(game.random_map_view != null, "(SLIME SENSE peek open)")
	game.slime.position = game.goal.position
	await _physics_frames(5)
	_check(game.won and game.random_map_view == null, "winning with the peek open closes it, so the result shows")
	await _stop(game)


func _background_mid_peek() -> void:
	_state({sense = 3})
	var game := await _spawn(true)
	game._spawn_at = Vector2.INF
	game.toggle_run_map()
	var p: bool = game.pause_for_background()
	await _physics_frames(2)
	var focus: Control = root.gui_get_focus_owner()
	_check(p and game.random_map_view == null and game.pause_menu.visible and focus != null and game.pause_menu.is_ancestor_of(focus),
		"going to the background mid-peek closes the map and focuses the pause menu (%s)" % focus)
	await _stop(game)
