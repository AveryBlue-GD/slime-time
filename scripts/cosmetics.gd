class_name Cosmetics
extends RefCounted

## Ticket cosmetics v1 (upgrades v2 batch 2, docs/design/upgrades-v2.md C.2): five goo TRAIL styles
## and map PAPERS (each a bundle: its sheet, its walls and its route; owner 2026-10-21: owned bundles'
## parts are mixed in the wardrobe, Progress.map_paper / map_walls / map_route, style_colors), sold in the hat wheel's SHOP tab (prices: Economy.COSMETICS), owned for
## good (Progress.cosmetics_owned), worn one at a time (Progress.trail_style / map_paper; the
## defaults DEFAULT_TRAIL and DEFAULT_PAPER are free and always owned). All palette / pattern work:
## no new sprite sheets, and nothing in a shader indexes an array at run time.
##   trails (game.gd paints the trail image's cells with `trail_cell`; the shader adds STARRY's specks)
##     INK     the skin's deep shade, alpha 150        GLOW    goo alpha 170 and the trail halo x2
##     GOLD    chalice gold goo (whatever the skin)    CANDY   skin / white stripes every 12 px traveled
##     STARRY  skin goo with 1 px white specks (trail.gdshader `stars`, by pixel hash: deterministic)
##   earned, never sold: ABYSS (Descent floor 10)
##   papers (MapView.palette `paper`, the MAP TABLE's map view; the PAPER button cycles owned ones)
##     BLUEPRINT  blue paper, white ink   NIGHT  dark paper, skin-colored ink   GOLD LEAF  cream paper, gold ink + coins
## The rainbow skin keeps its rainbow trail unless a trail style is worn.

const TRAIL := "trail"
const PAPER := "paper"
const DEFAULT_TRAIL := "skin"
const DEFAULT_PAPER := "parchment"
const DEFAULT_TRAIL_NAME := "SKIN GOO"  # i18n: ignore (English source; shown via display_name)
const DEFAULT_PAPER_NAME := "PARCHMENT"  # i18n: ignore (English source; shown via display_name)

const LIST := [
	{id = "ink", kind = TRAIL, name = "INK TRAIL", about = "DEEP INKY GOO"},  # i18n: ignore (English source; shown via display_name)
	{id = "glow", kind = TRAIL, name = "GLOW TRAIL", about = "THICK GLOWING GOO"},  # i18n: ignore (English source; shown via display_name)
	{id = "gold", kind = TRAIL, name = "GOLD TRAIL", about = "CHALICE GOLD, ANY SKIN"},  # i18n: ignore (English source; shown via display_name)
	{id = "candy", kind = TRAIL, name = "CANDY TRAIL", about = "SWEET STRIPES"},  # i18n: ignore (English source; shown via display_name)
	{id = "starry", kind = TRAIL, name = "STARRY TRAIL", about = "SPECKLED WITH STARS"},  # i18n: ignore (English source; shown via display_name)
	{id = "blueprint", kind = PAPER, name = "BLUEPRINT PAPER", about = "BLUE PAPER, WHITE INK"},  # i18n: ignore (English source; shown via display_name)
	{id = "night", kind = PAPER, name = "NIGHT PAPER", about = "DARK PAPER, SKIN INK"},  # i18n: ignore (English source; shown via display_name)
	{id = "goldleaf", kind = PAPER, name = "GOLD LEAF PAPER", about = "CREAM PAPER, GOLD INK"},  # i18n: ignore (English source; shown via display_name)
	# Dye bundles (Hats.DYES' colors but MIDNIGHT and SNOW: NIGHT and BLUEPRINT / GOLD LEAF are those looks): a pale sheet, deep walls and a
	# route in the dye. Then the flowing bundles (`flow`: MapView.mark_flow, map_flow.gdshader).
	{id = "cherry_paper", kind = PAPER, name = "CHERRY PAPER", about = "A CHERRY SET", dye = Color8(206, 52, 62)},  # i18n: ignore (English source; shown via display_name)
	{id = "tangerine_paper", kind = PAPER, name = "TANGERINE PAPER", about = "A TANGERINE SET", dye = Color8(232, 128, 48)},  # i18n: ignore (English source; shown via display_name)
	{id = "butter_paper", kind = PAPER, name = "BUTTER PAPER", about = "A BUTTER SET", dye = Color8(240, 204, 76)},  # i18n: ignore (English source; shown via display_name)
	{id = "clover_paper", kind = PAPER, name = "CLOVER PAPER", about = "A CLOVER SET", dye = Color8(72, 168, 84)},  # i18n: ignore (English source; shown via display_name)
	{id = "cobalt_paper", kind = PAPER, name = "COBALT PAPER", about = "A COBALT SET", dye = Color8(62, 110, 214)},  # i18n: ignore (English source; shown via display_name)
	{id = "plum_paper", kind = PAPER, name = "PLUM PAPER", about = "A PLUM SET", dye = Color8(124, 78, 196)},  # i18n: ignore (English source; shown via display_name)
	{id = "bubblegum_paper", kind = PAPER, name = "BUBBLEGUM PAPER", about = "A BUBBLEGUM SET", dye = Color8(236, 120, 176)},  # i18n: ignore (English source; shown via display_name)
	{id = "prism_paper", kind = PAPER, name = "PRISM PAPER", about = "TURNS THROUGH THE COLORS", flow = "prism"},  # i18n: ignore (English source; shown via display_name)
	{id = "rainbow_paper", kind = PAPER, name = "RAINBOW PAPER", about = "A FLOWING RAINBOW", flow = "gradient"},  # i18n: ignore (English source; shown via display_name)
	# Earned, never sold (not in the SHOP; `earned` says how): DESCENT batch 3.
	{id = "abyss", kind = TRAIL, name = "ABYSS TRAIL", about = "DARK GOO, FAINT STARS", earned = "REACH DESCENT FLOOR 10"},  # i18n: ignore (English source; shown via display_name)
]

## Trail looks: the goo alpha (0-255) of a painted cell, and the trail halo strength (game.gd TRAIL_GLOW).
const GOO_ALPHA := 120
const INK_ALPHA := 150
const GLOW_ALPHA := 170
const GOLD_ALPHA := 185
const TRAIL_GLOW := 0.3
const GLOW_TRAIL_GLOW := 0.6
const GOLD := Color8(255, 205, 117)
const GOLD_DEEP := Color8(196, 128, 52)
## CANDY: the stripe length (px traveled) and its white.
const CANDY_STRIPE := 12.0
const CANDY_WHITE := Color8(250, 246, 240)
const CANDY_WHITE_DEEP := Color8(214, 206, 214)
## ABYSS (earned on Descent floor 10): deep violet-black goo, faint halo, starry specks.
const ABYSS := Color8(52, 30, 92)
const ABYSS_DEEP := Color8(22, 12, 42)
const ABYSS_ALPHA := 190
const ABYSS_GLOW := 0.45


static func get_item(id: String) -> Dictionary:
	for item: Dictionary in LIST:
		if item.id == id:
			return item
	return {}


static func price(id: String) -> int:
	return int(Economy.COSMETICS.get(id, 0))


static func kind_of(id: String) -> String:
	if id == DEFAULT_TRAIL:
		return TRAIL
	if id == DEFAULT_PAPER:
		return PAPER
	return get_item(id).get("kind", "")


## True for a cosmetic that is earned (e.g. ABYSS: Descent floor 10), never sold.
static func is_earned(id: String) -> bool:
	return get_item(id).has("earned")


## How an earned cosmetic is earned ("" for a sold one).
static func earned_how(id: String) -> String:
	# i18n: how an earned trail is unlocked, wardrobe info line, max 200px
	match id:
		"abyss":
			return Loc.t("trail.abyss.unlock", "REACH DESCENT FLOOR 10")
	return get_item(id).get("earned", "")


## The sold ids of one kind, in shop order (earned ones are left out: they are never sold).
static func ids(kind := "") -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in LIST:
		if (kind == "" or item.kind == kind) and not item.has("earned"):
			out.append(item.id)
	return out


static func display_name(id: String) -> String:
	if id == DEFAULT_TRAIL:
		return Loc.t("trail.skin.name", "SKIN GOO")
	if id == DEFAULT_PAPER:
		return Loc.t("paper.parchment", "PARCHMENT")
	# i18n: wardrobe tile / info line name, max 120px, 1 line
	match id:
		"ink":
			return Loc.t("trail.ink.name", "INK TRAIL")
		"glow":
			return Loc.t("trail.glow.name", "GLOW TRAIL")
		"gold":
			return Loc.t("trail.gold.name", "GOLD TRAIL")
		"candy":
			return Loc.t("trail.candy.name", "CANDY TRAIL")
		"starry":
			return Loc.t("trail.starry.name", "STARRY TRAIL")
		"blueprint":
			return Loc.t("paper.blueprint", "BLUEPRINT PAPER")
		"night":
			return Loc.t("paper.night", "NIGHT PAPER")
		"goldleaf":
			return Loc.t("paper.goldleaf", "GOLD LEAF PAPER")
		"cherry_paper":
			return Loc.t("paper.cherry", "CHERRY PAPER")
		"tangerine_paper":
			return Loc.t("paper.tangerine", "TANGERINE PAPER")
		"butter_paper":
			return Loc.t("paper.butter", "BUTTER PAPER")
		"clover_paper":
			return Loc.t("paper.clover", "CLOVER PAPER")
		"cobalt_paper":
			return Loc.t("paper.cobalt", "COBALT PAPER")
		"plum_paper":
			return Loc.t("paper.plum", "PLUM PAPER")
		"bubblegum_paper":
			return Loc.t("paper.bubblegum", "BUBBLEGUM PAPER")
		"prism_paper":
			return Loc.t("paper.prism", "PRISM PAPER")
		"rainbow_paper":
			return Loc.t("paper.rainbow", "RAINBOW PAPER")
		"abyss":
			return Loc.t("trail.abyss.name", "ABYSS TRAIL")
	return get_item(id).get("name", "")


## The one-line description of a trail or paper ("" for the defaults).
static func about(id: String) -> String:
	# i18n: wardrobe info line, after the name; max 150px, 1 line, keep it short
	match id:
		"ink":
			return Loc.t("trail.ink.desc", "DEEP INKY GOO")
		"glow":
			return Loc.t("trail.glow.desc", "THICK GLOWING GOO")
		"gold":
			return Loc.t("trail.gold.desc", "CHALICE GOLD, ANY SKIN")
		"candy":
			return Loc.t("trail.candy.desc", "SWEET STRIPES")
		"starry":
			return Loc.t("trail.starry.desc", "SPECKLED WITH STARS")
		"blueprint":
			return Loc.t("paper.blueprint.desc", "BLUE PAPER, WHITE INK")
		"night":
			return Loc.t("paper.night.desc", "DARK PAPER, SKIN INK")
		"goldleaf":
			return Loc.t("paper.goldleaf.desc", "CREAM PAPER, GOLD INK")
		"cherry_paper":
			return Loc.t("paper.cherry.desc", "SHEET, WALLS AND ROUTE IN CHERRY")
		"tangerine_paper":
			return Loc.t("paper.tangerine.desc", "SHEET, WALLS AND ROUTE IN TANGERINE")
		"butter_paper":
			return Loc.t("paper.butter.desc", "SHEET, WALLS AND ROUTE IN BUTTER")
		"clover_paper":
			return Loc.t("paper.clover.desc", "SHEET, WALLS AND ROUTE IN CLOVER")
		"cobalt_paper":
			return Loc.t("paper.cobalt.desc", "SHEET, WALLS AND ROUTE IN COBALT")
		"plum_paper":
			return Loc.t("paper.plum.desc", "SHEET, WALLS AND ROUTE IN PLUM")
		"bubblegum_paper":
			return Loc.t("paper.bubblegum.desc", "SHEET, WALLS AND ROUTE IN BUBBLEGUM")
		"prism_paper":
			return Loc.t("paper.prism.desc", "TURNS THROUGH THE COLORS")
		"rainbow_paper":
			return Loc.t("paper.rainbow.desc", "A FLOWING RAINBOW")
		"abyss":
			return Loc.t("trail.abyss.desc", "DARK GOO, FAINT STARS")
	return ""


## Every trail style the player could wear: the default, the sold ones, then the earned ones.
static func trail_ids() -> Array[String]:
	var out: Array[String] = [DEFAULT_TRAIL]
	out.append_array(ids(TRAIL))
	for item: Dictionary in LIST:
		if item.kind == TRAIL and item.has("earned"):
			out.append(item.id)
	return out


static func paper_ids() -> Array[String]:
	var out: Array[String] = [DEFAULT_PAPER]
	out.append_array(ids(PAPER))
	return out


# ---------------------------------------------------------------- trails

## How trail `style` paints for a slime of `skin` (base color; `rainbow` = the rainbow skin):
## {light, deep} = the two goo colors of a cell (a fifth of the cells use `deep`), `rainbow` (the
## rainbow skin's hue bands; only with the default style), `candy` (white stripes), `stars` (the
## shader's specks), `glow` (halo strength).
static func trail_look(style: String, skin: Color, rainbow := false) -> Dictionary:
	var shades := Skins.shades(skin)
	var look := {light = Color(shades.mid, GOO_ALPHA / 255.0), deep = Color(shades.dark, GOO_ALPHA / 255.0),
		rainbow = false, candy = false, stars = false, glow = TRAIL_GLOW}
	match style:
		"ink":
			look.light = Color(shades.deep, INK_ALPHA / 255.0)
			look.deep = Color(shades.outline, INK_ALPHA / 255.0)
		"glow":
			look.light = Color(shades.mid, GLOW_ALPHA / 255.0)
			look.deep = Color(shades.dark, GLOW_ALPHA / 255.0)
			look.glow = GLOW_TRAIL_GLOW
		"gold":
			look.light = Color(GOLD, GOLD_ALPHA / 255.0)
			look.deep = Color(GOLD_DEEP, GOLD_ALPHA / 255.0)
		"candy":
			look.candy = true
		"starry":
			look.stars = true
		"abyss":  # whatever the skin: near-black violet goo with the starry specks
			look.light = Color(ABYSS, ABYSS_ALPHA / 255.0)
			look.deep = Color(ABYSS_DEEP, ABYSS_ALPHA / 255.0)
			look.stars = true
			look.glow = ABYSS_GLOW
		_:
			look.rainbow = rainbow  # the default: the rainbow skin lays rainbow bands
	return look


## The color of a newly painted trail cell: `look` from trail_look, `deep` = this cell is one of the
## darker fifth, `travel` = px the slime has moved this run (CANDY's stripes), `rainbow_hue` (0-1)
## the rainbow skin's hue right now.
static func trail_cell(look: Dictionary, deep: bool, travel: float, rainbow_hue := 0.0) -> Color:
	if look.rainbow:
		return Color.from_hsv(rainbow_hue, 0.85, 0.5 if deep else 0.9, GOO_ALPHA / 255.0)
	if look.candy and posmod(floori(travel / CANDY_STRIPE), 2) == 1:
		return Color(CANDY_WHITE_DEEP if deep else CANDY_WHITE, GOO_ALPHA / 255.0)
	return look.deep if deep else look.light


## A small picture of trail `style` (a wavy goo strip, `size` cells of the trail image; shown at 2x
## like the game's 2 px cells) for the wardrobe and the shop. `locked`: a dark silhouette.
static func trail_preview(style: String, skin: Color, rainbow: bool, size := Vector2i(16, 9), locked := false) -> Image:
	var look := trail_look(style, skin, rainbow)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in size.x:
		var mid := size.y / 2.0 + sin(x * 0.4) * 1.2
		for y in size.y:
			if absf(y + 0.5 - mid) > 2.4:
				continue
			var deep := posmod(hash(Vector2i(x, y)), 5) == 0
			var c := trail_cell(look, deep, x * 2.0 * 3.0, fposmod(x / float(size.x), 1.0) * 0.83)
			image.set_pixel(x, y, Color(0.08, 0.08, 0.12, 0.9) if locked else c)
	return image


# ---------------------------------------------------------------- map papers

## A map style: three owned papers' parts, "sheet|walls|route" (a bare paper id = all three its own;
## Progress.map_style).
static func style_parts(style: String) -> Array[String]:
	var parts: Array[String] = []
	for part in (style.split("|") if "|" in style else PackedStringArray([style, style, style])):
		parts.append(part)
	while parts.size() < 3:
		parts.append(DEFAULT_PAPER)
	return parts.slice(0, 3)


## Which of a paper's colors make up each part of a bundle.
const SHEET_KEYS := ["fog", "floor", "frame", "coin", "coin_edge"]
const WALL_KEYS := ["wall", "start", "goal"]
const ROUTE_KEYS := ["route"]


## The colors style `style` (see style_parts) puts over a map's palette: each part taken from its own
## paper's colors (the default parchment keeps the map's own); `flow` = {palette key: "prism" /
## "gradient"} for parts of a flowing paper. `ink`: the skin color (NIGHT draws in it).
static func style_colors(style: String, ink := Color.WHITE) -> Dictionary:
	var parts := style_parts(style)
	var out := {}
	var flow := {}
	for i in 3:
		var colors := paper_colors(parts[i], ink)
		var mode: String = get_item(parts[i]).get("flow", "")
		for key: String in [SHEET_KEYS, WALL_KEYS, ROUTE_KEYS][i]:
			if colors.has(key):
				out[key] = colors[key]
				if mode != "" and key in ["floor", "wall", "start", "goal", "route"]:
					flow[key] = mode
	if not flow.is_empty():
		out.flow = flow
	return out


## Whether style `style` has a flowing part (its map texture needs map_flow.gdshader).
static func style_flows(style: String) -> bool:
	for part in style_parts(style):
		if get_item(part).has("flow"):
			return true
	return false


## The colors map paper `paper` puts over a map's palette (MapView.palette): {} for the default.
## `ink`: the skin color (NIGHT draws in it). The classic papers keep the red route.
static func paper_colors(paper: String, ink := Color.WHITE) -> Dictionary:
	var item := get_item(paper)
	if item.has("dye"):
		var dye: Color = item.dye
		var sheet := dye.lerp(Color.WHITE, 0.62)
		var walls := dye.darkened(0.55) if dye.get_luminance() > 0.25 else dye.lerp(Color.BLACK, 0.3)
		var route := dye if dye.get_luminance() < 0.7 else dye.darkened(0.45)
		return {fog = dye.darkened(0.85), floor = sheet, wall = walls, start = walls, goal = walls, route = route,
			frame = [dye.darkened(0.8), dye.darkened(0.5), dye, sheet]}
	match item.get("flow", ""):
		"prism":  # (bright and saturated: the shader turns their hue as one)
			var red := Color8(222, 62, 70)
			return {fog = Color8(14, 12, 22), floor = Color8(250, 196, 196), wall = Color8(150, 30, 44), start = Color8(150, 30, 44),
				goal = Color8(150, 30, 44), route = red, frame = [Color8(14, 12, 22), Color8(150, 30, 44), red, Color8(250, 196, 196)]}
		"gradient":  # (mark_flow lays a rainbow across these, then the shader flows it)
			var red := Color8(224, 64, 72)
			return {fog = Color8(14, 12, 22), floor = Color8(250, 198, 198), wall = Color8(152, 32, 46), start = Color8(152, 32, 46),
				goal = Color8(152, 32, 46), route = red, frame = [Color8(14, 12, 22), Color8(152, 32, 46), red, Color8(250, 198, 198)]}
	match paper:
		"blueprint":
			var white := Color8(232, 242, 255)
			return {fog = Color8(10, 20, 46), floor = Color8(36, 82, 158), wall = white, start = white, goal = white,
				coin = white, coin_edge = Color8(20, 46, 96),
				frame = [Color8(10, 20, 46), Color8(30, 64, 128), Color8(80, 130, 200), white]}
		"night":
			var bright := Color.from_hsv(ink.h, minf(ink.s, 0.8), maxf(ink.v, 0.75))
			return {fog = Color8(6, 6, 12), floor = Color8(46, 44, 72), wall = bright, start = bright, goal = bright,
				frame = [Color8(6, 6, 12), Color8(36, 34, 56), Color8(62, 60, 92), bright]}
		"goldleaf":
			var gold := Color8(186, 136, 40)
			return {fog = Color8(40, 30, 18), floor = Color8(246, 234, 200), wall = gold, start = gold, goal = gold,
				coin = Color8(236, 186, 60), coin_edge = Color8(150, 98, 24),
				frame = [Color8(60, 40, 16), Color8(150, 104, 32), Color8(214, 168, 70), Color8(255, 228, 140)]}
	return {}
