extends Node

## Trailer graphics in the game's own look (the slimy pixel font with its drip shader, the logo, the
## skins screen's try-on stage). Two jobs, picked by the user args:
##   --captions=FILE.json  renders every caption overlay listed in FILE (written by
##                         tools/trailer/trailer.py) as a transparent PNG on the vertical canvas
##                         (Canvas.SIZE, 270x480 = 1080x1920 / 4), then quits. Needs a window
##                         (not --headless): the text is drawn by the GPU.
##   --card                the end card at 360x640 (= 1080x1920 / 3, so the 303 px logo fits),
##                         its frames saved to --frames-dir (see _build_card): the logo in the skin's colors, the slime
##                         acting out its loop, the tagline, CTA and an optional store line.
##                         --skin=ID (a Progress flag) and --jelly dress it; --tagline=,
##                         --cta=, --store= set the text ("|" = new line); --logo=N picks the logo variant.
## Colors in captions: "skin" (the equipped skin's color), "white", "gold", or "#rrggbb".

const CAPTION_SIZE := Vector2i(270, 480)
const CARD_SIZE := Vector2i(360, 640)
const LINE_BIG := 22   # 16 px font: 14 px letters + drips + gap
const LINE_SMALL := 12

var _opts := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=", true, 1)
			_opts[kv[0]] = kv[1]
		elif arg.begins_with("--"):
			_opts[arg.trim_prefix("--")] = "1"
	Progress.saving_enabled = false
	if _opts.has("jelly"):
		Progress.set_jelly(true)
	if _opts.has("captions"):
		_render_captions.call_deferred(String(_opts.captions))
	else:
		_build_card.call_deferred()


# ------------------------------------------------------------------ colors

static func color_of(name: String) -> Color:
	match name:
		"", "white":
			return UIKit.TEXT
		"gold":
			return UIKit.GOLD
		"skin":
			return _readable(Progress.skin_color())
	if name.begins_with("#"):
		return Color.html(name)
	var preset := Skins.get_preset(name)
	if not preset.is_empty():
		return _readable(preset.color)
	return UIKit.TEXT


## Skin colors as text on the dark canvas: the dark ones (INKKY, OCEAN) lifted so they read.
static func _readable(c: Color) -> Color:
	return c.lightened(0.45) if c.get_luminance() < 0.35 else c


# ------------------------------------------------------------------ captions

func _render_captions(path: String) -> void:
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var view := _make_view(CAPTION_SIZE, true)
	for job: Dictionary in jobs:
		for child in view.get_children():
			child.queue_free()
		await get_tree().process_frame
		_draw_caption(view, job)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := view.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		_outline(img)
		img.save_png(String(job.out))
		print("caption ", job.out)
	get_tree().quit()


func _make_view(size: Vector2i, transparent: bool) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = transparent
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	add_child(view)
	return view


## One overlay, laid over full-screen gameplay: `lines` (16 px text) and `sub` (8 px text) in
## `color`, starting at y = `at` ("top" = TOP_Y, "low" = LOW_Y, or a number), centred in the column
## `left`..`left + width`. The defaults keep it inside the phones' safe area: below the status bar,
## left of the right-hand button rail (~15%), above the bottom ~20% (caption, likes, progress bar).
## _outline() then gives it a dark outline and drop shadow so it reads over any background.
const TOP_Y := 34      # 136 px on the 1080x1920 frame
const LOW_Y := 300     # the block must end above 384 (80% of 480)
const SAFE_BOTTOM := 384


func _draw_caption(view: SubViewport, job: Dictionary) -> void:
	var root := Control.new()
	root.size = Vector2(CAPTION_SIZE)
	view.add_child(root)
	var lines: Array = job.get("lines", [])
	var sub: Array = job.get("sub", [])
	var block_h := lines.size() * LINE_BIG + sub.size() * LINE_SMALL
	var at = job.get("at", "top")
	var y := float(at) if (at is float or at is int) else float(LOW_Y if at == "low" else TOP_Y)
	y = minf(y, SAFE_BOTTOM - block_h)
	var left := float(job.get("left", 10))
	var width := float(job.get("width", 218))
	var color := color_of(String(job.get("color", "white")))
	var sub_color := color_of(String(job.get("sub_color", "white")))
	for text: String in lines:
		_line(root, text, UIKit.FONT_BIG, color, left, y, width)
		y += LINE_BIG
	for text: String in sub:
		_line(root, text, UIKit.FONT, sub_color, left, y, width)
		y += LINE_SMALL


const OUTLINE := Color(0.03, 0.03, 0.06, 1.0)
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)


## A 1 px dark outline all round the text (drips included), then a 1 px drop shadow down-right of
## that (2 px below), in caption pixels (x4 on screen).
static func _outline(img: Image) -> void:
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var area := used.grow(3).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var src := img.duplicate()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if src.get_pixel(x, y).a > 0.5:
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and ny >= 0 and nx < src.get_width() and ny < src.get_height() and src.get_pixel(nx, ny).a > 0.5:
						img.set_pixel(x, y, OUTLINE)
	var outlined := img.duplicate()
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if outlined.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]:
				var sx := x - d.x
				var sy := y - d.y
				if sx >= 0 and sy >= 0 and outlined.get_pixel(sx, sy).a > 0.5:
					img.set_pixel(x, y, SHADOW)
					break


func _line(root: Control, text: String, font_size: int, color: Color, left: float, y: float, width: float) -> Label:
	var label := UIKit.make_label(text, font_size, color)  # i18n: ignore (trailer text from tools/trailer/trailer.json)
	label.remove_from_group(SkinText.GROUP)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(left, roundf(y))
	label.size = Vector2(width, font_size + 4)
	root.add_child(label)
	return label


# ------------------------------------------------------------------ end card

## The movie writer records the 320x180 game viewport, so the card draws into its own 360x640
## SubViewport and saves each frame itself (--frames-dir=DIR: DIR/c00000000.png ...); the movie
## run still paces the frames and records the audio.
var _card_view: SubViewport
var _card_dir := ""
var _card_frame := 0


func _build_card() -> void:
	_card_dir = String(_opts.get("frames-dir", ""))
	_card_view = _make_view(CARD_SIZE, false)
	var root := Control.new()
	root.size = Vector2(CARD_SIZE)
	_card_view.add_child(root)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.size = Vector2(CARD_SIZE)
	root.add_child(bg)
	# Promo rule: never the RAINBOW / STOPWATCH skins in colour (docs/marketing/trailer.md).
	if Progress.selected_skin in [Skins.RAINBOW, Skins.STOPWATCH]:
		Progress.selected_skin = Skins.DEFAULT
	var skin := Progress.skin_color()
	var logo := TextureRect.new()
	logo.texture = load("res://scripts/ui/title.gd").logo_texture(int(_opts.get("logo", "0")))
	logo.material = Skins.make_material(skin, false)
	logo.position = Vector2(roundf((CARD_SIZE.x - logo.texture.get_width()) / 2.0), 170)
	root.add_child(logo)
	var stage := SkinShowcase.new()
	stage.position = Vector2(roundf((CARD_SIZE.x - SkinShowcase.STAGE_SIZE.x) / 2.0), 262)
	root.add_child(stage)
	stage.show_skin(skin, false, Progress.jelly)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: Sfx.play("unlock"))
	var y := 346.0
	for text: String in String(_opts.get("tagline", "")).split("|", false):
		_line(root, text, UIKit.FONT_BIG, UIKit.TEXT, 0, y, CARD_SIZE.x)
		y += LINE_BIG
	y += 14
	for text: String in String(_opts.get("cta", "")).split("|", false):
		_line(root, text, UIKit.FONT_BIG, color_of("skin"), 0, y, CARD_SIZE.x)
		y += LINE_BIG
	y += 6
	for text: String in String(_opts.get("store", "")).split("|", false):
		_line(root, text, UIKit.FONT, UIKit.TEXT_DIM, 0, y, CARD_SIZE.x)
		y += LINE_SMALL


func _process(_delta: float) -> void:
	if _card_view == null or _card_dir == "":
		return
	await RenderingServer.frame_post_draw
	_card_view.get_texture().get_image().save_png(_card_dir.path_join("c%08d.png" % _card_frame))
	_card_frame += 1
