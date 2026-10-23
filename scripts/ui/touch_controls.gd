class_name TouchControls
extends CanvasLayer

## On-screen controls for phones and tablets. They press the same input actions as the keyboard:
## - left half of the screen: a floating joystick (appears under the thumb), snapped to 8
##   directions so the slime's lane assist still lines it up with corridors
## - right half: the JUMP button (hold to charge, aim with the joystick, release to leap)
## - top-right corner: pause
## - ABILITIES (when the run has any): a small round button each, in a cluster left of the JUMP zone
##   (ABILITY_SLOTS: each ability has its own spot, SLIMAKAZE the farthest from JUMP), with its icon
##   and uses left; an ability fires on RELEASE, and only if the finger is still on its button (slide
##   off to cancel). With buttons shown JUMP catches the right strip x >= JUMP_ZONE_X (not the whole
##   right half), and a DEAD_RING gap between that zone and the buttons does nothing, so a thumb that
##   misses JUMP still leaps (or does nothing) and never fires an ability.
## Shown on touchscreens (Platform.has_touch: also the --touch debug flag); hidden again when a keyboard or a
## gamepad is used.

const SCREEN := Vector2(320, 180)
## Every TouchControls is in this group (PlatformEvents lets go of their held inputs when the app goes away).
const GROUP := "touch_controls"
const JOY_RADIUS := 20.0
const KNOB_RADIUS := 8.0
## Joystick dead zone, as a share of its radius.
const DEADZONE := 0.35
const JOY_HOME := Vector2(40, 140)
## Mirrors the joystick's home (40, 140): both 40 px in from their side edge, on one center line.
const JUMP_CENTER := Vector2(280, 140)
const JUMP_RADIUS := 19.0
## Room kept between the JUMP word's ink and the ring (jump_radius grows the circle to keep it).
const JUMP_TEXT_CLEAR := 2.0
const PAUSE_RECT := Rect2(302, 35, 15, 13)
## Where the pause button really is: PAUSE_RECT, moved down under the randomizer's taller attempt
## pod by game.gd (`pause_rect.position.y = PAUSE_Y_RANDOM`).
const PAUSE_Y_RANDOM := 44.0
var pause_rect := PAUSE_RECT
## Draws a small house instead of the pause bars (owner decision D10): the hub sets it on iOS / Android, where its
## button goes back to the title (and its STORY replay). Same rect and tap.
var home_icon := false:
	set(value):
		home_icon = value
		if _canvas:
			_canvas.queue_redraw()
const PAUSE_TOUCH_MARGIN := 5.0
## The pause (or home) button was tapped; emitted just before its `menu` press (the hub tells its home tap
## from Esc by it).
signal pause_tapped
## Set by a scene whose things are tapped (the hub: the station you stand at): true if a touch at `pos` lands on one,
## so it goes to `tapped` (on release) instead of the joystick or JUMP.
var tap_claim := Callable()
signal tapped(pos: Vector2)
var _tap_touch := -1
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
## ABILITIES: each ability's button center, in Abilities order (rifle, splat, kaze: the cheapest
## nearest the thumb, SLIMAKAZE farthest), and the radius (the hit disc is ABILITY_HIT).
const ABILITY_SLOTS: Array[Vector2] = [Vector2(207, 150), Vector2(207, 122), Vector2(181, 136), Vector2(181, 108)]
const ABILITY_RADIUS := 11.0
const ABILITY_HIT := ABILITY_RADIUS + 2.0
## With ability buttons shown, JUMP catches every touch at x >= JUMP_ZONE_X (the full height, the
## letterbox beyond the right edge too; minus pause); without them the whole right half as before.
const JUMP_ZONE_X := 228.0
## The gap kept between JUMP's catch zone and every ability hit disc: touches there do nothing.
const DEAD_RING := 8.0
## [{id, left, max}] from AbilityRunner.strip (empty: no buttons).
var abilities: Array[Dictionary] = []
## Finger -> the ability (index in `abilities`) it went down on, and where it is now; it fires on
## release, if still on that button.
var _ability_touch := {}
var _ability_pos := {}
## Emitted when a touch is released on the ability button it went down on (AbilityRunner.use).
signal ability_tapped(id: String)

var joy_vector := Vector2.ZERO
var _joy_touch := -1
var _joy_center := JOY_HOME
var _jump_touch := -1
## The finger on the pause button: its `menu` press is released when it lifts (or the level pauses /
## the controls go away), so the action is never left held.
var _pause_touch := -1
## The actions these controls are holding down. Only those are ever released here, so a key
## pressed on a keyboard (which hides the controls) keeps its own press of the same action.
var _held := {}
var _canvas: Control


func _ready() -> void:
	layer = 15
	add_to_group(GROUP)
	# A phone whose safe area cuts into the view: pause follows the HUD pods in (UIKit.hud_edge).
	var shift := UIKit.hud_edge() - Vector2i(UIKit.HUD_EDGE, UIKit.HUD_EDGE)
	pause_rect.position += Vector2(-shift.x, shift.y)
	# ...and under the two rows of pods as they grow for a taller script (pod_h(): POD_H in English).
	pause_rect.position.y += 2 * (UIKit.pod_h() - UIKit.POD_H)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	visible = Platform.has_touch()


## True while a hub panel with buttons is open: touches pass through to it, and the joystick and JUMP are not
## drawn over it (they do nothing meanwhile).
var menu_open := false:
	set(value):
		menu_open = value
		if value:
			_release_all()  # a finger still down when the panel opens must not stick
		if _canvas:
			_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if menu_open:
		return
	if (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and visible:
		_release_all()
		visible = false  # someone is using a keyboard or a gamepad
		return
	if event is InputEventScreenTouch:
		visible = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _joy_touch:
		_move_joystick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _ability_touch.has(event.index):
		_ability_pos[event.index] = event.position  # (the held look follows the finger on / off)
		_canvas.queue_redraw()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pausing (or leaving the level) mid-touch must not leave the slime moving or charging.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release_all()


func _touch_down(index: int, pos: Vector2) -> void:
	var slot := ability_at(pos)
	if slot >= 0:
		_ability_touch[index] = slot
		_ability_pos[index] = pos
	elif pause_rect.grow(PAUSE_TOUCH_MARGIN).has_point(pos):
		_release_pause()  # (a second finger on it: the first one's press ends)
		_pause_touch = index
		pause_tapped.emit()
		var pause := InputEventAction.new()
		pause.action = "menu"
		pause.pressed = true
		Input.parse_input_event(pause)
	elif _tap_touch == -1 and tap_claim.is_valid() and tap_claim.call(pos):
		_tap_touch = index
	elif pos.x < SCREEN.x / 2.0:
		if _joy_touch == -1:
			_joy_touch = index
			_joy_center = joystick_center_for(pos)
			_move_joystick(pos)
	elif not catches_jump(pos):
		pass  # (abilities shown: the dead ring / the buttons' side of the right half)
	elif _jump_touch == -1:
		_jump_touch = index
		_press("jump")
	_canvas.queue_redraw()


func _touch_up(index: int, pos: Vector2) -> void:
	if _ability_touch.has(index):
		var slot: int = _ability_touch[index]
		_ability_touch.erase(index)
		_ability_pos.erase(index)
		if slot < abilities.size() and ability_at(pos) == slot:
			ability_tapped.emit(abilities[slot].id)
	elif index == _pause_touch:
		_release_pause()
	elif index == _tap_touch:
		_tap_touch = -1
		tapped.emit(pos)
	elif index == _joy_touch:
		_joy_touch = -1
		_joy_center = JOY_HOME
		joy_vector = Vector2.ZERO
		_steer(Vector2.ZERO)
	elif index == _jump_touch:
		_jump_touch = -1
		_release("jump")
	_canvas.queue_redraw()


## Where the floating joystick appears for a thumb at `pos`: whole inside the screen (and the safe area: never
## in an iPhone's home-indicator strip or under a notch, Platform.safe_rect), 12 px clear of the top.
## PAUSE_Y_RANDOM, moved down with the HUD pods where a phone's safe area pushes them (UIKit.hud_edge),
## and as they grow for a taller script (pod_h / pod_h2).
func pause_y_random() -> float:
	return PAUSE_Y_RANDOM + UIKit.hud_edge().y - UIKit.HUD_EDGE + UIKit.pod_h() - UIKit.POD_H + UIKit.pod_h2() - UIKit.POD_H2


func joystick_center_for(pos: Vector2) -> Vector2:
	var safe := Platform.safe_rect()
	return pos.clamp(safe.position + Vector2(JOY_RADIUS, JOY_RADIUS + 12), safe.end - Vector2(JOY_RADIUS, JOY_RADIUS))


func _move_joystick(pos: Vector2) -> void:
	joy_vector = ((pos - _joy_center) / JOY_RADIUS).limit_length(1.0)
	var dir := Vector2.ZERO
	if joy_vector.length() > DEADZONE:
		var angle := snappedf(joy_vector.angle(), PI / 4.0)
		dir = Vector2(roundf(cos(angle)), roundf(sin(angle))).normalized()
	_steer(dir)
	_canvas.queue_redraw()


## Presses the movement actions for a direction (exact cardinals keep the lane assist working).
func _steer(dir: Vector2) -> void:
	var strengths := [dir.x, -dir.x, dir.y, -dir.y]
	for i in MOVE_ACTIONS.size():
		if strengths[i] > 0.05:
			_press(MOVE_ACTIONS[i], strengths[i])
		else:
			_release(MOVE_ACTIONS[i])


func _press(action: String, strength := 1.0) -> void:
	_held[action] = true
	Input.action_press(action, strength)


func _release(action: String) -> void:
	if _held.erase(action):
		Input.action_release(action)


## ABILITIES: the buttons to show ([{id, left, max}]; AbilityRunner keeps it current).
## The ability the tutorial is on (AbilityCoach): its button blinks a gold ring. "" = none.
var coach_id := ""
var _coach_clock := 0.0
const COACH_BLINK := 0.6


func set_coach(id: String) -> void:
	coach_id = id
	_coach_clock = 0.0
	if _canvas:
		_canvas.queue_redraw()


## Ticks the coached button's blink (AbilityCoach, while it shows a line).
func step_coach(delta: float) -> void:
	var was := fmod(_coach_clock, COACH_BLINK) < COACH_BLINK / 2.0
	_coach_clock += delta
	if _canvas and was != (fmod(_coach_clock, COACH_BLINK) < COACH_BLINK / 2.0):
		_canvas.queue_redraw()


func set_abilities(items: Array[Dictionary]) -> void:
	abilities = items.duplicate(true)
	if _canvas:
		_canvas.queue_redraw()


## The index (in `abilities`) of the button under `pos` (-1 = none).
func ability_at(pos: Vector2) -> int:
	for i in abilities.size():
		if pos.distance_to(slot_center(i)) <= ABILITY_HIT:
			return i
	return -1


## The center of the button of `abilities[i]`: its ability's own spot (so SLIMAKAZE never takes the
## spot nearest JUMP, whatever else is owned).
func slot_center(i: int) -> Vector2:
	return ABILITY_SLOTS[clampi(Abilities.ids().find(abilities[i].id), 0, ABILITY_SLOTS.size() - 1)]


## The left edge of JUMP's catch zone (x >= this counts as JUMP; the pause button is checked first).
func jump_zone_left() -> float:
	return JUMP_ZONE_X if not abilities.is_empty() else SCREEN.x / 2.0


## True if a touch at `pos` (not on pause or a button) goes to JUMP.
func catches_jump(pos: Vector2) -> bool:
	return pos.x >= jump_zone_left()


## The joystick's ring on screen while a thumb holds it (it floats to the thumb in the left half), empty at
## rest (the ring at JOY_HOME, clear of everything by layout) or while the controls are hidden. The training
## direction line keeps off it (HUD).
func joystick_rect() -> Rect2:
	if not visible or menu_open or _joy_touch == -1:
		return Rect2()
	return Rect2(_joy_center - Vector2.ONE * JOY_RADIUS, Vector2.ONE * JOY_RADIUS * 2.0)


## Hides the controls (e.g. when a level ends and menu buttons take over).
func hide_controls() -> void:
	_release_all()
	visible = false


## Lets go of the pause button's `menu` press, if it is held.
func _release_pause() -> void:
	if _pause_touch == -1:
		return
	_pause_touch = -1
	var release := InputEventAction.new()
	release.action = "menu"
	release.pressed = false
	Input.parse_input_event(release)


## Lets go of everything these controls hold (PlatformEvents: the app lost focus or went to the background).
func release_all() -> void:
	_release_all()


func _release_all() -> void:
	_release_pause()
	_joy_touch = -1
	_jump_touch = -1
	_tap_touch = -1  # (nothing opens: a tap only counts on a real release)
	_joy_center = JOY_HOME
	joy_vector = Vector2.ZERO
	_steer(Vector2.ZERO)
	_release("jump")
	_ability_touch.clear()  # (nothing fires: an ability only fires on a real release)
	_ability_pos.clear()
	if _canvas:
		_canvas.queue_redraw()


## The JUMP circle's radius: JUMP_RADIUS, larger only when a translated word (`text_w` wide, its line
## `line_h` tall) would come within JUMP_TEXT_CLEAR of the ring (LOMPAT): never cut, never scaled.
static func jump_radius(text_w: float, line_h: float) -> float:
	var corner := Vector2(text_w / 2.0 + JUMP_TEXT_CLEAR, minf(line_h, float(UIKit.TEXT_BODY + 2)) / 2.0)
	return maxf(JUMP_RADIUS, ceilf(corner.length() + 1.0))


## The baseline under JUMP_CENTER that centres the word's line box on it: 3 for the slimy font's
## 7 px line (English); a taller script's box (ascent / height) is centred, plus its ink_nudge.
static func jump_baseline(font: Font) -> float:
	var line_h := font.get_height(8)
	if line_h <= UIKit.TEXT_BODY:
		return 3.0
	return 3.0 + (font.get_ascent(8) - UIKit.TEXT_BODY) - floorf((line_h - UIKit.TEXT_BODY) / 2.0) + float(UIKit.metrics().get("ink_nudge", 0))


func _draw_controls() -> void:
	if menu_open:
		return  # (a hub panel is open: its buttons take the taps)
	var color := _skin_color()
	var dim := Color(UIKit.BG, 0.45)
	# Joystick: base ring + knob.
	_canvas.draw_circle(_joy_center, JOY_RADIUS, dim)
	_canvas.draw_arc(_joy_center, JOY_RADIUS, 0.0, TAU, 32, Color(color, 0.7), 1.0)
	_canvas.draw_circle((_joy_center + joy_vector * JOY_RADIUS).round(), KNOB_RADIUS,
		Color(color, 0.85 if _joy_touch != -1 else 0.5))
	# Jump button.
	var pressed := _jump_touch != -1
	var font := _canvas.get_theme_default_font()
	var jump_text := Loc.t("touch.jump", "JUMP")  # i18n: touch jump button, inside a 38 px circle, max 34px, grows to 48px (the circle grows)
	var label_width := font.get_string_size(jump_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var radius := jump_radius(label_width, font.get_height(8))
	_canvas.draw_circle(JUMP_CENTER, radius, Color(color, 0.55) if pressed else dim)
	_canvas.draw_arc(JUMP_CENTER, radius, 0.0, TAU, 32, Color(color, 0.8), 1.0)
	_canvas.draw_string(font, (JUMP_CENTER + Vector2(-label_width / 2.0, jump_baseline(font))).round(), jump_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))
	# Ability buttons: a ring, the icon (2x); lit when ready, dimmed once used.
	for i in abilities.size():
		var item: Dictionary = abilities[i]
		var at := slot_center(i)
		var held := false
		for index: int in _ability_touch:
			held = held or (_ability_touch[index] == i and ability_at(_ability_pos.get(index, at)) == i)
		var ready := int(item.left) > 0
		_canvas.draw_circle(at, ABILITY_RADIUS, Color(color, 0.55) if held else dim)
		_canvas.draw_arc(at, ABILITY_RADIUS, 0.0, TAU, 24, Color(color, 0.8 if ready else 0.35), 1.0)
		_canvas.draw_texture_rect(Abilities.icon(item.id), Rect2(at + Vector2(-8, -10), Vector2(16, 16)), false,
			Color(1, 1, 1, 0.95 if ready else 0.35))
		if item.id == coach_id and fmod(_coach_clock, COACH_BLINK) < COACH_BLINK / 2.0:
			_canvas.draw_arc(at, ABILITY_RADIUS + 2.0, 0.0, TAU, 24, UIKit.GOLD, 2.0)  # (the tutorial's ability: tap this)
	# Pause button: two bars (or the hub's home icon on phones).
	_canvas.draw_rect(pause_rect, dim)
	for r: Rect2i in (HOME_PIXELS if home_icon else PAUSE_PIXELS):
		_canvas.draw_rect(Rect2(pause_rect.position + Vector2(r.position), Vector2(r.size)), Color(color, 0.9))


## The pause button's ink, inside its 15x13 rect: two 2x7 bars, and the home icon (7x7 house: a 4-row pointed
## roof, 3 rows of wall with a 1x2 door gap), both centred on the rect (x 4..10, y 3..9).
const PAUSE_PIXELS: Array[Rect2i] = [Rect2i(4, 3, 2, 7), Rect2i(9, 3, 2, 7)]
const HOME_PIXELS: Array[Rect2i] = [Rect2i(7, 3, 1, 1), Rect2i(6, 4, 3, 1), Rect2i(5, 5, 5, 1), Rect2i(4, 6, 7, 1),
	Rect2i(5, 7, 5, 1), Rect2i(5, 8, 2, 2), Rect2i(8, 8, 2, 2)]


func _skin_color() -> Color:
	var progress := get_node_or_null("/root/Progress")
	var base: Color = progress.skin_color() if progress else Skins.get_preset(Skins.DEFAULT).color
	return SkinText.color_for(SkinText.ROLE_TITLE, base)
