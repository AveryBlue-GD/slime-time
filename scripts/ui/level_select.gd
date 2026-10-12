extends Control

## Grid of the 10 story levels (locked ones can't be picked; cleared ones are marked), plus the
## hard mode checkbox: hard mode plays its own mazes on a tight slime budget with no upgrades,
## and explored areas that fully dim are swallowed by fog again. Tiles show that mode's records.

var level_buttons: Array[Button] = []
var grid: GridContainer
var skin_text: SkinText
var hard_mode_box: CheckBox


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "LEVEL SELECT")
	grid = GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(42, 34)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	_fill_grid()
	level_buttons[Progress.current_level - 1].grab_focus()

	UIKit.add_panel(self, Rect2(14, 105, 292, 50))  # wide enough that the checkbox text clears the goo
	var info := UIKit.make_label("CLEAR A LEVEL TO UNLOCK THE NEXT\nEACH CLEAR ALSO UNLOCKS A NEW SKIN", 8, UIKit.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_top = 111
	info.offset_bottom = 133

	hard_mode_box = CheckBox.new()
	hard_mode_box.material = UIKit.text_material()
	hard_mode_box.text = "HARD MODE: NEW MAZES, NO UPGRADES, FOG RETURNS"
	hard_mode_box.button_pressed = Progress.hard_mode
	hard_mode_box.toggled.connect(func(on: bool) -> void:
		Progress.set_hard_mode(on)
		_fill_grid())  # show that mode's record times
	hard_mode_box.position = Vector2(25, 140)  # 270 wide, centered
	add_child(hard_mode_box)
	UIKit.add_back_button(self)


## (Re)builds the level tiles.
func _fill_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	level_buttons.clear()
	for level in range(1, Levels.COUNT + 1):
		var button := _make_tile(level)
		grid.add_child(button)
		level_buttons.append(button)
	if skin_text:
		skin_text.recolor.call_deferred()


## A level tile: the big level number, and under it the record time, a check (cleared, no
## time saved) or a lock.
func _make_tile(level: int) -> Button:
	# 32 tall: the number and the status line fit between the goo bands (rows 3-29).
	var button := UIKit.make_button("", func() -> void: _play(level), Vector2(44, 32))
	var locked := level > Progress.highest_unlocked
	button.disabled = locked
	var number := UIKit.make_label(str(level), 16, UIKit.TEXT_OFF if locked else UIKit.TEXT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.position = Vector2(0, 3)
	number.size = Vector2(44, 18)
	button.add_child(number)

	var status := CenterContainer.new()
	status.position = Vector2(0, 21)
	status.size = Vector2(44, 9)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(row)
	if locked:
		row.add_child(UIKit.make_icon("lock", UIKit.TEXT_OFF))
	elif Progress.best_time(level) >= 0.0:
		row.add_child(UIKit.make_label(UIKit.format_time(Progress.best_time(level)), 8, UIKit.TEXT_DIM))
	elif (level in Progress.hard_cleared) if Progress.hard_mode else (level <= Progress.levels_cleared):
		row.add_child(UIKit.make_icon("check", UIKit.GOLD))
	return button


func _play(level: int) -> void:
	Progress.start_story(level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
