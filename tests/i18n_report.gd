extends RefCounted

## Shared by tests/test_i18n_fit.gd (static width budgets) and tests/test_i18n_screens.gd (every screen
## built in every locale): a .po parser and the fit report (docs/i18n/plan.md section 9, chunk F).
## Each suite writes its own machine-readable list, docs/i18n/fit-report.<kind>.json, then renders
## docs/i18n/fit-report.md from every list that exists (so the two suites can run in parallel; the last
## one to finish writes the complete page). Output is deterministic (sorted, no timestamps): an
## unchanged layout leaves both files byte-identical.
## An issue is a Dictionary: test kind, screen (or "budget"), node (path or msgctxt key), key (msgctxt
## when known), locale, kind (overflow / lines / offscreen / overlap / clip), text, en_text, text_w,
## box_w, text_h, box_h, other (the overlapped control), acceptable (bool) and reason.

const JSON_PATH := "res://docs/i18n/fit-report.%s.json"
const MD_PATH := "res://docs/i18n/fit-report.md"
const KINDS := ["budget", "screens"]
## Every locale the reports cover, in this order: English first, the 17 translations, then pseudo.
const LOCALE_ORDER := ["en", "es", "pt_BR", "fr", "de", "it", "ru", "pl", "tr", "ja", "ko", "zh_CN", "zh_TW", "th",
	"vi", "id", "ar", "hi", "pseudo"]


## Every entry of a .po / .pot file (not the header, not obsolete `#~` ones): {ctx, msgid, plural,
## msgstr: Array[String] (one per plural form), notes (the `#.` lines joined), note_lines (the `#.`
## lines, one per call site's hint, then the extractor's `budget:` line), fuzzy}.
static func po_entries(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entry := {}
	var part := ""
	var notes := PackedStringArray()
	var fuzzy := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#~"):
			continue
		if line.begins_with("#."):
			notes.append(line.substr(2).strip_edges())
			continue
		if line.begins_with("#,"):
			fuzzy = fuzzy or line.contains("fuzzy")
			continue
		if line.begins_with("#") or line == "":
			continue
		var value := _unescape(line.substr(line.find("\"") + 1).trim_suffix("\"")) if line.contains("\"") else ""
		if line.begins_with("msgctxt "):
			_close(out, entry)
			entry = {ctx = value, msgid = "", plural = "", msgstr = [], notes = " ".join(notes), note_lines = Array(notes), fuzzy = fuzzy}
			notes.clear()
			fuzzy = false
			part = "ctx"
		elif line.begins_with("msgid_plural "):
			entry.plural = value
			part = "plural"
		elif line.begins_with("msgid "):
			if part != "ctx":
				_close(out, entry)
				entry = {ctx = "", msgid = "", plural = "", msgstr = [], notes = " ".join(notes), note_lines = Array(notes), fuzzy = fuzzy}
				notes.clear()
				fuzzy = false
			entry.msgid = value
			part = "msgid"
		elif line.begins_with("msgstr"):
			(entry.msgstr as Array).append(value)
			part = "msgstr"
		elif line.begins_with("\""):
			match part:
				"ctx":
					entry.ctx += value
				"msgid":
					entry.msgid += value
				"plural":
					entry.plural += value
				"msgstr":
					var forms: Array = entry.msgstr
					forms[forms.size() - 1] += value
	_close(out, entry)
	return out


static func _close(out: Array[Dictionary], entry: Dictionary) -> void:
	if not entry.is_empty() and entry.msgid != "":
		out.append(entry)


static func _unescape(text: String) -> String:
	return text.replace("\\n", "\n").replace("\\\"", "\"").replace("\\t", "\t").replace("\\\\", "\\")


## Writes this suite's list and re-renders the page. `info` holds per-suite notes (what was measured).
## One issue per line; accepted findings outside English keep only their place and reason (their
## English twin has the details), so the file stays small.
static func write(kind: String, issues: Array, info: Dictionary) -> void:
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_key(a) < _sort_key(b))
	var rows := PackedStringArray()
	for issue: Dictionary in issues:
		var row := issue.duplicate()
		for field in ["text_w", "box_w", "text_h", "box_h"]:
			if row.get(field) != null:
				row[field] = snappedf(float(row[field]), 0.1)
		if row.acceptable and row.locale != "en":
			row = {screen = row.screen, node = row.node, kind = row.kind, locale = row.locale, other = row.other,
				acceptable = true, reason = row.reason}
		rows.append("    " + JSON.stringify(row, "", true))
	var text := "{\n  \"info\": %s,\n  \"issues\": [\n%s\n  ],\n  \"kind\": %s\n}\n" % [JSON.stringify(info, "", true),
		",\n".join(rows), JSON.stringify(kind)]
	var file := FileAccess.open(JSON_PATH % kind, FileAccess.WRITE)
	if file == null:
		push_warning("fit report: can't write %s" % (JSON_PATH % kind))
		return
	file.store_string(text)
	file.close()
	var md := FileAccess.open(MD_PATH, FileAccess.WRITE)
	if md:
		md.store_string(render_md())
		md.close()


static func _sort_key(issue: Dictionary) -> String:
	return "%02d|%s|%s|%s|%s|%s" % [LOCALE_ORDER.find(issue.get("locale", "")), issue.get("screen", ""),
		issue.get("node", ""), issue.get("kind", ""), issue.get("text", ""), issue.get("other", "")]


static func load_kind(kind: String) -> Dictionary:
	if not FileAccess.file_exists(JSON_PATH % kind):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH % kind))
	return parsed if parsed is Dictionary else {}


## The Markdown page: a summary per locale (open / accepted per suite), then every open issue.
static func render_md() -> String:
	var lines := PackedStringArray()
	lines.append("# i18n fit report")
	lines.append("")
	lines.append("Generated by `tests/test_i18n_fit.gd` (static width budgets of `locale/*.po`) and `tests/test_i18n_screens.gd`")
	lines.append("(every screen / overlay / HUD state built in each locale, every visible Label / Button measured against its")
	lines.append("box, the 320x180 screen and its neighbours). Do not edit: rerun the suites. Machine-readable lists:")
	lines.append("`fit-report.budget.json`, `fit-report.screens.json`. **Open** = a layout to fix or a translation to shorten;")
	lines.append("**accepted** = also so in English (the source layout), or listed as known-acceptable in the suite.")
	lines.append("Both suites are enforced (`ENFORCE`): any open finding fails them, except in Arabic (reported only until chunk I's RTL pass).")
	lines.append("")
	var data := {}
	for kind: String in KINDS:
		data[kind] = load_kind(kind)
	lines.append("| locale | budget open | budget accepted | screens open | screens accepted |")
	lines.append("|---|---|---|---|---|")
	var totals := [0, 0, 0, 0]
	for code: String in LOCALE_ORDER:
		var row := [code]
		var i := 0
		for kind: String in KINDS:
			var open := 0
			var accepted := 0
			for issue: Dictionary in data[kind].get("issues", []):
				if issue.get("locale", "") != code:
					continue
				if issue.get("acceptable", false):
					accepted += 1
				else:
					open += 1
			row.append(str(open))
			row.append(str(accepted))
			totals[i] += open
			totals[i + 1] += accepted
			i += 2
		lines.append("| " + " | ".join(row) + " |")
	lines.append("| **total** | %d | %d | %d | %d |" % totals)
	lines.append("")
	for kind: String in KINDS:
		var info: Dictionary = data[kind].get("info", {})
		if info.is_empty():
			continue
		lines.append("## %s: what was measured" % kind)
		lines.append("")
		var keys := info.keys()
		keys.sort()
		for key: String in keys:
			lines.append("- %s: %s" % [key, str(info[key])])
		lines.append("")
	for kind: String in KINDS:
		var issues: Array = data[kind].get("issues", [])
		if issues.is_empty():
			continue
		# Open findings grouped by place: one row per screen + node + kind, with every locale it hits.
		var groups := {}
		var order: Array[String] = []
		for issue: Dictionary in issues:
			if issue.get("acceptable", false):
				continue
			var key := "%s|%s|%s" % [issue.get("screen", ""), issue.get("node", ""), issue.get("kind", "")]
			if not groups.has(key):
				groups[key] = []
				order.append(key)
			groups[key].append(issue)
		order.sort()
		lines.append("## %s: open (%d places)" % [kind, order.size()])
		lines.append("")
		lines.append("| screen | node / key | English | kind | locales | widest (text vs box) |")
		lines.append("|---|---|---|---|---|---|")
		for key in order:
			var group: Array = groups[key]
			var first: Dictionary = group[0]
			var worst: Dictionary = first
			var codes := PackedStringArray()
			for issue: Dictionary in group:
				codes.append(issue.locale)
				if float(issue.get("text_w", 0)) - float(issue.get("box_w", 0)) > float(worst.get("text_w", 0)) - float(worst.get("box_w", 0)):
					worst = issue
			var english := ""
			for issue: Dictionary in group:
				if issue.get("en_text", "") != "":
					english = issue.en_text
					break
			lines.append("| %s | %s | %s | %s | %d: %s | %s %s: %s vs %s%s |" % [first.get("screen", ""),
				_cell(first.get("key", "") if first.get("key", "") != "" else first.get("node", "")), _cell(english), first.get("kind", ""),
				codes.size(), ", ".join(codes), worst.locale, _cell(worst.get("text", "")).left(30), _size(worst, "text"), _size(worst, "box"),
				(" (over " + _cell(worst.other) + ")") if str(worst.get("other", "")) != "" else ""])
		lines.append("")
		lines.append("## %s: accepted in English (the source layout; the same finding in another locale is accepted too)" % kind)
		lines.append("")
		lines.append("| screen | node / key | kind | text | other | reason |")
		lines.append("|---|---|---|---|---|---|")
		for issue: Dictionary in issues:
			if issue.get("acceptable", false) and (issue.get("locale", "") == "en" or not str(issue.get("reason", "")).contains("English")):
				lines.append("| %s | %s | %s | %s | %s | %s |" % [issue.get("screen", ""),
					_cell(issue.get("key", "") if issue.get("key", "") != "" else issue.get("node", "")), issue.get("kind", ""),
					_cell(issue.get("text", "")), _cell(issue.get("other", "")), _cell(issue.get("reason", ""))])
		lines.append("")
	return "\n".join(lines)


static func _size(issue: Dictionary, which: String) -> String:
	var w: Variant = issue.get(which + "_w", null)
	var h: Variant = issue.get(which + "_h", null)
	if w == null and h == null:
		return ""
	return "%sx%s" % [_num(w), _num(h)]


static func _num(value: Variant) -> String:
	if value == null:
		return "-"
	return str(int(round(float(value)))) if is_equal_approx(float(value), round(float(value))) else "%.1f" % float(value)


static func _cell(text: Variant) -> String:
	return str(text).replace("\n", " / ").replace("|", "\\|").left(60)
