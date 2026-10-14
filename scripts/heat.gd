class_name Heat
extends RefCounted

## Hard-mode HEAT (upgrades v2 batch 4, docs/design/upgrades-v2.md C3): six optional modifiers for
## hard STORY levels, toggled on the level select's HEAT panel and saved as a bitmask
## (Progress.heat_mods, [settings] heat_mods). They apply to a hard level only once it has been
## cleared plainly on hard (Progress.heat_for_run). The run's heat is the sum of the modifiers' heat
## (0-10); clearing a level at a new best heat pays the bounty of every tier newly crossed
## (Economy.HEAT_TIERS / HEAT_BOUNTY: 2/4/7/10 -> 3/5/7/10 tickets, once per level and tier) and
## the level select shows the best tier as a flame. All numbers: Economy.HEAT_MODS & co.
## Every combination is winnable by a perfect walk (tests/test_heat.gd): only THIRSTY changes the
## meter (x1.08: L1's perfect run 87.5% -> 94.5%) and only RACE the time (1.3 x par; a perfect walk
## is ~73% of par).
## Icons are drawn here from little pixel grids (no sprite sheets): `icon(id)` (9x9) and
## `flame(tier)` (7x9, the badge / HUD / result flame).

## Modifier ids in bit order (bit i = 1 << i in the saved mask).
const IDS: Array[String] = ["dim", "brittle", "fog", "grounded", "thirsty", "race"]
const NAMES := {dim = "DIM", brittle = "BRITTLE", fog = "FOG BITES", grounded = "GROUNDED", thirsty = "THIRSTY", race = "RACE"}
## One line each for the HEAT panel (under the toggles, for the focused one).
const ABOUT := {
	dim = "LESS LIGHT, PATHS FADE FASTER",
	brittle = "SPLATS COST DOUBLE, NO FREE SLIDE",
	fog = "FOG RETURNS TWICE AS FAST",
	grounded = "NO LEAPS",
	thirsty = "SLIME DRAINS 8% FASTER",
	race = "BEAT 1.3 X PAR OR DRY UP",
}
const ALL := (1 << 6) - 1


static func bit(id: String) -> int:
	var i := IDS.find(id)
	return 0 if i < 0 else 1 << i


static func has(mask: int, id: String) -> bool:
	return mask & bit(id) != 0


static func heat_of(id: String) -> int:
	return int(Economy.HEAT_MODS[id].heat)


## The heat of a set of modifiers (the sum of their heat).
static func points(mask: int) -> int:
	var total := 0
	for id in IDS:
		if has(mask, id):
			total += heat_of(id)
	return total


## A mask as it may be used: only known bits, and never BRITTLE with GROUNDED (GROUNDED wins: a
## run with no leaps has no splats, so BRITTLE would be free heat).
static func sanitize(mask: int) -> int:
	mask &= ALL
	if has(mask, "grounded"):
		mask &= ~bit("brittle")
	return mask


static func valid(mask: int) -> bool:
	return mask >= 0 and mask <= ALL and sanitize(mask) == mask


## True when modifier `id` can't be switched on with `mask` (BRITTLE while GROUNDED is on).
static func blocked(mask: int, id: String) -> bool:
	return id == "brittle" and has(mask, "grounded")


## `mask` with `id` switched over. Switching GROUNDED on drops BRITTLE; BRITTLE can't go on while
## GROUNDED is on (the mask comes back unchanged).
static func toggle(mask: int, id: String) -> int:
	if bit(id) == 0 or (not has(mask, id) and blocked(mask, id)):
		return sanitize(mask)
	return sanitize(mask ^ bit(id))


## Every mask a player can pick (48 of the 64: no BRITTLE + GROUNDED), in order.
static func masks() -> Array[int]:
	var out: Array[int] = []
	for mask in ALL + 1:
		if valid(mask):
			out.append(mask)
	return out


static func ids_in(mask: int) -> Array[String]:
	var out: Array[String] = []
	for id in IDS:
		if has(mask, id):
			out.append(id)
	return out


## The highest bounty tier (2, 4, 7 or 10) at or under `heat`; 0 below the first.
static func tier_of(heat: int) -> int:
	var tier := 0
	for t in Economy.HEAT_TIERS:
		if heat >= t:
			tier = t
	return tier


## Tickets a clear at `after` heat pays on a level whose best heat was `before`: every tier in
## (before, after] (0 when it raises nothing).
static func bounty(before: int, after: int) -> int:
	var total := 0
	for i in Economy.HEAT_TIERS.size():
		var t: int = Economy.HEAT_TIERS[i]
		if before < t and after >= t:
			total += Economy.HEAT_BOUNTY[i]
	return total


## All bounties of one level (25) and of the whole story (250).
static func level_bounty() -> int:
	return bounty(0, Economy.HEAT_MAX)


static func total_bounty() -> int:
	return level_bounty() * Levels.COUNT


## What `mask` does to a run (game.gd `_apply_heat`):
##   relight  px the slime keeps revealed cells lit within (-1 = the game's own LIGHT_RADIUS)
##   fade     FADE_AFTER factor; lantern: the lantern glow's size factor
##   refog    factor on the last fade step before hard mode's fog returns
##   splat    splat penalty factor; slide: true = the knockback slide drains too
##   grounded no leaps; drain: meter drain factor; race: countdown = this x par (0 = no countdown)
static func effects(mask: int) -> Dictionary:
	mask = sanitize(mask)
	var m: Dictionary = Economy.HEAT_MODS
	var dim := has(mask, "dim")
	return {
		relight = float(m.dim.relight) if dim else -1.0,
		fade = float(m.dim.fade) if dim else 1.0,
		lantern = float(m.dim.lantern) if dim else 1.0,
		refog = float(m.fog.refog) if has(mask, "fog") else 1.0,
		splat = float(m.brittle.splat) if has(mask, "brittle") else 1.0,
		slide = has(mask, "brittle"),
		grounded = has(mask, "grounded"),
		drain = float(m.thirsty.drain) if has(mask, "thirsty") else 1.0,
		race = float(m.race.limit) if has(mask, "race") else 0.0,
	}


# ---------------------------------------------------------------- icons (drawn in code)

## 9x9 pictures: '.' clear, a/b/c the icon's three colors.
const _ICONS := {
	dim = [  # a crescent moon
		"...aaa...",
		"..aab....",
		".aab.....",
		".aa......",
		".aa......",
		".aab.....",
		"..aab....",
		"...aaa...",
		".........",
	],
	brittle = [  # a cracked stone block
		"aaaaaaaaa",
		"abbbcbbba",
		"abbbccbba",
		"abbbbcbba",
		"abbbccbba",
		"abbccbbba",
		"abbbcbbba",
		"aaaacaaaa",
		".........",
	],
	fog = [  # a fog cloud with teeth
		".........",
		"...aaa...",
		".aaaaaaa.",
		"aaaaaaaaa",
		"aaaaaaaaa",
		"bcbcbcbcb",
		".b.b.b.b.",
		".........",
		".........",
	],
	grounded = [  # a leap arrow, struck out
		"....a...c",
		"...aaa.c.",
		"..a.a.c..",
		"....ac...",
		"....c....",
		"...ca....",
		"..c.a....",
		"bbbbbbbbb",
		".........",
	],
	thirsty = [  # a goo drop, half empty
		"....a....",
		"...a.a...",
		"..a...a..",
		"..a...a..",
		".a.....a.",
		".abbbbba.",
		".abcbbba.",
		"..abbba..",
		"...aaa...",
	],
	race = [  # an hourglass (8x8, so the HUD's timer pod keeps an even width)
		"aaaaaaaa",
		".b....b.",
		"..bccb..",
		"...bb...",
		"...bb...",
		"..bccb..",
		".bcccccb",
		"aaaaaaaa",
	],
}
const _ICON_COLORS := {
	dim = [Color8(206, 216, 255), Color8(120, 130, 190), Color8(0, 0, 0)],
	brittle = [Color8(150, 140, 160), Color8(96, 88, 110), Color8(255, 236, 200)],
	fog = [Color8(170, 176, 196), Color8(250, 250, 255), Color8(120, 30, 40)],
	grounded = [Color8(200, 220, 255), Color8(140, 120, 100), Color8(240, 70, 70)],
	thirsty = [Color8(150, 220, 255), Color8(80, 170, 230), Color8(220, 245, 255)],
	race = [Color8(214, 168, 90), Color8(232, 220, 180), Color8(255, 205, 117)],
}
## The badge flame (7x9): the outline a, body b, core c; its colors heat up per tier.
const _FLAME := [
	"...a...",
	"..aa...",
	"..aba..",
	".abba..",
	".abcba.",
	"abccba.",
	"abcccba",
	"abcccba",
	".abbba.",
]
const FLAME_COLORS := {
	0: [Color8(70, 74, 96), Color8(52, 54, 72), Color8(86, 108, 134)],
	2: [Color8(130, 36, 30), Color8(196, 70, 40), Color8(236, 130, 60)],
	4: [Color8(196, 60, 34), Color8(240, 130, 50), Color8(255, 210, 90)],
	7: [Color8(236, 110, 40), Color8(255, 196, 70), Color8(255, 244, 190)],
	10: [Color8(255, 170, 60), Color8(255, 246, 220), Color8(130, 196, 255)],
}

static var _cache := {}


## The 9x9 icon of modifier `id`.
static func icon(id: String) -> Texture2D:
	var key := "i_" + id
	if not _cache.has(key):
		_cache[key] = _texture(_ICONS[id], _ICON_COLORS[id])
	return _cache[key]


## The 7x9 flame for a heat of `heat`: its bounty tier's colors (2, 4, 7, 10 hotter and hotter; a
## heat of 1 burns like 2), 0 = an unlit grey flame.
static func flame(heat: int) -> Texture2D:
	var tier := tier_of(maxi(heat, Economy.HEAT_TIERS[0])) if heat > 0 else 0
	var key := "f_%d" % tier
	if not _cache.has(key):
		_cache[key] = _texture(_FLAME, FLAME_COLORS[tier])
	return _cache[key]


## The flame's visible pixels (all 7x9 of its cell) for layout checks.
static func flame_size() -> Vector2i:
	return Vector2i(_FLAME[0].length(), _FLAME.size())


static func _texture(rows: Array, colors: Array) -> Texture2D:
	var image := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var i := "abc".find(row[x])
			if i >= 0:
				image.set_pixel(x, y, colors[i])
	return ImageTexture.create_from_image(image)


## A TextureRect of `texture` that ignores the mouse (for menus and the HUD).
static func make_rect(texture: Texture2D, tint := Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.size = Vector2(texture.get_size())
	return rect
