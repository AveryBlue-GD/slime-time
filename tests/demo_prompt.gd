extends Node

## Screenshot scenario: the R-key prompt (RESTART / UPGRADES / CANCEL) over a level.
## .\tools\screenshot.ps1 -Frames 60 -Scene res://tests/demo_prompt.tscn -GameArgs --unlock-all
## `-- close`: CANCEL 20 frames after it opens (the area name and story line come back under it).

var game: Node2D
var frame := 0


func _ready() -> void:
	Progress.saving_enabled = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # (keeps counting while the prompt pauses the level)
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = 5
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)


func _process(_delta: float) -> void:
	frame += 1
	if frame == 30:
		game.restart_prompt.open()
	if frame == 50 and "close" in OS.get_cmdline_user_args():
		game.restart_prompt.close()
