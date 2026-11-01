extends Node

## Screenshot scenario: SETTINGS with the RELAXED button focused (its CALM MODE hint shows).
## .\tools\screenshot.ps1 -Frames 40 -Scene res://tests/demo_relaxed_hint.tscn

func _ready() -> void:
	Progress.saving_enabled = false
	var scene: Node = load("res://scenes/controls.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(0.3).timeout
	scene.relaxed_button.grab_focus()
