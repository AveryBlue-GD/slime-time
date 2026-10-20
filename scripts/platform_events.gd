extends Node

## Autoload "PlatformEvents": the platform lifecycle, next to the Platform statics (scripts/platform.gd).
## - Android back button / back gesture (NOTIFICATION_WM_GO_BACK_REQUEST; project.godot sets
##   application/config/quit_on_go_back=false so it never closes the app): a tap of the game's own back key,
##   the `menu` action (Esc / P / Start). Every menu already backs out on it, a level opens its pause menu, the
##   hub goes back to the title and the title ignores it. iOS has no back button: every screen has BACK.
## - Focus loss and backgrounding (NOTIFICATION_APPLICATION_FOCUS_OUT / PAUSED; in a browser also the page's
##   `visibilitychange`): a running level opens its pause menu (so the run clock and the RACE countdown stop:
##   they only tick while the tree runs), every held input is let go (a finger or key held when the app went
##   away never comes back stuck) and a save that failed earlier is retried at once. Coming back releases
##   held inputs again and leaves the pause menu up: the player presses RESUME.
## - The last input device (Platform.last_input), read from every input event before any node sees it, so
##   prompts can name pad buttons, keys or taps (`input_kind_changed`).
## Achievements for Steam or the mobile stores attach to `progress_event` (emitted by Progress.report_progress
## from the save points; see docs/spring-cleaning/phase5-platform.md "Steam seam"). Nothing listens yet.

signal backgrounded
signal foregrounded
signal input_kind_changed(kind: String)
## A progress milestone was saved (Progress.report_progress: id + its new value). The seam for Steam achievements
## and mobile store hooks; nothing listens to it yet.
signal progress_event(id: String, value: int)

## True between a focus loss / backgrounding and the focus coming back.
var in_background := false
## True while in the background where that pauses a level (Platform.pauses_on_focus_loss, or a test's `force`): a
## level that starts meanwhile (its goo wipe was still running) pauses itself once it is in place (game.gd _ease_in).
var pause_wanted := false
## The left stick: its latest position, the 8-way direction it presses (Platform.snap8) and the move actions it
## holds (only those are released by it, as TouchControls does).
const STICK_DEADZONE := 0.35
const STICK_ACTIONS := {move_right = Vector2.RIGHT, move_left = Vector2.LEFT, move_down = Vector2.DOWN, move_up = Vector2.UP}
var stick := Vector2.ZERO
var stick_dir := Vector2.ZERO
var _stick_held := {}
## The browser's visibilitychange listener (kept so it isn't freed).
var _web_visibility: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Platform.frame_cap() > 0:
		Engine.max_fps = Platform.frame_cap()
	get_tree().root.window_input.connect(_on_window_input)
	if Platform.has_js():
		_web_visibility = JavaScriptBridge.create_callback(func(_args: Array) -> void:
			if JavaScriptBridge.eval("document.hidden", true):
				enter_background()
			else:
				leave_background())
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _web_visibility)


func _on_window_input(event: InputEvent) -> void:
	var before := Platform.last_input
	Platform.note_input(event)
	if Platform.last_input != before:
		input_kind_changed.emit(Platform.last_input)
	if event is InputEventJoypadMotion:
		_steer_stick(event)


## The left stick moves like the D-pad / arrows, snapped to 8 directions (exact cardinals keep the lane assist
## and straight leaps working); menus read the stick through Godot's own ui_* events.
func _steer_stick(event: InputEventJoypadMotion) -> void:
	if event.axis == JOY_AXIS_LEFT_X:
		stick.x = event.axis_value
	elif event.axis == JOY_AXIS_LEFT_Y:
		stick.y = event.axis_value
	else:
		return
	var dir := Platform.snap8(stick, STICK_DEADZONE)
	if dir == stick_dir:
		return
	stick_dir = dir
	for action: String in STICK_ACTIONS:
		var strength: float = dir.dot(STICK_ACTIONS[action])
		if strength > 0.05:
			_stick_held[action] = true
			Input.action_press(action, strength)
		elif _stick_held.erase(action):
			Input.action_release(action)


func _notification(what: int) -> void:
	if not is_inside_tree():  # a focus-out can arrive on quit after the autoload has left the tree
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			enter_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			leave_background()


## The system back button: one tap of `menu` (pressed now, released two physics frames later, so both the
## event handlers and the screens that poll Input.is_action_just_pressed see exactly one press).
func go_back() -> void:
	var press := InputEventAction.new()
	press.action = "menu"
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var release := InputEventAction.new()
	release.action = "menu"
	Input.parse_input_event(release)


## The app lost focus or went to the background. `force`: pause even where Platform.pauses_on_focus_loss is
## false (tests, which run headless).
func enter_background(force := false) -> void:
	in_background = true
	release_held_inputs()
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.flush_save()
	pause_wanted = force or (Platform.pauses_on_focus_loss() and get_tree().root.get_node_or_null("Autoplay") == null)
	if pause_wanted:
		var scene := get_tree().current_scene
		if scene and scene.has_method("pause_for_background"):
			scene.pause_for_background()
	backgrounded.emit()


func leave_background() -> void:
	if not in_background:
		return
	in_background = false
	pause_wanted = false
	release_held_inputs()
	foregrounded.emit()


## Lets go of everything held: the touch controls' joystick / JUMP / pause, and every action a key or pad
## button still holds (its release may never arrive once the app is in the background).
func release_held_inputs() -> void:
	get_tree().call_group(TouchControls.GROUP, "release_all")
	stick = Vector2.ZERO
	stick_dir = Vector2.ZERO
	_stick_held.clear()
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
