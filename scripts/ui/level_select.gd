extends Control

## Grid of the 10 story levels (locked ones can't be picked; cleared ones are marked), plus the
## hard mode checkbox: hard mode plays its own mazes on a tight slime budget with no upgrades,
## and explored areas that fully dim are swallowed by fog again. Tiles show that mode's records.

var level_buttons: Array[Button] = []
var grid: GridContainer
var skin_text: SkinText
var hard_mode_box: CheckBox

const TILE := Vector2i(44, 38)
const LOCKED_NUMBER := UIKit.TEXT_OFF  # dimmer than the lock over it


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "LEVEL SELECT")
	grid = GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(42, 23)
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


## A level tile: the big level number dead center (its letter pixels, not its line box, sit on the
## tile's center), and under it the record time or a check (cleared). A locked tile draws the lock
## over the number, also centered; unlocking just drops the lock and leaves the number there.
func _make_tile(level: int) -> Button:
	# 38 tall: the 14 px digits centered (rows 12-25) leave room under them for the status line
	# (rows 28-34, between the goo bands at rows 0-2 and 35-37).
	var button := UIKit.make_button("", func() -> void: _play(level), TILE)
	var locked := level > Progress.highest_unlocked
	button.disabled = locked
	var number := UIKit.make_label(str(level), 16, LOCKED_NUMBER if locked else UIKit.TEXT)
	number.name = "Number"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The 16 px font's line box is exactly its 14 px letter body (see CLAUDE.md), so the box
	# centered on the tile is the digits centered on the tile; the glyph cells have no empty
	# columns, so the horizontal centering is exact too.
	number.size = Vector2(TILE.x, 14)
	number.position = Vector2(0, (TILE.y - 14) / 2)
	button.add_child(number)

	if locked:
		button.add_child(_make_lock())
		return button
	# Medal pips stacked at the tile's top right: one gold pip per tier won (bronze 1, silver 2,
	# gold 3) on this mode's best clear, dark for the rest.
	var tier := Progress.medals_for(level)
	for i in 3:
		var pip := ColorRect.new()
		pip.position = Vector2(36, 5 + i * 5)
		pip.size = Vector2(3, 3)
		pip.color = UIKit.GOLD if i < tier else UIKit.TEXT_OFF
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(pip)
	var cleared := (level in Progress.hard_cleared) if Progress.hard_mode else (level <= Progress.levels_cleared)
	var status: Control = null
	if Progress.best_time(level) >= 0.0:
		status = UIKit.make_label(UIKit.format_time(Progress.best_time(level)), 8, UIKit.TEXT_DIM)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.size = Vector2(TILE.x, 7)
		status.position = Vector2(0, 28)
	elif cleared:
		status = UIKit.make_icon("check", UIKit.GOLD)
		status.position = Vector2((TILE.x - 8) / 2, 27)
	if status:
		button.add_child(status)
	return button


## The lock icon centered by its own pixels over the tile's center, on a dark copy (like the text
## shadow) so it reads over the digits beneath it.
func _make_lock() -> Control:
	var holder := Control.new()
	holder.name = "Lock"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := UIKit.icon_ink_rect("lock")
	var at := Vector2(TILE) / 2.0 - (Vector2(ink.position) + Vector2(ink.size) / 2.0)
	at = Vector2(floorf(at.x), floorf(at.y))
	var shadow := UIKit.make_icon("lock", UIKit.BG)
	shadow.position = at + Vector2(1, 1)
	holder.add_child(shadow)
	var icon := UIKit.make_icon("lock", UIKit.TEXT_DIM)
	icon.position = at
	holder.add_child(icon)
	return holder


func _play(level: int) -> void:
	Progress.start_story(level)
	UIKit.go(get_tree(), UIKit.GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
