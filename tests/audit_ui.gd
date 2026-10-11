extends Node

## UI symmetry audit. Renders a screen into its own 320x180 SubViewport, then measures:
## - TEXT: for every centered label and every button with text, where its letters actually are
##   (bright pixels, measuring only the 7 px letter bodies, not the drips hanging below) and how
##   far they sit from the center of the label / button face, horizontally and vertically;
## - LAYOUT: every panel, button, grid and slider with its left / right margins on the screen.
## Prints one line per item; anything off by a pixel or more is marked "<<".
## Run (windowed, quietly):
## .\tools\screenshot.ps1 -Frames 40 -Scene res://tests/audit_ui.tscn -GameArgs --unlock-all,--audit=res://scenes/title.tscn
## Optional --audit-step=hats|custom|confirm|pause|prompt|win|dry opens a sub-view first.

const SIZE := Vector2i(320, 180)
const CAPTURE_FRAME := 25

var view: SubViewport
var screen: Node
var frame := 0
var target := "res://scenes/title.tscn"
var step := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit="):
			target = arg.trim_prefix("--audit=")
		elif arg.begins_with("--audit-step="):
			step = arg.trim_prefix("--audit-step=")
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps counting frames while a step pauses the game
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	add_child(view)
	screen = load(target).instantiate()
	if screen is Node2D:
		screen.level = 3
	view.add_child(screen)


func _process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		_open_step()
	if frame == CAPTURE_FRAME:
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		print("AUDIT %s %s" % [target, step])
		_audit(screen, image)
		get_tree().quit()


func _open_step() -> void:
	match step:
		"hats":
			screen.show_page("hats")
		"custom":
			screen._on_tile(Skins.CUSTOM)
		"solid":
			screen._toggle_jelly()
		"confirm":
			screen._ask_reset()
		"pause":
			screen.pause_menu.open()
		"prompt":
			screen.restart_prompt.open()
		"win":
			screen.hud.show_message("CHALICE CONSUMED!\nLEVEL 3 CLEARED\nTIME 0:13.6")
			screen.hud.show_record(13.6)
			screen.hud.show_choices([["REPLAY", func() -> void: pass], ["NEXT LEVEL", func() -> void: pass]])
		"dry":
			screen.hud.show_message("DRIED UP")
			screen.hud.show_choices([["RESTART", func() -> void: pass], ["UPGRADES", func() -> void: pass]], 0)


func _audit(node: Node, image: Image) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child is Control:
			_report(child, image)
		_audit(child, image)


func _report(c: Control, image: Image) -> void:
	var r := c.get_global_rect()
	if r.size.x >= SIZE.x - 1 and r.size.y >= SIZE.y - 1:
		return  # full-screen backgrounds
	var margins := "L%5.1f R%5.1f" % [r.position.x, SIZE.x - r.end.x]
	var kind := c.get_class()
	if c is Label and c.text != "" and c.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		print("TEXT  %-22s %s %s" % ["\"%s\"" % c.text.get_slice("\n", 0).left(20), _text_offsets(r, image, c), margins])
	elif c is Button and c.text != "":
		var face := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 3))  # inside the goo frame (2 px band on top and sides, 1 at the bottom)
		print("BTN   %-22s %s %s" % ["\"%s\"" % c.text.left(20), _text_offsets(face, image, c), margins])
	elif c is Panel or c is PanelContainer or c is GridContainer or c is HSlider or (c is Button and c.get_child_count() > 0) or c is CheckBox:
		var sym := absf(r.position.x - (SIZE.x - r.end.x))
		print("BOX   %-22s %s%s" % [kind, margins, "  <<" if sym >= 1.0 and not c is Button else ""])


## Horizontal and vertical offsets of the letter pixels from the center of `area`.
func _text_offsets(area: Rect2, image: Image, c: Control) -> String:
	var x0 := int(area.position.x)
	var y0 := int(area.position.y)
	var x1 := int(area.end.x) - 1
	var y1 := int(area.end.y) - 1
	var font_size: int = c.get_theme_font_size("font_size")
	var body := 7 * font_size / 8  # letter body height (drips hang below it)
	var bright := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y:
			return false
		var p := image.get_pixel(x, y)
		return p.get_luminance() > 0.42 and p.a > 0.5
	var top := -1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if bright.call(x, y):
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return "(no letters found)              "
	var left := 9999
	var right := -1
	for y in range(top, mini(top + body, y1 + 1)):
		for x in range(x0, x1 + 1):
			if bright.call(x, y):
				left = mini(left, x)
				right = maxi(right, x)
	var dx := ((left - x0) - (x1 - right)) / 2.0
	var dy := ((top - y0) - (y1 - (top + body - 1))) / 2.0
	var lines: int = c.text.count("\n") + 1 if c is Label else 1
	var flag := "  <<" if absf(dx) >= 1.0 or (lines == 1 and absf(dy) >= 1.0) else ""
	return "dx%+5.1f dy%+5.1f%s" % [dx, dy if lines == 1 else 0.0, flag]
