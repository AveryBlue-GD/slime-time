extends Node

## Clip scenario for the soft bounce test (docs/spring-cleaning/soft-bounce-test.md): level 1 in FULL
## BRIGHT, then four leaps, 110 frames apart (placed, 0.5 s to settle, leap): a full-power diagonal
## leap in a corridor, a half-power one, a diagonal leap into a dead end's inside corner, and a
## full-power head-on leap into a dead end. Add `--softbounce` for the soft version (same leaps, spots).
## ./tools/godot.sh --path . --fixed-fps 60 --write-movie /private/tmp/claude-501/softbounce/on/f.png \
##   --quit-after 450 res://tests/demo_soft_bounce.tscn -- --softbounce --skin=lime

const GAP := 110  # physics frames between leaps
const LEAP_AT := 30  # frames after placing the slime (the camera settles first)

var game: Node2D
var frame := 0
var leaps: Array = []


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.current_level = 1
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 2:
		game.set_dev_bright(true)
		game.dev_no_drain = true
		var corridor := _find("corridor")
		var dead_end := _find("dead_end")
		leaps = [[corridor, 1, 100.0], [corridor, 1, 50.0], [dead_end, 1, 100.0], [dead_end, 0, 100.0]]
	var i := (frame - 10) / GAP
	if frame < 10 or i >= leaps.size():
		return
	var spot: Dictionary = leaps[i][0]
	var dir := Vector2(spot.dir)
	match (frame - 10) % GAP:
		0:  # put the slime on its spot and let the camera settle
			var start := MazeGenerator.cell_center(spot.cell - (spot.dir if leaps[i][1] == 0 else Vector2i.ZERO) * 3, 16)
			game.slime.position = start
			game.slime.velocity = Vector2.ZERO
			game.slime.state = Slime.State.GLIDE
			game.slime.knocked_back = false
			game.last_slime_pos = start
			game.slime.reset_physics_interpolation()
			game.camera.reset_smoothing()
		LEAP_AT:
			game.slime.facing = (dir + dir.orthogonal() * leaps[i][1]).normalized()
			game.slime.launch(leaps[i][2])


## corridor: 4 open cells straight ahead, walls both sides; dead_end: closed ahead and to one side,
## 3 open cells behind.
func _find(kind: String) -> Dictionary:
	var cells: Array[Vector2i] = []  # nearest the maze's middle first
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			cells.append(Vector2i(x, y))
	var mid := Vector2(game.maze.cells) / 2.0
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(mid) < Vector2(b).distance_squared_to(mid))
	for cell in cells:
		var open := MazeGenerator.open_neighbors(game.maze, cell)
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var side := Vector2i(Vector2(dir).orthogonal())
			var ok := true
			if kind == "corridor":
				ok = not (cell + side) in open and not (cell - side) in open
				var at := cell
				for n in 4:
					ok = ok and (at + dir) in MazeGenerator.open_neighbors(game.maze, at)
					at += dir
			else:
				ok = not (cell + dir) in open and not (cell + side) in open
				var back := cell
				for n in 3:
					ok = ok and (back - dir) in MazeGenerator.open_neighbors(game.maze, back)
					back -= dir
			if ok:
				return {cell = cell, dir = dir}
	return {cell = Vector2i.ZERO, dir = Vector2i.RIGHT}
