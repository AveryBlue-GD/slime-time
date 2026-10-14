extends SceneTree

## Mercy assist ("slime reserve"): after 3 dry-ups on the same story level in a session, the dry-up
## screen offers an optional ASSIST attempt with a bit more slime. It's never offered on hard
## mode or in randomizer mazes, applies to one attempt only, is labelled in the HUD, and an
## assisted win earns no medal tier and sets no record (but does clear the level). Throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_mercy.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()

	# --- Gating
	progress.dry_ups[1] = 2
	_check(not progress.assist_offered(1) and not progress.accept_assist(1), "two dry-ups: no assist yet")
	progress.dry_ups[1] = 3
	_check(progress.assist_offered(1) and not progress.assist_offered(2), "three dry-ups on a level offer it for that level only")
	progress.hard_mode = true
	_check(not progress.assist_offered(1) and not progress.accept_assist(1), "never on hard mode")
	progress.hard_mode = false
	_check(progress.accept_assist(1) and progress.assist_level == 1, "accepting sets it up for the next attempt")
	_check(not progress.take_assist(2) and progress.assist_level == 0, "(another level's attempt doesn't use it, and it's gone)")
	progress.accept_assist(1)
	_check(progress.take_assist(1) and not progress.take_assist(1), "it's used once: one attempt")
	_check(progress.assist_level == 0 and not ("assist" in progress._write().encode_to_text()), "...and is never saved")

	# --- The dry-up screen offers it (only when it should)
	var game := await _spawn(1, false)
	game._offer_retry()
	_check(_buttons(game) == ["RESTART", "ASSIST", "UPGRADES"] and game.hud.choice_buttons[0].has_focus(), "after 3 dry-ups: RESTART (the default), ASSIST, UPGRADES")
	_check("ASSIST" in game.hud.rewards_texts[0] and "NO MEDALS" in game.hud.rewards_texts[0], "...clearly labelled: no medals or tickets (%s)" % game.hud.rewards_texts[0])
	game.free()
	progress.dry_ups[1] = 2
	game = await _spawn(1, false)
	game._offer_retry()
	_check(_buttons(game) == ["RESTART", "UPGRADES"], "with fewer dry-ups it isn't offered")
	game.free()
	progress.dry_ups[1] = 5
	progress.hard_mode = true
	game = await _spawn(1, false)
	game._offer_retry()
	_check(_buttons(game) == ["RESTART", "UPGRADES"], "not on hard mode, however many dry-ups")
	game.free()
	progress.hard_mode = false
	progress.start_random()
	game = MAIN.instantiate()
	game.random_seed = 777
	root.add_child(game)
	await physics_frame
	game._offer_retry()
	_check(_buttons(game) == ["RESTART", "NEW MAZE", "UPGRADES"], "not in randomizer mazes")
	game.free()
	# (were a randomizer run ever assisted, its ticket would pay nothing, and the pod would say so)
	progress.upgrades = {"slime": 1}
	game = MAIN.instantiate()
	game.random_seed = 778
	game.assisted = true
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.hud.attempt_label.text.ends_with(" 0 TIX"), "an assisted randomizer attempt shows 0 TIX (%s)" % game.hud.attempt_label.text)
	var tickets_before: int = progress.tickets
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.won and progress.tickets == tickets_before and "ASSIST" in " ".join(game.hud.rewards_texts), "...and its win pays nothing (%s)" % " ".join(game.hud.rewards_texts))
	await _stop(game)
	progress.upgrades = {}
	progress.mode = progress.MODE_STORY

	# --- An assisted attempt: a little more slime, labelled, for one attempt
	progress.dry_ups[1] = 3
	game = await _spawn(1, false)
	var plain_cost: float = game.slime_cost_per_tile
	game.free()
	progress.accept_assist(1)
	game = await _spawn(1, false)
	_check(game.assisted and is_equal_approx(game.slime_cost_per_tile, plain_cost / 1.1) and game.hud.assist_pod.visible, "assisted: 10% more slime to spend, with an ASSIST tag in the HUD")
	game.free()
	game = await _spawn(1, false)
	_check(not game.assisted and is_equal_approx(game.slime_cost_per_tile, plain_cost) and not game.hud.assist_pod.visible, "the next attempt is unassisted again")
	game.free()

	# --- Coins picked up in an assisted run show on screen but are never saved
	progress.dry_ups[1] = 3
	progress.accept_assist(1)
	game = await _spawn(1, false)
	var coin: Coin = game.coins[0]
	game.slime.position = coin.position
	await physics_frame
	await physics_frame
	_check(game.assisted and not progress.has_coin(1, coin.cell) and progress.coins_found_in(1) == 0 and game.assisted_coins == 1,
		"an assisted run's coin isn't saved")
	_check(game.hud.coins_left_label.text == "%d LEFT" % (game.coins_here - 1), "...but the HUD still counts it (%s)" % game.hud.coins_left_label.text)
	game.free()

	# --- An assisted win: clears the level, but no tickets, medals or record
	progress.best_times = {}
	progress.accept_assist(1)
	game = await _spawn(1, true)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(game.won and game.assisted and game.reward.assisted and game.reward.tier == 0 and progress.tickets == 0, "an assisted win earns no tier or tickets")
	_check(progress.medals_for(1) == 0 and not progress.best_times.has(1), "...no medals and no record")
	_check(progress.levels_cleared == 1 and not progress.dry_ups.has(1), "...but the level is cleared and the dry-ups reset")
	_check("NO MEDALS" in game.hud.rewards_texts[0], "...and the result says so")
	await _stop(game)
	progress.start_story(1)
	game = await _spawn(1, true)
	game.slime.position = game.goal.position
	for i in 10:
		await physics_frame
	_check(not game.assisted and game.reward.new_best and progress.medals_for(1) >= 1 and progress.best_times.has(1), "the next, unassisted clear earns its medal and sets the record")
	await _stop(game)

	# --- A finishing clear is one save: the payment, the record and the cleared mark together
	progress.reset_progress()
	var done: Dictionary = progress.record_clear(1, 5.0, 10.0, false, true)
	var saved := ConfigFile.new()
	saved.load(progress.save_path)
	_check(done.tier == 3 and saved.get_value("medals", "level_1", 0) == 3 and saved.get_value("progress", "levels_cleared", 0) == 1
		and saved.get_value("records", "level_1", -1.0) == 5.0, "record_clear(finish) saves the medal tier, record and cleared mark together")
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _buttons(game: Node2D) -> Array[String]:
	var names: Array[String] = []
	for button in game.hud.choice_buttons:
		names.append(button.text)
	return names


func _spawn(level: int, running: bool) -> Node2D:
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	if running:
		current_scene = game
	await physics_frame
	return game


func _stop(game: Node2D) -> void:
	current_scene = null
	for i in int(game.END_DELAY * 60) + 10:
		await physics_frame
	game.free()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
