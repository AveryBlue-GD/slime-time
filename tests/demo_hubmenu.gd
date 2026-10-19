extends Node

## Screenshot scenario: the hub's Esc menu (MENU: BACK / SETTINGS / QUIT TO TITLE) open over the hub.
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_hubmenu.tscn --unlock-all

func _ready() -> void:
	var hub: Node = preload("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	hub.open_hub_menu.call_deferred()
