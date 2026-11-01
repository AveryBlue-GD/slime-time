extends "res://tests/suite_base.gd"

## Phase 4 checks: the sprite sheet has every animation with enough frames, each game state
## shows the right animation, and lit areas fade back toward darkness in steps.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_phase4.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")



func _initialize() -> void:
	var manifest: Dictionary = preload("res://assets/sprites/slime_sheet.json").data.anims
	var glide_frames := 0
	var jump_frames := 0
	for anim_name: String in manifest:
		var count := int(manifest[anim_name].frames)
		if anim_name.begins_with("glide_") or anim_name == "idle":
			glide_frames += count
		elif anim_name.get_slice("_", 0) in ["charge", "launch", "air", "land", "splat"] or anim_name == "recover":
			jump_frames += count
	_check(glide_frames >= 16, "%d gliding/idle frames (8 directions)" % glide_frames)
	_check(jump_frames >= 20, "%d jumping frames (charge, launch, air, land, splat, recover)" % jump_frames)
	for anim_name in ["dry", "celebrate", "splat_n", "splat_e", "splat_s", "splat_w", "glide_ne", "air_sw"]:
		_check(manifest.has(anim_name), "has animation '%s'" % anim_name)

	_check_unreachable_path()

	var game := await _spawn_game()
	var slime: Slime = game.slime
	var open_dir := StartDirs.open_dir(game.maze, game.maze.start)
	var action := StartDirs.action(open_dir)
	var glide_anim: String = "glide_" + StartDirs.ANIMS[open_dir]
	_check(slime.sprite.animation == "idle", "standing still shows idle")
	Input.action_press(action)
	await _wait_seconds(0.3)
	_check(slime.sprite.animation == glide_anim and slime.sprite.is_playing(),
		"gliding shows %s (got %s)" % [glide_anim, slime.sprite.animation])
	Input.action_release(action)
	await _wait_seconds(1.0)
	_check(slime.sprite.animation == "idle", "stopping returns to idle")

	# Leap from a cell whose corridor ends in a wall one cell on (the start is random since v4).
	var hop := _short_hop(game.maze)
	slime.position = MazeGenerator.cell_center(hop.cell, 16)
	slime.velocity = Vector2.ZERO
	game.last_slime_pos = slime.position
	await _wait_seconds(0.2)
	Input.action_press("jump")
	await _wait_seconds(0.8)
	_check(slime.sprite.animation.begins_with("charge_") and slime.sprite.frame == 1,
		"charging shows charge frames that follow the meter (frame %d at %.0f%%)" % [slime.sprite.frame, slime.charge])
	slime.facing = Vector2(hop.dir)
	var splat_anim: String = "splat_" + StartDirs.ANIMS[hop.dir]
	Input.action_release("jump")
	await physics_frame
	await physics_frame
	_check(slime.sprite.animation == "launch_" + StartDirs.ANIMS[hop.dir], "jumping starts with launch frames (got %s)" % slime.sprite.animation)
	_check(slime.shadow.visible, "a shadow shows under the slime in the air")
	for i in 60:
		if slime.state == Slime.State.STUNNED:
			break
		await physics_frame
	_check(slime.sprite.animation == splat_anim, "hitting the wall ahead shows %s (got %s)" % [splat_anim, slime.sprite.animation])
	_check(not slime.shadow.visible, "shadow hides on landing")
	await _wait_seconds(0.35)
	_check(slime.sprite.animation == "recover", "after the stun the slime wobbles back (got %s)" % slime.sprite.animation)

	# Fading: the start is lit, then left alone it steps down toward darkness.
	var start: Vector2 = MazeGenerator.cell_center(hop.cell, 16)
	_check(game.fog_alpha_at(start) == 0.0, "the area around the slime is fully lit")
	var path := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var far := MazeGenerator.cell_center(path[path.size() / 2], 16)  # well away from the start and the chalice
	slime.position = far
	slime.velocity = Vector2.ZERO  # drop any leftover splat knockback
	game.last_slime_pos = far
	await _wait_seconds(2.0)
	var after_4: float = game.fog_alpha_at(start)
	await _wait_seconds(3.0)
	var after_9: float = game.fog_alpha_at(start)
	await _wait_seconds(5.0)
	var after_21: float = game.fog_alpha_at(start)
	_check(after_4 > 0.0 and after_9 > after_4 and after_21 > after_9 and after_21 < 1.0,
		"left behind, it darkens in layers: %.2f -> %.2f -> %.2f (never fully black)" % [after_4, after_9, after_21])
	_check(game.fog_alpha_at(far) == 1.0, "unexplored areas stay black even next to the slime")
	slime.position = start
	game.last_slime_pos = start
	await _wait_seconds(0.1)
	_check(game.fog_alpha_at(start) == 0.0, "coming back relights it")
	_check(game.fade_alpha(0.0) == 0.0 and game.fade_alpha(1000.0) == game.FADE_ALPHA[-1], "fade starts lit and ends at the memory level")
	game.free()

	game = await _spawn_game()
	game.slime_remaining = 0.2
	Input.action_press(action)
	await _wait_seconds(0.5)
	Input.action_release(action)
	_check(game.slime.sprite.animation == "dry", "running out of slime plays the dry-up")
	game.free()

	game = await _spawn_game()
	game.slime.position = game.goal.position
	await _wait_seconds(0.1)
	_check(game.slime.sprite.animation == "celebrate", "reaching the chalice plays the celebration")
	game.free()

	_result()
	quit(1 if failures else 0)


## The cell nearest the start with an open neighbor in some direction and a wall right after it.
func _short_hop(maze: Dictionary) -> Dictionary:
	var dist := MazeGenerator.distances_from(maze, maze.start)
	var best := {}
	for cell: Vector2i in dist:
		for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := cell + dir
			if next in MazeGenerator.open_neighbors(maze, cell) and not next + dir in MazeGenerator.open_neighbors(maze, next):
				if best.is_empty() or dist[cell] < best.d:
					best = {cell = cell, dir = dir, d = dist[cell]}
				break
	return best


## MazeGenerator.shortest_path to a cell walled in on every side (or outside the maze) is empty: no route,
## never a made-up one (QA phase 4, finding 4: the walk back read cell -1, the last cell).
func _check_unreachable_path() -> void:
	var maze := MazeGenerator.generate(Vector2i(6, 4), 11)
	var reachable := MazeGenerator.shortest_path(maze, maze.start, maze.goal)
	_check(reachable.size() >= 2 and reachable[0] == maze.start and reachable[-1] == maze.goal, "a route from start to goal (%d cells)" % reachable.size())
	for cell: Vector2i in [maze.goal, Vector2i(5, 3), Vector2i(0, 0), Vector2i(3, 1)]:
		var walled: Dictionary = maze.duplicate(true)
		var size_x: int = walled.size.x
		var tile := (cell.y * MazeGenerator.CELL_SPAN + 1) * size_x + cell.x * MazeGenerator.CELL_SPAN + 1
		for side in [tile + MazeGenerator.OPEN, tile - 1, tile + MazeGenerator.OPEN * size_x, tile - size_x]:
			walled.walls[side] = 1
		var from: Vector2i = walled.start if walled.start != cell else walled.goal
		var path := MazeGenerator.shortest_path(walled, from, cell)
		_check(path.is_empty(), "cell %s walled in: no path to it (%s)" % [cell, path])
	_check(MazeGenerator.shortest_path(maze, maze.start, Vector2i(6, 0)).is_empty()
		and MazeGenerator.shortest_path(maze, Vector2i(-1, 2), maze.goal).is_empty(), "a cell outside the maze: no path")
