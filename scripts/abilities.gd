class_name Abilities
extends RefCounted

## ABILITIES v1 (docs/design/upgrades-v2.md "Abilities v1"): three active abilities bought with
## tickets in the cauldron's TICKETS tab (Progress.buy_ability; 3 levels each, not refundable) and
## used in a level with their own keys (1 / 2 / 3 by default, remappable; touch buttons by JUMP):
##   SLIME RIFLE  a goo shot flies straight to the first wall, revealing every floor tile it passes
##                (and the walls around them) and leaving a thin goo streak
##   SLIME SPLAT  a goo bomb lobbed up to Economy.SPLAT_RANGE tiles (stops at walls) bursts and lights
##                up / reveals the 3x3 tiles around where it lands
##   SLIMAKAZE    the slime dashes to the first wall and splats hard (Economy.ABILITIES.kaze.slime %
##                of the meter), spraying goo over a seeded random spread of tiles around the impact
## Each is aimed along the slime's facing (its last movement direction), snapped to the nearest of the
## four grid directions (a diagonal goes along x). Numbers: Economy.ABILITIES and the RIFLE_ / SPLAT_ /
## KAZE_ constants. This file holds the static rules (geometry, prices, icons); the in-level effects
## are AbilityRunner (scripts/ability_runner.gd).

const TILE := 16

const LIST := [
	{id = "rifle", name = "SLIME RIFLE", tag = "SHOOTS GOO", action = "ability_rifle", key = KEY_1},
	{id = "splat", name = "SLIME SPLAT", tag = "BOMB 3X3", action = "ability_splat", key = KEY_2},
	{id = "kaze", name = "SLIMAKAZE", tag = "WALL DASH", action = "ability_kaze", key = KEY_3},
]

## 8x8 icons in the boon icons' palette letters (BoonIcons.PAL): the goo shot streaking into a wall,
## the goo bomb with its lit fuse, the slime squashed flat against a wall with speed lines.
const ART := {
	"rifle": ["......xW", "....kk.W", "...kHlkW", "lllklmmW", "...kmnkW", "....kk.W", "......xW", "........"],
	"splat": ["....Yy..", "...ko...", "..kkkk..", ".kHllmk.", "kHelllmk", "kllmmmnk", ".kmmnnk.", "..kkkk.."],
	"kaze": [".....kWx", "ee..kHWx", "...kllWx", "eeklllWx", "...kmmWx", "ee..kmWx", ".....kWx", "........"],
}

static var _icons := {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in LIST:
		out.append(item.id)
	return out


static func _item(id: String) -> Dictionary:
	for item: Dictionary in LIST:
		if item.id == id:
			return item
	return {}


static func display_name(id: String) -> String:
	return _item(id).get("name", "")


## The short tag shown under the name in the cauldron (2-3 words; the owner wants no long text).
static func tag(id: String) -> String:
	return _item(id).get("tag", "")


## The input action of ability `id` ("ability_rifle" ...); made at startup by Progress (remappable).
static func action(id: String) -> String:
	return _item(id).get("action", "")


static func _track(id: String) -> Dictionary:
	return Economy.ABILITIES.get(id, {})


static func max_level(id: String) -> int:
	var track := _track(id)
	return track.costs.size() if not track.is_empty() else 0


## Tickets for the next level up from `level` (0 when maxed or unknown).
static func cost(id: String, level: int) -> int:
	var track := _track(id)
	if track.is_empty() or level < 0 or level >= track.costs.size():
		return 0
	return track.costs[level]


## Tickets a track at `level` cost in all.
static func total_cost(id: String, level: int) -> int:
	var track := _track(id)
	var total := 0
	if not track.is_empty():
		for i in clampi(level, 0, track.costs.size()):
			total += int(track.costs[i])
	return total


## Uses per attempt at `level` (0 at level 0).
static func charges(id: String, level: int) -> int:
	var track := _track(id)
	if track.is_empty() or level <= 0:
		return 0
	return int(track.charges[mini(level, track.charges.size()) - 1])


## Percent of the meter one use costs.
static func slime_cost(id: String) -> float:
	return float(_track(id).get("slime", 0.0))


# ---------------------------------------------------------------- geometry (tiles of the maze)

## The grid direction an ability goes for the slime's `facing`: the larger axis wins, x on a tie
## (an exact diagonal); never zero.
static func aim(facing: Vector2) -> Vector2i:
	if facing == Vector2.ZERO:
		return Vector2i.RIGHT
	if absf(facing.x) >= absf(facing.y):
		return Vector2i(1 if facing.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if facing.y > 0.0 else -1)


## The floor tiles after `from` going `dir`, up to (not including) the first wall; at most `limit`
## tiles when limit >= 0.
static func line_tiles(maze: Dictionary, from: Vector2i, dir: Vector2i, limit := -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at := from + dir
	while not MazeGenerator.is_wall(maze, at) and (limit < 0 or out.size() < limit):
		out.append(at)
		at += dir
	return out


## SLIME RIFLE: the tiles the shot reveals (its own tile, then every floor tile to the wall).
static func rifle_tiles(maze: Dictionary, from: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [from]
	out.append_array(line_tiles(maze, from, dir))
	return out


## SLIME SPLAT: where the bomb lands (`from` itself when a wall is right ahead).
static func lob_tile(maze: Dictionary, from: Vector2i, dir: Vector2i) -> Vector2i:
	var tiles := line_tiles(maze, from, dir, Economy.SPLAT_RANGE)
	return tiles[-1] if not tiles.is_empty() else from


## SLIME SPLAT: the tiles its burst reveals (floor and wall alike), clipped to the maze.
static func burst_tiles(maze: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := Economy.SPLAT_AREA
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tile := center + Vector2i(dx, dy)
			if tile.x >= 0 and tile.y >= 0 and tile.x < maze.size.x and tile.y < maze.size.y:
				out.append(tile)
	return out


## SLIMAKAZE: the last floor tile before the first wall (`from` itself when a wall is right ahead:
## then it doesn't fire).
static func dash_tile(maze: Dictionary, from: Vector2i, dir: Vector2i) -> Vector2i:
	var tiles := line_tiles(maze, from, dir)
	return tiles[-1] if not tiles.is_empty() else from


## SLIMAKAZE: where the slime stops (touching the wall ahead of `tile`, on its lane).
static func dash_point(tile: Vector2i, dir: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE + Vector2(dir) * (TILE / 2.0 - Slime.RADIUS)


## SLIMAKAZE: the seed of one splatter (stable for a maze, attempt, impact tile and use).
static func splatter_seed(maze_seed: int, attempt: int, impact: Vector2i, use: int) -> int:
	return hash([maze_seed, attempt, impact.x, impact.y, use])


## SLIMAKAZE: the splatter around `impact`: for every floor tile within KAZE_RADIUS (tile centers),
## nearest first, a roll against a chance falling from KAZE_CHANCE_NEAR to KAZE_CHANCE_FAR; each hit
## is {tile, offset (px from the tile's center, the goo blob's center), radius (px)}. A blob always
## stays inside its tile (|offset| <= 3, radius <= 4). Deterministic for a seed.
static func splatter(maze: Dictionary, impact: Vector2i, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var reach := ceili(Economy.KAZE_RADIUS)
	var tiles: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile := impact + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= Economy.KAZE_RADIUS and not MazeGenerator.is_wall(maze, tile):
				tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - impact).length_squared()
		var db := (b - impact).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for tile in tiles:
		var t := Vector2(tile - impact).length() / Economy.KAZE_RADIUS
		var roll := rng.randf()
		var offset := Vector2(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		var radius := float(rng.randi_range(3, 4))
		if tile == impact or roll < lerpf(Economy.KAZE_CHANCE_NEAR, Economy.KAZE_CHANCE_FAR, t):
			out.append({tile = tile, offset = offset, radius = radius})
	return out


# ---------------------------------------------------------------- icons

## The 8x8 icon of ability `id` (cached; BoonIcons' palette).
static func icon(id: String) -> ImageTexture:
	if not _icons.has(id):
		var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var rows: Array = ART.get(id, [])
		for y in rows.size():
			var row: String = rows[y]
			for x in mini(row.length(), 8):
				if BoonIcons.PAL.has(row[x]):
					image.set_pixel(x, y, BoonIcons.PAL[row[x]])
		_icons[id] = ImageTexture.create_from_image(image)
	return _icons[id]


## A TextureRect with the icon at `scale` x (whole pixels).
static func make_icon(id: String, scale := 1) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(8, 8) * scale
	rect.size = rect.custom_minimum_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect
