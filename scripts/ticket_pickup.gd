class_name TicketPickup
extends Sprite2D

## The ticket voucher waiting in a randomizer maze (see TicketSpawn for where): the gold ticket icon
## with a soft glow, bobbing a pixel up and down. It stays hidden until the slime is within a couple
## of tiles (like the chalice) and glints faintly through the fog when the slime is nearer (game.gd).
## The game collects it when the slime touches it.

## Touching distance between the slime's center and the ticket's.
const REACH := 10.0
const GLOW := Color(1.0, 0.82, 0.36)
const BOB_SPEED := 3.0

## The maze cell it sits in.
var cell := Vector2i.ZERO
## Reduce Motion: no bobbing.
var still := false
var _time := randf() * TAU
var _home := Vector2.ZERO


func setup(at_cell: Vector2i, at: Vector2) -> void:
	cell = at_cell
	texture = preload("res://assets/ui/icon_ticket.png")
	position = at
	_home = at
	var glow := Fx.make_light(22, Color(GLOW, 0.3))
	glow.z_index = -1
	add_child(glow)


## Collected: it pops into a few gold sparks and goes.
func collect(parent: Node) -> void:
	Fx.burst(parent, position, GLOW.lightened(0.25), 12, 40.0)
	queue_free()


func _process(delta: float) -> void:
	if still:
		return
	_time += delta * BOB_SPEED
	position = _home + Vector2(0, roundf(sin(_time)))
