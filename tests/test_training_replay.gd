extends "res://tests/suite_base.gd"

## Tutorial chunk E: SETTINGS has a TRAINING button only with the tutorial gate on; it starts training in
## replay mode (nothing saved). Never touches a real save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_training_replay.gd

var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	var real := ProjectSettings.globalize_path(progress.REAL_SAVE_PATH)
	var real_md5 := FileAccess.get_md5(real) if FileAccess.file_exists(real) else ""
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.reset_progress()
	progress.save_progress()
	Economy.tutorial_force = 0
	change_scene_to_file("res://scenes/controls.tscn")
	await _frames(5)
	_check(current_scene.training_button == null, "gate off: no TRAINING button")
	Economy.tutorial_force = 1
	change_scene_to_file("res://scenes/controls.tscn")
	await _frames(5)
	var page: Control = current_scene
	var b: Button = page.training_button
	_check(b != null and b.text == "TRAINING", "gate on: TRAINING button")
	if b == null:
		quit(1)
		return
	var rect := Rect2(Vector2.ZERO, UIKit.SCREEN)
	_check(rect.encloses(b.get_global_rect()), "inside the screen")
	for other: Button in [page.sound_button, page.motion_button, page.fog_button, page.fullscreen_button, page.controls_button, page.save_code_button, page.reset_button]:
		_check(not b.get_global_rect().intersects(other.get_global_rect()), "no overlap with " + other.text)
	_check(b.focus_mode == Control.FOCUS_ALL and b.get_global_rect().size.y >= UIKit.button_h(), "focusable, full height")
	b.grab_focus()
	_check(b.has_focus(), "takes focus")
	var seen_before: int = progress.tutorial_seen
	var coins_before: Dictionary = progress.coins_found.duplicate(true)
	var maps_before: Dictionary = progress.maps.duplicate(true)
	var save_before := FileAccess.get_file_as_string(test_save)
	b.pressed.emit()
	_check(progress.mode == progress.MODE_TRAINING and progress.training_replay, "pressing it enters the training maze in replay mode (MODE_TRAINING, training_replay)")
	await _frames(240)
	_check(current_scene.scene_file_path != "res://scenes/controls.tscn", "left SETTINGS")
	_check(current_scene.scene_file_path == "res://scenes/main.tscn" and progress.mode == progress.MODE_TRAINING and progress.training_replay, "now in the training maze, still replay")
	_check(progress.tutorial_seen == seen_before, "no tutorial bit written")
	_check(progress.coins_found == coins_before and progress.maps == maps_before, "no coins or surveys changed")
	_check(FileAccess.get_file_as_string(test_save) == save_before, "nothing saved (save file byte-identical)")
	Economy.tutorial_force = -1
	progress.reset_progress()
	_check(real_md5 == "" or FileAccess.get_md5(real) == real_md5, "the real save is untouched")
	_result()
	quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
