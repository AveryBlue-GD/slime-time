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
	return fill(text, args) if not args.is_empty() else text


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
	var all := args.duplicate()
	if not all.has("count"):
		all["count"] = count
	return fill(text, all)


## Fills `{name}` placeholders from `args` in ONE pass over `text`: a value is inserted as is, never
## searched again (String.format replaces key after key, so a value containing "{count}" would be
## filled in by a later key). Unknown placeholders and lone braces stay as written.
static func fill(text: String, args: Dictionary) -> String:
	if args.is_empty() or not text.contains("{"):
		return text
	var values := {}  # by String key (callers pass {level = 3} style keys or Strings)
	for key: Variant in args:
		values[str(key)] = args[key]
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
