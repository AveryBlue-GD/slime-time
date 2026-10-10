extends Node2D

## One maze: the map starts black, the slime's goo trail reveals it, moving drains the slime
## meter, and touching the golden chalice wins. Plays a story level or a randomizer maze.
##
## Jumps leave no trail in the air, only a splat where they land. A jump costs JUMP_COST_FACTOR
## of gliding the distance flown; hitting a wall adds a penalty (SPLAT_PENALTY_MIN for a tiny hop
## up to SPLAT_PENALTY_MAX for a full-power leap), shakes the screen and stains the wall.
##
## Reveal works on a fine grid (FOG_CELL px). Two images cover the map:
## - trail_image: goo (in the skin's colors) where the slime has been
## - fog_image:   per cell, r = when it was last lit, g = -1 never revealed / 0 floor / 1 wall,
##   b = when it was first revealed (see fog.gdshader, which draws it as soft drifting mist). Revealed cells near the slime stay lit; once it moves away they fade
##   back toward darkness in steps (FADE_AFTER / FADE_ALPHA). Walls follow the same steps at
##   the same moments, just a constant WALL_FOG_ALPHA darker, so everything dims together.

const TILE := 16
const FOG_CELL := 2
## Wider than the corridor, so the trail paints the floor wall to wall.
const TRAIL_RADIUS := 9.0
## How far past the trail's edge walls get revealed.
const WALL_REVEAL_REACH := 4.0
## How much darker revealed walls are than the floor beside them (0-1 of the remaining light).
const WALL_FOG_ALPHA := 0.3
const CHALICE_REVEAL_DISTANCE := 24.0
const END_DELAY := 2.0
const WIN_FINAL_DELAY := 5.0
const JUMP_COST_FACTOR := 0.5
## Extra percent of slime lost when a jump hits a wall, scaled by how hard it was charged.
const SPLAT_PENALTY_MIN := 2.0
const SPLAT_PENALTY_MAX := 5.0
const LANDING_RADIUS := 11.0
const STAIN_RADIUS := 6.0

## Revealed cells within this distance of the slime are kept fully lit.
const LIGHT_RADIUS := 20.0
## Fade layers: a cell last lit less than FADE_AFTER[i] seconds ago has darkness FADE_ALPHA[i];
## older than the last step, it settles at the final FADE_ALPHA (a dim memory of the path).
const FADE_AFTER: Array[float] = [3.0, 7.0, 12.0, 18.0]
const FADE_ALPHA: Array[float] = [0.0, 0.3, 0.5, 0.65, 0.78]
const UNREVEALED := Color(0, -1, 0, 0)
const KIND_FLOOR := 0.0
const KIND_WALL := 1.0
## Light radius of a fully glowing slime (custom skin, after beating the game).
const GLOW_MAX_RADIUS := 64.0

## Tile atlases from tools/make_placeholder_art.py.
## walls.png: column = neighbor mask (N=1 E=2 S=4 W=8 set when that neighbor is wall),
##            row = damage * 3 + style. floors.png: column = floor type, row = variant.
const WALL_SOURCE := 0
const FLOOR_SOURCE := 1
const WALL_MASKS := 16
const WALL_ROWS := 12
const FLOOR_TYPES := 8
const FLOOR_VARIANTS := 4
const FLOOR_RUBBLE := 7
const BROKEN := 3
const RUBBLE_CHANCE := 0.7

const GOO_ALPHA := 120
const CLEAR := Color(0, 0, 0, 0)
const TITLE_SCENE := "res://scenes/title.tscn"
const VICTORY_SCENE := "res://scenes/victory.tscn"
## Screen shake on a splat: lasts SHAKE_TIME, up to SHAKE_MAX px for a full-power leap.
const SHAKE_TIME := 0.25
const SHAKE_MAX := 3.0

signal level_finished(won: bool)

## Story level to play (1-10). 0 = ask the Progress autoload (or 1 without it).
@export var level := 0
## Non-zero: play a randomizer maze from this seed instead of a story level.
@export var random_seed := 0

## Percent of slime used per tile glided; set per maze so a perfect run uses its target.
var slime_cost_per_tile := 1.0
var slime_remaining := 100.0
var finished := false
var maze: Dictionary
## Damage level (0-3) of each wall tile, by tile coordinate.
var wall_damage := {}
var fog_image: Image
var trail_image: Image
var revealed_walls := {}
var textures_dirty := false
var last_slime_pos: Vector2
## Seconds since the maze started; the fog's clock.
var elapsed := 0.0
## Slime spent on the most recent jump (for tests and tuning).
var last_jump_cost := 0.0
var skin_color: Color = Skins.get_preset(Skins.DEFAULT).color
var goo := Color(0, 0, 0)
var goo_dark := Color(0, 0, 0)
var glow_radius := 0.0
var shake_left := 0.0
var shake_strength := 0.0

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var trail_sprite: Sprite2D = $Trail
@onready var fog_sprite: Sprite2D = $Fog
@onready var slime: Slime = $Slime
@onready var chalice: Area2D = $Chalice
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var camera: Camera2D = $Slime/Camera2D
@onready var progress: Node = get_node_or_null("/root/Progress")


func _ready() -> void:
	if level == 0 and random_seed == 0:
		if progress and progress.mode == progress.MODE_RANDOM:
			random_seed = progress.random_seed
		else:
			level = progress.current_level if progress else 1
	var config: Dictionary
	if is_random():
		config = Levels.random_config(random_seed)
		maze = MazeGenerator.generate_noise(config.cells, config.seed)
		hud.set_level_text("RANDOM MAZE #%d" % ((progress.randoms_cleared if progress else 0) + 1))
	else:
		config = Levels.get_config(level)
		maze = MazeGenerator.generate(config.cells, config.seed, config.branching)
		hud.set_level_text("LEVEL %d/%d" % [level, Levels.COUNT])
	# The slime grabs the chalice when their shapes touch, a little short of its center.
	var grab_reach: float = chalice.get_node("CollisionShape2D").shape.radius + Slime.RADIUS
	var path_tiles: float = maze.goal_steps * MazeGenerator.CELL_SPAN - grab_reach / TILE
	slime_cost_per_tile = config.target * 100.0 / path_tiles

	if progress:
		skin_color = progress.skin_color()
		glow_radius = progress.glow_amount() * GLOW_MAX_RADIUS
	var shades := Skins.shades(skin_color)
	goo = Color(shades.mid, GOO_ALPHA / 255.0)
	goo_dark = Color(shades.dark, GOO_ALPHA / 255.0)
	slime.apply_skin(skin_color)
	hud.set_skin_color(skin_color)

	_build_tiles(config.seed, config.get("tile_level", level))
	_build_overlays()

	slime.position = MazeGenerator.cell_center(maze.start, TILE)
	last_slime_pos = slime.position
	chalice.position = MazeGenerator.cell_center(maze.goal, TILE)
	chalice.visible = false
	chalice.body_entered.connect(_on_chalice_body_entered)
	slime.jump_landed.connect(_on_jump_landed)

	camera.limit_right = maze.size.x * TILE
	camera.limit_bottom = maze.size.y * TILE
	camera.reset_smoothing()

	_paint_goo(slime.position, TRAIL_RADIUS)
	_flush_textures()


func is_random() -> bool:
	return random_seed != 0


func _physics_process(delta: float) -> void:
	elapsed += delta
	var pos := slime.position
	_relight(pos)
	if finished:
		return
	if slime.is_airborne():
		last_slime_pos = pos
	else:
		var moved := pos.distance_to(last_slime_pos)
		if moved > 0.0:
			last_slime_pos = pos
			slime_remaining = maxf(slime_remaining - moved * slime_cost_per_tile / TILE, 0.0)
			_paint_goo(pos, TRAIL_RADIUS)
	if not chalice.visible and pos.distance_to(chalice.position) <= CHALICE_REVEAL_DISTANCE + glow_radius * 0.5:
		chalice.visible = true
	hud.set_slime(slime_remaining)
	if slime_remaining <= 0.0 and not slime.is_airborne():
		_dry_up()


func _process(_delta: float) -> void:
	var fog_material := fog_sprite.material as ShaderMaterial
	fog_material.set_shader_parameter("now", elapsed)
	fog_material.set_shader_parameter("glow_pos", slime.position + slime.sprite.position)
	_shake_camera(_delta)
	_flush_textures()


func _shake_camera(delta: float) -> void:
	if shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_left = maxf(shake_left - delta, 0.0)
	var strength := ceilf(shake_strength * shake_left / SHAKE_TIME)
	camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength)).round()


func is_wall_tile(tile: Vector2i) -> bool:
	return MazeGenerator.is_wall(maze, tile)


## Fog opacity (0 = fully lit, 1 = covered) at a pixel position right now; matches fog.gdshader's
## per-cell value, without its cosmetic extras (soft edges, clearing fade-in, glow).
func fog_alpha_at(pos: Vector2) -> float:
	var cell := fog_image.get_pixelv(Vector2i((pos / FOG_CELL).floor()))
	if cell.g < 0.0:
		return 1.0
	var alpha := fade_alpha(elapsed - cell.r)
	if cell.g > 0.5:
		alpha += (1.0 - alpha) * WALL_FOG_ALPHA
	return alpha


## Extra slime lost when a jump planned to cover intended_distance px hits a wall.
static func splat_penalty(intended_distance: float) -> float:
	var power := inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance)
	return lerpf(SPLAT_PENALTY_MIN, SPLAT_PENALTY_MAX, clampf(power, 0.0, 1.0))


## Darkness of a revealed floor cell last lit `age` seconds ago.
static func fade_alpha(age: float) -> float:
	for i in FADE_AFTER.size():
		if age < FADE_AFTER[i]:
			return FADE_ALPHA[i]
	return FADE_ALPHA[-1]


## Picks a wall variant for every wall tile (edges from its neighbors, damage and style from
## the level's weights) and a floor type for every tile. Seeded, so a maze always looks the same.
func _build_tiles(tile_seed: int, tile_level: int) -> void:
	var tile_set := _make_tile_set()
	floor_layer.tile_set = tile_set
	wall_layer.tile_set = tile_set
	var rng := RandomNumberGenerator.new()
	rng.seed = tile_seed * 7919 + 17
	var damage_weights := Levels.damage_weights(tile_level)
	var style_weights := PackedFloat32Array(Levels.WALL_STYLE)
	var floor_weights := Levels.floor_weights(tile_level)

	for y in maze.size.y:
		for x in maze.size.x:
			var tile := Vector2i(x, y)
			if not is_wall_tile(tile):
				continue
			var mask := 0
			for bit_dir: Array in [[1, Vector2i.UP], [2, Vector2i.RIGHT], [4, Vector2i.DOWN], [8, Vector2i.LEFT]]:
				if is_wall_tile(tile + bit_dir[1]):
					mask |= bit_dir[0]
			var damage := rng.rand_weighted(damage_weights)
			var style := rng.rand_weighted(style_weights)
			wall_damage[tile] = damage
			wall_layer.set_cell(tile, WALL_SOURCE, Vector2i(mask, damage * 3 + style))

	# Floor goes under walls too, so broken-off chunks of wall show floor through them.
	for y in maze.size.y:
		for x in maze.size.x:
			var tile := Vector2i(x, y)
			var type := 0
			if not is_wall_tile(tile):
				type = rng.rand_weighted(floor_weights)
				if wall_damage.get(tile + Vector2i.UP, 0) == BROKEN and rng.randf() < RUBBLE_CHANCE:
					type = FLOOR_RUBBLE
			floor_layer.set_cell(tile, FLOOR_SOURCE, Vector2i(type, rng.randi_range(0, FLOOR_VARIANTS - 1)))


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()

	var walls := _make_atlas(preload("res://assets/sprites/walls.png"), Vector2i(WALL_MASKS, WALL_ROWS))
	tile_set.add_source(walls, WALL_SOURCE)
	tile_set.add_source(_make_atlas(preload("res://assets/sprites/floors.png"),
		Vector2i(FLOOR_TYPES, FLOOR_VARIANTS)), FLOOR_SOURCE)

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


func _make_atlas(texture: Texture2D, grid: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for row in grid.y:
		for column in grid.x:
			source.create_tile(Vector2i(column, row))
	return source


func _build_overlays() -> void:
	var cells: Vector2i = maze.size * TILE / FOG_CELL
	fog_image = Image.create_empty(cells.x, cells.y, false, Image.FORMAT_RGBF)
	fog_image.fill(UNREVEALED)
	trail_image = Image.create_empty(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	trail_image.fill(CLEAR)
	fog_sprite.texture = ImageTexture.create_from_image(fog_image)
	trail_sprite.texture = ImageTexture.create_from_image(trail_image)
	fog_sprite.scale = Vector2(FOG_CELL, FOG_CELL)
	trail_sprite.scale = Vector2(FOG_CELL, FOG_CELL)

	var fog_material := ShaderMaterial.new()
	fog_material.shader = preload("res://assets/shaders/fog.gdshader")
	fog_material.set_shader_parameter("fade_after", PackedFloat32Array(FADE_AFTER))
	fog_material.set_shader_parameter("fade_alpha", PackedFloat32Array(FADE_ALPHA))
	fog_material.set_shader_parameter("wall_shade", WALL_FOG_ALPHA)
	fog_material.set_shader_parameter("map_size", Vector2(maze.size * TILE))
	fog_material.set_shader_parameter("glow_radius", glow_radius)
	fog_material.set_shader_parameter("glow_color", skin_color)
	fog_sprite.material = fog_material


## Paints goo on the floor in a disc around pos, then reveals walls next to it.
func _paint_goo(pos: Vector2, radius: float) -> void:
	_paint_cells(pos, radius, false)
	_reveal_walls_near(pos, radius)


## Splat stain on the wall the slime just hit; lit like the floor so it stands out.
func _stain_wall(pos: Vector2, wall_normal: Vector2) -> void:
	_paint_cells(pos - wall_normal * (Slime.RADIUS + 1.0), STAIN_RADIUS, true)


## Sets goo + lights fog cells within radius of pos, on floor cells or wall cells only.
func _paint_cells(pos: Vector2, radius: float, on_walls: bool) -> void:
	var first := Vector2i(((pos - Vector2(radius, radius)) / FOG_CELL).floor())
	var last := Vector2i(((pos + Vector2(radius, radius)) / FOG_CELL).floor())
	var bounds := Rect2i(Vector2i.ZERO, trail_image.get_size())
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			var center := (Vector2(cell) + Vector2(0.5, 0.5)) * FOG_CELL
			if not bounds.has_point(cell) or center.distance_to(pos) > radius:
				continue
			var tile := Vector2i((center / TILE).floor())
			if is_wall_tile(tile) != on_walls:
				continue
			if on_walls:
				_reveal_wall(tile)
			elif trail_image.get_pixelv(cell).a > 0.0:
				continue
			trail_image.set_pixelv(cell, goo_dark if posmod(hash(cell), 5) == 0 else goo)
			fog_image.set_pixelv(cell, Color(elapsed, KIND_FLOOR, elapsed))
			textures_dirty = true


## Keeps already-revealed cells around the slime fully lit (restarts their fade).
func _relight(pos: Vector2) -> void:
	var r := Vector2(LIGHT_RADIUS, LIGHT_RADIUS)
	var first := Vector2i(((pos - r) / FOG_CELL).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((pos + r) / FOG_CELL).floor()).min(fog_image.get_size() - Vector2i.ONE)
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			if ((Vector2(cell) + Vector2(0.5, 0.5)) * FOG_CELL).distance_to(pos) > LIGHT_RADIUS:
				continue
			var value := fog_image.get_pixelv(cell)
			if value.g >= 0.0 and value.r < elapsed:
				value.r = elapsed
				fog_image.set_pixelv(cell, value)
				textures_dirty = true


func _reveal_walls_near(pos: Vector2, radius: float) -> void:
	var reach := radius + WALL_REVEAL_REACH
	var first := Vector2i(((pos - Vector2(reach, reach)) / TILE).floor())
	var last := Vector2i(((pos + Vector2(reach, reach)) / TILE).floor())
	for ty in range(first.y, last.y + 1):
		for tx in range(first.x, last.x + 1):
			var tile := Vector2i(tx, ty)
			if not is_wall_tile(tile) or tx < 0 or ty < 0 or tx >= maze.size.x or ty >= maze.size.y:
				continue
			var rect := Rect2(Vector2(tile * TILE), Vector2(TILE, TILE))
			if pos.clamp(rect.position, rect.end).distance_to(pos) <= reach:
				_reveal_wall(tile)


## Marks a whole wall tile revealed (lit now) the first time it's seen.
func _reveal_wall(tile: Vector2i) -> void:
	if revealed_walls.has(tile):
		return
	revealed_walls[tile] = true
	fog_image.fill_rect(Rect2i(tile * TILE / FOG_CELL, Vector2i.ONE * (TILE / FOG_CELL)),
		Color(elapsed, KIND_WALL, elapsed))
	textures_dirty = true


func _flush_textures() -> void:
	if not textures_dirty:
		return
	(fog_sprite.texture as ImageTexture).update(fog_image)
	(trail_sprite.texture as ImageTexture).update(trail_image)
	textures_dirty = false


func _on_jump_landed(intended_distance: float, hit_wall: bool, wall_normal: Vector2) -> void:
	last_jump_cost = slime.last_jump_traveled / TILE * slime_cost_per_tile * JUMP_COST_FACTOR
	_paint_goo(slime.position, LANDING_RADIUS)
	if hit_wall:
		last_jump_cost += splat_penalty(intended_distance)
		_stain_wall(slime.position, wall_normal)
		shake_left = SHAKE_TIME
		shake_strength = lerpf(1.0, SHAKE_MAX, inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance))
	last_slime_pos = slime.position
	slime_remaining = maxf(slime_remaining - last_jump_cost, 0.0)
	hud.set_slime(slime_remaining)


func _on_chalice_body_entered(body: Node2D) -> void:
	if body != slime or finished:
		return
	chalice.visible = true
	slime.play_celebrate()
	_sfx("chalice")
	if is_random():
		_finish(true, "CHALICE CONSUMED!\nA NEW MAZE AWAITS...", END_DELAY)
		return
	var text := "CHALICE CONSUMED!\nLEVEL %d CLEARED" % level
	var delay := END_DELAY
	if level >= Levels.COUNT:
		text = "YOU ESCAPED ALL %d MAZES!" % Levels.COUNT
		delay = WIN_FINAL_DELAY
	if progress and progress.levels_cleared < level:
		var unlocked := Skins.unlocked_by_level(level)
		if level >= Levels.COUNT:
			text += "\nUNLOCKED: COLOR WHEEL + GLOW!"
		elif unlocked != "":
			text += "\nNEW SKIN: " + unlocked
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _sfx("unlock"))
	_finish(true, text, delay)


func _dry_up() -> void:
	slime.play_dry_up()
	_finish(false, "DRIED UP", END_DELAY)


## Freezes play and shows the result. When this is the running scene (not a test), records the
## result, then loads what comes next: the next level, a fresh random maze, a retry, or the title.
func _finish(won: bool, text: String, delay: float) -> void:
	finished = true
	slime.frozen = true
	hud.show_message(text)
	level_finished.emit(won)
	if not _is_running_scene():
		return
	var to_victory := false
	if won and progress:
		if is_random():
			progress.randoms_cleared += 1
			progress.new_random_maze()
		else:
			progress.complete_level(level)
			to_victory = level >= Levels.COUNT
	await get_tree().create_timer(delay).timeout
	if not _is_running_scene():
		return
	if to_victory:
		get_tree().change_scene_to_file(VICTORY_SCENE)
	else:
		get_tree().reload_current_scene()


func _is_running_scene() -> bool:
	return is_inside_tree() and get_tree().current_scene == self


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running_scene():
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _sfx(sound_name: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name)
