extends Node

## Screenshot scenario: the goo-wipe transition frozen partway down over the title screen.
## .\tools\screenshot.ps1 -Frames 20 -Scene res://tests/demo_wipe.tscn -GameArgs --unlock-all,--skin=ember

const COVER := 0.75


func _ready() -> void:
	add_child(preload("res://scenes/hub.tscn").instantiate())
	Transition._paint()
	Transition._set_edges(COVER, 0.0)
	Transition._sheet.visible = true
