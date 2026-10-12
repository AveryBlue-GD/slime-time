extends Control

## CONTROLS page (opened from SETTINGS): key remapping (click an action's key, then press the new
## key; Esc cancels; if the key was already used by another action, the two swap). BACK or Esc
## returns to SETTINGS.

const ACTION_NAMES := {
	move_up = "MOVE UP", move_down = "MOVE DOWN", move_left = "MOVE LEFT", move_right = "MOVE RIGHT",
	jump = "JUMP (HOLD)", restart = "RESTART LEVEL", interact = "INTERACT (HUB)",
}

var key_buttons := {}
var waiting_for := ""
var reset_keys_button: Button
var back_button: Button


func _ready() -> void:
	UIKit.setup_screen(self, "CONTROLS")
	var rows := GridContainer.new()
	rows.columns = 2
	rows.position = Vector2(71, 26)  # 80 + 8 + 90 wide, centered
	rows.add_theme_constant_override("h_separation", 8)
	rows.add_theme_constant_override("v_separation", 3)
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
	note.offset_top = 140
	note.offset_bottom = 150
	reset_keys_button = UIKit.make_button("RESET KEYS", _on_reset, Vector2(98, 13))
	reset_keys_button.position = Vector2(111, 160)
	add_child(reset_keys_button)
	back_button = UIKit.make_button("BACK", _back, Vector2(40, 13))
	back_button.position = Vector2(4, 160)
	add_child(back_button)


func _back() -> void:
	UIKit.go(get_tree(), "res://scenes/controls.tscn")


func _refresh() -> void:
	for action: String in key_buttons:
		key_buttons[action].text = Progress.key_name(Progress.bindings[action])


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
		_back()
