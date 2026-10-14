class_name TicketGoal
extends Area2D

## The randomizer maze's goal: the gold ticket voucher (assets/ui/icon_ticket.png) stands where a
## story level has its chalice (the maze's goal cell), and touching it wins the maze. Like the
## chalice it is drawn over the fog with a warm pulsing glow and a glint that runs along its top
## edge now and then; it bobs a pixel up and down (not with Reduce Motion). game.gd keeps it hidden
## until the slime is a couple of tiles away and makes it glimmer through the fog when nearer.

## Same grab circle as the chalice (scenes/chalice.tscn), so the route calibration is unchanged.
const GRAB_RADIUS := 6.0
const GLOW := Color(1.0, 0.82, 0.36)
const GLOW_STRENGTH := 0.55
const PULSE_SPEED := 2.5
const BOB_SPEED := 3.0
## A light pixel sweeps across the ticket's top edge every GLINT_EVERY s, taking GLINT_TIME s.
const GLINT_EVERY := 1.6
const GLINT_TIME := 0.35
const GLINT_COLOR := Color(1.0, 0.98, 0.85)

## Reduce Motion: no bobbing or glint.
var still := false
var sprite: Sprite2D
var _glow: Sprite2D
var _glint: Node2D
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
	_glint = Node2D.new()
	_glint.draw.connect(_draw_glint)
	sprite.add_child(_glint)


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = 0.7 + 0.3 * sin(_time * PULSE_SPEED)
	if still:
		sprite.position = Vector2.ZERO
		_glint.visible = false
		return
	sprite.position = Vector2(0, roundf(sin(_time * BOB_SPEED)))
	_glint.visible = fmod(_time, GLINT_EVERY) < GLINT_TIME
	if _glint.visible:
		_glint.queue_redraw()


## The glint: two light pixels on the voucher's top edge (row 1 of the 8x8 icon), left to right.
func _draw_glint() -> void:
	var x := floori(fmod(_time, GLINT_EVERY) / GLINT_TIME * 8.0) - 4
	_glint.draw_rect(Rect2(x, -3, 1, 1), GLINT_COLOR)
	if x + 1 < 4:
		_glint.draw_rect(Rect2(x + 1, -3, 1, 1), Color(GLINT_COLOR, 0.6))
