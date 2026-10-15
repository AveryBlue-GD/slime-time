extends "res://tests/suite_base.gd"

## Hat fit and craft checks, on the real sprite sheets: every hat on every frame of every
## animation it's worn through sits on the head (no floating gap, never over the eyes), its
## brim reaches at most a few px past the head, nothing pokes out of the allowed box, the head
## point doesn't jitter, the pixel art keeps its rules (no stray semi-transparent pixels, no
## orphans, no pure black, a limited palette), and hats.png is exactly what tools/make_hats.py draws.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hat_fit.gd

## Animations a hat is worn through (it's popped off for launch and air, so those only need to fit).
const WORN := ["idle", "glide_", "charge_", "land_", "splat_", "recover", "celebrate"]
## Brims (and horns) may reach this far past the widest part of the head, outline included.
const MAX_OVERHANG := 3
## How far above the top of the head a hat may reach (cones and pompoms included).
const MAX_HEIGHT := 10
const MAX_COLORS := 24
const EYE := Color8(26, 28, 44)

var sheet: Image
var hats: Image


func _initialize() -> void:
	sheet = preload("res://assets/sprites/slime_sheet.png").get_image()
	sheet.decompress()
	hats = preload("res://assets/sprites/hats.png").get_image()
	hats.decompress()
	_check(hats.get_size() == Vector2i(Hats.LIST.size() * Hats.FRAME.x, Hats.Width.size() * Hats.FRAME.y),
		"hats.png has a frame per hat and width (%s)" % hats.get_size())
	_check_head_points()
	_check_fit()
	_check_pixel_craft()
	_check_generator()
	_result()
	quit(1 if failures else 0)


func _frames() -> Array:
	var out := []
	var frames := Slime.load_sprite_frames()
	for anim in frames.get_animation_names():
		for f in frames.get_frame_count(anim):
			out.append([anim, f])
	return out


func _worn(anim: String) -> bool:
	for prefix: String in WORN:
		if anim.begins_with(prefix):
			return true
	return false


## The frame's top-left in the sheet.
func _origin(anim: String, frame: int) -> Vector2i:
	var tex := Slime.load_sprite_frames().get_frame_texture(anim, frame) as AtlasTexture
	return Vector2i(tex.region.position)


## The head point sits on the body's top row, centered on it (to the pixel), and moves at most a
## pixel between frames of a loop; loose sparkles never move it (the celebrate bug).
func _check_head_points() -> void:
	var off_top := []
	var off_center := []
	for pair: Array in _frames():
		var rows := Slime._body_rows(pair[0], pair[1])
		var hp := Slime.head_point(pair[0], pair[1])
		var top: Vector3i = rows[0]
		if hp.y != top.x - Slime.FRAME_SIZE / 2:
			off_top.append("%s:%d" % pair)
		var center := (top.y + top.z + 1) / 2.0 - Slime.FRAME_SIZE / 2.0
		if absf(hp.x - center) > 0.5:
			off_center.append("%s:%d" % pair)
	_check(off_top.is_empty(), "the head point is on the body's top row in every frame %s" % [off_top])
	_check(off_center.is_empty(), "...and centered on it %s" % [off_center])
	_check(absf(Slime.head_point("celebrate", 0).x) <= 1.0, "celebrate's sparkles don't drag the hat sideways (x %.1f)" % Slime.head_point("celebrate", 0).x)
	var jumpy := []
	for anim in ["idle", "glide_e", "glide_s", "glide_n", "charge_e", "land_e", "recover"]:
		var n := Slime.load_sprite_frames().get_frame_count(anim)
		for f in n:
			var d := Slime.head_point(anim, (f + 1) % n) - Slime.head_point(anim, f)
			if absf(d.x) > 1.0:
				jumpy.append("%s:%d" % [anim, f])
	_check(jumpy.is_empty(), "the hat never jumps sideways more than 1 px between frames %s" % [jumpy])


## Every hat on every frame, composited like the game does (Hat: the frame's HEAD on the head point).
func _check_fit() -> void:
	var floating := []
	var eyes := []
	var overhang := {}
	var too_tall := []
	var worst_at := {}
	var lifts := {}
	for hat: Dictionary in Hats.LIST:
		var worst := 0
		for pair: Array in _frames():
			var anim: String = pair[0]
			var frame: int = pair[1]
			var o := _origin(anim, frame)
			var rows := Slime._body_rows(anim, frame)
			var top: int = rows[0].x
			var body_left := 99
			var body_right := -99
			var body := {}
			for r: Vector3i in rows:
				body_left = mini(body_left, r.y)
				body_right = maxi(body_right, r.z)
				for x in range(r.y, r.z + 1):
					body[Vector2i(x, r.x)] = true
			var width := Hats.width_for(Slime.head_width(anim, frame))
			var region := Hats.region(hat.id, width)
			var lift := Hats.lift(hat.id, width, anim, frame)
			lifts[lift] = lifts.get(lift, 0) + 1
			var shift := Vector2i(Vector2(Slime.FRAME_SIZE / 2, Slime.FRAME_SIZE / 2) + Slime.head_point(anim, frame) - Hats.HEAD) - Vector2i(0, lift)
			var covers_top := false
			var hat_left := 99
			var hat_right := -99
			var highest := 99
			for hy in Hats.FRAME.y:
				for hx in Hats.FRAME.x:
					if hats.get_pixel(int(region.position.x) + hx, int(region.position.y) + hy).a < 0.5:
						continue
					var p := Vector2i(hx, hy) + shift
					hat_left = mini(hat_left, p.x)
					hat_right = maxi(hat_right, p.x)
					highest = mini(highest, p.y)
					if p.y <= top + 1 and body.has(p):
						covers_top = true  # (on the top row, or the next where the top is a 2 px nub)
					var inside := p.x >= 0 and p.y >= 0 and p.x < Slime.FRAME_SIZE and p.y < Slime.FRAME_SIZE
					if inside and body.has(p) and sheet.get_pixelv(o + p).is_equal_approx(EYE) and _worn(anim):
						eyes.append("%s %s:%d" % [hat.id, anim, frame])
			if not covers_top:
				floating.append("%s %s:%d" % [hat.id, anim, frame])
			if _worn(anim):
				var past := maxi(body_left - hat_left, hat_right - body_right)
				if past > worst:
					worst_at[hat.id] = "%s:%d" % [anim, frame]
				worst = maxi(worst, past)
			if top - highest > MAX_HEIGHT:
				too_tall.append("%s %s:%d (%d px)" % [hat.id, anim, frame, top - highest])
		overhang[hat.id] = worst
	_check(floating.is_empty(), "every hat sits down on the head in every frame (no gap) %s" % [floating.slice(0, 8)])
	_check(eyes.is_empty(), "no hat ever covers the eyes %s" % [eyes.slice(0, 8)])
	print("  hats lifted off the head to clear high eyes (px: hat-frames): %s" % [lifts])
	_check(lifts.get(0, 0) > 9 * (lifts.get(1, 0) + lifts.get(2, 0) + lifts.get(3, 0)), "...almost always without lifting the hat")
	var wide := []
	for id: String in overhang:
		if overhang[id] > MAX_OVERHANG:
			wide.append("%s %d px" % [id, overhang[id]])
	print("  brim overhang past the head (px, worst frame): %s %s" % [overhang, worst_at])
	_check(wide.is_empty(), "no hat reaches more than %d px past the head %s" % [MAX_OVERHANG, wide])
	_check(too_tall.is_empty(), "no hat towers more than %d px over the head %s" % [MAX_HEIGHT, too_tall.slice(0, 8)])


## Pixel rules per hat frame: fully opaque or clear, no orphan pixels, no pure black, a limited
## palette, the outline isn't black, and nothing touches the frame's edge (the allowed box).
func _check_pixel_craft() -> void:
	var problems := []
	for hat: Dictionary in Hats.LIST:
		for width in Hats.Width.size():
			var region := Hats.region(hat.id, width)
			var colors := {}
			var any := false
			for y in Hats.FRAME.y:
				for x in Hats.FRAME.x:
					var c := hats.get_pixel(int(region.position.x) + x, int(region.position.y) + y)
					if c.a == 0.0:
						continue
					any = true
					var tag := "%s/%d (%d,%d)" % [hat.id, width, x, y]
					if c.a < 1.0:
						problems.append(tag + " semi-transparent")
					if maxf(c.r, maxf(c.g, c.b)) < 0.04:
						problems.append(tag + " pure black")
					if x == 0 or y == 0 or x == Hats.FRAME.x - 1:
						problems.append(tag + " touches the frame edge")
					colors[c.to_html()] = true
					var lonely := true
					for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var q := Vector2i(x, y) + d
						if q.x >= 0 and q.y >= 0 and q.x < Hats.FRAME.x and q.y < Hats.FRAME.y \
								and hats.get_pixel(int(region.position.x) + q.x, int(region.position.y) + q.y).a > 0.0:
							lonely = false
					if lonely:
						problems.append(tag + " orphan pixel")
			if not any:
				problems.append("%s/%d is empty" % [hat.id, width])
			if colors.size() > MAX_COLORS:
				problems.append("%s/%d has %d colors" % [hat.id, width, colors.size()])
	_check(problems.is_empty(), "hat pixel art: opaque, no orphans or black, <= %d colors, inside its frame %s" % [MAX_COLORS, problems.slice(0, 10)])


## hats.png is exactly what tools/make_hats.py draws, and drawing it twice gives the same pixels.
func _check_generator() -> void:
	for python: String in ["python3", "python"]:
		var out := []
		var code := OS.execute(python, [ProjectSettings.globalize_path("res://tools/make_hats.py"), "--check"], out, true)
		if code == -1 or (code != 0 and "hats.png" not in "".join(out)):
			continue  # no such interpreter here
		_check(code == 0, "hats.png matches tools/make_hats.py, deterministically (%s)" % "".join(out).strip_edges())
		return
	print("  skip (no python): generator determinism")


