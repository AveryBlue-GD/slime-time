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

## The maze cell it sits in (its id in the save, with the level).
var cell := Vector2i.ZERO
var _time := 0.0


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


func _process(delta: float) -> void:
	_time += delta
	region_rect.position.x = (int(_time * SPIN_FPS) % FRAMES) * FRAME
