extends Node

## The randomizer's MAP after a dry-up (a watchable check, not a test): a random maze, the slime
## walked along its route for a while, dried up, then the MAP button pressed (RandomMapView).
## ./tools/screenshot.ps1 -Scene res://tests/demo_random_map.tscn -Frames 240

const MAIN := preload("res://scenes/main.tscn")


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.tutorial_seen = 3
	Progress.levels_cleared = Levels.COUNT
	Progress.start_random()
	var game: Node2D = MAIN.instantiate()
	game.level = 0
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = game
	var path: Array[Vector2i] = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	for cell in path.slice(0, path.size() * 2 / 3):
		game.slime.position = MazeGenerator.cell_center(cell, 16)
		await get_tree().physics_frame
	game.slime_remaining = 0.0
	for i in 200:
		await get_tree().physics_frame
		if not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].is_visible_in_tree():
			break
	game.open_random_map()
