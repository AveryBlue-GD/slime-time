class_name MazeTiles
extends RefCounted

## Fills a floor + wall TileMapLayer pair for a maze: picks a wall variant for every wall tile
## (edges from its neighbors, damage and style from the level's weights) and a floor type for
## every tile, plus (optionally) a fillet layer that rounds the inner corners where walls meet.
## Seeded, so a maze always looks the same. Used by the game and the menu backdrop.
##
## Tile atlases from tools/make_placeholder_art.py.
## walls.png: column = neighbor mask (N=1 E=2 S=4 W=8 set when that neighbor is wall),
##            row = damage * 3 + style. floors.png: column = floor type, row = variant.
## fillets.png: column = the same neighbor mask, for a floor tile (one row).

const TILE := 16
const WALL_SOURCE := 0
const FLOOR_SOURCE := 1
const FILLET_SOURCE := 2
const WALL_MASKS := 16
const WALL_ROWS := 12
const FLOOR_TYPES := 8
const FLOOR_VARIANTS := 4
const FLOOR_RUBBLE := 7
const BROKEN := 3
const RUBBLE_CHANCE := 0.7


## Returns each wall tile's damage level (0-3), by tile coordinate.
static func fill(floor_layer: TileMapLayer, wall_layer: TileMapLayer, maze: Dictionary, tile_seed: int,
		tile_level: int, fillet_layer: TileMapLayer = null) -> Dictionary:
	var tile_set := make_tile_set()
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

	for y in maze.size.y:
		for x in maze.size.x:
			var tile := Vector2i(x, y)
			if not MazeGenerator.is_wall(maze, tile):
				continue
			var mask := _wall_mask(maze, tile)
			var damage := rng.rand_weighted(damage_weights)
			var style := rng.rand_weighted(style_weights)
			wall_damage[tile] = damage
			wall_layer.set_cell(tile, WALL_SOURCE, Vector2i(mask, damage * 3 + style))

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
				var mask := _wall_mask(maze, tile)
				if _has_corner(mask):
					fillet_layer.set_cell(tile, FILLET_SOURCE, Vector2i(mask, 0))
	return wall_damage


## Neighbor mask: N=1 E=2 S=4 W=8 set where that neighbor is a wall.
static func _wall_mask(maze: Dictionary, tile: Vector2i) -> int:
	var mask := 0
	for bit_dir: Array in [[1, Vector2i.UP], [2, Vector2i.RIGHT], [4, Vector2i.DOWN], [8, Vector2i.LEFT]]:
		if MazeGenerator.is_wall(maze, tile + bit_dir[1]):
			mask |= bit_dir[0]
	return mask


## True if two touching sides (N+E, E+S, S+W, W+N) are both walls.
static func _has_corner(mask: int) -> bool:
	return (mask & 3) == 3 or (mask & 6) == 6 or (mask & 12) == 12 or (mask & 9) == 9


static func make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()

	var walls := _make_atlas(preload("res://assets/sprites/walls.png"), Vector2i(WALL_MASKS, WALL_ROWS))
	tile_set.add_source(walls, WALL_SOURCE)
	tile_set.add_source(_make_atlas(preload("res://assets/sprites/floors.png"),
		Vector2i(FLOOR_TYPES, FLOOR_VARIANTS)), FLOOR_SOURCE)
	tile_set.add_source(_make_atlas(load("res://assets/sprites/fillets.png"), Vector2i(WALL_MASKS, 1)), FILLET_SOURCE)

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


static func _make_atlas(texture: Texture2D, grid: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for row in grid.y:
		for column in grid.x:
			source.create_tile(Vector2i(column, row))
	return source
