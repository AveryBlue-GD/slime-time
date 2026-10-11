class_name GooBox
extends StyleBox

## Buttons and panels framed in slime. Only the frame is goo: a 1 px outline around a goo band
## (glossy top edge, dark inner edge) that swells into a few long tapered lumps and thickens in the
## top corners; round drops hang outside, below the box. The face inside stays clean, so text and
## its drips never touch the goo: on a 13 px button the goo keeps to rows 0-2 and 12 and the
## outer 3 columns (content margins: 4 at the sides, 3 above and below).
## The goo is the equipped skin's color (`set_goo_color`, called by SkinText); every box is
## seeded from its control, so each one keeps its own lumps and drops.

enum Kind { BUTTON, PANEL }

## The skin color every goo box uses (shades derived like the slime's).
static var goo_color := Color8(56, 183, 100)
static var _boxes: Array[WeakRef] = []

## Dried-up goo for disabled buttons.
const DRIED := {
	H = Color8(70, 66, 84), L = Color8(60, 56, 72), M = Color8(50, 46, 62),
	N = Color8(40, 37, 50), D = Color8(34, 31, 44), O = Color8(24, 22, 32),
}
## Hover: every goo shade one step lighter.
const LIFT := {H = "H", L = "H", M = "L", N = "M", D = "N", O = "D"}

var kind := Kind.BUTTON
## "normal", "hover", "pressed" or "disabled" (buttons).
var state := "normal"
var face := Color8(51, 44, 64)
## Goo band thickness inside the outline (top, sides, bottom) and how much thicker lumps get.
var band := Vector3i(1, 1, 1)
var lump := Vector3i(1, 1, 0)
## Rough spacing of the drops under the box, and how far from the ends they start.
var drop_every := 14
var drop_edge := 6


func _init() -> void:
	_boxes.append(weakref(self))


## Recolors every goo box (redraws them).
static func set_goo_color(color: Color) -> void:
	if color.is_equal_approx(goo_color):
		return
	goo_color = color
	var alive: Array[WeakRef] = []
	for ref in _boxes:
		var box := ref.get_ref() as GooBox
		if box:
			alive.append(ref)
			box.emit_changed()
	_boxes = alive


static func make_button(button_state: String) -> GooBox:
	var box := GooBox.new()
	box.state = button_state
	box.face = {
		"normal": Color8(51, 44, 64), "hover": Color8(72, 62, 94),
		"pressed": Color8(40, 34, 52), "disabled": Color8(34, 30, 44),
	}.get(button_state, Color8(51, 44, 64))
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


static func make_panel() -> GooBox:
	var box := GooBox.new()
	box.kind = Kind.PANEL
	box.face = Color8(30, 30, 48, 235)
	box.band = Vector3i(2, 2, 2)
	box.lump = Vector3i(2, 1, 1)
	box.drop_every = 15
	box.drop_edge = 7
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 8)
	return box


func _shades() -> Dictionary:
	if state == "disabled":
		return DRIED
	var s := Skins.shades(goo_color)
	var shades := {H = s.highlight, L = s.light, M = s.mid, N = s.dark, D = s.deep, O = s.outline}
	if state == "hover":
		var lifted := {}
		for key: String in shades:
			lifted[key] = shades[LIFT[key]]
		return lifted
	return shades


func _draw(item: RID, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([item.get_id(), int(rect.size.x), int(rect.size.y)])
	var sh := _shades()
	var x := int(rect.position.x)
	var y := int(rect.position.y)
	var w := int(rect.size.x)
	var h := int(rect.size.y)
	if w < 6 or h < 6:
		return
	var put := func(px: int, py: int, color: Color) -> void:
		RenderingServer.canvas_item_add_rect(item, Rect2(px, py, 1, 1), color)
	RenderingServer.canvas_item_add_rect(item, Rect2(x + 1, y + 1, w - 2, h - 1), face)

	var top := _lumps(rng, w, band.x, lump.x, 16)
	var bottom := _lumps(rng, w, band.z, lump.z, 16)
	var left := _lumps(rng, h, band.y, lump.y, 6)
	var right := _lumps(rng, h, band.y, lump.y, 6)
	for i in w:  # rounded fill in the top corners
		var d := mini(i, w - 1 - i)
		if d < 3:
			top[i] = maxi(top[i], band.x + 2 - d)
	for j in h / 2:
		var d := mini(j, h - 1 - j)
		if d < 3:
			left[j] = maxi(left[j], band.y + 2 - d)
			right[j] = maxi(right[j], band.y + 2 - d)

	# Sides (glossy on the upper left), then the top and bottom bands over them.
	for j in range(1, h):
		put.call(x, y + j, sh.O)
		put.call(x + w - 1, y + j, sh.O)
		for d in left[j]:
			put.call(x + 1 + d, y + j, sh.L if d == 0 else (sh.N if d == left[j] - 1 else sh.M))
		for d in right[j]:
			put.call(x + w - 2 - d, y + j, sh.N if d == 0 else sh.M)
	for i in range(1, w - 1):
		put.call(x + i, y, sh.O)
		for d in top[i]:
			var color: Color = sh.M
			if d == 0:
				color = sh.H if rng.randf() < 0.15 else sh.L
			elif d == top[i] - 1:
				color = sh.N
			put.call(x + i, y + 1 + d, color)
		for d in bottom[i]:
			put.call(x + i, y + h - 1 - d, sh.N if d == 0 else sh.M)
		put.call(x + i, y + h, sh.O)  # the bottom outline sits just under the box

	# Drops hanging under the box: round nubs and thin strings.
	var at := drop_edge + rng.randi_range(0, drop_every / 2)
	while at < w - drop_edge - 2:
		if rng.randf() < 0.55:
			var nub: Array = [[-2, sh.O], [-1, sh.M], [0, sh.L], [1, sh.N], [2, sh.O]]
			for p: Array in nub:
				put.call(x + at + p[0], y + h, p[1])
			put.call(x + at - 1, y + h + 1, sh.O)
			put.call(x + at, y + h + 1, sh.N)
			put.call(x + at + 1, y + h + 1, sh.O)
		else:
			put.call(x + at, y + h, sh.N)
			put.call(x + at, y + h + 1, sh.O)
		at += rng.randi_range(drop_every - drop_every / 3, drop_every + drop_every / 3)


## Goo thickness along an edge of `n` px: `base` everywhere, swelling into a few long tapered
## lumps up to `extra` px thicker (1 px at their ends).
static func _lumps(rng: RandomNumberGenerator, n: int, base: int, extra: int, every: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(n)
	out.fill(base)
	if extra <= 0:
		return out
	var at := rng.randi_range(3, every)
	while at < n - 4:
		var size := rng.randi_range(1, extra)
		var width := rng.randi_range(5, 9) + 2 * size
		for i in width:
			var ramp := mini(i + 1, width - i)
			if at + i < n - 2:
				out[at + i] = maxi(out[at + i], base + mini(size, (ramp + 1) / 2))
		at += width + rng.randi_range(every / 2, every)
	return out
