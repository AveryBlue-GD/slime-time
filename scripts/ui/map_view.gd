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
## - the route: a thin (1 px) red line through the cells' centers, whatever skin the slime wears
##   (ROUTE; the best clear solid, the last attempt dashed and fainter), only between two seen cells,
##   so a U-turn reads as a hairpin with a wall between its legs; the start (a ring) and the goal (an
##   X in the wall ink, once it has been seen or reached) only on seen cells.
## - coins: only the cells the caller passes (Progress.map_coins): collected coins are never drawn
##   (for everyone); the map coin reveal
##   (Economy.map_coin_reveal_on) passes the revealed uncollected ones, which may sit in fog
##   (`fog_coins`: seen through a wall by a bright light, or with F1 FULL BRIGHT); otherwise only on seen cells.
## So even a damaged or hostile survey can't draw over the fog (fog_coins is dev-only, in memory).
## Sizes are whole pixels (`layout`): a [floor px, wall px] pair per cell, the largest that fits, so
## a 36x20-cell maze still fits the 320x180 screen (5 + 2 px) with room for the title and BACK. Floors
## are always an odd number of px, so the 1 px route runs exactly down the middle of a corridor.
## `theme` (a Themes id; "" = the plain parchment) draws the map in that level's palette with a themed
## frame round it (on in the game: map_select.THEMED_MAPS). `paper` (a Cosmetics map paper, bought in
## the prize wheel's SHOP; "" / "parchment" = none) recolors the paper, ink, fog, marks and frame
## (Cosmetics.paper_colors; the frame keeps its theme's motif in the paper's colors); the route
## stays red on every paper.
## The MAP TABLE's tiles never show the real map: `preview` draws a tiny made-up example maze per
## level (EXAMPLE_CELLS, fixed for everyone, nothing from the real layout), lit in proportion to the
## real % uncovered, with an example route only when the level has a recorded route.

const FOG := Color8(13, 12, 21)
const FLOOR := Color8(216, 182, 126)
const WALL := Color8(74, 46, 38)
const START := Color8(244, 244, 244)
const COIN := Color8(255, 205, 117)
const COIN_EDGE := Color8(120, 70, 24)
## The route: a saturated red that reads on every palette (pale parchment and the dark-theme papers),
## never the skin's color.
const ROUTE := Color8(222, 24, 40)
## How far the last attempt's dashes fade toward the floor.
const ROUTE_FAINT := 0.3
## The last attempt's dash rhythm (px on, px off).
const DASH := Vector2i(2, 2)
## [floor px, wall px] per cell, largest first; floors are odd so the 1 px route is centered (walls
## 3 px on the biggest maps, 2 on mid, 1 on small).
const SIZES: Array[Vector2i] = [Vector2i(21, 3), Vector2i(19, 3), Vector2i(17, 3), Vector2i(15, 3),
	Vector2i(15, 2), Vector2i(13, 2), Vector2i(11, 2), Vector2i(9, 2), Vector2i(9, 1), Vector2i(7, 2),
	Vector2i(7, 1), Vector2i(5, 2), Vector2i(5, 1), Vector2i(3, 1), Vector2i(1, 1)]
## The thumbnail's box on a map select tile (px).
const THUMB := Vector2i(36, 20)
## The themed frame's width round the map (px), see `theme`.
const FRAME := 4
## The select tiles' example mazes: cells, drawn at 3 px floor + 1 px walls with a 1 px themed frame
## (35x19 px, inside THUMB).
const EXAMPLE_CELLS := Vector2i(8, 4)
const EXAMPLE_SIZES := Vector2i(3, 1)
## A fully uncovered level's preview frame.
const PREVIEW_GOLD := Color8(220, 168, 72)
## The plain (unthemed) frame colors [dark, mid, light, accent].
const PLAIN_FRAME := [Color8(26, 28, 44), Color8(74, 46, 38), Color8(132, 108, 80), Color8(216, 182, 126)]

## Themed palettes: paper (seen floor), ink (walls), fog (unseen), and the frame's colors [dark, mid,
## light, accent], taken from each theme's tile palette (tools/make_theme_art.py).
const THEMED := {
	"dungeon": {paper = Color8(206, 200, 184), ink = Color8(44, 48, 70),
		fog = Color8(20, 20, 34), frame = [Color8(26, 28, 44), Color8(86, 108, 134), Color8(148, 176, 194), Color8(94, 140, 60)]},
	"mossy": {paper = Color8(214, 214, 170), ink = Color8(40, 58, 36),
		fog = Color8(12, 24, 18), frame = [Color8(16, 24, 18), Color8(64, 80, 56), Color8(104, 126, 90), Color8(98, 164, 62)]},
	"sandstone": {paper = Color8(240, 214, 160), ink = Color8(110, 68, 40),
		fog = Color8(30, 22, 20), frame = [Color8(48, 28, 22), Color8(164, 118, 72), Color8(216, 174, 112), Color8(248, 224, 166)]},
	"sunken": {paper = Color8(196, 222, 208), ink = Color8(20, 62, 70),
		fog = Color8(8, 20, 30), frame = [Color8(10, 26, 32), Color8(48, 110, 106), Color8(88, 162, 150), Color8(112, 172, 222)]},
	"sewers": {paper = Color8(204, 196, 168), ink = Color8(54, 46, 36),
		fog = Color8(24, 26, 8), frame = [Color8(22, 18, 16), Color8(76, 66, 52), Color8(120, 128, 134), Color8(150, 232, 40)]},
	"catacombs": {paper = Color8(222, 212, 190), ink = Color8(62, 52, 46),
		fog = Color8(24, 20, 18), frame = [Color8(28, 22, 20), Color8(108, 100, 90), Color8(158, 148, 132), Color8(234, 224, 198)]},
	"frozen": {paper = Color8(222, 236, 248), ink = Color8(40, 62, 120),
		fog = Color8(14, 20, 38), frame = [Color8(16, 24, 50), Color8(112, 152, 202), Color8(172, 208, 238), Color8(255, 255, 255)]},
	"obsidian": {paper = Color8(178, 172, 202), ink = Color8(28, 26, 44),
		fog = Color8(6, 6, 12), frame = [Color8(6, 6, 10), Color8(42, 40, 62), Color8(72, 68, 104), Color8(154, 144, 214)]},
	"crystal": {paper = Color8(226, 212, 240), ink = Color8(66, 42, 94),
		fog = Color8(20, 10, 34), frame = [Color8(22, 10, 32), Color8(94, 62, 132), Color8(142, 102, 182), Color8(122, 222, 232)]},
	"volcanic": {paper = Color8(214, 190, 170), ink = Color8(58, 30, 26),
		fog = Color8(28, 10, 10), frame = [Color8(14, 8, 8), Color8(62, 42, 42), Color8(152, 40, 20), Color8(255, 200, 80)]},
}

## Example mazes (per level and mode) and preview textures, built once and kept (see `preview`).
static var _examples := {}
static var _previews := {}


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


## The route's width: a thin 1 px line (whatever the floor).
static func route_width(_floor_px: int) -> int:
	return 1


## Where the route runs inside a cell's floor (px from its top-left): the middle pixel.
static func route_inset(floor_px: int) -> int:
	return (floor_px - 1) / 2


## The colors of a map: the plain parchment (theme "") or a themed one, then map paper `paper` over
## it. Only the NIGHT paper depends on the skin (`ink`: its color).
static func palette(theme := "", paper := "", ink := Color.WHITE) -> Dictionary:
	var pal := {fog = FOG, floor = FLOOR, wall = WALL, route = ROUTE, start = START, goal = WALL,
		coin = COIN, coin_edge = COIN_EDGE, frame = PLAIN_FRAME}
	if THEMED.has(theme):
		var t: Dictionary = THEMED[theme]
		# A white start ring would vanish on the pale papers: start and goal marks in the ink.
		pal.merge({fog = t.fog, floor = t.paper, wall = t.ink, start = t.ink, goal = t.ink, frame = t.frame}, true)
	pal.merge(Cosmetics.paper_colors(paper, ink), true)
	if Coin.METAL.has(theme):  # the level's in-game coin metal, on every paper
		var m: Array = Coin.METAL[theme]
		var edge: Color = m[0]
		if absf(_luma(edge) - _luma(pal.floor)) < 0.25:  # keep the rim readable: the darker outline or the shine
			var dark: Color = edge.lerp(Color.BLACK, 0.5)
			edge = dark if absf(_luma(dark) - _luma(pal.floor)) >= absf(_luma(m[3]) - _luma(pal.floor)) else m[3]
		var fill: Color = m[1]  # (none reads: keep the face, the rim carries it) a face too dark or too like the paper: its light, then its shine (same hue family)
		for cand: Color in [m[1], m[2], m[3]]:
			if _luma(cand) >= 0.25 and absf(_luma(cand) - _luma(pal.floor)) >= 0.25:
				fill = cand
				break
		if fill == m[3] and edge == m[3]:  # face and rim both the shine: a flat coin; the darkened rim instead
			edge = (m[0] as Color).lerp(Color.BLACK, 0.5)
		pal.coin = fill
		pal.coin_edge = edge
	pal.faint = ROUTE.lerp(pal.floor, ROUTE_FAINT)
	return pal


static func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


## The full map of `survey` on `maze` (which it must fit, Survey.fits), at `sizes` (see layout).
## `coins`: cells of coins to mark (never collected ones, see above); `theme`: see above (adds a FRAME
## px frame round the map); `fog_coins`: also mark coins on unseen cells (dev coin reveal test).
static func render(maze: Dictionary, survey: Dictionary, sizes: Vector2i, coins: Array[Vector2i], theme := "",
		paper := "", ink := Color.WHITE, fog_coins := false) -> Image:
	var pal := palette(theme, paper, ink)
	var px := map_size(maze.cells, sizes)
	var image := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	image.fill(pal.fog)
	if Survey.fits(survey, maze):
		_draw_maze(image, maze, survey, sizes, pal)
		_draw_route(image, survey, Survey.route_cells(survey, maze), sizes, pal)
		_draw_marks(image, maze, survey, sizes, coins, pal, fog_coins)
	if not THEMED.has(theme):
		return image
	var framed := Image.create_empty(px.x + FRAME * 2, px.y + FRAME * 2, false, Image.FORMAT_RGBA8)
	framed.fill(pal.fog)
	framed.blit_rect(image, Rect2i(Vector2i.ZERO, px), Vector2i.ONE * FRAME)
	_draw_frame(framed, theme, pal.frame)
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


## The route as a 1 px red line through the cells' centers (floor shows on both sides of it and a
## hairpin's two legs keep the wall line between them): solid for the best clear, dashed and fainter
## for the last attempt. A step is drawn only between two seen cells.
static func _draw_route(image: Image, survey: Dictionary, cells: Array[Vector2i], sizes: Vector2i, pal: Dictionary) -> void:
	if cells.is_empty():
		return
	var clear: bool = survey.clear
	var color: Color = pal.route if clear else pal.faint
	var inset := Vector2i.ONE * route_inset(sizes.x)
	var run := 0  # px along the route, for the dashes
	if cells.size() == 1 and _cell_seen(survey, cells[0]):
		image.set_pixelv(cell_rect(cells[0], sizes).position + inset, color)
	for i in cells.size() - 1:
		var ca := cells[i]
		var cb := cells[i + 1]
		var a := cell_rect(ca, sizes).position + inset
		var b := cell_rect(cb, sizes).position + inset
		var length := (b - a).abs().x + (b - a).abs().y
		var dir := (b - a).sign()
		var drawn := _cell_seen(survey, ca) and _cell_seen(survey, cb)
		for k in length + 1:
			if k == length and i < cells.size() - 2:
				break  # the next step starts here
			if drawn and (clear or run % (DASH.x + DASH.y) < DASH.x):
				image.set_pixelv(a + dir * k, color)
			run += 1


## The given coins, the start ring and the goal X, each centered in its (seen) cell (`fog_coins`: coins
## on unseen cells inside the maze too).
static func _draw_marks(image: Image, maze: Dictionary, survey: Dictionary, sizes: Vector2i, coins: Array[Vector2i], pal: Dictionary,
		fog_coins := false) -> void:
	var f := sizes.x
	var dot := mini(f, maxi(2, f * 2 / 5))
	if (f - dot) % 2 == 1:
		dot += -1 if dot > 2 else 1
	for cell in coins:
		var inside: bool = cell.x >= 0 and cell.y >= 0 and cell.x < maze.cells.x and cell.y < maze.cells.y
		if _cell_seen(survey, cell) or (fog_coins and inside):
			var r := cell_rect(cell, sizes)
			if dot >= 3 and dot + 2 <= f:
				_draw_disc(image, _centered(r, dot + 2), pal.coin_edge)
			_draw_disc(image, _centered(r, dot), pal.coin)
	var mark := mini(f, maxi(5, f * 2 / 5 | 1))
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


# ---------------------------------------------------------------- select tile previews

## The MAP TABLE tile's picture of `level` (normal or `hard`): NOT the real map, but a tiny made-up
## example maze in the level's palette (`theme`) with a 1 px frame in its motif, the same for every
## player and built from nothing but the level number. It only tells what the player has:
## - `locked`: a sealed, dim frame round darkness (the select puts a lock on it);
## - otherwise the first `percent`% of its cells (in a fixed order spreading out from its start)
##   lit, the rest dark; `route` 0 = none, 1 = a last try (faint), 2 = a best clear (solid): the
##   example route, only over lit cells; at 100% the frame turns gold.
## Cached: the same arguments give the same ImageTexture, so the tiles cost nothing after the first.
static func preview(level: int, hard: bool, percent: int, route: int, locked: bool, theme := "") -> ImageTexture:
	var ex := example(level, hard)
	var total: int = ex.order.size()
	var lit := 0
	if not locked:
		lit = total if percent >= 100 else clampi(floori(percent * total / 100.0), 1 if percent > 0 else 0, total - 1)
	var key := "%d|%d|%d|%d|%d|%s" % [level, int(hard), lit, route if not locked else 0, int(locked), theme]
	if _previews.has(key):
		return _previews[key]
	var texture := ImageTexture.create_from_image(preview_image(ex, lit, route if not locked else 0, locked, theme))
	_previews[key] = texture
	return texture


## The preview's pixels (see `preview`): `ex` from `example`, `lit` cells lit.
static func preview_image(ex: Dictionary, lit: int, route: int, locked: bool, theme := "") -> Image:
	var pal := palette(theme)
	var px := map_size(EXAMPLE_CELLS, EXAMPLE_SIZES)
	var image := Image.create_empty(px.x + 2, px.y + 2, false, Image.FORMAT_RGBA8)
	image.fill(pal.fog)
	var maze: Dictionary = ex.maze
	var seen := Survey.blank(maze)
	for i in lit:
		Survey.mark_seen(seen, (ex.order[i] as Vector2i) * 2 + Vector2i.ONE)
	seen.clear = route == 2
	var inner := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	inner.fill(pal.fog)
	_draw_maze(inner, maze, seen, EXAMPLE_SIZES, pal)
	if route > 0:  # the last try solid but faint here: dashes would be noise at this size
		seen.clear = true
		if route == 1:
			pal.route = pal.faint
		_draw_route(inner, seen, ex.route, EXAMPLE_SIZES, pal)
	image.blit_rect(inner, Rect2i(Vector2i.ZERO, px), Vector2i.ONE)
	_draw_mini_frame(image, pal.frame, theme, locked, lit == ex.order.size() and lit > 0)
	return image


## The example maze of `level` (cached): {maze (MazeGenerator layout: size, cells, walls, start,
## goal), order (every cell, spreading out from the start: the order they light up in), route (the
## start-to-goal path)}. A seeded depth-first maze from pure integer hashing of the level number
## alone (hard mode has its own), so it is the same everywhere and knows nothing of the real maze.
static func example(level: int, hard: bool) -> Dictionary:
	var key := level + (100 if hard else 0)
	if _examples.has(key):
		return _examples[key]
	var cells := EXAMPLE_CELLS
	var size := cells * 2 + Vector2i.ONE
	var walls := PackedByteArray()
	walls.resize(size.x * size.y)
	walls.fill(1)
	var salt := 7919 * key + 31
	var start := Vector2i(0 if _hash(salt, 1) % 2 == 0 else cells.x - 1, _hash(salt, 2) % cells.y)
	var visited := {start: true}
	var stack: Array[Vector2i] = [start]
	walls[(start.y * 2 + 1) * size.x + start.x * 2 + 1] = 0
	var n := 0
	while not stack.is_empty():
		# Growing tree: mostly the newest cell (long corridors), sometimes a random one (branches), so
		# the start-to-goal route stays short next to the side passages.
		n += 1
		var at := stack.size() - 1 if _hash(salt, n) % 3 != 0 else _hash(salt + 1, n) % stack.size()
		var cell: Vector2i = stack[at]
		var options: Array[Vector2i] = []
		for dir: Vector2i in MazeGenerator.DIRS:
			var next := cell + dir
			if next.x >= 0 and next.y >= 0 and next.x < cells.x and next.y < cells.y and not visited.has(next):
				options.append(next)
		if options.is_empty():
			stack.remove_at(at)
			continue
		var next: Vector2i = options[_hash(salt, n + 10) % options.size()]
		var t := next * 2 + Vector2i.ONE
		walls[t.y * size.x + t.x] = 0
		var between := cell * 2 + Vector2i.ONE + (next - cell)
		walls[between.y * size.x + between.x] = 0
		visited[next] = true
		stack.append(next)
	var maze := {size = size, cells = cells, walls = walls, start = start, goal = start}
	# The light spreads from the start, breadth first; the goal is the farthest cell.
	var order: Array[Vector2i] = [start]
	var reached := {start: true}
	var i := 0
	while i < order.size():
		for next in MazeGenerator.open_neighbors(maze, order[i]):
			if not reached.has(next):
				reached[next] = true
				order.append(next)
		i += 1
	maze.goal = order[-1]
	var ex := {maze = maze, order = order, route = MazeGenerator.shortest_path(maze, start, maze.goal)}
	_examples[key] = ex
	return ex


## The preview's 1 px frame in the theme's colors with a small rhythm of its motif (joints, moss,
## strata, crests, bolts, bones, rime, glints, shards, embers); dim when `locked`; all gold when the
## level is fully uncovered (`full`).
static func _draw_mini_frame(image: Image, c: Array, theme: String, locked: bool, full: bool) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var perimeter := 2 * (w + h) - 4
	for k in perimeter:
		var p := _perimeter_point(k, w, h)
		var color: Color = c[1]
		var n := _hash(p.x, p.y)
		match theme:
			"dungeon":
				color = c[0] if k % 5 == 0 else c[1]
			"mossy":
				color = c[3] if n % 3 == 0 else c[1]
			"sandstone":
				color = c[3] if k % 4 == 0 else c[2]
			"sunken":
				color = c[3] if k % 6 < 2 else c[1]
			"sewers":
				color = c[2] if k % 7 == 0 else (c[3] if n % 9 == 0 else c[1])
			"catacombs":
				color = c[3] if k % 6 < 3 else c[1]
			"frozen":
				color = c[3] if n % 2 == 0 else c[2]
			"obsidian":
				color = c[3] if n % 5 == 0 else c[2]
			"crystal":
				color = c[3] if n % 3 == 0 else c[2]
			"volcanic":
				color = c[3] if n % 3 == 0 else c[2]
			_:
				color = c[2] if k % 4 == 0 else c[1]
		if locked:
			color = color.darkened(0.6)
		if full:  # fully uncovered: a plain gold frame
			color = PREVIEW_GOLD
		image.set_pixelv(p, color)
	var corner: Color = COIN if full else c[0]
	if locked:
		corner = (c[0] as Color).darkened(0.3)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		image.set_pixelv(p, corner)


## The `k`th pixel round the edge of a w x h image, clockwise from the top-left.
static func _perimeter_point(k: int, w: int, h: int) -> Vector2i:
	if k < w:
		return Vector2i(k, 0)
	k -= w
	if k < h - 1:
		return Vector2i(w - 1, k + 1)
	k -= h - 1
	if k < w - 1:
		return Vector2i(w - 2 - k, h - 1)
	k -= w - 1
	return Vector2i(0, h - 2 - k)


## The themed frame: a FRAME px border in the theme's colors with a cheap motif of its own
## (stone joints, moss tufts, sand strata, wave crests, pipe bolts and drips, bones, frost, glossy
## glints, crystals, lava glow) and accent studs in the corners. Pure integer hashing: the same every time.
static func _draw_frame(image: Image, theme: String, colors: Array = []) -> void:
	var c: Array = colors if colors.size() == 4 else THEMED[theme].frame
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
