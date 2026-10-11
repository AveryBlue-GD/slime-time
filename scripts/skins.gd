class_name Skins
extends RefCounted

## Slime colors. Each preset unlocks once `unlock` levels have been cleared (Ember from the
## start, then one per level 1-9). "custom" (color wheel + glow) unlocks after the final level.
## "rainbow" unlocks after beating RAINBOW_RANDOMS randomizer mazes: rainbow bands flow across
## the slime like a wave, and its trail cycles through the rainbow.
## Sprites are drawn in three green goo shades; the palette-swap shader replaces them with
## shades derived from the skin's base color, so one sprite sheet serves every skin.

const DEFAULT := "ember"
const CUSTOM := "custom"
const CUSTOM_NAME := "YOUR COLOR"
const RAINBOW := "rainbow"
const RAINBOW_NAME := "RAINBOW"
const RAINBOW_RANDOMS := 5
## Stand-in base color for the rainbow skin wherever one color is needed.
const RAINBOW_BASE := Color8(230, 60, 60)

const PRESETS := [
	{id = "ember", name = "EMBER", color = Color8(239, 125, 47), unlock = 0},
	{id = "lime", name = "LIME", color = Color8(56, 183, 100), unlock = 1},
	{id = "ocean", name = "OCEAN", color = Color8(59, 120, 220), unlock = 2},
	{id = "grape", name = "GRAPE", color = Color8(140, 72, 200), unlock = 3},
	{id = "bubblegum", name = "BUBBLEGUM", color = Color8(240, 110, 180), unlock = 4},
	{id = "lemon", name = "LEMON", color = Color8(236, 206, 58), unlock = 5},
	{id = "mint", name = "MINT", color = Color8(80, 220, 190), unlock = 6},
	{id = "crimson", name = "CRIMSON", color = Color8(200, 40, 60), unlock = 7},
	{id = "frost", name = "FROST", color = Color8(190, 225, 245), unlock = 8},
	{id = "shadow", name = "SHADOW", color = Color8(84, 70, 110), unlock = 9},
]

## The goo shades the sprite sheet is drawn in (palette "l", "m", "n" in the art script).
const SOURCE_LIGHT := Color8(148, 226, 112)
const SOURCE_MID := Color8(56, 183, 100)
const SOURCE_DARK := Color8(37, 113, 121)


static func get_preset(id: String) -> Dictionary:
	for preset: Dictionary in PRESETS:
		if preset.id == id:
			return preset
	return {}


## Levels that must be cleared before this skin can be used.
static func unlock_level(id: String) -> int:
	return Levels.COUNT if id == CUSTOM else int(get_preset(id).get("unlock", 0))


static func is_unlocked(id: String, levels_cleared: int, randoms_won := 0) -> bool:
	if id == RAINBOW:
		return randoms_won >= RAINBOW_RANDOMS
	return levels_cleared >= unlock_level(id)


static func display_name(id: String) -> String:
	if id == CUSTOM:
		return CUSTOM_NAME
	if id == RAINBOW:
		return RAINBOW_NAME
	return get_preset(id).get("name", "")


## Id of the skin that clearing `level` unlocks (level 0 = the starting skin). The next level's
## first run is played in it, to show off the reward.
static func skin_for_level(level: int) -> String:
	if level >= Levels.COUNT:
		return CUSTOM
	for preset: Dictionary in PRESETS:
		if preset.unlock == level:
			return preset.id
	return DEFAULT


## Display name of the skin that clearing `level` unlocks ("" if none).
static func unlocked_by_level(level: int) -> String:
	if level == Levels.COUNT:
		return CUSTOM_NAME
	for preset: Dictionary in PRESETS:
		if preset.unlock == level:
			return preset.name
	return ""


## Goo shades built from one base color: highlight, light, mid (the base), dark, deep shadow and
## the outline. Shadows drift a little toward cooler hues and lights toward warmer ones.
## (tools/make_placeholder_art.py app_icon uses the same math.)
static func shades(base: Color) -> Dictionary:
	return {
		highlight = Color.from_hsv(wrapf(base.h + 0.05, 0.0, 1.0), base.s * 0.35, minf(base.v * 1.25 + 0.3, 1.0)),
		light = Color.from_hsv(wrapf(base.h + 0.03, 0.0, 1.0), base.s * 0.7, minf(base.v * 1.2 + 0.12, 1.0)),
		mid = base,
		dark = Color.from_hsv(wrapf(base.h - 0.05, 0.0, 1.0), minf(base.s * 1.1, 1.0), base.v * 0.55),
		deep = Color.from_hsv(wrapf(base.h - 0.08, 0.0, 1.0), minf(base.s * 1.15, 1.0), base.v * 0.33),
		outline = Color.from_hsv(wrapf(base.h - 0.1, 0.0, 1.0), minf(base.s * 1.2, 1.0), base.v * 0.17),
	}


## Palette-swap material for a slime sprite in this color (or the flowing rainbow).
static func make_material(base: Color, rainbow := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/slime_skin.gdshader")
	apply_to(material, base, rainbow)
	return material


static func apply_to(material: ShaderMaterial, base: Color, rainbow := false) -> void:
	material.set_shader_parameter("rainbow", rainbow)
	var colors := shades(base)
	for shade: String in colors:
		material.set_shader_parameter(shade, colors[shade])
