extends Node

## Renders the itch.io cover: a level being played by the autopilot, with the logo on top and a
## tagline at the bottom, drawn into its own 315x250 SubViewport and saved as a PNG after
## CAPTURE_FRAME frames (tools/promo/make_promo.ps1 upscales it 2x to 630x500).
## Pass `-- --out=<file.png>` (plus any skin debug flags, and optionally --cover-level=N) when
## running it.

const SIZE := Vector2i(315, 250)
## Any level from 3 up is tall enough (272+ px) to fill the 250 px cover.
const DEFAULT_LEVEL := 7
## Frames of autopilot play before the picture is taken (--cover-frame=N to change).
const CAPTURE_FRAME := 420

var view: SubViewport
var frame := 0
var out_path := "user://cover.png"
var level := DEFAULT_LEVEL
var capture_frame := CAPTURE_FRAME


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--cover-level="):
			level = arg.trim_prefix("--cover-level=").to_int()
		elif arg.begins_with("--cover-frame="):
			capture_frame = arg.trim_prefix("--cover-frame=").to_int()
	view = SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	add_child(view)

	var game: Node2D = preload("res://scenes/main.tscn").instantiate()
	game.level = level
	view.add_child(game)
	game.hud.visible = false
	game.add_child(preload("res://tests/autopilot.gd").new())

	var overlay := Control.new()
	overlay.size = Vector2(SIZE)
	overlay.z_index = 100
	var layer := CanvasLayer.new()
	layer.layer = 30
	view.add_child(layer)
	layer.add_child(overlay)
	var logo := TextureRect.new()
	logo.texture = load("res://scripts/ui/title.gd").logo_texture(0)  # a fixed variant: the cover looks the same every render
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	logo.position = Vector2(roundf((SIZE.x - logo.texture.get_width()) / 2.0), 4)
	overlay.add_child(logo)
	var band := ColorRect.new()
	band.color = Color(UIKit.BG, 0.8)
	band.position = Vector2(0, SIZE.y - 18)
	band.size = Vector2(SIZE.x, 18)
	overlay.add_child(band)
	var tagline := UIKit.make_label("LEAP!  SPLAT!  ESCAPE THE FOG!", 8, UIKit.GOLD)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(0, SIZE.y - 14)
	tagline.size = Vector2(SIZE.x, 10)
	overlay.add_child(tagline)
	layer.add_child(SkinText.new())


func _process(_delta: float) -> void:
	frame += 1
	if frame == capture_frame:
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(out_path)
		print("saved cover to ", out_path)
		get_tree().quit()
