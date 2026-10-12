extends Control

## The title screen (the main scene): the big gooey logo in your skin's colors, your slime on
## either side (in your hat), an ENTER THE HUB button and the tagline under it. Everything else
## (story, randomizer, skins, upgrades, settings, quit) lives in the hub.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0
const TAGLINE := "ESCAPE THE FOG OR DRY TRYING"

var enter_button: Button


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
		var preview := UIKit.make_slime_preview(Progress.skin_color(), 2, Progress.is_rainbow())
		preview.position = Vector2(x, 124)
		add_child(preview)
		if Progress.selected_hat != Hats.NONE:  # the hat you're wearing, at the same 2x size
			var hat := Hat.new()
			hat.scale = preview.scale
			add_child(hat)
			hat.setup(Progress.selected_hat, preview)

	enter_button = UIKit.make_button("ENTER THE HUB", _enter, Vector2(120, 13))
	enter_button.position = Vector2(100, 112)
	add_child(enter_button)
	enter_button.grab_focus()

	var tagline := UIKit.make_label(TAGLINE, 8, UIKit.TEXT_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 134
	tagline.offset_bottom = 144


func _enter() -> void:
	UIKit.go(get_tree(), UIKit.HUB_SCENE)
