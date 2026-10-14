extends Node

## Watchable / screenshot demo of a HEAT run: a player who beat the story on normal and hard plays
## hard level LEVEL with DIM + FOG BITES + RACE (heat 6, nothing earned yet), the autopilot walks it
## and the result shows the medal row and the HEAT 6 / BOUNTY +8 line. Nothing is saved.
## ./tools/screenshot.sh --frames 1500 --scene res://tests/demo_heat.tscn --story-complete --skin=lemon
## `-- --heat-level=N` plays another level; `-- --trail=ember` shows the EMBER trail.

var level := 3
var game: Node2D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--heat-level="):
			level = clampi(arg.trim_prefix("--heat-level=").to_int(), 1, Levels.COUNT)
	Progress.saving_enabled = false
	Progress.hard_mode = true
	Progress.hard_cleared.assign(range(1, Levels.COUNT + 1))
	Progress.heat_best = {}
	if Progress.heat_mods == 0:
		Progress.heat_mods = Heat.bit("dim") | Heat.bit("fog") | Heat.bit("race")
	Progress.start_story(level)
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = level
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	queue_free()
	game.add_child(preload("res://tests/autopilot.gd").new())
