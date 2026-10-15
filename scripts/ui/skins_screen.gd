extends Control

## Skin select. Slimes are see-through jelly by default; the JELLY ON / OFF switch shows the same
## skins in solid form instead, each unlocked by beating its level on hard mode (the jelly ones
## unlock with the story levels). A tile per skin (locked ones are silhouettes); for the custom
## skin, once the game is beaten, a color wheel. The page button cycles SKINS -> HATS -> TRAILS:
## the hats page has a tile per hat (plus no hat), each shown on a slime in your skin; the TRAILS page
## (upgrades v2 batch 2) a tile per goo trail style (the skin's own goo plus the five sold in the
## prize wheel's SHOP, Cosmetics), each a little strip of that goo in your skin; owned ones are worn
## by pressing them, the others are silhouettes saying where to buy them.
##
## Layout (320x180, mirrored left/right): title, a 7-wide grid, the status line, a hint, the
## custom color panel or the preview stage (the clicked skin acting out a little routine, see
## SkinShowcase), and a bottom row of BACK | JELLY | HATS.

const TILE_SIZE := Vector2(40, 30)
const GRID_COLUMNS := 7
const GRID_GAP := 3
const GRID_TOP := 23
const STATUS_TOP := 89
const RULE_TOP := 100
const CUSTOM_TOP := 112
const WHEEL_SIZE := 48
const WHEEL_GAP := 40
const SKINS_RULE := "NEW LEVELS EQUIP YOUR NEWEST SKIN"
const SOLID_RULE := "SOLID SKINS UNLOCK ON HARD MODE"
const HATS_RULE := "WIN HATS ON THE PRIZE WHEEL IN THE HUB"
const TRAILS_RULE := "BUY TRAILS IN THE PRIZE WHEEL'S SHOP"
## The pages, in the order the page button cycles them.
const PAGES := ["skins", "hats", "trails"]

var tiles := {}
var hat_tiles := {}
var trail_tiles := {}
var status: Label
var custom_panel: Control
var wheel: ColorWheel
var big_preview: AnimatedSprite2D
## The animated preview of the clicked skin (where the custom panel goes when that's not shown).
var showcase: SkinShowcase
var skin_text: SkinText
## "skins", "hats" or "trails".
var page := "skins"
## Which version of the skins the grid shows: jelly (true) or solid.
var view_jelly := true
var page_button: Button
var jelly_button: Button
var _skin_grid: VBoxContainer
var _hat_grid: VBoxContainer
var _trail_grid: VBoxContainer
var _title: Label
var _rule: Label


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "SKINS")
	for child in get_children():
		if child is Label and child.text == "SKINS":
			_title = child
	view_jelly = Progress.jelly
	# A fresh random color on the wheel every visit (any hue, never washed out).
	Progress.custom_color = Color.from_hsv(randf(), randf_range(0.55, 1.0), 1.0)
	Progress.save_progress()
	_skin_grid = _make_grid()
	_fill_skin_grid()

	_hat_grid = _make_grid()
	var hat_ids: Array[String] = [Hats.NONE]
	for hat: Dictionary in Hats.LIST:
		hat_ids.append(hat.id)
	for id in hat_ids:
		_add_to_grid(_hat_grid, _make_hat_tile(id))
	_trail_grid = _make_grid()
	for id in Cosmetics.trail_ids():
		_add_to_grid(_trail_grid, _make_trail_tile(id))

	status = _centered_label("", UIKit.TEXT, STATUS_TOP)
	_rule = _centered_label(SKINS_RULE, UIKit.TEXT_DIM, RULE_TOP)
	_build_custom_panel()
	showcase = SkinShowcase.new()
	add_child(showcase)
	showcase.position = Vector2(roundf((320 - SkinShowcase.STAGE_SIZE.x) / 2.0), CUSTOM_TOP)

	# Bottom row: BACK and HATS the same width at the same distance from each edge, the jelly
	# switch centered between them.
	var back := UIKit.add_back_button(self)
	page_button = UIKit.make_button("HATS", func() -> void: show_page(PAGES[(PAGES.find(page) + 1) % PAGES.size()]), back.custom_minimum_size)
	page_button.position = Vector2(320 - back.position.x - back.custom_minimum_size.x, back.position.y)
	add_child(page_button)
	jelly_button = UIKit.make_button("", _toggle_jelly, Vector2(80, UIKit.BUTTON_H))
	jelly_button.position = Vector2((320 - 80) / 2, back.position.y)
	add_child(jelly_button)
	show_page("skins")


## A label centered across the screen, `top` = its top edge.
func _centered_label(text: String, color: Color, top: int) -> Label:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + 10
	return label


## A tile grid centered across the screen: rows of GRID_COLUMNS tiles, a shorter last row
## centered under the others (see _add_to_grid).
func _make_grid() -> VBoxContainer:
	var grid := VBoxContainer.new()
	grid.position = Vector2(roundf((320 - _grid_width()) / 2.0), GRID_TOP)
	grid.add_theme_constant_override("separation", GRID_GAP)
	add_child(grid)
	return grid


func _grid_width() -> float:
	return GRID_COLUMNS * TILE_SIZE.x + (GRID_COLUMNS - 1) * GRID_GAP


func _add_to_grid(grid: VBoxContainer, tile: Control) -> void:
	var row: HBoxContainer = grid.get_child(-1) if grid.get_child_count() > 0 else null
	if row == null or row.get_child_count() >= GRID_COLUMNS:
		row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size.x = _grid_width()
		row.add_theme_constant_override("separation", GRID_GAP)
		grid.add_child(row)
	row.add_child(tile)


## (Re)builds the skin tiles for the version on view (jelly or solid).
func _fill_skin_grid() -> void:
	for child in _skin_grid.get_children():
		_skin_grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append(Skins.CUSTOM)
	ids.append(Skins.RAINBOW)
	ids.append(Skins.STOPWATCH)
	for id in ids:
		_add_to_grid(_skin_grid, _make_tile(id))


## Switches between the skins, hats and trails pages.
func show_page(which: String) -> void:
	page = which
	var hats := page == "hats"
	var trails := page == "trails"
	_skin_grid.visible = page == "skins"
	_hat_grid.visible = hats
	_trail_grid.visible = trails
	jelly_button.visible = page == "skins"
	_title.text = page.to_upper()
	page_button.text = PAGES[(PAGES.find(page) + 1) % PAGES.size()].to_upper()
	if hats:
		_rule.text = HATS_RULE
		custom_panel.visible = false
		showcase.visible = false
		_refresh_hats()
		hat_tiles[Progress.selected_hat].grab_focus()
	elif trails:
		_rule.text = TRAILS_RULE
		custom_panel.visible = false
		showcase.visible = false
		_refresh_trails()
		trail_tiles[Progress.trail_style].grab_focus()
	else:
		_refresh()
		_preview(Progress.selected_skin)
		tiles[Progress.selected_skin].grab_focus()


## JELLY ON / OFF: shows the other version of every skin.
func _toggle_jelly() -> void:
	view_jelly = not view_jelly
	# The worn skin follows the switch when its other version is unlocked; otherwise it stays
	# as it is and the status line says the other version is still locked (_refresh).
	var worn: String = Progress.selected_skin
	if view_jelly != Progress.jelly and Progress.is_skin_unlocked(worn, view_jelly):
		Progress.select_skin(worn, view_jelly)
		skin_text.recolor()
		(big_preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if Progress.jelly else 0.0)
	_fill_skin_grid()
	_refresh()
	jelly_button.grab_focus()
	_preview(Progress.selected_skin)


func _make_tile(id: String) -> Button:
	var unlocked: bool = Progress.is_skin_unlocked(id, view_jelly)
	var tile := UIKit.make_button("", func() -> void: _on_tile(id), TILE_SIZE)
	var color: Color = _base_color(id)
	var preview := UIKit.make_slime_preview(color, 1, id == Skins.RAINBOW, view_jelly, id == Skins.STOPWATCH)
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
	var preview := UIKit.make_slime_preview(Progress.skin_color(), 1, Progress.is_rainbow(), null, Progress.is_stopwatch())
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


## A trail tile: a little strip of that style's goo in the worn skin (drawn like the game's trail:
## 2 px cells through trail.gdshader); a dark silhouette until it's bought.
func _make_trail_tile(id: String) -> Button:
	var owned: bool = Progress.owns_cosmetic(id)
	var tile := UIKit.make_button("", func() -> void: _on_trail_tile(id), TILE_SIZE)
	var look := Cosmetics.trail_look(id, Progress.skin_color(), Progress.is_rainbow())
	var strip := TextureRect.new()
	strip.texture = ImageTexture.create_from_image(Cosmetics.trail_preview(id, Progress.skin_color(), Progress.is_rainbow(), Vector2i(16, 9), not owned))
	strip.size = Vector2(32, 18)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.position = ((TILE_SIZE - strip.size) / 2.0).floor()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owned:
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/trail.gdshader")
		material.set_shader_parameter("stars", 1.0 if look.stars else 0.0)
		material.set_shader_parameter("animate", 0.0 if Progress.reduce_motion else 1.0)
		strip.material = material
	tile.add_child(strip)
	tile.focus_entered.connect(func() -> void:
		if page == "trails":
			_refresh_trails(id))
	trail_tiles[id] = tile
	return tile


func _on_trail_tile(id: String) -> void:
	if Progress.owns_cosmetic(id):
		Progress.equip_cosmetic(id)
	_refresh_trails(id)


## The trails page's status line (for `focus_id`, or the worn style) and tile highlights.
func _refresh_trails(focus_id := "") -> void:
	var id: String = focus_id if focus_id != "" else Progress.trail_style
	if Progress.owns_cosmetic(id):
		status.text = Cosmetics.display_name(id) + ("  (WEARING)" if id == Progress.trail_style else "")
	else:
		if Cosmetics.is_earned(id):
			status.text = "%s - %s" % [Cosmetics.display_name(id), Cosmetics.earned_how(id)]
		else:
			status.text = "%s - %d TIX IN THE SHOP" % [Cosmetics.display_name(id), Cosmetics.price(id)]
	for tile_id: String in trail_tiles:
		UIKit.set_selected(trail_tiles[tile_id], tile_id == Progress.trail_style)


## The custom color panel, mirrored about the center: the wheel on the left, the big preview
## on the right.
func _build_custom_panel() -> void:
	custom_panel = Control.new()
	custom_panel.position = Vector2(0, CUSTOM_TOP)
	add_child(custom_panel)
	var span := WHEEL_SIZE + WHEEL_GAP + WHEEL_SIZE  # wheel, gap, preview
	var left := roundf((320 - span) / 2.0)
	wheel = ColorWheel.new()
	wheel.position = Vector2(left, 0)
	wheel.size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	custom_panel.add_child(wheel)
	UIKit.add_touch_target(wheel)  # (a finger on the wheel is never taken by a tile's grown touch margin)
	wheel.set_color(Progress.custom_color)
	wheel.color_changed.connect(func(_c: Color) -> void: _on_custom_changed())

	big_preview = UIKit.make_slime_preview(Progress.custom_color, 2)
	big_preview.position = Vector2(left + span - WHEEL_SIZE / 2.0, WHEEL_SIZE / 2.0)
	custom_panel.add_child(big_preview)


## The color a skin's tile and preview are made from.
func _base_color(id: String) -> Color:
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.STOPWATCH:
		return Skins.STOPWATCH_BASE
	if id == Skins.CUSTOM:
		return Progress.custom_color
	return Skins.get_preset(id).color


func _on_tile(id: String) -> void:
	if Progress.is_skin_unlocked(id, view_jelly):
		Progress.select_skin(id, view_jelly)
		skin_text.recolor()
		(big_preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if Progress.jelly else 0.0)
	_refresh(id)
	_preview(id)


## Plays skin `id` (in the version on view) on the preview stage.
func _preview(id: String) -> void:
	var color: Color = _base_color(id)
	showcase.show_skin(color, id == Skins.RAINBOW, view_jelly, not Progress.is_skin_unlocked(id, view_jelly), id == Skins.STOPWATCH)


func _on_hat_tile(id: String) -> void:
	Progress.select_hat(id)
	_refresh_hats(id)


func _on_custom_changed() -> void:
	wheel.value = 1.0
	Progress.custom_color = wheel.get_color()
	Progress.save_progress()
	Skins.apply_to(big_preview.material, Progress.custom_color)
	Skins.apply_to(tiles[Skins.CUSTOM].get_meta("preview").material, Progress.custom_color)
	skin_text.recolor()


## Updates the status line (for `focus_id`, or the worn skin), the highlights and the custom panel.
func _refresh(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_skin
	var worn_here: bool = view_jelly == Progress.jelly
	if not Progress.is_skin_unlocked(id, view_jelly):
		if not view_jelly:
			status.text = "SOLID LOCKED - HARD CLEAR L%d" % Skins.solid_level(id)
		elif id == Skins.RAINBOW:
			status.text = "LOCKED - FIND EVERY COIN (%d/%d)" % [Progress.coins_earned(), Levels.total_coins()]
		elif id == Skins.STOPWATCH:
			status.text = "LOCKED - EARN ALL %d MEDALS (%d/%d)" % [Progress.medals_max(), Progress.medals_total(false), Progress.medals_max()]
		elif id == Skins.CUSTOM:
			status.text = "LOCKED - BEAT ALL %d LEVELS" % Levels.COUNT
		else:
			status.text = "LOCKED - CLEAR LEVEL %d" % Skins.unlock_level(id)
	else:
		status.text = Skins.display_name(id) + ("  (SELECTED)" if worn_here and id == Progress.selected_skin else "")
	for tile_id: String in tiles:
		var selected: bool = worn_here and tile_id == Progress.selected_skin
		UIKit.set_selected(tiles[tile_id], selected)
	jelly_button.text = "JELLY: ON" if view_jelly else "JELLY: OFF"
	_rule.text = SKINS_RULE if view_jelly else SOLID_RULE
	var custom_ready: bool = worn_here and Progress.selected_skin == Skins.CUSTOM and Progress.is_skin_unlocked(Skins.CUSTOM)
	# The color wheel while the custom skin is worn, unless another skin was just clicked to preview.
	custom_panel.visible = custom_ready and page == "skins" and (focus_id == "" or focus_id == Skins.CUSTOM)
	showcase.visible = page == "skins" and not custom_panel.visible
	if custom_ready:
		wheel.value = 1.0


## The hats page's status line (for `focus_id`, or the worn hat) and tile highlights.
func _refresh_hats(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_hat
	if Progress.is_hat_unlocked(id):
		status.text = Hats.display_name(id) + ("  (WEARING)" if id == Progress.selected_hat else "")
	else:
		status.text = "LOCKED - WIN IT ON THE HAT WHEEL"
	for tile_id: String in hat_tiles:
		var tile: Button = hat_tiles[tile_id]
		UIKit.set_selected(tile, tile_id == Progress.selected_hat)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
	elif event.is_action_pressed("tab_next") or event.is_action_pressed("tab_prev"):
		var step := 1 if event.is_action_pressed("tab_next") else -1  # LB / RB: the previous / next page
		show_page(PAGES[(PAGES.find(page) + step + PAGES.size()) % PAGES.size()])
		get_viewport().set_input_as_handled()
