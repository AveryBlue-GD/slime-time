extends Node

## Clip scenario for the coin catch test (docs/spring-cleaning/coin-catch-test.md): level 1 in FULL
## BRIGHT with every coin back in place (in memory only), then two pickups, 220 frames apart: the
## slime glides 3 cells down a straight corridor into a dead end's coin, then leaps 2 cells (4 tiles) onto
## another one (caught in mid-leap). Add `--coincatch` for the catch (same spots); `--jelly` for the
## see-through slime.
## ./tools/godot.sh --path . --fixed-fps 60 --write-movie /private/tmp/claude-501/coincatch/on/f.png \
##   --quit-after 450 res://tests/demo_coin_catch.tscn -- --coincatch --skin=lime --hat=tophat

const GAP := 220  # physics frames per pickup
const MOVE_AT := 20  # frames after placing the slime (the camera settles first)

var game: Node2D
var frame := 0
var spots: Array = []


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.coins_found = {}  # every coin out (never saved)
	Progress.hard_mode = false
	Progress.jelly = "--jelly" in OS.get_cmdline_user_args()  # not whatever the real save has
	Progress.reduce_motion = false
	Progress.skin_notices_seen.append(1)  # no first-run skin notice (it would force jelly on)
	Progress.dev_tools = true  # FULL BRIGHT (in memory)
	Progress.dev_coins = 0  # the counter starts at 0
	Progress.current_level = 1
	game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 2:
		game.set_dev_bright(true)
		game.dev_no_drain = true
		spots = _approaches()
	var i := (frame - 5) / GAP
	if frame < 5 or i >= mini(spots.size(), 2):
		return
	var spot: Dictionary = spots[i]
	var dir: Vector2i = spot.dir
	match (frame - 5) % GAP:
		0:
			var start := MazeGenerator.cell_center(spot.cell - dir * (3 if i == 0 else 2), 16)
			game.slime.position = start
			game.slime.velocity = Vector2.ZERO
			game.slime.facing = Vector2(dir)
			game.last_slime_pos = start
			game.slime.reset_physics_interpolation()
			game.camera.reset_smoothing()
		MOVE_AT:
			if i == 0:
				Input.action_press(_action(dir))
			else:
				game.slime.facing = Vector2(dir)
				game.slime.launch((4.0 - Slime.MIN_JUMP_TILES) / (Slime.MAX_JUMP_TILES - Slime.MIN_JUMP_TILES) * 100.0)
		MOVE_AT + 110:
			Input.action_release(_action(dir))


func _action(dir: Vector2i) -> String:
	return {Vector2i.RIGHT: "move_right", Vector2i.LEFT: "move_left", Vector2i.DOWN: "move_down", Vector2i.UP: "move_up"}[dir]


## Coins at the end of a straight corridor at least 3 cells long: {cell, dir} (dir points at the coin).
func _approaches() -> Array:
	var out := []
	for coin: Coin in game.coins:
		var open := MazeGenerator.open_neighbors(game.maze, coin.cell)
		if open.size() != 1:
			continue
		var dir: Vector2i = coin.cell - open[0]
		var at := coin.cell
		var ok := true
		for n in 3:
			ok = ok and (at - dir) in MazeGenerator.open_neighbors(game.maze, at)
			at -= dir
		if ok:
			out.append({cell = coin.cell, dir = dir})
	return out
