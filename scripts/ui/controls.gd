extends Control

## Settings: sound on/off, volume, motion, fog, fullscreen, a CONTROLS button (the key-remapping
## page, scripts/ui/key_controls.gd), SAVE CODE (copy your whole save as a code to back it up, or paste one to load it: the way to
## keep browser progress safe or move it to another browser or the Windows version), and
## RESET PROGRESS, which asks for a CONFIRM before wiping the save.

const KEY_CONTROLS_SCENE := "res://scenes/key_controls.tscn"

## Layout: two columns of buttons (options on the left, CONTROLS + SAVE CODE on the right), with
## RESET PROGRESS set apart at the bottom right and BACK at the bottom left.
const COL_W := 120
const COL_L := 36
const COL_R := 164
const FIRST_ROW := 34
const ROW_STEP := 19

var sound_button: Button
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
var copy_button: Button
var load_button: Button
## LOAD has been pressed once on a working code: the next press replaces the progress.
var load_armed := false


func _ready() -> void:
	UIKit.setup_screen(self, "SETTINGS")
	_section("OPTIONS", COL_L, FIRST_ROW - 11)
	_section("MORE", COL_R, FIRST_ROW - 11)
	sound_button = UIKit.make_button("", _toggle_sound, Vector2(COL_W, 13))
	sound_button.position = Vector2(COL_L, _row(0))
	add_child(sound_button)
	var volume_row := UIKit.make_volume_slider(COL_W)
	add_child(volume_row)  # (in the tree first, so it is measured in the theme's font)
	volume_row.position = Vector2(COL_L, _row(1))
	motion_button = UIKit.make_button("", _toggle_motion, Vector2(COL_W, 13))
	motion_button.position = Vector2(COL_L, _row(2))
	add_child(motion_button)
	fog_button = UIKit.make_button("", _cycle_fog, Vector2(COL_W, 13))
	fog_button.position = Vector2(COL_L, _row(3))
	add_child(fog_button)
	fullscreen_button = UIKit.make_button("", func() -> void: Progress.toggle_fullscreen(), Vector2(COL_W, 13))
	fullscreen_button.position = Vector2(COL_L, _row(4))
	add_child(fullscreen_button)
	_refresh_sound()
	_refresh_display_options()

	controls_button = UIKit.make_button("CONTROLS", _open_controls, Vector2(COL_W, 13))
	controls_button.position = Vector2(COL_R, _row(0))
	add_child(controls_button)
	save_code_button = UIKit.make_button("SAVE CODE", _open_codes, Vector2(COL_W, 13))
	save_code_button.position = Vector2(COL_R, _row(1))
	add_child(save_code_button)
	var back := UIKit.add_back_button(self)
	back.custom_minimum_size = Vector2(COL_W, 13)
	back.size = back.custom_minimum_size
	back.position = Vector2(COL_L, 160)
	# The destructive one, alone at the bottom right, away from the everyday buttons.
	reset_button = UIKit.make_button("RESET PROGRESS", _ask_reset, Vector2(COL_W, 13))
	reset_button.position = Vector2(COL_R, 160)
	add_child(reset_button)
	sound_button.grab_focus()
	_build_reset_confirm()
	_build_code_panel()


func _row(i: int) -> int:
	return FIRST_ROW + i * ROW_STEP


## A small dim heading over a column.
func _section(text: String, x: int, y: int) -> void:
	var label := UIKit.make_label(text, 8, UIKit.TEXT_DIM)
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
	_panel_label(code_panel, UIKit.make_label("SAVE CODE", 16, UIKit.GOLD), 20, 40)
	_panel_label(code_panel, UIKit.make_label("COPY THIS CODE TO BACK UP YOUR PROGRESS", 8, UIKit.TEXT_DIM), 45, 55)
	code_out = _code_box(true)
	code_out.position = Vector2(24, 58)
	copy_button = UIKit.make_button("COPY", _copy_code, Vector2(64, 13))
	copy_button.position = Vector2(232, 58)
	code_panel.add_child(copy_button)
	_panel_label(code_panel, UIKit.make_label("TO LOAD A SAVE, PASTE ITS CODE HERE", 8, UIKit.TEXT_DIM), 80, 90)
	code_in = _code_box(false)
	code_in.position = Vector2(24, 93)
	code_in.custom_minimum_size = Vector2(136, 13)  # (before size: a size under the old minimum won't stick)
	code_in.size = Vector2(136, 13)
	paste_button = UIKit.make_button("PASTE", _paste_code, Vector2(64, 13))
	paste_button.position = Vector2(164, 93)
	code_panel.add_child(paste_button)
	code_in.placeholder_text = "SLIME1-..."
	code_in.text_changed.connect(func(_text: String) -> void:
		load_armed = false
		code_status.text = "")
	load_button = UIKit.make_button("LOAD", _load_code, Vector2(64, 13))
	load_button.position = Vector2(232, 93)
	code_panel.add_child(load_button)
	code_status = UIKit.make_label("", 8, UIKit.TEXT)
	_panel_label(code_panel, code_status, 114, 124)
	var close := UIKit.make_button("CLOSE", _close_codes, Vector2(64, 13))
	close.position = Vector2(128, 140)
	code_panel.add_child(close)


func _code_box(read_only: bool) -> LineEdit:
	var box := LineEdit.new()
	box.size = Vector2(204, 13)
	box.custom_minimum_size = Vector2(204, 13)
	box.editable = not read_only
	box.select_all_on_focus = read_only
	box.add_theme_font_size_override("font_size", 8)
	box.material = UIKit.text_material()
	code_panel.add_child(box)
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


## Fills the load box from the clipboard. In a browser Godot only sees text pasted into the page,
## and a Ctrl+V reaches the box before that text arrives, so there the clipboard is read through
## the browser instead (it may ask for permission).
func _paste_code() -> void:
	if not OS.has_feature("web"):
		_set_pasted(DisplayServer.clipboard_get())
		return
	var clipboard = JavaScriptBridge.get_interface("navigator").clipboard
	if clipboard == null or not clipboard.readText:
		code_status.text = "CLICK THE BOX AND PRESS CTRL+V"
		return
	_web_read_done = JavaScriptBridge.create_callback(func(args: Array) -> void: _set_pasted(str(args[0])))
	_web_read_failed = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		code_status.text = "CLICK THE BOX AND PRESS CTRL+V")
	clipboard.readText().then(_web_read_done).catch(_web_read_failed)


func _set_pasted(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		code_status.text = "NOTHING TO PASTE - COPY A CODE FIRST"
		return
	code_in.text = text
	code_in.caret_column = text.length()
	load_armed = false
	code_status.text = "PASTED - PRESS LOAD" if Progress.read_code(text) != null else "THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE"
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
	save_code_button.grab_focus()


func _copy_code() -> void:
	DisplayServer.clipboard_set(code_out.text)
	code_out.select_all()
	code_status.text = "COPIED! KEEP IT SOMEWHERE SAFE"


func _load_code() -> void:
	if Progress.read_code(code_in.text) == null:
		load_armed = false
		code_status.text = "THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE"
		return
	if not load_armed:
		load_armed = true
		code_status.text = "THIS REPLACES YOUR PROGRESS - PRESS LOAD AGAIN"
		return
	Progress.load_code(code_in.text)
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)  # start fresh with the loaded save


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
	_centered_label(UIKit.make_label("ERASE ALL PROGRESS?", 16, UIKit.GOLD), 54, 74)
	_centered_label(UIKit.make_label("LEVELS, RECORDS, COINS, UPGRADES AND\nSKINS WILL BE GONE FOR GOOD", 8, UIKit.TEXT_DIM), 78, 98)
	confirm_button = UIKit.make_button("CONFIRM", _reset, Vector2(70, 13))
	confirm_button.position = Vector2(84, 108)
	reset_confirm.add_child(confirm_button)
	cancel_button = UIKit.make_button("CANCEL", _cancel_reset, Vector2(70, 13))
	cancel_button.position = Vector2(166, 108)
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


func _cancel_reset() -> void:
	reset_confirm.visible = false
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
