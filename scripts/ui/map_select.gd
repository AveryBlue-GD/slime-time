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
## Other languages (docs/ui-rules.md section 10): the tiles grow with the locale's lines (the name
## under the accents' room, two lines for a name longer than the tile, the % under it), the grid starts
## under title_bottom, and when five rows no longer fit above the bottom row the tiles go on two pages
## (three rows, then two; < and > beside the title flip them). The bottom row's line and HARD keep
## BACK's text line; the view's name line and the map area follow the line height, its BACK / PAPER
## their text. While a map is viewed the select behind the opaque view is hidden. English: unchanged.

## Two columns of tiles 2 apart, EDGE (4) from both screen edges.
const TILE_SIZE := Vector2(155, 26)
const GRID_POS := Vector2(4, 21)
const THUMB_POS := Vector2(4, 3)
## Where the map may be drawn in the view.
const MAP_AREA := Rect2i(2, 13, 316, 149)
## The themed maps (each level's map and tile picture in its own palette with a themed frame,
## MapView's `theme`). The one switch: false = the plain parchment style everywhere.
const THEMED_MAPS := true
## The tile text's left edge (after the picture) and the room kept right of it.
const TEXT_X := 43
const TEXT_PAD := 4
## Rows of tiles in the English layout, the page arrows' width.
const ROWS := 5
const PAGER_W := 20
## Between the grid's last row and the bottom row (English: 159 -> 164).
const BOTTOM_GAP := 5
const LevelSelect := preload("res://scripts/ui/level_select.gd")

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
## Where the map may be drawn (MAP_AREA in English; see view_map_area).
var map_area := MAP_AREA
## The select's controls kept out of focus while a map is viewed (UIKit.lock_focus).
var _focus_lock := {}
## The tiles' size and the rows of a page (TILE_SIZE and ROWS in English: one page).
var tile_size := TILE_SIZE
var rows_per_page := ROWS
var pages := 1
var page := 0
var page_prev: Button
var page_next: Button
## The name's top, its lines, the %'s top in a tile.
var _name_y := 3
var _name_lines := 1
var _percent_y := 3 + UIKit.DENSE_PITCH
## The select's controls hidden while a map is viewed.
var _hidden: Array[CanvasItem] = []


static func hint_text() -> String:
	# i18n: first-visit hint at the bottom, max 224px, 1 line
	return Loc.t("maps.hint", "PLAY TO FILL THEM IN")


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, Loc.t("maps.title", "MAP TABLE"))  # i18n: max 296px, 16 px font
	hard = Progress.hard_mode
	_layout_tiles()
	grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(GRID_POS.x, UIKit.title_bottom() - 1)  # GRID_POS: the title's shadow row
	grid.add_theme_constant_override("h_separation", UIKit.GAP_XS)
	grid.add_theme_constant_override("v_separation", UIKit.GAP_XS)
	add_child(grid)
	back_button = UIKit.add_back_button(self)
	# The bottom bar's line: centered on the screen (48..271, like the map view's), on BACK's baseline.
	hint_label = UIKit.add_label(self, hint_text() if not Progress.maps_hint_seen else "", bottom_line_rect(back_button),
		8, UIKit.TEXT_DIM)
	if not Progress.maps_hint_seen:  # once: the first time the table is opened
		Progress.maps_hint_seen = true
		Progress.save_progress()
	hard_box = CheckBox.new()
	hard_box.material = UIKit.text_material()
	# i18n: checkbox, max 60px, 1 line
	hard_box.text = Loc.t("maps.hard", "HARD")
	hard_box.button_pressed = hard
	hard_box.toggled.connect(func(on: bool) -> void:
		hard = on
		_fill_grid())
	add_child(hard_box)
	# On the bottom row: its text on BACK's baseline, its ink ending EDGE from the right edge.
	hard_box.size = hard_box.get_combined_minimum_size()
	hard_box.position = Vector2(UIKit.SCREEN.x - UIKit.EDGE - hard_box.size.x,
		text_line_y() - floorf((hard_box.size.y - UIKit.line_h()) / 2.0))
	UIKit.add_touch_target(hard_box)
	_build_view()
	if pages > 1:
		_add_pager()
	_fill_grid()
	_focus_tile(Progress.current_level)


## Wraps `label` (in the themed tree) to `box`: set once there, as a label sized before it keeps the
## default font's (or the unwrapped text's) larger minimum size.
static func wrap_label(label: Label, box: Vector2) -> void:
	label.autowrap_mode = UIKit.autowrap_mode()
	label.update_minimum_size()
	label.size = box


## The top of the bottom row's text line: BACK's text (BOTTOM_ROW_Y + 3 in English).
static func text_line_y() -> int:
	return UIKit.bottom_row_y() + UIKit.button_v_margins().x


## The bottom row's centred line (the hint, the view's % line): from GAP_M right of BACK to as far from
## the right edge, on BACK's text line (48..272 on row 167, 10 tall in English).
static func bottom_line_rect(back: Control) -> Rect2:
	var x := back.position.x + back.size.x + UIKit.GAP_M
	return Rect2(x, text_line_y(), UIKit.SCREEN.x - 2.0 * x, UIKit.line_h() + 3)


## The tiles' inside (the name under the accents' room, one or two lines, the % under it), their height,
## and the rows per page: five (one page) when they fit between the title and the bottom row, else
## balanced pages (three rows, then two).
func _layout_tiles() -> void:
	_name_y = 3 + LevelSelect.accent_room()
	var room := TILE_SIZE.x - TEXT_X - TEXT_PAD
	_name_lines = 1
	for level in range(1, Levels.COUNT + 1):
		if UIKit.text_w(Themes.display_name(Themes.for_level(level))) > room:
			_name_lines = 2
	_percent_y = _name_y + (_name_lines - 1) * UIKit.line_pitch() + UIKit.dense_pitch()
	tile_size = Vector2(TILE_SIZE.x, maxf(TILE_SIZE.y, _percent_y + TILE_SIZE.y - 3 - UIKit.DENSE_PITCH))
	# From the grid's top to BOTTOM_GAP over the bottom row (138 px in English: five rows exactly).
	var area := UIKit.bottom_row_y() - BOTTOM_GAP - (UIKit.title_bottom() - 1)
	var fit := UIKit.grid_budget(Levels.COUNT, 2, area, tile_size.y, UIKit.GAP_XS)
	pages = fit.pages
	rows_per_page = ceili(ROWS / float(pages))


## The page arrows (paged only): < at the left edge and > at the right, centred on the title's line.
func _add_pager() -> void:
	page_prev = UIKit.make_button("<", func() -> void: _flip(-1), Vector2(PAGER_W, UIKit.button_h()))
	page_prev.name = "PagePrev"
	page_next = UIKit.make_button(">", func() -> void: _flip(1), Vector2(PAGER_W, UIKit.button_h()))
	page_next.name = "PageNext"
	for arrow: Button in [page_prev, page_next]:
		add_child(arrow)  # (last: the other nodes keep their places; hidden with the select under the view)
		LevelSelect.use_plain_font(arrow)
	var y := LevelSelect.pager_y()
	page_prev.position = Vector2(UIKit.EDGE, y)
	page_next.position = Vector2(UIKit.SCREEN.x - UIKit.EDGE - PAGER_W, y)


func _flip(step: int) -> void:
	var arrow := page_prev if step < 0 else page_next
	_show_page(page + step)
	if arrow.disabled:  # the last page that way: the focus goes to its first tile
		for tile in tiles:
			if tile.visible and not tile.disabled:
				tile.grab_focus()
				break


## The levels on page `index`, in reading order: the left column top to bottom, then the right.
func page_levels(index: int) -> Array[int]:
	var per := rows_per_page * 2
	var out: Array[int] = []
	for level in range(index * per + 1, mini((index + 1) * per, Levels.COUNT) + 1):
		out.append(level)
	return out


## Shows page `index`: its tiles in the grid (row by row: left = the first half, right = the rest), the
## others hidden. One page: every tile, 1-5 on the left and 6-10 on the right.
func _show_page(index: int) -> void:
	page = clampi(index, 0, pages - 1)
	var levels := page_levels(page)
	var rows := ceili(levels.size() / 2.0)
	for tile in tiles:
		tile.visible = (tile.get_meta("level") as int) in levels
	for i in levels.size():
		var at := (i % 2) * rows + i / 2  # the grid fills row by row
		if at < levels.size():
			grid.move_child(tiles[levels[at] - 1], i)
	if page_prev:
		page_prev.disabled = page == 0
		page_next.disabled = page == pages - 1


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
	if _name_lines > 1:  # a name longer than the tile wraps (every tile keeps room for two lines)
		for tile in tiles:
			wrap_label(tile.get_meta("name_label"), Vector2(TILE_SIZE.x - TEXT_X - TEXT_PAD, UIKit.text_block_h(2)))
	if pages > 1:
		_show_page(page)
	if skin_text:
		skin_text.recolor.call_deferred()


## The tile of `level`: the example picture (MapView.preview), name and "NN%"; locked (sealed, a lock,
## 0%) until a run there has been recorded. The picture never reads the survey's cells: only its %
## and whether it holds a route.
func _make_tile(level: int) -> Button:
	var button := UIKit.make_button("", func() -> void: open_view(level), tile_size)
	var survey: Dictionary = Progress.survey_for(level, hard)
	var maze: Dictionary = Levels.story_maze(level, hard) if not survey.is_empty() else {}
	var locked := survey.is_empty() or not Survey.fits(survey, maze)
	button.disabled = locked
	button.set_meta("level", level)
	var name_label := UIKit.make_label(Themes.display_name(Themes.for_level(level)), 8, UIKit.TEXT_OFF if locked else UIKit.TEXT)
	name_label.position = Vector2(TEXT_X, _name_y)
	button.add_child(name_label)
	button.set_meta("name_label", name_label)
	var percent := 0 if locked else roundi(Survey.completeness(survey, maze) * 100.0)
	button.set_meta("percent", percent)
	var percent_label := UIKit.make_label("%d%%" % percent, UIKit.FONT, UIKit.TEXT_OFF if locked else (UIKit.GOLD if percent >= 100 else UIKit.TEXT_DIM))
	percent_label.position = Vector2(TEXT_X, _percent_y)  # the dense two-line pitch under the name
	button.add_child(percent_label)
	LevelSelect.use_plain_font(percent_label)
	var route := 0
	if not locked and not (survey.moves as PackedByteArray).is_empty():
		route = 2 if survey.clear else 1
	var texture := MapView.preview(level, hard, percent, route, locked, Themes.for_level(level) if themed else "")
	var thumb := TextureRect.new()
	thumb.texture = texture
	thumb.size = Vector2(texture.get_size())
	thumb.position = THUMB_POS + ((Vector2(MapView.THUMB) - Vector2(texture.get_size())) / 2.0).floor() \
		+ Vector2(0, floorf((tile_size.y - TILE_SIZE.y) / 2.0))  # (centred on a taller tile)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(thumb)
	if locked:
		var lock := UIKit.make_icon("lock", UIKit.TEXT_OFF)
		lock.position = ((thumb.size - Vector2(8, 8)) / 2.0).floor()
		thumb.add_child(lock)
	return button


func _focus_tile(level: int) -> void:
	if pages > 1:
		for i in pages:
			if level in page_levels(i):
				_show_page(i)
	var target: Button = null
	for tile in tiles:
		if tile.visible and not tile.disabled and (target == null or tile.get_meta("level") == level):
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
	map_area = view_map_area()
	view_area.position = Vector2(map_area.position)
	view_area.size = Vector2(map_area.size)
	view_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_root.add_child(view_area)
	view_title = UIKit.make_label("", UIKit.FONT, UIKit.GOLD)
	view_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_title.position = Vector2(0, view_title_y())
	view_title.size = Vector2(320, UIKit.line_h() + 3)
	view_root.add_child(view_title)
	view_map = TextureRect.new()
	view_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_root.add_child(view_map)
	view_line = UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	view_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_root.add_child(view_line)
	# i18n: max 32px, 1 line
	view_back = UIKit.make_button(Loc.t("common.back", "BACK"), close_view, UIKit.back_size())
	view_root.add_child(view_back)
	UIKit.place_bottom_row(view_back, -1)
	var line := bottom_line_rect(view_back)
	view_line.position = line.position
	view_line.size = line.size
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # the select's tiles stay out of reach
		view_back.set_focus_neighbor(side, view_back.get_path_to(view_back))
	view_back.focus_next = view_back.get_path_to(view_back)  # Tab / Shift+Tab too
	view_back.focus_previous = view_back.get_path_to(view_back)
	# i18n: max 36px (44 wide, 4 px margins), 1 line
	var paper_text := Loc.t("maps.paper", "PAPER")
	view_paper = UIKit.make_button(paper_text, cycle_paper, Vector2(UIKit.button_w(paper_text, 44), UIKit.button_h()))
	view_root.add_child(view_paper)
	UIKit.place_bottom_row(view_paper, 1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		view_paper.set_focus_neighbor(side, view_paper.get_path_to(view_back if side in [SIDE_LEFT, SIDE_RIGHT] else view_paper))
	view_paper.focus_next = view_paper.get_path_to(view_back)
	view_paper.focus_previous = view_paper.get_path_to(view_back)


## The view's name line: 3 px from the top (lower by a Vietnamese capital's stacked marks).
static func view_title_y() -> int:
	return maxi(3, 1 + LevelSelect.accent_room())


## The map's area: 3 px under the name line to 2 px over the bottom row, 2 px from the sides
## (MAP_AREA in English).
static func view_map_area() -> Rect2i:
	var top := view_title_y() + UIKit.line_h() + 3
	return Rect2i(MAP_AREA.position.x, top, MAP_AREA.size.x, UIKit.bottom_row_y() - 2 - top)


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
	var sizes := MapView.layout(maze.cells, map_area.size, themed)
	var paper: String = Progress.map_paper if themed else ""
	var image := MapView.render(maze, survey, sizes, coins, theme, paper, Progress.skin_color())
	view_area.color = MapView.palette(theme, paper, Progress.skin_color()).fog
	view_map.texture = ImageTexture.create_from_image(image)
	view_map.size = Vector2(image.get_size())
	view_map.position = Vector2(map_area.position + (map_area.size - image.get_size()) / 2)
	var theme_name := Themes.display_name(Themes.for_level(level))
	var percent := roundi(Survey.completeness(survey, maze) * 100.0)
	# i18n: {name} = the level's theme name; the map's title, max 296px, 1 line. The double space is spacing.
	view_title.text = Loc.t("maps.view_title_hard", "{name}  HARD", {name = theme_name}) if hard else theme_name
	if paper != "" and paper != Cosmetics.DEFAULT_PAPER:
		# i18n: {percent} = 0-100 (the % sign is part of the string), {paper} = the map paper's name; max 296px, 1 line
		view_line.text = Loc.t("maps.uncovered_paper", "{percent}% UNCOVERED  {paper}", {percent = percent, paper = Cosmetics.display_name(paper)})
	else:
		# i18n: {percent} = 0-100; the line under the map, max 296px, 1 line
		view_line.text = Loc.t("maps.uncovered", "{percent}% UNCOVERED", {percent = percent})
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
		# ...and is hidden: the view is opaque over all of it (nothing on screen changes)
		for child in get_children():
			if child != view_root and child is CanvasItem and (child as CanvasItem).visible:
				(child as CanvasItem).visible = false
				_hidden.append(child)
	skin_text.recolor.call_deferred()


func close_view() -> void:
	if not viewing:
		return
	viewing = false
	view_root.visible = false
	view_map.texture = null
	for child in _hidden:
		if is_instance_valid(child):
			child.visible = true
	_hidden.clear()
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
