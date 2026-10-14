extends Node

## Screenshot scenario: an in-game frame at the maze's top-left corner, with the corridors along the
## top and left edges explored, so the maze's outer walls and the border ring past them show through
## the normal fog (the Brightness upgrade's light reveals the ring). `--bright` (dev mode) switches
## on the dev FULL BRIGHT toggle as well, `--no-drain` the NO DRAIN one, and `--hud` keeps the HUD.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_edge.tscn --level 5 --unlock-all --upgrades=0,0,3 [--bright]

var game: Node2D
var frame := 0


func _ready() -> void:
	Progress.tutorial_seen = 3
	game = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 3:
		get_tree().current_scene = game
		game.hud.visible = OS.get_cmdline_user_args().has("--hud")
		var maze: Dictionary = game.maze
		var spots: Array[Vector2i] = []
		for x in range(1, mini(maze.size.x - 1, 22)):
			spots.append(Vector2i(x, 1))
		for y in range(2, mini(maze.size.y - 1, 14)):
			spots.append(Vector2i(1, y))
		for tile in spots:
			if game.is_wall_tile(tile):
				continue
			var at: Vector2 = (Vector2(tile) + Vector2(0.5, 0.5)) * game.TILE
			game._paint_goo(at, game.TRAIL_RADIUS)
			if game.light_reach > 0.0:
				game._reveal_light(at)
		game.slime.position = Vector2(3.5, 3.5) * game.TILE
		game.last_slime_pos = game.slime.position
		game.slime.set_physics_process(false)
		game.camera.reset_smoothing()
		if OS.get_cmdline_user_args().has("--bright") and game.has_method("set_dev_bright"):
			game.set_dev_bright(true)
		if OS.get_cmdline_user_args().has("--no-drain") and game.has_method("set_dev_no_drain"):
			game.set_dev_no_drain(true)
