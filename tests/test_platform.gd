extends "res://tests/suite_base.gd"

## The platform seam (scripts/platform.gd, scripts/platform_events.gd; docs/spring-cleaning/phase5-platform.md):
## every platform branch simulated through Platform.override (desktop, web, iOS, Android, Steam), the Android
## back button (NOTIFICATION_WM_GO_BACK_REQUEST) on every kind of screen, focus loss / backgrounding (a running
## level pauses, its clock and the RACE countdown stop, held inputs are let go), the hub's QUIT trapdoor and the
## SETTINGS FULLSCREEN button per platform, the remembered fullscreen choice, the CONTROLS note, and the safe
## area mapped into the 320x180 view (iPhone home indicator, notches, rounded corners) with simulated rects.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_platform.gd

const SaveText := preload("res://scripts/save_text.gd")
var HUB: PackedScene
var SETTINGS: PackedScene
var KEY_CONTROLS: GDScript

var progress: Node
var events: Node


func _initialize() -> void:
	await process_frame
	HUB = load("res://scenes/hub.tscn")
	SETTINGS = load("res://scenes/controls.tscn")
	KEY_CONTROLS = load("res://scripts/ui/key_controls.gd")
	progress = root.get_node("Progress")
	events = root.get_node("PlatformEvents")
	progress.save_path = throwaway_save()
	progress.enable_story_complete()
	progress.saving_enabled = true
	_kinds()
	await _hub_quit()
	await _settings_fullscreen()
	_fullscreen_memory()
	_controls_note()
	_project_settings()
	_safe_area()
	await _back_button()
	await _background()
	Platform.reset_overrides()
	_result()
	quit(1 if failures else 0)


func _kinds() -> void:
	var rows := {
		"desktop": {web = false, mobile = false, desktop = true, quit = true, full = true, remember = true, steam = false},
		"steam": {web = false, mobile = false, desktop = true, quit = true, full = true, remember = true, steam = true},
		"web": {web = true, mobile = false, desktop = false, quit = false, full = true, remember = false, steam = false},
		"ios": {web = false, mobile = true, desktop = false, quit = false, full = false, remember = false, steam = false},
		"android": {web = false, mobile = true, desktop = false, quit = false, full = false, remember = false, steam = false},
	}
	for kind: String in rows:
		Platform.reset_overrides()
		Platform.override = kind
		var want: Dictionary = rows[kind]
		var got := {web = Platform.is_web(), mobile = Platform.is_mobile_native(), desktop = Platform.is_desktop(),
			quit = Platform.can_quit(), full = Platform.has_window_fullscreen(), remember = Platform.remembers_fullscreen(),
			steam = Platform.is_steam()}
		_check(got == want, "%s: %s" % [kind, got])
	Platform.override = "ios"
	_check(Platform.has_touch() and Platform.is_ios() and not Platform.is_android(), "ios: touch, is_ios")
	Platform.override = "android"
	_check(Platform.has_touch() and Platform.is_android(), "android: touch, is_android")
	Platform.reset_overrides()
	_check(Platform.kind() == "desktop" and not Platform.has_js(), "this test run is a desktop build without browser APIs")
	_check(not Platform.is_steam(), "no Steam build yet: is_steam() is false")


## The QUIT trapdoor exists on desktop (and Steam) only; the room has one station fewer elsewhere.
func _hub_quit() -> void:
	for kind: String in ["desktop", "steam", "web", "ios", "android"]:
		Platform.reset_overrides()
		Platform.override = kind
		var hub: Node2D = HUB.instantiate()
		root.add_child(hub)
		await process_frame
		var has_quit: bool = not hub._station("quit").is_empty()
		_check(has_quit == (kind in ["desktop", "steam"]) and hub.stations.size() == (9 if has_quit else 8),
			"%s: hub QUIT trapdoor %s (%d stations)" % [kind, "shown" if has_quit else "hidden", hub.stations.size()])
		hub.free()
	Platform.reset_overrides()


## FULLSCREEN is disabled (not hidden: the layout stays) where it means nothing.
func _settings_fullscreen() -> void:
	for kind: String in ["desktop", "ios", "android"]:
		Platform.reset_overrides()
		Platform.override = kind
		var screen: Control = SETTINGS.instantiate()
		root.add_child(screen)
		await process_frame
		var disabled: bool = screen.fullscreen_button.disabled
		_check(disabled == (kind != "desktop") and screen.fullscreen_button.visible,
			"%s: SETTINGS FULLSCREEN %s" % [kind, "disabled" if disabled else "enabled"])
		screen.free()
	Platform.reset_overrides()


## [settings] fullscreen: written only when on, read back, kept by RESET PROGRESS; F11 on a phone does nothing.
func _fullscreen_memory() -> void:
	progress.fullscreen = false
	_check(not progress._write().has_section_key("settings", "fullscreen"), "fullscreen off: no key in the save (old saves read as windowed)")
	progress.fullscreen = true
	var file: ConfigFile = progress._write()
	_check(file.get_value("settings", "fullscreen", false) == true, "fullscreen on: [settings] fullscreen = true")
	progress.fullscreen = false
	progress._read(file)
	_check(progress.fullscreen, "the fullscreen choice is read back")
	progress.reset_progress()
	_check(progress.fullscreen, "RESET PROGRESS keeps the fullscreen setting")
	var text: String = file.encode_to_text()
	_check(SaveText.parse(text.to_utf8_buffer()) != null, "a save with the key passes the allow-list")
	progress.fullscreen = false
	Platform.override = "ios"
	var before := DisplayServer.window_get_mode()
	progress.toggle_fullscreen()
	_check(DisplayServer.window_get_mode() == before and not progress.fullscreen, "ios: F11 / FULLSCREEN does nothing")
	Platform.reset_overrides()
	progress.enable_story_complete()
	progress.saving_enabled = true


func _controls_note() -> void:
	Platform.reset_overrides()
	_check(KEY_CONTROLS.note_text() == "ARROWS ALWAYS MOVE - ESC OR P PAUSES - F11 FULLSCREEN", "desktop CONTROLS note unchanged")
	Platform.override = "web"
	_check(KEY_CONTROLS.note_text().contains("P PAUSES") and not KEY_CONTROLS.note_text().contains("ESC"), "web: P pauses (browsers keep Esc)")
	Platform.override = "ios"
	_check(not KEY_CONTROLS.note_text().contains("F11"), "ios: no F11 in the CONTROLS note (%s)" % KEY_CONTROLS.note_text())
	Platform.reset_overrides()
	Platform.last_input = Platform.INPUT_PAD
	_check(KEY_CONTROLS.note_text().begins_with("PAD:") and not KEY_CONTROLS.note_text().contains("ESC"), "pad in use: the note shows the pad layout, no keys")
	Platform.reset_overrides()


func _project_settings() -> void:
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "Android back never quits the app (quit_on_go_back = false)")
	_check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "phones: both landscape sides (sensor landscape)")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "phones use the same renderer as the web (gl_compatibility)")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "desktop renderer unchanged")


## Safe areas, simulated (window size + safe area in screen pixels, as DisplayServer reports them).
func _safe_area() -> void:
	Platform.reset_overrides()
	_check(Platform.safe_rect() == Rect2(0, 0, 320, 180), "desktop: the whole view is safe")
	_check(Platform.safe_insets() == {left = 0, top = 0, right = 0, bottom = 0}, "desktop: no insets")
	# iPhone 15 Pro landscape: 2556x1179, notch 59 pt and home indicator 21 pt at 3x.
	var iphone := Platform.safe_rect_for(Vector2i(2556, 1179), Rect2i(177, 0, 2202, 1116))
	_check(iphone.position == Vector2.ZERO and absf(iphone.end.x - 320.0) < 0.01, "iPhone: the notch is inside the side bars (x %s)" % iphone)
	_check(absf(iphone.end.y - 177.75) < 0.01, "iPhone: the home indicator cuts the view's bottom at y %.2f" % iphone.end.y)
	Platform.override = "ios"
	Platform.window_override = Vector2i(2556, 1179)
	Platform.safe_area_override = Rect2i(177, 0, 2202, 1116)
	_check(Platform.safe_insets() == {left = 0, top = 0, right = 0, bottom = 3}, "iPhone: insets bottom 3 (%s)" % Platform.safe_insets())
	# An exactly 16:9 phone with rounded corners: the view fills the screen, the safe area cuts 2 view px a side.
	Platform.window_override = Vector2i(1920, 1080)
	Platform.safe_area_override = Rect2i(12, 0, 1896, 1080)
	_check(Platform.safe_insets() == {left = 2, top = 0, right = 2, bottom = 0}, "16:9 phone with rounded corners: 2 px left / right (%s)" % Platform.safe_insets())
	Platform.safe_area_override = Rect2i(0, 0, 10, 10)
	_check(Platform.safe_rect() == Rect2(0, 0, 320, 180), "a nonsense safe area is ignored")
	Platform.reset_overrides()
	Platform.safe_area_override = Rect2i(0, 0, 1280, 700)  # a desktop never shrinks, whatever is reported...
	Platform.window_override = Vector2i(1280, 720)
	_check(Platform.safe_rect().end.y == 175.0, "...unless a test simulates it (override honored on any platform)")
	Platform.reset_overrides()
	_check(Platform.safe_rect() == Rect2(0, 0, 320, 180), "overrides reset")


func _go_back() -> void:
	events.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	for i in 6:
		await physics_frame
		await process_frame


func _set_scene(node: Node) -> void:
	paused = false
	root.add_child(node)
	current_scene = node
	await process_frame
	await physics_frame


func _clear_scene() -> void:
	var cs := current_scene
	current_scene = null
	paused = false
	if is_instance_valid(cs):
		cs.free()
	await process_frame


## The Android back button / gesture taps `menu`: a level pauses (and back again resumes), the level select goes
## back to the hub (through the goo wipe), the hub goes to the title, the title ignores it.
func _back_button() -> void:
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 2
	await _set_scene(game)
	await _physics_frames(10)
	await _go_back()
	_check(game.pause_menu.visible and paused, "back in a level opens the pause menu")
	await _go_back()
	_check(not game.pause_menu.visible and not paused, "back again resumes")
	_check(not Input.is_action_pressed("menu"), "the synthesized back press is released")
	await _clear_scene()

	var transition: Node = root.get_node("Transition")
	var select: Node = load("res://scenes/level_select.tscn").instantiate()
	await _set_scene(select)
	await _go_back()
	_check(transition.busy or (current_scene != select), "back on the level select leaves it (to the hub)")
	for i in 120:
		await process_frame
		if not transition.busy:
			break
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/hub.tscn", "...and lands in the hub (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	for i in 30:
		await process_frame
	await _go_back()
	for i in 120:
		await process_frame
		if not transition.busy:
			break
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/title.tscn", "back in the hub goes to the title")
	for i in 30:
		await process_frame
	var title := current_scene
	await _go_back()
	for i in 30:
		await process_frame
	_check(current_scene == title and not transition.busy, "back on the title does nothing (no quit, no screen change)")
	await _clear_scene()


## Focus loss / backgrounding.
func _background() -> void:
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 3
	await _set_scene(game)
	await _physics_frames(30)
	Input.action_press("jump")
	Input.action_press("move_right")
	var touch: TouchControls = game.touch_controls
	touch._press("move_up")
	await _physics_frames(2)
	var clock: float = game.run_time
	events.enter_background(true)
	_check(game.pause_menu.visible and paused, "backgrounded: a running level pauses itself")
	_check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up"),
		"backgrounded: every held input is let go (keys and the touch controls)")
	await _physics_frames(60)
	_check(game.run_time == clock, "backgrounded: the run clock stops (%.3f -> %.3f)" % [clock, game.run_time])
	events.leave_background()
	await _physics_frames(10)
	_check(game.pause_menu.visible and game.run_time == clock, "foreground again: still paused until RESUME")
	game.pause_menu.resume()
	await _physics_frames(10)
	_check(game.run_time > clock, "RESUME: the clock runs again")
	await _clear_scene()

	# RACE: the countdown stops as well.
	progress.hard_mode = true
	progress.heat_mods = Heat.bit("race")
	var race: Node2D = BASE_MAIN.instantiate()
	race.level = 1
	await _set_scene(race)
	await _physics_frames(20)
	if race.race_limit > 0.0:
		var t: float = race.run_time
		events.enter_background(true)
		await _physics_frames(90)
		_check(race.run_time == t and not race.race_over, "backgrounded: the RACE countdown stops")
		events.leave_background()
	else:
		_check(false, "RACE run set up (race_limit %.1f)" % race.race_limit)
	await _clear_scene()
	progress.hard_mode = false
	progress.heat_mods = 0

	# Nothing to pause: a finished level, the hub. Without force (headless), focus loss pauses nothing.
	var done: Node2D = BASE_MAIN.instantiate()
	done.level = 1
	await _set_scene(done)
	done.finished = true
	events.enter_background(true)
	_check(not done.pause_menu.visible and not paused, "a finished level (results showing) is left as it is")
	events.leave_background()
	await _clear_scene()
	var live: Node2D = BASE_MAIN.instantiate()
	live.level = 1
	await _set_scene(live)
	events.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not live.pause_menu.visible and events.in_background, "headless: a real focus loss is noted but never pauses (captures, tests)")
	events.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not events.in_background, "focus back: in the foreground again")
	await _clear_scene()
	var hub: Node2D = HUB.instantiate()
	await _set_scene(hub)
	events.enter_background(true)
	_check(not paused, "the hub is not paused by backgrounding")
	events.leave_background()
	await _clear_scene()

	# A save that failed (disk full) is retried when the app goes away.
	progress.save_failed = true
	events.enter_background(true)
	_check(not progress.save_failed and FileAccess.file_exists(progress.save_path), "backgrounding retries a failed save at once")
	events.leave_background()
