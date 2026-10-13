extends Node

var _frames := 0


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 40:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		Input.parse_input_event(key)
