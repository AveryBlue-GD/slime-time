extends Node

## Screenshot scenario: a full-power splat into the top wall, a short hop along the corridor,
## then charging a jump while aiming down the corridor (meter + landing dots visible).
## .\tools\screenshot.ps1 -Frames 150 -Scene res://tests/demo_jump.tscn

var game: Node2D
var frame := 0
var aim: Vector2


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 2:
		aim = Vector2.RIGHT if not game.is_wall_tile(Vector2i(3, 1)) else Vector2.DOWN
	match frame:
		5:
			game.slime.facing = Vector2.UP
			game.slime.launch(100.0)
		45:
			game.slime.facing = aim
			game.slime.launch(20.0)
		90:
			Input.action_press("jump")
		95:
			game.slime.facing = aim
