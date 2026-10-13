extends Control

## The title screen (the main scene): the big gooey logo in your skin's colors, your slime on
## either side (in your hat), an ENTER THE HUB button and the tagline under it. Everything else
## (story, randomizer, skins, upgrades, settings, quit) lives in the hub.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0
const TAGLINE := "ESCAPE THE FOG\nOR DRY TRYING"

var enter_button: Button
var story_button: Button


func _ready() -> void:
	UIKit.setup_screen(self, "")
	# The logo is drawn in the slime sheet's goo shades, so the skin shader recolors it too.
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/sprites/title.png")
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	(logo.material as ShaderMaterial).set_shader_parameter("rainbow_width", LOGO_RAINBOW_WIDTH)
	(logo.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)  # the logo stays solid
	logo.position = Vector2(roundf((320 - logo.texture.get_width()) / 2.0), 12)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	for x in [52, 268]:
		var preview := UIKit.make_slime_preview(Progress.skin_color(), 2, Progress.is_rainbow(), null, Progress.is_stopwatch())
		preview.position = Vector2(x, 112)
		add_child(preview)
		if Progress.selected_hat != Hats.NONE:  # the hat you're wearing, at the same 2x size
			var hat := Hat.new()
			hat.scale = preview.scale
			add_child(hat)
			hat.setup(Progress.selected_hat, preview)

	# A fresh save plays level 1 right away; the hub opens up once the first chalice is won.
	var fresh: bool = Progress.is_fresh_save()
	# Same 16 px lettering as the tagline, so the button isn't dwarfed by it.
	enter_button = UIKit.make_button("PLAY" if fresh else "ENTER THE HUB", _play if fresh else _enter, Vector2(176, 25))
	enter_button.add_theme_font_size_override("font_size", 16)
	UIKit.use_big_font(enter_button, 16)
	enter_button.position = Vector2(72, 84)
	add_child(enter_button)
	enter_button.grab_focus()
	# The story intro again: a small button in the bottom-left corner, beside the tagline.
	story_button = UIKit.make_button("STORY", _replay_story, Vector2(40, 13))
	story_button.position = Vector2(4, 163)
	add_child(story_button)

	var tagline := UIKit.make_label(TAGLINE, 16, UIKit.TEXT_DIM)  # big, filling the bottom
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_constant_override("line_spacing", UIKit.LINE_SPACING * 2)
	add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 124
	tagline.offset_bottom = 176
	_warm_up_shaders()


## Shaders compile the first time something draws with them, which on the web (no shader cache)
## is a hitch the first time a level or the hub opens. Draw a pixel with each of the game's other
## shaders for a couple of frames under the title's opaque backdrop (nothing shows), then drop it.
func _warm_up_shaders() -> void:
	var warm := Control.new()
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var materials: Array[Material] = []
	for path in ["fog", "trail", "hub_room", "rainbow_hat", "color_wheel"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/%s.gdshader" % path)
		materials.append(material)
	var additive := CanvasItemMaterial.new()  # lights, glows, trail glow
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	materials.append(additive)
	for material in materials:
		var dot := ColorRect.new()
		dot.size = Vector2.ONE
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.material = material
		warm.add_child(dot)
	add_child(warm)
	move_child(warm, 0)  # under the backdrop, whose background covers the whole screen
	for i in 3:
		await get_tree().process_frame
	warm.queue_free()


func _enter() -> void:
	UIKit.go(get_tree(), UIKit.HUB_SCENE)


## First launch: straight into level 1.
func _play() -> void:
	Progress.start_story(1)
	if Story.intro_due(Progress):
		Story.play(get_tree(), "intro", UIKit.GAME_SCENE)
	else:
		UIKit.go(get_tree(), UIKit.GAME_SCENE)


## The intro again (and then back to the title).
func _replay_story() -> void:
	Story.play(get_tree(), "intro", UIKit.TITLE_SCENE)
