class_name UIKit
extends RefCounted

## Shared look and helpers for the menu screens (320x180 base resolution, 8 px text).

## The title screen (the main scene), and the hub every BACK leads to.
const TITLE_SCENE := "res://scenes/title.tscn"
const HUB_SCENE := "res://scenes/hub.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

const BG := Color8(26, 28, 44)
const BUTTON := Color8(51, 44, 64)
const BUTTON_PRESSED := Color8(37, 113, 121)
const TEXT := Color8(244, 244, 244)
const TEXT_DIM := Color8(148, 176, 194)
const TEXT_OFF := Color8(86, 108, 134)
const GOLD := Color8(255, 205, 117)
## Space between lines of text (the 2 px drips below each line + a 3 px gap).
const LINE_SPACING := 5

# ---- Layout rules (docs/ui-rules.md). Base pixels at 320x180; use these instead of literals. ----
const SCREEN := Vector2(320, 180)
## Menu chrome (BACK, tabs, corner buttons, balance pods) sits this far from the screen edges.
const EDGE := 4
## In-level HUD pods and the hub's ticket pod sit this far from the edges (HUD.POD_MARGIN); on a phone whose
## safe area cuts into the view (rounded corners, a notch without bars) further in: see hud_edge.
const HUD_EDGE := 3
## Top of the bottom-row buttons (BACK bottom left, the page's own action bottom right): 13 tall, B = 3.
const BOTTOM_ROW_Y := 164
## Screen titles (16 px font): the line box (0, TITLE_Y)..(320, TITLE_Y + 20).
const TITLE_Y := 2
## Font sizes: text and titles (titles use pixel_big.fnt, see use_big_font).
const FONT := 8
const FONT_BIG := 16
## The 8 px font's letter body and the drips that hang below it (the 16 px font doubles both).
const TEXT_BODY := 7
const TEXT_DRIP := 2
## Line pitch of multi-line text (7 + LINE_SPACING); dense lists (coin board, map tiles) use 11.
const LINE_PITCH := 12
const DENSE_PITCH := 11
## The spacing scale: every gap is one of these.
const GAP_XS := 2  # dense tiles, header items, stacked HUD pods
const GAP_S := 3   # stacked menu buttons (pitch 16), tile grids
const GAP_M := 4   # toggles, tabs, button to box, controls inside one row
const GAP_L := 8   # result choice row, columns, panel side insets
const GAP_XL := 12  # paired confirm buttons, text line pitch
## Component sizes.
const BUTTON_H := 13
const BACK_SIZE := Vector2(40, BUTTON_H)
const CHOICE_SIZE := Vector2(84, BUTTON_H)  # the result / summary choice row...
const CHOICE_GAP := GAP_L             # ...its gap...
const CHOICE_Y := 153                 # ...and its top (also the Descent card's buttons)
const TAB_H := 13
## HUD and hub pods: one line (an 8 px icon sets it) and two lines.
const POD_H := 14
const POD_H2 := 23
## Inside a goo panel: content (text top, first button) starts PANEL_PAD below the panel's top
## edge, and the last button's bottom edge (or the last text line's drips) ends PANEL_PAD above its
## bottom edge, clear of the goo lumps and the buttons' own drops.
const PANEL_PAD := 8
## Touch: a target should be TOUCH_MIN px tall and wide (44 pt at about 2 pt per game px on phones).
## While touch is in use (UIKit.touch_active), a TouchButton's hit area grows by HIT_PAD on every side (13 -> 23), shared
## with its neighbors by distance so hit areas never overlap (see TouchButton).
const TOUCH_MIN := 22
const HIT_PAD := 5
## The group of every control a touch can land on (TouchButtons and the other inputs on screen).
const TOUCH_GROUP := "ui_touch_targets"
## Pixel-art UI pieces from tools/make_ui_art.py.
const UI_DIR := "res://assets/ui/"
## Room each side of a button's text when the button is sized from its text (button_w): text + 2x this.
## 5, one more than the style's 4 px content margin: the slimy letters keep their 1 px gap on the left
## only and the shadow falls right, so at text + 2 x 4 the last letter's shadow sat on the right goo lump
## column (MONEDAS, MÜNZEN, VOLTAR, BOUTIQUE, TOURNER  GRATUIT); now 3 clear columns left, 2 right.
const BUTTON_TEXT_PAD := 5
## The Language autoload's script (its static tables: metrics, fonts).
const Lang := preload("res://scripts/language.gd")

## True while the player is using touch: the last pointer event was a screen touch or drag (or the
## mouse event Godot makes from one); a real mouse turns it off. See note_pointer / touch_active.
static var touch_in_use := false
static var _text_material: ShaderMaterial
static var _clean_big_material: ShaderMaterial
static var _tabular_font: FontFile
static var _drip_scene := -1
static var _metrics_code := ""
static var _metrics: Dictionary = {}
## has_mark's cache (code -> bool) and the slimy font's i18n page (pixel_ext.png), whose glyphs have
## EXT_MARK_ROWS rows of marks above the letter.
static var _marked := {}
static var _ext_page: Image
const EXT_MARK_ROWS := 5


# ---- Per-locale sizes (docs/ui-rules.md section 10). The constants above are the English (and
# Indonesian, and gate-off) numbers; every size that follows the text's height comes from these
# functions, which read Language.metrics(current locale) and return exactly the constant for English.

## The locale whose text is on screen ("en" with the gate off or without the Language autoload).
static func locale() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var language: Node = tree.root.get_node_or_null("Language") if tree else null
	if language == null or not language.get("active"):
		return Lang.SOURCE_LOCALE
	return language.get("locale")


## Language.metrics(locale()): line_h, ink_above, ink_below, line_pitch, dense_pitch, button_h,
## title_line_h, title_above, ink_nudge, font_px, font_big_px.
static func metrics() -> Dictionary:
	var code := locale()
	if code != _metrics_code or _metrics.is_empty():
		_metrics_code = code
		_metrics = Lang.metrics(code)
	return _metrics


## True when the current script's line box is taller than the slimy font's 7 px body (CJK, Thai,
## Devanagari, Arabic): its buttons, pods and lines grow, and stacked layouts may need two pages.
static func tall_script() -> bool:
	return int(metrics().line_h) > TEXT_BODY


## One line's box (7 for the slimy font; marks above it and drips below are drawn outside it).
static func line_h() -> int:
	return int(metrics().line_h)


## Pitch of stacked one-line labels (LINE_PITCH in English).
static func line_pitch() -> int:
	return int(metrics().line_pitch)


## Pitch of dense lists (DENSE_PITCH in English: coin board, map tiles).
static func dense_pitch() -> int:
	return int(metrics().dense_pitch)


## The Label line_spacing that gives multi-line labels line_pitch() (LINE_SPACING in English).
static func line_spacing() -> int:
	return line_pitch() - line_h()


## Height of `lines` lines of 8 px text as a Label lays them out (the line boxes and the spacing
## between them; drips / marks hang outside): 7 for one English line, 19 for two.
static func text_block_h(lines: int) -> int:
	return lines * line_h() + maxi(lines - 1, 0) * line_spacing()


## The standard button height (BUTTON_H in English; 16 with accents, 18 Vietnamese, 16 CJK, 18 zh_TW,
## 19 Thai, 22 Arabic and Devanagari). The theme's button margins make every button at least this tall.
static func button_h() -> int:
	var m := metrics()
	# (a taller script's line starts on row GOO_INK_ROW - ink_top, clear of the goo: Devanagari 3 + 17; under
	# its last ink row (Language ink_bottom) 1 clear row and the bottom border, BOTTOM_INK_ROOM, as under
	# English's drips: the rows its line box lacks for that are added, Devanagari's trimmed line + 2 = 22 (fix
	# pass R2), Arabic's lowest dots (ink row 17 of 19) + 1 = 22 (they sat on the row over the border at 21))
	var room := 0
	if int(m.line_h) > TEXT_BODY:
		room = int(m.line_h) + maxi(0, GOO_INK_ROW - int(m.get("ink_top", 0))) + bottom_ink_room()
	return maxi(BUTTON_H, maxi(int(m.button_h), room))


## Rows a taller script's button adds under its line box so its last ink (Language ink_bottom) keeps
## BOTTOM_INK_ROOM (1 clear row, the bottom border) under it: Devanagari 2, Arabic 1, others 0.
static func bottom_ink_room() -> int:
	var m := metrics()
	return maxi(0, int(m.get("ink_bottom", 0)) + 1 + BOTTOM_INK_ROOM - int(m.line_h))


## How much taller than in English a button / pod / tab is in the current locale.
static func grow_h() -> int:
	return button_h() - BUTTON_H


## Tab height (TAB_H in English).
static func tab_h() -> int:
	return TAB_H + grow_h()


## One-line pod height (POD_H in English); two-line pods: pod_h2.
static func pod_h() -> int:
	return POD_H + grow_h()


static func pod_h2() -> int:
	return pod_h() + line_pitch() - (POD_H + LINE_PITCH - POD_H2)


## Top of the bottom-row buttons: they keep their bottom edge (row 176) whatever their height.
static func bottom_row_y() -> int:
	return BOTTOM_ROW_Y + BUTTON_H - button_h()


## The result / summary choice row's size and top (same bottom edge as in English).
static func choice_size() -> Vector2:
	return Vector2(CHOICE_SIZE.x, button_h())


static func choice_y() -> int:
	return CHOICE_Y + BUTTON_H - button_h()


## Pitch of a stack of buttons `gap` apart (16 in English with GAP_S).
static func stack_pitch(gap := GAP_S) -> int:
	return button_h() + gap


## IMP3-04: the gap of a stack of menu buttons: GAP_S, or while touch is in use the one that makes the pitch TOUCH_MIN
## (22 px: a thumb's width; 9 px between 13 px buttons in English). Built at layout time, so a menu opened after a tap has it.
static func menu_gap() -> int:
	return maxi(GAP_S, TOUCH_MIN - button_h()) if touch_active() else GAP_S


## The title's line box: top (TITLE_Y in English, lower by the accents' head room), height (20 in
## English: 14 body + 4 drips + 2 shadow; a taller script's title: its line box + the 2 px shadow, its
## glyphs have no drips and the box holds their descent) and bottom (22 in English: where a page's
## content may start).
static func title_top() -> int:
	return TITLE_Y + int(metrics().title_above)


static func title_h() -> int:
	var line := int(metrics().title_line_h)
	return 20 if line <= 14 else line + 2


static func title_bottom() -> int:
	return title_top() + title_h()


## How far a TouchButton's hit area grows on each side while touch is in use: HIT_PAD in English
## (13 -> 23 px); a taller button grows less, so its hit area is still 23 px (at least 1 px more).
static func hit_pad() -> int:
	return maxi(1, ceili((BUTTON_H + 2 * HIT_PAD - button_h()) / 2.0))


## The theme's top / bottom content margins for buttons (x = top, y = bottom): a button's minimum
## height is its line box plus these, so they make it exactly button_h(). English 3 / 3. With the
## slimy font the 3 rows under the body stay (drips) and the accents' rows go on top; a taller
## script's line box (which has its own empty rows) gets 1 / 1, moved down by its ink_nudge, and never
## less on top than puts its highest ink (Language ink_top) on row GOO_INK_ROW, under the goo's lump row
## (Devanagari: 3 / 2, its matras ink the line box's first row and its lowest marks the last; Arabic 2 / 1:
## 22 px keeps 1 clear row under the lowest marks / dots over the bottom border, as under English's drips).
static func button_v_margins() -> Vector2i:
	var margins := _v_margins(button_h(), line_h())
	if tall_script():
		var top := clampi(GOO_INK_ROW - int(metrics().get("ink_top", 0)), margins.x, button_h() - line_h())
		margins = Vector2i(top, button_h() - line_h() - top)
	return margins


## The same for the HUD / hub pods (an 8 px icon or a line, POD_H tall in English: 3 / 3).
static func pod_v_margins() -> Vector2i:
	return _v_margins(pod_h(), maxi(8, line_h()))


static func _v_margins(total: int, content: int) -> Vector2i:
	var extra := total - content
	if line_h() <= TEXT_BODY:
		return Vector2i(extra - 3, 3)
	# (a negative content margin means "the style's default" to Godot: the nudge stops at 0 below)
	var top := mini(extra, extra / 2 + int(metrics().get("ink_nudge", 0)))
	return Vector2i(top, extra - top)


## The first row a button's text may ink (row 0 = its outline, 1 the goo band, 2 the lumps): English
## capitals start here; marks and taller scripts' letters too (button_v_margins).
const GOO_INK_ROW := 3
## Rows a button keeps under its text's last ink: 1 clear row, then the bottom border (h - 1), as under
## English's drips (BACK: drips on row 10 of 13). A script's last ink row is at most h - 1 - BOTTOM_INK_ROOM.
const BOTTOM_INK_ROOM := 2
## A goo panel's (panel_style) first and last text rows: 6 (clear of the band and its lumps, rows 0-4, by
## one row) and h - PANEL_INK_BOTTOM (the drips end over the bottom band's lumps, as in English).
const PANEL_INK_TOP := 6
const PANEL_INK_BOTTOM := 4


## Where the first line of 8 px text goes in a hand-laid goo panel (add_panel + labels): PANEL_PAD
## below its top edge, or lower when the locale's marks would reach the band (panel_v_margins: 9
## accented, 11 Vietnamese). English 8. The panel grows by the difference.
static func panel_text_top() -> int:
	return maxi(PANEL_PAD, panel_v_margins().x)


## A goo panel's top / bottom content margins for one line of 8 px text in the current locale (x =
## top, y = bottom): its highest ink (marks: Language ink_top) on row PANEL_INK_TOP, its lowest
## (drips, descending marks) on row h - PANEL_INK_BOTTOM. English 6 / 5; accented 9 / 5; Vietnamese
## 11 / 5; CJK 3 / 2, Traditional Chinese 3 / 1, Thai 5 / 1, Devanagari 6 / 3, Arabic 5 / 2. With `text`
## (the line the panel will show), the slimy font's top is only as high as that line's marks need.
static func panel_v_margins(text: Variant = null) -> Vector2i:
	var m := metrics()
	var top := PANEL_INK_TOP - int(m.get("ink_top", 0))
	if text != null and not tall_script():  # (only the marks `text` has: English's 6 for a line without any)
		top = PANEL_INK_TOP + ink_above(String(text))
	var bottom := int(m.get("ink_bottom", TEXT_BODY + TEXT_DRIP - 1)) + PANEL_INK_BOTTOM - line_h()
	return Vector2i(maxi(0, top), maxi(0, bottom))


# ---- Measuring and fitting text (docs/ui-rules.md section 10) ----

## The font a Label / Button of `font_size` uses (pixel.fnt, or pixel_big.fnt for FONT_BIG), with
## the current locale's script fallback on it.
static func font_for(font_size := FONT) -> Font:
	return load(Lang.FONT_BIG_PATH if font_size == FONT_BIG else Lang.FONT_PATH)


## Width of the widest line of `text` (whole pixels, rounded up), in `font` (default: font_for(size)).
## The slimy font alone (no script fallback: English, Latin, Cyrillic) is a BMFont without kerning, so
## its widths are summed glyph advances: no shaped-text buffer is made, so measuring allocates no
## RenderingServer / TextServer ids (GooBox seeds each box's lumps from its canvas item id; an extra
## id would move every later button's lumps, and English must stay pixel-identical).
static func text_w(text: String, font_size := FONT, font: Font = null) -> int:
	var f := font if font else font_for(font_size)
	var widest := 0.0
	var plain := f.fallbacks.is_empty() and f is FontFile
	for line in text.split("\n"):
		var w := 0.0
		if plain:
			for i in line.length():
				if not is_format_char(line.unicode_at(i)):  # (bidi isolates draw nothing)
					w += f.get_char_size(line.unicode_at(i), font_size).x
		else:
			w = f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widest = maxf(widest, w)
	return ceili(widest)


## A button's width for `text`: `min_w`, or the text plus BUTTON_TEXT_PAD on each side when that is
## wider (so the text is centred on a whole pixel). English texts keep their min_w.
static func button_w(text: String, min_w: int, font_size := FONT, extra := 0) -> int:
	return maxi(min_w, text_w(text, font_size) + 2 * BUTTON_TEXT_PAD + extra)


## A one-line button's size for `text` (button_w x button_h).
static func button_size(text: String, min_w: int, font_size := FONT) -> Vector2:
	return Vector2(button_w(text, min_w, font_size), button_h())


## BACK's size: BACK_SIZE in English, wider for a longer word (VOLTAR, ZURÜCK...), button_h() tall.
static func back_size(text := "") -> Vector2:
	return button_size(text if text != "" else Loc.t("common.back", "BACK"), int(BACK_SIZE.x))


## Widths for a group of tabs (or any one-of-many row) from their measured texts: each at least its
## English width (`min_widths`, one per tab, or one int for all). When any text needs more and
## `equal` is on, every tab takes the widest width, so the row stays symmetric. English: unchanged.
static func tab_widths(texts: Array, min_widths: Variant = 40, equal := true) -> Array[int]:
	var out: Array[int] = []
	var grew := false
	for i in texts.size():
		var min_w: int = min_widths[i] if min_widths is Array else int(min_widths)
		var w := button_w(String(texts[i]), min_w)
		grew = grew or w > min_w
		out.append(w)
	if equal and grew:
		var widest: int = out.max()
		for i in out.size():
			out[i] = widest
	return out


## Lays `controls` out in a row `gap` apart, sized `widths` x tab_h(), starting at x `from`
## (align -1), ending at `from` (align 1), or centred on `from` (align 0). Returns the row's rect.
static func layout_row(controls: Array, widths: Array, from: float, y: float, gap := GAP_M, align := -1) -> Rect2:
	if not controls.is_empty():
		relayout(controls[0])  # (right-to-left: placed in LTR coordinates, mirrored at the frame's end)
	var total := 0
	for w: int in widths:
		total += w
	total += gap * maxi(controls.size() - 1, 0)
	var x := from if align < 0 else (from - total if align > 0 else from - roundf(total / 2.0))
	var h := tab_h()
	for i in controls.size():
		var control: Control = controls[i]
		control.custom_minimum_size = Vector2(widths[i], h)
		control.size = control.custom_minimum_size
		control.position = Vector2(x, y)
		x += widths[i] + gap
	return Rect2(from if align < 0 else x - gap - total, y, total, h)


## Lines `text` takes when wrapped to `width` px in `font` at `font_size` (break at spaces, U+200B,
## or anywhere for Chinese / Japanese, which have no spaces).
static func wrapped_lines(text: String, width: float, font_size := FONT, font: Font = null) -> int:
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, font if font else font_for(font_size), font_size)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | _wrap_break_flag()
	return paragraph.get_line_count()


## The autowrap mode for the current locale: arbitrary for Chinese / Japanese (no spaces), word
## otherwise (Thai translations carry U+200B between words).
static func autowrap_mode() -> TextServer.AutowrapMode:
	return TextServer.AUTOWRAP_ARBITRARY if locale() in ["zh_CN", "zh_TW", "ja"] else TextServer.AUTOWRAP_WORD_SMART


static func _wrap_break_flag() -> int:
	return TextServer.BREAK_GRAPHEME_BOUND if autowrap_mode() == TextServer.AUTOWRAP_ARBITRARY else TextServer.BREAK_WORD_BOUND


## Fits a Label's or Button's text into `box` (its designed rect, in its parent), in this order (never
## truncating, never scaling by a fraction; docs/ui-rules.md section 10):
## 1. as it is, if it fits the box;
## 2. a wider / taller box, up to `max_size` (a 0 component = the box's), growing from its `anchor`
##    (x: -1 keeps the left edge, 0 the centre (an odd growth shifts the box by the lower half, so it
##    stays on whole pixels), 1 the right edge; y the same for top / middle / bottom);
## 3. wrapped onto up to `max_lines` lines, if `max_size` holds them (word breaks; anywhere for Chinese
##    / Japanese; Thai at its U+200B);
## 4. the same font one crisp size down: a 16 px title in the 8 px font, or a script's smaller size
##    where one exists (Language.SMALLER_FONT_PX: Devanagari 14 -> 12), again growing / wrapping.
## Places the control (position and size). Returns {fits, step ("as is", "grow", "wrap", "smaller"),
## size, lines, font_size, wrap}. When nothing fits, fits is false and the text is never cut (the box
## is the largest allowed; a Label may still widen itself to its text): switch that screen to a
## two-page or scrolling layout (stack_pages / grid_budget). Call it once the control is in the themed
## tree (it measures with the control's own font, size, margins and line spacing), after any font /
## line-spacing override and before anything is placed from its size: the wrap and the new size take
## effect at once, in the same frame (no deferred second resize).
static func fit_text(control: Control, box: Rect2, max_size := Vector2.ZERO, max_lines := 2, anchor := Vector2i(0, 0)) -> Dictionary:
	var text: String = control.get("text")
	var start := box.size
	var limit := Vector2(start.x if max_size.x <= 0 else maxf(max_size.x, start.x), start.y if max_size.y <= 0 else maxf(max_size.y, start.y))
	var pad := _text_pads(control)
	var font_size: int = control.get_theme_font_size("font_size")
	var font: Font = control.get_theme_font("font")
	var result := _try_fit(control, text, font, font_size, start, limit, pad, max_lines)
	if not result.fits:
		var smaller := _smaller_font(font_size)
		if not smaller.is_empty():
			var tried := _try_fit(control, text, smaller.font, smaller.size, start, limit, pad, max_lines)
			if tried.fits:
				control.add_theme_font_override("font", smaller.font)
				control.add_theme_font_size_override("font_size", smaller.size)
				tried.step = "smaller"
				result = tried
	_apply_fit(control, result, box, anchor)
	return result


## {font, size} one crisp step down from `font_size` in the current locale, or {} if none.
static func _smaller_font(font_size: int) -> Dictionary:
	if font_size == FONT_BIG:
		return {font = font_for(FONT), size = FONT}
	var tree := Engine.get_main_loop() as SceneTree
	var language: Node = tree.root.get_node_or_null("Language") if tree else null
	if font_size == FONT and language and language.has_method("small_font"):
		var small: Font = language.small_font(locale())
		if small:
			return {font = small, size = FONT}
	return {}


## The room a control's box keeps around its text (x = left + right, y = top + bottom).
static func _text_pads(control: Control) -> Vector2:
	var style: StyleBox = control.get_theme_stylebox("normal")
	if style == null:
		return Vector2.ZERO
	return Vector2(style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT), style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))


static func _try_fit(control: Control, text: String, font: Font, font_size: int, start: Vector2, limit: Vector2,
		pad: Vector2, max_lines: int) -> Dictionary:
	var lines := text.count("\n") + 1
	var spacing: int = control.get_theme_constant("line_spacing") if control is Label else 0
	var line := font.get_height(font_size)
	var one_w := float(text_w(text, font_size, font))
	var need := Vector2(ceilf(one_w + pad.x), ceilf(lines * line + (lines - 1) * spacing + pad.y))
	var out := {fits = false, step = "as is", size = start, lines = lines, font_size = font_size, wrap = false}
	if need.x <= start.x and need.y <= start.y:
		out.fits = true
		return out
	if need.x <= limit.x and need.y <= limit.y:
		out.fits = true
		out.step = "grow"
		out.size = Vector2(maxf(start.x, need.x), maxf(start.y, need.y))
		return out
	# Wrap: the widest box allowed, as few lines as fit.
	if max_lines > lines and limit.x - pad.x > 0:
		var wrapped := wrapped_lines(text, limit.x - pad.x, font_size, font)
		var wrap_h := ceilf(wrapped * line + (wrapped - 1) * spacing + pad.y)
		if wrapped <= max_lines and wrap_h <= limit.y:
			out.fits = true
			out.step = "wrap"
			out.wrap = true
			out.lines = wrapped
			out.size = Vector2(maxf(start.x, minf(limit.x, need.x)), maxf(start.y, wrap_h))
			return out
	out.size = Vector2(minf(limit.x, maxf(start.x, need.x)), minf(limit.y, maxf(start.y, need.y)))
	return out


static func _apply_fit(control: Control, fit: Dictionary, box: Rect2, anchor: Vector2i) -> void:
	relayout(control)  # (right-to-left: placed in LTR coordinates, mirrored at the frame's end)
	if fit.wrap:
		if control is Label:
			(control as Label).autowrap_mode = autowrap_mode()
		elif control is Button:
			(control as Button).autowrap_mode = autowrap_mode()
		# (Godot does not refresh a Label's / Button's minimum size when only its autowrap changes: it
		# would still be the one-line width this frame and clamp the size below; refresh it now)
		control.update_minimum_size()
	var size: Vector2 = fit.size
	var grow := size - box.size
	var pos := box.position + Vector2(_anchor_shift(grow.x, anchor.x), _anchor_shift(grow.y, anchor.y))
	if control is Button:
		control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, size.x) if grow.x > 0 else minf(control.custom_minimum_size.x, size.x),
			maxf(control.custom_minimum_size.y, size.y) if grow.y > 0 else minf(control.custom_minimum_size.y, size.y))
	control.position = pos
	control.size = size


static func _anchor_shift(grow: float, anchor: int) -> float:
	if anchor < 0 or grow <= 0:
		return 0.0
	return -grow if anchor > 0 else -floorf(grow / 2.0)


# ---- Shared per-locale helpers (chunk G5: one copy of what the screen chunks G1-G4 each wrote) ----

## Meta key of note_text_w.
const TEXT_W_META := "ui_text_w"
## Page arrows' width (< / > beside a title or a row).
const PAGER_W := 20
## Fallback-free copies of the slimy fonts, by path, weakly held (see plain_font).
static var _plain_fonts := {}


## Records that `control`'s width comes from button_w(text, min_w, font_size, extra) over `texts`: its
## own text alone, an equal-width group's texts (tab_widths), or every text it can show (a key button
## sized for PRESS KEY). Changes nothing on screen; tests/test_i18n_screens.gd recomputes noted_text_w
## and accepts a button wider than in English when it is exactly that wide (never by node name).
static func note_text_w(control: Control, texts: Array, min_w: int, font_size := FONT, extra := 0) -> void:
	var strings := PackedStringArray()
	for text: Variant in texts:
		strings.append(String(text))
	control.set_meta(TEXT_W_META, {texts = strings, min_w = min_w, font_size = font_size, extra = extra})


## The width the sizing helpers give `control` now, from its note_text_w note (in the current locale):
## the widest button_w of the noted texts. -1 without a note, or when the control's own text would not
## fit that width.
static func noted_text_w(control: Control) -> int:
	if not control.has_meta(TEXT_W_META):
		return -1
	var note: Dictionary = control.get_meta(TEXT_W_META)
	var w := 0
	for text: String in note.texts:
		w = maxi(w, button_w(text, note.min_w, note.font_size, note.extra))
	if button_w(String(control.get("text")), note.min_w, note.font_size, note.extra) > w:
		return -1
	return w


## A CheckBox's width past its text, as button_w's `extra` (note_text_w(box, [text], 0, FONT,
## checkbox_extra(box))): Godot reserves the widest of all its check / radio icons (the default
## theme's 16 px radio icons, not our 9 px box) plus the theme's 4 px separation (no style margins).
static func checkbox_extra(box: CheckBox) -> int:
	var icon_w := 0
	for icon_name: String in ["checked", "unchecked", "radio_checked", "radio_unchecked", "checked_disabled",
			"unchecked_disabled", "radio_checked_disabled", "radio_unchecked_disabled"]:
		var icon := box.get_theme_icon(icon_name)
		if icon:
			icon_w = maxi(icon_w, icon.get_width())
	var style := box.get_theme_stylebox("normal")
	var margins := int(style.get_minimum_size().x) if style else 0
	return icon_w + box.get_theme_constant("h_separation") + margins - 2 * BUTTON_TEXT_PAD


## Puts a CheckBox's 9 px box where English has it beside its text: its bottom row 2 rows above the
## text's last ink row (the slimy body's last row, ascent - 1; CJK letters reach Language ink_drop
## lower). Godot centres the 16 px icon slot and the line box separately; a taller script's line box
## (its ascent) puts the letters lower, so the box sat 1-3 px high (CJK 2, zh_TW 3, Thai 1). English /
## Latin: no change. Call it once the box is in the themed tree and sized.
static func align_checkbox(box: CheckBox) -> void:
	if not tall_script():
		return
	var font: Font = box.get_theme_font("font")
	var h := maxf(box.size.y, box.get_combined_minimum_size().y)
	var icon_h := 0
	for icon_name: String in ["checked", "unchecked", "radio_checked", "radio_unchecked"]:
		var icon := box.get_theme_icon(icon_name)
		if icon:
			icon_h = maxi(icon_h, icon.get_height())
	var box_h := (box.get_theme_icon("unchecked") as Texture2D).get_height()
	var line_top := floorf((h - font.get_height(FONT)) / 2.0)
	var ink_bottom := line_top + roundf(font.get_ascent(FONT)) - 1 + int(metrics().get("ink_drop", 0))
	var want_top := ink_bottom - 2 - (box_h - 1)  # (English: 4 + 7 - 1 - 2 - 8 = 0)
	var top := floorf((h - icon_h) / 2.0)
	box.add_theme_constant_override("check_v_offset", int(want_top - top))


## A 16 px button's height (the title's ENTER): `english_h` with the slimy font; a taller script's 16 px
## line box plus its ink nudge when that is taller (its glyphs have no drips under them).
static func big_button_h(english_h: int) -> int:
	if not tall_script():
		return english_h
	return maxi(english_h, int(metrics().title_line_h) + int(metrics().get("ink_nudge", 0)))


## The rows a locale's accents need above a line of 8 px text in a box laid out for English, which
## already keeps the marks' 1 px gap row free (0 in English, 2 accented, 4 Vietnamese: ink_above - 1; a
## taller script's line box holds its marks: 0). Tiles and panels (no goo lump row over the text).
static func accent_room() -> int:
	return 0 if tall_script() else maxi(0, int(metrics().ink_above) - 1)


## The rows `text`'s marks draw above its line box in the current locale: the locale's ink_above (8 px)
## or title_above (16 px) when the text has a letter outside ASCII (an accented capital, conservatively
## any non-ASCII letter), else 0; 0 in a taller script (its line box holds its marks). For room that
## only a marked line needs (a tagline line under the title's slimes).
static func ink_above(text: String, font_size := FONT) -> int:
	if tall_script():
		return 0
	for i in text.length():
		if text.unicode_at(i) > 0x7F and has_mark(text.unicode_at(i)):
			return int(metrics().title_above if font_size == FONT_BIG else metrics().ink_above)
	return 0


## True when the slimy font's glyph for `code` inks above the line box (an accent, a breve, a dot: the
## i18n page's 5 rows over the letter, tools/make_font.py); false for ASCII and for letters drawn without
## marks (most Cyrillic: МЕШОК, СЛЕДЫ need no room). Read once per character from the font's own image.
static func has_mark(code: int) -> bool:
	if code <= 0x7F:
		return false
	if _marked.has(code):
		return _marked[code]
	var font: FontFile = load(Lang.FONT_PATH)
	var size := Vector2i(FONT, 0)
	var marked := false
	if font.get_glyph_list(0, size).has(code) and font.get_glyph_texture_idx(0, size, code) == 1:
		if _ext_page == null:
			_ext_page = font.get_texture_image(0, size, 1)
		var uv := font.get_glyph_uv_rect(0, size, code)
		for y in range(int(uv.position.y), int(uv.position.y) + EXT_MARK_ROWS):
			for x in range(int(uv.position.x), int(uv.end.x)):
				marked = marked or _ext_page.get_pixel(x, y).a > 0.5
	else:
		marked = not font.get_glyph_list(0, size).has(code)  # (another font draws it: assume marks)
	_marked[code] = marked
	return marked


# ---- Ink of shaped text (docs/ui-rules.md 10.1 "Ink-based placement"; one copy for every screen) ----

## A taller script's 16 px glyphs: the first row they ink under the line box's top, where it is less than
## GOO_INK_ROW (measured with tools/i18n_capture.sh --measure-boxes: Devanagari's matras 1; the others
## start lower: CJK 6, Thai 4, Arabic 5). The title's ENTER puts that row on GOO_INK_ROW.
const BIG_INK_TOP := {"hi": 1}
## A slimy letter in the 16 px title: 14 rows, 4 of drips and the shadow's 2, from the line's row 0.
const TITLE_SLIMY_END := 19


## The first and last rows `texts` ink in `font` at `font_size`, from the line's top: the shaped glyphs'
## bitmaps less the font cache's 1 px padding, as tests/test_i18n_f1_marks.gd reads them (Language keeps
## ink_top / ink_bottom for the 8 px font only, not for a smaller crisp size: the upgrades ABILITIES rows,
## the wardrobe's rule line). With `drips`, a glyph of the slimy font (a bitmap font: no padding, its cell
## holds the 2 drip rows under the letter) ends on its cell's last row: the drips a slimy digit hangs
## under a taller script's line (zh_TW `3X3`: 1 row under the hanzi; Devanagari's small font 1 row
## under the measured line).
static func ink_rows(texts: Array[String], font: Font, font_size := FONT, drips := false) -> Vector2i:
	var ts := TextServerManager.get_primary_interface()
	var slimy: RID = font.get_rids()[0] if drips else RID()
	var top := 99
	var bottom := -99
	for text in texts:
		var shaped := TextLine.new()
		shaped.add_string(text, font, font_size)
		var ascent := ts.shaped_text_get_ascent(shaped.get_rid())
		for g: Dictionary in ts.shaped_text_get_glyphs(shaped.get_rid()):
			if g.font_rid == RID() or g.index == 0:
				continue
			var fixed: int = ts.font_get_fixed_size(g.font_rid)
			var size := Vector2i(fixed if fixed > 0 else font_size, 0)
			var gs: Vector2 = ts.font_get_glyph_size(g.font_rid, size, g.index)
			if gs.y <= 2:
				continue
			var y0 := int(ascent + g.offset.y + ts.font_get_glyph_offset(g.font_rid, size, g.index).y) + 1
			top = mini(top, y0)
			bottom = maxi(bottom, y0 + int(gs.y) - (2 if g.font_rid == slimy else 3))
	return Vector2i(top, bottom) if bottom >= top else Vector2i(0, int(font.get_height(font_size)) - 1)


## How many rows `text`'s last ink (drips included) reaches under what a layout assumed for its line
## (`assumed_bottom`, line-relative: Language ink_bottom, or ink_rows of the line's texts), in `font`
## (default: the locale's 8 px font); 0 in English and wherever the assumption holds. Only a taller
## script's line can hang a slimy drip under its own ink (zh_TW digits: 1).
static func drip_excess(text: String, assumed_bottom: int, font: Font = null) -> int:
	if not tall_script() or text == "":
		return 0
	var texts: Array[String] = [text]
	return maxi(0, ink_rows(texts, font if font else font_for(), FONT, true).y - assumed_bottom)


## The rows the slimy font's marks over `text` reach above its line box at `font_size` (Й: 3 at 8 px,
## 6 at 16; 0 for a text without marks). Read from the 8 px font's i18n page, where each glyph has
## EXT_MARK_ROWS rows over the letter (the 16 px font is the same art at 2x). (ink_above gives the
## locale's tallest marks, not the text's own.)
static func mark_rows(text: String, font_size := FONT) -> int:
	var font: FontFile = load(Lang.FONT_PATH)
	var size := Vector2i(FONT, 0)
	var rows := 0
	var page: Image = null
	for i in text.length():
		var code := text.unicode_at(i)
		if code <= 0x7F or not has_mark(code) or not font.get_glyph_list(0, size).has(code) \
				or font.get_glyph_texture_idx(0, size, code) != 1:
			continue
		if page == null:
			page = font.get_texture_image(0, size, 1)
		var uv := font.get_glyph_uv_rect(0, size, code)
		for y in EXT_MARK_ROWS:
			var inked := false
			for x in range(int(uv.position.x), int(uv.end.x)):
				inked = inked or page.get_pixel(x, int(uv.position.y) + y).a > 0.5
			if inked:
				rows = maxi(rows, EXT_MARK_ROWS - y)
				break
	return rows * (2 if font_size == FONT_BIG else 1)


## How far a button's text should move right so its ink is centred (fix pass F3b): Chinese, Japanese
## and Korean glyphs start at their left edge and keep their spacing on the right (Hangul 2 px a
## syllable), so a centred CJK line sat 1-2 px left of the middle (ストーリー ink 1 / 3 px from the
## fill, 허브로 가기 34 / 38). Measured from the shaped glyphs' bitmaps (each with the font cache's
## 1 px padding); 0 in every other locale (the slimy font's own 1 px leading gap is English's look).
static func ink_shift(text: String, font_size: int) -> int:
	if not locale() in Lang.GAP_LOCALES:
		return 0
	var font: Font = font_for(font_size)
	var server := TextServerManager.get_primary_interface()
	var shaped := server.create_shaped_text()
	server.shaped_text_add_string(shaped, text, font.get_rids(), font_size)
	var x := 0.0
	var first := INF
	var last := -INF
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		var rid: RID = glyph.font_rid
		if rid.is_valid() and int(glyph.index) != 0:
			var size: Vector2 = server.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph.index)
			if size.x > 2.0:  # (a bitmap of more than its padding)
				var left: float = x + glyph.offset.x + server.font_get_glyph_offset(rid, Vector2i(font_size, 0), glyph.index).x
				first = minf(first, left + 1.0)
				last = maxf(last, left + size.x - 1.0)
		x += glyph.advance
	server.free_rid(shaped)
	if first == INF:
		return 0
	return floori(((x - last) - first) / 2.0)


## The last row the 16 px screen title inks (its 2 px shadow included) at title_top(), for any of
## `texts` in the title's `font`: the slimy font's box (title_bottom() - 1: 21 in English, its drips and
## shadow); a taller script's glyphs end well above their line box (CJK 20 px: row 27 of 2..32),
## measured from the shaped glyphs' bitmaps (less their 1 px padding).
static func title_ink_end(texts: Array[String], font: Font) -> int:
	if not tall_script():
		return title_bottom() - 1
	var slimy: RID = font.get_rids()[0]
	var ts := TextServerManager.get_primary_interface()
	var end := title_top()
	for text in texts:
		var shaped := TextLine.new()
		shaped.add_string(text, font, FONT_BIG)
		var ascent := ts.shaped_text_get_ascent(shaped.get_rid())
		for g: Dictionary in ts.shaped_text_get_glyphs(shaped.get_rid()):
			if g.font_rid == RID() or g.index == 0:
				continue
			if g.font_rid == slimy:
				end = maxi(end, title_top() + TITLE_SLIMY_END)
				continue
			var fixed: int = ts.font_get_fixed_size(g.font_rid)
			var size := Vector2i(fixed if fixed > 0 else FONT_BIG, 0)
			var gs: Vector2 = ts.font_get_glyph_size(g.font_rid, size, g.index)
			var y0 := int(ascent + g.offset.y + ts.font_get_glyph_offset(g.font_rid, size, g.index).y)
			end = maxi(end, title_top() + y0 + int(gs.y))  # (the bitmap less its padding row, + the 2 px shadow)
	return end


## Where a 7 px digit's body starts in a line box of the current locale's 8 px font: 0 in English and
## with accents; in a taller script's box (CJK, Thai, Devanagari, Arabic) the slimy digits sit
## ascent - 7 px down, so an icon beside a number moves down with them.
static func digit_top() -> float:
	if not tall_script():
		return 0.0  # (asking the font would allocate its size cache: English must keep its RIDs)
	return roundf(font_for().get_ascent(FONT)) - TEXT_BODY


## The slimy font WITHOUT the locale's script fallback, for digits-only texts (level numbers, times,
## percents, +N, the page arrows): Font.get_height counts every fallback, so a taller script would make
## their labels taller and push the digits down (they never use a fallback glyph). Null (no change)
## with no fallback installed (English; `always`: a fallback-free copy anyway, for text drawn beside
## another script's) or when `text` needs a glyph the slimy font lacks.
static func plain_font(text: String, font_size := FONT, always := false) -> Font:
	var base: FontFile = load(Lang.FONT_BIG_PATH if font_size == FONT_BIG else Lang.FONT_PATH)
	if base.fallbacks.is_empty() and not always:
		return null
	var held: WeakRef = _plain_fonts.get(base.resource_path)
	var plain: FontFile = held.get_ref() if held else null
	if plain == null:
		plain = base.duplicate()
		var none: Array[Font] = []
		plain.fallbacks = none
		_plain_fonts[base.resource_path] = weakref(plain)  # (kept while a control uses it)
	for i in text.length():
		if not plain.has_char(text.unicode_at(i)) and not is_format_char(text.unicode_at(i)):
			return null
	return plain


## True for an invisible bidi / joining control (Loc.fill's isolates U+2066..U+2069, marks, embeddings,
## zero-width space): the text server draws nothing for it, in any font.
static func is_format_char(code: int) -> bool:
	return (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069)


## `text` (one line) broken onto two at the space nearest the middle that keeps both within `room` px
## (as it is if there is none): a checkbox's or a result line's two balanced lines.
static func break_line(text: String, room: int) -> String:
	var best := text
	var best_w := INF
	for i in text.length():
		if text[i] != " ":
			continue
		var w := maxi(text_w(text.left(i)), text_w(text.substr(i + 1)))
		if w <= room and w < best_w:
			best_w = w
			best = text.left(i) + "\n" + text.substr(i + 1)
	return best


## Puts plain_font on `control` (a Label / Button showing digits or arrows) when it applies.
static func use_plain_font(control: Control, font_size := FONT) -> void:
	var font := plain_font(String(control.get("text")), font_size)
	if font:
		control.add_theme_font_override("font", font)


## Wraps `label` (already in the themed tree) to `box`: the locale's autowrap, then its minimum size
## updated before it is sized (a label sized while its minimum is still the one-line width, or the
## default font's, keeps that width).
static func wrap_label(label: Label, box: Vector2) -> void:
	relayout(label)
	label.autowrap_mode = autowrap_mode()
	label.update_minimum_size()
	label.size = box


## Page arrows for a layout a locale pages (docs/ui-rules.md section 10, paging): < at `left_x` and >
## ending at `right_x`, `w` x `h` (h -1: button_h()) on row `y`, added to `parent` (last, so the other
## nodes keep their places), in plain_font (the arrows sit on the line as in English), named PagePrev /
## PageNext. `on_step` gets -1 / 1. Returns [prev, next]; show_page_arrows sets their state.
static func add_page_arrows(parent: Node, on_step: Callable, y: float, left_x: float, right_x: float, w := PAGER_W,
		h := -1, focus := true) -> Array[Button]:
	var size := Vector2(w, button_h() if h < 0 else h)
	var arrows: Array[Button] = []
	for step: int in [-1, 1]:
		var arrow := make_button("<" if step < 0 else ">", func() -> void: on_step.call(step), size)
		arrow.name = "PagePrev" if step < 0 else "PageNext"
		if not focus:
			arrow.focus_mode = Control.FOCUS_NONE
		parent.add_child(arrow)
		use_plain_font(arrow)
		arrow.size = size
		arrow.position = Vector2(left_x if step < 0 else right_x - w, y)
		arrows.append(arrow)
	return arrows


## The arrows' state on page `page` of `pages`: the arrow that would leave the pages disabled (their
## visibility stays the caller's: a panel may be covering them).
static func show_page_arrows(arrows: Array, page: int, pages: int) -> void:
	for i in arrows.size():
		(arrows[i] as Button).disabled = page <= 0 if i == 0 else page >= pages - 1


## The top of page arrows beside a screen's title: centred on its letters (the 14 px body, or a taller
## script's line).
static func title_arrows_y() -> int:
	var body := maxi(14, int(metrics().get("title_line_h", 14)))
	return title_top() + floori((body - button_h()) / 2.0)


## The panel-cover rule (docs/ui-rules.md section 10): while a modal panel is open in a locale whose
## layout differs from English, the screen's own controls behind it are hidden (only those whose rect
## meets `rect`, when it has an area), so the panel's texts never sit over the page's ghost texts.
## Skips the drifting backdrop, anything in `keep` and what is already hidden. Returns what it hid
## (uncover shows it again). English keeps its ghosts (pixel-identical): callers skip it there.
static func cover_behind(screen: Node, keep: Array, rect := Rect2()) -> Array[CanvasItem]:
	relayout(screen)  # (the rect and the controls' positions in the same, LTR, coordinates)
	var hidden: Array[CanvasItem] = []
	for child in screen.get_children():
		var item := child as CanvasItem
		if item == null or item is MenuBackdrop or item in keep or not item.visible:
			continue
		if rect.has_area():
			var control := item as Control
			if control == null or not Rect2(control.position, control.size).intersects(rect):
				continue
		item.visible = false
		hidden.append(item)
	return hidden


## Shows what cover_behind hid again and empties the list.
static func uncover(hidden: Array) -> void:
	for item: Variant in hidden:
		if is_instance_valid(item):
			(item as CanvasItem).visible = true
	hidden.clear()


# ---- Right-to-left mirroring (chunk I, docs/ui-rules.md section 10.2) ----
# Every screen is laid out by hand in LEFT-TO-RIGHT coordinates (the English layout code, unchanged).
# In a right-to-left language (Language.is_rtl: Arabic) each UI root registers with mirror_root: it
# stays LTR while the screen builds, and at the end of that frame (deferred) it is flipped to
# Control.LAYOUT_DIRECTION_RTL. Godot then mirrors the whole subtree against each parent's real width
# (x' = parent_w - x - w: absolute positions through their offsets, anchors, container order, label /
# button alignment and the bidi base direction of every text), so BACK lands bottom right, tabs and
# columns reverse, page arrows swap sides and HUD pods swap corners with no per-screen arithmetic.
# Godot's `position` is VISUAL while RTL (setting it there is not mirrored), so code that moves or
# resizes controls after the build (a page / tab switch, a panel opening, a pod resizing) calls
# relayout(node) first: the root goes back to LTR for the rest of the frame (reads and writes are
# logical again) and is mirrored again at its end. Not mirrored, deliberately: the game world and the
# hub room (Node2D, never under a mirror root), the touch controls (thumb placement), text drawn with
# draw_string, and anything under keep_ltr (digits-only clocks, the map drawings). Node2D sprites
# placed inside a mirrored Control (slime previews) are mirrored with it; explicit focus neighbours swap
# left / right so the arrow keys follow the visual order. With the gate off or in an LTR language
# none of this runs: mirror_root / relayout return at once (English stays pixel-identical).

## Meta on a mirror root: {mirrored, pending}. On a Node2D under it: its [LTR x, mirrored x].
const MIRROR_META := "rtl_mirror"
const MIRROR_X_META := "rtl_x"
## Meta on a control whose subtree is never mirrored (keep_ltr).
const KEEP_LTR_META := "rtl_keep"


## True while the current language is written right to left (Arabic; never with the gate off).
static func rtl() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var language: Node = tree.root.get_node_or_null("Language") if tree else null
	return language != null and language.has_method("is_rtl") and language.is_rtl()


## -1 / 1 as the reading direction goes: 1 in English, -1 in a right-to-left language. For code that
## turns a left / right key into a logical step (previous / next page): `step * reading_dir()`.
static func reading_dir() -> int:
	return -1 if rtl() else 1


## Registers `root` (a screen's root Control, or a CanvasLayer whose Control children are the roots) to
## be mirrored in a right-to-left language once it is built (see the section comment). Nothing in LTR.
static func mirror_root(root: Node) -> void:
	if not rtl() or root == null:
		return
	root.set_meta(MIRROR_META, {mirrored = false, pending = false})
	for target in _direction_targets(root):
		target.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_queue_mirror(root)


## Call before moving / resizing controls under a mirror root after its build (or reading their
## positions to place others): the root is back in LTR (logical) coordinates for the rest of this frame
## and mirrored again at its end. Nothing in LTR or outside a mirror root.
static func relayout(node: Node) -> void:
	var root := mirror_root_of(node)
	if root == null:
		return
	var state: Dictionary = root.get_meta(MIRROR_META)
	if state.mirrored:
		_set_mirrored(root, false)
	_queue_mirror(root)


## Mirrors a mirror root now (tests, captures; normally deferred to the end of the frame).
static func mirror_now(node: Node) -> void:
	var root := mirror_root_of(node)
	if root:
		_mirror_deferred(root)


## The mirror root `node` is in (itself or an ancestor), or null.
static func mirror_root_of(node: Node) -> Node:
	var at := node
	while at != null:
		if at.has_meta(MIRROR_META):
			return at
		at = at.get_parent()
	return null


## True when `control` is drawn mirrored (under a mirror root that is flipped right now).
static func is_mirrored(control: Control) -> bool:
	return control != null and control.is_layout_rtl()


## The base text direction for a Label / Button OUTSIDE a mirror root (an autoload overlay): right to
## left in a right-to-left language, so punctuation and Latin words / numbers inside an Arabic line land
## where an Arabic reader expects them. Inherited (the default) otherwise; mirrored roots inherit RTL.
static func text_direction() -> Control.TextDirection:
	return Control.TEXT_DIRECTION_RTL if rtl() else Control.TEXT_DIRECTION_INHERITED


## Keeps `item` and everything under it left to right in a mirrored screen (a Control's own box is not
## moved either): an animated stage, a map drawing, a drawn widget whose input maps to its drawing.
## Nothing in LTR.
static func keep_ltr(item: CanvasItem) -> void:
	if not rtl():
		return
	if item is Control:
		(item as Control).layout_direction = Control.LAYOUT_DIRECTION_LTR
	item.set_meta(KEEP_LTR_META, true)


static func _direction_targets(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control:
		out.append(root)
	else:
		for child in root.get_children():
			if child is Control:
				out.append(child)
	return out


static func _queue_mirror(root: Node) -> void:
	var state: Dictionary = root.get_meta(MIRROR_META)
	if state.pending:
		return
	state.pending = true
	_mirror_deferred.bind(root).call_deferred()


## (`root` is a Variant: a freed node would fail the typed-argument conversion of the deferred call.)
static func _mirror_deferred(root: Variant) -> void:
	if not is_instance_valid(root) or not root.has_meta(MIRROR_META):
		return
	var state: Dictionary = root.get_meta(MIRROR_META)
	state.pending = false
	if not state.mirrored and rtl():
		_set_mirrored(root, true)


## Flips `root` to RTL (on) or back to LTR (off): the layout direction (Godot mirrors the positions),
## then what Godot does not mirror by itself: explicit left / right focus neighbours, Node2D children.
static func _set_mirrored(root: Node, on: bool) -> void:
	var state: Dictionary = root.get_meta(MIRROR_META)
	state.mirrored = on
	for target in _direction_targets(root):
		target.layout_direction = Control.LAYOUT_DIRECTION_RTL if on else Control.LAYOUT_DIRECTION_LTR
		_mirror_extras(target, on)


static func _mirror_extras(node: Node, on: bool) -> void:
	for child in node.get_children():
		if child.has_meta(KEEP_LTR_META):
			continue
		var control := child as Control
		if control:
			var left := control.focus_neighbor_left
			var right := control.focus_neighbor_right
			if left != right:
				control.focus_neighbor_left = right
				control.focus_neighbor_right = left
			_mirror_extras(control, on)
		elif child is Node2D:
			_mirror_node2d(child as Node2D, (node as Control).size.x if node is Control else 0.0, on)


## A sprite inside a mirrored Control: its x mirrored about the parent's width (sprites are centred on
## their position); the sprites under it (a hat, the try-on group's slimes) about their parent's origin,
## so the group lands mirrored as a whole. Art is never flipped. Off: back to the LTR x it had, unless the
## screen moved it meanwhile (a sprite that follows another each frame catches up by itself).
static func _mirror_node2d(node: Node2D, parent_w: float, on: bool) -> void:
	_mirror_x(node, parent_w, on)
	for child in node.get_children():
		if child is Node2D and not child.has_meta(KEEP_LTR_META):
			_mirror_node2d(child as Node2D, 0.0, on)
		elif child is Control and not child.has_meta(KEEP_LTR_META):
			_mirror_extras(child, on)


static func _mirror_x(node: Node2D, parent_w: float, on: bool) -> void:
	if on:
		var x := node.position.x
		var mirrored := parent_w - x
		node.set_meta(MIRROR_X_META, [x, mirrored])
		node.position.x = mirrored
	elif node.has_meta(MIRROR_X_META):
		var xs: Array = node.get_meta(MIRROR_X_META)
		if is_equal_approx(node.position.x, xs[1]):
			node.position.x = xs[0]
		node.remove_meta(MIRROR_X_META)


# ---- Layout budgets: does a layout fit the 320x180 safe area? (docs/ui-rules.md section 10) ----

## The safe 320x180 area for content (Platform.safe_rect: the whole view on desktop / web).
static func safe_rect() -> Rect2:
	return Platform.safe_rect()


## A menu page's content area: under the title box (+ `gap`), above the bottom row (- `gap`), EDGE
## in from the sides, inside the safe area. English: (4, 26)..(316, 160) with GAP_M.
static func content_rect(gap := GAP_M, title := true) -> Rect2:
	var top := (title_bottom() if title else EDGE) + gap
	var bottom := bottom_row_y() - gap
	var area := Rect2(EDGE, top, SCREEN.x - 2 * EDGE, bottom - top)
	return area.intersection(safe_rect())


## Height of a column of items `heights` stacked `gap` apart.
static func stack_h(heights: Array, gap: float) -> float:
	var h := 0.0
	for item_h: float in heights:
		h += item_h
	return h + gap * maxi(heights.size() - 1, 0)


## True when the stacked column fits `area_h` (default: content_rect's height).
static func stack_fits(heights: Array, gap: float, area_h := -1.0) -> bool:
	return stack_h(heights, gap) <= (content_rect().size.y if area_h < 0 else area_h)


## Splits a stacked column into pages that each fit `area_h` (keeping the order; an item taller than
## the area gets a page of its own). One page = it fits as it is. Returns arrays of item indexes.
static func stack_pages(heights: Array, gap: float, area_h := -1.0) -> Array[Array]:
	var room := content_rect().size.y if area_h < 0 else area_h
	var pages: Array[Array] = [[]]
	var used := 0.0
	for i in heights.size():
		var h: float = heights[i]
		var add := h if pages[-1].is_empty() else gap + h
		if not pages[-1].is_empty() and used + add > room:
			pages.append([])
			add = h
			used = 0.0
		pages[-1].append(i)
		used += add
	return pages


## Rows of `row_h` (default button_h()) `gap` apart that fit in `area_h`.
static func row_budget(area_h: float, row_h := -1.0, gap := GAP_S) -> int:
	var h := float(button_h()) if row_h < 0 else row_h
	return maxi(0, floori((area_h + gap) / (h + gap)))


## The width each of `columns` columns gets in `area_w` with `gap` between them (whole pixels).
static func column_budget(area_w: float, columns: int, gap := GAP_L) -> int:
	return floori((area_w - gap * (columns - 1)) / float(columns))


## A fixed grid of `count` cells, `columns` wide, cells `cell_h` tall (default button_h()) and `gap`
## apart, in `area_h`: {rows (needed), rows_per_page (fit), pages, pitch, h (one page's height),
## fits (one page)}. Screens use it to page a grid that a taller script no longer fits.
static func grid_budget(count: int, columns: int, area_h: float, cell_h := -1.0, gap := GAP_S) -> Dictionary:
	var h := float(button_h()) if cell_h < 0 else cell_h
	var rows := ceili(count / float(maxi(columns, 1)))
	var per_page := maxi(1, row_budget(area_h, h, gap))
	var shown := mini(rows, per_page)
	return {rows = rows, rows_per_page = per_page, pages = ceili(rows / float(per_page)), pitch = h + gap,
		h = shown * h + maxi(shown - 1, 0) * gap, fits = rows <= per_page}


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT
	# Beveled nine-slice buttons: hovering lifts the text 1 px, pressing pushes it down 1 px.
	theme.set_stylebox("normal", "Button", button_style("normal"))
	theme.set_stylebox("hover", "Button", button_style("hover"))
	theme.set_stylebox("pressed", "Button", button_style("pressed"))
	theme.set_stylebox("hover_pressed", "Button", button_style("pressed"))
	theme.set_stylebox("disabled", "Button", button_style("disabled"))
	theme.set_stylebox("focus", "Button", _focus_box())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_OFF)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "CheckBox", TEXT)
	theme.set_stylebox("focus", "CheckBox", _focus_box())
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	theme.set_icon("unchecked", "CheckBox", load(UI_DIR + "check_off.png"))
	theme.set_icon("checked", "CheckBox", load(UI_DIR + "check_on.png"))
	theme.set_constant("h_separation", "CheckBox", 4)
	theme.set_color("font_color", "Label", TEXT)
	# The font's line box is only the 7 px letter body (the drips hang below it), so lines are
	# spaced by the drips' 2 px plus the usual gap (a taller script: its own line_pitch, line_spacing()).
	theme.set_constant("line_spacing", "Label", line_spacing())
	# A 1 px drop shadow keeps text readable over the drifting backdrop.
	theme.set_color("font_shadow_color", "Label", Color(BG, 0.9))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	var track := _box(Color8(30, 26, 40), Color8(26, 28, 44))
	track.draw_center = true
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(BUTTON_PRESSED))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(Color8(56, 183, 100)))
	theme.set_icon("grabber", "HSlider", load(UI_DIR + "grabber.png"))
	theme.set_icon("grabber_highlight", "HSlider", load(UI_DIR + "grabber_hover.png"))
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	# Text boxes (the save code): a dark inset well, outlined brighter while you type in it.
	var well := _box(Color8(14, 14, 24), Color8(62, 74, 96))
	well.draw_center = true
	well.content_margin_top = 2
	well.content_margin_bottom = 1
	theme.set_stylebox("normal", "LineEdit", well)
	theme.set_stylebox("read_only", "LineEdit", well)
	var focused := well.duplicate() as StyleBoxFlat
	focused.border_color = TEXT_DIM
	theme.set_stylebox("focus", "LineEdit", focused)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_uneditable_color", "LineEdit", TEXT_DIM)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_OFF)
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", Color8(62, 74, 96))
	GooBox.track_theme(theme)
	return theme


## A goo-framed button ("normal", "hover", "pressed" or "disabled"; see GooBox). Hover brightens
## the goo and pressing darkens the face; the text never moves, so it stays clear of the goo. Its
## top / bottom content margins (button_v_margins) make a one-line button button_h() tall.
static func button_style(state: String) -> StyleBox:
	var box := GooBox.make_button(state)
	var margins := button_v_margins()
	box.content_margin_top = margins.x
	box.content_margin_bottom = margins.y
	return box


## The goo-framed panel behind groups of buttons and messages (`hud` = the plain, lighter HUD pod).
static func panel_style(hud := false) -> StyleBox:
	if not hud:
		var goo := GooBox.make_panel()
		var margins := panel_v_margins()  # (6 / 5 in English: below the goo band and its lumps, marks included)
		goo.content_margin_top = margins.x
		goo.content_margin_bottom = margins.y
		return goo
	var box := StyleBoxTexture.new()
	box.texture = load(UI_DIR + "hud_pod.png")
	var margin := 3
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = 4  # the frame is two px thick: dark outline + light rim (+ highlight on top)
	box.content_margin_right = 4
	var margins := pod_v_margins()  # 3 / 3 in English: a one-line pod is pod_h() tall
	box.content_margin_top = margins.x
	box.content_margin_bottom = margins.y
	return box


## Adds a framed panel covering `rect` (drawn behind whatever is added after it).
static func add_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


## The ticket store's BUY? confirm (hat wheel SHOP, upgrades TICKETS tab), added to `parent`: a dim
## sheet over the whole screen that swallows clicks and taps (so nothing behind the confirm can be
## pressed while it's open; the keyboard is locked by lock_focus) and the panel with its text, a
## price with a ticket icon, and BUY / BACK. Both start hidden. Returns {blocker, panel, label, price,
## buy, back}.
static func add_ticket_confirm(parent: Control, on_buy: Callable, on_back: Callable, price_tint: Color) -> Dictionary:
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.45)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	parent.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# English: a 148x58 panel at (86, 60): text at 8, price row at 20, BUY / BACK (48x13, 12 apart) at
	# 36, 9 px under them. A longer BUY / BACK widens both buttons alike (the pair stays symmetric) and
	# the panel with them; a taller script moves the rows by its line pitch / button height.
	# i18n: max 40px (button 48 wide, 4 px margins), grows to 60px (both buttons alike, the panel with them), 1 line
	var buy_text := Loc.t("common.buy", "BUY")
	# i18n: max 40px, grows to 60px (both buttons alike, the panel with them), 1 line
	var back_text := Loc.t("common.back", "BACK")
	var button_w: int = tab_widths([buy_text, back_text], 48, true).max()
	var panel_w := maxi(148, 2 * button_w + GAP_XL + 2 * 20)
	var line_box := line_h() + TEXT_DRIP + 1
	var price_y := 8 + line_pitch()
	var buttons_y := price_y + line_pitch() + GAP_M
	var panel_h := buttons_y + button_h() + 9
	var panel := add_panel(parent, Rect2(center_x(panel_w), 60 - floori((panel_h - 58) / 2.0), panel_w, panel_h))
	panel.visible = false
	var label := make_label("", FONT, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 8)
	label.size = Vector2(panel_w, line_box)
	panel.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, price_y)
	row.size = Vector2(panel_w, line_box)
	panel.add_child(row)
	var price := make_label("", FONT, price_tint)
	row.add_child(price)
	row.add_child(make_icon("ticket", Color.WHITE))
	var buy := make_button(buy_text, on_buy, Vector2(button_w, button_h()))
	buy.position = Vector2(center_x(2 * button_w + GAP_XL, 0, panel_w), buttons_y)
	panel.add_child(buy)
	var back := make_button(back_text, on_back, Vector2(button_w, button_h()))
	back.position = Vector2(buy.position.x + button_w + GAP_XL, buttons_y)
	panel.add_child(back)
	for b: Button in [buy, back]:
		note_text_w(b, [buy_text, back_text], 48)
	return {blocker = blocker, panel = panel, label = label, price = price, buy = buy, back = back}


## An 8x8 UI icon ("drop", "clock", "lock", "check").
static func make_icon(icon_name: String, tint := TEXT) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(UI_DIR + "icon_%s.png" % icon_name)
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


## The bounding box (in icon pixels) of an icon's visible pixels, so it can be centered by its ink
## rather than its 8x8 cell.
static func icon_ink_rect(icon_name: String) -> Rect2i:
	var img: Image = (load(UI_DIR + "icon_%s.png" % icon_name) as Texture2D).get_image()
	var used := img.get_used_rect()
	return used


## Full-screen menu root: theme, the drifting maze backdrop, a title at the top, and skin-colored
## text.
## Returns the SkinText node (call its recolor() after changing the skin).
static func setup_screen(root: Control, title: String) -> SkinText:
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # all text goes through Loc (docs/i18n/plan.md)
	root.theme = make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := MenuBackdrop.new()
	root.add_child(backdrop)
	keep_ltr(backdrop)  # (the drifting maze is a backdrop, not a layout: never mirrored)
	if title != "":
		var label := make_label(title, FONT_BIG, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		label.offset_top = title_top()  # TITLE_Y / TITLE_Y + 20 in English
		label.offset_bottom = title_bottom()
		label.add_theme_color_override("font_shadow_color", Color(BG, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 2)
	mirror_root(root)  # (right-to-left languages only: flipped once the screen is built)
	return add_skin_text(root)


## Adds a SkinText node so labels and the root's button text follow the equipped skin's color.
static func add_skin_text(root: Control) -> SkinText:
	var skin_text := SkinText.new()
	skin_text.theme_owner = root
	root.add_child(skin_text)
	return skin_text


static func make_label(text: String, font_size := FONT, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.material = text_material()
	use_big_font(label, font_size)
	# The standard UI colors stand for roles that SkinText recolors from the equipped skin.
	var role: String = {GOLD: SkinText.ROLE_TITLE, TEXT: SkinText.ROLE_TEXT, TEXT_DIM: SkinText.ROLE_DIM}.get(color, "")
	if role != "":
		label.set_meta("role", role)
		label.add_to_group(SkinText.GROUP)
	return label


## 16 px text uses the 2x font, whose letter gaps are split evenly so centered titles sit exactly
## on center (the 8 px font, scaled up, would put them a pixel right).
static func use_big_font(control: Control, font_size: int) -> void:
	if font_size == FONT_BIG:
		control.add_theme_font_override("font", load("res://assets/fonts/pixel_big.fnt"))


## The 8 px font with tabular digits: "1" takes a full digit cell (6 px, its ink centered in it) like
## every other digit, so a running time keeps its width and never jiggles (the HUD timer).
static func tabular_font() -> FontFile:
	if _tabular_font == null:
		var base: FontFile = load("res://assets/fonts/pixel.fnt")
		_tabular_font = base.duplicate(true)
		var size: Vector2i = _tabular_font.get_size_cache_list(0)[0]
		var one := "1".unicode_at(0)
		var zero := "0".unicode_at(0)
		var extra: float = _tabular_font.get_glyph_advance(0, size.x, zero).x - _tabular_font.get_glyph_advance(0, size.x, one).x
		_tabular_font.set_glyph_advance(0, size.x, one, _tabular_font.get_glyph_advance(0, size.x, zero))
		_tabular_font.set_glyph_offset(0, size, one, _tabular_font.get_glyph_offset(0, size, one) + Vector2(floorf(extra / 2.0), 0))
	return _tabular_font


## Shared material for text: every letter gets its own random goo drips (text_drips.gdshader).
static func text_material() -> ShaderMaterial:
	if _text_material == null:
		_text_material = ShaderMaterial.new()
		_text_material.shader = load("res://assets/shaders/text_drips.gdshader")
		_text_material.set_shader_parameter("clean_small", Economy.CLEAN_SMALL_TEXT)
	# New drips every time a screen opens: a fresh seed the first time text is made in each scene.
	var tree := Engine.get_main_loop() as SceneTree
	var scene_id := tree.current_scene.get_instance_id() if tree and tree.current_scene else 0
	if scene_id != _drip_scene:
		_drip_scene = scene_id
		_text_material.set_shader_parameter("seed", float(randi() % 10000))
	return _text_material


## The 16 px text without drips (BUG2-05: the title's tagline and ENTER THE HUB read clean; headings keep text_material()).
static func clean_big_material() -> ShaderMaterial:
	if _clean_big_material == null:
		_clean_big_material = ShaderMaterial.new()
		_clean_big_material.shader = load("res://assets/shaders/text_drips.gdshader")
		_clean_big_material.set_shader_parameter("clean_small", Economy.CLEAN_SMALL_TEXT)
		_clean_big_material.set_shader_parameter("clean_big", true)
	return _clean_big_material


static func make_button(text: String, on_press: Callable, min_size := Vector2(0, BUTTON_H)) -> Button:
	var button := TouchButton.new()
	button.text = text
	button.material = text_material()
	button.custom_minimum_size = min_size
	button.pressed.connect(func() -> void:
		var sfx := button.get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -6.0))
	button.pressed.connect(on_press)
	return button


## Bottom-left BACK button that returns to the hub (BACK_SIZE at EDGE, BOTTOM_ROW_Y on every screen in
## English; back_size() / bottom_row_y() otherwise: wider for a longer word, taller for a taller
## script, always ending on row 176).
static func add_back_button(root: Control, on_press := Callable()) -> Button:
	var press := on_press if on_press.is_valid() else func() -> void: go(root.get_tree(), HUB_SCENE)
	# i18n: max 32px (BACK_SIZE 40 wide, 4 px margins), grows to 40px (back_size: the button widens), 1 line; on every screen
	var text := Loc.t("common.back", "BACK")
	var button := make_button(text, press, back_size(text))
	note_text_w(button, [text], int(BACK_SIZE.x))
	root.add_child(button)
	place_bottom_row(button, -1)
	return button


## Puts `control` (sized) on the bottom row: side -1 = left edge, 1 = right edge, 0 = centered. Its
## bottom edge is the bottom row's (row 176), so a taller control starts higher (BOTTOM_ROW_Y for 13).
static func place_bottom_row(control: Control, side: int) -> void:
	relayout(control)  # (right-to-left: side -1 ends up on the right, mirrored at the frame's end)
	var w := control.size.x
	var x := float(EDGE) if side < 0 else (SCREEN.x - EDGE - w if side > 0 else center_x(w))
	control.position = Vector2(x, BOTTOM_ROW_Y + BUTTON_H - maxf(control.size.y, BUTTON_H))


## The x that centers a box `width` wide on the screen (or in `span` starting at `from`), on a
## whole pixel.
static func center_x(width: float, from := 0.0, span := SCREEN.x) -> float:
	return from + roundf((span - width) / 2.0)


## Adds a label to `parent` FIRST and sizes it after: a label sized before it is in the themed tree
## measures with the default font and keeps that larger minimum size (it then sits off center).
static func add_label(parent: Node, text: String, rect: Rect2, font_size := FONT, color := TEXT,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := make_label(text, font_size, color)
	label.horizontal_alignment = align
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


## Tabs and other one-of-many buttons: the selected one gets its own look (darker, pressed-in face
## and the brighter hover goo) in every state, so hovering another tab never looks like selecting it.
static func set_selected(button: Button, on: bool) -> void:
	if on:
		var style := button_style("selected")
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
	button.set_meta("selected", on)


## True when menus should use touch hit areas: the player is touching the screen (touch_in_use), or
## the --touch debug flag. A desktop that merely has a touchscreen keeps exact hit areas for its mouse.
static func touch_active() -> bool:
	if touch_in_use:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var progress: Node = tree.root.get_node_or_null("Progress") if tree else null
	return progress != null and progress.get("force_touch") == true


## The HUD pods' distance from the screen's sides (x, mirrored) and top (y): HUD_EDGE, or 1 px clear of the
## safe area where it cuts deeper (Platform.safe_insets; never on desktop or the web, so those stay at 3).
static func hud_edge() -> Vector2i:
	var insets := Platform.safe_insets()
	return Vector2i(maxi(HUD_EDGE, maxi(insets.left, insets.right) + 1), maxi(HUD_EDGE, insets.top + 1))


## Tracks touch_in_use from every input event, before any node or the GUI sees it (the RotateHint
## autoload connects it to the root window's window_input). A tap reaches the GUI as a mouse event
## Godot makes from the touch (device DEVICE_ID_EMULATION), so it counts as touch too.
static func note_pointer(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_in_use = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		touch_in_use = event.device == InputEvent.DEVICE_ID_EMULATION


## Marks a non-TouchButton input (checkbox, slider box, text box) as a touch target, so grown
## button hit areas never reach into it.
static func add_touch_target(control: Control) -> void:
	control.add_to_group(TOUCH_GROUP)


## Keeps keyboard / controller focus inside `modal`, a panel open over `screen`: every other
## focusable control under `screen` stops taking focus (arrows, Tab and Shift+Tab skip it) until
## `unlock_focus` gets the returned map back. Grab the panel's focus before or after; either works.
static func lock_focus(screen: Node, modal: Node) -> Dictionary:
	var saved := {}
	_lock_focus(screen, modal, saved)
	return saved


static func _lock_focus(node: Node, modal: Node, saved: Dictionary) -> void:
	for child in node.get_children():
		if child == modal:
			continue
		var control := child as Control
		if control and control.focus_mode != Control.FOCUS_NONE:
			saved[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
		_lock_focus(child, modal, saved)


## Undoes `lock_focus` (controls freed meanwhile are skipped).
static func unlock_focus(saved: Dictionary) -> void:
	for control: Variant in saved:
		if is_instance_valid(control):
			(control as Control).focus_mode = saved[control]
	saved.clear()


## A volume box's label: "sfx" (sound effects, Progress.volume) or "music" (Progress.music_volume).
static func volume_label(kind := "sfx") -> String:
	if kind == "music":
		return Loc.t("settings.volume_music", "MUSIC")  # i18n: volume slider label, max 60px, 1 line (the slider shrinks to fit)
	return Loc.t("settings.volume_sfx", "SFX")  # i18n: sound-effects volume slider label, max 60px, 1 line (the slider shrinks to fit)


## The slider width that makes a volume box `total` px wide: the box is 6 + label + 6 + slider + 6
## (margins and separation = 18 px), the label measured in `node`'s theme font so a longer
## translation takes its room from the slider, not from the box. The widest of `kinds`' labels counts
## (SETTINGS: both, so its two sliders line up; the pause menu: only its SFX).
static func volume_slider_width(node: Control, total: float, kinds: Array = ["sfx", "music"]) -> float:
	var font: Font = node.get_theme_font("font", "Label")
	var label_w := 0.0
	for kind: String in kinds:
		label_w = maxf(label_w, font.get_string_size(volume_label(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x)
	return total - 18.0 - ceilf(label_w)


## A volume label + slider wired to Progress.volume ("sfx": plays a bubble so you can hear the level) or
## Progress.music_volume ("music"), inside a goo-framed box like a button's (the slider is the box's
## "slider" meta). The label takes the room volume_slider_width left it, so two boxes line up.
static func make_volume_slider(width := 90.0, kind := "sfx") -> PanelContainer:
	var box := PanelContainer.new()
	var style := GooBox.make_button("normal")
	# The 10 px slider fills the face between the goo bands (2 / 1 in English: 13 tall); the box is
	# button_h() tall like its neighbours, the label's taller line / accents taking the extra rows.
	var extra := button_h() - maxi(10, line_h())
	style.content_margin_top = maxi(1, extra - 1)
	style.content_margin_bottom = extra - maxi(1, extra - 1)
	if line_h() >= 10:  # (a taller script's label is the tallest thing in the box: a button's margins)
		var margins := button_v_margins()
		style.content_margin_top = margins.x
		style.content_margin_bottom = margins.y
	style.content_margin_left = 6  # clear of the goo at the sides
	style.content_margin_right = 6
	box.add_theme_stylebox_override("panel", style)
	add_touch_target(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_theme_constant_override("separation", 6)
	# i18n: max 60px, 1 line (the slider shrinks to fit: Controls measures it)
	var label := make_label(volume_label(kind), FONT, TEXT_DIM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(width, 10)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	var progress: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Progress")
	var music := kind == "music"
	slider.value = (progress.music_volume if music else progress.volume) if progress else 0.8
	var setter := "set_music_volume" if music else "set_volume"
	var dragging := [false]  # applied live while dragging, saved once on release
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		dragging[0] = false
		if progress:
			progress.call(setter, slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		if progress:
			progress.call(setter, value, not dragging[0])
		var sfx := slider.get_node_or_null("/root/Sfx")
		if sfx and not music:
			sfx.play("click"))
	row.add_child(slider)
	box.set_meta("slider", slider)
	return box


## Idle slime preview in the given color (2 = double size).
static func make_slime_preview(color: Color, scale := 1, rainbow := false, jelly: Variant = null, clock := false) -> AnimatedSprite2D:
	var preview := AnimatedSprite2D.new()
	preview.sprite_frames = Slime.load_sprite_frames()
	preview.material = Skins.make_material(color, rainbow, clock)
	if jelly != null:
		(preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if jelly else 0.0)
	preview.scale = Vector2(scale, scale)
	preview.play("idle")
	if clock:
		Stopwatch.attach(preview, true)
	return preview


## Run time as m:ss.s (e.g. 1:02.3).
static func format_time(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


## Changes screens behind a goo wipe (instantly when the Transition autoload isn't there).
static func go(tree: SceneTree, scene: String) -> void:
	var transition := tree.root.get_node_or_null("Transition")
	if transition:
		transition.go(scene)
	else:
		tree.change_scene_to_file(scene)


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0), GOLD)
	box.set_expand_margin_all(1)
	return box


static func _box(color: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
		box.draw_center = false
	return box
