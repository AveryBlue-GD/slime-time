extends CanvasLayer

## In-game pause menu (Esc): resume, restart, sound on/off, volume, quit to the title.
## Runs while the tree is paused; everything else in the level freezes.

var buttons: Array[Button] = []
var sound_button: Button
var volume_row: PanelContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.theme = UIKit.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := UIKit.make_label("PAUSED", 16, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(320, 20)
	root.add_child(title)

	UIKit.add_panel(root, Rect2(100, 55, 120, 88))
	var menu := VBoxContainer.new()
	menu.position = Vector2(110, 62)
	menu.custom_minimum_size = Vector2(100, 0)
	menu.add_theme_constant_override("separation", 3)
	root.add_child(menu)
	sound_button = UIKit.make_button("", _toggle_sound)
	buttons = [
		UIKit.make_button("RESUME", resume),
		UIKit.make_button("RESTART", _restart),
		sound_button,
		UIKit.make_button("QUIT TO TITLE", _quit),
	]
	for button in buttons:
		menu.add_child(button)
	volume_row = UIKit.make_volume_slider(46.0)  # 6 + VOLUME + 6 + slider + 6 = the 100 px button column
	menu.add_child(volume_row)
	menu.move_child(volume_row, 3)
	_refresh_sound()
	UIKit.add_skin_text(root)


func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh_sound()
	buttons[0].grab_focus()
	_sfx("pause")


func resume() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	resume()
	get_tree().reload_current_scene()


func _quit() -> void:
	resume()
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)


func _toggle_sound() -> void:
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.sound_on = not progress.sound_on
		progress.save_progress()
	_refresh_sound()


func _refresh_sound() -> void:
	var progress := get_node_or_null("/root/Progress")
	sound_button.text = "SOUND: " + ("ON" if not progress or progress.sound_on else "OFF")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume()


func _sfx(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name)
