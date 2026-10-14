extends Node

## Screenshot scenario: a randomizer maze restarted for real until it is on attempt N, then the HUD's
## attempt pod is shown (the run's own frames, no pod set by hand). Prints the pod's text on each
## restart's first frame. Never saves (throwaway save path, saving off).
##   --attempt=N   restart until attempt N (default 1)
##   --route=key   the R key, then Enter on the R prompt's RESTART (default; as a player does)
##   --route=pause the pause menu's RESTART;  --route=dryup  the dry-up RESTART button
##   --pop         quit mid-pop (the TIX AVAILABLE flash), else once it has finished
## ./tools/screenshot.sh --frames 900 --scene res://tests/demo_attempts.tscn --upgrades=3,0,0 --skin=ocean --attempt=2

const GAME_SCENE := "res://scenes/main.tscn"

var target := 1
var route := "key"
var pop := false


func _ready() -> void:
	Progress.save_path = "user://test_save.cfg"  # never the real save
	Progress.saving_enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--attempt="):
			target = maxi(arg.trim_prefix("--attempt=").to_int(), 1)
		elif arg.begins_with("--route="):
			route = arg.trim_prefix("--route=")
		elif arg == "--pop":
			pop = true
	Progress.start_random()
	Progress.random_seed = 777
	var game: Node2D = load(GAME_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(game)
	_drive.call_deferred(game)


func _drive(game: Node2D) -> void:
	await get_tree().process_frame
	get_tree().current_scene = game
	await get_tree().physics_frame
	print("attempt pod: ", game.hud.attempt_label.text.replace("\n", " / "))
	while game.attempt < target:
		await get_tree().create_timer(0.6).timeout  # let the goo wipe clear, as a player would
		var old_id := game.get_instance_id()
		match route:
			"pause":
				game.pause_menu.open()
				await get_tree().process_frame
				game.pause_menu.buttons[1].pressed.emit()  # RESTART
			"dryup":
				game.slime_remaining = 0.0
				while game.hud.choice_buttons.is_empty():
					await get_tree().process_frame
				game.hud.choice_buttons[0].pressed.emit()  # RESTART
			_:
				_key(KEY_R)
				for i in 3:
					await get_tree().process_frame
				if is_instance_valid(game) and game.restart_prompt.visible:  # coins in hand: RESTART has the focus
					_key(KEY_ENTER)
		while get_tree().current_scene == null or get_tree().current_scene.get_instance_id() == old_id \
				or not get_tree().current_scene.is_inside_tree():
			await get_tree().process_frame
		game = get_tree().current_scene
		print("attempt pod: ", game.hud.attempt_label.text.replace("\n", " / "))
	await get_tree().create_timer(0.23 if pop and target > 1 else 1.2).timeout
	get_tree().quit()


func _key(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
