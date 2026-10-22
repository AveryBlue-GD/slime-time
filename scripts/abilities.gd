class_name Abilities
extends RefCounted

## ABILITIES v1 (docs/design/upgrades-v2.md "Abilities v1"): three active abilities bought with
## tickets in the cauldron's TICKETS tab (Progress.buy_ability; 3 levels each, not refundable) and
## used in a level with their own keys (1 / 2 / 3 by default, remappable; touch buttons by JUMP):
##   SLIME RIFLE  a goo shot flies straight THROUGH walls for Economy.RIFLE_RANGE tiles (by level; to
##                the maze's edge at most), revealing every tile it crosses (floor tiles with the walls
##                around them) and leaving a thin goo streak on the floor
##   SLIME SPLAT  a goo bomb lobbed OVER walls exactly Economy.SPLAT_RANGE tiles (by level, clamped to
##                the maze) bursts and lights up / reveals the 3x3 tiles around where it lands
##   SLIMAKAZE    the slime dashes to the first wall and splats hard (Economy.ABILITIES.kaze.slime %
##                of the meter), spraying goo over a seeded random spread of floor tiles within
##                Economy.KAZE_RADIUS (by level) of the impact, walls in between ignored
## Each is aimed along the slime's facing (its last movement direction), snapped to the nearest of the
## four grid directions (a diagonal goes along x). Numbers: Economy.ABILITIES and the RIFLE_ / SPLAT_ /
## KAZE_ constants. This file holds the static rules (geometry, prices, icons); the in-level effects
## are AbilityRunner (scripts/ability_runner.gd).

const TILE := 16


## THE RULE (owner, 2026-10-15): abilities work ONLY in randomizer mazes and Descent runs, never in a
## story level (normal or hard). Hard-mode randomizer stays off too (hard mode is played without
## upgrades; Descent always plays normal rules). Every ability path (runner, HUD strip, touch
## buttons, keys) hangs off AbilityRunner.create, which asks this.
static func allowed_in(game: Node) -> bool:
	if game == null or game.hard_mode:
		return false
	return game.is_random() or game.descent

const LIST := [
	{id = "rifle", name = "SLIME SNIPER", tag = "SHOOTS GOO", action = "ability_rifle", key = KEY_1},  # i18n: ignore (English source; shown via display_name)
	{id = "splat", name = "GOO GRENADE", tag = "BOMB 5X5", action = "ability_splat", key = KEY_2},  # i18n: ignore (English source; shown via display_name)
	{id = "kaze", name = "SLIMAKAZE", tag = "WALL DASH", action = "ability_kaze", key = KEY_3},  # i18n: ignore (English source; shown via display_name)
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
	# i18n: ability name, cauldron row and key list, max 110px
	match id:
		"rifle":
			return Loc.t("ability.rifle.name", "SLIME SNIPER")
		"splat":
			return Loc.t("ability.splat.name", "GOO GRENADE")
		"kaze":
			# i18n: pun on kamikaze + slime; keep a pun if the language can
			return Loc.t("ability.kaze.name", "SLIMAKAZE")
	return _item(id).get("name", "")


## The short tag shown under the name in the cauldron (2-3 words; the owner wants no long text).
static func tag(id: String) -> String:
	# i18n: short tag under the ability name, 2-3 words, max 110px
	match id:
		"rifle":
			return Loc.t("ability.rifle.desc", "SHOOTS GOO")
		"splat":
			# 5X5 is the blast size in tiles
			return Loc.t("ability.splat.desc", "BOMB 5X5")
		"kaze":
			return Loc.t("ability.kaze.desc", "WALL DASH")
	return _item(id).get("tag", "")


## The input action of ability `id` ("ability_rifle" ...); made at startup by Progress (remappable).
static func action(id: String) -> String:
	return _item(id).get("action", "")


static func _track(id: String) -> Dictionary:
	return Economy.ABILITIES.get(id, {})


static func max_level(id: String) -> int:
	var track := _track(id)
	return track.costs.size() if not track.is_empty() else 0


## The track's ticket prices: Economy.ABILITIES, with the demo's own first levels while it is on (Demo.ability_prices).
static func _costs(id: String) -> Array:
	var track := _track(id)
	return Demo.ability_prices(id, track.costs) if not track.is_empty() else []


## Tickets for the next level up from `level` (0 when maxed or unknown).
static func cost(id: String, level: int) -> int:
	var costs := _costs(id)
	if level < 0 or level >= costs.size():
		return 0
	return costs[level]


## Tickets a track at `level` cost in all.
static func total_cost(id: String, level: int) -> int:
	var costs := _costs(id)
	var total := 0
	for i in clampi(level, 0, costs.size()):
		total += int(costs[i])
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


## `v` (a direction) snapped to one of 8 grid directions, diagonals included (the aim mode of SLIME
## SNIPER / GOO GRENADE; owner, 2026-10-22). Zero: right.
static func aim8(v: Vector2) -> Vector2i:
	if v == Vector2.ZERO:
		return Vector2i.RIGHT
	var a := roundf(v.angle() / (PI / 4.0)) * (PI / 4.0)
	return Vector2i(roundi(cos(a)), roundi(sin(a)))


## How many diagonal steps match a straight `reach`: about as far (reach / sqrt 2), at least 1;
## a straight `dir` keeps `reach`.
static func reach_along(reach: int, dir: Vector2i) -> int:
	return reach if dir.x == 0 or dir.y == 0 else maxi(1, roundi(reach / sqrt(2.0)))


## The floor tiles after `from` going `dir`, up to (not including) the first wall; at most `limit`
## tiles when limit >= 0.
static func line_tiles(maze: Dictionary, from: Vector2i, dir: Vector2i, limit := -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at := from + dir
	while not MazeGenerator.is_wall(maze, at) and (limit < 0 or out.size() < limit):
		out.append(at)
		at += dir
	return out


## A per-level number from one of Economy's [L1, L2, L3] tables.
static func _by_level(table: Array, level: int):
	return table[clampi(level, 1, table.size()) - 1]


## SLIME RIFLE: tiles the shot flies past its own at `level`.
static func rifle_range(level: int) -> int:
	return _by_level(Economy.RIFLE_RANGE, level)


## SLIME SPLAT: tiles ahead the bomb lands at `level`.
static func splat_range(level: int) -> int:
	return _by_level(Economy.SPLAT_RANGE, level)


## SLIMAKAZE: the splatter's radius (tiles) at `level`.
static func kaze_radius(level: int) -> float:
	return _by_level(Economy.KAZE_RADIUS, level)


static func in_maze(maze: Dictionary, tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < maze.size.x and tile.y < maze.size.y


## SLIME RIFLE: the tiles the shot crosses: its own, then `reach` tiles straight on, walls and all
## (it pierces them), stopping early at the maze's outer edge.
static func rifle_tiles(maze: Dictionary, from: Vector2i, dir: Vector2i, reach: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [from]
	for i in range(1, reach_along(reach, dir) + 1):  # (diagonally: about as far, see reach_along)
		if not in_maze(maze, from + dir * i):
			break
		out.append(from + dir * i)
	return out


## SLIME SPLAT: where the bomb lands: `reach` tiles ahead over any walls, clamped inside the maze
## (a wall tile is fine: its 3x3 still bursts).
static func lob_tile(maze: Dictionary, from: Vector2i, dir: Vector2i, reach: int) -> Vector2i:
	var to := from + dir * reach_along(reach, dir)
	return Vector2i(clampi(to.x, 0, maze.size.x - 1), clampi(to.y, 0, maze.size.y - 1))


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


## SLIMAKAZE: the seed of one splatter: the maze, the impact tile and the use index (SLIMAKAZE uses
## so far this attempt), never the attempt, so every mode follows one rule and a restart can't re-roll it.
static func splatter_seed(maze_seed: int, impact: Vector2i, use: int) -> int:
	return hash([maze_seed, impact.x, impact.y, use])


## SLIMAKAZE: the splatter around `impact`: for every floor tile of the maze within `radius` tiles
## (tile centers; walls in between don't block it, so it reaches the corridors beyond), nearest
## first, a roll against a chance falling from KAZE_CHANCE_NEAR to KAZE_CHANCE_FAR; each hit
## is {tile, offset (px from the tile's center, the goo blob's center), radius (px)}. A blob always
## stays inside its tile (|offset| <= 3, radius <= 4). Deterministic for a seed.
static func splatter(maze: Dictionary, impact: Vector2i, seed_value: int, radius: float) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var reach := ceili(radius)
	var tiles: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile := impact + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= radius and not MazeGenerator.is_wall(maze, tile):
				tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - impact).length_squared()
		var db := (b - impact).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for tile in tiles:
		var t := Vector2(tile - impact).length() / maxf(radius, 0.001)
		var roll := rng.randf()
		var offset := Vector2(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		var blob_radius := float(rng.randi_range(3, 4))
		if tile == impact or roll < lerpf(Economy.KAZE_CHANCE_NEAR, Economy.KAZE_CHANCE_FAR, t):
			out.append({tile = tile, offset = offset, radius = blob_radius})
	return out


# ---------------------------------------------------------------- icons

## The 8x8 icon of ability `id` (cached; BoonIcons' palette).
static func icon(id: String) -> ImageTexture:
	if not _icons.has(id):
		_icons[id] = BoonIcons.paint(ART.get(id, []))
	return _icons[id]


## A TextureRect with the icon at `scale` x (whole pixels).
static func make_icon(id: String, scale := 1) -> TextureRect:
	return BoonIcons.icon_rect(icon(id), scale)
