class_name TutorialCues
extends Node2D

## Wordless teaching for the first two story levels, drawn above the slime on whole pixels:
## - a pulsing input glyph (the real keys, or a d-pad on touch screens) until the first move, and
##   a SPACE / JUMP key once the slime has wandered a while without ever leaping; each fades on
##   first use and never comes back (saved in Progress.tutorial_seen)
## Not used on hard mode or the randomizer. A child of the slime, so it follows it.

const MAX_LEVEL := 2
const WANDER_FOR_LEAP := 48.0
const LEAP_PAUSE := 1.0
const FADE_SPEED := 3.0
## Longest frame a fade step may use: a hitch (a phone's browser stalls for a moment on the first
## glide, as the trail, drips and sounds start) still plays the full fade instead of skipping it.
const MAX_FADE_STEP := 1.0 / 30.0
const KEY := 9.0
## Room kept each side of a translated key word that widens its key (_draw_key).
const KEY_PAD := 2.0
const KEY_FILL := Color8(26, 28, 44)
const KEY_EDGE := Color8(244, 244, 244)

var game: Node
var slime: Slime
var progress: Node
var move_alpha := 0.0
var leap_alpha := 0.0
var idle := 0.0
var wandered := 0.0
var _last := Vector2.ZERO
var _time := 0.0
var _moved := false
var _leapt := false
## The strongest alpha the last _draw() put on screen. The canvas keeps those commands until the
## next redraw, so one more redraw is due after everything reaches 0 (else the glyph stays stuck).
var drawn_alpha := 0.0


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
	var fade := minf(delta, MAX_FADE_STEP) * FADE_SPEED
	move_alpha = move_toward(move_alpha, 1.0 if live and not _moved else 0.0, fade)
	var want_leap: bool = live and _moved and not _leapt and wandered >= WANDER_FOR_LEAP and idle >= LEAP_PAUSE
	leap_alpha = move_toward(leap_alpha, 1.0 if want_leap else 0.0, fade)
	if move_alpha > 0.0 or leap_alpha > 0.0 or drawn_alpha > 0.0:
		queue_redraw()  # (including the one clearing redraw after the last fade step)


func _touch() -> bool:
	return game.touch_controls.visible


func _draw() -> void:
	drawn_alpha = maxf(move_alpha, leap_alpha)
	var bob := -1.0 if fmod(_time, 0.9) < 0.45 else 0.0  # a stepped 1 px pulse
	if move_alpha > 0.0:
		var top := Vector2(0, -33 + bob)
		if _touch() or Platform.using_pad():  # (no keys to show: the d-pad shape fits a stick and a joystick)
			_draw_dpad(top + Vector2(0, 6), move_alpha)
		else:
			_draw_wasd(top, move_alpha)
	if leap_alpha > 0.0:
		var spot := Vector2(0, -23 + bob)
		# i18n: tutorial keycap on touch screens, max 27px (a 29 px drawn key), grows to 60px (the key widens), 1 line
		var leap := Loc.t("tutorial.jump", "JUMP") if _touch() else Platform.prompt_for("jump", _key_text("jump", "SPACE"))  # (pad: A)
		_draw_key(spot, leap, 29.0, leap_alpha, _touch())


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


func _draw_key(center_top: Vector2, text: String, width: float, alpha: float, fit := false) -> void:
	var font := ThemeDB.fallback_font
	var arrow: bool = text in ["UP", "DOWN", "LEFT", "RIGHT"]
	var key := key_size(font, text, width, fit)
	width = key.x
	var height := key.y
	var top := center_top - Vector2(floorf(width / 2.0), height - KEY)
	var rect := Rect2(top.round(), Vector2(width, height))
	draw_rect(rect, Color(KEY_EDGE, alpha))
	draw_rect(rect.grow(-1.0), Color(KEY_FILL, alpha))
	var center := rect.position + rect.size / 2.0
	if arrow:
		var dir := {"UP": Vector2.UP, "DOWN": Vector2.DOWN, "LEFT": Vector2.LEFT, "RIGHT": Vector2.RIGHT}[text] as Vector2
		_draw_arrow(center.floor() + dir, dir, Color(KEY_EDGE, alpha))
	else:
		# The English baseline 7 px under the key's top; a taller script's line box fills the key's
		# inside (moved down by its ink_nudge, like the buttons' text).
		var baseline := 7.0 if height == KEY else 1.0 + font.get_ascent(8) + float(UIKit.metrics().get("ink_nudge", 0))
		draw_string(font, Vector2(rect.position.x, rect.position.y + baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, 8, Color(KEY_EDGE, alpha))


## A key cap's size for `text` (`width` wide as designed, KEY tall). A word wider than the key (SPACE,
## a long OS key name, the translated touch JUMP) widens it, never cut, centred on the same pixel. `fit`
## (the translated touch JUMP): KEY_PAD clear each side, and a script taller than the slimy font's
## 7 px line heightens it (its line box inside the 1 px edge; the key grows upward, so its bottom stays
## clear of the slime). A key name (W A S D, SPACE: the OS's, untranslated) keeps the 9 px height and
## widens only once its text would touch the key's 1 px edge, so the 9 px W A S D keys keep their size.
static func key_size(font: Font, text: String, width: float, fit := false) -> Vector2:
	var line_h := font.get_height(8)
	var height := KEY if not fit or line_h <= UIKit.TEXT_BODY else line_h + 2.0
	if not text in ["UP", "DOWN", "LEFT", "RIGHT"]:
		var text_w := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		if text_w + 2.0 * KEY_PAD > width if fit else text_w > width - 2.0:
			width = text_w + 2.0 * KEY_PAD + float(int(text_w + width) % 2)  # (same parity: centred on whole pixels)
	return Vector2(width, height)


## The label of the key bound to an action ("W", "SPACE", "UP"...), or the default.
func _key_text(action: String, fallback: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			var label := OS.get_keycode_string(code).to_upper()
			return label if label != "" else fallback
	return fallback

