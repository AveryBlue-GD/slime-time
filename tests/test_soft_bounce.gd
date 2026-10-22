extends "res://tests/suite_base.gd"

## The soft bounce test (Economy.SOFT_BOUNCE_TEST, docs/spring-cleaning/soft-bounce-test.md): off by
## default (today's splat, untouched); on, a glancing wall hit squashes briefly and slides on along the
## wall, braking to a stop within SOFT_BOUNCE_SLIDE_MIN..MAX px, and a head-on hit is a shorter splat.
## Checks: angle -> outcome, stun lengths, slide distances, the same cost as today, no rattle or jitter
## in corridors and corners (random leaps too), determinism, and Reduce Motion / no camera kick.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_soft_bounce.gd

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.levels_cleared = 3
	Economy.diagonal_leap_force = 1  # the angled hits below need diagonal leaps (off in the game for now)
	_check(not Economy.SOFT_BOUNCE_TEST and not Economy.soft_bounce_on(), "the soft bounce test is off by default")
	var progress_script: GDScript = load("res://scripts/progress.gd")
	_check(progress_script.game_args(PackedStringArray(["--softbounce"]), false).is_empty()
		and progress_script.game_args(PackedStringArray(["--softbounce"]), true) == PackedStringArray(["--softbounce"]),
		"--softbounce is a debug flag (a release build ignores it)")
	await _angles()
	await _head_on()
	await _cost_unchanged()
	await _corner()
	await _deterministic()
	await _reduce_motion()
	await _fuzz()
	Economy.softbounce_force = -1
	Economy.diagonal_leap_force = -1
	_result()
	quit(1 if failures else 0)


## Leaps in a corridor toward its side wall at `deg` degrees off the corridor's direction (90 = square
## into the side wall). Up to ~20 deg off head-on is a splat, beyond that a glance that slides on
## along the corridor.
func _angles() -> void:
	for deg: float in [30.0, 45.0, 60.0, 65.0, 75.0, 90.0]:
		var off_head_on: float = 90.0 - deg
		var glance: bool = off_head_on > 20.5
		for mode in [0, 1]:
			Economy.softbounce_force = mode
			var game := await _spawn_game()
			var spot := _find(game, "corridor")
			var run := await _leap(game, spot, _aim(spot, deg), 100.0, 150)
			var tag := "%d deg off head-on, flag %s" % [off_head_on, "on" if mode else "off"]
			if mode == 0:
				_check(run.stun_ticks >= 17 and run.stun_ticks <= 19 and not game.slime.last_hit_glancing,
					"%s: today's splat, %d ticks stunned" % [tag, run.stun_ticks])
			elif glance:
				_check(game.slime.last_hit_glancing, "%s: glances off" % tag)
				_check(run.stun_ticks >= 5 and run.stun_ticks <= 7, "...stunned %d ticks (~%.2f s)" % [run.stun_ticks, Economy.SOFT_BOUNCE_GLANCE_STUN])
				_check(run.held >= 2 and run.held <= 4, "...a quick squash on the wall (%d ticks still)" % run.held)
				_check(run.along >= Economy.SOFT_BOUNCE_SLIDE_MIN - 2.0 and run.along <= Economy.SOFT_BOUNCE_SLIDE_MAX + 1.0,
					"...slides on %.1f px along the wall (%d-%d)" % [run.along, Economy.SOFT_BOUNCE_SLIDE_MIN, Economy.SOFT_BOUNCE_SLIDE_MAX])
				_check(run.reversals == 0 and run.ricochets == 0 and run.perp_drift < 0.5,
					"...smoothly: no rattle (%d reversals, %d ricochets, %.2f px sideways)" % [run.reversals, run.ricochets, run.perp_drift])
				_check(run.first_speed > 0.0 and run.first_speed <= Slime.JUMP_SPEED * Economy.SOFT_BOUNCE_SPEED_SHARE + 1.0,
					"...at most %d%% of the leap's speed (%.0f px/s)" % [roundi(Economy.SOFT_BOUNCE_SPEED_SHARE * 100), run.first_speed])
			else:
				_check(not game.slime.last_hit_glancing, "%s: a splat" % tag)
			game.free()


## Straight into a dead end: a splat with a shorter stun and a short knockback straight back.
func _head_on() -> void:
	var back := {}
	for mode in [0, 1]:
		Economy.softbounce_force = mode
		var game := await _spawn_game()
		var spot := _find(game, "dead_end")
		var start_cell: Vector2i = spot.cell - spot.dir * 3
		var run := await _leap(game, {cell = start_cell, dir = spot.dir}, Vector2(spot.dir), 100.0, 150)
		back[mode] = run.knock
		if mode == 1:
			_check(not game.slime.last_hit_glancing and run.stun_ticks >= 10 and run.stun_ticks <= 12,
				"head-on: a splat, stunned %d ticks (~%.2f s)" % [run.stun_ticks, Economy.SOFT_BOUNCE_HEAD_STUN])
			_check(run.knock > 2.0 and run.knock <= Economy.SOFT_BOUNCE_HEAD_KNOCK_MAX + 1.0 and run.knock < back[0],
				"...knocked back %.1f px (today %.1f)" % [run.knock, back[0]])
			_check(run.reversals == 0 and run.perp_drift < 0.5, "...straight back, no rattle")
		game.free()


## Same leaps, flag off vs on: the leap cost and the splat penalty are exactly today's, and the
## slides are free.
func _cost_unchanged() -> void:
	for kind in ["corridor_45", "corridor_60", "head_on", "corridor_45_half"]:
		var costs := []
		var drains := []
		var splats := []
		for mode in [0, 1]:
			Economy.softbounce_force = mode
			var game := await _spawn_game()
			var run: Dictionary
			if kind == "head_on":
				var spot := _find(game, "dead_end")
				run = await _leap(game, {cell = spot.cell - spot.dir * 3, dir = spot.dir}, Vector2(spot.dir), 100.0, 150)
			else:
				var spot := _find(game, "corridor")
				run = await _leap(game, spot, _aim(spot, 60.0 if kind == "corridor_60" else 45.0), 50.0 if kind.ends_with("half") else 100.0, 150)
			costs.append(game.last_jump_cost)
			drains.append(run.cost)
			splats.append(game.splats)
			game.free()
		_check(is_equal_approx(costs[0], costs[1]) and splats[0] == splats[1] and splats[1] == 1,
			"%s: the same leap cost + splat penalty (%.3f%% vs %.3f%%)" % [kind, costs[0], costs[1]])
		_check(absf(drains[0] - drains[1]) < 0.02 and absf(drains[1] - costs[1]) < 0.02,
			"...and the slide after it is free (drained %.3f%% vs %.3f%%)" % [drains[0], drains[1]])


## A diagonal leap into a dead end's inside corner: one touch, the slide stops at the corner (no
## ping-pong), and the slime can glide straight back out.
func _corner() -> void:
	Economy.softbounce_force = 1
	var game := await _spawn_game()
	var spot := _find(game, "corner")
	var run := await _leap(game, spot, _aim(spot, 45.0), 100.0, 90)
	_check(run.landed and run.ricochets == 0 and run.reversals == 0 and run.walls == 0,
		"an inside corner: it stops there, no rattle, inside the maze (%d reversals)" % run.reversals)
	var at: Vector2 = game.slime.position
	var out: Vector2i = MazeGenerator.open_neighbors(game.maze, spot.cell)[0] - spot.cell
	var action: String = {Vector2i.RIGHT: "move_right", Vector2i.LEFT: "move_left", Vector2i.DOWN: "move_down", Vector2i.UP: "move_up"}[out]
	Input.action_press(action)
	await _physics_frames(30)
	Input.action_release(action)
	_check(game.slime.position.distance_to(at) > 12.0, "...and glides out of the corner (%.1f px)" % game.slime.position.distance_to(at))
	game.free()


## The same leap twice gives the same path, tick for tick.
func _deterministic() -> void:
	Economy.softbounce_force = 1
	var paths := []
	for i in 2:
		var game := await _spawn_game()
		var spot := _find(game, "corridor")
		paths.append((await _leap(game, spot, _aim(spot, 45.0), 80.0, 90)).path)
		game.free()
	_check(paths[0] == paths[1] and paths[0].size() == 90, "deterministic: the same leap, the same path")


## A glancing hit never moves the camera; a head-on one shakes as today, and with Reduce Motion the
## camera stays still and there is no hit-stop.
func _reduce_motion() -> void:
	Economy.softbounce_force = 1
	for reduce in [false, true]:
		progress.reduce_motion = reduce
		for kind in ["glance", "head_on"]:
			var game := await _spawn_game()
			var bursts := game.find_children("*", "CPUParticles2D", false, false).size()
			var spot := _find(game, "corridor" if kind == "glance" else "dead_end")
			if kind == "glance":
				_place(game, spot.cell)
				game.slime.facing = _aim(spot, 45.0)
			else:
				_place(game, spot.cell - spot.dir * 3)
				game.slime.facing = Vector2(spot.dir)
			game.slime.launch(100.0)
			var moved := false
			var held := false
			var sprayed := false
			for i in 40:
				await physics_frame
				moved = moved or game.camera.offset != Vector2.ZERO
				held = held or game.slime._hit_stop_left > 0.0
				sprayed = sprayed or game.find_children("*", "CPUParticles2D", false, false).size() > bursts
			var tag := "%s%s" % [kind, " (Reduce Motion)" if reduce else ""]
			if kind == "glance":
				_check(not moved and not held, "%s: no camera kick, no hit-stop" % tag)
				_check(sprayed, "...goo droplets at the contact")
			elif reduce:
				_check(not moved and not held, "%s: the camera stays still, no hit-stop" % tag)
			else:
				_check(moved, "%s: today's shake" % tag)
			game.free()
	progress.reduce_motion = false


## Many leaps from random spots (off-centre, partway into passages), in all 8 directions, at random
## power, on three levels: each one comes to rest, never inside a wall, never moves more than a tick's
## flight, never ricochets, and its slide never reverses (no rattle, no sticking).
func _fuzz() -> void:
	Economy.softbounce_force = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var leaps := 0
	var hits := 0
	var glances := 0
	var bad := ""
	for level in [1, 2, 3]:
		var game := await _spawn_game({level = level})
		game.dev_no_drain = true
		for n in 60:
			var cell := Vector2i(rng.randi_range(0, game.maze.cells.x - 1), rng.randi_range(0, game.maze.cells.y - 1))
			if Vector2(cell).distance_to(Vector2(game.maze.goal)) < 5.0:
				continue  # a leap onto the chalice would end the level
			var aim := Vector2.from_angle(PI / 4.0 * rng.randi_range(0, 7))
			var open := MazeGenerator.open_neighbors(game.maze, cell)
			var offset := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if not open.is_empty() and rng.randf() < 0.5:
				offset += Vector2(open[rng.randi_range(0, open.size() - 1)] - cell) * rng.randf_range(0.0, 16.0)
			var run := await _leap(game, {cell = cell, dir = Vector2i.RIGHT, offset = offset}, aim, [0.0, 50.0, 100.0][rng.randi_range(0, 2)], 200, true)
			leaps += 1
			hits += 1 if run.hit else 0
			glances += 1 if run.hit and game.slime.last_hit_glancing else 0
			if not run.landed:
				bad = "level %d cell %s aim %s never came to rest" % [level, cell, aim]
			elif run.walls > 0:
				bad = "level %d cell %s aim %s overlapped a wall" % [level, cell, aim]
			elif run.max_step > 8.0:  # a tick's flight (3.7 px) + the corner slip (Slime.CORNER_LEEWAY)
				bad = "level %d cell %s aim %s jumped %.1f px in a tick" % [level, cell, aim, run.max_step]
			elif run.ricochets > 0 or run.reversals > 0:
				bad = "level %d cell %s aim %s: %d ricochets, %d reversals" % [level, cell, aim, run.ricochets, run.reversals]
			elif run.hit and run.slide > Economy.SOFT_BOUNCE_SLIDE_MAX + 1.0:
				bad = "level %d cell %s aim %s slid %.1f px" % [level, cell, aim, run.slide]
			if bad != "":
				break
		game.free()
		if bad != "":
			break
	_check(bad == "" and glances > 5 and hits > glances, "%d random leaps (%d wall hits, %d glancing): all come to rest, no overlap, no tunnelling, no rattle %s" % [leaps, hits, glances, bad])


## Unit aim `deg` degrees from the corridor's direction toward its side (90 = square into the side wall).
func _aim(spot: Dictionary, deg: float) -> Vector2:
	var dir := Vector2(spot.dir)
	return (dir * cos(deg_to_rad(deg)) + dir.orthogonal() * sin(deg_to_rad(deg))).normalized()


func _place(game: Node2D, cell: Vector2i, offset := Vector2.ZERO) -> void:
	var start := MazeGenerator.cell_center(cell, 16) + offset
	game.slime.position = start
	game.slime.velocity = Vector2.ZERO
	game.slime.state = Slime.State.GLIDE
	game.slime.knocked_back = false
	game.last_slime_pos = start
	game.slime.reset_physics_interpolation()


## Leaps from `spot.cell` toward `aim` and watches `ticks` physics frames (stops early once at rest
## when `until_rest`). From the wall hit on: ticks stunned and held still, the slide's length (`slide`),
## its part along spot.dir (`along`) and straight back (`knock`), its sideways drift, reversals of
## its direction (rattle) and the first moving tick's speed.
func _leap(game: Node2D, spot: Dictionary, aim: Vector2, charge: float, ticks: int, until_rest := false) -> Dictionary:
	_place(game, spot.cell, spot.get("offset", Vector2.ZERO))
	var start: Vector2 = game.slime.position
	var before: float = game.slime_remaining
	game.slime.facing = aim
	game.slime.launch(charge)
	var dir := Vector2(spot.dir)
	var run := {landed = false, hit = false, stun_ticks = 0, held = 0, max_step = 0.0, walls = 0, path = [],
		reversals = 0, perp_drift = 0.0, first_speed = 0.0, slide = 0.0, along = 0.0, knock = 0.0, ricochets = 0}
	var last := start
	var hit_at := Vector2.ZERO
	var last_delta := Vector2.ZERO
	for i in ticks:
		await physics_frame
		var slime: Slime = game.slime
		var pos: Vector2 = slime.position
		var delta := pos - last
		run.path.append(pos)
		run.max_step = maxf(run.max_step, delta.length())
		if game.is_wall_tile(Vector2i((pos / 16.0).floor())):
			run.walls += 1
		var hit_tick := false
		if slime.state == Slime.State.STUNNED:
			if not run.hit:
				run.hit = true
				hit_tick = true  # this tick's move is the flight up to the wall
				hit_at = pos
			run.stun_ticks += 1
		if run.hit and not hit_tick:
			if delta.length() < 0.001 and slime.state == Slime.State.STUNNED:
				run.held += 1
			elif delta.length() >= 0.001:
				if run.first_speed == 0.0:
					run.first_speed = delta.length() * 60.0
				if last_delta != Vector2.ZERO and delta.dot(last_delta) < 0.0:
					run.reversals += 1
				last_delta = delta
			run.perp_drift = maxf(run.perp_drift, absf((pos - hit_at).dot(last_delta.normalized().orthogonal())) if last_delta != Vector2.ZERO else 0.0)
		last = pos
		if slime.state == Slime.State.GLIDE and not slime.knocked_back and slime.velocity.length() < Slime.KNOCKBACK_END_SPEED:
			run.landed = true
			if until_rest:
				break
	run.ricochets = game.slime.ricochets
	run.slide = game.slime.position.distance_to(hit_at) if run.hit else 0.0
	run.along = (game.slime.position - hit_at).dot(dir) if run.hit else 0.0
	run.knock = -run.along
	run.cost = before - game.slime_remaining
	return run


## corridor: a cell with 4 open cells straight ahead and walls on both sides; dead_end: closed ahead,
## 3 open cells straight behind; corner: closed ahead and to the side, open behind.
func _find(game: Node2D, kind: String) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			var open := MazeGenerator.open_neighbors(game.maze, cell)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var side := Vector2i(Vector2(dir).orthogonal())
				var ok := true
				if kind == "corridor":
					ok = not (cell + side) in open and not (cell - side) in open
					var at := cell
					for i in 4:
						ok = ok and (at + dir) in MazeGenerator.open_neighbors(game.maze, at)
						at += dir
				elif kind == "dead_end":
					ok = not (cell + dir) in open
					var back := cell
					for i in 3:
						ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
						back -= dir
				else:
					ok = not (cell + dir) in open and not (cell + side) in open and (cell - dir) in open
				if ok:
					return {cell = cell, dir = dir}
	return {cell = Vector2i.ZERO, dir = Vector2i.RIGHT}
