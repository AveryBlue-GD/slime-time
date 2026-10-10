extends Node

## Screenshot scenario: a level with the pause menu open.
## .\tools\screenshot.ps1 -Frames 40 -Scene res://tests/demo_pause.tscn

var game: Node2D
var frame := 0


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	frame += 1
	if frame == 20:
		game.pause_menu.open()
