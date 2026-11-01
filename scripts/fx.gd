class_name Fx
extends RefCounted

## Small visual extras: soft banded lights and pixel goo particles.

const RAINBOW_STOPS := 7


## Light textures by size, and the one additive dithered material every light shares: a light's
## tint and strength live in its modulate, so lights of one size are identical and can share (and batch).
static var _light_textures := {}
static var _additive: ShaderMaterial


## A radial light sprite: `diameter` px, a smooth falloff that light_dither.gdshader cuts into
## 4 world-locked Bayer-dithered steps (no hard rings) and adds on top of what's under it.
## Tint and brightness come from `color` (alpha = strength). Its texture and material are
## shared: change only its modulate (or transform).
static func make_light(diameter: int, color: Color) -> Sprite2D:
	return _light_sprite(Vector2i(diameter, diameter), color)


## A flat, oval pool of light (`size` px wide and deep) for the slanted hub floor: same dithered
## falloff as make_light, added on top of the floor.
static func make_pool(size: Vector2i, color: Color) -> Sprite2D:
	return _light_sprite(size, color)


static func _light_sprite(size: Vector2i, color: Color) -> Sprite2D:
	if not _light_textures.has(size):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0),
		])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = size.x
		texture.height = size.y
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		_light_textures[size] = texture
	if _additive == null:
		_additive = ShaderMaterial.new()
		_additive.shader = preload("res://assets/shaders/light_dither.gdshader")
	var light := Sprite2D.new()
	light.texture = _light_textures[size]
	light.material = _additive
	light.modulate = color
	return light


## The 4x4 Bayer value (0..15) at integer pixel (x, y): the same matrix as bayer4() in the shaders.
static func bayer(x: int, y: int) -> int:
	var ax := posmod(x, 2)
	var ay := posmod(y, 2)
	var bx := posmod(x >> 1, 2)
	var by := posmod(y >> 1, 2)
	return 4 * posmod(2 * ax + 3 * ay, 4) + posmod(2 * bx + 3 * by, 4)


static var _halos := {}


## A dithered halo texture for canvas drawing (the story intro): radius `r` px, `steps` levels
## (alpha = level / steps, so draw it with modulate alpha = steps * strength), Bayer-dithered in
## world pixels. The texture's top-left sits at world pixel (phase_x, phase_y) mod 4, so drawing it
## at a centre `c` needs phase = posmod(c.x - r, 4) / posmod(c.y - r, 4): the pattern then stays put.
static func halo_texture(r: int, steps: int, phase_x: int, phase_y: int) -> ImageTexture:
	var key := Vector4i(r, steps, phase_x, phase_y)
	if _halos.has(key):
		return _halos[key]
	var size := r * 2 + 1
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - r, y - r).length() / float(r)
			if d >= 1.0:
				continue
			var thr := (bayer(x + phase_x, y + phase_y) + 0.5) / 16.0
			var level := clampi(floori((1.0 - d) * steps * 1.15 + thr), 0, steps)
			if level > 0:
				image.set_pixel(x, y, Color(1, 1, 1, float(level) / steps))
	var texture := ImageTexture.create_from_image(image)
	_halos[key] = texture
	return texture


## Goo droplets flicked off the slime while it glides (emitting is switched on/off by the slime).
static func make_drips() -> CPUParticles2D:
	var drips := CPUParticles2D.new()
	drips.amount = 10
	drips.lifetime = 0.45
	drips.local_coords = false
	drips.emitting = false
	drips.spread = 35.0
	drips.gravity = Vector2.ZERO
	drips.initial_velocity_min = 12.0
	drips.initial_velocity_max = 28.0
	drips.damping_min = 40.0
	drips.damping_max = 60.0
	drips.scale_amount_min = 1.0
	drips.scale_amount_max = 2.0
	drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	drips.emission_sphere_radius = 4.0
	drips.color_ramp = _fade_out()
	return drips


## Burst presets (ANI-06): how a burst moves and is drawn. GOO: round droplets that shrink 2 -> 1 px;
## GOLD: little 4-point stars with a dark outline (chalice, coins, tickets); DUST: grey flecks that
## sink (wall break, the dry-up's crust flakes). All use whole-pixel sizes and stepped palette
## colours (bright -> base -> outline) instead of alpha fades, and a random lifetime so they don't
## all vanish on the same frame.
enum Preset { GOO, GOLD, DUST }
const DUST_BRIGHT := Color8(200, 196, 204)
const DUST_BASE := Color8(148, 140, 150)

static var _star_texture: ImageTexture
static var _shrink: Curve


## A one-shot burst of goo (or sparkles) at `pos`, freed when done. Flies out around
## `direction` within `spread` degrees (180 = all around).
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float,
		direction := Vector2.UP, spread := 180.0, rainbow := false, preset := Preset.GOO) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.5
	particles.lifetime_randomness = 0.4
	particles.position = pos
	particles.direction = direction
	particles.spread = spread
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 1.2
	particles.damping_max = speed * 1.8
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.color_ramp = stepped_ramp()
	match preset:
		Preset.GOO:
			particles.scale_amount_curve = _shrink_curve()  # 2 px, then 1 px for the second half
		Preset.GOLD:
			particles.texture = star_texture()
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 1.0
			particles.color_ramp = twinkle_ramp()
			particles.lifetime = 0.6
		Preset.DUST:
			particles.color = DUST_BASE if color.a <= 0.0 else color
			particles.gravity = Vector2(0.0, 60.0)
			particles.damping_min = speed * 0.6
			particles.damping_max = speed * 1.0
			particles.scale_amount_curve = _shrink_curve()
	if rainbow:
		particles.color_initial_ramp = rainbow_gradient()
	particles.z_index = 12
	particles.z_as_relative = false
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## Grey crust flakes for the dry-up (ANI-01): `amount` flecks at `pos`, sinking a little.
static func crust_flakes(parent: Node, pos: Vector2, amount := 7) -> CPUParticles2D:
	return burst(parent, pos, DUST_BASE, amount, 26.0, Vector2.UP, 180.0, false, Preset.DUST)


## The skin's three steps for a dashed afterimage (ANI-10): [bright, base, outline] as opaque
## palette-like colours (no alpha: dither them instead).
static func afterimage_colors(base: Color) -> PackedColorArray:
	return PackedColorArray([base.lightened(0.35), base, base.darkened(0.45)])


## Brightest at birth, then the base colour, then a dark outline shade for the last fifth: stepped,
## fully opaque (a particle just ends). Multiplies the particle's own colour.
static func stepped_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.8])
	gradient.colors = PackedColorArray([Color(1.35, 1.35, 1.35, 1), Color(1, 1, 1, 1), Color(0.55, 0.55, 0.55, 1)])
	return gradient


## Two-frame twinkle: bright / base, flipping every ~0.08 of a life, ending on the dark step.
static func twinkle_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.24, 0.36, 0.48, 0.8])
	gradient.colors = PackedColorArray([Color(1.35, 1.35, 1.35, 1), Color(1, 1, 1, 1), Color(1.35, 1.35, 1.35, 1),
		Color(1, 1, 1, 1), Color(1.35, 1.35, 1.35, 1), Color(0.7, 0.7, 0.7, 1)])
	return gradient


static func _shrink_curve() -> Curve:
	if _shrink == null:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0.0, 1.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
		_shrink.add_point(Vector2(0.5, 1.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
		_shrink.add_point(Vector2(0.501, 0.5), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
		_shrink.add_point(Vector2(1.0, 0.5), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return _shrink


## A 5x5 four-point star: a white plus with a grey outline (multiplied by the particle's colour,
## the outline becomes a dark shade of it, so it reads on gold scenes).
static func star_texture() -> ImageTexture:
	if _star_texture == null:
		var image := Image.create_empty(5, 5, false, Image.FORMAT_RGBA8)
		var outline := Color(0.3, 0.3, 0.3, 1)
		for p in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 3), Vector2i(3, 3)]:
			image.set_pixelv(p, outline)
		for p in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			image.set_pixelv(p, Color.WHITE)
		_star_texture = ImageTexture.create_from_image(image)
	return _star_texture


static func rainbow_gradient() -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in RAINBOW_STOPS:
		offsets.append(float(i) / (RAINBOW_STOPS - 1))
		colors.append(Color.from_hsv(float(i) / (RAINBOW_STOPS - 1) * 0.83, 0.8, 1.0))
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient


## Full color, then fades out over the last half of a particle's life.
static func _fade_out() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	return gradient
