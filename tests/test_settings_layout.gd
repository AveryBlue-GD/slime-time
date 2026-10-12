extends SceneTree

## Settings and Controls pages: no interactive control overlaps another, all sit inside the
## 320x180 screen, and the VOLUME slider answers to the mouse, keys and wheel.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_settings_layout.gd

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
	var page: Control = current_scene
	_check_layout(page, "settings")
	page.code_panel.visible = true
	_check_layout(page.code_panel, "settings SAVE CODE panel")
	page.code_panel.visible = false
	page.reset_confirm.visible = true
	_check_layout(page.reset_confirm, "settings RESET confirm panel")
	page.reset_confirm.visible = false
	await _frames(2)
	await _check_slider(page, progress)
	page.controls_button.pressed.emit()
	await _frames(240)
	_check_layout(current_scene, "controls")
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _interactive(node: Node, out: Array) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is HSlider or node is LineEdit):
		out.append(node)
	for child in node.get_children():
		_interactive(child, out)


## (A modal panel is checked on its own: it covers and blocks the page behind it.)
func _check_layout(page: Control, name: String) -> void:
	var found := []
	_interactive(page, found)
	var screen := Rect2(0, 0, 320, 180)
	var overlaps := []
	var outside := []
	for i in found.size():
		var a: Rect2 = found[i].get_global_rect()
		if not screen.encloses(a):
			outside.append(str(found[i].name, a))
		for j in range(i + 1, found.size()):
			if a.intersects(found[j].get_global_rect()):
				overlaps.append("%s%s x %s%s" % [found[i].name, a, found[j].name, found[j].get_global_rect()])
	_check(found.size() >= 2, "%s: %d controls found" % [name, found.size()])
	_check(overlaps.is_empty(), "%s: no overlapping controls %s" % [name, overlaps])
	_check(outside.is_empty(), "%s: all controls on screen %s" % [name, outside])


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _check_slider(page: Control, progress: Node) -> void:
	var slider: HSlider = page.volume_slider
	var rect := slider.get_global_rect()
	_check(rect.size.x >= 40 and rect.size.y >= 8, "slider is a usable size %s" % rect)
	_check(not rect.intersects(page.save_code_button.get_global_rect()), "slider is clear of SAVE CODE")
	var seen := {}
	for fraction in [0.25, 0.75, 0.5]:
		slider.value = 0.0 if fraction != 0.25 else 1.0  # start far from the target
		await process_frame
		var at := Vector2(rect.position.x + rect.size.x * fraction, rect.position.y + rect.size.y * 0.5)
		await _click(at)
		seen[fraction] = progress.volume
		_check(absf(progress.volume - fraction) < 0.2, "click at %d%% sets volume near it (got %.2f)" % [fraction * 100, progress.volume])
	slider.grab_focus()
	var before: float = slider.value
	var key := InputEventKey.new()
	key.keycode = KEY_LEFT
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(slider.value < before and is_equal_approx(progress.volume, slider.value), "left key lowers volume")
	key = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(is_equal_approx(slider.value, before), "right key raises it back")
	before = slider.value
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = rect.get_center()
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	await _frames(2)
	_check(slider.value != before, "mouse wheel changes volume")


func _frames(n: int) -> void:
	for i in n:
		await process_frame
