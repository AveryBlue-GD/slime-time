extends Node

## Screenshot scenario: the hub's hat wheel open, with the ticket balance and the spin price.
## ./tools/screenshot.sh --frames 60 --scene res://tests/demo_wheel.tscn --unlock-all --tickets=27 [--paid]

func _ready() -> void:
	Progress.spins = 2
	if "--paid" in OS.get_cmdline_user_args():  # a real player's wheel: the price rises with each spin
		Progress.dev_tools = false
		Hats.available = true
		Progress.spins = 6
	var hub: Node = preload("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	hub.open_hat_wheel.call_deferred()
