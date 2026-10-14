extends Node

## Screenshot scenario for the BRIGHTNESS breakpoints (upgrades v2: light radius 9 / 17 / 25 / 34 px):
## a story level with the test autopilot gliding the shortest route for a moment, so the light around
## the slime (and the relit trail behind it) shows at the bought level. Same level and frame count
## at every level, so the shots compare directly:
## ./tools/screenshot.sh --frames 330 --scene res://tests/demo_brightness.tscn --level 4 --upgrades=0,0,N --coins=0

var game: Node2D


func _ready() -> void:
	Progress.tutorial_seen = 3
	game = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	_start.call_deferred()


func _start() -> void:
	get_tree().current_scene = game
	game.add_child(preload("res://tests/autopilot.gd").new())
