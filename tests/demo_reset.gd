extends Node

## Screenshot scenario: the settings screen asking to confirm RESET PROGRESS.
## .\tools\screenshot.ps1 -Frames 30 -Scene res://tests/demo_reset.tscn -GameArgs --unlock-all


func _ready() -> void:
	var screen: Control = preload("res://scenes/controls.tscn").instantiate()
	add_child(screen)
	screen._ask_reset.call_deferred()
