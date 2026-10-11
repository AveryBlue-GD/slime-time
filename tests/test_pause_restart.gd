extends SceneTree

## Pausing during the automatic restart after a dry-up: the countdown waits while paused (the
## level doesn't reload underneath the pause menu and come back frozen), resuming lets it
## restart, and quitting to the title from the pause menu cancels the restart and lands on an
## unpaused title screen.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_pause_restart.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false

	# --- Pause during the restart countdown, then resume
	var game := await _play()
	game.slime_remaining = 0.1
	game.slime.position.x += 4.0  # a little glide uses up the last of the slime
	await _frames(5)
	_check(game.finished and not game.won, "the slime dries up")
	game.pause_menu.open()
	await _frames(int(game.END_DELAY * 60) + 60)
	_check(current_scene == game and paused and game.pause_menu.visible,
		"while paused the level doesn't restart underneath the pause menu")
	game.pause_menu.resume()
	await _frames(int(game.END_DELAY * 60) + 30)
	_check(current_scene != game and current_scene != null and not paused, "after resuming it restarts, unpaused")
	var restarted: Node = current_scene

	# --- Quit to the title during the countdown
	restarted.slime_remaining = 0.1
	restarted.slime.position.x += 4.0
	await _frames(5)
	restarted.pause_menu.open()
	restarted.pause_menu._quit()
	await _frames(int(restarted.END_DELAY * 60) + 60)
	_check(current_scene != null and current_scene.scene_file_path == UIKit.TITLE_SCENE and not paused,
		"quitting to the title mid-restart lands on the title, not a frozen level (%s)" % (current_scene.scene_file_path if current_scene else "none"))

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## Starts a level as the running scene (so its real restart flow runs).
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


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
