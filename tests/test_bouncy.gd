extends "res://tests/suite_base.gd"

## The bouncy leap test (Economy.BOUNCY_TEST, docs/spring-cleaning/bounce-test.md): off by default; on,
## a leap reflects off walls (Slime.bounce_dir) and flies on: a diagonal leap in a corridor taps the
## wall once and carries on along it, an inside corner gives one quick double bounce, nothing gets
## stuck, jitters or tunnels, the cost equals today's splat, it is deterministic, and the camera kick
## respects Reduce Motion.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_bouncy.gd

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.levels_cleared = 3
	_check(not Economy.BOUNCY_TEST and not Economy.bouncy_on(), "the bouncy test is off by default")
	var progress_script: GDScript = load("res://scripts/progress.gd")
	_check(progress_script.game_args(PackedStringArray(["--bouncy"]), false).is_empty()
		and progress_script.game_args(PackedStringArray(["--bouncy"]), true) == PackedStringArray(["--bouncy"]),
		"--bouncy is a debug flag (a release build ignores it)")
	_math()
	await _off_still_splats()
	Economy.bouncy_force = 1
	await _corridor()
	await _inside_corner()
	await _deterministic()
	await _camera_kick()
	await _fuzz()
	Economy.bouncy_force = -1
	_result()
	quit(1 if failures else 0)


func _math() -> void:
	var diag := Vector2(1, 1).normalized()
	var out := Slime.bounce_dir(diag, Vector2.UP)  # down-right into a floor below
	var want := Vector2(diag.x * Economy.BOUNCE_TANGENT_KEEP, -diag.y * Economy.BOUNCE_RESTITUTION)
	_check(out.is_equal_approx(want), "45 deg: the part into the wall comes back x RESTITUTION, the part along it keeps TANGENT_KEEP (%s)" % out)
	_check(out.length() < 1.0 and out.x > 0.0 and out.y < 0.0, "...it keeps going along the wall, off it, and loses energy (%.3f)" % out.length())
	var head_on := Slime.bounce_dir(Vector2.RIGHT, Vector2.LEFT)
	_check(head_on.is_equal_approx(Vector2.LEFT * Economy.BOUNCE_HEAD_ON_RESTITUTION), "head-on: straight back x HEAD_ON_RESTITUTION (%s)" % head_on)
	var near := Slime.bounce_dir(Vector2.from_angle(deg_to_rad(15.0)), Vector2.LEFT)
	_check(near.x < 0.0 and absf(near.x) < Economy.BOUNCE_HEAD_ON_RESTITUTION + 0.01, "within ~20 deg of head-on counts as head-on (%s)" % near)
	var mirrored := Slime.bounce_dir(Vector2(-1, 1).normalized(), Vector2.UP)
	_check(is_equal_approx(mirrored.x, -out.x) and is_equal_approx(mirrored.y, out.y), "the rule is symmetric")


## Off (the default): a diagonal leap into a corridor wall still splats (stun, knockback).
func _off_still_splats() -> void:
	var game := await _spawn_game()
	var spot := _find(game, "corridor")
	var run := await _leap(game, spot, (Vector2(spot.dir) + Vector2(spot.dir).orthogonal()).normalized(), 100.0, 30)
	_check(run.stunned and game.slime.leap_bounces == 0, "flag off: a diagonal wall hit is the old splat")
	game.free()


## A full diagonal leap in a 1-tile corridor: one bounce, then along the corridor; same cost as the splat.
func _corridor() -> void:
	var off_cost := 0.0
	for mode in [0, 1]:
		Economy.bouncy_force = mode
		var game := await _spawn_game()
		var spot := _find(game, "corridor")
		var dir := Vector2(spot.dir)
		var run := await _leap(game, spot, (dir + dir.orthogonal()).normalized(), 100.0, 120)
		if mode == 0:
			off_cost = run.cost
		else:
			_check(run.bounces == 1 and not run.stunned, "a diagonal leap in a corridor bounces once, no stun (%d)" % run.bounces)
			_check(run.ahead > 48.0, "...and carries on along the corridor (%.0f px)" % run.ahead)
			_check(run.landed and game.slime.state == Slime.State.GLIDE, "...then lands and can glide")
			_check(absf(run.cost - off_cost) < 0.01, "it costs what the splat costs (%.2f%% vs %.2f%%)" % [run.cost, off_cost])
			_check(run.max_step < 8.0 and run.walls == 0, "no jumps or overlaps with walls (max %.1f px a tick)" % run.max_step)
		game.free()
	Economy.bouncy_force = 1


## A diagonal leap into a dead end's inside corner: one squash, a quick second bounce, out.
func _inside_corner() -> void:
	var game := await _spawn_game()
	var spot := _find(game, "corner")
	var dir := Vector2(spot.dir)
	var run := await _leap(game, spot, (dir + dir.orthogonal()).normalized(), 100.0, 150)
	_check(run.bounces == 2, "an inside corner: two bounces (%d)" % run.bounces)
	_check(run.held <= roundi(Economy.BOUNCE_SQUASH_TIME * 60.0) + 1, "...one squash hold, not one per wall (%d ticks held)" % run.held)
	_check(run.landed and run.ahead < -16.0, "...and it comes back out of the dead end (%.0f px)" % run.ahead)
	game.free()


## The same leap twice gives the same path, tick for tick.
func _deterministic() -> void:
	var paths := []
	for i in 2:
		var game := await _spawn_game()
		var spot := _find(game, "corner")
		var dir := Vector2(spot.dir)
		paths.append((await _leap(game, spot, (dir + dir.orthogonal()).normalized(), 80.0, 90)).path)
		game.free()
	_check(paths[0] == paths[1] and paths[0].size() == 90, "deterministic: the same leap, the same path")


## The camera kicks in the bounce direction; with Reduce Motion it stays still.
func _camera_kick() -> void:
	for reduce in [false, true]:
		progress.reduce_motion = reduce
		var game := await _spawn_game()
		var spot := _find(game, "corridor")
		var dir := Vector2(spot.dir)
		var new_dirs := []
		game.slime.leap_bounced.connect(func(_c: Vector2, _n: Vector2, _i: float, d: Vector2) -> void: new_dirs.append(d))
		var bursts := game.find_children("*", "CPUParticles2D", false, false).size()
		_place(game, spot.cell)
		game.slime.facing = (dir + dir.orthogonal()).normalized()
		game.slime.launch(100.0)
		var still := true
		var kicked := false
		for i in 12:
			await physics_frame
			if not new_dirs.is_empty():
				kicked = kicked or game.kick.dot(new_dirs[0]) > 0.0
				still = still and game.camera.offset == Vector2.ZERO
		if reduce:
			_check(still, "Reduce Motion: no camera kick or shake on a bounce")
		else:
			_check(kicked, "the camera kicks in the bounce direction")
			_check(game.find_children("*", "CPUParticles2D", false, false).size() > bursts, "goo sprays off the contact point")
		game.free()
	progress.reduce_motion = false


## Many leaps from random spots (off-centre, partway into passages), in all 8 directions, at random power, on three levels: every one
## lands, never inside a wall, never moves more than a tick's flight, never bounces more than
## BOUNCE_MAX times or twice within 10 ticks except the corner double bounce.
func _fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var leaps := 0
	var bad := ""
	for level in [1, 2, 3]:
		var game := await _spawn_game({level = level})
		game.dev_no_drain = true  # 40 leaps would dry it up
		for n in 60:
			var cell := Vector2i(rng.randi_range(0, game.maze.cells.x - 1), rng.randi_range(0, game.maze.cells.y - 1))
			if Vector2(cell).distance_to(Vector2(game.maze.goal)) < 5.0:
				continue  # a leap onto the chalice would end the level
			var aim := Vector2.from_angle(PI / 4.0 * rng.randi_range(0, 7))
			var open := MazeGenerator.open_neighbors(game.maze, cell)
			var offset := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))  # off-centre: corners hit at odd angles
			if not open.is_empty() and rng.randf() < 0.5:  # or partway into a passage
				offset += Vector2(open[rng.randi_range(0, open.size() - 1)] - cell) * rng.randf_range(0.0, 16.0)
			var run := await _leap(game, {cell = cell, dir = Vector2i.RIGHT, offset = offset}, aim, [0.0, 50.0, 100.0][rng.randi_range(0, 2)], 200, true)
			leaps += 1
			if not run.landed:
				bad = "level %d cell %s aim %s never landed" % [level, cell, aim]
			elif run.walls > 0:
				bad = "level %d cell %s aim %s overlapped a wall" % [level, cell, aim]
			elif run.max_step > 8.0:
				bad = "level %d cell %s aim %s jumped %.1f px in a tick" % [level, cell, aim, run.max_step]
			elif run.bounces > Economy.BOUNCE_MAX or run.rattle > 2:
				bad = "level %d cell %s aim %s: %d bounces, %d within 10 ticks" % [level, cell, aim, run.bounces, run.rattle]
			if bad != "":
				break
		game.free()
		if bad != "":
			break
	_check(bad == "", "%d random leaps: all land, no wall overlap, no tunnelling, no ping-pong %s" % [leaps, bad])


func _place(game: Node2D, cell: Vector2i, offset := Vector2.ZERO) -> void:
	var start := MazeGenerator.cell_center(cell, 16) + offset
	game.slime.position = start
	game.slime.velocity = Vector2.ZERO
	game.slime.state = Slime.State.GLIDE
	game.slime.knocked_back = false
	game.last_slime_pos = start
	game.slime.reset_physics_interpolation()


## Leaps from `spot.cell` toward `aim` and watches `ticks` physics frames (stops early once landed
## when `until_landed`).
func _leap(game: Node2D, spot: Dictionary, aim: Vector2, charge: float, ticks: int, until_landed := false) -> Dictionary:
	_place(game, spot.cell, spot.get("offset", Vector2.ZERO))
	var start: Vector2 = game.slime.position
	var before: float = game.slime_remaining
	var bounce_ticks: Array[int] = []
	var tick := [0]
	var on_bounce := func(_c: Vector2, _n: Vector2, _i: float, _d: Vector2) -> void: bounce_ticks.append(tick[0])
	game.slime.leap_bounced.connect(on_bounce)
	game.slime.facing = aim
	game.slime.launch(charge)
	var run := {landed = false, stunned = false, max_step = 0.0, walls = 0, held = 0, path = []}
	var last := start
	for i in ticks:
		tick[0] = i
		await physics_frame
		var pos: Vector2 = game.slime.position
		run.path.append(pos)
		run.max_step = maxf(run.max_step, pos.distance_to(last))
		if game.is_wall_tile(Vector2i((pos / 16.0).floor())):
			run.walls += 1
		if game.slime.state == Slime.State.AIRBORNE and pos == last and i > 0:
			run.held += 1
		run.stunned = run.stunned or game.slime.state == Slime.State.STUNNED
		last = pos
		if game.slime.state == Slime.State.GLIDE and not run.landed:
			run.landed = true
			if until_landed:
				break
	game.slime.leap_bounced.disconnect(on_bounce)
	var rattle := 0
	for i in bounce_ticks.size():
		var close := 0
		for t in bounce_ticks:
			if t >= bounce_ticks[i] and t < bounce_ticks[i] + 10:
				close += 1
		rattle = maxi(rattle, close)
	run.bounces = bounce_ticks.size()
	run.rattle = rattle
	run.ahead = (game.slime.position - start).dot(Vector2(spot.dir))
	run.cost = before - game.slime_remaining
	return run


## corridor: a cell with 4 open cells straight ahead and walls on both sides; corner: a dead end
## closed ahead and to the side, open behind.
func _find(game: Node2D, kind: String) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			var open := MazeGenerator.open_neighbors(game.maze, cell)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var side := Vector2i(Vector2(dir).orthogonal())
				if kind == "corridor":
					var ok := not (cell + side) in open and not (cell - side) in open
					var at := cell
					for i in 4:
						ok = ok and (at + dir) in MazeGenerator.open_neighbors(game.maze, at)
						at += dir
					if ok:
						return {cell = cell, dir = dir}
				elif not (cell + dir) in open and not (cell + side) in open and (cell - dir) in open:
					return {cell = cell, dir = dir}
	return {cell = Vector2i.ZERO, dir = Vector2i.RIGHT}
