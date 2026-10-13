extends Control

## The story cards (see Story and docs/story.md): the intro (a fresh save's first PLAY, or the
## title's STORY button) and the finale (after level 10). Each card is a small pixel-art panel
## drawn from rects plus the slime's own sprite, with one or two lines under it. Any key, click or
## tap goes to the next card, Esc skips the lot. Reduce Motion draws every panel as a still.

const STAGE := Rect2(16, 10, 288, 92)
const TEXT_TOP := 108
const HINT_TOP := 164
## Input is ignored for this long after a card appears, so a held key can't skip it.
const GRACE := 0.25
const FLOOR_Y := 72.0
const SILHOUETTE := Color(0.04, 0.04, 0.08)
const FLAME := Color8(255, 205, 117)
const FLAME_HOT := Color8(239, 125, 47)

var mode := "intro"
var next_scene := ""
var cards: Array[Dictionary] = []
var index := 0
var finished := false
var calm := false

var art: StageArt
var text_label: Label
var hint_label: Label
var slime: AnimatedSprite2D
var _age := 0.0
var _next_calls := 0


func _ready() -> void:
	mode = Story.mode
	next_scene = Story.next_scene
	Story.mode = "intro"
	Story.next_scene = ""
	calm = Progress.reduce_motion
	cards = Story.cards(mode)
	UIKit.setup_screen(self, "")
	art = StageArt.new()
	art.screen = self
	art.position = STAGE.position
	art.size = STAGE.size
	art.clip_contents = true
	add_child(art)
	text_label = UIKit.make_label("", 8, UIKit.TEXT)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_constant_override("line_spacing", UIKit.LINE_SPACING)
	add_child(text_label)
	text_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	text_label.offset_top = TEXT_TOP
	text_label.offset_bottom = TEXT_TOP + 28
	hint_label = UIKit.make_label("", 8, UIKit.TEXT_OFF)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = HINT_TOP
	hint_label.offset_bottom = HINT_TOP + 10
	show_card(0)


func show_card(i: int) -> void:
	index = i
	_age = 0.0
	var card: Dictionary = cards[i]
	if slime:
		slime.queue_free()
		slime = null
	slime = UIKit.make_slime_preview(Progress.skin_color(), 1, Progress.is_rainbow(), null, Progress.is_stopwatch())
	art.add_child(slime)
	art.card = card.art
	text_label.text = "\n".join(card.lines)
	var last := i == cards.size() - 1
	hint_label.text = "%d/%d   ANY KEY: %s   ESC: SKIP" % [i + 1, cards.size(), "DONE" if last else "NEXT"]
	art.setup_slime()


## Next card, or the end of the sequence after the last one.
func advance() -> void:
	if finished:
		return
	if index + 1 < cards.size():
		show_card(index + 1)
	else:
		finish()


## Marks the sequence as seen and moves on (the next scene, or the title).
func finish() -> void:
	if finished:
		return
	finished = true
	Progress.mark_story_seen(Progress.STORY_FINALE if mode == "finale" else Progress.STORY_INTRO)
	var target := next_scene if next_scene != "" else (UIKit.TITLE_SCENE if mode == "intro" else "res://scenes/victory.tscn")
	UIKit.go(get_tree(), target)


func _process(delta: float) -> void:
	_age += delta


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


## The panel's picture, redrawn every frame from the card's art id and the card's age.
class StageArt extends Control:
	var screen: Control
	var card := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		_place_slime()
		queue_redraw()

	func _t() -> float:
		return 0.0 if screen.calm else screen._age

	## Where the card's slime is, and which animation it plays.
	func setup_slime() -> void:
		var s: AnimatedSprite2D = screen.slime
		s.visible = true
		var anim := {run = "glide_e", chase = "idle", crack = "idle", fall = "air_s", splat = "splat_s", daylight = "celebrate", search = "idle"}.get(card, "idle") as String
		s.play(anim)
		s.sprite_frames.set_animation_loop("splat_s", false)
		if screen.calm:
			s.pause()
			s.frame = 3 if anim == "splat_s" else 1
		if card == "search":
			s.visible = false  # only a puddle is left
		_place_slime()

	func _place_slime() -> void:
		var s: AnimatedSprite2D = screen.slime
		if s == null:
			return
		var t := _t()
		match card:
			"run":
				s.position = Vector2(206, FLOOR_Y - 8 + (0.0 if screen.calm else roundf(sin(t * 12.0)) * 1.0))
			"chase":
				s.position = Vector2(236, FLOOR_Y - 8)
			"crack":
				s.position = Vector2(144 + (0.0 if screen.calm else roundf(sin(t * 40.0) * clampf(t * 0.8, 0.0, 1.5))), FLOOR_Y - 8)
			"fall":
				s.position = Vector2(144, 44 + (0.0 if screen.calm else roundf(sin(t * 5.0) * 4.0)))
			"splat":
				s.position = Vector2(144, FLOOR_Y - 8)
				s.scale = Vector2(1, 1)
			"daylight":
				s.position = Vector2(144, 56 - (0.0 if screen.calm else absf(sin(t * 4.0)) * 14.0))
			_:
				s.position = Vector2(144, FLOOR_Y - 8)

	func _draw() -> void:
		var t := _t()
		var theme_colors := Themes.fog_colors("crystal")
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.15, 0.27))
		match card:
			"run":
				_floor(t)
				for i in 3:
					_adventurer(Vector2(34 + i * 34, FLOOR_Y), 1.0, t + i * 0.3, true)
				_torch_light(Vector2(60, 40), 60.0)
			"chase":
				_floor(0.0)
				_adventurer(Vector2(54, FLOOR_Y + 6), 2.0, t, true)
				_adventurer(Vector2(112, FLOOR_Y + 6), 2.0, t + 0.4, true)
				_torch_light(Vector2(84, 30), 80.0)
				if screen.calm or fmod(t, 0.8) < 0.5:  # the slime's alarm
					draw_rect(Rect2(235, 36, 2, 7), UIKit.GOLD)
					draw_rect(Rect2(235, 45, 2, 2), UIKit.GOLD)
			"crack":
				_slab(FLOOR_Y, size.y - FLOOR_Y)
				var p := 1.0 if screen.calm else clampf(t / 1.6, 0.0, 1.0)
				_cracks(p)
			"fall":
				var tint_a: Color = theme_colors[1]
				var offset := 0.0 if screen.calm else fposmod(t * 90.0, 46.0)
				for i in 4:
					var y := -10.0 + i * 46.0 - offset + 46.0
					var shade := tint_a.lerp(Color8(120, 100, 140), 0.25 * i)
					draw_rect(Rect2(0, y, 112, 6), shade)
					draw_rect(Rect2(176, y, 112, 6), shade)
					draw_rect(Rect2(0, y, 112, 1), shade.lightened(0.3))
					draw_rect(Rect2(176, y, 112, 1), shade.lightened(0.3))
				for i in 6:
					if screen.calm:
						break
					var x := 132.0 + i * 5.0 + fmod(i * 7.0, 3.0)
					draw_rect(Rect2(x, fposmod(t * 160.0 + i * 31.0, 100.0) - 8.0, 1, 9), Color(1, 1, 1, 0.18))
			"splat":
				_slab(FLOOR_Y + 8, size.y)
				var hit: float = 0.0 if screen.calm else t
				var goo: Color = Skins.shades(Progress.skin_color()).mid
				goo.a = 0.7
				draw_rect(Rect2(122, FLOOR_Y + 5, 44, 3), goo)
				draw_rect(Rect2(110, FLOOR_Y + 6, 8, 2), goo)
				draw_rect(Rect2(172, FLOOR_Y + 6, 6, 2), goo)
				draw_rect(Rect2(140, 1, 8, 2), Color(1, 0.95, 0.75, 0.9))  # far above: the hole it fell from
				for i in 3:
					var a := hit * 4.0 + i * TAU / 3.0
					draw_rect(Rect2(144 + roundf(cos(a) * 14.0), 30 + roundf(sin(a) * 4.0), 2, 2), UIKit.GOLD)
				if hit < 0.25 and not screen.calm:
					draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.8 * (1.0 - hit / 0.25)))
			"daylight":
				for i in 6:
					draw_rect(Rect2(0, i * 16, size.x, 16), Color8(70 + i * 20, 130 + i * 15, 200 + i * 8))
				draw_rect(Rect2(40, 14, 12, 12), Color8(255, 240, 160))
				draw_rect(Rect2(38, 16, 16, 8), Color8(255, 240, 160, 90))
				draw_colored_polygon(PackedVector2Array([Vector2(0, 92), Vector2(0, 66), Vector2(100, 78), Vector2(124, 92)]), Color8(60, 40, 44))
				draw_colored_polygon(PackedVector2Array([Vector2(288, 92), Vector2(288, 66), Vector2(188, 78), Vector2(164, 92)]), Color8(60, 40, 44))
				draw_colored_polygon(PackedVector2Array([Vector2(124, 92), Vector2(100, 78), Vector2(112, 76), Vector2(144, 88), Vector2(176, 76), Vector2(188, 78), Vector2(164, 92)]), Color8(150, 60, 40))
			"search":
				draw_rect(Rect2(0, FLOOR_Y, size.x, 20), Color(0.12, 0.1, 0.15))
				var goo: Color = Skins.shades(Progress.skin_color()).mid
				draw_rect(Rect2(138, FLOOR_Y - 2, 14, 3), goo)
				draw_rect(Rect2(144, FLOOR_Y - 3, 4, 1), goo.lightened(0.4))
				for i in 3:
					_adventurer(Vector2(40 + i * 28 if i < 2 else 214, FLOOR_Y), 1.0, 0.0, true, true)
				_torch_light(Vector2(70, 50), 70.0)
		_frame()

	func _frame() -> void:
		draw_rect(Rect2(0, 0, size.x, 1), UIKit.TEXT_OFF)
		draw_rect(Rect2(0, size.y - 1, size.x, 1), UIKit.TEXT_OFF)
		draw_rect(Rect2(0, 0, 1, size.y), UIKit.TEXT_OFF)
		draw_rect(Rect2(size.x - 1, 0, 1, size.y), UIKit.TEXT_OFF)

	func _slab(top: float, height: float) -> void:
		draw_rect(Rect2(0, top, size.x, height), Color8(58, 49, 71))
		draw_rect(Rect2(0, top, size.x, 1), Color8(120, 106, 134))
		for i in 8:
			draw_rect(Rect2(i * 40 + (top as int) % 16, top + 8, 20, 1), Color8(37, 34, 50))

	func _floor(t: float) -> void:
		_slab(FLOOR_Y, size.y - FLOOR_Y)
		for i in 10:
			var x := fposmod(i * 30.0 - t * 70.0, size.x + 20.0) - 10.0
			draw_rect(Rect2(roundf(x), FLOOR_Y + 12 + (i % 3) * 4, 6, 1), Color8(86, 80, 100))

	func _cracks(p: float) -> void:
		var points := [Vector2(144, FLOOR_Y), Vector2(138, FLOOR_Y + 5), Vector2(142, FLOOR_Y + 9), Vector2(130, FLOOR_Y + 14), Vector2(124, FLOOR_Y + 19)]
		var points_r := [Vector2(144, FLOOR_Y), Vector2(151, FLOOR_Y + 4), Vector2(148, FLOOR_Y + 10), Vector2(162, FLOOR_Y + 14), Vector2(170, FLOOR_Y + 19)]
		for line in [points, points_r]:
			var reach: float = p * (line.size() - 1)
			for i in line.size() - 1:
				if reach <= i:
					break
				var seg_p := minf(reach - i, 1.0)
				var a: Vector2 = line[i]
				var b: Vector2 = a.lerp(line[i + 1], seg_p)
				draw_line(a.round(), b.round(), SILHOUETTE, 1.0)
		if p >= 1.0:
			draw_rect(Rect2(122, FLOOR_Y + 1, 46, 1), SILHOUETTE)

	## A silhouette: legs, body, head, a sword, and a torch held up (flame flickers).
	func _adventurer(foot: Vector2, scale: float, t: float, torch: bool, stooped := false) -> void:
		draw_set_transform(foot, 0.0, Vector2(scale, scale))
		var stride := 1 if int(t * 8.0) % 2 == 0 else 0
		var lean := 2.0 if stooped else 0.0
		draw_rect(Rect2(-3, -6, 2, 6 - stride), SILHOUETTE)
		draw_rect(Rect2(1, -6, 2, 5 + stride), SILHOUETTE)
		draw_rect(Rect2(-4 + lean, -15, 8, 9), SILHOUETTE)
		draw_rect(Rect2(-3 + lean * 1.5, -20, 6, 5), SILHOUETTE)
		draw_rect(Rect2(-4 + lean * 1.5, -22, 8, 2), SILHOUETTE)  # a helmet
		draw_rect(Rect2(-7, -17, 1, 9), SILHOUETTE)  # a sword
		draw_rect(Rect2(-8, -17, 3, 1), SILHOUETTE)
		if torch:
			draw_rect(Rect2(5 + lean, -25, 1, 9), SILHOUETTE)
			var flick := int(Time.get_ticks_msec() / 120) % 2 if not screen.calm else 0
			draw_rect(Rect2(4 + lean, -29 - flick, 3, 4 + flick), FLAME_HOT)
			draw_rect(Rect2(5 + lean, -28 - flick, 1, 2), FLAME)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A banded warm halo (hard-edged rings, like the game's own lights).
	func _torch_light(center: Vector2, radius: float) -> void:
		for i in 3:
			draw_circle(center, radius * (1.0 - i * 0.3), Color(1.0, 0.6, 0.25, 0.05))
