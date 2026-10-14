extends SceneTree

## The randomizer's attempt pod (ATTEMPT n / TIX AVAILABLE k/5) counts down on EVERY real restart
## route, read from the pod's displayed text on the restarted run's first frame: R (straight away
## and through the R prompt's RESTART), the pause menu's RESTART button, the dry-up RESTART button,
## the win screen's REPLAY MAZE, and the UPGRADES round trip (dry-up UPGRADES, then PLAY). A win pays
## exactly what the pod showed, for attempts 1-6 and every route; quitting to the hub and coming back
## with a NEW maze starts at 1 again; dev mode (999 coins) behaves the same; the caps still show
## (typed seed, no MORE SLIME, dev toggles, daily cap). The pod pops when its number changes (none
## with Reduce Motion). Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_attempt_restarts.gd

const TEST_SAVE := "user://test_save.cfg"
const GAME_SCENE := "res://scenes/main.tscn"
const PAY := [5, 4, 3, 2, 1, 1]

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.hard_mode = false
	progress.reset_progress()
	progress.day_override = 40000

	for dev in [false, true]:
		progress.dev_tools = dev
		progress.dev_bright = false
		progress.dev_no_drain = false
		progress.upgrades = {"slime": 1}
		var tag := "dev: " if dev else ""
		# Each route, on its own fresh maze: start, restart that way, read the pod each time.
		for route in ["r_key", "r_coins", "pause", "dryup", "upgrades", "replay"]:
			# no coins in hand: R restarts at once; with coins (and always in dev mode, 999 coins): the
			# R prompt opens and its RESTART restarts
			progress.coins_found = {1: ["1,1", "2,2", "3,3"]} if route == "r_coins" else {}
			var game := await _start_new_maze()
			var seed_value: int = game.random_seed
			var ok := _pod_is(game, 1)
			for n in range(2, 7):
				game = await _restart(game, route)
				# REPLAY MAZE follows a win, and a seed that paid today pays nothing again: 0/5
				var shown_ok := _pod(game) == "ATTEMPT %d\nTIX AVAILABLE 0/5" % n if route == "replay" else _pod_is(game, n)
				ok = ok and game != null and game.random_seed == seed_value and shown_ok
				if not ok:
					break
			var expect := "ATTEMPT 2..6 at 0/5 (the won seed already paid today)" if route == "replay" else "ATTEMPT 1..6 count down 5/5 4/5 3/5 2/5 1/5 1/5"
			_check(ok, "%s%s: %s on the first frame of each restart (%s)" % [tag, route, expect, _pod(game).replace("\n", " ")])
			_reset_day()
		# A win pays what the pod showed, attempt 1-6, through every route.
		for route in ["r_key", "pause", "dryup", "upgrades"]:
			for n in range(1, 7):
				var game := await _start_new_maze()
				for i in n - 1:
					game = await _restart(game, route)
				var shown := _pod(game)
				var paid := await _win(game)
				_check(paid == PAY[n - 1] and shown.ends_with("%d/5" % paid), "%s%s: a win on attempt %d pays %d, as the pod said (%s)" % [tag, route, n, paid, shown.replace("\n", " ")])
				await _leave(game)
				_reset_day()
		# Quit to the hub and back: a NEW maze, attempt 1 again.
		var g := await _start_new_maze()
		var old_seed: int = g.random_seed
		g = await _restart(g, "pause")
		g = await _restart(g, "pause")
		_check(_pod_is(g, 3), "%s(attempt 3 before quitting)" % tag)
		await _leave(g)
		g = await _start_new_maze()  # the hub's portal: Progress.start_random
		_check(g.random_seed != old_seed and _pod_is(g, 1), "%squit to the hub, then a new maze: ATTEMPT 1, 5/5 (%s)" % [tag, _pod(g)])
		g = await _restart(g, "r_key")
		_check(_pod_is(g, 2), "%s...and its restart is ATTEMPT 2, 4/5 (%s)" % [tag, _pod(g)])
		var paid := await _win(g)
		_check(paid == 4, "%s...an R-restart win on attempt 2 pays 4 (%d)" % [tag, paid])
		await _leave(g)
		_reset_day()

	# --- Caps still shown, and they agree with the payout
	progress.dev_tools = true
	progress.upgrades = {"slime": 1}
	var game := await _start_new_maze()
	game.set_dev_bright(true)
	_check(_pod(game).ends_with("0/5"), "dev FULL BRIGHT: the pod shows 0/5 (%s)" % _pod(game))
	game = await _restart(game, "r_key")
	_check(_pod(game) == "ATTEMPT 2\nTIX AVAILABLE 0/5", "...still 0/5 on the restarted run (toggle kept) (%s)" % _pod(game))
	game.set_dev_bright(false)
	await _leave(game)
	progress.dev_bright = false
	progress.dev_tools = false
	progress.upgrades = {}
	game = await _start_new_maze()
	game = await _restart(game, "pause")
	_check(_pod(game) == "ATTEMPT 2\nTIX AVAILABLE 1/5", "no MORE SLIME: attempt 2 shows 1/5 (%s)" % _pod(game))
	_check(await _win(game) == 1, "...and pays 1")
	await _leave(game)
	_reset_day()
	progress.upgrades = {"slime": 1}
	game = await _start_new_maze()
	progress.random_seed_fresh = false  # as a typed seed does (pause menu SEED box)
	game = await _restart(game, "dryup")
	_check(_pod(game) == "ATTEMPT 2\nTIX AVAILABLE 1/5", "typed seed: attempt 2 shows 1/5 (%s)" % _pod(game))
	_check(await _win(game) == 1, "...and pays 1")
	await _leave(game)
	_reset_day()
	progress.random_paid = 5
	progress.random_pay_day = progress.utc_day()
	game = await _start_new_maze()
	game = await _restart(game, "r_key")
	_check(_pod(game) == "ATTEMPT 2\nTIX AVAILABLE 0/5", "daily cap reached: attempt 2 shows 0/5 (%s)" % _pod(game))
	_check(await _win(game) == 0, "...and pays 0")
	await _leave(game)
	_reset_day()

	# --- The countdown pops when the number changes (not on a first start; never with Reduce Motion)
	game = await _start_new_maze()
	_check(not game.hud.attempt_flashing(), "attempt 1: no pop")
	game = await _restart(game, "r_key")
	_check(game.hud.attempt_flashing(), "a restart that lowers the number pops the pod")
	for i in 60:
		await process_frame
	_check(not game.hud.attempt_flashing() and game.hud.attempt_pod.scale == Vector2.ONE, "...for about half a second, then it's back to normal")
	progress.reduce_motion = true
	game = await _restart(game, "r_key")
	_check(not game.hud.attempt_flashing() and _pod_is(game, 3), "Reduce Motion: the number just changes (%s)" % _pod(game))
	progress.reduce_motion = false
	for i in 4:
		game = await _restart(game, "r_key")
	_check(_pod_is(game, 7) and not game.hud.attempt_flashing(), "7th attempt: 1/5 as before, nothing to pop")
	await _leave(game)

	progress.day_override = -1
	progress.dev_tools = false
	progress.reset_progress()
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _pod(game: Node) -> String:
	return game.hud.attempt_label.text if game and game.hud.attempt_pod.visible else "<no pod>"


func _pod_is(game: Node, n: int) -> bool:
	return _pod(game) == "ATTEMPT %d\nTIX AVAILABLE %d/5" % [n, PAY[mini(n, PAY.size()) - 1]]


func _reset_day() -> void:
	progress.random_paid = 0
	progress.random_paid_seeds.clear()


## The hub's portal: a new randomizer maze, the game scene loaded the way the game loads it.
func _start_new_maze() -> Node2D:
	progress.start_random()
	change_scene_to_file(GAME_SCENE)
	return await _first_frame()


## The new game scene as soon as it is in the tree (its _ready has run: the first frame it draws).
func _first_frame(old_id := 0) -> Node2D:
	for i in 600:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_instance_id() != old_id and scene.is_inside_tree() and scene.get("attempt") != null:
			return scene
	return null


## Restarts `game` by the real route and returns the restarted game.
func _restart(game: Node2D, route: String) -> Node2D:
	var old_id := game.get_instance_id()
	match route:
		"r_key", "r_coins":
			_press("restart")
			await process_frame
			if progress.coins() > 0:
				_check_quiet(game.restart_prompt.visible, "the R prompt opened (coins in hand)")
				_find_button(game.restart_prompt, "RESTART").pressed.emit()
		"pause":
			_press("menu")
			await process_frame
			_find_button(game.pause_menu, "RESTART").pressed.emit()
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
	return await _first_frame(old_id)


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


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


## Wins `game` (the slime on the ticket) and returns the tickets it paid.
func _win(game: Node2D) -> int:
	var before: int = progress.tickets
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check_quiet(game.won, "the win registered")
	return progress.tickets - before


## Leaves a game for good (as QUIT TO HUB would, without the hub).
func _leave(game: Variant) -> void:
	if is_instance_valid(game):
		current_scene = null
		game.queue_free()
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
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
