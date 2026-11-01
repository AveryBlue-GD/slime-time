extends Area2D

## The golden chalice: a warm glow pulses around it (drawn over the fog, so once found it shines
## through the mist). It stands still on the sheet's first frame: no moving glint (owner request,
## 2026-10-14; the sheet's other frames are only used by the HUD's NEW RECORD banner).

const GLOW_COLOR := Color(1.0, 0.72, 0.28)
const GLOW_STRENGTH := 0.55
const PULSE_SPEED := 2.5

var _time := 0.0
var _glow: Sprite2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.frame = 0
	_glow = Fx.make_light(72, Color(GLOW_COLOR, GLOW_STRENGTH))
	_glow.z_index = -1
	add_child(_glow)
	move_child(_glow, 0)


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = GLOW_STRENGTH * (0.7 + 0.3 * sin(_time * PULSE_SPEED))


## ANI-02: the win consumes the chalice (sheet frames 4 tilt toward the slime, 5 gulp, 6 gone; ~0.25 s). The slime gulps on
## frame 5 and then celebrates. Node-bound tween, so leaving the tree stops it; the slime is checked before each call.
func consume(slime: Node2D) -> void:
	var toward := signf(slime.global_position.x - global_position.x)
	sprite.flip_h = toward < 0.0
	sprite.frame = 4
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(_gulp.bind(slime))
	tween.tween_interval(0.08)
	tween.tween_callback(_gone.bind(slime))


func _gulp(slime: Node2D) -> void:
	sprite.frame = 5
	if is_instance_valid(slime):
		slime.play_gulp()


func _gone(slime: Node2D) -> void:
	sprite.frame = 6
	sprite.visible = false
	_glow.visible = false
	if is_instance_valid(slime):
		slime.play_celebrate()
