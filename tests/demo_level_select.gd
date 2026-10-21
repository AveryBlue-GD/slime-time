extends Node2D

## Level select with a mix of states for screenshots: tiles 1-3 cleared (gold / silver / bronze,
## two with record times), 4 cleared without a time, 5 open, 6-10 locked; focus on tile 5.
## Pass `-- hard`, `-- only=lock|number` (measuring) for hard mode, `-- focus=N` to focus another tile. Nothing is saved.
## `-- all-times`: all 10 tiles open, each with a record time.
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
	var args := OS.get_cmdline_user_args()
	Progress.best_times[base + 1] = 12.3
	Progress.best_times[base + 2] = 65.4
	if "all-times" in args:  # every tile open with a record time (the number vs time gap on 1-10)
		Progress.highest_unlocked = 10
		Progress.levels_cleared = 10
		if hard:
			Progress.hard_cleared.assign(range(1, 11))
		var times := [12.3, 65.4, 44.4, 66.6, 63.6, 99.9, 646.4, 81.0, 63.6, 600.0]
		for i in 10:
			Progress.best_times[base + i + 1] = times[i]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("focus="):
			Progress.current_level = arg.trim_prefix("focus=").to_int()
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	add_child(screen)
	screen.size = Vector2(320, 180)  # (under a Node2D the full-rect anchors have no parent rect)
	# `only=lock` / `only=number`: drop the other so tools/measure_tiles.py can measure one alone.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			var drop := "Number" if arg == "only=lock" else "Lock"
			for tile in screen.level_buttons:
				for child in tile.get_children():
					if child.name == drop:
						child.free()
