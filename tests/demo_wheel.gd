extends Node

## Screenshot scenario: the hub's hat wheel open, with the ticket balance and the spin price.
## ./tools/screenshot.sh --frames 60 --scene res://tests/demo_wheel.tscn --unlock-all --tickets=27

func _ready() -> void:
	Progress.spins = 2
	var hub: Node = preload("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	hub.open_hat_wheel.call_deferred()
