extends Control

## The title screen (the main scene): the big gooey logo in your skin's colors, your slime on
## either side (in your hat), an ENTER THE HUB button and the tagline under it. Everything else
## (story, randomizer, skins, upgrades, settings, quit) lives in the hub.

## Rainbow skin: how wide one full rainbow is across the logo (px).
const LOGO_RAINBOW_WIDTH := 90.0
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

## ENTER THE HUB / PLAY in English (a longer text widens it, a taller script's line makes it taller).
const ENTER_SIZE := Vector2(176, 25)
const ENTER_Y := 84
## ENTER's 16 px line in English: its top row (centred: 5), the line's ink (14 body + 4 drip rows), and the
## rows a taller ENTER keeps under the drips: the bottom outline, as every button (a 13 px button's drips
## end on row 11 of 13; English's centred ENTER keeps 2).
const ENTER_TEXT_TOP := 5
const BIG_LINE_INK := 18
const ENTER_TEXT_BOTTOM := 1
## A taller script's 16 px glyphs: the first row they ink under the line box's top, where it is less than
## UIKit.GOO_INK_ROW (measured with tools/i18n_capture.sh --measure-boxes: Devanagari's matras 1; the
## others start lower: CJK 6, Thai 4, Arabic 5).
const BIG_INK_TOP := {"hi": 1}
## Your slime on each side: this far beyond the button's ends, a little low (English 52 / 268, 112).
const SLIME_OUT := 20
const SLIME_Y := 112
## The 2x slime's ink around its position (measured: body, eyes and shadow), and how far above the
## button's middle its position goes to stand level with the button (ink centred on the button's rows).
const SLIME_INK := Rect2(-16, -12, 32, 30)
const SLIME_LEVEL := 3
## The tagline is centred between the button and this row; one line of it is at most this wide.
const TAGLINE_BOTTOM := 176
const TAGLINE_W := 300

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
	# A fresh save plays level 1 right away; the hub opens up once the first chalice is won.
	var fresh: bool = Progress.is_fresh_save()
	# Same 16 px lettering as the tagline, so the button isn't dwarfed by it.
	# i18n: max 168px, grows to 224px (the button widens, the slimes move out with its ends), 1 line, 16 px font; the button text is PLAY on a fresh save, else ENTER THE HUB
	var enter_text := Loc.t("title.play", "PLAY") if fresh else Loc.t("title.enter_hub", "ENTER THE HUB")
	# English: 176x25 at (72, 84), your slime 20 px beyond each end (x 52 / 268, y 112). A longer text
	# widens it (still centred, the slimes moving out with its ends); a taller script's 16 px line makes
	# it taller (enter_height), the slimes staying level with its middle.
	var previews: Array[Node2D] = []
	for i in 2:
		var preview := UIKit.make_slime_preview(Progress.skin_color(), 2, Progress.is_rainbow(), null, Progress.is_stopwatch())
		add_child(preview)
		previews.append(preview)
		if Progress.selected_hat != Hats.NONE:  # the hat you're wearing, at the same 2x size
			var hat := Hat.new()
			hat.scale = preview.scale
			add_child(hat)
			hat.setup(Progress.selected_hat, preview)

	enter_button = UIKit.make_button(enter_text, _play if fresh else _enter, Vector2(ENTER_SIZE.x, enter_height(enter_text)))
	enter_button.add_theme_font_size_override("font_size", UIKit.FONT_BIG)
	UIKit.use_big_font(enter_button, 16)
	var shift := ink_shift(enter_text, UIKit.FONT_BIG)
	if UIKit.tall_script() or _marked_locale():
		var top := enter_top(enter_text)
		_slim_styles(enter_button, top, enter_height(enter_text) - top - int(UIKit.metrics().title_line_h), shift)
	elif shift != 0:
		_shift_styles(enter_button, shift)
	# (measured once the 16 px font is in use: loading it earlier would shift every goo box's lumps)
	var enter_size := Vector2(UIKit.button_w(enter_text, int(ENTER_SIZE.x), UIKit.FONT_BIG), enter_height(enter_text))
	var enter_rect := Rect2(UIKit.center_x(enter_size.x), ENTER_Y, enter_size.x, enter_size.y)
	enter_button.custom_minimum_size = enter_size
	UIKit.note_text_w(enter_button, [enter_text], int(ENTER_SIZE.x), UIKit.FONT_BIG)
	enter_button.position = enter_rect.position
	add_child(enter_button)
	enter_button.grab_focus()
	# The story intro again: a small button in the bottom-left corner, beside the tagline (BACK's size).
	var story_text := Loc.t("title.story", "STORY")
	story_button = UIKit.make_button(story_text, _replay_story, UIKit.back_size(story_text))
	UIKit.note_text_w(story_button, [story_text], int(UIKit.BACK_SIZE.x))
	var story_shift := ink_shift(story_text, UIKit.FONT)
	if story_shift != 0:
		_shift_styles(story_button, story_shift)
	add_child(story_button)
	UIKit.place_bottom_row(story_button, -1)

	# i18n: tagline, two lines (\n) of the 16 px font, max 300px each; a pun (fog / dry up), keep it short
	var parts := [Loc.t("title.tagline.1", "ESCAPE THE FOG"), Loc.t("title.tagline.2", "OR DRY TRYING")]
	var tagline := UIKit.make_label(Loc.lines(parts), UIKit.FONT_BIG, UIKit.TEXT_DIM)  # big, filling the bottom
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacing := UIKit.line_spacing() * 2  # (10 in English: the big font's double line spacing)
	tagline.add_theme_constant_override("line_spacing", spacing)
	add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Centred between the button and the bottom edge (124 in English). A taller script whose two lines
	# don't fit there takes them on one line when that fits the screen (Traditional Chinese). A second
	# line long enough to run over STORY's corner lifts the block clear of it (Spanish, French, Italian).
	var line := int(UIKit.metrics().title_line_h)
	var block := 2 * line + spacing
	var below := int(enter_rect.end.y)
	var widths: Array[int] = [UIKit.text_w(parts[0], UIKit.FONT_BIG), UIKit.text_w(parts[1], UIKit.FONT_BIG)]
	if below + block > TAGLINE_BOTTOM and UIKit.text_w(" ".join(parts), UIKit.FONT_BIG) <= TAGLINE_W:
		tagline.text = " ".join(parts)
		block = line
		widths = [UIKit.text_w(tagline.text, UIKit.FONT_BIG)]
	var top := ceili((below + TAGLINE_BOTTOM - block) / 2.0)
	var drips := 0 if UIKit.tall_script() else 2 * UIKit.TEXT_DRIP  # (the 16 px font's drips under a line)
	var story_rect := Rect2(story_button.position, story_button.size)
	if widths.size() == 2 and 160 - widths[1] / 2.0 < story_rect.end.x + UIKit.GAP_M and top + block + drips > story_rect.position.y - UIKit.GAP_S:
		top = int(story_rect.position.y) - UIKit.GAP_S - block - drips
	tagline.offset_top = top
	tagline.offset_bottom = TAGLINE_BOTTOM
	# Your slimes 20 px beyond the button's ends, a little low (y 112); when the tagline's first line
	# would run under them (a line wider than the room between them), they stand level with the button.
	var slime_y := SLIME_Y + floori((enter_size.y - ENTER_SIZE.y) / 2.0)
	var line_top := top - UIKit.ink_above(tagline.text.get_slice("\n", 0), UIKit.FONT_BIG)  # (its marks, if it has any)
	for i in 2:
		var x := enter_rect.position.x - SLIME_OUT if i == 0 else enter_rect.end.x + SLIME_OUT
		previews[i].position = Vector2(x, slime_y)
	var inner := previews[0].position.x + SLIME_INK.end.x + UIKit.GAP_M
	if 160 - widths[0] / 2.0 < inner and slime_y + SLIME_INK.end.y + UIKit.GAP_M > line_top:
		slime_y = int(enter_rect.position.y) + floori(enter_size.y / 2.0) - SLIME_LEVEL
		for preview in previews:
			preview.position.y = slime_y
	_warm_up_shaders()
	_start_preload(fresh)


## The ENTER button's height: ENTER_SIZE.y, or a taller script's 16 px line box (+ its ink nudge) when
## that is taller: its line box already holds the room around its glyphs, so its button keeps no other
## margins (_slim_styles) and grows only as much as its line (CJK 28, Traditional Chinese 32).
## With the slimy font (fix pass F3b): the 16 px line starts on ENTER_TEXT_TOP as in English, lower by
## its marks' rows when it has any (the highest mark on UIKit.GOO_INK_ROW, under the lump row: a Й
## breve sat on row 1, Vietnamese marks on row 2), the button as tall as keeps ENTER_TEXT_BOTTOM rows under
## the line's drips (the accents' theme margins had pushed the drips onto the bottom outline, row 24).
static func enter_height(text := "") -> int:
	if _marked_locale():
		return maxi(int(ENTER_SIZE.y), enter_top(text) + BIG_LINE_INK + ENTER_TEXT_BOTTOM)
	if UIKit.tall_script():
		return UIKit.big_button_h(int(ENTER_SIZE.y)) + enter_top(text) - int(UIKit.metrics().get("ink_nudge", 0))
	return int(ENTER_SIZE.y)


## The 16 px line's top row in ENTER: English's 5 (centred), lower by the text's marks (slimy font);
## a taller script: its ink nudge, or as low as puts its glyphs' first inked row (BIG_INK_TOP) on
## UIKit.GOO_INK_ROW.
static func enter_top(text: String) -> int:
	if UIKit.tall_script():
		var nudge := int(UIKit.metrics().get("ink_nudge", 0))
		return maxi(nudge, UIKit.GOO_INK_ROW - int(BIG_INK_TOP.get(UIKit.locale(), UIKit.GOO_INK_ROW)))
	return maxi(ENTER_TEXT_TOP, UIKit.GOO_INK_ROW + mark_rows(text, UIKit.FONT_BIG))


## True in a locale whose slimy text has marks over the line (accented, Vietnamese, pseudo): there the
## theme's button margins (made for the 8 px line) would put the 16 px line 2 px low, so ENTER gets its
## own (enter_top). English and the other slimy locales: the theme's, untouched.
static func _marked_locale() -> bool:
	return not UIKit.tall_script() and int(UIKit.metrics().ink_above) > 0


## The rows the slimy font's marks over `text` reach above its line box at `font_size` (Й: 3 at 8 px,
## 6 at 16; 0 for a text without marks). Read from the 8 px font's i18n page, where each glyph has
## UIKit.EXT_MARK_ROWS rows over the letter (the 16 px font is the same art at 2x).
## (A local helper: UIKit.ink_above gives the locale's tallest marks, not the text's own.)
static func mark_rows(text: String, font_size := UIKit.FONT) -> int:
	var font: FontFile = load(UIKit.Lang.FONT_PATH)
	var size := Vector2i(UIKit.FONT, 0)
	var rows := 0
	var page: Image = null
	for i in text.length():
		var code := text.unicode_at(i)
		if code <= 0x7F or not UIKit.has_mark(code) or not font.get_glyph_list(0, size).has(code) \
				or font.get_glyph_texture_idx(0, size, code) != 1:
			continue
		if page == null:
			page = font.get_texture_image(0, size, 1)
		var uv := font.get_glyph_uv_rect(0, size, code)
		for y in UIKit.EXT_MARK_ROWS:
			var inked := false
			for x in range(int(uv.position.x), int(uv.end.x)):
				inked = inked or page.get_pixel(x, int(uv.position.y) + y).a > 0.5
			if inked:
				rows = maxi(rows, UIKit.EXT_MARK_ROWS - y)
				break
	return rows * (2 if font_size == UIKit.FONT_BIG else 1)


## How far a button's text should move right so its ink is centred (fix pass F3b): Chinese, Japanese
## and Korean glyphs start at their left edge and keep their spacing on the right (Hangul 2 px a
## syllable), so a centred CJK line sat 1-2 px left of the middle (ストーリー ink 1 / 3 px from the
## fill, 허브로 가기 34 / 38). Measured from the shaped glyphs' bitmaps (each with the font cache's
## 1 px padding); 0 in every other locale (the slimy font's own 1 px leading gap is English's look).
static func ink_shift(text: String, font_size: int) -> int:
	if not UIKit.locale() in UIKit.Lang.GAP_LOCALES:
		return 0
	var font: Font = UIKit.font_for(font_size)
	var server := TextServerManager.get_primary_interface()
	var shaped := server.create_shaped_text()
	server.shaped_text_add_string(shaped, text, font.get_rids(), font_size)
	var x := 0.0
	var first := INF
	var last := -INF
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		var rid: RID = glyph.font_rid
		if rid.is_valid() and int(glyph.index) != 0:
			var size: Vector2 = server.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph.index)
			if size.x > 2.0:  # (a bitmap of more than its padding)
				var left: float = x + glyph.offset.x + server.font_get_glyph_offset(rid, Vector2i(font_size, 0), glyph.index).x
				first = minf(first, left + 1.0)
				last = maxf(last, left + size.x - 1.0)
		x += glyph.advance
	server.free_rid(shaped)
	if first == INF:
		return 0
	return floori(((x - last) - first) / 2.0)


## ENTER's goo looks with its own top / bottom content margins (the line box exactly between them) and
## the text moved `shift` px right (ink_shift).
static func _slim_styles(button: Button, top: int, bottom: int, shift := 0) -> void:
	for slot: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := UIKit.button_style("pressed" if slot == "hover_pressed" else slot)
		box.content_margin_top = top
		box.content_margin_bottom = bottom
		box.content_margin_left += shift
		box.content_margin_right -= shift
		button.add_theme_stylebox_override(slot, box)


## A themed button's looks with its text moved `shift` px right (ink_shift); everything else the theme's.
static func _shift_styles(button: Button, shift: int) -> void:
	for slot: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := UIKit.button_style("pressed" if slot == "hover_pressed" else slot)
		box.content_margin_left += shift
		box.content_margin_right -= shift
		button.add_theme_stylebox_override(slot, box)


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
