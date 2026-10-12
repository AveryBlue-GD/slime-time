extends CanvasLayer

## In-game pause menu (Esc): resume, restart, sound on/off, volume, quit to the title. In a
## randomizer maze it also shows the maze's SEED (press it to copy the number or type another
## one: that maze is rebuilt, the same for anyone with the seed). Runs while the tree is paused;
## everything else in the level freezes.

var buttons: Array[Button] = []
var sound_button: Button
var volume_row: PanelContainer
var seed_button: Button
var seed_edit: LineEdit
var _panel: Panel


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

	_panel = UIKit.add_panel(root, Rect2(100, 55, 120, 88))
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
		UIKit.make_button("QUIT TO HUB", _quit),
	]
	for button in buttons:
		menu.add_child(button)
	volume_row = UIKit.make_volume_slider(46.0)  # 6 + VOLUME + 6 + slider + 6 = the 100 px button column
	menu.add_child(volume_row)
	menu.move_child(volume_row, 3)
	seed_button = UIKit.make_button("", _edit_seed)
	seed_button.visible = false
	menu.add_child(seed_button)
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(100, 13)
	seed_edit.max_length = 10
	seed_edit.placeholder_text = "NEW SEED"
	seed_edit.add_theme_font_size_override("font_size", 8)
	seed_edit.material = UIKit.text_material()
	seed_edit.visible = false
	seed_edit.text_submitted.connect(_submit_seed)
	menu.add_child(seed_edit)
	_refresh_sound()
	UIKit.add_skin_text(root)


func open() -> void:
	visible = true
	var game := get_parent()
	var random: bool = game.has_method("is_random") and game.is_random()
	seed_button.visible = random
	seed_edit.visible = false
	_panel.size.y = 88 + (16 if random else 0)
	if random:
		seed_button.text = "SEED %d" % game.random_seed
	get_tree().paused = true
	_refresh_sound()
	buttons[0].grab_focus()
	_sfx("pause")


func resume() -> void:
	visible = false
	get_tree().paused = false


## The seed button: swaps to a box holding the seed (selected, so it can be copied) to type over.
func _edit_seed() -> void:
	seed_edit.text = str(get_parent().random_seed)
	seed_button.visible = false
	seed_edit.visible = true
	seed_edit.grab_focus()
	seed_edit.select_all()


## A seed typed in: rebuilds that maze (the same one for everybody with that number). Anything
## that isn't a seed (empty, letters, 0) just closes the box.
func _submit_seed(text: String) -> void:
	var value := parse_seed(text)
	if value == 0:
		seed_edit.visible = false
		seed_button.visible = true
		seed_button.grab_focus()
		return
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.random_seed = value
	resume()
	get_tree().reload_current_scene()


## A seed number from text: 1 to 2,000,000,000 (what the randomizer picks from), else 0.
static func parse_seed(text: String) -> int:
	var clean := text.strip_edges()
	if clean == "" or not clean.is_valid_int():
		return 0
	var value := clean.to_int()
	return value if value >= 1 and value <= 2_000_000_000 else 0


func _restart() -> void:
	resume()
	get_tree().reload_current_scene()


func _quit() -> void:
	resume()
	UIKit.go(get_tree(), UIKit.HUB_SCENE)


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
		if seed_edit.visible:  # Esc first closes the seed box
			_submit_seed("")
		else:
			resume()


func _sfx(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name)
