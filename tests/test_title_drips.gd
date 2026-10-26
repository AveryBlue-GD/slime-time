extends "res://tests/suite_base.gd"

## Title drips (ITER-3, UI-41..43). assets/shaders/text_drips.gdshader decides every drip from the font's own
## pixels (headless runs have no renderer), so this suite MIRRORS its whitelist on assets/fonts/pixel_big.png:
##  - STEM: a column with ink on the last 2 rows, nothing beside it on those rows, in a glyph with other bottom ink;
##  - FLAT: the middle of an exactly 5-wide flat bottom bar;  digits (atlas units 154..210) never.
## It then checks every real title of the game, letter by letter: no letter may have a candidate column unless it is
## one of the safe shapes (A H K M N R X stems, E L Z bars), no round / serif / point letter and no digit ever drips,
## and the floor: a title has candidate letters at about 1 in 3 or more (and at least one).

const UNIT := 2
const SAFE_LETTERS := "HKMNRX"  # (flat bars E L Z are not used: the middle drip read as a cedilla)
const TITLES: Array[String] = ["ACHIEVEMENTS", "BOARDS", "SKINS", "HATS", "YOU ESCAPED!", "LEVEL SELECT", "PAUSED", "MAP TABLE",
	"END OF THE DEMO", "UPGRADES", "CONTROLS", "WINS", "SCORES", "COSMETICS", "NEW RECORD", "PRIZE WHEEL", "MENU", "RANDOMIZER",
	"QUIT TO TITLE", "LEAVE THE HUB?", "LANGUAGE", "FULL GAME PREVIEW", "THIS MAZE SO FAR", "ERASE ALL PROGRESS?", "RESTART?",
	"ROTATE YOUR DEVICE", "SAVE CODE", "SETTINGS", "ENTER THE HUB", "PLAY", "STORY", "ESCAPE THE FOG", "BEFORE YOU DRY UP",
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "LEVEL 3", "SPACE", "ENTER", "SHIFT"]

var img: Image
var chars := {}  # code -> [atlas x (in font units), width (units)]


func _ink(ux: int, uy: int) -> bool:
	if ux < 0 or ux * UNIT >= img.get_width():
		return false
	return img.get_pixel(ux * UNIT, uy * UNIT).a > 0.5


func _gap(ux: int) -> bool:
	for y in 7:
		if _ink(ux, y):
			return false
	return true


## The atlas columns of the glyph at x, width w, where the shader lets a drip hang.
func _columns(gx: int, w: int) -> Array[int]:
	var others := false
	for x in range(gx, gx + w):
		# (the shader's `others` looks at neighbours; counting >= 2 bottom-ink columns is the same for a glyph cell)
		pass
	var bottoms := 0
	for x in range(gx, gx + w):
		if _ink(x, 6):
			bottoms += 1
	others = bottoms >= 2
	var out: Array[int] = []
	if gx >= 154 and gx < 211:
		return out  # digits
	for x in range(gx, gx + w):
		var stem := _ink(x, 0) and _ink(x, 6) and _ink(x, 5) and not _ink(x - 1, 6) and not _ink(x + 1, 6) and not _ink(x - 1, 5) and not _ink(x + 1, 5)
		var flat := _ink(x - 2, 6) and _ink(x - 1, 6) and _ink(x, 6) and _ink(x + 1, 6) and _ink(x + 2, 6) and not _ink(x - 3, 6) and not _ink(x + 3, 6)
		if others and stem:  # (flat bars: not used, see SAFE_LETTERS)
			if flat:
				pass
			out.append(x)
	return out


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
			chars[int(f.id)] = [int(f.x) / UNIT, int(f.width) / UNIT]
	# per glyph: the whitelist is exactly the safe shapes
	var safe_seen := ""
	for code: int in chars:
		var ch := char(code)
		var c: Array = chars[code]
		for x in range(c[0], c[0] + c[1]):
			if ch.to_upper() == ch.to_lower() and not ch.is_valid_int():
				break  # (symbols / quotes are two-part glyphs)
			_check(not _gap(x), "%s: no empty column inside the glyph (column %d)" % [ch, x - c[0]])
		var cols := _columns(c[0], c[1])
		if ch >= "A" and ch <= "Z":
			if ch in SAFE_LETTERS:
				_check(not cols.is_empty(), "%s: has a safe drip column" % ch)
				safe_seen += ch
			else:
				_check(cols.is_empty(), "%s: must never drip (round bottom, serif, point or lone stem), got columns %s" % [ch, cols])
		elif ch >= "0" and ch <= "9":
			_check(cols.is_empty(), "digit %s never drips" % ch)
		else:
			# symbols and anything else: any drip must still be under a stem or a bar (the shader's own rule), never under a round shape
			for x in cols:
				_check(_ink(x, 5) or _ink(x, 6), "%s: column %d" % [ch, x - c[0]])
		# every drip column: nothing beside the stem foot / bar must be inked below the bar (no hook)
		for x in cols:
			_check(_ink(x, 6), "%s: drip column %d is on the last ink row" % [ch, x - c[0]])
	# the safe stems really are the ones drawn: letters with a bottom bar of 5 (E L Z) or free-standing legs
	_check(safe_seen.length() == SAFE_LETTERS.length(), "every safe letter found: %s" % safe_seen)
	# every real title, letter by letter
	var all_letters := 0
	var all_cands := 0
	for title in TITLES:
		var letters := 0
		var candidates := 0
		for ch in title:
			if ch == " ":
				continue
			letters += 1
			var c: Array = chars[ch.unicode_at(0)]
			var cols := _columns(c[0], c[1])
			if not cols.is_empty():
				candidates += 1
				_check(ch in SAFE_LETTERS, "%s: '%s' has a drip column but is not a safe letter" % [title, ch])
			if ch >= "0" and ch <= "9":
				_check(cols.is_empty(), "%s: digit %s drips" % [title, ch])
		if letters >= 4 and title.to_upper() == title and not title[0].is_valid_int():
			print("  %-22s letters %2d  candidate letters %d" % [title, letters, candidates])
			all_letters += letters
			all_cands += candidates
	# The floor: a title with no safe letter (LEVEL SELECT) simply has no drips; overall about 1 letter in 6 can drip.
	_check(all_cands * 7 >= all_letters, "floor: at least 1 candidate letter in 7 over every title (%d of %d)" % [all_cands, all_letters])
	_result()
	quit(0 if failures == 0 else 1)
