class_name Coin
extends Sprite2D

## A coin waiting at a dead end, spinning in place in its level's theme (a row of
## assets/sprites/coins.png, tools/make_coins.py). It sits under the fog, so it only shows once
## that spot is explored. The game collects it when the slime touches it (see game.gd).

const FRAME := 10
const FRAMES := 8
const SPIN_FPS := 10.0
## Touching distance between the slime's center and the coin's.
const REACH := 10.0
## Jelly test: seconds a collected coin takes to dissolve inside the slime.
const DISSOLVE_TIME := 0.9

## The maze cell it sits in (its id in the save, with the level).
var cell := Vector2i.ZERO
var _time := 0.0
var _spin := 1.0


## Shows the coin for theme `theme_index` (Themes.BY_LEVEL order), starting at a random angle.
func setup(theme_index: int, at_cell: Vector2i) -> void:
	cell = at_cell
	texture = preload("res://assets/sprites/coins.png")
	region_enabled = true
	region_rect = Rect2(0, theme_index * FRAME, FRAME, FRAME)
	_time = randf() * FRAMES / SPIN_FPS
	var glow := Fx.make_light(20, Color(1.0, 0.9, 0.6, 0.18))
	glow.z_index = -1
	add_child(glow)


## Jelly test: the coin sinks into the see-through slime's body and dissolves there, spinning
## faster, fading out and fizzing tiny bubbles, then disappears.
func dissolve_into(slime: Node2D, bubble_color: Color) -> void:
	reparent(slime)
	z_index = -1  # just behind the slime's body, seen through it
	_spin = 2.5
	var bubbles := CPUParticles2D.new()
	bubbles.amount = 10
	bubbles.lifetime = 0.5
	bubbles.direction = Vector2.UP
	bubbles.spread = 30.0
	bubbles.gravity = Vector2.ZERO
	bubbles.initial_velocity_min = 6.0
	bubbles.initial_velocity_max = 14.0
	bubbles.scale_amount_max = 1.5
	bubbles.color = bubble_color
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 2.0
	add_child(bubbles)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector2(0, 1), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DISSOLVE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta * _spin
	region_rect.position.x = (int(_time * SPIN_FPS) % FRAMES) * FRAME
