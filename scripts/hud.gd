extends CanvasLayer

## Slime meter (top-left, in the skin's color), level name (top-right) and a center message.

const BAR_SIZE := Vector2(60, 4)
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(220, 40, 50)

var fill: ColorRect
var goo_color := Color8(239, 125, 47)
var _rainbow := false
var _hue := 0.0
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
	fill.color = goo_color
	fill.position = Vector2(5, 5)
	fill.size = BAR_SIZE
	add_child(fill)

	label = _make_label()
	label.position = Vector2(68, 0)
	add_child(label)

	level_label = _make_label()
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.offset_left = -120
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
	fill.color = LOW_COLOR if percent < 20.0 else goo_color
	label.text = "SLIME %d%%" % ceili(percent)


func set_level_text(text: String) -> void:
	level_label.text = text


func set_skin_color(color: Color, rainbow := false) -> void:
	goo_color = color
	fill.color = color
	_rainbow = rainbow


## Rainbow skin: the meter cycles through the rainbow (unless it's low and flashing red).
func _process(delta: float) -> void:
	if not _rainbow:
		return
	_hue = fposmod(_hue + delta * 0.25, 0.83)
	goo_color = Color.from_hsv(_hue, 0.8, 0.95)
	if fill.color != LOW_COLOR:
		fill.color = goo_color


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_outline_color", FRAME_COLOR)
	l.add_theme_constant_override("outline_size", 2)
	return l
