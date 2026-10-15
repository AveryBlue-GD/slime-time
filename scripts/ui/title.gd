extends Control

## The title screen (the main scene): the big gooey logo in your skin's colors, your slime on
## either side (in your hat), an ENTER THE HUB button and the tagline under it. Everything else
## (story, randomizer, skins, upgrades, settings, quit) lives in the hub.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0
const TAGLINE := "ESCAPE THE FOG\nOR DRY TRYING"
## The scenes the first title of a session loads before its first frame (the boot screen still
## shows), so the first change to each one doesn't stall under the goo wipe (the first level of a
## session froze the wipe for 180-330 ms on the M3, several seconds on a phone; the hub and the story
## 90 ms). Kept loaded for the session (a few MB), so every later change finds them in the cache.
## Plain loads on purpose: a threaded request deadlocked Godot 4.7.2 when a scene change loaded the
## same scene before it finished, and the web build has no threads anyway.
static var _preloaded: Array[Resource] = []
static var _preload_started := false
## Tests only: preload in a headless run too (see _start_preload).
static var preload_in_headless := false

var enter_button: Button
var story_button: Button


func _ready() -> void:
	# The very first launch of a fresh save opens with the animated intro (the launch trailer),
	# which then wipes into this screen. Only the title the game boots into counts.
	if Story.launch_due(self, Progress):
		# Preload before the hand-off too: the trailer's title is then a warm one, like every other
		# boot (still under the boot screen; the story scene is the one opening next anyway).
		_start_preload(true)
		Story.launched = true
		Story.mode = "intro"
		Story.next_scene = UIKit.TITLE_SCENE
		get_tree().change_scene_to_file.call_deferred(Story.SCENE)
		return
	if get_tree().current_scene == self:
		Story.launched = true  # the booted title: no trailer later this run
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
	if Progress.heat_crown():  # HEAT 10 on every hard level: a crown of white-hot flames over the logo
		for i in 5:
			var flame := Heat.make_rect(Heat.flame(Economy.HEAT_MAX))
			flame.name = "CrownFlame%d" % i
			flame.position = Vector2(160 - 4 + (i - 2) * 12, 2 + absi(i - 2))
			add_child(flame)
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
	enter_button.add_theme_font_size_override("font_size", UIKit.FONT_BIG)
	UIKit.use_big_font(enter_button, 16)
	enter_button.position = Vector2(72, 84)
	add_child(enter_button)
	enter_button.grab_focus()
	# The story intro again: a small button in the bottom-left corner, beside the tagline.
	story_button = UIKit.make_button("STORY", _replay_story, UIKit.BACK_SIZE)
	add_child(story_button)
	UIKit.place_bottom_row(story_button, -1)

	var tagline := UIKit.make_label(TAGLINE, UIKit.FONT_BIG, UIKit.TEXT_DIM)  # big, filling the bottom
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_constant_override("line_spacing", UIKit.LINE_SPACING * 2)
	add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 124
	tagline.offset_bottom = 176
	_warm_up_shaders()
	_start_preload(fresh)


## Shaders compile the first time something draws with them, which on the web (no shader cache)
## is a hitch the first time a level or the hub opens. Draw a pixel with each of the game's other
## shaders for a couple of frames under the title's opaque backdrop (nothing shows), then drop it.
func _warm_up_shaders() -> void:
	var warm := Control.new()
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var materials: Array[Material] = []
	# goo_wipe: the first screen change's first frame would compile it (the title draws atmosphere,
	# slime_skin and text_drips itself; listed so the set stays whole if the title changes). The wipe's
	# own sheet also costs a few ms on its first draw: Transition.warm_up draws it, invisibly.
	for path in ["fog", "trail", "hub_room", "rainbow_hat", "color_wheel", "goo_wipe", "atmosphere", "slime_skin", "text_drips"]:
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
	# The warm-up node drops itself after a few frames; a tween bound to it dies with it, so this
	# is safe when the title is freed early (e.g. the first-launch trailer takes over).
	var transition := get_node_or_null("/root/Transition")
	if transition:
		transition.warm_up()
	var drop := warm.create_tween()
	drop.tween_interval(0.05)
	drop.tween_callback(warm.queue_free)


## Once per session (not in headless runs: tests and tools have nothing to draw and change scenes
## at once).
func _start_preload(fresh: bool) -> void:
	if _preload_started or (DisplayServer.get_name() == "headless" and not preload_in_headless):
		return
	_preload_started = true
	var paths := [UIKit.GAME_SCENE, UIKit.HUB_SCENE] if fresh else [UIKit.HUB_SCENE, UIKit.GAME_SCENE]
	for path: String in paths + [Story.SCENE]:
		_preloaded.append(load(path))


func _enter() -> void:
	UIKit.go(get_tree(), UIKit.HUB_SCENE)


## First launch: straight into level 1 (the intro already played when the game opened).
func _play() -> void:
	Progress.start_story(1)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


## The intro again (and then back to the title).
func _replay_story() -> void:
	Story.play(get_tree(), "intro", UIKit.TITLE_SCENE)
