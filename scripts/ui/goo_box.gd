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
## Themes that hold goo boxes (UIKit.make_theme registers them): a recolor makes each emit one
## change instead of one per box it holds.
static var _themes: Array[WeakRef] = []
## Dead refs (boxes / themes already freed) are pruned every PRUNE_EVERY registrations, so the lists
## (and their WeakRef objects) stay bounded however many screens are opened.
const PRUNE_EVERY := 32
static var _registered := 0

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
	_count_registration()


## Registers a theme holding goo boxes, so `set_goo_color` batches its change signals.
static func track_theme(theme: Theme) -> void:
	_themes.append(weakref(theme))
	_count_registration()


static func _count_registration() -> void:
	_registered += 1
	if _registered >= PRUNE_EVERY:
		_registered = 0
		prune()


## Drops the refs of freed boxes and themes.
static func prune() -> void:
	_boxes = _live(_boxes)
	_themes = _live(_themes)


static func _live(refs: Array[WeakRef]) -> Array[WeakRef]:
	var out: Array[WeakRef] = []
	for ref in refs:
		if ref.get_ref() != null:
			out.append(ref)
	return out


## Recolors every goo box (redraws them). Each tracked theme's signals are held while its boxes
## change and it then emits once (a theme already held by the caller is left to it), so its
## controls are re-themed once rather than once per box; the final state is the same.
static func set_goo_color(color: Color) -> void:
	if color.is_equal_approx(goo_color):
		return
	goo_color = color
	var held: Array[Theme] = []
	var live_themes: Array[WeakRef] = []
	for ref in _themes:
		var theme := ref.get_ref() as Theme
		if theme:
			live_themes.append(ref)
			if not theme.is_blocking_signals():
				theme.set_block_signals(true)
				held.append(theme)
	_themes = live_themes
	var alive: Array[WeakRef] = []
	for ref in _boxes:
		var box := ref.get_ref() as GooBox
		if box:
			alive.append(ref)
			box.emit_changed()
	_boxes = alive
	for theme in held:
		theme.set_block_signals(false)
		theme.emit_changed()


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


## Shade keys, in the order `_layout` stores them as indices.
const KEYS := ["H", "L", "M", "N", "D", "O"]
const MAX_LAYOUTS := 256

## Per box: the goo layout for each (canvas item, size), built once (see `_layout`). The lumps,
## drops and glints come from an RNG seeded by those, never from the color, so a recolor or a
## redraw only replays the cached runs with the current shades.
var _layouts := {}


func _draw(item: RID, rect: Rect2) -> void:
	var x := int(rect.position.x)
	var y := int(rect.position.y)
	var w := int(rect.size.x)
	var h := int(rect.size.y)
	if w < 6 or h < 6:
		return
	var key := Vector3i(item.get_id(), w, h)
	var layout: Array = _layouts.get(key, [])
	if layout.is_empty():
		if _layouts.size() >= MAX_LAYOUTS:
			_layouts.clear()
		layout = _layout(item.get_id(), w, h)
		_layouts[key] = layout
	var sh := _shades()
	var colors: Array[Color] = []
	var opaque := true
	for k: String in KEYS:
		colors.append(sh[k])
		opaque = opaque and sh[k].a >= 1.0
	RenderingServer.canvas_item_add_rect(item, Rect2(x + 1, y + 1, w - 2, h - 1), face)
	if opaque:
		# Opaque goo: the last write to a pixel is what shows, so same-shade runs of the resolved
		# grid paint exactly the same pixels as the single-pixel writes.
		var runs: PackedInt32Array = layout[0]
		for i in range(0, runs.size(), 4):
			RenderingServer.canvas_item_add_rect(item, Rect2(x + runs[i], y + runs[i + 1], runs[i + 2], 1), colors[runs[i + 3]])
	else:
		var pixels: PackedInt32Array = layout[1]  # every write in its original order
		for i in range(0, pixels.size(), 3):
			RenderingServer.canvas_item_add_rect(item, Rect2(x + pixels[i], y + pixels[i + 1], 1, 1), colors[pixels[i + 2]])


## The goo of a `w` x `h` box drawn on canvas item `item_id`: [runs, pixels]. `pixels` lists every
## 1 px write (dx, dy, shade index) in drawing order; `runs` (dx, dy, length, shade index) merges
## the final grid into horizontal runs of one shade. Offsets are from the box's top-left corner.
func _layout(item_id: int, w: int, h: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([item_id, w, h])
	var pixels := PackedInt32Array()
	var put := func(px: int, py: int, shade: int) -> void:
		pixels.append(px)
		pixels.append(py)
		pixels.append(shade)
	const H := 0
	const L := 1
	const M := 2
	const N := 3
	const O := 5

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
		put.call(0, j, O)
		put.call(w - 1, j, O)
		for d in left[j]:
			put.call(1 + d, j, L if d == 0 else (N if d == left[j] - 1 else M))
		for d in right[j]:
			put.call(w - 2 - d, j, N if d == 0 else M)
	for i in range(1, w - 1):
		put.call(i, 0, O)
		for d in top[i]:
			var shade := M
			if d == 0:
				shade = H if rng.randf() < 0.15 else L
			elif d == top[i] - 1:
				shade = N
			put.call(i, 1 + d, shade)
		for d in bottom[i]:
			put.call(i, h - 1 - d, N if d == 0 else M)
		put.call(i, h, O)  # the bottom outline sits just under the box

	# Drops hanging under the box: round nubs and thin strings.
	var at := drop_edge + rng.randi_range(0, drop_every / 2)
	while at < w - drop_edge - 2:
		if rng.randf() < 0.55:
			var nub: Array = [[-2, O], [-1, M], [0, L], [1, N], [2, O]]
			for p: Array in nub:
				put.call(at + p[0], h, p[1])
			put.call(at - 1, h + 1, O)
			put.call(at, h + 1, N)
			put.call(at + 1, h + 1, O)
		else:
			put.call(at, h, N)
			put.call(at, h + 1, O)
		at += rng.randi_range(drop_every - drop_every / 3, drop_every + drop_every / 3)

	# Resolve the writes into a grid (last write wins) and merge each row into same-shade runs.
	var gw := w + 2
	var gh := h + 2
	var grid := PackedInt32Array()
	grid.resize(gw * gh)
	grid.fill(-1)
	for i in range(0, pixels.size(), 3):
		grid[pixels[i + 1] * gw + pixels[i] + 1] = pixels[i + 2]
	var runs := PackedInt32Array()
	for gy in gh:
		var gx := 0
		while gx < gw:
			var shade := grid[gy * gw + gx]
			var run := 1
			while gx + run < gw and grid[gy * gw + gx + run] == shade:
				run += 1
			if shade >= 0:
				runs.append_array([gx - 1, gy, run, shade])
			gx += run
	return [runs, pixels]


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
