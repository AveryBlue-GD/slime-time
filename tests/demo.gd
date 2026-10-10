extends Node

## Plays the main scene with the autopilot driving. Used for screenshots:
## .\tools\screenshot.ps1 -Frames 400 -Scene res://tests/demo.tscn


func _ready() -> void:
	var game: Node2D = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.add_child(preload("res://tests/autopilot.gd").new())
