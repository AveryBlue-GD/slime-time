extends "res://tests/suite_base.gd"

## The LANGUAGE screen (docs/i18n/plan.md section 6, chunk E): scenes/language.tscn +
## scripts/ui/language_screen.gd and the gated LANGUAGE button in SETTINGS (scripts/ui/controls.gd).
## - Gate off: SETTINGS has no LANGUAGE button (and nothing else changed: same buttons, same places).
## - Gate on, in every supported locale: SETTINGS shows a LANGUAGE button in the right column's 4th
##   cell (a globe + the current language's own name); the LANGUAGE page has 18 buttons in
##   Language.LOCALES order, each with its own name, script font and text direction, inside 320x180,
##   symmetric, rows >= 2 px apart, every name fitting its button (minimum size <= size), BACK on the
##   bottom row and inside the screen, only the current language selected and focused.
## - Keyboard / pad focus moves in the grid (wrapping left / right, down to BACK, BACK back up).
## - Picking a language saves it ([settings] language in the throwaway save) and reloads the page in
##   it; Esc / B goes back to SETTINGS. The real save is never touched (throwaway_save).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 120000 -s res://tests/test_language_screen.gd

const SETTINGS := "res://scenes/controls.tscn"
const PAGE := "res://scenes/language.tscn"
const PageScript := preload("res://scripts/ui/language_screen.gd")

var test_save := throwaway_save()
var progress: Node
var language: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	await _gate_off()
	Economy.languages_force = 1
	language.enable()
	await _settings_button()
	await _layout_every_locale()
	await _focus()
	await _pick_and_back()
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_check(not language.active and TranslationServer.get_loaded_locales().is_empty(), "the suite leaves nothing loaded")
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	await process_frame
	return screen


func _close(screen: Control) -> void:
	if current_scene == screen:
		current_scene = null
	screen.free()


## Every Button under `node`, as "text@rect" lines (the SETTINGS layout fingerprint).
func _button_layout(node: Node) -> Array[String]:
	var out: Array[String] = []
	for b: Node in node.find_children("*", "Button", true, false):
		var button := b as Button
		if button.is_visible_in_tree():
			out.append("%s@%s" % [button.text, Rect2(button.global_position, button.size)])
	out.sort()
	return out


func _gate_off() -> void:
	_check(not Economy.languages_on(), "the languages gate is off by default")
	var settings: Control = await _open(SETTINGS)
	_check(settings.language_button == null, "gate off: SETTINGS has no LANGUAGE button")
	var with_code := settings.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.has_meta("code"))
	_check(with_code.is_empty(), "gate off: no language button anywhere on SETTINGS")
	var layout := _button_layout(settings)
	_close(settings)
	# The same page with the gate on (English) has the same buttons plus the LANGUAGE one.
	Economy.languages_force = 1
	language.enable()
	language.set_locale("en")
	settings = await _open(SETTINGS)
	var on_layout := _button_layout(settings)
	on_layout.erase("@%s" % Rect2(settings.language_button.global_position, settings.language_button.size))
	_check(on_layout == layout, "gate on (English): every other SETTINGS button keeps its text and place")
	_close(settings)
	language.disable()
	Economy.languages_force = -1
	_check(progress.language == "", "nothing picked yet: no saved language")


func _settings_button() -> void:
	language.set_locale("en")
	var settings: Control = await _open(SETTINGS)
	var button: Button = settings.language_button
	_check(button != null and button.is_visible_in_tree(), "gate on: SETTINGS shows the LANGUAGE button")
	if button == null:
		_close(settings)
		return
	_check(Rect2(button.position, button.size) == Rect2(settings._cell(1, 3), Vector2(settings.COL_W, UIKit.BUTTON_H)),
		"it sits in the right column's 4th cell, 120x13 like its neighbours (mirroring FOG)")
	var icon: TextureRect = null
	var label: Label = null
	for child in button.get_children():
		if child is TextureRect:
			icon = child
		elif child is Label:
			label = child
	_check(icon != null and icon.texture.resource_path.ends_with("icon_globe.png"), "it shows the globe icon")
	_check(label != null and label.text == "ENGLISH", "... and the current language's own name")
	if icon and label:
		_check(icon.modulate == label.get_theme_color("font_color"), "the globe takes the name's color")
		var ink_l := button.position.x + icon.position.x
		var ink_r := button.position.x + label.position.x + label.size.x
		var left := ink_l - button.position.x
		var right := button.position.x + button.size.x - ink_r
		_check(absf(left - right) <= 1.0, "globe + name are centred as one group (%d / %d)" % [left, right])
	_close(settings)
	# In a tall script the button grows to that script's button height, on its row like its neighbours
	# (the rows follow UIKit.button_h(): i18n chunk G2).
	language.set_locale("hi")
	settings = await _open(SETTINGS)
	button = settings.language_button
	var h := maxi(UIKit.button_h(), int(language.metrics("hi").button_h))  # (22: the settings rows' height, fix pass R2)
	_check(button.size.y == h and button.get_combined_minimum_size().y <= h, "Hindi: the button is %d tall and its name fits" % h)
	_check(button.position == settings._cell(1, 3) and button.size.x == settings.fog_button.size.x
		and button.position.y == settings.fog_button.position.y and button.size.y == settings.fog_button.size.y,
		"... on its row, level with FOG and as big")
	_close(settings)
	language.set_locale("en")


func _layout_every_locale() -> void:
	var codes: Array[String] = language.codes()
	_check(codes.size() == 18, "18 languages")
	for code in codes:
		language.set_locale(code)
		var page: Control = await _open(PAGE)
		var bad: Array[String] = []
		var rects: Array[Rect2] = []
		var selected: Array[String] = []
		for i in codes.size():
			var c: String = codes[i]
			var b: Button = page.buttons.get(c)
			if b == null:
				bad.append("%s missing" % c)
				continue
			var r := Rect2(b.global_position, b.size)
			rects.append(r)
			if b.text != language.native_name(c):
				bad.append("%s text %s" % [c, b.text])
			if b.get_combined_minimum_size().y > b.size.y or b.get_combined_minimum_size().x > b.size.x:
				bad.append("%s does not fit (%s > %s)" % [c, b.get_combined_minimum_size(), b.size])
			if not Rect2(0, 0, 320, 180).encloses(r):
				bad.append("%s off screen" % c)
			if r.size.y < int(language.metrics(c).button_h):
				bad.append("%s shorter than its script's button" % c)
			var font: Font = b.get_theme_font("font")
			if font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FONT).x > b.size.x - 8:
				bad.append("%s wider than its button minus 4 px margins" % c)
			if not font.has_char(b.text.unicode_at(0)) and not (font.fallbacks.any(func(f: Font) -> bool: return f.has_char(b.text.unicode_at(0)))):
				bad.append("%s's font lacks its script" % c)
			var wrong := _wrong_font_chars(c, font)
			if wrong != "":
				bad.append("%s: %s drawn by the wrong font" % [c, wrong])
			var rtl: bool = c in language.RTL_LOCALES
			if b.text_direction != (Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR):
				bad.append("%s text direction" % c)
			if b.get_meta("selected", false):
				selected.append(c)
			if i > 0 and i % PageScript.COLUMNS != 0:
				# (reading order: left to right, or right to left in a mirrored (RTL) page, docs/ui-rules.md 10.2)
				var prev: Button = page.buttons[codes[i - 1]]
				var step := (PageScript.BUTTON_W + PageScript.COL_GAP) * UIKit.reading_dir()
				if b.position.y != prev.position.y or b.position.x != prev.position.x + step:
					bad.append("%s not %s of %s" % [c, "left" if step < 0 else "right", codes[i - 1]])
		# Overlaps and gaps (>= 2 px between any two buttons, BACK included).
		var back: Button = page.back_button
		var back_rect := Rect2(back.global_position, back.size)
		rects.append(back_rect)
		for a in rects.size():
			for z in range(a + 1, rects.size()):
				if rects[a].grow(1).intersects(rects[z].grow(1)):
					bad.append("%s and %s closer than 2 px" % [rects[a], rects[z]])
		var grid: Rect2 = page.grid
		var left := grid.position.x
		var right := 320 - grid.end.x
		if left != right or grid.size.x != 304:
			bad.append("grid not symmetric (L%d R%d W%d)" % [left, right, grid.size.x])
		var back_x := UIKit.SCREEN.x - UIKit.EDGE - back_rect.size.x if UIKit.rtl() else float(UIKit.EDGE)  # (bottom right when mirrored)
		if back_rect.position.x != back_x or back_rect.end.y > UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H \
				or back_rect.position.y > UIKit.BOTTOM_ROW_Y or back.get_combined_minimum_size().y > back.size.y:
			bad.append("BACK misplaced %s" % back_rect)
		if grid.position.y < UIKit.TITLE_Y + 20:
			bad.append("grid under the title box")
		if selected != [code]:
			bad.append("selected %s" % [selected])
		if root.gui_get_focus_owner() != page.buttons.get(code):
			bad.append("focus is not on the current language")
		_check(bad.is_empty(), "%s: LANGUAGE page layout %s" % [code, "ok" if bad.is_empty() else str(bad)])
		_close(page)
	language.set_locale("en")


## The family each script's fallback must come from (tools/i18n_subset_fonts.py names the subsets):
## Han characters have regional shapes, so 繁體中文 must be drawn by the Traditional (Taiwan) font.
const SCRIPT_FAMILY := {"zh_CN": "SlimeTime CJK SC", "zh_TW": "SlimeTime CJK TC", "ja": "SlimeTime CJK JP",
	"ko": "SlimeTime CJK KR", "th": "SlimeTime Thai", "hi": "SlimeTime Devanagari", "ar": "SlimeTime Arabic"}


## The characters of `code`'s native name that `font` would draw with another font than the right one:
## the slimy font (no fallback) for Latin / Cyrillic names, else that locale's own script fallback
## (its family, at its fixed size) for every character the slimy font lacks. Resolves like Godot does:
## the font itself (a FontVariation's base), then its fallbacks in order.
func _wrong_font_chars(code: String, font: Font) -> String:
	var chain: Array[Font] = [font.base_font if font is FontVariation else font]
	chain.append_array(font.fallbacks)
	var own: FontFile = language.fallback_font(code)
	var out := ""
	var name: String = language.native_name(code)
	for i in name.length():
		var ch := name.unicode_at(i)
		if name[i] == " ":
			continue
		var used: Font = null
		for f in chain:
			if f.has_char(ch):
				used = f
				break
		var ok := used != null
		if own == null:
			ok = ok and used == chain[0] and font.fallbacks.is_empty()
		elif not chain[0].has_char(ch):
			ok = ok and used == own and own.get_font_name() == SCRIPT_FAMILY[code] \
				and own.fixed_size == int(language.SCRIPT_FONTS[code][1]) \
				and (code != "zh_TW" or own.fixed_size >= 12)  # 10 px Traditional: 繁 / 體 read as 無 / 罶
		if not ok:
			out += name[i]
	return out


func _focus() -> void:
	language.set_locale("en")
	var page: Control = await _open(PAGE)
	var codes: Array[String] = language.codes()
	var b: Dictionary = page.buttons
	var en: Button = b.en
	_check(en.get_node(en.focus_neighbor_right) == b.es and en.get_node(en.focus_neighbor_left) == b.pt_BR,
		"left / right move in a row and wrap")
	_check(en.get_node(en.focus_neighbor_bottom) == b.fr and en.get_node(en.focus_neighbor_top) == en, "down moves a row, up stops at the top")
	var last_row: Button = b[codes[codes.size() - 2]]
	_check(last_row.get_node(last_row.focus_neighbor_bottom) == page.back_button, "down from the bottom row goes to BACK")
	_check(page.back_button.get_node(page.back_button.focus_neighbor_top) == b[codes[codes.size() - 3]],
		"up from BACK goes to the bottom row's first button")
	_tap_key(KEY_RIGHT)
	await process_frame
	_check(root.gui_get_focus_owner() == b.es, "the right arrow moves the focus to ESPAÑOL")
	_tap_key(KEY_DOWN)
	await process_frame
	_check(root.gui_get_focus_owner() == b.de, "the down arrow moves it to DEUTSCH")
	var pad := InputEventJoypadButton.new()
	for down in [true, false]:
		pad.button_index = JOY_BUTTON_DPAD_LEFT
		pad.pressed = down
		Input.parse_input_event(pad.duplicate())
		Input.flush_buffered_events()
		await process_frame
	_check(root.gui_get_focus_owner() == b.fr, "the D-pad moves it too")
	# Touch: every name is a TouchButton (grown hit areas, shared by distance; UIKit rules).
	_check(codes.all(func(c: String) -> bool: return b[c] is TouchButton), "every language is a touch button")
	var pitch: float = b.fr.position.y - b.en.position.y
	_check(pitch >= 19.0, "rows have a pitch of at least 19 px (%d)" % pitch)
	_close(page)


## Waits until a NEW scene from `path` replaced `old` as the current scene.
func _wait_for_scene(path: String, old: Node, frames := 240) -> bool:
	var old_id := old.get_instance_id()
	for i in frames:
		await process_frame
		if current_scene and current_scene.get_instance_id() != old_id and current_scene.scene_file_path == path:
			return true
	return false


func _pick_and_back() -> void:
	language.set_locale("en")
	progress.language = ""
	progress.save_progress()
	_check(not FileAccess.get_file_as_string(test_save).contains("language"), "before a pick the save has no language")
	var page: Control = await _open(PAGE)
	page.buttons.es.pressed.emit()
	_check(language.locale == "es" and progress.language == "es", "picking ESPAÑOL switches to es and sets Progress.language")
	_check(FileAccess.get_file_as_string(test_save).contains("language=\"es\""), "... and saves it ([settings] language)")
	_check(await _wait_for_scene(PAGE, page), "the page reloads in the new language")
	page = current_scene
	_check(page.buttons.es.get_meta("selected", false) and not page.buttons.en.get_meta("selected", false),
		"after the reload ESPAÑOL is the selected one")
	_check(root.gui_get_focus_owner() == page.buttons.es, "... and has the focus")
	# Picking the language in use saves it too (e.g. one that only came from the OS), no reload.
	progress.language = ""
	page.buttons.es.pressed.emit()
	_check(progress.language == "es", "picking the current language saves it")
	await process_frame
	_check(current_scene == page, "... without reloading")
	_tap_key(KEY_ESCAPE)
	_check(await _wait_for_scene(SETTINGS, page), "Esc goes back to SETTINGS")
	var settings: Control = current_scene
	await process_frame
	_check(settings.language_button != null and settings.language_button.get_meta("code") == "es",
		"SETTINGS' LANGUAGE button now names ESPAÑOL")
	settings.language_button.pressed.emit()
	_check(await _wait_for_scene(PAGE, settings), "the LANGUAGE button opens the page")
	page = current_scene
	page.back_button.pressed.emit()
	_check(await _wait_for_scene(SETTINGS, page), "BACK returns to SETTINGS")
	await process_frame
	var leftover := current_scene
	current_scene = null
	leftover.queue_free()
	await process_frame
	progress.language = ""
	language.set_locale("en")
