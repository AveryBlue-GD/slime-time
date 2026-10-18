extends Node

## Watchable demo: the slime wears a hat and keeps leaping back and forth along the longest
## straight corridor of level 1, at random strengths, sometimes splatting into the far wall, so
## the hat can be seen popping off, riding the momentum and landing back on.
## .\tools\play.ps1 -Dev -Scene res://tests/demo_hat_hops.tscn -GameArgs --hat=tophat [--level=N]

const HOP_EVERY := 1.6

var game: Node2D
var lane: Dictionary
var _next := 1.0
var _forward := true


func _ready() -> void:
	if Progress.selected_hat == Hats.NONE:
		Progress.saving_enabled = false
		Progress.selected_hat = Hats.LIST[0].id
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):  # (another level, to show its own skin there)
			game.level = int(arg.trim_prefix("--level="))
	add_child(game)
	lane = _longest_lane()
	var start := MazeGenerator.cell_center(lane.from, 16)
	game.slime.position = start
	game.last_slime_pos = start
	game.slime_remaining = 100.0


func _physics_process(delta: float) -> void:
	game.slime_remaining = 100.0  # never dry up during the demo
	_next -= delta
	if _next > 0.0 or game.slime.state != Slime.State.GLIDE or game.slime.velocity.length() > 5.0:
		return
	_next = HOP_EVERY
	game.slime.facing = Vector2(lane.dir) * (1.0 if _forward else -1.0)
	_forward = not _forward
	game.slime.launch(randf_range(25.0, 100.0))


## The longest straight run of open cells in the maze: {from, dir, length}.
func _longest_lane() -> Dictionary:
	var best := {from = game.maze.start, dir = Vector2i.RIGHT, length = 0}
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var cell := Vector2i(x, y)
				var length := 0
				while (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					cell += dir
					length += 1
				if length > best.length:
					best = {from = Vector2i(x, y), dir = dir, length = length}
	return best
