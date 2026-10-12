extends Control

## Settings: key remapping (click an action's key, then press the new key; Esc cancels; if the
## key was already used by another action, the two swap), sound on/off, volume, fullscreen, and
## RESET PROGRESS, which asks for a CONFIRM before wiping the save.

const ACTION_NAMES := {
	move_up = "MOVE UP", move_down = "MOVE DOWN", move_left = "MOVE LEFT", move_right = "MOVE RIGHT",
	jump = "JUMP (HOLD)", restart = "RESTART LEVEL", interact = "INTERACT (HUB)",
}

var key_buttons := {}
var waiting_for := ""
var sound_button: Button
var fullscreen_button: Button
var reset_button: Button
var reset_confirm: Control
var confirm_button: Button
var cancel_button: Button


func _ready() -> void:
	UIKit.setup_screen(self, "SETTINGS")
	var rows := GridContainer.new()
	rows.columns = 2
	rows.position = Vector2(71, 22)  # 80 + 8 + 90 wide, centered
	rows.add_theme_constant_override("h_separation", 8)
	rows.add_theme_constant_override("v_separation", 1)
	add_child(rows)
	for action: String in ACTION_NAMES:
		var label := UIKit.make_label(ACTION_NAMES[action])
		label.custom_minimum_size = Vector2(80, 13)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.add_child(label)
		var button := UIKit.make_button("", func() -> void: _start_rebind(action), Vector2(90, 13))
		rows.add_child(button)
		key_buttons[action] = button
	_refresh()
	key_buttons.move_up.grab_focus()

	var pause_keys := "P PAUSES" if OS.has_feature("web") else "ESC OR P PAUSES"  # browsers keep Esc for themselves
	var note := UIKit.make_label("ARROWS ALWAYS MOVE - %s - F11 FULLSCREEN" % pause_keys, 8, UIKit.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	note.offset_top = 121
	note.offset_bottom = 131
	var reset := UIKit.make_button("RESET KEYS", _on_reset, Vector2(76, 13))
	reset.position = Vector2(20, 148)  # the three buttons span 20..300, 6 px apart
	sound_button = UIKit.make_button("", _toggle_sound, Vector2(84, 13))
	sound_button.position = Vector2(102, 148)
	add_child(sound_button)
	fullscreen_button = UIKit.make_button("", func() -> void: Progress.toggle_fullscreen(), Vector2(108, 13))
	fullscreen_button.position = Vector2(192, 148)
	add_child(fullscreen_button)
	_refresh_sound()
	add_child(reset)
	var volume_row := UIKit.make_volume_slider(110.0)
	add_child(volume_row)  # (in the tree first, so it is measured in the theme's font)
	volume_row.position = Vector2(roundf((320 - volume_row.get_combined_minimum_size().x) / 2.0), 133)
	UIKit.add_back_button(self)
	reset_button = UIKit.make_button("RESET PROGRESS", _ask_reset, Vector2(96, 13))
	reset_button.position = Vector2(220, 164)
	add_child(reset_button)
	_build_reset_confirm()


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
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)


func _refresh() -> void:
	for action: String in key_buttons:
		key_buttons[action].text = Progress.key_name(Progress.bindings[action])


## Keeps the fullscreen label right whether it was toggled here or with F11.
func _process(_delta: float) -> void:
	fullscreen_button.text = "FULLSCREEN: " + ("ON" if Progress.is_fullscreen() else "OFF")


func _toggle_sound() -> void:
	Progress.sound_on = not Progress.sound_on
	Progress.save_progress()
	_refresh_sound()


func _refresh_sound() -> void:
	sound_button.text = "SOUND: " + ("ON" if Progress.sound_on else "OFF")


func _start_rebind(action: String) -> void:
	waiting_for = action
	_refresh()
	key_buttons[action].text = "PRESS A KEY..."


func _on_reset() -> void:
	waiting_for = ""
	Progress.reset_bindings()
	_refresh()


func _input(event: InputEvent) -> void:
	if waiting_for == "" or not (event is InputEventKey) or not event.pressed or event.echo:
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
		if reset_confirm.visible:
			_cancel_reset()
		else:
			UIKit.go(get_tree(), UIKit.TITLE_SCENE)
