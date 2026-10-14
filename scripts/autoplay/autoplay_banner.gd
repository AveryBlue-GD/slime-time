class_name AutoplayBanner
extends CanvasLayer

## The --autoplay status strip in the bottom-right corner: a dim band just as wide as its one or
## two lines of the dripping pixel font, right-aligned (clear of the BACK / PLAY button in the
## menus). During a run it shows two lines (`AUTOPLAY  NORMAL L3  COINS 9/14  ATTEMPT 2` over the
## campaign totals); with buttons on screen (result choices, menus) only the first line, under the
## buttons (y 168+). `at_top` moves it to the top-right corner (the hub, whose prompt is at the bottom).

const MARGIN := 4
const LINE_Y := [160, 170]
const TOP_LINE_Y := [4, 14]
const BAND_ALPHA := 0.55

var band: ColorRect
var edge: ColorRect
var lines: Array[Label] = []


func _ready() -> void:
	layer = 110  # over the HUD, menus and the goo wipe (always readable)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	band = ColorRect.new()
	band.color = Color(UIKit.BG, BAND_ALPHA)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	edge = ColorRect.new()  # a 1 px goo line on top of the band
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edge)
	for i in 2:
		var label := UIKit.make_label("", 8, UIKit.TEXT if i == 0 else UIKit.TEXT_DIM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.position = Vector2(MARGIN, LINE_Y[i])
		label.size = Vector2(320 - MARGIN * 2, 9)
		root.add_child(label)
		lines.append(label)
	show_lines("AUTOPLAY", "")


## Shows `first` (status) and `second` (totals); `second` == "" = one line (low down at the bottom).
func show_lines(first: String, second: String, at_top := false) -> void:
	var two := second != ""
	lines[0].text = first
	lines[1].text = second
	lines[1].visible = two
	var top: float
	if at_top:
		lines[0].position.y = TOP_LINE_Y[0]
		lines[1].position.y = TOP_LINE_Y[1]
		top = 0.0
	else:
		lines[0].position.y = LINE_Y[0] if two else LINE_Y[1]
		lines[1].position.y = LINE_Y[1]
		top = (LINE_Y[0] if two else LINE_Y[1]) - 3
	var bottom: float = (TOP_LINE_Y[1 if two else 0] + 12) if at_top else 180.0
	var width: float = maxi(text_width(first), text_width(second) if two else 0) + MARGIN * 3
	band.position = Vector2(320 - width, top)
	band.size = Vector2(width, bottom - top)
	edge.position = Vector2(320 - width, bottom if at_top else top - 1)
	edge.size = Vector2(width, 1)
	var progress := get_node_or_null("/root/Progress")
	edge.color = Color(Skins.shades(progress.skin_color()).mid if progress else UIKit.GOLD, 0.8)

## Width in px of `text` in the 8 px pixel font (letters advance 6 px, spaces 4).
static func text_width(text: String) -> int:
	var spaces := text.count(" ")
	return (text.length() - spaces) * 6 + spaces * 4
