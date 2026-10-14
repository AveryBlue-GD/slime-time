extends Control

## The cauldron: two tabs, COINS | TICKETS (upgrades v2, docs/design/upgrades-v2.md C.3).
## COINS: the upgrade tree, a row per upgrade with its level (one fat pip per level: 7 / 4 / 3, so
## each level reads as a chunk), the effect now and after the next level (BRIGHTNESS as its light
## radius before -> after and the lit area gained, so the jump is clear), and buttons to put a coin
## level in (+) or take it back out (-) at any time. Dev-only upgrades (wall power) only appear in
## dev mode. Tracks and costs: Economy.COIN_TRACKS via Upgrades.
## TICKETS: the WORKSHOP (Workshop, Economy.WORKSHOP): five 3-level utility tracks bought with
## tickets (+ only: not refundable), each with its effect now -> next and its price with the ticket
## icon; locked (EARN TICKETS IN THE RANDOMIZER) until the player has ever had a ticket.
## The pod top right shows coins or tickets, following the tab. Esc / B / BACK leave the screen
## from either tab (a tab is not an overlay, so nothing stacks).

const ROW_TOP := 26
const ROW_HEIGHT := 30
## The workshop's five rows (two lines each: name, effect) from TICKET_ROW_TOP, TICKET_ROW_HEIGHT apart
## (panels 2 px shorter): 24 + 5 x 25 = 149, leaving one hint line above the bottom buttons. (The
## spec's 26 + 5 x 24 put the effect line on the goo band of its panel.)
const TICKET_ROW_TOP := 24
const TICKET_ROW_HEIGHT := 25
const PIP := Vector2(10, 6)
const PIP_GAP := 4
## The pips end here (right-aligned against the - button at 226), whatever the track's length.
const PIPS_RIGHT := 222
const COINS_HINT := "COINS HIDE AT DEAD ENDS IN THE STORY MAZES\nTAKE COINS BACK OUT ANY TIME"
const TICKETS_HINT := "TICKETS FROM THE RANDOMIZER - OFF IN HARD MODE"
const TICKETS_LOCKED := "EARN TICKETS IN THE RANDOMIZER FIRST"
## The tab the next opening shows ("coins" or "tickets"), for that one opening (demos and tests set
## it); the hub's cauldron always opens on COINS.
static var open_tab := "coins"

## The coin rows (by track id) and the workshop rows.
var rows := {}
var ticket_rows := {}
var coin_label: Label
var pod_icon: TextureRect
var skin_text: SkinText
## "coins" or "tickets".
var page := "coins"
var coins_tab: Button
var tickets_tab: Button
var coin_page: Control
var ticket_page: Control
var hint: Label
var back: Button
var _rows_bottom := {}


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "UPGRADES")
	var coin_pod := PanelContainer.new()
	coin_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	add_child(coin_pod)
	# Top-right corner, as far from the edges as BACK is in its corner.
	coin_pod.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_pod.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	coin_pod.offset_left = -4
	coin_pod.offset_right = -4
	coin_pod.offset_top = 4
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 3)
	coin_pod.add_child(coin_row)
	pod_icon = UIKit.make_icon("coin", Color.WHITE)
	coin_row.add_child(pod_icon)
	coin_label = UIKit.make_label("", 8, UIKit.TEXT)
	coin_label.custom_minimum_size = Vector2(28, 0)
	coin_row.add_child(coin_label)

	# The tabs, top left (mirroring the pod).
	coins_tab = UIKit.make_button("COINS", func() -> void: show_page("coins"), Vector2(40, 13))
	coins_tab.position = Vector2(4, 4)
	add_child(coins_tab)
	tickets_tab = UIKit.make_button("TICKETS", func() -> void: show_page("tickets"), Vector2(52, 13))
	tickets_tab.position = Vector2(46, 4)
	add_child(tickets_tab)

	coin_page = _make_page()
	var y := ROW_TOP
	for upgrade: Dictionary in Upgrades.LIST:
		if upgrade.get("dev", false) and not Progress.dev_tools:
			continue
		_make_row(coin_page, upgrade, y)
		y += ROW_HEIGHT
	_rows_bottom["coins"] = y - 5

	ticket_page = _make_page()
	y = TICKET_ROW_TOP
	for item: Dictionary in Workshop.LIST:
		_make_ticket_row(item, y)
		y += TICKET_ROW_HEIGHT
	_rows_bottom["tickets"] = y - 4

	hint = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back = UIKit.add_back_button(self)
	if Progress.return_to_game:  # came here from a dry-up: go straight back into the level
		back.text = "PLAY"
		back.pressed.disconnect(back.pressed.get_connections()[-1].callable)
		back.pressed.connect(_leave)
	show_page(open_tab if open_tab in ["coins", "tickets"] else "coins")
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
	page = which
	var tickets := page == "tickets"
	coin_page.visible = not tickets
	ticket_page.visible = tickets
	for pair: Array in [[coins_tab, not tickets], [tickets_tab, tickets]]:
		(pair[0] as Button).add_theme_stylebox_override("normal", UIKit.button_style("hover" if pair[1] else "normal"))
	pod_icon.texture = load(UIKit.UI_DIR + ("icon_ticket.png" if tickets else "icon_coin.png"))
	# Centered between the last row's panel and the bottom buttons (COINS: two lines, 7 + LINE_SPACING
	# + 7 px; TICKETS: one line).
	var hint_height := 7 if tickets else 14 + UIKit.LINE_SPACING
	var rows_bottom: int = _rows_bottom[page]
	hint.offset_top = rows_bottom + floori((164 - rows_bottom - hint_height) / 2.0)
	hint.offset_bottom = hint.offset_top + hint_height + 2
	_refresh()
	var first: Button = null
	if tickets:
		first = ticket_rows[Workshop.LIST[0].id].plus if Progress.workshop_open() else tickets_tab
	elif not rows.is_empty():
		first = rows[Upgrades.LIST[0].id].plus
	if first:
		first.grab_focus()
	skin_text.recolor.call_deferred()


func _make_row(parent: Control, upgrade: Dictionary, y: int) -> void:
	UIKit.add_panel(parent, Rect2(10, y - 2, 300, ROW_HEIGHT - 3))
	var name_label := UIKit.make_label(upgrade.name, 8, UIKit.GOLD if upgrade.get("dev", false) else UIKit.TEXT)
	name_label.position = Vector2(18, y + 1)
	parent.add_child(name_label)
	var about := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	about.position = Vector2(18, y + 12)
	parent.add_child(about)
	var pips := _make_pips(parent, Upgrades.max_level(upgrade.id), y)
	var minus := UIKit.make_button("-", func() -> void: _change(upgrade.id, false), Vector2(16, 13))
	minus.position = Vector2(226, y)
	parent.add_child(minus)
	var plus := UIKit.make_button("+", func() -> void: _change(upgrade.id, true), Vector2(16, 13))
	plus.position = Vector2(244, y)
	parent.add_child(plus)
	var cost := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	cost.position = Vector2(264, y + 2)
	parent.add_child(cost)
	rows[upgrade.id] = {pips = pips, minus = minus, plus = plus, cost = cost, about = about}


## A workshop row: name, effect now -> next, 3 pips, + and the price with the ticket icon.
func _make_ticket_row(item: Dictionary, y: int) -> void:
	UIKit.add_panel(ticket_page, Rect2(10, y - 2, 300, TICKET_ROW_HEIGHT - 2))
	var name_label := UIKit.make_label(item.name, 8, UIKit.TEXT)
	name_label.position = Vector2(18, y + 1)
	ticket_page.add_child(name_label)
	var about := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	about.position = Vector2(18, y + 11)
	ticket_page.add_child(about)
	var pips := _make_pips(ticket_page, Workshop.max_level(item.id), y)
	var plus := UIKit.make_button("+", func() -> void: _buy_workshop(item.id), Vector2(16, 13))
	plus.position = Vector2(244, y)
	ticket_page.add_child(plus)
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 2)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.position = Vector2(264, y + 2)
	ticket_page.add_child(price)
	var cost := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	price.add_child(cost)
	var icon := UIKit.make_icon("ticket", Color.WHITE)
	price.add_child(icon)
	ticket_rows[item.id] = {pips = pips, plus = plus, cost = cost, icon = icon, about = about}


func _make_pips(parent: Control, count: int, y: int) -> Array[ColorRect]:
	var pips: Array[ColorRect] = []
	var left := PIPS_RIGHT - (count * (int(PIP.x) + PIP_GAP) - PIP_GAP)
	for i in count:
		var pip := ColorRect.new()
		pip.position = Vector2(left + i * (int(PIP.x) + PIP_GAP), y + 3)
		pip.size = PIP
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(pip)
		pips.append(pip)
	return pips


func _change(id: String, up: bool) -> void:
	var changed: bool = Progress.buy_upgrade(id) if up else Progress.refund_upgrade(id)
	if changed and up:
		_upgrade_sound(Progress.upgrade_level(id), Upgrades.max_level(id))
	_refresh()


func _buy_workshop(id: String) -> void:
	if Progress.buy_workshop(id):
		_upgrade_sound(Progress.workshop_level(id), Workshop.max_level(id))
	_refresh()


## A power-up swell, a little higher for each level.
func _upgrade_sound(level: int, top_level: int) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		var top := maxi(top_level - 1, 1)
		sfx.play("upgrade", -4.0, 1.0 + 0.3 * (level - 1) / top)


func _refresh() -> void:
	var tickets := page == "tickets"
	coin_label.text = str(Progress.tickets if tickets else Progress.coins())
	var skin := Progress.skin_color()
	for id: String in rows:
		var row: Dictionary = rows[id]
		var level: int = Progress.upgrade_level(id)
		_color_pips(row.pips, level, skin)
		var maxed := level >= Upgrades.max_level(id)
		row.cost.text = "MAX" if maxed else "%d" % Upgrades.cost(id, level)
		row.plus.disabled = maxed or Progress.coins() < Upgrades.cost(id, level)
		row.minus.disabled = level <= 0
		row.about.text = effect_text(id, level)
	var open: bool = Progress.workshop_open()
	for id: String in ticket_rows:
		var row: Dictionary = ticket_rows[id]
		var level: int = Progress.workshop_level(id)
		_color_pips(row.pips, level, skin)
		var maxed := level >= Workshop.max_level(id)
		row.cost.text = "MAX" if maxed else "%d" % Progress.workshop_cost(id)
		row.icon.visible = not maxed
		row.plus.disabled = not Progress.can_buy_workshop(id)
		row.about.text = Workshop.effect_text(id, level)
		row.about.modulate = Color.WHITE if open else Color(1, 1, 1, 0.5)
	hint.text = (TICKETS_HINT if open else TICKETS_LOCKED) if tickets else COINS_HINT


func _color_pips(pips: Array, level: int, skin: Color) -> void:
	for i in pips.size():
		(pips[i] as ColorRect).color = skin if i < level else Color8(74, 70, 96)


## The row's second line: the effect at `level` and, unless maxed, after the next level.
##   MORE SLIME: SLIME x1.30 -> x1.45     SPEED: SPEED x1.12 -> x1.25
##   BRIGHTNESS: LIGHT 9 -> 17 PX  +257% AREA (the radius the light reveals, and the lit disc gained)
static func effect_text(id: String, level: int) -> String:
	var maxed := level >= Upgrades.max_level(id)
	var now := Upgrades.value(id, level)
	var next := Upgrades.value(id, level + 1)
	match id:
		"slime", "speed":
			var label := "SLIME" if id == "slime" else "SPEED"
			return "%s x%.2f" % [label, now] + ("  MAXED" if maxed else " -> x%.2f" % next)
		"brightness":
			var r_now := Upgrades.reveal_radius(level)
			var r_next := Upgrades.reveal_radius(level + 1)
			if maxed:
				return "LIGHT %d PX  MAXED" % roundi(r_now)
			var gain := roundi((r_next * r_next / (r_now * r_now) - 1.0) * 100.0)
			return "LIGHT %d -> %d PX  +%d%% AREA" % [roundi(r_now), roundi(r_next), gain]
		"power":
			return "SPLATS DAMAGE WALLS (DEV ONLY)" if level <= 0 or maxed else "WALL DAMAGE x%.1f -> x%.1f" % [now, next]
	return ""


## Leaves: back into the level after a dry-up, otherwise to the hub.
func _leave() -> void:
	var to_game: bool = Progress.return_to_game
	Progress.return_to_game = false
	if to_game:
		DevLog.route(get_tree(), "UPGRADES return")
	UIKit.go(get_tree(), UIKit.GAME_SCENE if to_game else UIKit.HUB_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		_leave()
