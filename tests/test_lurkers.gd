extends "res://tests/suite_base.gd"

## BM-01 LURKERS (Economy.LURKERS_TEST): spawn rules (never in story / hard story / training / demo / the daily / weekly /
## Descent: forced in hard mode, the SETTINGS LURKERS toggle in normal random mazes, seeded placement), each hunter's target rule on a small hand-made maze, dormancy, contact
## (15% of the meter, 8% in hard mode, a knockback, invulnerability, never kills), stun by SLIME SPLAT and by a leap landing, the x1.25 pay,
## and flag off = no lurkers.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_lurkers.gd

const MAIN := preload("res://scenes/main.tscn")
var progress: Node


## A 3x3-cell maze (7x7 tiles) with the cells in `links` joined: pairs of cells.
func _maze(links: Array) -> Dictionary:
	var size := Vector2i(7, 7)
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	walls.fill(1)
	for y in 3:
		for x in 3:
			walls[(y * 2 + 1) * size.x + x * 2 + 1] = 0
	for pair in links:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var t: Vector2i = a * 2 + Vector2i.ONE + (b - a)
		walls[t.y * size.x + t.x] = 0
	return {cells = Vector2i(3, 3), size = size, walls = walls, start = Vector2i(0, 0), goal = Vector2i(2, 2)}


func _spawn_random(seed_value: int) -> Node2D:
	progress.mode = progress.MODE_RANDOM
	progress.random_seed = seed_value
	var game: Node2D = MAIN.instantiate()
	game.random_seed = seed_value
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _spawn_story(level: int) -> Node2D:
	progress.mode = progress.MODE_STORY
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _drop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await physics_frame


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	_check(Economy.LURKERS_TEST == true, "LURKERS_TEST is on in this test build")

	# ---- the rules
	Economy.lurkers_force = -1  # (the real rules: LURKERS_TEST on, no flag)
	# allowed(random, hard, shared, descent, training, demo, toggle, ability_tutorial)
	_check(Lurkers.allowed(false, true, false, false, false, false, false, false), "a hard story level always has them")
	_check(Lurkers.allowed(true, true, false, false, false, false, false, false), "a hard random maze always has them (toggle off)")
	_check(not Lurkers.allowed(false, false, false, false, false, false, true, false), "never in a normal story level")
	_check(not Lurkers.allowed(true, false, false, false, false, false, false, false), "a normal random maze: none with the toggle off")
	_check(Lurkers.allowed(true, false, false, false, false, false, true, false), "a normal random maze: lurkers with the toggle on")
	_check(not Lurkers.allowed(true, false, true, false, false, false, true, false), "never the daily / weekly (shared mazes), toggle on")
	_check(not Lurkers.allowed(true, true, true, false, false, false, true, false), "...and hard rules never apply to them")
	_check(not Lurkers.allowed(true, false, false, true, false, false, true, false) and not Lurkers.allowed(false, true, false, true, false, false, true, false), "never in Descent")
	_check(not Lurkers.allowed(true, false, false, false, true, false, true, false) and not Lurkers.allowed(false, true, false, false, true, false, true, false), "never in training / the tutorial")
	_check(not Lurkers.allowed(true, false, false, false, false, true, true, false) and not Lurkers.allowed(false, true, false, false, false, true, true, false), "never in the demo")
	_check(not Lurkers.allowed(true, false, false, false, false, false, true, true), "not during the ability tutorial")
	_check(Lurkers.story_count(1) == 2 and Lurkers.story_count(3) == 2 and Lurkers.story_count(4) == 3 and Lurkers.story_count(10) == 3, "hard story: 2 lurkers on levels 1-3, then 3")
	_check(Lurkers.story_seed(5) == Lurkers.story_seed(5) and Lurkers.story_seed(5) != Lurkers.story_seed(6), "a hard story level's lurkers are seeded by the level")
	Economy.lurkers_force = 2
	_check(Lurkers.allowed(true, false, false, false, false, false, false, true), "--lurkers forces them into every random maze (even over the ability tutorial)")
	_check(not Lurkers.allowed(true, false, false, false, false, true, false, false), "--lurkers still never in the demo")
	Economy.lurkers_force = 0
	_check(not Lurkers.allowed(true, true, false, false, false, false, true, false), "flag off: not allowed anywhere")
	Economy.lurkers_force = 2

	# ---- placement
	var maze := MazeGenerator.generate_random(Levels.random_config(777, false, 0), 777)
	var a := Lurkers.place(maze, 777)
	var b := Lurkers.place(maze, 777)
	_check(a == b and a.size() >= 2 and a.size() <= 3, "seeded placement: the same twice, 2-3 lurkers (%d)" % a.size())
	var distinct := true
	for i in a.size():
		distinct = distinct and a[i] != maze.start and a[i] != maze.goal
		for j in range(i + 1, a.size()):
			distinct = distinct and maxi(absi(a[i].x - a[j].x), absi(a[i].y - a[j].y)) >= Lurkers.SPACING_CELLS
	_check(distinct, "spread out, never on the start or the goal")

	# ---- target rules on a hand-made maze: a plus around the centre (1,1)
	var plus := _maze([[Vector2i(1, 1), Vector2i(0, 1)], [Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 1), Vector2i(1, 0)], [Vector2i(1, 1), Vector2i(1, 2)]])
	var c := Vector2i(1, 1)
	_check(Lurkers.pick_next(plus, c, Vector2i(0, 1), Vector2i(1, 2)) == Vector2i(1, 2), "greedy: steps toward a target straight ahead")
	_check(Lurkers.pick_next(plus, c, Vector2i(0, 1), Vector2i(2, 0)) == Vector2i(2, 1), "a tie goes right before up")
	_check(Lurkers.pick_next(plus, c, Vector2i(2, 1), Vector2i(2, 1)) != Vector2i(2, 1), "no backtracking, even toward the target")
	_check(Lurkers.pick_next(plus, Vector2i(2, 1), c, Vector2i(0, 1)) == c, "a dead end turns back")
	var game: Node2D = await _spawn_random(4321)
	var lk: Lurkers = game.lurkers
	_check(lk != null and lk.lurkers.size() >= 2, "a random maze with --lurkers has lurkers")
	game.hud.set_attempt(2, 5, false, true, true)
	_check("LURKERS X1.25" in game.hud.attempt_label.text, "IMP4-04: a normal maze with lurkers shows the x1.25 premium on the pod (%s)" % game.hud.attempt_label.text)
	game.hud.set_attempt(99, 5, false, true, true)
	await process_frame
	var pod_w: float = game.hud.attempt_label.get_minimum_size().x
	_check(pod_w <= 130.0, "IMP4-04: ATTEMPT 99 LURKERS X1.25 fits the pod's 128px budget (%.0f)" % pod_w)
	game.hud.set_attempt(2, 5, false, true, false)
	_check("LURKERS" in game.hud.attempt_label.text and not ("X1.25" in game.hud.attempt_label.text), "IMP4-04: hard shows no premium")
	game._refresh_attempt_pod()
	_check(not game.hard_mode and "X1.25" in game.hud.attempt_label.text, "IMP4-04: the game's own pod carries X1.25 on a normal random maze")
	var cell0 := Lurkers.cell_of(game.slime.position)
	_check(lk.target_for(Lurkers.Kind.CRAWLER) == cell0, "CRAWLER heads for the slime's cell")
	lk._trail.clear()
	for k in 4:
		lk._trail.append(Vector2i(k, 0))
	_check(lk.target_for(Lurkers.Kind.SNIFFER) == Vector2i(1, 0), "SNIFFER heads for the trail, 3 cells behind the newest")
	var bright := func(cell: Vector2i) -> float:
		return 0.9 if cell == Vector2i(cell0.x + 2, cell0.y) else (0.5 if cell == Vector2i(cell0.x, cell0.y + 1) else 0.0)
	_check(Lurkers.lantern_target(game.maze, cell0, bright) == Vector2i(cell0.x + 2, cell0.y), "LANTERN-EATER heads for the brightest lit cell")
	var none := func(_cell: Vector2i) -> float: return 0.0
	_check(Lurkers.lantern_target(game.maze, cell0, none) == cell0, "no lit cell near: it falls back to the slime")

	# ---- dormant until the light is near, then awake
	var l: Lurkers.Lurker = lk.lurkers[0]
	game.slime.position = l.pos + Vector2(Economy.LURKER_WAKE_DIST + 40.0, 0.0)
	lk.step(0.016)
	_check(not l.awake, "dormant while the slime is far")
	game.slime.position = l.pos + Vector2(Economy.LURKER_WAKE_DIST - 20.0, 0.0)
	lk.step(0.016)
	_check(l.awake, "it wakes once the slime is within ~6 tiles")

	# ---- contact
	l.wake_t = Lurkers.WAKE_TIME
	l.stun = 0.0
	lk.invuln = 0.0
	game.slime.position = l.pos + Vector2(2.0, 0.0)
	game.slime_remaining = 80.0
	var before: Vector2 = game.slime.position
	lk.step(0.016)
	_check(is_equal_approx(game.slime_remaining, 80.0 - Economy.LURKER_HIT), "contact costs %d%% of the meter" % int(Economy.LURKER_HIT))
	_check(is_equal_approx(lk.invuln, Economy.LURKER_INVULN) or is_equal_approx(lk.invuln, Economy.LURKER_INVULN_TOUCH), "contact gives invulnerability")
	for k in 8:
		lk.step(0.016)
	_check(before.distance_to(game.slime.position) > 8.0, "contact knocks the slime back")
	# BUG3-13: a touch player (a phone browser too, not only a native build) gets the longer grace
	var saved_hits: int = lk.hits
	var saved_invuln: float = lk.invuln
	var saved_remaining: float = game.slime_remaining
	var saved_pos: Vector2 = game.slime.position
	UIKit.touch_in_use = true
	lk._hit(l)
	var want_touch: float = Economy.LURKER_INVULN_TOUCH_HARD if game.hard_mode else Economy.LURKER_INVULN_TOUCH
	_check(is_equal_approx(lk.invuln, want_touch), "touch input: the longer contact grace (%.2f)" % lk.invuln)
	UIKit.touch_in_use = false
	lk._hit(l)
	_check(is_equal_approx(lk.invuln, Economy.LURKER_INVULN), "no touch: the desktop grace (%.2f)" % lk.invuln)
	lk.hits = saved_hits
	lk.invuln = saved_invuln
	lk._push_left = 0.0
	l.stun = 0.0
	game.slime_remaining = saved_remaining
	game.slime.position = saved_pos
	_check(is_equal_approx(game.slime_remaining, 80.0 - Economy.LURKER_HIT), "no second hit while invulnerable")

	# ---- near miss: slow-mo never touches Engine.time_scale, a pause cannot strand it
	l.near_active = true
	l.near_hit = false
	lk.invuln = 0.0
	lk._near_miss(l, Economy.LURKER_NEAR_MISS_DIST + 20.0)
	_check(lk.near_misses >= 1 and Engine.time_scale == 1.0, "a near miss leaves Engine.time_scale at 1.0")
	paused = true
	for k in 5:
		await process_frame
	_check(Engine.time_scale == 1.0, "paused during the slow-mo: Engine.time_scale stays 1.0")
	paused = false
	lk._slowmo_until_ms = Time.get_ticks_msec() - 1
	await process_frame
	_check(game.is_physics_processing() and Engine.time_scale == 1.0, "slow-mo over: the level runs at full speed again")
	# IMP4-05: the slow-mo's skipped frames are added back: run_time tracks the frames lived through (1 tick = 1/60 s here)
	l.near_active = true
	l.near_hit = false
	lk.invuln = 0.0
	lk._clock_wall = 0.0
	var rt0: float = game.run_time
	var misses0 := lk.near_misses
	lk._near_miss(l, Economy.LURKER_NEAR_MISS_DIST + 20.0)
	var frames := 0
	if lk._slowmo_until_ms >= 0:
		for k in 18:  # (headless frames run faster than the slow-mo's wall-clock window: expire it by hand)
			await physics_frame
			frames += 1
		lk._slowmo_until_ms = Time.get_ticks_msec() - 1
		for k in 3:
			await physics_frame
			frames += 1
		var gained: float = game.run_time - rt0
		_check(lk.near_misses == misses0 + 1 and absf(gained - frames / 60.0) <= 2.0 / 60.0 + 0.001,
			"IMP4-05: run_time after a near miss matches the frames lived through (%.3f vs %.3f s)" % [gained, frames / 60.0])
	else:
		_check(game.motion_scale() <= 0.0, "IMP4-05: no slow-mo only with Reduce Motion (no clock change)")
	game.slime_remaining = 10.0
	lk.invuln = 0.0
	l.stun = 0.0
	game.slime.position = l.pos
	lk.step(0.016)
	_check(game.slime_remaining >= 1.0 - 0.001, "a hit never takes the last 1%")
	game.slime_remaining = 0.5
	lk.invuln = 0.0
	l.stun = 0.0
	game.slime.position = l.pos
	lk.step(0.016)
	_check(is_equal_approx(game.slime_remaining, 0.5) and not game.finished, "a nearly dry slime is not killed by a lurker")
	game.slime_remaining = 80.0
	lk.invuln = 0.0
	l.stun = 2.0
	game.slime.position = l.pos
	lk.step(0.016)
	_check(is_equal_approx(game.slime_remaining, 80.0), "a stunned lurker does no harm")

	# ---- stun by SLIME SPLAT and by a leap landing
	l.stun = 0.0
	var tiles: Array[Vector2i] = [Vector2i((l.pos / 16.0).floor())]
	_check(lk.stun_tiles(tiles, Economy.LURKER_STUN_SPLAT) >= 1 and is_equal_approx(l.stun, 4.0), "SLIME SPLAT stuns lurkers in its blast for 4 s")
	l.stun = 0.0
	var landed := lk.on_landing(l.pos + Vector2(3.0, 0.0))
	_check(landed == 1 and is_equal_approx(l.stun, 2.0) and lk.bonks == 1, "a leap landing on a lurker bonks it (stun 2 s)")

	# ---- stealth: standing still makes them wander, not hunt
	l.stun = 0.0
	var wander := lk._decide(l, true)
	_check(wander in MazeGenerator.open_neighbors(game.maze, l.cell) or wander == l.cell, "stealth: a wander step on the grid")

	# ---- pay x1.25
	var plain := float(progress.random_length_factor(game.random_seed, game.seed_level, game.hard_mode))
	_check(is_equal_approx(game.pay_factor(), plain * Economy.LURKER_PAY), "a maze with lurkers pays x1.25")
	await _drop(game)

	# ---- the real rules in real runs
	Economy.lurkers_force = -1
	progress.hard_mode = false
	progress.lurkers_random = false
	game = await _spawn_random(4321)
	_check(game.lurkers == null, "LURKERS off: a normal random maze has none")
	await _drop(game)
	progress.lurkers_random = true
	game = await _spawn_random(4321)
	_check(game.lurkers != null and game.pay_factor() > 0.0, "LURKERS on: a normal random maze has them")
	await _drop(game)
	progress.relaxed = true
	game = await _spawn_random(4321)
	_check(game.lurkers != null, "LURKERS on, RELAXED: still there")
	await _drop(game)
	progress.relaxed = false
	progress.start_daily()
	game = await _spawn_random(progress.random_seed)
	_check(game.lurkers == null, "the daily has none, even with the toggle on")
	await _drop(game)
	progress.start_weekly()
	game = await _spawn_random(progress.random_seed)
	_check(game.lurkers == null, "the weekly has none, even with the toggle on")
	await _drop(game)
	progress.random_daily = false
	progress.random_weekly = false
	progress.lurkers_random = false
	progress.hard_mode = true
	game = await _spawn_random(4321)
	_check(game.lurkers != null and game.lurkers.lurkers.size() >= 2, "a hard random maze: forced (toggle off)")
	await _drop(game)
	progress.relaxed = true
	for lvl in [1, 4]:
		progress.start_story(lvl)
		progress.hard_mode = true
		game = await _spawn_story(lvl)
		var want := Lurkers.story_count(lvl)
		_check(game.lurkers != null and game.lurkers.lurkers.size() >= 2 and game.lurkers.lurkers.size() <= want and (lvl > 3 or game.lurkers.lurkers.size() == want), "hard level %d (RELAXED on): up to %d lurkers forced (%d; spacing may fit fewer)" % [lvl, want, game.lurkers.lurkers.size() if game.lurkers else -1])
		var first: Array = []
		for hl in game.lurkers.lurkers:
			first.append(hl.cell)
		if lvl == 1:
			var hk: Lurkers = game.lurkers
			var hl: Lurkers.Lurker = hk.lurkers[0]
			hl.awake = true
			hl.wake_t = Lurkers.WAKE_TIME
			hl.stun = 0.0
			hk.invuln = 0.0
			game.slime.position = hl.pos + Vector2(2.0, 0.0)
			game.slime_remaining = 80.0
			hk.step(0.016)
			_check(is_equal_approx(game.slime_remaining, 80.0 - Economy.LURKER_HIT_HARD), "hard contact costs 8%% (%s left)" % game.slime_remaining)
			game.slime_remaining = 5.0
			hk.invuln = 0.0
			hl.stun = 0.0
			game.slime.position = hl.pos
			hk.step(0.016)
			_check(game.slime_remaining >= 1.0 - 0.001 and not game.finished, "a hard hit still never takes the last 1%")
		await _drop(game)
		game = await _spawn_story(lvl)
		var again: Array = []
		for hl in game.lurkers.lurkers:
			again.append(hl.cell)
		_check(again == first, "hard level %d: the same cells every try (learnable)" % lvl)
		await _drop(game)
	progress.hard_mode = true
	progress.start_story(1)
	game = await _spawn_story(1)
	game.lurkers.hits = 2
	game.run_time = 40.0
	game._on_goal_body_entered(game.slime)
	await physics_frame
	_check("LURKER HITS 2" in game.hud.message.text and game.hud.message.text.count("
") <= 4, "IMP4-05: the hard result names the lurker hits, at most 5 lines (%s)" % game.hud.message.text.replace("
", " | "))
	await _drop(game)
	progress.relaxed = false
	progress.hard_mode = false
	progress.start_story(1)
	game = await _spawn_story(1)
	_check(game.lurkers == null, "a normal story level has none")
	await _drop(game)
	# the toggle's save and the CALM DARK migration
	progress.lurkers_random = true
	var q: Node = preload("res://scripts/progress.gd").new()
	var f := ConfigFile.new()
	f.set_value("settings", "lurkers", true)
	SaveFile.read(q, f)
	_check(q.lurkers_random, "the toggle loads from [settings] lurkers")
	f.set_value("settings", "calm_dark", true)
	SaveFile.read(q, f)
	_check(not q.lurkers_random, "migration: an old CALM DARK save starts with LURKERS off")
	var g := ConfigFile.new()
	g.set_value("settings", "calm_dark", false)
	SaveFile.read(q, g)
	_check(not q.lurkers_random, "...and a save without the toggle: off")
	q.free()
	progress.lurkers_random = false
	Economy.lurkers_force = 0
	game = await _spawn_random(4321)
	_check(game.lurkers == null, "flag off: no lurkers")
	_check(is_equal_approx(game.pay_factor(), float(progress.random_length_factor(game.random_seed, game.seed_level, game.hard_mode))), "flag off: pay unchanged")
	await _drop(game)
	Economy.lurkers_force = 2
	game = await _spawn_story(1)
	_check(game.lurkers == null, "a story level never has lurkers")
	game.queue_free()
	await physics_frame
	Economy.lurkers_force = 0
	_result()
	quit(0 if failures == 0 else 1)
