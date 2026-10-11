extends CanvasLayer

## Three framed pods along the top: slime meter (goo-drop icon + segmented bar in the skin's
## color + percent), run timer (clock icon), level name. Plus a center message on a panel, the
## gold NEW RECORD! banner with sparkling chalices, and a soft vignette under it all.

const BAR_SIZE := Vector2(50, 6)
const SEGMENTS := 5
const POD_MARGIN := 3
## Below this percent the meter turns red and pulses.
const LOW_PERCENT := 20.0
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(220, 40, 50)
const GOLD := Color8(255, 205, 117)
const CHALICE_FPS := 5.0

var fill: ColorRect
var _shine: ColorRect
var _drop: TextureRect
var _low := false
var _pulse := 0.0
var goo_color := Color8(239, 125, 47)
var _rainbow := false
var _hue := 0.0
var label: Label
var level_label: Label
var message: Label
var _message_panel: PanelContainer
var time_label: Label
## Shown only when a level is beaten faster than its saved record.
var record_banner: CenterContainer
var record_time_label: Label
var _chalices: Array[TextureRect] = []
var _chalice_clock := 0.0
## Buttons offered after a win (replay / next).
var choice_buttons: Array[Button] = []
var _choice_root: Control
var _skin_text: SkinText


func _ready() -> void:
	var vignette := ColorRect.new()
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	vignette_material.set_shader_parameter("mist_strength", 0.0)
	vignette_material.set_shader_parameter("vignette_strength", 0.55)
	vignette.material = vignette_material
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# Left pod: goo drop, segmented meter, percent.
	var meter_row := _make_pod(Control.PRESET_TOP_LEFT)
	_drop = UIKit.make_icon("drop", goo_color)
	meter_row.add_child(_drop)
	meter_row.add_child(_build_meter())
	label = _make_label()
	label.custom_minimum_size = Vector2(22, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter_row.add_child(label)

	# Center pod: clock + run time.
	var time_row := _make_pod(Control.PRESET_CENTER_TOP)
	time_row.add_child(UIKit.make_icon("clock", UIKit.TEXT))
	time_label = _make_label()
	time_label.custom_minimum_size = Vector2(32, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_row.add_child(time_label)

	# Right pod: level name.
	var level_row := _make_pod(Control.PRESET_TOP_RIGHT)
	level_label = _make_label()
	level_row.add_child(level_label)

	var message_center := CenterContainer.new()
	message_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_center.offset_top = 20
	message_center.offset_bottom = -40
	message_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_center)
	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_center.add_child(_message_panel)
	message = _make_label(SkinText.ROLE_TITLE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_panel.add_child(message)
	# The panel shows whenever the message does.
	message.visibility_changed.connect(func() -> void: _message_panel.visible = message.visible)
	message.visible = false
	_message_panel.visible = false

	_build_record_banner()
	_build_choice_row()
	set_slime(100.0)
	set_time(0.0)
	_skin_text = SkinText.new()
	_skin_text.theme_owner = _choice_root
	add_child(_skin_text)


func set_slime(percent: float) -> void:
	fill.size.x = roundf(BAR_SIZE.x * clampf(percent, 0.0, 100.0) / 100.0)
	_shine.size.x = fill.size.x
	_low = percent < LOW_PERCENT
	fill.color = LOW_COLOR if _low else goo_color
	if not _low:
		fill.modulate = Color.WHITE
	label.text = "%d%%" % ceili(percent)


## A framed pod anchored to a top corner (or the top center); returns its row to fill.
func _make_pod(preset: Control.LayoutPreset) -> HBoxContainer:
	var pod := PanelContainer.new()
	pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pod)
	pod.set_anchors_preset(preset)
	pod.offset_top = POD_MARGIN
	match preset:
		Control.PRESET_TOP_LEFT:
			pod.offset_left = POD_MARGIN
			pod.offset_right = POD_MARGIN
		Control.PRESET_TOP_RIGHT:
			pod.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			pod.offset_left = -POD_MARGIN
			pod.offset_right = -POD_MARGIN
		_:
			pod.grow_horizontal = Control.GROW_DIRECTION_BOTH
			pod.offset_left = 0
			pod.offset_right = 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod.add_child(row)
	return row


## The slime bar: dark frame, sunken track, goo fill with a 1 px shine, segment ticks.
func _build_meter() -> Control:
	var meter := Control.new()
	meter.custom_minimum_size = BAR_SIZE + Vector2(2, 2)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_rect(meter, Vector2.ZERO, BAR_SIZE + Vector2(2, 2), FRAME_COLOR)
	_add_rect(meter, Vector2.ONE, BAR_SIZE, Color8(40, 34, 52))
	fill = _add_rect(meter, Vector2.ONE, BAR_SIZE, goo_color)
	_shine = _add_rect(meter, Vector2.ONE, Vector2(BAR_SIZE.x, 1), Color(1, 1, 1, 0.35))
	for i in range(1, SEGMENTS):
		_add_rect(meter, Vector2(1 + i * BAR_SIZE.x / SEGMENTS, 1), Vector2(1, BAR_SIZE.y), Color(FRAME_COLOR, 0.6))
	return meter


func _add_rect(parent: Control, at: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func set_time(seconds: float) -> void:
	time_label.text = UIKit.format_time(seconds)


## The gold NEW RECORD! banner (big text + the new time) between two sparkling chalices.
func show_record(seconds: float) -> void:
	record_time_label.text = UIKit.format_time(seconds)
	record_banner.visible = true


## Shows a row of buttons, each [text, Callable]; the last one gets keyboard focus.
func show_choices(options: Array) -> void:
	var row: HBoxContainer = _choice_root.get_child(0).get_child(0)
	for child in row.get_children():
		child.queue_free()
	choice_buttons.clear()
	for option: Array in options:
		var button := UIKit.make_button(option[0], option[1], Vector2(84, 13))
		row.add_child(button)
		choice_buttons.append(button)
	_choice_root.visible = true
	_skin_text.recolor()
	choice_buttons[-1].grab_focus()


func _build_choice_row() -> void:
	_choice_root = Control.new()
	_choice_root.theme = UIKit.make_theme()
	_choice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.visible = false
	add_child(_choice_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 152
	center.offset_bottom = 168
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	center.add_child(row)


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
	_drop.modulate = color
	_rainbow = rainbow


## Rainbow skin: the meter cycles through the rainbow (unless it's low and flashing red).
func _process(delta: float) -> void:
	if record_banner.visible:
		_chalice_clock += delta
		var frame := int(_chalice_clock * CHALICE_FPS) % 4
		for i in _chalices.size():
			# Glints alternate between the two chalices.
			(_chalices[i].texture as AtlasTexture).region.position.x = ((frame + i * 2) % 4) * 16
	if _low:
		_pulse += delta
		fill.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), 0.5 + 0.5 * sin(_pulse * 10.0))
	if not _rainbow:
		return
	_hue = fposmod(_hue + delta * 0.25, 0.83)
	goo_color = Color.from_hsv(_hue, 0.8, 0.95)
	_drop.modulate = goo_color
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
	l.add_theme_color_override("font_shadow_color", Color(FRAME_COLOR, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
