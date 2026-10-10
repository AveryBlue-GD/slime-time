extends CanvasLayer

## Slime meter (top-left, in the skin's color), run timer (top-center), level name (top-right),
## a center message, and the gold NEW RECORD! banner with sparkling chalices.

const BAR_SIZE := Vector2(60, 4)
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(220, 40, 50)
const GOLD := Color8(255, 205, 117)
const CHALICE_FPS := 5.0

var fill: ColorRect
var goo_color := Color8(239, 125, 47)
var _rainbow := false
var _hue := 0.0
var label: Label
var level_label: Label
var message: Label
var time_label: Label
## Shown only when a level is beaten faster than its saved record.
var record_banner: CenterContainer
var record_time_label: Label
var _chalices: Array[TextureRect] = []
var _chalice_clock := 0.0


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

	time_label = _make_label()
	time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.offset_left = -30
	time_label.offset_right = 30
	add_child(time_label)

	message = _make_label(SkinText.ROLE_TITLE)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.visible = false
	add_child(message)

	_build_record_banner()
	set_slime(100.0)
	set_time(0.0)
	add_child(SkinText.new())


func set_slime(percent: float) -> void:
	fill.size.x = roundf(BAR_SIZE.x * clampf(percent, 0.0, 100.0) / 100.0)
	fill.color = LOW_COLOR if percent < 20.0 else goo_color
	label.text = "SLIME %d%%" % ceili(percent)


func set_time(seconds: float) -> void:
	time_label.text = UIKit.format_time(seconds)


## The gold NEW RECORD! banner (big text + the new time) between two sparkling chalices.
func show_record(seconds: float) -> void:
	record_time_label.text = UIKit.format_time(seconds)
	record_banner.visible = true


func _build_record_banner() -> void:
	record_banner = CenterContainer.new()
	record_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	record_banner.offset_top = 114
	record_banner.offset_bottom = 148
	record_banner.visible = false
	add_child(record_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	record_banner.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	var title := _gold_label("NEW RECORD!", 16)
	record_time_label = _gold_label("", 8)
	words.add_child(title)
	words.add_child(record_time_label)
	row.add_child(_make_chalice())
	row.add_child(words)
	row.add_child(_make_chalice())


func _make_chalice() -> TextureRect:
	var chalice := TextureRect.new()
	var frame := AtlasTexture.new()
	frame.atlas = preload("res://assets/sprites/chalice_sheet.png")
	frame.region = Rect2(0, 0, 16, 16)
	chalice.texture = frame
	# Drawn at 2x (whole pixels stay crisp) to match the big NEW RECORD! text.
	chalice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chalice.stretch_mode = TextureRect.STRETCH_SCALE
	chalice.custom_minimum_size = Vector2(32, 32)
	chalice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chalices.append(chalice)
	return chalice


## Gold text that keeps its color whatever the skin (not in the SkinText group).
func _gold_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


func set_level_text(text: String) -> void:
	level_label.text = text


func set_skin_color(color: Color, rainbow := false) -> void:
	goo_color = color
	fill.color = color
	_rainbow = rainbow


## Rainbow skin: the meter cycles through the rainbow (unless it's low and flashing red).
func _process(delta: float) -> void:
	if record_banner.visible:
		_chalice_clock += delta
		var frame := int(_chalice_clock * CHALICE_FPS) % 4
		for i in _chalices.size():
			# Glints alternate between the two chalices.
			(_chalices[i].texture as AtlasTexture).region.position.x = ((frame + i * 2) % 4) * 16
	if not _rainbow:
		return
	_hue = fposmod(_hue + delta * 0.25, 0.83)
	goo_color = Color.from_hsv(_hue, 0.8, 0.95)
	if fill.color != LOW_COLOR:
		fill.color = goo_color


## Shows a message for a few seconds (unless something else replaces it meanwhile).
func flash_message(text: String, seconds: float) -> void:
	show_message(text)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(message) and message.text == text:
		message.visible = false


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func _make_label(role := SkinText.ROLE_TEXT) -> Label:
	var l := Label.new()
	l.set_meta("role", role)
	l.add_to_group(SkinText.GROUP)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_outline_color", FRAME_COLOR)
	l.add_theme_constant_override("outline_size", 2)
	return l
