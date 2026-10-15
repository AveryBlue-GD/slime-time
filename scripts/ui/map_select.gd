extends Control

## The MAP TABLE (opened at the hub's map table): the trail maps of the 10 story levels (Survey,
## recorded by real runs; see Progress.record_survey), normal or hard (the HARD switch only changes
## which maps are shown here, not the game's mode).
## - Select: goo-framed tiles like the level select's, two columns, each with a small picture, the
##   level's name and how much of its floor has been uncovered ("72%", gold at 100%). The picture is
##   NOT the real map: a tiny made-up example maze in the level's colors (MapView.preview), lit as far
##   as the real % uncovered, with a red example route once the level has a recorded route, a gold
##   frame at 100%; it gives nothing of the real layout away. A level never attempted (or whose
##   survey is of an older layout, Survey.fits) is locked: a sealed dark picture with a lock, dim
##   text, 0%. The first time the table is opened a short hint line explains it.
## - View: the player's real map (MapView: only what was seen, the route as a thin red line (the
##   last try dashed), found coins, the start, the goal once seen) under the level's name, with one
##   line below: "72% UNCOVERED". No times: the level select has those. The route is red whatever
##   the skin.
## PAPER (bottom right of the view, once a map paper is owned: Cosmetics, bought in the prize wheel's
## SHOP) cycles the owned papers (parchment first) and redraws the map in it; the choice is saved.
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
## The themed maps (each level's map and tile picture in its own palette with a themed frame,
## MapView's `theme`). The one switch: false = the plain parchment style everywhere.
const THEMED_MAPS := true

## Themed maps on this screen (THEMED_MAPS; the demo's --themed / --plain override it).
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
var view_paper: Button
## The select's controls kept out of focus while a map is viewed (UIKit.lock_focus).
var _focus_lock := {}


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "MAP TABLE")
	hard = Progress.hard_mode
	grid = GridContainer.new()
	grid.columns = 2
	grid.position = GRID_POS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	back_button = UIKit.add_back_button(self)
	# The bottom bar's line: centered on the screen (48..271, like the map view's), on BACK's baseline.
	hint_label = UIKit.add_label(self, HINT if not Progress.maps_hint_seen else "", Rect2(48, UIKit.BOTTOM_ROW_Y + 3, 224, 10),
		8, UIKit.TEXT_DIM)
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
	add_child(hard_box)
	# On the bottom row: its text on BACK's baseline, its ink ending EDGE from the right edge.
	hard_box.size = hard_box.get_combined_minimum_size()
	hard_box.position = Vector2(UIKit.SCREEN.x - UIKit.EDGE - hard_box.size.x, UIKit.BOTTOM_ROW_Y - 1)
	UIKit.add_touch_target(hard_box)
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


## The tile of `level`: the example picture (MapView.preview), name and "NN%"; locked (sealed, a lock,
## 0%) until a run there has been recorded. The picture never reads the survey's cells: only its %
## and whether it holds a route.
func _make_tile(level: int) -> Button:
	var button := UIKit.make_button("", func() -> void: open_view(level), TILE_SIZE)
	var survey: Dictionary = Progress.survey_for(level, hard)
	var maze: Dictionary = Levels.story_maze(level, hard) if not survey.is_empty() else {}
	var locked := survey.is_empty() or not Survey.fits(survey, maze)
	button.disabled = locked
	button.set_meta("level", level)
	var name_label := UIKit.make_label(Themes.display_name(Themes.for_level(level)), 8, UIKit.TEXT_OFF if locked else UIKit.TEXT)
	name_label.position = Vector2(43, 3)
	button.add_child(name_label)
	var percent := 0 if locked else roundi(Survey.completeness(survey, maze) * 100.0)
	button.set_meta("percent", percent)
	var percent_label := UIKit.make_label("%d%%" % percent, 8, UIKit.TEXT_OFF if locked else (UIKit.GOLD if percent >= 100 else UIKit.TEXT_DIM))
	percent_label.position = Vector2(43, 14)
	button.add_child(percent_label)
	var route := 0
	if not locked and not (survey.moves as PackedByteArray).is_empty():
		route = 2 if survey.clear else 1
	var texture := MapView.preview(level, hard, percent, route, locked, Themes.for_level(level) if themed else "")
	var thumb := TextureRect.new()
	thumb.texture = texture
	thumb.size = Vector2(texture.get_size())
	thumb.position = THUMB_POS + ((Vector2(MapView.THUMB) - Vector2(texture.get_size())) / 2.0).floor()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(thumb)
	if locked:
		var lock := UIKit.make_icon("lock", UIKit.TEXT_OFF)
		lock.position = ((thumb.size - Vector2(8, 8)) / 2.0).floor()
		thumb.add_child(lock)
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
	view_paper = UIKit.make_button("PAPER", cycle_paper, Vector2(44, 13))
	view_paper.position = Vector2(320 - 4 - 44, 164)
	view_root.add_child(view_paper)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		view_paper.set_focus_neighbor(side, view_paper.get_path_to(view_back if side in [SIDE_LEFT, SIDE_RIGHT] else view_paper))
	view_paper.focus_next = view_paper.get_path_to(view_back)
	view_paper.focus_previous = view_paper.get_path_to(view_back)


## The papers the player can draw maps on (the parchment, then the owned ones).
func owned_papers() -> Array[String]:
	var out: Array[String] = []
	for id in Cosmetics.paper_ids():
		if Progress.owns_cosmetic(id):
			out.append(id)
	return out


## PAPER: the next owned map paper (saved) and the map drawn again on it.
func cycle_paper() -> void:
	var papers := owned_papers()
	var next: String = papers[(papers.find(Progress.map_paper) + 1) % papers.size()]
	Progress.equip_cosmetic(next)
	if viewing:
		open_view(viewed_level)
		view_paper.grab_focus()


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
	var paper: String = Progress.map_paper if themed else ""
	var image := MapView.render(maze, survey, sizes, coins, theme, paper, Progress.skin_color())
	view_area.color = MapView.palette(theme, paper, Progress.skin_color()).fog
	view_map.texture = ImageTexture.create_from_image(image)
	view_map.size = Vector2(image.get_size())
	view_map.position = Vector2(MAP_AREA.position + (MAP_AREA.size - image.get_size()) / 2)
	view_title.text = Themes.display_name(Themes.for_level(level)) + ("  HARD" if hard else "")
	view_line.text = "%d%% UNCOVERED" % roundi(Survey.completeness(survey, maze) * 100.0)
	if paper != "" and paper != Cosmetics.DEFAULT_PAPER:
		view_line.text += "  " + Cosmetics.display_name(paper)
	# PAPER shows once a paper is owned; BACK and PAPER then lead to each other (and nowhere else).
	view_paper.visible = owned_papers().size() > 1 and themed
	var to_paper := view_back.get_path_to(view_paper if view_paper.visible else view_back)
	view_back.set_focus_neighbor(SIDE_RIGHT, to_paper)
	view_back.set_focus_neighbor(SIDE_LEFT, to_paper)
	view_back.focus_next = to_paper
	view_back.focus_previous = to_paper
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
