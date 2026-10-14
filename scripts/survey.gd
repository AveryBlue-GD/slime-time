class_name Survey
extends RefCounted

## The trail map's data for one story level (normal or hard; randomizer mazes record nothing,
## they are fresh each time): what the player has really seen of the maze over all their runs,
## plus one route. Shown at the hub's MAP TABLE (scripts/ui/map_select.gd); it never shows
## anything the player hasn't seen, so the dark-fog discovery stays.
## A survey is a Dictionary:
##   w, h      the maze's size in tiles
##   fp        the maze's layout fingerprint (`fingerprint`: walls + start + goal); a survey whose
##             size or fingerprint isn't the maze's is from another layout and is ignored (`fits`)
##   seen      PackedByteArray bitset, one bit per tile (row-major, bit i in byte i >> 3, LSB first):
##             every tile EVER revealed (lit by the trail, the Brightness light, or a wall seen),
##             merged (OR) over every recorded attempt, across dry-ups, restarts and sessions
##   start     the route's first maze cell (Vector2i)
##   moves     PackedByteArray, one move code per maze cell stepped (index into
##             MazeGenerator.DIRS: 0 right, 1 left, 2 down, 3 up), at most MAX_MOVES
##   clear     true when the route is the fastest unassisted clear; false = the last attempt's
##             walk (shown faint, "LAST TRY") until there is a clear
##   best_ms   the clear's run time in ms (0 without a clear)
##   goal      the goal (chalice) was seen or reached on some recorded attempt
## Saved under [maps] level_N (N = level, + Progress.HARD_RECORDS on hard) as base64 of `pack`:
##   0 version (2), 1 flags (1 clear, 2 goal), 2 w, 3 h, 4-7 best_ms (u32 LE), 8 start.x, 9 start.y,
##   10-11 move count (u16 LE), 12-15 layout fingerprint (u32 LE), then the seen bitset
##   (ceil(w*h/8) bytes), then the moves at 2 bits each, four to a byte (LSB first).
## Version 1 (no fingerprint) can't be checked against the maze, so it is dropped on load: that level
## just has no survey until its next run (safer than drawing a stale map over a re-laid maze).

const VERSION := 2
const HEADER := 16
## Longest route kept (moves); a walk past this stops being recorded (real runs are a few hundred).
const MAX_MOVES := 2000
## Largest maze (tiles) a survey may describe: the 36x20-cell cap (Levels.HARD_MAX_CELLS) = 73x41.
const MAX_TILES := Vector2i(81, 49)
## Longest packed survey accepted from a save (base64 chars); a full one is well under 1.5 KB.
const MAX_TEXT := 4096
## A clear's time is kept up to a day.
const MAX_MS := 86_400_000
const FLAG_CLEAR := 1
const FLAG_GOAL := 2


## An empty survey of `maze`.
static func blank(maze: Dictionary) -> Dictionary:
	var size: Vector2i = maze.size
	var seen := PackedByteArray()
	seen.resize((size.x * size.y + 7) >> 3)
	return {w = size.x, h = size.y, fp = fingerprint(maze), seen = seen, start = maze.start, moves = PackedByteArray(),
		clear = false, best_ms = 0, goal = false}


## True when `survey` describes this maze: same size in tiles and the same layout (fingerprint).
static func fits(survey: Dictionary, maze: Dictionary) -> bool:
	return not survey.is_empty() and survey.w == maze.size.x and survey.h == maze.size.y \
		and survey.get("fp", -1) == fingerprint(maze)


## A 32-bit fingerprint of a maze's layout: its size, walls, start and goal (MD5, so it is the same
## on every platform and engine version). Any change to the layout gives another one.
static func fingerprint(maze: Dictionary) -> int:
	var head := PackedByteArray()
	head.resize(12)
	head.encode_u16(0, maze.size.x)
	head.encode_u16(2, maze.size.y)
	head.encode_u16(4, maze.start.x)
	head.encode_u16(6, maze.start.y)
	head.encode_u16(8, maze.goal.x)
	head.encode_u16(10, maze.goal.y)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(head)
	ctx.update(maze.walls)
	return ctx.finish().decode_u32(0)


static func is_seen(survey: Dictionary, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= survey.w or tile.y >= survey.h:
		return false
	var i: int = tile.y * survey.w + tile.x
	return (survey.seen[i >> 3] >> (i & 7)) & 1 == 1


## Marks one tile seen (in place; outside the maze does nothing).
static func mark_seen(survey: Dictionary, tile: Vector2i) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= survey.w or tile.y >= survey.h:
		return
	var i: int = tile.y * survey.w + tile.x
	var seen: PackedByteArray = survey.seen
	seen[i >> 3] |= 1 << (i & 7)
	survey.seen = seen


## Merges one attempt into `survey` (in place): `tiles` = one byte per maze tile (non-zero = seen
## on this attempt). Returns true if any new tile was added.
static func merge_seen(survey: Dictionary, tiles: PackedByteArray) -> bool:
	var seen: PackedByteArray = survey.seen
	var count: int = mini(tiles.size(), survey.w * survey.h)
	var added := false
	var i := 0
	while i < count:
		var byte := 0
		for b in mini(8, count - i):
			if tiles[i + b] != 0:
				byte |= 1 << b
		var old := seen[i >> 3]
		if byte & ~old:
			seen[i >> 3] = old | byte
			added = true
		i += 8
	survey.seen = seen
	return added


## The share (0..1) of the maze's floor tiles seen.
static func completeness(survey: Dictionary, maze: Dictionary) -> float:
	if not fits(survey, maze):
		return 0.0
	var walls: PackedByteArray = maze.walls
	var floor_tiles := 0
	var seen_tiles := 0
	var seen: PackedByteArray = survey.seen
	for i in walls.size():
		if walls[i] == 0:
			floor_tiles += 1
			if (seen[i >> 3] >> (i & 7)) & 1 == 1:
				seen_tiles += 1
	return float(seen_tiles) / floor_tiles if floor_tiles > 0 else 0.0


## The route's cells, start first, following the moves while they stay inside the maze and on open
## passages (a move into a wall ends it: a damaged or foreign survey never draws through walls).
static func route_cells(survey: Dictionary, maze: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not fits(survey, maze):
		return cells
	var cell: Vector2i = survey.start
	if cell.x < 0 or cell.y < 0 or cell.x >= maze.cells.x or cell.y >= maze.cells.y:
		return cells
	cells.append(cell)
	for code: int in survey.moves:
		var next: Vector2i = cell + MazeGenerator.DIRS[code & 3]
		if not next in MazeGenerator.open_neighbors(maze, cell):
			break
		cells.append(next)
		cell = next
	return cells


## A finished survey for testing the maps (--story-complete, --maps=full): every tile seen, the
## goal seen, and the shortest start-to-goal route as the best clear in `seconds`.
static func full(maze: Dictionary, seconds: float) -> Dictionary:
	var survey := blank(maze)
	var seen: PackedByteArray = survey.seen
	seen.fill(255)
	survey.seen = seen
	survey.moves = moves_along(MazeGenerator.shortest_path(maze, maze.start, maze.goal))
	survey.clear = true
	survey.best_ms = clampi(roundi(seconds * 1000.0), 1, MAX_MS)
	survey.goal = true
	return survey


## Move codes for a path of neighboring cells.
static func moves_along(path: Array[Vector2i]) -> PackedByteArray:
	var moves := PackedByteArray()
	for i in range(1, mini(path.size(), MAX_MOVES + 1)):
		moves.append(MazeGenerator.DIRS.find(path[i] - path[i - 1]) & 3)
	return moves


## The survey as a short string for the save file (base64 of the packed bytes above).
static func pack(survey: Dictionary) -> String:
	var moves: PackedByteArray = survey.moves
	var count := mini(moves.size(), MAX_MOVES)
	var seen: PackedByteArray = survey.seen
	var bytes := PackedByteArray()
	bytes.resize(HEADER)
	bytes[0] = VERSION
	bytes[1] = (FLAG_CLEAR if survey.clear else 0) | (FLAG_GOAL if survey.goal else 0)
	bytes[2] = survey.w
	bytes[3] = survey.h
	bytes.encode_u32(4, clampi(survey.best_ms, 0, MAX_MS))
	bytes[8] = clampi(survey.start.x, 0, 255)
	bytes[9] = clampi(survey.start.y, 0, 255)
	bytes.encode_u16(10, count)
	bytes.encode_u32(12, int(survey.get("fp", 0)) & 0xFFFFFFFF)
	bytes.append_array(seen.slice(0, (survey.w * survey.h + 7) >> 3))
	var packed := PackedByteArray()
	packed.resize((count + 3) >> 2)
	for i in count:
		packed[i >> 2] |= (moves[i] & 3) << ((i & 3) * 2)
	bytes.append_array(packed)
	return Marshalls.raw_to_base64(bytes)


## A survey from a save string, or {} when it isn't a valid one (wrong type, too long, broken
## base64, unknown version (incl. version 1, which has no fingerprint), a size out of range or a
## length that doesn't add up). Values are clamped: flags masked, time within a day, start cell
## inside the maze; the fingerprint is kept as read (a wrong one only makes the survey not fit).
static func unpack(text: Variant) -> Dictionary:
	if typeof(text) != TYPE_STRING or (text as String).length() > MAX_TEXT or (text as String).length() % 4 != 0 \
			or not _base64_chars().search(text):
		return {}
	var bytes := Marshalls.base64_to_raw(text)
	if bytes.size() < HEADER or bytes[0] != VERSION:
		return {}
	var w := bytes[2]
	var h := bytes[3]
	if w < 3 or h < 3 or w > MAX_TILES.x or h > MAX_TILES.y:
		return {}
	var count := bytes.decode_u16(10)
	var seen_len := (w * h + 7) >> 3
	if count > MAX_MOVES or bytes.size() != HEADER + seen_len + ((count + 3) >> 2):
		return {}
	var cells := Vector2i((w - 1) / 2, (h - 1) / 2)
	var start := Vector2i(clampi(bytes[8], 0, cells.x - 1), clampi(bytes[9], 0, cells.y - 1))
	var moves := PackedByteArray()
	moves.resize(count)
	for i in count:
		moves[i] = (bytes[HEADER + seen_len + (i >> 2)] >> ((i & 3) * 2)) & 3
	var clear := bytes[1] & FLAG_CLEAR != 0
	var best_ms := clampi(bytes.decode_u32(4), 0, MAX_MS)
	if not clear or best_ms <= 0:
		clear = false
		best_ms = 0
	return {w = w, h = h, fp = bytes.decode_u32(12), seen = bytes.slice(HEADER, HEADER + seen_len), start = start, moves = moves,
		clear = clear, best_ms = best_ms, goal = bytes[1] & FLAG_GOAL != 0}


static var _base64: RegEx


## Matches a whole string of base64 characters (so broken text is refused before decoding).
static func _base64_chars() -> RegEx:
	if _base64 == null:
		_base64 = RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return _base64
