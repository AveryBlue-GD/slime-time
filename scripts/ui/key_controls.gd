extends Control

## CONTROLS page (opened from SETTINGS): key remapping (click an action's key, then press the new
## key; Esc cancels; if the key was already used by another action, the two swap). BACK or Esc
## returns to SETTINGS. Two columns: moving and leaping on the left; restart, the hub's use key and the
## three ticket ABILITIES on the right.

const ACTION_NAMES := {
	move_up = "MOVE UP", move_down = "MOVE DOWN", move_left = "MOVE LEFT", move_right = "MOVE RIGHT",
	jump = "JUMP (HOLD)", restart = "RESTART LEVEL", interact = "INTERACT (HUB)",
	ability_rifle = "SLIME RIFLE", ability_splat = "SLIME SPLAT", ability_kaze = "SLIMAKAZE",
}
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


func _ready() -> void:
	UIKit.setup_screen(self, "CONTROLS")
	var width := 2 * (LABEL_WIDTH + GAP + KEY_WIDTH) + COLUMN_GAP
	for c in COLUMNS.size():
		var rows := GridContainer.new()
		rows.columns = 2
		rows.position = Vector2((320 - width) / 2 + c * (LABEL_WIDTH + GAP + KEY_WIDTH + COLUMN_GAP), ROWS_TOP)
		rows.add_theme_constant_override("h_separation", GAP)
		rows.add_theme_constant_override("v_separation", 4)
		add_child(rows)
		for action: String in COLUMNS[c]:
			var label := UIKit.make_label(ACTION_NAMES[action])
			label.custom_minimum_size = Vector2(LABEL_WIDTH, 13)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rows.add_child(label)
			var button := UIKit.make_button("", func() -> void: _start_rebind(action), Vector2(KEY_WIDTH, 13))
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
	key_buttons[action].text = "PRESS KEY"


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
