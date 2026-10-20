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
	await _title_quit()
	await _settings_fullscreen()
	_fullscreen_memory()
	_progress_events()
	_controls_note()
	_project_settings()
	_safe_area()
	await _safe_area_ui()
	await _back_button()
	await _background()
	await _background_during_wipe()
	_fullscreen_sync()
	await _home_icon()
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
	# Frame cap: 60 on web / phones, none on desktop; never in a headless run (tests run as fast as they can).
	var caps := {}
	for kind: String in rows:
		Platform.override = kind
		caps[kind] = Platform.frame_cap()
	_check(caps.values().all(func(c: int) -> bool: return c == 0) and Engine.max_fps == 0, "headless: no frame cap on any platform (%s)" % caps)
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


## The title's QUIT follows the trapdoor's rule (Platform.can_quit): desktop / Steam only; elsewhere STORY's
## bottom row has no QUIT and the focus chain is ENTER <-> STORY.
func _title_quit() -> void:
	for kind: String in ["desktop", "steam", "web", "ios", "android"]:
		Platform.reset_overrides()
		Platform.override = kind
		var title: Control = load("res://scenes/title.tscn").instantiate()
		root.add_child(title)
		await process_frame
		var shown: bool = title.quit_button != null and title.quit_button.is_visible_in_tree()
		_check(shown == (kind in ["desktop", "steam"]), "%s: title QUIT %s" % [kind, "shown" if shown else "hidden"])
		var story: Button = title.story_button
		_check(story.get_node(story.focus_neighbor_right) == (title.quit_button if shown else story), "%s: STORY's right neighbour" % kind)
		title.free()
	Platform.reset_overrides()


## FULLSCREEN on desktop (enabled) and on a desktop-sized web page; phones and tablets get VIBRATION in its cell
## (a saved setting, on by default, toggled there).
func _settings_fullscreen() -> void:
	for kind: String in ["desktop", "ios", "android"]:
		Platform.reset_overrides()
		Platform.override = kind
		var screen: Control = SETTINGS.instantiate()
		root.add_child(screen)
		await process_frame
		if kind == "desktop":
			_check(screen.fullscreen_button != null and not screen.fullscreen_button.disabled and screen.vibration_button == null,
				"desktop: SETTINGS FULLSCREEN enabled, no VIBRATION")
		else:
			var vib: Button = screen.vibration_button
			_check(screen.fullscreen_button == null and vib != null and vib.position == screen._cell(1, 0) and vib.text == "VIBRATION: ON",
				"%s: SETTINGS VIBRATION: ON in FULLSCREEN's cell" % kind)
			vib.pressed.emit()
			_check(not progress.vibration and vib.text == "VIBRATION: OFF", "%s: ...a press turns it off" % kind)
			vib.pressed.emit()
			_check(progress.vibration, "%s: ...and on again" % kind)
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


## The Steam seam: saved milestones are reported on PlatformEvents.progress_event (nothing listens yet).
func _progress_events() -> void:
	var got: Array = []
	var take := func(id: String, value: int) -> void: got.append([id, value])
	events.progress_event.connect(take)
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.coins_found.erase(1)
	progress.collect_coin(1, Vector2i(3, 3))
	_check(got.size() == 1 and got[0][0] == "coins" and got[0][1] == progress.coins_earned(), "a coin found reports coins (%s)" % [got])
	progress.dev_tools = true
	progress.collect_coin(1, Vector2i(5, 5))
	_check(got.size() == 1, "dev mode reports nothing")
	progress.dev_tools = false
	events.progress_event.disconnect(take)


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


## The safe area applied: bottom-row touch margins stop above an iPhone's home indicator, the floating joystick
## stays out of it, and HUD pods (and the touch pause button) move in where a phone's safe area cuts the sides.
## Desktop: unchanged.
func _safe_area_ui() -> void:
	var screen: Control = SETTINGS.instantiate()
	root.add_child(screen)
	await process_frame
	var back: TouchButton = null
	for child in screen.get_children():
		if child is TouchButton and child.text == "BACK":
			back = child
	UIKit.touch_in_use = true
	var below := Vector2(back.global_rect().get_center().x, back.global_rect().end.y + 1.5)  # y 178.5: in the grown margin
	_check(back.claims(below), "desktop: BACK's grown touch margin reaches y %.1f" % below.y)
	Platform.override = "ios"
	Platform.window_override = Vector2i(2556, 1179)
	Platform.safe_area_override = Rect2i(177, 0, 2202, 1116)
	_check(not back.claims(below) and back.claims(below - Vector2(0, 1.0)), "iPhone: the margin stops at the home indicator (y 177.75)")
	UIKit.touch_in_use = false
	screen.free()

	var touch := TouchControls.new()
	_check(touch.joystick_center_for(Vector2(40, 179)).y <= 177.75 - TouchControls.JOY_RADIUS, "iPhone: the joystick never opens in the home-indicator strip")
	touch.free()

	# A phone whose safe area cuts 4 view px off each side (24 px at 6x): pods and the pause button move in.
	Platform.window_override = Vector2i(1920, 1080)
	Platform.safe_area_override = Rect2i(24, 0, 1872, 1080)
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await process_frame
	await process_frame
	var rects: Array[Rect2] = game.hud.pod_rects()
	var right_edge := 0.0
	for r in rects:
		if r.position.x > 200.0:
			right_edge = maxf(right_edge, r.end.x)
	_check(rects[0].position.x == 5.0 and right_edge == 315.0, "safe area 4 px a side: HUD pods 5 px in (left %s, right edge %.0f)" % [rects[0], right_edge])
	_check(game.touch_controls.pause_rect.position.x == TouchControls.PAUSE_RECT.position.x - 2.0, "...and the touch pause button with them")
	game.free()
	Platform.reset_overrides()
	game = BASE_MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await process_frame
	await process_frame
	rects = game.hud.pod_rects()
	_check(rects[0].position.x == 3.0 and rects[0].position.y == 3.0 and game.touch_controls.pause_rect == TouchControls.PAUSE_RECT, "desktop: pods and pause where they were (3 px)")
	game.free()
	await process_frame


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
## back to the hub (through the goo wipe), the hub opens its menu (back again closes it), the title ignores it.
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
	var hub: Node = current_scene
	await _go_back()
	_check(hub.hub_menu.visible and not transition.busy, "back in the hub opens the hub menu (as Esc)")
	await _go_back()
	_check(not hub.hub_menu.visible and current_scene == hub, "back again closes it")
	await _go_back()
	hub.menu_quit.pressed.emit()
	for i in 120:
		await process_frame
		if not transition.busy:
			break
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/title.tscn", "...its QUIT TO TITLE goes to the title")
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
	progress.save_failed = true
	events.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not progress.save_failed, "closing the window (close request) retries a failed save first")
	events.leave_background()


## QA phase 5 #2: the app goes to the background during the goo wipe into a level (pause_for_background skips a
## screen change): the level pauses itself once the wipe is over, so its run clock never runs unattended.
func _background_during_wipe() -> void:
	var transition: Node = root.get_node("Transition")
	progress.mode = progress.MODE_STORY
	progress.current_level = 1
	paused = false
	transition.go("res://scenes/main.tscn")
	await process_frame
	_check(transition.busy, "the wipe into a level is underway")
	events.enter_background(true)
	for i in 120:
		await physics_frame
	var game := current_scene
	var is_level: bool = game != null and game.scene_file_path == "res://scenes/main.tscn"
	_check(is_level and paused and game.pause_menu.visible, "backgrounded during the wipe: the level pauses once it is in place")
	_check(is_level and game.run_time < 0.1, "...and its clock does not run (%.2f s)" % (game.run_time if is_level else -1.0))
	events.leave_background()
	await _physics_frames(5)
	_check(is_level and paused, "foreground again: still paused until RESUME")
	await _clear_scene()
	# Not backgrounded: the level starts unpaused, as before.
	transition.go("res://scenes/main.tscn")
	for i in 60:
		await physics_frame
	_check(current_scene != null and not paused and not current_scene.pause_menu.visible, "a wipe in the foreground starts the level unpaused")
	await _clear_scene()


## QA phase 5 #4: the window leaves (or enters) fullscreen without F11 (macOS green button): the remembered choice
## follows the window mode on desktop only.
func _fullscreen_sync() -> void:
	Platform.reset_overrides()
	Platform.override = "desktop"
	progress.fullscreen = true
	progress.save_progress()
	_check(progress.window_mode_changed(DisplayServer.WINDOW_MODE_WINDOWED) and not progress.fullscreen, "desktop: leaving fullscreen by the OS clears the choice")
	var file := ConfigFile.new()
	file.load(progress.save_path)
	_check(not file.get_value("settings", "fullscreen", false), "...and saves it")
	_check(not progress.window_mode_changed(DisplayServer.WINDOW_MODE_MAXIMIZED) and not progress.fullscreen, "a maximized window is not fullscreen")
	_check(progress.window_mode_changed(DisplayServer.WINDOW_MODE_FULLSCREEN) and progress.fullscreen, "entering fullscreen by the OS sets it")
	file.load(progress.save_path)
	_check(file.get_value("settings", "fullscreen", false) == true, "...and saves it")
	_check(not progress.window_mode_changed(DisplayServer.WINDOW_MODE_FULLSCREEN), "the same mode again changes nothing")
	for kind: String in ["web", "ios", "android"]:
		Platform.override = kind
		_check(not progress.window_mode_changed(DisplayServer.WINDOW_MODE_WINDOWED) and progress.fullscreen, "%s: the window mode is not remembered" % kind)
	Platform.reset_overrides()
	progress.fullscreen = false
	progress.save_progress()


## Owner decision D10: on iOS / Android the hub's touch pause button (it goes to the title) draws a home icon; desktop,
## web and levels keep the pause bars (there its tap presses `menu`, as Esc: the hub menu opens).
func _home_icon() -> void:
	for kind: String in ["desktop", "web", "ios", "android"]:
		Platform.reset_overrides()
		Platform.override = kind
		var hub: Node2D = HUB.instantiate()
		await _set_scene(hub)
		var home: bool = hub._touch_controls.home_icon
		_check(home == (kind in ["ios", "android"]), "%s: hub touch button draws %s" % [kind, "a home icon" if home else "pause bars"])
		var at: Vector2 = TouchControls.PAUSE_RECT.get_center()
		hub._touch_controls._touch_down(0, at)
		await physics_frame
		await physics_frame
		hub._touch_controls._touch_up(0, at)
		await physics_frame
		if home:
			_check(hub.slime.frozen and not hub.hub_menu.visible and root.get_node("Transition").busy,
				"%s: the home button goes straight to the title (no hub menu)" % kind)
			for i in 120:
				await process_frame
				if not root.get_node("Transition").busy:
					break
		else:
			_check(hub.hub_menu.visible and hub.slime.frozen, "%s: the pause button opens the hub menu, as Esc" % kind)
		await _clear_scene()
	var game: Node2D = BASE_MAIN.instantiate()
	game.level = 1
	await _set_scene(game)
	_check(not game.touch_controls.home_icon, "ios: a level keeps the pause bars")
	await _clear_scene()
	Platform.reset_overrides()
	# Both glyphs are 7 px tall, inside the 15x13 rect and centred on it (ui-rules: whole pixels, centred ink).
	for glyph: Array in [TouchControls.PAUSE_PIXELS, TouchControls.HOME_PIXELS]:
		var ink := Rect2i(glyph[0])
		for r: Rect2i in glyph:
			ink = ink.merge(r)
		_check(Rect2i(Vector2i.ZERO, Vector2i(TouchControls.PAUSE_RECT.size)).encloses(ink) and ink.position == Vector2i(4, 3) and ink.end == Vector2i(11, 10),
			"pause-button glyph ink %s centred in the rect" % ink)
