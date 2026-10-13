extends Node

## Screenshot scenario: the hub's trapdoor confirm panel (LEAVE THE HUB? QUIT / BACK) open.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_quitmenu.tscn --unlock-all

func _ready() -> void:
	var hub: Node = preload("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	hub.open_quit_menu.call_deferred()
