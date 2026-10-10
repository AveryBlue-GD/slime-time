extends CanvasLayer

## Slime meter (top-left) and a center-screen message.

const BAR_SIZE := Vector2(60, 4)
const FRAME_COLOR := Color8(26, 28, 44)
const GOO_COLOR := Color8(56, 183, 100)
const LOW_COLOR := Color8(239, 125, 87)

var fill: ColorRect
var label: Label
var level_label: Label
var message: Label


func _ready() -> void:
	var frame := ColorRect.new()
	frame.color = FRAME_COLOR
	frame.position = Vector2(4, 4)
	frame.size = BAR_SIZE + Vector2(2, 2)
	add_child(frame)

	fill = ColorRect.new()
	fill.color = GOO_COLOR
	fill.position = Vector2(5, 5)
	fill.size = BAR_SIZE
	add_child(fill)

	label = _make_label()
	label.position = Vector2(68, 0)
	add_child(label)

	level_label = _make_label()
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.offset_left = -80
	level_label.offset_right = -4
	add_child(level_label)

	message = _make_label()
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.visible = false
	add_child(message)

	set_slime(100.0)


func set_slime(percent: float) -> void:
	fill.size.x = roundf(BAR_SIZE.x * clampf(percent, 0.0, 100.0) / 100.0)
	fill.color = LOW_COLOR if percent < 20.0 else GOO_COLOR
	label.text = "SLIME %d%%" % ceili(percent)


func set_level(level: int) -> void:
	level_label.text = "LEVEL %d/%d" % [level, Levels.COUNT]


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_outline_color", FRAME_COLOR)
	l.add_theme_constant_override("outline_size", 2)
	return l
