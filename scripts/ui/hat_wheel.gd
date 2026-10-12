class_name HatWheel
extends Control

## The hat wheel, opened at the prize wheel in the hub: a big wheel with a wedge for every hat
## you don't have yet, each showing its hat. A spin whirls it round (the flapper ticking on each
## wedge it passes), slows down and lands on a random hat: that hat is won (Progress.win_hat; the
## slime puts it on) and comes off the wheel, so the next spin is only between the hats still
## missing. Spins will cost a currency later; for now only dev mode can spin (Progress.can_spin_hats).
## The hub opens and closes it, and passes on the spin key (`spin`).

signal landed(hat_id: String)

const CENTER := Vector2(160, 87)
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

## The hats on the wheel right now (the ones not won yet), in wheel order.
var hats: Array[String] = []
## How far the wheel has turned (radians); wedge i starts at turn + i * span (0 = pointing right).
var turn := 0.0
var spinning := false
var _from := 0.0
var _to := 0.0
var _t := 0.0
var _won := ""
var _last_wedge := -1
var _kick := 0.0
var title: Label
var result: Label
var hint: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UIKit.add_panel(self, Rect2(76, 6, 168, 166))
	panel.show_behind_parent = true  # the wheel is drawn by this control, over its panel
	title = _label("HAT WHEEL", 8, UIKit.GOLD, 12)
	result = _label("", 8, UIKit.TEXT, 146)
	hint = _label("", 8, UIKit.TEXT_DIM, 157)


func _label(text: String, size: int, color: Color, top: int) -> Label:
	var label := UIKit.make_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.position = Vector2(76, top)
	label.size = Vector2(168, 10)
	return label


## Puts the hats still to win on the wheel and the right words under it. Right after a win the
## won hat stays where it landed, lit up under the pointer, until the next spin takes it off.
func refresh(spin_key: String) -> void:
	if _won == "":
		hats = Progress.hats_left()
	if Progress.hats_left().is_empty() and _won == "":
		result.text = "EVERY HAT WON!"
		hint.text = "%s TO CLOSE" % spin_key
	elif _won != "":
		result.text = "YOU WON THE %s!" % Hats.display_name(_won)
		hint.text = "%s SPIN AGAIN - ESC CLOSE" % spin_key if Progress.can_spin_hats() else "ESC TO CLOSE"
	else:
		result.text = "%d HAT%s TO WIN" % [hats.size(), "" if hats.size() == 1 else "S"]
		hint.text = "%s TO SPIN - ESC CLOSE" % spin_key if Progress.can_spin_hats() else "SPINS COMING SOON"
	queue_redraw()


func span() -> float:
	return TAU / maxf(hats.size(), 1.0)


## Which wedge is under the pointer (at the top) for a given turn.
func wedge_at(at_turn: float) -> int:
	if hats.is_empty():
		return -1
	var a := fposmod(-PI / 2.0 - at_turn, TAU)
	return int(a / span()) % hats.size()


## Spins to a random hat still on the wheel. False if it can't spin.
func spin() -> bool:
	if spinning or not Progress.can_spin_hats():
		return false
	hats = Progress.hats_left()  # the last hat won comes off the wheel now
	if hats.is_empty():
		return false
	var pick := randi() % hats.size()
	# Land with the pointer somewhere inside the picked wedge (not on its edge), after a few turns.
	var inside := randf_range(0.2, 0.8)
	var target := -PI / 2.0 - (pick + inside) * span()
	var turns := randi_range(4, 6)
	_from = turn
	_to = target - TAU * turns
	while _to > _from - TAU * turns:  # always whirl the same way, plenty of times
		_to -= TAU
	_t = 0.0
	_won = ""
	spinning = true
	_last_wedge = wedge_at(turn)
	result.text = "..."
	hint.text = ""
	return true


func _process(delta: float) -> void:
	_kick = maxf(_kick - delta * 6.0, 0.0)
	if not spinning:
		return
	_t = minf(_t + delta / SPIN_TIME, 1.0)
	var eased := 1.0 - pow(1.0 - _t, 3.0)  # fast at first, slowing to a stop
	turn = lerpf(_from, _to, eased)
	var wedge := wedge_at(turn)
	if wedge != _last_wedge:  # the flapper ticks past a wedge edge
		_last_wedge = wedge
		_kick = 1.0
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("click", -14.0, 1.3)
	if _t >= 1.0:
		spinning = false
		turn = fposmod(turn, TAU)
		_won = hats[wedge_at(turn)]
		Progress.win_hat(_won)
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play("unlock", -4.0)
		landed.emit(_won)
	queue_redraw()


func _draw() -> void:
	# Rim, then a wedge per hat (alternating colors), dividers, pegs, the hub, the hats, the flapper.
	draw_circle(CENTER, RADIUS + 4.0, RIM_DARK)
	draw_circle(CENTER, RADIUS + 3.0, RIM)
	var n := hats.size()
	if n == 0:
		draw_circle(CENTER, RADIUS, Color8(52, 30, 24))
	for i in n:
		var a0 := turn + i * span()
		var points := PackedVector2Array([CENTER])
		var steps := maxi(4, int(48.0 / n))
		for s in steps + 1:
			var a := a0 + span() * s / steps
			points.append(CENTER + Vector2(cos(a), sin(a)) * RADIUS)
		var color := WEDGE_COLORS[i % WEDGE_COLORS.size()]
		if n % WEDGE_COLORS.size() == 1 and i == n - 1 and n > 1:
			color = WEDGE_COLORS[2]  # keep the last wedge from matching the first
		if _won != "" and hats[i] == _won:
			color = color.lightened(0.45)  # the winner, lit up under the pointer
		draw_colored_polygon(points, color)
	for i in n:
		var a := turn + i * span()
		draw_line(CENTER, CENTER + Vector2(cos(a), sin(a)) * RADIUS, DIVIDER, 1.0)
		var peg := (CENTER + Vector2(cos(a), sin(a)) * (RADIUS + 1.5)).round()
		draw_rect(Rect2(peg - Vector2(1, 1), Vector2(2, 2)), PEG)
	draw_circle(CENTER, 6.0, Color8(209, 136, 58))
	draw_circle(CENTER, 4.0, Color8(255, 205, 117))
	var atlas: Texture2D = preload("res://assets/sprites/hats.png")
	for i in n:
		var a := turn + (i + 0.5) * span()
		var at := (CENTER + Vector2(cos(a), sin(a)) * RADIUS * 0.7).round()
		# The narrow version, so neighbors don't touch.
		draw_texture_rect_region(atlas, Rect2(at - Vector2(Hats.FRAME) / 2.0, Vector2(Hats.FRAME)), Hats.region(hats[i], Hats.Width.NARROW))
	# The flapper at the top, kicked aside as it ticks past each wedge.
	var tip := Vector2(CENTER.x + roundf(_kick * 2.0), CENTER.y - RADIUS + 6.0)
	var base_y := CENTER.y - RADIUS - 7.0
	draw_colored_polygon(PackedVector2Array([Vector2(CENTER.x - 4, base_y), Vector2(CENTER.x + 4, base_y), tip]), FLAPPER)
	draw_rect(Rect2(CENTER.x - 5, base_y - 3, 10, 3), Color8(132, 138, 162))
