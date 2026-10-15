class_name HatWheel
extends Control

## The prize wheel's overlay, opened at the prize wheel in the hub: two tabs, WHEEL | SHOP
## (upgrades v2 batch 2, docs/design/upgrades-v2.md C.1-C.3).
## WHEEL: a big wheel with a wedge for every hat you don't have yet, each showing its hat; a wedge's
## size is its odds (Hats.weight), so the rare rainbow hat gets a thin rainbow-striped sliver. A spin
## (the SPIN button, or the interact key / JUMP on a touchscreen) whirls it round (the flapper ticking
## on each wedge it passes), slows down and lands on a random hat. The spin is settled before the
## wheel turns (Progress.spin_hat picks the hat, charges its price (free first, then 12, +2 per spin
## taken, max 40; dev mode never pays) and wins it, all saved at once); the wheel just plays out
## where it lands. A won hat comes off the wheel, so there are never duplicates: an empty wheel once
## every hat is yours.
## SHOP: three sections (HATS, TRAILS, PAPERS) of goo-framed tiles with their prices and the ticket
## icon. HATS = the TAILOR: any hat still on the wheel for 45 tickets (rainbow 80) once 3 spins have
## been taken (a buy counts as a spin). TRAILS / PAPERS = Cosmetics; an owned one is worn / taken off
## by pressing its tile. Buying asks once (BUY GOLD TRAIL? 30 [ticket]  BUY / BACK, focus on BACK).
## Focus stays inside (the confirm, when open, locks it); Esc / B close the confirm first, then the
## overlay (the hub does that, via `back`). The hub opens and closes it and passes on the spin key.
## On a touchscreen there is no key to close it, so a BACK button shows in the header (mirroring the SHOP
## tab, `show_close`); a tap anywhere else never spins (the hub's JUMP mapping is off while it's open).

signal landed(hat_id: String)
## The SPIN button started a spin, something was bought in the SHOP (a hat or cosmetic id), or a
## cosmetic was worn / taken off ("" for a spin).
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
const SECTIONS := ["hats", "trails", "papers"]
## Where the try-on slimes stand (centers): either side of the wheel at 2x after a win, or of the
## text under the shop grid at 1x (clear of the grid's last row, whatever hat).
const TRY_ON := {"wheel": [Vector2(56, 92), Vector2(264, 92)], "shop": [Vector2(30, 154), Vector2(290, 154)]}

## The hats on the wheel right now (the ones not won yet), in wheel order.
var hats: Array[String] = []:
	set(value):
		hats = value
		_layout()
## Where each wedge starts (radians from the wheel's zero) and how wide it is: shares of the
## circle by Hats.weight.
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
## (WHEEL), or the TAILOR's hat you're looking at (SHOP). `_try_on_id` = "tab:hat" they're dressed for.
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
	title = _label("HAT WHEEL", UIKit.GOLD, HEADER_Y + 3)  # on the tabs' text baseline
	# The ticket balance, top right of the panel.
	balance = UIKit.make_label("", UIKit.FONT, TICKET_TINT)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.position = Vector2(PANEL.end.x - 50, HEADER_Y + 3)
	balance.size = Vector2(32, 10)
	add_child(balance)
	_balance_icon = UIKit.make_icon("ticket", Color.WHITE)
	_balance_icon.position = Vector2(PANEL.end.x - HEADER_INSET - 8, HEADER_Y + 3)  # mirrors the WHEEL tab's inset
	add_child(_balance_icon)
	wheel_tab = UIKit.make_button("WHEEL", func() -> void: show_tab("wheel"), Vector2(44, UIKit.TAB_H))
	wheel_tab.position = Vector2(PANEL.position.x + HEADER_INSET, HEADER_Y)
	add_child(wheel_tab)
	shop_tab = UIKit.make_button("SHOP", func() -> void: show_tab("shop"), Vector2(44, UIKit.TAB_H))
	shop_tab.position = Vector2(PANEL.position.x + HEADER_INSET + 44 + 2, HEADER_Y)
	add_child(shop_tab)
	close_button = UIKit.make_button("BACK", func() -> void: close_requested.emit(), Vector2(44, UIKit.TAB_H))
	close_button.position = Vector2(320 - shop_tab.position.x - 44, HEADER_Y)  # the SHOP tab's mirror
	close_button.visible = false
	add_child(close_button)

	wheel_page = _page()
	result = _label("", UIKit.TEXT, 146, wheel_page)
	spin_button = UIKit.make_button("SPIN", _on_spin_pressed, Vector2(84, UIKit.BUTTON_H))
	spin_button.position = Vector2(roundf(CENTER.x - 42), 158)
	spin_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wheel_page.add_child(spin_button)

	shop_page = _page()
	var x := roundf(CENTER.x - (3 * 52 + 2 * 4) / 2.0)
	for id: String in SECTIONS:
		var button := UIKit.make_button(id.to_upper(), func() -> void: show_section(id), Vector2(52, UIKit.TAB_H))
		button.position = Vector2(x, 28)
		x += 56
		shop_page.add_child(button)
		section_buttons[id] = button
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
	status = _label("", UIKit.TEXT, 141, shop_page)
	status_line = _label("", UIKit.TEXT_DIM, 153, shop_page)
	_try_on_root = Node2D.new()  # (under the confirm and its dim sheet)
	add_child(_try_on_root)
	_build_confirm()
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
	label.size = Vector2(PANEL.size.x, 10)
	return label


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
	return false


## Switches between the WHEEL and the SHOP and focuses something on it.
func show_tab(which: String, focus := true) -> void:
	if spinning:
		return
	tab = which
	var shop := tab == "shop"
	wheel_page.visible = not shop
	shop_page.visible = shop
	title.text = "SHOP" if shop else "HAT WHEEL"
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
	_spin_key = spin_key
	if tab == "wheel" and not spinning:
		_refresh_wheel()


## Shows the header's BACK (touch: there is no Esc / B to close the overlay).
func show_close(on: bool) -> void:
	close_button.visible = on


## Fills the overlay for the state of play. `opening`: the hub just opened it (WHEEL first, or the
## SHOP when every hat is already won; focus inside). Right after a win the won hat stays where it
## landed, lit up under the pointer, until the next spin takes it off.
func refresh(spin_key: String, opening := false) -> void:
	_spin_key = spin_key
	if opening:
		_won = ""
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
	if _won == "" and not spinning:  # (mid-spin the won hat stays on until it has landed)
		hats = Progress.hats_left()
	balance.text = str(Progress.tickets)
	var can: bool = Progress.can_spin_hats() and not spinning
	var cost: int = Progress.spin_cost()
	if Progress.hats_left().is_empty() and _won == "":
		result.text = "EVERY HAT WON! NEW LOOKS IN THE SHOP"
	elif spinning:
		result.text = "..."
	elif _won != "":
		result.text = "YOU WON THE %s!" % Hats.display_name(_won)
	elif not Hats.available and not Progress.dev_tools:
		result.text = "THE WHEEL IS RESTING"
	elif not can:
		result.text = "NEED %d TICKETS TO SPIN" % cost
	else:
		result.text = "%d HAT%s TO WIN" % [hats.size(), "" if hats.size() == 1 else "S"] \
			+ ("" if _spin_key == "" else " - %s TO SPIN" % _spin_key)  # (touch: no key, the SPIN button)
	_show_try_on(_won if not spinning else "")  # the hat you just won, on you
	spin_button.disabled = not can
	if Progress.hats_left().is_empty():
		spin_button.text = "SPIN"
		spin_button.icon = null
	elif cost == 0:
		spin_button.text = "SPIN  FREE"
		spin_button.icon = null
	else:
		spin_button.text = "SPIN  %d" % cost
		spin_button.icon = load(UIKit.UI_DIR + "icon_ticket.png")
	# A disabled button never takes the keyboard (arrows skip it): the tabs while the wheel turns, SPIN
	# when it can't spin (mid-spin it keeps the focus it has).
	spin_button.focus_mode = Control.FOCUS_ALL if can or spinning else Control.FOCUS_NONE
	for button: Button in [wheel_tab, shop_tab, close_button]:
		button.disabled = spinning
		button.focus_mode = Control.FOCUS_NONE if spinning else Control.FOCUS_ALL


func _on_spin_pressed() -> void:
	if spin():
		changed.emit("")


## Sizes the wedges by each hat's odds.
func _layout() -> void:
	starts.clear()
	sizes.clear()
	var total := 0.0
	for id in hats:
		total += Hats.weight(id, Progress.rainbow_pity)
	var at := 0.0
	for id in hats:
		starts.append(at)
		sizes.append(TAU * Hats.weight(id, Progress.rainbow_pity) / total)
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

## Shows a SHOP section's tiles: HATS (the TAILOR), TRAILS or PAPERS.
func show_section(which: String, focus := true) -> void:
	section = which
	for id: String in section_buttons:
		UIKit.set_selected(section_buttons[id], id == section)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	shop_tiles.clear()
	var ids := _section_ids()
	for i in ids.size():
		var tile := _make_tile(ids[i])
		tile.position = Vector2(GRID_LEFT[i % 2], GRID_TOP + (i / 2) * GRID_STEP)
		_grid.add_child(tile)
		shop_tiles[ids[i]] = tile
	balance.text = str(Progress.tickets)
	if ids.is_empty():
		_show_try_on("")
		status.text = "EVERY HAT IS YOURS"
		status_line.text = "WEAR THEM IN THE WARDROBE"
	else:
		_describe(ids[0])
	if focus:
		(shop_tiles[ids[0]] if not ids.is_empty() else section_buttons[section]).grab_focus()


func _section_ids() -> Array[String]:
	match section:
		"hats":
			return Progress.hats_left()
		"trails":
			return Cosmetics.ids(Cosmetics.TRAIL)
	return Cosmetics.ids(Cosmetics.PAPER)


func _is_hat(id: String) -> bool:
	return not Hats.get_hat(id).is_empty()


func _name_of(id: String) -> String:
	return Hats.display_name(id) if _is_hat(id) else Cosmetics.display_name(id)


func _price_of(id: String) -> int:
	return Progress.tailor_price(id) if _is_hat(id) else Progress.cosmetic_price(id)


func _worn(id: String) -> bool:
	return Progress.trail_style == id or Progress.map_paper == id


## A goo-framed tile: the item's name, and its price with the ticket icon (or OWNED / WORN).
func _make_tile(id: String) -> Button:
	var tile := UIKit.make_button("", func() -> void: _on_tile(id), TILE)
	var name_label := UIKit.make_label(_name_of(id), UIKit.FONT, UIKit.TEXT)
	name_label.position = Vector2(4, 3)
	tile.add_child(name_label)
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", UIKit.GAP_XS)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.position = Vector2(TILE.x - 4 - 40, 2)
	right.size = Vector2(40, 9)
	tile.add_child(right)
	if not _is_hat(id) and Progress.owns_cosmetic(id):
		right.add_child(UIKit.make_label("WORN" if _worn(id) else "OWNED", UIKit.FONT, UIKit.GOLD if _worn(id) else UIKit.TEXT_DIM))
		if _worn(id):
			UIKit.set_selected(tile, true)
	else:
		var price := _price_of(id)
		var affordable := price <= Progress.tickets and (not _is_hat(id) or Progress.tailor_open())
		right.add_child(UIKit.make_label("FREE" if price == 0 else str(price), UIKit.FONT, UIKit.TEXT if affordable else UIKit.TEXT_OFF))
		if price > 0:
			right.add_child(UIKit.make_icon("ticket", Color.WHITE if affordable else Color(0.55, 0.55, 0.6)))
	tile.focus_entered.connect(func() -> void: _describe(id))
	tile.mouse_entered.connect(func() -> void: _describe(id))
	return tile


## The two status lines for item `id`: its name and what pressing it does (or why it can't), and
## its picture (trails and papers).
func _describe(id: String) -> void:
	_show_preview(id)
	_show_try_on(id if _is_hat(id) else "")
	if _is_hat(id):
		status.text = Hats.display_name(id) + " - FROM THE TAILOR"
		if not Progress.tailor_open():
			status_line.text = "THE TAILOR OPENS AFTER %d SPINS (%d/%d)" % [Economy.TAILOR_AFTER_SPINS,
				mini(Progress.spins, Economy.TAILOR_AFTER_SPINS), Economy.TAILOR_AFTER_SPINS]
		elif Progress.tailor_price(id) > Progress.tickets:
			status_line.text = "NEED %d TICKETS" % Progress.tailor_price(id)
		else:
			status_line.text = "NO LUCK NEEDED (COUNTS AS A SPIN)"
		return
	status.text = "%s - %s" % [Cosmetics.display_name(id), Cosmetics.get_item(id).get("about", "")]
	if Progress.owns_cosmetic(id):
		status_line.text = "PRESS TO TAKE IT OFF" if _worn(id) else "PRESS TO WEAR IT"
	elif Progress.cosmetic_price(id) > Progress.tickets:
		status_line.text = "NEED %d TICKETS" % Progress.cosmetic_price(id)
	else:
		status_line.text = "PRESS TO BUY"


func _show_preview(id: String) -> void:
	preview.visible = not _is_hat(id) and Cosmetics.get_item(id).size() > 0
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
	preview.position = (Vector2(CENTER.x, 112) - preview.size / 2.0).round()
	_preview_floor.position = preview.position - Vector2(4, 4)  # a bit of dark floor round it
	_preview_floor.size = preview.size + Vector2(8, 8)


## Puts hat `id` on the two try-on slimes (in the skin you wear now), or hides them ("").
func _show_try_on(id: String) -> void:
	_try_on_root.visible = id != ""
	var key := tab + ":" + id
	if key == _try_on_id or id == "":
		return
	_try_on_id = key
	for child in _try_on_root.get_children():
		child.queue_free()
	var scale := 2 if tab == "wheel" else 1
	for at: Vector2 in TRY_ON[tab]:
		var slime := UIKit.make_slime_preview(Progress.skin_color(), scale, Progress.is_rainbow(), null, Progress.is_stopwatch())
		slime.position = at
		_try_on_root.add_child(slime)
		var hat := Hat.new()
		hat.scale = slime.scale
		_try_on_root.add_child(hat)
		hat.setup(id, slime)


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
	if not _is_hat(id) and Progress.owns_cosmetic(id):
		if _worn(id):
			Progress.unequip_cosmetic(id)
		else:
			Progress.equip_cosmetic(id)
		changed.emit(id)
		_rebuild_keep_focus(id)
		return
	var can: bool = Progress.can_buy_hat(id) if _is_hat(id) else Progress.can_buy_cosmetic(id)
	if not can:
		_sfx("click", -6.0, 0.6)
		_describe(id)
		return
	open_confirm(id)


func open_confirm(id: String) -> void:
	_confirm_id = id
	confirm_label.text = "BUY %s?" % _name_of(id)
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
	var ok: bool = Progress.buy_hat(id) if _is_hat(id) else Progress.buy_cosmetic(id)
	confirm.visible = false
	_blocker.visible = false
	UIKit.unlock_focus(_confirm_lock)
	_confirm_id = ""
	if ok:
		_sfx("unlock", -4.0)
		balance.text = str(Progress.tickets)
		changed.emit(id)
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
	draw_circle(CENTER, RADIUS + 4.0, RIM_DARK)
	draw_circle(CENTER, RADIUS + 3.0, RIM)
	var n := hats.size()
	if n == 0:
		draw_circle(CENTER, RADIUS, Color8(52, 30, 24))
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
				var outer := RADIUS * (1.0 - k / float(RAINBOW_RINGS.size()))
				var color := RAINBOW_RINGS[k].lightened(0.4) if lit else RAINBOW_RINGS[k]
				draw_colored_polygon(_wedge(a0, sizes[i], outer), color)
			continue
		var color := WEDGE_COLORS[plain % WEDGE_COLORS.size()]
		if plain_count % WEDGE_COLORS.size() == 1 and plain == plain_count - 1 and plain_count > 1:
			color = WEDGE_COLORS[2]  # keep the last wedge from matching the first
		plain += 1
		draw_colored_polygon(_wedge(a0, sizes[i], RADIUS), color.lightened(0.45) if lit else color)
	for i in n:
		var a := turn + starts[i]
		draw_line(CENTER, CENTER + Vector2(cos(a), sin(a)) * RADIUS, DIVIDER, 1.0)
		var peg := (CENTER + Vector2(cos(a), sin(a)) * (RADIUS + 1.5)).round()
		draw_rect(Rect2(peg - Vector2(1, 1), Vector2(2, 2)), PEG)
	_flow_step = Hats.flow_step()
	draw_circle(CENTER, 6.0, Color8(209, 136, 58))
	draw_circle(CENTER, 4.0, Color8(255, 205, 117))
	var atlas: Texture2D = preload("res://assets/sprites/hats.png")
	for i in n:
		var a := turn + starts[i] + sizes[i] / 2.0
		# Out toward the rim in a thin wedge, where it has the most room.
		var reach := 0.7 if sizes[i] > 0.4 else 0.8
		var at := (CENTER + Vector2(cos(a), sin(a)) * RADIUS * reach).round()
		# The loose version (its own shape, inside showing; narrow, so neighbors don't touch). The
		# rainbow hat flows like it does on a slime (its shader can't go on one draw call).
		if Hats.get_hat(hats[i]).get("flows", false):
			draw_texture(Hats.flow_texture(hats[i], Hats.Width.LOOSE, _flow_step), at - Vector2(Hats.FRAME) / 2.0)
		else:
			draw_texture_rect_region(atlas, Rect2(at - Vector2(Hats.FRAME) / 2.0, Vector2(Hats.FRAME)), Hats.region(hats[i], Hats.Width.LOOSE))
	# The flapper at the top, kicked aside as it ticks past each wedge.
	var tip := Vector2(CENTER.x + roundf(_kick * 2.0), CENTER.y - RADIUS + 6.0)
	var base_y := CENTER.y - RADIUS - 7.0
	draw_colored_polygon(PackedVector2Array([Vector2(CENTER.x - 4, base_y), Vector2(CENTER.x + 4, base_y), tip]), FLAPPER)
	draw_rect(Rect2(CENTER.x - 5, base_y - 3, 10, 3), Color8(132, 138, 162))


## A wedge of the wheel from angle a0, `size` radians wide, out to `radius`.
func _wedge(a0: float, size: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array([CENTER])
	var steps := maxi(3, int(size * 12.0))
	for s in steps + 1:
		var a := a0 + size * s / steps
		points.append(CENTER + Vector2(cos(a), sin(a)) * radius)
	return points
