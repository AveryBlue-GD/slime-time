class_name TouchControls
extends CanvasLayer

## On-screen controls for phones and tablets. They press the same input actions as the keyboard:
## - left half of the screen: a floating joystick (appears under the thumb), snapped to 8
##   directions so the slime's lane assist still lines it up with corridors
## - right half: the JUMP button (hold to charge, aim with the joystick, release to leap)
## - top-right corner: pause
## Shown on touchscreens (or with the --touch debug flag); hidden again when a keyboard is used.

const SCREEN := Vector2(320, 180)
const JOY_RADIUS := 20.0
const KNOB_RADIUS := 8.0
## Joystick dead zone, as a share of its radius.
const DEADZONE := 0.35
const JOY_HOME := Vector2(40, 140)
const JUMP_CENTER := Vector2(282, 142)
const JUMP_RADIUS := 19.0
const PAUSE_RECT := Rect2(302, 13, 15, 13)
const PAUSE_TOUCH_MARGIN := 5.0
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]

var joy_vector := Vector2.ZERO
var _joy_touch := -1
var _joy_center := JOY_HOME
var _jump_touch := -1
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


func _input(event: InputEvent) -> void:
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
	if PAUSE_RECT.grow(PAUSE_TOUCH_MARGIN).has_point(pos):
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
		Input.action_press("jump")
	_canvas.queue_redraw()


func _touch_up(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_joy_center = JOY_HOME
		joy_vector = Vector2.ZERO
		_steer(Vector2.ZERO)
	elif index == _jump_touch:
		_jump_touch = -1
		Input.action_release("jump")
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
			Input.action_press(MOVE_ACTIONS[i], strengths[i])
		else:
			Input.action_release(MOVE_ACTIONS[i])


func _release_all() -> void:
	_joy_touch = -1
	_jump_touch = -1
	_joy_center = JOY_HOME
	joy_vector = Vector2.ZERO
	_steer(Vector2.ZERO)
	Input.action_release("jump")
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))
	# Pause button: two bars.
	_canvas.draw_rect(PAUSE_RECT, dim)
	_canvas.draw_rect(Rect2(PAUSE_RECT.position + Vector2(4, 3), Vector2(2, 7)), Color(color, 0.9))
	_canvas.draw_rect(Rect2(PAUSE_RECT.position + Vector2(9, 3), Vector2(2, 7)), Color(color, 0.9))


func _skin_color() -> Color:
	var progress := get_node_or_null("/root/Progress")
	var base: Color = progress.skin_color() if progress else Skins.get_preset(Skins.DEFAULT).color
	return SkinText.color_for(SkinText.ROLE_TITLE, base)
