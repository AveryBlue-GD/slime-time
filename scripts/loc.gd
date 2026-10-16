class_name Loc

## The one lookup for player-visible text (docs/i18n/plan.md section 2). Static, so the data classes
## (Skins, Hats, Themes...) and the tests can call it without the scene tree.
## - `ctx` is the stable key (msgctxt, e.g. "hub.portal.random_maze"), `msgid` the English source text
##   with NAMED placeholders ({count}, {level}); both must be string literals at the call site, the
##   extractor (tools/i18n_extract.py) reads them from the code.
## - Never build a sentence out of fragments: whole sentences with placeholders, plurals via `n`.
## - Gate off (Economy.languages_on() false): the English msgid, formatted, i.e. exactly today's text.
##   Gate on: TranslationServer (the catalogs the `Language` autoload loaded), falling back to English.


## The translation of `msgid` in context `ctx`, with `{name}` placeholders filled from `args`.
static func t(ctx: String, msgid: String, args := {}) -> String:
	var text := String(TranslationServer.translate(msgid, ctx)) if Economy.languages_on() else msgid
	return fill(text, args) if not args.is_empty() else text


## A counted string: the plural form for `count` in the current language ({count} is filled in
## automatically, plus any other `args`). English: `singular` for 1, `plural` otherwise.
static func n(ctx: String, singular: String, plural: String, count: int, args := {}) -> String:
	var text := ""
	if Economy.languages_on():
		text = String(TranslationServer.translate_plural(singular, plural, count, ctx))
	else:
		text = singular if count == 1 else plural
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
