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
## Dev mode only (built only then): FULL BRIGHT and NO DRAIN switches (Game.set_dev_bright /
## set_dev_no_drain, also F1 / F2 in the level), on their own panel to the right.
var dev_panel: Control
var bright_button: Button
var drain_button: Button
## What had keyboard focus when the menu opened (e.g. a dry-up / win choice): it gets it back on
## resume. And the level's controls kept out of focus while the menu is open (UIKit.lock_focus).
var _return_focus: Control
var _focus_lock := {}


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
	seed_edit.max_length = 13
	seed_edit.placeholder_text = "NEW SEED"
	seed_edit.add_theme_font_size_override("font_size", 8)
	seed_edit.material = UIKit.text_material()
	seed_edit.visible = false
	seed_edit.text_submitted.connect(_submit_seed)
	seed_edit.focus_exited.connect(func() -> void: _refocus.call_deferred())
	menu.add_child(seed_edit)
	_refresh_sound()
	var progress := get_node_or_null("/root/Progress")
	if progress and progress.dev_tools:
		_build_dev_panel(root)
	UIKit.add_skin_text(root)


func _build_dev_panel(root: Control) -> void:
	dev_panel = UIKit.add_panel(root, Rect2(226, 55, 88, 50))
	var column := VBoxContainer.new()
	column.position = Vector2(232, 60)
	column.custom_minimum_size = Vector2(76, 0)
	column.add_theme_constant_override("separation", 3)
	root.add_child(column)
	var title := UIKit.make_label("DEV (F1 / F2)", 8, UIKit.TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	bright_button = UIKit.make_button("", func() -> void: _dev_toggle("set_dev_bright", "dev_bright"))
	drain_button = UIKit.make_button("", func() -> void: _dev_toggle("set_dev_no_drain", "dev_no_drain"))
	column.add_child(bright_button)
	column.add_child(drain_button)
	_refresh_dev()


func _dev_toggle(setter: String, flag: String) -> void:
	var game := get_parent()
	if game.has_method(setter):
		game.call(setter, not game.get(flag))
	_refresh_dev()


func _refresh_dev() -> void:
	if dev_panel == null:
		return
	var game := get_parent()
	var bright: bool = game.get("dev_bright") == true
	var no_drain: bool = game.get("dev_no_drain") == true
	bright_button.text = "BRIGHT: " + ("ON" if bright else "OFF")
	drain_button.text = "DRAIN: " + ("OFF" if no_drain else "ON")


func open() -> void:
	visible = true
	var game := get_parent()
	var random: bool = game.has_method("is_random") and game.is_random()
	seed_button.visible = random
	seed_edit.visible = false
	_panel.size.y = 88 + (16 if random else 0)
	if random:
		seed_button.text = "SEED " + Levels.seed_code(game.random_seed, game.seed_level)
	get_tree().paused = true
	_refresh_sound()
	_refresh_dev()
	var owner_now := get_viewport().gui_get_focus_owner()
	_return_focus = owner_now if owner_now and not is_ancestor_of(owner_now) else null
	buttons[0].grab_focus()
	if _focus_lock.is_empty():
		_focus_lock = UIKit.lock_focus(get_parent(), self)
	_sfx("pause")


func resume() -> void:
	visible = false
	get_tree().paused = false
	UIKit.unlock_focus(_focus_lock)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()  # e.g. the dry-up / win choice that had it
	_return_focus = null


## Esc in the seed box only stops editing it (the LineEdit takes the first Esc; the next one closes
## the box): if that leaves nothing focused, RESUME gets it so keys and the controller still work.
func _refocus() -> void:
	if visible and is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		buttons[0].grab_focus()


## The seed button: swaps to a box holding the seed (selected, so it can be copied) to type over.
func _edit_seed() -> void:
	seed_edit.text = Levels.seed_code(get_parent().random_seed, get_parent().seed_level)
	seed_button.visible = false
	seed_edit.visible = true
	seed_edit.grab_focus()
	seed_edit.select_all()


## A seed typed in: rebuilds that maze (the same one for everybody with that number). Anything
## that isn't a seed (empty, letters, 0) just closes the box.
func _submit_seed(text: String) -> void:
	var code := Levels.parse_seed_code(text)
	var value := code.x
	if value == 0:
		seed_edit.visible = false
		seed_button.visible = true
		seed_button.grab_focus()
		return
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.random_seed = value
		progress.random_level = code.y  # -1 (a plain number): the game uses the player's own level
		progress.random_seed_fresh = false  # a typed seed pays at most 1 ticket
	resume()
	DevLog.route(get_tree(), "typed seed", get_parent())
	get_tree().reload_current_scene()


## The seed number from text (a plain number or a "12345-2" code): 1 to 2,000,000,000 (what the
## randomizer picks from), else 0. A typed code keeps its MORE SLIME level (see Levels.parse_seed_code).
static func parse_seed(text: String) -> int:
	return Levels.parse_seed_code(text).x


func _restart() -> void:
	resume()
	DevLog.route(get_tree(), "pause RESTART", get_parent())
	get_tree().reload_current_scene()


func _quit() -> void:
	DevLog.log_event(get_tree(), "quit to hub (pause)", get_parent())
	var transition := get_node_or_null("/root/Transition")
	if transition == null or transition.busy:
		resume()
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
		return
	# The level stays paused under the wipe (Transition.go unpauses as it swaps the scene): nothing
	# runs meanwhile, no win or dry-up can happen and the result buttons can't be pressed.
	visible = false
	_return_focus = null
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


## Touch / web: tapping or clicking anywhere outside the seed box closes it (like Esc).
func _input(event: InputEvent) -> void:
	if not (visible and seed_edit.visible):
		return
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if pressed and not seed_edit.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		_submit_seed("")


func _sfx(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name)
