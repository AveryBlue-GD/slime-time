extends Area2D

## The golden chalice: a glint travels around it.

const SPARKLE_FPS := 5.0

var _time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	_time += delta
	sprite.frame = int(_time * SPARKLE_FPS) % sprite.hframes
