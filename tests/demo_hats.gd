extends Node

## Screenshot scenario: the skins screen flipped to the hats page.
## .\tools\screenshot.ps1 -Frames 30 -Scene res://tests/demo_hats.tscn -GameArgs --unlock-all,--hat=tophat


func _ready() -> void:
	var screen: Control = preload("res://scenes/skins.tscn").instantiate()
	add_child(screen)
	screen.show_page.call_deferred("hats")
