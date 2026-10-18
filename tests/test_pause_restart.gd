extends "res://tests/suite_base.gd"

## After drying up: the RESTART / UPGRADES buttons appear (no automatic restart), pausing in the
## meantime doesn't freeze anything, RESTART reloads the level, UPGRADES opens the upgrades
## screen whose PLAY button goes straight back into the level, and quitting to the title from
## the pause menu lands on an unpaused title screen.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_pause_restart.gd

const MAIN := preload("res://scenes/main.tscn")



func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false

	# --- Dry up, pause while the buttons are coming, then RESTART
	var game := await _play()
	await _dry_up(game)
	_check(game.finished and not game.won, "the slime dries up")
	game.pause_menu.open()
	await _frames(int(game.CHOICE_DELAY * 60) + 60)
	_check(current_scene == game and paused and game.pause_menu.visible, "pausing holds everything (nothing reloads underneath)")
	game.pause_menu.resume()
	await _frames(int(game.CHOICE_DELAY * 60) + 10)
	_check(current_scene == game and game.hud.choice_buttons.size() == 3, "after resuming, RESTART, UPGRADES and MAP appear (no automatic restart)")
	game.hud.choice_buttons[0].pressed.emit()
	await _frames(5)
	_check(current_scene != game and current_scene != null and not paused, "RESTART plays the level again")

	# --- UPGRADES, then PLAY goes back into the level
	game = current_scene
	await _dry_up(game)
	await _frames(int(game.CHOICE_DELAY * 60) + 10)
	game.hud.choice_buttons[1].pressed.emit()
	await _frames(40)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/upgrades.tscn", "UPGRADES opens the upgrades screen")
	var screen: Node = current_scene
	var back: Button = screen.get_children().filter(func(n: Node) -> bool: return n is Button and n.text == "PLAY").front()
	_check(back != null, "...whose back button says PLAY")
	back.pressed.emit()
	await _frames(40)
	_check(current_scene != null and current_scene.scene_file_path == UIKit.GAME_SCENE, "PLAY goes straight back into the level")

	# --- Quit to the title from the pause menu after a dry-up
	game = current_scene
	await _dry_up(game)
	game.pause_menu.open()
	game.pause_menu._quit()
	await _frames(int(game.CHOICE_DELAY * 60) + 60)
	_check(current_scene != null and current_scene.scene_file_path == UIKit.HUB_SCENE and not paused,
		"quitting to the hub lands in the hub, unpaused (%s)" % (current_scene.scene_file_path if current_scene else "none"))

	_result()
	quit(1 if failures else 0)


func _dry_up(game: Node2D) -> void:
	game.slime_remaining = 0.1
	game.slime.position.x += 4.0  # a little glide uses up the last of the slime
	await _frames(5)


## Starts a level as the running scene (so its real end-of-run flow runs).
func _play() -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _frames(count: int) -> void:
	for i in count:
		await process_frame


