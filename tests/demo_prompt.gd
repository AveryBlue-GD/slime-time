extends Node

## Screenshot scenario: the R-key prompt (RESTART / UPGRADES / CANCEL) over a level.
## .\tools\screenshot.ps1 -Frames 60 -Scene res://tests/demo_prompt.tscn -GameArgs --unlock-all

var game: Node2D
var frame := 0


func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 5
	add_child(game)


func _process(_delta: float) -> void:
	frame += 1
	if frame == 30:
		game.restart_prompt.open()
