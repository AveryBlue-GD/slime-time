extends Node

## Screenshot scenario: a level won faster than a (fake, slow) record, showing the NEW RECORD! banner.
## Run with -GameArgs --unlock-all so nothing is saved:
## .\tools\screenshot.ps1 -Frames 75 -Scene res://tests/demo_record.tscn -GameArgs --unlock-all

var game: Node2D
var frame := 0


func _ready() -> void:
	Progress.best_times[2] = 99.0
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 2
	add_child(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 40:
		game.slime.position = game.chalice.position
