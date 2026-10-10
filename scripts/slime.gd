class_name Slime
extends CharacterBody2D

## Free gliding movement plus a charge jump.
## Hold "jump" to charge: the slime slides to a stop and the movement keys only aim.
## Release to leap in the aimed direction. Hitting a wall mid-air is a splat.
## Speeds are in pixels per second at the 320x180 base resolution.

signal jump_landed(intended_distance: float, hit_wall: bool, wall_normal: Vector2)

enum State { GLIDE, CHARGING, AIRBORNE, STUNNED }

const TILE := 16
const RADIUS := 5.0
const CHARGE_TIME := 1.5
const MIN_JUMP_TILES := 1.0
const MAX_JUMP_TILES := 8.0
const JUMP_SPEED := 220.0
const SPLAT_STUN := 0.4

@export var max_speed := 72.0
@export var acceleration := 420.0
@export var friction := 260.0

## Set by the game when the slime dries up or reaches the chalice.
var frozen := false
var state := State.GLIDE
## 0-100 while charging.
var charge := 0.0
## Unit vector the slime is aiming/moving in (8 directions with keyboard input).
var facing := Vector2.RIGHT

var _jump_dir := Vector2.ZERO
var _jump_distance := 0.0
var _jump_traveled := 0.0
var _stun_left := 0.0

@onready var sprite: Sprite2D = $Sprite2D


static func jump_distance_for(charge_value: float) -> float:
	return lerpf(MIN_JUMP_TILES, MAX_JUMP_TILES, clampf(charge_value, 0.0, 100.0) / 100.0) * TILE


func is_airborne() -> bool:
	return state == State.AIRBORNE


## Leaps in the facing direction. Called on releasing the jump key (and by tests).
func launch(charge_value: float) -> void:
	_jump_dir = facing
	_jump_distance = jump_distance_for(charge_value)
	_jump_traveled = 0.0
	velocity = Vector2.ZERO
	charge = 0.0
	state = State.AIRBORNE


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not frozen:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO and (state == State.GLIDE or state == State.CHARGING):
		facing = input.normalized()
		if facing.x != 0.0:
			sprite.flip_h = facing.x < 0.0

	if state == State.GLIDE and not frozen and Input.is_action_just_pressed("jump"):
		state = State.CHARGING
		charge = 0.0

	match state:
		State.GLIDE:
			_glide(input, delta)
		State.CHARGING:
			_glide(Vector2.ZERO, delta)
			if frozen:
				state = State.GLIDE
				charge = 0.0
			else:
				charge = minf(charge + 100.0 / CHARGE_TIME * delta, 100.0)
				if not Input.is_action_pressed("jump"):
					launch(charge)
		State.AIRBORNE:
			_fly(delta)
		State.STUNNED:
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.GLIDE


func _glide(input: Vector2, delta: float) -> void:
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func _fly(delta: float) -> void:
	var step := minf(JUMP_SPEED * delta, _jump_distance - _jump_traveled)
	var collision := move_and_collide(_jump_dir * step)
	_jump_traveled += step
	var arc_height := 3.0 + _jump_distance / TILE * 1.5
	sprite.position.y = -roundf(sin(PI * _jump_traveled / _jump_distance) * arc_height)
	if collision:
		_land(true, collision.get_normal())
	elif _jump_traveled >= _jump_distance:
		_land(false, Vector2.ZERO)


func _land(hit_wall: bool, wall_normal: Vector2) -> void:
	sprite.position.y = 0.0
	if hit_wall:
		state = State.STUNNED
		_stun_left = SPLAT_STUN
	else:
		state = State.GLIDE
	jump_landed.emit(_jump_distance, hit_wall, wall_normal)
