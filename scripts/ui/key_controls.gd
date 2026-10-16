extends Control

## CONTROLS page (opened from SETTINGS): key remapping (click an action's key, then press the new
## key; Esc cancels; if the key was already used by another action, the two swap). BACK or Esc
## returns to SETTINGS. Two columns: moving and leaping on the left; restart, the hub's use key and the
## three ticket ABILITIES on the right.

## The actions in each column, top to bottom.
const COLUMNS := [["move_up", "move_down", "move_left", "move_right", "jump"],
	["restart", "interact", "ability_rifle", "ability_splat", "ability_kaze"]]
## A column: a label LABEL_WIDTH wide, GAP, the key button KEY_WIDTH wide; the two columns
## COLUMN_GAP apart, centered: 2 x (84 + 4 + 64) + 8 = 312.
const LABEL_WIDTH := 84
const KEY_WIDTH := 64
const GAP := 4
const COLUMN_GAP := 8
const ROWS_TOP := 30

var key_buttons := {}
var waiting_for := ""
var reset_keys_button: Button
var back_button: Button
## The line under the key rows: fixed keys on a keyboard, the fixed pad layout after pad input (Platform).
var note: Label


## The label of a rebindable action. i18n: max 76px (labels are 84 wide), 1 line.
static func action_name(action: String) -> String:
	match action:
		"move_up": return Loc.t("keys.move_up", "MOVE UP")
		"move_down": return Loc.t("keys.move_down", "MOVE DOWN")
		"move_left": return Loc.t("keys.move_left", "MOVE LEFT")
		"move_right": return Loc.t("keys.move_right", "MOVE RIGHT")
		"jump": return Loc.t("keys.jump", "JUMP (HOLD)")
		"restart": return Loc.t("keys.restart", "RESTART LEVEL")
		"interact": return Loc.t("keys.interact", "INTERACT (HUB)")
		"ability_rifle": return Loc.t("keys.ability_rifle", "SLIME RIFLE")
		"ability_splat": return Loc.t("keys.ability_splat", "SLIME SPLAT")
		"ability_kaze": return Loc.t("keys.ability_kaze", "SLIMAKAZE")  # pun: slime + kamikaze
	return action


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("keys.title", "CONTROLS"))  # i18n: max 296px, 16 px font
	var width := 2 * (LABEL_WIDTH + GAP + KEY_WIDTH) + COLUMN_GAP
	for c in COLUMNS.size():
		var rows := GridContainer.new()
		rows.columns = 2
		rows.position = Vector2((320 - width) / 2 + c * (LABEL_WIDTH + GAP + KEY_WIDTH + COLUMN_GAP), ROWS_TOP)
		rows.add_theme_constant_override("h_separation", GAP)
		rows.add_theme_constant_override("v_separation", 4)
		add_child(rows)
		for action: String in COLUMNS[c]:
			var label := UIKit.make_label(action_name(action))
			label.custom_minimum_size = Vector2(LABEL_WIDTH, UIKit.BUTTON_H)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rows.add_child(label)
			var button := UIKit.make_button("", func() -> void: _start_rebind(action), Vector2(KEY_WIDTH, UIKit.BUTTON_H))
			rows.add_child(button)
			key_buttons[action] = button
	# Arrows move between the columns too (a GridContainer per column has no neighbors across).
	for r in COLUMNS[0].size():
		var left: Button = key_buttons[COLUMNS[0][r]]
		var right: Button = key_buttons[COLUMNS[1][r]]
		left.focus_neighbor_right = left.get_path_to(right)
		right.focus_neighbor_left = right.get_path_to(left)
	_refresh()
	key_buttons.move_up.grab_focus()
	note = UIKit.make_label(note_text(), UIKit.FONT, UIKit.TEXT_DIM)
	PlatformEvents.input_kind_changed.connect(func(_kind: String) -> void: note.text = note_text())
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	note.offset_top = 140
	note.offset_bottom = 150
	# i18n: max 90px (98 wide, 4 px margins), 1 line
	reset_keys_button = UIKit.make_button(Loc.t("keys.reset", "RESET KEYS"), _on_reset, Vector2(98, UIKit.BUTTON_H))
	add_child(reset_keys_button)
	UIKit.place_bottom_row(reset_keys_button, 0)
	back_button = UIKit.add_back_button(self, _back)  # (back to SETTINGS)


## The fixed controls, for the device in use: the gamepad layout after pad input (not remappable yet), else the
## keys that always work (browsers keep Esc in fullscreen, so there P; F11 only where fullscreen exists).
static func note_text() -> String:
	# i18n: footer, one line, max 300px; pad button names (A X START B) stay as printed on the pad
	if Platform.using_pad():
		return Loc.t("keys.note.pad", "PAD: A LEAP - X USE - START PAUSE - B BACK")
	# i18n: footer, one line, max 300px; the key names (ESC, P, F11) are the keyboard's, not translated
	if not Platform.has_window_fullscreen():
		if Platform.is_web():
			return Loc.t("keys.note.web", "ARROWS ALWAYS MOVE - P PAUSES")
		return Loc.t("keys.note.desktop", "ARROWS ALWAYS MOVE - ESC OR P PAUSES")
	if Platform.is_web():
		return Loc.t("keys.note.web_f11", "ARROWS ALWAYS MOVE - P PAUSES - F11 FULLSCREEN")
	return Loc.t("keys.note.desktop_f11", "ARROWS ALWAYS MOVE - ESC OR P PAUSES - F11 FULLSCREEN")


func _back() -> void:
	UIKit.go(get_tree(), "res://scenes/controls.tscn")


func _refresh() -> void:
	for action: String in key_buttons:
		key_buttons[action].text = Progress.key_name(Progress.bindings[action])


func _start_rebind(action: String) -> void:
	waiting_for = action
	_refresh()
	key_buttons[action].text = Loc.t("keys.press_key", "PRESS KEY")  # i18n: max 56px (key buttons are 64 wide), 1 line


func _on_reset() -> void:
	waiting_for = ""
	Progress.reset_bindings()
	_refresh()


func _input(event: InputEvent) -> void:
	if waiting_for == "":
		return
	if not (event is InputEventKey) and (event is InputEventJoypadButton or event.is_action("menu") or event.is_action("ui_cancel")) \
			and event.is_pressed():
		# A gamepad (or the system back button) can't give a key: it cancels the wait instead of trapping it.
		get_viewport().set_input_as_handled()
		var waited := waiting_for
		waiting_for = ""
		_refresh()
		key_buttons[waited].grab_focus()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	# Esc and P are reserved for pausing (P because browsers keep Esc in fullscreen).
	if key.physical_keycode not in [KEY_ESCAPE, KEY_P, 0]:
		Progress.set_binding(waiting_for, key.physical_keycode)
	var action := waiting_for
	waiting_for = ""
	_refresh()
	key_buttons[action].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if waiting_for == "" and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		_back()
