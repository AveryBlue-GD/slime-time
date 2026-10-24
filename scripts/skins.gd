class_name Skins
extends RefCounted

## Slime colors. Each preset unlocks once `unlock` levels have been cleared (Lime from the
## start, then one per level 1-9). A level's first run is played in the skin the level before it
## unlocked, so each one is matched to the next level's theme (see Themes.BY_LEVEL). "custom" (color wheel) unlocks after the final level.
## "rainbow" unlocks by finding every coin in the story (its jelly version, like the custom
## color's, by beating level 10 on hard): rainbow bands flow across the slime like a wave, and its
## trail cycles through the rainbow.
## Opaque (solid) slimes are the normal-mode skins and the default look. Every skin also comes in
## a see-through jelly version ("JELLY: ON" on the skins screen), the hard-mode reward: unlocked by
## beating its level on hard mode (see jelly_level). Owner decision D14.
## Sprites are drawn in three green goo shades; the palette-swap shader replaces them with
## shades derived from the skin's base color, so one sprite sheet serves every skin.

const DEFAULT := "lime"
const CUSTOM := "custom"
const RAINBOW := "rainbow"
## "stopwatch" unlocks with all 30 normal-mode medals (gold on every level): a pale gold-trimmed
## clock-face jelly with a working clock inside (see Stopwatch). Its look is fixed (STOPWATCH_SHADES),
## so it has no opaque/jelly unlock of its own: both versions open together (the one exception
## to "jelly = hard-mode reward").
const STOPWATCH := "stopwatch"
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
## Whether new slime materials are see-through jelly (kept in step with Progress.jelly; off =
## opaque, the default).
static var jelly := false
## Stand-in base color for the rainbow skin wherever one color is needed.
const RAINBOW_BASE := Color8(230, 60, 60)
## PASTEL skins (owner, 2026-10-22): the ten presets and the rainbow each have a soft pastel version
## (opaque and jelly), unlocked by randomizer wins: one preset every PASTEL_WINS_STEP wins in PRESETS
## order (Lime at 5 ... Ember at 50) and the rainbow at RAINBOW_PASTEL_WINS, each on top of that skin's
## own opaque / jelly unlock (pastel_wins, is_unlocked). CHAMELEON and the STOPWATCH have no pastel
## version. While `pastel` is on (kept in step with Progress.pastel; the skins screen sets it to the
## version on view) presets swap to the soft PASTEL bases (pastel_shades) and the rainbow to paler
## bands (shader `pastel_rainbow`).
static var pastel := false
const PASTEL_WINS_STEP := 5
const RAINBOW_PASTEL_WINS := 100
const PASTEL := {
	lime = Color8(142, 230, 168),
	mint = Color8(163, 240, 223),
	lemon = Color8(255, 238, 153),
	ocean = Color8(165, 202, 250),
	grape = Color8(208, 171, 245),
	crimson = Color8(250, 167, 181),
	frost = Color8(217, 242, 255),
	shadow = Color8(167, 155, 194),
	bubblegum = Color8(255, 178, 223),
	ember = Color8(255, 194, 153),
}

const PRESETS := [
	{id = "lime", name = "LIME", color = Color8(56, 183, 100), unlock = 0},  # i18n: ignore (English source); 1 Dark Dungeon
	{id = "mint", name = "MINT", color = Color8(80, 220, 190), unlock = 1},  # i18n: ignore (English source); 2 Mossy Mines: lichen
	{id = "lemon", name = "LEMON", color = Color8(236, 206, 58), unlock = 2},  # i18n: ignore (English source); 3 Sandstone Sanctum: sun
	{id = "ocean", name = "OCEAN", color = Color8(59, 120, 220), unlock = 3},  # i18n: ignore (English source); 4 Sunken Shrine
	{id = "grape", name = "GRAPE", color = Color8(140, 72, 200), unlock = 4},  # i18n: ignore (English source); 5 Toxic Tunnels: toxic ooze
	{id = "crimson", name = "CRIMSON", color = Color8(200, 40, 60), unlock = 5},  # i18n: ignore (English source); 6 Creepy Catacombs: blood
	{id = "frost", name = "FROST", color = Color8(190, 225, 245), unlock = 6},  # i18n: ignore (English source); 7 Frozen Fortress
	{id = "shadow", name = "INKKY", color = Color8(84, 70, 110), unlock = 7},  # i18n: ignore (English source); 8 Obsidian Oubliette
	{id = "bubblegum", name = "BUBBLEGUM", color = Color8(240, 110, 180), unlock = 8},  # i18n: ignore (English source); 9 Crystal Caverns
	{id = "ember", name = "EMBER", color = Color8(239, 125, 47), unlock = 9},  # i18n: ignore (English source); 10 Volcanic Vault: molten
]


static func get_preset(id: String) -> Dictionary:
	for preset: Dictionary in PRESETS:
		if preset.id == id:
			return preset
	return {}


## Levels that must be cleared before this skin can be used (the rainbow also needs every coin;
## its jelly version needs this level on hard, see jelly_level).
static func unlock_level(id: String) -> int:
	return Levels.COUNT if id == CUSTOM or id == RAINBOW or id == STOPWATCH else int(get_preset(id).get("unlock", 0))


## The hard-mode level that unlocks a skin's see-through jelly version: the same level that
## unlocks it normally (the starter Lime needs hard level 1).
static func jelly_level(id: String) -> int:
	return maxi(unlock_level(id), 1)


## Whether skin `id` has a pastel version (the presets and the rainbow).
static func has_pastel(id: String) -> bool:
	return id == RAINBOW or not get_preset(id).is_empty()


## Randomizer wins that unlock skin `id`'s pastel version (-1: it has none).
static func pastel_wins(id: String) -> int:
	if id == RAINBOW:
		return RAINBOW_PASTEL_WINS
	for i in PRESETS.size():
		if PRESETS[i].id == id:
			return (i + 1) * PASTEL_WINS_STEP
	return -1


## Every randomizer-win count that unlocks a pastel version (the presets, then the rainbow): the achievements page's reward road.
static func pastel_marks() -> Array[int]:
	var out: Array[int] = []
	for id: String in PRESETS.map(func(preset: Dictionary) -> String: return preset.id) + [RAINBOW]:
		out.append(pastel_wins(id))
	return out


## The skin whose pastel version unlocks at exactly `wins` randomizer wins ("" if none).
static func pastel_unlocked_at(wins: int) -> String:
	for id: String in PRESETS.map(func(preset: Dictionary) -> String: return preset.id) + [RAINBOW]:
		if pastel_wins(id) == wins:
			return id
	return ""


## Opaque skins (`jelly_version` false) unlock with the story levels (the rainbow with every story
## coin found: `coins_found`); jelly ones with the same level beaten on hard mode (`hard_cleared` =
## those levels). The stopwatch opens both together with all 30 medals. A pastel version
## (`pastel_version`) also needs its pastel_wins randomizer wins (`random_wins`).
static func is_unlocked(id: String, levels_cleared: int, hard_cleared: Array = [], jelly_version := false, coins_found := 0, all_medals := false, pastel_version := false, random_wins := 0) -> bool:
	if id != RAINBOW and id != CUSTOM and id != STOPWATCH and get_preset(id).is_empty():
		return false
	if pastel_version and (not has_pastel(id) or random_wins < pastel_wins(id)):
		return false
	if id == STOPWATCH:
		return all_medals
	if jelly_version:
		return jelly_level(id) in hard_cleared
	if id == RAINBOW:
		return coins_found >= Levels.total_coins()
	return levels_cleared >= unlock_level(id)


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


## The English names stay in PRESETS / the *_NAME consts (internal, tools); players see these.
static func display_name(id: String) -> String:
	# i18n: skin name, max 80px, 1 line; used on the skins screen and in the win text
	match id:
		"custom":
			return Loc.t("skin.custom", "CHAMELEON")
		"rainbow":
			return Loc.t("skin.rainbow", "RAINBOW")
		"stopwatch":
			return Loc.t("skin.stopwatch", "STOPWATCH")
		"lime":
			return Loc.t("skin.lime", "LIME")
		"mint":
			return Loc.t("skin.mint", "MINT")
		"lemon":
			return Loc.t("skin.lemon", "LEMON")
		"ocean":
			return Loc.t("skin.ocean", "OCEAN")
		"grape":
			return Loc.t("skin.grape", "GRAPE")
		"crimson":
			return Loc.t("skin.crimson", "CRIMSON")
		"frost":
			return Loc.t("skin.frost", "FROST")
		"shadow":
			return Loc.t("skin.shadow", "INKKY")
		"bubblegum":
			return Loc.t("skin.bubblegum", "BUBBLEGUM")
		"ember":
			return Loc.t("skin.ember", "EMBER")
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
		return display_name(CUSTOM)
	for preset: Dictionary in PRESETS:
		if preset.unlock == level:
			return display_name(preset.id)
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


## Shades for a PASTEL base: brighter and softer than shades(), with gentler shadows.
static func pastel_shades(base: Color) -> Dictionary:
	return {
		highlight = Color.from_hsv(wrapf(base.h + 0.05, 0.0, 1.0), base.s * 0.22, 1.0),
		light = Color.from_hsv(wrapf(base.h + 0.03, 0.0, 1.0), base.s * 0.6, minf(base.v + 0.04, 1.0)),
		mid = base,
		dark = Color.from_hsv(wrapf(base.h - 0.035, 0.0, 1.0), minf(base.s * 1.3, 1.0), base.v * 0.82),
		deep = Color.from_hsv(wrapf(base.h - 0.06, 0.0, 1.0), minf(base.s * 1.5, 1.0), base.v * 0.66),
		outline = Color.from_hsv(wrapf(base.h - 0.08, 0.0, 1.0), minf(base.s * 1.7, 0.8), base.v * 0.42),
	}


## The PASTEL base for a preset's color (or its pastel color itself), or null for any other color
## (CHAMELEON).
static func pastel_base(base: Color) -> Variant:
	for preset: Dictionary in PRESETS:
		if (preset.color as Color).is_equal_approx(base) or (PASTEL[preset.id] as Color).is_equal_approx(base):
			return PASTEL[preset.id]
	return null


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
	material.set_shader_parameter("pastel_rainbow", pastel and rainbow and not clock)
	var colors := STOPWATCH_SHADES if clock else shades(base)
	if pastel and not clock:  # (the stopwatch has no pastel version)
		var soft: Variant = pastel_base(base)
		if soft != null:
			colors = pastel_shades(soft)
	for shade: String in colors:
		material.set_shader_parameter(shade, colors[shade])
