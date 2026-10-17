extends "res://tests/suite_base.gd"

## Loc.isolate_signed (Arabic only, docs/i18n/plan.md section 11): a signed / percent number written in a
## translation is wrapped in LRI .. PDI so the bidi algorithm keeps `+5` and `-10%` in order; a sign right
## after a digit, a Latin letter, a brace, a sign or a % is a dash inside a word (`10-20%`, `A-1`) and starts
## no run (it used to give `10` LRI `-20%` PDI). Also: no isolate in any Arabic catalog string opens right after
## such a character. Pure string checks; no save is read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_i18n_signs.gd

const LRI := "\u2066"
const PDI := "\u2069"


func _initialize() -> void:
	var cases := [
		["+5", LRI + "+5" + PDI],
		["-10%", LRI + "-10%" + PDI],
		["الخزان -10%", "الخزان " + LRI + "-10%" + PDI],
		["+1 تذكرة", LRI + "+1" + PDI + " تذكرة"],
		["10-20%", "10-20%"],
		["المدى 10-20% فقط", "المدى 10-20% فقط"],
		["5-10", "5-10"],
		["A-1", "A-1"],
		["المستوى A-1", "المستوى A-1"],
		["B+2", "B+2"],
		["1/3", "1/3"],
		["X1.5", "X1.5"],
		["x2", "x2"],
		["(+0)", "(" + LRI + "+0" + PDI + ")"],
		["{n}-5", "{n}-5"],
		["+{n}", "+{n}"],
		["50%-", "50%-"],
		["10%", LRI + "10%" + PDI],
		[LRI + "+5" + PDI, LRI + "+5" + PDI],
	]
	for c: Array in cases:
		var got := Loc.isolate_signed(c[0])
		_check(got == c[1], "isolate_signed %s -> %s (want %s)" % [c[0].c_escape(), got.c_escape(), c[1].c_escape()])
	_catalog()
	_result()
	quit(1 if failures else 0)


## Every Arabic translation run through isolate_signed: no LRI right after a character that glues a number
## (the split-run bug), and LRI / PDI balanced.
func _catalog() -> void:
	var texts := _po_strings("res://locale/ar.po")
	var bad := PackedStringArray()
	for text in texts:
		var iso := Loc.isolate_signed(text)
		if iso.count(LRI) != iso.count(PDI):
			bad.append("unbalanced: " + text.c_escape())
		var at := iso.find(LRI)
		while at > 0:
			if Loc._glues_number(iso.unicode_at(at - 1)):
				bad.append("split run: " + iso.c_escape())
				break
			at = iso.find(LRI, at + 1)
	_check(texts.size() > 100 and bad.is_empty(), "ar catalog (%d strings): no split signed run, isolates balanced %s" % [texts.size(), bad])


## Every non-empty msgstr / msgstr[n] of a .po file (continuation lines joined, escapes resolved).
static func _po_strings(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var inside := false
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("msgstr"):
			if inside and cur != "":
				out.append(cur.c_unescape())
			inside = true
			cur = line.substr(line.find("\"") + 1).trim_suffix("\"")
		elif inside and line.begins_with("\""):
			cur += line.substr(1).trim_suffix("\"")
		else:
			if inside and cur != "":
				out.append(cur.c_unescape())
			inside = false
			cur = ""
	if inside and cur != "":
		out.append(cur.c_unescape())
	return out
