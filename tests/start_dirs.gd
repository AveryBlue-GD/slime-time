extends RefCounted

## Test helper: since v4 the slime starts anywhere (SpawnPicker), not in the top-left corner, so
## tests ask the maze which way from the start is open and which is a wall.

const ACTIONS := {Vector2i.RIGHT: "move_right", Vector2i.LEFT: "move_left", Vector2i.DOWN: "move_down", Vector2i.UP: "move_up"}
const ANIMS := {Vector2i.RIGHT: "e", Vector2i.LEFT: "w", Vector2i.DOWN: "s", Vector2i.UP: "n"}


## An open direction from `cell` (RIGHT, DOWN, LEFT, UP preference order).
static func open_dir(maze: Dictionary, cell: Vector2i) -> Vector2i:
	var open := MazeGenerator.open_neighbors(maze, cell)
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if cell + dir in open:
			return dir
	return Vector2i.RIGHT


## A direction from `cell` with a wall right beside it (UP, LEFT, DOWN, RIGHT preference order).
static func wall_dir(maze: Dictionary, cell: Vector2i) -> Vector2i:
	var open := MazeGenerator.open_neighbors(maze, cell)
	for dir: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		if not cell + dir in open:
			return dir
	return Vector2i.UP


static func action(dir: Vector2i) -> String:
	return ACTIONS[dir]
