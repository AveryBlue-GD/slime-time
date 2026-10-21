class_name RandomMapView
extends Control

## The current random maze's map, opened from the MAP button after a dry-up in the randomizer
## (Game._offer_retry): every try at this maze so far drawn like a MAP TABLE map (MapView.render: the
## tiles seen, the last try's route dashed, the start ring; no coins, a random maze has none). It
## lives only as long as the maze does (Progress.random_map: gone once the maze is cleared, a new one
## is started or the player goes back to the hub; the view only says how much is explored). BACK (or Esc / B) closes it; focus stays inside
## while it's open and goes back where it was.

signal closed

const MARGIN := 8

var _back: Button
var _lock := {}
var _return_focus: Control


## Builds the view over the whole screen for `maze` and `survey` in `maze_theme` (the maze's own theme), on
## map paper `paper` in ink `ink` (the worn paper and skin color).
func open(maze: Dictionary, survey: Dictionary, maze_theme: String, paper: String, ink: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (all text goes through Loc)
	theme = UIKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cover := ColorRect.new()
	cover.color = UIKit.BG
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# i18n: random maze map view title, max 296px, 1 line
	var title := _label(Loc.t("random_map.title", "THIS MAZE SO FAR"), UIKit.GOLD, MARGIN)
	var percent := roundi(Survey.completeness(survey, maze) * 100.0)
	# i18n: random maze map view line, max 296px, 1 line; {percent} = share of the maze explored
	var line := _label(Loc.t("random_map.explored", "{percent}% EXPLORED", {percent = percent}), UIKit.TEXT_DIM, 0)
	_back = UIKit.add_back_button(self, close)
	line.position.y = _back.position.y - UIKit.GAP_M - UIKit.line_h()
	var top := title.position.y + UIKit.line_h() + UIKit.GAP_M
	var area := Vector2i(320 - 2 * MARGIN, int(line.position.y - UIKit.GAP_M - top))
	var sizes := MapView.layout(maze.cells, area, true)
	var image := MapView.render(maze, survey, sizes, [] as Array[Vector2i], maze_theme, paper, ink)
	var fog := ColorRect.new()
	fog.color = MapView.palette(maze_theme, paper, ink).fog
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.position = Vector2(MARGIN, top)
	fog.size = Vector2(area)
	add_child(fog)
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(image)
	map.material = MapView.flow_material(paper)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.size = Vector2(image.get_size())
	map.position = (Vector2(MARGIN, top) + (Vector2(area) - map.size) / 2.0).floor()
	add_child(map)
	_return_focus = get_viewport().gui_get_focus_owner()
	_lock = UIKit.lock_focus(get_tree().current_scene, self)
	_back.grab_focus()


func _label(text: String, color: Color, top: float) -> Label:
	return UIKit.add_label(self, text, Rect2(0, top, 320, maxi(10, UIKit.line_h())), UIKit.FONT, color)  # (in the tree first: centred)


## Closes the view and gives the focus back.
func close() -> void:
	if not is_inside_tree():
		return
	UIKit.unlock_focus(_lock)
	if is_instance_valid(_return_focus) and _return_focus.is_inside_tree():
		_return_focus.grab_focus()
	closed.emit()
	queue_free()


## Esc / B close it; the game's keys (pause, restart) do nothing underneath while it's open.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
