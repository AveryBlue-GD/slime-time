extends "res://tests/suite_base.gd"

## Flow round: a fresh save's title plays level 1 (PLAY), existing saves keep ENTER THE HUB; a
## dry-up retries quickly and keeps the same randomizer maze; levels 1-2 teach wordlessly (input
## glyph until the first move, SPACE key after wandering without a leap; no chalice beacon even after
## long idling or a dry-up), each remembered in the save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_flow.gd

const MAIN := preload("res://scenes/main.tscn")

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000  # pinned UTC day: the daily pay caps cannot roll over mid-run
	progress.saving_enabled = false
	progress.dev_tools = false

	# --- Title: fresh save -> PLAY -> level 1; existing save -> ENTER THE HUB
	progress.levels_cleared = 0
	progress.tutorial_seen = 0
	progress.story_seen = 0  # even with the intro unseen, PLAY no longer replays it (it plays at launch)
	_check(progress.is_fresh_save(), "a save with nothing cleared is fresh")
	Economy.tutorial_force = 0  # (the tutorial gate's own path, PLAY -> SPLASHDOWN, is test_tutorial_flow's)
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _physics_frames(2)
	_check(title.enter_button.text == "PLAY", "a fresh save's title button says PLAY")
	title.enter_button.pressed.emit()
	await _physics_frames(90)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn" and current_scene.level == 1,
		"PLAY goes straight into level 1 (no intro, tutorial gate off)")
	Economy.tutorial_force = -1
	if current_scene:
		current_scene.free()
	current_scene = null
	title.free()
	progress.levels_cleared = 1
	_check(not progress.is_fresh_save(), "one cleared level ends the fresh state")
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _physics_frames(2)
	_check(title.enter_button.text == "ENTER THE HUB", "an existing save keeps ENTER THE HUB")
	title.free()

	# --- Dry-up: quick buttons, same maze in the randomizer
	progress.start_random()
	progress.random_seed = 4321
	var game: Node2D = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.DRY_CHOICE_DELAY <= 0.3 and game.DRY_CHOICE_DELAY < game.CHOICE_DELAY, "dry-up buttons come up fast")
	game._dry_up()
	await _physics_frames(40)
	var texts: Array = game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)
	_check(texts == ["RESTART", "NEW MAZE", "UPGRADES"], "a random dry-up offers RESTART first, then NEW MAZE and UPGRADES")
	_check(progress.random_seed == 4321 and game.hud.message.text == "DRIED UP", "...and keeps the same maze")
	current_scene = null
	game.free()

	# --- Wordless teaching on level 1
	progress.levels_cleared = 0
	progress.tutorial_seen = 0
	progress.dry_ups = {}
	progress.start_story(1)
	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	var cues: TutorialCues = game.slime.get_node_or_null("TutorialCues") if game.slime.has_node("TutorialCues") else null
	if cues == null:
		for child in game.slime.get_children():
			if child is TutorialCues:
				cues = child
	_check(cues != null, "level 1 has the teaching cues")
	await _physics_frames(30)
	_check(cues.move_alpha > 0.3, "an input glyph shows at the start")
	game.slime.position += Vector2(8, 0)
	await _physics_frames(5)
	_check(cues.idle < 1.0, "moving resets the idle timer")
	await _physics_frames(40)
	_check(cues.move_alpha == 0.0 and progress.has_seen_tutorial(Progress.TUTORIAL_MOVE), "the glyph fades on the first move and is remembered")
	cues.wandered = 100.0
	cues.idle = 2.0
	await _physics_frames(30)
	_check(cues.leap_alpha > 0.3, "after wandering without leaping, the SPACE key shows")
	game.slime.state = Slime.State.CHARGING
	await _physics_frames(3)
	game.slime.state = Slime.State.GLIDE
	await _physics_frames(40)
	_check(cues.leap_alpha == 0.0 and progress.has_seen_tutorial(Progress.TUTORIAL_LEAP), "charging a leap fades it for good")
	# no beacon: a long idle and a dry-up on the level draw nothing once both cues are spent
	cues.idle = 600.0
	progress.dry_ups[1] = 1
	await _physics_frames(90)
	_check(cues.drawn_alpha == 0.0 and cues.move_alpha == 0.0 and cues.leap_alpha == 0.0, "no beacon after a long idle and a dry-up (level 1)")
	cues.queue_redraw()
	await _physics_frames(2)
	current_scene = null
	game.free()

	# --- No cues past level 2, on hard mode, or in the randomizer
	progress.start_story(3)
	game = MAIN.instantiate()
	game.level = 3
	root.add_child(game)
	await physics_frame
	var has_cues := false
	for child in game.slime.get_children():
		has_cues = has_cues or child is TutorialCues
	_check(not has_cues, "level 3 has no teaching cues")
	game.free()

	_result()
	quit(1 if failures else 0)


