class_name Hat
extends Sprite2D

## A hat on a slime. It's drawn to fit round the slime's dome (not just perched on it), and as the
## slime squashes and stretches it swaps to the matching width (Hats.width_for(Slime.head_width)).
## When the slime leaps, the hat pops off: it keeps the slime's momentum, arcs through the air and drops
## back onto its head as the slime comes down. If the slime stops short (a splat), the hat flies
## on, bounces off the wall, lands on the floor and hops back on.
##
## Works for the slime in a level (`is_wall` lets it bounce off walls) and for menu previews.
## Positions are split into `ground` (where it is on the floor plan) and `height` (how far above
## the floor), so the arc reads correctly in the top-down view.

enum State { ON, FLYING, GROUNDED }

## Strong enough that even a short hop flicks the hat up visibly and a full leap sends it high.
const GRAVITY := 1000.0
## How close (px, on the floor plan) the hat must come down to the slime to land on it.
const CATCH_RADIUS := 8.0
## Share of speed kept when bouncing off a wall.
const WALL_BOUNCE := 0.45
## Pause on the floor before hopping back on, and how fast that hop travels.
const HOP_DELAY := 0.35
const HOP_SPEED := 140.0
## Even the smallest hop sends the hat up for at least this long.
const MIN_FLIGHT := 0.25

## The slime's sprite (the hat sits on top of its current frame) and the node marking where the
## slime is on the floor (the slime itself in a level; the sprite in a menu preview).
var body: AnimatedSprite2D
var anchor: Node2D
## Optional: is this floor-plan point inside a wall? (bounces the hat off walls in a level)
var is_wall := Callable()
var state := State.ON
var ground := Vector2.ZERO
var height := 0.0
var velocity := Vector2.ZERO
var lift := 0.0
var _hop_wait := 0.0
var hat_id := Hats.NONE


## Puts hat `hat_id` on the given slime sprite.
func setup(id: String, slime_body: AnimatedSprite2D, slime_anchor: Node2D = null) -> void:
	hat_id = id
	body = slime_body
	anchor = slime_anchor if slime_anchor else slime_body
	texture = preload("res://assets/sprites/hats.png")
	region_enabled = true
	region_rect = Hats.region(hat_id)
	centered = false
	offset = -Hats.HEAD  # the frame's head point goes on the top of the slime's head
	_follow()


## Pops the hat off with the slime's leap: `slime_velocity` is how fast the slime moves along the
## floor and `flight_time` how long it will be in the air, so the hat comes down onto it.
func pop(slime_velocity: Vector2, flight_time: float) -> void:
	ground = _floor_point()
	height = _head_height()
	region_rect = Hats.region(hat_id)  # off the head it keeps its own shape
	velocity = slime_velocity
	var time := maxf(flight_time * 0.95, MIN_FLIGHT)
	lift = GRAVITY * time / 2.0
	state = State.FLYING


func _process(delta: float) -> void:
	match state:
		State.ON:
			_follow()
		State.FLYING:
			_fly(delta)
		State.GROUNDED:
			_hop_wait -= delta
			if _hop_wait <= 0.0 or ground.distance_to(_floor_point()) < CATCH_RADIUS:
				_hop_back()
			global_position = ground.round()


func _follow() -> void:
	global_position = _head().round()
	# Squashed slime, wider hat; stretched slime, narrower and taller.
	region_rect = Hats.region(hat_id, Hats.width_for(Slime.head_width(body.animation, body.frame)))


func _fly(delta: float) -> void:
	var step := velocity * delta
	if is_wall.is_valid():
		if is_wall.call(ground + Vector2(step.x, 0.0)):
			velocity.x = -velocity.x * WALL_BOUNCE
			step.x = 0.0
		if is_wall.call(ground + Vector2(0.0, step.y)):
			velocity.y = -velocity.y * WALL_BOUNCE
			step.y = 0.0
	ground += step
	lift -= GRAVITY * delta
	height += lift * delta
	if lift < 0.0 and height <= _head_height() + 1.0 and ground.distance_to(_floor_point()) < CATCH_RADIUS:
		state = State.ON  # back on the slime's head
		_follow()
		return
	if height <= 0.0:
		height = 0.0
		velocity = Vector2.ZERO
		state = State.GROUNDED
		_hop_wait = HOP_DELAY
	global_position = (ground - Vector2(0.0, height)).round()


## A hop from the floor that comes down on the slime's head.
func _hop_back() -> void:
	var to_slime := _floor_point() - ground
	var time := clampf(to_slime.length() / HOP_SPEED, 0.3, 0.7)
	velocity = to_slime / time
	lift = _head_height() / time + GRAVITY * time / 2.0
	state = State.FLYING


## Top-center of the slime's body right now (follows its squash, stretch and jump arc).
func _head() -> Vector2:
	return body.global_position + Slime.head_point(body.animation, body.frame) * body.global_scale


func _floor_point() -> Vector2:
	return anchor.global_position


## How high the top of the slime's head is above the floor.
func _head_height() -> float:
	return _floor_point().y - _head().y
