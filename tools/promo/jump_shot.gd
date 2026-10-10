extends Node

## Screenshot scenario for the itch page: the autopilot glides partway through a level, then the
## slime stops and charges a jump down the longest open corridor (meter + landing dots visible).

const LEVEL := 2
const STOP_FRAME := 300

var game: Node2D
var pilot: Node
var frame := 0


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = LEVEL
	add_child(game)
	pilot = preload("res://tests/autopilot.gd").new()
	game.add_child(pilot)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == STOP_FRAME:
		pilot.queue_free()
		game.slime.facing = _longest_open_direction()
		Input.action_press("jump")


func _longest_open_direction() -> Vector2:
	var tile := Vector2i((game.slime.position / 16.0).floor())
	var best := Vector2i.RIGHT
	var best_run := -1
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var run := 0
		while not game.is_wall_tile(tile + dir * (run + 1)):
			run += 1
		# A full jump is 8 tiles; prefer sideways aims since the screen is wider than tall.
		var score := mini(run, 8) * (2 if dir.y == 0 else 1)
		if score > best_run:
			best_run = score
			best = dir
	return Vector2(best)
