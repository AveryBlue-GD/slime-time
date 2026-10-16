extends Control

## Grid of the 10 story levels (locked ones can't be picked; cleared ones are marked), plus the
## hard mode checkbox: hard mode plays its own mazes on a tight slime budget with no upgrades,
## and explored areas that fully dim are swallowed by fog again. Tiles show that mode's records.
## Hard mode adds HEAT (Heat, upgrades v2 batch 4): a HEAT n button bottom right (mirroring BACK)
## opens the HeatPanel of six modifier toggles, the info lines name the bounties, and each hard
## tile shows its best heat tier as a flame at its top left (mirroring the medal pips).
## Other languages (docs/ui-rules.md section 10): sizes follow the locale's lines (title_bottom,
## line pitch, button_h, the accents' room); when the two rows of tiles, the info panel and the bottom
## row don't fit between the title and row 176 (every locale with taller lines: accents, Vietnamese,
## CJK, Thai, Devanagari) the tiles go on two pages of one row, < and > beside the title flip them
## (and left / right past a row's end). English (and Indonesian) keep the one-page layout.

var level_buttons: Array[Button] = []
var grid: GridContainer
var skin_text: SkinText
var hard_mode_box: CheckBox
var info: Label
var heat_button: Button
var heat_panel: HeatPanel
var info_panel: Panel
## Pages of tiles (1: the English two rows; 2: one row of PAGE_SIZE each) and the one shown.
var pages := 1
var page := 0
var page_prev: Button
var page_next: Button

## 48x42: the 14 px digits sit 3 px above the tile's center (rows 11-24; their drips end on row 28
## and their shadow on row 29), then 2 clear rows (30-31) and the 7 px record time (rows 32-38,
## drips 39-40, the drips' 1 px shadow on the frame's bottom row 41): the digits' drips never
## touch the time on any tile (owner decision L2: the number 2 px above centre, not touching).
const TILE := Vector2i(48, 42)
const NUMBER_Y := 11
## Five tiles 3 apart (252 px) centered on the screen: L34 / R34.
const GRID_POS := Vector2(34, 22)
const GRID_GAP := 3
const STATUS_Y := 32  # top row of the record time / check
## The info panel, 4 px under the grid (the section gap).
const INFO_RECT := Rect2(14, 113, 292, 48)
const LOCKED_NUMBER := UIKit.TEXT_OFF  # dimmer than the lock over it
## The flame badge's top-left corner on a hard tile (7x9; the medal pips mirror it at the top right).
const FLAME_POS := Vector2(5, 5)
const HEAT_BUTTON_SIZE := Vector2(52, UIKit.BUTTON_H)
## The info lines' top under the panel's top edge (English; the accents' room is added on top).
const INFO_PAD := 5
## Tiles per page when paged (one row).
const PAGE_SIZE := 5


## The two help lines under the tiles.
static func info_text(hard: bool) -> String:
	# i18n: two lines, each max 300px; the numbers are the heat levels and ticket payouts (Heat.BOUNTIES), keep them
	if hard:
		return Loc.lines([
			Loc.t("levels.info_hard.1", "HEAT UP LEVELS BEATEN ON HARD"),
			Loc.t("levels.info_hard.2", "HEAT 2 4 7 10 PAYS 3 5 7 10 TICKETS ONCE"),
		])
	return Loc.lines([
		Loc.t("levels.info_normal.1", "CLEAR A LEVEL TO UNLOCK THE NEXT"),
		Loc.t("levels.info_normal.2", "EACH CLEAR ALSO UNLOCKS A NEW SKIN"),
	])


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, Loc.t("levels.title", "LEVEL SELECT"))  # i18n: max 296px, 16 px font
	grid = GridContainer.new()
	grid.columns = 5
	grid.position = GRID_POS
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	add_child(grid)

	_fill_grid()

	info_panel = UIKit.add_panel(self, INFO_RECT)  # wide enough that the checkbox text clears the goo
	info = UIKit.make_label(info_text(Progress.hard_mode), UIKit.FONT, UIKit.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_top = INFO_RECT.position.y + 5
	info.offset_bottom = INFO_RECT.position.y + 25

	hard_mode_box = CheckBox.new()
	hard_mode_box.material = UIKit.text_material()
	# i18n: checkbox, max 268px, grows to 276px, wraps onto 2 lines past that (broken at a space), lines 2
	hard_mode_box.text = Loc.t("levels.hard_mode", "HARD MODE: NEW MAZES, NO UPGRADES, FOG RETURNS")
	if UIKit.text_w(hard_mode_box.text) > _checkbox_text_room():  # (pseudo): two lines, broken at a space
		hard_mode_box.text = UIKit.break_line(hard_mode_box.text, _checkbox_text_room())
		hard_mode_box.add_theme_constant_override("line_spacing", UIKit.line_spacing())
	hard_mode_box.button_pressed = Progress.hard_mode
	hard_mode_box.toggled.connect(func(on: bool) -> void:
		Progress.set_hard_mode(on)
		_fill_grid()  # show that mode's record times
		_refresh_heat())
	add_child(hard_mode_box)
	UIKit.note_text_w(hard_mode_box, [hard_mode_box.text], 0, UIKit.FONT, UIKit.checkbox_extra(hard_mode_box))  # (sized to its text)
	UIKit.add_touch_target(hard_mode_box)
	UIKit.add_back_button(self)
	# HEAT (hard mode only): bottom right, mirroring BACK (placed by _refresh_heat: its width follows its text).
	heat_button = UIKit.make_button("", _open_heat, HEAT_BUTTON_SIZE)
	add_child(heat_button)
	_layout()
	heat_panel = HeatPanel.new()
	heat_panel.closed.connect(_refresh_heat)
	add_child(heat_panel)
	if pages > 1:
		_add_pager()  # (last: the other nodes keep their places; hidden under a resized HEAT panel)
	_refresh_heat()
	_show_page((Progress.current_level - 1) / PAGE_SIZE)
	level_buttons[Progress.current_level - 1].grab_focus()


## Places the info panel (its lines, the checkbox under them, its bottom GRID_GAP over the bottom row)
## and the grid (two rows right under the title, or one row centred between the title and the panel
## when paged). English: INFO_RECT, the checkbox at (25, 145), the grid at GRID_POS.
func _layout() -> void:
	if "\n" in hard_mode_box.text:
		# Two lines: GAP_M over and under them (one line has 4.5 px in its 16 px box), so the drips stay
		# off the panel's goo. (Its cached minimum size predates the second line.)
		hard_mode_box.update_minimum_size()
		hard_mode_box.custom_minimum_size.y = UIKit.text_block_h(2) + 2 * UIKit.GAP_M
	var box := hard_mode_box.get_combined_minimum_size()
	var top_pad := INFO_PAD + UIKit.accent_room()
	var lines_h := UIKit.text_block_h(2)
	# The checkbox's text keeps 4 px of its box under it (4.5 in English) off the panel's bottom goo.
	var box_text_h := UIKit.text_block_h(hard_mode_box.text.count("\n") + 1)
	var panel_h := top_pad + lines_h + UIKit.GAP_L + int(box.y) + maxi(0, UIKit.GAP_M - floori((box.y - box_text_h) / 2.0))
	var panel_bottom := UIKit.bottom_row_y() - GRID_GAP
	var two_rows_h := 2 * TILE.y + GRID_GAP
	pages = 1 if UIKit.title_bottom() + two_rows_h + UIKit.GAP_M + panel_h <= panel_bottom else ceili(Levels.COUNT / float(PAGE_SIZE))
	# As wide as INFO_RECT, or wider for a longer line / checkbox (GAP_L clear of the goo each side).
	var widest := maxi(UIKit.text_w(info_text(false)), UIKit.text_w(info_text(true)))
	var panel_w := mini(maxi(int(INFO_RECT.size.x), maxi(widest, int(box.x)) + 2 * UIKit.GAP_L), int(UIKit.SCREEN.x) - 2 * UIKit.EDGE)
	var panel := Rect2(UIKit.center_x(panel_w), panel_bottom - panel_h, panel_w, panel_h)
	info_panel.position = panel.position
	info_panel.size = panel.size
	info.offset_top = panel.position.y + top_pad
	info.offset_bottom = info.offset_top + lines_h + 1
	hard_mode_box.position = Vector2(UIKit.center_x(box.x), info.offset_top + lines_h + UIKit.GAP_L)
	UIKit.align_checkbox(hard_mode_box)
	var grid_y := float(UIKit.title_bottom())
	if pages > 1:
		grid_y += floorf((panel.position.y - UIKit.GAP_M - UIKit.title_bottom() - TILE.y) / 2.0)
	grid.position = Vector2(GRID_POS.x, grid_y)


## The widest the checkbox's text may be: the screen less EDGE and GAP_L each side, the box icon (16)
## and its separation (the theme's 4).
func _checkbox_text_room() -> int:
	return int(UIKit.SCREEN.x) - 2 * (UIKit.EDGE + UIKit.GAP_L) - 16 - UIKit.GAP_M


## The page arrows (paged only): < at the left edge and > at the right, centred on the title's line.
func _add_pager() -> void:
	var arrows := UIKit.add_page_arrows(self, _flip, UIKit.title_arrows_y(), UIKit.EDGE, UIKit.SCREEN.x - UIKit.EDGE)
	page_prev = arrows[0]
	page_next = arrows[1]


func _flip(step: int) -> void:
	var arrow := page_prev if step < 0 else page_next
	_show_page(page + step)
	if arrow.disabled:  # the last page that way: the focus goes to its first tile
		level_buttons[page * PAGE_SIZE].grab_focus()


## Shows page `index` (paged only; one page shows every tile).
func _show_page(index: int) -> void:
	page = clampi(index, 0, pages - 1)
	if pages < 2:
		return
	for i in level_buttons.size():
		level_buttons[i].visible = i / PAGE_SIZE == page
	UIKit.show_page_arrows([page_prev, page_next], page, pages)


## Left / right past the row's end flip the page (paged only).
func _tile_input(level: int, event: InputEvent) -> void:
	if pages < 2:
		return
	var i := level - 1
	var step := 0
	# (the row reads right to left in a mirrored layout: there the left key leads on to the next page)
	var on := "ui_left" if UIKit.is_mirrored(level_buttons[i]) else "ui_right"
	var back := "ui_right" if on == "ui_left" else "ui_left"
	if event.is_action_pressed(on) and i % PAGE_SIZE == PAGE_SIZE - 1 and i + 1 < level_buttons.size():
		step = 1
	elif event.is_action_pressed(back) and i % PAGE_SIZE == 0 and i > 0:
		step = -1
	if step == 0:
		return
	level_buttons[i].accept_event()
	_show_page(page + step)
	level_buttons[i + step].grab_focus()


## The HEAT button (shown in hard mode: HEAT n, the picked modifiers' total) and the info lines.
func _refresh_heat() -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	heat_button.visible = Progress.hard_mode
	# i18n: {points} = the heat total (0-99); max 52px, grows to 100px (button_w: the button widens), 1 line
	heat_button.text = Loc.t("levels.heat", "HEAT {points}", {points = Heat.points(Progress.heat_mods)})
	var heat_size := Vector2(UIKit.button_w(heat_button.text, int(HEAT_BUTTON_SIZE.x)), UIKit.button_h())
	UIKit.note_text_w(heat_button, [heat_button.text], int(HEAT_BUTTON_SIZE.x))
	heat_button.custom_minimum_size = heat_size
	heat_button.size = heat_size
	UIKit.place_bottom_row(heat_button, 1)
	info.text = info_text(Progress.hard_mode)
	if not Progress.hard_mode and heat_panel.visible:
		heat_panel.close()


func _open_heat() -> void:
	if Progress.hard_mode and not heat_panel.visible:
		heat_panel.open(self, heat_button)


## (Re)builds the level tiles.
func _fill_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	level_buttons.clear()
	var plain := UIKit.plain_font("0") != null
	for level in range(1, Levels.COUNT + 1):
		var button := _make_tile(level)
		grid.add_child(button)
		level_buttons.append(button)
		if plain:  # the digits' boxes again in the themed tree (sized before, the fallback's line box held them)
			for label in button.find_children("*", "Label", false, false):
				if label.has_meta("box"):
					label.size = label.get_meta("box")
	_show_page(page)
	if skin_text:
		skin_text.recolor.call_deferred()


## A level tile: the big level number centered across the tile (its letter pixels, not its line
## box) and 3 px above its middle (NUMBER_Y), and under it the record time or a check (cleared). A locked tile draws the lock
## over the number, also centered; unlocking just drops the lock and leaves the number there.
func _make_tile(level: int) -> Button:
	var button := UIKit.make_button("", func() -> void: _play(level), TILE)
	button.gui_input.connect(func(event: InputEvent) -> void: _tile_input(level, event))
	var locked := level > Progress.highest_unlocked
	button.disabled = locked
	var number := UIKit.make_label(str(level), UIKit.FONT_BIG, LOCKED_NUMBER if locked else UIKit.TEXT)
	number.name = "Number"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The 16 px font's line box is exactly its 14 px letter body (see CLAUDE.md), so the digits
	# fill rows NUMBER_Y..NUMBER_Y + 13; the glyph cells have no empty columns, so the horizontal
	# centering is exact.
	UIKit.use_plain_font(number, UIKit.FONT_BIG)  # (a script fallback's line box would push the digits down)
	number.size = Vector2(TILE.x, 14)
	number.set_meta("box", Vector2(TILE.x, 14))
	number.position = Vector2(0, NUMBER_Y)
	button.add_child(number)

	if locked:
		button.add_child(_make_lock())
		return button
	# Hard mode: the best heat tier this level was cleared at, as a flame at the top left.
	var heat_tier := Heat.tier_of(Progress.best_heat(level)) if Progress.hard_mode else 0
	if heat_tier > 0:
		var flame := Heat.make_rect(Heat.flame(heat_tier))
		flame.name = "Flame"
		flame.position = FLAME_POS
		button.add_child(flame)
	# Medal pips stacked at the tile's top right: one gold pip per tier won (bronze 1, silver 2,
	# gold 3) on this mode's best clear, dark for the rest.
	var tier := Progress.medals_for(level)
	for i in 3:
		var pip := ColorRect.new()
		pip.position = Vector2(TILE.x - 8, 5 + i * 5)
		pip.size = Vector2(3, 3)
		pip.color = UIKit.GOLD if i < tier else UIKit.TEXT_OFF
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(pip)
	var cleared := (level in Progress.hard_cleared) if Progress.hard_mode else (level <= Progress.levels_cleared)
	var status: Control = null
	if Progress.best_time(level) >= 0.0:
		status = UIKit.make_label(UIKit.format_time(Progress.best_time(level)), 8, UIKit.TEXT_DIM)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# clip_text drops the label's minimum width (52 px here, wider than the tile, which pushed
		# the centered text right); the 9 px height (7 + 2 drip rows) keeps its drips unclipped.
		status.clip_text = true
		UIKit.use_plain_font(status)
		status.size = Vector2(TILE.x, 9)
		status.set_meta("box", Vector2(TILE.x, 9))
		status.position = Vector2(0, STATUS_Y)
	elif cleared:
		status = UIKit.make_icon("check", UIKit.GOLD)
		var ink := UIKit.icon_ink_rect("check")  # centered in the 7 px status band by its own pixels
		status.position = Vector2((TILE.x - 8) / 2, STATUS_Y + (7 - ink.size.y) / 2 - ink.position.y)
	if status:
		button.add_child(status)
	return button


## The lock icon centered by its own pixels on the number's center, on a dark copy (like the text
## shadow) so it reads over the digits beneath it.
func _make_lock() -> Control:
	var holder := Control.new()
	holder.name = "Lock"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := UIKit.icon_ink_rect("lock")
	var at := Vector2(TILE.x / 2.0, NUMBER_Y + 7.0) - (Vector2(ink.position) + Vector2(ink.size) / 2.0)
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
		if heat_panel.visible:  # Esc closes the HEAT panel first
			get_viewport().set_input_as_handled()
			heat_panel.close()
			return
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
