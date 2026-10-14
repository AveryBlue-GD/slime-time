class_name BoonIcons
extends RefCounted

## The DESCENT boons' icons (Descent.IDS), 8x8 like the other UI icons, drawn here from rows of
## palette letters (the art palette `PAL` of tools/make_placeholder_art.py: k outline, e white,
## H/l/m/n goo greens, Y/y/o gold, B/d blue, x/w/W stone, M/i ruby pink). Built once per boon and
## cached; shown 1x in the HUD's boon strip and 2x on the boon card.

const PAL := {
	"k": Color8(26, 28, 44), "e": Color8(244, 244, 244), "H": Color8(214, 250, 186), "l": Color8(148, 226, 112),
	"m": Color8(56, 183, 100), "n": Color8(37, 113, 121), "Y": Color8(255, 240, 180), "y": Color8(255, 205, 117),
	"o": Color8(209, 136, 58), "B": Color8(94, 130, 190), "d": Color8(41, 54, 111), "x": Color8(194, 210, 222),
	"w": Color8(148, 176, 194), "W": Color8(86, 108, 134), "M": Color8(255, 138, 150), "i": Color8(168, 24, 44),
	"F": Color8(40, 34, 52),
}

const ART := {
	"gulp": ["...kk...", "..kHlk..", ".kHlemk.", "klleeemk", "kmlmemmk", ".kmmmnk.", "..knnk..", "...kk..."],
	"tank": [".kkkkkk.", ".kxwwWk.", "..kkkk..", ".kFFFFk.", ".kHlllk.", ".klllmk.", ".kmmmnk.", "..kkkk.."],
	"feather": [".....kkk", "....kxek", "...kxek.", "..kxek..", ".kxwk...", ".kwk....", "kWk.....", "k......."],
	"rubber": ["..kkkk..", ".kMeMMk.", "kMeMMMik", "kMMMMMik", "kMMMMiik", ".kiiiik.", "..kkkk..", ".W.WW.W."],
	"slick": ["........", "....kkk.", "ee.kHlmk", "..klllmk", "eee.kmnk", "..kmmnk.", "....kk..", "........"],
	"blaze": ["...y....", ".y.y.y..", "..yYy...", "yyYeYyy.", "..yYy...", ".y.y.y..", "...y....", "........"],
	"sense": ["kyyyyyyk", "kYyyyyok", ".kyyyok.", "..kyok..", "...yo...", "..kyok..", ".kyyyok.", ".kkkkkk."],
	"bladder": ["..kkkk..", ".kBeBdk.", "kBeBBBdk", "kBBBBBdk", "kBBBBddk", ".kdddk..", "..kdk...", "...k...."],
	"thrift": ["...kk...", "..klmk..", ".kllmmk.", "kllllmmk", "kkkllkkk", "..kllk..", "..kmnk..", "..kkkk.."],
	"greedy": ["........", "kkkkkkkk", "kYyyyyok", ".kyeyok.", ".kyyyok.", "kyyyyyok", "kkkkkkkk", "........"],
	"glass": ["...kk...", "..kexk..", ".kexwBk.", "kexkwBBk", "kxwwkBdk", ".kwBkdk.", "..kBdk..", "...kk..."],
}

static var _cache := {}


## The icon of boon `id` (an empty 8x8 for an unknown id).
static func texture(id: String) -> ImageTexture:
	if not _cache.has(id):
		var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var rows: Array = ART.get(id, [])
		for y in rows.size():
			var row: String = rows[y]
			for x in mini(row.length(), 8):
				var c: String = row[x]
				if PAL.has(c):
					image.set_pixel(x, y, PAL[c])
		_cache[id] = ImageTexture.create_from_image(image)
	return _cache[id]


## A TextureRect showing the icon at `scale` x (whole pixels).
static func make(id: String, scale := 1) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = Vector2(8, 8) * scale
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon
