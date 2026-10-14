class_name GooDrop
extends Node2D

## A DESCENT goo drop (Economy.DESCENT_DROP_REFILL % of the meter): a little drop of the skin's goo
## sitting at a dead end under the fog, found by exploring (fog glimmers mark it; MAGNET pulls it,
## GOO NOSE twinkles it more often). Drawn from pixels in the skin's shades; bobs a pixel (not with
## Reduce Motion). game.gd picks it up within Coin.REACH (or MAGNET's reach).

## Rows of shade letters: o outline, H highlight, L light, M mid, D dark (7 x 9, centered on x 3).
const SHAPE := ["...o...", "..oHo..", "..oLo..", ".oLLMo.", "oLHLMMo", "oLLMMDo", "oMMMMDo", ".oMDDo.", "..ooo.."]
const BOB_SPEED := 3.0

var cell := Vector2i.ZERO
var color := Color8(56, 183, 100)
## Reduce Motion: no bobbing.
var still := false
var _time := 0.0
var _bob := 0
var _shades := {}


func _ready() -> void:
	_shades = Skins.shades(color)
	var glow := Fx.make_light(22, Color(_shades.light, 0.3))
	glow.z_index = -1
	add_child(glow)


func _process(delta: float) -> void:
	_time += delta
	var bob := 0 if still else roundi(sin(_time * BOB_SPEED))
	if bob != _bob:
		_bob = bob
		queue_redraw()


func _draw() -> void:
	var colors := {"o": _shades.get("outline", Color.BLACK), "H": _shades.get("highlight", Color.WHITE),
		"L": _shades.get("light", color), "M": _shades.get("mid", color), "D": _shades.get("dark", color)}
	for y in SHAPE.size():
		var row: String = SHAPE[y]
		for x in row.length():
			if colors.has(row[x]):
				draw_rect(Rect2(x - 3, y - 5 + _bob, 1, 1), colors[row[x]])
