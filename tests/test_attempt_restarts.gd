extends "res://tests/suite_base.gd"

## The randomizer's attempt pod ("ATTEMPT n" over "TIX AVAILABLE k") counts down on EVERY real
## restart route and a win pays exactly the k it shows, in normal mode AND in the owner's dev launch
## (tools/play.sh --dev = --unlock-all: Progress.enable_dev_mode, dev tools on, saving off, so the
## tickets only land in memory). Routes, each driven with real input where a player uses input:
## R at once (no coins), the R prompt's RESTART (coins in hand), the pause menu's RESTART by keyboard
## (Esc, Down, Enter) and by mouse (a click on the button), Esc + RESTART after drying up, the dry-up
## RESTART button, the UPGRADES round trip (dry-up UPGRADES, then PLAY) and the win's REPLAY MAZE.
## Attempts 1-6 each: the pod's text on the restarted run's first frame, then a win by autopilot
## (walking the shortest route onto the ticket) whose tickets delta and result line must match it.
## Also: QUIT TO HUB + the hub portal and NEW MAZE start at 1 again, typed seeds and no MORE SLIME cap
## at 1, the daily cap / dev toggles / assist show and pay 0, the pod is re-derived every frame (a
## stale label fixes itself), and it pops when its number changes (none with Reduce Motion).
## Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_attempt_restarts.gd

var test_save := throwaway_save()
const GAME_SCENE := "res://scenes/main.tscn"
const PAY := [5, 4, 3, 2, 1, 1]
const ROUTES := ["r_key", "prompt", "pause_keys", "pause_mouse", "pause_after_dryup", "dryup", "upgrades"]

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.hard_mode = false
	progress.reset_progress()
	progress.day_override = 40000

	for dev in [false, true]:
		_set_mode(dev)
		var tag := "dev launch: " if dev else "normal: "
		# Each route on its own fresh maze: attempts 1-6 read off the pod on each restart's first frame.
		for route in ROUTES + ["replay"]:
			_set_coins(route, dev)
			var game := await _start_new_maze()
			var seed_value: int = game.random_seed
			var seen: Array[String] = [_pod(game)]
			var ok := _pod(game) == _text(1, 5)
			for n in range(2, 7):
				game = await _restart(game, route, n % 2 == 0)  # every other one after moving
				seen.append(_pod(game).replace("\nTIX AVAILABLE ", " k="))
				# REPLAY MAZE follows a win, and a seed that paid today pays nothing again: 0
				var want := _text(n, 0 if route == "replay" else PAY[n - 1])
				ok = ok and game != null and game.random_seed == seed_value and _pod(game) == want and game.ticket_offer() == _k(want)
				if not ok:
					break
			_check(ok, "%s%s: the pod counts the attempts and the tickets down on every restart %s" % [tag, route, seen])
			await _leave(game)
			_reset_day()
		# A win pays what the pod showed: attempts 1-6 through every route (autopilot onto the ticket).
		for route in ROUTES:
			_set_coins(route, dev)
			var results: Array[String] = []
			var ok := true
			for n in range(1, 7):
				var game := await _start_new_maze()
				for i in n - 1:
					game = await _restart(game, route, i % 2 == 1)
				var shown := _pod(game)
				var win := await _win(game)
				var line := "TICKET! ATTEMPT %d = +%d" % [n, PAY[n - 1]]
				ok = ok and shown == _text(n, PAY[n - 1]) and win.paid == PAY[n - 1] and win.paid == _k(shown) \
						and line in game.hud.rewards_texts
				results.append("%d:+%d" % [n, win.paid])
				await _leave(game)
				_reset_day()
			_check(ok, "%s%s: wins on attempts 1-6 pay exactly what the pod showed (5 4 3 2 1 1) and say so %s" % [tag, route, results])
		# REPLAY MAZE: shows 0 and a win then pays 0 (the seed already paid today).
		var g := await _start_new_maze()
		g = await _restart(g, "replay")
		var replay_win := await _win(g)
		_check(_k(replay_win.shown) == 0 and replay_win.paid == 0, "%sREPLAY MAZE after a win: shows 0 and pays 0 (%s)" % [tag, replay_win.shown])
		await _leave(g)
		_reset_day()

		# QUIT TO HUB, then the hub's portal: a new maze at attempt 1 again.
		_set_coins("pause_keys", dev)
		g = await _start_new_maze()
		var old_seed: int = g.random_seed
		g = await _restart(g, "pause_keys")
		g = await _restart(g, "pause_mouse")
		_check(_pod(g) == _text(3, 3), "%s(attempt 3 before quitting: %s)" % [tag, _pod(g)])
		_find_button(g.pause_menu, "QUIT TO HUB")  # exists
		_key(KEY_ESCAPE)
		await process_frame
		_find_button(g.pause_menu, "QUIT TO HUB").pressed.emit()
		var hub := await _wait_scene("hub")
		hub._use(hub._station("random"))  # the portal's choice (Descent batch 3): RANDOM MAZE
		hub.maze_button.pressed.emit()
		g = await _wait_game(0)
		_check(g.random_seed != old_seed and _pod(g) == _text(1, 5), "%squit to the hub, then the portal: a new maze at ATTEMPT 1, 5 (%s)" % [tag, _pod(g)])
		g = await _restart(g, "pause_keys")
		var w := await _win(g)
		_check(w.shown == _text(2, 4) and w.paid == 4, "%s...its pause restart is attempt 2 and a win pays 4 (%s, +%d)" % [tag, w.shown, w.paid])
		await _wait_choices(g)
		var won_seed: int = g.random_seed
		_find_button(g.hud, "NEW MAZE").pressed.emit()
		var g2 := await _wait_game(g.get_instance_id())
		_check(g2.random_seed != won_seed and _pod(g2) == _text(1, 5), "%sNEW MAZE: ATTEMPT 1, 5 again (%s)" % [tag, _pod(g2)])
		g = await _restart(g2, "pause_mouse")
		_check(_pod(g) == _text(2, 4), "%s...and counts on from there (%s)" % [tag, _pod(g)])
		await _leave(g)
		_reset_day()

		# Caps: they show on the pod, and the win agrees.
		_set_coins("pause_keys", dev)
		g = await _start_new_maze()
		g.pause_menu._submit_seed("123457")  # another maze's number typed into the SEED box
		g = await _wait_game(g.get_instance_id())
		var capped := [_pod(g)]
		for n in range(2, 7):
			g = await _restart(g, "pause_keys")
			capped.append(_pod(g).replace("\nTIX AVAILABLE ", " k="))
		w = await _win(g)
		_check(_k(capped[0]) == 1 and w.shown == _text(6, 1) and w.paid == 1, "%styped seed: 1 on every attempt, and a win pays 1 %s" % [tag, capped])
		await _leave(g)
		_reset_day()
		progress.upgrades = {}
		g = await _start_new_maze()
		# No MORE SLIME bought: capped at 1 in normal play; dev mode (everything unlocked) has no such cap.
		var no_slime_k := [5, 4] if dev else [1, 1]
		_check(_pod(g) == _text(1, no_slime_k[0]), "%sno MORE SLIME: attempt 1 shows %d (%s)" % [tag, no_slime_k[0], _pod(g)])
		g = await _restart(g, "pause_mouse")
		w = await _win(g)
		_check(w.shown == _text(2, no_slime_k[1]) and w.paid == no_slime_k[1], "%s...attempt 2 shows %d and a win pays it (%s)" % [tag, no_slime_k[1], w.shown])
		await _leave(g)
		_reset_day()
		progress.upgrades = {"slime": 1}
		progress.random_paid = progress.RANDOM_PAID_PER_DAY
		progress.random_pay_day = progress.utc_day()
		g = await _start_new_maze()
		g = await _restart(g, "pause_keys")
		w = await _win(g)
		_check(w.shown == _text(2, 0) and w.paid == 0 and "DAILY TICKET LIMIT REACHED" in g.hud.rewards_texts,
			"%sdaily cap reached: attempt 2 shows 0 and a win pays 0 (%s)" % [tag, w.shown])
		await _leave(g)
		_reset_day()
		g = await _start_new_maze()
		g = await _restart(g, "pause_keys")
		g.assisted = true  # an assisted attempt (the slime reserve)
		await process_frame
		w = await _win(g)
		_check(w.shown == _text(2, 0) and w.paid == 0, "%sassisted: the pod drops to 0 on the next frame and a win pays 0 (%s)" % [tag, w.shown])
		await _leave(g)
		_reset_day()
		# The pod is re-derived every frame: a stale label can't survive a frame.
		g = await _start_new_maze()
		g = await _restart(g, "pause_keys")
		g.hud.attempt_label.text = "ATTEMPT 1\nTIX AVAILABLE 5"
		await process_frame
		_check(_pod(g) == _text(2, 4), "%sa stale pod is corrected on the next frame (%s)" % [tag, _pod(g)])
		await _leave(g)

	# Dev launch with no MORE SLIME bought (the owner's setup): the pod counts 5, 4, 3, 2, 1, 1 and a win pays what it showed.
	_set_mode(true)
	progress.upgrades = {}
	var table := []
	var dg := await _start_new_maze()
	for n in range(1, 7):
		if n > 1:
			dg = await _restart(dg, "pause_keys")
		table.append(_k(_pod(dg)))
	var dw := await _win(dg)
	_check(table == [5, 4, 3, 2, 1, 1] and dw.shown == _text(6, 1) and dw.paid == 1, "dev mode, no MORE SLIME: the pod counts %s and the win pays 1 (%s)" % [table, dw.shown])
	await _leave(dg)
	_reset_day()

	# Dev toggles (dev launch): 0 while on, kept across restarts, and a toggled win pays 0.
	_set_mode(true)
	var game := await _start_new_maze()
	game.set_dev_bright(true)
	_check(_pod(game) == _text(1, 0), "dev FULL BRIGHT: the pod shows 0 (%s)" % _pod(game))
	game = await _restart(game, "pause_keys")
	var tw := await _win(game)
	_check(tw.shown == _text(2, 0) and tw.paid == 0, "...still 0 on the restarted run (toggle kept), and a win pays 0 (%s)" % tw.shown)
	progress.dev_bright = false
	await _leave(game)
	_reset_day()

	# --- The countdown pops when the number changes (not on a first start; never with Reduce Motion)
	_set_mode(false)
	game = await _start_new_maze()
	_check(not game.hud.attempt_flashing(), "attempt 1: no pop")
	game = await _restart(game, "pause_keys")
	_check(game.hud.attempt_flashing(), "a restart that lowers the number pops the pod")
	for i in 60:
		await process_frame
	_check(not game.hud.attempt_flashing(), "...for about half a second, then it's back to normal")
	progress.reduce_motion = true
	game = await _restart(game, "r_key")
	_check(not game.hud.attempt_flashing() and _pod(game) == _text(3, 3), "Reduce Motion: the number just changes (%s)" % _pod(game))
	progress.reduce_motion = false
	for i in 4:
		game = await _restart(game, "r_key")
	_check(_pod(game) == _text(7, 1) and not game.hud.attempt_flashing(), "7th attempt: 1 as before, nothing to pop")
	await _leave(game)

	progress.day_override = -1
	progress.dev_tools = false
	progress.reset_progress()
	_result()
	quit(1 if failures > 0 else 0)


## Normal mode, or exactly what --unlock-all sets up (dev tools on, saving off, 999 dev coins).
func _set_mode(dev: bool) -> void:
	progress.reset_progress()
	progress.day_override = 40000
	if dev:
		progress.enable_dev_mode()
	else:
		progress.dev_tools = false
		progress.saving_enabled = true
		progress.levels_cleared = Levels.COUNT  # the hub's portal is open
		progress.highest_unlocked = Levels.COUNT
	progress.dev_bright = false
	progress.dev_no_drain = false
	progress.upgrades = {"slime": 1}


## No coins in hand: R restarts at once; coins in hand (always in dev mode): the R prompt opens.
func _set_coins(route: String, dev: bool) -> void:
	progress.coins_found = {1: ["1,1", "2,2", "3,3"]} if route == "prompt" else {}
	if route == "prompt":
		assert(progress.coins() > 0)
	elif route == "r_key" and not dev:
		assert(progress.coins() <= 0)


func _text(n: int, k: int) -> String:
	return "ATTEMPT %d\nTIX AVAILABLE %d" % [n, k]


func _k(text: String) -> int:
	return text.get_slice("TIX AVAILABLE ", 1).to_int() if "TIX AVAILABLE " in text else -1


func _pod(game: Node) -> String:
	return game.hud.attempt_label.text if game and game.hud.attempt_pod.visible else "<no pod>"


func _reset_day() -> void:
	progress.random_paid = 0
	progress.random_paid_seeds.clear()


## The hub's portal: a new randomizer maze, the game scene loaded the way the game loads it.
func _start_new_maze() -> Node2D:
	progress.start_random()
	change_scene_to_file(GAME_SCENE)
	return await _wait_game(0)


## The new game scene as soon as it is in the tree (its _ready has run: the first frame it draws).
func _wait_game(old_id: int) -> Node2D:
	for i in 900:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_instance_id() != old_id and scene.is_inside_tree() and scene.get("attempt") != null:
			while get_root().get_node("Transition").busy:  # arriving through a goo wipe: input waits for it
				await process_frame
			return scene
	_check(false, "a new game scene appeared")
	return null


## Restarts `game` by the real route (after moving for a moment if `move_first`) and returns the
## restarted game.
func _restart(game: Node2D, route: String, move_first := false) -> Node2D:
	var old_id := game.get_instance_id()
	if move_first and route != "replay":
		Input.action_press("move_right")
		Input.action_press("move_down")
		for i in 12:
			await physics_frame
		Input.action_release("move_right")
		Input.action_release("move_down")
	match route:
		"r_key", "prompt":
			_key(KEY_R)
			await process_frame
			await process_frame
			if progress.coins() > 0:
				_check_quiet(game.restart_prompt.visible, "the R prompt opened (coins in hand)")
				_find_button(game.restart_prompt, "RESTART").pressed.emit()
		"pause_keys", "pause_after_dryup":
			if route == "pause_after_dryup":
				await _dry_up(game)
			_key(KEY_ESCAPE)
			await process_frame
			await process_frame
			_check_quiet(game.pause_menu.visible and get_root().gui_get_focus_owner() == game.pause_menu.buttons[0], "Esc opened the pause menu on RESUME")
			_key(KEY_DOWN)
			await process_frame
			await process_frame
			_check_quiet(get_root().gui_get_focus_owner() == game.pause_menu.buttons[1], "Down moved to RESTART")
			_key(KEY_ENTER)
		"pause_mouse":
			_key(KEY_ESCAPE)
			await process_frame
			await process_frame
			_check_quiet(game.pause_menu.visible, "Esc opened the pause menu")
			_click(_find_button(game.pause_menu, "RESTART"))
		"dryup", "upgrades":
			await _dry_up(game)
			if route == "dryup":
				_find_button(game.hud, "RESTART").pressed.emit()
			else:
				_find_button(game.hud, "UPGRADES").pressed.emit()
				var screen := await _wait_scene("upgrades")
				_find_button(screen, "PLAY").pressed.emit()
		"replay":
			await _win(game)
			await _wait_choices(game)
			_find_button(game.hud, "REPLAY MAZE").pressed.emit()
	return await _wait_game(old_id)


## A real key press and release (keycode and physical keycode), a frame apart.
func _key(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()


## A real left click in the middle of `control` (window coordinates).
func _click(control: Control) -> void:
	var at := get_root().get_final_transform() * control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		Input.flush_buffered_events()


func _dry_up(game: Node2D) -> void:
	game.slime_remaining = 0.0
	for i in 30:
		await physics_frame
	await _wait_choices(game)


func _wait_choices(game: Node2D) -> void:
	for i in 600:
		if game.hud.choice_buttons.size() > 0 and game.hud.choice_buttons[0].is_visible_in_tree():
			return
		await process_frame


func _wait_scene(name_part: String) -> Node:
	for i in 600:
		await process_frame
		if current_scene and name_part in current_scene.scene_file_path:
			await process_frame
			return current_scene
	return null


## Wins `game` by autopilot: walks the slime along the shortest route onto the ticket, a few px per
## physics frame (gliding drains the meter as usual). Returns {shown: the pod just before the win,
## paid: the tickets the balance gained (in memory in dev mode, where nothing is saved)}.
func _win(game: Node2D) -> Dictionary:
	var before: int = progress.tickets
	var shown := _pod(game)
	var route := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var points: Array[Vector2] = []
	for cell in route:
		points.append(MazeGenerator.cell_center(cell, 16))
	var index := 1
	for step in 3000:
		if game.won or index >= points.size():
			break
		shown = _pod(game)
		var delta: Vector2 = points[index] - game.slime.position
		if delta.length() <= 4.0:
			index += 1
			continue
		game.slime.position += delta.limit_length(4.0)
		await physics_frame
	for i in 5:
		await physics_frame
	_check_quiet(game.won, "the autopilot reached the ticket")
	return {shown = shown, paid = progress.tickets - before}


## Leaves a game for good (as QUIT TO HUB would, without the hub).
func _leave(game: Variant) -> void:
	get_root().get_node("Transition").busy = false
	paused = false
	if is_instance_valid(game) and game == current_scene:
		current_scene = null
		game.queue_free()
	elif current_scene:
		var scene := current_scene
		current_scene = null
		scene.queue_free()
	await process_frame
	await process_frame


func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	push_error("no %s button under %s" % [text, node.name])
	return null


func _check_quiet(ok: bool, label: String) -> void:
	if not ok:
		_check(false, label)


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label.replace("\n", " / "))
	if not ok:
		failures += 1
