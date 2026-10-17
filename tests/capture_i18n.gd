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
## Goo-ink check findings (_check_goo_ink): text ink drawn inside a goo frame's band / lump rows.
var goo_ink: Array[Dictionary] = []
var goo_touch := 0
## --measure-boxes: each goo box's text ink extent (box-relative first / last column and row).
var measure_boxes := false
var box_ink: Array[Dictionary] = []
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
		elif arg == "--measure-boxes":
			measure_boxes = true
	if out_dir == "":
		push_error("capture_i18n: --out=DIR is required")
		quit(2)
		return
	Economy.descent_force = 1  # Descent is switched off in the game; its screens are still captured
	Hats.frozen_flow_step = 0  # (the rainbow hat's clock-driven hue: same pixels and RIDs every run)
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
	_write_json(out_dir.path_join("json/goo_ink_%s.json" % locale_code), goo_ink)
	if measure_boxes:
		_write_json(out_dir.path_join("json/box_ink_%s.json" % locale_code), box_ink)
	var on_px := 0
	var zone_px := 0
	for hit in goo_ink:
		on_px += int(hit.on_goo)
		zone_px += int(hit.zone)
	print("  goo-ink check %s: %d glyph ink pixels on goo, %d in band / lump rows (%d boxes), %d touching a panel's goo" % [locale_code, on_px, zone_px, goo_ink.size(), goo_touch])
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
	Hats.frozen_flow_step = -1
	GooBox.seed_ids.clear()
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


func _scan(state: String, node: Node) -> void:  # (a coroutine here: the suite awaits it)
	var slug := slugify(state)
	_hide_backdrop(node)
	order.append([state, slug])
	_check_glyphs(state, node)
	if not wanted.is_empty() and not (slug in wanted or state in wanted):
		return
	# Frozen while it is captured and checked (nothing moves between the renders), and the text drips on
	# one fixed seed: two runs, or two builds, give the same pixels (UIKit's per-scene drip seed depends on
	# how much the scene's build drew from the RNG).
	var mode := node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if UIKit._text_material:
		UIKit._text_material.set_shader_parameter("seed", float(SEED % 10000))
	_stable_lumps()
	var img := await _render()
	if img == null or img.is_empty():
		push_error("capture_i18n: no frame for %s" % state)
		node.process_mode = mode
		return
	img.save_png(out_dir.path_join(locale_code).path_join(slug + ".png"))
	var raw := FileAccess.open(out_dir.path_join(locale_code).path_join(".raw/%s.rgbz" % slug), FileAccess.WRITE)
	raw.store_buffer(PackedInt32Array([img.get_width(), img.get_height()]).to_byte_array())
	raw.store_buffer(img.get_data().compress(FileAccess.COMPRESSION_DEFLATE))
	raw.close()
	await _goo_ink_frozen(state, node, img)
	captured.append(slug)
	node.process_mode = mode


## Every goo box's lumps seeded from its place in the tree (child indices from the root), not from its
## canvas item's RID: the RID counter depends on everything built before (an extra text shaped, a node
## hidden), which moved the lumps of every later state; with this a build is compared state by state.
func _stable_lumps() -> void:
	GooBox.seed_ids.clear()
	var stack: Array[Array] = [[root, "r"]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var n: Node = top[0]
		var path: String = top[1]
		var item := n as CanvasItem
		if item:
			GooBox.seed_ids[item.get_canvas_item().get_id()] = hash(path)
			item.queue_redraw()
		for i in n.get_child_count():
			stack.append([n.get_child(i), "%s/%d" % [path, i]])


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


# ---- Goo-ink check (render based, docs/ui-rules.md section 10): no glyph ink inside a goo band ----
# The frame is rendered again with every text transparent (Label self_modulate, Button / LineEdit font
# colours): the pixels that change are the texts' ink (letters, marks, shadows, drips). Every visible
# goo box (GooBox: buttons, tabs, panels, pills) has a band zone: its outline, band and the deepest its
# lumps can reach (band + lump rows at the top / bottom, columns at the sides). Text ink inside a box's
# rect but in that zone is a finding (English: 0). Separately counted, not a finding: ink right under a
# panel's actual goo pixel (a mark touching the drips; English panels keep a clear row).

const TEXT_COLORS := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
	"font_hover_pressed_color", "font_disabled_color", "font_outline_color", "font_uneditable_color",
	"font_placeholder_color", "font_shadow_color"]


func _goo_ink_frozen(state: String, node: Node, frame: Image) -> void:
	var undo: Array[Callable] = []
	var nodes := _all(node)
	var texts: Array[Array] = []  # [index in nodes, grown rect, canvas]: ink is only looked for around texts
	for n in nodes.size():
		var control := nodes[n] as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if (control is Label or control is Button or control is LineEdit) and String(control.get("text")) != "":
			var tr := _rect(control)
			texts.append([n, Rect2i(int(tr.position.x) - 2, int(tr.position.y) - 8, int(tr.size.x) + 4, int(tr.size.y) + 12), control.get_canvas()])
		if control is Label:
			var label := control as Label
			var before := label.self_modulate
			label.self_modulate = Color(before, 0.0)
			undo.append(func() -> void: label.self_modulate = before)
		elif control is Button or control is LineEdit:
			for color_name: String in TEXT_COLORS:
				if control.has_theme_color_override(color_name):
					var old := control.get_theme_color(color_name)
					undo.append(func() -> void: control.add_theme_color_override(color_name, old))
				else:
					undo.append(func() -> void: control.remove_theme_color_override(color_name))
				control.add_theme_color_override(color_name, Color(0, 0, 0, 0))
	var bare := await _render()
	for f in undo:
		f.call()
	# Then only the Labels' drop shadows hidden: a pixel that changes there is shadow, not a glyph's ink.
	undo.clear()
	for c in nodes:
		var label := c as Label
		if label and label.is_visible_in_tree():
			var had := label.has_theme_color_override("font_shadow_color")
			var old := label.get_theme_color("font_shadow_color")
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			undo.append(func() -> void:
				if had:
					label.add_theme_color_override("font_shadow_color", old)
				else:
					label.remove_theme_color_override("font_shadow_color"))
	var unshaded := await _render()
	for f in undo:
		f.call()
	await _frames(2)
	var w := frame.get_width()
	var h := frame.get_height()
	var a := frame.get_data()
	var b := bare.get_data()
	var c := unshaded.get_data()
	var changed := PackedByteArray()
	changed.resize(w * h)
	for i in w * h:
		var o := i * 3
		if (a[o] != b[o] or a[o + 1] != b[o + 1] or a[o + 2] != b[o + 2]) and a[o] == c[o] and a[o + 1] == c[o + 1] and a[o + 2] == c[o + 2]:
			changed[i] = 1
	# Goo boxes in drawing order, so a box's goo hidden under a later box (a panel opened over buttons)
	# is not counted.
	var boxes: Array[Array] = []  # [index in nodes, rect, canvas]
	for n in nodes.size():
		var control := nodes[n] as Control
		if control and control.is_visible_in_tree() and _alpha(control) >= 0.05 and _goo_box(control) != null:
			boxes.append([n, Rect2i(_rect(control)), control.get_canvas()])
	for n in nodes.size():
		var control := nodes[n] as Control
		if control == null or not control.is_visible_in_tree() or _alpha(control) < 0.05:
			continue
		var box := _goo_box(control)
		if box == null:
			continue
		var r := _rect(control)
		var x0 := int(r.position.x)
		var y0 := int(r.position.y)
		var bw := int(r.size.x)
		var bh := int(r.size.y)
		if bw < 6 or bh < 6:
			continue
		# Ink that can be over this box: texts drawn after it (its own, its children's, later nodes' on
		# the same canvas), never a text behind it showing through a translucent face.
		var ink := PackedByteArray()
		ink.resize(w * h)
		for t: Array in texts:
			if t[0] < n or t[2] != control.get_canvas():
				continue
			var tr: Rect2i = t[1]
			for y in range(maxi(tr.position.y, 0), mini(tr.end.y, h)):
				for x in range(maxi(tr.position.x, 0), mini(tr.end.x, w)):
					ink[y * w + x] = changed[y * w + x]
		# The band zone: rows 0 .. band + lump at the top (row 0 = outline), the same at the bottom, columns
		# 0 .. band + lump at the sides; and the goo's real pixels (outline, band, lumps, drops).
		var later: Array[Rect2i] = []  # (later boxes on the same canvas, not this one's children: they cover it)
		for other: Array in boxes:
			if other[0] > n and other[2] == control.get_canvas() and not control.is_ancestor_of(nodes[other[0]]):
				later.append(other[1])
		var top := 1 + box.band.x + box.lump.x
		var bottom := box.band.z + box.lump.z
		var side := 1 + box.band.y + box.lump.y
		var zone := 0
		var rows := {}
		for y in range(maxi(y0, 0), mini(y0 + bh, h)):
			for x in range(maxi(x0, 0), mini(x0 + bw, w)):
				if ink[y * w + x] == 0 or _covered(later, x, y):
					continue
				var dy := y - y0
				var dx := x - x0
				if dy < top or dy >= bh - bottom or dx < side or dx >= bw - side:
					zone += 1
					rows[dy] = true
		var on := 0
		var touch := 0
		var layout: Array = box._layout(control.get_canvas_item().get_id(), bw, bh)
		var runs: PackedInt32Array = layout[0]
		for i in range(0, runs.size(), 4):
			for k in runs[i + 2]:
				var x := x0 + runs[i] + k
				var y := y0 + runs[i + 1]
				if x < 0 or x >= w or y < 0 or y >= h or _covered(later, x, y):
					continue
				if ink[y * w + x] == 1:
					on += 1
				elif box.kind == GooBox.Kind.PANEL:
					for ny in [y - 1, y + 1]:
						if ny >= y0 and ny < mini(h, y0 + bh) and ink[ny * w + x] == 1:
							touch += 1
		goo_touch += touch
		if measure_boxes:  # (--measure-boxes: every box's ink rows / columns, for layout work)
			var ink_box := Rect2i()
			for y in range(maxi(y0, 0), mini(y0 + bh, h)):
				for x in range(maxi(x0, 0), mini(x0 + bw, w)):
					if ink[y * w + x] == 1 and not _covered(later, x, y):
						var p := Rect2i(x - x0, y - y0, 1, 1)
						ink_box = p if ink_box.size == Vector2i.ZERO else ink_box.merge(p)
			if ink_box.size != Vector2i.ZERO:
				box_ink.append({state = slugify(state), box = _id(node, control), rect = [x0, y0, bw, bh],
					ink = [ink_box.position.x, ink_box.position.y, ink_box.end.x - 1, ink_box.end.y - 1]})
		if zone > 0 or on > 0:
			var hit := {locale = locale_code, state = state, slug = slugify(state), box = _id(node, control),
				rect = [x0, y0, bw, bh], on_goo = on, zone = zone, touch = touch, rows = rows.keys()}
			goo_ink.append(hit)


func _render() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


static func _covered(rects: Array[Rect2i], x: int, y: int) -> bool:
	for r in rects:
		if r.has_point(Vector2i(x, y)):
			return true
	return false


## The goo box `control` draws now (a Button's state style, a panel's "panel"), or null.
func _goo_box(control: Control) -> GooBox:
	var names: Array[String] = []
	if control is Button:
		var button := control as Button
		if button.disabled:
			names.append("disabled")
		elif button.button_pressed:
			names.append("pressed")
		names.append("normal")
	else:
		names.append_array(["panel", "normal"])
	for style_name in names:
		if control.has_theme_stylebox(style_name):
			var style := control.get_theme_stylebox(style_name)
			if style is GooBox:
				return style as GooBox
	return null
