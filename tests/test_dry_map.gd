extends "res://tests/suite_base.gd"

## The dry-up choice row's MAP button (owner, 2026-10-18): story levels only (normal and hard; a random
## maze has no map), last in the row (keyboard order RESTART, UPGRADES, MAP; with the ASSIST offer
## RESTART, ASSIST, UPGRADES, MAP, all inside the screen), RESTART keeps the focus. Pressing it commits the
## dry-up survey, then opens the MAP TABLE in the mode just played with that level's tile focused (its page shown).
## Uses a throwaway save; the real save's md5 is checked unchanged at the end.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_dry_map.gd

const MAIN := preload("res://scenes/main.tscn")
const MAPS := "res://scenes/maps.tscn"
var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.day_override = 40000
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.reset_progress()
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	progress.tutorial_seen = 3

	var game := await _dry(7, false, false)
	_check(_labels(game) == ["RESTART", "UPGRADES", "MAP"], "story dry-up row: %s" % [_labels(game)])
	_check(game.hud.choice_buttons[0].has_focus(), "...RESTART keeps the focus")
	_check(_row_inside(game), "...the row sits inside the screen")
	await _stop(game)

	game = await _dry(1, false, false, true)
	_check(_labels(game) == ["RESTART", "ASSIST", "UPGRADES", "MAP"] and _row_inside(game), "with the ASSIST offer: 4 buttons, inside the screen: %s" % [_labels(game)])
	await _stop(game)

	game = await _dry(0, false, true)
	_check("MAP" not in _labels(game), "a random maze has no MAP button: %s" % [_labels(game)])
	await _stop(game)

	progress.maps = {}
	for hard in [false, true]:
		var lvl := 7
		game = await _dry(lvl, hard, false)
		game.hud.choice_buttons[2].grab_focus()
		await _action("ui_accept")
		var maps: Node = await _until_scene(MAPS)
		_check(maps != null, "MAP opens the MAP TABLE (hard=%s)" % hard)
		if maps == null:
			break
		await _physics_frames(2)
		_check(maps.hard == hard and progress.hard_mode == hard and maps.hard_box.button_pressed == hard, "...in the mode just played (HARD %s)" % hard)
		var focus := maps.get_viewport().gui_get_focus_owner()
		_check(focus != null and focus.has_meta("level") and focus.get_meta("level") == lvl and focus.is_visible_in_tree(),
			"...with level %d's tile focused and its page shown" % lvl)
		_check(not progress.survey_for(lvl, hard).is_empty(), "...the dry-up survey is recorded (the tile is unlocked)")
		_check(not focus.disabled, "...the tile is open")
		maps.queue_free()
		current_scene = null
		await _physics_frames(2)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched")
	_result()
	quit(1 if failures else 0)


## Dries a run up (level 0 = a random maze) and waits for its choice buttons.
func _dry(level: int, hard: bool, random: bool, assist := false) -> Node2D:
	progress.hard_mode = hard
	if random:
		progress.start_random()
	else:
		progress.start_story(level)
	if assist:
		progress.dry_ups[level] = 3
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await _physics_frames(3)
	game.slime_remaining = 0.0
	for i in 120:
		await physics_frame
		if not game.hud.choice_buttons.is_empty() and game.hud.choice_buttons[0].is_visible_in_tree():
			break
	await _physics_frames(3)
	return game


func _labels(game: Node2D) -> Array:
	return game.hud.choice_buttons.map(func(b: Button) -> String: return b.text)


func _row_inside(game: Node2D) -> bool:
	for b: Button in game.hud.choice_buttons:
		var r := b.get_global_rect()
		if r.position.x < 0 or r.end.x > 320:
			return false
	return true


func _stop(game: Node2D) -> void:
	current_scene = null
	game.free()
	await _physics_frames(1)


func _until_scene(path: String) -> Node:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return current_scene
	return null


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _physics_frames(2)
