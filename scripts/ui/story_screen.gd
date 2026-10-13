extends Control

## The story (see Story and docs/story.md): the intro (a fresh save's first PLAY, or the title's
## STORY button) and the finale (after level 10), each a run of short animated shots drawn in code
## at 320x180 behind letterbox bars, with the shot's lines typed on in the bottom bar.
## A shot moves on by itself after its time; any key, click or tap moves on early; Esc skips the
## lot. Reduce Motion freezes each shot on a still (its `still` moment, particles and all) with no
## shake or zoom, fades the text in, and holds each still at least CALM_HOLD seconds.
##
## Drawing: StageArt (a Node2D moved and scaled as the camera: zooms, bounces, shakes) draws the
## shot behind the slime sprite; its `front` layer draws foreground pillars, particles, speed lines,
## pop-ups and the darkness; Cover draws the letterbox bars and fades in screen space.

signal done

const SCREEN := Vector2(320, 180)
const BAR_TOP := 14.0
const BAR_BOTTOM := 36.0
const TEXT_TOP := 150
## Input is ignored for this long after a shot starts, so a held key can't skip it.
const GRACE := 0.25
const TYPE_DELAY := 0.3
const TYPE_RATE := 42.0
## A Reduce Motion still stays up at least this long, to read it.
const CALM_HOLD := 4.5
const INK := Color8(9, 8, 16)

var mode := "intro"
var next_scene := ""
var cards: Array[Dictionary] = []
var index := 0
var finished := false
var calm := false
## Off in demos: finishing only emits `done` instead of changing scenes.
var leave_on_finish := true

var art: StageArt
var cover: Cover
var text_label: Label
var hint_label: Label
var title_label: Label
var subtitle_label: Label
var slime: AnimatedSprite2D
var _age := 0.0
var _bars := 0.0


func _ready() -> void:
	mode = Story.mode
	next_scene = Story.next_scene
	Story.mode = "intro"
	Story.next_scene = ""
	calm = Progress.reduce_motion
	cards = Story.cards(mode)
	theme = UIKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks reach _unhandled_input
	art = StageArt.new()
	art.screen = self
	add_child(art)
	slime = UIKit.make_slime_preview(Progress.skin_color(), 1, Progress.is_rainbow(), null, Progress.is_stopwatch())
	slime.stop()
	art.add_child(slime)
	art.front = Layer.new()
	art.front.draw_fn = art.draw_front
	art.add_child(art.front)
	cover = Cover.new()
	cover.screen = self
	add_child(cover)
	title_label = _label("", 16, Color8(232, 236, 250), 30)  # not skin-tinted: pale on the dark
	title_label.add_theme_color_override("font_shadow_color", Color(INK, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label = _label("", 8, Color8(150, 160, 196), 50)
	subtitle_label.add_theme_color_override("font_shadow_color", Color(INK, 0.9))
	subtitle_label.add_theme_constant_override("shadow_offset_x", 1)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 1)
	text_label = _label("", 8, UIKit.TEXT, TEXT_TOP, 28)
	hint_label = _label("", 8, UIKit.TEXT_OFF, 4)
	UIKit.add_skin_text(self)
	show_card(0)


func _label(text: String, font_size: int, color: Color, top: int, height := 18) -> Label:
	var label := UIKit.make_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + height
	return label


func show_card(i: int) -> void:
	index = i
	_age = 0.0
	var card: Dictionary = cards[i]
	text_label.text = "\n".join(card.lines)
	text_label.visible_characters = -1 if calm else 0
	title_label.text = card.get("title", "")
	subtitle_label.text = card.get("subtitle", "")
	var last := i == cards.size() - 1
	hint_label.text = "%d/%d   ANY KEY: %s   ESC: SKIP" % [i + 1, cards.size(), "DONE" if last else "NEXT"]
	if calm or i > 0:
		_bars = 1.0
	art.start(card.art)
	if calm:
		art.simulate_to(card.still)
	_apply_fades()


## How long the current shot stays up before moving on by itself.
func card_length() -> float:
	var card: Dictionary = cards[index]
	return maxf(card.time, CALM_HOLD) if calm else card.time


## Next shot, or the end of the sequence after the last one.
func advance() -> void:
	if finished:
		return
	if index + 1 < cards.size():
		show_card(index + 1)
	else:
		finish()


## Marks the sequence as seen and moves on (the next scene, or the title / victory screen).
func finish() -> void:
	if finished:
		return
	finished = true
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		for long_sound in ["sunrise", "whoosh", "crumble", "crack", "splat"]:
			sfx.stop(long_sound)
	Progress.mark_story_seen(Progress.STORY_FINALE if mode == "finale" else Progress.STORY_INTRO)
	done.emit()
	if not leave_on_finish:
		return
	var target := next_scene if next_scene != "" else (UIKit.TITLE_SCENE if mode == "intro" else "res://scenes/victory.tscn")
	UIKit.go(get_tree(), target)


func _process(delta: float) -> void:
	if finished:
		return
	var prev := _age
	_age += delta
	if not calm:
		_bars = minf(_bars + delta / 0.5, 1.0)
		art.step(prev, _age, delta)
		text_label.visible_characters = int(maxf(_age - TYPE_DELAY, 0.0) * TYPE_RATE)
	_apply_fades()
	if _age >= card_length():
		advance()


func _apply_fades() -> void:
	var card: Dictionary = cards[index]
	text_label.modulate.a = clampf(_age / 0.8, 0.0, 1.0) if calm else 1.0
	var title_t := 1.0 + _age if calm else _age - float(card.get("title_at", 0.0))
	title_label.modulate.a = clampf(title_t / 0.8, 0.0, 1.0)
	subtitle_label.modulate.a = clampf((title_t - 0.5) / 0.6, 0.0, 1.0)
	hint_label.modulate.a = clampf((_age - 0.8) / 0.5, 0.0, 0.8) if index == 0 else 0.8
	cover.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("menu") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		finish()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed and _age >= GRACE:
		get_viewport().set_input_as_handled()
		advance()


## A Node2D that draws with someone else's function (the stage's foreground).
class Layer extends Node2D:
	var draw_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)


## Screen-space overlay: letterbox bars, the fade at each shot's start and the finale's gold.
class Cover extends Control:
	var screen: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var fade: Color = screen.art.fade_color()
		if fade.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, SCREEN), fade)
		var e: float = 1.0 - pow(1.0 - screen._bars, 3.0)
		var top := roundf(BAR_TOP * e)
		var bottom := roundf(BAR_BOTTOM * e)
		draw_rect(Rect2(0, 0, SCREEN.x, top), INK)
		draw_rect(Rect2(0, SCREEN.y - bottom, SCREEN.x, bottom), INK)
		if e > 0.99:
			draw_rect(Rect2(0, top, SCREEN.x, 1), Color8(30, 26, 44))
			draw_rect(Rect2(0, SCREEN.y - bottom - 1, SCREEN.x, 1), Color8(30, 26, 44))


## The stage: every shot drawn from code, plus a small particle system and the camera.
class StageArt extends Node2D:
	const SIL := Color8(14, 12, 22)
	const RIM := Color8(150, 82, 50)
	const FLAME := Color8(255, 205, 117)
	const FLAME_HOT := Color8(239, 125, 47)
	const FLAME_TIP := Color8(255, 240, 180)
	const GOLD := Color8(255, 205, 117)
	const GOLD_DARK := Color8(120, 62, 30)
	## Torch-lit stone, cool shadow to warm light (a hue-shifted ramp).
	const WARM := [Color8(18, 16, 30), Color8(32, 28, 48), Color8(52, 42, 62), Color8(86, 60, 66), Color8(132, 86, 70), Color8(176, 120, 82)]
	## Stone under the pale light from the hole (a cool ramp).
	const COOL := [Color8(12, 12, 22), Color8(24, 26, 42), Color8(40, 46, 68), Color8(64, 76, 104), Color8(98, 116, 146), Color8(140, 158, 184)]
	const FLOOR_Y := 112.0
	const STAGE_BOTTOM := 146.0
	const MAX_PARTS := 220
	const RUN_SPEED := 84.0
	## The fall: ten floors (level 10 at the top down to level 1), FALL_TIME seconds.
	const LAYER_H := 118.0
	const FALL_TOP := -70.0
	const FALL_TIME := 4.8
	## Stone colors per theme (from tools/make_theme_art.py): outline k, highlight x, light w,
	## dark W, stain z, accent v, liquid d / glint B.
	const THEME_PAL := {
		"dungeon": {k = Color8(26, 28, 44), x = Color8(194, 210, 222), w = Color8(148, 176, 194), W = Color8(86, 108, 134), z = Color8(62, 74, 96), v = Color8(94, 140, 60), d = Color8(41, 54, 111), B = Color8(94, 130, 190)},
		"mossy": {k = Color8(16, 24, 18), x = Color8(150, 172, 128), w = Color8(104, 126, 90), W = Color8(64, 80, 56), z = Color8(44, 58, 40), v = Color8(98, 164, 62), d = Color8(34, 62, 70), B = Color8(84, 136, 144)},
		"sandstone": {k = Color8(48, 28, 22), x = Color8(248, 224, 166), w = Color8(216, 174, 112), W = Color8(164, 118, 72), z = Color8(126, 86, 54), v = Color8(152, 140, 72), d = Color8(70, 110, 130), B = Color8(130, 180, 200)},
		"sunken": {k = Color8(10, 26, 32), x = Color8(152, 216, 198), w = Color8(88, 162, 150), W = Color8(48, 110, 106), z = Color8(30, 72, 78), v = Color8(62, 152, 112), d = Color8(30, 72, 124), B = Color8(112, 172, 222)},
		"sewers": {k = Color8(22, 18, 16), x = Color8(152, 138, 112), w = Color8(114, 100, 80), W = Color8(76, 66, 52), z = Color8(54, 46, 36), v = Color8(150, 232, 40), d = Color8(92, 152, 22), B = Color8(196, 252, 96)},
		"catacombs": {k = Color8(28, 22, 20), x = Color8(208, 198, 178), w = Color8(158, 148, 132), W = Color8(108, 100, 90), z = Color8(78, 70, 62), v = Color8(112, 120, 82), d = Color8(40, 44, 60), B = Color8(90, 96, 120)},
		"frozen": {k = Color8(16, 24, 50), x = Color8(236, 248, 255), w = Color8(172, 208, 238), W = Color8(112, 152, 202), z = Color8(80, 114, 172), v = Color8(196, 224, 244), d = Color8(82, 132, 192), B = Color8(204, 232, 255)},
		"obsidian": {k = Color8(6, 6, 10), x = Color8(154, 144, 214), w = Color8(72, 68, 104), W = Color8(42, 40, 62), z = Color8(28, 26, 44), v = Color8(124, 72, 176), d = Color8(32, 22, 52), B = Color8(124, 104, 184)},
		"crystal": {k = Color8(22, 10, 32), x = Color8(198, 162, 232), w = Color8(142, 102, 182), W = Color8(94, 62, 132), z = Color8(66, 42, 94), v = Color8(122, 222, 232), d = Color8(62, 42, 112), B = Color8(182, 142, 242)},
		"volcanic": {k = Color8(14, 8, 8), x = Color8(132, 98, 92), w = Color8(92, 66, 64), W = Color8(62, 42, 42), z = Color8(44, 30, 30), v = Color8(90, 84, 82), d = Color8(240, 112, 32), B = Color8(255, 222, 92)},
	}

	var screen: Control
	var front: Layer
	var shot := ""
	var t := 0.0
	var parts: Array[Dictionary] = []
	var shake := 0.0
	const MAX_PHYSICS := 0.25
	var bounce := 0.0
	var bounce_v := 0.0
	var zoom := 1.0
	var focus := Vector2(160, 90)
	var anchor := Vector2(160, 90)
	var silent := false
	var font: Font
	var checker: Texture2D
	var lights: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	var goo: Dictionary
	var pops: Array[Dictionary] = []  # "!" / "?" / "XP!" pop-ups: {text, who, at, life}
	var cracks: Array[Dictionary] = []
	var chunks: Array[Dictionary] = []
	var layers: Array[Dictionary] = []

	func _ready() -> void:
		font = load("res://assets/fonts/pixel.fnt")
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.WHITE)
		image.set_pixel(1, 1, Color.WHITE)
		checker = ImageTexture.create_from_image(image)
		goo = Skins.shades(Progress.skin_color())
		for i in Themes.BY_LEVEL.size():
			var id: String = Themes.BY_LEVEL[Themes.BY_LEVEL.size() - 1 - i]
			layers.append({id = id, name = Themes.display_name(id), pal = THEME_PAL.get(id, THEME_PAL["dungeon"])})

	# --- Timeline ----------------------------------------------------------------------------

	func start(which: String) -> void:
		shot = which
		t = 0.0
		parts.clear()
		pops.clear()
		cracks.clear()
		chunks.clear()
		shake = 0.0
		bounce = 0.0
		bounce_v = 0.0
		rng.seed = hash(which)
		if shot == "crack":
			_make_cracks()
		_cues(-1.0, 0.0)
		_update_camera()
		_place_slime()
		queue_redraw()
		front.queue_redraw()

	## Runs the shot silently up to `at` and freezes there (Reduce Motion stills).
	func simulate_to(at: float) -> void:
		silent = true
		var now := 0.0
		while now < at:
			var dt := minf(1.0 / 30.0, at - now)
			step(now, now + dt, dt)
			now += dt
		silent = false
		shake = 0.0
		bounce = 0.0
		bounce_v = 0.0
		_update_camera()
		_place_slime()

	func step(prev: float, now: float, delta: float) -> void:
		t = now
		_cues(prev, now)
		_emit(prev, now)
		# Physics runs in steps of at most 1/30 s and no more than a quarter second in all, so a long
		# frame (the first one after a web scene load) can't fling the stage off-screen.
		var left := minf(delta, MAX_PHYSICS)
		while left > 0.0:
			var dt := minf(left, 1.0 / 30.0)
			left -= dt
			_update_parts(dt)
			shake = maxf(shake - dt * 14.0, 0.0)
			bounce_v += (-bounce * 260.0 - bounce_v * 12.0) * dt
			bounce += bounce_v * dt
		_update_camera()
		_place_slime()
		queue_redraw()
		front.queue_redraw()

	func _at(prev: float, now: float, when: float) -> bool:
		return prev < when and now >= when

	## How many ticks of a `gap`-second clock (running from `from` to `to`) fell in (prev, now].
	func _every(prev: float, now: float, gap: float, from := 0.0, to := 999.0) -> int:
		if now < from or prev > to:
			return 0
		return int(floor((minf(now, to) - from) / gap)) - int(floor((maxf(prev, from) - from) / gap))

	func _sfx(sound: String, db := -10.0, pitch := 1.0) -> void:
		if silent:
			return
		var sfx := get_node_or_null("/root/Sfx")
		if sfx and sfx.has_sound(sound):
			sfx.play(sound, db, pitch)

	func _kick(amount: float) -> void:
		if not screen.calm:
			shake = maxf(shake, amount)

	## Fade over the whole screen (drawn by Cover): black in at each shot's start, a white flash on
	## the splat, gold at the very end of the finale.
	func fade_color() -> Color:
		if screen.calm:
			return Color(INK, clampf(1.0 - screen._age / 0.5, 0.0, 1.0))
		var c := Color(INK, clampf(1.0 - t / 0.22, 0.0, 1.0))
		match shot:
			"splat":
				c = Color(1, 0.97, 0.9, clampf(1.0 - t / 0.16, 0.0, 1.0))
			"fall":
				c.a = 0.0
			"search":
				if t >= 3.9 and t < 4.2:
					c = Color(INK, 1.0 - (t - 3.9) / 0.3)
				elif t > 4.7:
					c = Color(Color8(255, 214, 140), clampf((t - 4.7) / 1.3, 0.0, 1.0))
		return c

	func _cues(prev: float, now: float) -> void:
		match shot:
			"run":
				for i in 3:
					if _at(prev, now, 0.5 + i * 1.1):
						_pop("!", 2 - i, 0.9)
						_sfx("clank", -15.0, 1.0 - i * 0.08)
			"chase":
				for i in 3:
					if _at(prev, now, 0.35 + i * 0.9):
						_pop("XP!", i, 1.0)
				if _at(prev, now, 1.2):
					_sfx("clank", -16.0, 0.9)
			"crack":
				if _at(prev, now, 0.55):
					_pop("?", -1, 1.0)
				if _at(prev, now, 0.75):
					_sfx("crack", -9.0)
					_kick(1.0)
				if _at(prev, now, 1.6):
					_sfx("crack", -8.0, 0.85)
					_kick(1.5)
				if _at(prev, now, 2.35):
					_sfx("crumble", -6.0, 0.8)
					_kick(3.0)
					_pop("!", -1, 0.6)
					for i in 3:
						_pop("!", i, 1.2)
					_break_floor()
			"fall":
				if _at(prev, now, 0.0):
					_sfx("whoosh", -9.0)
				if _at(prev, now, 2.2):
					_sfx("whoosh", -12.0, 0.8)
			"splat":
				if _at(prev, now, 0.0):
					_sfx("splat", -3.0, 0.7)
					_kick(7.0)
					bounce_v = 150.0
					_goo_ring()
			"daylight":
				if _at(prev, now, 0.55):
					_sfx("jump", -6.0, 0.8)
					_burst_crater()
				if _at(prev, now, 1.5):
					_sfx("land", -6.0)
				if _at(prev, now, 2.0):
					_sfx("sunrise", -8.0)
			"search":
				if _at(prev, now, 1.9):
					_pop("+1 LOOT", 0, 1.6)
					_sfx("coin", -14.0, 0.8)
				if _at(prev, now, 3.9):
					_sfx("sunrise", -11.0, 1.12)

	## Continuous emitters: torch sparks, trail goo, dust, falling grit.
	func _emit(prev: float, now: float) -> void:
		# The heroes and torches depend only on the shot and t, which hold for this whole step:
		# work them out once (no RNG involved, so the sparks come out exactly the same).
		var heroes: Array[Dictionary] = []
		if shot in ["run", "chase", "search"]:
			heroes = _heroes()
		var torches: Array[Vector2] = []
		if shot in ["run", "chase", "crack"]:
			torches = _wall_torches()
		match shot:
			"run", "chase":
				for i in _every(prev, now, 0.05):
					var hero: Dictionary = heroes[rng.randi_range(0, 1)]
					_spark(hero.tip, Vector2(-40 + rng.randf_range(-20, 10), rng.randf_range(-40, -10)))
				for i in _every(prev, now, 0.07):
					_trail_drop()
				for i in _every(prev, now, 0.12):
					for torch in torches:
						_spark(torch + Vector2(0, -5), Vector2(rng.randf_range(-6, 6), rng.randf_range(-28, -12)))
			"crack":
				for i in _every(prev, now, 0.05, 0.75, 2.6):
					var p := _crack_reach(cracks[rng.randi_range(0, cracks.size() - 1)])
					if p.x > 0:
						_dust(p, 1)
				for i in _every(prev, now, 0.09, 0.8, 3.4):
					_part({p = Vector2(rng.randf_range(70, 230), 52.0), v = Vector2(0, rng.randf_range(10, 40)), g = 300.0,
						life = 1.0, c = Color8(70, 62, 84), s = 1.0 if rng.randf() < 0.6 else 2.0})
				for i in _every(prev, now, 0.18):
					for torch in torches:
						_spark(torch + Vector2(0, -5), Vector2(rng.randf_range(-6, 6), rng.randf_range(-28, -12)))
			"splat":
				for i in _every(prev, now, 0.15, 0.0, 1.4):
					_part({p = Vector2(rng.randf_range(150, 170), 16.0), v = Vector2(rng.randf_range(-6, 6), 30), g = 260.0,
						life = 1.3, c = COOL[4], s = 1.0, floor = 120.0})
			"daylight":
				for i in _every(prev, now, 0.07, 0.0, 2.0):
					_part({p = Vector2(rng.randf_range(120, 148), 112.0), v = Vector2(rng.randf_range(-8, 8), rng.randf_range(-50, -20)),
						g = -10.0, life = 1.0, c = FLAME_HOT if rng.randf() < 0.6 else FLAME, s = 1.0})
				for i in _every(prev, now, 0.2):
					_part({p = Vector2(rng.randf_range(124, 144), 108.0), v = Vector2(rng.randf_range(4, 12), rng.randf_range(-14, -8)),
						g = 0.0, life = 2.4, c = Color(Color8(120, 100, 120), 0.5), s = 2.0, fade = true})
			"search":
				for i in _every(prev, now, 0.06, 0.0, 3.9):
					var hero: Dictionary = heroes[rng.randi_range(0, 1)]
					_spark(hero.tip, Vector2(rng.randf_range(-6, 6), rng.randf_range(-30, -12)))

	func _part(d: Dictionary) -> void:
		if parts.size() >= MAX_PARTS:
			parts.pop_front()
		d.age = 0.0
		if not d.has("v"):
			d.v = Vector2.ZERO
		parts.append(d)

	func _spark(p: Vector2, v: Vector2) -> void:
		_part({p = p, v = v, g = -20.0, life = rng.randf_range(0.35, 0.7), c = FLAME if rng.randf() < 0.5 else FLAME_HOT, s = 1.0})

	func _dust(p: Vector2, count: int) -> void:
		for i in count:
			_part({p = p + Vector2(rng.randf_range(-2, 2), 0), v = Vector2(rng.randf_range(-24, 24), rng.randf_range(-22, -4)),
				g = 20.0, drag = 2.5, life = rng.randf_range(0.5, 0.9), c = Color8(92, 84, 104), s = 2.0, fade = true})

	func _trail_drop() -> void:
		var x := _run_slime_x()
		var c: Color = goo.mid if rng.randf() < 0.6 else goo.dark
		_part({p = Vector2(x - 4, FLOOR_Y + 1), v = Vector2(-RUN_SPEED, 0), life = 1.6, c = c, s = 2.0, flat = true, back = true})
		if rng.randf() < 0.35:
			_part({p = Vector2(x - 5, FLOOR_Y - 5), v = Vector2(-RUN_SPEED * 0.5 - rng.randf_range(10, 40), rng.randf_range(-50, -20)),
				g = 380.0, life = 0.6, c = goo.light, s = 1.0, floor = FLOOR_Y + 1.0})

	func _goo_ring() -> void:
		for i in 34:
			var a := PI + PI * (i + rng.randf()) / 34.0
			var speed := rng.randf_range(60, 180)
			var c: Color = [goo.highlight, goo.light, goo.mid, goo.mid, goo.dark][i % 5]
			_part({p = Vector2(160, 116), v = Vector2(cos(a) * speed * 1.4, sin(a) * speed), g = 420.0, life = 3.5,
				c = c, s = 2.0 if i % 3 == 0 else 1.0, floor = 121.0, stick = true})
		for i in 14:
			_part({p = Vector2(160 + rng.randf_range(-12, 12), 119), v = Vector2(rng.randf_range(-70, 70), rng.randf_range(-16, -4)),
				g = 0.0, drag = 3.0, life = 1.2, c = Color8(64, 70, 96), s = 2.0, fade = true})

	func _burst_crater() -> void:
		for i in 24:
			var a := -PI * 0.5 + rng.randf_range(-0.7, 0.7)
			var speed := rng.randf_range(60, 150)
			var lava := i % 2 == 0
			_part({p = Vector2(134, 112), v = Vector2(cos(a), sin(a)) * speed, g = 260.0, life = 1.4,
				c = (FLAME_HOT if i % 4 == 0 else FLAME) if lava else goo.light, s = 1.0 if i % 3 else 2.0})

	func _update_parts(delta: float) -> void:
		var keep: Array[Dictionary] = []
		for p in parts:
			p.age += delta
			if p.age >= p.life:
				continue
			if p.get("stuck", false):
				keep.append(p)
				continue
			p.v.y += p.get("g", 0.0) * delta
			if p.has("drag"):
				p.v *= maxf(0.0, 1.0 - p.drag * delta)
			p.p += p.v * delta
			if p.has("floor") and p.p.y >= p.floor and p.v.y > 0:
				p.p.y = p.floor
				if p.get("stick", false):
					p.stuck = true
				else:
					p.v = Vector2(p.v.x * 0.3, -p.v.y * 0.2)
			keep.append(p)
		parts = keep

	func _draw_parts(canvas: CanvasItem, back: bool) -> void:
		for p in parts:
			if p.get("back", false) != back:
				continue
			var c: Color = p.c
			var life_left: float = 1.0 - p.age / p.life
			if p.get("fade", false):
				c.a *= life_left
			elif life_left < 0.3:
				c.a *= life_left / 0.3
			var s: float = p.s
			var pos: Vector2 = p.p.round()
			if p.get("flat", false) or p.get("stuck", false):
				canvas.draw_rect(Rect2(pos.x - s * 0.5, pos.y, s + 1, 1), c)
			else:
				canvas.draw_rect(Rect2(pos, Vector2(s, s)), c)

	# --- Pop-ups ("!", "?", "XP!") -------------------------------------------------------------

	## who: hero index 0-2, or -1 for the slime.
	func _pop(text: String, who: int, life: float) -> void:
		pops.append({text = text, who = who, at = t, life = life})

	func _draw_pops(canvas: CanvasItem) -> void:
		var heroes := _heroes()
		for pop in pops:
			var age: float = t - pop.at
			if age < 0.0 or age > pop.life:
				continue
			var base: Vector2
			if pop.who < 0:
				base = screen.slime.position + Vector2(0, -16)
			elif pop.who < heroes.size():
				base = heroes[pop.who].foot + Vector2(0, -35)
			else:
				continue
			var lift := minf(age * 30.0, 4.0)
			var sc := 2 if pop.text.length() == 1 and zoom < 1.5 else 1  # a lone "!" reads better big
			if age < 0.08 and not screen.calm:
				sc += 1  # pops in big for a frame or two
			_outlined_text(canvas, pop.text, base + Vector2(0, -lift - 4 * (sc - 1)), GOLD, sc)

	## Pixel text with a dark outline, centered on `center`; scale in whole pixels.
	func _outlined_text(canvas: CanvasItem, text: String, center: Vector2, color: Color, scale_px := 1) -> void:
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * scale_px
		var origin := (center - Vector2(width * 0.5, -3.0 * scale_px)).round()
		canvas.draw_set_transform(origin, 0.0, Vector2(scale_px, scale_px))
		var edge := GOLD_DARK if color == GOLD else INK
		edge.a = color.a
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
			canvas.draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, edge)
		canvas.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- Camera ------------------------------------------------------------------------------

	func _update_camera() -> void:
		zoom = 1.0
		focus = Vector2(160, 90)
		anchor = Vector2(160, 90)
		match shot:
			"chase":
				zoom = 2.0
				focus = Vector2(108, 94)
				anchor = Vector2(160, 84)
			"crack":
				zoom = 2.0
				focus = Vector2(148, 104)
				anchor = Vector2(160, 84)
			"fall":
				focus = Vector2(160, _fall_cam() + 90.0)
			"splat":
				var z := 0.0 if screen.calm else _smooth(clampf((t - 1.6) / 3.4, 0.0, 1.0))
				zoom = 1.0 + z
				focus = Vector2(160, 90).lerp(Vector2(160, 108), z)
				anchor = Vector2(160, 90).lerp(Vector2(160, 96), z)
		var offset := Vector2.ZERO
		if shake > 0.0 and not screen.calm:
			offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
		offset.y += bounce
		scale = Vector2(zoom, zoom)
		position = (anchor - focus * zoom + offset).round()

	## The part of the stage in view, in stage coordinates.
	func _view() -> Rect2:
		return Rect2(-position / zoom, SCREEN / zoom)

	static func _smooth(x: float) -> float:
		return x * x * (3.0 - 2.0 * x)

	# --- The slime ---------------------------------------------------------------------------

	func _set_anim(anim: String, frame: int) -> void:
		var s: AnimatedSprite2D = screen.slime
		if s.animation != anim:
			s.animation = anim
		s.frame = clampi(frame, 0, s.sprite_frames.get_frame_count(anim) - 1)

	func _run_slime_x() -> float:
		return 200.0 if shot == "run" else 168.0

	func _place_slime() -> void:
		var s: AnimatedSprite2D = screen.slime
		if s == null:
			return
		s.visible = true
		match shot:
			"run", "chase":
				_set_anim("glide_e", int(t * 16.0) % 4)
				s.position = Vector2(_run_slime_x(), FLOOR_Y - 8)
			"crack":
				var arrive := clampf(t / 0.5, 0.0, 1.0)
				var x := lerpf(96.0, 160.0, 1.0 - pow(1.0 - arrive, 3.0))
				var y := FLOOR_Y - 8
				if t < 0.4:
					_set_anim("glide_e", int(t * 16.0) % 4)
				elif t < 0.65:
					_set_anim("land_e", int((t - 0.4) * 16.0))
				elif t < 2.35:
					_set_anim("idle", 0 if fmod(t, 1.3) < 1.15 else 3)
					if t > 1.6 and not screen.calm:
						x += 1.0 if int(t * 30.0) % 2 == 0 else -1.0  # trembling
				elif t < 2.6:
					_set_anim("air_s", 3)  # a cartoon beat: hanging over nothing
				else:
					_set_anim("air_s", 0)
					y += 0.5 * 700.0 * pow(t - 2.6, 2.0)
				s.position = Vector2(x, y)
				s.visible = y < 200
			"fall":
				_set_anim("air_s", 0 if int(t * 10.0) % 3 else 1)
				s.position = Vector2(160 + roundf(sin(t * 2.6) * 5.0), _fall_cam() + 72.0)
			"splat":
				if t < 0.45:
					_set_anim("splat_s", 0)
				elif t < 0.85:
					_set_anim("splat_s", 1 + int((t - 0.45) * 7.5))
				else:
					var blink := fmod(t - 0.85, 1.7) > 1.52
					_set_anim("idle", 3 if blink else int(t * 3.0) % 3)
				s.position = Vector2(160, 112)
			"daylight":
				_place_daylight_slime(s)
			"search":
				s.visible = t >= 3.9
				_set_anim("celebrate", int(t * 8.0) % 4)
				s.position = Vector2(186, 101)

	func _place_daylight_slime(s: AnimatedSprite2D) -> void:
		var start := Vector2(134, 114)
		var land := Vector2(186, 101)
		s.position = land
		if t < 0.55:
			s.visible = false
			s.position = start
		elif t < 1.5:
			var u := (t - 0.55) / 0.95
			var p := start.lerp(land, u)
			p.y -= sin(u * PI) * 64.0
			s.position = p
			if u < 0.2:
				_set_anim("launch_n", 1)
			else:
				_set_anim("air_ne" if u < 0.55 else "air_se", int(u * 4.0))
		elif t < 1.75:
			_set_anim("land_se", int((t - 1.5) * 16.0))
		elif t < 2.6:
			_set_anim("idle", 0 if fmod(t, 1.0) < 0.85 else 3)
		elif t < 3.5:
			_set_anim("launch_ne", 0 if t < 2.75 else 1)  # stretching toward the light
		else:
			_set_anim("celebrate", int(t * 8.0) % 4)

	# --- Drawing -----------------------------------------------------------------------------

	func _draw() -> void:
		lights.clear()
		match shot:
			"run", "chase":
				_draw_corridor(t * RUN_SPEED, _heroes())
			"crack":
				_draw_crack()
			"fall":
				_draw_fall()
			"splat":
				_draw_splat()
			"daylight":
				_draw_daylight(t)
			"search":
				if t < 3.9:
					_draw_search()
				else:
					_draw_daylight(7.0 + t)
		var s: AnimatedSprite2D = screen.slime
		if s.visible and shot != "splat":
			_halo(self, s.position + Vector2(0, 2), 18.0, goo.light, 0.045)
		_draw_parts(self, true)

	func draw_front(canvas: CanvasItem) -> void:
		match shot:
			"run":
				_draw_pillars(canvas, t * RUN_SPEED)
				_draw_motion_lines(canvas)
			"chase":
				_draw_motion_lines(canvas)
				_draw_zzz(canvas)
			"fall":
				_draw_fall_front(canvas)
			"splat":
				var r := 48.0 if screen.calm else lerpf(260.0, 44.0, _smooth(clampf((t - 0.7) / 2.2, 0.0, 1.0)))
				_draw_dark(canvas, Vector2(160, 104), r)
		_draw_parts(canvas, false)
		_draw_pops(canvas)

	## A banded halo (hard rings, like the game's lights).
	func _halo(canvas: CanvasItem, c: Vector2, r: float, color: Color, alpha := 0.07) -> void:
		for i in 3:
			canvas.draw_circle(c.round(), roundf(r * (1.0 - i * 0.3)), Color(color, alpha))

	## How lit a spot is, in ramp steps 0-5; `dither` (from _bayer) breaks the edges between steps
	## into a checker, like hand-dithered pixel art.
	func _light_band(p: Vector2, dither := 0.0) -> int:
		var sum := 0.0
		for l in lights:
			var d := p.distance_to(Vector2(l.x, l.y))
			if d < l.z:
				sum += 1.0 - d / l.z
		return clampi(int(sum * 4.0 + dither), 0, 5)

	## Ordered 2x2 dither offset for brick (col, row).
	static func _bayer(col: int, row: int) -> float:
		return [0.0, 0.5, 0.75, 0.25][posmod(col, 2) + posmod(row, 2) * 2]

	func _flicker(seed: float) -> float:
		return 1.0 if screen.calm else 0.9 + 0.1 * sin(t * 23.0 + seed * 3.1) * sin(t * 7.0 + seed)

	# --- Run / chase / crack: the torch-lit corridor ------------------------------------------

	## The three adventurers this frame: {foot, kind, run (stride speed), torch (angle), tip}.
	func _heroes() -> Array[Dictionary]:
		var list: Array[Dictionary] = []
		match shot:
			"run", "chase":
				var xs: Array = [80.0, 50.0, 22.0] if shot == "run" else [74.0, 46.0, 18.0]
				for i in 3:
					var x: float = xs[i] + (0.0 if screen.calm else sin(t * 1.3 + i * 2.0) * 6.0)
					list.append(_hero_at(Vector2(roundf(x), FLOOR_Y), i, 1.0, sin(t * 9.0 + i * 1.7) * 0.45 + 0.35))
			"crack":
				var arrive := _smooth(clampf((t - 0.9) / 0.9, 0.0, 1.0))
				var xs: Array = [112.0, 94.0, 76.0]
				for i in 3:
					var x: float = lerpf(-30.0 - i * 26.0, xs[i], arrive)
					list.append(_hero_at(Vector2(roundf(x), FLOOR_Y), i, 1.0 if arrive < 0.98 else 0.0, sin(t * 6.0 + i) * 0.25 + 0.3))
			"search":
				var spots := [Vector2(150, 120), Vector2(112, 120), Vector2(200, 120)]
				for i in 3:
					var hero := _hero_at(spots[i], i, 0.0, sin(t * 2.0 + i) * 0.15 + 0.2)
					hero.crouch = i == 0
					list.append(hero)
		return list

	func _hero_at(foot: Vector2, kind: int, run: float, torch: float) -> Dictionary:
		var hero := {foot = foot, kind = kind, run = run, torch = torch, crouch = false}
		if kind == 2:
			hero.tip = foot + Vector2(7, -29)
		else:
			hero.tip = foot + _hand(kind, run) + Vector2(sin(torch), -cos(torch)) * 9.0
		return hero

	func _hand(kind: int, run: float) -> Vector2:
		var bob := -1.0 if run > 0.0 and absf(sin(t * run * 11.0)) < 0.5 else 0.0
		return Vector2(7, -16 + bob) if kind == 0 else Vector2(6, -15 + bob)

	func _wall_torches() -> Array[Vector2]:
		var list: Array[Vector2] = []
		var wall_scroll := _scroll() * 0.75
		var first := floorf((wall_scroll - 40.0) / 150.0)
		for k in 4:
			var x := (first + k) * 150.0 + 75.0 - wall_scroll
			if x > -40.0 and x < 360.0:
				list.append(Vector2(roundf(x), 60))
		return list

	func _scroll() -> float:
		match shot:
			"run", "chase":
				return t * RUN_SPEED
			"crack":
				return _crack_scroll()
		return 0.0

	func _crack_scroll() -> float:
		return 520.0

	func _draw_corridor(s: float, heroes: Array[Dictionary]) -> void:
		var view := _view()
		var torches := _wall_torches()
		for torch in torches:
			lights.append(Vector3(torch.x, torch.y, 70.0 * _flicker(torch.x)))
		for hero in heroes:
			if hero.kind == 2:
				lights.append(Vector3(hero.tip.x, hero.tip.y, 30.0))
			else:
				lights.append(Vector3(hero.tip.x, hero.tip.y, 62.0 * _flicker(hero.kind + 2.0)))
		draw_rect(Rect2(view.position.x - 2, 0, view.size.x + 4, FLOOR_Y), WARM[0])
		_draw_arches(s, view)
		_draw_bricks(s * 0.75, view)
		for torch in torches:
			_draw_wall_torch(torch)
		_draw_floor(s, view, WARM)
		# Long shadows thrown forward by the torches behind: the slime's, then the heroes' own.
		var sx: float = screen.slime.position.x
		if shot != "crack" or t < 2.35:
			draw_colored_polygon(PackedVector2Array([Vector2(sx - 6, FLOOR_Y + 1), Vector2(sx + 6, FLOOR_Y + 1),
				Vector2(sx + 62, FLOOR_Y + 5), Vector2(sx + 30, FLOOR_Y + 5)]), Color(INK, 0.45))
		for hero in heroes:
			var f: Vector2 = hero.foot
			draw_colored_polygon(PackedVector2Array([f + Vector2(-4, 1), f + Vector2(4, 1), f + Vector2(44, 6), f + Vector2(24, 6)]), Color(INK, 0.4))
		if shot == "chase":  # their huge shadows on the wall, swaying with the torches
			for hero in heroes:
				var sway := sin(t * 9.0 + hero.kind * 1.7) * 5.0
				_hero(self, hero.foot + Vector2(-14 + sway, -8), hero.kind, 1.0, hero.torch, 2.0, Color8(16, 12, 24), false, false, false)
		for hero in heroes:
			_draw_hero_with_light(hero)

	func _draw_hero_with_light(hero: Dictionary) -> void:
		var tip: Vector2 = hero.tip
		if hero.kind == 2:
			_halo(self, tip, 22.0, Color8(140, 190, 255), 0.06)
		else:
			_halo(self, tip, 40.0 * _flicker(hero.kind + 2.0), FLAME_HOT, 0.05)
		_hero(self, hero.foot, hero.kind, hero.run, hero.torch, 1.0, SIL, true, true, hero.crouch)

	func _draw_arches(s: float, view: Rect2) -> void:
		var first := floorf(s * 0.75 / 150.0) - 1
		for k in 5:
			var x := roundf((first + k) * 150.0 - s * 0.75)
			if x < view.position.x - 40 or x > view.end.x + 10:
				continue
			var arch := Rect2(x + 2, 40, 30, FLOOR_Y - 40)
			draw_rect(arch, Color8(10, 9, 18))
			draw_circle(Vector2(arch.position.x + 15, 40), 15, Color8(10, 9, 18))
			# Deep inside: a far corridor sliding by more slowly, one dim torch in it.
			var deep_x := fposmod(-s * 0.4 + 7.0 * (first + k), 30.0)
			draw_rect(Rect2(arch.position.x + roundf(deep_x), 56, 2, FLOOR_Y - 56), Color8(22, 18, 30))
			draw_rect(Rect2(arch.position.x + roundf(fposmod(deep_x + 14, 30)), 64, 1, 2), Color8(150, 80, 44))
			draw_rect(Rect2(arch.position.x, FLOOR_Y - 3, 30, 3), Color8(18, 14, 26))

	func _draw_bricks(scroll: float, view: Rect2) -> void:
		var row_h := 7.0
		var y := 14.0
		var row := 0
		var bw := 20.0
		while y < FLOOR_Y:
			var offset := 10.0 if row % 2 else 0.0
			var first := floorf((scroll + view.position.x - offset) / bw) - 1
			var x := first * bw + offset - scroll
			while x < view.end.x + bw:
				if not _in_arch(x + 10.0, y, scroll):
					var band := _light_band(Vector2(x + bw * 0.5, y + 3), _bayer(int(roundf((x + scroll) / bw)), row) - 0.25)
					var c: Color = WARM[band]
					var jitter := int(absf(sin((x + scroll) * 12.9898 + row * 78.233)) * 3.0)
					if jitter == 2 and band > 0:
						c = c.lerp(WARM[band - 1], 0.5)
					draw_rect(Rect2(roundf(x) + 1, y + 1, bw - 1, row_h - 1), c)
					if band >= 2:
						draw_rect(Rect2(roundf(x) + 1, y + 1, bw - 1, 1), WARM[mini(band + 1, 5)])
				x += bw
			y += row_h
			row += 1
		draw_rect(Rect2(view.position.x - 2, FLOOR_Y - 4, view.size.x + 4, 4), Color(INK, 0.5))

	func _in_arch(x: float, y: float, scroll: float) -> bool:
		var local := fposmod(x + scroll, 150.0)
		return local > 0 and local < 36 and y >= 26

	func _draw_wall_torch(p: Vector2) -> void:
		_halo(self, p + Vector2(0, -4), 46.0 * _flicker(p.x), FLAME_HOT, 0.05)
		draw_rect(Rect2(p.x - 2, p.y, 5, 2), Color8(40, 30, 34))
		draw_rect(Rect2(p.x - 1, p.y + 2, 3, 4), Color8(30, 22, 28))
		_flame(self, p + Vector2(0, -1), 1.0, p.x, 0.0, 1.5)

	## A flickering flame whose base sits at p (sc scales whole pixels).
	func _flame(canvas: CanvasItem, p: Vector2, sc: float, seed: float, lean: float, size := 1.0) -> void:
		var fi := 0 if screen.calm else int(t * 14.0 + seed * 7.0) % 4
		var h: float = (4.0 + [0.0, 1.0, 2.0, 1.0][fi]) * size
		var w := roundf(3.0 * size)
		var base := p.round()
		canvas.draw_rect(Rect2(base + Vector2(-floorf(w * 0.5), -roundf(h * 0.55)) * sc, Vector2(w, roundf(h * 0.55)) * sc), FLAME_HOT)
		canvas.draw_rect(Rect2(base + Vector2(-floorf(w * 0.5) + roundf(lean * 0.5), -roundf(h * 0.85)) * sc, Vector2(maxf(w - 1, 1), roundf(h * 0.45)) * sc), FLAME)
		canvas.draw_rect(Rect2(base + Vector2(lean, -roundf(h)) * sc, Vector2(1, 1) * sc), FLAME_TIP)
		canvas.draw_rect(Rect2(base + Vector2(0, -roundf(h * 0.45)) * sc, Vector2(1, 2) * sc), FLAME_TIP)

	func _draw_floor(s: float, view: Rect2, ramp: Array) -> void:
		var bottom := STAGE_BOTTOM + 4
		var x := floorf(view.position.x / 8.0) * 8.0
		while x < view.end.x:
			var band := _light_band(Vector2(x + 4, FLOOR_Y + 6))
			draw_rect(Rect2(x, FLOOR_Y, 8, bottom - FLOOR_Y), ramp[maxi(band - 1, 0)])
			draw_rect(Rect2(x, FLOOR_Y, 8, 2), ramp[mini(band + 1, 5)] if band > 0 else ramp[1])
			x += 8
		for y in [119.0, 128.0, 140.0]:
			draw_rect(Rect2(view.position.x, y, view.size.x, 1), Color(INK, 0.55))
		var spacing := 28.0
		var first := floorf((s + view.position.x - 160.0) / spacing) - 3
		for k in 20:
			var top_x := (first + k) * spacing - s
			var bottom_x := 160.0 + (top_x - 160.0) * 1.8
			if maxf(top_x, bottom_x) < view.position.x - 4 or minf(top_x, bottom_x) > view.end.x + 4:
				continue
			draw_line(Vector2(roundf(top_x), FLOOR_Y + 2), Vector2(roundf(bottom_x), bottom), Color(INK, 0.55), 1.0)

	func _draw_pillars(canvas: CanvasItem, s: float) -> void:
		var near := s * 1.6
		var first := floorf(near / 340.0) - 1
		for k in 3:
			var x := roundf((first + k) * 340.0 + 250.0 - near)
			if x < -40 or x > 330:
				continue
			canvas.draw_rect(Rect2(x, 0, 26, 180), Color8(7, 6, 12))
			canvas.draw_rect(Rect2(x + 25, 0, 1, 180), Color8(70, 40, 36))
			canvas.draw_rect(Rect2(x - 3, 126, 32, 54), Color8(7, 6, 12))
			canvas.draw_rect(Rect2(x - 3, 126, 32, 1), Color8(60, 36, 34))

	func _draw_motion_lines(canvas: CanvasItem) -> void:
		if screen.calm:
			return
		var base: Vector2 = screen.slime.position
		for i in 5:
			var phase := fposmod(t * 6.0 + i * 0.37, 1.0)
			var length := 6.0 + (i * 5) % 11
			var x := base.x - 10.0 - phase * 30.0
			var y := base.y - 5.0 + (i * 3) % 12
			canvas.draw_rect(Rect2(roundf(x - length), y, length, 1), Color(goo.highlight, 0.55 * (1.0 - phase)))

	func _draw_zzz(canvas: CanvasItem) -> void:
		var base: Vector2 = screen.slime.position
		for i in 3:
			var age := fposmod(t * 0.9 + i / 3.0, 1.0)
			var p := base + Vector2(-6.0 - age * 26.0, -12.0 - age * 18.0 + sin(age * 9.0) * 2.0)
			_outlined_text(canvas, "Z" if i == 1 else "z", p, Color(Color8(196, 210, 238), 1.0 - age * age))

	## An adventurer's silhouette, foot at `foot`, facing right; sc scales whole pixels.
	## kind: 0 knight (helmet, plume, shield, torch), 1 rogue (hood, cape, torch), 2 wizard (hat, staff).
	func _hero(canvas: CanvasItem, foot: Vector2, kind: int, run: float, torch_a: float, sc: float, col: Color,
			rim: bool, flame: bool, crouch: bool) -> void:
		var ph := t * run * 11.0
		var a := sin(ph) if run > 0.0 else 0.0
		var by := -1.0 if run > 0.0 and absf(a) < 0.5 else 0.0
		var cy := 3.0 if crouch else 0.0
		var lean := 2.0 if crouch else 0.0
		var f := foot.round()
		var rc := func(x: float, y: float, w: float, h: float, c: Color) -> void:
			canvas.draw_rect(Rect2(f + Vector2(x, y) * sc, Vector2(w, h) * sc), c)
		var r := func(x: float, y: float, w: float, h: float) -> void:
			canvas.draw_rect(Rect2(f + Vector2(x, y) * sc, Vector2(w, h) * sc), col)
		var poly := func(points: Array) -> void:
			var packed := PackedVector2Array()
			for p: Vector2 in points:
				packed.append(f + p * sc)
			canvas.draw_colored_polygon(packed, col)
		var leg := roundf(a * 3.0)
		var lift_a := 1.0 if run > 0.0 and cos(ph) > 0.3 else 0.0
		var lift_b := 1.0 if run > 0.0 and cos(ph) < -0.3 else 0.0
		if kind == 2:
			r.call(-2 - leg, -7, 2, 7 - lift_a)
			r.call(1 + leg, -7, 2, 7 - lift_b)
			poly.call([Vector2(-6, -3 + by), Vector2(5, -3 + by), Vector2(3, -17 + by), Vector2(-3, -17 + by)])
			r.call(-3, -21 + by, 6, 4)
			r.call(-6, -22 + by, 12, 1)
			poly.call([Vector2(-3, -22 + by), Vector2(3, -22 + by), Vector2(-2, -29 + by), Vector2(-6, -31 + by)])
			r.call(2, -18 + by, 3, 5)  # beard
			r.call(6, -28, 1, 28)  # staff
			if flame:
				rc.call(5, -31, 3, 3, Color8(140, 190, 255))
				rc.call(6, -30, 1, 1, Color8(236, 248, 255))
			if rim:
				rc.call(3, -16 + by, 1, 12, RIM.darkened(0.3))
			return
		r.call(-2 - leg, -8, 2, 8 - lift_a)
		r.call(1 + leg, -8, 2, 8 - lift_b)
		r.call(-3 - leg, -1 - lift_a, 3, 1)
		r.call(1 + leg, -1 - lift_b, 3, 1)
		if kind == 0:
			r.call(-4 + lean, -17 + by + cy, 8, 10 - cy)
			r.call(2 + lean, -17 + by + cy, 3, 3)
			r.call(-3 + lean * 2, -23 + by + cy, 6, 6)
			r.call(-2 + lean * 2, -24 + by + cy, 4, 1)
			r.call(-5 + lean * 2, -25 + by + cy, 3, 2)
			r.call(-7 + lean * 2, -24 + by + cy, 2, 2)
			r.call(-8 + lean * 2, -22 + by + cy, 1, 2)
			r.call(-7 + lean, -17 + by + cy, 4, 8)
			if rim:
				rc.call(1 + lean * 2, -21 + by + cy, 2, 1, Color8(255, 196, 120))  # visor glint
				rc.call(3 + lean, -14 + by + cy, 1, 6, RIM)
				rc.call(-6 + lean, -14 + by + cy, 1, 1, Color8(110, 104, 120))  # shield boss
		else:
			var flap := 0.0 if screen.calm or run <= 0.0 else roundf(sin(t * 14.0) * 2.0)
			poly.call([Vector2(-2, -18 + by), Vector2(-10 - flap, -13 + by), Vector2(-9 - flap, -4), Vector2(-2, -7)])
			r.call(-3 + lean, -16 + by + cy, 6, 9 - cy)
			r.call(-3 + lean * 2, -22 + by + cy, 6, 6)
			r.call(-5 + lean * 2, -23 + by + cy, 3, 2)
			rc.call(-5, -10 + by, 3, 1, Color8(120, 120, 140) if rim else col)  # dagger
			if rim:
				rc.call(2 + lean, -15 + by + cy, 1, 7, RIM)
				rc.call(2 + lean * 2, -21 + by + cy, 1, 4, RIM)
		# The torch arm and the torch.
		var hand := _hand(kind, run) + Vector2(lean, cy)
		var shoulder := Vector2(2 + lean, -15 + by + cy)
		canvas.draw_line(f + shoulder * sc, f + hand * sc, col, sc)
		var tip := hand + Vector2(sin(torch_a), -cos(torch_a)) * 9.0
		canvas.draw_line(f + hand * sc, f + tip * sc, Color8(50, 34, 30) if rim else col, sc)
		if flame:
			_flame(canvas, f + tip * sc, sc, kind * 3.0, -1.0 if run > 0.0 else 0.0)

	# --- Crack --------------------------------------------------------------------------------

	func _make_cracks() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 4242
		var specs := [
			[Vector2(160, FLOOR_Y), Vector2(161, STAGE_BOTTOM), 0.75, 0.9],
			[Vector2(160, FLOOR_Y), Vector2(124, FLOOR_Y + 2), 0.8, 0.8],
			[Vector2(160, FLOOR_Y), Vector2(198, FLOOR_Y + 1), 0.85, 0.75],
			[Vector2(158, FLOOR_Y + 9), Vector2(130, STAGE_BOTTOM), 1.4, 0.7],
			[Vector2(162, FLOOR_Y + 7), Vector2(192, STAGE_BOTTOM), 1.5, 0.7],
			[Vector2(140, FLOOR_Y + 1), Vector2(128, FLOOR_Y + 16), 1.8, 0.4],
			[Vector2(180, FLOOR_Y + 1), Vector2(196, FLOOR_Y + 18), 1.9, 0.4],
		]
		for spec in specs:
			var a: Vector2 = spec[0]
			var b: Vector2 = spec[1]
			var pts := PackedVector2Array([a])
			for i in range(1, 6):
				var normal := (b - a).normalized().orthogonal()
				pts.append((a.lerp(b, i / 6.0) + normal * r.randf_range(-3, 3)).round())
			pts.append(b)
			cracks.append({pts = pts, t0 = spec[2], dur = spec[3]})

	## Where a crack's growing tip is now (x < 0 when it hasn't started).
	func _crack_reach(crack: Dictionary) -> Vector2:
		if t < crack.t0:
			return Vector2(-1, -1)
		var pts: PackedVector2Array = crack.pts
		var reach := clampf((t - crack.t0) / crack.dur, 0.0, 1.0) * (pts.size() - 1)
		var i := mini(int(reach), pts.size() - 2)
		return pts[i].lerp(pts[i + 1], reach - i)

	func _break_floor() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 99
		var edges := [124.0, 141.0, 161.0, 179.0, 198.0]
		for k in 4:
			var x0: float = edges[k]
			var x1: float = edges[k + 1]
			var shape := PackedVector2Array([Vector2(x0, FLOOR_Y + r.randi_range(0, 1)), Vector2(x1, FLOOR_Y + r.randi_range(0, 2)),
				Vector2(x1 - r.randi_range(0, 4), FLOOR_Y + 12 + r.randi_range(0, 8)), Vector2(x0 + (x1 - x0) * 0.5, FLOOR_Y + 22 + r.randi_range(0, 6)),
				Vector2(x0 + r.randi_range(0, 4), FLOOR_Y + 10 + r.randi_range(0, 8))])
			chunks.append({shape = shape, at = t, vx = r.randf_range(-14, 14), delay = r.randf_range(0.0, 0.14)})
		for i in 16:
			_dust(Vector2(r.randf_range(124, 198), FLOOR_Y), 1)
		for i in 10:
			_part({p = Vector2(r.randf_range(126, 196), FLOOR_Y + r.randf_range(0, 20)), v = Vector2(r.randf_range(-30, 30), r.randf_range(-60, 0)),
				g = 420.0, life = 1.4, c = WARM[2], s = 2.0})

	func _draw_crack() -> void:
		_draw_corridor(_crack_scroll(), _heroes())
		if t >= 2.35:
			# The floor is gone: the void below, faintly lit by lava far, far down.
			draw_colored_polygon(PackedVector2Array([Vector2(124, FLOOR_Y), Vector2(198, FLOOR_Y + 1), Vector2(196, FLOOR_Y + 18),
				Vector2(192, STAGE_BOTTOM + 4), Vector2(130, STAGE_BOTTOM + 4), Vector2(128, FLOOR_Y + 16)]), Color8(6, 4, 10))
			draw_texture_rect(checker, Rect2(132, FLOOR_Y + 14, 58, 4), true, Color8(36, 12, 12))
			draw_rect(Rect2(132, FLOOR_Y + 18, 58, 40), Color8(36, 12, 12))
			draw_texture_rect(checker, Rect2(136, FLOOR_Y + 24, 50, 4), true, Color8(80, 24, 14))
			draw_rect(Rect2(136, FLOOR_Y + 28, 50, 40), Color8(80, 24, 14))
			for chunk in chunks:
				var age: float = maxf(t - chunk.at - chunk.delay, 0.0)
				var off := Vector2(roundf(chunk.vx * age), roundf(300.0 * age * age))
				if off.y > 60:
					continue
				var shape := PackedVector2Array()
				for p: Vector2 in chunk.shape:
					shape.append(p + off)
				draw_colored_polygon(shape, WARM[2])
				draw_line(shape[0], shape[1], WARM[4], 1.0)
				draw_line(shape[1], shape[2], WARM[1], 1.0)
			return
		for crack in cracks:
			if t < crack.t0:
				continue
			var pts: PackedVector2Array = crack.pts
			var reach := clampf((t - crack.t0) / crack.dur, 0.0, 1.0) * (pts.size() - 1)
			for i in pts.size() - 1:
				if reach <= i:
					break
				var a := pts[i]
				var b := a.lerp(pts[i + 1], minf(reach - i, 1.0)).round()
				draw_line(a + Vector2(0, 1), b + Vector2(0, 1), WARM[4], 1.0)  # the lit lip under the crack
				draw_line(a, b, INK, 1.0)

	# --- Fall: a cross-section of the mountain ------------------------------------------------

	## Camera top during the fall: slow off the ledge, then faster and faster.
	func _fall_cam() -> float:
		var u := clampf(t / FALL_TIME, 0.0, 1.0)
		var end := LAYER_H * 10.0 - 16.0 - 128.0
		return FALL_TOP + (end - FALL_TOP) * (0.18 * u + 0.82 * u * u)

	func _mountain_half(y: float) -> float:
		return 58.0 + maxf(y, 0.0) * 0.32

	func _draw_fall() -> void:
		var top := _view().position.y
		# Night sky beside the peak, the mountain's rock, and the floors cut into it.
		draw_rect(Rect2(0, top - 2, 320, 184), Color8(12, 10, 28))
		if top < 160:
			for i in 26:
				var sx := fposmod(i * 73.0, 320.0)
				var sy := -70.0 + fposmod(i * 41.0, 140.0)
				if absf(sx - 160) > _mountain_half(sy) + 2:
					draw_rect(Rect2(sx, sy, 1, 1), Color8(150, 150, 200) if i % 3 else Color8(230, 230, 255))
		var rows := PackedVector2Array()
		var rows_r := PackedVector2Array()
		var y := floorf(top / 6.0) * 6.0 - 6.0
		while y < top + 192:
			var hw := _mountain_half(y)
			rows.append(Vector2(160 - hw, y))
			rows_r.append(Vector2(160 + hw, y))
			y += 6
		var outline := rows.duplicate()
		var rev := rows_r.duplicate()
		rev.reverse()
		outline.append_array(rev)
		draw_colored_polygon(outline, Color8(24, 18, 26))
		var band_y := floorf(top / 22.0) * 22.0
		while band_y < top + 190:  # rock strata, dithered
			var hw := _mountain_half(band_y)
			draw_texture_rect(checker, Rect2(160 - hw, band_y, hw * 2, 2), true, Color8(44, 32, 40))
			band_y += 22
		for i in layers.size():
			var y0 := i * LAYER_H
			if y0 + LAYER_H >= top and y0 <= top + 180:
				_draw_chamber(i, y0)
		if top < 0:
			# The corridor the slime fell out of, the hole, and the adventurers peering down it.
			var hw := _mountain_half(-30) - 4
			draw_rect(Rect2(160 - hw, -62, hw * 2, 32), WARM[1])
			draw_rect(Rect2(160 - hw, -30, hw * 2, 30), WARM[2])
			draw_rect(Rect2(160 - hw, -30, hw * 2, 2), WARM[4])
			draw_rect(Rect2(146, -30, 28, 30), Color8(6, 4, 10))
			_halo(self, Vector2(136, -52), 26, FLAME_HOT, 0.06)
			_hero(self, Vector2(134, -30), 0, 0.0, 0.4, 1.0, SIL, true, true, true)
			_hero(self, Vector2(116, -30), 1, 0.0, 0.2, 1.0, SIL, true, true, false)
		draw_polyline(rows, Color8(80, 62, 100), 1.0)
		draw_polyline(rows_r, Color8(80, 62, 100), 1.0)

	## One floor of the dungeon in the cut: back wall, its theme's set dressing, and the slab under
	## it (holed in the middle, except the bottom floor, where the slime lands).
	func _draw_chamber(i: int, y0: float) -> void:
		var layer: Dictionary = layers[i]
		var pal: Dictionary = layer.pal
		var slab_y := y0 + LAYER_H - 16.0
		var hw := minf(_mountain_half(y0 + 10) - 16.0, 84.0)
		var left := 160.0 - hw
		var width := hw * 2.0
		var ramp: Array = [pal.k.lerp(pal.z, 0.25), pal.k.lerp(pal.z, 0.6), pal.z, pal.z.lerp(pal.W, 0.55)]
		draw_rect(Rect2(left, y0, width, slab_y - y0), pal.k)
		# Blocks in a pool of the floor's own light, dithered between steps.
		var glow := Vector2(160, y0 + (slab_y - y0) * 0.62)
		var row := 0
		var by := y0 + 2.0
		while by < slab_y - 4:
			var bx := left + 2 - (9.0 if row % 2 else 0.0)
			var col := 0
			while bx < left + width - 2:
				var d := Vector2(bx + 9, by + 3).distance_to(glow) / (hw * 0.95)
				var level := clampi(int((1.0 - d) * 4.0 + _bayer(col, row) - 0.25), 0, 3)
				var c: Color = ramp[level]
				var x0 := maxf(bx, left + 2)
				var x1 := minf(bx + 17, left + width - 2)
				if x1 > x0:
					draw_rect(Rect2(x0, by, x1 - x0, 6), c)
					if level >= 2:
						draw_rect(Rect2(x0, by, x1 - x0, 1), pal.w.lerp(c, 0.5))
				bx += 18
				col += 1
			by += 7
			row += 1
		_draw_dressing(layer.id, pal, Rect2(left, y0, width, slab_y - y0))
		# Darker toward the sides: the mountain's shadow.
		draw_texture_rect(checker, Rect2(left, y0, 8, slab_y - y0), true, pal.k)
		draw_texture_rect(checker, Rect2(left + width - 8, y0, 8, slab_y - y0), true, pal.k)
		draw_rect(Rect2(left, y0, 3, slab_y - y0), pal.k)
		draw_rect(Rect2(left + width - 3, y0, 3, slab_y - y0), pal.k)
		# The slab.
		var slab_half := _mountain_half(slab_y) - 2.0
		draw_rect(Rect2(160 - slab_half, slab_y, slab_half * 2, 16), pal.W)
		draw_rect(Rect2(160 - slab_half, slab_y, slab_half * 2, 2), pal.x)
		draw_rect(Rect2(160 - slab_half, slab_y + 2, slab_half * 2, 1), pal.w)
		draw_texture_rect(checker, Rect2(160 - slab_half, slab_y + 10, slab_half * 2, 4), true, pal.z)
		draw_rect(Rect2(160 - slab_half, slab_y + 14, slab_half * 2, 2), pal.k)
		if i < layers.size() - 1:
			draw_colored_polygon(PackedVector2Array([Vector2(145, slab_y), Vector2(175, slab_y), Vector2(172, slab_y + 5),
				Vector2(176, slab_y + 10), Vector2(173, slab_y + 16), Vector2(147, slab_y + 16), Vector2(143, slab_y + 9),
				Vector2(147, slab_y + 4)]), pal.k)
			draw_rect(Rect2(141, slab_y - 1, 3, 1), pal.x)
			draw_rect(Rect2(176, slab_y - 1, 2, 1), pal.x)

	func _draw_dressing(id: String, pal: Dictionary, r: Rect2) -> void:
		var floor_y := r.end.y
		var mid := r.position.x + r.size.x * 0.5
		var tt := 0.0 if screen.calm else t
		match id:
			"volcanic":
				_halo(self, Vector2(mid, floor_y - 6), r.size.x * 0.45, pal.d, 0.07)
				draw_rect(Rect2(r.position.x, floor_y - 10, r.size.x, 10), pal.d)
				draw_rect(Rect2(r.position.x, floor_y - 10, r.size.x, 2), pal.B)
				for k in 10:
					var x := r.position.x + fposmod(k * 31.0 + tt * 20.0, r.size.x - 4)
					draw_rect(Rect2(roundf(x), floor_y - 11 - (k % 3), 3, 1), pal.B)
			"crystal":
				_halo(self, Vector2(mid, floor_y - 10), 44, pal.v, 0.05)
				for k in 7:
					var x := r.position.x + 12 + k * (r.size.x - 24) / 6.0
					var h := 10.0 + (k * 7) % 12
					draw_colored_polygon(PackedVector2Array([Vector2(x - 4, floor_y), Vector2(x + 4, floor_y), Vector2(x, floor_y - h)]), pal.v)
					draw_line(Vector2(x, floor_y - h + 2), Vector2(x - 2, floor_y - 1), Color8(230, 250, 255), 1.0)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 3, r.position.y), Vector2(x + 3, r.position.y), Vector2(x + 1, r.position.y + h * 0.6)]), pal.B)
			"obsidian":
				for k in 5:
					var x := roundf(r.position.x + 20 + k * (r.size.x - 40) / 4.0)
					var h := 20.0 + (k * 9) % 18
					draw_rect(Rect2(x, r.position.y, 1, h), Color8(60, 56, 80))
					draw_rect(Rect2(x - 1, r.position.y + h, 3, 3), Color8(80, 76, 104))
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 20, floor_y), Vector2(r.position.x + 30, floor_y - 14), Vector2(r.position.x + 34, floor_y)]), pal.v)
				draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 34, floor_y), Vector2(r.end.x - 26, floor_y - 18), Vector2(r.end.x - 20, floor_y)]), pal.v)
			"frozen":
				for k in 14:
					var x := r.position.x + 6 + k * (r.size.x - 12) / 13.0
					var h := 4.0 + (k * 5) % 9
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, r.position.y), Vector2(x + 2, r.position.y), Vector2(x, r.position.y + h)]), pal.x)
				draw_rect(Rect2(r.position.x, floor_y - 3, r.size.x, 3), pal.x)
				draw_rect(Rect2(r.position.x, floor_y - 4, r.size.x, 1), pal.w)
			"catacombs":
				for k in 6:
					var x := roundf(r.position.x + 14 + k * (r.size.x - 28) / 5.0)
					var y := r.position.y + 30 + (k % 2) * 16
					draw_rect(Rect2(x - 5, y - 2, 10, 9), pal.k)
					draw_rect(Rect2(x - 3, y, 6, 5), pal.x)
					draw_rect(Rect2(x - 2, y + 2, 1, 1), pal.k)
					draw_rect(Rect2(x + 1, y + 2, 1, 1), pal.k)
				for k in 4:
					draw_rect(Rect2(roundf(r.position.x + 20 + k * (r.size.x - 40) / 3.0), floor_y - 2, 7, 2), pal.x)
			"sewers":
				draw_rect(Rect2(r.position.x, floor_y - 8, r.size.x, 8), pal.d)
				draw_rect(Rect2(r.position.x, floor_y - 8, r.size.x, 1), pal.B)
				for k in 6:
					var x := r.position.x + fposmod(k * 47.0 + tt * 30.0, r.size.x - 2)
					draw_rect(Rect2(roundf(x), floor_y - 10 - (int(tt * 4.0 + k) % 3), 2, 2), pal.B)
				draw_rect(Rect2(r.position.x, r.position.y + 24, 30, 6), pal.z)
				draw_rect(Rect2(r.position.x + 28, r.position.y + 22, 4, 10), pal.W)
			"sunken":
				var water := roundf(floor_y - r.size.y * 0.45)
				draw_rect(Rect2(r.position.x, water, r.size.x, floor_y - water), Color(pal.d, 0.75))
				for k in 10:
					var x := r.position.x + k * r.size.x / 10.0 + roundf(sin(tt * 3.0 + k) * 2.0)
					draw_rect(Rect2(roundf(x), water, 8, 1), pal.B)
				for k in 4:
					var x := roundf(r.position.x + 16 + k * (r.size.x - 32) / 3.0)
					draw_line(Vector2(x, floor_y), Vector2(x + roundf(sin(tt * 2.0 + k) * 2.0), floor_y - 18), pal.v, 1.0)
			"sandstone":
				for k in 3:
					var x := roundf(r.position.x + 24 + k * (r.size.x - 48) / 2.0)
					draw_rect(Rect2(x - 4, r.position.y + 6, 8, r.size.y - 14), pal.W.lerp(pal.w, 0.4))
					draw_rect(Rect2(x - 4, r.position.y + 6, 2, r.size.y - 14), pal.x)
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, floor_y), Vector2(r.position.x, floor_y - 10),
					Vector2(r.position.x + r.size.x * 0.3, floor_y - 4), Vector2(r.position.x + r.size.x * 0.6, floor_y - 9),
					Vector2(r.end.x, floor_y - 3), Vector2(r.end.x, floor_y)]), pal.w)
			"mossy":
				for k in 3:
					var x := roundf(r.position.x + 30 + k * (r.size.x - 60) / 2.0)
					draw_rect(Rect2(x, r.position.y + 10, 3, r.size.y - 10), Color8(92, 64, 40))
					draw_rect(Rect2(x - 8, r.position.y + 10, 19, 3), Color8(110, 78, 46))
				for k in 10:
					var x := roundf(r.position.x + 8 + k * (r.size.x - 16) / 9.0)
					draw_rect(Rect2(x, r.position.y, 3, 6 + (k * 7) % 14), pal.v)
					draw_rect(Rect2(x + 1, r.position.y, 1, 9 + (k * 7) % 14), Color8(52, 104, 46))
			"dungeon":
				for x in [r.position.x + 30, r.end.x - 30]:
					_draw_wall_torch(Vector2(roundf(x), r.position.y + 50))

	func _draw_fall_front(canvas: CanvasItem) -> void:
		if screen.calm:
			return
		var top := _view().position.y
		var speed := clampf(t / 3.0, 0.3, 1.0)
		# Speed lines rushing up past the camera.
		for i in 18:
			var x := fposmod(i * 97.3, 320.0)
			if absf(x - 160) < 18:
				x += 40
			var length := roundf((12.0 + (i * 13) % 28) * speed)
			var y := fposmod(-t * (520.0 + (i % 5) * 90.0) + i * 53.0, 220.0) - 20.0
			canvas.draw_rect(Rect2(roundf(x), top + roundf(y), 1, length), Color(1, 1, 1, 0.16 + 0.05 * (i % 3)))
		# Wind motes and goo streaming up off the slime.
		var base: Vector2 = screen.slime.position
		for i in 10:
			var age := fposmod(t * 2.2 + i * 0.1, 1.0)
			var p := base + Vector2(((i * 7) % 15) - 7.0 + sin(age * 6.0 + i) * 2.0, -10.0 - age * 46.0)
			canvas.draw_rect(Rect2(p.round(), Vector2.ONE * (2.0 if i % 4 == 0 else 1.0)), Color(goo.light if i % 3 else goo.highlight, 1.0 - age))

	# --- Splat --------------------------------------------------------------------------------

	func _draw_splat() -> void:
		_draw_room()
		# A little moss: the Dark Dungeon's own art.
		draw_rect(Rect2(118, 114, 5, 6), Color8(52, 92, 52))
		draw_rect(Rect2(119, 113, 3, 2), Color8(94, 140, 60))
		draw_rect(Rect2(196, 116, 7, 4), Color8(52, 92, 52))
		draw_rect(Rect2(197, 115, 3, 1), Color8(94, 140, 60))
		# The hole far above and its shaft of light.
		var shaft := Color(Color8(170, 190, 230), 0.07)
		draw_colored_polygon(PackedVector2Array([Vector2(150, 14), Vector2(170, 14), Vector2(196, 120), Vector2(124, 120)]), shaft)
		draw_colored_polygon(PackedVector2Array([Vector2(154, 14), Vector2(166, 14), Vector2(182, 120), Vector2(138, 120)]), shaft)
		draw_rect(Rect2(148, 14, 24, 3), Color8(210, 222, 240))
		for i in 12:
			var age := fposmod(t * 0.08 + i * 0.083, 1.0)
			var p := Vector2(150 + fposmod(i * 37.0, 22.0) + age * 10.0 * sin(i), 18 + age * 100.0)
			draw_rect(Rect2(p.round(), Vector2.ONE), Color(Color8(220, 230, 255), 0.6 * (1.0 - absf(age - 0.5) * 2.0)))
		# The splat's goo puddle, spreading.
		var spread := 1.0 if screen.calm else clampf(t / 0.3, 0.0, 1.0)
		var w := roundf(20.0 + 16.0 * spread)
		draw_rect(Rect2(160 - roundf(w * 0.5), 120, w, 2), goo.dark)
		draw_rect(Rect2(160 - roundf(w * 0.5) + 3, 120, w - 6, 1), goo.mid)
		_halo(self, Vector2(160, 112), 26.0, goo.light, 0.04)

	## The Dark Dungeon room the slime lands in: blocks and flagstones in an oval pool of pale light
	## from the hole far above, plus any torches in `lights` (warm wins where it's brighter).
	func _draw_room() -> void:
		draw_rect(Rect2(-10, 0, 340, 180), COOL[0])
		# Back wall: dungeon blocks, lit only by the pale light falling from the hole (an oval pool,
		# dithered between steps).
		var row := 0
		var y := 14.0
		while y < 120:
			var x := -8.0 if row % 2 else 0.0
			var col := 0
			while x < 330:
				var d := Vector2((x + 8 - 160.0) / 92.0, (y + 3 - 112.0) / 70.0).length()
				var band := clampi(int((1.0 - d) * 5.0 + _bayer(col, row) - 0.25), 0, 4)
				var ramp: Array = COOL
				var warm := _light_band(Vector2(x + 8, y + 3), _bayer(col, row) - 0.25)
				if warm > band:
					band = mini(warm, 4)
					ramp = WARM
				draw_rect(Rect2(x + 1, y + 1, 15, 6), ramp[band])
				if band >= 2:
					draw_rect(Rect2(x + 1, y + 1, 15, 1), ramp[band + 1])
				x += 16
				col += 1
			y += 7
			row += 1
		# The floor: flagstones catching the light around the splat.
		var fy := 120.0
		var frow := 0
		while fy < 146:
			var fx := 0.0
			var fcol := 0
			while fx < 320:
				var d := Vector2((fx + 2 - 160.0) / 100.0, (fy - 120.0) / 30.0).length()
				var band := clampi(int((1.0 - d) * 5.0 + _bayer(fcol, frow) - 0.25), 0, 4)
				var ramp: Array = COOL
				var warm := _light_band(Vector2(fx + 2, fy + 1), _bayer(fcol, frow) - 0.25) - 1
				if warm > band:
					band = mini(warm, 4)
					ramp = WARM
				draw_rect(Rect2(fx, fy, 4, 3), ramp[band])
				fx += 4
				fcol += 1
			fy += 3
			frow += 1
		draw_rect(Rect2(0, 120, 320, 1), COOL[3])
		draw_texture_rect(checker, Rect2(40, 120, 240, 1), true, COOL[5])
		for k in 14:
			var top_x := k * 28.0 - 22.0
			draw_line(Vector2(top_x, 121), Vector2(roundf(160 + (top_x - 160) * 1.7), 150), Color(INK, 0.45), 1.0)
		draw_rect(Rect2(0, 128, 320, 1), Color(INK, 0.45))
		draw_rect(Rect2(0, 139, 320, 1), Color(INK, 0.45))

	## Darkness closing in around `center`: banded rings, then black.
	func _draw_dark(canvas: CanvasItem, center: Vector2, r: float) -> void:
		var c := center.round()
		canvas.draw_arc(c, r + 3.0, 0, TAU, 48, Color(INK, 0.45), 6.0)
		canvas.draw_arc(c, r + 9.0, 0, TAU, 48, Color(INK, 0.75), 6.0)
		canvas.draw_arc(c, r + 12.0 + 200.0, 0, TAU, 64, INK, 400.0)

	# --- Finale: dawn over the crater ---------------------------------------------------------

	func _draw_daylight(tt: float) -> void:
		var dawn := _smooth(clampf(tt / 4.5, 0.0, 1.0))
		var night := [Color8(10, 8, 26), Color8(16, 14, 40), Color8(26, 22, 58), Color8(40, 30, 74), Color8(58, 38, 86), Color8(82, 46, 92)]
		var day := [Color8(38, 52, 120), Color8(72, 76, 150), Color8(140, 96, 160), Color8(214, 116, 128), Color8(250, 160, 108), Color8(255, 208, 128)]
		var band_h := 18.0
		for i in 6:
			draw_rect(Rect2(0, 10 + i * band_h, 320, band_h), night[i].lerp(day[i], dawn))
			if i < 5:
				draw_texture_rect(checker, Rect2(0, 10 + (i + 1) * band_h - 3, 320, 3), true, night[i + 1].lerp(day[i + 1], dawn))
		draw_rect(Rect2(0, 118, 320, 62), night[5].lerp(day[5], dawn))
		# Stars, fading as the sun comes up.
		for i in 34:
			var a := (1.0 - dawn) * (0.5 + 0.5 * sin(tt * 3.0 + i * 1.7))
			if a > 0.05:
				draw_rect(Rect2(fposmod(i * 89.0, 320.0), 16 + fposmod(i * 47.0, 70.0), 1, 1), Color(1, 1, 1, a))
		# The sun, rising behind the far peaks, with slowly turning rays.
		var sun := Vector2(232, roundf(lerpf(138.0, 74.0, _smooth(clampf(tt / 5.5, 0.0, 1.0)))))
		if dawn > 0.05:
			for k in 10:
				var ang := k * TAU / 10.0 + tt * 0.08
				var a1 := sun + Vector2(cos(ang - 0.07), sin(ang - 0.07)) * 300.0
				var a2 := sun + Vector2(cos(ang + 0.07), sin(ang + 0.07)) * 300.0
				draw_colored_polygon(PackedVector2Array([sun, a1, a2]), Color(1.0, 0.86, 0.6, 0.06 * dawn))
		_halo(self, sun, 44.0, Color8(255, 196, 120), 0.12 * dawn + 0.02)
		draw_circle(sun, 11, Color8(255, 236, 170))
		draw_circle(sun + Vector2(-2, -2), 7, Color8(255, 250, 220))
		# Far ranges (cool), then nearer ones, rims lit on the slopes facing the sun.
		_ridge([0, 110, 30, 92, 70, 104, 110, 86, 150, 100, 200, 82, 250, 98, 290, 88, 320, 100], night[3].lerp(Color8(104, 76, 140), dawn), Color8(255, 190, 150), dawn * 0.6)
		_ridge([0, 124, 40, 108, 90, 120, 260, 112, 300, 104, 320, 112], night[2].lerp(Color8(70, 46, 96), dawn), Color8(255, 170, 120), dawn)
		# The volcano's summit: a dark cone, the crater's lava glowing inside, rims lit toward the sun.
		var rock := Color8(24, 14, 24).lerp(Color8(58, 32, 46), dawn)
		var rock_lit := Color8(40, 22, 34).lerp(Color8(120, 62, 58), dawn)
		var rim_l := Vector2(98, 106)
		var rim_r := Vector2(170, 104)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 180), Vector2(-10, 150), Vector2(40, 128), rim_l,
			Vector2(134, 110), rim_r, Vector2(240, 124), Vector2(330, 140), Vector2(330, 180)]), rock)
		# The sunlit face (right of the cone), then shading toward the base.
		draw_colored_polygon(PackedVector2Array([rim_r, Vector2(240, 124), Vector2(330, 140), Vector2(330, 180), Vector2(200, 180), Vector2(176, 120)]), rock_lit)
		draw_texture_rect(checker, Rect2(0, 136, 320, 4), true, Color8(16, 10, 18))
		draw_rect(Rect2(0, 140, 320, 8), Color8(16, 10, 18))
		# The crater mouth.
		draw_colored_polygon(PackedVector2Array([rim_l, Vector2(134, 102), rim_r, Vector2(160, 116), Vector2(134, 122), Vector2(108, 116)]), Color8(18, 8, 14))
		draw_colored_polygon(PackedVector2Array([Vector2(112, 113), Vector2(134, 109), Vector2(156, 113), Vector2(134, 118)]), Color8(140, 40, 20))
		draw_colored_polygon(PackedVector2Array([Vector2(120, 113), Vector2(134, 111), Vector2(148, 113), Vector2(134, 116)]), FLAME_HOT)
		draw_rect(Rect2(128, 112, 10, 2), FLAME)
		_halo(self, Vector2(134, 110), 30.0, FLAME_HOT, 0.07)
		var gold := Color8(255, 200, 130).lerp(rock, 1.0 - dawn)
		draw_line(Vector2(134, 102), rim_r, Color8(255, 150, 80).lerp(rock, 0.3), 1.0)
		draw_line(rim_r, Vector2(240, 124), gold, 1.0)
		draw_line(Vector2(240, 124), Vector2(330, 140), gold.lerp(rock_lit, 0.5), 1.0)
		draw_line(Vector2(40, 128), rim_l, Color8(130, 80, 100).lerp(rock, 1.0 - dawn), 1.0)
		draw_line(rim_l, Vector2(134, 102), Color8(255, 140, 70).lerp(rock, 0.4), 1.0)
		# Birds, once the sun is up.
		if tt > 2.0:
			for i in 3:
				var bx := roundf(330.0 - (tt - 2.0) * (26.0 + i * 5.0) - i * 18.0)
				var by := roundf(42.0 + i * 9.0 + sin(tt * 2.0 + i) * 2.0)
				var wing := -1.0 if int(tt * 6.0 + i) % 2 == 0 and not screen.calm else 1.0
				var bc := Color8(40, 26, 48)
				draw_rect(Rect2(bx, by, 1, 1), bc)
				draw_rect(Rect2(bx - 2, by + wing, 2, 1), bc)
				draw_rect(Rect2(bx + 1, by + wing, 2, 1), bc)
		# Warm light washing over everything.
		draw_rect(Rect2(0, 0, 320, 180), Color(1.0, 0.75, 0.45, 0.07 * dawn))

	func _ridge(pts: Array, color: Color, rim: Color, rim_a: float) -> void:
		var line := PackedVector2Array()
		for i in range(0, pts.size(), 2):
			line.append(Vector2(pts[i], pts[i + 1]))
		var poly := line.duplicate()
		poly.append(Vector2(320, 180))
		poly.append(Vector2(0, 180))
		draw_colored_polygon(poly, color)
		if rim_a > 0.05:
			for i in line.size() - 1:
				if line[i + 1].y < line[i].y or line[i].x > 180:  # slopes facing the sun
					draw_line(line[i], line[i + 1], Color(rim, rim_a * 0.8), 1.0)

	func _draw_search() -> void:
		var heroes := _heroes()
		for hero in heroes:
			lights.append(Vector3(hero.tip.x, hero.tip.y, (34.0 if hero.kind == 2 else 70.0) * _flicker(hero.kind)))
		_draw_room()
		draw_colored_polygon(PackedVector2Array([Vector2(154, 14), Vector2(166, 14), Vector2(182, 120), Vector2(138, 120)]), Color(Color8(170, 190, 230), 0.06))
		draw_rect(Rect2(148, 14, 24, 3), Color8(210, 222, 240))
		# The puddle they found.
		draw_rect(Rect2(156, 119, 18, 2), goo.dark)
		draw_rect(Rect2(158, 118, 13, 2), goo.mid)
		draw_rect(Rect2(161, 118, 3, 1), goo.highlight)
		for hero in heroes:
			var f: Vector2 = hero.foot
			draw_colored_polygon(PackedVector2Array([f + Vector2(-4, 1), f + Vector2(4, 1), f + Vector2(-30, 8), f + Vector2(-46, 8)]), Color(INK, 0.4))
		for hero in heroes:
			_draw_hero_with_light(hero)
