class_name LightLife
extends RefCounted

## LIGHT & LIFE (Economy.LIGHT_LIFE_TEST, BM-09): the numbers fog.gdshader's light effects are fed with.
## The shader does the drawing; this only picks colours per theme and the skin.

## The goal's god-rays reach this far (12 tiles) and the win ring lasts this long (s).
## GOAL_RAYS off (owner, 2026-10-24: the rays through the fog gave the chalice away and made mazes too easy).
const GOAL_RAYS := false
const GOAL_REACH := 192.0
const SUNRISE_TIME := 1.6
## Light pocket: radius (px) and strength of the tint over the clear ground.
const POCKET_RADIUS := 44.0
const POCKET_STRENGTH := 0.16
const GLINT := Color(1.0, 1.0, 0.9)
const GOLD := Color(1.0, 0.82, 0.3)
## How much of the skin colour is mixed into the theme's light.
const SKIN_MIX := 0.35

## The light's own colour per theme (a faint cast, not a lamp).
const THEME_LIGHT := {
	"dungeon": Color(0.8, 0.9, 1.0),
	"mossy": Color(0.6, 1.0, 0.6),
	"sandstone": Color(1.0, 0.85, 0.5),
	"sunken": Color(0.5, 0.9, 1.0),
	"sewers": Color(0.8, 1.0, 0.4),
	"catacombs": Color(0.9, 0.75, 0.85),
	"frozen": Color(0.8, 0.95, 1.0),
	"obsidian": Color(0.7, 0.55, 1.0),
	"crystal": Color(1.0, 0.7, 1.0),
	"volcanic": Color(1.0, 0.55, 0.25),
}


## The tint of the lit pocket: the theme's light leaning toward the worn skin colour.
static func pocket_tint(theme: String, skin: Color) -> Color:
	var base: Color = THEME_LIGHT.get(theme, Color(0.9, 0.95, 1.0))
	return base.lerp(Color(skin, 1.0), SKIN_MIX)


## Pushes the static settings into the maze fog's material.
static func setup(material: ShaderMaterial, theme: String, skin: Color, trail_texture: Texture2D) -> void:
	var tint := pocket_tint(theme, skin)
	material.set_shader_parameter("ll_on", true)
	material.set_shader_parameter("trail_tex", trail_texture)
	material.set_shader_parameter("ll_tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("ll_strength", POCKET_STRENGTH)
	material.set_shader_parameter("ll_radius", POCKET_RADIUS)
	material.set_shader_parameter("ll_glint", Vector3(GLINT.r, GLINT.g, GLINT.b))
	material.set_shader_parameter("goal_color", Vector3(GOLD.r, GOLD.g, GOLD.b))


## Per frame: the goal's rays (position, or strength 0 when there is no goal / the level is over) and the sunrise clock.
static func frame(material: ShaderMaterial, goal_pos: Vector2, rays: bool, sunrise_t: float) -> void:
	material.set_shader_parameter("goal_fx", Vector4(goal_pos.x, goal_pos.y, GOAL_REACH, 1.0 if rays and GOAL_RAYS else 0.0))
	material.set_shader_parameter("sunrise", sunrise_t if sunrise_t >= 0.0 and sunrise_t < SUNRISE_TIME else -1.0)
