class_name Ambient
extends Node2D

## Cheap ambient motes for each level theme (dust, spores, sand, bubbles, snow, embers, glints):
## one CPUParticles2D of 1-2 px squares per theme, kept in the world around the camera and drawn
## on the floor (under the trail, chalice, slime and coins) and under the fog, so the fog hides
## them exactly like the floor. Counts are capped (MAX_AMOUNT)
## and nothing is made with Reduce Motion on.

const MAX_AMOUNT := 28
## Half the emission area: a little more than half the 320x180 screen so nothing pops in.
const REACH := Vector2(176.0, 100.0)
## Draw order: above the floor, goo trail and fillets (z 1-2), under coins and the fog (z 10).
const PREPROCESS_MAX := 2.0
const Z := 9

## Per theme: amount, life (s), dir, spread (deg), speed [min, max] px/s, gravity (px/s^2),
## color (+ alpha), end (color at the end of its life, optional), size (px, max), add (additive).
const BY_THEME := {
	"dungeon": {amount = 14, life = 6.0, dir = Vector2(0.3, -1.0), spread = 70.0, speed = [2.0, 6.0],
		gravity = Vector2.ZERO, color = Color(0.72, 0.78, 0.9, 0.5), size = 1.0},
	"mossy": {amount = 18, life = 7.0, dir = Vector2(0.2, -1.0), spread = 60.0, speed = [3.0, 8.0],
		gravity = Vector2(0, -0.5), color = Color(0.62, 1.0, 0.55, 0.6), size = 1.0, add = true},
	"sandstone": {amount = 22, life = 2.5, dir = Vector2(1.0, 0.1), spread = 12.0, speed = [28.0, 55.0],
		gravity = Vector2.ZERO, color = Color(0.95, 0.8, 0.55, 0.55), size = 1.0},
	"sunken": {amount = 16, life = 5.0, dir = Vector2(0.0, -1.0), spread = 15.0, speed = [8.0, 16.0],
		gravity = Vector2(0, -2.0), color = Color(0.6, 0.95, 1.0, 0.7), size = 2.0, add = true},
	"sewers": {amount = 12, life = 6.0, dir = Vector2(0.0, -1.0), spread = 20.0, speed = [5.0, 11.0],
		gravity = Vector2(0, -1.0), color = Color(0.78, 0.9, 0.35, 0.7), size = 2.0, add = true},
	"catacombs": {amount = 16, life = 8.0, dir = Vector2(0.15, 1.0), spread = 50.0, speed = [1.5, 4.0],
		gravity = Vector2.ZERO, color = Color(0.82, 0.74, 0.78, 0.45), size = 1.0},
	"frozen": {amount = 28, life = 5.0, dir = Vector2(0.35, 1.0), spread = 20.0, speed = [10.0, 22.0],
		gravity = Vector2.ZERO, color = Color(0.92, 0.97, 1.0, 0.8), size = 1.0},
	"obsidian": {amount = 10, life = 7.0, dir = Vector2(0.0, -1.0), spread = 90.0, speed = [2.0, 5.0],
		gravity = Vector2.ZERO, color = Color(0.7, 0.5, 1.0, 0.5), size = 1.0, add = true},
	"crystal": {amount = 14, life = 1.8, dir = Vector2(0.0, -1.0), spread = 180.0, speed = [0.0, 3.0],
		gravity = Vector2.ZERO, color = Color(1.0, 0.7, 1.0, 0.9), size = 1.0, add = true},
	"volcanic": {amount = 28, life = 3.5, dir = Vector2(0.15, -1.0), spread = 30.0, speed = [10.0, 26.0],
		gravity = Vector2(0, -3.0), color = Color(1.0, 0.7, 0.25, 1.0), end = Color(0.8, 0.15, 0.05, 0.0),
		size = 2.0, add = true},
}

var particles: CPUParticles2D


## The ambient look for a theme (empty if it has none).
static func look(theme: String) -> Dictionary:
	return BY_THEME.get(theme, {})


## Particle count a theme runs with (0 = none, e.g. with Reduce Motion), capped at MAX_AMOUNT.
static func amount_for(theme: String, reduce_motion: bool) -> int:
	if reduce_motion:
		return 0
	return mini(int(look(theme).get("amount", 0)), MAX_AMOUNT)


## Builds the emitter for `theme`; with nothing to show, no node is made and this returns null.
static func create(theme: String, reduce_motion: bool) -> Ambient:
	var amount := amount_for(theme, reduce_motion)
	if amount <= 0:
		return null
	var cfg := look(theme)
	var ambient := Ambient.new()
	ambient.z_index = Z
	ambient.z_as_relative = false
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = cfg.life
	p.preprocess = minf(cfg.life, PREPROCESS_MAX)  # mostly filled when the level opens (capped: it simulates up front)
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = REACH
	p.direction = cfg.dir
	p.spread = cfg.spread
	p.gravity = cfg.gravity
	p.initial_velocity_min = cfg.speed[0]
	p.initial_velocity_max = cfg.speed[1]
	p.scale_amount_min = 1.0
	p.scale_amount_max = cfg.size
	p.color_ramp = _ramp(cfg.color, cfg.get("end", cfg.color))
	if cfg.get("add", false):
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = material
	ambient.add_child(p)
	ambient.particles = p
	return ambient


## Keeps the emission area centered on what the camera sees (whole pixels; the motes already
## in the world stay where they are).
func follow(view_center: Vector2) -> void:
	position = view_center.round()


## Fades in, holds, fades out (and shifts toward `end_color` if it differs).
static func _ramp(color: Color, end_color: Color) -> Gradient:
	var gradient := Gradient.new()
	var clear := Color(color, 0.0)
	var tail := end_color if end_color.a < color.a else color
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	gradient.colors = PackedColorArray([clear, color, tail if end_color != color else color, Color(tail, 0.0)])
	return gradient
