class_name Hat
extends Sprite2D

## A hat on a slime. It's drawn to fit round the slime's dome (not just perched on it), and as the
## slime squashes and stretches it swaps to the matching width (Hats.width_for(Slime.head_width)).
## When the slime leaps, the hat pops off and arcs up and back down onto its head (a hovering
## one, the raincloud, just keeps raining on it all the way). A small hop (a flight under SMALL_HOP,
## the shortest leaps) only lifts it a pixel or two off the head and sets it back down just after
## the slime lands, still fitted to the head (owner, 2026-10-21: it used to fly 3x as long as the hop
## and hang in the air between quick hops). Along the floor
## it goes wherever the slime really goes (not where the leap was aimed), so when the slime bonks a
## wall, bounces back or gets stuck, the hat stays in line over it: a bonk just jolts it a few px
## on (it keeps a little of the speed the slime lost), springing back while it falls.
##
## Works for the slime in a level and for menu previews. Positions are split into `ground` (where
## it is on the floor plan) and `height` (how far above the floor), so the arc reads correctly in
## the top-down view.

enum State { ON, FLYING }

## Strong enough that even a short hop flicks the hat up visibly and a full leap sends it high.
const GRAVITY := 1000.0
## Even the smallest leap that pops it off sends the hat up for at least this long.
const MIN_FLIGHT := 0.25
## Leaps shorter than this (seconds in the air: about 2 tiles) are small hops: the hat stays on and
## only lifts HOP_LIFT px off the head (more for a longer hop, at most HOP_LIFT_MAX), landing HOP_LAG
## after the slime does.
const SMALL_HOP := 0.15
const HOP_LIFT := 1.0
const HOP_LIFT_MAX := 2.0
const HOP_LAG := 0.05
## A bonk: share of the speed the slime suddenly lost that jolts the hat on (px per px/s), the
## most it can be thrown off line, and how fast it springs back over the slime.
const JOLT := 0.03
const MAX_JOLT := 5.0
const JOLT_SPRING := 9.0

## The slime's sprite (the hat sits on top of its current frame) and the node marking where the
## slime is on the floor (the slime itself in a level; the sprite in a menu preview).
var body: AnimatedSprite2D
var anchor: Node2D
var state := State.ON
var ground := Vector2.ZERO
var height := 0.0
var lift := 0.0
var hat_id := Hats.NONE
## The dye it's drawn in ("": its own color; Hats.dyes_for).
var dye := ""
## How far the hat is thrown off line from the slime by a bonk (springs back to zero).
var jolt := Vector2.ZERO
var _slime_last := Vector2.ZERO
var _slime_velocity := Vector2.ZERO
## The height when this physics tick began (drawn between ticks when interpolating).
var _height_from := 0.0
## An animated hat's clock, in frames (Hats.frames, Hats.fps): `anim_frame` is the one shown.
var _anim_time := 0.0
var anim_frame := 0
## A small hop's lift: time into it, its length and its height (px; 0 = none).
var _hop_t := 0.0
var _hop_len := 0.0
var _hop_px := 0.0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # it places itself every frame


## Puts hat `hat_id` on the given slime sprite, in dye `dye_id` ("": its own color; the player's
## hat wears Progress.hat_dye_of).
func setup(id: String, slime_body: AnimatedSprite2D, slime_anchor: Node2D = null, dye_id := "") -> void:
	hat_id = id
	dye = dye_id if dye_id in Hats.dyes_for(id) else ""
	body = slime_body
	anchor = slime_anchor if slime_anchor else slime_body
	texture = Hats.texture_for(hat_id, dye)
	region_enabled = true
	region_rect = Hats.dye_region(hat_id, dye)
	material = Hats.material_for(hat_id, dye)
	centered = false
	offset = -Hats.HEAD  # the frame's head point goes on the top of the slime's head
	_follow()


## Pops the hat off with the slime's leap: `slime_velocity` is how fast the slime moves along the
## floor and `flight_time` how long it will be in the air, so the hat comes down onto it.
func pop(slime_velocity: Vector2, flight_time: float) -> void:
	if Hats.get_hat(hat_id).get("hovers", false):
		return  # a hovering hat (the raincloud) isn't knocked off: it rides along over the head
	if flight_time < SMALL_HOP and state == State.ON:
		# A small hop: it barely lifts off and settles back just after the slime lands.
		_hop_t = 0.0
		_hop_len = flight_time + HOP_LAG
		_hop_px = clampf(HOP_LIFT + flight_time / SMALL_HOP, HOP_LIFT, HOP_LIFT_MAX)
		return
	_hop_len = 0.0
	ground = _floor_point()
	if state != State.FLYING:  # (popped again mid-flight: it carries on from where it is, no snap)
		height = _head_height()
	region_rect = Hats.dye_region(hat_id, dye, Hats.Width.LOOSE, anim_frame)  # off the head it keeps its own shape
	_slime_last = ground
	_slime_velocity = slime_velocity
	_height_from = height
	jolt = Vector2.ZERO
	var time := maxf(flight_time * 0.95, MIN_FLIGHT)
	lift = GRAVITY * time / 2.0
	state = State.FLYING


## The flight is simulated on physics ticks, when the slime itself moves: measured per render frame,
## the slime's speed would read 0 on frames without a tick and 2-4x on frames after one (any display
## above 60 Hz), and the jolt would flicker the hat by a few px every frame of a leap. The drawing
## follows per frame.
func _physics_process(delta: float) -> void:
	if state == State.FLYING:
		_height_from = height
		_fly(delta)


func _process(delta: float) -> void:
	_animate(delta)
	if _hop_len > 0.0:
		_hop_t += delta
		if _hop_t >= _hop_len:
			_hop_len = 0.0
	match state:
		State.ON:
			_follow()
		State.FLYING:
			region_rect = Hats.dye_region(hat_id, dye, Hats.Width.LOOSE, anim_frame)
			var drawn_height := height
			var slime := anchor as Slime
			if slime and slime.is_physics_interpolated_and_enabled():
				drawn_height = lerpf(_height_from, height, Engine.get_physics_interpolation_fraction())
			_place(_snap(ground + _drawn_shift(false) - Vector2(0.0, drawn_height)))


## Steps an animated hat on (the propeller cap spins, the raincloud rains): at its own pace, faster
## while the slime glides or winds up a leap and fastest flying off it. It holds its still frame
## on a paused slime (a locked wardrobe tile's silhouette) and in frozen reviewer captures.
func _animate(delta: float) -> void:
	var n := Hats.frames(hat_id)
	if n <= 1:
		return
	if Hats.frozen_flow_step >= 0 or (body and not body.is_playing()):
		_anim_time = 0.0
		anim_frame = 0
		return
	var moving := body != null and (body.animation.begins_with("glide") or body.animation.begins_with("charge"))
	_anim_time = fmod(_anim_time + delta * Hats.fps(hat_id, moving, state == State.FLYING), float(n))
	anim_frame = int(_anim_time) % n


func _follow() -> void:
	# Squashed slime, wider hat; stretched slime, narrower and taller. Lifted a px or two in the
	# few frames whose eyes sit high, so it never covers them.
	var width := Hats.width_for(Slime.head_width(body.animation, body.frame))
	region_rect = Hats.dye_region(hat_id, dye, width, anim_frame)
	var lift_px := Hats.lift(hat_id, width, body.animation, body.frame) + _hop_lift()
	var mat := material as ShaderMaterial
	if mat and mat.get_shader_parameter("gradient"):  # (the RAINBOW dye's gradient lines up with a rainbow slime's)
		var head := Slime.head_point(body.animation, body.frame) - Vector2(0, lift_px)
		if mat.get_shader_parameter("head_offset") != head:
			mat.set_shader_parameter("head_offset", head)
	_place(_snap(_head() + _drawn_shift(true) - Vector2(0, lift_px) * body.global_scale))


## A small hop's lift right now (whole px; 0 when not hopping).
func _hop_lift() -> int:
	if _hop_len <= 0.0:
		return 0
	return roundi(sin(PI * clampf(_hop_t / _hop_len, 0.0, 1.0)) * _hop_px)


## How far from its physics position a slime anchor is drawn this frame (Slime.drawn_shift: only
## with physics interpolation on; `with_sprite` = its jump arc too). Zero for menu previews.
func _drawn_shift(with_sprite: bool) -> Vector2:
	var slime := anchor as Slime
	return slime.drawn_shift(with_sprite) if slime else Vector2.ZERO


## Puts the hat at `drawn` on screen. A hat that is the slime's own child (the hub) is already
## carried along by the slime's interpolation, so that share comes off.
func _place(drawn: Vector2) -> void:
	var parent := get_parent() as Slime
	global_position = drawn - (parent.drawn_shift(false) if parent and parent == anchor else Vector2.ZERO)


func _fly(delta: float) -> void:
	# Predict from where the slime really is: its speed this tick against last tick's. A sudden
	# drop (a bonk, a bounce back) throws the hat on a little, in line with the slime.
	var slime_at := _floor_point()
	if delta > 0.0:
		var now_velocity := (slime_at - _slime_last) / delta
		jolt += (_slime_velocity - now_velocity) * JOLT
		jolt = jolt.limit_length(MAX_JOLT)
		_slime_velocity = now_velocity
	_slime_last = slime_at
	jolt *= exp(-JOLT_SPRING * delta)
	ground = slime_at + jolt
	lift -= GRAVITY * delta
	height += lift * delta
	if lift < 0.0 and height <= _head_height() + 1.0:
		state = State.ON  # back on the slime's head
		_follow()


## Whole pixels, rounded the way the renderer snaps the slime's sprite (half up), so the hat never
## lands a pixel off it.
static func _snap(at: Vector2) -> Vector2:
	return (at + Vector2(0.5, 0.5)).floor()


## Top-center of the slime's body right now (follows its squash, stretch and jump arc).
func _head() -> Vector2:
	return body.global_position + Slime.head_point(body.animation, body.frame) * body.global_scale


func _floor_point() -> Vector2:
	return anchor.global_position


## How high the top of the slime's head is above the floor.
func _head_height() -> float:
	return _floor_point().y - _head().y
