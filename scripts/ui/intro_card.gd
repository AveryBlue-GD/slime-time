class_name IntroCard
extends Control

## IMP2-01: the 1.8 s launch card, an overlay state of the title (title.gd adds it on every cold launch except the
## first-ever one, where the story intro plays; never when coming back to the title from the hub). Its first
## frame is the boot splash (assets/ui/boot_splash.png, tools/make_splash.py) pixel for pixel, after a 0.15 s fade
## from the boot colour; then the slime blinks, squashes and leaps, its goo trail paints itself and the fog peels
## back along it, the logo's drips grow and one fat drop splats, and the light pocket widens into the title (its
## UI fading in). Any key / click / tap / pad button skips it after 0.15 s; that input is consumed (it never
## presses ENTER THE HUB). MOTION: LESS is a 0.4 s plain fade from the splash frame. Skipped in headless runs,
## tests, --story, --autoplay and screenshot runs (`--intro-card[=SECONDS]` captures a frozen frame of it).

signal finished

const DURATION := 1.8
const STILL_DURATION := 0.4
const SKIP_AFTER := 0.15
const FADE_IN := 0.15
const SPLASH := "res://assets/ui/boot_splash.png"
const WORLD := "res://assets/ui/intro_card_world.png"
const SLIME_SHEET := "res://assets/sprites/slime_sheet.png"
const LOGO := "res://assets/sprites/title/logo_00.png"
const FOG_SHADER := "res://assets/shaders/intro_fog.gdshader"
## Layout shared with tools/make_splash.py (the splash's own constants).
const LOGO_POS := Vector2(8, 12)
const LOGO_STUB_ROWS := 54
const LOGO_ROWS := 64
const SLIME_POS := Vector2(84, 114)
const LAND_POS := Vector2(156, 114)
const POCKET_CENTER := Vector2(96, 146)
const POCKET_RADIUS := 54.0
const SCREEN := Vector2(320, 180)
const GROUND_Y := 154.0
const FOG := Color8(26, 28, 44)
const GOO := Color8(37, 113, 121)
const GOO_LIGHT := Color8(56, 183, 100)
const GOO_HIGH := Color8(214, 250, 186)
const GOO_DEEP := Color8(22, 66, 82)

## Tests only: ignore the headless / test / screenshot skips (the first-launch and cold-launch rules still apply).
static var force := false

var time := 0.0
## True while it runs; false once finished or skipped.
var running := true
var still := false
## Screenshot runs (`--intro-card=T`): the card stops advancing at T seconds so a mid-card frame can be captured.
var freeze_at := -1.0
## Sets the alpha of the title's own UI (everything above the backdrop), 0..1.
var _set_ui_alpha := Callable()
var _fog: ColorRect
var _art: Control
var _veil: ColorRect
var _world: Texture2D
var _splash: Texture2D
var _sheet: Texture2D
var _logo: Texture2D
var _drop_x := 150.0
var _skipped := false


## Whether the card plays. `cold`: this title is the one the game booted into, not preceded by the first-launch
## intro (Story.launched false before it). The first-ever launch of a save (the story intro is due) never gets it.
static func due(cold: bool, progress: Node) -> bool:
	if not Economy.INTRO_CARD or not cold:
		return false
	if progress != null and Story.intro_due(progress):
		return false
	return force or not env_skips()


## Tests, tools, headless, movie / screenshot capture and the --story / --autoplay / --tutorial flags never play it.
static func env_skips() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if capture_seconds() >= 0.0:
		return false  # the screenshot tool asked for a frame of it
	if OS.has_feature("movie"):
		return true  # --write-movie: the screenshot tool and the promo renders
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--write-movie") or arg.begins_with("res://tests/") or arg.begins_with("res://tools/") \
				or arg == "-s" or arg == "--script" or arg.ends_with(".gd"):
			return true
	var args := OS.get_cmdline_user_args()  # (no autoload names here: tests load this class before the autoloads exist)
	for arg in args:
		if arg == "--story-complete" or arg.begins_with("--tutorial"):
			return true
	return Autoplay.requested(args)


## `--intro-card` (0.9 s) or `--intro-card=SECONDS`: the screenshot tool's flag, plays the card frozen at that time;
## -1 when absent. (A debug flag: release builds never read it.)
static func capture_seconds() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg == "--intro-card":
			return 0.9
		if arg.begins_with("--intro-card="):
			return float(arg.trim_prefix("--intro-card="))
	return -1.0


## `set_ui_alpha(a)` fades the title's own UI; `reduce_motion` picks the plain fade.
func setup(set_ui_alpha: Callable, reduce_motion: bool) -> void:
	_set_ui_alpha = set_ui_alpha
	still = reduce_motion
	name = "IntroCard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks while it runs never reach the buttons under it
	_world = load(WORLD)
	_splash = load(SPLASH)
	_sheet = load(SLIME_SHEET)
	_logo = load(LOGO)
	_fog = ColorRect.new()
	_fog.color = FOG
	_fog.size = SCREEN
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(FOG_SHADER)
	_fog.material = material
	add_child(_fog)
	_art = Control.new()
	_art.size = SCREEN
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_paint)
	add_child(_art)
	_veil = ColorRect.new()
	_veil.color = FOG
	_veil.size = SCREEN
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	# The fat drop falls from the logo's longest drip (the lowest ink row of the art).
	var image := _logo.get_image()
	for x in image.get_width():
		if image.get_pixel(x, LOGO_ROWS - 2).a > 0.5:
			_drop_x = LOGO_POS.x + x
			break
	freeze_at = capture_seconds()
	_apply()
	var music := get_node_or_null("/root/Music")
	if music:
		music.play_sting()


func duration() -> float:
	return STILL_DURATION if still else DURATION


func _process(delta: float) -> void:
	if not running:
		return
	if freeze_at >= 0.0 and time >= freeze_at:
		return
	time += delta
	if freeze_at >= 0.0:
		time = minf(time, freeze_at)
	if time >= duration():
		_finish(false)
		return
	_apply()


## Any key / click / tap / pad button after SKIP_AFTER skips the card; the event is consumed here (before the
## buttons see it), so it never presses ENTER THE HUB.
func _input(event: InputEvent) -> void:
	if not running or not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	if time >= SKIP_AFTER:
		_finish(true)


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)


func _finish(skipped: bool) -> void:
	if not running:
		return
	running = false
	_skipped = skipped
	if _set_ui_alpha.is_valid():
		_set_ui_alpha.call(1.0)
	var music := get_node_or_null("/root/Music")
	if music and skipped:
		music.skip_sting()
	finished.emit()
	# Freed a frame later: the input that skipped it is already consumed and nothing can reach the buttons first.
	queue_free.call_deferred()


func was_skipped() -> bool:
	return _skipped


## Everything is a function of `time`: the veil, the fog hole, the art and the title's UI alpha.
func _apply() -> void:
	var t := time
	var ui := 0.0
	var radius := 0.0
	var center := POCKET_CENTER
	if still:
		ui = clampf(t / STILL_DURATION, 0.0, 1.0)
		_veil.color.a = 0.0
	else:
		_veil.color.a = clampf(1.0 - t / FADE_IN, 0.0, 1.0)
		ui = clampf((t - 1.4) / 0.4, 0.0, 1.0)
		var slime := _slime_pos()
		if t < 1.3:
			center = slime + Vector2(20, 24)
			radius = 44.0 * smoothstep(0.62, 1.15, t)
		else:
			center = center.lerp(Vector2(160, 100), smoothstep(1.3, 1.8, t))
			radius = lerpf(44.0, 230.0, smoothstep(1.3, 1.8, t))
	var material := _fog.material as ShaderMaterial
	material.set_shader_parameter("center", center)
	material.set_shader_parameter("radius", radius)
	if _set_ui_alpha.is_valid():
		_set_ui_alpha.call(ui)
	_art.queue_redraw()


## The slime's top-left corner: at rest, then the leap's parabola (0.70 .. 1.15 s).
func _slime_pos() -> Vector2:
	var u := clampf((time - 0.70) / 0.45, 0.0, 1.0)
	var pos := SLIME_POS.lerp(LAND_POS, u)
	pos.y -= 50.0 * 4.0 * u * (1.0 - u)
	return Vector2(roundf(pos.x), roundf(pos.y))


## The slime sheet's frame for this moment: [row, column] (rows: 0 idle, 2 charge, 3 launch, 4 air, 5 land).
func _slime_frame() -> Vector2i:
	var t := time
	if t < 0.20:
		return Vector2i(0, 1)
	if t < 0.32:
		return Vector2i(0, 3)  # the blink: eyes closed
	if t < 0.45:
		return Vector2i(0, 1)
	if t < 0.70:
		return Vector2i(2, mini(3, int((t - 0.45) / 0.25 * 4.0)))  # squash down
	if t < 0.78:
		return Vector2i(3, int((t - 0.70) / 0.04) % 2)  # launch
	if t < 1.15:
		return Vector2i(4, mini(3, int((t - 0.78) / 0.37 * 4.0)))  # air
	if t < 1.35:
		return Vector2i(5, mini(3, int((t - 1.15) / 0.05)))  # land
	return Vector2i(0, 0 if int((t - 1.35) * 4.0) % 2 == 0 else 1)


func _paint() -> void:
	var t := time
	if still:
		_art.draw_texture(_splash, Vector2.ZERO, Color(1, 1, 1, 1.0 - clampf(t / STILL_DURATION, 0.0, 1.0)))
		return
	var fade := 1.0 - clampf((t - 1.4) / 0.4, 0.0, 1.0)  # the card's art hands over to the title's own
	var world_a := 1.0 - smoothstep(1.1, 1.5, t)
	_art.draw_texture(_world, Vector2.ZERO, Color(1, 1, 1, world_a))
	# The goo trail paints itself ahead of the leaping slime (same ribbon as the splash's, thickest part).
	if t >= 0.70:
		var head := mini(int(_slime_pos().x) + 16, 190)
		for x in range(100, head):
			var yc := 151 + roundi(3.2 * sin((x - 30) / 8.5))
			_art.draw_rect(Rect2(x, yc - 3, 1, 1), GOO_LIGHT if (x / 3) % 2 == 0 else GOO_HIGH)
			_art.draw_rect(Rect2(x, yc - 2, 1, 5), GOO)
			_art.draw_rect(Rect2(x, yc + 3, 1, 1), GOO_DEEP)
	# The slime, 2x.
	var frame := _slime_frame()
	var pos := _slime_pos()
	_art.draw_texture_rect_region(_sheet, Rect2(pos, Vector2(40, 40)), Rect2(frame.y * 20, frame.x * 20, 20, 20),
		Color(1, 1, 1, fade))
	# The logo: letters and drip stubs, the drips growing downward (0.85 .. 1.15 s).
	var grow := smoothstep(0.85, 1.15, t)
	var rows := roundi(lerpf(LOGO_STUB_ROWS, LOGO_ROWS, grow))
	_art.draw_texture_rect_region(_logo, Rect2(LOGO_POS, Vector2(_logo.get_width(), rows)),
		Rect2(0, 0, _logo.get_width(), rows), Color(1, 1, 1, fade))
	# One fat drop leaves the longest drip at 1.0 s, falls and splats on the ground.
	var fall := t - 1.0
	if fall > 0.0:
		var start_y := LOGO_POS.y + LOGO_ROWS
		var y := start_y + 0.5 * 780.0 * fall * fall
		if y < GROUND_Y:
			_art.draw_rect(Rect2(_drop_x - 1, y, 3, 4), GOO_LIGHT)
			_art.draw_rect(Rect2(_drop_x - 1, y, 1, 2), GOO_HIGH)
		else:
			var s := clampf((t - (1.0 + sqrt(2.0 * (GROUND_Y - start_y) / 780.0))) / 0.35, 0.0, 1.0)
			var a := 1.0 - s
			for i in 4:
				var dx := (2.0 + 9.0 * s) * (1 if i % 2 == 0 else -1) * (0.55 + 0.45 * (i / 2))
				var up := 5.0 * sin(PI * s) * (0.6 + 0.4 * (i / 2))
				_art.draw_rect(Rect2(_drop_x + dx, GROUND_Y - up, 2, 2), Color(GOO_LIGHT, a))
			_art.draw_rect(Rect2(_drop_x - 4 - 4 * s, GROUND_Y, 9 + 8 * s, 1), Color(GOO, a))
