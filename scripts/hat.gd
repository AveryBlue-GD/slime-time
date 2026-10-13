class_name Hat
extends Sprite2D

## A hat on a slime. It's drawn to fit round the slime's dome (not just perched on it), and as the
## slime squashes and stretches it swaps to the matching width (Hats.width_for(Slime.head_width)).
## When the slime leaps, the hat pops off and arcs up and back down onto its head. Along the floor
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
## Even the smallest hop sends the hat up for at least this long.
const MIN_FLIGHT := 0.25
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
## How far the hat is thrown off line from the slime by a bonk (springs back to zero).
var jolt := Vector2.ZERO
var _slime_last := Vector2.ZERO
var _slime_velocity := Vector2.ZERO


## Puts hat `hat_id` on the given slime sprite.
func setup(id: String, slime_body: AnimatedSprite2D, slime_anchor: Node2D = null) -> void:
	hat_id = id
	body = slime_body
	anchor = slime_anchor if slime_anchor else slime_body
	texture = preload("res://assets/sprites/hats.png")
	region_enabled = true
	region_rect = Hats.region(hat_id)
	material = Hats.material_for(hat_id)
	centered = false
	offset = -Hats.HEAD  # the frame's head point goes on the top of the slime's head
	_follow()


## Pops the hat off with the slime's leap: `slime_velocity` is how fast the slime moves along the
## floor and `flight_time` how long it will be in the air, so the hat comes down onto it.
func pop(slime_velocity: Vector2, flight_time: float) -> void:
	ground = _floor_point()
	height = _head_height()
	region_rect = Hats.region(hat_id, Hats.Width.LOOSE)  # off the head it keeps its own shape
	_slime_last = ground
	_slime_velocity = slime_velocity
	jolt = Vector2.ZERO
	var time := maxf(flight_time * 0.95, MIN_FLIGHT)
	lift = GRAVITY * time / 2.0
	state = State.FLYING


func _process(delta: float) -> void:
	match state:
		State.ON:
			_follow()
		State.FLYING:
			_fly(delta)


func _follow() -> void:
	# Squashed slime, wider hat; stretched slime, narrower and taller. Lifted a px or two in the
	# few frames whose eyes sit high, so it never covers them.
	var width := Hats.width_for(Slime.head_width(body.animation, body.frame))
	region_rect = Hats.region(hat_id, width)
	var lift_px := Hats.lift(hat_id, width, body.animation, body.frame)
	global_position = _snap(_head() - Vector2(0, lift_px) * body.global_scale)


func _fly(delta: float) -> void:
	# Predict from where the slime really is: its speed this frame against last frame's. A sudden
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
		return
	global_position = _snap(ground - Vector2(0.0, height))


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
