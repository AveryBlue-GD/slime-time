extends "res://tests/suite_base.gd"

## BM-01 LURKERS (Economy.LURKERS_TEST): spawn rules (never in story / hard story / training / demo / RELAXED / CALM DARK /
## Descent, 1 seed in 3, seeded placement), each hunter's target rule on a small hand-made maze, dormancy, contact
## (15% of the meter, a knockback, invulnerability, never kills), stun by SLIME SPLAT and by a leap landing, the x1.25 pay,
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
	Economy.lurkers_force = 1
	var hits := 0
	for s in 600:
		if Lurkers.seed_has_lurkers(1000 + s * 7):
			hits += 1
	_check(hits > 140 and hits < 260, "about 1 seed in 3 has lurkers (%d of 600)" % hits)
	_check(Lurkers.seed_has_lurkers(4242) == Lurkers.seed_has_lurkers(4242), "the same seed always answers the same")
	_check(Lurkers.allowed(true, false, false, false, false, false, false, false), "a plain random maze may have them")
	_check(not Lurkers.allowed(false, false, false, false, false, false, false, false), "never in a story level")
	_check(not Lurkers.allowed(false, true, false, false, false, false, false, false), "never in a hard story level")
	_check(not Lurkers.allowed(true, false, true, false, false, false, false, false), "never in Descent")
	_check(not Lurkers.allowed(true, false, false, true, false, false, false, false), "never in training / the tutorial")
	_check(not Lurkers.allowed(true, false, false, false, true, false, false, false), "never in the demo")
	_check(not Lurkers.allowed(true, false, false, false, false, true, false, false), "never in a RELAXED run")
	_check(not Lurkers.allowed(true, false, false, false, false, false, true, false), "never with CALM DARK on")
	_check(not Lurkers.allowed(true, false, false, false, false, false, false, true), "not during the ability tutorial")
	Economy.lurkers_force = 2
	_check(Lurkers.allowed(true, false, false, false, false, false, false, true) and Lurkers.seed_has_lurkers(1),
		"--lurkers forces them into every random maze (even over the ability tutorial)")
	_check(not Lurkers.allowed(true, false, false, false, true, false, false, false), "--lurkers still never in the demo")
	Economy.lurkers_force = 0
	_check(not Lurkers.allowed(true, false, false, false, false, false, false, false), "flag off: not allowed anywhere")
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

	# ---- CALM DARK / RELAXED switch them off in a real run, flag off too
	progress.calm_dark = true
	game = await _spawn_random(4321)
	_check(game.lurkers == null, "CALM DARK: no lurkers")
	await _drop(game)
	progress.calm_dark = false
	progress.relaxed = true
	game = await _spawn_random(4321)
	_check(game.lurkers == null, "RELAXED: no lurkers")
	await _drop(game)
	progress.relaxed = false
	Economy.lurkers_force = 0
	game = await _spawn_random(4321)
	_check(game.lurkers == null, "flag off: no lurkers")
	_check(is_equal_approx(game.pay_factor(), float(progress.random_length_factor(game.random_seed, game.seed_level, game.hard_mode))), "flag off: pay unchanged")
	await _drop(game)
	Economy.lurkers_force = 2
	game = await _spawn_game({level = 1})
	_check(game.lurkers == null, "a story level never has lurkers")
	game.queue_free()
	await physics_frame
	Economy.lurkers_force = 0
	_result()
	quit(0 if failures == 0 else 1)
