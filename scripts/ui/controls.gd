extends Control

## Settings: sound on/off, volume, motion, fog, fullscreen, a CONTROLS button (the key-remapping
## page, scripts/ui/key_controls.gd), SAVE CODE (copy your whole save as a code to back it up, or paste one to load it: the way to
## keep browser progress safe or move it to another browser or the Windows version), and
## RESET PROGRESS, which asks for a CONFIRM before wiping the save.

const KEY_CONTROLS_SCENE := "res://scenes/key_controls.tscn"
## The LANGUAGE page (scripts/ui/language_screen.gd), reached from the gated LANGUAGE button.
const ACHIEVEMENTS_SCENE := "res://scenes/achievements.tscn"
const BOARDS_SCENE := "res://scenes/boards.tscn"
const LANGUAGE_SCENE := "res://scenes/language.tscn"
const LanguageScreen := preload("res://scripts/ui/language_screen.gd")
## What the SAVE CODE panel says: a code from an older build (it never loads), a successful copy, and
## (web only) the browser refusing to copy, so the code is shown in the browser's own prompt.

static func old_code_message() -> String:
	# i18n: status line in the SAVE CODE panel, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	return Loc.t("savecode.old_version", "THAT CODE IS FROM AN OLD VERSION")


static func copied_message() -> String:
	# i18n: status line in the SAVE CODE panel, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	return Loc.t("savecode.copied", "COPIED! KEEP IT SOMEWHERE SAFE")


static func copy_by_hand_message() -> String:
	# i18n: status line in the SAVE CODE panel (web, browser refused to copy), max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	return Loc.t("savecode.copy_by_hand", "COPY THE CODE FROM THE POP-UP")


## Layout: two even columns on one grid. Left: SOUND, SFX and MUSIC volume, MOTION, FOG. Right: FULLSCREEN,
## CONTROLS, SAVE CODE, and (only while Economy.languages_on(), docs/i18n/plan.md section 6) LANGUAGE
## mirroring FOG. BACK bottom left, the destructive RESET PROGRESS bottom right.
## English: columns COL_W wide at x COL_L / COL_R, headings HEADING_GAP under the title's line box (y 27),
## rows ROW_GAP apart from FIRST_ROW (38, 58, 78, 98, 118). Other locales (_plan_page, docs/ui-rules.md
## section 10): both columns widen alike when a text needs it (staying centred), rows follow the
## locale's button_h() / line_h() under its title_bottom(), and the row gap closes to GAP_M / GAP_S only
## when the five rows would not end above the bottom row otherwise (Devanagari).
const ROWS := 5


## The grid's rows: one more for CALM DARK while the lurkers test (Economy.LURKERS_TEST, BM-01) is on.
static func rows() -> int:
	return ROWS + (1 if Economy.lurkers_on() and not Demo.on() else 0)
const COL_W := 120
const COL_L := 36
const COL_R := COL_L + COL_W + UIKit.GAP_L  # 164
const FIRST_ROW := 38
const ROW_STEP := 20
const HEADING_GAP := 5
const ROW_GAP := ROW_STEP - UIKit.BUTTON_H  # 7
## RESET PROGRESS on the bottom row, mirroring BACK (its text + the 4 px margins, even).
const RESET_SIZE := Vector2(92, UIKit.BUTTON_H)
## The VOLUME box is 6 + label + 6 + slider + 6 wide, which must equal the column: the slider width is
## UIKit.volume_slider_width (measured from the translated label). A longer label widens both columns
## (as a longer button text does) so the slider keeps English's length, VOLUME_SLIDER_MIN (fix pass R2:
## LAUTSTÄRKE left the German slider 42 px), while the two columns fit the screen's EDGE.
const VOLUME_SLIDER_MIN := 66
const VOLUME_BOX_EXTRA := 18
## The panels (SAVE CODE, RESET confirm): text keeps PANEL_TEXT_PAD from the panel's sides, and a panel
## stays inside the screen's EDGE (at most 312 wide, 172 tall).
const PANEL_TEXT_PAD := UIKit.PANEL_PAD
const PANEL_MAX := Vector2(320 - 2 * UIKit.EDGE, 180 - 2 * UIKit.EDGE)

## This locale's page grid (_plan_page; the constants above in English).
var col_w := COL_W
var col_x: Array[int] = [COL_L, COL_R]
var heading_y := FIRST_ROW - 11
var first_row := FIRST_ROW
var row_step := ROW_STEP
## The column width the VOLUME label + a VOLUME_SLIDER_MIN slider need (_plan_page).
var volume_col_w := COL_W
## The page's controls a panel hid while it is open (_cover_page): see there.
var _covered: Array[CanvasItem] = []

var sound_button: Button
var volume_slider: HSlider
var music_slider: HSlider
var fullscreen_button: Button
## Phones and tablets (Platform.has_vibration): VIBRATION ON / OFF in FULLSCREEN's cell (fullscreen_button null).
var vibration_button: Button
## REDUCE MOTION (no shake, kick or hit-stop) and FOG brightness (DARK / NORMAL / BRIGHT).
var motion_button: Button
var fog_button: Button
var level_music_button: Button
## RELAXED (no idle drain, no medals; Progress.relaxed) under SAVE CODE / TRAINING, with a hint line under it.
var relaxed_button: Button
var relaxed_hint: Label
## LURKERS (ON = lurkers in every normal random maze, Progress.lurkers_random; hard mode always has them): the grid's extra row, only with the lurkers test on.
var calm_button: Button
var controls_button: Button
var reset_button: Button
## ACHIEVEMENTS, top right (null in the demo).
var achievements_button: Button
var boards_button: Button  # (BM-03, only while Economy.boards_on())
## Only with the tutorial gate on (Economy.tutorial_on()): replays the training maze, writes nothing.
var training_button: Button
var reset_confirm: Control
var confirm_button: Button
var cancel_button: Button
var save_code_button: Button
## The LANGUAGE button (null with the languages gate off): a globe and the current language's own name.
var language_button: Button
var code_panel: Control
## The save code of your progress (read-only, to copy) and the box to paste a code into.
var code_out: LineEdit
var code_in: LineEdit
var code_status: Label
var paste_button: Button
## In the browser: the page's paste event and the clipboard read, kept alive while they're in use.
var _web_paste_event: JavaScriptObject
var _web_read_done: JavaScriptObject
var _web_read_failed: JavaScriptObject
var _web_copy_done: JavaScriptObject
var _web_copy_failed: JavaScriptObject
var copy_button: Button
var load_button: Button
## LOAD has been pressed once on a working code: the next press replaces the progress.
var load_armed := false
## The page's controls kept out of focus while the SAVE CODE or RESET panel is open (UIKit.lock_focus):
## arrows / Tab stay inside the panel, so a second panel can't be opened on top.
var _focus_lock := {}


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("settings.title", "SETTINGS"))  # i18n: max 296px, 16 px font
	_plan_page()
	# i18n: column headings, max 120px, 1 line
	_section(Loc.t("settings.options", "OPTIONS"), col_x[0], heading_y)
	_section(Loc.t("settings.more", "MORE"), col_x[1], heading_y)
	sound_button = _column_button(_cell(0, 0), _toggle_sound)
	volume_slider = _volume_row(1, "sfx")
	music_slider = _volume_row(2, "music")
	motion_button = _column_button(_cell(0, 3), _toggle_motion)
	fog_button = _column_button(_cell(0, 4), _cycle_fog)
	if Platform.has_vibration():  # (phones: VIBRATION in FULLSCREEN's cell; the web's TAP TO PLAY goes full screen)
		vibration_button = _column_button(_cell(1, 0), _toggle_vibration)
	else:
		fullscreen_button = _column_button(_cell(1, 0), func() -> void: Progress.toggle_fullscreen())
		fullscreen_button.disabled = not Progress.fullscreen_available()  # (iPhone Safari: no Fullscreen API)
	relaxed_button = _column_button(_cell(1, 4), _toggle_relaxed)
	# i18n: hint under the RELAXED button, max 296px (about 49 characters), 1 line (centred under both columns)
	relaxed_hint = UIKit.make_label(Loc.t("settings.relaxed.hint", "RELAXED: MORE SLIME, NO MEDALS OR TICKETS"), UIKit.FONT, UIKit.TEXT)
	add_child(relaxed_hint)
	relaxed_hint.size = Vector2(UIKit.SCREEN.x, UIKit.line_h())
	relaxed_hint.position = Vector2(0, minf(_cell(1, rows() - 1).y + UIKit.button_h() + UIKit.GAP_XS, UIKit.bottom_row_y() - UIKit.line_h() - 1))  # (BUG4-05: never over the bottom row at touch pitch)
	relaxed_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relaxed_hint.visible = false  # (only while the RELAXED button has focus or the pointer over it)
	for sig in [relaxed_button.focus_entered, relaxed_button.mouse_entered, relaxed_button.focus_exited, relaxed_button.mouse_exited]:
		sig.connect(_update_relaxed_hint)
	if rows() > ROWS:
		calm_button = _column_button(_cell(1, ROWS), _toggle_calm)
		for sig in [calm_button.focus_entered, calm_button.mouse_entered, calm_button.focus_exited, calm_button.mouse_exited]:
			sig.connect(_update_relaxed_hint)
	_refresh_sound()
	_refresh_display_options()

	# i18n: column buttons, max 112px (button 120 wide, 4 px margins), 1 line
	controls_button = _column_button(_cell(1, 1), _open_controls, Loc.t("settings.controls", "CONTROLS"))
	save_code_button = _column_button(_cell(1, 2), _open_codes, Loc.t("settings.save_code", "SAVE CODE"))
	if Economy.languages_on():
		_build_language_button()
	UIKit.add_back_button(self)  # the standard BACK, bottom left like every screen
	if Economy.ACHIEVEMENTS and not Demo.on():
		_build_achievements_button()
	# The destructive one, alone at the bottom right, away from the everyday buttons.
	# i18n: max 84px (RESET_SIZE 92 wide), grows to 160px (button_size: the button widens), 1 line
	var reset_text := Loc.t("settings.reset", "RESET PROGRESS")
	reset_button = UIKit.make_button(reset_text, _ask_reset, UIKit.button_size(reset_text, int(RESET_SIZE.x)))
	UIKit.note_text_w(reset_button, [reset_text], int(RESET_SIZE.x))
	add_child(reset_button)
	reset_button.size = reset_button.custom_minimum_size
	UIKit.place_bottom_row(reset_button, 1)
	if Economy.tutorial_on():
		# The MORE column under SAVE CODE (docs/tutorial/design.md section 2), beside FOG: a full 4 x 2 grid.
		# With the language test on, LANGUAGE has that cell: then centred in the bottom row instead.
		# i18n: column button, max 112px (button 120 wide, 4 px margins); in the bottom row (languages on) it grows with the text, 1 line
		var training_text := Loc.t("settings.training", "TRAINING")
		if language_button == null:
			training_button = _column_button(_cell(1, 3), _start_training, training_text)
		else:
			training_button = UIKit.make_button(training_text, _start_training, UIKit.button_size(training_text, 56))
			UIKit.note_text_w(training_button, [training_text], 56)
			add_child(training_button)
			training_button.size = training_button.custom_minimum_size
			UIKit.place_bottom_row(training_button, 0)  # (centred between BACK and RESET PROGRESS; left of LEVEL MUSIC when that is there)
	if Economy.LEVEL_MUSIC:
		# IMP-05: centred in the bottom row, in both modes (with the language test on, TRAINING steps left of it)
		# i18n: bottom-row button, grows with the text (max 120px), 1 line; the two states are whole strings
		var lm_text := Loc.t("settings.level_music.on", "LEVEL MUSIC: ON")
		level_music_button = UIKit.make_button(lm_text, _toggle_level_music, UIKit.button_size(lm_text, 104))
		UIKit.note_text_w(level_music_button, [lm_text, Loc.t("settings.level_music.off", "LEVEL MUSIC: OFF")], 104)
		add_child(level_music_button)
		level_music_button.size = level_music_button.custom_minimum_size
		UIKit.place_bottom_row(level_music_button, 0)
		if training_button != null and language_button != null:
			training_button.position.x = level_music_button.position.x - UIKit.GAP_S - training_button.size.x
		_refresh_display_options()
	if Economy.ACHIEVEMENTS and not Demo.on() and Economy.boards_on():
		_build_boards_button()  # (IMP4-03: the bottom row, right of BACK; the corner keeps ACHIEVEMENTS alone)
	sound_button.grab_focus()
	_build_reset_confirm()
	_build_code_panel()


## This locale's grid (English: the constants). Columns: COL_W, or every text + its 4 px margins when
## one needs more (both columns alike, the pair re-centred: Spanish PANTALLA COMPLETA), or the VOLUME
## label + a VOLUME_SLIDER_MIN slider (German LAUTSTÄRKE). Rows: the
## headings HEADING_GAP under the title's line box, the first row 4 px under a heading's line, rows
## ROW_GAP apart; GAP_M, then GAP_S, when ROWS rows would not end GAP_M above the bottom row.
func _plan_page() -> void:
	var widest := 0
	for text in column_texts():
		widest = maxi(widest, UIKit.text_w(text))
	col_w = maxi(COL_W, widest + 2 * UIKit.BUTTON_TEXT_PAD)
	var label_w := ceili(COL_W - VOLUME_BOX_EXTRA - UIKit.volume_slider_width(self, COL_W))  # (the VOLUME label)
	var volume_col := VOLUME_BOX_EXTRA + label_w + VOLUME_SLIDER_MIN
	var max_col := floori((UIKit.SCREEN.x - 2 * UIKit.EDGE - UIKit.GAP_L) / 2.0)
	volume_col_w = mini(volume_col, max_col)
	col_w = maxi(col_w, volume_col_w)
	var left := int(UIKit.center_x(2 * col_w + UIKit.GAP_L))
	col_x = [left, left + col_w + UIKit.GAP_L]
	heading_y = UIKit.title_bottom() + HEADING_GAP
	first_row = heading_y + UIKit.line_h() + UIKit.GAP_M
	var bottom := UIKit.bottom_row_y() - UIKit.GAP_M
	var gaps: Array[int] = [ROW_GAP, UIKit.GAP_M, UIKit.GAP_S]
	if UIKit.touch_active():
		# IMP3-04: a 22 px pitch (TOUCH_MIN) for every row, headings and first row pulled up to make the room; a
		# script too tall for it falls back to the usual rows below
		var tight := UIKit.title_bottom() + 3
		var tight_first := tight + UIKit.line_h() + 2
		var touch_step := maxi(UIKit.TOUCH_MIN, UIKit.button_h() + ROW_GAP)
		if tight_first + (rows() - 1) * touch_step + UIKit.button_h() <= bottom + UIKit.GAP_M - 2:
			heading_y = tight
			first_row = tight_first
			row_step = touch_step
			return
	for gap: int in gaps:
		row_step = UIKit.button_h() + gap
		if first_row + (rows() - 1) * row_step + UIKit.button_h() <= bottom:
			break


## A volume box ("sfx" / "music") in the left column's `row`; returns its slider.
func _volume_row(row: int, kind: String) -> HSlider:
	var box := UIKit.make_volume_slider(UIKit.volume_slider_width(self, col_w), kind)
	add_child(box)  # (in the tree first, so it is measured in the theme's font)
	box.position = _cell(0, row)
	box.custom_minimum_size = Vector2(col_w, UIKit.button_h())
	box.size = Vector2(col_w, UIKit.button_h())
	return box.get_meta("slider")


## Top-left corner of a grid cell (column 0 = left, 1 = right).
func _cell(column: int, row: int) -> Vector2:
	return Vector2(col_x[column], first_row + row * row_step)


func _column_button(at: Vector2, on_press: Callable, text := "") -> Button:
	var button := UIKit.make_button(text, on_press, Vector2(col_w, UIKit.button_h()))
	# (both columns one width: every text they can show, or the VOLUME box's)
	UIKit.note_text_w(button, column_texts(), maxi(COL_W, volume_col_w))
	button.position = at
	add_child(button)
	return button


## A small dim heading over a column.
func _section(text: String, x: int, y: int) -> void:
	var label := UIKit.make_label(text, UIKit.FONT, UIKit.TEXT_DIM)
	label.position = Vector2(x, y)
	add_child(label)


## The LANGUAGE button in the free cell under SAVE CODE: a globe plus the current language's name in
## its own script (Language.native_name, never translated), so a player stuck in a language they can't
## read still finds it. As tall as the current script's button (UIKit.button_h(); 13 for Latin), on its
## row like the other column buttons. Only built with the gate on.
func _build_language_button() -> void:
	var language := LanguageScreen.lang()
	var code: String = language.locale
	var h: int = maxi(UIKit.button_h(), int(LanguageScreen.Lang.metrics(code).button_h))
	var at := _cell(1, 3)
	language_button = UIKit.make_button("", _open_language, Vector2(col_w, h))
	LanguageScreen.fit_styles(language_button, false)
	language_button.position = at
	add_child(language_button)
	language_button.size = Vector2(col_w, h)
	# (the current language's name: in the font every other button's text uses, so its line sits where theirs do)
	var font: Font = UIKit.font_for() if code == UIKit.locale() else language.native_font(code)
	var name := LanguageScreen.Lang.native_name(code)
	var text_w := int(font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FONT).x)
	# Globe ink (7 px) + 4 px clear + the name (its 1 px leading letter gap inside the label), as one
	# centred group.
	var group_w := 7 + 3 + text_w
	var x := roundi((col_w - group_w) / 2.0)
	# The name's line box where the theme puts every button's text (UIKit.button_v_margins: under the
	# accents' rows, the 3 drip rows kept below), so it shares the column's baseline (centred on the box
	# it sat 2 px high with accents, 3 in Vietnamese: fix pass F3b). The globe on the letter body (the
	# line box with the slimy font; centred on the button in a taller script, as before).
	var line_top := UIKit.button_v_margins().x if h == UIKit.button_h() else floori((h - UIKit.line_h()) / 2.0)
	var globe := UIKit.make_icon("globe")
	globe.position = Vector2(x, line_top if not UIKit.tall_script() else floori((h - 7) / 2.0))
	language_button.add_child(globe)
	var label := UIKit.make_label(name)
	label.add_theme_font_override("font", font)
	label.text_direction = Control.TEXT_DIRECTION_RTL if code in LanguageScreen.Lang.RTL_LOCALES else Control.TEXT_DIRECTION_LTR
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))  # (button text has no shadow)
	language_button.add_child(label)
	# The globe takes the name's color (SkinText recolors the label from the skin, rainbow included).
	label.theme_changed.connect(func() -> void: globe.modulate = label.get_theme_color("font_color"))
	globe.modulate = label.get_theme_color("font_color")
	label.position = Vector2(x + 10, line_top)
	label.size = Vector2(text_w, UIKit.line_h())
	language_button.set_meta("code", code)


## ACHIEVEMENTS in the top right corner (IMP2-02, BUG2-03): the way to the goals page on a phone (iOS has no back
## key for the hub menu's entry), also by pad and keyboard (focus moves to it by position). BACK returns to the hub.
func _build_achievements_button() -> void:
	# i18n: settings button (top right corner), max 90px, grows with the text, 1 line; opens the achievements page
	var text := Loc.t("hub.menu.achievements", "ACHIEVEMENTS")
	achievements_button = UIKit.make_button(text, func() -> void:
		(load("res://scripts/ui/achievements_screen.gd") as GDScript).back_scene = "res://scenes/controls.tscn"  # (BACK returns to SETTINGS)
		UIKit.go(get_tree(), ACHIEVEMENTS_SCENE), UIKit.button_size(text, 90))
	UIKit.note_text_w(achievements_button, [text], 90)
	add_child(achievements_button)
	achievements_button.size = achievements_button.custom_minimum_size
	var safe := UIKit.safe_rect()
	achievements_button.position = Vector2(safe.end.x - UIKit.EDGE - achievements_button.size.x, safe.position.y + UIKit.EDGE)


## BOARDS in the bottom row beside BACK (BM-03, IMP4-03): the daily / weekly top times and the ghost toggle; BACK returns to SETTINGS.
func _build_boards_button() -> void:
	# i18n: settings button (bottom row, right of BACK), max 90px, grows with the text, 1 line; opens the boards page
	var text := Loc.t("settings.boards", "BOARDS")
	boards_button = UIKit.make_button(text, func() -> void:
		(load("res://scripts/ui/boards_screen.gd") as GDScript).back_scene = "res://scenes/controls.tscn"
		UIKit.go(get_tree(), BOARDS_SCENE), UIKit.button_size(text, 90))
	UIKit.note_text_w(boards_button, [text], 90)
	add_child(boards_button)
	boards_button.size = boards_button.custom_minimum_size
	UIKit.place_bottom_row(boards_button, -1)
	var back := UIKit.back_size("BACK")
	boards_button.position.x += back.x + UIKit.GAP_S


## TRAINING replays the maze (replay = true: nothing is saved, docs/tutorial/design.md section 8).
func _start_training() -> void:
	Progress.start_training(true)


func _open_language() -> void:
	UIKit.go(get_tree(), LANGUAGE_SCENE)


func _open_controls() -> void:
	UIKit.go(get_tree(), KEY_CONTROLS_SCENE)


## The SAVE CODE panel: your progress as a code to copy, and a box to paste a code into and load.
## Loading asks for a second press, since it replaces the progress you have.
## English: a 296x150 panel at (12, 14): the title at 20, each hint one line pitch (12) over the row it
## describes (code box + COPY at 58, code box + PASTE + LOAD at 93, 10 px between the two sections), the
## status line at 114, CLOSE at 140, 11 px under it. Other locales: the same column from the locale's
## title / line / button heights (_code_layout), re-centred on the English panel's middle.
func _build_code_panel() -> void:
	code_panel = Control.new()
	code_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(code_panel)
	code_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	code_panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.85)
	code_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# i18n: panel title, max 270px, 16 px font; grows to 296px, steps down to 8 px past that
	var title_text := Loc.t("savecode.title", "SAVE CODE")
	# i18n: max 270px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	var copy_hint := Loc.t("savecode.copy_hint", "COPY THIS CODE TO BACK UP YOUR PROGRESS")
	# i18n: SAVE CODE panel buttons (COPY, PASTE, LOAD, CLOSE), max 56px (64 wide, 4 px margins), 1 line
	var copy_text := Loc.t("savecode.copy", "COPY")
	# i18n: max 270px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	var paste_hint := Loc.t("savecode.paste_hint", "TO LOAD A SAVE, PASTE ITS CODE HERE")
	# i18n: max 56px, 1 line
	var paste_text := Loc.t("savecode.paste", "PASTE")
	# i18n: max 56px, 1 line
	var load_text := Loc.t("savecode.load", "LOAD")
	# i18n: max 56px, 1 line
	var close_text := Loc.t("savecode.close", "CLOSE")
	var plan := _code_layout(title_text, [copy_hint, paste_hint])
	var top: int = plan.rect.position.y
	var tops: Array = plan.tops
	var row_h := UIKit.button_h()
	code_panel.set_meta("panel_rect", plan.rect)
	UIKit.add_panel(code_panel, plan.rect)
	var title := UIKit.make_label(title_text, plan.title_size, UIKit.GOLD)
	_panel_label(code_panel, title, top + tops[0], top + tops[0] + plan.heights[0])
	# Each line sits one line pitch (12) over the row it describes; 10 px between the two sections.
	_panel_text(code_panel, copy_hint, UIKit.TEXT_DIM, plan, top + tops[1], plan.heights[1])
	code_out = _code_box(true)
	code_out.position = Vector2(24, top + tops[2])
	copy_button = UIKit.make_button(copy_text, _copy_code, Vector2(64, row_h))
	copy_button.position = Vector2(232, top + tops[2])
	code_panel.add_child(copy_button)
	_panel_text(code_panel, paste_hint, UIKit.TEXT_DIM, plan, top + tops[3], plan.heights[3])
	code_in = _code_box(false)
	code_in.position = Vector2(24, top + tops[4])
	code_in.custom_minimum_size = Vector2(136, row_h)  # (before size: a size under the old minimum won't stick)
	code_in.size = Vector2(136, row_h)
	paste_button = UIKit.make_button(paste_text, _paste_code, Vector2(64, row_h))
	paste_button.position = Vector2(164, top + tops[4])
	code_panel.add_child(paste_button)
	code_in.placeholder_text = Progress.SAVE_CODE_PREFIX + "..."
	code_in.text_changed.connect(func(_text: String) -> void:
		load_armed = false
		code_status.text = "")
	load_button = UIKit.make_button(load_text, _load_code, Vector2(64, row_h))
	load_button.position = Vector2(232, top + tops[4])
	code_panel.add_child(load_button)
	code_status = _panel_text(code_panel, "", UIKit.TEXT, plan, top + tops[5], plan.heights[5])
	var close := UIKit.make_button(close_text, _close_codes, Vector2(64, row_h))
	close.position = Vector2(128, top + tops[6])
	code_panel.add_child(close)


## The SAVE CODE panel's column for this locale: {rect, tops (of title, hint, row, hint, row, status,
## CLOSE from the panel's top), heights, title_size, font (the hints' / status's font, null = theme),
## lines (a text's lines: 2 where it is wider than the panel's text width), text_w}. English: the
## numbers above. The panel widens (up to PANEL_MAX.x) for a wider text, which wraps onto two lines
## when even that is too narrow. When the column is taller than PANEL_MAX.y, its gaps close to the
## spacing scale (status / CLOSE, bottom pad, the sections, status, title), then the hints and status
## take the script's smaller crisp size (Language.small_font: Devanagari 12 px), then the gaps close one
## step more (GAP_S), then the title takes the 8 px font (UIKit.fit_text's steps; never a fractional scale).
func _code_layout(title_text: String, hints: Array) -> Dictionary:
	var widest := UIKit.text_w(title_text, UIKit.FONT_BIG)
	var line_widest := 0
	for text: String in hints + status_texts():
		line_widest = maxi(line_widest, UIKit.text_w(text))
	var panel_w := clampi(maxi(widest, line_widest) + 2 * PANEL_TEXT_PAD, 296, int(PANEL_MAX.x))
	var text_w := panel_w - 2 * PANEL_TEXT_PAD
	var hint_lines := 1
	for text: String in hints:
		if UIKit.text_w(text) > text_w:
			hint_lines = 2
	var status_lines := 1
	for text in status_texts():
		if UIKit.text_w(text) > text_w:
			status_lines = 2
	var small := _small_font()
	var plan := {}
	# Steps: 0 the theme's font; 1 the smaller crisp font for the hints / status; 2 also the column's gaps
	# one scale step closer (GAP_S, fix pass R2: "keep the 16 px title by making room", the pseudo
	# locale's two-line hints dropped its title to 8 px); 3 the title in the 8 px font.
	for step in 4:
		if step == 1 and small == null:
			continue
		var font: Font = small if step >= 1 else null
		var title_size := UIKit.FONT if step == 3 or widest > text_w else UIKit.FONT_BIG
		var title_h := UIKit.title_h() if title_size == UIKit.FONT_BIG else _text_box(1, UIKit.TEXT_DRIP + 1, null)
		var hint_h := _text_box(hint_lines, UIKit.TEXT_DRIP + 1, font)
		var heights := [title_h, hint_h, UIKit.button_h(), hint_h, UIKit.button_h(), _text_box(status_lines, UIKit.TEXT_DRIP + 1, font), UIKit.button_h()]
		var top_pad := 6 + int(UIKit.metrics().title_above)
		var near := UIKit.GAP_S if step == 2 else UIKit.GAP_M
		var gaps := [[top_pad, top_pad], [6, near], [2, 2], [10, near], [2, 2], [8, near], [16, near], [11, UIKit.GAP_L]]
		var column := stack_column(heights, gaps, [6, 7, 3, 5, 1], int(PANEL_MAX.y))
		plan = {tops = column.tops, heights = heights, title_size = title_size, font = font, text_w = text_w,
			lines = {hint = hint_lines, status = status_lines}, h = column.h}
		if column.fits:
			break
	var h: int = plan.h
	var y := clampi(14 - floori((h - 150) / 2.0), UIKit.EDGE, int(UIKit.SCREEN.y) - UIKit.EDGE - h)
	plan.rect = Rect2(UIKit.center_x(panel_w), y, panel_w, h)
	return plan


## The current script's smaller crisp font (Language.small_font), or null.
func _small_font() -> Font:
	var language := get_node_or_null("/root/Language")
	if language == null or not language.get("active"):
		return null
	return language.small_font(UIKit.locale())


## The height a panel text of `lines` lines takes in `font` (null = the theme's): its line boxes and
## spacing, plus `extra` rows (the drips) for the slimy font's 7 px body (a taller script's line box
## holds its own marks).
static func _text_box(lines: int, extra: int, font: Font) -> int:
	if font == null:
		return UIKit.text_block_h(lines) + (0 if UIKit.tall_script() else extra)
	var line := ceili(font.get_height(UIKit.FONT))
	return lines * line + (lines - 1) * UIKit.line_spacing()


## Lays a panel's column out: `heights` top to bottom, `gaps[i]` = [gap, smallest gap] before item i
## (gaps[0] the top pad, the last one the bottom pad). While the column is taller than `max_h`, the
## gaps listed in `shrink_order` close towards their smallest, one after the other, only as far as
## needed. Returns {tops (each item's top), h (the whole column, pads included), fits}.
static func stack_column(heights: Array, gaps: Array, shrink_order: Array, max_h: int) -> Dictionary:
	var g: Array[int] = []
	var total := 0
	for pair: Array in gaps:
		g.append(int(pair[0]))
		total += int(pair[0])
	for item_h: int in heights:
		total += item_h
	for i: int in shrink_order:
		if total <= max_h:
			break
		var cut := mini(g[i] - int(gaps[i][1]), total - max_h)
		g[i] -= cut
		total -= cut
	var tops: Array[int] = []
	var y := 0
	for i in heights.size():
		y += g[i]
		tops.append(y)
		y += int(heights[i])
	return {tops = tops, h = total, fits = total <= max_h}


## A centred panel text (hint / status) at `top`, `h` tall: in the plan's font, wrapped inside the
## panel's text width when the plan gave it two lines.
func _panel_text(parent: Control, text: String, color: Color, plan: Dictionary, top: int, h: int) -> Label:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	if plan.font != null:
		label.add_theme_font_override("font", plan.font)
	_panel_label(parent, label, top, top + h)
	if h > _text_box(1, UIKit.TEXT_DRIP + 1, plan.font):
		label.autowrap_mode = UIKit.autowrap_mode()
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM  # (a one-line text stays over its row)
		var side: float = plan.rect.position.x + PANEL_TEXT_PAD
		label.offset_left = side
		label.offset_right = -side
	return label


func _code_box(read_only: bool) -> LineEdit:
	var box := LineEdit.new()
	box.custom_minimum_size = Vector2(204, UIKit.button_h())
	box.editable = not read_only
	box.select_all_on_focus = read_only
	box.add_theme_font_size_override("font_size", UIKit.FONT)
	box.material = UIKit.text_material()
	code_panel.add_child(box)
	if UIKit.tall_script():
		# A taller script's line box (the code itself is in the slimy glyphs) + the well's 2 / 1 margins
		# would be 1 px taller than the buttons beside it: 1 / 1 keeps the box button_h() tall.
		for slot: String in ["normal", "read_only", "focus"]:
			var well := box.get_theme_stylebox(slot).duplicate() as StyleBox
			var extra := maxi(0, UIKit.button_h() - UIKit.line_h())
			well.content_margin_top = ceili(extra / 2.0)
			well.content_margin_bottom = extra - ceili(extra / 2.0)
			box.add_theme_stylebox_override(slot, well)
	# Sized once in the themed tree (sized before, it keeps the default font's 22 px height).
	box.size = Vector2(204, UIKit.button_h())
	UIKit.add_touch_target(box)
	return box


func _panel_label(parent: Control, label: Label, top: int, bottom: int) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom


func _open_codes() -> void:
	code_out.text = Progress.save_code()
	code_in.text = ""
	code_status.text = ""
	load_armed = false
	code_panel.visible = true
	_cover_page(code_panel)
	_listen_for_web_paste()
	copy_button.grab_focus()
	_lock_page(code_panel)


## Fills the load box from the clipboard. In a browser Godot only sees text pasted into the page,
## and a Ctrl+V reaches the box before that text arrives, so there the clipboard is read through
## the browser instead (it may ask for permission). On itch (a cross-origin iframe without the
## `clipboard-read` permission) the browser refuses, and a phone has no Ctrl+V, so then the browser's
## own prompt asks for the code: its text field takes a long-press paste (web QA pass).
func _paste_code() -> void:
	if not Platform.has_js():
		_set_pasted(DisplayServer.clipboard_get())
		return
	var clipboard = JavaScriptBridge.get_interface("navigator").clipboard
	if clipboard == null or not clipboard.readText:
		_web_paste_by_hand()
		return
	_web_read_done = JavaScriptBridge.create_callback(func(args: Array) -> void: _set_pasted(str(args[0])))
	_web_read_failed = JavaScriptBridge.create_callback(func(_args: Array) -> void: _web_paste_by_hand())
	clipboard.readText().then(_web_read_done).catch(_web_read_failed)


func _web_paste_by_hand() -> void:
	var text = JavaScriptBridge.get_interface("window").prompt(Loc.t("savecode.prompt_paste", "Paste your Dry Trying save code:"), "")  # i18n: browser dialog, mixed case, any width
	if text is String and text.strip_edges() != "":
		_set_pasted(text)
	else:
		# i18n: {keys} = CMD+V or CTRL+V; status line, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
		var keys := "CMD+V" if OS.has_feature("web_macos") or OS.has_feature("web_ios") else "CTRL+V"
		code_status.text = Loc.t("savecode.click_box", "CLICK THE BOX AND PRESS {keys}", {keys = keys})


func _set_pasted(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		# i18n: status line, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
		code_status.text = Loc.t("savecode.nothing_to_paste", "NOTHING TO PASTE - COPY A CODE FIRST")
		return
	code_in.text = text
	code_in.caret_column = text.length()
	load_armed = false
	# i18n: status line, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	code_status.text = Loc.t("savecode.pasted", "PASTED - PRESS LOAD") if Progress.read_code(text) != null else _bad_code_message(text)
	load_button.grab_focus()


## In the browser, text pasted into the page (Ctrl+V, or paste from a phone's menu) goes straight
## into the load box while the SAVE CODE panel is open.
func _listen_for_web_paste() -> void:
	if not Platform.has_js() or _web_paste_event != null:
		return
	_web_paste_event = JavaScriptBridge.create_callback(func(args: Array) -> void:
		if not code_panel.visible:
			return
		var data = args[0].clipboardData
		if data:
			_set_pasted.call_deferred(str(data.getData("text"))))
	JavaScriptBridge.get_interface("window").addEventListener("paste", _web_paste_event)


func _exit_tree() -> void:
	if _web_paste_event != null:
		JavaScriptBridge.get_interface("window").removeEventListener("paste", _web_paste_event)
		_web_paste_event = null


func _close_codes() -> void:
	code_panel.visible = false
	_cover_page(null)
	UIKit.unlock_focus(_focus_lock)
	save_code_button.grab_focus()


## While a panel is open, the page's own controls under its rect are hidden (null `panel`: shown again).
## The panel's face is 92 % opaque over a 85 % dim, so they would only show as a faint ghost; in a
## taller or longer locale the panel's texts grow over them, and text over ghost text reads as clutter.
## English keeps its ghost: its panels' texts already avoid the page; only a label of the page whose
## box reaches the panel's goo band rows is hidden (the SETTINGS title's drips showed through SAVE CODE's
## top band: 4 px); the buttons' ghosts over the RESET panel stay as they were.
func _cover_page(panel: Control) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	UIKit.uncover(_covered)
	if panel == null:
		return
	var rect: Rect2 = panel.get_meta("panel_rect")
	if UIKit.locale() == LanguageScreen.Lang.SOURCE_LOCALE:
		var band := Vector2(rect.size.x, UIKit.PANEL_INK_TOP)
		for child in get_children():
			var label := child as Label
			if label and label.visible and (Rect2(label.position, label.size).intersects(Rect2(rect.position, band))
					or Rect2(label.position, label.size).intersects(Rect2(rect.end - band, band))):
				label.visible = false
				_covered.append(label)
		return
	_covered = UIKit.cover_behind(self, [code_panel, reset_confirm], rect)


func _lock_page(panel: Control) -> void:
	UIKit.unlock_focus(_focus_lock)
	_focus_lock = UIKit.lock_focus(self, panel)
	for box: LineEdit in [code_out, code_in]:
		if not box.focus_exited.is_connected(_on_box_focus_exited):
			box.focus_exited.connect(_on_box_focus_exited)


## Esc in a text box only stops editing it (the LineEdit takes the first Esc; a second one closes
## the panel). If that leaves nothing focused, focus goes to the box's button so keys still work.
func _on_box_focus_exited() -> void:
	_refocus_panel.call_deferred()


func _refocus_panel() -> void:
	if code_panel.visible and is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		copy_button.grab_focus()


func _copy_code() -> void:
	code_out.select_all()
	if Platform.has_js():
		_web_copy(code_out.text)
		return
	DisplayServer.clipboard_set(code_out.text)
	code_status.text = copied_message()


## Copying in a browser. On itch the game runs in a cross-origin iframe without the
## `clipboard-write` permission, so `navigator.clipboard.writeText` (what `clipboard_set` uses) is
## refused there and the code never reached the clipboard (web QA pass). A hidden text box +
## `execCommand("copy")` works in that iframe on the button's click; `writeText` is the second try
## (Firefox only allows the old command inside the click handler itself), and if both are refused
## the browser's own prompt shows the code selected, ready to copy by hand.
func _web_copy(text: String) -> void:
	if JavaScriptBridge.eval(web_copy_js(text), true):
		code_status.text = copied_message()
		return
	var clipboard = JavaScriptBridge.get_interface("navigator").clipboard
	if clipboard == null or not clipboard.writeText:
		_web_copy_by_hand(text)
		return
	_web_copy_done = JavaScriptBridge.create_callback(func(_args: Array) -> void: code_status.text = copied_message())
	_web_copy_failed = JavaScriptBridge.create_callback(func(_args: Array) -> void: _web_copy_by_hand(text))
	clipboard.writeText(text).then(_web_copy_done).catch(_web_copy_failed)


func _web_copy_by_hand(text: String) -> void:
	code_status.text = copy_by_hand_message()
	JavaScriptBridge.get_interface("window").prompt(Loc.t("savecode.prompt_copy", "Copy your Dry Trying save code:"), text)  # i18n: browser dialog, mixed case, any width


## The script `_web_copy` runs: copies `text` through a hidden, selected text box and gives the
## keyboard back to the game's canvas. Returns whether the browser copied it.
static func web_copy_js(text: String) -> String:
	return """(function (text) {
	var box = document.createElement('textarea');
	box.value = text;
	box.setAttribute('readonly', '');
	box.style.position = 'fixed';
	box.style.top = '0';
	box.style.left = '0';
	box.style.opacity = '0';
	document.body.appendChild(box);
	box.select();
	box.setSelectionRange(0, text.length);
	var ok = false;
	try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
	box.remove();
	var canvas = document.getElementById('canvas');
	if (canvas) { canvas.focus(); }
	return ok === true;
})(%s)""" % JSON.stringify(text)


func _load_code() -> void:
	if Progress.read_code(code_in.text) == null:
		load_armed = false
		code_status.text = _bad_code_message(code_in.text)
		return
	if not load_armed:
		load_armed = true
		# i18n: status line, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
		code_status.text = Loc.t("savecode.replaces", "THIS REPLACES YOUR PROGRESS - PRESS LOAD AGAIN")
		return
	Progress.load_code(code_in.text)
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)  # start fresh with the loaded save


## Why a code won't load: one from an older version of the game (progress from before the public
## release never carries over) or a broken / cut-off one.
func _bad_code_message(code: String) -> String:
	if Progress.is_old_code(code):
		return old_code_message()
	# i18n: status line in the SAVE CODE panel, max 260px; the panel grows to 296px, then wraps onto 2 lines, lines 2
	return Loc.t("savecode.bad_code", "THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE")


## The "are you sure?" panel for RESET PROGRESS: nothing is wiped until CONFIRM is clicked.
func _build_reset_confirm() -> void:
	reset_confirm = Control.new()
	reset_confirm.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks on the settings behind it
	add_child(reset_confirm)
	reset_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset_confirm.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.85)
	reset_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# English: a 272x82 panel at (24, 48): the title at 54, the two lines at 78, CONFIRM / CANCEL (70 wide,
	# 12 apart) at 108, 9 px under them. Other locales: the same column from the locale's title / line /
	# button heights, re-centred on the English panel's middle; a wider text widens the panel (up to
	# PANEL_MAX.x), a longer CONFIRM / CANCEL both buttons alike (UIKit.tab_widths).
	# i18n: max 256px, 16 px font; grows to 296px, steps down to 8 px past that
	var title_text := Loc.t("reset.title", "ERASE ALL PROGRESS?")
	# i18n: two lines, each max 256px; the panel grows to 296px, then each wraps onto 2 lines, lines 2
	var body_text := Loc.lines([Loc.t("reset.body.1", "LEVELS, RECORDS, COINS, UPGRADES AND"), Loc.t("reset.body.2", "SKINS WILL BE GONE FOR GOOD")])
	# i18n: reset confirm buttons (CONFIRM, CANCEL), max 62px (70 wide, 4 px margins), 1 line
	var confirm_text := Loc.t("reset.confirm", "CONFIRM")
	var cancel_text := Loc.t("common.cancel", "CANCEL")
	var button_w: int = UIKit.tab_widths([confirm_text, cancel_text], 70, true).max()
	var pair_w := 2 * button_w + UIKit.GAP_XL
	var widest := maxi(maxi(UIKit.text_w(title_text, UIKit.FONT_BIG), UIKit.text_w(body_text)), pair_w)
	var panel_w := clampi(widest + 2 * PANEL_TEXT_PAD, 272, int(PANEL_MAX.x))
	# A title wider than the widest panel's text: two 16 px lines (fix pass R2: the 16 px title kept, as on
	# every other screen), else the 8 px font (UIKit.fit_text's smaller step).
	var text_room := panel_w - 2 * PANEL_TEXT_PAD
	var title_size := UIKit.FONT_BIG
	var title_lines := 1
	var title_spacing := big_line_spacing()
	if UIKit.text_w(title_text, UIKit.FONT_BIG) > text_room:
		var split := two_lines(title_text, UIKit.FONT_BIG)
		title_lines = 2
		if UIKit.tall_script() or split == "" or UIKit.text_w(split, UIKit.FONT_BIG) > text_room:
			title_size = UIKit.FONT
			title_lines = 1
		else:
			title_text = split
	var title_h := UIKit.title_h() if title_size == UIKit.FONT_BIG else _text_box(1, UIKit.TEXT_DRIP + 1, null)
	if title_lines == 2:
		title_h += int(UIKit.metrics().title_line_h) + title_spacing
	var top_pad := 6 + int(UIKit.metrics().title_above)
	var heights := [title_h, _text_box(2, 1, null), UIKit.button_h()]
	var column := stack_column(heights, [[top_pad, top_pad], [4, UIKit.GAP_XS], [10, UIKit.GAP_M], [9, UIKit.GAP_L]], [2, 1], int(PANEL_MAX.y))
	if title_lines == 2 and not column.fits:  # (the 8 px title after all)
		title_size = UIKit.FONT
		title_lines = 1
		title_h = _text_box(1, UIKit.TEXT_DRIP + 1, null)
		heights[0] = title_h
		column = stack_column(heights, [[top_pad, top_pad], [4, UIKit.GAP_XS], [10, UIKit.GAP_M], [9, UIKit.GAP_L]], [2, 1], int(PANEL_MAX.y))
	var h: int = column.h
	var rect := Rect2(UIKit.center_x(panel_w), 48 - floori((h - 82) / 2.0), panel_w, h)
	var top := int(rect.position.y)
	reset_confirm.set_meta("panel_rect", rect)
	UIKit.add_panel(reset_confirm, rect)
	var title := UIKit.make_label(title_text, title_size, UIKit.GOLD)
	_centered_label(title, top + column.tops[0], top + column.tops[0] + heights[0])
	if title_lines == 2:  # (the second line under the first's drips and over its own marks)
		title.add_theme_constant_override("line_spacing", title_spacing)
	_centered_label(UIKit.make_label(body_text, UIKit.FONT, UIKit.TEXT_DIM), top + column.tops[1], top + column.tops[1] + heights[1])
	var buttons_y: int = top + column.tops[2]
	confirm_button = UIKit.make_button(confirm_text, _reset, Vector2(button_w, UIKit.button_h()))
	confirm_button.position = Vector2(UIKit.center_x(pair_w), buttons_y)  # 84 in English
	reset_confirm.add_child(confirm_button)
	cancel_button = UIKit.make_button(cancel_text, _cancel_reset, Vector2(button_w, UIKit.button_h()))
	for b: Button in [confirm_button, cancel_button]:
		UIKit.note_text_w(b, [confirm_text, cancel_text], 70)
	cancel_button.position = Vector2(confirm_button.position.x + button_w + UIKit.GAP_XL, buttons_y)  # 166
	reset_confirm.add_child(cancel_button)


## `text` broken at the space that makes its two lines the most even (each line centred), or "" when it
## has no space.
static func two_lines(text: String, font_size := UIKit.FONT) -> String:
	var words := text.split(" ")
	var best := ""
	var best_w := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(UIKit.text_w(a, font_size), UIKit.text_w(b, font_size))
		if w < best_w:
			best_w = w
			best = a + "\n" + b
	return best


## The line spacing of a two-line 16 px panel title: the first line's drips and shadow (6 rows) and the
## second line's marks (title_above) between the two line boxes.
static func big_line_spacing() -> int:
	return 2 * UIKit.TEXT_DRIP + 2 + int(UIKit.metrics().title_above)


func _centered_label(label: Label, top: int, bottom: int) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_confirm.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom


func _ask_reset() -> void:
	reset_confirm.visible = true
	_cover_page(reset_confirm)
	cancel_button.grab_focus()  # the safe choice is the default
	_lock_page(reset_confirm)


func _cancel_reset() -> void:
	reset_confirm.visible = false
	_cover_page(null)
	UIKit.unlock_focus(_focus_lock)
	reset_button.grab_focus()


## RESET PROGRESS starts over like a first launch: the story intro plays again (reset clears the seen
## flag), then the training maze (tutorial on) or the title. Dev mode, which never plays it, goes to the hub.
func _reset() -> void:
	Progress.reset_progress()
	if Story.intro_due(Progress):
		Story.play(get_tree(), "intro", Story.launch_next(Progress))
	else:
		UIKit.go(get_tree(), UIKit.HUB_SCENE)


## Keeps the fullscreen label right whether it was toggled here or with F11.
func _process(_delta: float) -> void:
	if fullscreen_button == null:
		return
	# i18n: max 112px, 1 line; the two states are whole strings
	if Progress.is_fullscreen():
		fullscreen_button.text = Loc.t("settings.fullscreen.on", "FULLSCREEN: ON")
	else:
		fullscreen_button.text = Loc.t("settings.fullscreen.off", "FULLSCREEN: OFF")


func _toggle_sound() -> void:
	Progress.sound_on = not Progress.sound_on
	Progress.save_progress()
	_refresh_sound()


func _toggle_motion() -> void:
	Progress.reduce_motion = not Progress.reduce_motion
	Progress.save_progress()
	_refresh_display_options()


func _update_relaxed_hint() -> void:
	var on_calm := calm_button != null and (calm_button.has_focus() or calm_button.is_hovered())
	# i18n: hint under the LURKERS button, max 296px, 1 line (centred under both columns)
	relaxed_hint.text = Loc.t("settings.lurkers.hint", "LURKERS IN RANDOM MAZES (HARD: ALWAYS)") if on_calm else Loc.t("settings.relaxed.hint", "RELAXED: MORE SLIME, NO MEDALS OR TICKETS")
	relaxed_hint.visible = on_calm or relaxed_button.has_focus() or relaxed_button.is_hovered()


func _toggle_calm() -> void:
	Progress.lurkers_random = not Progress.lurkers_random
	Progress.save_progress()
	_refresh_display_options()


func _toggle_relaxed() -> void:
	Progress.relaxed = not Progress.relaxed
	Progress.save_progress()
	_refresh_display_options()


func _toggle_vibration() -> void:
	Progress.vibration = not Progress.vibration
	Progress.save_progress()
	_refresh_display_options()
	if Progress.vibration:
		Input.vibrate_handheld(60)  # (a sample buzz)


func _toggle_level_music() -> void:
	Progress.level_music = not Progress.level_music
	Progress.save_progress()
	_refresh_display_options()


func _cycle_fog() -> void:
	Progress.fog_brightness = (Progress.fog_brightness + 1) % 3
	Progress.save_progress()
	_refresh_display_options()


func _refresh_display_options() -> void:
	# i18n: max 112px, 1 line; every state is a whole string
	if Progress.reduce_motion:
		motion_button.text = Loc.t("settings.motion.less", "MOTION: LESS")
	else:
		motion_button.text = Loc.t("settings.motion.full", "MOTION: FULL")
	# i18n: max 112px, 1 line; the two states are whole strings (no idle drain, no medals)
	if Progress.relaxed:
		relaxed_button.text = Loc.t("settings.relaxed.on", "RELAXED: ON")
	else:
		relaxed_button.text = Loc.t("settings.relaxed.off", "RELAXED: OFF")
	if calm_button != null:
		# i18n: max 112px, 1 line; the two states are whole strings (ON = the creatures in the fog of random mazes)
		if Progress.lurkers_random:
			calm_button.text = Loc.t("settings.lurkers.on", "LURKERS: ON")
		else:
			calm_button.text = Loc.t("settings.lurkers.off", "LURKERS: OFF")
	if vibration_button:
		# i18n: max 112px, 1 line; the two states are whole strings (phones: a buzz on each splat)
		if Progress.vibration:
			vibration_button.text = Loc.t("settings.vibration.on", "VIBRATION: ON")
		else:
			vibration_button.text = Loc.t("settings.vibration.off", "VIBRATION: OFF")
	if level_music_button:
		if Progress.level_music:
			level_music_button.text = Loc.t("settings.level_music.on", "LEVEL MUSIC: ON")
		else:
			level_music_button.text = Loc.t("settings.level_music.off", "LEVEL MUSIC: OFF")
	match Progress.fog_brightness:
		0:
			fog_button.text = Loc.t("settings.fog.dark", "FOG: DARK")
		1:
			fog_button.text = Loc.t("settings.fog.normal", "FOG: NORMAL")
		_:
			fog_button.text = Loc.t("settings.fog.bright", "FOG: BRIGHT")


func _refresh_sound() -> void:
	# i18n: max 112px, 1 line; the two states are whole strings
	if Progress.sound_on:
		sound_button.text = Loc.t("settings.sound.on", "SOUND: ON")
	else:
		sound_button.text = Loc.t("settings.sound.off", "SOUND: OFF")


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		if code_panel.visible:
			_close_codes()
		elif reset_confirm.visible:
			_cancel_reset()
		else:
			UIKit.go(get_tree(), UIKit.HUB_SCENE)


## Every text a column button can show (each state is a whole string), for the column width.
static func column_texts() -> Array[String]:
	return [Loc.t("settings.sound.on", "SOUND: ON"), Loc.t("settings.sound.off", "SOUND: OFF"),
		Loc.t("settings.motion.less", "MOTION: LESS"), Loc.t("settings.motion.full", "MOTION: FULL"),
		Loc.t("settings.fog.dark", "FOG: DARK"), Loc.t("settings.fog.normal", "FOG: NORMAL"),
		Loc.t("settings.fog.bright", "FOG: BRIGHT"), Loc.t("settings.fullscreen.on", "FULLSCREEN: ON"),
		Loc.t("settings.fullscreen.off", "FULLSCREEN: OFF"), Loc.t("settings.vibration.on", "VIBRATION: ON"),
		Loc.t("settings.vibration.off", "VIBRATION: OFF"), Loc.t("settings.controls", "CONTROLS"),
		Loc.t("settings.relaxed.on", "RELAXED: ON"), Loc.t("settings.relaxed.off", "RELAXED: OFF"),
		Loc.t("settings.save_code", "SAVE CODE")] + calm_texts()


## LURKERS's two states (only while the lurkers test is on; they share the column width).
static func calm_texts() -> Array[String]:
	if rows() == ROWS:
		return []
	return [Loc.t("settings.lurkers.on", "LURKERS: ON"), Loc.t("settings.lurkers.off", "LURKERS: OFF")]


## Every status line the SAVE CODE panel can show (for its width).
static func status_texts() -> Array[String]:
	return [old_code_message(), copied_message(), copy_by_hand_message(),
		Loc.t("savecode.click_box", "CLICK THE BOX AND PRESS {keys}", {keys = "CTRL+V"}),
		Loc.t("savecode.nothing_to_paste", "NOTHING TO PASTE - COPY A CODE FIRST"),
		Loc.t("savecode.pasted", "PASTED - PRESS LOAD"),
		Loc.t("savecode.replaces", "THIS REPLACES YOUR PROGRESS - PRESS LOAD AGAIN"),
		Loc.t("savecode.bad_code", "THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE")]
