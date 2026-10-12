extends Node2D

## The hub, which is also the title screen: the slime's room. It's shaped like a giant slime
## (glossy goo rim, the slime's eyes on the back, jelly-cube floor; all in your skin's colors) and
## seen at a slant. The stations stand evenly spaced around the rim, all facing the center:
## - archway: STORY (level select, with the hard mode switch)
## - portal: RANDOMIZER (dimmed and locked until the story is beaten)
## - wardrobe: SKINS & HATS
## - cauldron: UPGRADES
## - prize wheel: HAT WHEEL (coming soon)
## - gear signpost: SETTINGS
## - trapdoor: QUIT (not in a browser, where quitting would leave a dead page)
## In the middle stands a wheel on a stick. Hit it (the interact key, F, next to it, or leap into
## it) and the whole building turns one station round, like turning the camera in Don't Starve:
## floor, rim and stations swing round together (hub_room.gdshader draws the room for the current
## turn) and the next station comes to the back of the room, facing you. Each station shows the
## view for where it stands: its front at the back of the room, its side at the sides, its back up
## close (holding left while hitting the wheel turns the other way). You glide and leap around as
## your slime, in your skin and hat; next to a station the prompt names it and the interact key
## uses it (on a touchscreen, JUMP does, right next to one).
## The logo shows over the room when the game starts and fades once you move. Coming back from a
## station turns the room so that station faces you again, with the slime in front of it.

const CENTER := Vector2(160, 98)
## The room on screen (an ellipse: a round room seen at a slant).
const ROOM_RADII := Vector2(154, 78)
## The ring the stations stand on, and the ring of spots in front of them (radii, x and y).
const RING := Vector2(124, 62)
const USE_RING := Vector2(100, 49)
const USE_REACH := 15.0
## The walkable floor: the ellipse the slime's center stays inside (inside the rim, less its size).
const FLOOR := Vector2(134, 64)
const ROTOR_REACH := 17.0
const TURN_TIME := 0.55
const START := CENTER + Vector2(0, 40)
const ART := "res://assets/sprites/hub/"
const FPS := 6.0
const PROMPT_Y := 166.0
const LOGO_RAINBOW_WIDTH := 90.0
enum View { FRONT, SIDE, BACK }

## The station used last: coming back turns the room to face it, with the slime in front of it.
static var return_to := ""

var slime: Slime
var hat: Hat
## Each: {id, name, sprite, body, size, frames, flat, view, flipped}; index = place in the ring.
var stations: Array[Dictionary] = []
## How far the room has turned (radians); station i stands at -PI/2 + turn + i * step.
var turn := 0.0
var step := 0.0
var turning := false
var _turn_from := 0.0
var _turn_to := 0.0
var _turn_t := 0.0
var rotor: Sprite2D
## The station (or {id = "rotor"}) the slime is next to ({} = none).
var near: Dictionary = {}
var world: Node2D
var prompt: PanelContainer
var prompt_name: Label
var prompt_key: Label
var logo_layer: CanvasLayer
var room: ColorRect
var _touch_controls: CanvasLayer
var _time := 0.0


func _ready() -> void:
	_build_room()
	_build_stations()
	_spawn_slime()
	_build_ui()
	_place_all()
	_update_near()


## The room (drawn by hub_room.gdshader for the current turn), its walls (an ellipse the slime
## can't leave), the y-sorted world for the stations and the slime, and the wheel in the middle.
func _build_room() -> void:
	room = ColorRect.new()
	room.size = Vector2(320, 180)
	room.z_index = -2
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/hub_room.gdshader")
	material.set_shader_parameter("center", CENTER)
	material.set_shader_parameter("radii", ROOM_RADII)
	material.set_shader_parameter("background", UIKit.BG)
	var shades := Skins.shades(Skins.RAINBOW_BASE if Progress.is_rainbow() else Progress.skin_color())
	for shade: String in shades:
		material.set_shader_parameter("outline" if shade == "outline" else shade, shades[shade])
	room.material = material
	add_child(room)

	var walls := StaticBody2D.new()
	var outline := CollisionPolygon2D.new()
	outline.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var points := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		points.append(CENTER + Vector2(cos(a) * FLOOR.x, sin(a) * FLOOR.y))
	outline.polygon = points
	walls.add_child(outline)
	add_child(walls)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	rotor = _make_sprite("rotor", Vector2i(24, 34))
	rotor.position = CENTER + Vector2(0, 6)
	rotor.material = _skin_material()
	world.add_child(rotor)
	_add_body(rotor.position + Vector2(0, -2), 5.0, false)


func _build_stations() -> void:
	var web := OS.has_feature("web") or "--web-ui" in OS.get_cmdline_user_args()
	# Clockwise round the room from the back.
	_add_station("story", "STORY - LEVEL %d" % Progress.current_level, "door", Vector2i(26, 36), 1)
	_add_station("upgrades", "UPGRADES", "cauldron", Vector2i(26, 24), 4)
	_add_station("random", "RANDOMIZER", "portal", Vector2i(28, 36), 6)
	_add_station("settings", "SETTINGS", "signpost", Vector2i(20, 30), 1)
	if not web:
		_add_station("quit", "QUIT", "hatch", Vector2i(26, 16), 1, true)
	_add_station("wheel", "HAT WHEEL", "wheel", Vector2i(30, 36), 1)
	_add_station("wardrobe", "SKINS & HATS", "wardrobe", Vector2i(26, 36), 1)
	step = TAU / stations.size()
	if not Progress.is_randomizer_unlocked():
		_station("random").sprite.modulate = Color(0.45, 0.45, 0.5)
	var back := _station(return_to)
	if not back.is_empty():
		turn = -stations.find(back) * step  # that station back at the back of the room


func _add_station(id: String, title: String, art: String, size: Vector2i, frames: int, flat := false) -> void:
	var sprite := _make_sprite(art, size)
	sprite.material = _skin_material()  # its goo in your skin
	if flat:  # lies on the floor, under everything
		sprite.z_index = -1
		sprite.offset = Vector2(-size.x / 2, -size.y / 2)
		add_child(sprite)
	else:
		world.add_child(sprite)
	var body: AnimatableBody2D = null if flat else _add_body(Vector2.ZERO, size.x / 2.0 - 4.0, true)
	stations.append({id = id, name = title, sprite = sprite, body = body, size = size, frames = frames,
		flat = flat, view = View.FRONT, flipped = false})


func _make_sprite(art: String, size: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + art + ".png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, size.x, size.y)
	sprite.centered = false
	sprite.offset = Vector2(-size.x / 2, -size.y)  # its position is where it stands
	return sprite


## A round footprint to bump into (stations move with the room, so theirs are animatable).
func _add_body(at: Vector2, radius: float, moving: bool) -> AnimatableBody2D:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.scale = Vector2(1.0, 0.5)  # flat on the slanted floor
	if moving:
		var body := AnimatableBody2D.new()
		body.sync_to_physics = true
		body.position = at
		body.add_child(shape)
		add_child(body)
		return body
	var still := StaticBody2D.new()
	still.position = at
	still.add_child(shape)
	add_child(still)
	return null


func _skin_material() -> ShaderMaterial:
	var material := Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	material.set_shader_parameter("translucency", 0.0)
	return material


## Your slime, in your skin (jelly or solid) and hat, with the camera held still on the room.
func _spawn_slime() -> void:
	slime = preload("res://scenes/slime.tscn").instantiate()
	slime.z_index = 0  # y-sorted with the stations
	world.add_child(slime)
	slime.position = USE_RING * Vector2(0, -1) + CENTER + Vector2(0, 4) if not _station(return_to).is_empty() else START
	slime.apply_skin(Progress.skin_color(), Progress.is_rainbow())
	slime.set_translucency(1.0 if Progress.jelly else 0.0)
	slime.jump_landed.connect(_on_jump_landed)
	var camera: Camera2D = slime.get_node("Camera2D")
	camera.enabled = false
	if Progress.selected_hat != Hats.NONE:
		hat = Hat.new()
		hat.z_index = 1
		add_child(hat)
		hat.setup(Progress.selected_hat, slime.sprite, slime)
		hat.is_wall = func(at: Vector2) -> bool: return not _on_floor(at)
		slime.launched.connect(hat.pop)


func _on_floor(at: Vector2) -> bool:
	return ((at - CENTER) / FLOOR).length() <= 1.0


## The prompt bar, the title logo (on a fresh start), a soft vignette and touch controls.
func _build_ui() -> void:
	var shade := CanvasLayer.new()
	shade.layer = 1
	add_child(shade)
	var vignette := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	material.set_shader_parameter("mist_strength", 0.0)
	material.set_shader_parameter("vignette_strength", 0.4)
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
	if return_to == "":
		_build_logo(root)
	UIKit.add_skin_text(root)
	_touch_controls = preload("res://scripts/ui/touch_controls.gd").new()
	add_child(_touch_controls)


## The gooey logo and the tagline over the room, as the title; they fade once you move.
func _build_logo(root: Control) -> void:
	logo_layer = CanvasLayer.new()
	logo_layer.layer = 3
	add_child(logo_layer)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/sprites/title.png")
	logo.position = Vector2(roundf((320 - logo.texture.get_width()) / 2.0), 2)
	logo.material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
	(logo.material as ShaderMaterial).set_shader_parameter("rainbow_width", LOGO_RAINBOW_WIDTH)
	(logo.material as ShaderMaterial).set_shader_parameter("translucency", 0.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_layer.add_child(logo)
	var tagline := UIKit.make_label("ESCAPE THE FOG OR DRY TRYING!", 8, UIKit.TEXT_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tagline)
	tagline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tagline.offset_top = 171
	tagline.offset_bottom = 180
	tagline.set_meta("fades_with_logo", true)
	logo_layer.set_meta("tagline", tagline)


func _fade_logo() -> void:
	if logo_layer == null or logo_layer.has_meta("fading"):
		return
	logo_layer.set_meta("fading", true)
	var tagline: Label = logo_layer.get_meta("tagline")
	var tween := create_tween().set_parallel()
	tween.tween_property(logo_layer.get_child(0), "modulate:a", 0.0, 0.6)
	tween.tween_property(tagline, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(func() -> void:
		tagline.queue_free()
		logo_layer.queue_free()
		logo_layer = null)


func _physics_process(delta: float) -> void:
	if turning:
		_turn_t = minf(_turn_t + delta / TURN_TIME, 1.0)
		var eased := _turn_t * _turn_t * (3.0 - 2.0 * _turn_t)
		turn = lerpf(_turn_from, _turn_to, eased)
		_place_all()
		if _turn_t >= 1.0:
			turning = false
			turn = wrapf(_turn_to, -PI, PI)
			_place_all()
	if logo_layer and (slime.velocity.length() > 4.0 or slime.state != Slime.State.GLIDE):
		_fade_logo()
	_update_near()
	# The interact key (F) uses the station or wheel you're next to; on a touchscreen there's no
	# such key, so right next to one JUMP uses it instead of leaping.
	var touch := _touch_controls != null and _touch_controls.visible
	slime.can_charge = near.is_empty() or not touch
	var used := Input.is_action_just_pressed("interact") or (touch and Input.is_action_just_pressed("jump"))
	if not near.is_empty() and used and slime.state == Slime.State.GLIDE:
		_fade_logo()
		if near.id == "rotor":
			turn_room(-1 if Input.is_action_pressed("move_left") else 1)
		else:
			_use(near)


func _process(delta: float) -> void:
	_time += delta
	for station in stations:
		if station.frames > 1:
			_set_frame(station, int(_time * FPS) % station.frames)
		var lit: bool = station == near
		if station.id != "random" or Progress.is_randomizer_unlocked():
			station.sprite.self_modulate = Color(1.25, 1.25, 1.25) if lit else Color.WHITE
	rotor.region_rect.position.x = (int(_turn_t * 12.0) % 4 if turning else 0) * 24
	rotor.self_modulate = Color(1.25, 1.25, 1.25) if near.get("id", "") == "rotor" else Color.WHITE
	if hat:
		hat.z_index = 1


## Turns the room one station round (1 = the next station clockwise comes to the back).
func turn_room(direction: int) -> void:
	if turning:
		return
	turning = true
	_turn_from = turn
	_turn_to = turn - step * direction
	_turn_t = 0.0
	near = {}
	prompt.visible = false
	_sfx("squish", 0.7)
	_sfx("click", 0.8)


## Leaping into the wheel turns the room too (the side you hit it from picks the way).
func _on_jump_landed(_intended: float, hit_wall: bool, wall_normal: Vector2) -> void:
	if hit_wall and slime.position.distance_to(rotor.position) < ROTOR_REACH + 4.0:
		turn_room(-1 if wall_normal.x > 0.0 else 1)


## Puts every station on the ring for the current turn, with the view for where it stands.
func _place_all() -> void:
	for i in stations.size():
		var station := stations[i]
		var a := -PI / 2.0 + turn + i * step
		var base := CENTER + Vector2(cos(a) * RING.x, sin(a) * RING.y)
		station.sprite.position = base.round()
		if station.body:
			station.body.position = base + Vector2(0, -2)
		var deg := rad_to_deg(wrapf(a, -PI, PI))
		var view := View.SIDE
		if deg > -135.0 and deg < -45.0:
			view = View.FRONT
		elif deg > 45.0 and deg < 135.0:
			view = View.BACK
		station.view = view
		station.flipped = view == View.SIDE and absf(deg) < 90.0  # right-hand side faces left
		if not station.flat:
			station.sprite.flip_h = station.flipped
			_set_frame(station, int(_time * FPS) % station.frames)
	(room.material as ShaderMaterial).set_shader_parameter("turn", turn)


func _set_frame(station: Dictionary, frame: int) -> void:
	var row: int = 0 if station.flat else station.view
	station.sprite.region_rect = Rect2(frame * station.size.x, row * station.size.y, station.size.x, station.size.y)


func _update_near() -> void:
	var best := {}
	var best_distance := USE_REACH
	if not turning:
		for i in stations.size():
			var a := -PI / 2.0 + turn + i * step
			var spot := CENTER + Vector2(cos(a) * USE_RING.x, sin(a) * USE_RING.y)
			var distance := slime.position.distance_to(spot)
			if distance < best_distance:
				best_distance = distance
				best = stations[i]
		if slime.position.distance_to(rotor.position + Vector2(0, 8)) < ROTOR_REACH and best.is_empty():
			best = {id = "rotor", name = "TURN THE ROOM"}
	if best == near:
		return
	near = best
	_show_prompt()


func _show_prompt(note := "") -> void:
	prompt.visible = not near.is_empty()
	if near.is_empty():
		return
	prompt_name.text = near.name
	var touch := _touch_controls != null and _touch_controls.visible
	var key: String = "TAP JUMP" if touch else Progress.key_name(Progress.bindings.interact)
	if note != "":
		prompt_key.text = note
	elif near.id == "random" and not Progress.is_randomizer_unlocked():
		prompt_key.text = "LOCKED"
	elif near.id == "wheel":
		prompt_key.text = "COMING SOON"
	else:
		prompt_key.text = key
	prompt.reset_size()
	var size := prompt.get_combined_minimum_size()
	prompt.position = Vector2(roundf((320.0 - size.x) / 2.0), PROMPT_Y)


func _station(id: String) -> Dictionary:
	for station in stations:
		if station.id == id:
			return station
	return {}


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
