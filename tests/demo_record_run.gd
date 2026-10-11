extends Node

## Watchable demo: the autopilot plays a level against an easy (fake) old record, so the real
## win flow shows the NEW RECORD! banner with its sound, then the replay / next buttons.
## Run windowed with dev flags so nothing is saved:
## .\tools\godot.ps1 --path . res://tests/demo_record_run.tscn -- --unlock-all

const LEVEL := 3
const OLD_RECORD := 30.0

var game: Node2D


func _ready() -> void:
	Progress.best_times[LEVEL] = OLD_RECORD
	Progress.start_story(LEVEL)
	game = preload("res://scenes/main.tscn").instantiate()
	game.level = LEVEL
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred()


func _drive() -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	queue_free()
	game.add_child(preload("res://tests/autopilot.gd").new())
