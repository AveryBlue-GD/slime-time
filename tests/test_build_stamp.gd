extends "res://tests/suite_base.gd"

## The title's build stamp (tools/ios_build.sh test builds) and its hidden dev switch (owner, 2026-11-01: a phone has
## no launch flags): 5 quick taps on the stamp turn dev mode on for the session (Progress.enable_dev_mode, nothing
## saved). No stamp (every other build): nothing shows and taps do nothing.

const STAMP := "abc1234 11-01 22:40 FULL"
var progress: Node


func _new_title() -> Control:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _physics_frames(2)
	return title


func _reset() -> void:
	progress.dev_tools = false
	progress.saving_enabled = true
	progress.levels_cleared = 1
	progress.highest_unlocked = 2


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	progress.tutorial_seen = 0xFFFF
	Economy.tutorial_force = 0
	var old_version: Variant = ProjectSettings.get_setting("application/config/version", "")
	var real_path: String = progress.save_path

	# --- No stamp: nothing on the title, taps on its corner do nothing
	ProjectSettings.set_setting("application/config/version", "")
	_reset()
	var title := await _new_title()
	_check(title.stamp_label == null and title.get_node_or_null("BuildStamp") == null, "no build stamp: no label")
	for i in 6:
		title._input(_touch(Vector2(12, 5)))
	_check(not progress.dev_tools, "no build stamp: taps in its corner never turn dev mode on")
	title.free()

	# --- A test build's stamp: 5 quick taps on it turn dev mode on
	ProjectSettings.set_setting("application/config/version", STAMP)
	_reset()
	title = await _new_title()
	var label: Label = title.stamp_label
	_check(label != null and label.text == STAMP and label.visible, "a test build shows its stamp")
	var on_stamp: Vector2 = label.get_global_rect().get_center()
	var t := 10.0
	for i in title.DEV_TAPS - 1:
		_check(title.dev_tap(on_stamp, t), "tap %d on the stamp counts" % (i + 1))
		t += 0.3
	_check(not progress.dev_tools, "4 taps: still off")
	_check(not title.dev_tap(Vector2(160, 120), t), "a tap away from the stamp is not counted")
	t += 3.0
	title.dev_tap(on_stamp, t)
	_check(not progress.dev_tools, "a slow 5th tap starts the count over")
	for i in title.DEV_TAPS - 1:
		t += 0.3
		title.dev_tap(on_stamp + Vector2(0, title.DEV_TAP_GROW - 2), t)
	_check(progress.dev_tools and not progress.saving_enabled, "5 quick taps (near the stamp counts): dev mode on, nothing saved")
	_check(progress.highest_unlocked == Levels.COUNT and progress.levels_cleared == Levels.COUNT,
		"...exactly as --dev: every level open")
	_check(label.text == STAMP + title.DEV_MARK, "...and the stamp says DEV")
	_check(progress.save_path == real_path, "the save path is untouched (saving is off, not redirected)")
	title.free()

	# --- Through real input: touches count once (their emulated clicks are skipped), a desktop click counts
	_reset()
	title = await _new_title()
	on_stamp = title.stamp_label.get_global_rect().get_center()
	for i in title.DEV_TAPS - 1:
		title._input(_touch(on_stamp))
		var emulated := _click(on_stamp)
		emulated.device = InputEvent.DEVICE_ID_EMULATION
		title._input(emulated)
	_check(not progress.dev_tools, "4 touches (with their emulated clicks) are 4 taps, not 8")
	title._input(_click(on_stamp))
	_check(progress.dev_tools, "a 5th tap by mouse finishes it")
	title.free()

	# --- A title opened while dev mode is on keeps the DEV mark
	title = await _new_title()
	_check(title.stamp_label.text.ends_with(title.DEV_MARK), "a later title visit shows DEV")
	title.free()

	ProjectSettings.set_setting("application/config/version", old_version)
	Economy.tutorial_force = -1
	_result()


func _touch(pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = true
	return e


func _click(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e
