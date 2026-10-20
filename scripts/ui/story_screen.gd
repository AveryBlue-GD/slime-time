extends Control

## The story (see Story and docs/story.md): the intro (a fresh save's first PLAY, or the title's
## STORY button) and the finale (after level 10), each a run of short animated shots drawn in code
## at 320x180 behind letterbox bars. The story is wordless: no text is drawn anywhere on this
## screen (tests/test_story.gd checks it); beats are told by staging, light and pixel pictograms.
## A shot moves on by itself after its time; any key, click or tap moves on early; Esc skips the
## lot; on a touchscreen the fast-forward mark in the bottom bar is a pod (drawn, wordless) whose tap
## skips the lot. Reduce Motion freezes each shot on a still (its `still` moment, particles and all) with no
## shake or zoom, and holds each still at least CALM_HOLD seconds.
##
## Drawing: StageArt (a Node2D moved and scaled as the camera: zooms, bounces, shakes) draws the
## shot behind the slime sprite; its `front` layer draws foreground pillars, particles, speed lines,
## pictogram bubbles and the darkness; Cover draws the letterbox bars, fades, the depth gauge and
## the shot pips in screen space.

signal done

const SCREEN := Vector2(320, 180)
const BAR_TOP := 14.0
const BAR_BOTTOM := 36.0
## Input is ignored for this long after a shot starts, so a held key can't skip it.
const GRACE := 0.25
## A Reduce Motion still stays up at least this long, to read it.
const CALM_HOLD := 4.5
const INK := Color8(9, 8, 16)
## Touch: the fast-forward pod (bottom right, in the letterbox bar) and its tap area (>= UIKit.TOUCH_MIN).
const SKIP_POD := Rect2(SCREEN.x - 27, SCREEN.y - 25, 21, 13)
const SKIP_HIT := Rect2(SCREEN.x - 40, SCREEN.y - 36, 40, 36)

var mode := "intro"
var next_scene := ""
var cards: Array[Dictionary] = []
var index := 0
var finished := false
var calm := false
## Off in demos: finishing only emits `done` instead of changing scenes.
var leave_on_finish := true
## A touchscreen: the fast-forward pod is shown from the start and a tap on it skips the lot.
var touch_skip := false

var art: StageArt
var cover: Cover
var slime: AnimatedSprite2D
var _age := 0.0
var _bars := 0.0


func _ready() -> void:
	mode = Story.mode
	next_scene = Story.next_scene
	Story.mode = "intro"
	Story.next_scene = ""
	calm = Progress.reduce_motion
	touch_skip = Platform.has_touch()
	cards = Story.cards(mode)
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
	show_card(0)


func show_card(i: int) -> void:
	index = i
	_age = 0.0
	var card: Dictionary = cards[i]
	if calm or i > 0:
		_bars = 1.0
	art.start(card.art)
	if calm:
		art.simulate_to(card.still)
	cover.queue_redraw()


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
		for long_sound in ["sunrise", "whoosh", "crumble", "crack", "splat", "grumble"]:
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
	cover.queue_redraw()
	if _age >= card_length():
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("menu") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		finish()
		return
	if touch_skip and _skip_tapped(event):
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


## A tap (or the click a tap is emulated as) on the touch fast-forward pod.
func _skip_tapped(event: InputEvent) -> bool:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) 		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	return tap and SKIP_HIT.has_point(make_input_local(event).position)


## Screen-space overlay: letterbox bars, the fade at each shot's start and the finale's gold, the
## depth gauge (fall, splat) and the shot pips with a fast-forward mark (skip) in the bars.
class Cover extends Control:
	var screen: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var fade: Color = screen.art.fade_color()
		if fade.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, SCREEN), fade)
		screen.art.draw_gauge(self)
		var e: float = 1.0 - pow(1.0 - screen._bars, 3.0)
		var top := roundf(BAR_TOP * e)
		var bottom := roundf(BAR_BOTTOM * e)
		draw_rect(Rect2(0, 0, SCREEN.x, top), INK)
		draw_rect(Rect2(0, SCREEN.y - bottom, SCREEN.x, bottom), INK)
		if e > 0.99:
			draw_rect(Rect2(0, top, SCREEN.x, 1), Color8(30, 26, 44))
			draw_rect(Rect2(0, SCREEN.y - bottom - 1, SCREEN.x, 1), Color8(30, 26, 44))
		var alpha := clampf((screen._age - 0.8) / 0.5, 0.0, 1.0) if screen.index == 0 and not screen.calm else 1.0
		_draw_pips(alpha)
		_draw_skip(1.0 if screen.touch_skip else alpha)

	## One pip per shot (past ones dim goo, the current one bright).
	func _draw_pips(alpha: float) -> void:
		if alpha <= 0.0:
			return
		var goo: Dictionary = screen.art.goo
		var n: int = screen.cards.size()
		var x0 := roundf(160.0 - (n * 6.0 - 2.0) * 0.5)
		var y := SCREEN.y - 20.0
		for i in n:
			var c: Color = goo.light if i == screen.index else (goo.dark if i < screen.index else Color8(44, 40, 62))
			# The current pip grows a row above and below (4x5), so it stays centered on the row.
			var current: bool = i == screen.index
			draw_rect(Rect2(x0 + i * 6.0, y - (1.0 if current else 0.0), 4, 5 if current else 3), Color(c, alpha))

	## The fast-forward mark; on touch inside a pod (a dark fill with a 1 px goo edge) and brighter, as a button.
	func _draw_skip(alpha: float) -> void:
		if alpha <= 0.0:
			return
		var ff := Color(Color8(84, 78, 110), alpha * 0.9)
		if screen.touch_skip:
			draw_rect(SKIP_POD, Color(Color8(20, 18, 32), alpha))
			draw_rect(SKIP_POD.grow(-0.5), Color(screen.art.goo.dark, alpha), false, 1.0)
			ff = Color(Color8(170, 162, 200), alpha)
		for k in 2:
			var fx := SCREEN.x - 22.0 + k * 5.0
			for row in 5:
				var w := 3 - absi(row - 2)
				draw_rect(Rect2(fx, SCREEN.y - 21.0 + row, w, 1), ff)
		draw_rect(Rect2(SCREEN.x - 12.0, SCREEN.y - 21.0, 1, 5), ff)


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
	## The finale's search: when each adventurer (knight, rogue, wizard) is puzzled ("?") and then
	## angry, the wizard's stomps, and the cut back to the sunrise (s into the shot).
	const SEARCH_HUH := [0.45, 0.75, 1.05]
	const SEARCH_MAD := [2.15, 2.27, 2.39]
	const SEARCH_STOMPS := [2.55, 2.95, 3.35, 3.75]
	const SEARCH_CUT := 3.9
	## Where a reaction pictogram ("?", angry face) is centered, above an adventurer's feet.
	const REACT_Y := -44.0
	const RUN_SPEED := 84.0
	## The fall: ten floors (level 10 at the top down to level 1), FALL_TIME seconds.
	const LAYER_H := 118.0
	## Depth gauge geometry (see gauge_slice).
	const GAUGE_SLICE_H := 3
	const GAUGE_GAP := 1
	const GAUGE_BASE_W := 6
	const GAUGE_STEP := 2
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
	var checker: Texture2D
	var lights: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	var goo: Dictionary
	var pops: Array[Dictionary] = []  # pictogram bubbles: {icon, who, at, life, think}
	var cracks: Array[Dictionary] = []
	var pieces: Array[Dictionary] = []  # the slabs of floor that break in the crack shot
	var layers: Array[Dictionary] = []
	var corridor_hole: Dictionary  # the crumbled hole in the corridor floor atop the fall
	var corridor_rim: Dictionary
	var lava_lips: Array[PackedVector2Array] = []

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.WHITE)
		image.set_pixel(1, 1, Color.WHITE)
		checker = ImageTexture.create_from_image(image)
		goo = Skins.shades(Progress.skin_color())
		for i in Themes.BY_LEVEL.size():
			var id: String = Themes.BY_LEVEL[Themes.BY_LEVEL.size() - 1 - i]
			var pal: Dictionary = THEME_PAL.get(id, THEME_PAL["dungeon"])
			layers.append({id = id, name = Themes.display_name(id), pal = pal, rim = _rim_colors(id, pal), hole = _make_hole(7100 + i * 37, 16)})
		corridor_hole = _make_hole(7777, 30)
		for k in 2:
			var lip := PackedVector2Array()
			for p: Vector2 in (LAVA_LIP_L if k == 0 else LAVA_LIP_R):
				lip.append(Vector2(-p.x if k == 0 else p.x, p.y))
			lava_lips.append(lip)
		corridor_rim = _rim_colors("", {k = VOID, x = WARM[4], w = WARM[3], W = WARM[2], z = WARM[1]})

	# --- Timeline ----------------------------------------------------------------------------

	func start(which: String) -> void:
		shot = which
		t = 0.0
		parts.clear()
		pops.clear()
		cracks.clear()
		pieces.clear()
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
				if t >= SEARCH_CUT and t < SEARCH_CUT + 0.3:
					c = Color(INK, 1.0 - (t - SEARCH_CUT) / 0.3)
				elif t > 4.7:
					c = Color(Color8(255, 214, 140), clampf((t - 4.7) / 1.3, 0.0, 1.0))
		return c

	## One depth-gauge slice (i = 0 is the top floor, the Volcanic Vault) in gauge space: every
	## slice GAUGE_SLICE_H tall with a GAUGE_GAP gap, centered on x = 0 in whole pixels, and
	## GAUGE_STEP narrower than the one above it (an upside-down stepped pyramid: the top floor is
	## the biggest maze, the Dark Dungeon at the bottom the smallest, GAUGE_BASE_W wide).
	static func gauge_slice(i: int, n: int) -> Rect2:
		var w := GAUGE_BASE_W + (n - 1 - i) * GAUGE_STEP
		return Rect2(w * -0.5, i * (GAUGE_SLICE_H + GAUGE_GAP), w, GAUGE_SLICE_H)

	## Screen-space depth gauge (drawn by Cover): the mountain's ten floors as a stack of colored
	## slices, widest at the top (see gauge_slice), a little sun above it, and the slime's marker
	## sliding down beside it during the fall. After the splat the marker sits at the very bottom and a dotted arrow
	## climbs from it to the sun: the way out is up.
	func draw_gauge(canvas: CanvasItem) -> void:
		var alpha := 0.0
		var depth := 0.0
		var origin := Vector2(298, 34)
		var sc := 1.0
		match shot:
			"fall":
				alpha = 1.0 if screen.calm else clampf((t - 0.2) / 0.4, 0.0, 1.0)
				depth = clampf(screen.slime.position.y / (LAYER_H * layers.size() - 16.0), 0.0, 1.0)
			"splat":
				# Big, in the dark beside the slime: this is where the climb starts.
				alpha = 1.0 if screen.calm else clampf((t - 2.6) / 0.6, 0.0, 1.0)
				depth = 1.0
				origin = Vector2(272, 52)
				sc = 2.0
		if alpha <= 0.0:
			return
		canvas.draw_set_transform(origin, 0.0, Vector2(sc, sc))
		var n := layers.size()
		var stack_h := float(n * (GAUGE_SLICE_H + GAUGE_GAP) - GAUGE_GAP)
		# The marker runs in its own column just left of the widest (top) slice.
		var half_top := (GAUGE_BASE_W + (n - 1) * GAUGE_STEP) * 0.5
		var mx := -half_top - 7.0
		canvas.draw_rect(Rect2(mx - 2.0, -17, half_top + 4.0 - mx, stack_h + 23), Color(INK, 0.6 * alpha))
		# The sun over the summit.
		var sun := Vector2(0, -9)
		canvas.draw_rect(Rect2(sun + Vector2(-2, -2), Vector2(5, 5)), Color(FLAME, alpha))
		canvas.draw_rect(Rect2(sun + Vector2(-1, -3), Vector2(3, 7)), Color(FLAME, alpha))
		canvas.draw_rect(Rect2(sun + Vector2(-3, -1), Vector2(7, 3)), Color(FLAME, alpha))
		canvas.draw_rect(Rect2(sun + Vector2(-1, -1), Vector2(2, 2)), Color(FLAME_TIP, alpha))
		for ray in [Vector2(0, -5), Vector2(0, 5), Vector2(-5, 0), Vector2(5, 0), Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
			canvas.draw_rect(Rect2(sun + ray, Vector2.ONE), Color(FLAME_HOT, alpha))
		var current := clampi(int(depth * n), 0, n - 1)
		for i in n:
			var r := gauge_slice(i, n)
			var c: Color = _sig_color(layers[i])
			if i != current:
				c = c.lerp(INK, 0.45)
			canvas.draw_rect(r, Color(c, alpha))
			canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(c.lightened(0.3), alpha))
		# The slime's marker: a little goo blob with a pointer, beside the current depth.
		var my := roundf(depth * (stack_h - GAUGE_SLICE_H)) - 1.0
		canvas.draw_rect(Rect2(mx, my + 1, 5, 3), Color(goo.mid, alpha))
		canvas.draw_rect(Rect2(mx + 1, my, 3, 1), Color(goo.light, alpha))
		canvas.draw_rect(Rect2(mx + 1, my + 1, 1, 1), Color(goo.highlight, alpha))
		canvas.draw_rect(Rect2(mx + 5, my + 2, 1, 1), Color(goo.light, alpha))
		if shot == "splat":
			# A dotted arrow climbing from the marker to the sun: the way out is up.
			var x := mx + 2.0
			var y1 := sun.y - 1.0
			var run := 0.0 if screen.calm else fposmod(t * 6.0, 3.0)
			var y := my - 3.0 - run
			while y > y1 + 4:
				canvas.draw_rect(Rect2(x, roundf(y), 1, 2), Color(goo.light, alpha * 0.9))
				y -= 3.0
			canvas.draw_rect(Rect2(x, y1 + 1, 1, 1), Color(goo.light, alpha))
			canvas.draw_rect(Rect2(x - 1, y1 + 2, 3, 1), Color(goo.light, alpha))
			canvas.draw_rect(Rect2(x - 2, y1 + 3, 5, 1), Color(goo.light, alpha))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _cues(prev: float, now: float) -> void:
		match shot:
			"run":
				# Each adventurer brandishes its weapon (crossed swords), the slime panics (!).
				for i in 3:
					if _at(prev, now, 0.4 + i * 0.6):
						_pop("swords", i, 2.4 - i * 0.3)
						_sfx("clank", -15.0, 1.0 - i * 0.08)
				if _at(prev, now, 0.9):
					_pop("alarm", -1, 1.6)
				if _at(prev, now, 0.15):
					_pop("sweat", -1, 4.4)
			"chase":
				# They dream of gold; it dreams of a nap.
				for i in 3:
					if _at(prev, now, 0.3 + i * 0.35):
						_pop("coin", i, 3.4 - i * 0.35, true)
				if _at(prev, now, 1.3):
					_pop("moon", -1, 9.0, true)
				if _at(prev, now, 1.2):
					_sfx("clank", -16.0, 0.9)
			"crack":
				if _at(prev, now, 0.55):
					_pop("sweat", -1, 1.4)
				if _at(prev, now, 0.75):
					_sfx("crack", -9.0)
					_kick(1.0)
				if _at(prev, now, 1.6):
					_sfx("crack", -8.0, 0.85)
					_kick(1.5)
					_pop("alarm", -1, 0.9)
				if _at(prev, now, 2.35):
					_sfx("crumble", -6.0, 0.8)
					_kick(3.0)
					for i in 3:
						_pop("alarm", i, 1.2)
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
				# Puzzled (a "?" over each head) ... then furious (angry faces) till the cut.
				for i in 3:
					if _at(prev, now, SEARCH_HUH[i]):
						_pop("huh", i, SEARCH_MAD[i] - SEARCH_HUH[i])
						_sfx("huh", -15.0, [1.0, 1.12, 0.9][i])
					if _at(prev, now, SEARCH_MAD[i]):
						_pop("angry", i, SEARCH_CUT - SEARCH_MAD[i])
				if _at(prev, now, SEARCH_MAD[0]):
					_sfx("grumble", -12.0)
				for stomp in SEARCH_STOMPS:
					if _at(prev, now, stomp):
						_sfx("land", -15.0, 0.6)
						_kick(0.8)
						_dust(Vector2(200, 120), 3)
				if _at(prev, now, SEARCH_CUT):
					parts.clear()  # no sparks, steam or dust over the sunrise
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
				# Rim slabs crumbling off in dust and pebbles, and loose bits trickling off the rim.
				for piece in pieces:
					if piece.at > BREAK_AT + 0.1 and _at(prev, now, piece.at):
						_dust(piece.top[1], 2)
						for k in 3:
							_pebble(piece.center + Vector2(rng.randf_range(-4, 4), rng.randf_range(-2, 2)), Vector2(rng.randf_range(-12, 12), rng.randf_range(-20, 10)), rng)
				for i in _every(prev, now, 0.08, BREAK_AT + 0.1, 3.8):
					var piece: Dictionary = pieces[rng.randi_range(0, pieces.size() - 1)]
					var side: Dictionary = piece.sides[rng.randi_range(0, 2)]
					if now >= piece.at and not _fallen(side.other):
						var pts: PackedVector2Array = side.pts
						_pebble(pts[rng.randi_range(0, pts.size() - 1)] + Vector2(0, 1), Vector2(rng.randf_range(-8, 8), rng.randf_range(0, 20)), rng)
				for i in _every(prev, now, 0.09, 0.8, 3.4):
					_part({p = Vector2(rng.randf_range(70, 230), 52.0), v = Vector2(0, rng.randf_range(10, 40)), g = 300.0,
						life = 1.0, c = Color8(70, 62, 84), s = 1.0 if rng.randf() < 0.6 else 2.0})
				for i in _every(prev, now, 0.18):
					for torch in torches:
						_spark(torch + Vector2(0, -5), Vector2(rng.randf_range(-6, 6), rng.randf_range(-28, -12)))
			"fall":
				# Embers and sparks rising off the lava pools and the hot crust round the hole.
				for i in _every(prev, now, 0.035, 0.0, 2.2):
					var vault: float = LAYER_H - 16.0
					var side := -1.0 if rng.randf() < 0.5 else 1.0
					var x := 160.0 + side * rng.randf_range(26.0, 64.0)
					var from := Vector2(x, vault - 8.0)
					if rng.randf() < 0.25:
						from = Vector2(160.0 + side * rng.randf_range(15.0, 20.0), vault - 2.0)
					_part({p = from, v = Vector2(rng.randf_range(-6, 6), rng.randf_range(-70, -30)), g = -12.0,
						drag = 0.6, life = rng.randf_range(0.6, 1.3), c = [FLAME, FLAME_HOT, FLAME_TIP][rng.randi_range(0, 2)], s = 1.0})
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
				for i in _every(prev, now, 0.06, 0.0, SEARCH_CUT - 0.05):
					var hero: Dictionary = heroes[rng.randi_range(0, 1)]
					_spark(hero.tip, Vector2(rng.randf_range(-6, 6), rng.randf_range(-30, -12)))
				# Steam puffing off the angry faces.
				for i in _every(prev, now, 0.11, SEARCH_MAD[0] + 0.15, SEARCH_CUT - 0.05):
					var k := rng.randi_range(0, 2)
					if now < SEARCH_MAD[k] + 0.1:
						continue
					var side := -1.0 if rng.randf() < 0.5 else 1.0
					_part({p = heroes[k].foot + Vector2(side * 7.0, REACT_Y - 3.0), v = Vector2(side * rng.randf_range(10, 18), rng.randf_range(-22, -12)),
						g = -6.0, drag = 1.5, life = rng.randf_range(0.4, 0.6), c = Color(Color8(214, 208, 218), 0.8), s = 2.0, fade = true})

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

	# --- Pictogram bubbles (no text anywhere: icons drawn pixel by pixel) -----------------------

	## Icon bitmaps, one character per pixel (see ICON_INK).
	const ICONS := {
		alarm = ["rr", "rr", "rr", "rr", "..", "rr", "rr"],
		coin = ["..GGG..", ".GgggG.", "GgyggGG", "GgyggGG", "GggggGG", ".GGGGG.", "..GGG.."],
		moon = ["..mmm....", ".mmm...w.", "mmm......", "mmm...w..", "mmm......", ".mmm.....", "..mmm...."],
		swords = ["s.......s", "Ss.....sS", ".SS...SS.", "..SS.SS..", "...SSS...", "..gSSSg..", ".g.g.g.g.", ".ng...gn.", "nn.....nn"],
		sweat = [".b.", ".b.", "bbb", "bwb", ".b."],
		# Reactions, drawn bare (no bubble) with a dark outline: a puzzled "?" and an angry face.
		huh = [".qqqq..", "qqqqqq.", "qq..qqQ", "....qqQ", "...qqQ.", "..qqQ..", "..qqQ..", ".......", "..qqQ..", "..qqQ.."],
		angry = ["....ooooo....", "..oohhRRRoo..", ".ohhRRRRRRRo.", ".ohkkRRRkkRo.", "ohRRkkRkkRRRo", "oRRRRRRRRRRRo",
			"oRRkkRRRkkRRo", "oRRkkRRRkkRRo", "oRRRRRRRRRRDo", "oRRRRkkkRRRDo", ".oRRkRRRkRDo.", "..ooDDDDDoo..", "....ooooo...."],
		vein = [".r.r.", "rr.rr", ".....", "rr.rr", ".r.r."],
	}
	const ICON_INK := {
		r = Color8(214, 52, 44), G = Color8(150, 82, 22), g = Color8(255, 196, 70), y = Color8(255, 244, 180),
		w = Color8(255, 255, 255), m = Color8(250, 226, 130), s = Color8(150, 164, 190), S = Color8(64, 76, 104),
		b = Color8(110, 170, 240), n = Color8(110, 64, 36),
		q = Color8(240, 236, 224), Q = Color8(150, 158, 190),
		o = Color8(96, 14, 26), R = Color8(222, 56, 44), h = Color8(255, 132, 92), D = Color8(164, 30, 36), k = Color8(44, 8, 18),
	}
	const BUBBLE := Color8(240, 236, 224)

	## who: hero index 0-2, or -1 for the slime. think: a thought cloud (dots, no tail).
	func _pop(icon: String, who: int, life: float, think := false) -> void:
		pops.append({icon = icon, who = who, at = t, life = life, think = think})

	func _draw_pops(canvas: CanvasItem) -> void:
		var heroes := _heroes()
		var sc := 2.0 if zoom < 1.5 else 1.0  # same size on screen at 1x and 2x
		for pop in pops:
			var age: float = t - pop.at
			if age < 0.0 or age > pop.life or (pop.icon == "huh" and age >= pop.life - 0.001):
				continue
			var base: Vector2
			if pop.who < 0:
				base = screen.slime.position + Vector2(0, -12)
			elif pop.who < heroes.size():
				base = heroes[pop.who].foot + Vector2(0, -36 if zoom < 1.5 else -28)
			else:
				continue
			if pop.icon in ["huh", "angry"]:
				_reaction(canvas, pop.icon, heroes[pop.who], age)
				continue
			var alpha := clampf((pop.life - age) / 0.2, 0.0, 1.0)
			# Pops up with a little overshoot, then hangs, bobbing a pixel.
			var lift := 0.0
			if not screen.calm:
				lift = (1.0 - minf(age / 0.14, 1.0)) * -4.0 + (1.0 if age > 0.14 and age < 0.24 else 0.0)
				lift += roundf(sin(age * 3.0 + pop.who) * 0.6)
			if pop.icon == "sweat":
				var drip := 0.0 if screen.calm else fposmod(age * 10.0, 6.0)
				_icon(canvas, ICONS.sweat, base + Vector2(9, 3 + drip), 1.0, alpha)
				continue
			_bubble(canvas, pop.icon, base + Vector2(-6 if pop.think and pop.who < 0 else 0, lift), sc, pop.think, alpha)

	## A pixel speech bubble (tail) or thought cloud (trailing dots) with an icon in it; its bottom
	## edge sits just above `base`.
	func _bubble(canvas: CanvasItem, icon: String, base: Vector2, sc: float, think: bool, alpha: float) -> void:
		var rows: Array = ICONS[icon]
		var px := sc
		var size := Vector2(rows[0].length() + 4, rows.size() + 4) * px
		var box := Rect2((base - Vector2(size.x * 0.5, size.y + 3 * px)).round(), size)
		var edge := Color(INK, alpha)
		var fill := Color(BUBBLE, alpha)
		# Outline without its corner pixels, then the fill with dark corners: a rounded box.
		canvas.draw_rect(Rect2(box.position + Vector2(0, -px), Vector2(box.size.x, px)), edge)
		canvas.draw_rect(Rect2(box.position + Vector2(0, box.size.y), Vector2(box.size.x, px)), edge)
		canvas.draw_rect(Rect2(box.position + Vector2(-px, 0), Vector2(px, box.size.y)), edge)
		canvas.draw_rect(Rect2(box.position + Vector2(box.size.x, 0), Vector2(px, box.size.y)), edge)
		canvas.draw_rect(box, fill)
		for corner in [box.position, Vector2(box.end.x - px, box.position.y), Vector2(box.position.x, box.end.y - px), box.end - Vector2(px, px)]:
			canvas.draw_rect(Rect2(corner, Vector2(px, px)), edge)
		if think:
			canvas.draw_rect(Rect2((Vector2(box.position.x + 2 * px, box.end.y + px)).round(), Vector2(2, 2) * px), edge)
			canvas.draw_rect(Rect2((Vector2(box.position.x + 2.5 * px, box.end.y + 1.5 * px)).round(), Vector2(px, px)), fill)
			canvas.draw_rect(Rect2((Vector2(box.position.x + px, box.end.y + 3.5 * px)).round(), Vector2(px, px)), edge)
		else:
			var tip := Vector2(roundf(box.position.x + box.size.x * 0.5) - px, box.end.y)
			canvas.draw_rect(Rect2(tip + Vector2(-px, 0), Vector2(4, 1) * px), edge)
			canvas.draw_rect(Rect2(tip, Vector2(2, 1) * px), fill)
			canvas.draw_rect(Rect2(tip + Vector2(0, px), Vector2(2, 1) * px), edge)
			canvas.draw_rect(Rect2(tip + Vector2(0, px), Vector2(1, 1) * px), fill)
			canvas.draw_rect(Rect2(tip + Vector2(0, 2 * px), Vector2(1, 1) * px), edge)
		_icon(canvas, rows, box.get_center(), px, alpha)

	## A bare reaction over an adventurer's head: a "?" that pops up and sways, puzzled, or an
	## angry face that shakes with rage, an anger mark throbbing beside it.
	func _reaction(canvas: CanvasItem, icon: String, hero: Dictionary, age: float) -> void:
		var c: Vector2 = hero.foot + Vector2(0, REACT_Y)
		if not screen.calm:
			c.y += (1.0 - minf(age / 0.12, 1.0)) * 6.0 - (1.0 if age > 0.12 and age < 0.22 else 0.0)
			if icon == "huh":
				c.x += [0.0, 1.0, 0.0, -1.0][int(age * 5.0 + hero.kind) % 4]
			else:
				c.x += 1.0 if int(age * 24.0) % 2 == 0 else -1.0
		_outlined(canvas, ICONS[icon], c.round())
		if icon == "angry" and (screen.calm or fposmod(age + hero.kind * 0.17, 0.5) < 0.3):
			_outlined(canvas, ICONS.vein, c.round() + Vector2(8, -7))

	## An icon at 1x with a dark outline all round, so it reads on any background.
	func _outlined(canvas: CanvasItem, rows: Array, center: Vector2) -> void:
		var origin := (center - Vector2(rows[0].length(), rows.size()) * 0.5).round()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] != ".":
					canvas.draw_rect(Rect2(origin + Vector2(x - 1, y - 1), Vector2(3, 3)), INK)
		_icon(canvas, rows, center, 1.0)

	## Draws an icon bitmap centered on `center`, `px` stage pixels per icon pixel.
	func _icon(canvas: CanvasItem, rows: Array, center: Vector2, px: float, alpha := 1.0) -> void:
		px = maxf(px, 1.0)
		var origin := (center - Vector2(rows[0].length(), rows.size()) * px * 0.5).round()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var key := row[x]
				if key != ".":
					canvas.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), Color(ICON_INK[key], alpha))

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
				anchor = Vector2(160, 90)
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
		s.modulate = Color.WHITE
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
				s.position = Vector2(160 + roundf(sin(t * 2.6) * 3.0), _fall_cam() + 72.0)
				s.modulate = _fall_tint(s.position.y)
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
				s.visible = t >= SEARCH_CUT
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
				if t < SEARCH_CUT:
					_draw_search()
				else:
					_draw_daylight(7.0 + t)
		var s: AnimatedSprite2D = screen.slime
		if s.visible and shot != "splat":
			_halo(self, s.position + Vector2(0, 2), 18.0, goo.light, 0.045)
			if shot == "fall" and s.modulate.g < 0.97:  # hot light from the lava on the slime
				_halo(self, s.position + Vector2(0, 4), 14.0, FLAME_HOT, 0.08 * (1.0 - s.modulate.b))
		_draw_parts(self, true)

	func draw_front(canvas: CanvasItem) -> void:
		match shot:
			"run":
				_draw_pillars(canvas, t * RUN_SPEED)
				_draw_motion_lines(canvas)
			"chase":
				_draw_motion_lines(canvas)
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
					var pose := _search_pose(i)
					var torch: float = pose.get("torch", sin(t * 2.0 + i) * 0.15 + 0.2)
					list.append(_hero_at(spots[i] - Vector2(0, pose.get("hop", 0.0)), i, 0.0, torch, pose))
		return list

	func _hero_at(foot: Vector2, kind: int, run: float, torch: float, pose := {}) -> Dictionary:
		var hero := {foot = foot, kind = kind, run = run, torch = torch, crouch = pose.get("crouch", false), pose = pose}
		if kind == 2:
			hero.tip = foot + Vector2(7, -29)
		else:
			var hand: Vector2 = pose.get("hand", _hand(kind, run) + (Vector2(2, 3) if hero.crouch else Vector2.ZERO))
			hero.tip = foot + hand + Vector2(sin(torch), -cos(torch)) * 9.0
		if pose.get("face", 1.0) < 0.0:
			hero.tip.x = 2.0 * foot.x - hero.tip.x
		return hero

	## The search's acting, per adventurer (0 knight, 1 rogue, 2 wizard): poking at the puddle,
	## then puzzled (scratching heads, peering, looking round), then furious (the knight shakes his
	## torch in the air, the rogue jabs his at the puddle, the wizard stomps). Keys for _hero: face
	## (-1 turns left), head (offset), hand (in place of the torch hand), crouch; plus torch and hop.
	func _search_pose(i: int) -> Dictionary:
		var mad: bool = t >= SEARCH_MAD[i]
		var calm: bool = screen.calm
		var jig := 0.0 if calm else float(int(t * 12.0 + i) % 2)
		match i:
			0:
				if mad:
					return {hand = Vector2(6 + jig, -27), torch = 0.25 + (0.0 if calm else sin(t * 26.0) * 0.4)}
				if t < 1.15:
					return {crouch = true, head = Vector2(0 if t < 0.6 else -1, 0)}
				return {head = Vector2(-1, 0), hand = Vector2(3, -24 + jig), torch = -0.45}  # scratching his helmet
			1:
				if mad:
					return {hand = Vector2(7 + jig * 2.0, -19), torch = 1.0 + jig * 0.15}
				if t > 1.0 and t < 1.6:
					return {face = -1.0}  # looking back down the corridor
				return {head = Vector2(1, 1) if t > 0.6 else Vector2.ZERO}
			_:
				if mad:
					var hop := 0.0
					for stomp in SEARCH_STOMPS:
						var u: float = (t - (stomp - 0.16)) / 0.16
						if u > 0.0 and u < 1.0 and not calm:
							hop = roundf(sin(u * PI) * 3.0)
					return {face = -1.0, hop = hop}
				if t > 1.4 and t < 1.85:
					return {face = 1.0}  # a look round
				return {face = -1.0, head = Vector2(-1, 1) if t > 0.9 else Vector2.ZERO}

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
		var face: float = hero.get("pose", {}).get("face", 1.0)
		if face < 0.0:  # mirrored about the feet
			draw_set_transform(Vector2(2.0 * roundf(hero.foot.x), 0), 0.0, Vector2(-1, 1))
		_hero(self, hero.foot, hero.kind, hero.run, hero.torch, 1.0, SIL, true, true, hero.crouch, hero.get("pose", {}))
		if face < 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

	## An adventurer's silhouette, foot at `foot`, facing right; sc scales whole pixels.
	## kind: 0 knight (helmet, plume, shield, torch), 1 rogue (hood, cape, torch), 2 wizard (hat, staff).
	func _hero(canvas: CanvasItem, foot: Vector2, kind: int, run: float, torch_a: float, sc: float, col: Color,
			rim: bool, flame: bool, crouch: bool, pose := {}) -> void:
		var ph := t * run * 11.0
		var head: Vector2 = pose.get("head", Vector2.ZERO)
		var hx := head.x
		var hy := head.y
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
			r.call(-3 + hx, -21 + by + hy, 6, 4)
			r.call(-6 + hx, -22 + by + hy, 12, 1)
			poly.call([Vector2(-3 + hx, -22 + by + hy), Vector2(3 + hx, -22 + by + hy), Vector2(-2 + hx, -29 + by + hy), Vector2(-6 + hx, -31 + by + hy)])
			r.call(2 + hx, -18 + by + hy, 3, 5)  # beard
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
			r.call(-3 + lean * 2 + hx, -23 + by + cy + hy, 6, 6)
			r.call(-2 + lean * 2 + hx, -24 + by + cy + hy, 4, 1)
			r.call(-5 + lean * 2 + hx, -25 + by + cy + hy, 3, 2)
			r.call(-7 + lean * 2 + hx, -24 + by + cy + hy, 2, 2)
			r.call(-8 + lean * 2 + hx, -22 + by + cy + hy, 1, 2)
			r.call(-7 + lean, -17 + by + cy, 4, 8)
			if rim:
				rc.call(1 + lean * 2 + hx, -21 + by + cy + hy, 2, 1, Color8(255, 196, 120))  # visor glint
				rc.call(3 + lean, -14 + by + cy, 1, 6, RIM)
				rc.call(-6 + lean, -14 + by + cy, 1, 1, Color8(110, 104, 120))  # shield boss
		else:
			var flap := 0.0 if screen.calm or run <= 0.0 else roundf(sin(t * 14.0) * 2.0)
			poly.call([Vector2(-2, -18 + by), Vector2(-10 - flap, -13 + by), Vector2(-9 - flap, -4), Vector2(-2, -7)])
			r.call(-3 + lean, -16 + by + cy, 6, 9 - cy)
			r.call(-3 + lean * 2 + hx, -22 + by + cy + hy, 6, 6)
			r.call(-5 + lean * 2 + hx, -23 + by + cy + hy, 3, 2)
			rc.call(-5, -10 + by, 3, 1, Color8(120, 120, 140) if rim else col)  # dagger
			if rim:
				rc.call(2 + lean, -15 + by + cy, 1, 7, RIM)
				rc.call(2 + lean * 2 + hx, -21 + by + cy + hy, 1, 4, RIM)
		# The torch arm and the torch.
		var hand: Vector2 = pose.get("hand", _hand(kind, run) + Vector2(lean, cy))
		var shoulder := Vector2(2 + lean, -15 + by + cy)
		canvas.draw_line(f + shoulder * sc, f + hand * sc, col, sc)
		var tip := hand + Vector2(sin(torch_a), -cos(torch_a)) * 9.0
		canvas.draw_line(f + hand * sc, f + tip * sc, Color8(50, 34, 30) if rim else col, sc)
		if flame:
			_flame(canvas, f + tip * sc, sc, kind * 3.0, -1.0 if run > 0.0 else 0.0)

	# --- Crack --------------------------------------------------------------------------------

	## The floor that breaks under the slime: a seeded lattice of slabs in perspective, BREAK_XS
	## columns (x at the far edge, spreading toward the viewer like the floor's seams) by BREAK_YS
	## rows, jittered, with jagged shared edges. The edges are the cracks that spread first (from
	## under the slime outward, plus hairlines running off the rim); from BREAK_AT the slabs sag and
	## drop: the middle under the slime first, then the rim crumbling away piece by piece (a slab
	## only drops once the one in front of it has gone, and some rim slabs stay put, cracked).
	const BREAK_XS := [126.0, 137.0, 148.0, 160.0, 172.0, 183.0, 192.0]
	const BREAK_YS := [112.0, 121.0, 131.0, 152.0]
	const BREAK_AT := 2.35
	const VOID := Color8(6, 4, 10)
	## The hole's glow from the lava far, far below: [top y, color, dithered].
	const GLOW_BANDS := [[126.0, Color8(36, 12, 12), true], [130.0, Color8(36, 12, 12), false],
		[136.0, Color8(80, 24, 14), true], [140.0, Color8(80, 24, 14), false]]

	static func _floor_x(x: float, y: float) -> float:
		return 160.0 + (x - 160.0) * (1.0 + 0.8 * (y - FLOOR_Y) / 38.0)

	func _make_cracks() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 4242
		var nx := BREAK_XS.size()
		var ny := BREAK_YS.size()
		var cols := nx - 1
		var v: Array[Vector2] = []  # lattice corners, v[j * nx + i]
		for j in ny:
			for i in nx:
				var bx: float = BREAK_XS[i]
				var mid := bx >= 148.0 and bx <= 172.0
				var y: float = BREAK_YS[j]
				if j > 0:
					y += r.randi_range(-2, 2)
				elif not mid:
					y += r.randi_range(2, 5)  # a ragged strip of floor stays along the wall
				var jit := 0 if mid and j == 0 else r.randi_range(-2, 2)
				v.append(Vector2(roundf(_floor_x(bx + jit, y)), y))
		var jag := func(a: Vector2, b: Vector2, n: int, amt: int) -> PackedVector2Array:
			var pts := PackedVector2Array([a])
			var normal := (b - a).normalized().orthogonal()
			for k in range(1, n + 1):
				var p := (a.lerp(b, float(k) / (n + 1)) + normal * r.randi_range(-amt, amt)).round()
				pts.append(Vector2(p.x, maxf(p.y, FLOOR_Y)))
			pts.append(b)
			return pts
		var cell := func(i: int, j: int) -> int:
			return j * cols + i if i >= 0 and i < cols and j >= 0 and j < ny - 1 else -1
		var origin := Vector2(160, FLOOR_Y)
		var h_edge := {}  # Vector2i(i, j): v(i, j) -> v(i + 1, j)
		var v_edge := {}  # Vector2i(i, j): v(i, j) -> v(i, j + 1)
		var wall_foot := {}
		for j in ny:
			for i in nx:
				var a := v[j * nx + i]
				if i < cols:
					var b := v[j * nx + i + 1]
					var pts: PackedVector2Array
					if j == 0 and a.y == FLOOR_Y and b.y == FLOOR_Y:
						# The wall's foot: its bottom bricks crumble too, in notches up into the wall.
						pts = PackedVector2Array([a])
						for k in range(1, 5):
							pts.append(Vector2(roundf(lerpf(a.x, b.x, k / 5.0)), FLOOR_Y - r.randi_range(0, 2)))
						pts.append(b)
						wall_foot[Vector2i(i, j)] = true
					else:
						pts = jag.call(a, b, 3 if j == 0 else 2, 2)
					h_edge[Vector2i(i, j)] = pts
					_add_crack(pts, origin, cell.call(i, j - 1), cell.call(i, j), j > 0 and j < ny - 1, r)
				if j < ny - 1:
					v_edge[Vector2i(i, j)] = jag.call(a, v[(j + 1) * nx + i], 2, 2)
					_add_crack(v_edge[Vector2i(i, j)], origin, cell.call(i - 1, j), cell.call(i, j), j == ny - 2, r)
		# Hairline cracks running off the rim into the floor that stays.
		for spec in [[0, 0, -11.0, 3.0], [0, 1, -14.0, 4.0], [0, 2, -9.0, 6.0], [nx - 1, 0, 8.0, 3.0], [nx - 1, 1, 10.0, 5.0], [nx - 1, 2, 9.0, 6.0]]:
			var a := v[spec[1] * nx + spec[0]]
			var pts: PackedVector2Array = jag.call(a, a + Vector2(spec[2], spec[3]), 2, 1)
			cracks.append({pts = pts, t0 = 1.75 + r.randf() * 0.3, dur = 0.35, a = -1, b = -1, minor = false})
		# The slabs, their fall times and their rims.
		for j in ny - 1:
			for i in cols:
				var top: PackedVector2Array = h_edge[Vector2i(i, j)]
				var right: PackedVector2Array = v_edge[Vector2i(i + 1, j)]
				var bottom: PackedVector2Array = h_edge[Vector2i(i, j + 1)].duplicate()
				bottom.reverse()
				var left: PackedVector2Array = v_edge[Vector2i(i, j)].duplicate()
				left.reverse()
				var poly := top.duplicate()
				poly.append_array(right.slice(1))
				poly.append_array(bottom.slice(1))
				poly.append_array(left.slice(1, left.size() - 1))
				var outline := poly.duplicate()
				outline.append(poly[0])
				var under := PackedVector2Array()
				for p in poly:
					under.append(p + Vector2(0, 3))
				var center := Vector2.ZERO
				for p in poly:
					center += p
				center /= poly.size()
				var glow: Array[Dictionary] = []
				for band in GLOW_BANDS:
					var y0: float = band[0]
					var clip := PackedVector2Array([Vector2(60, y0), Vector2(260, y0), Vector2(260, 200), Vector2(60, 200)])
					for part: PackedVector2Array in Geometry2D.intersect_polygons(poly, clip):
						var uv := PackedVector2Array()
						if band[2]:
							for p in part:
								uv.append(p * 0.5)
						glow.append({poly = part, c = band[1], uv = uv})
				# Rims: the broken faces of the floor left round the hole once this slab is gone.
				var sides: Array[Dictionary] = []
				var specs := [[top, Vector2(0, 3), cell.call(i, j - 1), 0], [left, Vector2(2, 1), cell.call(i - 1, j), 1],
					[right, Vector2(-2, 1), cell.call(i + 1, j), 2], [bottom, Vector2.ZERO, cell.call(i, j + 1), 3]]
				for s in specs:
					var pts: PackedVector2Array = s[0]
					var faces: Array[PackedVector2Array] = []
					var wall: bool = s[3] == 0 and wall_foot.has(Vector2i(i, j))
					if s[1] != Vector2.ZERO and not wall:
						var face := pts.duplicate()
						for k in range(pts.size() - 1, -1, -1):
							var wobble := Vector2(0, r.randi_range(-1, 1)) if s[3] == 0 and k > 0 and k < pts.size() - 1 else Vector2.ZERO
							face.append(pts[k] + s[1] + wobble)
						for part: PackedVector2Array in Geometry2D.intersect_polygons(face, poly):
							faces.append(part)
					sides.append({pts = pts, faces = faces, other = s[2], kind = s[3], dark = wall or s[3] == 3})
				pieces.append({poly = poly, outline = outline, under = under, top = top, center = center, glow = glow,
					sides = sides, at = INF, vx = signf(center.x - 160.0) * -r.randf_range(2.0, 10.0)})
		# Fall order: the middle first, then the rim; front to back within a column, so a falling
		# slab never passes over floor that is still there.
		for i in cols:
			var drop := r.randf() < 0.75 or i in [2, 3]
			for j in range(ny - 2, -1, -1):
				var at := BREAK_AT + (ny - 2 - j) * 0.02
				if i == 1 or i == cols - 2:
					at += 0.06 + r.randf() * 0.05
				elif i == 0 or i == cols - 1:
					at += 0.2 + r.randf() * 0.75
					if r.randf() < 0.3:
						drop = false  # this rim slab (and the ones behind it) holds
				if j < ny - 2:
					at = maxf(at, pieces[(j + 1) * cols + i].at + 0.04)
				pieces[j * cols + i].at = at if drop else INF

	## A crack along `pts` between slabs a and b (-1 = none), growing from its end nearer `origin`.
	## Minor ones (between slabs, across the spokes) only split open just before the floor goes.
	func _add_crack(pts: PackedVector2Array, origin: Vector2, a: int, b: int, minor: bool, r: RandomNumberGenerator) -> void:
		var grow := pts.duplicate()
		if grow[grow.size() - 1].distance_to(origin) < grow[0].distance_to(origin):
			grow.reverse()
		var length := 0.0
		for k in grow.size() - 1:
			length += grow[k].distance_to(grow[k + 1])
		var t0 := minf(0.75 + grow[0].distance_to(origin) * 0.02, 1.95)
		if minor:
			t0 = 1.85 + r.randf() * 0.25
		cracks.append({pts = grow, t0 = t0, dur = clampf(0.1 + length * 0.012, 0.15, 0.3), a = a, b = b, minor = minor})

	func _fallen(i: int) -> bool:
		return i >= 0 and t >= pieces[i].at

	## The corridor ends in a solid wall right of the slime (cornered): big torch-lit blocks, a
	## perspective edge where it meets the floor, and a heap of rubble at its foot.
	func _draw_dead_end() -> void:
		var x0 := 204.0
		var floor_x := 160.0 + (x0 - 160.0) * 1.8
		var sconce := Vector2(220, 80)
		lights.append(Vector3(sconce.x, sconce.y, 56.0 * _flicker(sconce.x)))
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(340, 0), Vector2(340, 190), Vector2(floor_x + (190 - STAGE_BOTTOM) * 1.2, 190),
			Vector2(x0, FLOOR_Y)]), WARM[1])
		var row := 0
		var y := 14.0
		while y < FLOOR_Y:
			var x := x0 + (0.0 if row % 2 else -8.0)
			var col := 0
			while x < 330:
				var bx := maxf(x, x0 + 1)
				var band := _light_band(Vector2(bx + 8, y + 5), _bayer(col, row) - 0.25)
				var c: Color = WARM[clampi(band, 2, 4)]
				draw_rect(Rect2(bx, y + 1, x + 15 - bx, 9), c)
				if band >= 2:
					draw_rect(Rect2(bx, y + 1, x + 15 - bx, 1), WARM[mini(band + 1, 5)])
				x += 16
				col += 1
			y += 10
			row += 1
		# The wall's lit edge and its foot meeting the floor in perspective.
		draw_rect(Rect2(x0, 14, 1, FLOOR_Y - 14), WARM[5])
		draw_rect(Rect2(x0 + 1, 14, 2, FLOOR_Y - 14), Color(INK, 0.35))
		draw_line(Vector2(x0, FLOOR_Y), Vector2(floor_x + (190 - STAGE_BOTTOM) * 1.2, 190), WARM[4], 1.0)
		_draw_wall_torch(sconce)
		# Rubble heaped at the foot.
		var rocks := [Rect2(x0 - 9, FLOOR_Y - 3, 6, 4), Rect2(x0 - 4, FLOOR_Y - 6, 7, 7), Rect2(x0 + 2, FLOOR_Y - 2, 6, 5),
			Rect2(x0 - 14, FLOOR_Y, 4, 3), Rect2(x0 + 6, FLOOR_Y + 4, 5, 4)]
		for rock: Rect2 in rocks:
			draw_rect(rock, WARM[2])
			draw_rect(Rect2(rock.position + Vector2(1, 0), Vector2(rock.size.x - 2, 1)), WARM[4])
			draw_rect(Rect2(rock.position + Vector2(0, rock.size.y - 1), Vector2(rock.size.x, 1)), WARM[1])
			draw_rect(Rect2(rock.end.x - 1, rock.position.y + 1, 1, rock.size.y - 1), WARM[1])

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
		for i in 16:
			_dust(Vector2(r.randf_range(128, 192), FLOOR_Y + r.randi_range(0, 4)), 1)
		for i in 12:
			_pebble(Vector2(r.randf_range(140, 180), FLOOR_Y + r.randf_range(0, 18)), Vector2(r.randf_range(-30, 30), r.randf_range(-60, 0)), r)

	## A loose bit of floor tumbling into the hole (behind the slime).
	func _pebble(p: Vector2, v: Vector2, r: RandomNumberGenerator) -> void:
		_part({p = p.round(), v = v, g = 420.0, life = r.randf_range(0.7, 1.3), c = WARM[r.randi_range(1, 3)],
			s = 1.0 if r.randf() < 0.6 else 2.0, back = true})

	func _draw_crack() -> void:
		_draw_corridor(_crack_scroll(), _heroes())
		_draw_dead_end()
		if t >= BREAK_AT:
			# The void where slabs have gone, faintly lit by lava far, far down.
			for piece in pieces:
				if t >= piece.at:
					draw_colored_polygon(piece.poly, VOID)
					for g: Dictionary in piece.glow:
						draw_colored_polygon(g.poly, g.c, g.uv, checker if g.uv.size() > 0 else null)
			# The broken edges of the floor round it: the far rim's torn face (lit along its top),
			# the side walls' faces, and a dark lip on the near side.
			for piece in pieces:
				if t < piece.at:
					continue
				for side: Dictionary in piece.sides:
					if _fallen(side.other):
						continue
					var face: Color = WARM[1] if side.kind == 2 else WARM[2]
					for f: PackedVector2Array in side.faces:
						draw_colored_polygon(f, face)
					draw_polyline(side.pts, INK if side.dark else WARM[4], 1.0)
		for crack in cracks:
			if t < crack.t0 or (t >= BREAK_AT and (_fallen(crack.a) or _fallen(crack.b))):
				continue
			var pts: PackedVector2Array = crack.pts
			var reach := clampf((t - crack.t0) / crack.dur, 0.0, 1.0) * (pts.size() - 1)
			for i in pts.size() - 1:
				if reach <= i:
					break
				var a := pts[i]
				var b := a.lerp(pts[i + 1], minf(reach - i, 1.0)).round()
				if not crack.minor:
					draw_line(a + Vector2(0, 1), b + Vector2(0, 1), WARM[4], 1.0)  # the lit lip under the crack
				draw_line(a, b, INK, 1.0)
		# The slabs dropping away: a sag, then down, showing their broken front face.
		for piece in pieces:
			if t < piece.at:
				continue
			var age: float = t - piece.at
			var off := Vector2(roundf(piece.vx * age), 1.0 + roundf(220.0 * age * age))
			if off.y > 70.0:
				continue
			draw_set_transform(off)
			draw_colored_polygon(piece.under, WARM[1])
			draw_colored_polygon(piece.poly, WARM[clampi(_light_band(piece.center), 2, 3)])
			draw_polyline(piece.top, WARM[4], 1.0)
			draw_polyline(piece.outline, Color(INK, 0.6), 1.0)
			draw_set_transform(Vector2.ZERO)

	# --- Fall: a cross-section of the mountain ------------------------------------------------

	## Camera top during the fall: slow off the ledge, then faster and faster.
	func _fall_cam() -> float:
		var u := clampf(t / FALL_TIME, 0.0, 1.0)
		var end := LAYER_H * 10.0 - 16.0 - 128.0
		return FALL_TOP + (end - FALL_TOP) * (0.18 * u + 0.82 * u * u)

	func _mountain_half(y: float) -> float:
		return 84.0 + maxf(y, 0.0) * 0.28


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
			_draw_rim(corridor_hole, -30.0, corridor_rim, 0.0 if screen.calm else t)
			_halo(self, Vector2(136, -52), 26, FLAME_HOT, 0.06)
			_hero(self, Vector2(134, -30), 0, 0.0, 0.4, 1.0, SIL, true, true, true)
			_hero(self, Vector2(116, -30), 1, 0.0, 0.2, 1.0, SIL, true, true, false)
		draw_polyline(rows, Color8(80, 62, 100), 1.0)
		draw_polyline(rows_r, Color8(80, 62, 100), 1.0)

	## The hole the slime drops through in every floor (and the corridor above), and the column it
	## falls down: no prop, liquid or rock is ever drawn inside SHAFT_L..SHAFT_R.
	const HOLE_L := 146.0
	const HOLE_R := 174.0
	const SHAFT_L := 141.0
	const SHAFT_R := 179.0

	## The layer (0 = Volcanic Vault at the top) a stage y falls in, and how far down it (0-1).
	func _layer_at(y: float) -> Vector2:
		var i := clampi(int(floor(y / LAYER_H)), 0, layers.size() - 1)
		return Vector2(i, clampf((y - i * LAYER_H) / LAYER_H, 0.0, 1.0))

	## The light a floor throws on the slime falling through it (multiplied into its colors).
	func _fall_tint(y: float) -> Color:
		var at := _layer_at(y)
		var layer: Dictionary = layers[int(at.x)]
		if y < 0.0:
			return Color.WHITE
		if layer.id == "volcanic":
			var heat := clampf((at.y - 0.05) / 0.6, 0.0, 1.0)
			var flick := 0.0 if screen.calm else 0.06 * sin(t * 31.0)
			return Color.WHITE.lerp(Color(1.6 + flick, 0.95, 0.5), heat)
		var light: Color = layer.pal.B if layer.id in ["crystal", "sunken", "sewers", "frozen"] else layer.pal.x
		return Color.WHITE.lerp(Color(light.r * 1.3, light.g * 1.3, light.b * 1.3), 0.22)

	func _sig_color(layer: Dictionary) -> Color:
		match layer.id:
			"volcanic":
				return layer.pal.d
			"sewers":
				return layer.pal.v
		return layer.pal.w

	## One floor of the dungeon in the cut: back wall, its theme's set dressing (kept out of the
	## shaft), and the slab under it, opened by a themed hole (except the bottom floor, where the
	## slime lands).
	func _draw_chamber(i: int, y0: float) -> void:
		var layer: Dictionary = layers[i]
		var pal: Dictionary = layer.pal
		var slab_y := y0 + LAYER_H - 16.0
		var hw := minf(_mountain_half(y0 + 10) - 16.0, 84.0)
		var left := 160.0 - hw
		var width := hw * 2.0
		var ramp: Array = [pal.k.lerp(pal.z, 0.25), pal.k.lerp(pal.z, 0.6), pal.z, pal.z.lerp(pal.W, 0.55)]
		draw_rect(Rect2(left, y0, width, slab_y - y0), pal.k)
		# Blocks in pools of the floor's own light, dithered between steps. The Volcanic Vault is lit
		# from below by its two lava pools; the others by a glow in the middle.
		var glows: Array[Vector2] = [Vector2(160, y0 + (slab_y - y0) * 0.62)]
		var reach := hw * 0.95
		if layer.id == "volcanic":
			# Basalt lit red-hot from below by the two lava pools.
			glows = [Vector2(left + 26, slab_y - 4), Vector2(left + width - 26, slab_y - 4)]
			reach = hw * 1.05
			ramp = [Color8(30, 14, 16), Color8(58, 24, 22), Color8(98, 38, 26), Color8(150, 62, 32)]
		var row := 0
		var by := y0 + 2.0
		while by < slab_y - 4:
			var bx := left + 2 - (9.0 if row % 2 else 0.0)
			var col := 0
			while bx < left + width - 2:
				var d := 9.0
				for g in glows:
					d = minf(d, Vector2(bx + 9, by + 3).distance_to(g) / reach)
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
		var room := Rect2(left, y0, width, slab_y - y0)
		_draw_dressing(layer.id, pal, room)
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
		if layer.id == "volcanic":
			_draw_lava_front(pal, room)
		if i < layers.size() - 1:
			_draw_hole(layer, slab_y)

	## Solid rock never reaches into CLEAR_L..CLEAR_R: the slime's body as it sways down the shaft.
	const CLEAR_L := 149
	const CLEAR_R := 171
	const HOLE_KEYS := ["gap", "lit", "face_l", "face_r", "shade", "crack", "crack_lit", "stone_lit", "crumb"]

	## A crumbled opening through a slab `h` px thick, seeded so every playback is the same. Per row,
	## where the gap starts and ends (jagged: a crumbled-off top corner, an overhanging lip with an
	## undercut below it, a ragged underside), plus the rects that dress it (lit ledges, broken
	## faces, cracks running off the rim, a loose stone, crumbs hanging under it) and the pebbles and
	## dust puffs falling off it. x is stage x, y is from the slab's top. Solid pixels never reach
	## CLEAR_L..CLEAR_R; built once, drawn as plain rects.
	static func _make_hole(seed: int, h: int) -> Dictionary:
		var r := RandomNumberGenerator.new()
		r.seed = seed
		var hole := {h = h, pebbles = [], dust = []}
		for key in HOLE_KEYS:
			hole[key] = [] as Array[Rect2]
		var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]  # first gap x / first solid x
		for side in 2:
			var most := 3 if side == 0 else 2  # how far rock may jut toward the middle
			var lip := r.randi_range(3, h - 8)
			var walk := r.randi_range(-2, 0)
			for y in h:
				if r.randf() < 0.5:
					walk = clampi(walk + r.randi_range(-2, 2), -4, most - 1)
				var inset := walk
				if y == 0:
					inset = -r.randi_range(3, 5)  # the top corner crumbled away
				elif y == 1:
					inset = mini(walk, -r.randi_range(1, 3))
				elif y == lip:
					inset = most  # an overhanging lip ...
				elif y == lip + 1:
					inset = most - 1
				elif y >= lip + 2 and y <= lip + 3:
					inset = -r.randi_range(2, 4)  # ... undercut below it
					walk = inset
				if y >= h - 2:
					inset = mini(inset, walk) - r.randi_range(1, 2)  # a ragged underside
				inset = clampi(inset, -5, most)
				edges[side].append(int(HOLE_L) + inset if side == 0 else int(HOLE_R) - inset)
		var el := edges[0]
		var er := edges[1]
		hole.top_l = el[0]
		hole.top_r = er[0]
		hole.bottom_l = el[h - 1]
		hole.bottom_r = er[h - 1]
		# The gap, row by row (equal rows merged).
		var y0 := 0
		for y in range(1, h + 1):
			if y == h or el[y] != el[y0] or er[y] != er[y0]:
				hole.gap.append(Rect2(el[y0], y0, er[y0] - el[y0], y - y0))
				y0 = y
		# Chips out of the slab's top near the rim.
		for side in 2:
			var w := r.randi_range(1, 3)
			var x := el[0] - r.randi_range(4, 8) - w if side == 0 else er[0] + r.randi_range(3, 7)
			hole.gap.append(Rect2(x, 0, w, r.randi_range(1, 2)))
		# The broken faces: lit where rock juts out under open air, shaded under overhangs.
		for y in h:
			for side in 2:
				var e: int = el[y] if side == 0 else er[y]
				var prev: int = (el[y - 1] if side == 0 else er[y - 1]) if y > 0 else e
				var juts := (e > prev) if side == 0 else (e < prev)
				if juts:
					hole.lit.append(Rect2(mini(e, prev), y, absi(e - prev), 1))
				hole[("face_l" if side == 0 else "face_r")].append(Rect2(e - 1 if side == 0 else e, y, 1, 1))
				if y + 1 < h:
					var below: int = el[y + 1] if side == 0 else er[y + 1]
					if (below < e) if side == 0 else (below > e):
						hole.shade.append(Rect2(mini(e, below), y, absi(e - below), 1))
		# Cracks running off the rim into the slab: one along it, one up to the top (a loose corner).
		for side in 2:
			var dir := -1 if side == 0 else 1
			for k in 2:
				var y := r.randi_range(3, h - 4) if k == 0 else r.randi_range(3, mini(6, h - 4))
				var x: int = (el[y] - 1 if side == 0 else er[y])
				for step in r.randi_range(4, 9 if h < 20 else 14):
					x += dir
					if k == 1:
						if r.randf() < 0.55:
							y -= 1
						if y < 0:
							break
					elif r.randf() < 0.4:
						y = clampi(y + r.randi_range(-1, 1), 2, h - 3)
					hole.crack.append(Rect2(x, y, 1, 1))
					if k == 0:
						hole.crack_lit.append(Rect2(x, y + 1, 1, 1))
		# A loose stone at the rim on one side: seams round it, its top catching the light.
		var ss := r.randi_range(0, 1)
		var sy := r.randi_range(4, h - 5)
		var se: int = el[sy] if ss == 0 else er[sy]
		var sx := se - 5 if ss == 0 else se + 1
		var seam_x := sx - 1 if ss == 0 else sx + 4
		hole.crack.append(Rect2(sx - (1 if ss == 0 else 0), sy - 1, 5, 1))
		hole.crack.append(Rect2(seam_x, sy, 1, 3))
		hole.stone_lit.append(Rect2(sx, sy, 4, 1))
		# Crumbs hanging off the underside and pebbles dropping from it, clear of the shaft.
		for side in 2:
			var e: int = el[h - 1] if side == 0 else er[h - 1]
			var x := e - r.randi_range(2, 4) if side == 0 else e + r.randi_range(0, 2)
			hole.crumb.append(Rect2(x, h, 2, 1))
			hole.crumb.append(Rect2(x + (1 if side == 0 else 0), h + 1, 1, 1))
			for k in 2:
				var px := clampi(e + r.randi_range(-3, 1), 141, CLEAR_L - 2) if side == 0 else clampi(e + r.randi_range(-1, 3), CLEAR_R + 1, 178)
				hole.pebbles.append({x = px, phase = r.randf(), speed = r.randf_range(0.55, 0.95), s = 1 + int(r.randf() < 0.4)})
			hole.dust.append({x = (el[0] - 2 if side == 0 else er[0] + 1), y = -1, phase = r.randf()})
			hole.dust.append({x = (e - 3 if side == 0 else e + 2), y = h + 1, phase = r.randf()})
		return hole

	## The rim's colors from a theme palette (the Volcanic Vault's glow red-hot).
	static func _rim_colors(id: String, pal: Dictionary) -> Dictionary:
		if id == "volcanic":
			return {gap = pal.k, lit = pal.B, face_l = pal.d, face_r = Color8(200, 70, 24), shade = Color8(120, 40, 20),
				crack = pal.d, crack_lit = Color8(120, 40, 20), stone_lit = pal.d, crumb = Color8(200, 70, 24),
				pebble = FLAME_HOT, pebble_lit = pal.B, dust = Color8(120, 100, 120)}
		return {gap = pal.k, lit = pal.x, face_l = pal.w, face_r = pal.z, shade = pal.z.lerp(pal.k, 0.45),
			crack = pal.k, crack_lit = pal.w, stone_lit = pal.w, crumb = pal.z, pebble = pal.W, pebble_lit = pal.x, dust = pal.w}

	## Draws a hole from _make_hole with its top at `top_y`.
	func _draw_rim(hole: Dictionary, top_y: float, c: Dictionary, tt: float) -> void:
		for key in HOLE_KEYS:
			var col: Color = c[key]
			for rect: Rect2 in hole[key]:
				draw_rect(Rect2(rect.position.x, top_y + rect.position.y, rect.size.x, rect.size.y), col)
		var h: float = hole.h
		for p: Dictionary in hole.pebbles:
			var u := fposmod(tt * p.speed + p.phase, 1.0)
			var y := top_y + h + roundf(u * u * 40.0)
			var a := 1.0 if u < 0.75 else (1.0 - u) * 4.0
			draw_rect(Rect2(p.x, y, p.s, p.s), Color(c.pebble, a))
			draw_rect(Rect2(p.x, y, 1, 1), Color(c.pebble_lit, a))
		for d: Dictionary in hole.dust:
			var u := fposmod(tt * 0.8 + d.phase, 1.0)
			var spread := roundf(u * 3.0)
			var col := Color(c.dust, 0.5 * (1.0 - u))
			draw_rect(Rect2(d.x - spread, top_y + d.y - roundf(u * 3.0), 2, 1), col)
			draw_rect(Rect2(d.x + spread + 1, top_y + d.y - roundf(u * 2.0) - 1, 1, 1), col)

	## The opening in a floor slab: a dark broken-edged gap through the slab's cut, then the
	## theme's own lip (glowing crust, crystals, an open grate, ice, a mine collar, sand, water...).
	func _draw_hole(layer: Dictionary, slab_y: float) -> void:
		var tt := 0.0 if screen.calm else t
		var id: String = layer.id
		var pal: Dictionary = layer.pal
		var hole: Dictionary = layer.hole
		_draw_rim(hole, slab_y, layer.rim, tt)
		var top_l: float = hole.top_l  # first open x at the top of the slab, left
		var top_r: float = hole.top_r  # first rock x at the top, right
		match id:
			"volcanic":
				# Crust split open: the rim and its cracks glow red-hot (_rim_colors), the corners pulse.
				_halo(self, Vector2(160, slab_y + 2), 22.0, pal.d, 0.05)
				var pulse := 0.5 + 0.5 * sin(tt * 5.0)
				draw_rect(Rect2(top_l - 2, slab_y, 2, 1), Color(pal.B, 0.6 + 0.4 * pulse))
				draw_rect(Rect2(top_r, slab_y, 2, 1), Color(pal.B, 0.6 + 0.4 * pulse))
			"crystal":
				for x in [top_l - 3.0, top_l - 7.0, top_r + 3.0, top_r + 7.0]:
					var h := 7.0 if absf(x - 160) < 18 else 4.0
					var lean := -2.0 if x < 160 else 2.0
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, slab_y), Vector2(x + 2, slab_y), Vector2(x + lean, slab_y - h)]), pal.v)
					draw_rect(Rect2(x, slab_y - h + 2, 1, 2), Color8(230, 250, 255))
				_halo(self, Vector2(160, slab_y), 18.0, pal.v, 0.04)
			"obsidian":
				# The oubliette's grate hangs open from its hinge.
				var hx := top_l - 2.0
				draw_rect(Rect2(hx, slab_y - 1, 3, 2), Color8(90, 86, 110))
				for k in 4:
					draw_rect(Rect2(hx - 1 + (k % 2), slab_y + 1 + k * 5, 2, 4), Color8(60, 56, 80))
				draw_rect(Rect2(hx - 1, slab_y + 1, 1, 20), Color8(104, 98, 128))
			"frozen":
				var bl: float = hole.bottom_l
				var br: float = hole.bottom_r
				for x in [bl - 3.0, bl - 7.0, bl - 11.0, br + 2.0, br + 6.0, br + 10.0]:
					var h := 3.0 + int(absf(x - 160)) % 4
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, slab_y + 16), Vector2(x + 2, slab_y + 16), Vector2(x, slab_y + 16 + h)]), pal.x)
				for x in [top_l - 3.0, top_r + 2.0]:
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, slab_y), Vector2(x + 2, slab_y), Vector2(x, slab_y - 4)]), pal.x)
			"catacombs":
				draw_rect(Rect2(top_l - 9, slab_y - 3, 6, 3), pal.w)
				draw_rect(Rect2(top_l - 9, slab_y - 3, 6, 1), pal.x)
				draw_colored_polygon(PackedVector2Array([Vector2(top_r, slab_y), Vector2(top_r + 9, slab_y - 4), Vector2(top_r + 10, slab_y - 2), Vector2(top_r + 2, slab_y + 1)]), pal.w)
			"sewers", "sunken", "sandstone":
				# Whatever lies on the floor spills over both lips and pours down the shaft's walls.
				var stuff: Color = pal.d if id != "sandstone" else pal.w
				var shine: Color = pal.B if id != "sandstone" else pal.x
				for side in [top_l, top_r - 2.0]:
					draw_rect(Rect2(side, slab_y - 1, 2, 22), stuff)
					for k in 3:
						var yy := fposmod(k * 7.0 + tt * 40.0, 20.0)
						draw_rect(Rect2(side, slab_y + roundf(yy), 1, 2), shine)
					draw_rect(Rect2(side - 1, slab_y + 21, 1, 1), shine)
					draw_rect(Rect2(side + 2, slab_y + 22, 1, 1), shine)
			"mossy":
				# A mine shaft's timber collar and a ladder down its wall.
				for x in [top_l - 4.0, top_r]:
					draw_rect(Rect2(x, slab_y - 6, 3, 22), Color8(92, 64, 40))
					draw_rect(Rect2(x, slab_y - 6, 1, 22), Color8(140, 100, 60))
				draw_rect(Rect2(top_l - 8, slab_y - 7, 9, 2), Color8(110, 78, 46))
				draw_rect(Rect2(top_r - 1, slab_y - 7, 9, 2), Color8(110, 78, 46))

	func _draw_dressing(id: String, pal: Dictionary, r: Rect2) -> void:
		var floor_y := r.end.y
		var top := r.position.y
		var tt := 0.0 if screen.calm else t
		match id:
			"volcanic":
				_draw_lava_back(pal, r)
			"crystal":
				_halo(self, Vector2(r.position.x + 30, floor_y - 10), 40, pal.v, 0.05)
				_halo(self, Vector2(r.end.x - 30, floor_y - 10), 40, pal.v, 0.05)
				for k in 9:
					var x := r.position.x + 10 + k * (r.size.x - 20) / 8.0
					if x > SHAFT_L - 6 and x < SHAFT_R + 6:
						continue
					var h := 10.0 + (k * 7) % 12
					draw_colored_polygon(PackedVector2Array([Vector2(x - 4, floor_y), Vector2(x + 4, floor_y), Vector2(x, floor_y - h)]), pal.v)
					draw_line(Vector2(x, floor_y - h + 2), Vector2(x - 2, floor_y - 1), Color8(230, 250, 255), 1.0)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 3, top), Vector2(x + 3, top), Vector2(x + 1, top + h * 0.6)]), pal.B)
			"obsidian":
				for x in [r.position.x + 22, r.position.x + 44, r.end.x - 44, r.end.x - 22]:
					var h := 20.0 + int(x) % 18
					for k in int(h / 3.0):
						draw_rect(Rect2(roundf(x) - (k % 2), top + k * 3, 1 + (k % 2), 2), Color8(60, 56, 80))
					draw_rect(Rect2(roundf(x) - 1, top + h, 3, 3), Color8(80, 76, 104))
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 12, floor_y), Vector2(r.position.x + 22, floor_y - 14), Vector2(r.position.x + 28, floor_y)]), pal.v)
				draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 30, floor_y), Vector2(r.end.x - 22, floor_y - 18), Vector2(r.end.x - 14, floor_y)]), pal.v)
			"frozen":
				for k in 16:
					var x := r.position.x + 6 + k * (r.size.x - 12) / 15.0
					if x > SHAFT_L - 2 and x < SHAFT_R + 2:
						continue
					var h := 4.0 + (k * 5) % 9
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, top), Vector2(x + 2, top), Vector2(x, top + h)]), pal.x)
				# Ice sheets on the floor, cracked away around the hole.
				for span in [[r.position.x, HOLE_L - 2.0], [HOLE_R + 2.0, r.end.x]]:
					draw_rect(Rect2(span[0], floor_y - 3, span[1] - span[0], 3), pal.x)
					draw_rect(Rect2(span[0], floor_y - 4, span[1] - span[0], 1), pal.w)
			"catacombs":
				for x in [r.position.x + 18, r.position.x + 40, r.position.x + 62, r.end.x - 62, r.end.x - 40, r.end.x - 18]:
					if x > SHAFT_L - 6 and x < SHAFT_R + 6:
						continue
					var y := top + 30 + (int(x) % 2) * 16
					draw_rect(Rect2(roundf(x) - 5, y - 2, 10, 9), pal.k)
					draw_rect(Rect2(roundf(x) - 3, y, 6, 5), pal.x)
					draw_rect(Rect2(roundf(x) - 2, y + 2, 1, 1), pal.k)
					draw_rect(Rect2(roundf(x) + 1, y + 2, 1, 1), pal.k)
				for x in [r.position.x + 20, r.position.x + 48, r.end.x - 52, r.end.x - 26]:
					draw_rect(Rect2(roundf(x), floor_y - 2, 7, 2), pal.x)
			"sewers":
				for span in [[r.position.x, HOLE_L - 1.0], [HOLE_R + 1.0, r.end.x]]:
					draw_rect(Rect2(span[0], floor_y - 6, span[1] - span[0], 6), pal.d)
					draw_rect(Rect2(span[0], floor_y - 6, span[1] - span[0], 1), pal.B)
				for k in 6:
					var x := r.position.x + fposmod(k * 47.0 + tt * 30.0, r.size.x - 2)
					if x > HOLE_L - 4 and x < HOLE_R + 2:
						continue
					draw_rect(Rect2(roundf(x), floor_y - 8 - (int(tt * 4.0 + k) % 3), 2, 2), pal.B)
				draw_rect(Rect2(r.position.x, top + 24, 30, 6), pal.z)
				draw_rect(Rect2(r.position.x + 28, top + 22, 4, 10), pal.W)
				draw_rect(Rect2(r.end.x - 30, top + 40, 30, 6), pal.z)
				draw_rect(Rect2(r.end.x - 32, top + 38, 4, 10), pal.W)
			"sunken":
				# Two flooded basins either side of the hole, walled off from it.
				for span in [[r.position.x, HOLE_L - 6.0], [HOLE_R + 6.0, r.end.x]]:
					var water := floor_y - 12.0
					draw_rect(Rect2(span[0], water, span[1] - span[0], 12), Color(pal.d, 0.85))
					var x: float = span[0]
					while x < span[1] - 6:
						draw_rect(Rect2(roundf(x + sin(tt * 3.0 + x) * 1.5), water, 5, 1), pal.B)
						x += 10
				for x in [HOLE_L - 6.0, HOLE_R + 2.0]:
					draw_rect(Rect2(x, floor_y - 14, 4, 14), pal.W)
					draw_rect(Rect2(x, floor_y - 14, 4, 1), pal.x)
				for x in [r.position.x + 16, r.position.x + 40, r.end.x - 40, r.end.x - 16]:
					draw_line(Vector2(x, floor_y - 12), Vector2(x + roundf(sin(tt * 2.0 + x) * 2.0), floor_y - 30), pal.v, 1.0)
			"sandstone":
				for x in [r.position.x + 26, r.end.x - 26]:
					draw_rect(Rect2(x - 4, top + 6, 8, r.size.y - 14), pal.W.lerp(pal.w, 0.4))
					draw_rect(Rect2(x - 4, top + 6, 2, r.size.y - 14), pal.x)
				# Dunes slumping toward the hole from both walls.
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, floor_y), Vector2(r.position.x, floor_y - 12),
					Vector2(r.position.x + 40, floor_y - 7), Vector2(HOLE_L - 1, floor_y - 1), Vector2(HOLE_L - 1, floor_y)]), pal.w)
				draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, floor_y), Vector2(r.end.x, floor_y - 9),
					Vector2(r.end.x - 34, floor_y - 6), Vector2(HOLE_R + 1, floor_y - 1), Vector2(HOLE_R + 1, floor_y)]), pal.w)
			"mossy":
				for x in [r.position.x + 30, r.end.x - 32]:
					draw_rect(Rect2(x, top + 10, 3, r.size.y - 10), Color8(92, 64, 40))
					draw_rect(Rect2(x - 8, top + 10, 19, 3), Color8(110, 78, 46))
				for k in 12:
					var x := roundf(r.position.x + 8 + k * (r.size.x - 16) / 11.0)
					if x > SHAFT_L - 4 and x < SHAFT_R + 2:
						continue
					draw_rect(Rect2(x, top, 3, 6 + (k * 7) % 14), pal.v)
					draw_rect(Rect2(x + 1, top, 1, 9 + (k * 7) % 14), Color8(52, 104, 46))
				# A minecart on its rail, off to the side.
				draw_rect(Rect2(r.position.x + 10, floor_y - 1, 50, 1), Color8(120, 110, 100))
				draw_rect(Rect2(r.position.x + 22, floor_y - 9, 16, 7), Color8(84, 70, 60))
				draw_rect(Rect2(r.position.x + 22, floor_y - 9, 16, 1), Color8(130, 112, 92))
				draw_rect(Rect2(r.position.x + 24, floor_y - 3, 3, 3), INK)
				draw_rect(Rect2(r.position.x + 33, floor_y - 3, 3, 3), INK)
			"dungeon":
				for x in [r.position.x + 30, r.end.x - 30]:
					_draw_wall_torch(Vector2(roundf(x), top + 50))

	## The Volcanic Vault behind the slime: lava pouring from vents in both walls into two pools held
	## off from the hole by rock lips, glowing cracks, basalt teeth and heat haze over the pools.
	func _draw_lava_back(pal: Dictionary, r: Rect2) -> void:
		var tt := 0.0 if screen.calm else t
		var floor_y := r.end.y
		var top := r.position.y
		var surface := floor_y - 9.0
		var pools := [[r.position.x + 3.0, SHAFT_L - 5.0], [SHAFT_R + 5.0, r.end.x - 3.0]]
		for pool in pools:
			var mid: float = (pool[0] + pool[1]) * 0.5
			_halo(self, Vector2(mid, surface), 46.0, FLAME_HOT, 0.06)
		# Basalt teeth from the ceiling, near the walls.
		for x in [r.position.x + 12, r.position.x + 24, r.end.x - 24, r.end.x - 12]:
			var h := 8.0 + int(x) % 7
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, top), Vector2(x + 3, top), Vector2(x, top + h)]), pal.W)
			draw_rect(Rect2(x - 1, top, 1, h - 3), pal.w)
		# Glowing seams in the back wall, just above the pools.
		for k in 4:
			var x: float = [r.position.x + 24, r.position.x + 40, r.end.x - 40, r.end.x - 24][k]
			var pts := PackedVector2Array([Vector2(x, surface - 1), Vector2(x + 2, surface - 7), Vector2(x - 1, surface - 13 - k * 2)])
			draw_polyline(pts, Color(pal.d, 0.7), 1.0)
		# Vents in the side walls and the lavafalls pouring out of them.
		for side in [0, 1]:
			var x := r.position.x + 9.0 if side == 0 else r.end.x - 13.0
			var vent_y: float = top + 22.0 + side * 8.0
			draw_rect(Rect2(x - 2, vent_y - 3, 7, 5), pal.k)
			draw_rect(Rect2(x - 2, vent_y - 4, 7, 1), pal.d)
			var fall_h: float = surface - vent_y
			draw_rect(Rect2(x - 1, vent_y, 5, fall_h), Color8(200, 70, 24))
			draw_rect(Rect2(x, vent_y, 3, fall_h), pal.d)
			draw_rect(Rect2(x + 1, vent_y, 1, fall_h), pal.B.lerp(pal.d, 0.4))
			for k in 6:
				var yy := fposmod(k * fall_h / 6.0 + tt * 70.0, fall_h)
				draw_rect(Rect2(x + (k % 2) * 2, vent_y + roundf(yy), 1, 3), pal.B)
			_halo(self, Vector2(x + 1, vent_y + fall_h * 0.5), 18.0, FLAME_HOT, 0.06)
			# The splash where it hits the pool.
			var splash := 0.0 if screen.calm else float(int(tt * 12.0) % 3)
			draw_rect(Rect2(x - 2 - splash, surface - 2, 7 + splash * 2, 2), pal.B)
		# Heat haze: thin wavering bands over the pools.
		for pool in pools:
			for k in 5:
				var yy := surface - 5.0 - k * 6.0
				var wave := 0.0 if screen.calm else roundf(sin(tt * 7.0 + k * 1.3) * 2.0)
				var x0: float = pool[0] + 4 + wave + (k % 2) * 6
				var span: float = pool[1] - pool[0] - 16
				draw_rect(Rect2(x0, yy, span * 0.5, 1), Color(pal.B, 0.14 + 0.05 * (k % 2)))
				draw_rect(Rect2(x0 + span * 0.5 + 3, yy + 1, span * 0.4, 1), Color(pal.B, 0.12))

	## The basalt lips' outlines, from the inner face's foot (x outward from the hole, y up):
	## left, then right (mirrored), each with its own broken top.
	const LAVA_LIP_L := [Vector2(0, 2), Vector2(0, -9), Vector2(1, -10), Vector2(2, -12), Vector2(4, -12), Vector2(6, -13),
		Vector2(8, -12), Vector2(9, -10), Vector2(9, 2)]
	const LAVA_LIP_R := [Vector2(0, 2), Vector2(0, -11), Vector2(1, -12), Vector2(3, -14), Vector2(5, -12), Vector2(7, -12),
		Vector2(8, -11), Vector2(9, -11), Vector2(9, 2)]

	## The pools themselves, the lips holding them and the crust around the hole, drawn over the slab.
	func _draw_lava_front(pal: Dictionary, r: Rect2) -> void:
		var tt := 0.0 if screen.calm else t
		var floor_y := r.end.y
		var surface := floor_y - 9.0
		var pools := [[r.position.x + 3.0, SHAFT_L - 5.0], [SHAFT_R + 5.0, r.end.x - 3.0]]
		for pool in pools:
			var x0: float = pool[0]
			var x1: float = pool[1]
			draw_rect(Rect2(x0, surface, x1 - x0, floor_y + 7 - surface), pal.d)
			draw_rect(Rect2(x0, surface + 5, x1 - x0, floor_y + 2 - surface - 5), Color8(200, 70, 24))
			draw_texture_rect(checker, Rect2(x0, surface + 4, x1 - x0, 2), true, Color8(200, 70, 24))
			draw_rect(Rect2(x0, floor_y + 7, x1 - x0, 1), pal.k)
			draw_rect(Rect2(x0, surface, x1 - x0, 1), pal.B)
			# Rolling bright ripples and dark crust skins drifting on top.
			for k in 4:
				var x := x0 + fposmod(k * 11.0 + tt * (8.0 + k * 3.0), x1 - x0 - 4)
				draw_rect(Rect2(roundf(x), surface + 1 + (k % 2), 4, 1), FLAME_TIP)
			for k in 2:
				var x := x0 + fposmod(k * 17.0 - tt * 5.0, x1 - x0 - 6)
				draw_rect(Rect2(roundf(x), surface + 2, 5, 1), Color8(120, 40, 20))
			# A bubble swelling and popping now and then.
			var b := fposmod(tt * 1.4 + x0 * 0.1, 1.0)
			if b > 0.6:
				var bx := roundf(x0 + (x1 - x0) * fposmod(x0 * 0.37 + floorf(tt * 1.4) * 0.61, 0.8) + 2)
				draw_rect(Rect2(bx, surface - 1, 3 if b < 0.9 else 1, 1), FLAME)
		# Rock lips walling the pools off from the hole: the slime drops between them. Each is a
		# stack of basalt blocks, glowing on the side facing its pool.
		# Their tops and inner faces are broken and uneven (LAVA_LIPS, mirrored for the right one).
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var inner := HOLE_L - 1.0 if side < 0 else HOLE_R + 1.0
			var x0 := inner - 9.0 if side < 0 else inner
			var lip: PackedVector2Array = lava_lips[k]
			draw_set_transform(Vector2(inner, floor_y))
			draw_colored_polygon(lip, pal.W)
			draw_polyline(lip.slice(1, 7), pal.w, 1.0)
			draw_set_transform(Vector2.ZERO)
			draw_rect(Rect2(x0 + 2, floor_y - 6, 6, 1), pal.z)
			var hot_x := x0 if side < 0 else x0 + 8.0
			draw_rect(Rect2(hot_x, floor_y - 10, 1, 12), FLAME_HOT)
			draw_rect(Rect2(hot_x + (1.0 if side < 0 else -1.0), floor_y - 10, 1, 12), Color(FLAME_HOT, 0.35))
			# The broken inner face, in shadow, with a chip knocked out of it.
			var cool_x := x0 + 8.0 if side < 0 else x0
			draw_rect(Rect2(cool_x, floor_y - 8, 1, 10), pal.k)
			draw_rect(Rect2(cool_x - side, floor_y - (5.0 if k == 0 else 7.0), 1, 2), pal.k)

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

	const SPLAT_HOLE := [Rect2(151, 13, 5, 1), Rect2(159, 13, 6, 1), Rect2(149, 14, 21, 1), Rect2(147, 15, 25, 1),
		Rect2(149, 16, 9, 1), Rect2(160, 16, 10, 1), Rect2(153, 17, 3, 1), Rect2(164, 17, 2, 1)]

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
		for rect: Rect2 in SPLAT_HOLE:  # the hole far above, its crumbled edge against the light
			draw_rect(rect, Color8(210, 222, 240))
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
		for rect: Rect2 in SPLAT_HOLE:  # the hole far above, its crumbled edge against the light
			draw_rect(rect, Color8(210, 222, 240))
		# The puddle they found.
		draw_rect(Rect2(156, 119, 18, 2), goo.dark)
		draw_rect(Rect2(158, 118, 13, 2), goo.mid)
		draw_rect(Rect2(161, 118, 3, 1), goo.highlight)
		# Just goo: a faint wet shimmer creeping along it (no treasure here).
		var sx := 159.0 + (3.0 if screen.calm else roundf(fposmod(t * 5.0, 12.0)))
		draw_rect(Rect2(sx, 119, 2, 1), Color(goo.light, 0.5))
		for hero in heroes:
			var f := Vector2(hero.foot.x, 120)  # on the floor, even mid-stomp
			draw_colored_polygon(PackedVector2Array([f + Vector2(-4, 1), f + Vector2(4, 1), f + Vector2(-30, 8), f + Vector2(-46, 8)]), Color(INK, 0.4))
		for hero in heroes:
			_draw_hero_with_light(hero)
