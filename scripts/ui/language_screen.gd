extends Control

## LANGUAGE page (opened from SETTINGS, only while Economy.languages_on(); docs/i18n/plan.md section 6).
## One button per supported language (Lang.LOCALES, in that fixed order), each written in its own
## script with its own font (lang().native_font), never translated, so a player stuck in a language
## they can't read still finds theirs. The current one is marked with UIKit.set_selected. Picking one
## saves it (lang().pick: the only place [settings] language is written) and reloads this page in
## the new language. BACK or Esc / B returns to SETTINGS.
## Layout: a 3 x 6 grid of 96 px buttons, 8 px apart (3 x 96 + 2 x 8 = 304, L8 / R8). Each row is as
## tall as the tallest script in it needs (Lang.metrics(code).button_h: 16 for the accented Latin
## and Cyrillic rows, 16 CJK, 19 Thai, 21 Devanagari), so every name fits in every language; 4 px
## between rows (UIKit.GAP_M; GAP_S where the current locale's taller title and BACK leave less room:
## row_gap). Uniform rows of 21 would not leave room for a Hindi / Thai / Arabic BACK (as tall as its
## own script's button) under them. The grid is centred between the title's line box
## (UIKit.title_bottom()) and BACK, the standard one (UIKit.add_back_button: (4, 164) in English, wider
## for a longer word, taller and higher for a taller script, always ending on row 176).
## Names in a script the slimy font has are drawn with a copy of it WITHOUT the current locale's
## fallback (with Hindi on, pixel.fnt's line box is Devanagari's 19 px and ENGLISH would need 21).

## The Language autoload's script, for its static tables (codes, names, metrics); the autoload node
## itself (current locale, fonts, pick) is lang().
const Lang := preload("res://scripts/language.gd")
const SETTINGS_SCENE := "res://scenes/controls.tscn"
const SCENE := "res://scenes/language.tscn"
const COLUMNS := 3
const BUTTON_W := 96
const COL_GAP := UIKit.GAP_L
const ROW_GAP := UIKit.GAP_M
## The space the grid is centred in starts under the title's line box (English: 22).
const AREA_TOP := UIKit.TITLE_Y + 20

## Thai and Devanagari keep empty descent room under most letters, so their ink sits above the line
## box's centre; their buttons move the text down by shifting this much content margin from the
## bottom to the top (the minimum height stays the same). Measured on rendered buttons (--write-movie):
## Thai moves 1 px for 1; Devanagari's line, about as tall as its content box, moves 1 px for 2. Both
## then have their ink within 0.5 px of the button's middle (docs/ui-rules.md section 4).
const INK_NUDGE := {"th": 1, "hi": 2}

## code -> its button.
var buttons := {}
var back_button: Button
## Where the grid sits (grid_rect, between the title and BACK).
var grid: Rect2
## The slimy font without fallbacks (see above), shared by this page's Latin / Cyrillic names.
var _plain_font: FontFile


## The Language autoload.
static func lang() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Language")


static func row_count() -> int:
	return ceili(Lang.codes().size() / float(COLUMNS))


## Each row's height: the tallest button its languages' scripts need (Lang.metrics), at least
## UIKit.BUTTON_H.
static func row_heights() -> Array[int]:
	var codes := Lang.codes()
	var out: Array[int] = []
	for row in row_count():
		var h := UIKit.BUTTON_H
		for i in range(row * COLUMNS, mini((row + 1) * COLUMNS, codes.size())):
			h = maxi(h, int(Lang.metrics(codes[i]).button_h))
		out.append(h)
	return out


## The grid's rect: centred on the screen, and vertically between the title's line box and `back_top`.
static func grid_rect(back_top: float = UIKit.bottom_row_y()) -> Rect2:
	var w := COLUMNS * BUTTON_W + (COLUMNS - 1) * COL_GAP
	var gap := row_gap(back_top)
	var h := (row_count() - 1) * gap
	for row_h in row_heights():
		h += row_h
	var top := UIKit.title_bottom()  # AREA_TOP in English
	return Rect2(UIKit.center_x(w), UIKit.center_x(h, top, back_top - top), w, h)


## The gap between rows: ROW_GAP, or GAP_S when the grid would not keep ROW_GAP clear of the title's
## line box and of BACK (the current locale's taller title / BACK: Traditional Chinese, Devanagari, vi).
static func row_gap(back_top: float = UIKit.bottom_row_y()) -> int:
	var h := (row_count() - 1) * ROW_GAP
	for row_h in row_heights():
		h += row_h
	return ROW_GAP if h + 2 * ROW_GAP <= back_top - UIKit.title_bottom() else UIKit.GAP_S


## The font a language's name is drawn in: its script's fallback over the slimy font
## (lang().native_font), or for Latin / Cyrillic the slimy font with no fallback at all.
func name_font(code: String) -> Font:
	if lang().fallback_font(code) != null:
		return lang().native_font(code)
	if _plain_font == null:
		_plain_font = UIKit.plain_font("", UIKit.FONT, true) as FontFile  # (kept: the cache holds it weakly)
	return _plain_font


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("language.title", "LANGUAGE"))  # i18n: max 296px, 16 px font
	back_button = UIKit.add_back_button(self, _back)  # (back to SETTINGS)
	grid = grid_rect(back_button.position.y)
	var gap := row_gap(back_button.position.y)
	var heights := row_heights()
	var codes := Lang.codes()
	var y := grid.position.y
	for i in codes.size():
		var code: String = codes[i]
		var row := i / COLUMNS
		var h := heights[row]
		var button := UIKit.make_button(Lang.native_name(code), func() -> void: _pick(code), Vector2(BUTTON_W, h))
		button.add_theme_font_override("font", name_font(code))
		# Each name in its own direction (Arabic right to left inside its button), never reversed by hand.
		button.text_direction = Control.TEXT_DIRECTION_RTL if code in Lang.RTL_LOCALES else Control.TEXT_DIRECTION_LTR
		button.set_meta("code", code)
		UIKit.set_selected(button, code == lang().locale)
		fit_styles(button, code == lang().locale, INK_NUDGE.get(code, 0))
		add_child(button)
		button.size = Vector2(BUTTON_W, h)
		button.position = Vector2(grid.position.x + (i % COLUMNS) * (BUTTON_W + COL_GAP), y)
		if i % COLUMNS == COLUMNS - 1:
			y += h + gap
		buttons[code] = button
	_link_focus(codes)
	var current: Button = buttons.get(lang().locale, buttons[codes[0]])
	current.grab_focus()


## The button's goo styles with 1 px content margins above and below instead of 3: a button's minimum
## height is its line box plus those margins, and a line in a tall script (Devanagari 19 px, Thai 17,
## and every line while such a locale's fallback is on the slimy font) would otherwise grow the button
## past the row. The row height (Lang.metrics button_h) already leaves the goo its room. Same
## looks as UIKit.make_button / UIKit.set_selected. `nudge`: INK_NUDGE (the bottom margin may go
## below 0, which only lets the text box reach 1 px into the goo band it never draws on).
static func fit_styles(button: Button, selected: bool, nudge := 0) -> void:
	for slot: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var look := "pressed" if slot == "hover_pressed" else slot
		if selected and slot in ["normal", "hover"]:
			look = "selected"
		var box := UIKit.button_style(look)
		box.content_margin_top = 1 + nudge
		box.content_margin_bottom = 1 - nudge
		button.add_theme_stylebox_override(slot, box)


## Arrows / D-pad / stick: left and right wrap inside a row, up stops at the top row, down from the
## bottom row (or from a column with no button under it) goes to BACK, and BACK goes back up.
func _link_focus(codes: Array[String]) -> void:
	var rows := row_count()
	for i in codes.size():
		var button: Button = buttons[codes[i]]
		var row := i / COLUMNS
		var row_start := row * COLUMNS
		var row_len := mini(COLUMNS, codes.size() - row_start)
		var left: Button = buttons[codes[row_start + (i - row_start + row_len - 1) % row_len]]
		var right: Button = buttons[codes[row_start + (i - row_start + 1) % row_len]]
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(buttons[codes[i - COLUMNS]] if row > 0 else button)
		var below := i + COLUMNS
		button.focus_neighbor_bottom = button.get_path_to(buttons[codes[below]] if below < codes.size() else back_button)
		button.focus_previous = button.get_path_to(buttons[codes[i - 1]] if i > 0 else back_button)
		button.focus_next = button.get_path_to(buttons[codes[i + 1]] if i + 1 < codes.size() else back_button)
	var bottom_left: Button = buttons[codes[(rows - 1) * COLUMNS]]
	back_button.focus_neighbor_top = back_button.get_path_to(bottom_left)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
	back_button.focus_previous = back_button.get_path_to(buttons[codes[codes.size() - 1]])
	back_button.focus_next = back_button.get_path_to(buttons[codes[0]])


## Saves the choice (also when it is already the language in use, e.g. one that came from the OS) and
## rebuilds this page in it when it changed (every text is built in _ready, in the new locale).
func _pick(code: String) -> void:
	var changed: bool = code != lang().locale
	if lang().pick(code) and changed:
		UIKit.go(get_tree(), SCENE)


func _back() -> void:
	UIKit.go(get_tree(), SETTINGS_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
