extends Area2D

## The golden chalice: a glint travels around it, and a warm glow pulses around it (drawn over
## the fog, so once found it shines through the mist).

const SPARKLE_FPS := 5.0
const GLOW_COLOR := Color(1.0, 0.72, 0.28)
const GLOW_STRENGTH := 0.55
const PULSE_SPEED := 2.5

var _time := 0.0
var _glow: Sprite2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_glow = Fx.make_light(72, Color(GLOW_COLOR, GLOW_STRENGTH))
	_glow.z_index = -1
	add_child(_glow)
	move_child(_glow, 0)


func _process(delta: float) -> void:
	_time += delta
	sprite.frame = int(_time * SPARKLE_FPS) % sprite.hframes
	_glow.modulate.a = GLOW_STRENGTH * (0.7 + 0.3 * sin(_time * PULSE_SPEED))
