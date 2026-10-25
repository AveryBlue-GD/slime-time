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
## Room kept each side of a translated key word that widens its key (draw_key).
const KEY_PAD := 2.0
const KEY_FILL := Color8(26, 28, 44)
const KEY_EDGE := Color8(244, 244, 244)  # the letters and arrowheads
## CON-09: the keycap's 1 px rim, the HUD pod family (TEXT_DIM on the dark fill), not a white slab.
const KEY_RIM := Color8(148, 176, 194)

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
	draw_cues(self)


## Draws the cues as they stand on `canvas` (this node; tests pass a recorder with the same draw_rect /
## draw_string, tests/test_training_cues.gd).
func draw_cues(canvas: Variant) -> void:
	var bob := bob_at(_time)
	if move_alpha > 0.0:
		draw_move(canvas, Vector2(0, -33 + bob), _touch() or Platform.using_pad(), move_alpha)
	if leap_alpha > 0.0:
		draw_key(canvas, Vector2(0, -23 + bob), leap_label(_touch()), 29.0, leap_alpha, _touch())


## ---------------------------------------------------------------- shared drawing (static)
## The keycaps, d-pad and arrowheads, as statics drawing on any CanvasItem (`canvas`: anything with
## CanvasItem's draw_rect / draw_string, e.g. a test's recorder), so the training cues
## (training_cues.gd) draw exactly the same glyphs. Levels 1-2 are pixel-identical to the drawing
## these replaced (tests/test_training_cues.gd keeps a golden of it, tests/demo_cue_golden.tscn shows it).

## The stepped 1 px pulse at `time` seconds: -1 for the first 0.45 s of every 0.9 s, else 0.
static func bob_at(time: float) -> float:
	return -1.0 if fmod(time, 0.9) < 0.45 else 0.0


## The move glyph with its top at `top`: the bound keys (W A S D, or the remapped ones), or a d-pad
## (`dpad`: a pad or the touch joystick, no keys to show; the d-pad shape fits both). `top_pad`: see draw_key.
static func draw_move(canvas: Variant, top: Vector2, dpad: bool, alpha: float, top_pad := 0.0) -> void:
	if dpad:
		draw_dpad(canvas, top + Vector2(0, 6), alpha)
	else:
		draw_wasd(canvas, top, alpha, top_pad)


## The leap key's word: JUMP on touch screens, else the pad's A or the bound key (SPACE).
static func leap_label(touch: bool) -> String:
	# i18n: tutorial keycap on touch screens, max 27px (a 29 px drawn key), grows to 60px (the key widens), 1 line
	return Loc.t("tutorial.jump", "JUMP") if touch else Platform.prompt_for("jump", key_text("jump", "SPACE"))  # (pad: A)


## The four move keys (W over A S D), the bottom row's bottom at `top` + 2 KEY + 1 whatever `top_pad`
## (taller keys grow upward; the rows stay 1 px apart).
static func draw_wasd(canvas: Variant, top: Vector2, alpha: float, top_pad := 0.0) -> void:
	var step := KEY + 1.0
	draw_key(canvas, top + Vector2(0, -top_pad), key_text("move_up", "W"), KEY, alpha, false, top_pad)
	draw_key(canvas, top + Vector2(-step, step), key_text("move_left", "A"), KEY, alpha, false, top_pad)
	draw_key(canvas, top + Vector2(0, step), key_text("move_down", "S"), KEY, alpha, false, top_pad)
	draw_key(canvas, top + Vector2(step, step), key_text("move_right", "D"), KEY, alpha, false, top_pad)


## A plus-shaped d-pad of four arrowheads (touch screens: the joystick takes any direction).
static func draw_dpad(canvas: Variant, center: Vector2, alpha: float) -> void:
	var color := Color(KEY_EDGE, alpha)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_arrow(canvas, (center + dir * 7.0).round(), dir, color)
	canvas.draw_rect(Rect2(center.round() - Vector2.ONE, Vector2(3, 3)), color)


static func draw_arrow(canvas: Variant, tip_center: Vector2, dir: Vector2, color: Color) -> void:
	var side := Vector2(dir.y, dir.x).abs()  # perpendicular, kept positive
	for i in 3:  # three rows, widest at the base
		var back := tip_center - dir * float(2 - i)
		var half := float(i)
		canvas.draw_rect(Rect2((back - side * half).round(), Vector2.ONE + side * (half * 2.0)), color)


## A keycap centred on `center_top` (its bottom row KEY under that point); returns its rect. `top_pad`
## (the training cues: 2) adds that many clear rows over the word, the key growing upward: the 9 px key's
## letters start on its top edge (an A's top merges into it and reads as H); levels 1-2 keep 0.
static func draw_key(canvas: Variant, center_top: Vector2, text: String, width: float, alpha: float, fit := false, top_pad := 0.0) -> Rect2:
	var font := ThemeDB.fallback_font
	var arrow: bool = text in ["UP", "DOWN", "LEFT", "RIGHT"]
	var key := key_size(font, text, width, fit)
	width = key.x
	if key.y != KEY:
		top_pad = 0.0  # (a taller script's key already has room over its line)
	var height := key.y + top_pad
	var top := center_top - Vector2(floorf(width / 2.0), height - KEY)
	var rect := Rect2(top.round(), Vector2(width, height))
	canvas.draw_rect(rect, Color(KEY_RIM, alpha))
	canvas.draw_rect(rect.grow(-1.0), Color(KEY_FILL, alpha))
	var center := rect.position + rect.size / 2.0
	if arrow:
		var dir := {"UP": Vector2.UP, "DOWN": Vector2.DOWN, "LEFT": Vector2.LEFT, "RIGHT": Vector2.RIGHT}[text] as Vector2
		draw_arrow(canvas, center.floor() + dir, dir, Color(KEY_EDGE, alpha))
	else:
		# The English baseline 7 px under the key's top; a taller script's line box fills the key's
		# inside (moved down by its ink_nudge, like the buttons' text).
		var baseline := top_pad + (7.0 if key.y == KEY else 1.0 + font.get_ascent(8) + float(UIKit.metrics().get("ink_nudge", 0)))
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, 8, Color(KEY_EDGE, alpha))
	return rect


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
static func key_text(action: String, fallback: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var label := key_label(event)
			return label if label != "" else fallback
	return fallback


## The name printed on the player's own key for a key event: a physical binding (W A S D) shows the
## letter of the keyboard layout (Z Q S D on AZERTY: Platform.key_label); a plain keycode its name.
static func key_label(event: InputEventKey) -> String:
	var code: Key = Platform.key_label(event.physical_keycode) if event.physical_keycode != KEY_NONE else event.keycode
	return OS.get_keycode_string(code).to_upper()
