extends Node

## Test slime demo: the see-through jelly slime glides through a level (autopilot), with extra
## coins scattered along its path so you can watch each one sink into its body and dissolve.
## .\tools\play.ps1 -Dev -Scene res://tests/demo_jelly.tscn

const LEVEL := 2
## A coin every this many cells along the path.
const COIN_EVERY := 3

var game: Node2D


func _ready() -> void:
	Progress.set_jelly(true)
	Progress.saving_enabled = false
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = LEVEL
	add_child(game)
	var path := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	for i in range(2, path.size() - 1, COIN_EVERY):
		var coin := Coin.new()
		coin.z_index = 6
		coin.position = MazeGenerator.cell_center(path[i], 16)
		game.add_child(coin)
		coin.setup(Themes.BY_LEVEL.find(game.theme), path[i] + Vector2i(1000, 1000))  # not a real coin
		game.coins.append(coin)
	game.add_child(preload("res://tests/autopilot.gd").new())
