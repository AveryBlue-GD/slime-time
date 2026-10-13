class_name Skins
extends RefCounted

## Slime colors. Each preset unlocks once `unlock` levels have been cleared (Lime from the
## start, then one per level 1-9). A level's first run is played in the skin the level before it
## unlocked, so each one is matched to the next level's theme (see Themes.BY_LEVEL). "custom" (color wheel) unlocks after the final level.
## "rainbow" unlocks by finding every coin in the story (its solid version, like the custom
## color's, by beating level 10 on hard): rainbow bands flow across the slime like a wave, and its
## trail cycles through the rainbow.
## Jelly: slimes are see-through jelly by default. Every skin also comes in a solid version
## ("JELLY OFF" on the skins screen), unlocked by beating its level on hard mode instead
## (see solid_level).
## Sprites are drawn in three green goo shades; the palette-swap shader replaces them with
## shades derived from the skin's base color, so one sprite sheet serves every skin.

const DEFAULT := "lime"
const CUSTOM := "custom"
const CUSTOM_NAME := "CHAMELEON"
const RAINBOW := "rainbow"
const RAINBOW_NAME := "RAINBOW"
## "stopwatch" unlocks with all 30 normal-mode medals (gold on every level): a pale gold-trimmed
## clock-face jelly with a working clock inside (see Stopwatch). Its look is fixed (STOPWATCH_SHADES),
## so it has no solid/jelly unlock of its own: both versions open together.
const STOPWATCH := "stopwatch"
const STOPWATCH_NAME := "STOPWATCH"
## Stand-in base color (gold) wherever one color is needed (trail, meter, menu text).
const STOPWATCH_BASE := Color8(240, 190, 60)
const STOPWATCH_SHADES := {
	highlight = Color8(255, 253, 240),
	light = Color8(252, 247, 226),
	mid = Color8(244, 236, 208),
	dark = Color8(222, 204, 150),
	deep = Color8(226, 164, 40),
	outline = Color8(122, 74, 16),
}
## Whether new slime materials are see-through jelly (kept in step with Progress.jelly).
static var jelly := true
## Stand-in base color for the rainbow skin wherever one color is needed.
const RAINBOW_BASE := Color8(230, 60, 60)

const PRESETS := [
	{id = "lime", name = "LIME", color = Color8(56, 183, 100), unlock = 0},           # 1 Dank Dungeon
	{id = "mint", name = "MINT", color = Color8(80, 220, 190), unlock = 1},           # 2 Mossy Mines: lichen
	{id = "lemon", name = "LEMON", color = Color8(236, 206, 58), unlock = 2},         # 3 Sandstone Sanctum: sun
	{id = "ocean", name = "OCEAN", color = Color8(59, 120, 220), unlock = 3},         # 4 Sunken Shrine
	{id = "grape", name = "GRAPE", color = Color8(140, 72, 200), unlock = 4},         # 5 Toxic Tunnels: toxic ooze
	{id = "crimson", name = "CRIMSON", color = Color8(200, 40, 60), unlock = 5},      # 6 Creepy Catacombs: blood
	{id = "frost", name = "FROST", color = Color8(190, 225, 245), unlock = 6},        # 7 Frozen Fortress
	{id = "shadow", name = "INKKY", color = Color8(84, 70, 110), unlock = 7},        # 8 Obsidian Oubliette
	{id = "bubblegum", name = "BUBBLEGUM", color = Color8(240, 110, 180), unlock = 8},  # 9 Crystal Caverns
	{id = "ember", name = "EMBER", color = Color8(239, 125, 47), unlock = 9},         # 10 Volcanic Vault: molten
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


## Levels that must be cleared before this skin can be used (the rainbow also needs every coin;
## its solid version needs this level on hard, see solid_level).
static func unlock_level(id: String) -> int:
	return Levels.COUNT if id == CUSTOM or id == RAINBOW or id == STOPWATCH else int(get_preset(id).get("unlock", 0))


## The hard-mode level that unlocks a skin's solid (jelly off) version: the same level that
## unlocks it normally (the starter Lime needs hard level 1).
static func solid_level(id: String) -> int:
	return maxi(unlock_level(id), 1)


## Jelly skins unlock with the story levels (the rainbow with every story coin found:
## `coins_found`); solid ones (`jelly` false) with the same level beaten on hard mode
## (`hard_cleared` = those levels).
static func is_unlocked(id: String, levels_cleared: int, hard_cleared: Array = [], jelly_version := true, coins_found := 0, all_medals := false) -> bool:
	if id != RAINBOW and id != CUSTOM and id != STOPWATCH and get_preset(id).is_empty():
		return false
	if id == STOPWATCH:
		return all_medals
	if jelly_version and id == RAINBOW:
		return coins_found >= Levels.total_coins()
	if jelly_version:
		return levels_cleared >= unlock_level(id)
	return solid_level(id) in hard_cleared


## The color a level's atmosphere (fog, ambient motes) borrows from a skin: its base color, except
## the rainbow and the stopwatch (and anything unknown), which use a neutral warm gold/cream so the
## level's own look stays readable. Alpha 0 = no tint.
const ATMOSPHERE_NEUTRAL := Color8(255, 222, 150)
const ATMOSPHERE_FOG_MIX := 0.32
const ATMOSPHERE_MOTE_MIX := 0.4


static func atmosphere_color(id: String, base: Color) -> Color:
	if id == RAINBOW or id == STOPWATCH or base.s < 0.1:  # (no hue to lend: grey, white, black)
		return ATMOSPHERE_NEUTRAL
	return base


## `color` (dark fog / bright mote) with `tint`'s hue blended in by `amount`, keeping its own
## brightness (value) and alpha, so a tint can never brighten the fog or hide a theme's identity.
static func tinted(color: Color, tint: Color, amount: float) -> Color:
	if tint.a <= 0.0:
		return color
	if tint.s < 0.1:  # grey / white / black has no hue to lend (forcing saturation would turn the fog red)
		return color
	var target := Color.from_hsv(tint.h, clampf(tint.s, 0.35, 0.8), color.v, color.a)
	var mixed := color.lerp(target, amount)
	return Color.from_hsv(mixed.h, mixed.s, color.v, color.a)


static func display_name(id: String) -> String:
	if id == CUSTOM:
		return CUSTOM_NAME
	if id == RAINBOW:
		return RAINBOW_NAME
	if id == STOPWATCH:
		return STOPWATCH_NAME
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
static func make_material(base: Color, rainbow := false, clock := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/slime_skin.gdshader")
	material.set_shader_parameter("translucency", 1.0 if jelly else 0.0)
	apply_to(material, base, rainbow, clock)
	return material


static func apply_to(material: ShaderMaterial, base: Color, rainbow := false, clock := false) -> void:
	material.set_shader_parameter("rainbow", rainbow)
	material.set_shader_parameter("clock_on", 1.0 if clock else 0.0)
	var colors := STOPWATCH_SHADES if clock else shades(base)
	for shade: String in colors:
		material.set_shader_parameter(shade, colors[shade])
