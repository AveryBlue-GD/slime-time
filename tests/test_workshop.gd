extends "res://tests/suite_base.gd"

## Ticket WORKSHOP checks (upgrades v2 batch 2, docs/design/upgrades-v2.md B.2): each effect in a real
## level - QUICK CHARGE (a full charge in 0.7 s instead of 1.5), STICKY (splat penalty x0.40, stun
## 0.06 s), MAGNET (coins within 34 px fly in, only on revealed floor in plain sight), GOO NOSE
## (glimmers x2.3 as often, 300 px), SECOND WIND (refills to 25% once per run, then the next empty meter
## dries up; not on a level's first clear; in the randomizer it costs one attempt step of the payout,
## the attempt pod shows it live). Hard mode turns all of it off, par never moves, nothing touches the
## real save. Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_workshop.gd

const MAIN := preload("res://scenes/main.tscn")

var progress: Node


func _initialize() -> void:
	Economy.coincatch_force = 0  # assumes the instant pickup (coin catch has its own suite)
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.saving_enabled = false
	Economy.workshop_force = 1  # the workshop is switched off in the game; these suites test it
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	await _charge()
	await _sticky()
	await _magnet()
	await _nose()
	await _wind()
	await _wind_random()
	await _hard_and_par()
	progress.reset_progress()
	_result()
	quit(0 if failures == 0 else 1)


func _state(levels: Dictionary, cleared := 10) -> void:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	progress.levels_cleared = cleared
	progress.highest_unlocked = mini(cleared + 1, 10)
	progress.mode = progress.MODE_STORY
	progress.workshop = levels.duplicate()


func _spawn(level := 1, random_seed := 0) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	if random_seed != 0:
		progress.mode = progress.MODE_RANDOM
		progress.random_seed = random_seed
		game.random_seed = random_seed
	else:
		game.level = level
	root.add_child(game)
	await physics_frame
	return game


func _stop(game: Node2D) -> void:
	Input.action_release("jump")
	game.free()
	await process_frame


# ---------------------------------------------------------------- QUICK CHARGE

## Frames from pressing jump until the charge is full.
func _charge_frames(game: Node2D) -> int:
	Input.action_press("jump")
	var n := 0
	while game.slime.charge < 100.0 and n < 200:
		await physics_frame
		n += 1
	Input.action_release("jump")
	await _physics_frames(80)
	return n


func _charge() -> void:
	_state({})
	var game := await _spawn()
	await _physics_frames(5)
	var base := await _charge_frames(game)
	await _stop(game)
	_state({charge = 3})
	game = await _spawn()
	await _physics_frames(5)
	var quick := await _charge_frames(game)
	_check(is_equal_approx(game.slime.charge_time, 0.7) and absi(base - 90) <= 3 and absi(quick - 42) <= 3,
		"QUICK CHARGE 3: a full charge in %d frames (0.7 s) instead of %d (1.5 s)" % [quick, base])
	await _stop(game)


# ---------------------------------------------------------------- STICKY

func _sticky() -> void:
	for level in [0, 3]:
		_state({sticky = level} if level > 0 else {})
		var game := await _spawn()
		await _physics_frames(3)
		game.slime.last_jump_traveled = 0.0
		var before: float = game.slime_remaining
		game._on_jump_landed(Slime.jump_distance_for(100.0), true, Vector2.LEFT)
		var cost: float = before - game.slime_remaining
		var want := 5.0 if level == 0 else 5.0 * 0.40
		_check(is_equal_approx(cost, want) and is_equal_approx(game.slime.splat_stun, 0.3 if level == 0 else 0.06),
			"STICKY %d: a full-power splat costs %.2f%% (want %.2f), stun %.2f s" % [level, cost, want, game.slime.splat_stun])
		await _stop(game)


# ---------------------------------------------------------------- MAGNET

## Puts the slime at `at` for a few frames and says whether `coin` was collected.
func _try_coin(game: Node2D, coin: Coin, at: Vector2) -> bool:
	game.slime.position = at
	game.last_slime_pos = at
	game.slime.velocity = Vector2.ZERO
	await _physics_frames(2)
	var taken: bool = not coin in game.coins
	game.slime.position = MazeGenerator.cell_center(game.maze.start, 16)
	game.last_slime_pos = game.slime.position
	await _physics_frames(1)
	return taken


func _magnet() -> void:
	_state({magnet = 3})
	var game := await _spawn(2)
	await _physics_frames(3)
	_check(game.coin_reach == 34.0, "MAGNET 3: coin reach 34 px")
	# A coin at a dead end: its open side, and a walled side.
	var coin: Coin = null
	var open_dir := Vector2i.ZERO
	var wall_dir := Vector2i.ZERO
	for c: Coin in game.coins:
		var tile: Vector2i = c.cell * 2 + Vector2i.ONE
		var o := Vector2i.ZERO
		var w := Vector2i.ZERO
		for d: Vector2i in MazeGenerator.DIRS:
			var beyond: Vector2i = tile + d * 2
			if not game.is_wall_tile(tile + d):
				o = d
			elif beyond.x > 0 and beyond.y > 0 and beyond.x < game.maze.size.x - 1 and beyond.y < game.maze.size.y - 1:
				w = d
		if o != Vector2i.ZERO and w != Vector2i.ZERO:
			coin = c
			open_dir = o
			wall_dir = w
			break
	_check(coin != null, "found a dead-end coin with an open and a walled side")
	if coin == null:
		await _stop(game)
		return
	var c_pos := coin.position
	_check(not await _try_coin(game, coin, c_pos + Vector2(open_dir) * 30.0), "...still in the fog: the magnet leaves it")
	game._paint_goo(c_pos, game.TRAIL_RADIUS)  # its floor revealed
	_check(not await _try_coin(game, coin, c_pos + Vector2(wall_dir) * 32.0), "...behind a wall (no line of sight): left alone")
	_check(await _try_coin(game, coin, c_pos + Vector2(open_dir) * 32.0), "...from the next cell in plain sight (32 px): it flies in")
	await _stop(game)
	# Without the magnet, 24 px is too far even in plain sight.
	_state({})
	game = await _spawn(2)
	await _physics_frames(3)
	var c2: Coin = game.coins[0]
	var tile2: Vector2i = c2.cell * 2 + Vector2i.ONE
	var d2 := Vector2i.ZERO
	for d: Vector2i in MazeGenerator.DIRS:
		if not game.is_wall_tile(tile2 + d):
			d2 = d
	game._paint_goo(c2.position, game.TRAIL_RADIUS)
	_check(game.coin_reach == Coin.REACH and not await _try_coin(game, c2, c2.position + Vector2(d2) * 24.0)
		and await _try_coin(game, c2, c2.position + Vector2(d2) * 8.0), "no MAGNET: 24 px away it stays, touching it (8 px) takes it")
	await _stop(game)
	# A solid slime (jelly off): a magnetized coin flies into the slime instead of bursting in place.
	_state({magnet = 3})
	var was_jelly: bool = progress.jelly
	progress.jelly = false
	game = await _spawn(2)
	await _physics_frames(3)
	var c3: Coin = game.coins[0]
	var tile3: Vector2i = c3.cell * 2 + Vector2i.ONE
	var d3 := Vector2i.ZERO
	for d: Vector2i in MazeGenerator.DIRS:
		if not game.is_wall_tile(tile3 + d):
			d3 = d
	game._paint_goo(c3.position, game.TRAIL_RADIUS)
	var from3 := c3.position
	var slime_at := c3.position + Vector2(d3) * 30.0
	game.slime.position = slime_at
	game.last_slime_pos = slime_at
	game.slime.velocity = Vector2.ZERO
	await _physics_frames(2)
	_check(not c3 in game.coins and is_instance_valid(c3) and c3.position.distance_to(slime_at) < from3.distance_to(slime_at),
		"jelly off: the magnetized coin is flying toward the slime (%.0f px left of 30)" % c3.position.distance_to(slime_at))
	await _physics_frames(20)
	_check(not is_instance_valid(c3) or c3.is_queued_for_deletion(), "...and is gone once it arrives")
	progress.jelly = was_jelly
	await _stop(game)


# ---------------------------------------------------------------- GOO NOSE

func _nose() -> void:
	_state({nose = 3})
	var game := await _spawn(3)
	await _physics_frames(2)
	var gaps := []
	for i in 200:
		gaps.append(game._glimmer_gap())
	_check(game.glimmer_rate == 2.3 and game.glimmer_reach == 300.0 and gaps.min() >= 180.0 / 2.3 - 0.1 and gaps.max() <= 360.0 / 2.3 + 0.1,
		"GOO NOSE 3: glimmers every 78-157 px (x2.3 as often), reaching 300 px (%.0f-%.0f)" % [gaps.min(), gaps.max()])
	await _stop(game)
	# Visible glimmers per minute at levels 0-3: a field of hidden coins round the slime, 60 s of
	# gliding at the slime's speed (~70 px/s); every glimmer must sit inside the camera view.
	var counts := []
	for lvl in 4:
		_state({nose = lvl} if lvl > 0 else {})
		game = await _spawn(3)
		await _physics_frames(2)
		counts.append(_visible_glimmers(game))
		await _stop(game)
	var ratios := []
	for c in counts:
		ratios.append(snappedf(float(c) / counts[0], 0.01))
	print("GOO NOSE visible glimmers per minute at levels 0-3: %s  ratios %s" % [counts, ratios])
	_check(counts[0] > 0 and counts[1] > counts[0] and counts[2] > counts[1] and counts[3] > counts[2]
		and ratios[1] >= 1.25 and ratios[2] >= 1.55 and ratios[3] >= 2.0,
		"each GOO NOSE level shows clearly more glimmers on screen (ratios %s)" % [ratios])


## Counts the glimmers per minute (all on screen, asserted) over 20 min of travel across a fake coin field.
func _visible_glimmers(game: Node2D) -> float:
	var field: Array[Coin] = []
	for ix in range(-12, 13):
		for iy in range(-8, 9):
			var coin := Coin.new()
			coin.position = game.slime.position + Vector2(ix * 25, iy * 25)
			game.add_child(coin)
			field.append(coin)
	game.coins = field
	var count := 0
	var all_visible := true
	var rect: Rect2 = Rect2(game.camera.get_screen_center_position() - Vector2(168, 98), Vector2(336, 196))
	for i in 72000:  # 20 minutes at 60 fps, 70 px/s (counts are divided by 20)
		game._count_glimmer_travel(game._glimmer_from + Vector2(70.0 / 60.0, 0))
	for node in game.get_children():
		if node.is_in_group("glimmer"):
			count += 1
			all_visible = all_visible and rect.grow(80).has_point(node.position)  # the slime moved no real distance
			node.remove_from_group("glimmer")
			node.queue_free()
	_check(all_visible, "...every glimmer sits in the visible view")
	return count / 20.0


# ---------------------------------------------------------------- SECOND WIND

func _wind() -> void:
	_state({wind = 2}, 1)
	var game := await _spawn(1)
	await _physics_frames(2)
	_check(game.wind_state == "ready" and game.hud.wind_pod.visible, "SECOND WIND 2 on a cleared level: ready, the HUD shows WIND")
	game.slime_remaining = 0.0
	await _physics_frames(2)
	_check(not game.finished and game.wind_state == "refilling" and game.wind_fired, "the meter hits 0: it fires instead of drying up")
	await _physics_frames(40)
	_check(not game.finished and game.wind_state == "used" and absf(game.slime_remaining - 25.0) < 0.6 and game.hud.wind_pod.visible,
		"...refilled to 25%% over 0.4 s (%.1f%%), the tag dims" % game.slime_remaining)
	game.slime_remaining = 0.0
	await _physics_frames(2)
	_check(game.finished and not game.won, "once per run: the next empty meter dries up")
	await _stop(game)
	# A fixed amount: slime spent during the 0.4 s refill is not topped up again (25% added - 10 spent).
	_state({wind = 2}, 1)
	game = await _spawn(1)
	await _physics_frames(2)
	game.slime_remaining = 0.0
	await _physics_frames(2)
	await _physics_frames(5)
	var spent := 5.0
	game.slime_remaining -= spent
	await _physics_frames(40)
	_check(game.wind_state == "used" and absf(game.slime_remaining - (25.0 - spent)) < 0.8,
		"SECOND WIND adds a fixed 25%%, slime spent while refilling stays spent (%.1f%%, want %.1f)" % [game.slime_remaining, 25.0 - spent])
	await _stop(game)
	# A level's first clear: no SECOND WIND.
	_state({wind = 3}, 0)
	game = await _spawn(1)
	await _physics_frames(2)
	_check(game.wind_state == "" and not game.hud.wind_pod.visible, "not on a level's first clear (no tag either)")
	game.slime_remaining = 0.0
	await _physics_frames(2)
	_check(game.finished and not game.won, "...it just dries up")
	await _stop(game)


func _wind_random() -> void:
	_state({wind = 1})
	progress.upgrades = {slime = 1}
	progress.coins_found = {0: ["a"]}
	progress.random_attempts.clear()
	var game := await _spawn(0, 777001)
	await _physics_frames(3)
	var before: int = game.payout().tickets
	_check(game.wind_state == "ready" and before == 10, "randomizer attempt 1 offers 10 with SECOND WIND ready")
	game.slime_remaining = 0.0
	await _physics_frames(3)
	await process_frame
	_check(game.pay_attempt() == 2 and game.payout().tickets == 8 and "TIX AVAILABLE 8" in game.hud.attempt_label.text,
		"firing it costs one attempt step: a win now pays 8, the pod says so (%s)" % game.hud.attempt_label.text.replace("\n", " / "))
	await _stop(game)


# ---------------------------------------------------------------- hard mode, par

func _hard_and_par() -> void:
	var full := {wind = 3, charge = 3, sticky = 3, magnet = 3, nose = 3}
	_state({})
	var game := await _spawn(4)
	var par: float = game.par_time
	await _stop(game)
	_state(full)
	game = await _spawn(4)
	_check(is_equal_approx(game.par_time, par) and game.workshop.size() == 5, "the whole workshop leaves par alone (%.2f s)" % par)
	await _stop(game)
	_state(full)
	progress.hard_mode = true
	game = await _spawn(4)
	await _physics_frames(2)
	_check(game.workshop.is_empty() and game.slime.charge_time == Slime.CHARGE_TIME and game.slime.splat_stun == Slime.SPLAT_STUN
		and game.splat_factor == 1.0 and game.coin_reach == Coin.REACH and game.glimmer_rate == 1.0 and game.wind_state == ""
		and not game.hud.wind_pod.visible, "hard mode: the whole workshop is off (no WIND tag)")
	await _stop(game)
	progress.hard_mode = false


