extends Control

## The MAP TABLE (opened at the hub's map table): the trail maps of the 10 story levels (Survey,
## recorded by real runs; see Progress.record_survey), normal or hard (the HARD switch only changes
## which maps are shown here, not the game's mode).
## - Select: goo-framed tiles like the level select's, two columns: a thumbnail of the survey, the
##   level's name, its number, how much of its floor has been seen and its route marker (a gold drop
##   and the best clear's time, or a dim drop and LAST TRY). A level never attempted (or whose survey
##   is of an older layout, Survey.fits) is locked: NO SURVEY YET. The first time the table is opened
##   a hint line explains it. The route's time is shown only when it is the level's record (`route_text`):
##   a record set before the maps existed is faster than any route recorded since, so then the
##   tile just says ROUTE and the view SET A NEW BEST, and the two screens never disagree.
## - View: the whole map (MapView: only what was seen, the route, found coins, the start, the goal
##   once seen) under the level's title, with its survey % and route below.
## BACK / Esc / B (ui_cancel) go from the view back to the select, and from the select to the hub
## (which turns to face the table). Keyboard/controller focus moves over the tiles as in the other
## menus; touch taps the tiles and BACK. Nothing moves (Reduce Motion needs nothing) and nothing is
## built per frame: thumbnails and the map are drawn into images once, when shown.

const TILE_SIZE := Vector2(156, 26)
const GRID_POS := Vector2(3, 21)
const THUMB_POS := Vector2(4, 3)
## Where the map may be drawn in the view.
const MAP_AREA := Rect2i(4, 14, 312, 146)
const HINT := "YOUR RUNS DRAW THESE MAPS"

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
	hint_label.position = Vector2(46, 167)
	hint_label.size = Vector2(200, 10)
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


## The tile of `level`: survey thumbnail, name, and "L# NN%" with the route marker; locked (NO SURVEY
## YET) until a run there has been recorded.
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(43, 14)
	button.add_child(row)
	if locked:
		var lock := UIKit.make_icon("lock", UIKit.TEXT_OFF)
		lock.position = (Vector2(MapView.THUMB) - Vector2(8, 8)) / 2.0
		thumb_box.add_child(lock)
		row.add_child(UIKit.make_label("L%d NO SURVEY YET" % level, 8, UIKit.TEXT_OFF))
		return button
	var image := MapView.thumbnail(maze, survey, _goo)
	var thumb := TextureRect.new()
	thumb.texture = ImageTexture.create_from_image(image)
	thumb.position = ((Vector2(MapView.THUMB) - Vector2(image.get_size())) / 2.0).floor()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.add_child(thumb)
	var percent := roundi(Survey.completeness(survey, maze) * 100.0)
	button.set_meta("percent", percent)
	row.add_child(UIKit.make_label("L%d %d%%" % [level, percent], 8, UIKit.TEXT_DIM))
	row.add_child(UIKit.make_icon("drop", UIKit.GOLD if survey.clear else UIKit.TEXT_OFF))  # the route marker
	var best := route_best(level, survey)
	if not survey.clear:
		row.add_child(UIKit.make_label("LAST TRY", 8, UIKit.TEXT_DIM))
	elif best >= 0.0:
		row.add_child(UIKit.make_label(UIKit.format_time(best), 8, UIKit.GOLD))
	else:
		row.add_child(UIKit.make_label("ROUTE", 8, UIKit.TEXT_DIM))
	return button


## The time to show for a survey's clear route: the level's record when the route is that record
## (the same value the level select shows, so the two screens never disagree), else -1: the record is
## faster (set before the maps existed, or by a run not recorded on the map).
func route_best(level: int, survey: Dictionary) -> float:
	if not survey.get("clear", false):
		return -1.0
	var record: float = Progress.record_for(level, hard)
	if record < 0.0:
		return survey.best_ms / 1000.0
	return record if absi(roundi(record * 1000.0) - int(survey.best_ms)) <= 1 else -1.0


## The view's route text: BEST ROUTE and the record, the route's own time with SET A NEW BEST when the
## record is faster (see route_best), or LAST TRY.
func route_text(level: int, survey: Dictionary) -> String:
	if not survey.get("clear", false):
		return "LAST TRY"
	var best := route_best(level, survey)
	if best >= 0.0:
		return "BEST ROUTE " + UIKit.format_time(best)
	return "ROUTE %s  SET A NEW BEST" % UIKit.format_time(survey.best_ms / 1000.0)


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
	var area := ColorRect.new()
	area.color = MapView.FOG
	area.position = Vector2(MAP_AREA.position)
	area.size = Vector2(MAP_AREA.size)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_root.add_child(area)
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
	view_line.size = Vector2(268, 10)
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
	var sizes := MapView.layout(maze.cells, MAP_AREA.size)
	var image := MapView.render(maze, survey, sizes, coins, _goo)
	view_map.texture = ImageTexture.create_from_image(image)
	view_map.size = Vector2(image.get_size())
	view_map.position = Vector2(MAP_AREA.position + (MAP_AREA.size - image.get_size()) / 2)
	view_title.text = "LEVEL %d  %s%s" % [level, Themes.display_name(Themes.for_level(level)), "  HARD" if hard else ""]
	var percent := roundi(Survey.completeness(survey, maze) * 100.0)
	view_line.text = "SURVEY %d%%   %s" % [percent, route_text(level, survey)]
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
