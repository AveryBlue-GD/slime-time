extends "res://tests/suite_base.gd"

## Hat checks: hats are won on the hat wheel and saved; a worn hat sits on the slime's
## head, pops off when it leaps, keeps its momentum and lands back on its head; after a splat it
## stays in line over the slime (a small jolt on), comes down and lands back on. Uses a throwaway save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hats.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.levels_cleared = 10
	progress.selected_hat = Hats.NONE
	progress.hats_owned.clear()
	progress.hats_owned.append(Hats.LIST[0].id)
	_check(Hats.available and progress.is_hat_unlocked(Hats.LIST[0].id), "hats are out for every player (upgrades v2 batch 2): a won hat can be worn")
	Hats.available = false  # the switch still works: off, even won hats can't be worn
	_check(not progress.is_hat_unlocked(Hats.LIST[0].id), "with Hats.available off they can't be worn, even won ones")
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
	reloaded.save_path = test_save
	reloaded.load_progress()
	_check(reloaded.selected_hat == first and first in reloaded.hats_owned, "won hats and the one you wear are saved")
	reloaded.free()

	# --- On the head
	var game := await _spawn_game()
	_check(game.hat != null and game.hat.state == Hat.State.ON, "the slime wears its hat into the level")
	await _physics_frames(5)
	_check(game.hat.region_rect.position.y == Hats.Width.NORMAL * Hats.FRAME.y, "at rest it's the normal-width hat")
	Input.action_press("jump")
	await _physics_frames(70)
	_check(game.hat.region_rect.position.y == Hats.Width.WIDE * Hats.FRAME.y, "squashed down to charge, the slime wears it wider")
	Input.action_release("jump")
	await _physics_frames(90)
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

	# --- A splat: the hat stays over the slime (just jolted on a little) and comes back down on it
	game = await _spawn_game()
	var end := _dead_end(game, 3)
	var near := MazeGenerator.cell_center(end.cell, 16)
	game.slime.position = near
	game.last_slime_pos = near
	game.slime.facing = Vector2(end.dir)
	await physics_frame
	game.slime.launch(100.0)
	var overshoot := 0.0
	var off_line := 0.0
	var splat_flew := false
	var back_on := false
	for i in 60 * 4:
		await process_frame
		if game.hat.state != Hat.State.ON:
			splat_flew = true
			overshoot = maxf(overshoot, (game.hat.ground - game.slime.position).dot(Vector2(end.dir)))
			off_line = maxf(off_line, game.hat.ground.distance_to(game.slime.position))
		elif splat_flew:
			back_on = true
			break
	# (+3: this reads the slime after its physics step but before the hat follows that frame)
	_check(overshoot > 0.5 and off_line <= Hat.MAX_JOLT + 3.0, "a splat jolts the hat on a little but keeps it in line over the slime (%.1f px on, %.1f px off at most)" % [overshoot, off_line])
	_check(back_on, "...then it comes straight back down onto the slime")
	game.free()

	await _check_animated_hats()
	progress.selected_hat = Hats.NONE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
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


## The animated hats on a slime: the propeller spins through its frames (faster on the move,
## fastest flying), the raincloud rains; a paused slime (a locked tile) shows the still frame.
func _check_animated_hats() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var body := UIKit.make_slime_preview(Skins.get_preset("lime").color, 1, false, null, false)
	holder.add_child(body)
	body.play("idle")
	var hat := Hat.new()
	holder.add_child(hat)
	hat.setup("propeller", body)
	hat.set_process(false)  # (stepped by hand below)
	var seen := {}
	for i in 16:
		hat._process(1.0 / 8.0)
		seen[int(hat.region_rect.position.x)] = true
	_check(seen.size() == Hats.frames("propeller"), "the propeller cap's propeller spins through all %d frames (%d)" % [Hats.frames("propeller"), seen.size()])
	var rest := _frames_in(hat, 0.5)
	body.play("glide_e")
	var moving := _frames_in(hat, 0.5)
	hat.state = Hat.State.FLYING
	var flying := _frames_in(hat, 0.5)
	hat.state = Hat.State.ON
	_check(rest < moving and moving < flying, "...lazily at rest, faster on the move, fastest flying (%d < %d < %d frames in half a second)" % [rest, moving, flying])
	body.play("idle")
	body.pause()
	hat._process(0.3)
	_check(hat.anim_frame == 0 and hat.region_rect == Hats.region("propeller", Hats.width_for(Slime.head_width("idle", body.frame))), "a paused slime's hat holds its still frame")
	hat.queue_free()
	body.play("idle")
	var cloud := Hat.new()
	holder.add_child(cloud)
	cloud.setup("raincloud", body)
	cloud.set_process(false)
	var shown := {}
	for i in 8:
		cloud._process(1.0 / Hats.fps("raincloud"))
		shown[int(cloud.region_rect.position.x)] = true
	_check(shown.size() == Hats.frames("raincloud") and Hats.get_hat("raincloud").get("hovers", false), "the raincloud rains (%d frames) over the head" % shown.size())
	cloud.pop(Vector2(80, 0), 0.5)
	_check(cloud.state == Hat.State.ON, "a leap doesn't knock the raincloud off: it rides along over the head")
	_check(Hats.display_name("raincloud") == "RAINCLOUD" and Hats.about("raincloud") != "" and "raincloud" in Hats.ids(), "it's the RAINCLOUD, with its own line")
	holder.queue_free()
	await process_frame


## How many frame changes hat `hat` makes in `seconds` (stepped at 60 fps).
func _frames_in(hat: Hat, seconds: float) -> int:
	var changes := 0
	var last := hat.anim_frame
	for i in int(seconds * 60.0):
		hat._process(1.0 / 60.0)
		if hat.anim_frame != last:
			changes += 1
			last = hat.anim_frame
	return changes
