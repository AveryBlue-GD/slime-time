extends Control

## The cauldron: tabs COINS | TICKETS (upgrades v2, docs/design/upgrades-v2.md C.3 and "Abilities v1").
## COINS: the upgrade tree, one line per upgrade (owner: no explanations, just let them be): its name,
## its level as one uniform bar of fat pips (7 / 4 / 3), - / + to take a coin level back out or put
## one in at any time, and the next level's cost (MAX when maxed). No row is recommended or marked
## (owner, D12: the game never nudges toward an upgrade). Buying BRIGHTNESS flashes a 1 s light-ring picture
## (no text). Dev-only upgrades (wall power) only appear in dev mode. Tracks: Economy.COIN_TRACKS.
## TICKETS (Economy.ABILITIES_ENABLED): the three ABILITIES (Abilities), a row each with its icon,
## name, a 2-3 word tag, level pips, + and the price with the ticket icon (not refundable: a BUY /
## BACK confirm); locked (EARN TICKETS IN THE RANDOMIZER) until the player has ever had a ticket.
## The old WORKSHOP (Workshop, Economy.WORKSHOP; five 3-level tracks with effect lines) is switched
## off (Economy.WORKSHOP_ENABLED); with the test hook on it comes back on a TOOLS tab (page "tickets",
## its legacy name) and the title makes room for the third tab.
## The pod top right shows coins or tickets, following the tab. Esc / B / BACK leave the screen
## from either tab (a tab is not an overlay, so nothing stacks).

## COINS rows: one line each, centered in a panel ROW_HEIGHT - 3 tall.
const ROW_TOP := 28
const ROW_HEIGHT := 26
## The ABILITIES rows (icon, name over tag), ABILITY_ROW_HEIGHT apart.
const ABILITY_ROW_TOP := 28
const ABILITY_ROW_HEIGHT := 30
## The workshop's five rows (two lines each: name, effect) from TICKET_ROW_TOP, TICKET_ROW_HEIGHT apart
## (panels 2 px shorter): 24 + 5 x 25 = 149, leaving one hint line above the bottom buttons. (The
## spec's 26 + 5 x 24 put the effect line on the goo band of its panel.)
const TICKET_ROW_TOP := 24
const TICKET_ROW_HEIGHT := 25
## Every level bar has the same total width BAR_WIDTH (so MORE SLIME 7, SPEED 4, BRIGHTNESS 3 and the
## workshop's 3 line up), split into one whole-pixel segment per level with BAR_GAP px between them:
## 83 = 7 x 11 + 6 = 4 x 20 + 3 = 3 x 27 + 2. The bars end at PIPS_RIGHT (against the - button at 226).
const BAR_WIDTH := 83
const BAR_HEIGHT := 6
const PIP_GAP := 1
const PIPS_RIGHT := 222
## A row's controls, GAP_M (4) apart: bar | - | + | cost (- at 226, so the two 16 px buttons keep
## a 4 px gap for touch: their grown hit areas split it).
const MINUS_X := 226
const PLUS_X := 246
const COST_X := 266
## The ABILITIES page's hint: its keys (read from the bindings; the pad buttons after pad input, the on-screen
## buttons on touch) and where they work (randomizer mazes and Descent only). See ability_hint.
## Presses of a buy closer together than this are ignored (a double tap). Timed on the engine's
## clock (a SceneTreeTimer), so it plays out the same in fixed-fps runs on a loaded machine.
const BUY_GUARD_TIME := 0.3
const PREVIEW_TIME := 1.0
## The tab the next opening shows ("coins", "abilities" or, with the workshop on, "tickets"), for that one opening (demos and tests set
## it); the hub's cauldron always opens on COINS.
static var open_tab := "coins"

## The coin rows (by track id) and the workshop rows.
var rows := {}
var ticket_rows := {}
## The ABILITIES rows by id: {icon, name, tag, pips, plus, cost, ticket}.
var ability_rows := {}
var abilities_tab: Button
var ability_page: Control
var coin_label: Label
var pod_icon: TextureRect
var skin_text: SkinText
## "coins", "abilities" or "tickets" (the workshop).
var page := "coins"
var coins_tab: Button
var tickets_tab: Button
var coin_page: Control
var ticket_page: Control
var hint: Label
var back: Button
var _rows_bottom := {}
## The TICKETS tab's BUY / BACK confirm (like the SHOP's): the workshop is not refundable.
var confirm: Control
var confirm_label: Label
var confirm_price: Label
var confirm_buy: Button
var confirm_back: Button
var _blocker: ColorRect
var _confirm_id := ""
## What the confirm buys: "ability" or "workshop".
var _confirm_kind := ""
var _confirm_lock := {}
## True for BUY_GUARD_TIME s after a buy.
var _buy_guarded := false
## The dim tag on the MORE SLIME row (shown until it is maxed) and the 1 s BRIGHTNESS light-ring
## preview (null when not showing).
var preview: Control


func _ready() -> void:
	var workshop_on := Economy.workshop_on()
	var abilities_on := Economy.abilities_on()
	# (three tabs need the title's room)
	skin_text = UIKit.setup_screen(self, "" if workshop_on and abilities_on else Loc.t("upgrades.title", "UPGRADES"))  # i18n: title max 200px, 16 px font
	var coin_pod := PanelContainer.new()
	coin_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	add_child(coin_pod)
	# Top-right corner, as far from the edges as BACK is in its corner.
	coin_pod.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_pod.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	coin_pod.offset_left = -UIKit.EDGE
	coin_pod.offset_right = -UIKit.EDGE
	coin_pod.offset_top = UIKit.EDGE
	coin_pod.custom_minimum_size.y = UIKit.POD_H
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", UIKit.GAP_S)
	coin_pod.add_child(coin_row)
	pod_icon = UIKit.make_icon("coin", Color.WHITE)
	coin_row.add_child(pod_icon)
	# Sized to its text (the pod grows leftward from the edge): the content pads stay 4 / 4.
	coin_label = UIKit.make_label("", UIKit.FONT, UIKit.TEXT)
	coin_row.add_child(coin_label)

	# The tabs, top left (mirroring the pod).
	if workshop_on or abilities_on:  # (one page only with both switched off: no tab bar)
		# i18n: tab, max 32px (40 wide, 4 px margins), 1 line
		coins_tab = UIKit.make_button(Loc.t("upgrades.tab_coins", "COINS"), func() -> void: show_page("coins"), Vector2(40, UIKit.TAB_H))
		coins_tab.position = Vector2(4, 4)
		add_child(coins_tab)
	if abilities_on:
		# i18n: tab, max 44px (52 wide, 4 px margins), 1 line
		abilities_tab = UIKit.make_button(Loc.t("upgrades.tab_tickets", "TICKETS"), func() -> void: show_page("abilities"), Vector2(52, UIKit.TAB_H))
		abilities_tab.position = Vector2(46, 4)
		add_child(abilities_tab)
	if workshop_on:
		# i18n: tab, TOOLS max 32px (40 wide) or TICKETS max 44px (52 wide), 1 line
		tickets_tab = UIKit.make_button(Loc.t("upgrades.tab_tools", "TOOLS") if abilities_on else Loc.t("upgrades.tab_tickets", "TICKETS"), func() -> void: show_page("tickets"),
			Vector2(40 if abilities_on else 52, UIKit.TAB_H))
		tickets_tab.position = Vector2(100 if abilities_on else 46, 4)
		add_child(tickets_tab)

	coin_page = _make_page()
	var y := ROW_TOP
	for upgrade: Dictionary in Upgrades.LIST:
		if upgrade.get("dev", false) and not Progress.dev_tools:
			continue
		_make_row(coin_page, upgrade, y)
		y += ROW_HEIGHT
	_rows_bottom["coins"] = y - 5

	if workshop_on:
		ticket_page = _make_page()
		y = TICKET_ROW_TOP
		for item: Dictionary in Workshop.LIST:
			_make_ticket_row(item, y)
			y += TICKET_ROW_HEIGHT
		_rows_bottom["tickets"] = y - 4

	if abilities_on:
		ability_page = _make_page()
		y = ABILITY_ROW_TOP
		for item: Dictionary in Abilities.LIST:
			_make_ability_row(item, y)
			y += ABILITY_ROW_HEIGHT
		_rows_bottom["abilities"] = y - 5

	hint = UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back = UIKit.add_back_button(self)
	if Progress.return_to_game:  # came here from a dry-up: go straight back into the level
		back.text = Loc.t("upgrades.play", "PLAY")  # i18n: replaces BACK, max 32px, 1 line
		back.pressed.disconnect(back.pressed.get_connections()[-1].callable)
		back.pressed.connect(_leave)
	if workshop_on or abilities_on:
		_build_confirm()
	show_page(open_tab)
	open_tab = "coins"  # (one opening only)


func _make_page() -> Control:
	var page_root := Control.new()
	page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page_root)
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page_root


## Shows the COINS or TICKETS tab and focuses its first + (or the TICKETS tab, while the workshop
## is still shut).
func show_page(which: String) -> void:
	if which == "tickets" and ticket_page == null or which == "abilities" and ability_page == null \
			or not which in ["coins", "tickets", "abilities"]:
		which = "coins"
	page = which
	var tickets := page != "coins"
	coin_page.visible = page == "coins"
	if ticket_page != null:
		ticket_page.visible = page == "tickets"
	if ability_page != null:
		ability_page.visible = page == "abilities"
	for pair: Array in [[coins_tab, "coins"], [tickets_tab, "tickets"], [abilities_tab, "abilities"]]:
		if pair[0] != null:
			UIKit.set_selected(pair[0], page == pair[1])
	pod_icon.texture = load(UIKit.UI_DIR + ("icon_ticket.png" if tickets else "icon_coin.png"))
	# Centered between the last row's panel and the bottom buttons (COINS: two lines, 7 + LINE_SPACING
	# + 7 px; TICKETS: one line).
	var hint_height := 7 if tickets else 14 + UIKit.LINE_SPACING
	var rows_bottom: int = _rows_bottom[page]
	hint.offset_top = rows_bottom + floori((164 - rows_bottom - hint_height) / 2.0)
	hint.offset_bottom = hint.offset_top + hint_height + 2
	_refresh()
	var first: Button = null
	if page == "abilities":
		first = ability_rows[Abilities.LIST[0].id].plus if Progress.abilities_open() else abilities_tab
	elif tickets:
		first = ticket_rows[Workshop.LIST[0].id].plus if Progress.workshop_open() else tickets_tab
	elif not rows.is_empty():
		first = rows[Upgrades.LIST[0].id].plus
	if first:
		first.grab_focus()
	skin_text.recolor.call_deferred()


## A COINS row on one line, everything centered on the panel's middle (y + 9.5): name, bar, - / +,
## cost. Every row looks the same (no tag on any track, D12).
func _make_row(parent: Control, upgrade: Dictionary, y: int) -> void:
	UIKit.add_panel(parent, Rect2(10, y - 2, 300, ROW_HEIGHT - 3))
	var name_label := UIKit.make_label(Upgrades.display_name(upgrade.id), UIKit.FONT, UIKit.GOLD if upgrade.get("dev", false) else UIKit.TEXT)
	name_label.position = Vector2(18, y + 6)
	parent.add_child(name_label)
	var pips := _make_pips(parent, Upgrades.max_level(upgrade.id), y + 3)
	var minus := UIKit.make_button("-", func() -> void: _change(upgrade.id, false), Vector2(16, UIKit.BUTTON_H))
	minus.position = Vector2(MINUS_X, y + 3)
	parent.add_child(minus)
	var plus := UIKit.make_button("+", func() -> void: _change(upgrade.id, true), Vector2(16, UIKit.BUTTON_H))
	plus.position = Vector2(PLUS_X, y + 3)
	parent.add_child(plus)
	var cost := UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	cost.position = Vector2(COST_X, y + 6)
	parent.add_child(cost)
	rows[upgrade.id] = {pips = pips, minus = minus, plus = plus, cost = cost, name = name_label, y = y}


## An ABILITIES row: the icon (2x), name over its short tag, 3 pips, + and the price with the ticket
## icon.
func _make_ability_row(item: Dictionary, y: int) -> void:
	UIKit.add_panel(ability_page, Rect2(10, y - 2, 300, ABILITY_ROW_HEIGHT - 3))
	var icon := Abilities.make_icon(item.id, 2)
	icon.position = Vector2(17, y + 3)
	ability_page.add_child(icon)
	var name_label := UIKit.make_label(Abilities.display_name(item.id), UIKit.FONT, UIKit.TEXT)
	name_label.position = Vector2(40, y + 2)
	ability_page.add_child(name_label)
	var tag := UIKit.make_label(Abilities.tag(item.id), UIKit.FONT, UIKit.TEXT_DIM)
	tag.position = Vector2(40, y + 13)
	ability_page.add_child(tag)
	var pips := _make_pips(ability_page, Abilities.max_level(item.id), y + 5)
	var plus := UIKit.make_button("+", func() -> void: _buy_ability(item.id), Vector2(16, UIKit.BUTTON_H))
	plus.position = Vector2(PLUS_X, y + 5)
	ability_page.add_child(plus)
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 2)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.position = Vector2(COST_X, y + 8)  # the price text on the + button's text row (y + 8)
	ability_page.add_child(price)
	var cost := UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	price.add_child(cost)
	var ticket := UIKit.make_icon("ticket", Color.WHITE)
	price.add_child(ticket)
	ability_rows[item.id] = {icon = icon, name = name_label, tag = tag, pips = pips, plus = plus, cost = cost, ticket = ticket}


## A workshop row: name, effect now -> next, 3 pips, + and the price with the ticket icon.
func _make_ticket_row(item: Dictionary, y: int) -> void:
	UIKit.add_panel(ticket_page, Rect2(10, y - 2, 300, TICKET_ROW_HEIGHT - 2))
	var name_label := UIKit.make_label(Workshop.display_name(item.id), UIKit.FONT, UIKit.TEXT)
	name_label.position = Vector2(18, y + 1)
	ticket_page.add_child(name_label)
	var about := UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	about.position = Vector2(18, y + 11)
	ticket_page.add_child(about)
	var pips := _make_pips(ticket_page, Workshop.max_level(item.id), y)
	var plus := UIKit.make_button("+", func() -> void: _buy_workshop(item.id), Vector2(16, UIKit.BUTTON_H))
	plus.position = Vector2(PLUS_X, y)
	ticket_page.add_child(plus)
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 2)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.position = Vector2(COST_X, y + 2)
	ticket_page.add_child(price)
	var cost := UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	price.add_child(cost)
	var icon := UIKit.make_icon("ticket", Color.WHITE)
	price.add_child(icon)
	ticket_rows[item.id] = {pips = pips, plus = plus, cost = cost, icon = icon, about = about}


func _make_pips(parent: Control, count: int, y: int) -> Array[ColorRect]:
	var pips: Array[ColorRect] = []
	var left := PIPS_RIGHT - BAR_WIDTH
	for i in count:
		var edge_a := left + (BAR_WIDTH + PIP_GAP) * i / count  # whole pixels; equal when count divides 83 + 1 - ...
		var edge_b := left + (BAR_WIDTH + PIP_GAP) * (i + 1) / count - PIP_GAP
		var pip := ColorRect.new()
		pip.position = Vector2(edge_a, y + 3)
		pip.size = Vector2(edge_b - edge_a, BAR_HEIGHT)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(pip)
		pips.append(pip)
	return pips


func _change(id: String, up: bool) -> void:
	var before: int = Progress.upgrade_level(id)
	var changed: bool = Progress.buy_upgrade(id) if up else Progress.refund_upgrade(id)
	if changed and up and id == "brightness":
		_show_preview(Upgrades.reveal_radius(before), Upgrades.reveal_radius(before + 1))
	if changed and up:
		_upgrade_sound(Progress.upgrade_level(id), Upgrades.max_level(id))
	_refresh()


## The row's + opens the confirm (nothing is spent yet).
func _buy_workshop(id: String) -> void:
	if confirm.visible or _buy_guarded:
		return
	if not Progress.can_buy_workshop(id):
		return
	_confirm_id = id
	_confirm_kind = "workshop"
	var next_level: int = Progress.workshop_level(id) + 1
	# i18n: {name} = an upgrade name, {level} = the level being bought; max 140px, 1 line
	confirm_label.text = Loc.t("upgrades.buy_confirm", "BUY {name} {level}?", {name = Workshop.display_name(id), level = next_level})
	confirm_price.text = str(Progress.workshop_cost(id))
	confirm.visible = true
	_blocker.visible = true
	if _confirm_lock.is_empty():
		_confirm_lock = UIKit.lock_focus(self, confirm)
	confirm_back.grab_focus()


## An ABILITIES row's + opens the confirm (nothing is spent yet): BUY SLIME RIFLE 2? / price.
func _buy_ability(id: String) -> void:
	if confirm.visible or _buy_guarded:
		return
	if not Progress.can_buy_ability(id):
		return
	_confirm_id = id
	_confirm_kind = "ability"
	# i18n: {name} = an ability name, {level} = the level being bought; max 140px, 1 line
	confirm_label.text = Loc.t("upgrades.buy_confirm", "BUY {name} {level}?", {name = Abilities.display_name(id), level = Progress.ability_level(id) + 1})
	confirm_price.text = str(Progress.ability_cost(id))
	confirm.visible = true
	_blocker.visible = true
	if _confirm_lock.is_empty():
		_confirm_lock = UIKit.lock_focus(self, confirm)
	confirm_back.grab_focus()


func _end_buy_guard() -> void:
	_buy_guarded = false


func _buy_confirmed() -> void:
	var id := _confirm_id
	var kind := _confirm_kind
	if id == "" or _buy_guarded:
		return
	_buy_guarded = true
	get_tree().create_timer(BUY_GUARD_TIME, true, false, true).timeout.connect(_end_buy_guard)
	_close_confirm(false)
	if kind == "ability":
		if Progress.buy_ability(id):
			_upgrade_sound(Progress.ability_level(id), Abilities.max_level(id))
	elif Progress.buy_workshop(id):
		_upgrade_sound(Progress.workshop_level(id), Workshop.max_level(id))
	_refresh()
	var focus_rows := ability_rows if kind == "ability" else ticket_rows
	if focus_rows.has(id):
		(focus_rows[id].plus as Button).grab_focus()


func close_confirm() -> void:
	_close_confirm(true)


func _close_confirm(refocus: bool) -> void:
	if not confirm.visible:
		return
	confirm.visible = false
	_blocker.visible = false
	UIKit.unlock_focus(_confirm_lock)
	var id := _confirm_id
	var focus_rows := ability_rows if _confirm_kind == "ability" else ticket_rows
	_confirm_id = ""
	_confirm_kind = ""
	if refocus and focus_rows.has(id):
		(focus_rows[id].plus as Button).grab_focus()


func _build_confirm() -> void:
	var parts := UIKit.add_ticket_confirm(self, _buy_confirmed, close_confirm, UIKit.TEXT)
	_blocker = parts.blocker
	confirm = parts.panel
	confirm_label = parts.label
	confirm_price = parts.price
	confirm_buy = parts.buy
	confirm_back = parts.back


## BRIGHTNESS bought: for 1 s the hint area shows a disc at the old light radius and a ring at the
## new one (to scale), so the jump is seen (a picture only, no text). Centered on the screen.
func _show_preview(old_radius: float, new_radius: float) -> void:
	if preview != null:
		preview.queue_free()
	var rows_bottom: int = _rows_bottom["coins"]
	var top := rows_bottom + 2
	var bottom := 162
	var scale := minf(0.7, float(bottom - top) / 2.0 / new_radius)
	var center := Vector2(160, (top + bottom) / 2.0)
	var skin := Progress.skin_color()
	var canvas := Control.new()  # (the draw lambda keeps its own reference: `preview` is cleared later)
	preview = canvas
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func() -> void:
		canvas.draw_circle(center, new_radius * scale, Color(skin, 0.14))
		canvas.draw_circle(center, old_radius * scale, Color(skin, 0.42))
		canvas.draw_arc(center, new_radius * scale, 0.0, TAU, 48, skin, 1.0, false))
	canvas.queue_redraw()
	hint.visible = false
	var timer := Timer.new()  # a child of the preview: replaced or freed with it
	timer.one_shot = true
	timer.wait_time = PREVIEW_TIME
	timer.timeout.connect(_end_preview)
	canvas.add_child(timer)
	timer.start()


func _end_preview() -> void:
	if preview != null:
		preview.queue_free()
		preview = null
	hint.visible = true


## A power-up swell, a little higher for each level.
func _upgrade_sound(level: int, top_level: int) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		var top := maxi(top_level - 1, 1)
		sfx.play("upgrade", -4.0, 1.0 + 0.3 * (level - 1) / top)


func _refresh() -> void:
	var tickets := page != "coins"
	coin_label.text = str(maxi(Progress.tickets if tickets else Progress.coins(), 0))  # never negative
	var skin := Progress.skin_color()
	for id: String in rows:
		var row: Dictionary = rows[id]
		var level: int = Progress.upgrade_level(id)
		_color_pips(row.pips, level, skin)
		var maxed := level >= Upgrades.max_level(id)
		row.cost.text = Loc.t("upgrades.max", "MAX") if maxed else "%d" % Upgrades.cost(id, level)
		row.plus.disabled = maxed or Progress.coins() < Upgrades.cost(id, level)
		row.minus.disabled = level <= 0
	var open: bool = Progress.workshop_open()
	for id: String in ticket_rows:  # (empty while the workshop is switched off)
		var row: Dictionary = ticket_rows[id]
		var level: int = Progress.workshop_level(id)
		_color_pips(row.pips, level, skin)
		var maxed := level >= Workshop.max_level(id)
		row.cost.text = Loc.t("upgrades.max", "MAX") if maxed else "%d" % Progress.workshop_cost(id)
		row.icon.visible = not maxed
		row.plus.disabled = not Progress.can_buy_workshop(id)
		row.about.text = Workshop.effect_text(id, level)
		row.about.modulate = Color.WHITE if open else Color(1, 1, 1, 0.5)
	var abilities_open: bool = Progress.abilities_open()
	for id: String in ability_rows:
		var row: Dictionary = ability_rows[id]
		var level: int = Progress.ability_level(id)
		_color_pips(row.pips, level, skin)
		var maxed := level >= Abilities.max_level(id)
		row.cost.text = Loc.t("upgrades.max", "MAX") if maxed else "%d" % Progress.ability_cost(id)
		row.ticket.visible = not maxed
		row.plus.disabled = not Progress.can_buy_ability(id)
		var shade := Color.WHITE if abilities_open else Color(1, 1, 1, 0.5)
		row.icon.modulate = shade
		row.tag.modulate = shade
	if page == "abilities":
		hint.text = ability_hint() if abilities_open else tickets_locked_text()
	elif tickets:
		hint.text = tickets_hint_text() if open else tickets_locked_text()
	else:
		# i18n: two lines, each max 300px
		hint.text = Loc.lines([
			Loc.t("upgrades.hint_coins.1", "COINS HIDE AT DEAD ENDS IN THE STORY MAZES"),
			Loc.t("upgrades.hint_coins.2", "TAKE COINS BACK OUT ANY TIME"),
		])


static func tickets_hint_text() -> String:
	# i18n: bottom hint, max 300px, 1 line
	return Loc.t("upgrades.hint_tickets", "TICKETS FROM THE RANDOMIZER - OFF IN HARD MODE")


static func tickets_locked_text() -> String:
	# i18n: bottom hint, max 300px, 1 line
	return Loc.t("upgrades.hint_tickets_locked", "EARN TICKETS IN THE RANDOMIZER FIRST")


## The ABILITIES hint for the device in use (Platform.last_input): keys, pad buttons or the touch buttons.
static func ability_hint() -> String:
	var keys := []
	for id in Abilities.ids():
		var action := Abilities.action(id)
		keys.append(Platform.prompt_for(action, Progress.key_name(Progress.bindings.get(action, 0))))
	if Platform.using_pad():
		# i18n: {a} {b} {c} = three pad button names (A, X, Y...), not translated; bottom hint, max 300px, 1 line
		return Loc.t("upgrades.hint_pad", "PAD {a} {b} {c} - RANDOM MAZES", {a = keys[0], b = keys[1], c = keys[2]})
	if UIKit.touch_active() or Platform.is_mobile_native():
		# i18n: bottom hint, max 300px, 1 line
		return Loc.t("upgrades.hint_touch", "TAP THEIR BUTTONS - RANDOM MAZES")
	# i18n: {a} {b} {c} = three key names (1, 2, 3 ...), not translated; bottom hint, max 300px, 1 line
	return Loc.t("upgrades.hint_keys", "KEYS {a} {b} {c} - RANDOM MAZES", {a = keys[0], b = keys[1], c = keys[2]})


func _color_pips(pips: Array, level: int, skin: Color) -> void:
	for i in pips.size():
		(pips[i] as ColorRect).color = skin if i < level else Color8(74, 70, 96)


## Leaves: back into the level after a dry-up, otherwise to the hub.
func _leave() -> void:
	var to_game: bool = Progress.return_to_game
	Progress.return_to_game = false
	if to_game:
		DevLog.route(get_tree(), "UPGRADES return")
	UIKit.go(get_tree(), UIKit.GAME_SCENE if to_game else UIKit.HUB_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if confirm != null and confirm.visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		close_confirm()  # Esc closes the confirm first, then the screen
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		_leave()
	elif (event.is_action_pressed("tab_next") or event.is_action_pressed("tab_prev")) and (confirm == null or not confirm.visible):
		var tabs := _tab_pages()  # LB / RB on a gamepad: the previous / next tab
		if tabs.size() > 1:
			var step := 1 if event.is_action_pressed("tab_next") else -1
			show_page(tabs[(tabs.find(page) + step + tabs.size()) % tabs.size()])
			get_viewport().set_input_as_handled()


## The tabs shown, left to right (page names).
func _tab_pages() -> Array[String]:
	var out: Array[String] = []
	for pair: Array in [[coins_tab, "coins"], [abilities_tab, "abilities"], [tickets_tab, "tickets"]]:
		if pair[0] != null:
			out.append(pair[1])
	return out
