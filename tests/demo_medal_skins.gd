extends Node2D

## MOCKUP ONLY, THROWAWAY: six candidate "all 30 medals" reward skins drawn with the game's real
## slime sprite + a copy of the skin shader (tests/medal_skin_mock.gdshader), next to the existing
## skins for comparison. Nothing here is a real skin: no Skins/Progress changes, no saves.
## ./tools/screenshot.sh --frames 60 --scene res://tests/demo_medal_skins.tscn

const SHADER := preload("res://tests/medal_skin_mock.gdshader")
const SLIME := preload("res://scenes/slime.tscn")
const GOLD_TXT := Color8(255, 205, 117)

## Palettes: highlight, light, mid, dark, deep, outline.
const GOLD := ["fff6c8", "ffde6e", "f5b226", "b06a22", "703c24", "3e201e"]
const AURUM := ["fffbe6", "ffe98a", "f7c331", "c07a22", "7a4422", "44241e"]
const LANTERN := ["ffffee", "fff4b0", "ffd060", "f09a38", "b85a2a", "6a3024"]
const STOPWATCH := ["ffffff", "faf6e6", "eee6cc", "cabf9e", "e8b030", "8a5418"]

var _time := 0.0
var _overlays: Array = []  # [Node2D, kind, slime center]


func _ready() -> void:
	_floor()
	_title("MOCKUP: ALL 30 MEDALS SKINS", Vector2(0, 3), 320, GOLD_TXT)
	_title("EXISTING", Vector2(0, 14), 56, UIKit.TEXT_DIM)
	var ref_x := 28
	_slime(Vector2(ref_x, 44), "ref", Skins.get_preset("lime").color)
	_label("LIME", Vector2(ref_x, 56))
	_slime(Vector2(ref_x, 88), "rainbow", Color.WHITE)
	_label("RAINBOW", Vector2(ref_x, 100))
	_slime(Vector2(ref_x, 132), "ref", Skins.get_preset("shadow").color)
	_label("INKKY", Vector2(ref_x, 144))
	for y in range(20, 170, 4):
		_px(Rect2(58, y, 1, 2), Color8(60, 70, 90))
	var names := ["GOLDEN", "CHAMPION", "STOPWATCH", "LANTERN", "TROPHY", "PRESTIGE"]
	var kinds := ["golden", "champion", "stopwatch", "lantern", "trophy", "prestige"]
	for i in 6:
		var cx := 100 + (i % 3) * 78
		var cy := 56 if i < 3 else 130
		_slime(Vector2(cx, cy), kinds[i], Color.WHITE)
		_label(names[i], Vector2(cx, cy + 14), GOLD_TXT)


func _process(delta: float) -> void:
	_time += delta
	for entry: Array in _overlays:
		var node: Node2D = entry[0]
		if entry[1] == "halo":
			node.modulate.a = 0.55 + 0.1 * sin(_time * 3.0) * sin(_time * 1.7)
		elif entry[1] == "glow":
			node.modulate.a = 0.55 * (0.7 + 0.3 * sin(_time * 2.5))
		else:
			node.queue_redraw()


# ---------------------------------------------------------------- scene pieces

func _floor() -> void:
	var bg := ColorRect.new()
	bg.color = Color8(14, 18, 30)
	bg.size = Vector2(320, 180)
	add_child(bg)
	# Dithered fog patches (static) so the floor reads like the game's mist, not a flat fill.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 150:
		var p := Vector2(rng.randi_range(0, 319), rng.randi_range(0, 179))
		_px(Rect2(p, Vector2(rng.randi_range(2, 5), 1)), Color8(24, 30, 46, 255))
		if i % 2 == 0:
			_px(Rect2(p + Vector2(1, 1), Vector2(rng.randi_range(1, 3), 1)), Color8(20, 25, 40))


func _px(r: Rect2, c: Color) -> void:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	add_child(cr)


func _title(text: String, pos: Vector2, width: float, color: Color) -> void:
	var l := UIKit.make_label(text, 8, color)
	l.position = pos
	l.size = Vector2(width, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)


func _label(text: String, center: Vector2, color := UIKit.TEXT) -> void:
	var l := UIKit.make_label(text, 8, color)
	l.size = Vector2(70, 8)
	l.position = Vector2(center.x - 35, center.y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)


func _pal(mat: ShaderMaterial, hexes: Array) -> void:
	for i in 6:
		mat.set_shader_parameter(["highlight", "light", "mid", "dark", "deep", "outline"][i], Color.html(hexes[i]))


func _slime(pos: Vector2, kind: String, base: Color) -> void:
	var root := Node2D.new()
	root.position = pos
	root.z_index = 1  # lifts glow layers (z -1 inside) above the floor rects
	add_child(root)
	var back := Node2D.new()  # glow layers under the slime
	back.z_index = -1
	root.add_child(back)
	var slime: CharacterBody2D = SLIME.instantiate()
	slime.get_node("Camera2D").queue_free()
	slime.set_physics_process(false)
	root.add_child(slime)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("gloss", 1.0)
	mat.set_shader_parameter("translucency", 1.0)
	slime.sprite.material = mat  # replaces the one slime._ready() would make (below)
	# slime._ready() ran when added to the tree and installed the real skin material; take over.
	match kind:
		"ref", "rainbow":
			mat.shader = preload("res://assets/shaders/slime_skin.gdshader")
			Skins.apply_to(mat, base, kind == "rainbow")
		"golden":
			_pal(mat, AURUM)
			mat.set_shader_parameter("translucency", 0.0)
			mat.set_shader_parameter("shine_rate", 0.18)
			mat.set_shader_parameter("shine_width", 3.2)
		"champion":
			Skins.apply_to(mat, Color8(92, 160, 240))
			mat.set_shader_parameter("translucency", 0.45)
		"stopwatch":
			_pal(mat, STOPWATCH)
			mat.set_shader_parameter("translucency", 0.35)
		"lantern":
			_pal(mat, LANTERN)
			mat.set_shader_parameter("translucency", 0.3)
		"trophy":
			_pal(mat, GOLD)
			mat.set_shader_parameter("translucency", 0.15)
		"prestige":
			_pal(mat, GOLD)
			mat.set_shader_parameter("translucency", 0.0)
			mat.set_shader_parameter("edge_rainbow", 1.0)
	# Glow lights (same Fx.make_light the chalice uses).
	if kind == "lantern":
		var halo := Fx.make_light(60, Color.WHITE)
		halo.modulate = Color(1.0, 0.85, 0.5, 0.6)
		back.add_child(halo)
		_overlays.append([halo, "halo", pos])
	if kind == "trophy":
		var glow := Fx.make_light(60, Color.WHITE)
		glow.modulate = Color(1.0, 0.72, 0.28, 0.55)  # = Chalice.GLOW_COLOR
		back.add_child(glow)
		_overlays.append([glow, "glow", pos])
	if kind in ["champion", "stopwatch", "trophy", "lantern"]:
		var front := Overlay.new()
		front.z_index = 12
		front.kind = kind
		front.owner_demo = self
		root.add_child(front)
		_overlays.append([front, kind, pos])
		if kind in ["champion"]:
			var behind := Overlay.new()
			behind.z_index = -1
			behind.kind = "champion_back"
			behind.owner_demo = self
			root.add_child(behind)
			_overlays.append([behind, "champion_back", pos])


# ---------------------------------------------------------------- overlay drawing

## One pixel-art overlay layer (all coordinates whole pixels, relative to the slime center).
class Overlay extends Node2D:
	var kind := ""
	var owner_demo: Node2D

	func _draw() -> void:
		var t: float = owner_demo._time
		match kind:
			"champion": _champion(t, true)
			"champion_back": _champion(t, false)
			"stopwatch": _stopwatch(t)
			"trophy": _sparkles(t)
			"lantern": _lantern(t)

	func px(x: int, y: int, c: Color, w := 1, h := 1) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func art(x: int, y: int, rows: Array, pal: Dictionary) -> void:
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				var ch := row[c]
				if pal.has(ch):
					px(x + c, y + r, pal[ch])

	# Gold medal ribbon rosette on the chest, three gold pips orbiting the body.
	func _champion(t: float, front: bool) -> void:
		if front:
			art(-4, -1, [
				".rrrrr.",
				"rrgggrr",
				"rgGhGgr",
				"rgGGGgr",
				"rrgggrr",
				".rrrrr.",
				".rR.Rr.",
				".rR.Rr.",
				".rr.rr.",
				".r...r.",
			], {r = Color8(214, 52, 66), R = Color8(255, 110, 110), g = Color8(255, 200, 60), G = Color8(235, 160, 30), h = Color8(255, 246, 200)})
		for k in 3:
			var a := t * 1.8 + k * TAU / 3.0
			var back := sin(a) < 0.0
			if back == front:
				continue
			_pip(roundi(cos(a) * 13.0), roundi(sin(a) * 5.0) - 1, back)

	func _pip(x: int, y: int, dim: bool) -> void:
		var m := 0.7 if dim else 1.0
		px(x, y, Color(1.0, 0.76, 0.2) * Color(m, m, m, 1.0), 2, 2)
		px(x, y, Color(1.0, 0.97, 0.78) * Color(m, m, m, 1.0))
		px(x + 1, y + 1, Color(0.7, 0.4, 0.14) * Color(m, m, m, 1.0))

	func _stopwatch(t: float) -> void:
		var tick := Color8(56, 36, 34)
		var ring := [[0, -5], [2, -4], [4, -2], [5, 1], [4, 3], [2, 5], [0, 6], [-2, 5], [-4, 3], [-5, 1], [-4, -2], [-2, -4]]
		for i in ring.size():
			var p: Array = ring[i]
			var major := i % 3 == 0
			px(p[0] + (0 if not major else 0), p[1] + 1, tick if major else Color8(96, 76, 66))
		# Ticking second hand: jumps one notch at a time (12 notches, 4 per second).
		var step := int(t * 4.0) % 12
		var a := step * TAU / 12.0 - PI / 2.0
		for r in range(1, 4):
			px(roundi(cos(a) * r), roundi(sin(a) * r) + 1, Color8(230, 50, 50))
		px(0, 1, Color8(120, 30, 30))
		# Crown button on top, gold.
		px(-1, -9, Color8(255, 214, 90), 3, 1)
		px(0, -10, Color8(200, 140, 40), 1, 1)

	func _sparkles(t: float) -> void:
		for i in 7:
			var life := fposmod(t * 0.9 + i / 7.0, 1.0)
			var x := -7 - int(life * 22.0)
			var y := 6 - int(life * 7.0) + int(sin(i * 2.7) * 4.0)
			var c := Color(1.0, 0.96, 0.7).lerp(Color(1.0, 0.7, 0.2), life)
			if life < 0.55 and (i + int(t * 6.0)) % 3 != 0:
				px(x, y - 1, c); px(x, y + 1, c); px(x - 1, y, c); px(x + 1, y, c)
				px(x, y, Color(1, 1, 1))
			elif life < 0.9:
				px(x, y, c)

	func _lantern(t: float) -> void:
		# Soft inner glow over the body, flickering a touch.
		var flick := 0.5 + 0.5 * sin(t * 7.0) * sin(t * 3.1)
		for p in [[-3, -3, 3], [-2, -4, 2], [-2, -2, 4], [-4, 0, 1]]:
			px(p[0] + 1, p[1] + 1, Color(1.0, 0.97, 0.75, 0.3 + 0.25 * flick), p[2] + 1, 1)
