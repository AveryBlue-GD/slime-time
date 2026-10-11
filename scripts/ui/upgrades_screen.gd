extends Control

## The upgrade tree: a row per upgrade with its level (10 pips), and buttons to put a coin level
## in (+) or take it back out (-) at any time. Coins in hand show at the top. Dev-only upgrades
## (wall power) only appear in dev mode.

const ROW_TOP := 26
const ROW_HEIGHT := 30
const PIP := Vector2(6, 6)

var rows := {}
var coin_label: Label
var skin_text: SkinText


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, "UPGRADES")
	var coin_pod := PanelContainer.new()
	coin_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	coin_pod.position = Vector2(262, 4)
	add_child(coin_pod)
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 3)
	coin_pod.add_child(coin_row)
	coin_row.add_child(UIKit.make_icon("coin", Color.WHITE))
	coin_label = UIKit.make_label("", 8, UIKit.TEXT)
	coin_label.custom_minimum_size = Vector2(28, 0)
	coin_row.add_child(coin_label)

	var y := ROW_TOP
	for upgrade: Dictionary in Upgrades.LIST:
		if upgrade.get("dev", false) and not Progress.dev_tools:
			continue
		_make_row(upgrade, y)
		y += ROW_HEIGHT

	var hint := UIKit.make_label("COINS HIDE AT DEAD ENDS IN THE STORY MAZES\nTAKE COINS BACK OUT ANY TIME", 8, UIKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 143
	hint.offset_bottom = 161
	UIKit.add_back_button(self)
	_refresh()
	rows[Upgrades.LIST[0].id].plus.grab_focus()


func _make_row(upgrade: Dictionary, y: int) -> void:
	UIKit.add_panel(self, Rect2(10, y - 2, 300, ROW_HEIGHT - 3))
	var name_label := UIKit.make_label(upgrade.name, 8, UIKit.GOLD if upgrade.get("dev", false) else UIKit.TEXT)
	name_label.position = Vector2(18, y + 1)
	add_child(name_label)
	var about := UIKit.make_label(upgrade.about, 8, UIKit.TEXT_DIM)
	about.position = Vector2(18, y + 12)
	add_child(about)
	var pips: Array[ColorRect] = []
	for i in Upgrades.MAX_LEVEL:
		var pip := ColorRect.new()
		pip.position = Vector2(142 + i * 8, y + 3)
		pip.size = PIP
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		pips.append(pip)
	var minus := UIKit.make_button("-", func() -> void: _change(upgrade.id, false), Vector2(16, 13))
	minus.position = Vector2(226, y)
	add_child(minus)
	var plus := UIKit.make_button("+", func() -> void: _change(upgrade.id, true), Vector2(16, 13))
	plus.position = Vector2(244, y)
	add_child(plus)
	var cost := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	cost.position = Vector2(264, y + 2)
	add_child(cost)
	rows[upgrade.id] = {pips = pips, minus = minus, plus = plus, cost = cost}


func _change(id: String, up: bool) -> void:
	var changed: bool = Progress.buy_upgrade(id) if up else Progress.refund_upgrade(id)
	if changed:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx and up:
			sfx.play("coin", -6.0)
	_refresh()


func _refresh() -> void:
	coin_label.text = str(Progress.coins())
	var skin := Progress.skin_color()
	for id: String in rows:
		var row: Dictionary = rows[id]
		var level: int = Progress.upgrade_level(id)
		for i in Upgrades.MAX_LEVEL:
			(row.pips[i] as ColorRect).color = skin if i < level else Color8(74, 70, 96)
		var maxed := level >= Upgrades.MAX_LEVEL
		row.cost.text = "MAX" if maxed else "%d" % Upgrades.cost(level)
		row.plus.disabled = maxed or Progress.coins() < Upgrades.cost(level)
		row.minus.disabled = level <= 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
