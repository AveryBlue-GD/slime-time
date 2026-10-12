extends SceneTree

## Hat checks: hats are won on the hat wheel and saved; a worn hat sits on the slime's
## head, pops off when it leaps, keeps its momentum and lands back on its head; after a splat it
## flies on, comes down and hops back on. Uses a throwaway save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hats.gd

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.levels_cleared = 10
	progress.selected_hat = Hats.NONE
	progress.hats_owned.clear()
	progress.hats_owned.append(Hats.LIST[0].id)
	_check(not progress.is_hat_unlocked(Hats.LIST[0].id), "while hats are 'coming soon' they can't be worn, even won ones")
	progress.hats_owned.clear()
	Hats.available = true  # the rest checks how they work once released

	# --- Won on the hat wheel, and saved
	var first: String = Hats.LIST[0].id
	_check(progress.is_hat_unlocked(Hats.NONE) and not progress.is_hat_unlocked(first), "no hat at first; hats are locked")
	progress.select_hat(first)
	_check(progress.selected_hat == Hats.NONE, "a locked hat can't be worn")
	progress.win_hat(first)
	_check(progress.selected_hat == first and not first in progress.hats_left(), "winning a hat puts it on and takes it off the wheel")
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.selected_hat == first and first in reloaded.hats_owned, "won hats and the one you wear are saved")
	reloaded.free()

	# --- On the head
	var game := await _spawn()
	_check(game.hat != null and game.hat.state == Hat.State.ON, "the slime wears its hat into the level")
	var spot := _straight(game, 4)
	_check(not spot.is_empty(), "found a straight corridor to jump along")
	var start := MazeGenerator.cell_center(spot.cell, 16)
	game.slime.position = start
	game.last_slime_pos = start
	await physics_frame
	await process_frame
	var head_gap: float = game.slime.position.y - game.hat.global_position.y
	_check(head_gap > 4.0 and head_gap < 12.0, "the hat sits on top of the slime (%.0f px above its center)" % head_gap)

	# --- A clean leap: off, along for the ride, back on
	game.slime.facing = Vector2(spot.dir)
	game.slime.launch(28.0)  # about 3 tiles, well short of the far wall
	var flew := false
	var rode_along := true
	var highest := 0.0
	for i in 30:
		await process_frame
		if game.hat.state == Hat.State.FLYING:
			flew = true
			highest = maxf(highest, game.hat.height)
			rode_along = rode_along and game.hat.ground.distance_to(game.slime.position) < 10.0
	_check(flew and highest > head_gap + 6.0, "the hat pops off on the leap (up to %.0f px high)" % highest)
	_check(rode_along, "...and keeps the slime's momentum, staying over it")
	for i in 30:
		await process_frame
	_check(game.hat.state == Hat.State.ON, "...and lands back on its head")
	game.free()

	# --- A splat: the hat flies on, comes down, hops back on
	game = await _spawn()
	var end := _dead_end(game, 3)
	var near := MazeGenerator.cell_center(end.cell, 16)
	game.slime.position = near
	game.last_slime_pos = near
	game.slime.facing = Vector2(end.dir)
	await physics_frame
	game.slime.launch(100.0)
	var overshoot := 0.0
	var back_on := false
	for i in 60 * 4:
		await process_frame
		if game.hat.state != Hat.State.ON:
			overshoot = maxf(overshoot, (game.hat.ground - game.slime.position).dot(Vector2(end.dir)))
		elif overshoot > 0.0 and i > 30:
			back_on = true
			break
	_check(overshoot > 3.0, "after a splat the hat keeps going past where the slime stopped (%.0f px)" % overshoot)
	_check(back_on, "...then comes back down onto the slime")
	game.free()

	progress.selected_hat = Hats.NONE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## A cell with `length` open cells ahead of it in a straight line.
func _straight(game: Node2D, length: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var cell := Vector2i(x, y)
				var ok := true
				for i in length:
					ok = ok and (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell)
					cell += dir
				if ok:
					return {cell = Vector2i(x, y), dir = dir}
	return {}


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
