extends Node2D

## The hub, which is also the title screen: the slime's room under the big gooey logo. You glide
## (and leap) around it as your slime, in your skin and hat; gliding up to a station shows its
## name, and the jump key (SPACE, or JUMP on touch) uses it:
## - the archway: STORY (level select, with the hard mode switch)
## - the portal: RANDOMIZER (locked until the story is beaten)
## - the wardrobe: SKINS & HATS
## - the cauldron: UPGRADES
## - the prize wheel: HAT WHEEL (coming soon)
## - the gear signpost: SETTINGS
## - the trapdoor: QUIT (not in a browser, where quitting would leave a dead page)
## Away from stations the jump key leaps as usual. Coming back from a station puts the slime in
## front of it again.

const ROOM := Vector2i(20, 12)  # tiles; 320 x 192 px, the camera shows the top 180
const FLOOR_TOP := 5            # rows above this are the back wall (under the logo)
## Standing stations touch the floor at this y; their "use" spot is just in front of them.
const STAND_Y := 104.0
const USE_OFFSET := 9.0
const USE_REACH := 16.0
const START := Vector2(160, 136)
const LOGO_RAINBOW_WIDTH := 90.0
const ART := "res://assets/sprites/hub/"
const FPS := 6.0
## Top of the prompt bar ("UPGRADES  SPACE").
const PROMPT_Y := 156.0

## The station used last; the slime comes back in front of it.
static var return_to := ""

var slime: Slime
var hat: Hat
## Each: {id, name, sprite, base (bottom-center), use (spot), standing, frames, size}.
var stations: Array[Dictionary] = []
## The station the slime is next to ({} = none).
var near: Dictionary = {}
var prompt: PanelContainer
var prompt_name: Label
var prompt_key: Label
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var fillet_layer: TileMapLayer
var _time := 0.0
var _deny_left := 0.0


func _ready() -> void:
	_build_room()
	_build_stations()
	_build_logo()
	_spawn_slime()
	_build_ui()
	_update_near()


## The room: a wall all around (a deep back wall under the logo), dungeon floor inside.
func _build_room() -> void:
	floor_layer = TileMapLayer.new()
	wall_layer = TileMapLayer.new()
	fillet_layer = TileMapLayer.new()
	fillet_layer.z_index = 2
	for layer in [floor_layer, wall_layer, fillet_layer]:
		add_child(layer)
	var walls := PackedByteArray()
	walls.resize(ROOM.x * ROOM.y)
	for y in ROOM.y:
		for x in ROOM.x:
			var wall := x == 0 or x == ROOM.x - 1 or y < FLOOR_TOP or y == ROOM.y - 1
			walls[y * ROOM.x + x] = 1 if wall else 0
	var room := {size = ROOM, walls = walls}
	MazeTiles.fill(floor_layer, wall_layer, room, 7, 1, fillet_layer, Themes.DUNGEON)


func _build_stations() -> void:
	var web := OS.has_feature("web") or "--web-ui" in OS.get_cmdline_user_args()
	var level := Progress.current_level
	_add_station("wardrobe", "SKINS & HATS", "wardrobe", Vector2i(26, 36), 1, Vector2(40, STAND_Y), true)
	_add_station("wheel", "HAT WHEEL", "wheel", Vector2i(30, 36), 1, Vector2(90, STAND_Y), true)
	_add_station("story", "STORY - LEVEL %d" % level, "door", Vector2i(26, 36), 1, Vector2(160, STAND_Y), false)
	_add_station("upgrades", "UPGRADES", "cauldron", Vector2i(26, 24), 4, Vector2(230, STAND_Y), true)
	_add_station("random", "RANDOMIZER", "portal", Vector2i(28, 36), 6, Vector2(280, STAND_Y), true)
	_add_station("settings", "SETTINGS", "signpost", Vector2i(20, 30), 1, Vector2(30, 166), true)
	if not web:
		_add_station("quit", "QUIT", "hatch", Vector2i(26, 16), 1, Vector2(290, 164), false)
	if not Progress.is_randomizer_unlocked():
		_station("random").sprite.modulate = Color(0.45, 0.45, 0.5)
		var lock := UIKit.make_icon("lock", UIKit.TEXT_OFF)
		lock.position = Vector2(-4, -22)
		_station("random").sprite.add_child(lock)


func _add_station(id: String, title: String, art: String, size: Vector2i, frames: int, base: Vector2, standing: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + art + ".png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, size.x, size.y)
	sprite.centered = false
	sprite.offset = Vector2(-size.x / 2, -size.y)
	sprite.position = base
	sprite.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())  # goo in your skin
	(sprite.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)
	sprite.z_index = 10
	add_child(sprite)
	if standing:  # something to bump into: the station's footprint on the floor
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size.x - 4, 6)
		shape.shape = rect
		body.position = base + Vector2(0, -3)
		body.add_child(shape)
		add_child(body)
	var use := base + Vector2(0, USE_OFFSET) if standing else base + Vector2(0, -size.y / 2.0 + (4.0 if id == "quit" else 10.0))
	stations.append({id = id, name = title, sprite = sprite, base = base, use = use, standing = standing, frames = frames, size = size})


func _station(id: String) -> Dictionary:
	for station in stations:
		if station.id == id:
			return station
	return {}


## The gooey logo over the back wall, in the skin's colors.
func _build_logo() -> void:
	var logo := Sprite2D.new()
	logo.texture = preload("res://assets/sprites/title.png")
	logo.centered = false
	logo.position = Vector2(roundf((320 - logo.texture.get_width()) / 2.0), 2)
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	(logo.material as ShaderMaterial).set_shader_parameter("rainbow_width", LOGO_RAINBOW_WIDTH)
	(logo.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)
	logo.z_index = 20
	add_child(logo)


## Your slime, in your skin (jelly or solid) and hat, with the camera held on the room.
func _spawn_slime() -> void:
	slime = preload("res://scenes/slime.tscn").instantiate()
	add_child(slime)
	var back := _station(return_to)
	slime.position = back.use + Vector2(0, 4) if not back.is_empty() else START
	slime.apply_skin(Progress.skin_color(), Progress.is_rainbow())
	slime.set_translucency(1.0 if Progress.jelly else 0.0)
	var camera: Camera2D = slime.get_node("Camera2D")
	camera.limit_right = 320
	camera.limit_bottom = 180
	camera.position_smoothing_enabled = false
	if Progress.selected_hat != Hats.NONE:
		hat = Hat.new()
		hat.z_index = slime.z_index + 1
		add_child(hat)
		hat.setup(Progress.selected_hat, slime.sprite, slime)
		hat.is_wall = func(at: Vector2) -> bool: return wall_layer.get_cell_source_id(Vector2i((at / 16.0).floor())) != -1
		slime.launched.connect(hat.pop)


## The prompt over the station you're at, the tagline, a soft vignette and touch controls.
func _build_ui() -> void:
	var shade := CanvasLayer.new()
	shade.layer = 1
	add_child(shade)
	var vignette := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	material.set_shader_parameter("mist_strength", 0.0)
	material.set_shader_parameter("vignette_strength", 0.45)
	vignette.material = material
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.theme = UIKit.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	prompt.add_child(row)
	prompt_name = UIKit.make_label("", 8, UIKit.TEXT)
	prompt_key = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	row.add_child(prompt_name)
	row.add_child(prompt_key)
	prompt.visible = false
	var tagline := UIKit.make_label("ESCAPE THE FOG OR DRY TRYING!", 8, UIKit.TEXT_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 171
	tagline.offset_bottom = 180
	UIKit.add_skin_text(root)
	add_child(preload("res://scripts/ui/touch_controls.gd").new())


func _physics_process(_delta: float) -> void:
	_update_near()
	# Next to a station the jump key uses it instead of leaping.
	slime.can_charge = near.is_empty()
	if not near.is_empty() and Input.is_action_just_pressed("jump") and slime.state == Slime.State.GLIDE:
		_use(near)


func _process(delta: float) -> void:
	_time += delta
	_deny_left = maxf(_deny_left - delta, 0.0)
	for station in stations:
		var sprite: Sprite2D = station.sprite
		if station.frames > 1:
			sprite.region_rect.position.x = (int(_time * FPS) % station.frames) * station.size.x
		# Standing stations hide the slime when it's behind them.
		if station.standing:
			sprite.z_index = 12 if slime.position.y < station.base.y - 2.0 else 10
		var lit: bool = station == near
		sprite.position = station.base + Vector2(0, -1 if lit and fmod(_time, 0.8) < 0.4 else 0)
		if station.id != "random" or Progress.is_randomizer_unlocked():
			sprite.self_modulate = Color(1.25, 1.25, 1.25) if lit else Color.WHITE
	if hat:
		hat.z_index = slime.z_index + 1


func _update_near() -> void:
	var best := {}
	var best_distance := USE_REACH
	for station in stations:
		var distance: float = slime.position.distance_to(station.use)
		if distance < best_distance:
			best_distance = distance
			best = station
	if best == near:
		return
	near = best
	_show_prompt()


func _show_prompt(note := "") -> void:
	prompt.visible = not near.is_empty()
	if near.is_empty():
		return
	prompt_name.text = near.name
	var touch := DisplayServer.is_touchscreen_available() or Progress.force_touch
	var key: String = "TAP JUMP" if touch else Progress.key_name(Progress.bindings.jump)
	if note != "":
		prompt_key.text = note
	elif near.id == "random" and not Progress.is_randomizer_unlocked():
		prompt_key.text = "LOCKED"
	elif near.id == "wheel":
		prompt_key.text = "COMING SOON"
	else:
		prompt_key.text = key
	# A bar at the bottom center, just above the tagline (clear of the logo and the stations).
	prompt.reset_size()
	var size := prompt.get_combined_minimum_size()
	prompt.position = Vector2(roundf((320.0 - size.x) / 2.0), PROMPT_Y)


## Uses a station: opens its screen, or says why it can't.
func _use(station: Dictionary) -> void:
	match station.id:
		"story":
			_leave(station, "res://scenes/level_select.tscn")
		"wardrobe":
			_leave(station, "res://scenes/skins.tscn")
		"upgrades":
			_leave(station, "res://scenes/upgrades.tscn")
		"settings":
			_leave(station, "res://scenes/controls.tscn")
		"random":
			if Progress.is_randomizer_unlocked():
				Progress.start_random()
				_leave(station, UIKit.GAME_SCENE)
			else:
				_deny("BEAT ALL %d LEVELS" % Levels.COUNT)
		"wheel":
			_deny("COMING SOON")
		"quit":
			get_tree().quit()


func _leave(station: Dictionary, scene: String) -> void:
	return_to = station.id
	_sfx("click")
	slime.frozen = true
	UIKit.go(get_tree(), scene)


func _deny(why: String) -> void:
	_sfx("click", 0.6)
	_show_prompt(why)


func _sfx(sound: String, pitch := 1.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound, -6.0, pitch)
