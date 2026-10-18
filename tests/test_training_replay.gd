extends SceneTree

## Tutorial chunk E: SETTINGS has a TRAINING button only with the tutorial gate on; it starts training in
## replay mode (nothing saved). Never touches a real save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_training_replay.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
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
	b.pressed.emit()
	_check(progress.training_replay or progress.tour_replay, "pressing it starts training in replay mode (the chunk A stub hands on at once: tour_replay)")
	await _frames(240)
	_check(current_scene.scene_file_path != "res://scenes/controls.tscn", "left SETTINGS")
	_check(progress.tutorial_seen == seen_before, "no tutorial bit written")
	Economy.tutorial_force = -1
	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
