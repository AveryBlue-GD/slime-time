extends "res://tests/suite_base.gd"

## UI-21 / CON-24: the title drip floor. assets/shaders/text_drips.gdshader decides every drip from the font's
## own pixels (headless runs have no renderer to look at), so this suite MIRRORS its rules on assets/fonts/pixel_big.png:
##  - a column drips only at a stroke end (ink above the bottom row) or the left end of a round bottom run;
##  - every glyph has ONE primary column (its leftmost; a lone T / I / Y stem too, but only when the floor forces it);
##  - every other glyph of a line is forced to drip there (by its left edge on screen, 24 px period, 75 % of it), so a title
##    gets at least 1 drip per 2 letters (counted over every start offset of the real titles' advances);
##  - round letters (C G O Q S U 0 2 3 5 6 8 9) never drip under the middle of a curved bottom.

const UNIT := 2
const TITLES: Array[String] = ["ACHIEVEMENTS", "BOARDS", "SKINS", "HATS", "YOU ESCAPED!", "LEVEL SELECT", "PAUSED", "MAP TABLE",
	"END OF THE DEMO", "UPGRADES", "CONTROLS", "WINS", "SCORES", "COSMETICS", "NEW RECORD", "PRIZE WHEEL"]

var img: Image
var chars := {}  # code -> [atlas x (in font units), width (units), advance (units)]


func _ink(ux: int, uy: int) -> bool:
	if ux < 0 or ux * UNIT >= img.get_width():
		return false
	return img.get_pixel(ux * UNIT, uy * UNIT).a > 0.5


func _eligible(ux: int) -> bool:
	var b := _ink(ux, 6)
	return b and (_ink(ux, 5) or (not _ink(ux - 1, 6) and (_ink(ux + 1, 6) or (_ink(ux - 1, 5) and _ink(ux + 1, 5)))))


func _gap(ux: int) -> bool:
	for y in 7:
		if _ink(ux, y):
			return false
	return true


## [primary column or -1, drip columns] of the glyph at atlas unit x gx, width w (what the shader works out per column).
func _glyph(gx: int, w: int) -> Array:
	var cols: Array[int] = []
	var bottoms := 0
	for x in range(gx, gx + w):
		if _ink(x, 6):
			bottoms += 1
		if _eligible(x):
			cols.append(x)
	if cols.is_empty():
		return [-1, []]
	return [cols[0], cols]


func _init() -> void:
	super()
	img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/fonts/pixel_big.png"))
	for line in FileAccess.get_file_as_string("res://assets/fonts/pixel_big.fnt").split("\n"):
		if not line.begins_with("char id="):
			continue
		var f := {}
		for part in line.split(" "):
			if "=" in part:
				f[part.get_slice("=", 0)] = part.get_slice("=", 1)
		if int(f.get("page", 0)) == 0:
			chars[int(f.id)] = [int(f.x) / UNIT, int(f.width) / UNIT, int(f.xadvance) / UNIT]
	# the glyph cells in the font file are the shader's glyph extents (an empty column ends a glyph)
	var curved := "CGOQSU035689"
	var primaries := 0
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
		var c: Array = chars[ch.unicode_at(0)]
		var g := _glyph(c[0], c[1])
		# the cell must end at an empty column, as the shader assumes (no empty column inside a glyph)
		for x in range(c[0], c[0] + c[1]):
			_check(not _gap(x), "%s: no empty column inside the glyph (column %d)" % [ch, x - c[0]])
		if g[0] >= 0:
			primaries += 1
			_check(_eligible(g[0]), "%s: the primary column is a drip column" % ch)
		if ch in curved:
			var run_left := -1
			for x in range(c[0], c[0] + c[1]):
				if _ink(x, 6):
					run_left = x
					break
			for x: int in g[1]:
				var ok: bool = x == run_left or (_ink(x, 5) and (x == c[0] or x == c[0] + c[1] - 1))
				_check(ok, "%s: column %d is a stroke end or the left end of the bottom, not under a curve" % [ch, x - c[0]])
		else:
			for x: int in g[1]:
				_check(_ink(x, 5) or not _ink(x - 1, 6), "%s: column %d has a stroke above it or starts a bottom run" % [ch, x - c[0]])
	var none := ""
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
		var cc: Array = chars[ch.unicode_at(0)]
		if _glyph(cc[0], cc[1])[0] < 0:
			none += ch
	print("  no primary column: ", none)
	_check(primaries >= 26, "most letters and digits have a primary drip column (%d)" % primaries)
	# The floor: lay each title out with the real advances, try every start offset (the title is centred, so
	# its left edge varies by screen), count the letters whose glyph the shader forces to drip.
	var worst := 99.0
	for title in TITLES:
		var letters := 0
		for ch in title:
			if ch != " " and ch != "!":
				letters += 1
		var low := 999
		for start in range(0, 24, 2):
			var x := start
			var drips := 0
			for ch in title:
				var code := ch.unicode_at(0)
				if ch == " ":
					x += 2 * 2
					continue
				var c: Array = chars[code]
				var g := _glyph(c[0], c[1])
				var screen_x := x + 1  # (xoffset 1 px)
				if g[0] >= 0 and fmod(float(screen_x), 24.0) < 18.0:
					drips += 1
				x += c[2] * UNIT
			low = mini(low, drips)
		var need := int(floor(letters / 2.0))
		print("  %-16s letters %2d  forced drips >= %d (need %d)" % [title, letters, low, need])
		_check(low >= need, "%s: at least 1 drip per 2 letters (%d of %d letters, worst offset)" % [title, low, letters])
	_result()
	quit(0 if failures == 0 else 1)
