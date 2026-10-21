extends SceneTree

## Settings -> CONTROLS page -> rebind a key -> BACK -> settings. Never touches a real save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_settings_nav.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
	change_scene_to_file("res://scenes/controls.tscn")
	await _frames(5)
	var settings: Control = current_scene
	_check(settings.controls_button != null and settings.controls_button.text == "CONTROLS", "settings has one CONTROLS button")
	_check(not settings.has_method("_start_rebind"), "...and no key rows of its own")
	settings.controls_button.pressed.emit()
	await _frames(240)
	var page: Control = current_scene
	_check(page.scene_file_path == "res://scenes/key_controls.tscn" and page.key_buttons.size() == 10, "CONTROLS opens the key page")
	page._start_rebind("jump")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_J
	page._input(event)
	_check(progress.bindings["jump"] == KEY_J, "a key can be rebound there")
	page._on_reset()
	_check(progress.bindings["jump"] == KEY_SPACE, "RESET KEYS restores it")
	var esc := InputEventAction.new()
	esc.action = "menu"
	esc.pressed = true
	page._unhandled_input(esc)  # Esc goes back to settings
	await _frames(240)
	_check(current_scene.scene_file_path == "res://scenes/controls.tscn", "Esc returns to settings")
	current_scene.controls_button.pressed.emit()
	await _frames(240)
	current_scene.back_button.pressed.emit()
	await _frames(240)
	_check(current_scene.scene_file_path == "res://scenes/controls.tscn", "BACK returns to settings")
	# RESET PROGRESS (confirmed) starts over like a first launch: the story intro plays again.
	progress.dev_tools = false
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	current_scene._reset()
	await _frames(60)
	_check(current_scene.scene_file_path == "res://scenes/story.tscn" and current_scene.mode == "intro" and not progress.has_seen_story(progress.STORY_INTRO),
		"RESET PROGRESS replays the story intro")
	current_scene.finish()
	await _frames(240)
	_check(current_scene.scene_file_path == Story.launch_next(progress), "...and then goes where a first launch goes (%s)" % current_scene.scene_file_path)
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
