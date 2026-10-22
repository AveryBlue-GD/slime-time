class_name Cosmetics
extends RefCounted

## Ticket cosmetics v1 (upgrades v2 batch 2, docs/design/upgrades-v2.md C.2): five goo TRAIL styles
## and map PAPERS (each a bundle: its sheet, its walls and its route, worn together; Progress.map_paper), sold in the hat wheel's SHOP tab (prices: Economy.COSMETICS), owned for
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
	# route in the dye. Then the flowing bundle, PRISM (`flow`: MapView.mark_flow, map_flow.gdshader;
	# a RAINBOW gradient paper was tried and dropped, owner 2026-10-21: "gradient" stays supported).
	{id = "cherry_paper", kind = PAPER, name = "CHERRY PAPER", about = "A CHERRY SET", dye = Color8(206, 52, 62)},  # i18n: ignore (English source; shown via display_name)
	{id = "tangerine_paper", kind = PAPER, name = "TANGERINE PAPER", about = "A TANGERINE SET", dye = Color8(232, 128, 48)},  # i18n: ignore (English source; shown via display_name)
	{id = "butter_paper", kind = PAPER, name = "BUTTER PAPER", about = "A BUTTER SET", dye = Color8(240, 204, 76)},  # i18n: ignore (English source; shown via display_name)
	{id = "clover_paper", kind = PAPER, name = "CLOVER PAPER", about = "A CLOVER SET", dye = Color8(72, 168, 84)},  # i18n: ignore (English source; shown via display_name)
	{id = "cobalt_paper", kind = PAPER, name = "COBALT PAPER", about = "A COBALT SET", dye = Color8(62, 110, 214)},  # i18n: ignore (English source; shown via display_name)
	{id = "plum_paper", kind = PAPER, name = "PLUM PAPER", about = "A PLUM SET", dye = Color8(124, 78, 196)},  # i18n: ignore (English source; shown via display_name)
	{id = "bubblegum_paper", kind = PAPER, name = "BUBBLEGUM PAPER", about = "A BUBBLEGUM SET", dye = Color8(236, 120, 176)},  # i18n: ignore (English source; shown via display_name)
	{id = "prism_paper", kind = PAPER, name = "PRISM PAPER", about = "TURNS THROUGH THE COLORS", flow = "prism"},  # i18n: ignore (English source; shown via display_name)
	# Earned, never sold (not in the SHOP; `earned` says how): DESCENT batch 3.
	{id = "abyss", kind = TRAIL, name = "ABYSS TRAIL", about = "DARK GOO, FAINT STARS", earned = "REACH DESCENT FLOOR 10"},  # i18n: ignore (English source; shown via display_name)
	# PREVIEW (trail-preview branch, ideas/trail-ideas.md): ten proposed trail styles, wearable only
	# with the debug flag --trail=ID; `earned` keeps them out of the SHOP. Painted per cell
	# (trail_cell_at); TOXIC / FROST / GHOST also use a trail.gdshader `fx` effect.
	{id = "dried", kind = TRAIL, name = "DRIED TRAIL", about = "SUN-BAKED CRUST", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "frost", kind = TRAIL, name = "FROST TRAIL", about = "ICY SPARKLES", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "toxic", kind = TRAIL, name = "TOXIC TRAIL", about = "NEON BUBBLES", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "pixel", kind = TRAIL, name = "PIXEL TRAIL", about = "TWO-TONE CHECKERS", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "treasure", kind = TRAIL, name = "TREASURE TRAIL", about = "X MARKS THE ROUTE", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "confetti", kind = TRAIL, name = "CONFETTI TRAIL", about = "PARTY SPRINKLES", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "crystal", kind = TRAIL, name = "CRYSTAL TRAIL", about = "SHINY FACETS", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "moss", kind = TRAIL, name = "MOSS TRAIL", about = "GREEN GOO, TINY FLOWERS", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "ghost", kind = TRAIL, name = "GHOST TRAIL", about = "FAINT AND SHIMMERY", earned = "PREVIEW"},  # i18n: ignore (preview only)
	{id = "pulse", kind = TRAIL, name = "PULSE TRAIL", about = "GLOWING BANDS", earned = "PREVIEW"},  # i18n: ignore (preview only)
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
## PREVIEW trail styles (see LIST): their colors (alpha in the color), and the trail.gdshader `fx`.
const FX_FROST := 1.0
const FX_TOXIC := 2.0
const FX_GHOST := 3.0
const DRIED := Color8(212, 182, 132, 160)
const DRIED_DEEP := Color8(190, 158, 108, 160)
const DRIED_CRACK := Color8(84, 58, 36, 210)
const FROST := Color8(176, 218, 242, 140)
const FROST_DEEP := Color8(132, 184, 226, 140)
const FROST_SPARKLE := Color8(250, 253, 255, 230)
const TOXIC := Color8(184, 244, 44, 165)
const TOXIC_DEEP := Color8(112, 204, 32, 165)
const TOXIC_BUBBLE := Color8(234, 255, 150, 220)
const TREASURE_RED := Color8(200, 36, 40, 230)
const TREASURE_GAP := Color8(242, 228, 190, 55)
const TREASURE_DASH := 8.0  # px traveled per dash (and per gap)
const CONFETTI_PINK := Color8(250, 120, 180, 230)
const CONFETTI_YELLOW := Color8(252, 224, 80, 230)
const CONFETTI_CYAN := Color8(90, 224, 240, 230)
const CONFETTI_WHITE := Color8(252, 252, 252, 230)
const CRYSTAL_CYAN := Color8(112, 222, 242, 165)
const CRYSTAL_PINK := Color8(242, 142, 212, 165)
const CRYSTAL_LILAC := Color8(184, 154, 244, 165)
const CRYSTAL_GLINT := Color8(255, 255, 255, 235)
const MOSS := Color8(60, 126, 54, 170)
const MOSS_DEEP := Color8(38, 92, 40, 170)
const MOSS_PINK := Color8(244, 134, 184, 235)
const MOSS_YELLOW := Color8(250, 222, 92, 235)
const GHOST := Color8(222, 234, 255, 72)
const GHOST_DEEP := Color8(192, 208, 242, 60)
const PULSE_BAND := 24.0  # px traveled per pulse band


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
		"dried", "frost", "toxic", "pixel", "treasure", "confetti", "crystal", "moss", "ghost", "pulse":
			look.style = style
			look.per_cell = true
			look.fx = {"frost": FX_FROST, "toxic": FX_TOXIC, "ghost": FX_GHOST}.get(style, 0.0)
			look.glow = {"dried": 0.06, "frost": 0.35, "toxic": 0.5, "treasure": 0.12, "crystal": 0.65,
				"moss": 0.15, "ghost": 0.25, "pulse": 0.45}.get(style, TRAIL_GLOW)
			look.skin_light = Color(shades.light, GOO_ALPHA / 255.0)
			look.skin_deep = Color(shades.deep, GOO_ALPHA / 255.0)
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


## The color of trail cell `cell` (trail image coords, 2 px each) for a PREVIEW style (`look.per_cell`):
## hash / parity / distance rules, no textures. Other looks fall back to trail_cell.
static func trail_cell_at(look: Dictionary, deep: bool, travel: float, cell: Vector2i, rainbow_hue := 0.0) -> Color:
	if not look.get("per_cell", false):
		return trail_cell(look, deep, travel, rainbow_hue)
	var h := posmod(hash(cell * 7 + Vector2i(3, 11)), 1000)
	match look.style:
		"dried":  # mud cracks: rows every 5 cells, each row split at a jittered column, broken lines
			var row := floori(cell.y / 5.0)
			var jitter := posmod(hash(Vector2i(row, 91)), 7)
			var crack := posmod(cell.y, 5) == 0 or posmod(cell.x + jitter + (posmod(cell.y, 5) >> 1), 7) == 0
			if crack and h % 5 != 0:
				return DRIED_CRACK
			return DRIED_DEEP if deep else DRIED
		"frost":
			if h % 11 == 0:
				return FROST_SPARKLE
			return FROST_DEEP if deep else FROST
		"toxic":
			if h % 13 == 0:
				return TOXIC_BUBBLE
			return TOXIC_DEEP if deep else TOXIC
		"pixel":
			return look.skin_light if posmod(cell.x + cell.y, 2) == 0 else look.skin_deep
		"treasure":  # the gap; the red dashes are laid along the slime's center (game.gd)
			return TREASURE_GAP
		"confetti":
			if h % 6 == 0:
				match (h / 6) % 4:
					0: return CONFETTI_PINK
					1: return CONFETTI_YELLOW
					2: return CONFETTI_CYAN
					_: return CONFETTI_WHITE
			return look.deep if deep else look.light
		"crystal":  # 3x3-cell facets, one tint each, a few white glints
			if h % 19 == 0:
				return CRYSTAL_GLINT
			match posmod(hash(Vector2i(floori(cell.x / 3.0), floori(cell.y / 3.0))), 3):
				0: return CRYSTAL_CYAN.darkened(0.25) if deep else CRYSTAL_CYAN
				1: return CRYSTAL_PINK.darkened(0.25) if deep else CRYSTAL_PINK
				_: return CRYSTAL_LILAC.darkened(0.25) if deep else CRYSTAL_LILAC
		"moss":
			if h % 29 == 0:
				return MOSS_PINK
			if h % 29 == 1:
				return MOSS_YELLOW
			return MOSS_DEEP if deep else MOSS
		"ghost":
			return GHOST_DEEP if deep else GHOST
		"pulse":  # static: a brighter band every PULSE_BAND px traveled (no per-cell age to animate)
			var phase := fposmod(travel / PULSE_BAND, 1.0)
			var base: Color = look.deep if deep else look.light
			if phase < 0.35:
				var lift := sin(phase / 0.35 * PI)
				return Color(base.lerp(Color.WHITE, 0.45 * lift), lerpf(base.a, 0.8, lift))
			return base
	return look.deep if deep else look.light


## The center line a style lays over its painted cells (TREASURE's red dashes), or null.
static func trail_center(look: Dictionary, travel: float) -> Variant:
	if look.get("style", "") == "treasure" and posmod(floori(travel / TREASURE_DASH), 2) == 0:
		return TREASURE_RED
	return null


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
			var c := trail_cell_at(look, deep, x * 2.0 * 3.0, Vector2i(x, y), fposmod(x / float(size.x), 1.0) * 0.83)
			image.set_pixel(x, y, Color(0.08, 0.08, 0.12, 0.9) if locked else c)
	return image


# ---------------------------------------------------------------- map papers

## Which of a paper's palette colors may flow (a PRISM paper: MapView.mark_flow).
const FLOW_KEYS := ["floor", "wall", "start", "goal", "route"]


## The colors paper `paper` puts over a map's palette, plus `flow` = {palette key: "prism" /
## "gradient"} for a flowing paper. `ink`: the skin color (NIGHT draws in it).
static func style_colors(paper: String, ink := Color.WHITE) -> Dictionary:
	var out := paper_colors(paper, ink)
	var mode: String = get_item(paper).get("flow", "")
	if mode != "":
		var flow := {}
		for key: String in FLOW_KEYS:
			if out.has(key):
				flow[key] = mode
		out.flow = flow
	return out


## Whether paper `paper` flows (its map texture needs map_flow.gdshader).
static func style_flows(paper: String) -> bool:
	return get_item(paper).has("flow")


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
