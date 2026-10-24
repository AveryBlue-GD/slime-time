extends Node

## BM-01 screenshot / clip scene: a random maze with --lurkers, the first lurker awake in the slime's light next to
## it and the second awake in the fog two cells away (only its eye glints show). Nothing is saved.
## ./tools/screenshot.ps1 -Frames 40 -Scene res://tests/demo_lurkers.tscn -GameArgs --lurkers,--skin=lime

var game: Node2D
var frame := 0
var pins: Array[Vector2] = []


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.mode = Progress.MODE_RANDOM
	Progress.random_seed = 4321
	Progress.reduce_motion = false
	Progress.skin_notices_seen.append(1)
	game = preload("res://scenes/main.tscn").instantiate()
	game.random_seed = 4321
	add_child(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		var lk: Lurkers = game.lurkers
		var start: Vector2i = game.maze.start
		var near := MazeGenerator.open_neighbors(game.maze, start)
		var far: Array[Vector2i] = []
		if not near.is_empty():
			far = MazeGenerator.open_neighbors(game.maze, near[0])
		lk.invuln = 99.0
		var cells: Array[Vector2i] = []
		if not near.is_empty():
			cells.append(near[0])
		for c in far:
			if c != start:
				cells.append(c)
				break
		var i := 0
		for l in lk.lurkers:
			if i < cells.size():
				l.cell = cells[i]
				l.prev = cells[i]
				l.to = cells[i]
				l.pos = MazeGenerator.cell_center(cells[i], 16)
				if i == 0:  # in the light: a little way down the passage toward its cell
					l.pos = MazeGenerator.cell_center(start, 16) + Vector2(cells[0] - start) * 17.0
				l.awake = true
				l.wake_t = Lurkers.WAKE_TIME
				l.kind = 1 - i if i < 2 else l.kind
			pins.append(l.pos)
			if i == 0:
				game._paint_goo(l.pos, 9.0)  # the light pocket it stands in
			i += 1
	elif frame > 3 and game.lurkers != null:
		for k in mini(pins.size(), game.lurkers.lurkers.size()):
			game.lurkers.lurkers[k].pos = pins[k]  # hold them still for the picture
