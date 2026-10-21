extends Node

## Consecutive small hops with a hat on (a watchable check, not a test): level 1, the slime in a
## straight corridor wearing the top hat, hopping the shortest leap back and forth every HOP_EVERY
## seconds. Record it with --write-movie (tools/screenshot.ps1 -Scene res://tests/demo_hat_hops.tscn).

const MAIN := preload("res://scenes/main.tscn")
const HOP_EVERY := 0.16


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.tutorial_seen = 3
	Progress.levels_cleared = Levels.COUNT
	Progress.hats_owned.assign(["tophat"])
	Progress.selected_hat = "tophat"
	Progress.start_story(1)
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = game
	game.set_dev_bright(true)
	game.set_dev_no_drain(true)
	var spot := _straight(game, 3)
	game.slime.position = MazeGenerator.cell_center(spot.cell, 16)
	game.last_slime_pos = game.slime.position
	var dir := Vector2(spot.dir)
	var hops := 0
	while is_inside_tree():
		await get_tree().create_timer(HOP_EVERY).timeout
		if game.slime.state == Slime.State.GLIDE:
			game.slime.facing = dir
			game.slime.launch(0.0)
			hops += 1
			if hops % 4 == 0:
				dir = -dir


func _straight(game: Node2D, length: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT]:
				var cell := Vector2i(x, y)
				var ok := true
				for i in length:
					ok = ok and (cell + d) in MazeGenerator.open_neighbors(game.maze, cell)
					cell += d
				if ok:
					return {cell = Vector2i(x, y), dir = d}
	return {}
