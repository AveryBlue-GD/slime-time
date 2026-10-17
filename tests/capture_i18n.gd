extends "res://tests/test_i18n_screens.gd"

## Reviewer capture driver (docs/i18n/review/README.md; run it through ./tools/i18n_capture.sh).
## Not a test (the name does not match test_*.gd, so tools/test_all.sh skips it). It reuses the 53
## screen / overlay / HUD state builders of tests/test_i18n_screens.gd by extending that suite and
## overriding only what happens at each state: `_scan` (instead of measuring text it saves the rendered
## frame and checks every character against the font chain the control really uses) and `_open` (re-seeds
## the global RNG so the text drips are the same on every run).
## One process = one locale (the shell runs several in parallel). Needs a window (not --headless).
## Args after `--`: --locale=xx  --out=ABS_DIR  [--states=slug,slug]  [--keep-backdrop]
## Output: OUT/<locale>/<state-slug>.png (320x180), OUT/<locale>/.raw/<slug>.rgbz (zlib RGB8 for
## tools/i18n_contact_sheet.py), OUT/json/missing_<locale>.json and OUT/json/states_<locale>.json.
## Throwaway save only; the real save is never read or written.

const SEED := 20261017

var out_dir := ""
var locale_code := "en"
var wanted: PackedStringArray = []
var keep_backdrop := false
var captured: Array[String] = []
var missing: Array[Dictionary] = []
var texts_checked := 0
## state name -> slug, in build order
var order: Array[Array] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			locale_code = arg.substr(9)
		elif arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--states="):
			wanted = arg.substr(9).split(",", false)
		elif arg == "--keep-backdrop":
			keep_backdrop = true
	if out_dir == "":
		push_error("capture_i18n: --out=DIR is required")
		quit(2)
		return
	Economy.descent_force = 1  # Descent is switched off in the game; its screens are still captured
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	Economy.languages_force = 1
	Economy.forced_locale = locale_code
	language.enable()
	language.set_locale(locale_code)
	_check(language.locale == locale_code, "%s: locale set" % locale_code)
	DirAccess.make_dir_recursive_absolute(out_dir.path_join(locale_code).path_join(".raw"))
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("json"))
	_code = locale_code
	await _all_states()
	_write_json(out_dir.path_join("json/missing_%s.json" % locale_code), missing)
	var names: Array = []
	for pair in order:
		names.append({state = pair[0], slug = pair[1]})
	_write_json(out_dir.path_join("json/states_%s.json" % locale_code), names)
	var probe: Font = load(Lang.FONT_PATH)  # the check's sanity probe: the slimy font has A, not an emoji
	_check(probe.has_char(0x41) and not probe.has_char(0x1F600), "glyph probe: has_char tells present from absent")
	print("  checked %d texts" % texts_checked)
	print("  captured %d of %d states for %s, %d missing-glyph findings" % [captured.size(), order.size(), locale_code, missing.size()])
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	_result()
	quit(1 if failures else 0)


## Every screen is opened with the same RNG state: the text drips (UIKit's per-scene shader seed) and
## anything else random come out the same in every run and every locale.
func _open(path: String) -> Node:
	seed(SEED)
	var screen: Node = await super._open(path)
	_hide_backdrop(screen)
	await _frames(2)  # (the hidden backdrop must be rendered before any capture)
	return screen


## The drifting maze and mist move with the engine clock: hide them, keep the flat background colour.
func _hide_backdrop(node: Node) -> void:
	if keep_backdrop:
		return
	for n in _all(node):
		if n is MenuBackdrop:
			for i in range(1, n.get_child_count()):
				(n.get_child(i) as CanvasItem).visible = false


func _scan(state: String, node: Node) -> void:
	var slug := slugify(state)
	_hide_backdrop(node)
	order.append([state, slug])
	_check_glyphs(state, node)
	if not wanted.is_empty() and not (slug in wanted or state in wanted):
		return
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("capture_i18n: no frame for %s" % state)
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(locale_code).path_join(slug + ".png"))
	var raw := FileAccess.open(out_dir.path_join(locale_code).path_join(".raw/%s.rgbz" % slug), FileAccess.WRITE)
	raw.store_buffer(PackedInt32Array([img.get_width(), img.get_height()]).to_byte_array())
	raw.store_buffer(img.get_data().compress(FileAccess.COMPRESSION_DEFLATE))
	raw.close()
	captured.append(slug)


static func slugify(state: String) -> String:
	var out := ""
	for c in state.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.trim_prefix("-").trim_suffix("-")


## Flags every character of a visible Label / Button text that its own font chain cannot draw (it
## would show as a missing-glyph box). Font.has_char looks through the font's fallbacks.
func _check_glyphs(state: String, node: Node) -> void:
	for c in _all(node):
		var control := c as Control
		if control == null or not (control is Label or control is Button):
			continue
		if not control.is_visible_in_tree() or _alpha(control) < 0.05:
			continue
		var text: String = control.text
		if text.strip_edges() == "":
			continue
		texts_checked += 1
		var font: Font = control.get_theme_font("font")
		var bad := {}
		for i in text.length():
			var cp := text.unicode_at(i)
			if _ignorable(cp):
				continue
			if not font.has_char(cp):
				bad[cp] = true
		if bad.is_empty():
			continue
		var chars := PackedStringArray()
		var points := PackedStringArray()
		for cp: int in bad:
			chars.append(char(cp))
			points.append("U+%04X" % cp)
		missing.append({locale = locale_code, state = state, slug = slugify(state), node = _id(node, control), text = text,
			chars = "".join(chars), codepoints = ", ".join(points), font = font.get_font_name() if font.get_font_name() != "" else str(font)})


## Spaces, controls and invisible format characters never draw a glyph.
static func _ignorable(cp: int) -> bool:
	return cp <= 0x20 or (cp >= 0x7F and cp <= 0xA0) or cp == 0xAD or (cp >= 0x200B and cp <= 0x200F) \
		or (cp >= 0x202A and cp <= 0x202E) or (cp >= 0x2060 and cp <= 0x206F) or cp == 0xFEFF or (cp >= 0xFE00 and cp <= 0xFE0F)


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", true))
	f.close()
