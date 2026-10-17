class_name Loc

## The one lookup for player-visible text (docs/i18n/plan.md section 2). Static, so the data classes
## (Skins, Hats, Themes...) and the tests can call it without the scene tree.
## - `ctx` is the stable key (msgctxt, e.g. "hub.portal.random_maze"), `msgid` the English source text
##   with NAMED placeholders ({count}, {level}); both must be string literals at the call site, the
##   extractor (tools/i18n_extract.py) reads them from the code.
## - Never build a sentence out of fragments: whole sentences with placeholders, plurals via `n`.
## - Gate off (Economy.languages_on() false): the English msgid, formatted, i.e. exactly today's text.
##   Gate on: TranslationServer (the catalogs the `Language` autoload loaded), falling back to English.
## - Pseudo-localization (`--lang=pseudo`, tests; docs/i18n/plan.md section 8): `pseudo` is set only by
##   Language._apply_pseudo. Every looked-up text then becomes its English source with accented letters,
##   about 40 % longer (padding included) and bracketed per line, `[_ÉXÁMPŁÉ_]`, placeholders kept as
##   written, so text that bypasses Loc (no brackets), boxes that overflow at +40 % and clipped lines
##   show at a glance. Not Godot's built-in pseudolocalization: that one accents `{count}` too (it only
##   skips %-formats) and uses letters (Ĥ, ή, combining marks) the slimy font doesn't have.

## True while the pseudo locale is on (Language sets it; never with the gate off).
static var pseudo := false
## True in a right-to-left locale (Arabic; Language._apply_direction sets it, never with the gate off).
## `fill` then wraps every placeholder "word" that comes out without right-to-left letters (a number with
## its sign / unit / slash: +5, 30%, X1.5, 1/3, (+0); a Latin key or pad name) in a left-to-right isolate,
## U+2066 LRI .. U+2069 PDI (Unicode bidi algorithm, UAX #9): inside it reads left to right as one unit
## (the + stays before the number, % after it), and to the Arabic line around it it is one neutral word,
## so space-separated values follow the line's right-to-left order (the pad letters {a} {b} {c} line up
## with the mirrored ability row; "{now} -> {next}" shows the arrow pointing from now to next). The
## translation itself is never changed, and Arabic values (names) are inserted as they are.
static var isolate_ltr := false
const LRI := "\u2066"
const PDI := "\u2069"
## True in Chinese / Japanese / Korean (Language._apply_script_gap sets it, never with the gate off):
## `t` / `n` then put SCRIPT_GAP between a slimy-font character (a digit, a Latin key letter, %) and a
## following CJK letter. The slimy glyphs keep their 1 px letter gap on the left only, and the CJK
## glyphs start at their own left edge, so `12階`, `第1关`, `按F转动`, `1층` read as one blob (0 px
## between them); the gap gives them the 1 px the slimy letters keep between themselves (fix pass F1).
## The translations are never changed: the gap is added to the finished text.
static var cjk_gap := false
## U+2007 FIGURE SPACE: no line break at it (a counter stays with its number), and the slimy fonts get a
## 1 px (2 px at 16) glyph for it while a CJK locale is on (Language._apply_script_gap).
const SCRIPT_GAP := "\u2007"
## Characters that end a placeholder's word on either side (besides spaces and Arabic letters).
const WORD_BREAKS := "،؛؟!"

## Pseudo-localization: how much longer each line gets (brackets + padding), and the letters swapped
## for accented ones the slimy font has (uppercase and lowercase map to the same glyph).
const PSEUDO_EXPANSION := 0.4
const PSEUDO_PAD := "_"
const PSEUDO_ACCENTS := {
	"A": "Á", "C": "Ç", "D": "Đ", "E": "É", "G": "Ğ", "I": "Í", "L": "Ł", "N": "Ñ", "O": "Ö", "S": "Ś", "U": "Ü",
	"Y": "Ý", "Z": "Ż", "a": "á", "c": "ç", "d": "đ", "e": "é", "g": "ğ", "i": "í", "l": "ł", "n": "ñ", "o": "ö",
	"s": "ś", "u": "ü", "y": "ý", "z": "ż",
}


## The translation of `msgid` in context `ctx`, with `{name}` placeholders filled from `args`.
static func t(ctx: String, msgid: String, args := {}) -> String:
	var text := String(TranslationServer.translate(msgid, ctx)) if Economy.languages_on() else msgid
	if pseudo:
		text = pseudolocalize(text)
	if isolate_ltr:
		text = isolate_signed(text)
	text = fill(text, args) if not args.is_empty() else text
	return space_scripts(text) if cjk_gap else text


## A counted string: the plural form for `count` in the current language ({count} is filled in
## automatically, plus any other `args`). English: `singular` for 1, `plural` otherwise.
static func n(ctx: String, singular: String, plural: String, count: int, args := {}) -> String:
	var text := ""
	if Economy.languages_on():
		text = String(TranslationServer.translate_plural(singular, plural, count, ctx))
	else:
		text = singular if count == 1 else plural
	if pseudo:
		text = pseudolocalize(text)
	if isolate_ltr:
		text = isolate_signed(text)
	var all := args.duplicate()
	if not all.has("count"):
		all["count"] = count
	text = fill(text, all)
	return space_scripts(text) if cjk_gap else text


## Fills `{name}` placeholders from `args` in ONE pass over `text`: a value is inserted as is, never
## searched again (String.format replaces key after key, so a value containing "{count}" would be
## filled in by a later key). Unknown placeholders and lone braces stay as written.
static func fill(text: String, args: Dictionary) -> String:
	if args.is_empty() or not text.contains("{"):
		return text
	var values := {}  # by String key (callers pass {level = 3} style keys or Strings)
	for key: Variant in args:
		values[str(key)] = args[key]
	if isolate_ltr:
		return _fill_isolated(text, values)
	return _fill_values(text, values)


## fill's one pass, with the values already keyed by String.
static func _fill_values(text: String, values: Dictionary) -> String:
	var out := PackedStringArray()
	var at := 0
	while true:
		var open := text.find("{", at)
		if open < 0:
			break
		var close := text.find("}", open + 1)
		if close < 0:
			break
		var key := text.substr(open + 1, close - open - 1)
		if values.has(key):
			out.append(text.substr(at, open - at))
			out.append(str(values[key]))
			at = close + 1
		else:
			out.append(text.substr(at, open + 1 - at))
			at = open + 1
	out.append(text.substr(at))
	return "".join(out)


## fill in a right-to-left locale (isolate_ltr): the text cut into the "words" around its known
## placeholders (no spaces, no Arabic letters, none of WORD_BREAKS) and the rest; each word filled and,
## when the result has no Arabic letter but a digit or a Latin / Cyrillic letter, isolated (LRI .. PDI).
static func _fill_isolated(text: String, values: Dictionary) -> String:
	var spans: Array[Vector2i] = []  # [from, to) of each word that holds a known placeholder
	var at := 0
	while true:
		var open := text.find("{", at)
		if open < 0:
			break
		var close := text.find("}", open + 1)
		if close < 0:
			break
		if not values.has(text.substr(open + 1, close - open - 1)):
			at = open + 1
			continue
		var from := open
		while from > 0 and _glues(text.unicode_at(from - 1)):
			from -= 1
		var to := close + 1
		while to < text.length() and _glues(text.unicode_at(to)):
			to += 1
		if not spans.is_empty() and from <= spans[-1].y:
			spans[-1].y = maxi(spans[-1].y, to)
		else:
			spans.append(Vector2i(from, to))
		at = close + 1
	var out := PackedStringArray()
	var done := 0
	for span in spans:
		out.append(_fill_values(text.substr(done, span.x - done), values))
		var word := _fill_values(text.substr(span.x, span.y - span.x), values)
		out.append(LRI + word + PDI if _reads_ltr(word) else word)
		done = span.y
	out.append(_fill_values(text.substr(done), values))
	return "".join(out)


## True for a character that belongs to a placeholder's word (not a space, an Arabic letter or a break).
static func _glues(code: int) -> bool:
	return code > 0x20 and not _is_arabic(code) and not char(code) in WORD_BREAKS


static func _is_arabic(code: int) -> bool:
	return (code >= 0x0590 and code <= 0x08FF) or (code >= 0xFB1D and code <= 0xFDFF) or (code >= 0xFE70 and code <= 0xFEFF)


## True when `word` has no right-to-left letter but a digit or a Latin / Cyrillic letter.
static func _reads_ltr(word: String) -> bool:
	var ltr := false
	for i in word.length():
		var code := word.unicode_at(i)
		if _is_arabic(code):
			return false
		if (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) or (code >= 0xC0 and code < 0x0590):
			ltr = true
	return ltr


## `text` with SCRIPT_GAP after every slimy-font character (ASCII letter, digit or % ) ! ?) that is
## followed by a Chinese / Japanese / Korean letter (see cjk_gap). Nothing else changes.
static func space_scripts(text: String) -> String:
	var out := PackedStringArray()
	var from := 0
	for i in range(1, text.length()):
		if _is_cjk(text.unicode_at(i)) and _slimy_end(text.unicode_at(i - 1)):
			out.append(text.substr(from, i - from))
			out.append(SCRIPT_GAP)
			from = i
	if out.is_empty():
		return text
	out.append(text.substr(from))
	return "".join(out)


## A character the slimy font draws that ends a run before a CJK letter: digits, Latin letters, % ) ] ! ?
static func _slimy_end(code: int) -> bool:
	return (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) \
		or code in [0x25, 0x29, 0x5D, 0x21, 0x3F]


## A CJK letter (kana, ideographs, Hangul syllables / jamo); not CJK punctuation, which keeps its own room.
static func _is_cjk(code: int) -> bool:
	return (code >= 0x3040 and code <= 0x30FF) or (code >= 0x31F0 and code <= 0x31FF) or (code >= 0x3400 and code <= 0x4DBF) \
		or (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0xF900 and code <= 0xFAFF) or (code >= 0xAC00 and code <= 0xD7AF) \
		or (code >= 0x1100 and code <= 0x11FF) or (code >= 0x3130 and code <= 0x318F)


## In a right-to-left locale (isolate_ltr): every signed number written in the translation itself (not a
## placeholder: `+1 تذكرة`, `الخزان -10%`, `+30%`) wrapped in LRI .. PDI like fill's placeholders, so the
## bidi algorithm keeps the sign before the number and the % after it (it drew `1+` and `%10-`). A word
## counts when it is a sign, digits (with . , / x X) and an optional %, or digits and a %; placeholders
## and words already isolated are left alone.
static func isolate_signed(text: String) -> String:
	var out := PackedStringArray()
	var at := 0
	var i := 0
	var n := text.length()
	while i < n:
		var code := text.unicode_at(i)
		var starts := (code == 0x2B or code == 0x2D or code == 0x2212) and i + 1 < n and _is_digit(text.unicode_at(i + 1))
		starts = starts or (_is_digit(code) and (i == 0 or not _glues_number(text.unicode_at(i - 1))))
		if not starts or (i > 0 and text.unicode_at(i - 1) == LRI.unicode_at(0)):
			i += 1
			continue
		var j := i + 1
		while j < n and (_is_digit(text.unicode_at(j)) or (text[j] in ".,/xX" and j + 1 < n and _is_digit(text.unicode_at(j + 1)))):
			j += 1
		var percent := j < n and text[j] == "%"
		if percent:
			j += 1
		var signed := code == 0x2B or code == 0x2D or code == 0x2212
		var ends := j >= n or not _glues_number(text.unicode_at(j))
		if (signed or percent) and ends and not (j < n and text[j] == "}"):
			out.append(text.substr(at, i - at))
			out.append(LRI + text.substr(i, j - i) + PDI)
			at = j
		i = j
	if out.is_empty():
		return text
	out.append(text.substr(at))
	return "".join(out)


static func _is_digit(code: int) -> bool:
	return code >= 0x30 and code <= 0x39


## A character that makes a number part of a longer word (a placeholder's braces, Latin letters, digits).
static func _glues_number(code: int) -> bool:
	return _is_digit(code) or code == 0x7B or code == 0x7D or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) \
		or code == 0x2B or code == 0x2D or code == 0x25


## Whole translated lines joined by line breaks (the win text and other multi-line blocks: each line
## is its own Loc.t, a line is replaced by its index, never sliced out of the finished text).
static func lines(parts: Array) -> String:
	var out := PackedStringArray()
	for part: Variant in parts:
		out.append(str(part))
	return "\n".join(out)


## The pseudo-localized form of `text` (see `pseudo`): per line, letters accented, `{placeholders}`
## kept, padded so the line is PSEUDO_EXPANSION longer (brackets count), wrapped in [ ].
static func pseudolocalize(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		out.append(_pseudo_line(line))
	return "\n".join(out)


static func _pseudo_line(line: String) -> String:
	if line == "":
		return line
	var body := PackedStringArray()
	var i := 0
	while i < line.length():
		if line[i] == "{":
			var close := line.find("}", i + 1)
			if close > i:
				body.append(line.substr(i, close - i + 1))
				i = close + 1
				continue
		body.append(PSEUDO_ACCENTS.get(line[i], line[i]))
		i += 1
	var pad := maxi(0, ceili(line.length() * PSEUDO_EXPANSION) - 2)
	var left := PSEUDO_PAD.repeat(pad / 2)
	return "[" + left + "".join(body) + PSEUDO_PAD.repeat(pad - pad / 2) + "]"
