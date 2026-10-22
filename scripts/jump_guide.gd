extends Node2D

## While charging: a meter above the slime and a dotted line to where the jump will land.
## The dots draw over the fog but reveal nothing about what lies in between.

const METER_SIZE := Vector2(14, 3)
const METER_Y := -20.0
const DOT_SPACING := 6.0
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(56, 183, 100)
const MID_COLOR := Color8(255, 205, 117)
const HIGH_COLOR := Color8(239, 125, 87)
const DOT_COLOR := Color8(244, 244, 244, 190)

@onready var slime: Slime = get_parent()


func _process(_delta: float) -> void:
	visible = slime.state == Slime.State.CHARGING
	if visible:
		queue_redraw()


func _draw() -> void:
	var amount := slime.charge / 100.0
	var corner := Vector2(-METER_SIZE.x / 2.0, METER_Y)
	draw_rect(Rect2(corner - Vector2.ONE, METER_SIZE + Vector2(2, 2)), FRAME_COLOR)
	var color := LOW_COLOR.lerp(MID_COLOR, amount * 2.0) if amount < 0.5 \
		else MID_COLOR.lerp(HIGH_COLOR, amount * 2.0 - 1.0)
	draw_rect(Rect2(corner, Vector2(roundf(METER_SIZE.x * amount), METER_SIZE.y)), color)

	var distance := Slime.jump_distance_for(slime.charge)
	var aim := slime.leap_aim()
	var d := DOT_SPACING
	while d < distance - 2.0:
		draw_rect(Rect2((aim * d).round(), Vector2.ONE), DOT_COLOR)
		d += DOT_SPACING
	var landing := (aim * distance).round()
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_rect(Rect2(landing + offset, Vector2.ONE), DOT_COLOR)
