extends Node

## Screenshot scenario: a level won faster than a (fake, slow) record, showing the NEW RECORD! banner
## and the REPLAY / NEXT LEVEL buttons. The level is added to the root and made the current scene
## so its real win flow runs. Run with -GameArgs --unlock-all so nothing is saved:
## .\tools\screenshot.ps1 -Frames 100 -Scene res://tests/demo_record.tscn -GameArgs --unlock-all

var game: Node2D
var frame := 0


func _ready() -> void:
	Progress.best_times[2] = 99.0
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 2
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
	elif frame == 40:
		game.slime.position = game.goal.position
