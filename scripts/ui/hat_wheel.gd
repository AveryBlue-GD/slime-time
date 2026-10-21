class_name HatWheel
extends Control

## The prize wheel's overlay, opened at the prize wheel in the hub: two tabs, WHEEL | SHOP
## (upgrades v2 batch 2, docs/design/upgrades-v2.md C.1-C.3).
## WHEEL: a big wheel with a wedge for every hat you don't have yet, each showing its hat; a wedge's
## size is its odds (Progress.wheel_weight, the table in Economy), so the rare hats (rainbow, propeller)
## get thin slivers, the rainbow one rainbow-striped. A spin
## (the SPIN button, or the interact key / JUMP on a touchscreen) whirls it round (the flapper ticking
## on each wedge it passes), slows down and lands on a random hat. The spin is settled before the
## wheel turns (Progress.spin_hat picks the hat, charges its price (free first, then 12, +2 per spin
## taken, max 40; dev mode never pays) and wins it, all saved at once); the wheel just plays out
## where it lands (always inside the won hat's wedge). A save's first spin never lands on a rare
## hat (Progress.wheel_pool). A won hat comes off the wheel, so there are never duplicates: an empty wheel once
## every hat is yours.
## SHOP: three sections (DYES, TRAILS, PAPERS) of goo-framed tiles with their prices and the ticket
## icon. Hats are never sold. DYES (section id "hats"): a tile per dyeable hat you have won (its name
## and how many of its dyes you own); pressing one opens its colors (`dye_hat`): ORIGINAL and each dye
## (a swatch, the name, the price or OWNED / WORN; Hats.dyes_for, Economy.DYE_PRICE). Pressing an owned
## one puts the hat on in it; Esc / B or the DYES button go back to the hats. TRAILS / PAPERS =
## Cosmetics; an owned one is worn / taken off by pressing its tile. Buying asks once (BUY GOLD
## TRAIL? 30 [ticket]  BUY / BACK, focus on BACK). Focus stays inside (the confirm, when open, locks
## it); Esc / B close the confirm first, then a hat's colors, then the overlay (the hub does that,
## via `back`). The hub opens and closes it and passes on the spin key.
## On a touchscreen there is no key to close it, so a BACK button shows in the header (mirroring the SHOP
## tab, `show_close`); a tap anywhere else never spins (the hub's JUMP mapping is off while it's open).

signal landed(hat_id: String)
## The SPIN button started a spin, something was bought in the SHOP (a cosmetic id, or the hat id
## of a dye), or a cosmetic / dye was worn / taken off ("" for a spin).
signal changed(id: String)
## The touch BACK button was pressed (the hub closes the overlay).
signal close_requested

const PANEL := Rect2(8, 4, 304, 172)
const CENTER := Vector2(160, 88)
const RADIUS := 52.0
const SPIN_TIME := 3.6
const WEDGE_COLORS: Array[Color] = [
	Color8(200, 60, 70), Color8(236, 200, 80), Color8(60, 170, 170),
	Color8(140, 80, 190), Color8(230, 130, 50), Color8(70, 110, 200),
]
const RIM := Color8(170, 118, 70)
const RIM_DARK := Color8(88, 54, 34)
const DIVIDER := Color8(240, 236, 226)
const PEG := Color8(255, 240, 180)
const FLAPPER := Color8(176, 40, 54)
const RAINBOW_RINGS: Array[Color] = [
	Color8(236, 64, 76), Color8(246, 142, 52), Color8(252, 222, 74),
	Color8(92, 204, 96), Color8(70, 140, 236), Color8(150, 92, 220),
]
const TICKET_TINT := Color8(255, 226, 150)
## The SHOP grid: two columns of tiles.
## The header row (tabs top left, title centered, balance top right): one text baseline (the tabs'
## text rows 3-9 = the labels at HEADER_Y + 3), HEADER_INSET from the panel's sides.
const HEADER_Y := 9
const HEADER_INSET := 8
const TILE := Vector2(138, UIKit.BUTTON_H)
## Two columns of 138 px tiles 2 apart, centered in the panel: insets 13 / 13.
const GRID_LEFT := [21.0, 161.0]
const GRID_TOP := 46
const GRID_STEP := 15
## A dye tile's color swatch (square, before its name) and the room it takes from the name.
const SWATCH := 5
const SWATCH_ROOM := 8
## The tiles' text inset, the least gap between a name and its price, the gap between tiles.
const TILE_PAD := 4
const NAME_GAP := 3
const GRID_GAP := 2
## The least room between the grid and the panel's sides (13 in English; 6 for long names).
const GRID_MIN_INSET := 6
## SPIN's bottom edge (158 + 13 in English) and the status lines' (153 + 7).
const SPIN_BOTTOM := 171.0
const STATUS_BOTTOM := 160.0
## The status lines' width when they must wrap (clear of the try-on slimes).
const STATUS_W := 240.0
const SECTIONS := ["hats", "trails", "papers"]
## Where the try-on slimes stand (centers): either side of the wheel at 2x after a win, or of the
## text under the shop grid at 1x (clear of the grid's last row, whatever hat).
const TRY_ON := {"wheel": [Vector2(56, 92), Vector2(264, 92)], "shop": [Vector2(30, 154), Vector2(290, 154)]}

## The wheel's centre and radius in the current language (CENTER / RADIUS in English): a taller
## script's header and result line leave it less room, so it is drawn smaller (_layout_wheel_page).
var wheel_center := CENTER
var wheel_radius := RADIUS
## The SHOP grid in the current language: tile size, the two columns' x, the first row's y, the row
## pitch, the rows on one page (all of them in English) and the page shown; the PREV / NEXT arrows
## by the section row show only when a section needs more than one page (taller scripts).
var tile_size := TILE
var grid_left: Array[float] = [GRID_LEFT[0], GRID_LEFT[1]]
var grid_top := float(GRID_TOP)
var grid_step := float(GRID_STEP)
var rows_per_page := 1000
var _two_line_names := false
var _status_first_lines := 1
var _status_second_lines := 1
var page := 0
var pages := 1
var prev_page: Button
var next_page: Button
## The section row (HATS / TRAILS / PAPERS) on screen.
var sections_rect := Rect2()
## The two status lines' tops (141 / 153 in English).
var status_y := 141.0
var status_line_y := 153.0
## The hats on the wheel right now (the ones not won yet), in wheel order: the rare ones spread
## evenly round it (spread_rares).
var hats: Array[String] = []:
	set(value):
		hats = spread_rares(value)
		_layout()
## Where each wedge starts (radians from the wheel's zero) and how wide it is: shares of the
## circle by Progress.wheel_weight. (A save's first spin can't land on a rare hat's wedge, but it
## still shows: Progress.wheel_pool.)
var starts: Array[float] = []
var sizes: Array[float] = []
## How far the wheel has turned (radians); wedge i starts at turn + starts[i] (0 = pointing right).
var turn := 0.0
var spinning := false
var _from := 0.0
var _to := 0.0
var _t := 0.0
var _won := ""
var _target := ""
var _last_wedge := -1
var _kick := 0.0
var title: Label
var result: Label
var balance: Label
var _balance_icon: TextureRect
## "wheel" or "shop", and the SHOP's section.
var tab := "wheel"
var section := "hats"
## DYES: the hat whose colors are shown ("": the list of your dyeable hats). Its tiles' ids are
## "hat:dye" ("hat:" = ORIGINAL).
var dye_hat := ""
var wheel_tab: Button
var shop_tab: Button
var spin_button: Button
var wheel_page: Control
var shop_page: Control
var section_buttons := {}
## The SHOP's tiles by item id (hat or cosmetic), for the section shown.
var shop_tiles := {}
var _grid: Control
var status: Label
var status_line: Label
## TRAILS / PAPERS: a picture of the focused item in the free space under the tiles (a strip of that
## goo in the worn skin through the trail shader, or a scrap of map on that paper).
var preview: TextureRect
var _preview_floor: ColorRect
## Two slimes in your skin wearing a hat, either side of the text at the bottom: the hat you just won
## (WHEEL), or the hat / dye you're looking at (SHOP). `_try_on_id` = "tab:hat:dye" they're dressed for.
var _try_on_root: Node2D
var _try_on_id := ""
## The hue step the flowing (rainbow) hat on the wheel was last drawn at (Hats.flow_step).
var _flow_step := -1
## The buy confirm: BUY <NAME>? <price> [ticket], BUY / BACK.
var confirm: Panel
var confirm_label: Label
var confirm_price: Label
var confirm_buy: Button
var confirm_back: Button
var _confirm_id := ""
var _blocker: ColorRect
var _confirm_lock := {}
var _spin_key := "F"
## Touch only: BACK in the header (hidden otherwise; see show_close).
var close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UIKit.add_panel(self, PANEL)
	panel.show_behind_parent = true  # the wheel is drawn by this control, over its panel
	var text_y := HEADER_Y + UIKit.button_v_margins().x  # the tabs' line box (HEADER_Y + 3 in English)
	title = _label(Loc.t("wheel.title", "HAT WHEEL"), UIKit.GOLD, text_y)  # on the tabs' text baseline
	# The ticket balance, top right of the panel.
	balance = UIKit.make_label("", UIKit.FONT, TICKET_TINT)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.position = Vector2(PANEL.end.x - 50, text_y)
	balance.size = Vector2(32, maxi(10, UIKit.line_h()))
	add_child(balance)
	_balance_icon = UIKit.make_icon("ticket", Color.WHITE)
	_balance_icon.position = Vector2(PANEL.end.x - HEADER_INSET - 8, text_y + UIKit.digit_top())  # mirrors the WHEEL tab's inset
	add_child(_balance_icon)
	# WHEEL | SHOP: 44 wide in English, equal widths from the longer word; the touch BACK as wide as
	# the SHOP tab (or its own word), mirroring it.
	var tab_texts := [Loc.t("wheel.tab.wheel", "WHEEL"), Loc.t("wheel.tab.shop", "SHOP"), Loc.t("common.back", "BACK")]
	var tab_w := UIKit.tab_widths(tab_texts.slice(0, 2), 44)
	var close_w := UIKit.button_w(tab_texts[2], tab_w[1])
	wheel_tab = UIKit.make_button(tab_texts[0], func() -> void: show_tab("wheel"), Vector2(tab_w[0], UIKit.tab_h()))
	wheel_tab.position = Vector2(PANEL.position.x + HEADER_INSET, HEADER_Y)
	add_child(wheel_tab)
	shop_tab = UIKit.make_button(tab_texts[1], func() -> void: show_tab("shop"), Vector2(tab_w[1], UIKit.tab_h()))
	shop_tab.position = Vector2(PANEL.position.x + HEADER_INSET + tab_w[0] + 2, HEADER_Y)
	add_child(shop_tab)
	close_button = UIKit.make_button(tab_texts[2], func() -> void: close_requested.emit(), Vector2(close_w, UIKit.tab_h()))
	for tab: Button in [wheel_tab, shop_tab]:
		UIKit.note_text_w(tab, tab_texts.slice(0, 2), 44)
	UIKit.note_text_w(close_button, [tab_texts[2]], tab_w[1])
	close_button.position = Vector2(320 - shop_tab.position.x - close_w, HEADER_Y)  # the SHOP tab's mirror
	close_button.visible = false
	add_child(close_button)

	wheel_page = _page()
	result = _label("", UIKit.TEXT, 146, wheel_page)
	spin_button = UIKit.make_button(Loc.t("wheel.spin", "SPIN"), _on_spin_pressed, Vector2(84, UIKit.button_h()))
	spin_button.position = Vector2(roundf(CENTER.x - 42), SPIN_BOTTOM - UIKit.button_h())
	spin_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wheel_page.add_child(spin_button)

	shop_page = _page()
	# HATS / TRAILS / PAPERS: 52 wide in English (equal widths from the longest word), 4 apart, centred
	# 6 under the header's tabs.
	var section_texts: Array = SECTIONS.map(_section_label)
	var section_w := UIKit.tab_widths(section_texts, 52)
	var row_w := 0
	for w in section_w:
		row_w += w
	row_w += UIKit.GAP_M * (SECTIONS.size() - 1)
	var x := roundf(CENTER.x - row_w / 2.0)
	# (taller buttons than English (accents' room, a taller script) take the gaps GAP_M / GAP_S here
	# and the status lines go down to PANEL_PAD above the panel's bottom, so the rows fit: _compact())
	var sections_y := HEADER_Y + UIKit.tab_h() + (UIKit.GAP_M if _compact() else 6)
	sections_rect = Rect2(x, sections_y, row_w, UIKit.tab_h())
	for i in SECTIONS.size():
		var id: String = SECTIONS[i]
		var button := UIKit.make_button(section_texts[i], func() -> void: _on_section_button(id), Vector2(section_w[i], UIKit.tab_h()))
		UIKit.note_text_w(button, section_texts, 52)
		button.position = Vector2(x, sections_y)
		x += section_w[i] + UIKit.GAP_M
		shop_page.add_child(button)
		section_buttons[id] = button
	grid_top = sections_rect.end.y + (UIKit.GAP_S if _compact() else 5)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_page.add_child(_grid)
	_preview_floor = ColorRect.new()
	_preview_floor.color = Color8(40, 34, 52)
	_preview_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_page.add_child(_preview_floor)
	preview = TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	shop_page.add_child(preview)
	# The two status lines: a line_pitch() apart, the second ending on row 160 in English (PANEL_PAD
	# above the panel's bottom with taller buttons: _compact()).
	status_line_y = (PANEL.end.y - UIKit.PANEL_PAD if _compact() else STATUS_BOTTOM) - UIKit.line_h()
	status_y = status_line_y - UIKit.line_pitch()
	status = _label("", UIKit.TEXT, int(status_y), shop_page)
	status_line = _label("", UIKit.TEXT_DIM, int(status_line_y), shop_page)

	_try_on_root = Node2D.new()  # (under the confirm and its dim sheet)
	add_child(_try_on_root)
	_build_confirm()
	_layout_wheel_page()
	show_tab("wheel", false)


func _page() -> Control:
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page


func _label(text: String, color: Color, top: int, parent: Control = null) -> Label:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(parent if parent else self).add_child(label)
	label.position = Vector2(PANEL.position.x, top)
	label.size = Vector2(PANEL.size.x, maxi(10, UIKit.line_h()))
	return label


## True when this locale's buttons are taller than English's (accents' room or a taller script): the
## SHOP then uses its compact gaps, so as many rows fit as in English where they can.
func _compact() -> bool:
	return UIKit.grow_h() > 0


## The wheel page: SPIN ends on row SPIN_BOTTOM, the result line 5 above its top, and the wheel
## (flapper to rim) fills what is left between the header and the result line: CENTER / RADIUS in
## English, a smaller wheel under a taller script's header and result line.
func _layout_wheel_page() -> void:
	var spin_y := SPIN_BOTTOM - UIKit.button_h()
	var result_y := spin_y - 5 - UIKit.line_h()
	if result.position.y != result_y:
		result.position.y = result_y
	var top := HEADER_Y + UIKit.tab_h() + 4.0
	var bottom := result_y - 2.0
	wheel_radius = minf(RADIUS, floorf((bottom - top - 14.0) / 2.0))
	wheel_center = Vector2(CENTER.x, top + 10.0 + wheel_radius)
	_fit_spin_button()


## SPIN is 84 wide in English, wider for a longer text (and its ticket icon), centred under the wheel.
func _fit_spin_button() -> void:
	var extra := 0
	if spin_button.icon:
		extra = spin_button.icon.get_width() + spin_button.get_theme_constant("h_separation")
	var w := UIKit.button_w(spin_button.text, 84, UIKit.FONT, extra)
	UIKit.note_text_w(spin_button, [spin_button.text], 84, UIKit.FONT, extra)
	if w != int(spin_button.custom_minimum_size.x):
		spin_button.custom_minimum_size = Vector2(w, UIKit.button_h())
		spin_button.size = spin_button.custom_minimum_size
	var at := Vector2(roundf(CENTER.x - w / 2.0), SPIN_BOTTOM - UIKit.button_h())
	if spin_button.position != at:  # (setting it, even unchanged, shapes the text early: English keeps its RIDs)
		spin_button.position = at


func _build_confirm() -> void:
	var parts := UIKit.add_ticket_confirm(self, _buy_confirmed, close_confirm, TICKET_TINT)
	_blocker = parts.blocker
	confirm = parts.panel
	confirm_label = parts.label
	confirm_price = parts.price
	confirm_buy = parts.buy
	confirm_back = parts.back


## The panel focus must stay in right now (the confirm while it's open, else the whole overlay).
func modal() -> Control:
	return confirm if confirm.visible else self


## Esc / B: closes the confirm if it's open (true); false = nothing to close here (the hub then
## closes the overlay).
func back() -> bool:
	if confirm.visible:
		close_confirm()
		return true
	if tab == "shop" and section == "hats" and dye_hat != "":
		var hat := dye_hat
		dye_hat = ""
		show_section("hats", false)
		if shop_tiles.has(hat):
			(shop_tiles[hat] as Button).grab_focus()
			_describe(hat)
		return true
	return false


## Switches between the WHEEL and the SHOP and focuses something on it.
func show_tab(which: String, focus := true) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	if spinning:
		return
	tab = which
	var shop := tab == "shop"
	wheel_page.visible = not shop
	shop_page.visible = shop
	title.text = Loc.t("wheel.tab.shop", "SHOP") if shop else Loc.t("wheel.title", "HAT WHEEL")
	_place_title()
	for pair: Array in [[wheel_tab, not shop], [shop_tab, shop]]:
		UIKit.set_selected(pair[0], pair[1])
	if shop:
		show_section(section, focus)
	else:
		_refresh_wheel()
		if focus:
			(spin_button if not spin_button.disabled else wheel_tab).grab_focus()
	queue_redraw()


## The key named in the WHEEL's "TO SPIN" hint changed (the player switched between keys, pad and touch):
## only the hint text is redone (nothing is rebuilt, so the focus stays where it is).
func set_spin_key(spin_key: String) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	_spin_key = spin_key
	if tab == "wheel" and not spinning:
		_refresh_wheel()


## Shows the header's BACK (touch: there is no Esc / B to close the overlay).
func show_close(on: bool) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	close_button.visible = on
	_place_title()


## The header's title: centred on the screen (English), or in the room between the tabs and the
## balance (or the touch BACK) when wider tabs would touch it; hidden when it fits nowhere (it only
## repeats the tab or station name).
func _place_title() -> void:
	var w := UIKit.text_w(title.text)
	var from := shop_tab.position.x + shop_tab.size.x + UIKit.GAP_M
	var to := (close_button.position.x if close_button.visible else balance.position.x + balance.size.x - UIKit.text_w(balance.text)) - UIKit.GAP_M
	var centred := roundf(CENTER.x - w / 2.0)
	title.visible = w <= to - from
	var span := Vector2(PANEL.position.x, PANEL.size.x)
	if (centred < from or centred + w > to) and title.visible:
		# (as near the centre as the tabs let it: moved just clear of them, not centred in the room left,
		# which put ROUE À CHAPEAUX 44 px right of the centre: fix pass F3a)
		var near := from - UIKit.GAP_M + UIKit.GAP_L  # (GAP_L clear of the tabs where it fits)
		span = Vector2(clampf(centred, near if w <= to - near else from, to - w), w)
	if title.position.x != span.x or title.size.x != span.y:
		title.position.x = span.x
		title.size.x = span.y


## Fills the overlay for the state of play. `opening`: the hub just opened it (WHEEL first, or the
## SHOP when every hat is already won; focus inside). Right after a win the won hat stays where it
## landed, lit up under the pointer, until the next spin takes it off.
func refresh(spin_key: String, opening := false) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	_spin_key = spin_key
	if opening:
		_won = ""
		dye_hat = ""
		_try_on_id = ""  # (the skin may have changed since: dress new ones)
		close_confirm()
		show_tab("shop" if Progress.hats_left().is_empty() else "wheel")
	elif tab == "shop":
		show_section(section, false)
	else:
		_refresh_wheel()
	balance.text = str(Progress.tickets)
	queue_redraw()


func _refresh_wheel() -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	if _won == "" and not spinning:  # (mid-spin the won hat stays on until it has landed)
		hats = Progress.hats_left()
	balance.text = str(Progress.tickets)
	var can: bool = Progress.can_spin_hats() and not spinning
	var cost: int = Progress.spin_cost()
	if Progress.hats_left().is_empty() and _won == "":
		result.text = Loc.t("wheel.all_won", "EVERY HAT WON! NEW LOOKS IN THE SHOP")
	elif spinning:
		result.text = "..."
	elif _won != "":
		result.text = Loc.t("wheel.won", "YOU WON THE {name}!", {name = Hats.display_name(_won)})
	elif not Hats.available and not Progress.dev_tools:
		result.text = Loc.t("wheel.resting", "THE WHEEL IS RESTING")
	elif Progress.demo_wheel_block() != "":
		result.text = Demo.wheel_block_text(Progress.demo_wheel_block())  # (the demo: hats used up / not open yet)
	elif not can:
		result.text = Loc.n("wheel.need_to_spin", "NEED {count} TICKET TO SPIN", "NEED {count} TICKETS TO SPIN", cost)
	else:
		# (touch: no key, the SPIN button)
		if _spin_key == "":
			result.text = Loc.n("wheel.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", hats.size())
		else:
			result.text = Loc.n("wheel.hats_left_key", "{count} HAT TO WIN - {key} TO SPIN", "{count} HATS TO WIN - {key} TO SPIN", hats.size(), {key = _spin_key})
	_show_try_on(_won if not spinning else "")  # the hat you just won, on you
	spin_button.disabled = not can
	if Progress.hats_left().is_empty():
		spin_button.text = Loc.t("wheel.spin", "SPIN")
		spin_button.icon = null
	elif cost == 0:
		spin_button.text = Loc.t("wheel.spin_free", "SPIN  FREE")
		spin_button.icon = null
	else:
		spin_button.text = Loc.t("wheel.spin_cost", "SPIN  {cost}", {cost = cost})
		spin_button.icon = load(UIKit.UI_DIR + "icon_ticket.png")
	_fit_spin_button()
	# A disabled button never takes the keyboard (arrows skip it): the tabs while the wheel turns, SPIN
	# when it can't spin (mid-spin it keeps the focus it has).
	spin_button.focus_mode = Control.FOCUS_ALL if can or spinning else Control.FOCUS_NONE
	for button: Button in [wheel_tab, shop_tab, close_button]:
		button.disabled = spinning
		button.focus_mode = Control.FOCUS_NONE if spinning else Control.FOCUS_ALL


func _on_spin_pressed() -> void:
	if spin():
		changed.emit("")


## `ids` in wheel order with the rare hats (Progress.is_rare_hat) spaced evenly between the
## ordinary ones, not bunched together: each rare sliver sits in the middle of its share of the
## ordinary wedges (9 ordinary + 3 rare = 3 ordinary, rare, 3 ordinary, rare, ...). Only the drawing
## order: the odds and the pick (Progress.spin_hat, by id) don't depend on it.
static func spread_rares(ids: Array[String]) -> Array[String]:
	var plain: Array[String] = []
	var rare: Array[String] = []
	for id in ids:
		if Progress.is_rare_hat(id):
			rare.append(id)
		else:
			plain.append(id)
	if rare.is_empty() or plain.is_empty():
		return ids.duplicate()
	var out: Array[String] = []
	var next := 0  # the next rare hat to place
	for i in plain.size():
		out.append(plain[i])
		# Rare k goes after ordinary wedge ceil((k + 1) * plain / rare) - 1: one per equal stretch.
		while next < rare.size() and i + 1 >= ceili((next + 1) * plain.size() / float(rare.size())):
			out.append(rare[next])
			next += 1
	return out


## Sizes the wedges by each hat's odds.
func _layout() -> void:
	starts.clear()
	sizes.clear()
	var total := 0.0
	for id in hats:
		total += Progress.wheel_weight(id, Progress.rainbow_pity)
	var at := 0.0
	for id in hats:
		starts.append(at)
		sizes.append(TAU * Progress.wheel_weight(id, Progress.rainbow_pity) / total)
		at += sizes[-1]


## Which wedge is under the pointer (at the top) for a given turn.
func wedge_at(at_turn: float) -> int:
	if hats.is_empty():
		return -1
	var a := fposmod(-PI / 2.0 - at_turn, TAU)
	for i in hats.size():
		if a < starts[i] + sizes[i]:
			return i
	return hats.size() - 1


## Spins to a random hat still on the wheel (WHEEL tab, no confirm open). False if it can't spin.
func spin() -> bool:
	if spinning or tab != "wheel" or confirm.visible or not Progress.can_spin_hats():
		return false
	hats = Progress.hats_left()  # the last hat won comes off the wheel now (wedges sized by today's odds)
	if hats.is_empty():
		return false
	# Settle it all first: the hat is picked, paid for, won and saved before anything turns.
	_target = Progress.spin_hat()
	if _target == "":
		return false
	var pick := hats.find(_target)
	balance.text = str(Progress.tickets)
	# Land with the pointer somewhere inside the picked wedge (not on its edge), after a few turns.
	var inside := randf_range(0.2, 0.8)
	var target := -PI / 2.0 - (starts[pick] + inside * sizes[pick])
	var turns := randi_range(4, 6)
	_from = turn
	_to = target - TAU * turns
	while _to > _from - TAU * turns:  # always whirl the same way, plenty of times
		_to -= TAU
	_t = 0.0
	_won = ""
	spinning = true
	_last_wedge = wedge_at(turn)
	if is_visible_in_tree():
		spin_button.grab_focus()  # (the tabs are about to go dark)
	_refresh_wheel()
	return true


func _process(delta: float) -> void:
	_kick = maxf(_kick - delta * 6.0, 0.0)
	if not spinning:
		if tab == "wheel" and is_visible_in_tree() and Hats.flow_step() != _flow_step:
			queue_redraw()  # the rainbow hat's colors flow on (Hats.flow_texture)
		return
	_t = minf(_t + delta / SPIN_TIME, 1.0)
	var eased := 1.0 - pow(1.0 - _t, 3.0)  # fast at first, slowing to a stop
	turn = lerpf(_from, _to, eased)
	var wedge := wedge_at(turn)
	if wedge != _last_wedge:  # the flapper ticks past a wedge edge
		_last_wedge = wedge
		_kick = 1.0
		_sfx("click", -14.0, 1.3)
	if _t >= 1.0:
		spinning = false
		turn = fposmod(turn, TAU)
		_won = _target
		_sfx("unlock", -4.0)
		_refresh_wheel()
		var owner := get_viewport().gui_get_focus_owner()
		if visible and (owner == null or (owner == spin_button and spin_button.disabled)):
			(spin_button if not spin_button.disabled else wheel_tab).grab_focus()
		landed.emit(_won)
	queue_redraw()


# ---------------------------------------------------------------- the SHOP

## The SHOP section tab's label (the internal ids stay English).
func _section_label(id: String) -> String:
	match id:
		"hats":
			return Loc.t("wheel.section.dyes", "DYES")  # i18n: max 44px, grows to 56px (tab_widths: the three alike), 1 line; hat dyes (colors)
		"trails":
			return Loc.t("wheel.section.trails", "TRAILS")  # i18n: max 44px, grows to 56px (tab_widths: the three alike), 1 line
	return Loc.t("wheel.section.papers", "PAPERS")  # i18n: max 44px, grows to 56px (tab_widths: the three alike), 1 line


## A section button: its tiles (DYES: back to the list of hats).
func _on_section_button(id: String) -> void:
	dye_hat = ""
	show_section(id)


## Shows a SHOP section's tiles: DYES (your dyeable hats, or one's colors: dye_hat), TRAILS or PAPERS.
func show_section(which: String, focus := true) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	if which != section:
		page = 0
	section = which
	for id: String in section_buttons:
		UIKit.set_selected(section_buttons[id], id == section)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	shop_tiles.clear()
	var ids := _section_ids()
	_fit_grid(ids)
	for i in ids.size():
		var tile := _make_tile(ids[i])
		tile.position = Vector2(grid_left[i % 2], grid_top + ((i / 2) % rows_per_page) * grid_step)
		if dye_hat != "" and section == "hats" and i == ids.size() - 1 and i % 2 == 0:
			tile.position.x = roundf(CENTER.x - tile_size.x / 2.0)  # (a hat's last dye, RAINBOW, alone on its row: centred under the two above)
		_grid.add_child(tile)
		if tile.has_meta("wrap_name"):
			var wrap: Array = tile.get_meta("wrap_name")
			UIKit.wrap_label(wrap[0], wrap[1])
		shop_tiles[ids[i]] = tile
	_show_page(mini(page, pages - 1), ids)
	balance.text = str(Progress.tickets)
	if ids.is_empty():
		_show_try_on("")
		status.text = _empty_texts()[0]
		status_line.text = _empty_texts()[1]
		_fit_status_lines()
	else:
		_describe(ids[0])
	if focus:
		var first := page * rows_per_page * 2
		(shop_tiles[ids[first]] if first < ids.size() else section_buttons[section]).grab_focus()


## Sizes the SHOP grid for the section's items: tiles TILE (138 x button_h()) in English, wider for a
## longer name (up to two columns filling the panel), the name on two lines (a taller tile) when even
## that is too narrow; as many rows as fit between the section row and the status lines (preview
## room kept for TRAILS / PAPERS), the rest on further pages (grid_budget) with PREV / NEXT.
func _fit_grid(ids: Array[String]) -> void:
	var name_w := 0
	var right_w := 0
	for id in ids:
		name_w = maxi(name_w, UIKit.text_w(_name_of(id)) + (SWATCH_ROOM if _is_dye(id) else 0))
		right_w = maxi(right_w, _right_w(id))
	# (up to GRID_MIN_INSET from the panel's sides before a name has to wrap)
	var max_w := floorf((PANEL.size.x - 2 * GRID_MIN_INSET - GRID_GAP) / 2.0)
	var need := TILE_PAD + name_w + NAME_GAP + right_w + TILE_PAD
	# (a tile that grows anyway keeps GAP_L between its longest name and the price where the panel has
	# the room: КЕПКА С ПРОПЕЛЛЕРОМ read as one string with 45 at 3 px, fix pass F3a)
	if need > TILE.x and need - NAME_GAP + UIKit.GAP_L <= max_w:
		need += UIKit.GAP_L - NAME_GAP
	_two_line_names = need > max_w
	tile_size = Vector2(clampf(need, TILE.x, max_w), UIKit.button_h() + (UIKit.line_pitch() if _two_line_names else 0))
	var left := roundf(CENTER.x - (2 * tile_size.x + GRID_GAP) / 2.0)
	grid_left = [left, left + tile_size.x + GRID_GAP]
	grid_step = tile_size.y + GRID_GAP
	_place_status(ids)
	var area := status_y - (UIKit.GAP_S if _compact() else UIKit.GAP_M) - grid_top
	if section != "hats":
		area -= _preview_room()
	var budget := UIKit.grid_budget(ids.size(), 2, area, tile_size.y, GRID_GAP)
	rows_per_page = budget.rows_per_page if not budget.fits else maxi(budget.rows, 1)
	pages = budget.pages if not budget.fits else 1
	if pages > 1 and prev_page == null:
		_make_page_arrows()


## The room a TRAILS / PAPERS preview takes under the grid (its picture, its floor and a gap).
func _preview_room() -> float:
	return (9.0 * 2.0 if section == "trails" else 10.0 * 3.0) + 8.0 + UIKit.GAP_M


## The width of a tile's right part for item `id`: its price and the ticket icon, OWNED / WORN, or
## a dyeable hat's dye count.
func _right_w(id: String) -> int:
	if _is_hat(id):
		return UIKit.text_w(_dye_count(id))
	if _owned(id):
		return UIKit.text_w(Loc.t("wheel.worn", "WORN") if _worn(id) else Loc.t("wheel.owned", "OWNED"))
	var price := _price_of(id)
	if price == 0:
		return UIKit.text_w(Loc.t("wheel.free", "FREE"))
	return UIKit.text_w(str(price)) + UIKit.GAP_XS + 8


## PREV / NEXT either side of the section row (made the first time a section needs two pages).
func _make_page_arrows() -> void:
	# (no focus: the keys turn pages from the grid's first / last row)
	var arrows := UIKit.add_page_arrows(shop_page, func(step: int) -> void: _turn_page(step), sections_rect.position.y,
		grid_left[0], grid_left[1] + tile_size.x, UIKit.PAGER_W, UIKit.tab_h(), false)
	prev_page = arrows[0]
	next_page = arrows[1]


## Shows page `which` of the section's tiles (the others hidden) and the arrows that lead on.
func _show_page(which: int, ids: Array[String]) -> void:
	page = clampi(which, 0, pages - 1)
	for i in ids.size():
		(shop_tiles[ids[i]] as Button).visible = (i / 2) / rows_per_page == page
	if prev_page != null:
		prev_page.visible = pages > 1
		next_page.visible = pages > 1
		UIKit.show_page_arrows([prev_page, next_page], page, pages)
	_link_page_edges(ids)


## Turns the SHOP grid `delta` pages on (PREV / NEXT, or the keys past the first / last row), focus
## on the first tile of the new page (or the tile in `column` of its first / last row).
func _turn_page(delta: int, column := -1) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	var ids := _section_ids()
	var to := clampi(page + delta, 0, pages - 1)
	if to == page:
		return
	_show_page(to, ids)
	var first := page * rows_per_page * 2
	var last := mini(first + rows_per_page * 2, ids.size()) - 1
	var at := first
	if column >= 0:
		at = first + column if delta > 0 else last - ((last - first) % 2) + column
		at = clampi(at, first, last)
	if at < ids.size() and shop_tiles.has(ids[at]):
		(shop_tiles[ids[at]] as Button).grab_focus()
		_describe(ids[at])


## Down from a page's last row / up from its first row turns the page (when there is one).
func _link_page_edges(ids: Array[String]) -> void:
	for i in ids.size():
		var tile: Button = shop_tiles[ids[i]]
		tile.set_meta("grid_index", i)


func _on_tile_input(event: InputEvent, tile: Button) -> void:
	if pages <= 1 or not tile.has_meta("grid_index"):
		return
	var i: int = tile.get_meta("grid_index")
	var row := (i / 2) % rows_per_page
	var rows_here := ceili((mini((page + 1) * rows_per_page * 2, _section_ids().size()) - page * rows_per_page * 2) / 2.0)
	if event.is_action_pressed("ui_down") and row == rows_here - 1 and page < pages - 1:
		tile.accept_event()
		_turn_page(1, i % 2)
	elif event.is_action_pressed("ui_up") and row == 0 and page > 0:
		tile.accept_event()
		_turn_page(-1, i % 2)


func _section_ids() -> Array[String]:
	match section:
		"hats":
			var ids: Array[String] = []
			if dye_hat != "":
				ids.append(dye_hat + ":")
				for dye in Hats.dyes_for(dye_hat):
					ids.append("%s:%s" % [dye_hat, dye])
				return ids
			for hat in Hats.ids():
				if Hats.is_dyeable(hat) and Progress.is_hat_unlocked(hat):
					ids.append(hat)
			return ids
		"trails":
			return Cosmetics.ids(Cosmetics.TRAIL)
	return Cosmetics.ids(Cosmetics.PAPER)


## A DYES hat tile (a dyeable hat's id).
func _is_hat(id: String) -> bool:
	return not Hats.get_hat(id).is_empty()


## A DYES color tile ("hat:dye"; "hat:" = ORIGINAL).
func _is_dye(id: String) -> bool:
	return ":" in id


func _dye_parts(id: String) -> Array[String]:
	return [id.get_slice(":", 0), id.get_slice(":", 1)]


func _name_of(id: String) -> String:
	if _is_dye(id):
		return Hats.dye_name(_dye_parts(id)[1])
	return Hats.display_name(id) if _is_hat(id) else Cosmetics.display_name(id)


func _price_of(id: String) -> int:
	return Progress.dye_price(_dye_parts(id)[1]) if _is_dye(id) else Progress.cosmetic_price(id)


## Whether item `id` is yours (a hat's ORIGINAL always is).
func _owned(id: String) -> bool:
	if _is_dye(id):
		var parts := _dye_parts(id)
		return parts[1] == "" or Progress.owns_dye(parts[0], parts[1])
	return not _is_hat(id) and Progress.owns_cosmetic(id)


func _worn(id: String) -> bool:
	if _is_dye(id):
		var parts := _dye_parts(id)
		return Progress.selected_hat == parts[0] and Progress.hat_dye_of(parts[0]) == parts[1]
	return Progress.trail_style == id or Progress.map_paper == id


## A dyeable hat tile's right part: the dyes owned of its dyes ("3/9").
func _dye_count(hat: String) -> String:
	var owned := 0
	for dye in Hats.dyes_for(hat):
		if Progress.owns_dye(hat, dye):
			owned += 1
	return "%d/%d" % [owned, Hats.dyes_for(hat).size()]  # i18n: ignore (numbers only)


## The two status lines when the section has no tiles (no dyeable hat won yet).
func _empty_texts() -> Array[String]:
	# i18n: SHOP status lines (DYES with no dyeable hat yet), max 240px each, 1 line each
	return [Loc.t("wheel.dyes_empty", "NO HATS TO DYE YET"), Loc.t("wheel.dyes_win", "WIN ONE ON THE WHEEL, THEN DYE IT HERE")]


## A goo-framed tile: the item's name, and its price with the ticket icon (or OWNED / WORN).
func _make_tile(id: String) -> Button:
	var tile := UIKit.make_button("", func() -> void: _on_tile(id), tile_size)
	var name_label := UIKit.make_label(_name_of(id), UIKit.FONT, UIKit.TEXT)
	var text_y := UIKit.button_v_margins().x  # (3 in English: the tile's text rows)
	# (right-to-left: the Kufi letters have no side bearing, the slimy font's 1 px is on the left, so
	# the right-aligned name keeps 1 px more from the tile's inner border: 3 clear columns, as English's left)
	name_label.position = Vector2(TILE_PAD + (1 if UIKit.rtl() else 0), text_y)
	if _is_dye(id):  # a swatch of the dye (the hat's own look for ORIGINAL: a goo-dark square with its outline)
		var dye := _dye_parts(id)[1]
		var swatch := ColorRect.new()
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = Hats.dye_color(dye) if dye != "" else UIKit.TEXT_DIM
		swatch.size = Vector2(SWATCH, SWATCH)
		swatch.position = Vector2(TILE_PAD, text_y + 1)
		swatch.material = Hats.flow_material() if Hats.dye_flows(dye) else null  # (the RAINBOW swatch flows too)
		tile.add_child(swatch)
		name_label.position.x += SWATCH_ROOM
	tile.add_child(name_label)
	var right_w := maxf(40, _right_w(id))
	if _two_line_names:  # (wrapped into the room left of the price, sized once in the tree: show_section)
		name_label.autowrap_mode = UIKit.autowrap_mode()
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER  # (a one-line name in the middle)
		name_label.add_theme_constant_override("line_spacing", UIKit.line_spacing())
		tile.set_meta("wrap_name", [name_label, Vector2(tile_size.x - 2 * TILE_PAD - NAME_GAP - _right_w(id), UIKit.text_block_h(2))])
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", UIKit.GAP_XS)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UIKit.tall_script() or _two_line_names or tile_size.x != TILE.x:
		# (a taller script: the price's line box on the name's, so the digits share its baseline)
		var line := UIKit.line_h()
		var y := text_y + (UIKit.line_pitch() / 2 if _two_line_names else 0)
		right.position = Vector2(tile_size.x - TILE_PAD - right_w, y if UIKit.tall_script() else y - 1)
		right.size = Vector2(right_w, line if UIKit.tall_script() else 9)
	else:
		# (the price on the name's text row: text_y - 1 like the branch above; 2 in English. It sat on
		# row 2 in every locale, 3-4 px over an accented locale's name: fix pass F3a)
		right.position = Vector2(TILE.x - 4 - 40, text_y - 1)
		right.size = Vector2(40, 9)
	tile.add_child(right)
	if _is_hat(id):
		right.add_child(UIKit.make_label(_dye_count(id), UIKit.FONT, UIKit.TEXT_DIM))
		if Progress.selected_hat == id:
			UIKit.set_selected(tile, true)
	elif _owned(id):
		right.add_child(UIKit.make_label(Loc.t("wheel.worn", "WORN") if _worn(id) else Loc.t("wheel.owned", "OWNED"), UIKit.FONT, UIKit.GOLD if _worn(id) else UIKit.TEXT_DIM))
		if _worn(id):
			UIKit.set_selected(tile, true)
	else:
		var price := _price_of(id)
		var affordable := price <= Progress.tickets and Demo.shop_open()
		right.add_child(UIKit.make_label(Loc.t("wheel.free", "FREE") if price == 0 else str(price), UIKit.FONT, UIKit.TEXT if affordable else UIKit.TEXT_OFF))
		if price > 0:
			right.add_child(UIKit.make_icon("ticket", Color.WHITE if affordable else Color(0.55, 0.55, 0.6)))
	tile.focus_entered.connect(func() -> void: _describe(id))
	tile.mouse_entered.connect(func() -> void: _describe(id))
	if pages > 1:
		tile.gui_input.connect(_on_tile_input.bind(tile))
	return tile


## The two status lines for item `id`: its name and what pressing it does (or why it can't), and
## its picture (trails and papers).
func _describe(id: String) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	_describe_texts(id)
	_fit_status_lines()


## Both status lines fitted (_fit_status) in the room _place_status kept.
func _fit_status_lines() -> void:
	# (this item's lines, bottom-aligned in the room kept for the section's longest: 141 / 153 in English)
	var second := _status_lines(status_line.text)
	var line_top := status_line_y + UIKit.text_block_h(_status_second_lines) - UIKit.text_block_h(second)
	_fit_status(status, line_top - _status_lines(status.text) * UIKit.line_pitch(), _status_first_lines)
	_fit_status(status_line, line_top, _status_second_lines)


func _describe_texts(id: String) -> void:
	_show_preview(id)
	if _is_dye(id):
		_show_try_on(_dye_parts(id)[0], _dye_parts(id)[1])
	else:
		_show_try_on(id if _is_hat(id) else "", Progress.hat_dye_of(id))
	var texts := _status_texts(id)
	status.text = texts[0]
	status_line.text = texts[1]


## Item `id`'s two status lines: its name and what pressing it does (or why it can't).
func _status_texts(id: String) -> Array[String]:
	var line := ""
	if not Demo.shop_open() and (_is_hat(id) or not _owned(id)):
		# The demo: the SHOP's goods are on show, bought in the full game.
		var name := _dye_title(id) if _is_dye(id) else Hats.display_name(id) if _is_hat(id) else Cosmetics.display_name(id)
		# i18n: SHOP status line (demo build), max 300px, 1 line
		return [name, Loc.t("wheel.demo_shop", "THE SHOP OPENS IN THE FULL GAME")]
	if _is_hat(id):
		# i18n: SHOP status line (DYES: a dyeable hat's tile), max 240px, 1 line
		return [Hats.display_name(id), Loc.t("wheel.pick_dye", "PRESS TO PICK ITS COLOR")]
	if _is_dye(id):
		if _owned(id):
			line = Loc.t("wheel.worn", "WORN") if _worn(id) else Loc.t("wheel.wear", "PRESS TO WEAR IT")
		elif _price_of(id) > Progress.tickets:
			line = Loc.n("wheel.need", "NEED {count} TICKET", "NEED {count} TICKETS", _price_of(id))
		else:
			line = Loc.t("wheel.buy", "PRESS TO BUY")
		return [_dye_title(id), line]
	var item_status := Loc.t("wheel.item_info", "{name} - {about}", {name = Cosmetics.display_name(id), about = Cosmetics.about(id)})
	if Progress.owns_cosmetic(id):
		line = Loc.t("wheel.take_off", "PRESS TO TAKE IT OFF") if _worn(id) else Loc.t("wheel.wear", "PRESS TO WEAR IT")
	elif Progress.cosmetic_price(id) > Progress.tickets:
		line = Loc.n("wheel.need", "NEED {count} TICKET", "NEED {count} TICKETS", Progress.cosmetic_price(id))
	else:
		line = Loc.t("wheel.buy", "PRESS TO BUY")
	return [item_status, line]


## A dye tile's first status line: the hat in that color ("TOP HAT - COBALT").
func _dye_title(id: String) -> String:
	var parts := _dye_parts(id)
	# i18n: SHOP status line (DYES), max 240px, 1 line: a hat name, then a dye name or ORIGINAL
	return Loc.t("wheel.dye_title", "{hat} - {dye}", {hat = Hats.display_name(parts[0]), dye = Hats.dye_name(parts[1])})


## The width the status lines may take: between the try-on slimes (DYES), or the panel's.
func _status_room() -> float:
	return STATUS_W if section == "hats" and tab == "shop" else PANEL.size.x - 2 * HEADER_INSET


## Lines `text` takes in the status room (1 in English).
func _status_lines(text: String) -> int:
	var room := _status_room()
	return 1 if UIKit.text_w(text) <= room else UIKit.wrapped_lines(text, room)


## Places the two status lines for the section's longest descriptions: the second ends on row 160 in
## English (PANEL_PAD above the panel's bottom with taller buttons), each line a line_pitch() below
## the one above, so a description that wraps takes room from the grid, never from the frame.
func _place_status(ids: Array[String]) -> void:
	var first := 1
	var second := 1
	for id in ids:
		var texts := _status_texts(id)
		first = maxi(first, _status_lines(texts[0]))
		second = maxi(second, _status_lines(texts[1]))
	if ids.is_empty():
		first = _status_lines(_empty_texts()[0])
		second = _status_lines(_empty_texts()[1])
	var bottom := PANEL.end.y - UIKit.PANEL_PAD if _compact() else STATUS_BOTTOM
	status_line_y = bottom - UIKit.text_block_h(second)
	status_y = status_line_y - first * UIKit.line_pitch()
	_status_first_lines = first
	_status_second_lines = second


## Fits a status line in its room from row `top`: as it is in English; a longer text wraps (onto the
## lines _place_status kept for it), never cut.
func _fit_status(label: Label, top: float, lines: int) -> void:
	var room := _status_room()
	var line_box := maxi(10, UIKit.line_h())
	if UIKit.text_w(label.text) <= room:
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.position.y != top:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.position = Vector2(PANEL.position.x, top)
			label.size = Vector2(PANEL.size.x, line_box)
		return
	label.add_theme_constant_override("line_spacing", UIKit.line_spacing())
	UIKit.fit_text(label, Rect2(CENTER.x - room / 2.0, top, room, line_box), Vector2(room, UIKit.text_block_h(maxi(lines, 2))), maxi(lines, 2), Vector2i(0, -1))


func _show_preview(id: String) -> void:
	preview.visible = not _is_hat(id) and not _is_dye(id) and Cosmetics.get_item(id).size() > 0
	_preview_floor.visible = preview.visible
	if not preview.visible:
		return
	var image: Image
	var material: ShaderMaterial = null
	if Cosmetics.kind_of(id) == Cosmetics.TRAIL:
		image = Cosmetics.trail_preview(id, Progress.skin_color(), Progress.is_rainbow(), Vector2i(30, 9))
		material = ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/trail.gdshader")
		material.set_shader_parameter("stars", 1.0 if id == "starry" else 0.0)
		material.set_shader_parameter("animate", 0.0 if Progress.reduce_motion else 1.0)
	else:
		image = paper_swatch(id, Progress.skin_color())
	preview.material = material
	preview.texture = ImageTexture.create_from_image(image)
	var scale := 2 if material else 3
	preview.size = Vector2(image.get_size() * scale)
	# Centred at y 112 (English), or halfway between the grid and the status lines when that would touch them.
	var shown := mini(rows_per_page, ceili(_section_ids().size() / 2.0))
	var grid_end := grid_top + shown * grid_step - GRID_GAP
	var center_y := 112.0
	var half := preview.size.y / 2.0 + 4.0
	if center_y - half < grid_end + UIKit.GAP_XS or center_y + half > status_y - UIKit.GAP_XS:
		center_y = roundf((grid_end + status_y) / 2.0)
	preview.position = (Vector2(CENTER.x, center_y) - preview.size / 2.0).round()
	_preview_floor.position = preview.position - Vector2(4, 4)  # a bit of dark floor round it
	_preview_floor.size = preview.size + Vector2(8, 8)


## Puts hat `id` (in dye `dye`) on the two try-on slimes (in the skin you wear now), or hides them ("").
func _show_try_on(id: String, dye := "") -> void:
	_try_on_root.visible = id != ""
	var key := "%s:%s:%s" % [tab, id, dye]
	if key == _try_on_id or id == "":
		return
	_try_on_id = key
	for child in _try_on_root.get_children():
		child.queue_free()
	var scale := 2 if tab == "wheel" else 1
	for at: Vector2 in TRY_ON[tab]:
		var slime := UIKit.make_slime_preview(Progress.skin_color(), scale, Progress.is_rainbow(), null, Progress.is_stopwatch())
		# (with the wheel, or beside the status lines: lower or higher with them in a taller script)
		slime.position = at + (Vector2(0, wheel_center.y - CENTER.y) if tab == "wheel" else Vector2(0, status_y - 141.0))
		_try_on_root.add_child(slime)
		var hat := Hat.new()
		hat.scale = slime.scale
		_try_on_root.add_child(hat)
		hat.setup(id, slime, null, dye)


## A scrap of map on paper `paper`: a little maze corner (floor cells, wall lines, a red route, a coin).
static func paper_swatch(paper: String, ink: Color) -> Image:
	var pal := MapView.palette("dungeon", paper, ink)
	var image := Image.create_empty(28, 10, false, Image.FORMAT_RGBA8)
	image.fill(pal.wall)
	image.fill_rect(Rect2i(1, 1, 26, 3), pal.floor)
	image.fill_rect(Rect2i(1, 6, 18, 3), pal.floor)
	image.fill_rect(Rect2i(23, 1, 3, 8), pal.floor)
	image.fill_rect(Rect2i(19, 6, 3, 3), pal.fog)
	for x in range(2, 25):
		image.set_pixel(x, 2, pal.route)
	for y in range(2, 8):
		image.set_pixel(24, y, pal.route)
	image.fill_rect(Rect2i(3, 7, 1, 1), pal.coin)
	return image


func _on_tile(id: String) -> void:
	if _is_hat(id):  # a dyeable hat: its colors
		_sfx("click", -6.0)
		dye_hat = id
		page = 0
		show_section("hats")
		return
	if _is_dye(id) and _owned(id):
		var parts := _dye_parts(id)
		if Progress.wear_dye(parts[0], parts[1]):
			changed.emit(parts[0])
		_rebuild_keep_focus(id)
		return
	if not _is_dye(id) and Progress.owns_cosmetic(id):
		if _worn(id):
			Progress.unequip_cosmetic(id)
		else:
			Progress.equip_cosmetic(id)
		changed.emit(id)
		_rebuild_keep_focus(id)
		return
	var can: bool = Progress.can_buy_dye(_dye_parts(id)[0], _dye_parts(id)[1]) if _is_dye(id) else Progress.can_buy_cosmetic(id)
	if not can:
		_sfx("click", -6.0, 0.6)
		_describe(id)
		return
	open_confirm(id)


func open_confirm(id: String) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	_confirm_id = id
	var name := _name_of(id)
	if _is_dye(id):
		# i18n: the buy confirm's name for a hat dye, e.g. BUY TEAL DYE?; max 120px with BUY ...?
		name = Loc.t("wheel.dye_name", "{dye} DYE", {dye = _name_of(id)})
	confirm_label.text = Loc.t("wheel.confirm", "BUY {name}?", {name = name})
	confirm_price.text = str(_price_of(id))
	confirm.visible = true
	_blocker.visible = true
	if _confirm_lock.is_empty():
		_confirm_lock = UIKit.lock_focus(self, confirm)
	confirm_back.grab_focus()


func close_confirm() -> void:
	if not confirm.visible:
		return
	confirm.visible = false
	_blocker.visible = false
	UIKit.unlock_focus(_confirm_lock)
	var id := _confirm_id
	_confirm_id = ""
	if shop_tiles.has(id) and is_instance_valid(shop_tiles[id]):
		(shop_tiles[id] as Button).grab_focus()
	elif tab == "shop":
		show_section(section)


func _buy_confirmed() -> void:
	var id := _confirm_id
	var ok: bool = Progress.buy_dye(_dye_parts(id)[0], _dye_parts(id)[1]) if _is_dye(id) else Progress.buy_cosmetic(id)
	confirm.visible = false
	_blocker.visible = false
	UIKit.unlock_focus(_confirm_lock)
	_confirm_id = ""
	if ok:
		_sfx("unlock", -4.0)
		balance.text = str(Progress.tickets)
		changed.emit(_dye_parts(id)[0] if _is_dye(id) else id)
	_rebuild_keep_focus(id)


## Rebuilds the section's tiles (prices, OWNED / WORN) and puts the focus back on `id`'s tile, or
## the first tile (a bought hat leaves the list), or the section button.
func _rebuild_keep_focus(id: String) -> void:
	show_section(section, false)
	if shop_tiles.has(id):
		(shop_tiles[id] as Button).grab_focus()
		_describe(id)
	elif not shop_tiles.is_empty():
		(shop_tiles.values()[0] as Button).grab_focus()
	else:
		(section_buttons[section] as Button).grab_focus()


func _sfx(sound: String, volume_db: float, pitch := 1.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound, volume_db, pitch)


func _draw() -> void:
	if tab != "wheel":
		return
	# Rim, then a wedge per hat (alternating colors), dividers, pegs, the hub, the hats, the flapper.
	draw_circle(wheel_center, wheel_radius + 4.0, RIM_DARK)
	draw_circle(wheel_center, wheel_radius + 3.0, RIM)
	var n := hats.size()
	if n == 0:
		draw_circle(wheel_center, wheel_radius, Color8(52, 30, 24))
	var plain := 0  # ordinary wedges so far, for alternating their colors
	var plain_count := 0
	for id in hats:
		if not Hats.get_hat(id).get("flows", false):
			plain_count += 1
	for i in n:
		var a0 := turn + starts[i]
		var lit := _won != "" and hats[i] == _won  # the winner, lit up under the pointer
		if Hats.get_hat(hats[i]).get("flows", false):
			# The rare hat's sliver: rainbow rings, red on the outside.
			for k in RAINBOW_RINGS.size():
				var outer := wheel_radius * (1.0 - k / float(RAINBOW_RINGS.size()))
				var color := RAINBOW_RINGS[k].lightened(0.4) if lit else RAINBOW_RINGS[k]
				draw_colored_polygon(_wedge(a0, sizes[i], outer), color)
			continue
		var color := WEDGE_COLORS[plain % WEDGE_COLORS.size()]
		if plain_count % WEDGE_COLORS.size() == 1 and plain == plain_count - 1 and plain_count > 1:
			color = WEDGE_COLORS[2]  # keep the last wedge from matching the first
		plain += 1
		draw_colored_polygon(_wedge(a0, sizes[i], wheel_radius), color.lightened(0.45) if lit else color)
	for i in n:
		var a := turn + starts[i]
		draw_line(wheel_center, wheel_center + Vector2(cos(a), sin(a)) * wheel_radius, DIVIDER, 1.0)
		var peg := (wheel_center + Vector2(cos(a), sin(a)) * (wheel_radius + 1.5)).round()
		draw_rect(Rect2(peg - Vector2(1, 1), Vector2(2, 2)), PEG)
	_flow_step = Hats.flow_step()
	draw_circle(wheel_center, 6.0, Color8(209, 136, 58))
	draw_circle(wheel_center, 4.0, Color8(255, 205, 117))
	var atlas: Texture2D = preload("res://assets/sprites/hats.png")
	for i in n:
		var a := turn + starts[i] + sizes[i] / 2.0
		# Out toward the rim in a thin wedge, where it has the most room.
		var reach := 0.7 if sizes[i] > 0.4 else 0.8
		var at := (wheel_center + Vector2(cos(a), sin(a)) * wheel_radius * reach).round()
		# The loose version (its own shape, inside showing; narrow, so neighbors don't touch). The
		# rainbow hat flows like it does on a slime (its shader can't go on one draw call).
		if Hats.get_hat(hats[i]).get("flows", false):
			draw_texture(Hats.flow_texture(hats[i], Hats.Width.LOOSE, _flow_step), at - Vector2(Hats.FRAME) / 2.0)
		else:
			draw_texture_rect_region(atlas, Rect2(at - Vector2(Hats.FRAME) / 2.0, Vector2(Hats.FRAME)), Hats.region(hats[i], Hats.Width.LOOSE))
	# The flapper at the top, kicked aside as it ticks past each wedge.
	var tip := Vector2(wheel_center.x + roundf(_kick * 2.0), wheel_center.y - wheel_radius + 6.0)
	var base_y := wheel_center.y - wheel_radius - 7.0
	draw_colored_polygon(PackedVector2Array([Vector2(wheel_center.x - 4, base_y), Vector2(wheel_center.x + 4, base_y), tip]), FLAPPER)
	draw_rect(Rect2(wheel_center.x - 5, base_y - 3, 10, 3), Color8(132, 138, 162))


## A wedge of the wheel from angle a0, `size` radians wide, out to `radius`.
func _wedge(a0: float, size: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array([wheel_center])
	var steps := maxi(3, int(size * 12.0))
	for s in steps + 1:
		var a := a0 + size * s / steps
		points.append(wheel_center + Vector2(cos(a), sin(a)) * radius)
	return points
