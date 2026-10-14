extends Control

## The MAP TABLE (opened at the hub's map table): the trail maps of the 10 story levels (Survey,
## recorded by real runs; see Progress.record_survey), normal or hard (the HARD switch only changes
## which maps are shown here, not the game's mode).
## - Select: goo-framed tiles like the level select's, two columns, each with just a thumbnail of the
##   survey, the level's name and how much of its floor has been uncovered ("72%", gold at 100%). A
##   level never attempted (or whose survey is of an older layout, Survey.fits) is locked: a lock in
##   the thumbnail, dim text, 0%. The first time the table is opened a short hint line explains it.
## - View: the whole map (MapView: only what was seen, the route (a clear in the goo color, the last
##   try faint), found coins, the start, the goal once seen) under the level's name, with one line
##   below: "72% UNCOVERED". No times: the level select has those.
## BACK / Esc / B (ui_cancel) go from the view back to the select, and from the select to the hub
## (which turns to face the table). Keyboard/controller focus moves over the tiles as in the other
## menus; touch taps the tiles and BACK. Nothing moves (Reduce Motion needs nothing) and nothing is
## built per frame: thumbnails and the map are drawn into images once, when shown.

const TILE_SIZE := Vector2(156, 26)
const GRID_POS := Vector2(3, 21)
const THUMB_POS := Vector2(4, 3)
## Where the map may be drawn in the view.
const MAP_AREA := Rect2i(2, 13, 316, 149)
const HINT := "PLAY TO FILL THEM IN"
## The themed maps (each level's map in its own palette with a themed frame, MapView's `theme`): a
## mockup for the owner to look at, off in the game. demo_maps.tscn's --themed turns it on there.
const THEMED_MAPS := false

## Themed maps on this screen (THEMED_MAPS, or the demo's --themed).
var themed := THEMED_MAPS

var hard := false
var viewing := false
var viewed_level := 0
var tiles: Array[Button] = []
var grid: GridContainer
var hard_box: CheckBox
var hint_label: Label
var back_button: Button
var skin_text: SkinText
## The map view: an opaque layer over the select with the title, the map and its line.
var view_root: Control
var view_area: ColorRect
var view_title: Label
var view_map: TextureRect
var view_line: Label
var view_back: Button
var _goo: Dictionary
## The select's controls kept out of focus while a map is viewed (UIKit.lock_focus).
var _focus_lock := {}


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "MAP TABLE")
	_goo = Skins.shades(Progress.skin_color())
	hard = Progress.hard_mode
	grid = GridContainer.new()
	grid.columns = 2
	grid.position = GRID_POS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	back_button = UIKit.add_back_button(self)
	hint_label = UIKit.make_label(HINT if not Progress.maps_hint_seen else "", 8, UIKit.TEXT_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(48, 167)
	hint_label.size = Vector2(216, 10)
	add_child(hint_label)
	if not Progress.maps_hint_seen:  # once: the first time the table is opened
		Progress.maps_hint_seen = true
		Progress.save_progress()
	hard_box = CheckBox.new()
	hard_box.material = UIKit.text_material()
	hard_box.text = "HARD"
	hard_box.button_pressed = hard
	hard_box.toggled.connect(func(on: bool) -> void:
		hard = on
		_fill_grid())
	hard_box.position = Vector2(270, 164)
	add_child(hard_box)
	_build_view()
	_fill_grid()
	_focus_tile(Progress.current_level)


## (Re)builds the 10 tiles for the current mode.
func _fill_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	for level in range(1, Levels.COUNT + 1):
		tiles.append(_make_tile(level))
	# Two columns read top to bottom: 1-5 on the left, 6-10 on the right (the grid fills row by row).
	var rows := (Levels.COUNT + 1) / 2
	for i in Levels.COUNT:
		grid.add_child(tiles[(i % 2) * rows + i / 2])
	if skin_text:
		skin_text.recolor.call_deferred()


## The tile of `level`: survey thumbnail, name and "NN%"; locked (a lock, 0%) until a run there has
## been recorded.
func _make_tile(level: int) -> Button:
	var button := UIKit.make_button("", func() -> void: open_view(level), TILE_SIZE)
	var survey: Dictionary = Progress.survey_for(level, hard)
	var maze: Dictionary = Levels.story_maze(level, hard) if not survey.is_empty() else {}
	var locked := survey.is_empty() or not Survey.fits(survey, maze)
	button.disabled = locked
	button.set_meta("level", level)
	var thumb_box := Control.new()
	thumb_box.position = THUMB_POS
	thumb_box.size = Vector2(MapView.THUMB)
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(thumb_box)
	var well := ColorRect.new()  # the thumbnail's dark well
	well.color = MapView.FOG
	well.size = Vector2(MapView.THUMB)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.add_child(well)
	var name_label := UIKit.make_label(Themes.display_name(Themes.for_level(level)), 8, UIKit.TEXT_OFF if locked else UIKit.TEXT)
	name_label.position = Vector2(43, 3)
	button.add_child(name_label)
	var percent := 0 if locked else roundi(Survey.completeness(survey, maze) * 100.0)
	button.set_meta("percent", percent)
	var percent_label := UIKit.make_label("%d%%" % percent, 8, UIKit.TEXT_OFF if locked else (UIKit.GOLD if percent >= 100 else UIKit.TEXT_DIM))
	percent_label.position = Vector2(43, 14)
	button.add_child(percent_label)
	if locked:
		var lock := UIKit.make_icon("lock", UIKit.TEXT_OFF)
		lock.position = (Vector2(MapView.THUMB) - Vector2(8, 8)) / 2.0
		thumb_box.add_child(lock)
		return button
	var image := MapView.thumbnail(maze, survey, _goo, Themes.for_level(level) if themed else "")
	var thumb := TextureRect.new()
	thumb.texture = ImageTexture.create_from_image(image)
	thumb.position = ((Vector2(MapView.THUMB) - Vector2(image.get_size())) / 2.0).floor()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.add_child(thumb)
	return button


func _focus_tile(level: int) -> void:
	var target: Button = null
	for tile in tiles:
		if not tile.disabled and (target == null or tile.get_meta("level") == level):
			target = tile
	if target:
		target.grab_focus()
	else:
		back_button.grab_focus()


func _build_view() -> void:
	view_root = Control.new()
	view_root.visible = false
	add_child(view_root)
	view_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()  # opaque: the select and the drifting backdrop stay hidden behind it
	cover.color = UIKit.BG
	view_root.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_area = ColorRect.new()
	view_area.color = MapView.FOG
	view_area.position = Vector2(MAP_AREA.position)
	view_area.size = Vector2(MAP_AREA.size)
	view_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_root.add_child(view_area)
	view_title = UIKit.make_label("", 8, UIKit.GOLD)
	view_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_title.position = Vector2(0, 3)
	view_title.size = Vector2(320, 10)
	view_root.add_child(view_title)
	view_map = TextureRect.new()
	view_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_root.add_child(view_map)
	view_line = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	view_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_line.position = Vector2(48, 167)
	view_line.size = Vector2(224, 10)
	view_root.add_child(view_line)
	view_back = UIKit.make_button("BACK", close_view, Vector2(40, 13))
	view_back.position = Vector2(4, 164)
	view_root.add_child(view_back)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # the select's tiles stay out of reach
		view_back.set_focus_neighbor(side, view_back.get_path_to(view_back))
	view_back.focus_next = view_back.get_path_to(view_back)  # Tab / Shift+Tab too
	view_back.focus_previous = view_back.get_path_to(view_back)


## Shows the map of `level` (current mode). Does nothing for a locked level.
func open_view(level: int) -> void:
	var survey: Dictionary = Progress.survey_for(level, hard)
	if survey.is_empty():
		return
	var maze := Levels.story_maze(level, hard)
	if not Survey.fits(survey, maze):
		return
	var coins: Array[Vector2i] = []
	if not hard:
		for cell in Levels.story_coin_cells(level):
			if Progress.has_coin(level, cell):
				coins.append(cell)
	var theme := Themes.for_level(level) if themed else ""
	var sizes := MapView.layout(maze.cells, MAP_AREA.size, themed)
	var image := MapView.render(maze, survey, sizes, coins, _goo, theme)
	view_area.color = MapView.palette(_goo, theme).fog
	view_map.texture = ImageTexture.create_from_image(image)
	view_map.size = Vector2(image.get_size())
	view_map.position = Vector2(MAP_AREA.position + (MAP_AREA.size - image.get_size()) / 2)
	view_title.text = Themes.display_name(Themes.for_level(level)) + ("  HARD" if hard else "")
	view_line.text = "%d%% UNCOVERED" % roundi(Survey.completeness(survey, maze) * 100.0)
	viewing = true
	viewed_level = level
	view_root.visible = true
	view_back.grab_focus()
	if _focus_lock.is_empty():  # the hidden select (tiles, HARD, BACK) can't take focus meanwhile
		_focus_lock = UIKit.lock_focus(self, view_root)
	skin_text.recolor.call_deferred()


func close_view() -> void:
	if not viewing:
		return
	viewing = false
	view_root.visible = false
	view_map.texture = null
	UIKit.unlock_focus(_focus_lock)
	_focus_tile(viewed_level)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if viewing:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -6.0)
		close_view()
	else:
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
