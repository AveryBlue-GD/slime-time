extends "res://tests/suite_base.gd"

## UIKit's per-locale sizes and fitting helpers (docs/ui-rules.md section 10, i18n chunk G0).
## - English (gate off, gate on, and Indonesian, whose metrics are English's): every per-locale size is
##   exactly today's constant (button 13, pod 14 / 23, title 2..22, bottom row 164, hit pad 5, line
##   spacing 5), and the shared widgets keep their English rects (BACK 40x13 at (4, 164), BUY? confirm
##   148x58 at (86, 60) with 48x13 buttons at (20, 36) / (80, 36)).
## - Every locale: a themed button / pod / volume box is exactly button_h() / pod_h() tall; BACK fits its
##   word (text + 2x4 px) and ends on row 176; the BUY? confirm's two buttons are equal, fit their words,
##   sit symmetric in a panel centred on the screen, under the price row; the title's line box fits its
##   box; the hit pad keeps a 23 px hit area.
## - the shared helpers (chunk G5): accent_room / digit_top / big_button_h per locale, plain_font only
##   with a script fallback, note_text_w / noted_text_w (a width the helpers give, an own text that would
##   not fit), checkbox_extra = Godot's CheckBox chrome, page arrows (names, places, plain font, state),
##   cover_behind / uncover, wrap_label;
## - fit_text: as is / grow (centred on a whole pixel) / wrap / smaller font (Devanagari 12) / no fit
##   (text never cut); tab_widths, stack_pages, grid_budget, row_budget arithmetic.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 60000 -s res://tests/test_ui_kit_locale.gd

const Lang := preload("res://scripts/language.gd")

var language: Node


func _initialize() -> void:
	await process_frame
	var progress := root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	_check(UIKit.locale() == "en", "gate off: UIKit.locale() is English")
	_english_numbers("gate off")
	await _widgets("gate off")
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in ["en"] + Lang.codes().slice(1) + [Lang.PSEUDO]:
		language.set_locale(code)
		_check(UIKit.locale() == code, "%s: UIKit follows the locale" % code)
		if Lang.metrics(code) == Lang.metrics("en"):
			_english_numbers(code)
		_sizes(code)
		await _widgets(code)
		await _shared_helpers(code)
	language.set_locale("en")
	_fit_helpers_latin()
	await _fit_text_cases()
	language.set_locale("hi")
	await _fit_smaller_hi()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_result()
	quit(1 if failures else 0)


func _english_numbers(tag: String) -> void:
	_check(UIKit.button_h() == UIKit.BUTTON_H and UIKit.tab_h() == UIKit.TAB_H and UIKit.pod_h() == UIKit.POD_H
		and UIKit.pod_h2() == UIKit.POD_H2 and UIKit.line_pitch() == UIKit.LINE_PITCH and UIKit.dense_pitch() == UIKit.DENSE_PITCH
		and UIKit.line_spacing() == UIKit.LINE_SPACING and UIKit.title_top() == UIKit.TITLE_Y and UIKit.title_bottom() == UIKit.TITLE_Y + 20
		and UIKit.bottom_row_y() == UIKit.BOTTOM_ROW_Y and UIKit.hit_pad() == UIKit.HIT_PAD and UIKit.choice_y() == UIKit.CHOICE_Y
		and UIKit.choice_size() == UIKit.CHOICE_SIZE and UIKit.back_size() == UIKit.BACK_SIZE and UIKit.stack_pitch() == 16
		and UIKit.button_v_margins() == Vector2i(3, 3) and UIKit.pod_v_margins() == Vector2i(3, 3),
		"%s: every per-locale size is today's English constant" % tag)


## Numbers that must hold in every locale.
func _sizes(code: String) -> void:
	var m: Dictionary = Lang.metrics(code)
	_check(UIKit.button_h() == m.button_h, "%s: button_h %d = metrics" % [code, UIKit.button_h()])
	_check(UIKit.button_h() + 2 * UIKit.hit_pad() >= UIKit.BUTTON_H + 2 * UIKit.HIT_PAD,
		"%s: hit area %d px tall (>= 23)" % [code, UIKit.button_h() + 2 * UIKit.hit_pad()])
	_check(UIKit.bottom_row_y() + UIKit.button_h() == UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H, "%s: the bottom row still ends on row 176" % code)
	_check(UIKit.title_top() >= UIKit.TITLE_Y + int(m.title_above) and UIKit.title_h() >= int(m.title_line_h) + (6 if int(m.title_line_h) <= 14 else 2),
		"%s: the title box (%d..%d) holds its marks above and its line" % [code, UIKit.title_top(), UIKit.title_bottom()])
	var bm := UIKit.button_v_margins()
	_check(bm.x + bm.y + UIKit.line_h() == UIKit.button_h() and bm.x >= 1 + int(m.ink_above),
		"%s: button margins %s give button_h with room for the marks above" % [code, bm])
	_check(UIKit.line_spacing() + UIKit.line_h() == UIKit.line_pitch(), "%s: label line spacing gives the line pitch" % code)


## The shared widgets, built in the current locale on a themed screen.
func _widgets(tag: String) -> void:
	var screen := Control.new()
	root.add_child(screen)
	UIKit.setup_screen(screen, Loc.t("settings.title", "SETTINGS"))
	var back := UIKit.add_back_button(screen, func() -> void: pass)
	var plain := UIKit.make_button("A", func() -> void: pass, Vector2(40, UIKit.BUTTON_H))
	screen.add_child(plain)
	var pod := PanelContainer.new()
	pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	var pod_row := HBoxContainer.new()
	pod.add_child(pod_row)
	pod_row.add_child(UIKit.make_icon("ticket"))
	pod_row.add_child(UIKit.make_label("88"))
	screen.add_child(pod)
	var volume := UIKit.make_volume_slider(40)
	screen.add_child(volume)
	var parts := UIKit.add_ticket_confirm(screen, func() -> void: pass, func() -> void: pass, UIKit.TEXT)
	(parts.panel as Control).visible = true
	(parts.label as Label).text = "88"
	(parts.price as Label).text = "40"
	for i in 3:
		await process_frame
	var bh := UIKit.button_h()
	_check(plain.get_combined_minimum_size().y == bh and plain.size.y == bh, "%s: a themed button is %d tall (%s)" % [tag, bh, plain.size])
	_check(pod.get_combined_minimum_size().y == UIKit.pod_h(), "%s: a one-line pod is %d tall (%s)" % [tag, UIKit.pod_h(), pod.get_combined_minimum_size()])
	_check(volume.get_combined_minimum_size().y == bh, "%s: the VOLUME box is %d tall (%s)" % [tag, bh, volume.get_combined_minimum_size()])
	# BACK: its word fits with 4 px a side, on the bottom row's slot, its minimum size within its size.
	var back_text_w := UIKit.text_w(back.text)
	var br := Rect2(back.position, back.size)
	_check((br.position.x == UIKit.EDGE or language.is_rtl()) and br.end.y == UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H and br.size.y == bh
		and br.size.x >= back_text_w + 8 and br.size.x >= UIKit.BACK_SIZE.x and back.get_combined_minimum_size().x <= br.size.x,
		"%s: BACK %s fits %s (%d px)" % [tag, br, back.text, back_text_w])
	if tag in ["gate off", "en", "id"]:
		_check(br == Rect2(4, 164, 40, 13), "%s: BACK is 40x13 at (4, 164)" % tag)
	# The BUY? confirm.
	var panel: Control = parts.panel
	var buy: Control = parts.buy
	var cancel: Control = parts.back
	var pr := Rect2(panel.position, panel.size)
	var left := buy.position.x
	var right := pr.size.x - (cancel.position.x + cancel.size.x)
	# (Arabic: positions are mirrored by Godot's RTL layout until chunk I; the sizes still count.)
	var rtl: bool = language.is_rtl()
	_check(buy.size == cancel.size and buy.size.y == bh and (rtl or (left == right and absf(pr.get_center().x - 160.0) <= 0.5
		and cancel.position.x - (buy.position.x + buy.size.x) == UIKit.GAP_XL)) and buy.position.y == cancel.position.y,
		"%s: BUY? buttons equal (%s), symmetric in the panel (L %d / R %d), panel %s centred" % [tag, buy.size, left, right, pr])
	for b: Button in [parts.buy, parts.back]:
		_check(UIKit.text_w(b.text) + 8 <= b.size.x and b.get_combined_minimum_size().x <= b.size.x,
			"%s: BUY? %s fits its %d px button" % [tag, b.text, b.size.x])
	var row: Control = (parts.price as Control).get_parent()
	_check(row.position.y - (parts.label as Control).position.y >= UIKit.line_pitch()
		and buy.position.y - row.position.y >= maxi(UIKit.line_pitch(), 8 + UIKit.TEXT_DRIP + 1) and buy.position.y + bh + 8 <= pr.size.y,
		"%s: BUY? rows in order: text, price, buttons, 8+ px above the panel's bottom" % tag)
	if tag in ["gate off", "en", "id"]:
		_check(pr == Rect2(86, 60, 148, 58) and buy.position == Vector2(20, 36) and cancel.position == Vector2(80, 36) and buy.size == Vector2(48, 13),
			"%s: BUY? confirm is today's 148x58 at (86, 60)" % tag)
	# The title.
	var title: Label = null
	for child in screen.get_children():
		if child is Label and child.get_theme_font_size("font_size") == UIKit.FONT_BIG:
			title = child
	if title:
		var line := title.get_theme_font("font").get_height(UIKit.FONT_BIG)
		_check(title.position.y == UIKit.title_top() and title.size.y == UIKit.title_h() and line + (6 if line <= 14 else 2) <= title.size.y + 0.5,
			"%s: title box y %d h %d holds its %d px line" % [tag, title.position.y, title.size.y, line])
	screen.free()


func _shared_helpers(code: String) -> void:
	var m: Dictionary = Lang.metrics(code)
	var tall: bool = int(m.line_h) > UIKit.TEXT_BODY
	_check(UIKit.accent_room() == (0 if tall else int(m.ink_above) - (1 if int(m.ink_above) > 0 else 0)) and UIKit.accent_room() == (0 if tall else UIKit.button_v_margins().x - 3),
		"%s: accent_room %d" % [code, UIKit.accent_room()])
	_check(UIKit.digit_top() == (roundf(UIKit.font_for().get_ascent(UIKit.FONT)) - UIKit.TEXT_BODY if tall else 0.0) and UIKit.digit_top() >= 0,
		"%s: digit_top %d" % [code, UIKit.digit_top()])
	_check(UIKit.big_button_h(25) == (maxi(25, int(m.title_line_h) + int(m.get("ink_nudge", 0))) if tall else 25), "%s: big_button_h" % code)
	var has_fallback := not (load(Lang.FONT_PATH) as Font).fallbacks.is_empty()
	var plain := UIKit.plain_font("0")
	_check((plain != null) == has_fallback and (plain == null or (plain.fallbacks.is_empty() and plain.get_height(UIKit.FONT) == UIKit.TEXT_BODY))
		and UIKit.plain_font("", UIKit.FONT, true) != null, "%s: plain_font only with a script fallback, 7 px tall" % code)
	var screen := Control.new()
	root.add_child(screen)
	UIKit.setup_screen(screen, "")
	var b := UIKit.make_button("ABCDEFGHIJKL", func() -> void: pass, Vector2(UIKit.button_w("ABCDEFGHIJKL", 40), UIKit.button_h()))
	screen.add_child(b)
	UIKit.note_text_w(b, ["AB", "ABCDEFGHIJKL"], 40)
	_check(UIKit.noted_text_w(b) == UIKit.text_w("ABCDEFGHIJKL") + 8, "%s: noted_text_w = the widest button_w of the noted texts" % code)
	b.text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	_check(UIKit.noted_text_w(b) == -1, "%s: noted_text_w -1 when the shown text would not fit" % code)
	var box := CheckBox.new()
	box.text = "HARD"
	screen.add_child(box)
	_check(int(box.get_combined_minimum_size().x) == UIKit.button_w(box.text, 0, UIKit.FONT, UIKit.checkbox_extra(box)),
		"%s: checkbox_extra matches the CheckBox's own width (%s)" % [code, box.get_combined_minimum_size()])
	var steps: Array[int] = []
	var arrows := UIKit.add_page_arrows(screen, func(step: int) -> void: steps.append(step), UIKit.title_arrows_y(), UIKit.EDGE, UIKit.SCREEN.x - UIKit.EDGE)
	arrows[0].pressed.emit()
	arrows[1].pressed.emit()
	UIKit.show_page_arrows(arrows, 0, 2)
	_check(arrows[0].name == "PagePrev" and arrows[1].name == "PageNext" and steps == [-1, 1] and arrows[0].position == Vector2(UIKit.EDGE, UIKit.title_arrows_y())
		and arrows[1].position.x + arrows[1].size.x == UIKit.SCREEN.x - UIKit.EDGE and arrows[0].size == Vector2(UIKit.PAGER_W, UIKit.button_h())
		and arrows[0].disabled and not arrows[1].disabled and (arrows[0].get_theme_font("font").fallbacks.is_empty()),
		"%s: page arrows (< > at the edges, steps -1 / 1, plain font, first page)" % code)
	var panel := Control.new()
	screen.add_child(panel)
	var hidden := UIKit.cover_behind(screen, [panel], Rect2(0, 0, 40, 40))
	_check(hidden.has(arrows[0]) and not hidden.has(arrows[1]) and not arrows[0].visible and arrows[1].visible and panel.visible,
		"%s: cover_behind hides only what is under the rect" % code)
	UIKit.uncover(hidden)
	_check(arrows[0].visible and hidden.is_empty(), "%s: uncover shows it again" % code)
	var label := UIKit.add_label(screen, "ABCDE FGHIJ KLMNO", Rect2(0, 100, 200, 7))
	UIKit.wrap_label(label, Vector2(40, UIKit.text_block_h(3)))
	_check(label.size == Vector2(40, UIKit.text_block_h(3)) and label.autowrap_mode == UIKit.autowrap_mode(), "%s: wrap_label sizes at once" % code)
	screen.free()
	await process_frame


func _fit_helpers_latin() -> void:
	_check(str(UIKit.tab_widths(["COINS", "TICKETS"], [40, 52])) == "[40, 52]", "tab_widths: English tabs keep their widths")
	var grown := UIKit.tab_widths(["MONEDAS", "BOLETOS"], [40, 52])
	_check(grown[0] == grown[1] and grown[0] >= UIKit.text_w("MONEDAS") + 8, "tab_widths: a grown group is equal (%s)" % [grown])
	_check(UIKit.row_budget(100, 13, 3) == 6 and UIKit.row_budget(15, 13, 3) == 1 and UIKit.row_budget(12, 13, 3) == 0, "row_budget")
	_check(UIKit.column_budget(304, 3, 8) == 96, "column_budget: 3 x 96 + 2 x 8 = 304")
	var g := UIKit.grid_budget(18, 3, 100, 21, 4)
	_check(g.rows == 6 and g.rows_per_page == 4 and g.pages == 2 and not g.fits and g.h == 96, "grid_budget pages a tall grid (%s)" % [g])
	_check(str(UIKit.stack_pages([13, 13, 13], 3, 45)) == "[[0, 1, 2]]" and str(UIKit.stack_pages([21, 21, 21], 3, 45)) == "[[0, 1], [2]]"
		and UIKit.stack_fits([13, 13, 13], 3, 45) and not UIKit.stack_fits([21, 21, 21], 3, 45), "stack_pages / stack_fits")
	_check(UIKit.content_rect() == Rect2(4, 26, 312, 134), "content_rect: (4, 26) 312x134 in English (%s)" % UIKit.content_rect())


func _fit_text_cases() -> void:
	var screen := Control.new()
	root.add_child(screen)
	UIKit.setup_screen(screen, "")
	# As is.
	var a := UIKit.make_button("BACK", func() -> void: pass, Vector2(40, 13))
	screen.add_child(a)
	var r := UIKit.fit_text(a, Rect2(100, 50, 40, 13), Vector2(80, 13))
	_check(r.fits and r.step == "as is" and a.size == Vector2(40, 13) and a.position == Vector2(100, 50), "fit_text: a fitting text stays (%s)" % [r])
	# Grow, centred on a whole pixel.
	var b := UIKit.make_button("ABCDEFGHIJ", func() -> void: pass, Vector2(40, 13))
	screen.add_child(b)
	r = UIKit.fit_text(b, Rect2(100, 50, 40, 13), Vector2(90, 13))
	var need := UIKit.text_w(b.text) + 8
	_check(r.fits and r.step == "grow" and b.size == Vector2(need, 13) and b.position.x == 100 - floorf((need - 40) / 2.0) and b.position.y == 50,
		"fit_text: grows to %d centred (%s at %s)" % [need, b.size, b.position])
	# Wrap: a label too wide for 60 px but two lines fit.
	var c := UIKit.add_label(screen, "ABCDE FGHIJ", Rect2(10, 10, 40, 7))
	r = UIKit.fit_text(c, Rect2(10, 10, 40, 7), Vector2(60, UIKit.text_block_h(2)), 2)
	_check(r.fits and r.step == "wrap" and r.lines == 2 and c.autowrap_mode != TextServer.AUTOWRAP_OFF and c.size.y == UIKit.text_block_h(2)
		and c.text == "ABCDE FGHIJ", "fit_text: wraps onto 2 lines (%s, %s)" % [r, c.size])
	_check(c.size == r.size and c.position == Vector2(10 - floorf((r.size.x - 40) / 2.0), 10 - floorf((r.size.y - 7) / 2.0)),
		"fit_text: the wrapped size holds in the same frame, no deferred resize (%s vs %s)" % [c.size, r.size])
	# No fit: nothing cut, fits false.
	var d := UIKit.add_label(screen, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", Rect2(10, 30, 40, 7))
	r = UIKit.fit_text(d, Rect2(10, 30, 40, 7), Vector2(60, 7), 1)
	_check(not r.fits and d.text == "ABCDEFGHIJKLMNOPQRSTUVWXYZ" and r.size.x <= 60, "fit_text: too long -> fits false, text kept (%s)" % [r])
	# A 16 px title steps down to the 8 px font.
	var e := UIKit.add_label(screen, "ABCDEFGHIJ", Rect2(0, 0, 70, 20), UIKit.FONT_BIG)
	r = UIKit.fit_text(e, Rect2(0, 0, 70, 20), Vector2(70, 20), 1)
	_check(r.fits and r.step == "smaller" and e.get_theme_font_size("font_size") == UIKit.FONT, "fit_text: a title too wide at 16 px uses 8 px (%s)" % [r])
	screen.free()


func _fit_smaller_hi() -> void:
	var screen := Control.new()
	root.add_child(screen)
	UIKit.setup_screen(screen, "")
	var text := "प्रगति मिटाओ प्रगति"
	var label := UIKit.add_label(screen, text, Rect2(0, 0, 10, UIKit.line_h()))
	var normal_w := UIKit.text_w(text)
	var small: Font = language.small_font("hi")
	var small_w := UIKit.text_w(text, UIKit.FONT, small)
	var r := UIKit.fit_text(label, Rect2(0, 0, small_w, UIKit.line_h()), Vector2.ZERO, 1)
	_check(small != null and small_w < normal_w and r.fits and r.step == "smaller" and label.get_theme_font("font") == small,
		"fit_text: Devanagari steps down to 12 px (%d -> %d px, %s)" % [normal_w, small_w, r])
	_check(small.get_height(UIKit.FONT) < UIKit.line_h(), "the 12 px Devanagari line (%d) is shorter than 14 px's (%d)" % [small.get_height(UIKit.FONT), UIKit.line_h()])
	_check(language.small_font("ar") == null and language.small_font("en") == null, "no smaller size where none is crisp (Arabic, the slimy font)")
	screen.free()
