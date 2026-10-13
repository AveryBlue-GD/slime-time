extends Node

## Screenshot scenario: a real win (the slime is dropped on the chalice early). A story win shows
## the medal tier (`--slow` = a silver-time run instead of gold, `--best=N` = a tier already held
## on this level, so a better run says NEW BEST); `--random` plays a randomizer maze and shows the
## tickets paid (`--slow` = over par, so no under-par bonus).
## ./tools/screenshot.sh --frames 200 --scene res://tests/demo_rewards.tscn --unlock-all --skin=lemon --random
const LEVEL := 3

var game: Node2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	game = preload("res://scenes/main.tscn").instantiate()
	if "--random" in args:
		Progress.start_random()
		game.random_seed = 777
	else:
		Progress.start_story(LEVEL)
		Progress.levels_cleared = LEVEL - 1
		game.level = LEVEL
	for arg in args:
		if arg.begins_with("--best="):
			Progress.medals[LEVEL] = arg.trim_prefix("--best=").to_int()
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	await get_tree().create_timer(1.0).timeout
	if "--slow" in OS.get_cmdline_user_args():
		game.run_time = game.par_time * (1.1 if "--random" not in OS.get_cmdline_user_args() else 1.5)
	game.slime.position = game.chalice.position
	queue_free()
