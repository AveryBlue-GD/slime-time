class_name Themes
extends RefCounted

## Art themes: each story level has its own look, and every randomizer maze picks one at random
## (from its seed, so replaying a maze keeps its theme). A theme recolors the wall and floor tiles
## through tile_theme.gdshader (a gradient map: dark / mid / light, keeping the art's shading) and
## tints the fog. The Dungeon theme is the original art, untouched.
##
## walls / floor: [dark, mid, light] colors. keep: how much moss, puddles and other colorful
## details keep their own color (0-1). fog: [deep, mist].

const DUNGEON := "dungeon"

const ALL := {
	"dungeon": {name = "THE DUNGEON"},
	"mossy": {
		name = "MOSSY CAVERN",
		walls = [Color8(18, 30, 24), Color8(66, 104, 70), Color8(160, 204, 128)],
		floor = [Color8(14, 22, 18), Color8(36, 52, 36), Color8(62, 84, 52)],
		keep = 0.8,
		fog = [Color8(12, 24, 18), Color8(42, 66, 50)],
	},
	"sandstone": {
		name = "SANDSTONE RUINS",
		walls = [Color8(42, 26, 22), Color8(156, 108, 66), Color8(236, 202, 146)],
		floor = [Color8(32, 22, 20), Color8(76, 54, 42), Color8(110, 84, 62)],
		keep = 0.3,
		fog = [Color8(30, 22, 20), Color8(90, 72, 58)],
	},
	"sunken": {
		name = "SUNKEN TEMPLE",
		walls = [Color8(12, 30, 36), Color8(52, 116, 112), Color8(150, 214, 196)],
		floor = [Color8(10, 20, 34), Color8(26, 46, 68), Color8(44, 72, 96)],
		keep = 0.6,
		fog = [Color8(8, 20, 30), Color8(36, 70, 84)],
	},
	"sewers": {
		name = "TOXIC SEWERS",
		walls = [Color8(24, 28, 18), Color8(90, 100, 62), Color8(186, 196, 120)],
		floor = [Color8(20, 26, 12), Color8(46, 62, 24), Color8(80, 104, 34)],
		keep = 0.5,
		fog = [Color8(20, 28, 10), Color8(72, 90, 36)],
	},
	"catacombs": {
		name = "BONE CATACOMBS",
		walls = [Color8(30, 24, 22), Color8(120, 108, 96), Color8(222, 210, 186)],
		floor = [Color8(24, 18, 16), Color8(52, 42, 36), Color8(80, 66, 56)],
		keep = 0.3,
		fog = [Color8(24, 20, 18), Color8(74, 66, 60)],
	},
	"frozen": {
		name = "FROZEN CRYPT",
		walls = [Color8(18, 26, 50), Color8(98, 142, 194), Color8(224, 242, 255)],
		floor = [Color8(14, 20, 38), Color8(36, 50, 82), Color8(62, 84, 122)],
		keep = 0.4,
		fog = [Color8(14, 20, 38), Color8(72, 98, 134)],
	},
	"obsidian": {
		name = "OBSIDIAN HALLS",
		walls = [Color8(10, 10, 18), Color8(54, 58, 84), Color8(156, 166, 210)],
		floor = [Color8(8, 8, 14), Color8(26, 26, 38), Color8(44, 46, 64)],
		keep = 0.3,
		fog = [Color8(6, 6, 12), Color8(34, 36, 58)],
	},
	"crystal": {
		name = "CRYSTAL GROTTO",
		walls = [Color8(30, 16, 46), Color8(124, 74, 176), Color8(228, 178, 255)],
		floor = [Color8(20, 14, 34), Color8(46, 32, 70), Color8(74, 54, 104)],
		keep = 0.5,
		fog = [Color8(20, 10, 34), Color8(78, 50, 110)],
	},
	"volcanic": {
		name = "VOLCANIC DEPTHS",
		walls = [Color8(20, 12, 14), Color8(84, 52, 50), Color8(192, 118, 80)],
		floor = [Color8(20, 10, 10), Color8(54, 24, 20), Color8(104, 40, 24)],
		keep = 0.2,
		fog = [Color8(28, 10, 10), Color8(90, 36, 28)],
	},
}

## One per story level, getting stranger the deeper you go.
const BY_LEVEL: Array[String] = [
	"dungeon", "mossy", "sandstone", "sunken", "sewers",
	"catacombs", "frozen", "obsidian", "crystal", "volcanic",
]

## Source-art brightness ranges for the gradient map (the floors are much darker than the walls).
const WALL_LUM := Vector2(0.1, 0.82)
const FLOOR_LUM := Vector2(0.1, 0.3)


static func for_level(level: int) -> String:
	return BY_LEVEL[clampi(level, 1, BY_LEVEL.size()) - 1]


## A random theme for a randomizer maze, fixed by its seed.
static func for_seed(maze_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed * 31 + 7
	return BY_LEVEL[rng.randi_range(0, BY_LEVEL.size() - 1)]


static func display_name(id: String) -> String:
	return ALL.get(id, ALL[DUNGEON]).name


## Recolors a floor/wall/fillet layer set (no-op for the original Dungeon look).
static func apply(id: String, floor_layer: CanvasItem, wall_layers: Array) -> void:
	var theme: Dictionary = ALL.get(id, ALL[DUNGEON])
	if not theme.has("walls"):
		floor_layer.material = null
		for layer: CanvasItem in wall_layers:
			layer.material = null
		return
	floor_layer.material = _material(theme.floor, FLOOR_LUM, theme.keep)
	var wall_material := _material(theme.walls, WALL_LUM, theme.keep)
	for layer: CanvasItem in wall_layers:
		layer.material = wall_material


## The fog's [deep, mist] colors, or an empty array to keep the default.
static func fog_colors(id: String) -> Array:
	return ALL.get(id, ALL[DUNGEON]).get("fog", [])


static func _material(ramp: Array, lum: Vector2, keep: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/tile_theme.gdshader")
	material.set_shader_parameter("dark", ramp[0])
	material.set_shader_parameter("mid", ramp[1])
	material.set_shader_parameter("light", ramp[2])
	material.set_shader_parameter("lum_low", lum.x)
	material.set_shader_parameter("lum_high", lum.y)
	material.set_shader_parameter("keep_color", keep)
	return material
