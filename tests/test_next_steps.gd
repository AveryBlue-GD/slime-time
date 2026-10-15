extends "res://tests/suite_base.gd"

## After-win choices: story wins offer REPLAY / NEXT LEVEL (CONTINUE after level 10) / HUB, random
## wins offer REPLAY MAZE / NEW MAZE / HUB; each button loads the right thing (HUB lands in front of
## the station the run came from). Dry-ups offer RESTART / UPGRADES. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_next_steps.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.save_path = test_save
	progress.levels_cleared = 0
	progress.highest_unlocked = 1
	progress.best_times = {}
	progress.skin_notices_seen.assign([1, 2, 3, 10])

	# Story win -> NEXT LEVEL loads level 2.
	var game := await _spawn_story(1)
	await _win(game)
	_check(_texts(game) == ["REPLAY", "NEXT LEVEL", "HUB"], "a story win offers REPLAY, NEXT LEVEL and HUB (%s)" % [_texts(game)])
	_check(game.hud.choice_buttons[1].has_focus(), "NEXT LEVEL is focused for keyboard players")
	_check(not game.touch_controls.visible, "touch controls get out of the way of the buttons")
	game.hud.choice_buttons[1].pressed.emit()
	var next := await _new_scene(game)
	_check(next.level == 2, "NEXT LEVEL loads level 2 (got %d)" % next.level)
	_drop(next)

	# Story win -> REPLAY loads the same level (even though progress moved on).
	game = await _spawn_story(1)
	await _win(game)
	game.hud.choice_buttons[0].pressed.emit()
	next = await _new_scene(game)
	_check(next.level == 1, "REPLAY loads the same level again (got %d)" % next.level)
	_drop(next)

	# Story win -> HUB goes back to the hub, in front of the archway.
	game = await _spawn_story(1)
	await _win(game)
	game.hud.choice_buttons[2].pressed.emit()
	for i in 180:
		await process_frame
		if current_scene != game and current_scene != null:
			break
	var hub_script: GDScript = load("res://scripts/hub.gd")
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/hub.tscn" and hub_script.get("return_to") == "story",
		"HUB goes back to the hub, facing the story archway")
	if current_scene and current_scene != game:
		var hub := current_scene
		current_scene = null
		hub.free()
	if is_instance_valid(game):
		game.free()

	# Last level -> REPLAY / CONTINUE.
	progress.levels_cleared = 9
	progress.highest_unlocked = 10
	game = await _spawn_story(10)
	await _win(game)
	_check(_texts(game) == ["REPLAY", "CONTINUE", "HUB"], "after level 10: REPLAY, CONTINUE (to the victory screen) and HUB")
	_check("TIME" in game.hud.message.text, "the level 10 message still shows your time")
	await _drop_running(game)

	# Random win -> REPLAY MAZE keeps the seed, NEW MAZE changes it.
	game = await _spawn_random(4242)
	await _win(game)
	_check(_texts(game) == ["REPLAY MAZE", "NEW MAZE", "HUB"], "a random win offers REPLAY MAZE, NEW MAZE and HUB")
	game.hud.choice_buttons[0].pressed.emit()
	next = await _new_scene(game)
	_check(next.random_seed == 4242, "REPLAY MAZE plays the same maze")
	await _win(next)
	next.hud.choice_buttons[1].pressed.emit()
	var newer := await _new_scene(next)
	_check(newer.random_seed != 4242, "NEW MAZE plays a different maze")
	_drop(newer)

	# Dry-up: RESTART or go spend coins on UPGRADES.
	game = await _spawn_story(1)
	game.slime_remaining = 0.2
	var open_action := StartDirs.action(StartDirs.open_dir(game.maze, game.maze.start))
	Input.action_press(open_action)
	await _physics_frames(20)
	Input.action_release(open_action)
	await _physics_frames(int(game.CHOICE_DELAY * 60) + 5)
	_check(game.finished and _texts(game) == ["RESTART", "UPGRADES"], "drying up offers %s" % [_texts(game)])
	_check(not game.won, "...and it's not a win")
	_drop(game)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


func _spawn_story(level: int) -> Node2D:
	progress.start_story(level)
	return await _spawn({level = level})


func _spawn_random(seed_value: int) -> Node2D:
	progress.start_random()
	progress.random_seed = seed_value
	return await _spawn({random_seed = seed_value})


## A game as the current scene, so its real end-of-maze flow runs.
func _spawn(settings: Dictionary) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


## Wins and waits for the replay / next buttons.
func _win(game: Node2D) -> void:
	game.slime.position = game.goal.position
	await _physics_frames(int(game.CHOICE_DELAY * 60) + 10)


## Waits for a button's scene reload and returns the new level scene.
func _new_scene(old: Node2D) -> Node2D:
	for i in 10:
		await process_frame
		if current_scene != old and current_scene != null:
			break
	await physics_frame
	return current_scene


func _drop(game: Node2D) -> void:
	current_scene = null
	game.free()


## Detaches a game before any automatic retry fires, then frees it.
func _drop_running(game: Node2D) -> void:
	current_scene = null
	await _physics_frames(int(game.CHOICE_DELAY * 60) + 10)
	game.free()


func _texts(game: Node2D) -> Array:
	return game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)


