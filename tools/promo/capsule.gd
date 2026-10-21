extends Node

## Renders one piece of Steam store art or one Steam screenshot (docs/marketing/README.md, tools/promo/make_steam_art.sh): a level the
## autopilot plays, drawn `--zoom` px per game pixel and filling `--size`, with the logo (`--logo-scale`, 0 = none),
## the tagline (`--tagline`) and, for the demo app's art, the DEMO sticker (`--demo`). `--logo-only` draws just
## the logo on a transparent background (Steam's library logo). The PNG is saved at its final size after
## `--frame` frames, so no upscaling is needed afterwards.
## Flags after `--`: --out=<file.png> --size=W,H --zoom=N --logo-scale=N --logo-y=N --tagline --demo --logo-only --hud
## --cover-level=N --frame=N, plus the usual skin flags (--unlock-all --skin=...).
## Promo rules (docs/marketing/brief.md): each level in its own skin; never the RAINBOW / STOPWATCH skins in colour.

var size := Vector2i(920, 430)
var zoom := 2
var logo_scale := 1
## The logo's top edge in final pixels (-1 = a small margin, scaled).
var logo_y := -1
var tagline := false
var demo := false
var logo_only := false
## Show the game's HUD (Steam screenshots); capsules hide it.
var hud := false
var level := 7
var capture_frame := 420
var out_path := "user://capsule.png"

var view: SubViewport
var frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--out": out_path = value
			"--size": size = Vector2i(value.get_slice(",", 0).to_int(), value.get_slice(",", 1).to_int())
			"--zoom": zoom = maxi(1, value.to_int())
			"--logo-scale": logo_scale = value.to_int()
			"--logo-y": logo_y = value.to_int()
			"--tagline": tagline = true
			"--demo": demo = true
			"--logo-only": logo_only = true
			"--hud": hud = true
			"--cover-level": level = value.to_int()
			"--frame": capture_frame = value.to_int()
	if Progress.selected_skin in [Skins.RAINBOW, Skins.STOPWATCH]:
		Progress.selected_skin = Skins.skin_for_level(level - 1)
	view = SubViewport.new()
	view.size = size
	view.transparent_bg = logo_only
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	if logo_only:
		capture_frame = 5
	else:
		_add_game()
	_add_overlay()


## The level, in its own small viewport (size / zoom game pixels), shown `zoom` times larger.
func _add_game() -> void:
	var game_view := SubViewport.new()
	game_view.size = Vector2i(ceili(float(size.x) / zoom), ceili(float(size.y) / zoom))
	game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	game_view.snap_2d_transforms_to_pixel = true
	view.add_child(game_view)
	var game: Node2D = preload("res://scenes/main.tscn").instantiate()
	game.level = level
	game_view.add_child(game)
	game.hud.visible = hud
	game.add_child(preload("res://tests/autopilot.gd").new())
	var shown := TextureRect.new()
	shown.texture = game_view.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.scale = Vector2(zoom, zoom)
	view.add_child(shown)


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	view.add_child(layer)
	var overlay := Control.new()
	overlay.size = Vector2(size)
	layer.add_child(overlay)
	if logo_scale > 0:
		var logo := TextureRect.new()
		logo.texture = load("res://scripts/ui/title.gd").logo_texture(0)  # a fixed variant: the same every render
		logo.material = Skins.make_material(Progress.skin_color(), false)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.scale = Vector2(logo_scale, logo_scale)
		# Centred on its ink (the texture has a few clear columns), so a 2x logo fits a 600 px capsule.
		var ink := logo.texture.get_image().get_used_rect()
		var top := logo_y if logo_y >= 0 else 4 * logo_scale
		if logo_only:
			top = (size.y - logo.texture.get_height() * logo_scale) / 2
		logo.position = Vector2((size.x - ink.size.x * logo_scale) / 2 - ink.position.x * logo_scale, top)
		overlay.add_child(logo)
		if demo:
			var sticker: TextureRect = load("res://scripts/ui/title.gd").make_demo_sticker()
			sticker.material = Skins.make_material(Progress.skin_color(), false)
			(sticker.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)
			sticker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sticker.scale = Vector2(logo_scale, logo_scale)
			# Under the logo's left end, as on the demo's title (its top on the logo's drip rows).
			sticker.position = logo.position + Vector2(-4, 48) * logo_scale
			sticker.position.x = maxf(sticker.position.x, 2.0 * logo_scale)
			overlay.add_child(sticker)
	if tagline:
		var s := maxi(1, logo_scale)
		var band := ColorRect.new()
		band.color = Color(UIKit.BG, 0.8)
		band.size = Vector2(size.x, 18 * s)
		band.position = Vector2(0, size.y - band.size.y)
		overlay.add_child(band)
		var label := UIKit.make_label("LEAP!  SPLAT!  ESCAPE THE FOG!", 8, UIKit.GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(float(size.x) / s, 10)
		label.scale = Vector2(s, s)
		label.position = Vector2(0, size.y - 14 * s)
		overlay.add_child(label)
	layer.add_child(SkinText.new())


func _process(_delta: float) -> void:
	frame += 1
	if frame == capture_frame:
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(out_path)
		print("saved ", size, " to ", out_path)
		get_tree().quit()
