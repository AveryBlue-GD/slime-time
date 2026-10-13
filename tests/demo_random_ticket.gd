extends Node

## Screenshot scenario: a randomizer maze, the slime walked (6 px a frame) along the route to just
## before the ticket so the ticket shows in the lit area. `--slime=N` sets MORE SLIME levels.
## ./tools/screenshot.sh --frames 420 --scene res://tests/demo_random_ticket.tscn --unlock-all --skin=ocean

var game: Node2D


func _ready() -> void:
	Progress.start_random()
	game = preload("res://scenes/main.tscn").instantiate()
	game.random_seed = 777
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	await get_tree().physics_frame
	var route := MazeGenerator.shortest_path(game.maze, game.maze.start, game.ticket.cell)
	var points: Array[Vector2] = []
	for cell in route:
		points.append(MazeGenerator.cell_center(cell, 16))
	var index := 1
	while index < points.size() and not game.finished:
		var target := points[index]
		var delta: Vector2 = target - game.slime.position
		if delta.length() <= 6.0:
			index += 1
			continue
		game.slime.position += delta.normalized() * 6.0
		await get_tree().physics_frame
		if index == points.size() - 1 and game.slime.position.distance_to(target) < 30.0:
			break
	await get_tree().create_timer(0.5).timeout
	queue_free()
