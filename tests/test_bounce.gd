extends SceneTree

## Splat knockback checks: hitting a wall throws the slime back the way it came, by about
## BOUNCE_FACTOR of the jump distance it had left, so hard leaps bounce further than soft hops;
## the knockback slide costs no slime but still smears goo.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_bounce.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://test_save.cfg"
	progress.levels_cleared = 1

	var game := await _spawn()
	var spot := _dead_end(game, 3)
	_check(not spot.is_empty(), "found a dead end with an open corridor behind it")
	var dir: Vector2 = Vector2(spot.dir)

	# Full-power leap into the dead-end wall from its last cell.
	var hard := await _splat(game, spot, 100.0)
	_check(hard.back_dot < -0.95, "the slime is thrown back the way it came")
	_check(absf(hard.bounce - hard.expected) < 6.0,
		"it slides back ~%.0f%% of its leftover jump (%.0f px for %.0f px left)" % [Slime.BOUNCE_FACTOR * 100.0, hard.bounce, hard.leftover])
	_check(absf(hard.used - game.last_jump_cost) < 0.01, "the knockback slide costs no extra slime")
	_check(game.fog_alpha_at(hard.contact - dir * hard.bounce / 2.0) < 1.0, "the slide still smears goo (the area it slid over is revealed)")
	_check(not game.slime.knocked_back, "the knockback ends once the slime stops")
	game.free()

	# A soft hop into the same wall bounces much less.
	game = await _spawn()
	var soft := await _splat(game, spot, 0.0)
	_check(soft.bounce < hard.bounce / 3.0, "a gentle hop barely bounces (%.1f px vs %.0f px)" % [soft.bounce, hard.bounce])
	game.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## Puts the slime in the dead end's last cell, leaps at the wall with `charge`, waits for the
## knockback to settle, and measures what happened.
func _splat(game: Node2D, spot: Dictionary, charge: float) -> Dictionary:
	var start := MazeGenerator.cell_center(spot.cell, 16)
	game.slime.position = start
	game.last_slime_pos = start
	var dir := Vector2(spot.dir)
	game.slime.facing = dir
	var before: float = game.slime_remaining
	game.slime.launch(charge)
	for i in 120:
		await physics_frame
		if game.slime.state == Slime.State.STUNNED:
			break
	var contact: Vector2 = game.slime.position
	var leftover: float = Slime.jump_distance_for(charge) - game.slime.last_jump_traveled
	for i in 120:
		await physics_frame
	var offset: Vector2 = game.slime.position - contact
	return {
		contact = contact,
		bounce = offset.length(),
		back_dot = offset.normalized().dot(dir) if offset.length() > 0.5 else -1.0,
		leftover = leftover,
		expected = leftover * Slime.BOUNCE_FACTOR,
		used = before - game.slime_remaining,
	}


## A cell whose way forward (dir) is a wall while the cells behind it run straight for `behind`.
func _dead_end(game: Node2D, behind: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			var cell := Vector2i(x, y)
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					continue
				var back := cell
				var ok := true
				for i in behind:
					ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
					back -= dir
				if ok:
					return {cell = cell, dir = dir}
	return {}


func _spawn() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	return game


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
