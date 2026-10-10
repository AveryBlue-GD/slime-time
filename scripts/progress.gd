extends Node

## Autoload "Progress": which level to play and what has been cleared, saved to
## user://save.cfg. (Phase 5 adds skins here.)
## Debug: run the game with `-- --level=N` to start on level N without touching the save.

const SECTION := "progress"

var save_path := "user://save.cfg"
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of levels beaten so far (0-10).
var levels_cleared := 0
## Level the game scene loads next.
var current_level := 1


func _ready() -> void:
	load_progress()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)


func load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	levels_cleared = clampi(file.get_value(SECTION, "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(file.get_value(SECTION, "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(file.get_value(SECTION, "current_level", 1), 1, highest_unlocked)


func save_progress() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "levels_cleared", levels_cleared)
	file.set_value(SECTION, "highest_unlocked", highest_unlocked)
	file.set_value(SECTION, "current_level", current_level)
	file.save(save_path)


## Records a win and picks the next level (back to 1 after beating the last one).
func complete_level(level: int) -> void:
	levels_cleared = maxi(levels_cleared, level)
	highest_unlocked = maxi(highest_unlocked, mini(level + 1, Levels.COUNT))
	current_level = level + 1 if level < Levels.COUNT else 1
	save_progress()
