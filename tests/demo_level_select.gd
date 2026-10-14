extends Node2D

## Level select with a mix of states for screenshots: tiles 1-3 cleared (gold / silver / bronze,
## two with record times), 4 cleared without a time, 5 open, 6-10 locked; focus on tile 5.
## Pass `-- hard`, `-- only=lock|number` (measuring) for hard mode, `-- focus=N` to focus another tile. Nothing is saved.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_level_select.tscn [hard]


func _ready() -> void:
	Progress.saving_enabled = false
	Progress.highest_unlocked = 5
	Progress.levels_cleared = 4
	Progress.current_level = 5
	var hard := "hard" in OS.get_cmdline_user_args()
	Progress.hard_mode = hard
	var base := 100 if hard else 0
	Progress.medals[base + 1] = 3
	Progress.medals[base + 2] = 2
	Progress.medals[base + 3] = 1
	if hard:
		Progress.hard_cleared.assign([1, 2, 3, 4])
	Progress.best_times[base + 1] = 12.3
	Progress.best_times[base + 2] = 65.4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("focus="):
			Progress.current_level = arg.trim_prefix("focus=").to_int()
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	add_child(screen)
	# `only=lock` / `only=number`: drop the other so tools/measure_tiles.py can measure one alone.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			var drop := "Number" if arg == "only=lock" else "Lock"
			for tile in screen.level_buttons:
				for child in tile.get_children():
					if child.name == drop:
						child.free()
