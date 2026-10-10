extends Control

## Key remapping (plus sound on/off, volume and fullscreen). Click an action's key, then press the new key
## (Esc cancels). If the key was already used by another action, the two actions swap keys.

const ACTION_NAMES := {
	move_up = "MOVE UP", move_down = "MOVE DOWN", move_left = "MOVE LEFT", move_right = "MOVE RIGHT",
	jump = "JUMP (HOLD)", restart = "RESTART LEVEL",
}

var key_buttons := {}
var waiting_for := ""
var sound_button: Button
var fullscreen_button: Button


func _ready() -> void:
	UIKit.setup_screen(self, "CONTROLS")
	var rows := GridContainer.new()
	rows.columns = 2
	rows.position = Vector2(70, 24)
	rows.add_theme_constant_override("h_separation", 8)
	rows.add_theme_constant_override("v_separation", 2)
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

	var note := UIKit.make_label("ARROWS ALWAYS MOVE - ESC OR P PAUSES - F11 FULLSCREEN", 8, UIKit.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	note.offset_top = 117
	note.offset_bottom = 127
	var reset := UIKit.make_button("RESET KEYS", _on_reset, Vector2(76, 13))
	reset.position = Vector2(22, 146)
	sound_button = UIKit.make_button("", _toggle_sound, Vector2(84, 13))
	sound_button.position = Vector2(104, 146)
	add_child(sound_button)
	fullscreen_button = UIKit.make_button("", func() -> void: Progress.toggle_fullscreen(), Vector2(108, 13))
	fullscreen_button.position = Vector2(194, 146)
	add_child(fullscreen_button)
	_refresh_sound()
	add_child(reset)
	var volume_row := UIKit.make_volume_slider(110.0)
	volume_row.position = Vector2(95, 130)
	add_child(volume_row)
	UIKit.add_back_button(self)


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
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
