extends "res://tests/suite_base.gd"

## The shared rules of the i18n fix pass F1 (docs/i18n/review/fixes-F1.md, docs/ui-rules.md 10.1 "No ink
## on the goo", "Script gap (CJK)", 10.2 signed numbers), in every locale:
## - every script's 8 px ink (Language METRICS ink_top .. ink_bottom, checked against every glyph of every
##   msgstr shaped with the installed fallback: bitmap bounds less their 1 px padding) lands, in a themed
##   button, from row GOO_INK_ROW 3 to row h - 2 (under the lump row, over the bottom band), and in a goo
##   panel (panel_style) from row 6 to row h - 4; Devanagari's trimmed line (17) holds all its ink;
## - a button sized from its text is text + 2 x BUTTON_TEXT_PAD (5) wide;
## - marks: has_mark / ink_above only for letters the slimy font draws with a mark;
## - Loc: the CJK script gap (U+2007, 1 px) after a slimy character before a CJK letter, only in ja / ko /
##   zh_CN / zh_TW; Arabic signed numbers written in a translation isolated (LRI .. PDI);
## - hub: the ticket pod is faded while the coin board is open (it sat on the board's frame), back after.
## The rendered check (glyph ink pixels in each goo box's band rows) is tools/i18n_capture.sh's goo-ink check.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_f1_marks.gd

const Report := preload("res://tests/i18n_report.gd")
const Lang := preload("res://scripts/language.gd")

var progress: Node
var language: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		language.set_locale(code)
		_margins(code)
		_script_ink(code)
		_loc(code)
	language.set_locale("en")
	_marks()
	await _coin_board()
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_result()
	quit(1 if failures else 0)


func _margins(code: String) -> void:
	var m := UIKit.metrics()
	var b := UIKit.button_v_margins()
	var bh := UIKit.button_h()
	_check(b.x + b.y + UIKit.line_h() == bh and b.x + int(m.ink_top) >= UIKit.GOO_INK_ROW and b.x + int(m.ink_bottom) <= bh - 2,
		"%s: button %d (%d / %d): ink rows %d .. %d between the lump row and the bottom band" % [code, bh, b.x, b.y,
		b.x + int(m.ink_top), b.x + int(m.ink_bottom)])
	var p := UIKit.panel_v_margins()
	var ph := p.x + UIKit.line_h() + p.y
	_check(p.x + int(m.ink_top) >= UIKit.PANEL_INK_TOP and p.x + int(m.ink_bottom) <= ph - UIKit.PANEL_INK_BOTTOM,
		"%s: goo panel line (%d / %d): ink rows %d .. %d of %d, clear of the band and lumps" % [code, p.x, p.y,
		p.x + int(m.ink_top), p.x + int(m.ink_bottom), ph])
	var style := UIKit.panel_style() as StyleBox
	_check(int(style.content_margin_top) == p.x and int(style.content_margin_bottom) == p.y, "%s: panel_style carries them" % code)
	_check(UIKit.panel_text_top() == maxi(UIKit.PANEL_PAD, p.x), "%s: panel_text_top %d" % [code, UIKit.panel_text_top()])
	if code == "en":
		_check(b == Vector2i(3, 3) and p == Vector2i(6, 5) and bh == 13 and UIKit.panel_text_top() == 8, "en: English margins unchanged")
	var text := "ABCDEFGHIJKLMNOP"
	_check(UIKit.button_w(text, 0) == UIKit.text_w(text) + 10 and UIKit.button_w("AB", 40) == 40,
		"%s: a text-sized button is text + 2 x 5" % code)


## Every glyph a translation draws in the current locale's fallback stays in METRICS ink_top .. ink_bottom.
func _script_ink(code: String) -> void:
	if not Lang.SCRIPT_FONTS.has(code):
		return
	var ts := TextServerManager.get_primary_interface()
	var font: Font = load(Lang.FONT_PATH)
	var ascent := font.get_ascent(UIKit.FONT)
	var slimy: RID = font.get_rids()[0]
	var top := 99
	var bottom := -99
	var ctx := ""
	for line in FileAccess.get_file_as_string("res://locale/%s.po" % code).split("\n"):
		if line.begins_with("msgctxt "):
			ctx = line
		if not line.begins_with("msgstr \"") or line.length() < 10 or ctx.begins_with("msgctxt \"web."):
			continue  # (web.*: the HTML shell draws those, not the game's fonts)
		var shaped := TextLine.new()
		shaped.add_string(line.substr(8, line.length() - 9).c_unescape(), font, UIKit.FONT)
		for g: Dictionary in ts.shaped_text_get_glyphs(shaped.get_rid()):
			if g.font_rid == RID() or g.font_rid == slimy or g.index == 0:
				continue
			var fixed: int = ts.font_get_fixed_size(g.font_rid)
			var size := Vector2i(fixed if fixed > 0 else UIKit.FONT, 0)
			var gs: Vector2 = ts.font_get_glyph_size(g.font_rid, size, g.index)
			if gs.y <= 2:
				continue
			var y0 := int(ascent + g.offset.y + ts.font_get_glyph_offset(g.font_rid, size, g.index).y) + 1
			top = mini(top, y0)
			bottom = maxi(bottom, y0 + int(gs.y) - 3)
	var m := UIKit.metrics()
	_check(top >= int(m.ink_top) and bottom <= int(m.ink_bottom) and bottom < UIKit.line_h(),
		"%s: the script's ink rows %d .. %d within METRICS %d .. %d and its %d px line" % [code, top, bottom, m.ink_top, m.ink_bottom, UIKit.line_h()])


func _loc(code: String) -> void:
	var cjk := code in ["ja", "ko", "zh_CN", "zh_TW"]
	_check(Loc.cjk_gap == cjk, "%s: script gap %s" % [code, "on" if cjk else "off"])
	_check(Loc.space_scripts("第1关 F转 10%券 A。") == "第1 关 F 转 10% 券 A。", "%s: space_scripts after a slimy character before a CJK letter only" % code)
	var shown := Loc.fill(Loc.t("x.test", "LEVEL {n}"), {n = 1})
	_check(not shown.contains(Loc.SCRIPT_GAP), "%s: no gap in a text without CJK" % code)
	if cjk:
		var w := UIKit.text_w("1 ") - UIKit.text_w("1")
		_check(w == 1 and (load(Lang.FONT_BIG_PATH) as Font).get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x == 2,
			"%s: the gap is 1 px (2 px at 16)" % code)
	_check(Loc.isolate_ltr == (code == "ar"), "%s: signed-number isolates only in Arabic" % code)
	var iso := Loc.isolate_signed("خزان +15% و (+0) و 10% {n}% +{n} X1.5")
	_check(iso == "خزان \u2066+15%\u2069 و (\u2066+0\u2069) و \u206610%\u2069 {n}% +{n} X1.5", "%s: isolate_signed %s" % [code, iso.c_escape()])


func _marks() -> void:
	var marked := true
	for c in "ÁÜÉÑÖİЙẪỔ":
		marked = marked and UIKit.has_mark(c.unicode_at(0))
	var plain := true
	for c in "AÇŞĐŁМЕШОКСЛЕДЫ":
		plain = plain and not UIKit.has_mark(c.unicode_at(0))
	_check(marked and plain, "has_mark: accented capitals yes, unmarked letters (Cyrillic, cedillas, bars) no")
	language.set_locale("ru")
	_check(UIKit.ink_above("МЕШОК МОНЕТ") == 0 and UIKit.ink_above("НАСТРОЙКИ") == 3, "ru: ink_above only for a line with a mark")
	language.set_locale("en")


func _coin_board() -> void:
	for code: String in ["en", "ar"]:
		language.set_locale(code)
		var hub: Node = load("res://scenes/hub.tscn").instantiate()
		root.add_child(hub)
		for i in 3:
			await process_frame
		hub.open_coin_board()
		await process_frame
		_check(hub.ticket_pod.modulate.a == 0.0, "%s: the ticket pod is faded while the coin board is open" % code)
		hub.close_coin_board()
		_check(hub.ticket_pod.modulate.a == 1.0 and hub.ticket_pod.visible, "%s: and back when it closes" % code)
		hub.free()
		await process_frame
