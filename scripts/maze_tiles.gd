class_name MazeTiles
extends RefCounted

## Fills a floor + wall TileMapLayer pair for a maze: picks a wall variant for every wall tile
## (edges from its neighbors, damage and style from the level's weights) and a floor type for
## every tile, plus (optionally) a fillet layer that rounds the inner corners where walls meet.
## Seeded, so a maze always looks the same. Used by the game and the menu backdrop.
##
## Tile atlases per theme from tools/make_theme_art.py (paths from Themes.atlas_path).
## walls: column = neighbor mask (N=1 E=2 S=4 W=8 set when that neighbor is wall),
##        row = construction * 12 + damage * 3 + style. floors: column = floor type, row = variant.
## Each theme has CONSTRUCTIONS kinds of wall (e.g. brick, cut blocks, cobbles); a smooth noise
## map picks one per tile, so the material changes in patches across the maze.
## fillets.png: column = the same neighbor mask, for a floor tile (one row).
## border.png: the border outside the maze (add_border).

const TILE := 16
const WALL_SOURCE := 0
const FLOOR_SOURCE := 1
const FILLET_SOURCE := 2
const WALL_MASKS := 16
const CONSTRUCTIONS := 3
const WALL_ROWS := CONSTRUCTIONS * 12
## Noise scale for the construction patches, and the cut-offs (about 50% / 30% / 20%).
const CONSTRUCTION_FREQUENCY := 0.11
const CONSTRUCTION_CUTS: Array[float] = [0.0, 0.3]
const FLOOR_TYPES := 8
const FLOOR_VARIANTS := 4
const FLOOR_RUBBLE := 7
const BROKEN := 3
const RUBBLE_CHANCE := 0.7
## The border atlas (themes/<id>_border.png, see add_border): the ring's tiles collide (BORDER_SOURCE),
## the bedrock past it uses the same art without collision (BORDER_DEEP_SOURCE).
const BORDER_SOURCE := 3
const BORDER_DEEP_SOURCE := 4
const BORDER_GRID := Vector2i(16, 8)
const BORDER_PROP_ROW := 4
const BORDER_RIM_ROW := 5
const BORDER_BOULDER_ROW := 6
const BORDER_BOULDERS := 8
## Percent chances: a 2x2 boulder where one fits, a prop on whole bedrock, decoration on whole rim stone.
const BORDER_BOULDER_CHANCE := 10
const BORDER_PROP_CHANCE := 28
const BORDER_RIM_CHANCE := 30
## Corners between the lattice points of the rim's thickness noise, and the score (noise 0-99 +
## jitter 0-15) a corner 1, 2 ... tiles out must beat to be rim stone (about 45% and 12%; none further).
const BORDER_NOISE_STEP := 6
const BORDER_STONE_CUT: Array[int] = [0, 58, 86]


## Returns each wall tile's damage level (0-3), by tile coordinate.
static func fill(floor_layer: TileMapLayer, wall_layer: TileMapLayer, maze: Dictionary, tile_seed: int,
		tile_level: int, fillet_layer: TileMapLayer = null, theme := Themes.DUNGEON) -> Dictionary:
	var tile_set := make_tile_set(theme)
	floor_layer.tile_set = tile_set
	wall_layer.tile_set = tile_set
	if fillet_layer:
		fillet_layer.tile_set = tile_set
	var rng := RandomNumberGenerator.new()
	rng.seed = tile_seed * 7919 + 17
	var damage_weights := Levels.damage_weights(tile_level)
	var style_weights := PackedFloat32Array(Levels.WALL_STYLE)
	var floor_weights := Levels.floor_weights(tile_level)
	var wall_damage := {}
	var patches := FastNoiseLite.new()
	patches.seed = tile_seed
	patches.frequency = CONSTRUCTION_FREQUENCY

	for y in maze.size.y:
		for x in maze.size.x:
			var tile := Vector2i(x, y)
			if not MazeGenerator.is_wall(maze, tile):
				continue
			var mask := wall_mask(maze, tile)
			var damage := rng.rand_weighted(damage_weights)
			var style := rng.rand_weighted(style_weights)
			wall_damage[tile] = damage
			var construction := construction_at(patches, tile)
			wall_layer.set_cell(tile, WALL_SOURCE, Vector2i(mask, construction * 12 + damage * 3 + style))

	# Floor goes under walls too, so broken-off chunks of wall show floor through them.
	for y in maze.size.y:
		for x in maze.size.x:
			var tile := Vector2i(x, y)
			var type := 0
			if not MazeGenerator.is_wall(maze, tile):
				type = rng.rand_weighted(floor_weights)
				if wall_damage.get(tile + Vector2i.UP, 0) == BROKEN and rng.randf() < RUBBLE_CHANCE:
					type = FLOOR_RUBBLE
			floor_layer.set_cell(tile, FLOOR_SOURCE, Vector2i(type, rng.randi_range(0, FLOOR_VARIANTS - 1)))
			if fillet_layer and not MazeGenerator.is_wall(maze, tile):
				var mask := wall_mask(maze, tile)
				if has_corner(mask):
					fillet_layer.set_cell(tile, FILLET_SOURCE, Vector2i(mask, 0))
	return wall_damage


## Which of the theme's wall constructions a tile uses (0 = the main one).
static func construction_at(patches: FastNoiseLite, tile: Vector2i) -> int:
	var n := patches.get_noise_2d(tile.x, tile.y)
	for i in CONSTRUCTION_CUTS.size():
		if n < CONSTRUCTION_CUTS[i]:
			return i
	return CONSTRUCTION_CUTS.size()


## The unbreakable border outside the maze: `ring` tiles of wall (with the maze's own outer wall, a
## double wall that marks where the maze ends; they collide like any wall), then bedrock on out to
## `depth` tiles (scenery only: no collision, never reachable), drawn from the theme's border atlas
## (tools/make_theme_art.py `<id>_border.png`). See border_cells for how the tiles are picked.
## Fully opaque art, so no floor is laid under it.
static func add_border(_floor_layer: TileMapLayer, wall_layer: TileMapLayer, maze: Dictionary, ring := 1,
		depth := 1, salt := 0, theme := Themes.DUNGEON) -> void:
	_add_border_sources(wall_layer.tile_set, theme)
	var cells := border_cells(maze.size, ring, maxi(depth, ring), salt)
	for tile: Vector2i in cells:
		var pick: Vector3i = cells[tile]
		wall_layer.set_cell(tile, pick.z, Vector2i(pick.x, pick.y))


## Border tiles by tile coordinate: Vector3i(atlas column, atlas row, source). Every tile within
## `depth` of the maze (Chebyshev distance 1..depth) and none inside it. Deterministic integer math
## from `salt` (the level's tile seed), the same on every platform:
## - Each tile corner is rim stone or bedrock. Corners on the maze's edge are always stone; further
##   out stone gets rarer, with a smooth thickness noise along the edge, so the rim's depth wanders.
##   The tile shows its four corners' terrain (atlas column = corner mask NW=1 NE=2 SW=4 SE=8).
## - 2x2 boulders sit where four whole-bedrock tiles meet (BORDER_BOULDER_CHANCE percent of spots);
##   whole-bedrock and whole-stone tiles sometimes carry a themed prop (rows 4 and 5); the rest pick
##   one of the variants: stone by construction patches (smooth noise), plain bedrock by depth (past
##   the ring the sparser, deeper-looking rows 2-3).
static func border_cells(maze_size: Vector2i, ring: int, depth: int, salt: int) -> Dictionary:
	var cells := {}
	var used := {}
	var region := Rect2i(-Vector2i.ONE * depth, maze_size + Vector2i.ONE * depth * 2)
	var stone := {}
	for cy in range(-depth, maze_size.y + depth + 1):
		for cx in range(-depth, maze_size.x + depth + 1):
			stone[Vector2i(cx, cy)] = _corner_stone(Vector2i(cx, cy), maze_size, salt)
	# Boulders first (whole-bedrock 2x2 blocks), in a fixed order so overlaps resolve the same way.
	for y in range(region.position.y, region.end.y - 1):
		for x in range(region.position.x, region.end.x - 1):
			var at := Vector2i(x, y)
			if not _boulder_fits(at, maze_size, depth, stone, used):
				continue
			var h := border_hash(x, y, salt + 3)
			if h % 100 >= BORDER_BOULDER_CHANCE:
				continue
			var which := (h / 100) % BORDER_BOULDERS
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				used[at + d] = true
				cells[at + d] = Vector3i(which * 2 + d.x, BORDER_BOULDER_ROW + d.y, _border_source(at + d, maze_size, ring))
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			var d := border_depth(tile, maze_size)
			if d <= 0 or used.has(tile):
				continue
			var mask := _corner_mask(tile, stone)
			var h := border_hash(x, y, salt + 5)
			# Stone shows the theme's constructions in patches (rows 0-1 the main one, 2 and 3 the others).
			var patch := _smooth_noise(tile, salt + 7)
			var pick := Vector2i(mask, h % 2 if patch < 45 else (2 if patch < 70 else 3))
			if mask == 0:
				pick.y = (h % 2) + (0 if d <= ring else 2)
				if (h / 8) % 100 < BORDER_PROP_CHANCE:
					pick = Vector2i((h / 800) % 16, BORDER_PROP_ROW)
			elif mask == 15 and (h / 8) % 100 < BORDER_RIM_CHANCE:
				pick = Vector2i((h / 800) % 16, BORDER_RIM_ROW)
			cells[tile] = Vector3i(pick.x, pick.y, _border_source(tile, maze_size, ring))
	return cells


## How far outside the maze a tile is (0 inside it, 1 = the ring next to it, ...).
static func border_depth(tile: Vector2i, maze_size: Vector2i) -> int:
	return maxi(maxi(-tile.x, tile.x - maze_size.x + 1), maxi(maxi(-tile.y, tile.y - maze_size.y + 1), 0))


## The ring collides like the maze's walls; the bedrock beyond can't be reached and doesn't.
static func _border_source(tile: Vector2i, maze_size: Vector2i, ring: int) -> int:
	return BORDER_SOURCE if border_depth(tile, maze_size) <= ring else BORDER_DEEP_SOURCE


static func _corner_mask(tile: Vector2i, stone: Dictionary) -> int:
	var mask := 0
	if stone[tile]:
		mask |= 1
	if stone[tile + Vector2i(1, 0)]:
		mask |= 2
	if stone[tile + Vector2i(0, 1)]:
		mask |= 4
	if stone[tile + Vector2i(1, 1)]:
		mask |= 8
	return mask


static func _boulder_fits(at: Vector2i, maze_size: Vector2i, depth: int, stone: Dictionary, used: Dictionary) -> bool:
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var tile := at + d
		var td := border_depth(tile, maze_size)
		if td <= 0 or td > depth or used.has(tile):
			return false
	for dy in 3:
		for dx in 3:
			if stone[at + Vector2i(dx, dy)]:
				return false
	for dy in range(-2, 4):  # two tiles of bedrock between boulders, so they don't line up in rows
		for dx in range(-2, 4):
			if used.has(at + Vector2i(dx, dy)):
				return false
	return true


## Whether a tile corner (corner (x, y) is the top-left of tile (x, y)) is rim stone. Corners on the
## maze's edge always are; further out, the edge's thickness noise (0-99, smooth along the edge) plus
## a little jitter must beat BORDER_STONE_CUT for that distance, so the rim runs thick or thin in
## long stretches rather than flickering tile by tile.
static func _corner_stone(corner: Vector2i, maze_size: Vector2i, salt: int) -> bool:
	var d := maxi(maxi(-corner.x, corner.x - maze_size.x), maxi(maxi(-corner.y, corner.y - maze_size.y), 0))
	if d <= 0:
		return true
	if d >= BORDER_STONE_CUT.size():
		return false
	var thickness := _smooth_noise(corner, salt)
	var jitter := border_hash(corner.x, corner.y, salt + 1) % 16
	return thickness + jitter > BORDER_STONE_CUT[d]


## Value noise (0-99) on a lattice of BORDER_NOISE_STEP corners, blended bilinearly in integers.
static func _smooth_noise(at: Vector2i, salt: int) -> int:
	var step := BORDER_NOISE_STEP
	var fx := posmod(at.x, step)
	var fy := posmod(at.y, step)
	var gx := (at.x - fx) / step
	var gy := (at.y - fy) / step
	var v00 := border_hash(gx, gy, salt) % 100
	var v10 := border_hash(gx + 1, gy, salt) % 100
	var v01 := border_hash(gx, gy + 1, salt) % 100
	var v11 := border_hash(gx + 1, gy + 1, salt) % 100
	return (v00 * (step - fx) * (step - fy) + v10 * fx * (step - fy) + v01 * (step - fx) * fy + v11 * fx * fy) / (step * step)


## A well-mixed non-negative 31-bit hash of a tile and a salt (64-bit integer math, no floats).
static func border_hash(x: int, y: int, salt: int) -> int:
	var h := (x * 374761393 + y * 668265263 + (salt & 0x7FFFFFFF) * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0x7FFFFFFF


## Neighbor mask: N=1 E=2 S=4 W=8 set where that neighbor is a wall.
static func wall_mask(maze: Dictionary, tile: Vector2i) -> int:
	var mask := 0
	for bit_dir: Array in [[1, Vector2i.UP], [2, Vector2i.RIGHT], [4, Vector2i.DOWN], [8, Vector2i.LEFT]]:
		if MazeGenerator.is_wall(maze, tile + bit_dir[1]):
			mask |= bit_dir[0]
	return mask


## True if two touching sides (N+E, E+S, S+W, W+N) are both walls.
static func has_corner(mask: int) -> bool:
	return (mask & 3) == 3 or (mask & 6) == 6 or (mask & 12) == 12 or (mask & 9) == 9


## Built tile sets by theme (never changed once built; layers only change their cells): the menu
## backdrop's dungeon set, plus the last level theme so a restart reuses it.
static var _tile_sets := {}


static func make_tile_set(theme := Themes.DUNGEON) -> TileSet:
	if _tile_sets.has(theme):
		return _tile_sets[theme]
	for kept: String in _tile_sets.keys():
		if kept != Themes.DUNGEON:
			_tile_sets.erase(kept)
	var tile_set := _build_tile_set(theme)
	_tile_sets[theme] = tile_set
	return tile_set


static func _build_tile_set(theme: String) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()

	var walls := _make_atlas(load(Themes.atlas_path(theme, "walls")), Vector2i(WALL_MASKS, WALL_ROWS))
	tile_set.add_source(walls, WALL_SOURCE)
	tile_set.add_source(_make_atlas(load(Themes.atlas_path(theme, "floors")),
		Vector2i(FLOOR_TYPES, FLOOR_VARIANTS)), FLOOR_SOURCE)
	tile_set.add_source(_make_atlas(load(Themes.atlas_path(theme, "fillets")), Vector2i(WALL_MASKS, 1)), FILLET_SOURCE)

	# Every wall blocks fully, however broken it looks.
	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	for row in WALL_ROWS:
		for column in WALL_MASKS:
			var data := walls.get_tile_data(Vector2i(column, row), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tile_set


## The border atlas sources (add_border), added to a theme's tile set the first time a level needs
## them (the menu backdrop never does): the ring's copy collides like the walls, the other doesn't.
static func _add_border_sources(tile_set: TileSet, theme: String) -> void:
	if tile_set.has_source(BORDER_SOURCE):
		return
	var texture: Texture2D = load(Themes.atlas_path(theme, "border"))
	var border := _make_atlas(texture, BORDER_GRID)
	tile_set.add_source(border, BORDER_SOURCE)
	tile_set.add_source(_make_atlas(texture, BORDER_GRID), BORDER_DEEP_SOURCE)
	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	for row in BORDER_GRID.y:
		for column in BORDER_GRID.x:
			var data := border.get_tile_data(Vector2i(column, row), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)


static func _make_atlas(texture: Texture2D, grid: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for row in grid.y:
		for column in grid.x:
			source.create_tile(Vector2i(column, row))
	return source
