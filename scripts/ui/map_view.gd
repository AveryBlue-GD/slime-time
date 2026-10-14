class_name MapView
extends RefCounted

## Draws a story level's trail map (see Survey) into an Image, once per opening (nothing per frame),
## as a maze diagram: every seen cell is a block of floor, and thin wall lines run between cells
## wherever the maze has a wall, so two corridors side by side (a route's hairpin) always show the wall
## between them. Only what the player has seen is drawn:
## - a cell's floor only when the cell was seen (Survey.is_seen on its tile); unseen cells stay the
##   dark fog color;
## - a wall line (or the open doorway in it) only when at least one of the two cells it divides was
##   seen (a wall next to seen floor is known; between two unseen cells it would be a spoiler); the
##   posts where lines cross likewise only at a seen cell's corners;
## - the route (the best clear in the goo color, edged when there is room; the last attempt faint,
##   without the edge) only between two seen cells, through the cells' centers, so a U-turn reads as a
##   hairpin with a wall between its legs; found coins, the start (a ring) and the goal (an X, once it
##   has been seen or reached) only on seen cells.
## So even a damaged or hostile survey can't draw over the fog.
## Sizes are whole pixels (`layout`): a [floor px, wall px] pair per cell, the largest that fits, so
## a 36x20-cell maze still fits the 320x180 screen (6 + 1 px) with room for the title and BACK.
## `theme` (a Themes id; "" = the default parchment) draws the map in that level's palette with a
## themed frame round it: a mockup, off in the game (map_select.THEMED_MAPS).

const FOG := Color8(13, 12, 21)
const FLOOR := Color8(216, 182, 126)
const WALL := Color8(74, 46, 38)
const START := Color8(244, 244, 244)
const GOAL := Color8(200, 36, 52)
const COIN := Color8(255, 205, 117)
const COIN_EDGE := Color8(120, 70, 24)
## Thumbnail colors (dimmer, so the tile's text stays the brightest thing on it).
const THUMB_FLOOR := Color8(132, 108, 80)
const THUMB_WALL := Color8(58, 40, 36)
## [floor px, wall px] per cell, largest first (walls 3 px on the biggest maps, 2 on mid, 1 on small).
const SIZES: Array[Vector2i] = [Vector2i(21, 3), Vector2i(19, 3), Vector2i(17, 3), Vector2i(16, 2),
	Vector2i(14, 2), Vector2i(12, 2), Vector2i(11, 2), Vector2i(10, 2), Vector2i(9, 1), Vector2i(8, 1),
	Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 1), Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)]
## The least brightness difference between the route and the floor (see route_color).
const ROUTE_CONTRAST := 0.22
## The thumbnail's box on a map select tile (px).
const THUMB := Vector2i(36, 20)
## The themed frame's width round the map (px), see `theme`.
const FRAME := 4

## Themed palettes (mockup): paper (seen floor), ink (walls), trail, fog (unseen), and the frame's
## colors [dark, mid, light, accent], taken from each theme's tile palette (tools/make_theme_art.py).
const THEMED := {
	"dungeon": {paper = Color8(206, 200, 184), ink = Color8(44, 48, 70), trail = Color8(64, 110, 190),
		fog = Color8(20, 20, 34), frame = [Color8(26, 28, 44), Color8(86, 108, 134), Color8(148, 176, 194), Color8(94, 140, 60)]},
	"mossy": {paper = Color8(214, 214, 170), ink = Color8(40, 58, 36), trail = Color8(56, 132, 52),
		fog = Color8(12, 24, 18), frame = [Color8(16, 24, 18), Color8(64, 80, 56), Color8(104, 126, 90), Color8(98, 164, 62)]},
	"sandstone": {paper = Color8(240, 214, 160), ink = Color8(110, 68, 40), trail = Color8(40, 120, 150),
		fog = Color8(30, 22, 20), frame = [Color8(48, 28, 22), Color8(164, 118, 72), Color8(216, 174, 112), Color8(248, 224, 166)]},
	"sunken": {paper = Color8(196, 222, 208), ink = Color8(20, 62, 70), trail = Color8(30, 90, 160),
		fog = Color8(8, 20, 30), frame = [Color8(10, 26, 32), Color8(48, 110, 106), Color8(88, 162, 150), Color8(112, 172, 222)]},
	"sewers": {paper = Color8(204, 196, 168), ink = Color8(54, 46, 36), trail = Color8(96, 160, 20),
		fog = Color8(24, 26, 8), frame = [Color8(22, 18, 16), Color8(76, 66, 52), Color8(120, 128, 134), Color8(150, 232, 40)]},
	"catacombs": {paper = Color8(222, 212, 190), ink = Color8(62, 52, 46), trail = Color8(120, 60, 140),
		fog = Color8(24, 20, 18), frame = [Color8(28, 22, 20), Color8(108, 100, 90), Color8(158, 148, 132), Color8(234, 224, 198)]},
	"frozen": {paper = Color8(222, 236, 248), ink = Color8(40, 62, 120), trail = Color8(60, 130, 210),
		fog = Color8(14, 20, 38), frame = [Color8(16, 24, 50), Color8(112, 152, 202), Color8(172, 208, 238), Color8(255, 255, 255)]},
	"obsidian": {paper = Color8(178, 172, 202), ink = Color8(28, 26, 44), trail = Color8(124, 60, 180),
		fog = Color8(6, 6, 12), frame = [Color8(6, 6, 10), Color8(42, 40, 62), Color8(72, 68, 104), Color8(154, 144, 214)]},
	"crystal": {paper = Color8(226, 212, 240), ink = Color8(66, 42, 94), trail = Color8(30, 150, 170),
		fog = Color8(20, 10, 34), frame = [Color8(22, 10, 32), Color8(94, 62, 132), Color8(142, 102, 182), Color8(122, 222, 232)]},
	"volcanic": {paper = Color8(214, 190, 170), ink = Color8(58, 30, 26), trail = Color8(220, 90, 24),
		fog = Color8(28, 10, 10), frame = [Color8(14, 8, 8), Color8(62, 42, 42), Color8(152, 40, 20), Color8(255, 200, 80)]},
}


## The largest [floor px, wall px] that fits `cells` into `area` px (`framed`: leaving room for the
## themed frame).
static func layout(cells: Vector2i, area: Vector2i, framed := false) -> Vector2i:
	var room := area - Vector2i.ONE * (FRAME * 2 if framed else 0)
	for s in SIZES:
		if map_size(cells, s).x <= room.x and map_size(cells, s).y <= room.y:
			return s
	return SIZES[SIZES.size() - 1]


## The map's size in px (without a themed frame): a wall line on every side of every cell.
static func map_size(cells: Vector2i, sizes: Vector2i) -> Vector2i:
	return cells * (sizes.x + sizes.y) + Vector2i.ONE * sizes.y


## A cell's floor rect (px).
static func cell_rect(cell: Vector2i, sizes: Vector2i) -> Rect2i:
	return Rect2i(cell * (sizes.x + sizes.y) + Vector2i.ONE * sizes.y, Vector2i.ONE * sizes.x)


## The rect of the wall line between `cell` and its neighbor `cell + dir` (one of MazeGenerator.DIRS):
## as long as the floor is wide, as thick as the wall.
static func edge_rect(cell: Vector2i, dir: Vector2i, sizes: Vector2i) -> Rect2i:
	var r := cell_rect(cell, sizes)
	if dir.x > 0:
		return Rect2i(r.end.x, r.position.y, sizes.y, sizes.x)
	if dir.x < 0:
		return Rect2i(r.position.x - sizes.y, r.position.y, sizes.y, sizes.x)
	if dir.y > 0:
		return Rect2i(r.position.x, r.end.y, sizes.x, sizes.y)
	return Rect2i(r.position.x, r.position.y - sizes.y, sizes.x, sizes.y)


## The route's width on a floor of `floor_px`: about a third of it, with the same parity, so it sits
## exactly in the middle with floor showing on both sides (from 3 px floors up).
static func route_width(floor_px: int) -> int:
	var w := maxi(1, floor_px / 3)
	if (floor_px - w) % 2 == 1:
		w += 1 if floor_px - w - 1 >= 2 else -1
	return clampi(w, 1, floor_px)


## The colors of a map: the default parchment (theme ""), a themed one, or the thumbnail's.
static func palette(goo: Dictionary, theme := "", thumb := false) -> Dictionary:
	var pal := {fog = FOG, floor = FLOOR, wall = WALL, route = route_color(goo, FLOOR), goo = goo.mid, edge = goo.outline,
		start = START, goal = GOAL, coin = COIN, coin_edge = COIN_EDGE}
	if THEMED.has(theme):
		var t: Dictionary = THEMED[theme]
		pal.merge({fog = t.fog, floor = t.paper, wall = t.ink, route = t.trail, goo = t.trail, edge = (t.trail as Color).darkened(0.6),
			start = t.ink}, true)  # a white start ring would vanish on the pale papers
	if thumb:
		pal.fog = Color(0, 0, 0, 0)  # unseen cells stay clear over the tile's dark well
		if not THEMED.has(theme):
			pal.floor = THUMB_FLOOR
			pal.wall = THUMB_WALL
	pal.faint = (pal.route as Color).lerp(pal.floor, 0.5)
	return pal


## The route's color without an edge: the skin's goo, or its darker shade when the goo is too close to
## the floor in brightness to read on it (a pale lemon or lime on parchment). An edged route (big
## maps) is always the goo itself.
static func route_color(goo: Dictionary, floor: Color) -> Color:
	var mid: Color = goo.mid
	if absf(mid.get_luminance() - floor.get_luminance()) >= ROUTE_CONTRAST:
		return mid
	return goo.dark


## The full map of `survey` on `maze` (which it must fit, Survey.fits), at `sizes` (see layout).
## `coins`: cells of found coins; `goo`: the skin's goo shades (Skins.shades); `theme`: see above
## (adds a FRAME px frame round the map).
static func render(maze: Dictionary, survey: Dictionary, sizes: Vector2i, coins: Array[Vector2i], goo: Dictionary, theme := "") -> Image:
	var pal := palette(goo, theme)
	var px := map_size(maze.cells, sizes)
	var image := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	image.fill(pal.fog)
	if Survey.fits(survey, maze):
		_draw_maze(image, maze, survey, sizes, pal)
		_draw_route(image, survey, Survey.route_cells(survey, maze), sizes, pal, true)
		_draw_marks(image, maze, survey, sizes, coins, pal)
	if not THEMED.has(theme):
		return image
	var framed := Image.create_empty(px.x + FRAME * 2, px.y + FRAME * 2, false, Image.FORMAT_RGBA8)
	framed.fill(pal.fog)
	framed.blit_rect(image, Rect2i(Vector2i.ZERO, px), Vector2i.ONE * FRAME)
	_draw_frame(framed, theme)
	return framed


## Seen cells' floor, the line on each side of them (a wall, or floor where the maze is open), and
## the posts at their corners. Nothing touches a cell that wasn't seen unless a seen one borders it.
static func _draw_maze(image: Image, maze: Dictionary, survey: Dictionary, sizes: Vector2i, pal: Dictionary) -> void:
	var cells: Vector2i = maze.cells
	for cy in cells.y:
		for cx in cells.x:
			var cell := Vector2i(cx, cy)
			if not _cell_seen(survey, cell):
				continue
			image.fill_rect(cell_rect(cell, sizes), pal.floor)
			for dir: Vector2i in MazeGenerator.DIRS:
				var tile: Vector2i = cell * 2 + Vector2i.ONE + dir
				image.fill_rect(edge_rect(cell, dir, sizes), pal.wall if MazeGenerator.is_wall(maze, tile) else pal.floor)
	# Posts: the wall tiles where the lines cross (always walls), at the corners of seen cells.
	var step := sizes.x + sizes.y
	for py in cells.y + 1:
		for px in cells.x + 1:
			var near := false
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
				near = near or _cell_seen(survey, Vector2i(px, py) + d)
			if near:
				image.fill_rect(Rect2i(px * step, py * step, sizes.y, sizes.y), pal.wall)


static func _cell_seen(survey: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and Survey.is_seen(survey, cell * 2 + Vector2i.ONE)


## The route as a band through the cells' centers (route_width wide, so floor shows on both sides of
## it and a hairpin's two legs keep the wall line between them): a clear in the goo color, edged in its
## outline shade when the floor has room (`edged`), the last attempt faint without the edge. A step is
## drawn only between two seen cells.
static func _draw_route(image: Image, survey: Dictionary, cells: Array[Vector2i], sizes: Vector2i, pal: Dictionary, edged: bool) -> void:
	if cells.is_empty():
		return
	var clear: bool = survey.clear
	var w := route_width(sizes.x)
	var passes: Array = [[w, pal.route if clear else pal.faint]]
	if clear and edged and (sizes.x - w) / 2 >= 3:
		passes = [[w + 2, pal.edge], [w, pal.goo]]
	for p: Array in passes:
		var width: int = p[0]
		var color: Color = p[1]
		var inset := Vector2i.ONE * ((sizes.x - width) / 2)
		for i in cells.size():
			var ca := cells[i]
			var cb := cells[mini(i + 1, cells.size() - 1)]
			if not (_cell_seen(survey, ca) and _cell_seen(survey, cb)):
				continue
			var a := cell_rect(ca, sizes).position + inset
			var b := cell_rect(cb, sizes).position + inset
			image.fill_rect(Rect2i(a.min(b), (a.max(b) - a.min(b)) + Vector2i.ONE * width), color)


## Found coins, the start ring and the goal X, each centered in its (seen) cell.
static func _draw_marks(image: Image, maze: Dictionary, survey: Dictionary, sizes: Vector2i, coins: Array[Vector2i], pal: Dictionary) -> void:
	var f := sizes.x
	var dot := mini(f, maxi(2, f * 2 / 5))
	if (f - dot) % 2 == 1:
		dot += -1 if dot > 2 else 1
	for cell in coins:
		if _cell_seen(survey, cell):
			var r := cell_rect(cell, sizes)
			if dot >= 3 and dot + 2 <= f:
				_draw_disc(image, _centered(r, dot + 2), pal.coin_edge)
			_draw_disc(image, _centered(r, dot), pal.coin)
	var mark := mini(f, route_width(f) + 4)
	if _cell_seen(survey, survey.start):
		_draw_ring(image, _centered(cell_rect(survey.start, sizes), mark), pal.start)
	if survey.goal and _cell_seen(survey, maze.goal):
		_draw_x(image, _centered(cell_rect(maze.goal, sizes), mini(f, maxi(5, mark))), pal.goal)


## A coin: the square `r` with its corners cut (1 px from 4 px up, 2 px from 8 px up).
static func _draw_disc(image: Image, r: Rect2i, color: Color) -> void:
	var cut := 2 if r.size.x >= 8 else (1 if r.size.x >= 4 else 0)
	for y in r.size.y:
		var inset := maxi(0, cut - mini(y, r.size.y - 1 - y))
		image.fill_rect(Rect2i(r.position.x + inset, r.position.y + y, r.size.x - inset * 2, 1), color)


## A `size` px square centered in `r` (whole pixels).
static func _centered(r: Rect2i, size: int) -> Rect2i:
	return Rect2i(r.position + Vector2i.ONE * ((r.size.x - size) / 2), Vector2i.ONE * size)


static func _draw_ring(image: Image, r: Rect2i, color: Color) -> void:
	if r.size.x < 3:
		image.fill_rect(r, color)
		return
	image.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), color)
	image.fill_rect(Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)), color)
	image.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), color)
	image.fill_rect(Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y)), color)


## An X filling the square `r`, mirror-symmetric (2 px strokes from 6 px up).
static func _draw_x(image: Image, r: Rect2i, color: Color) -> void:
	var s := r.size.x
	var bold := s >= 6
	for k in s:
		for x: int in [k, s - 1 - k]:
			image.set_pixelv(r.position + Vector2i(x, k), color)
		if bold and k < s - 1:
			image.set_pixelv(r.position + Vector2i(k + 1, k), color)
			image.set_pixelv(r.position + Vector2i(s - 2 - k, k), color)


## The map select tile's thumbnail, as big as fits THUMB: the same wall-line diagram as the map
## (seen floor dim, walls, the route, start and goal) when the maze fits at 1 px floor + 1 px walls or
## more; a bigger maze gets one block per cell (seen cells floor, the route's cells in the goo color),
## too small for wall lines. Unseen cells are transparent (nothing is drawn on them).
static func thumbnail(maze: Dictionary, survey: Dictionary, goo: Dictionary, theme := "") -> Image:
	var pal := palette(goo, theme, true)
	var cells: Vector2i = maze.cells
	var sizes := layout(cells, THUMB)
	var px := map_size(cells, sizes)
	if px.x <= THUMB.x and px.y <= THUMB.y:
		var lines := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
		if Survey.fits(survey, maze):
			_draw_maze(lines, maze, survey, sizes, pal)
			_draw_route(lines, survey, Survey.route_cells(survey, maze), sizes, pal, false)
			if _cell_seen(survey, survey.start):
				lines.fill_rect(_centered(cell_rect(survey.start, sizes), route_width(sizes.x)), pal.start)
			if survey.goal and _cell_seen(survey, maze.goal):
				lines.fill_rect(cell_rect(maze.goal, sizes), pal.goal)
		return lines
	var scale := maxi(1, mini(THUMB.x / cells.x, THUMB.y / cells.y))
	var image := Image.create_empty(cells.x * scale, cells.y * scale, false, Image.FORMAT_RGBA8)
	if not Survey.fits(survey, maze):
		return image
	for cy in cells.y:
		for cx in cells.x:
			if _cell_seen(survey, Vector2i(cx, cy)):
				image.fill_rect(Rect2i(cx * scale, cy * scale, scale, scale), pal.floor)
	var route: Color = pal.route if survey.clear else pal.faint
	for cell in Survey.route_cells(survey, maze):
		if _cell_seen(survey, cell):
			image.fill_rect(Rect2i(cell * scale, Vector2i.ONE * scale), route)
	if _cell_seen(survey, survey.start):
		image.fill_rect(Rect2i(survey.start * scale, Vector2i.ONE * scale), pal.start)
	if survey.goal and _cell_seen(survey, maze.goal):
		image.fill_rect(Rect2i(maze.goal * scale, Vector2i.ONE * scale), pal.goal)
	return image


## The themed frame (mockup): a FRAME px border in the theme's colors with a cheap motif of its own
## (stone joints, moss tufts, sand strata, wave crests, pipe bolts and drips, bones, frost, glossy
## glints, crystals, lava glow) and accent studs in the corners. Pure integer hashing: the same every time.
static func _draw_frame(image: Image, theme: String) -> void:
	var c: Array = THEMED[theme].frame
	var w := image.get_width()
	var h := image.get_height()
	var f := FRAME
	for y in h:
		for x in w:
			var d := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))  # depth into the band, 0 = outer edge
			if d >= f:
				continue
			var color: Color = c[0] if d == 0 else (c[2] if d == f - 1 else c[1])
			var n := _hash(x, y)
			var blob := _hash(x >> 1, y >> 1)  # 2x2 px clumps, less noisy than single pixels
			var along := x if (y < f or y >= h - f) else y
			match theme:
				"dungeon":  # brick joints
					if d > 0 and d < f - 1 and along % 6 == 0:
						color = c[0]
				"mossy":  # moss tufts creeping over the band
					if d > 0 and (blob % 4 == 0 or (n % 3 == 0 and d == f - 1)):
						color = c[3]
				"sandstone":  # strata
					color = [c[0], c[1], c[3], c[2]][d]
					if d > 0 and n % 9 == 0:
						color = c[1]
				"sunken":  # wave crests
					if d == 1 and along % 6 < 2 or d == 2 and along % 6 == 2:
						color = c[3]
				"sewers":  # a pipe with bolts and toxic drips
					if d == 1 and along % 10 == 0:
						color = c[2]
					elif d == f - 1 and n % 6 == 0:
						color = c[3]
				"catacombs":  # little bones laid along the band
					if (d == 1 or d == 2) and along % 8 < 5 and not (along % 8 in [1, 2, 3] and d == 2):
						color = c[3]
				"frozen":  # frost rime and speckles
					if d == f - 1:
						color = c[3]
					elif d > 0:
						color = c[2] if blob % 3 else c[3]
				"obsidian":  # glossy glints on black glass
					color = c[0] if d < f - 1 else c[2]
					if d > 0 and d < f - 1 and n % 11 == 0:
						color = c[3]
				"crystal":  # crystal shards
					if d > 0 and blob % 6 == 0:
						color = c[3]
					elif d == f - 1:
						color = c[2]
				"volcanic":  # lava glow on the inner edge, embers in the rock
					if d == f - 1:
						color = c[3] if blob % 3 == 0 else c[2]
					elif d > 0 and blob % 11 == 0:
						color = c[3]
			image.set_pixel(x, y, color)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(w - f, 0), Vector2i(0, h - f), Vector2i(w - f, h - f)]:
		image.fill_rect(Rect2i(corner, Vector2i(f, f)), c[0])
		image.fill_rect(Rect2i(corner + Vector2i.ONE, Vector2i(f - 2, f - 2)), c[3])


static func _hash(x: int, y: int) -> int:
	var n := (x * 374761393 + y * 668265263) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return n ^ (n >> 16)
