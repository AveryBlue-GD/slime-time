extends Node

## The trailer's animated end card (marketing only): the DRY TRYING logo in the skin's colors over the
## skins screen's try-on stage (the slime acting out its loop), on the menu background, at 360x640
## (= 1080x1920 / 3, so the 303 px logo fits), its frames saved to --frames-dir (see _build_card).
## --skin=ID (a Progress flag) and --jelly dress it; --logo=N picks the logo variant.
## The card's words (tagline, CTA, store line) and every caption are drawn in the logo's own goo
## lettering by tools/trailer/goo_text.py and laid over it by trailer.py; they start under the stage
## (trailer.py CARD_TEXT_TOP).

const CARD_SIZE := Vector2i(360, 640)
const LOGO_Y := 120
const STAGE_Y := 212

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
	_build_card.call_deferred()


func _make_view(size: Vector2i, transparent: bool) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = transparent
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	add_child(view)
	return view


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
	logo.position = Vector2(roundf((CARD_SIZE.x - logo.texture.get_width()) / 2.0), LOGO_Y)
	root.add_child(logo)
	var stage := SkinShowcase.new()
	stage.position = Vector2(roundf((CARD_SIZE.x - SkinShowcase.STAGE_SIZE.x) / 2.0), STAGE_Y)
	root.add_child(stage)
	stage.show_skin(skin, false, Progress.jelly)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: Sfx.play("unlock"))


func _process(_delta: float) -> void:
	if _card_view == null or _card_dir == "":
		return
	await RenderingServer.frame_post_draw
	_card_view.get_texture().get_image().save_png(_card_dir.path_join("c%08d.png" % _card_frame))
	_card_frame += 1
