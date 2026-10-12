class_name TutorialCues
extends Node2D

## Wordless teaching for the first two story levels, drawn above the slime on whole pixels:
## - a pulsing input glyph (the real keys, or a d-pad on touch screens) until the first move, and
##   a SPACE / JUMP key once the slime has wandered a while without ever leaping; each fades on
##   first use and never comes back (saved in Progress.tutorial_seen)
## - a faint gold chevron pointing toward the chalice, after the slime has stood still for a
##   while or after a dry-up on this level; it vanishes once the chalice is in view
## Not used on hard mode or the randomizer. A child of the slime, so it follows it.

const MAX_LEVEL := 2
const IDLE_FOR_BEACON := 6.0
const WANDER_FOR_LEAP := 48.0
const LEAP_PAUSE := 1.0
const FADE_SPEED := 3.0
const KEY := 9.0
const KEY_FILL := Color8(26, 28, 44)
const KEY_EDGE := Color8(244, 244, 244)
const GOLD := Color8(255, 205, 117)
const BEACON_DISTANCE := 26.0

var game: Node
var slime: Slime
var progress: Node
var move_alpha := 0.0
var leap_alpha := 0.0
var beacon_alpha := 0.0
var idle := 0.0
var wandered := 0.0
var _last := Vector2.ZERO
var _time := 0.0
var _moved := false
var _leapt := false


func setup(game_node: Node, slime_node: Slime, progress_node: Node) -> void:
	game = game_node
	slime = slime_node
	progress = progress_node
	z_index = 1
	_moved = progress.has_seen_tutorial(Progress.TUTORIAL_MOVE)
	_leapt = progress.has_seen_tutorial(Progress.TUTORIAL_LEAP)
	_last = slime.position


func _process(delta: float) -> void:
	_time += delta
	var moved := slime.position.distance_to(_last)
	_last = slime.position
	if game.finished:
		moved = 0.0
	if moved > 0.2:
		idle = 0.0
		wandered += moved
		if not _moved:
			_moved = true
			progress.mark_tutorial_seen(Progress.TUTORIAL_MOVE)
	else:
		idle += delta
	if not _leapt and slime.state != Slime.State.GLIDE and slime.state != Slime.State.STUNNED:
		_leapt = true
		progress.mark_tutorial_seen(Progress.TUTORIAL_LEAP)
	var live: bool = not game.finished
	move_alpha = move_toward(move_alpha, 1.0 if live and not _moved else 0.0, delta * FADE_SPEED)
	var want_leap: bool = live and _moved and not _leapt and wandered >= WANDER_FOR_LEAP and idle >= LEAP_PAUSE
	leap_alpha = move_toward(leap_alpha, 1.0 if want_leap else 0.0, delta * FADE_SPEED)
	beacon_alpha = move_toward(beacon_alpha, 1.0 if live and _beacon_wanted() else 0.0, delta * FADE_SPEED * 0.5)
	if move_alpha > 0.0 or leap_alpha > 0.0 or beacon_alpha > 0.0:
		queue_redraw()


func _beacon_wanted() -> bool:
	if game.chalice.visible:
		return false
	return idle >= IDLE_FOR_BEACON or int(progress.dry_ups.get(game.level, 0)) > 0


func _touch() -> bool:
	return game.touch_controls.visible


func _draw() -> void:
	var bob := -1.0 if fmod(_time, 0.9) < 0.45 else 0.0  # a stepped 1 px pulse
	if move_alpha > 0.0:
		var top := Vector2(0, -33 + bob)
		if _touch():
			_draw_dpad(top + Vector2(0, 6), move_alpha)
		else:
			_draw_wasd(top, move_alpha)
	if leap_alpha > 0.0:
		var spot := Vector2(0, -23 + bob)
		_draw_key(spot, "JUMP" if _touch() else _key_text("jump", "SPACE"), 29.0, leap_alpha)
	if beacon_alpha > 0.0:
		_draw_beacon(beacon_alpha * (0.7 if bob < 0.0 else 0.5))


func _draw_wasd(top: Vector2, alpha: float) -> void:
	var step := KEY + 1.0
	_draw_key(top + Vector2(0, 0), _key_text("move_up", "W"), KEY, alpha)
	_draw_key(top + Vector2(-step, step), _key_text("move_left", "A"), KEY, alpha)
	_draw_key(top + Vector2(0, step), _key_text("move_down", "S"), KEY, alpha)
	_draw_key(top + Vector2(step, step), _key_text("move_right", "D"), KEY, alpha)


## A plus-shaped d-pad of four arrowheads (touch screens: the joystick takes any direction).
func _draw_dpad(center: Vector2, alpha: float) -> void:
	var color := Color(KEY_EDGE, alpha)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_draw_arrow((center + dir * 7.0).round(), dir, color)
	draw_rect(Rect2(center.round() - Vector2.ONE, Vector2(3, 3)), color)


func _draw_arrow(tip_center: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(dir.y, dir.x).abs()  # perpendicular, kept positive
	for i in 3:  # three rows, widest at the base
		var back := tip_center - dir * float(2 - i)
		var half := float(i)
		draw_rect(Rect2((back - side * half).round(), Vector2.ONE + side * (half * 2.0)), color)


func _draw_key(center_top: Vector2, text: String, width: float, alpha: float) -> void:
	var rect := Rect2((center_top - Vector2(floorf(width / 2.0), 0.0)).round(), Vector2(width, KEY))
	draw_rect(rect, Color(KEY_EDGE, alpha))
	draw_rect(rect.grow(-1.0), Color(KEY_FILL, alpha))
	var center := rect.position + rect.size / 2.0
	match text:
		"UP", "DOWN", "LEFT", "RIGHT":
			var dir := {"UP": Vector2.UP, "DOWN": Vector2.DOWN, "LEFT": Vector2.LEFT, "RIGHT": Vector2.RIGHT}[text] as Vector2
			_draw_arrow(center.floor() + dir, dir, Color(KEY_EDGE, alpha))
		_:
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(rect.position.x, rect.position.y + 7.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, 8, Color(KEY_EDGE, alpha))


## The label of the key bound to an action ("W", "SPACE", "UP"...), or the default.
func _key_text(action: String, fallback: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			var label := OS.get_keycode_string(code).to_upper()
			return label if label != "" else fallback
	return fallback


## A small gold chevron on the straight line toward the chalice (not along the path).
func _draw_beacon(alpha: float) -> void:
	var dir: Vector2 = (game.chalice.position - slime.position).normalized()
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var center := dir * BEACON_DISTANCE
	var tip := (center + dir * 3.0).round()
	var left := (center - dir * 2.0 + perp * 3.0).round()
	var right := (center - dir * 2.0 - perp * 3.0).round()
	draw_colored_polygon(PackedVector2Array([tip, right, left]), Color(GOLD, alpha))
	draw_rect(Rect2((center - dir * 6.0).round(), Vector2.ONE), Color(GOLD, alpha * 0.8))
