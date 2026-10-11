extends Control

## Skin select: a tile per skin (locked ones are silhouettes), and for the custom skin, once the
## game is beaten, a color wheel with brightness and glow sliders. The rainbow skin unlocks from
## randomizer wins.

const TILE_SIZE := Vector2(44, 32)

var tiles := {}
var status: Label
var custom_panel: Control
var wheel: ColorWheel
var brightness: HSlider
var glow_slider: HSlider
var big_preview: AnimatedSprite2D
var skin_text: SkinText


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "SKINS")
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(18, 22)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append(Skins.CUSTOM)
	ids.append(Skins.RAINBOW)
	for id in ids:
		grid.add_child(_make_tile(id))

	status = UIKit.make_label("")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(0, 92)
	status.size = Vector2(320, 12)
	add_child(status)

	_build_custom_panel()
	var rule := UIKit.make_label("NEW LEVELS ARE FIRST PLAYED IN YOUR NEWEST SKIN", 8, UIKit.TEXT_DIM)
	rule.position = Vector2(50, 167)
	add_child(rule)
	UIKit.add_back_button(self)
	_refresh()
	tiles[Progress.selected_skin].grab_focus()


func _make_tile(id: String) -> Button:
	var unlocked: bool = Progress.is_skin_unlocked(id)
	var tile := UIKit.make_button("", func() -> void: _on_tile(id), TILE_SIZE)
	var color: Color = Skins.RAINBOW_BASE if id == Skins.RAINBOW else (Progress.custom_color if id == Skins.CUSTOM else Skins.get_preset(id).color)
	var preview := UIKit.make_slime_preview(color, 1, id == Skins.RAINBOW)
	preview.position = TILE_SIZE / 2.0 + Vector2(0, -2)
	if not unlocked:
		preview.modulate = Color(0, 0, 0, 0.85)
		preview.pause()
	tile.add_child(preview)
	tile.set_meta("preview", preview)
	tiles[id] = tile
	return tile


func _build_custom_panel() -> void:
	custom_panel = Control.new()
	custom_panel.position = Vector2(0, 104)
	add_child(custom_panel)
	wheel = ColorWheel.new()
	wheel.position = Vector2(60, 0)
	wheel.size = Vector2(58, 58)
	custom_panel.add_child(wheel)
	wheel.set_color(Progress.custom_color)
	wheel.color_changed.connect(func(_c: Color) -> void: _on_custom_changed())

	var label := UIKit.make_label("BRIGHTNESS", 8, UIKit.TEXT_DIM)
	label.position = Vector2(128, 2)
	custom_panel.add_child(label)
	brightness = _make_slider(Vector2(128, 14), Progress.custom_color.v)
	brightness.min_value = 0.25
	label = UIKit.make_label("GLOW", 8, UIKit.TEXT_DIM)
	label.position = Vector2(128, 30)
	custom_panel.add_child(label)
	glow_slider = _make_slider(Vector2(128, 42), Progress.glow)

	big_preview = UIKit.make_slime_preview(Progress.custom_color, 2)
	big_preview.position = Vector2(258, 28)
	custom_panel.add_child(big_preview)


func _make_slider(at: Vector2, start: float) -> HSlider:
	var slider := HSlider.new()
	slider.position = at
	slider.size = Vector2(90, 10)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = start
	slider.value_changed.connect(func(_v: float) -> void: _on_custom_changed())
	custom_panel.add_child(slider)
	return slider


func _on_tile(id: String) -> void:
	if Progress.is_skin_unlocked(id):
		Progress.select_skin(id)
		skin_text.recolor()
	_refresh(id)


func _on_custom_changed() -> void:
	wheel.value = brightness.value
	Progress.custom_color = wheel.get_color()
	Progress.glow = glow_slider.value
	Progress.save_progress()
	Skins.apply_to(big_preview.material, Progress.custom_color)
	Skins.apply_to(tiles[Skins.CUSTOM].get_meta("preview").material, Progress.custom_color)
	big_preview.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.6), Progress.glow * 0.5)
	skin_text.recolor()


## Updates the status line (for `focus_id`, or the selected skin) and the custom panel.
func _refresh(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_skin
	var unlocked: bool = Progress.is_skin_unlocked(id)
	var skin_name := Skins.display_name(id)
	if not unlocked:
		if id == Skins.CUSTOM:
			status.text = "LOCKED - BEAT ALL %d LEVELS" % Levels.COUNT
		elif id == Skins.RAINBOW and not Progress.is_randomizer_unlocked():
			# How to earn it stays a secret until the randomizer opens up.
			status.text = "LOCKED - BEAT ALL %d LEVELS TO FIND OUT HOW" % Levels.COUNT
		elif id == Skins.RAINBOW:
			status.text = "LOCKED - BEAT %d RANDOM MAZES (%d/%d)" % [Skins.RAINBOW_RANDOMS, Progress.randoms_won, Skins.RAINBOW_RANDOMS]
		else:
			status.text = "LOCKED - CLEAR LEVEL %d" % Skins.unlock_level(id)
	else:
		status.text = skin_name + ("  (SELECTED)" if id == Progress.selected_skin else "")
	for tile_id: String in tiles:
		var tile: Button = tiles[tile_id]
		var selected: bool = tile_id == Progress.selected_skin
		tile.add_theme_stylebox_override("normal", UIKit.button_style("hover" if selected else "normal"))
	var custom_ready: bool = Progress.selected_skin == Skins.CUSTOM and Progress.is_skin_unlocked(Skins.CUSTOM)
	custom_panel.visible = custom_ready
	if custom_ready:
		wheel.value = brightness.value


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
