extends Node

## IMP4-03 touch shot set: `-- --shot=hub|toast|result|look|pause` (add --platform=ios for the phone layout).
## ./tools/screenshot.sh --frames 60 --scene res://tests/demo_imp4_shots.tscn --unlock-all -- --platform=ios --shot=toast

var game: Node2D


func _ready() -> void:
	var p := get_node("/root/Progress")
	UIKit.touch_in_use = true
	var mode := "hub"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			mode = a.substr(7)
	match mode:
		"hub":
			var hub: Node = preload("res://scenes/hub.tscn").instantiate()
			add_child(hub)
			p.start_daily()
			await get_tree().create_timer(0.3).timeout
			var st: Dictionary = {}
			for pr in hub._all_props():
				if pr.id == "daily":
					st = pr
			hub.slime.position = st.sprite.position + Vector2(0, 4)
			await get_tree().create_timer(0.3).timeout
		"toast":
			add_child(preload("res://scenes/hub.tscn").instantiate())
			p.notify_once("shot_wear", "NEW REWARD: NIGHT PAPER", "reward", "night")
		"look":
			var skins: Node = preload("res://scenes/skins.tscn").instantiate()
			add_child(skins)
			await get_tree().process_frame
			skins.toggle_random_look()
		"pause":
			game = preload("res://scenes/main.tscn").instantiate()
			add_child(game)
			await get_tree().create_timer(0.5).timeout
			game.pause_menu.open()
		"result":
			p.start_daily()
			p.daily_streak = 6
			p.daily_day = p.utc_day() - 1
			p.randoms_won = 4
			game = preload("res://scenes/main.tscn").instantiate()
			game.random_seed = p.random_seed
			get_tree().root.add_child.call_deferred(game)
			await get_tree().process_frame
			get_tree().current_scene = game  # (so the result takes the real running-scene path)
			await get_tree().physics_frame
			game.slime.position = game.goal.position
			await get_tree().physics_frame
			game._on_goal_body_entered(game.slime)
