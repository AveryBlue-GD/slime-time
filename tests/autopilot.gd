extends Node

## Test/demo helper: add as a child of the game scene and it steers the slime along the
## shortest maze path to the chalice by pressing the real movement actions.

const ARRIVE_DISTANCE := 6.0

var game: Node2D
var waypoints: Array[Vector2] = []


func _ready() -> void:
	game = get_parent()
	for cell in MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal):
		waypoints.append(MazeGenerator.cell_center(cell, game.TILE))


func _physics_process(_delta: float) -> void:
	if game.finished or waypoints.is_empty():
		_steer(Vector2.ZERO)
		return
	var to_target: Vector2 = waypoints[0] - game.slime.position
	if to_target.length() < ARRIVE_DISTANCE and waypoints.size() > 1:
		waypoints.pop_front()
		to_target = waypoints[0] - game.slime.position
	_steer(to_target.normalized())


func _exit_tree() -> void:
	_steer(Vector2.ZERO)


func _steer(dir: Vector2) -> void:
	_press("move_right", dir.x)
	_press("move_left", -dir.x)
	_press("move_down", dir.y)
	_press("move_up", -dir.y)


func _press(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
