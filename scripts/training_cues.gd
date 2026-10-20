class_name TrainingCues
extends Node2D

## SPLASHDOWN's wordless cues (the training maze, docs/tutorial/design.md sections 3, 4 and 14), drawn above the
## slime with the level 1-2 glyphs (TutorialCues' static helpers, so both draw identical keycaps):
## - the move glyph (bound keys, or a d-pad for a pad / the touch joystick) from the start of each attempt
##   until the slime first moves;
## - the leap key (SPACE / the bound key, A on a pad, JUMP on touch) with a 2 px hold bar under it, from the
##   `"straight"` beat until the first leap: the bar fills while the key is held (it teaches *hold*);
## - nothing at all from the `"chalice"` beat on. No arrow, no beacon (D13).
## Each fades on use. A real move / leap is reported with Progress.note_training_input (never
## mark_tutorial_seen: a replay writes nothing); the bits it collects also keep a cue gone on attempt 2
## (RESTART reloads the scene). The prompts follow the device in use every frame.
## game.gd (MODE_TRAINING) makes it a child of the slime and calls setup; the HUD (hud.gd) listens to the
## same `training_cue` signal for the meter pod pulse (`"first_drain"`) and the accept glyph by RESTART
## (`"dry"`; draw_accept below).

const NODE_NAME := "TrainingCues"
const FADE_SPEED := TutorialCues.FADE_SPEED
const MAX_FADE_STEP := TutorialCues.MAX_FADE_STEP
## Where the glyphs sit over the slime's centre (the level 1-2 spots: move top, leap key top).
const MOVE_TOP := -33.0
const LEAP_TOP := -23.0
## Clear rows over the keycaps' words (TutorialCues.draw_key `top_pad`): 11 px keys, the letters 1 px under the
## top edge instead of on it (on it, an A's top merges into the edge and reads as H). Keys grow upward.
const KEY_TOP_PAD := 2.0
## Both glyphs go up this far while the slime wears a hat (a SETTINGS replay may have one on).
const HAT_LIFT := 8.0
## The leap key's width as designed (TutorialCues' 29 px; a longer word widens it).
const LEAP_KEY_W := 29.0
## The hold bar: this tall, 1 px under the leap key, as wide as the key.
const HOLD_BAR_H := 2.0
const HOLD_TRACK_ALPHA := 0.35

var game: Node
var slime: Slime
var progress: Node
var move_alpha := 0.0
var leap_alpha := 0.0
## The strongest alpha the last _draw() put on screen (one clearing redraw is due once all reach 0).
var drawn_alpha := 0.0
## Beats seen this attempt: the move glyph is armed from the start (the `"start"` beat may fire before
## this node is connected), the leap key from `"straight"`; `"chalice"` ends both.
var want_move := true
var want_leap := false
var done := false
var _moved := false
var _leapt := false
var _last := Vector2.ZERO
var _primed := false
var _time := 0.0


func setup(game_node: Node, slime_node: Slime, progress_node: Node) -> void:
	game = game_node
	slime = slime_node
	progress = progress_node
	name = NODE_NAME
	z_index = 1
	var used: int = progress.training_used
	_moved = used & Progress.TUTORIAL_MOVE != 0
	_leapt = used & Progress.TUTORIAL_LEAP != 0
	if game.has_signal("training_cue"):
		game.connect("training_cue", on_cue)


func on_cue(beat: String) -> void:
	match beat:
		"start", "restart":
			want_move = true
		"straight":
			want_leap = true
		"chalice":
			done = true


func _process(delta: float) -> void:
	if not _primed:  # (game.gd sets the slime on its start after making this node)
		_primed = true
		_last = slime.position
	_time += delta
	var moved := slime.position.distance_to(_last)
	_last = slime.position
	var finished: bool = game.finished
	if moved > 0.2 and not finished and not _moved:
		_moved = true
		progress.note_training_input(Progress.TUTORIAL_MOVE)
	if slime.state == Slime.State.AIRBORNE and not _leapt:  # (a launched leap; holding the key alone is not one)
		_leapt = true
		progress.note_training_input(Progress.TUTORIAL_LEAP)
	var live := not finished and not done
	var fade := minf(delta, MAX_FADE_STEP) * FADE_SPEED
	move_alpha = move_toward(move_alpha, 1.0 if live and want_move and not _moved else 0.0, fade)
	leap_alpha = move_toward(leap_alpha, 1.0 if live and want_leap and not _leapt else 0.0, fade)
	if move_alpha > 0.0 or leap_alpha > 0.0 or drawn_alpha > 0.0:
		queue_redraw()  # (every frame while shown: the device, the bob and the hold bar follow)


## "keys", "pad" or "touch" (Platform.INPUT_*): the device the prompts name. A pad wins once used (the last
## device); touch while the touch controls are up, as on level 1.
static func device_for(game_node: Node) -> String:
	if Platform.using_pad():
		return Platform.INPUT_PAD
	var touch: Node = game_node.get("touch_controls") if game_node else null
	if (touch and touch.visible) or Platform.last_input == Platform.INPUT_TOUCH:
		return Platform.INPUT_TOUCH
	return Platform.INPUT_KEYS


func _draw() -> void:
	drawn_alpha = maxf(move_alpha, leap_alpha)
	draw_cues(self)


## Draws the cues as they stand on `canvas` (this node, or a test's recorder).
func draw_cues(canvas: Variant) -> void:
	var device := device_for(game)
	var bob := TutorialCues.bob_at(_time)
	var lift := -HAT_LIFT if game.get("hat") != null else 0.0
	if move_alpha > 0.0:
		TutorialCues.draw_move(canvas, Vector2(0, MOVE_TOP + bob + lift), device != Platform.INPUT_KEYS, move_alpha, KEY_TOP_PAD)
	if leap_alpha > 0.0:
		var touch := device == Platform.INPUT_TOUCH
		var key := TutorialCues.draw_key(canvas, Vector2(0, LEAP_TOP + bob + lift), TutorialCues.leap_label(touch), LEAP_KEY_W, leap_alpha, touch, KEY_TOP_PAD)
		var charging := slime.state == Slime.State.CHARGING
		draw_hold_bar(canvas, key, slime.charge / 100.0 if charging else 0.0, leap_alpha)


## The 2 px hold bar 1 px under `key`: a faint track, filled left to right by `share` (0..1) in the key's white.
static func draw_hold_bar(canvas: Variant, key: Rect2, share: float, alpha: float) -> void:
	var bar := Rect2(key.position.x, key.end.y + 1.0, key.size.x, HOLD_BAR_H)
	canvas.draw_rect(bar, Color(TutorialCues.KEY_EDGE, alpha * HOLD_TRACK_ALPHA))
	var filled := roundf(bar.size.x * clampf(share, 0.0, 1.0))
	if filled > 0.0:
		canvas.draw_rect(Rect2(bar.position, Vector2(filled, bar.size.y)), Color(TutorialCues.KEY_EDGE, alpha))


## ---------------------------------------------------------------- the accept glyph by RESTART (hud.gd)

## The word on the accept key: A on a pad, else the keyboard key that presses a focused button (SPACE when
## ui_accept has it, the key the player just leapt with; else its first key, ENTER).
static func accept_label() -> String:
	var first := ""
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			if code == KEY_SPACE:
				first = TutorialCues.key_label(event)
				break
			if first == "":
				first = TutorialCues.key_label(event)
	return Platform.prompt_for("ui_accept", first if first != "" else "ENTER")  # i18n: ignore (an OS key name, like the keys TutorialCues shows)


## The accept keycap with its left edge at `left` and its box centred on `mid_y` (a stepped 1 px bob at
## `time`), in the training's keycap style (KEY_TOP_PAD). Returns its rect.
static func draw_accept(canvas: Variant, left: float, mid_y: float, time: float, alpha := 1.0) -> Rect2:
	var text := accept_label()
	var size := TutorialCues.key_size(ThemeDB.fallback_font, text, TutorialCues.KEY)
	var pad := KEY_TOP_PAD if size.y == TutorialCues.KEY else 0.0
	var box_top := roundf(mid_y - (size.y + pad) / 2.0) + TutorialCues.bob_at(time)
	return TutorialCues.draw_key(canvas, Vector2(left + floorf(size.x / 2.0), box_top + size.y + pad - TutorialCues.KEY), text,
		TutorialCues.KEY, alpha, false, KEY_TOP_PAD)
