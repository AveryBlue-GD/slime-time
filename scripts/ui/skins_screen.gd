extends Control

## Skin select: a tile per skin (locked ones are silhouettes), and for the custom skin, once the
## game is beaten, a color wheel and a glow slider (brightness is an upgrade now). The rainbow skin unlocks from
## randomizer wins. A HATS button flips to the hats page: a tile per hat (plus no hat), each
## shown on a slime in your skin; hats unlock from randomizer wins too.

const TILE_SIZE := Vector2(44, 32)
const SKINS_RULE := "NEW LEVELS START IN YOUR NEWEST SKIN"
const HATS_RULE := "WIN RANDOM MAZES TO UNLOCK HATS"

var tiles := {}
var hat_tiles := {}
var status: Label
var custom_panel: Control
var wheel: ColorWheel
var glow_slider: HSlider
var big_preview: AnimatedSprite2D
var skin_text: SkinText
## "skins" or "hats".
var page := "skins"
var page_button: Button
var _skin_grid: GridContainer
var _hat_grid: GridContainer
var _title: Label
var _rule: Label


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "SKINS")
	for child in get_children():
		if child is Label and child.text == "SKINS":
			_title = child
	_skin_grid = _make_grid()
	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append(Skins.CUSTOM)
	ids.append(Skins.RAINBOW)
	for id in ids:
		_skin_grid.add_child(_make_tile(id))

	_hat_grid = _make_grid()
	var hat_ids: Array[String] = [Hats.NONE]
	for hat: Dictionary in Hats.LIST:
		hat_ids.append(hat.id)
	for id in hat_ids:
		_hat_grid.add_child(_make_hat_tile(id))

	status = UIKit.make_label("")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(0, 92)
	status.size = Vector2(320, 12)
	add_child(status)

	_build_custom_panel()
	_rule = UIKit.make_label(SKINS_RULE, 8, UIKit.TEXT_DIM)
	_rule.position = Vector2(50, 167)
	add_child(_rule)
	UIKit.add_back_button(self)
	page_button = UIKit.make_button("HATS", func() -> void: show_page("skins" if page == "hats" else "hats"), Vector2(40, 13))
	page_button.position = Vector2(276, 164)
	add_child(page_button)
	show_page("skins")


func _make_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(18, 22)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	return grid


## Switches between the skins page and the hats page.
func show_page(which: String) -> void:
	page = which
	var hats := page == "hats"
	_skin_grid.visible = not hats
	_hat_grid.visible = hats
	_title.text = "HATS" if hats else "SKINS"
	_rule.text = HATS_RULE if hats else SKINS_RULE
	_rule.position.x = roundf((320 - _rule.get_minimum_size().x) / 2.0)
	page_button.text = "SKINS" if hats else "HATS"
	if hats:
		custom_panel.visible = false
		_refresh_hats()
		hat_tiles[Progress.selected_hat].grab_focus()
	else:
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


## A hat tile: a slime in the selected skin wearing the hat (a silhouette while locked).
func _make_hat_tile(id: String) -> Button:
	var unlocked: bool = Progress.is_hat_unlocked(id)
	var tile := UIKit.make_button("", func() -> void: _on_hat_tile(id), TILE_SIZE)
	var preview := UIKit.make_slime_preview(Progress.skin_color(), 1, Progress.is_rainbow())
	preview.position = TILE_SIZE / 2.0 + Vector2(0, 2)
	tile.add_child(preview)
	if id != Hats.NONE:
		var hat := Hat.new()
		tile.add_child(hat)
		hat.setup(id, preview)
		if not unlocked:
			hat.modulate = Color(0, 0, 0, 0.85)
	if not unlocked:
		preview.modulate = Color(0, 0, 0, 0.85)
		preview.pause()
	hat_tiles[id] = tile
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

	# (Brightness is an upgrade now, not a color setting: the wheel's colors are full strength.)
	var label := UIKit.make_label("GLOW", 8, UIKit.TEXT_DIM)
	label.position = Vector2(128, 16)
	custom_panel.add_child(label)
	glow_slider = _make_slider(Vector2(128, 28), Progress.glow)

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


func _on_hat_tile(id: String) -> void:
	Progress.select_hat(id)
	_refresh_hats(id)


func _on_custom_changed() -> void:
	wheel.value = 1.0
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
	custom_panel.visible = custom_ready and page == "skins"
	if custom_ready:
		wheel.value = 1.0


## The hats page's status line (for `focus_id`, or the worn hat) and tile highlights.
func _refresh_hats(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_hat
	if Progress.is_hat_unlocked(id):
		status.text = Hats.display_name(id) + ("  (WEARING)" if id == Progress.selected_hat else "")
	elif not Progress.is_randomizer_unlocked():
		status.text = "LOCKED - BEAT ALL %d LEVELS TO FIND OUT HOW" % Levels.COUNT
	else:
		var needed := Hats.wins_needed(id)
		status.text = "LOCKED - WIN %d RANDOM MAZE%s (%d/%d)" % [needed, "" if needed == 1 else "S", Progress.randoms_won, needed]
	for tile_id: String in hat_tiles:
		var tile: Button = hat_tiles[tile_id]
		tile.add_theme_stylebox_override("normal", UIKit.button_style("hover" if tile_id == Progress.selected_hat else "normal"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
