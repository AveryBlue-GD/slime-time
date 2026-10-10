class_name ColorWheel
extends Control

## Click/drag to pick hue (around) and saturation (outward). Brightness comes from `value`.
## Uses the same stepped math as color_wheel.gdshader, so the picked color matches the swatch.

signal color_changed(color: Color)

const HUE_STEPS := 24.0
const SAT_STEPS := 6.0

var hue := 0.0
var saturation := 1.0
var value := 1.0:
	set(new_value):
		value = new_value
		if _wheel:
			(_wheel.material as ShaderMaterial).set_shader_parameter("value", value)

var _wheel: ColorRect
var _marker: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel = ColorRect.new()
	_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.material = ShaderMaterial.new()
	(_wheel.material as ShaderMaterial).shader = preload("res://assets/shaders/color_wheel.gdshader")
	add_child(_wheel)
	_marker = ColorRect.new()
	_marker.size = Vector2(3, 3)
	_marker.color = UIKit.BG
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)
	value = value
	_place_marker()


func get_color() -> Color:
	return Color.from_hsv(hue, saturation, value)


func set_color(color: Color) -> void:
	hue = floorf(color.h * HUE_STEPS) / HUE_STEPS
	saturation = maxf(ceilf(color.s * SAT_STEPS) / SAT_STEPS, 1.0 / SAT_STEPS)
	value = color.v
	_place_marker()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var dragged: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not (pressed or dragged):
		return
	var p: Vector2 = event.position / size * 2.0 - Vector2.ONE
	hue = floorf(fposmod(atan2(p.y, p.x) / TAU, 1.0) * HUE_STEPS) / HUE_STEPS
	saturation = maxf(ceilf(minf(p.length(), 1.0) * SAT_STEPS) / SAT_STEPS, 1.0 / SAT_STEPS)
	_place_marker()
	color_changed.emit(get_color())
	accept_event()


func _place_marker() -> void:
	if not _marker:
		return
	var angle := (hue + 0.5 / HUE_STEPS) * TAU
	var radius := saturation - 0.5 / SAT_STEPS
	var p := Vector2(cos(angle), sin(angle)) * radius
	_marker.position = ((p + Vector2.ONE) / 2.0 * size - Vector2(1.5, 1.5)).round()
