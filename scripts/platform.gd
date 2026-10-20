class_name Platform
extends RefCounted

## The platform seam (spring cleaning phase 5, docs/spring-cleaning/phase5-platform.md): every "which platform
## is this / what can it do" question the game asks goes through here, so the iOS / Android / Steam ports
## change one file instead of a dozen scattered `OS.has_feature` checks. Pure statics; the lifecycle side
## (Android back button, focus loss / backgrounding, the last input device) is the PlatformEvents autoload
## (scripts/platform_events.gd).
##
## UI decisions (can the game quit? show FULLSCREEN? which prompt text?) use the overridable queries below.
## Browser APIs (JavaScriptBridge) must only be called when `has_js()` is true: that one is never overridden.
##
## Tests simulate a platform with `Platform.override = "ios"` (or "android", "web", "desktop", "steam") and a
## safe area with `Platform.safe_area_override` / `window_override`; `reset_overrides()` puts it back. In a
## debug build, `-- --platform=ios` (etc.) previews a platform's UI on the desktop (a release build ignores it,
## like every debug flag: Progress.game_args).

const VIEW := Vector2(320, 180)
const FULL_VIEW := Rect2(Vector2.ZERO, VIEW)
## Kinds of the last input device (`last_input`), for prompts: keys / mouse, a gamepad, a touchscreen.
const INPUT_KEYS := "keys"
const INPUT_PAD := "pad"
const INPUT_TOUCH := "touch"
## Stick travel (0..1) that counts as using the pad (smaller is drift / noise).
const PAD_STICK_USE := 0.5

## The fixed default gamepad layout (owner decision D4; button glyphs and remapping come later). Godot's names
## are positional (Xbox / Steam Deck labels): A = bottom face button, B = right, X = left, Y = top.
## Left stick and D-pad move (the stick is snapped to 8 directions by PlatformEvents, like the touch joystick,
## so lanes and straight leaps behave as on keys); A leaps; X uses a hub station; START pauses / goes back;
## VIEW (Back / Select) restarts; LB / Y / RB are the three abilities (1 / 2 / 3); in menus the D-pad and stick
## move the focus (Godot's own ui_* pad events), A presses, B backs out and LB / RB switch tabs.
const PAD_BUTTONS := {
	move_up = [JOY_BUTTON_DPAD_UP], move_down = [JOY_BUTTON_DPAD_DOWN],
	move_left = [JOY_BUTTON_DPAD_LEFT], move_right = [JOY_BUTTON_DPAD_RIGHT],
	jump = [JOY_BUTTON_A], interact = [JOY_BUTTON_X], menu = [JOY_BUTTON_START], restart = [JOY_BUTTON_BACK],
	ability_rifle = [JOY_BUTTON_LEFT_SHOULDER], ability_splat = [JOY_BUTTON_Y], ability_kaze = [JOY_BUTTON_RIGHT_SHOULDER],
	tab_prev = [JOY_BUTTON_LEFT_SHOULDER], tab_next = [JOY_BUTTON_RIGHT_SHOULDER],
	ui_accept = [JOY_BUTTON_A], ui_cancel = [JOY_BUTTON_B],  # (Godot 4.7's defaults give pads no accept / cancel)
}
## Menu actions made at startup (pad only: a keyboard reaches the tabs with the arrows).
const PAD_ONLY_ACTIONS := ["tab_prev", "tab_next"]
## Prompt names of the pad buttons (plain text; glyph art later).
const PAD_NAMES := {jump = "A", interact = "X", menu = "START", restart = "VIEW", ui_cancel = "B", ui_accept = "A",
	ability_rifle = "LB", ability_splat = "Y", ability_kaze = "RB"}

## "" = the real platform; otherwise "desktop", "web", "ios", "android" or "steam" (tests and --platform=).
static var override := ""
## Tests: a display safe area (screen pixels) and window size to use instead of the real ones (Rect2i() /
## Vector2i.ZERO = real).
static var safe_area_override := Rect2i()
static var window_override := Vector2i.ZERO
## The kind of device the player used last (INPUT_*), kept by PlatformEvents from every input event.
static var last_input := INPUT_KEYS
static var _flag_read := false
static var _fullscreen_ok := -1
## Tests: 1 = run as the demo, 0 = the full game, -1 = the real build / launch flag (is_demo).
static var demo_override := -1
static var _demo_flag := -1


## The platform as one word: "web", "ios", "android", "steam" or "desktop".
static func kind() -> String:
	if override != "":
		return override
	if not _flag_read:
		_flag_read = true
		for arg in _user_args():
			if arg.begins_with("--platform="):
				override = arg.trim_prefix("--platform=")
				return override
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("steam"):  # a future Steam export preset sets custom_features="steam"
		return "steam"
	return "desktop"


## Running in a browser (the web build, or the --web-ui preview of its UI).
static func is_web() -> bool:
	return kind() == "web" or "--web-ui" in _user_args()


## A native phone / tablet app (iOS or Android; not a mobile browser, which is_web).
static func is_mobile_native() -> bool:
	return kind() in ["ios", "android"]


static func is_ios() -> bool:
	return kind() == "ios"


static func is_android() -> bool:
	return kind() == "android"


## The key the player's keyboard layout prints on physical key `physical` (Z for W on AZERTY), or `physical`
## itself where the display server can't tell (headless, web, phones: the call only logs an error there).
static func key_label(physical: Key) -> Key:
	if not is_desktop() or DisplayServer.get_name() == "headless":
		return physical
	var shown := DisplayServer.keyboard_get_label_from_physical(physical)
	return shown if shown != KEY_NONE else physical


## The frame-rate cap: 60 on the web and on phones / tablets (physics runs 60 ticks and interpolation stays
## off at 60 fps, so a 120 Hz screen would only run every per-frame cost twice and drain the battery);
## 0 = none (desktop keeps 120 / 144 / 240 Hz smooth). Headless runs (tests) are never capped.
static func frame_cap() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	return 60 if is_web() or is_mobile_native() else 0


## A desktop build (Windows / macOS / Linux, Steam included).
static func is_desktop() -> bool:
	return not is_web() and not is_mobile_native()


## The Steam build (a future export preset with the "steam" feature). Always false today.
static func is_steam() -> bool:
	return kind() == "steam"


## The demo build (docs/demo-plan.md): an export preset with the custom feature `demo`, or the debug launch
## flag `--demo` (tools/play.sh --demo, play.ps1 -Demo; like every flag, a release build ignores it). Every
## demo gate asks this through the Demo class (scripts/demo.gd); with it false the game is the full game.
static func is_demo() -> bool:
	if demo_override >= 0:
		return demo_override == 1
	if OS.has_feature("demo"):
		return true
	if _demo_flag < 0:
		_demo_flag = 1 if "--demo" in _user_args() else 0
	return _demo_flag == 1


## True when browser APIs (JavaScriptBridge) exist. Never overridden: guard every JS call with this.
static func has_js() -> bool:
	return OS.has_feature("web")


## The web build: writes user:// (the in-memory file system) to the browser's IndexedDB now. Godot does it a
## frame after each write anyway; this is for the moment the page may stop running (hidden tab, quit). No-op
## elsewhere.
static func sync_storage() -> void:
	if has_js():
		JavaScriptBridge.force_fs_sync()


## The device has a touchscreen (or the --touch flag / a mobile override asks for touch controls).
static func has_touch() -> bool:
	if is_mobile_native():
		return true
	if override == "" and DisplayServer.is_touchscreen_available():
		return true
	var progress: Node = _progress()
	return progress != null and progress.get("force_touch") == true


## The game may close itself: desktop only. A browser would be left on a dead page, iOS forbids it (Apple HIG)
## and Android has its own back / home. The hub's QUIT trapdoor is only built where this is true.
static func can_quit() -> bool:
	return is_desktop()


## A window that can go fullscreen: desktop, and browsers with the Fullscreen API for page elements (not iPhone
## Safari). Native phones are always fullscreen, so SETTINGS disables its FULLSCREEN button there.
static func has_window_fullscreen() -> bool:
	if is_mobile_native():
		return false
	if not is_web() or not has_js():
		return true
	if _fullscreen_ok < 0:
		var ok: Variant = JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true)
		_fullscreen_ok = 0 if typeof(ok) == TYPE_BOOL and not ok else 1
	return _fullscreen_ok == 1


## The fullscreen choice is remembered between launches (saved [settings] fullscreen): desktop only. A browser
## must not go fullscreen without a click, and phones always are.
static func remembers_fullscreen() -> bool:
	return is_desktop()


## Whether losing focus / going to the background pauses a running level here. True on every platform except
## headless runs and movie captures (a demo capture must not pause because the user clicked another window).
static func pauses_on_focus_loss() -> bool:
	return DisplayServer.get_name() != "headless" and Engine.get_write_movie_path() == ""


## The safe area (no notch, rounded corner or home indicator) in the 320x180 view's own pixels. The whole view
## on desktop and the web (Godot reports the whole screen there anyway); on a phone, the part of the view the
## system leaves clear. See safe_rect_for.
static func safe_rect() -> Rect2:
	if safe_area_override == Rect2i() and not is_mobile_native():
		return Rect2(Vector2.ZERO, VIEW)
	var window := window_override if window_override != Vector2i.ZERO else DisplayServer.window_get_size()
	var area := safe_area_override if safe_area_override != Rect2i() else DisplayServer.get_display_safe_area()
	return safe_rect_for(window, area)


## `area` (screen pixels, from DisplayServer.get_display_safe_area) mapped into the 320x180 view as the window
## shows it: the largest whole multiple (stretch mode `viewport`, scale mode `integer`), centered with black
## bars. Parts of the view outside the safe area are cut off this rect; bars that already cover a notch leave
## it whole. Always inside the view, never empty.
static func safe_rect_for(window: Vector2i, area: Rect2i) -> Rect2:
	if window.x <= 0 or window.y <= 0 or area.size.x <= 0 or area.size.y <= 0:
		return Rect2(Vector2.ZERO, VIEW)
	var scale := maxi(mini(int(window.x / VIEW.x), int(window.y / VIEW.y)), 1)
	var origin := (Vector2(window) - VIEW * scale) / 2.0
	var top_left := ((Vector2(area.position) - origin) / scale).max(Vector2.ZERO)
	var bottom_right := ((Vector2(area.end) - origin) / scale).min(VIEW)
	if bottom_right.x - top_left.x < VIEW.x / 2.0 or bottom_right.y - top_left.y < VIEW.y / 2.0:
		return Rect2(Vector2.ZERO, VIEW)  # (nonsense from a device: ignore it)
	return Rect2(top_left, bottom_right - top_left)


## How far (whole view pixels) the safe area cuts into each side: {left, top, right, bottom}. All 0 on desktop.
static func safe_insets() -> Dictionary:
	var r := safe_rect()
	return {left = ceili(r.position.x), top = ceili(r.position.y), right = ceili(VIEW.x - r.end.x), bottom = ceili(VIEW.y - r.end.y)}


## Notes the device behind `event` (PlatformEvents feeds it every input event, before any node).
static func note_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			last_input = INPUT_PAD
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= PAD_STICK_USE:
			last_input = INPUT_PAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_input = INPUT_TOUCH
	elif event is InputEventKey:
		if event.pressed:
			last_input = INPUT_KEYS
	elif event is InputEventMouseButton:
		if event.pressed:
			last_input = INPUT_TOUCH if event.device == InputEvent.DEVICE_ID_EMULATION else INPUT_KEYS


## True when the last input came from a gamepad (prompts then name pad buttons, not keys).
static func using_pad() -> bool:
	return last_input == INPUT_PAD


## Adds the fixed pad layer (PAD_BUTTONS) to the input map; Progress.apply_bindings calls it after setting the
## keys (which erases every event of a remappable action). Never adds an event twice.
static func apply_pad_layout() -> void:
	for action: String in PAD_ONLY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for action: String in PAD_BUTTONS:
		if not InputMap.has_action(action):
			continue
		for button: JoyButton in PAD_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			event.device = -1  # any pad
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


## What a prompt calls the control for `action` on the device in use: the pad button after pad input, else
## `key_text` (the bound key's name, or TAP JUMP on touch: the callers know their own key / touch wording).
static func prompt_for(action: String, key_text: String) -> String:
	if using_pad() and PAD_NAMES.has(action):
		return PAD_NAMES[action]
	return key_text


## `v` (a stick) snapped to one of 8 directions (cardinals exact, diagonals normalized), or zero inside
## `deadzone` (a share of full travel).
static func snap8(v: Vector2, deadzone: float) -> Vector2:
	if v.length() <= deadzone:
		return Vector2.ZERO
	var angle := snappedf(v.angle(), PI / 4.0)
	return Vector2(roundf(cos(angle)), roundf(sin(angle))).normalized()


static func reset_overrides() -> void:
	override = ""
	_flag_read = true
	safe_area_override = Rect2i()
	window_override = Vector2i.ZERO
	last_input = INPUT_KEYS
	demo_override = -1


## The flags after `--` this build honors (Progress.user_args: every flag in a debug build, only the UI previews
## --touch / --web-ui in a release export). Loaded by path: this file must not depend on the autoloads.
static func _user_args() -> PackedStringArray:
	return load("res://scripts/progress.gd").user_args()


static func _progress() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Progress") if tree else null
