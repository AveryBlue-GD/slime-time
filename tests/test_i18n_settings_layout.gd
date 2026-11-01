extends "res://tests/suite_base.gd"

## Layout in every locale (i18n chunk G2, docs/ui-rules.md section 10) of SETTINGS (+ its SAVE CODE and
## RESET panels), CONTROLS (key remapping, every page), the title and LANGUAGE, with the gate on and the
## locale's fallback font installed. Arabic is skipped (its mirroring is chunk I). Measured from the
## built controls' rects and their texts' widths / line heights, per locale:
## - SETTINGS: both columns the same width and centred (left margin == right margin), the four rows
##   evenly pitched under the headings, the headings under the title's line box, the last row at least
##   GAP_S over BACK / RESET PROGRESS, every text inside its button (minimum size <= size), no two
##   buttons / boxes overlapping, everything inside 320x180.
## - SAVE CODE / RESET panels: the panel inside the screen's EDGE, every text and button inside the panel,
##   no text over a button or another text, the code boxes as tall as and level with their buttons,
##   the button pairs centred; the page's controls under a
##   panel hidden while it is open (all but English, which keeps its faint ghost: byte-identical).
## - CONTROLS: on each page, the shown rows inside the screen, no overlaps, the columns centred, the note
##   under the rows and over the bottom row; every action on exactly one page; one page wherever five
##   rows and the note fit (all Latin locales, CJK, Vietnamese).
## - Title: ENTER centred, the slimes symmetric to it, the tagline under it and inside the screen, each of
##   its lines' ink (accents, drips) clear of the slimes' ink and of STORY.
## - LANGUAGE: the grid symmetric, >= 2 px under the title's line box and over BACK.
## - English: the source positions pinned (SOUND at (36, 38) 120x13, rows 20 apart, CONTROLS rows at 30,
##   17 apart, the SAVE CODE panel (12, 14) 296x150, the RESET panel (24, 48) 272x82, ENTER (72, 84)).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 120000 -s res://tests/test_i18n_settings_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")
const SCREEN := Rect2(0, 0, 320, 180)

var progress: Node
var language: Node
var _code := ""
## The locales whose CONTROLS note is centred nearer than GAP_L over the bottom row (_keys).
var _centred_notes := {}


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		if code == "ar":
			continue
		_code = code
		language.set_locale(code)
		await _settings()
		await _keys()
		await _title()
		await _language_page()
	_check(_centred_notes.keys() == ["vi", "pseudo"], "CONTROLS: the note closer than GAP_L to the bottom row (centred) only in Vietnamese and pseudo (%s)" % [_centred_notes.keys()])
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	return screen


# ------------------------------------------------------------------ SETTINGS

func _settings() -> void:
	var page: Control = await _open("res://scenes/controls.tscn")
	var bad: Array[String] = []
	var left: Array[Control] = [page.sound_button, page.volume_slider.get_parent().get_parent(), page.music_slider.get_parent().get_parent(), page.motion_button, page.fog_button]
	var right: Array[Control] = [page.fullscreen_button, page.controls_button, page.save_code_button, page.language_button]
	var w: float = page.sound_button.size.x
	for column: Array[Control] in [left, right]:
		for i in column.size():
			var r := _rect(column[i])
			if r.size.x != w:
				bad.append("%s %d wide (column %d)" % [column[i].name, r.size.x, w])
			if r.size.y != UIKit.button_h():
				bad.append("%s %d tall (button_h %d)" % [column[i].name, r.size.y, UIKit.button_h()])
			if i > 0 and r.position.y - _rect(column[i - 1]).position.y != page.row_step:
				bad.append("%s off the row pitch" % column[i].name)
			if r.position.y != _rect(left[i]).position.y:
				bad.append("%s not level with its row" % column[i].name)
	var l := _rect(left[0]).position.x
	var r_end := _rect(right[0]).end.x
	if l != 320 - r_end or _rect(right[0]).position.x - _rect(left[0]).end.x != UIKit.GAP_L:
		bad.append("columns not centred (L%d R%d)" % [l, 320 - r_end])
	var bottom := _rect(left[left.size() - 1]).end.y
	if bottom + UIKit.GAP_S > UIKit.bottom_row_y():
		bad.append("last row ends at %d, bottom row at %d" % [bottom, UIKit.bottom_row_y()])
	if page.heading_y < UIKit.title_bottom() or page.heading_y + UIKit.line_h() > page.first_row:
		bad.append("headings at %d (title ends %d, first row %d)" % [page.heading_y, UIKit.title_bottom(), page.first_row])
	if _code == "en" and (_rect(page.sound_button) != Rect2(36, 38, 120, 13) or page.row_step != 20 or _rect(page.language_button) != Rect2(164, 98, 120, 13)):
		bad.append("English grid moved: SOUND %s LANGUAGE %s" % [_rect(page.sound_button), _rect(page.language_button)])
	_overlaps(page, page, bad)
	_check(bad.is_empty(), "%s: SETTINGS grid %s" % [_code, "ok" if bad.is_empty() else str(bad)])

	page._open_codes()
	await process_frame
	bad = []
	_panel(page, page.code_panel, bad)
	for box: LineEdit in [page.code_out, page.code_in]:
		if _rect(box).size.y != UIKit.button_h() or _rect(box).position.y != _rect(page.copy_button if box == page.code_out else page.paste_button).position.y:
			bad.append("%s %s not level with its buttons (button_h %d)" % [box.name, _rect(box), UIKit.button_h()])
	if _code == "en" and page.code_panel.get_meta("panel_rect") != Rect2(12, 14, 296, 150):
		bad.append("English SAVE CODE panel moved: %s" % page.code_panel.get_meta("panel_rect"))
	_check(bad.is_empty(), "%s: SAVE CODE panel %s" % [_code, "ok" if bad.is_empty() else str(bad)])
	page._close_codes()
	await process_frame
	_check(page.sound_button.visible and page.reset_button.visible, "%s: the page is back when SAVE CODE closes" % _code)

	page._ask_reset()
	await process_frame
	bad = []
	_panel(page, page.reset_confirm, bad)
	var pair := [_rect(page.confirm_button), _rect(page.cancel_button)]
	if pair[0].size != pair[1].size or pair[0].position.x - 0 != 320 - pair[1].end.x:
		bad.append("CONFIRM / CANCEL not an even centred pair %s" % [pair])
	if _code == "en" and (page.reset_confirm.get_meta("panel_rect") != Rect2(24, 48, 272, 82) or pair[0] != Rect2(84, 108, 70, 13)):
		bad.append("English RESET panel moved: %s %s" % [page.reset_confirm.get_meta("panel_rect"), pair[0]])
	_check(bad.is_empty(), "%s: RESET panel %s" % [_code, "ok" if bad.is_empty() else str(bad)])
	page._cancel_reset()
	page.free()


## A modal panel: inside the screen's EDGE; its texts and buttons inside it, not over each other; the
## page under it hidden (but in English).
func _panel(page: Control, modal: Control, bad: Array[String]) -> void:
	var rect: Rect2 = modal.get_meta("panel_rect")
	if not SCREEN.grow(-UIKit.EDGE).encloses(rect):
		bad.append("panel %s outside the screen's edge" % rect)
	var items := _items(modal)
	for item: Dictionary in items:
		if not rect.encloses(item.box):
			bad.append("%s %s outside the panel %s" % [item.name, item.box, rect])
	_overlaps(page, modal, bad)
	for child in page.get_children():
		var control := child as Control
		if control == null or control is MenuBackdrop or control == page.code_panel or control == page.reset_confirm:
			continue
		var shown := control.visible and Rect2(control.position, control.size).intersects(rect)
		if _code != "en" and shown:
			bad.append("%s still shown under the panel" % control.name)


# ------------------------------------------------------------------ CONTROLS

func _keys() -> void:
	var page: Control = await _open("res://scenes/key_controls.tscn")
	var seen := {}
	var bad: Array[String] = []
	for p in page.pages:
		page.show_page(p)
		await process_frame
		var shown: Array[Rect2] = []
		for action: String in page.key_buttons:
			var button: Button = page.key_buttons[action]
			if button.is_visible_in_tree():
				seen[action] = seen.get(action, 0) + 1
				shown.append(_rect(button))
				var label := button.get_parent().get_child(button.get_index() - 1) as Label
				var text_w := UIKit.text_w(label.text)
				if text_w > label.size.x or _rect(label).end.x > _rect(button).position.x:
					bad.append("page %d: %s label %d wide in %d" % [p, action, text_w, label.size.x])
				if button.get_combined_minimum_size().x > button.size.x or button.size.y != UIKit.button_h():
					bad.append("page %d: %s key %s" % [p, action, button.size])
		var top := 999.0
		var bottom := 0.0
		var left := 999.0
		var right := 0.0
		for r in shown:
			top = minf(top, r.position.y)
			bottom = maxf(bottom, r.end.y)
			right = maxf(right, r.end.x)
		for grid: GridContainer in page.grids:
			if grid.visible:
				left = minf(left, grid.position.x)
		if left != 320 - right:
			bad.append("page %d: columns not centred (L%d R%d)" % [p, left, 320 - right])
		if top < UIKit.title_bottom() + UIKit.GAP_S:  # (GAP_M; GAP_S where that keeps the rows on one page)
			bad.append("page %d: rows start at %d, title ends %d" % [p, top, UIKit.title_bottom()])
		var note := _rect(page.note)
		# GAP_L over the bottom row; GAP_M only where the note is centred between the rows and the bottom row
		# (fix pass F3b: Vietnamese and pseudo, their marks over the last key's goo): as near to the rows' bottom
		# (its own marks counted) as to the bottom row. English pinned below (NOTE_GAP).
		var below := UIKit.bottom_row_y() - note.end.y
		var above := note.position.y - UIKit.mark_rows(page.note.text) - bottom
		var centred := below < UIKit.GAP_L and below >= UIKit.GAP_M and absf(above - below) <= 1.0
		if bottom + UIKit.GAP_M > note.position.y or (below < UIKit.GAP_L and not centred):
			bad.append("page %d: rows end %d, note %s (%d over the bottom row %d, %d under the rows)" % [p, bottom, note, below,
				UIKit.bottom_row_y(), above])
		if centred:
			_centred_notes[_code] = true
		var note_w := UIKit.text_w(page.note.text)
		if page.note_lines == 1 and note_w > 320 - 2 * UIKit.EDGE:
			bad.append("note %d wide on one line" % note_w)
		_overlaps(page, page, bad)
	for action: String in page.key_buttons:
		if seen.get(action, 0) != 1:
			bad.append("%s on %d pages" % [action, seen.get(action, 0)])
	var tall: bool = _code in ["th", "hi", "zh_TW"]
	if page.pages != (2 if tall or _code == "pseudo" else 1):
		bad.append("%d pages" % page.pages)
	if (page.page_button != null) != (page.pages > 1):
		bad.append("page button")
	if _code == "en" and (_rect(page.key_buttons.move_up) != Rect2(92, 30, 64, 13) or _rect(page.key_buttons.restart) != Rect2(252, 30, 64, 13) \
			or _rect(page.key_buttons.jump).position.y != 98 or _rect(page.note).position.y != 140 \
			or UIKit.bottom_row_y() - _rect(page.note).end.y != page.NOTE_GAP):
		bad.append("English CONTROLS moved: %s %s" % [_rect(page.key_buttons.move_up), _rect(page.note)])
	_check(bad.is_empty(), "%s: CONTROLS (%d page%s) %s" % [_code, page.pages, "" if page.pages == 1 else "s", "ok" if bad.is_empty() else str(bad)])
	page.free()


# ------------------------------------------------------------------ title / LANGUAGE

func _title() -> void:
	var page: Control = await _open("res://scenes/title.tscn")
	var bad: Array[String] = []
	var enter := _rect(page.enter_button)
	if enter.position.x != 320 - enter.end.x:
		bad.append("ENTER not centred %s" % enter)
	if page.enter_button.get_combined_minimum_size().x > enter.size.x or page.enter_button.get_combined_minimum_size().y > enter.size.y:
		bad.append("ENTER's text does not fit %s" % enter)
	var slimes: Array[float] = []
	for base in page._idle_base:  # (the resting spots; the slimes themselves hop)
		slimes.append(base.x)
	if slimes.size() != 2 or slimes[0] + slimes[1] != 320 or slimes[0] != enter.position.x - page.SLIME_OUT:
		bad.append("slimes %s not symmetric to ENTER %s" % [slimes, enter])
	var tagline: Label = null
	for child in page.get_children():
		if child is Label and child.get_theme_font_size("font_size") == UIKit.FONT_BIG:
			tagline = child
	var lines := tagline.text.count("\n") + 1
	var h := lines * tagline.get_theme_font("font").get_height(UIKit.FONT_BIG) + (lines - 1) * tagline.get_theme_constant("line_spacing")
	var top := _rect(tagline).position.y
	if top < enter.end.y or top + h > 180 or UIKit.text_w(tagline.text, UIKit.FONT_BIG) > 320 - 2 * UIKit.EDGE:
		bad.append("tagline %d..%d (%d lines), ENTER ends %d" % [top, top + h, lines, enter.end.y])
	# Each tagline line's ink (its width centred, the 16 px line + accents above / drips below) clear of
	# the slimes' ink and of STORY.
	var drips := 0 if UIKit.tall_script() else 2 * UIKit.TEXT_DRIP
	var line_h := tagline.get_theme_font("font").get_height(UIKit.FONT_BIG)
	var avoid: Array[Rect2] = [_rect(page.story_button)]
	for child in page.get_children():
		if child is AnimatedSprite2D:
			avoid.append(Rect2(child.position + page.SLIME_INK.position, page.SLIME_INK.size))
	var parts := tagline.text.split("\n")
	for i in parts.size():
		var w := UIKit.text_w(parts[i], UIKit.FONT_BIG)
		var y := top + i * (line_h + tagline.get_theme_constant("line_spacing"))
		var above := UIKit.ink_above(parts[i], UIKit.FONT_BIG)  # (accent room only over a line that has marks)
		var ink := Rect2(160 - w / 2.0, y - above, w, line_h + above + drips)
		for r in avoid:
			if ink.intersects(r):
				bad.append("tagline line %d %s over %s" % [i + 1, ink, r])
	var story := _rect(page.story_button)
	if story.end.y != UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H or story.position.x != UIKit.EDGE or page.story_button.get_combined_minimum_size().x > story.size.x:
		bad.append("STORY %s" % story)
	if _code == "en" and (enter != Rect2(72, 84, 176, 25) or top != 124 or story != Rect2(4, 164, 40, 13)):
		bad.append("English title moved: ENTER %s tagline %d STORY %s" % [enter, top, story])
	_check(bad.is_empty(), "%s: title %s" % [_code, "ok" if bad.is_empty() else str(bad)])
	page.free()


func _language_page() -> void:
	var page: Control = await _open("res://scenes/language.tscn")
	var bad: Array[String] = []
	var grid: Rect2 = page.grid
	var back := _rect(page.back_button)
	if grid.position.x != 320 - grid.end.x:
		bad.append("grid not centred %s" % grid)
	if grid.position.y < UIKit.title_bottom() + UIKit.GAP_XS or grid.end.y + UIKit.GAP_XS > back.position.y:
		bad.append("grid %s, title ends %d, BACK %s" % [grid, UIKit.title_bottom(), back])
	if back.end.y != UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H or back.size.y != UIKit.button_h():
		bad.append("BACK %s" % back)
	_overlaps(page, page, bad)
	_check(bad.is_empty(), "%s: LANGUAGE %s" % [_code, "ok" if bad.is_empty() else str(bad)])
	page.free()


# ------------------------------------------------------------------ measuring

func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


## Visible buttons / line boxes and the texts of labels under `root` (a label: its text's width centred
## or left in its rect, its lines' height), as {name, box, button}.
func _items(root_node: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node in _all(root_node):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is Button or control is LineEdit or control is PanelContainer:
			if control.get_parent() is Button:
				continue
			out.append({name = control.name, box = _rect(control), button = true, control = control})
		elif control is Label and control.text.strip_edges() != "" and not (control.get_parent() is Button) and not (control.get_parent() is HBoxContainer):
			var label := control as Label
			var font := label.get_theme_font("font")
			var size := label.get_theme_font_size("font_size")
			var lines := label.get_line_count() if label.autowrap_mode != TextServer.AUTOWRAP_OFF else label.text.count("\n") + 1
			var h := lines * font.get_height(size) + (lines - 1) * label.get_theme_constant("line_spacing")
			var w := 0.0
			for line in label.text.split("\n"):
				w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			var r := _rect(label)
			w = minf(w, r.size.x) if label.autowrap_mode != TextServer.AUTOWRAP_OFF else w
			var x := r.position.x + ((r.size.x - w) / 2.0 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
			var y := r.position.y
			if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
				y += (r.size.y - h) / 2.0
			elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
				y += r.size.y - h
			out.append({name = label.name, box = Rect2(x, y, w, h), button = false, control = control})
	return out


## No two of `root`'s items overlapping (texts' boxes, buttons, boxes) and every one inside the screen;
## the page's items under a panel are not counted when `root` is that panel.
func _overlaps(_page: Control, root_node: Control, bad: Array[String]) -> void:
	var items := _items(root_node)
	for i in items.size():
		var a: Dictionary = items[i]
		if not SCREEN.encloses(a.box.grow(-0.01)):
			bad.append("%s %s off screen" % [a.name, a.box])
		if a.button and (a.control.get_combined_minimum_size().x > a.box.size.x + 0.5 or a.control.get_combined_minimum_size().y > a.box.size.y + 0.5):
			bad.append("%s's text does not fit %s" % [a.name, a.box])
		for j in range(i + 1, items.size()):
			var b: Dictionary = items[j]
			if a.control.is_ancestor_of(b.control) or b.control.is_ancestor_of(a.control):
				continue
			if a.box.grow(-0.5).intersects(b.box.grow(-0.5)):
				bad.append("%s %s over %s %s" % [a.name, a.box, b.name, b.box])


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all(child))
	return out
