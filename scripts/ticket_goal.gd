class_name TicketGoal
extends Area2D

## The randomizer maze's goal: the gold ticket voucher (assets/ui/icon_ticket.png) stands where a
## story level has its chalice (the maze's goal cell), and touching it wins the maze. Like the
## chalice it is drawn over the fog with a warm pulsing glow; it bobs a pixel up and down (not with
## Reduce Motion). No glint and no glimmer through the fog (owner request, 2026-10-14). game.gd
## keeps it hidden until the slime is a couple of tiles away.

## Same grab circle as the chalice (scenes/chalice.tscn), so the route calibration is unchanged.
const GRAB_RADIUS := 6.0
const GLOW := Color(1.0, 0.82, 0.36)
const GLOW_STRENGTH := 0.55
const PULSE_SPEED := 2.5
const BOB_SPEED := 3.0

## Reduce Motion: no bobbing.
var still := false
var sprite: Sprite2D
var _glow: Sprite2D
var _time := 0.0


func _init() -> void:
	name = "TicketGoal"
	z_index = 11  # over the fog, like the chalice (hidden until seen)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = GRAB_RADIUS
	shape.shape = circle
	add_child(shape)
	_glow = Fx.make_light(72, Color(GLOW, GLOW_STRENGTH))
	_glow.z_index = -1
	add_child(_glow)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/ui/icon_ticket.png")
	add_child(sprite)


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = 0.7 + 0.3 * sin(_time * PULSE_SPEED)
	sprite.position = Vector2.ZERO if still else Vector2(0, roundf(sin(_time * BOB_SPEED)))
