extends "res://tests/suite_base.gd"

## Measures what a wall hit during a leap does, with the bouncy test off and on (Economy.BOUNCY_TEST,
## docs/spring-cleaning/bounce-test.md): per scenario the speed into the wall and right after it, the
## direction after, how long the slime is out of control (stun / squash), how far it moves after the
## contact, and what the leap cost. Prints a table; no pass / fail.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/bench_bounce.gd
## (`-- --trace=corridor` also prints every tick of the scenarios whose name starts so.)

var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.save_path = test_save
	progress.levels_cleared = 1
	var trace := ""  # `-- --trace=NAME` prints every tick of that scenario
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="):
			trace = arg.trim_prefix("--trace=")
	for mode in [0, 1]:
		Economy.bouncy_force = mode
		print("== bouncy %s ==" % ("ON" if mode else "OFF"))
		for scenario: Array in [["corridor diag 100", "corridor", 100.0], ["corridor diag 50", "corridor", 50.0],
				["corridor diag 0", "corridor", 0.0], ["corner (junction) diag 100", "junction", 100.0],
				["dead end inside corner 100", "corner", 100.0], ["dead end head-on 100", "dead_end", 100.0], ["dead end head-on 80", "dead_end", 80.0]]:
			var game := await _spawn_game()
			var m := await _measure(game, scenario[1], scenario[2], trace != "" and scenario[0].begins_with(trace))
			print("%-28s in %3.0f px/s | out %3.0f px/s at %4.0f deg | no control %.2f s | after contact %5.1f px (net %5.1f) | ahead %5.1f px | cost %.2f%% | hits %d" % [
				scenario[0], m.speed_in, m.speed_out, m.angle_out, m.lost, m.path_after, m.net_after, m.ahead, m.cost, m.hits])
			game.free()
	Economy.bouncy_force = -1
	quit(0)


func _measure(game: Node2D, kind: String, charge: float, trace: bool) -> Dictionary:
	var spot := _find(game, kind)
	var dir := Vector2(spot.dir)
	var aim := dir if kind == "dead_end" else (dir + dir.orthogonal()).normalized()
	var start := MazeGenerator.cell_center(spot.cell - (spot.dir * 3 if kind == "dead_end" else Vector2i.ZERO), 16)
	game.slime.position = start
	game.last_slime_pos = start
	game.slime.facing = aim
	var before: float = game.slime_remaining
	game.slime.launch(charge)
	var last := start
	var contact := Vector2.INF
	var contact_tick := -1
	var speed_in := 0.0
	var speed_out := 0.0
	var angle_out := 0.0
	var path_after := 0.0
	var control_tick := -1
	for tick in 240:
		await physics_frame
		var pos: Vector2 = game.slime.position
		var step := pos - last
		if trace:
			print("  t%03d state %d pos (%.1f, %.1f) step %.2f anim %s:%d y %.0f" % [tick, game.slime.state, pos.x, pos.y,
				step.length(), game.slime.sprite.animation, game.slime.sprite.frame, game.slime.sprite.position.y])
		var hit: bool = game.slime.state == Slime.State.STUNNED or game.slime.get("leap_bounces") != null and game.slime.leap_bounces > 0
		if contact_tick < 0 and hit:
			contact_tick = tick
			contact = pos
			speed_in = Slime.JUMP_SPEED
		elif contact_tick >= 0:
			path_after += step.length()
			if speed_out == 0.0 and step.length() > 0.01:
				speed_out = step.length() * 60.0
				angle_out = rad_to_deg(step.angle_to(aim))
			if control_tick < 0 and game.slime.state == Slime.State.GLIDE:
				control_tick = tick
		last = pos
	var lost := (control_tick - contact_tick) / 60.0 if contact_tick >= 0 and control_tick >= 0 else 0.0
	return {speed_in = speed_in, speed_out = speed_out, angle_out = absf(angle_out), lost = lost,
		path_after = path_after, net_after = (game.slime.position - contact).length() if contact_tick >= 0 else 0.0,
		ahead = (game.slime.position - start).dot(dir), cost = before - game.slime_remaining,
		hits = game.slime.ricochets + (game.slime.leap_bounces if game.slime.get("leap_bounces") != null else 0)}


## corridor: a cell with 4 straight open cells ahead (dir) and walls on both sides (a 1-tile corridor);
## junction: a cell open ahead and to the orthogonal side (the diagonal hits the corner between them);
## corner: a dead end closed ahead and to the side; dead_end: a cell closed ahead with 3 open cells
## behind it (the head-on leap starts 3 cells back).
func _find(game: Node2D, kind: String) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			var open := MazeGenerator.open_neighbors(game.maze, cell)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var side := Vector2i(Vector2(dir).orthogonal())
				match kind:
					"corridor":
						var ok := not (cell + side) in open and not (cell - side) in open
						var at := cell
						for i in 4:
							ok = ok and (at + dir) in MazeGenerator.open_neighbors(game.maze, at)
							at += dir
						if ok:
							return {cell = cell, dir = dir}
					"junction":
						if (cell + dir) in open and (cell + side) in open:
							return {cell = cell, dir = dir}
					"corner":  # a dead end whose orthogonal side is closed too (the diagonal hits the inside corner)
						if not (cell + dir) in open and not (cell + side) in open and (cell - dir) in open:
							return {cell = cell, dir = dir}
					"dead_end":
						var ok := not (cell + dir) in open
						var back := cell
						for i in 3:
							ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
							back -= dir
						if ok:
							return {cell = cell, dir = dir}
	return {cell = Vector2i.ZERO, dir = Vector2i.RIGHT}
