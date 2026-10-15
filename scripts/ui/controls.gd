extends Control

## Settings: sound on/off, volume, motion, fog, fullscreen, a CONTROLS button (the key-remapping
## page, scripts/ui/key_controls.gd), SAVE CODE (copy your whole save as a code to back it up, or paste one to load it: the way to
## keep browser progress safe or move it to another browser or the Windows version), and
## RESET PROGRESS, which asks for a CONFIRM before wiping the save.

const KEY_CONTROLS_SCENE := "res://scenes/key_controls.tscn"
## What the SAVE CODE panel says about a code from an older build (it never loads).
const OLD_CODE_MESSAGE := "THAT CODE IS FROM AN OLD VERSION"
const COPIED_MESSAGE := "COPIED! KEEP IT SOMEWHERE SAFE"
## Web only, when the browser refuses to copy: the code is shown in the browser's own prompt.
const COPY_BY_HAND_MESSAGE := "COPY THE CODE FROM THE POP-UP"

## Layout: two even columns on one grid. Left: SOUND, VOLUME, MOTION, FOG. Right: FULLSCREEN,
## CONTROLS, SAVE CODE. BACK bottom left, the destructive RESET PROGRESS bottom right.
const COL_W := 120
const COL_L := 36
const COL_R := COL_L + COL_W + UIKit.GAP_L  # 164
const FIRST_ROW := 38
const ROW_STEP := 20
## RESET PROGRESS on the bottom row, mirroring BACK (its text + the 4 px margins, even).
const RESET_SIZE := Vector2(92, UIKit.BUTTON_H)
## The VOLUME box is 6 + "VOLUME" + 6 + slider + 6 wide, which must equal COL_W (as in the pause menu).
const SLIDER_W := COL_W - 54

var sound_button: Button
var volume_slider: HSlider
var fullscreen_button: Button
## REDUCE MOTION (no shake, kick or hit-stop) and FOG brightness (DARK / NORMAL / BRIGHT).
var motion_button: Button
var fog_button: Button
var controls_button: Button
var reset_button: Button
var reset_confirm: Control
var confirm_button: Button
var cancel_button: Button
var save_code_button: Button
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
	UIKit.setup_screen(self, "SETTINGS")
	_section("OPTIONS", COL_L, FIRST_ROW - 11)
	_section("MORE", COL_R, FIRST_ROW - 11)
	sound_button = _column_button(_cell(0, 0), _toggle_sound)
	var volume_row := UIKit.make_volume_slider(SLIDER_W)
	add_child(volume_row)  # (in the tree first, so it is measured in the theme's font)
	volume_row.position = _cell(0, 1)
	volume_row.custom_minimum_size = Vector2(COL_W, UIKit.BUTTON_H)
	volume_row.size = Vector2(COL_W, UIKit.BUTTON_H)
	volume_slider = volume_row.get_meta("slider")
	motion_button = _column_button(_cell(0, 2), _toggle_motion)
	fog_button = _column_button(_cell(0, 3), _cycle_fog)
	fullscreen_button = _column_button(_cell(1, 0), func() -> void: Progress.toggle_fullscreen())
	fullscreen_button.disabled = not Progress.fullscreen_available()  # (iPhone Safari: no Fullscreen API)
	_refresh_sound()
	_refresh_display_options()

	controls_button = _column_button(_cell(1, 1), _open_controls, "CONTROLS")
	save_code_button = _column_button(_cell(1, 2), _open_codes, "SAVE CODE")
	UIKit.add_back_button(self)  # the standard BACK, bottom left like every screen
	# The destructive one, alone at the bottom right, away from the everyday buttons.
	reset_button = UIKit.make_button("RESET PROGRESS", _ask_reset, RESET_SIZE)
	add_child(reset_button)
	UIKit.place_bottom_row(reset_button, 1)
	sound_button.grab_focus()
	_build_reset_confirm()
	_build_code_panel()


## Top-left corner of a grid cell (column 0 = left, 1 = right).
func _cell(column: int, row: int) -> Vector2:
	return Vector2(COL_R if column == 1 else COL_L, FIRST_ROW + row * ROW_STEP)


func _column_button(at: Vector2, on_press: Callable, text := "") -> Button:
	var button := UIKit.make_button(text, on_press, Vector2(COL_W, UIKit.BUTTON_H))
	button.position = at
	add_child(button)
	return button


## A small dim heading over a column.
func _section(text: String, x: int, y: int) -> void:
	var label := UIKit.make_label(text, UIKit.FONT, UIKit.TEXT_DIM)
	label.position = Vector2(x, y)
	add_child(label)


func _open_controls() -> void:
	UIKit.go(get_tree(), KEY_CONTROLS_SCENE)


## The SAVE CODE panel: your progress as a code to copy, and a box to paste a code into and load.
## Loading asks for a second press, since it replaces the progress you have.
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
	UIKit.add_panel(code_panel, Rect2(12, 14, 296, 150))
	_panel_label(code_panel, UIKit.make_label("SAVE CODE", UIKit.FONT_BIG, UIKit.GOLD), 20, 40)
	# Each line sits one line pitch (12) over the row it describes; 10 px between the two sections.
	_panel_label(code_panel, UIKit.make_label("COPY THIS CODE TO BACK UP YOUR PROGRESS", UIKit.FONT, UIKit.TEXT_DIM), 58 - UIKit.LINE_PITCH, 58 - 2)
	code_out = _code_box(true)
	code_out.position = Vector2(24, 58)
	copy_button = UIKit.make_button("COPY", _copy_code, Vector2(64, UIKit.BUTTON_H))
	copy_button.position = Vector2(232, 58)
	code_panel.add_child(copy_button)
	_panel_label(code_panel, UIKit.make_label("TO LOAD A SAVE, PASTE ITS CODE HERE", UIKit.FONT, UIKit.TEXT_DIM), 93 - UIKit.LINE_PITCH, 93 - 2)
	code_in = _code_box(false)
	code_in.position = Vector2(24, 93)
	code_in.custom_minimum_size = Vector2(136, UIKit.BUTTON_H)  # (before size: a size under the old minimum won't stick)
	code_in.size = Vector2(136, UIKit.BUTTON_H)
	paste_button = UIKit.make_button("PASTE", _paste_code, Vector2(64, UIKit.BUTTON_H))
	paste_button.position = Vector2(164, 93)
	code_panel.add_child(paste_button)
	code_in.placeholder_text = Progress.SAVE_CODE_PREFIX + "..."
	code_in.text_changed.connect(func(_text: String) -> void:
		load_armed = false
		code_status.text = "")
	load_button = UIKit.make_button("LOAD", _load_code, Vector2(64, UIKit.BUTTON_H))
	load_button.position = Vector2(232, 93)
	code_panel.add_child(load_button)
	code_status = UIKit.make_label("", UIKit.FONT, UIKit.TEXT)
	_panel_label(code_panel, code_status, 114, 124)
	var close := UIKit.make_button("CLOSE", _close_codes, Vector2(64, UIKit.BUTTON_H))
	close.position = Vector2(128, 140)
	code_panel.add_child(close)


func _code_box(read_only: bool) -> LineEdit:
	var box := LineEdit.new()
	box.custom_minimum_size = Vector2(204, UIKit.BUTTON_H)
	box.editable = not read_only
	box.select_all_on_focus = read_only
	box.add_theme_font_size_override("font_size", UIKit.FONT)
	box.material = UIKit.text_material()
	code_panel.add_child(box)
	# Sized once in the themed tree (sized before, it keeps the default font's 22 px height).
	box.size = Vector2(204, UIKit.BUTTON_H)
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
	_listen_for_web_paste()
	copy_button.grab_focus()
	_lock_page(code_panel)


## Fills the load box from the clipboard. In a browser Godot only sees text pasted into the page,
## and a Ctrl+V reaches the box before that text arrives, so there the clipboard is read through
## the browser instead (it may ask for permission). On itch (a cross-origin iframe without the
## `clipboard-read` permission) the browser refuses, and a phone has no Ctrl+V, so then the browser's
## own prompt asks for the code: its text field takes a long-press paste (web QA pass).
func _paste_code() -> void:
	if not OS.has_feature("web"):
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
	var text = JavaScriptBridge.get_interface("window").prompt("Paste your Slime Time save code:", "")
	if text is String and text.strip_edges() != "":
		_set_pasted(text)
	else:
		code_status.text = "CLICK THE BOX AND PRESS CTRL+V"


func _set_pasted(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		code_status.text = "NOTHING TO PASTE - COPY A CODE FIRST"
		return
	code_in.text = text
	code_in.caret_column = text.length()
	load_armed = false
	code_status.text = "PASTED - PRESS LOAD" if Progress.read_code(text) != null else _bad_code_message(text)
	load_button.grab_focus()


## In the browser, text pasted into the page (Ctrl+V, or paste from a phone's menu) goes straight
## into the load box while the SAVE CODE panel is open.
func _listen_for_web_paste() -> void:
	if not OS.has_feature("web") or _web_paste_event != null:
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
	UIKit.unlock_focus(_focus_lock)
	save_code_button.grab_focus()


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
	if OS.has_feature("web"):
		_web_copy(code_out.text)
		return
	DisplayServer.clipboard_set(code_out.text)
	code_status.text = COPIED_MESSAGE


## Copying in a browser. On itch the game runs in a cross-origin iframe without the
## `clipboard-write` permission, so `navigator.clipboard.writeText` (what `clipboard_set` uses) is
## refused there and the code never reached the clipboard (web QA pass). A hidden text box +
## `execCommand("copy")` works in that iframe on the button's click; `writeText` is the second try
## (Firefox only allows the old command inside the click handler itself), and if both are refused
## the browser's own prompt shows the code selected, ready to copy by hand.
func _web_copy(text: String) -> void:
	if JavaScriptBridge.eval(web_copy_js(text), true):
		code_status.text = COPIED_MESSAGE
		return
	var clipboard = JavaScriptBridge.get_interface("navigator").clipboard
	if clipboard == null or not clipboard.writeText:
		_web_copy_by_hand(text)
		return
	_web_copy_done = JavaScriptBridge.create_callback(func(_args: Array) -> void: code_status.text = COPIED_MESSAGE)
	_web_copy_failed = JavaScriptBridge.create_callback(func(_args: Array) -> void: _web_copy_by_hand(text))
	clipboard.writeText(text).then(_web_copy_done).catch(_web_copy_failed)


func _web_copy_by_hand(text: String) -> void:
	code_status.text = COPY_BY_HAND_MESSAGE
	JavaScriptBridge.get_interface("window").prompt("Copy your Slime Time save code:", text)


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
		code_status.text = "THIS REPLACES YOUR PROGRESS - PRESS LOAD AGAIN"
		return
	Progress.load_code(code_in.text)
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)  # start fresh with the loaded save


## Why a code won't load: one from an older version of the game (progress from before the public
## release never carries over) or a broken / cut-off one.
func _bad_code_message(code: String) -> String:
	return OLD_CODE_MESSAGE if Progress.is_old_code(code) else "THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE"


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
	UIKit.add_panel(reset_confirm, Rect2(24, 48, 272, 82))
	_centered_label(UIKit.make_label("ERASE ALL PROGRESS?", UIKit.FONT_BIG, UIKit.GOLD), 54, 74)
	_centered_label(UIKit.make_label("LEVELS, RECORDS, COINS, UPGRADES AND\nSKINS WILL BE GONE FOR GOOD", UIKit.FONT, UIKit.TEXT_DIM), 78, 98)
	confirm_button = UIKit.make_button("CONFIRM", _reset, Vector2(70, UIKit.BUTTON_H))
	confirm_button.position = Vector2(84, 108)
	reset_confirm.add_child(confirm_button)
	cancel_button = UIKit.make_button("CANCEL", _cancel_reset, Vector2(70, UIKit.BUTTON_H))
	cancel_button.position = Vector2(confirm_button.position.x + 70 + UIKit.GAP_XL, 108)  # 166
	reset_confirm.add_child(cancel_button)


func _centered_label(label: Label, top: int, bottom: int) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_confirm.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom


func _ask_reset() -> void:
	reset_confirm.visible = true
	cancel_button.grab_focus()  # the safe choice is the default
	_lock_page(reset_confirm)


func _cancel_reset() -> void:
	reset_confirm.visible = false
	UIKit.unlock_focus(_focus_lock)
	reset_button.grab_focus()


func _reset() -> void:
	Progress.reset_progress()
	UIKit.go(get_tree(), UIKit.HUB_SCENE)


## Keeps the fullscreen label right whether it was toggled here or with F11.
func _process(_delta: float) -> void:
	fullscreen_button.text = "FULLSCREEN: " + ("ON" if Progress.is_fullscreen() else "OFF")


func _toggle_sound() -> void:
	Progress.sound_on = not Progress.sound_on
	Progress.save_progress()
	_refresh_sound()


func _toggle_motion() -> void:
	Progress.reduce_motion = not Progress.reduce_motion
	Progress.save_progress()
	_refresh_display_options()


func _cycle_fog() -> void:
	Progress.fog_brightness = (Progress.fog_brightness + 1) % 3
	Progress.save_progress()
	_refresh_display_options()


func _refresh_display_options() -> void:
	motion_button.text = "MOTION: " + ("LESS" if Progress.reduce_motion else "FULL")
	fog_button.text = "FOG: " + ["DARK", "NORMAL", "BRIGHT"][Progress.fog_brightness]


func _refresh_sound() -> void:
	sound_button.text = "SOUND: " + ("ON" if Progress.sound_on else "OFF")


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		if code_panel.visible:
			_close_codes()
		elif reset_confirm.visible:
			_cancel_reset()
		else:
			UIKit.go(get_tree(), UIKit.HUB_SCENE)
