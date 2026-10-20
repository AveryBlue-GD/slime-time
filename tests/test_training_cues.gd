extends "res://tests/suite_base.gd"

## SPLASHDOWN's training cues (chunk C, docs/tutorial/design.md sections 3, 4, 7 and 14) and the level 1-2 cues
## they share their drawing with:
## - golden: TutorialCues' drawing (W A S D / d-pad / SPACE / A / JUMP, a remap, both bob steps, two alphas),
##   recorded through its draw_cues into draw commands, matches tests/data/tutorial_cues_golden.txt (made
##   from the drawing proven pixel-identical to the pre-refactor one with tests/demo_cue_golden.tscn);
## - level 1 gets nothing new: no TrainingCues node, no HUD hook, no accept glyph, no meter pulse;
## - in the training maze: the move glyph from the start until the first move, the leap key only from the
##   "straight" beat until the first leap (with the hold bar filling while charging), the meter pod pulse on
##   "first_drain", the accept glyph by RESTART on "dry" (keys / pad; the button pulses on touch), nothing
##   again on attempt 2 once used, nothing after "chalice"; the glyph follows the device (keys, a remapped
##   jump key, pad, touch); real moves / leaps are noted in Progress.training_used, never in tutorial_seen;
## - the training glyphs are the same keycaps as the level 1-2 ones.
## Nothing is written to disk (saving off). `-- --update-golden` rewrites the golden file.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_training_cues.gd

const MAIN := preload("res://scenes/main.tscn")
const StartDirs := preload("res://tests/start_dirs.gd")
const GOLDEN := "res://tests/data/tutorial_cues_golden.txt"


## Records CanvasItem draw calls as text (the cues draw through draw_rect / draw_string only).
class Pen extends RefCounted:
	var lines: PackedStringArray = []

	func draw_rect(rect: Rect2, color: Color, _filled := true, _width := -1.0, _aa := false) -> void:
		lines.append("rect %s %s %s %s %s" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y, color.to_html(true)])

	func draw_string(_font: Font, pos: Vector2, text: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0,
			font_size := 16, color := Color.WHITE, _j := 3, _d := 0, _o := 0, _oversampling := 0.0) -> void:
		lines.append("text %s %s '%s' %d %s %d %s" % [pos.x, pos.y, text, align, width, font_size, color.to_html(true)])

	func strings() -> PackedStringArray:
		var out: PackedStringArray = []
		for line in lines:
			if line.begins_with("text "):
				out.append(line.get_slice("'", 1))
		return out

	## Rects `h` px tall (the hold bar's 2 px rows).
	func rects_of_height(h: float) -> Array[Rect2]:
		var out: Array[Rect2] = []
		for line in lines:
			var parts := line.split(" ")
			if parts[0] == "rect" and float(parts[4]) == h:
				out.append(Rect2(float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])))
		return out


## Stands in for game.gd while TutorialCues draws (it reads touch_controls.visible and finished).
class FakeGame extends Node:
	var touch_controls := Control.new()
	var finished := false
	var hat: Node = null

	func _init() -> void:
		add_child(touch_controls)


var progress: Node
var game: Node2D


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.dev_tools = false
	Platform.reset_overrides()
	await _golden_case()
	await _level_one_case()
	await _training_case()
	await _chalice_case()
	Platform.reset_overrides()
	progress.mode = progress.MODE_STORY
	_result()
	quit(1 if failures else 0)


## ---------------------------------------------------------------- golden of the level 1-2 drawing

func _golden_case() -> void:
	var lines := _golden_lines()
	var update := "--update-golden" in OS.get_cmdline_user_args()
	if update or not FileAccess.file_exists(GOLDEN):
		var file := FileAccess.open(GOLDEN, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
		_check(update, "golden written to %s (%d lines; run again to compare)" % [GOLDEN, lines.size()])
		return
	var want := FileAccess.get_file_as_string(GOLDEN).strip_edges().split("\n")
	var first := -1
	for i in maxi(want.size(), lines.size()):
		if i >= want.size() or i >= lines.size() or want[i] != lines[i]:
			first = i
			break
	_check(first == -1, "level 1-2 cue drawing matches the golden (%d commands%s)" % [lines.size(),
		"" if first == -1 else "; first difference at line %d: %s" % [first + 1, lines[first] if first < lines.size() else "(missing)"]])


## Every state of the demo (tests/demo_cue_golden.gd): 4 setups x 2 bob steps x 4 alpha states.
func _golden_lines() -> PackedStringArray:
	var fake := FakeGame.new()
	root.add_child(fake)
	var saved := _save_bindings()
	var lines: PackedStringArray = []
	for setup: String in ["keys", "pad", "touch", "remap"]:
		Platform.last_input = Platform.INPUT_PAD if setup == "pad" else (Platform.INPUT_TOUCH if setup == "touch" else Platform.INPUT_KEYS)
		fake.touch_controls.visible = setup == "touch"
		if setup == "remap":
			_bind("move_up", KEY_UP)
			_bind("move_left", KEY_LEFT)
			_bind("move_down", KEY_DOWN)
			_bind("move_right", KEY_RIGHT)
			_bind("jump", KEY_J)
		for time: float in [0.0, 0.5]:
			for state: Array in [[1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [0.4, 0.4]]:
				var cue := TutorialCues.new()
				cue.game = fake
				cue._time = time
				cue.move_alpha = state[0]
				cue.leap_alpha = state[1]
				var pen := Pen.new()
				cue.draw_cues(pen)
				lines.append("# %s t=%s move=%s leap=%s" % [setup, time, state[0], state[1]])
				lines.append_array(pen.lines)
				cue.free()
	_restore_bindings(saved)
	Platform.last_input = Platform.INPUT_KEYS
	fake.free()
	return lines


## ---------------------------------------------------------------- level 1: nothing new

func _level_one_case() -> void:
	progress.mode = progress.MODE_STORY
	progress.levels_cleared = 0
	progress.randoms_won = 0
	progress.tutorial_seen = 0
	progress.start_story(1)
	game = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	current_scene = game
	await _physics_frames(40)
	var training_nodes: Array = game.slime.get_children().filter(func(c: Node) -> bool: return c is TrainingCues)
	var tutorial_nodes: Array = game.slime.get_children().filter(func(c: Node) -> bool: return c is TutorialCues)
	_check(training_nodes.is_empty() and tutorial_nodes.size() == 1, "level 1: its TutorialCues only, no training cues")
	_check(not game.hud.training_hooked and game.hud.accept_glyph == null and game.hud.meter_pod.modulate == Color.WHITE,
		"level 1: the HUD has no training hook, accept glyph or meter pulse")
	await _end_game()


## ---------------------------------------------------------------- the training maze

func _start_training() -> TrainingCues:
	progress.tutorial_seen = 0
	progress.prepare_training(false)
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await _physics_frames(3)
	return _cues()


func _cues() -> TrainingCues:
	for child in game.slime.get_children():
		if child is TrainingCues:
			return child
	return null


func _training_case() -> void:
	var cues := await _start_training()
	_check(cues != null and game.training, "training: the slime carries the training cues")
	if cues == null:
		await _end_game()
		return
	_check(game.hud.training_hooked, "training: the HUD listens to training_cue")
	_check(game.slime.get_children().filter(func(c: Node) -> bool: return c is TutorialCues).is_empty(),
		"training: no level 1-2 TutorialCues on top")
	await _physics_frames(30)
	_check(cues.move_alpha > 0.9 and cues.leap_alpha == 0.0, "start: the move glyph shows, the leap key doesn't (yet)")

	# Keycap names follow the keyboard layout (DisplayServer's label for a physical key: Z for W on AZERTY).
	var physical_w := InputEventKey.new()
	physical_w.physical_keycode = KEY_W
	var plain_z := InputEventKey.new()
	plain_z.keycode = KEY_Z
	var layout_w := DisplayServer.keyboard_get_label_from_physical(KEY_W)
	_check(TutorialCues.key_label(physical_w) == OS.get_keycode_string(layout_w if layout_w != KEY_NONE else KEY_W).to_upper() 			and TutorialCues.key_label(plain_z) == "Z", "keycaps: a physical key shows its layout's letter (%s), a plain keycode its name" % TutorialCues.key_label(physical_w))
	# The move glyph per device, and the same keycaps as level 1-2's.
	var fake := FakeGame.new()
	root.add_child(fake)
	for device: String in ["keys", "pad", "touch"]:
		_device(device)
		fake.touch_controls.visible = device == "touch"
		var pen := _pen(cues)
		var level_pen := _level_pen(fake, cues._time, 1.0, 0.0)
		var want := ["W", "A", "S", "D"] if device == "keys" else []
		_check(Array(pen.strings()) == want, "move glyph, %s: %s" % [device, "W A S D keys" if device == "keys" else "a d-pad"])
		if device == "keys":
			# UI pass: the training's keycaps are KEY_TOP_PAD taller (letters off the top edge), same widths
			# and columns, the bottom row's bottom where level 1-2's is, the rows 1 px apart.
			var caps := _keycaps(pen)
			var level_caps := _keycaps(level_pen)
			_check(caps.size() == 4 and level_caps.size() == 4, "move glyph, keys: four keycaps")
			var faults := _keycap_faults(caps)
			for i in mini(caps.size(), level_caps.size()):
				var r: Rect2 = caps[i].rect
				var l: Rect2 = level_caps[i].rect
				if r.position.x != l.position.x or r.size.x != l.size.x or r.size.y != l.size.y + TrainingCues.KEY_TOP_PAD:
					faults.append("%s %s vs level %s" % [caps[i].text, r, l])
			if caps.size() == 4:
				if caps[1].rect.end.y != level_caps[1].rect.end.y or caps[1].rect.position.y - caps[0].rect.end.y != 1.0:
					faults.append("rows: W %s, A %s" % [caps[0].rect, caps[1].rect])
			_check(faults.is_empty(), "move glyph, keys: the level 1-2 keys, %d px taller, letters clear of the edges (%s)" % [TrainingCues.KEY_TOP_PAD, ", ".join(faults)])
		else:
			_check(pen.lines == level_pen.lines, "move glyph, %s: the same pixels as level 1-2's" % device)
	_device("keys")

	# Moving fades it and notes MOVE (in the session, not the save).
	var dir := StartDirs.open_dir(game.maze, game.maze.start)
	_key(StartDirs.action(dir), true)
	var pulse_peak := 0.0
	for i in 40:
		await physics_frame
		pulse_peak = maxf(pulse_peak, game.hud.meter_pod.modulate.r)
	_key(StartDirs.action(dir), false)
	_check(cues.move_alpha == 0.0, "the first move fades the move glyph")
	_check(progress.training_used & Progress.TUTORIAL_MOVE != 0 and progress.tutorial_seen == 0,
		"the move is noted in training_used, not in tutorial_seen")
	_check(pulse_peak > 1.5, "first_drain: the meter pod pulses (peak %.2f)" % pulse_peak)
	await _physics_frames(40)
	_check(game.hud.meter_pod.modulate == Color.WHITE, "the pulse is over after %.1f s" % game.hud.METER_PULSE_TIME)
	_check(cues.leap_alpha == 0.0, "no leap key before the straight")

	# The straight: the leap key per device (a remapped jump key shows its key), with the hold bar.
	game.training_beat("straight")
	await _physics_frames(30)
	_check(cues.leap_alpha > 0.9, "straight: the leap key shows")
	var saved := _save_bindings()
	for device: String in ["keys", "remap", "pad", "touch"]:
		if device == "remap":
			_bind("jump", KEY_J)
		_device("keys" if device == "remap" else device)
		fake.touch_controls.visible = device == "touch"
		var pen := _pen(cues)
		var word: String = {keys = "SPACE", remap = "J", pad = "A", touch = TutorialCues.leap_label(true)}[device]
		_check(Array(pen.strings()) == [word], "leap key, %s: %s" % [device, word])
		var bars := pen.rects_of_height(TrainingCues.HOLD_BAR_H)
		_check(bars.size() == 1, "leap key, %s: an empty hold bar under it" % device)
		var level_pen := _level_pen(fake, cues._time, 0.0, 1.0)
		var caps := _keycaps(pen)
		var level_caps := _keycaps(level_pen)
		var faults := _keycap_faults(caps)
		if caps.size() != 1 or level_caps.size() != 1:
			faults.append("%d keycaps" % caps.size())
		else:
			var r: Rect2 = caps[0].rect
			var l: Rect2 = level_caps[0].rect
			var pad := TrainingCues.KEY_TOP_PAD if l.size.y == TutorialCues.KEY else 0.0
			if r.position.x != l.position.x or r.size.x != l.size.x or r.end.y != l.end.y or r.size.y != l.size.y + pad \
					or caps[0].baseline != level_caps[0].baseline:
				faults.append("%s vs level %s" % [r, l])
			if bars.size() == 1 and (bars[0].position.y != r.end.y + 1.0 or bars[0].position.x != r.position.x or bars[0].size.x != r.size.x):
				faults.append("hold bar %s" % bars[0])
		_check(faults.is_empty(), "leap key, %s: level 1-2's keycap grown upward (letters clear of the edges, bottom and word unmoved), the hold bar 1 px under it (%s)" % [device, ", ".join(faults)])
		if device == "remap":
			_restore_bindings(saved)
	_device("keys")
	fake.free()

	# Holding the key fills the bar; the leap (release) fades the key and notes LEAP.
	_key("jump", true)
	await _physics_frames(int(game.slime.charge_time * 30.0))
	_check(game.slime.state == Slime.State.CHARGING, "holding the leap key charges")
	var bars := _pen(cues).rects_of_height(TrainingCues.HOLD_BAR_H)
	var key_w := bars[0].size.x if not bars.is_empty() else 0.0
	_check(bars.size() == 2 and bars[1].size.x > key_w * 0.3 and bars[1].size.x < key_w,
		"the hold bar fills while charging (%s of %s px)" % [bars[1].size.x if bars.size() == 2 else 0.0, key_w])
	_check(cues.leap_alpha > 0.9, "the key stays up while charging (holding is not a leap)")
	_key("jump", false)
	await _physics_frames(40)
	_check(cues.leap_alpha == 0.0 and cues.drawn_alpha == 0.0, "the leap fades the key and clears it")
	_check(progress.training_used & Progress.TUTORIAL_LEAP != 0 and progress.tutorial_seen == 0,
		"the leap is noted in training_used, not in tutorial_seen")

	# Drying up: the accept glyph beside RESTART.
	await _physics_frames(30)
	game.slime_remaining = 0.0
	for i in 300:
		await physics_frame
		if game.hud._choice_root.visible and not game.hud.choice_buttons.is_empty():
			break
	await _physics_frames(5)
	var hud: CanvasLayer = game.hud
	_check(hud.accept_armed and hud.accept_glyph != null, "dry: the HUD arms the accept glyph")
	if hud.accept_glyph:
		var button: Button = hud.choice_buttons[0]
		_check(hud.accept_glyph.visible and hud.accept_glyph.global_position.x >= button.get_global_rect().end.x,
			"dry, keys: the glyph sits right of RESTART")
		var pen := Pen.new()
		TrainingCues.draw_accept(pen, 0.0, 5.0, 0.0)
		_check(Array(pen.strings()) == ["SPACE"], "dry, keys: the accept key reads SPACE (%s)" % [pen.strings()])
		# UI pass: the glyph's box centred on RESTART (its focus frame 1 px outside the rect), GAP_M clear of that
		# frame, letters clear of the edges, inside the screen.
		var b_rect := button.get_global_rect()
		var glyph_pen := Pen.new()
		TrainingCues.draw_accept(glyph_pen, 0.0, hud.accept_glyph.size.y / 2.0, 0.5)  # (0.5 s: the bob's rest phase)
		var caps := _keycaps(glyph_pen)
		var faults := _keycap_faults(caps)
		if caps.size() == 1:
			var at: Rect2 = Rect2(caps[0].rect.position + hud.accept_glyph.global_position, caps[0].rect.size)
			var frame := b_rect.grow(1.0)
			if at.position.y - frame.position.y != frame.end.y - at.end.y:
				faults.append("not centred on RESTART: %s in %s" % [at, frame])
			if at.position.x - frame.end.x != UIKit.GAP_M:
				faults.append("%d px from RESTART's frame" % (at.position.x - frame.end.x))
			if not Rect2(Vector2.ZERO, UIKit.SCREEN).encloses(at):
				faults.append("off screen %s" % at)
		else:
			faults.append("%d keycaps" % caps.size())
		_check(faults.is_empty(), "dry, keys: the accept glyph centred beside RESTART, GAP_M off its frame (%s)" % ", ".join(faults))
		_device("pad")
		await _physics_frames(2)
		pen = Pen.new()
		TrainingCues.draw_accept(pen, 0.0, 5.0, 0.0)
		_check(hud.accept_glyph.visible and Array(pen.strings()) == ["A"], "dry, pad: the accept glyph reads A")
		_device("touch")
		var pulsed := false
		for i in 60:
			await physics_frame
			pulsed = pulsed or button.modulate == hud.ACCEPT_PULSE
		_check(not hud.accept_glyph.visible and pulsed, "dry, touch: no glyph, the RESTART button pulses")
		_device("keys")
		await _physics_frames(2)
		_check(button.modulate == Color.WHITE, "back on keys the button stops pulsing")

	# RESTART (one press of SPACE): attempt 2 shows neither cue again.
	_tap_key(KEY_SPACE)
	for i in 120:
		await physics_frame
		if current_scene != game and current_scene != null and current_scene.is_node_ready():
			break
	game = current_scene
	await _physics_frames(30)
	cues = _cues()
	_check(game.training_attempt == 2 and cues != null, "RESTART: attempt 2 with its training cues")
	if cues:
		game.training_beat("straight")
		await _physics_frames(30)
		_check(cues.move_alpha == 0.0 and cues.leap_alpha == 0.0 and cues.drawn_alpha == 0.0,
			"attempt 2: the move glyph and leap key don't come back once used")
		_check(game.hud.accept_glyph == null, "attempt 2: no accept glyph left over")
	_check(progress.tutorial_seen == 0, "the training run wrote nothing to tutorial_seen")
	await _end_game()


## A fresh run that reaches the chalice before using anything: every cue goes.
func _chalice_case() -> void:
	var cues := await _start_training()
	if cues == null:
		_check(false, "chalice: training cues present")
		await _end_game()
		return
	game.training_beat("straight")
	await _physics_frames(30)
	_check(cues.move_alpha > 0.9 and cues.leap_alpha > 0.9, "fresh run: both cues up (nothing used yet)")
	game.training_beat("chalice")
	await _physics_frames(30)
	_check(cues.move_alpha == 0.0 and cues.leap_alpha == 0.0 and cues.drawn_alpha == 0.0, "chalice: every cue is gone")
	_check(progress.training_used == 0, "nothing noted without a move or a leap")
	await _end_game()


## ---------------------------------------------------------------- helpers

## The keycaps on `pen`: each outer rect in the key's white, the fill inside it and the word drawn next
## ({rect, baseline, text}; a d-pad's arrows are not keycaps).
func _keycaps(pen: Pen) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lines := pen.lines
	for i in lines.size() - 2:
		var a := lines[i].split(" ")
		var b := lines[i + 1].split(" ")
		var c := lines[i + 2]
		if a[0] == "rect" and b[0] == "rect" and c.begins_with("text ") and a[5].begins_with(TutorialCues.KEY_EDGE.to_html(false)):
			var t := c.split(" ")
			out.append({rect = Rect2(float(a[1]), float(a[2]), float(a[3]), float(a[4])), baseline = float(t[2]), text = c.get_slice("'", 1)})
	return out


## The keycap rule (docs/ui-rules.md, Tutorial UI): the word's 7 px letters start 2 rows under the key's top
## (its 1 px edge and 1 clear row) and its drips end on the bottom edge at the lowest.
func _keycap_faults(caps: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for cap in caps:
		var r: Rect2 = cap.rect
		var letters_top: float = cap.baseline - UIKit.TEXT_BODY
		if letters_top < r.position.y + 2.0 or cap.baseline + UIKit.TEXT_DRIP > r.end.y:
			out.append("%s letters %d..%d in %s" % [cap.text, letters_top, cap.baseline + UIKit.TEXT_DRIP - 1, r])
	return out


func _pen(cues: Node) -> Pen:
	var pen := Pen.new()
	cues.draw_cues(pen)
	return pen


## What level 1-2's TutorialCues draw at `time` with these alphas (on `fake`'s touch state).
func _level_pen(fake: FakeGame, time: float, move: float, leap: float) -> Pen:
	var cue := TutorialCues.new()
	cue.game = fake
	cue._time = time
	cue.move_alpha = move
	cue.leap_alpha = leap
	var pen := Pen.new()
	cue.draw_cues(pen)
	cue.free()
	return pen


func _device(device: String) -> void:
	Platform.last_input = {keys = Platform.INPUT_KEYS, pad = Platform.INPUT_PAD, touch = Platform.INPUT_TOUCH}[device]
	if game and game.touch_controls:
		game.touch_controls.visible = device == "touch"


func _end_game() -> void:
	current_scene = null
	if is_instance_valid(game):
		game.free()
	await _physics_frames(2)


func _key(action: String, pressed: bool) -> void:
	for bound in InputMap.action_get_events(action):
		if bound is InputEventKey:
			var event := InputEventKey.new()
			event.physical_keycode = bound.physical_keycode
			event.keycode = bound.keycode
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			return


func _save_bindings() -> Dictionary:
	var saved := {}
	for action: String in ["move_up", "move_left", "move_down", "move_right", "jump"]:
		saved[action] = InputMap.action_get_events(action)
	return saved


func _restore_bindings(saved: Dictionary) -> void:
	for action: String in saved:
		InputMap.action_erase_events(action)
		for event: InputEvent in saved[action]:
			InputMap.action_add_event(action, event)


## Puts `key` first on `action` (as a remap would), for this run only.
func _bind(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	for old in InputMap.action_get_events(action):
		if old is InputEventKey:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)
