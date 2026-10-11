class_name Fx
extends RefCounted

## Small visual extras: soft banded lights and pixel goo particles.

const RAINBOW_STOPS := 7


## A radial light sprite: `diameter` px, stepped into a few hard-edged bands (pixel look) and
## added on top of what's under it. Tint and brightness come from `color` (alpha = strength).
static func make_light(diameter: int, color: Color) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = diameter
	texture.height = diameter
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := Sprite2D.new()
	light.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = material
	light.modulate = color
	return light


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


## A one-shot burst of goo (or sparkles) at `pos`, freed when done. Flies out around
## `direction` within `spread` degrees (180 = all around).
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float,
		direction := Vector2.UP, spread := 180.0, rainbow := false) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.5
	particles.position = pos
	particles.direction = direction
	particles.spread = spread
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 1.2
	particles.damping_max = speed * 1.8
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.color_ramp = _fade_out()
	if rainbow:
		particles.color_initial_ramp = rainbow_gradient()
	particles.z_index = 12
	particles.z_as_relative = false
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


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
