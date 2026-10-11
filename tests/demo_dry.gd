extends Node

## Screenshot scenario: drying up in level 3, with the RESTART / UPGRADES buttons.
## .\tools\screenshot.ps1 -Frames 120 -Scene res://tests/demo_dry.tscn -GameArgs --unlock-all

var game: Node2D
var frame := 0


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 3
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
	elif frame == 30:
		game.slime_remaining = 0.1
		game.slime.position.x += 4.0
