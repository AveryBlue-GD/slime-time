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
## - fog_image:   per cell, when it was last lit, when it was first revealed, and floor vs wall,
##   packed into a plain RGBA8 image (see _fog_color) so every device can use it -- many phone
##   GPUs can't load float textures. fog.gdshader decodes it and draws soft drifting mist. Revealed cells near the slime stay lit; once it moves away they fade
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
## Hard mode: a cell older than the last step is covered by fog again.
const FADE_AFTER: Array[float] = [1.5, 3.5, 6.0, 9.0]
const FADE_ALPHA: Array[float] = [0.0, 0.3, 0.5, 0.65, 0.78]
const UNREVEALED := Color(0, 0, 0, 0)
## Fog times are stored as 16-bit counts of 1/FOG_TICKS seconds (up to ~68 minutes).
const FOG_TICKS := 16.0
## Light radius of a fully glowing slime (custom skin, after beating the game).
const GLOW_MAX_RADIUS := 64.0

const GOO_ALPHA := 120
## Rainbow skin: the trail's hue advances this many full rainbows per second of play.
const RAINBOW_TRAIL_SPEED := 0.08
const CLEAR := Color(0, 0, 0, 0)
const TITLE_SCENE := "res://scenes/title.tscn"
## Seconds the "first run: playing as ..." notice stays up.
const FORCED_SKIN_NOTICE := 2.5
const VICTORY_SCENE := "res://scenes/victory.tscn"
const UPGRADES_SCENE := "res://scenes/upgrades.tscn"
## After a win, the replay / next buttons appear after this long (so a held key can't press one).
const CHOICE_DELAY := 0.6
## The chalice fanfare plays about a third quieter than other sounds (-3.5 dB = 67% amplitude).
const CHALICE_VOLUME_DB := -3.5
## Screen shake on a splat: lasts SHAKE_TIME, up to SHAKE_MAX px for a full-power leap.
const SHAKE_TIME := 0.25
const SHAKE_MAX := 3.0
## The slime's own soft light on the floor and walls around it (diameter px, strength 0-1).
const SLIME_LIGHT_SIZE := 112
const SLIME_LIGHT_STRENGTH := 0.22
## Camera look-ahead: leads the slime by its velocity * LOOK_AHEAD_TIME, up to LOOK_AHEAD_MAX px.
const LOOK_AHEAD_TIME := 0.3
const LOOK_AHEAD_MAX := 24.0
const LOOK_AHEAD_SPEED := 3.0
const CHALICE_GOLD := Color8(255, 205, 117)
## Ambience (tools/make_ambience.py). Every theme loops a bed (assets/sounds/ambient_<theme>.wav):
## very faint (AMBIENT_FAINT_DB) except the Sunken Shrine's waves and the Sandstone Sanctum's
## sandstorm (AMBIENT_BED_DB). On top, distant one-off sounds (ambient_<theme>_<n>.wav) play at
## random every AMBIENT_EVENT_GAP seconds, at a random level within AMBIENT_EVENT_DB.
const AMBIENT_FAINT_DB := -25.0
const AMBIENT_BED_DB := {"sunken": -17.0, "sandstone": -17.0}
const AMBIENT_FADE := 2.0
const AMBIENT_EVENT_GAP := Vector2(10.0, 24.0)
const AMBIENT_EVENT_DB := Vector2(-25.0, -17.0)
## Extra quietness for some themes' events (the catacombs' scream is meant to be barely there).
const AMBIENT_EVENT_TRIM := {"catacombs": -7.0}

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
var rainbow := false
## Hard mode: fully dimmed areas turn back into unexplored fog.
var hard_mode := false
## Seconds spent on this maze (stops on pause and when the maze ends).
var run_time := 0.0
## True once this maze has been won (R then replays it rather than moving on).
var won := false
var shake_left := 0.0
var shake_strength := 0.0
var slime_light: Sprite2D
## The hat the slime is wearing, if any (see Hat).
var hat: Hat
## Coins still waiting in this story level (see Coin; never in randomizer mazes).
var coins: Array[Coin] = []
## How many coins this level hides in total.
var coins_here := 0
## Gold skin: jumps and landings throw off gold sparks.
var gold := false
## Asks RESTART / UPGRADES / CANCEL when R is pressed mid-run.
var restart_prompt: RestartPrompt
## Brightness upgrade: extra reach (px) of the slime's light (see Upgrades.light_reach).
var light_reach := 0.0
## Dev wall power (see Upgrades): damage left on walls, by tile (100 = intact).
var wall_power := 0
var wall_health := {}
## Art theme id (see Themes): one per story level, random per randomizer maze.
var theme := Themes.DUNGEON
var _look_ahead := Vector2.ZERO
## Plays the theme's continuous ambient loop (follows the sound on/off setting).
var ambient: AudioStreamPlayer
## The theme's one-off ambient sounds, and the player and countdown for the next one.
var ambient_events: Array[AudioStream] = []
var ambient_event_player: AudioStreamPlayer
var _next_ambient_event := 0.0
var _last_ambient_event := -1

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var fillet_layer: TileMapLayer = $Fillets
@onready var trail_sprite: Sprite2D = $Trail
@onready var fog_sprite: Sprite2D = $Fog
@onready var slime: Slime = $Slime
@onready var chalice: Area2D = $Chalice
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var camera: Camera2D = $Slime/Camera2D
@onready var progress: Node = get_node_or_null("/root/Progress")


func _ready() -> void:
	if level == 0 and random_seed == 0:
		if progress and progress.mode == progress.MODE_RANDOM:
			random_seed = progress.random_seed
		else:
			level = progress.current_level if progress else 1
	hard_mode = progress.hard_mode if progress else false
	var mode_tag := "  HARD" if hard_mode else ""
	var config: Dictionary
	if is_random():
		config = Levels.random_config(random_seed, hard_mode)
		maze = MazeGenerator.generate_noise(config.cells, config.seed)
		hud.set_level_text("RANDOM MAZE #%d%s" % [(progress.randoms_cleared if progress else 0) + 1, mode_tag])
	else:
		config = Levels.get_config(level, hard_mode)
		maze = MazeGenerator.generate(config.cells, config.seed, config.branching)
		hud.set_level_text("LEVEL %d/%d%s" % [level, Levels.COUNT, mode_tag])
	# The slime grabs the chalice when their shapes touch, a little short of its center.
	var grab_reach: float = chalice.get_node("CollisionShape2D").shape.radius + Slime.RADIUS
	var path_tiles: float = maze.goal_steps * MazeGenerator.CELL_SPAN - grab_reach / TILE
	slime_cost_per_tile = config.target * 100.0 / path_tiles
	_apply_upgrades()

	# A new story level's very first attempt equips the skin just earned (see Progress).
	var equipped := ""
	if progress:
		if not is_random() and not hard_mode:
			equipped = progress.equip_first_run_skin(level)
		skin_color = progress.skin_color()
		glow_radius = progress.glow_amount() * GLOW_MAX_RADIUS
		rainbow = progress.is_rainbow()
	var shades := Skins.shades(skin_color)
	goo = Color(shades.mid, GOO_ALPHA / 255.0)
	goo_dark = Color(shades.dark, GOO_ALPHA / 255.0)
	slime.apply_skin(skin_color, rainbow)
	if progress and progress.jelly:
		slime.set_translucency(1.0)
	hud.set_skin_color(skin_color, rainbow)

	if equipped != "":
		hud.flash_message("NEW SKIN EQUIPPED: %s" % Skins.display_name(equipped), FORCED_SKIN_NOTICE)
	gold = progress != null and progress.is_gold()

	theme = Themes.for_seed(random_seed) if is_random() else Themes.for_level(level)
	wall_damage = MazeTiles.fill(floor_layer, wall_layer, maze, config.seed, config.get("tile_level", level), fillet_layer, theme)
	hud.show_area_name(Themes.display_name(theme))
	_start_ambience()
	_build_overlays()
	_place_coins(config.seed)

	slime.position = MazeGenerator.cell_center(maze.start, TILE)
	last_slime_pos = slime.position
	chalice.position = MazeGenerator.cell_center(maze.goal, TILE)
	chalice.visible = false
	chalice.body_entered.connect(_on_chalice_body_entered)
	slime.jump_landed.connect(_on_jump_landed)
	slime.bounced.connect(_on_bounced)
	if gold:
		slime.launched.connect(func(_v: Vector2, _t: float) -> void: _gold_flourish(slime.position, 12))
	restart_prompt = RestartPrompt.new()
	restart_prompt.game = self
	add_child(restart_prompt)
	_put_on_hat()

	camera.limit_right = maze.size.x * TILE
	camera.limit_bottom = maze.size.y * TILE
	camera.reset_smoothing()

	_paint_goo(slime.position, TRAIL_RADIUS)
	_flush_textures()
	_ease_in.call_deferred()


## Restarts and next levels ease in from under a sheet of goo (only when actually playing).
func _ease_in() -> void:
	var transition := get_node_or_null("/root/Transition")
	if transition and _is_running_scene():
		transition.reveal()


func _exit_tree() -> void:
	if progress:
		progress.skin_override = ""


func is_random() -> bool:
	return random_seed != 0


func _physics_process(delta: float) -> void:
	elapsed += delta
	var pos := slime.position
	_relight(pos)
	if finished:
		return
	run_time += delta
	hud.set_time(run_time)
	if slime.is_airborne():
		last_slime_pos = pos
	else:
		var moved := pos.distance_to(last_slime_pos)
		if moved > 0.0:
			last_slime_pos = pos
			if not slime.knocked_back:  # a splat's knockback slide is already paid for
				slime_remaining = maxf(slime_remaining - moved * slime_cost_per_tile / TILE, 0.0)
			_paint_goo(pos, TRAIL_RADIUS)
			if light_reach > 0.0:
				_reveal_light(pos)
	_pick_up_coins(pos)
	if not chalice.visible and pos.distance_to(chalice.position) <= CHALICE_REVEAL_DISTANCE + glow_radius * 0.5:
		chalice.visible = true
	hud.set_slime(slime_remaining)
	if slime_remaining <= 0.0 and not slime.is_airborne():
		_dry_up()


func _process(_delta: float) -> void:
	var fog_material := fog_sprite.material as ShaderMaterial
	fog_material.set_shader_parameter("now", elapsed)
	fog_material.set_shader_parameter("glow_pos", slime.position + slime.sprite.position)
	slime_light.position = (slime.position + slime.sprite.position).round()
	if rainbow:
		slime_light.modulate = Color(hud.goo_color, SLIME_LIGHT_STRENGTH)
	_lead_camera(_delta)
	_update_ambience(_delta)
	_shake_camera(_delta)
	_flush_textures()


## Loads the theme's ambience: its continuous bed (looping, fading in) if it has one, and its
## one-off sounds.
func _start_ambience() -> void:
	var bed_path := "res://assets/sounds/ambient_%s.wav" % theme
	if ResourceLoader.exists(bed_path):
		var stream := load(bed_path) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		ambient = AudioStreamPlayer.new()
		ambient.stream = stream
		ambient.volume_db = -60.0
		add_child(ambient)
		create_tween().tween_property(ambient, "volume_db", AMBIENT_BED_DB.get(theme, AMBIENT_FAINT_DB), AMBIENT_FADE)
	var k := 0
	while ResourceLoader.exists("res://assets/sounds/ambient_%s_%d.wav" % [theme, k]):
		ambient_events.append(load("res://assets/sounds/ambient_%s_%d.wav" % [theme, k]))
		k += 1
	ambient_event_player = AudioStreamPlayer.new()
	add_child(ambient_event_player)
	_next_ambient_event = randf_range(3.0, AMBIENT_EVENT_GAP.x)
	_update_ambience(0.0)


## Keeps the bed in step with the sound on/off setting and plays a one-off sound now and then.
func _update_ambience(delta: float) -> void:
	var sound_on: bool = progress == null or progress.sound_on
	if ambient:
		if sound_on and not ambient.playing:
			ambient.play()
		elif not sound_on and ambient.playing:
			ambient.stop()
	if ambient_events.is_empty() or not sound_on:
		return
	_next_ambient_event -= delta
	if _next_ambient_event > 0.0:
		return
	_next_ambient_event = randf_range(AMBIENT_EVENT_GAP.x, AMBIENT_EVENT_GAP.y)
	# Any of the theme's sounds except the one just played, so it never repeats back to back.
	var pick := randi() % ambient_events.size()
	if ambient_events.size() > 1 and pick == _last_ambient_event:
		pick = (pick + 1 + randi() % (ambient_events.size() - 1)) % ambient_events.size()
	_last_ambient_event = pick
	ambient_event_player.stream = ambient_events[pick]
	ambient_event_player.volume_db = randf_range(AMBIENT_EVENT_DB.x, AMBIENT_EVENT_DB.y) + AMBIENT_EVENT_TRIM.get(theme, 0.0)
	ambient_event_player.pitch_scale = randf_range(0.9, 1.08)
	ambient_event_player.play()


## Eases the camera ahead of the slime in the direction it's gliding.
func _lead_camera(delta: float) -> void:
	var target := (slime.velocity * LOOK_AHEAD_TIME).limit_length(LOOK_AHEAD_MAX)
	if finished:
		target = Vector2.ZERO
	_look_ahead = _look_ahead.lerp(target, 1.0 - exp(-LOOK_AHEAD_SPEED * delta))
	camera.position = _look_ahead.round()


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
	var cell := _fog_decode(fog_image.get_pixelv(Vector2i((pos / FOG_CELL).floor())))
	if not cell.revealed:
		return 1.0
	var age: float = elapsed - cell.lit
	if hard_mode and age >= FADE_AFTER[-1]:
		return 1.0
	var alpha := fade_alpha(age)
	if cell.wall:
		alpha += (1.0 - alpha) * WALL_FOG_ALPHA
	return alpha


## Packs one fog cell into RGBA8: r,g = last-lit time; b,a = (first-revealed time + 1) * 2 + is_wall,
## both in 1/FOG_TICKS second steps. b,a = 0 means never revealed. fog.gdshader decodes the same way.
static func _fog_color(lit: float, revealed: float, wall: bool) -> Color:
	var lit_ticks := clampi(int(lit * FOG_TICKS), 0, 65535)
	var packed := (clampi(int(revealed * FOG_TICKS), 0, 32766) + 1) * 2 + (1 if wall else 0)
	return Color8(lit_ticks >> 8, lit_ticks & 255, packed >> 8, packed & 255)


static func _fog_decode(color: Color) -> Dictionary:
	var packed := color.b8 * 256 + color.a8
	return {
		revealed = packed > 0,
		wall = packed % 2 == 1,
		lit = (color.r8 * 256 + color.g8) / FOG_TICKS,
		first_revealed = ((packed >> 1) - 1) / FOG_TICKS,
	}


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


func _build_overlays() -> void:
	var cells: Vector2i = maze.size * TILE / FOG_CELL
	fog_image = Image.create_empty(cells.x, cells.y, false, Image.FORMAT_RGBA8)
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
	fog_material.set_shader_parameter("hard_mode", hard_mode)
	var fog_colors := Themes.fog_colors(theme)
	if not fog_colors.is_empty():
		fog_material.set_shader_parameter("fog_deep", fog_colors[0])
		fog_material.set_shader_parameter("fog_mist", fog_colors[1])
	fog_sprite.material = fog_material

	slime_light = Fx.make_light(SLIME_LIGHT_SIZE + int(light_reach * 2.0), Color(skin_color, SLIME_LIGHT_STRENGTH))
	slime_light.z_index = 5
	add_child(slime_light)


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
			trail_image.set_pixelv(cell, _goo_color(posmod(hash(cell), 5) == 0))
			fog_image.set_pixelv(cell, _fog_color(elapsed, elapsed, false))
			textures_dirty = true


## Trail color for a newly painted cell: the skin's goo, or for the rainbow skin a hue that
## shifts as you go, so the trail lays down rainbow bands along your path.
func _goo_color(dark: bool) -> Color:
	if not rainbow:
		return goo_dark if dark else goo
	var hue := fposmod(elapsed * RAINBOW_TRAIL_SPEED, 1.0) * 0.83
	return Color.from_hsv(hue, 0.85, 0.5 if dark else 0.9, GOO_ALPHA / 255.0)


## Keeps already-revealed cells around the slime fully lit (restarts their fade). The
## Brightness upgrade widens it.
func _relight(pos: Vector2) -> void:
	var radius := LIGHT_RADIUS + light_reach
	var r := Vector2(radius, radius)
	var first := Vector2i(((pos - r) / FOG_CELL).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((pos + r) / FOG_CELL).floor()).min(fog_image.get_size() - Vector2i.ONE)
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			if ((Vector2(cell) + Vector2(0.5, 0.5)) * FOG_CELL).distance_to(pos) > radius:
				continue
			var value := _fog_decode(fog_image.get_pixelv(cell))
			if value.revealed and int(value.lit * FOG_TICKS) < int(elapsed * FOG_TICKS):
				fog_image.set_pixelv(cell, _fog_color(elapsed, value.first_revealed, value.wall))
				textures_dirty = true


## Brightness upgrade: the slime's own light reveals unexplored floor (and the walls beside it)
## a little beyond its goo trail, without laying goo there.
func _reveal_light(pos: Vector2) -> void:
	var radius := TRAIL_RADIUS + light_reach
	var first := Vector2i(((pos - Vector2(radius, radius)) / FOG_CELL).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((pos + Vector2(radius, radius)) / FOG_CELL).floor()).min(fog_image.get_size() - Vector2i.ONE)
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell := Vector2i(cx, cy)
			var center := (Vector2(cell) + Vector2(0.5, 0.5)) * FOG_CELL
			if center.distance_to(pos) > radius or is_wall_tile(Vector2i((center / TILE).floor())):
				continue
			if not _fog_decode(fog_image.get_pixelv(cell)).revealed:
				fog_image.set_pixelv(cell, _fog_color(elapsed, elapsed, false))
				textures_dirty = true
	_reveal_walls_near(pos, radius)


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
		_fog_color(elapsed, elapsed, true))
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
	if gold:
		_gold_flourish(slime.position, 22)
	if hit_wall:
		last_jump_cost += splat_penalty(intended_distance)
		_stain_wall(slime.position, wall_normal)
		shake_left = SHAKE_TIME
		shake_strength = lerpf(1.0, SHAKE_MAX, inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance))
		Fx.burst(self, slime.position - wall_normal * Slime.RADIUS, skin_color, 18, 70.0, wall_normal, 70.0, rainbow)
		_damage_wall(slime.position, wall_normal,
			inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance))
	else:
		Fx.burst(self, slime.position, skin_color, 10, 35.0, Vector2.UP, 180.0, rainbow)
	last_slime_pos = slime.position
	slime_remaining = maxf(slime_remaining - last_jump_cost, 0.0)
	hud.set_slime(slime_remaining)


## Applies the bought upgrades (see Upgrades): more slime to spend, faster gliding, a wider
## light, and (dev only) wall power.
func _apply_upgrades() -> void:
	if progress == null or hard_mode:  # hard mode is played without upgrades
		return
	slime_cost_per_tile /= Upgrades.slime_factor(progress.upgrade_level("slime"))
	var speed := Upgrades.speed_factor(progress.upgrade_level("speed"))
	slime.max_speed *= speed
	slime.acceleration *= speed
	light_reach = Upgrades.light_reach(progress.upgrade_level("brightness"))
	wall_power = progress.upgrade_level("power")


# ---------------------------------------------------------------- coins

## The cells holding this level's coins: Levels.COINS[level] of its dead ends (never the start or
## the chalice's cell), picked with the level's seed so they're always in the same places.
func coin_cells(maze_seed: int) -> Array[Vector2i]:
	var dead_ends: Array[Vector2i] = []
	for y in maze.cells.y:
		for x in maze.cells.x:
			var cell := Vector2i(x, y)
			if cell != maze.start and cell != maze.goal and MazeGenerator.open_neighbors(maze, cell).size() == 1:
				dead_ends.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed * 13 + 5
	for i in range(dead_ends.size() - 1, 0, -1):  # a seeded shuffle
		var j := rng.randi_range(0, i)
		var swap := dead_ends[i]
		dead_ends[i] = dead_ends[j]
		dead_ends[j] = swap
	return dead_ends.slice(0, Levels.COINS[level - 1])


## Puts out the coins of a story level that haven't been collected yet.
func _place_coins(maze_seed: int) -> void:
	if is_random() or hard_mode or progress == null:  # coins live in the normal story mazes
		hud.set_coins(progress.coins() if progress else 0, 0, 0)
		return
	var theme_index := Themes.BY_LEVEL.find(theme)
	var cells := coin_cells(maze_seed)
	coins_here = cells.size()
	for cell in cells:
		if progress.has_coin(level, cell):
			continue
		var coin := Coin.new()
		coin.z_index = 6  # under the fog: found by exploring
		coin.position = MazeGenerator.cell_center(cell, TILE)
		add_child(coin)
		coin.setup(theme_index, cell)
		coins.append(coin)
	hud.set_coins(progress.coins(), progress.coins_found_in(level), coins_here)


func _pick_up_coins(pos: Vector2) -> void:
	for coin in coins.duplicate():
		if pos.distance_to(coin.position) > Coin.REACH:
			continue
		coins.erase(coin)
		progress.collect_coin(level, coin.cell)
		_sfx("coin", -4.0)
		if progress.jelly:
			coin.dissolve_into(slime, Skins.shades(skin_color).light)  # seen sinking into the body
		else:
			Fx.burst(self, coin.position, Color8(255, 214, 110), 14, 45.0)
			coin.queue_free()
		hud.set_coins(progress.coins(), progress.coins_found_in(level), coins_here, true)
		if progress.coins_earned() == Upgrades.full_tree_cost():  # the very last coin
			hud.flash_message("EVERY COIN FOUND!\nNEW SKIN: " + Skins.GOLD_NAME, 3.0)
			_sfx("unlock")


# ---------------------------------------------------------------- dev: wall power

## Wall power (dev only): a splat chips away at the wall it hits, harder the stronger the leap.
## Walls crack through the art's damage stages as they weaken and crumble away at zero. The
## maze's outer edge can't be broken.
func _damage_wall(pos: Vector2, wall_normal: Vector2, charge: float) -> void:
	if wall_power <= 0:
		return
	var tile := Vector2i(((pos - wall_normal * (Slime.RADIUS + 2.0)) / TILE).floor())
	if not is_wall_tile(tile) or _is_edge(tile):
		return
	var health: float = wall_health.get(tile, 100.0 - 25.0 * wall_damage.get(tile, 0))
	health -= Upgrades.wall_damage(wall_power, charge)
	if health <= 0.0:
		_break_wall(tile)
		return
	wall_health[tile] = health
	var stage := clampi(3 - int(health / 25.0), 0, 3)
	if stage > wall_damage.get(tile, 0):
		wall_damage[tile] = stage
		var row := wall_layer.get_cell_atlas_coords(tile).y
		wall_layer.set_cell(tile, MazeTiles.WALL_SOURCE,
			Vector2i(wall_layer.get_cell_atlas_coords(tile).x, (row / 12) * 12 + stage * 3 + row % 3))


func _is_edge(tile: Vector2i) -> bool:
	return tile.x <= 0 or tile.y <= 0 or tile.x >= maze.size.x - 1 or tile.y >= maze.size.y - 1


## Knocks a wall out: it becomes rubble-strewn floor, and the walls and corner fillets around it
## re-fit their edges to the new opening.
func _break_wall(tile: Vector2i) -> void:
	maze.walls[tile.y * maze.size.x + tile.x] = 0
	wall_layer.erase_cell(tile)
	wall_damage.erase(tile)
	wall_health.erase(tile)
	revealed_walls.erase(tile)
	floor_layer.set_cell(tile, MazeTiles.FLOOR_SOURCE, Vector2i(MazeTiles.FLOOR_RUBBLE, 0))
	fog_image.fill_rect(Rect2i(tile * TILE / FOG_CELL, Vector2i.ONE * (TILE / FOG_CELL)), _fog_color(elapsed, elapsed, false))
	textures_dirty = true
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var near := tile + offset
		if near.x < 0 or near.y < 0 or near.x >= maze.size.x or near.y >= maze.size.y:
			continue
		if is_wall_tile(near):
			var row := wall_layer.get_cell_atlas_coords(near).y
			wall_layer.set_cell(near, MazeTiles.WALL_SOURCE, Vector2i(MazeTiles.wall_mask(maze, near), row))
		else:
			var mask := MazeTiles.wall_mask(maze, near)
			if MazeTiles.has_corner(mask):
				fillet_layer.set_cell(near, MazeTiles.FILLET_SOURCE, Vector2i(mask, 0))
			else:
				fillet_layer.erase_cell(near)
	var center := (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	Fx.burst(self, center, Color8(148, 140, 150), 24, 60.0)
	shake_left = SHAKE_TIME
	shake_strength = SHAKE_MAX
	_sfx("crumble")


## Gold skin: a gold spark burst (bigger for landings).
func _gold_flourish(at: Vector2, sparks: int) -> void:
	Fx.burst(self, at, Color8(255, 214, 90), sparks, 55.0)


## Puts the selected hat on the slime: it pops off on every leap and comes back down on its head.
func _put_on_hat() -> void:
	if progress == null or progress.selected_hat == Hats.NONE:
		return
	hat = Hat.new()
	hat.z_index = slime.z_index + 1
	add_child(hat)
	hat.setup(progress.selected_hat, slime.sprite, slime)
	hat.is_wall = func(at: Vector2) -> bool: return is_wall_tile(Vector2i((at / TILE).floor()))
	slime.launched.connect(hat.pop)


## A knockback ricochet: a smaller splat (stain, goo spray, a shake that scales with the hit).
func _on_bounced(wall_normal: Vector2, impact: float) -> void:
	var power := clampf(impact / 200.0, 0.0, 1.0)
	_stain_wall(slime.position, wall_normal)
	Fx.burst(self, slime.position - wall_normal * Slime.RADIUS, skin_color, int(lerpf(4, 12, power)), lerpf(25.0, 60.0, power), wall_normal, 70.0, rainbow)
	if power > 0.3:
		shake_left = SHAKE_TIME * 0.6
		shake_strength = lerpf(1.0, SHAKE_MAX - 1.0, power)


func _on_chalice_body_entered(body: Node2D) -> void:
	if body != slime or finished:
		return
	chalice.visible = true
	slime.play_celebrate()
	if hat:
		hat.pop(Vector2.ZERO, 0.45)  # tossed up in celebration
	Fx.burst(self, chalice.position, CHALICE_GOLD, 28, 60.0)
	_sfx("chalice", CHALICE_VOLUME_DB)
	if is_random():
		var random_text := "CHALICE CONSUMED!\nTIME " + UIKit.format_time(run_time)
		_finish(true, random_text, END_DELAY)
		return
	var text := "CHALICE CONSUMED!\nLEVEL %d CLEARED" % level
	# Records: a first clear just sets the record; only beating an existing one celebrates.
	var best: float = progress.best_time(level) if progress else -1.0
	text += "\nTIME " + UIKit.format_time(run_time)
	if best >= 0.0 and run_time < best:
		hud.show_record(run_time)
		get_tree().create_timer(0.4).timeout.connect(func() -> void: _sfx("unlock"))
	elif best >= 0.0:
		text += "   BEST " + UIKit.format_time(best)
	var delay := END_DELAY
	if level >= Levels.COUNT:
		text = ("YOU ESCAPED ALL %d MAZES!\n" % Levels.COUNT) + text.get_slice("\n", 2)
		delay = WIN_FINAL_DELAY
	if progress and hard_mode and not level in progress.hard_cleared and progress.hard_cleared.size() == Levels.COUNT - 1:
		text += "\nEVERY LEVEL BEATEN ON HARD!\nNEW SKIN: " + Skins.RAINBOW_NAME
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _sfx("unlock"))
	elif progress and progress.levels_cleared < level:
		var unlocked := Skins.unlocked_by_level(level)
		if level >= Levels.COUNT:
			text += "\nUNLOCKED: ANY SKIN YOU WANT + GLOW!"
		elif unlocked != "":
			text += "\nNEW SKIN: " + unlocked
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _sfx("unlock"))
	_finish(true, text, delay)


func _dry_up() -> void:
	slime.play_dry_up()
	_finish(false, "DRIED UP\nTHE MAZE WILL SHUFFLE" if is_random() else "DRIED UP", END_DELAY)


## Freezes play and shows the result. When this is the running scene (not a test), records the
## result. After a dry-up it retries automatically (a story level again, or a freshly shuffled
## random maze); after a win it offers REPLAY or NEXT (see _offer_next_steps).
func _finish(did_win: bool, text: String, delay: float) -> void:
	finished = true
	won = did_win
	slime.frozen = true
	touch_controls.hide_controls()
	hud.show_message(text)
	level_finished.emit(did_win)
	if not _is_running_scene():
		return
	if not did_win:
		if progress and is_random():
			progress.new_random_maze()
		# The delay pauses with the game (false = not while paused), and the buttons are skipped
		# if the player has left for the menu meanwhile.
		await get_tree().create_timer(CHOICE_DELAY, false).timeout
		if _is_running_scene() and not _leaving():
			_offer_retry()
		return
	if progress:
		if is_random():
			progress.complete_random()
		else:
			progress.record_time(level, run_time)
			progress.complete_level(level)
	await get_tree().create_timer(CHOICE_DELAY, false).timeout
	if _is_running_scene() and not _leaving():
		_offer_next_steps()


## The buttons shown after drying up: try again, or go spend coins on upgrades first (the
## upgrades screen's PLAY button comes back here).
func _offer_retry() -> void:
	hud.show_choices([["NEW MAZE" if is_random() else "RESTART", retry], ["UPGRADES", go_to_upgrades]], 0)


## Tries again: the same story level, or (the seed was already changed) a new random maze.
func retry() -> void:
	get_tree().reload_current_scene()


func go_to_upgrades() -> void:
	if progress:
		progress.return_to_game = true
	UIKit.go(get_tree(), UPGRADES_SCENE)


## The buttons shown after a win.
func _offer_next_steps() -> void:
	if is_random():
		hud.show_choices([["REPLAY MAZE", replay], ["NEW MAZE", play_next]])
	elif level >= Levels.COUNT:
		hud.show_choices([["REPLAY", replay], ["CONTINUE", play_next]])
	else:
		hud.show_choices([["REPLAY", replay], ["NEXT LEVEL", play_next]])


## Plays this same maze again (for a random maze, the same seed).
func replay() -> void:
	if progress and not is_random():
		progress.start_story(level)
	get_tree().reload_current_scene()


## Moves on: the next story level, a new random maze, or the victory screen after the last level.
func play_next() -> void:
	if is_random():
		if progress:
			progress.new_random_maze()
		get_tree().reload_current_scene()
	elif level >= Levels.COUNT:
		get_tree().change_scene_to_file(VICTORY_SCENE)
	else:
		if progress:
			progress.start_story(level + 1)
		get_tree().reload_current_scene()


func _is_running_scene() -> bool:
	return is_inside_tree() and get_tree().current_scene == self


## True while a screen change is underway (e.g. quitting to the title from the pause menu).
func _leaving() -> bool:
	var transition := get_node_or_null("/root/Transition")
	return transition != null and transition.busy


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running_scene() or _leaving():
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		if won:
			replay()
		elif finished:
			retry()  # the dry-up buttons already offer the upgrades
		else:
			restart_prompt.open()  # mid-run: restart, or spend coins on upgrades first


func _sfx(sound_name: String, volume_db := 0.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name, volume_db)
