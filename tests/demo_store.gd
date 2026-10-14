extends Node

## Screenshot scenarios for the ticket store (upgrades v2 batch 2), picked with `--shot=`:
##   tickets  the cauldron's TICKETS tab (the WORKSHOP), with some levels bought
##   shop     the prize wheel's SHOP tab (TRAILS section; `--section=hats|papers` for the others)
##   trails   the wardrobe's TRAILS page
##   wind     SECOND WIND firing in a level (the meter empties mid-glide, refills, the WIND tag lights)
##   trail    a level with the test autopilot gliding, to show the worn trail style (`--trail=ID`)
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_store.tscn --story-complete --tickets=60 --shot=tickets --workshop=2,1,0,3,0
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_store.tscn --story-complete --tickets=120 --shot=shop --trail=gold
## ./tools/screenshot.sh --frames 40 --scene res://tests/demo_store.tscn --story-complete --shot=trails --trail=candy
## ./tools/screenshot.sh --frames 268 --scene res://tests/demo_store.tscn --story-complete --shot=wind --level 3 --skin=lemon --workshop=2
## ./tools/screenshot.sh --frames 330 --scene res://tests/demo_store.tscn --story-complete --shot=trail --level 1 --skin=lime --trail=gold

var shot := ""
var game: Node2D
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	Progress.tickets_lifetime = maxi(Progress.tickets_lifetime, Progress.tickets)
	Progress.tutorial_seen = 3
	match shot:
		"tickets":
			load("res://scripts/ui/upgrades_screen.gd").set("open_tab", "tickets")
			add_child(load("res://scenes/upgrades.tscn").instantiate())
		"shop":
			Progress.spins = 3
			var hub: Node = load("res://scenes/hub.tscn").instantiate()
			add_child(hub)
			_open_shop.call_deferred(hub)
		"trails":
			var screen: Control = load("res://scenes/skins.tscn").instantiate()
			add_child(screen)
			screen.show_page.call_deferred("trails")
		"coins", "brightness":  # the COINS tab (RECOMMENDED tag); `brightness` buys a level for the 1 s ring
			var cauldron: Control = load("res://scenes/upgrades.tscn").instantiate()
			add_child(cauldron)
			if shot == "brightness":
				Progress.upgrades = {slime = 2, speed = 1, brightness = 1}
				cauldron.show_page.call_deferred("coins")
				cauldron.rows.brightness.plus.pressed.emit.call_deferred()
		"confirm":  # the TICKETS tab with the BUY / BACK confirm open
			load("res://scripts/ui/upgrades_screen.gd").set("open_tab", "tickets")
			var cauldron2: Control = load("res://scenes/upgrades.tscn").instantiate()
			add_child(cauldron2)
			cauldron2.ticket_rows.charge.plus.pressed.emit.call_deferred()
		"nose":  # GOO NOSE: twinkles over several coins that are on screen
			game = preload("res://scenes/main.tscn").instantiate()
			get_tree().root.add_child.call_deferred(game)
			_nose.call_deferred()
		"wind", "trail":
			game = preload("res://scenes/main.tscn").instantiate()
			get_tree().root.add_child.call_deferred(game)
			_start.call_deferred()


func _open_shop(hub: Node) -> void:
	hub.open_hat_wheel()
	hub.hat_wheel.show_tab("shop")
	var section := "trails"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			section = arg.trim_prefix("--section=")
	hub.hat_wheel.show_section(section)


func _start() -> void:
	get_tree().current_scene = game
	game.add_child(preload("res://tests/autopilot.gd").new())


func _physics_process(_delta: float) -> void:
	_frame += 1
	if shot == "wind" and game and _frame == 250 and game.wind_state == "ready":
		game.slime_remaining = 0.0  # (the demo empties the meter mid-glide: SECOND WIND fires)


func _nose() -> void:
	get_tree().current_scene = game
	for i in 4:
		await get_tree().physics_frame
	var coin: Node2D = game.coins[0]
	var near := coin.position
	for d: Vector2i in MazeGenerator.DIRS:
		if not game.is_wall_tile(Vector2i(floori(near.x / 16.0), floori(near.y / 16.0)) + d):
			near += Vector2(d) * 16.0
			break
	game.slime.position = near
	game.last_slime_pos = near
	game.glimmer_reach = 9999.0
	for i in 3:
		await get_tree().physics_frame
	var field: Array[Coin] = []
	for offset: Vector2 in [Vector2(-90, -40), Vector2(80, -50), Vector2(-60, 55), Vector2(100, 40), Vector2(10, -70)]:
		var extra := Coin.new()  # (stand-in coins: the picture needs several in view)
		extra.position = near + offset
		game.add_child(extra)
		field.append(extra)
	for c in field:  # a twinkle over every coin in view
		var one: Array[Coin] = [c]
		game.coins = one
		game._spawn_glimmer()
	game.glimmer_reach = 300.0
