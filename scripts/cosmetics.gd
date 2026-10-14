class_name Cosmetics
extends RefCounted

## Ticket cosmetics v1 (upgrades v2 batch 2, docs/design/upgrades-v2.md C.2): five goo TRAIL styles
## and three map PAPERS, sold in the hat wheel's SHOP tab (prices: Economy.COSMETICS), owned for
## good (Progress.cosmetics_owned), worn one at a time (Progress.trail_style / map_paper; the
## defaults DEFAULT_TRAIL and DEFAULT_PAPER are free and always owned). All palette / pattern work:
## no new sprite sheets, and nothing in a shader indexes an array at run time.
##   trails (game.gd paints the trail image's cells with `trail_cell`; the shader adds STARRY's specks)
##     INK     the skin's deep shade, alpha 150        GLOW    goo alpha 170 and the trail halo x2
##     GOLD    chalice gold goo (whatever the skin)    CANDY   skin / white stripes every 12 px traveled
##     STARRY  skin goo with 1 px white specks (trail.gdshader `stars`, by pixel hash: deterministic)
##   earned, never sold: ABYSS (Descent floor 10), EMBER (HEAT 7+ on every hard level)
##   papers (MapView.palette `paper`, the MAP TABLE's map view; the PAPER button cycles owned ones)
##     BLUEPRINT  blue paper, white ink   NIGHT  dark paper, skin-colored ink   GOLD LEAF  cream paper, gold ink + coins
## The rainbow skin keeps its rainbow trail unless a trail style is worn.

const TRAIL := "trail"
const PAPER := "paper"
const DEFAULT_TRAIL := "skin"
const DEFAULT_PAPER := "parchment"
const DEFAULT_TRAIL_NAME := "SKIN GOO"
const DEFAULT_PAPER_NAME := "PARCHMENT"

const LIST := [
	{id = "ink", kind = TRAIL, name = "INK TRAIL", about = "DEEP INKY GOO"},
	{id = "glow", kind = TRAIL, name = "GLOW TRAIL", about = "THICK GLOWING GOO"},
	{id = "gold", kind = TRAIL, name = "GOLD TRAIL", about = "CHALICE GOLD, ANY SKIN"},
	{id = "candy", kind = TRAIL, name = "CANDY TRAIL", about = "SWEET STRIPES"},
	{id = "starry", kind = TRAIL, name = "STARRY TRAIL", about = "SPECKLED WITH STARS"},
	{id = "blueprint", kind = PAPER, name = "BLUEPRINT PAPER", about = "BLUE PAPER, WHITE INK"},
	{id = "night", kind = PAPER, name = "NIGHT PAPER", about = "DARK PAPER, SKIN INK"},
	{id = "goldleaf", kind = PAPER, name = "GOLD LEAF PAPER", about = "CREAM PAPER, GOLD INK"},
	# Earned, never sold (not in the SHOP; `earned` says how): DESCENT batch 3.
	{id = "abyss", kind = TRAIL, name = "ABYSS TRAIL", about = "DARK GOO, FAINT STARS", earned = "REACH DESCENT FLOOR 10"},
	# Earned on HEAT (batch 4): every hard level cleared at heat Economy.HEAT_EMBER+.
	{id = "ember", kind = TRAIL, name = "EMBER TRAIL", about = "GLOWING EMBERS, ANY SKIN", earned = "HEAT 7 ON EVERY HARD LEVEL"},
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
## EMBER (earned with HEAT 7+ on every hard level): glowing orange-red goo, a strong halo and
## sparks (the shader's specks).
const EMBER := Color8(255, 120, 40)
const EMBER_DEEP := Color8(170, 40, 24)
const EMBER_ALPHA := 180
const EMBER_GLOW := 0.7


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
		return DEFAULT_TRAIL_NAME
	if id == DEFAULT_PAPER:
		return DEFAULT_PAPER_NAME
	return get_item(id).get("name", "")


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
		"ember":  # whatever the skin: hot orange goo, cooling red, with sparks
			look.light = Color(EMBER, EMBER_ALPHA / 255.0)
			look.deep = Color(EMBER_DEEP, EMBER_ALPHA / 255.0)
			look.stars = true
			look.glow = EMBER_GLOW
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

## The colors map paper `paper` puts over a map's palette (MapView.palette): {} for the default.
## `ink`: the skin color (NIGHT draws in it). The route stays red on every paper.
static func paper_colors(paper: String, ink := Color.WHITE) -> Dictionary:
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
