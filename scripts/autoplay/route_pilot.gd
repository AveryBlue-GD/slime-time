class_name RoutePilot
extends Node

## Steers the game's slime along a route of maze cells by pressing the real movement actions
## (child of the game scene; it reads `game.slime` and `game.finished`). Each physics tick it
## heads for the next cell center, moving on to the one after once within ARRIVE_DISTANCE px, so
## it cuts corners a little like a player. Used by the --autoplay bot (scripts/autoplay/) and the
## tests' autopilot (tests/autopilot.gd: the shortest route to the goal).
## Decisions are made once per physics tick from the slime's position only, so a run plays the same
## at any Engine.time_scale (the bot raises the physics tick rate with it; see autoplay.gd).

signal route_done  ## within ARRIVE_DISTANCE of the last waypoint (once)

const ARRIVE_DISTANCE := 6.0

var game: Node2D
var waypoints: Array[Vector2] = []
## The cells to follow; set before adding the pilot to the game (else the subclass picks them).
var cells: Array[Vector2i] = []
var _done := false


func _ready() -> void:
	game = get_parent()
	if cells.is_empty():
		cells = route()
	for cell in cells:
		waypoints.append(MazeGenerator.cell_center(cell, game.TILE))


## The route when none was given (tests/autopilot.gd: start to goal).
func route() -> Array[Vector2i]:
	return MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)


func _physics_process(_delta: float) -> void:
	if game.finished or waypoints.is_empty():
		_steer(Vector2.ZERO)
		return
	var to_target: Vector2 = waypoints[0] - game.slime.position
	if to_target.length() < ARRIVE_DISTANCE and waypoints.size() > 1:
		waypoints.pop_front()
		to_target = waypoints[0] - game.slime.position
	if waypoints.size() == 1 and to_target.length() < ARRIVE_DISTANCE and not _done:
		_done = true
		route_done.emit()
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
