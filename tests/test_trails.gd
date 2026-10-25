extends "res://tests/suite_base.gd"

## Trail styles (upgrades v2 batch 2 cosmetics, Cosmetics): every style on every skin (10 presets,
## CHAMELEON, rainbow, stopwatch) in a real level paints its cells in its own colors and alpha (INK the
## skin's deep shade at 150, GLOW 170 with the halo x2, GOLD chalice gold whatever the skin, CANDY white
## stripes every 12 px traveled, STARRY the shader's specks), the default style is byte-identical to
## the skin's own goo (rainbow bands included), the wardrobe / shop previews build, and nothing logs an
## error. (Pixels on screen: the batch 2 reference shots were deleted in the spring cleaning; `git show spring-cleaning-baseline:docs/polish-shots/batch2_trail_<style>.png` still has them.)
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_trails.gd

const MAIN := preload("res://scenes/main.tscn")

var progress: Node


const ErrLog := preload("res://tests/err_log.gd")


var errlog := ErrLog.new()


func _initialize() -> void:
	Economy.descent_force = 1  # Descent is switched off in the game (D11); this suite tests it
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	OS.add_logger(errlog)
	var skins: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		skins.append(preset.id)
	skins.append_array([Skins.CUSTOM, Skins.RAINBOW, Skins.STOPWATCH])
	var bad: Array[String] = []
	var runs := 0
	for style in Cosmetics.trail_ids():
		for skin in skins:
			var why := await _check_style(style, skin)
			runs += 1
			if why != "":
				bad.append("%s on %s: %s" % [style, skin, why])
	_check(bad.is_empty() and runs == Cosmetics.trail_ids().size() * skins.size() and Cosmetics.trail_ids().size() == 17, "%d style x skin runs paint their own colors (%s)" % [runs, "ok" if bad.is_empty() else "; ".join(bad.slice(0, 4))])
	# Previews (wardrobe tiles / shop) for every style, locked and owned.
	var previews_ok := true
	for style in Cosmetics.trail_ids():
		for locked in [false, true]:
			var img := Cosmetics.trail_preview(style, Color8(56, 183, 100), false, Vector2i(16, 9), locked)
			previews_ok = previews_ok and img.get_width() == 16 and img.get_used_rect().size.x == 16
	_check(previews_ok, "every style's preview strip builds (owned and locked)")
	_check(errlog.count == 0, "no engine or script errors (%d)%s" % [errlog.count, "" if errlog.lines.is_empty() else ": " + errlog.lines[0]])
	progress.reset_progress()
	_result()
	quit(0 if failures == 0 else 1)


## Every alpha (0-255) wheel-trail look `look` can paint: its cell rules over a patch of cells and a
## stretch of travel (PULSE's bands), plus TREASURE's center dashes.
func _wheel_alphas(look: Dictionary) -> Dictionary:
	var out := {}
	for y in 24:
		for x in 24:
			for deep in [false, true]:
				out[Cosmetics.trail_cell_at(look, deep, 0.0, Vector2i(x, y)).a8] = true
	for step in 1000:  # (fine steps: PULSE's band alpha changes smoothly with travel)
		var travel := step * 0.05
		for deep in [false, true]:
			out[Cosmetics.trail_cell_at(look, deep, travel, Vector2i(1, 1)).a8] = true
		var center: Variant = Cosmetics.trail_center(look, travel)
		if center != null:
			out[(center as Color).a8] = true
	return out


## Plays level 1 a moment with trail `style` on skin `skin`; returns "" or what's wrong.
func _check_style(style: String, skin: String) -> String:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = true  # every skin and cosmetic unlocked
	progress.tutorial_seen = 3
	progress.selected_skin = skin
	progress.trail_style = style
	var game: Node2D = MAIN.instantiate()
	game.level = 1
	root.add_child(game)
	await physics_frame
	var why := ""
	var look: Dictionary = game.trail_look
	var base := Color(game.skin_color)
	var shades := Skins.shades(base)
	var painted := _painted(game)
	var alpha: int = {"ink": 150, "glow": 170, "gold": 185, "abyss": Cosmetics.ABYSS_ALPHA}.get(style, 120)
	# A wheel trail paints per cell (Cosmetics.trail_cell_at): its alphas are the ones its rules give.
	var alphas := {alpha: true}
	if look.get("per_cell", false):
		alphas = _wheel_alphas(look)
	if painted.is_empty():
		why = "nothing painted"
	for c: Color in painted:
		var near := false
		for a: int in alphas:
			near = near or absi(c.a8 - a) <= 1
		if not near:
			why = "alpha %d, want one of %s" % [c.a8, alphas.keys()]
			break
	if look.get("per_cell", false):
		if float((game.trail_sprite.material as ShaderMaterial).get_shader_parameter("fx")) != look.get("fx", 0.0):
			why = "the shader's fx is not the style's"
		var base_cell: Color = Cosmetics.trail_cell_at(look, false, 0.0, Vector2i(1, 1))
		if not look.has("per_cell") or not _has(painted, base_cell) and style != "treasure" and style != "pulse":
			why = "not the style's own goo"
	match style:
		"ink":
			if not _has(painted, shades.deep):
				why = "no deep-shade cells"
		"gold":
			if not _has(painted, Cosmetics.GOLD) or _has(painted, shades.mid):
				why = "not chalice gold"
		"glow":
			var glow: Sprite2D = game.trail_sprite.get_child(0)
			var strength := float((glow.material as ShaderMaterial).get_shader_parameter("strength"))
			if not is_equal_approx(strength, Cosmetics.GLOW_TRAIL_GLOW):
				why = "halo %.2f" % strength
		"starry":
			if float((game.trail_sprite.material as ShaderMaterial).get_shader_parameter("stars")) != 1.0:
				why = "the shader's stars are off"
		"abyss":  # (earned on Descent floor 10): violet-black goo with specks, whatever the skin
			if not _has(painted, Cosmetics.ABYSS) or float((game.trail_sprite.material as ShaderMaterial).get_shader_parameter("stars")) != 1.0:
				why = "not the abyss goo with specks"
		"candy":
			game.trail_travel = Cosmetics.CANDY_STRIPE  # the next stripe: white
			var white: Color = game._goo_color(false)
			game.trail_travel = 0.0
			if white.r8 != Cosmetics.CANDY_WHITE.r8 or not (game.rainbow or _same_rgb(game._goo_color(false), shades.mid)):
				why = "no white / skin stripes"
		"skin":
			if game.rainbow:
				if not look.rainbow:
					why = "the rainbow skin lost its rainbow trail"
			elif not _same_rgb(painted[0], shades.mid) and not _same_rgb(painted[0], shades.dark):
				why = "not the skin's goo"
	if style != "skin" and style != "candy" and look.rainbow:
		why = "a worn style still paints rainbow bands"
	if not style in ["starry", "abyss"] and float((game.trail_sprite.material as ShaderMaterial).get_shader_parameter("stars")) != 0.0:
		why = "stars on a non-starry trail"
	game.free()
	await process_frame
	return why


## The distinct colors of the painted trail cells.
func _painted(game: Node2D) -> Array[Color]:
	var out: Array[Color] = []
	var img: Image = game.trail_image
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 > 0 and not seen.has(c.to_rgba32()):
				seen[c.to_rgba32()] = true
				out.append(c)
	return out


func _has(colors: Array[Color], want: Color) -> bool:
	for c in colors:
		if _same_rgb(c, want):
			return true
	return false


func _same_rgb(a: Color, b: Color) -> bool:
	return absi(a.r8 - b.r8) <= 1 and absi(a.g8 - b.g8) <= 1 and absi(a.b8 - b.b8) <= 1


