extends "res://tests/suite_base.gd"

## Static width budgets (docs/i18n/plan.md section 9.2, chunk F). For every locale (English, the 17
## translations and the pseudo locale) and every template entry with a `max Npx` budget in its notes,
## measures each line of each form (every plural form) with the real font chain of that locale (the
## slimy pixel.fnt / pixel_big.fnt plus the locale's fallback, as Language installs it; 16 px when the
## notes say "16 px font"), placeholders filled with wide sample values (SAMPLES), against the budget,
## and the line count against a `lines N` budget. Gives translators an exact list without building any
## screen; tests/test_i18n_screens.gd measures the real layouts.
## Every overflow goes into docs/i18n/fit-report.budget.json + fit-report.md (tests/i18n_report.gd).
## An overflow is "accepted" when English itself is over the same budget (the budget note is then the
## thing to fix, not the translation).
## A budget is each call site's `max Npx`, or its `grows to Npx` where the screen widens the box for the
## text (UIKit sizing helpers, up to the room the layout has), `wraps` where it wraps (_budget_of).
## ENFORCED for every locale (chunk G5; Arabic since chunk I).
## Also runs `tools/i18n_extract.py --check` (catalogs merged, placeholders, casing, no untranslated
## entry, no English literal outside Loc in scripts/), so test_all.sh covers it; skipped with a note
## when no Python 3 is on the PATH.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 120000 -s res://tests/test_i18n_fit.gd

const ENFORCE := true
## Locales whose findings are reported but do not fail the suite (none since chunk I).
const REPORT_ONLY: Array[String] = []
const Lang := preload("res://scripts/language.gd")
const Report := preload("res://tests/i18n_report.gd")
const TEMPLATE := "res://locale/messages.pot"
## Wide but realistic placeholder values. Names are a long skin name; {about} / {how} are other
## translated texts (measured in place by the screens suite), so they count as empty here.
const SAMPLES := {
	"count": "88", "n": "88", "level": "10", "total": "10", "floor": "88", "time": "8:88.88", "best": "8:88.88",
	"code": "10", "own": "10", "have": "165", "hand": "165", "cost": "888", "price": "888", "pot": "888",
	"paid": "888", "gain": "888", "left": "88", "max": "99", "next": "888", "now": "888", "percent": "25",
	"points": "99", "rate": "888", "reach": "88", "slot": "8", "a": "888", "b": "888", "c": "888",
	"key": "SPACE", "keys": "WASD", "name": "BUBBLEGUM", "skin": "BUBBLEGUM", "paper": "PARCHMENT",
	"names": "BUBBLEGUM, LIME", "about": "", "how": "",
}

var test_save := throwaway_save()
var language: Node
var _budget := RegEx.create_from_string("max (\\d+) ?px")
var _lines := RegEx.create_from_string("\\blines (\\d+)\\b")
var _grows := RegEx.create_from_string("grows to (\\d+) ?px")


func _initialize() -> void:
	await process_frame
	var progress := root.get_node("Progress")
	progress.save_path = test_save
	progress.saving_enabled = false
	language = root.get_node("Language")
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	_pseudo()
	var template := Report.po_entries(TEMPLATE)
	var budgeted: Array[Dictionary] = []
	for entry in template:
		var budget := _budget_of(entry)
		if not budget.is_empty():
			budgeted.append(entry.merged(budget))
	_check(template.size() > 400 and budgeted.size() > 100, "%d template entries, %d with a width budget" % [template.size(), budgeted.size()])
	var issues: Array = []
	var english := {}  # ctx -> kinds over budget in English
	var measured := 0
	for code: String in Report.LOCALE_ORDER:
		language.set_locale(code)
		_check(language.locale == code, "%s: locale set" % code)
		var catalog := {}
		if code != "en" and code != Lang.PSEUDO:
			for entry in Report.po_entries("res://locale/%s.po" % code):
				catalog[entry.ctx + "\u0004" + entry.msgid] = entry
		for entry in budgeted:
			for text in _forms(code, entry, catalog):
				var font: Font = load(Lang.FONT_BIG_PATH if entry.big else Lang.FONT_PATH)
				var size := UIKit.FONT_BIG if entry.big else UIKit.FONT
				measured += 1
				var filled := Loc.fill(text, SAMPLES)
				# (a 16 px text that steps down to the 8 px font where it doesn't fit: measured at 8 px then)
				if entry.big and entry.steps_down and UIKit.text_w(filled, UIKit.FONT_BIG, font) > entry.max_w:
					font = load(Lang.FONT_PATH)
					size = UIKit.FONT
				var widest := 0.0
				var widest_line := ""
				var line_count := filled.count("\n") + 1
				# (a box that wraps: only an unbreakable word can be too wide; the lines are the wrapped ones)
				var pieces: PackedStringArray = filled.replace("\n", " ").split(" ", false) if entry.wraps else filled.split("\n")
				for line in pieces:
					var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
					if w > widest:
						widest = w
						widest_line = line
				if entry.wraps:
					line_count = 0
					for line in filled.split("\n"):
						line_count += UIKit.wrapped_lines(line, entry.max_w, size, font)
				var found: Array[String] = []
				if widest > entry.max_w:
					found.append("overflow")
				if entry.max_lines > 0 and line_count > entry.max_lines:
					found.append("lines")
				for kind in found:
					if code == "en":
						english[entry.ctx + kind] = true
					var issue := {test = "budget", screen = "budget", node = entry.ctx, key = entry.ctx, locale = code, kind = kind,
						text = filled if kind == "lines" else widest_line, en_text = entry.msgid, text_w = widest, box_w = entry.max_w,
						text_h = line_count, box_h = entry.max_lines if entry.max_lines > 0 else null, other = ""}
					if code == "en":
						issue.acceptable = true
						issue.reason = "English source over its own budget note"
					elif english.has(entry.ctx + kind):
						issue.acceptable = true
						issue.reason = "also over in English"
					else:
						issue.acceptable = false
						issue.reason = ""
					issues.append(issue)
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	var open := issues.filter(func(i: Dictionary) -> bool: return not i.acceptable)
	_check(measured > budgeted.size() * Report.LOCALE_ORDER.size(), "%d texts measured" % measured)
	Report.write("budget", issues, {
		budgets = "%d of %d template entries carry a `max Npx` note" % [budgeted.size(), template.size()],
		fonts = "pixel.fnt at 8 px (pixel_big.fnt at 16 px for notes saying 16 px font) + the locale's fallback (Language.set_locale)",
		limits = "each call site's max Npx, or its grows to Npx where the screen widens the box for the text (wraps: wrapped there, line count and longest word measured); enforced for every locale%s" % ("" if REPORT_ONLY.is_empty() else " but " + ", ".join(REPORT_ONLY)),
		placeholders = "filled with tests/test_i18n_fit.gd SAMPLES (numbers 88 / 888, times 8:88.88, names BUBBLEGUM; {about} / {how} empty)",
	})
	for code: String in Report.LOCALE_ORDER:
		var mine := open.filter(func(i: Dictionary) -> bool: return i.locale == code)
		if not mine.is_empty():
			print("  report %s: %d over budget, e.g. %s (%d > %d px)" % [code, mine.size(), mine[0].key, mine[0].text_w, mine[0].box_w])
	print("  budget report: %d open, %d accepted -> docs/i18n/fit-report.md" % [open.size(), issues.size() - open.size()])
	if ENFORCE:
		var failing := open.filter(func(i: Dictionary) -> bool: return not i.locale in REPORT_ONLY)
		# (English-only mode, tests/i18n_mode.gd: the open ones are non-English by construction - English's own are
		# "acceptable" - so they are reported in the list above and docs/i18n/fit-report.md, not failed)
		_check_locale(failing.is_empty(), "every translation fits its width budget in every locale (%d open%s)" % [failing.size(),
			"" if REPORT_ONLY.is_empty() else ", reported only: " + ", ".join(REPORT_ONLY)])
	_extractor_check()
	_result()
	quit(1 if failures else 0)


## `entry`'s width budget from its call sites' hints (`#.` lines): each site's `max Npx`, or the larger
## `grows to Npx` where that site sizes its box from the text with the UIKit helpers (button_w /
## tab_widths / fit_text: the room the layout really has); the smallest over the sites. `wraps`: every
## budgeted site wraps the text inside that width (fit_text / autowrap), so the line count is the wrapped
## one (against `lines N`, default 2) and only an unbreakable word can overflow. `steps down to 8 px`:
## a 16 px text measured in the 8 px font where it does not fit at 16 (fit_text's last step). {} without
## a budget.
func _budget_of(entry: Dictionary) -> Dictionary:
	var limit := -1
	var wraps := true
	for line: String in entry.note_lines:
		if line.begins_with("budget:"):
			continue
		var m := _budget.search(line)
		if m == null:
			continue
		var w := int(m.get_string(1))
		var grows := _grows.search(line)
		if grows:
			w = maxi(w, int(grows.get_string(1)))
		limit = w if limit < 0 else mini(limit, w)
		wraps = wraps and line.contains("wraps")
	if limit < 0:
		return {}
	var lines := _lines.search(entry.notes)
	var max_lines := int(lines.get_string(1)) if lines else 0
	if wraps and max_lines == 0:
		max_lines = 2
	return {max_w = limit, max_lines = max_lines, big = entry.notes.contains("16 px"), wraps = wraps,
		steps_down = entry.notes.contains("steps down to 8 px")}


## The texts of `entry` in `code`: English (singular + plural), its pseudo-localized form, or every
## non-empty translated form (English where untranslated or fuzzy, as the game shows it).
func _forms(code: String, entry: Dictionary, catalog: Dictionary) -> Array[String]:
	var english: Array[String] = [entry.msgid]
	if entry.plural != "":
		english.append(entry.plural)
	if code == "en":
		return english
	if code == Lang.PSEUDO:
		var out: Array[String] = []
		for text in english:
			out.append(Loc.pseudolocalize(text))
		return out
	var translated: Dictionary = catalog.get(entry.ctx + "\u0004" + entry.msgid, {})
	var forms: Array[String] = []
	if not translated.is_empty() and not translated.fuzzy:
		for text: String in translated.msgstr:
			if text != "":
				forms.append(text)
	return forms if not forms.is_empty() else english


func _extractor_check() -> void:
	var script := ProjectSettings.globalize_path("res://tools/i18n_extract.py")
	for python: String in ["python3", "python"]:
		var output: Array = []
		var code := OS.execute(python, [script, "--check"] + (["--partial"] if I18nMode.ENGLISH_ONLY else []), output, true)
		if code == -1 or (code != 0 and not "i18n check" in "".join(output)):
			continue  # no such interpreter
		var text := "".join(output).strip_edges()
		_check(code == 0, "tools/i18n_extract.py --check%s: %s" % [" --partial (English-only mode)" if I18nMode.ENGLISH_ONLY else "", text.get_slice("\n", text.get_slice_count("\n") - 1)])
		if code != 0:
			print(text)
		return
	print("  note: no Python 3 on the PATH, tools/i18n_extract.py --check skipped")


## The pseudo locale (plan section 8): English, accented, ~40 % longer, bracketed per line, the
## placeholders kept and filled; on only while the pseudo locale is set.
func _pseudo() -> void:
	_check(Lang.choose_locale("es", Lang.PSEUDO, "fr_FR") == Lang.PSEUDO, "--lang=pseudo beats the saved and OS locale")
	var text := Loc.pseudolocalize("{count} HATS LEFT")
	_check(text.begins_with("[") and text.ends_with("]") and text.contains("{count}") and text.contains("HÁTŚ ŁÉFT")
		and text.length() >= ceili("{count} HATS LEFT".length() * 1.4), "pseudolocalize: %s" % text)
	_check(Loc.pseudolocalize("A\nB") == "[Á]\n[B]", "pseudolocalize: each line bracketed")
	language.set_locale(Lang.PSEUDO)
	_check(Loc.pseudo and Loc.t("common.back", "BACK") == Loc.pseudolocalize("BACK"), "pseudo locale: Loc.t returns the pseudo text")
	var counted := Loc.n("wheel.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", 3)
	_check(counted.contains("3 HÁTŚ") and not counted.contains("{"), "pseudo locale: plurals filled (%s)" % counted)
	_check((load(Lang.FONT_PATH) as Font).fallbacks.is_empty() and Lang.metrics(Lang.PSEUDO).ink_above == 3,
		"pseudo locale: the slimy font alone, accent head room")
	language.set_locale("en")
	_check(not Loc.pseudo and Loc.t("common.back", "BACK") == "BACK", "back to English: plain text")
