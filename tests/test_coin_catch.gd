extends "res://tests/suite_base.gd"

## The coin catch test (Economy.COIN_CATCH_TEST, docs/spring-cleaning/coin-catch-test.md): off by
## default (today's pickup, untouched); on, a touched coin is tossed up, caught by a cosmetic hop and
## dissolves inside the slime before the HUD counter pops. Checks: the credit at touch (save, coin key,
## HUD's final value) is today's; the lifecycle toss -> catch -> dissolve -> counter pop; the slime's
## body, meter and timer never notice; several coins at once; a catch in mid-leap; pause, dry-up, win
## and restart mid-show; Reduce Motion; jelly and solid; whole-pixel placement.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_coin_catch.gd

const LEVEL := 2
var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.hard_mode = false
	progress.levels_cleared = 10
	progress.jelly = false
	progress.reduce_motion = false
	_check(Economy.COIN_CATCH_TEST and Economy.coin_catch_on(), "the coin catch is on by default")
	var progress_script: GDScript = load("res://scripts/progress.gd")
	_check(progress_script.game_args(PackedStringArray(["--coincatch"]), false).is_empty()
		and progress_script.game_args(PackedStringArray(["--coincatch"]), true) == PackedStringArray(["--coincatch"]),
		"--coincatch is a debug flag (a release build ignores it)")
	_check(root.get_node("Sfx").has_sound("coin_fizz"), "the soft coin fizz sound loads")
	await _flag_off()
	await _lifecycle(false)
	await _lifecycle(true)
	await _body_untouched()
	await _many()
	await _pause_and_endings()
	await _restart()
	await _reduce_motion()
	Economy.coincatch_force = -1
	_result()
	quit(1 if failures else 0)


func _fresh() -> void:
	progress.coins_found = {}
	progress.upgrades = {}


## Puts the slime right on `coin` (standing still) and runs one tick, so it is picked up.
func _touch(game: Node2D, coin: Coin) -> void:
	game.slime.position = coin.position
	game.slime.velocity = Vector2.ZERO
	game.slime.reset_physics_interpolation()
	await physics_frame


## Flag off: today's pickup exactly (counted on the HUD at once, no catch, no hop).
func _flag_off() -> void:
	_fresh()
	Economy.coincatch_force = 0
	var game := await _spawn_game({level = LEVEL})
	var coin: Coin = game.coins[0]
	var cell := coin.cell
	await _touch(game, coin)
	await physics_frame
	_check(progress.has_coin(LEVEL, cell) and game.hud.coin_label.text == "1"
		and game.coin_catches.is_empty() and game.slime.catch_t < 0.0 and game.slime.sprite.position.y == 0.0,
		"flag off: today's pickup (counted at once, no catch, no hop)")
	game.free()


## The whole show on a solid (or jelly) slime, tick by tick.
func _lifecycle(jelly: bool) -> void:
	_fresh()
	progress.jelly = jelly
	Economy.coincatch_force = 1
	var tag := "jelly" if jelly else "solid"
	var game := await _spawn_game({level = LEVEL})
	var coin: Coin = game.coins[0]
	var cell := coin.cell
	await _touch(game, coin)
	_check(progress.has_coin(LEVEL, cell) and not coin in game.coins, "%s: the coin is collected at touch" % tag)
	var reloaded: Node = load("res://scripts/progress.gd").new()
	reloaded.save_path = test_save
	reloaded.load_progress()
	_check(reloaded.has_coin(LEVEL, cell) and (reloaded.coins_found[LEVEL] as Array) == [progress.coin_key(cell)],
		"%s: ...and saved at once under today's coin key" % tag)
	reloaded.free()
	_check(game.coin_catches.size() == 1 and game.hud.coin_label.text == "0"
		and game.hud.coins_left_label.text == "%d LEFT" % Levels.COINS[LEVEL - 1],
		"%s: the HUD holds the count while the show runs" % tag)
	var catch: CoinCatch = game.coin_catches[0]
	var top := 0.0
	var lift := 0.0
	var caught_at := -1
	var done_at := -1
	var whole := true
	var behind := false
	var shrank := false
	var ticks := 0
	var popped := false
	while ticks < 150:
		ticks += 1
		await physics_frame
		if not is_instance_valid(catch):
			done_at = ticks
			popped = game.hud.coin_label.get_theme_color("font_color") == game.hud.GOLD
			break
		var rel: Vector2 = catch.coin.position
		top = minf(top, rel.y)
		lift = maxf(lift, -game.slime.sprite.position.y)
		whole = whole and rel == rel.round() and game.slime.sprite.position == game.slime.sprite.position.round()
		if catch.phase == CoinCatch.Phase.DISSOLVE and caught_at < 0:
			caught_at = ticks
		if catch.phase == CoinCatch.Phase.DISSOLVE:
			behind = behind or catch.coin.self_modulate != Color.WHITE
			shrank = shrank or catch.coin.scale.x < 0.5
		if done_at < 0 and game.hud.coin_label.text != "0" and is_instance_valid(catch):
			break  # counted early
	var catch_ticks := roundi(Slime.catch_moment() * 60)
	_check(top <= -Economy.COIN_CATCH_TOSS_HEIGHT + 3.0 and top >= -Economy.COIN_CATCH_TOSS_HEIGHT - 3.0,
		"%s: tossed up %.0f px over the slime" % [tag, -top])
	_check(lift == Economy.COIN_CATCH_HOP_PX, "%s: the slime hops %.0f px to catch it" % [tag, lift])
	_check(absi(caught_at - catch_ticks) <= 1, "%s: caught at the hop's catch moment (tick %d)" % [tag, caught_at])
	var dissolve := done_at - caught_at
	_check(absf(dissolve / 60.0 - Economy.COIN_CATCH_DISSOLVE_TIME) <= 0.05,
		"%s: dissolves for %.2f s" % [tag, dissolve / 60.0])
	_check(shrank and (behind if jelly else not behind), "%s: shrinks away %s" % [tag, "inside the body (tinted by the goo)" if jelly else "into the top of the body"])
	_check(game.hud.coin_label.text == "1" and popped
		and game.hud.coins_left_label.text == "%d LEFT" % (Levels.COINS[LEVEL - 1] - 1),
		"%s: then the counter pops up to 1" % tag)
	_check(whole, "%s: coin and sprite sit on whole pixels every tick" % tag)
	await _physics_frames(20)
	_check(game.slime.catch_t < 0.0 and game.slime.sprite.position.y == 0.0 and game.slime.get_child_count() == _base_children(game),
		"%s: nothing left behind (hop over, sprite back, no nodes)" % tag)
	game.free()
	progress.jelly = false


func _base_children(game: Node2D) -> int:
	var n := 0
	for child in game.slime.get_children():
		n += 0 if child is CoinCatch else 1
	return n


## The same leap through a coin with the flag off and on: the body goes exactly the same way, the
## meter and the timer read the same; the catch happens in the air (the hop adds onto the arc).
func _body_untouched() -> void:
	var runs := {}
	for mode in [0, 1]:
		_fresh()
		Economy.coincatch_force = mode
		var game := await _spawn_game({level = LEVEL})
		var coin: Coin = game.coins[0]
		var cell := coin.cell
		var open: Array = MazeGenerator.open_neighbors(game.maze, coin.cell)
		var from: Vector2i = open[0]
		game.slime.position = MazeGenerator.cell_center(from, 16)
		game.slime.velocity = Vector2.ZERO
		game.last_slime_pos = game.slime.position
		game.slime.reset_physics_interpolation()
		await physics_frame
		game.slime.facing = Vector2(cell - from)
		game.slime.launch(25.0)
		var trace: Array[Vector2] = []
		var air_catch := false
		for i in 70:
			await physics_frame
			trace.append(game.slime.position)
			if mode == 1 and game.slime.state == Slime.State.AIRBORNE and not game.coin_catches.is_empty():
				air_catch = true
		runs[mode] = {trace = trace, meter = game.slime_remaining, time = game.run_time, flown = game.slime.last_jump_traveled,
			got = progress.has_coin(LEVEL, cell), air = air_catch, state = game.slime.state}
		game.free()
	_check(runs[0].got and runs[1].got, "a leap over a coin collects it, flag off and on")
	_check(runs[1].air, "on: the catch starts in mid-leap")
	_check(runs[0].trace == runs[1].trace and runs[0].flown == runs[1].flown and runs[0].state == runs[1].state,
		"the slime's body moves exactly the same with the catch on (%d ticks)" % runs[0].trace.size())
	_check(runs[0].meter == runs[1].meter and runs[0].time == runs[1].time,
		"...and the meter (%.3f) and run timer (%.2f s) are the same" % [runs[1].meter, runs[1].time])


## Four coins in four ticks: at most COIN_CATCH_MAX shows at once, each counted once, the counter
## ending on the right total.
func _many() -> void:
	_fresh()
	Economy.coincatch_force = 1
	var game := await _spawn_game({level = 3})
	var picked: Array[Coin] = []
	for i in mini(4, game.coins.size()):
		picked.append(game.coins[i])
	var most := 0
	for coin in picked:
		await _touch(game, coin)
		most = maxi(most, game.coin_catches.size())
	_check(picked.size() == 4 and most == Economy.COIN_CATCH_MAX, "4 coins in 4 ticks: %d shows at most at once" % most)
	_check(game.hud.coin_label.text == "1", "...the oldest finished at once (counter %s)" % game.hud.coin_label.text)
	await _wait_seconds(Slime.catch_hop_length() + Economy.COIN_CATCH_DISSOLVE_TIME + 0.2)
	_check(game.coin_catches.is_empty() and game.hud.coin_label.text == "4" and progress.coins_found_in(3) == 4
		and (progress.coins_found[3] as Array).size() == 4,
		"...all four end up counted exactly once (HUD %s, save %d)" % [game.hud.coin_label.text, progress.coins_found_in(3)])
	game.free()


## Pause freezes a show; a dry-up and a win end it cleanly with the full count.
func _pause_and_endings() -> void:
	_fresh()
	Economy.coincatch_force = 1
	var game := await _spawn_game({level = LEVEL})
	await _touch(game, game.coins[0])
	await _physics_frames(10)
	var catch: CoinCatch = game.coin_catches[0]
	var t0 := catch.t
	var lift0: float = game.slime.sprite.position.y
	paused = true
	await _physics_frames(60)
	_check(catch.t == t0 and game.slime.sprite.position.y == lift0, "pause freezes the show (%.2f s in)" % t0)
	paused = false
	await _physics_frames(5)
	_check(catch.t > t0, "...and it carries on after")
	game._dry_up()
	await physics_frame
	_check(game.coin_catches.is_empty() and game.hud.coin_label.text == "1" and game.slime.sprite.position.y == 0.0
		and game.slime.catch_t < 0.0, "a dry-up mid-show ends it: counted, sprite back down")
	game.free()

	_fresh()
	game = await _spawn_game({level = LEVEL})
	await _touch(game, game.coins[0])
	await _touch(game, game.coins[1])
	await _physics_frames(15)
	game.slime.play_celebrate()
	game._finish(true, "TEST WIN")
	await physics_frame
	_check(game.coin_catches.is_empty() and game.hud.coin_label.text == "2" and game.slime.sprite.position.y == 0.0
		and _base_children(game) == game.slime.get_child_count(), "a win mid-show ends both: counter 2, nothing left over")
	_check(progress.coins_found_in(LEVEL) == 2, "...and the save holds exactly 2")
	game.free()


## A restart (the scene reloads) mid-show never loses or double-counts the coin.
func _restart() -> void:
	_fresh()
	Economy.coincatch_force = 1
	var game := await _spawn_game({level = LEVEL})
	var coin: Coin = game.coins[0]
	var cell := coin.cell
	await _touch(game, coin)
	await _physics_frames(30)
	game.free()  # what reload_current_scene does to it
	game = await _spawn_game({level = LEVEL})
	var cells: Array = game.coins.map(func(c: Coin) -> Vector2i: return c.cell)
	_check(not cell in cells and game.coins.size() == Levels.COINS[LEVEL - 1] - 1 and game.hud.coin_label.text == "1"
		and progress.coins_found_in(LEVEL) == 1, "a restart mid-show: the coin stays collected, counted once")
	game.free()


## Reduce Motion: no toss, no hop: the coin fades out in the slime, slower.
func _reduce_motion() -> void:
	for jelly in [false, true]:
		_fresh()
		progress.reduce_motion = true
		progress.jelly = jelly
		Economy.coincatch_force = 1
		var game := await _spawn_game({level = LEVEL})
		await _touch(game, game.coins[0])
		var catch: CoinCatch = game.coin_catches[0]
		var still := true
		var ticks := 0
		var first := Vector2.INF
		while is_instance_valid(catch) and ticks < 200:
			if first == Vector2.INF:
				first = catch.coin.position
			still = still and game.slime.sprite.position.y == 0.0 and game.slime.catch_t < 0.0 and catch.coin.position == first
			ticks += 1
			await physics_frame
		_check(still and absf(ticks / 60.0 - Economy.COIN_CATCH_CALM_TIME) <= 0.05 and game.hud.coin_label.text == "1",
			"Reduce Motion (%s): no toss or hop, a still %.2f s fade, then counted" % ["jelly" if jelly else "solid", ticks / 60.0])
		game.free()
	progress.reduce_motion = false
	progress.jelly = false
