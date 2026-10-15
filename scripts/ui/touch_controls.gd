class_name TouchControls
extends CanvasLayer

## On-screen controls for phones and tablets. They press the same input actions as the keyboard:
## - left half of the screen: a floating joystick (appears under the thumb), snapped to 8
##   directions so the slime's lane assist still lines it up with corridors
## - right half: the JUMP button (hold to charge, aim with the joystick, release to leap)
## - top-right corner: pause
## - ABILITIES (when the run has any): a small round button each, in an arc left of / above JUMP
##   (ABILITY_SLOTS, in Abilities order), with its icon and uses left; a tap presses its action
## Shown on touchscreens (or with the --touch debug flag); hidden again when a keyboard is used.

const SCREEN := Vector2(320, 180)
const JOY_RADIUS := 20.0
const KNOB_RADIUS := 8.0
## Joystick dead zone, as a share of its radius.
const DEADZONE := 0.35
const JOY_HOME := Vector2(40, 140)
const JUMP_CENTER := Vector2(282, 142)
const JUMP_RADIUS := 19.0
const PAUSE_RECT := Rect2(302, 35, 15, 13)
## Where the pause button really is: PAUSE_RECT, moved down under the randomizer's taller attempt
## pod by game.gd (`pause_rect.position.y = PAUSE_Y_RANDOM`).
const PAUSE_Y_RANDOM := 44.0
var pause_rect := PAUSE_RECT
const PAUSE_TOUCH_MARGIN := 5.0
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
## ABILITIES: the buttons' centers (left of JUMP, up-left, above; 33 px from its center) and radius.
const ABILITY_SLOTS: Array[Vector2] = [Vector2(249, 142), Vector2(259, 119), Vector2(282, 109)]
const ABILITY_RADIUS := 11.0
## [{id, left, max}] from AbilityRunner.strip (empty: no buttons).
var abilities: Array[Dictionary] = []
## Ability id -> the finger holding its button.
var _ability_touch := {}

var joy_vector := Vector2.ZERO
var _joy_touch := -1
var _joy_center := JOY_HOME
var _jump_touch := -1
## False when the run has no leaps (HEAT GROUNDED): the JUMP button is drawn struck out and does nothing.
var jump_enabled := true
## The finger on the pause button: its `menu` press is released when it lifts (or the level pauses /
## the controls go away), so the action is never left held.
var _pause_touch := -1
## The actions these controls are holding down. Only those are ever released here, so a key
## pressed on a keyboard (which hides the controls) keeps its own press of the same action.
var _held := {}
var _canvas: Control


func _ready() -> void:
	layer = 15
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	var progress := get_node_or_null("/root/Progress")
	visible = DisplayServer.is_touchscreen_available() or (progress != null and progress.force_touch)


## True while a hub panel with buttons is open: touches pass through to it.
var menu_open := false:
	set(value):
		menu_open = value
		if value:
			_release_all()  # a finger still down when the panel opens must not stick


func _input(event: InputEvent) -> void:
	if menu_open:
		return
	if event is InputEventKey and event.pressed and visible:
		_release_all()
		visible = false  # someone is using a keyboard
		return
	if event is InputEventScreenTouch:
		visible = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _joy_touch:
		_move_joystick(event.position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pausing (or leaving the level) mid-touch must not leave the slime moving or charging.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_release_all()


func _touch_down(index: int, pos: Vector2) -> void:
	var slot := ability_at(pos)
	if slot >= 0:
		var action := Abilities.action(abilities[slot].id)
		_ability_touch[index] = action
		_press(action)
	elif pause_rect.grow(PAUSE_TOUCH_MARGIN).has_point(pos):
		_release_pause()  # (a second finger on it: the first one's press ends)
		_pause_touch = index
		var pause := InputEventAction.new()
		pause.action = "menu"
		pause.pressed = true
		Input.parse_input_event(pause)
	elif pos.x < SCREEN.x / 2.0:
		if _joy_touch == -1:
			_joy_touch = index
			_joy_center = pos.clamp(Vector2(JOY_RADIUS, JOY_RADIUS + 12), SCREEN - Vector2(JOY_RADIUS, JOY_RADIUS))
			_move_joystick(pos)
	elif _jump_touch == -1:
		_jump_touch = index
		if jump_enabled:
			_press("jump")
	_canvas.queue_redraw()


func _touch_up(index: int) -> void:
	if _ability_touch.has(index):
		_release(_ability_touch[index])
		_ability_touch.erase(index)
	elif index == _pause_touch:
		_release_pause()
	elif index == _joy_touch:
		_joy_touch = -1
		_joy_center = JOY_HOME
		joy_vector = Vector2.ZERO
		_steer(Vector2.ZERO)
	elif index == _jump_touch:
		_jump_touch = -1
		_release("jump")
	_canvas.queue_redraw()


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
func set_abilities(items: Array[Dictionary]) -> void:
	abilities = items.duplicate(true)
	if _canvas:
		_canvas.queue_redraw()


## The ability button slot under `pos` (-1 = none).
func ability_at(pos: Vector2) -> int:
	for i in mini(abilities.size(), ABILITY_SLOTS.size()):
		if pos.distance_to(ABILITY_SLOTS[i]) <= ABILITY_RADIUS + 2.0:
			return i
	return -1


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


func _release_all() -> void:
	_release_pause()
	_joy_touch = -1
	_jump_touch = -1
	_joy_center = JOY_HOME
	joy_vector = Vector2.ZERO
	_steer(Vector2.ZERO)
	_release("jump")
	for index: int in _ability_touch:
		_release(_ability_touch[index])
	_ability_touch.clear()
	if _canvas:
		_canvas.queue_redraw()


func _draw_controls() -> void:
	var color := _skin_color()
	var dim := Color(UIKit.BG, 0.45)
	# Joystick: base ring + knob.
	_canvas.draw_circle(_joy_center, JOY_RADIUS, dim)
	_canvas.draw_arc(_joy_center, JOY_RADIUS, 0.0, TAU, 32, Color(color, 0.7), 1.0)
	_canvas.draw_circle((_joy_center + joy_vector * JOY_RADIUS).round(), KNOB_RADIUS,
		Color(color, 0.85 if _joy_touch != -1 else 0.5))
	# Jump button.
	var pressed := _jump_touch != -1
	_canvas.draw_circle(JUMP_CENTER, JUMP_RADIUS, Color(color, 0.55) if pressed else dim)
	_canvas.draw_arc(JUMP_CENTER, JUMP_RADIUS, 0.0, TAU, 32, Color(color, 0.8), 1.0)
	var font := _canvas.get_theme_default_font()
	var label_width := font.get_string_size("JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_canvas.draw_string(font, (JUMP_CENTER + Vector2(-label_width / 2.0, 3)).round(), "JUMP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9 if jump_enabled else 0.35))
	if not jump_enabled:  # GROUNDED: struck out
		var d := Vector2(JUMP_RADIUS, JUMP_RADIUS) * 0.6
		_canvas.draw_line((JUMP_CENTER - d).round(), (JUMP_CENTER + d).round(), Color(0.95, 0.3, 0.3, 0.8), 1.0)
	# Ability buttons: a ring, the icon (2x) and a pip per use left.
	for i in mini(abilities.size(), ABILITY_SLOTS.size()):
		var item: Dictionary = abilities[i]
		var at := ABILITY_SLOTS[i]
		var held := _ability_touch.values().has(Abilities.action(item.id))
		var ready := int(item.left) > 0
		_canvas.draw_circle(at, ABILITY_RADIUS, Color(color, 0.55) if held else dim)
		_canvas.draw_arc(at, ABILITY_RADIUS, 0.0, TAU, 24, Color(color, 0.8 if ready else 0.35), 1.0)
		_canvas.draw_texture_rect(Abilities.icon(item.id), Rect2(at + Vector2(-8, -10), Vector2(16, 16)), false,
			Color(1, 1, 1, 0.95 if ready else 0.35))
		var pips := int(item.max)
		for p in pips:
			var x := at.x - (pips * 3 - 1) / 2.0 + p * 3
			_canvas.draw_rect(Rect2(Vector2(roundf(x), at.y + 7), Vector2(2, 2)), Color(color, 0.95) if p < int(item.left) else Color(0.3, 0.3, 0.38, 0.8))
	# Pause button: two bars.
	_canvas.draw_rect(pause_rect, dim)
	_canvas.draw_rect(Rect2(pause_rect.position + Vector2(4, 3), Vector2(2, 7)), Color(color, 0.9))
	_canvas.draw_rect(Rect2(pause_rect.position + Vector2(9, 3), Vector2(2, 7)), Color(color, 0.9))


func _skin_color() -> Color:
	var progress := get_node_or_null("/root/Progress")
	var base: Color = progress.skin_color() if progress else Skins.get_preset(Skins.DEFAULT).color
	return SkinText.color_for(SkinText.ROLE_TITLE, base)
