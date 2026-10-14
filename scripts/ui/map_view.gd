class_name MapView
extends RefCounted

## Draws a story level's trail map (see Survey) into an Image, once per opening (nothing per frame):
## only what the player has seen is drawn. Unseen tiles stay the dark fog color (so the map never
## shows layout that hasn't been surveyed), seen floor is parchment and seen walls ink-brown; on top,
## the route (the best clear in the goo color with a dark edge, or the last attempt faint, without
## the edge), found coins (gold, only on seen tiles), the start (a white ring) and the goal (a red X)
## only once it has been seen or reached. Every mark is clipped to seen tiles too (a route step is
## drawn only when both cells and the passage between them were seen; the start, goal and coins only
## on seen cells), so even a damaged or hostile survey can't draw over the fog.
## Cells and walls get integer sizes (`layout`): the largest pair that fits the area, so a 36x20-cell
## maze (73x41 tiles) still fits the 320x180 screen with room for the title and BACK.

const FOG := Color8(13, 12, 21)
const FLOOR := Color8(216, 182, 126)
const FLOOR_ALT := Color8(204, 168, 114)
const WALL := Color8(104, 70, 60)
const START := Color8(244, 244, 244)
const GOAL := Color8(200, 36, 52)
const COIN := Color8(255, 205, 117)
const COIN_EDGE := Color8(120, 70, 24)
## Thumbnail colors (one pixel or block per maze cell).
const THUMB_SEEN := Color8(112, 90, 70)
## [cell px, wall px] pairs, largest first.
const SIZES: Array[Vector2i] = [Vector2i(14, 4), Vector2i(12, 3), Vector2i(10, 3), Vector2i(8, 2),
	Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)]
## The thumbnail's box on a map select tile (cells).
const THUMB := Vector2i(36, 20)


## The largest [cell px, wall px] that fits `cells` into `area` px.
static func layout(cells: Vector2i, area: Vector2i) -> Vector2i:
	for s in SIZES:
		if map_size(cells, s).x <= area.x and map_size(cells, s).y <= area.y:
			return s
	return SIZES[SIZES.size() - 1]


static func map_size(cells: Vector2i, sizes: Vector2i) -> Vector2i:
	return cells * (sizes.x + sizes.y) + Vector2i.ONE * sizes.y


## A tile's first pixel along one axis, and its width (cells odd, walls even tile indices).
static func _tile_px(t: int, sizes: Vector2i) -> Vector2i:
	return Vector2i((t >> 1) * (sizes.x + sizes.y) + (sizes.y if t & 1 else 0), sizes.x if t & 1 else sizes.y)


static func _cell_center(cell: Vector2i, sizes: Vector2i) -> Vector2i:
	return cell * (sizes.x + sizes.y) + Vector2i.ONE * (sizes.y + sizes.x / 2)


## The full map of `survey` on `maze` (which it must fit, Survey.fits), at `sizes` (see layout).
## `coins`: cells of found coins; `goo`: the skin's goo shades (Skins.shades).
static func render(maze: Dictionary, survey: Dictionary, sizes: Vector2i, coins: Array[Vector2i], goo: Dictionary) -> Image:
	var px := map_size(maze.cells, sizes)
	var image := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	image.fill(FOG)
	if not Survey.fits(survey, maze):
		return image
	var walls: PackedByteArray = maze.walls
	var w: int = maze.size.x
	for ty in maze.size.y:
		var y := _tile_px(ty, sizes)
		for tx in w:
			if not Survey.is_seen(survey, Vector2i(tx, ty)):
				continue
			var x := _tile_px(tx, sizes)
			var color := WALL if walls[ty * w + tx] == 1 else (FLOOR if ((tx >> 1) + (ty >> 1)) & 1 == 0 else FLOOR_ALT)
			image.fill_rect(Rect2i(x.x, y.x, x.y, y.y), color)
	_draw_route(image, survey, Survey.route_cells(survey, maze), sizes, goo)
	var dot := maxi(1, sizes.x / 2)
	for cell in coins:
		if Survey.is_seen(survey, cell * 2 + Vector2i.ONE):
			var c := _cell_center(cell, sizes)
			if dot >= 3:
				image.fill_rect(Rect2i(c - Vector2i.ONE * ((dot + 2) / 2), Vector2i.ONE * (dot + 2)), COIN_EDGE)
			image.fill_rect(Rect2i(c - Vector2i.ONE * (dot / 2), Vector2i.ONE * dot), COIN)
	if _cell_seen(survey, survey.start):
		_draw_ring(image, _cell_center(survey.start, sizes), maxi(5, sizes.x - 2), START)
	if survey.goal and _cell_seen(survey, maze.goal):
		_draw_x(image, _cell_center(maze.goal, sizes), maxi(5, sizes.x - 1), GOAL)
	return image


static func _cell_seen(survey: Dictionary, cell: Vector2i) -> bool:
	return Survey.is_seen(survey, cell * 2 + Vector2i.ONE)


## The route as a line through the cells' centers: a clear in the goo color on a dark edge, the
## last attempt faint (half blended into the floor) and without the edge. Only steps over seen tiles
## (both cells and the passage tile between them) are drawn.
static func _draw_route(image: Image, survey: Dictionary, cells: Array[Vector2i], sizes: Vector2i, goo: Dictionary) -> void:
	if cells.is_empty():
		return
	var clear: bool = survey.clear
	var thick := maxi(1, sizes.x / 4)
	var line: Color = goo.light if clear else (goo.mid as Color).lerp(FLOOR, 0.5)
	var passes: Array = [[thick + 2, goo.outline], [thick, line]] if clear else [[thick, line]]
	for p: Array in passes:
		var width: int = p[0]
		var color: Color = p[1]
		for i in cells.size():
			var ca := cells[i]
			var cb := cells[mini(i + 1, cells.size() - 1)]
			if not (_cell_seen(survey, ca) and _cell_seen(survey, cb) and Survey.is_seen(survey, ca + cb + Vector2i.ONE)):
				continue
			var a := _cell_center(ca, sizes)
			var b := _cell_center(cb, sizes)
			var from: Vector2i = a.min(b) - Vector2i.ONE * (width / 2)
			var to: Vector2i = a.max(b) + Vector2i.ONE * ((width - 1) / 2)
			image.fill_rect(Rect2i(from, to - from + Vector2i.ONE), color)


static func _draw_ring(image: Image, center: Vector2i, size: int, color: Color) -> void:
	var r := Rect2i(center - Vector2i.ONE * (size / 2), Vector2i.ONE * size)
	image.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), color)
	image.fill_rect(Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)), color)
	image.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), color)
	image.fill_rect(Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y)), color)


## A bold X (2 px strokes from 5 px up; 1 px below) centered on `center`.
static func _draw_x(image: Image, center: Vector2i, size: int, color: Color) -> void:
	var half := size / 2
	var bold := 1 if size >= 5 else 0
	for d in range(-half, half + 1):
		for p: Vector2i in [center + Vector2i(d, d), center + Vector2i(d, -d)]:
			for b in bold + 1:
				var q := p + Vector2i(b, 0)
				if q.x >= 0 and q.y >= 0 and q.x < image.get_width() and q.y < image.get_height():
					image.set_pixelv(q, color)


## The map select tile's thumbnail: one block per maze cell (as big as fits THUMB), seen cells
## parchment-dim, the route's cells in the goo color (faint for a last attempt), the start white and
## the goal red once seen; unseen cells transparent (nothing is drawn on them).
static func thumbnail(maze: Dictionary, survey: Dictionary, goo: Dictionary) -> Image:
	var cells: Vector2i = maze.cells
	var scale := maxi(1, mini(THUMB.x / cells.x, THUMB.y / cells.y))
	var image := Image.create_empty(cells.x * scale, cells.y * scale, false, Image.FORMAT_RGBA8)
	if not Survey.fits(survey, maze):
		return image
	for cy in cells.y:
		for cx in cells.x:
			if Survey.is_seen(survey, Vector2i(cx * 2 + 1, cy * 2 + 1)):
				image.fill_rect(Rect2i(cx * scale, cy * scale, scale, scale), THUMB_SEEN)
	var route: Color = goo.light if survey.clear else (goo.mid as Color).lerp(THUMB_SEEN, 0.5)
	for cell in Survey.route_cells(survey, maze):
		if _cell_seen(survey, cell):
			image.fill_rect(Rect2i(cell * scale, Vector2i.ONE * scale), route)
	if _cell_seen(survey, survey.start):
		image.fill_rect(Rect2i(survey.start * scale, Vector2i.ONE * scale), START)
	if survey.goal and _cell_seen(survey, maze.goal):
		image.fill_rect(Rect2i(maze.goal * scale, Vector2i.ONE * scale), GOAL)
	return image
