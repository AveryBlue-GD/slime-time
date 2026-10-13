extends Node2D

## The hub: the slime's room, where every menu lives (the title screen leads here). It's shaped like a giant slime
## (glossy goo rim, the slime's eyes on the back, jelly-cube floor; all in your skin's colors) and
## seen at a slant. The stations stand evenly spaced around the rim, all facing the center:
## - archway: STORY (level select, with the hard mode switch)
## - coin bag: a board of the coins found in each story level (no screen change)
## - portal: RANDOMIZER (dimmed and locked until the story is beaten)
## - wardrobe: SKINS & HATS
## - cauldron: UPGRADES
## - prize wheel: HAT WHEEL: spin for a random hat you don't have yet (won hats come off the
##   wheel); a spin costs 12 tickets, then 2 more for each spin taken (up to 40; the first is free), but while Hats.available is false only
##   dev mode can use it. The top-left pod shows the ticket balance and medals won.
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
## The title screen (title.tscn) leads here, and Esc goes back to it. Coming back from a station turns the room so that
## station faces you again, with the slime in front of it.

const CENTER := Vector2(160, 98)
## The room on screen (an ellipse: a round room seen at a slant).
const ROOM_RADII := Vector2(154, 78)
## The ring the stations stand on, and the ring of spots in front of them (radii, x and y).
const RING := Vector2(124, 62)
const USE_RING := Vector2(100, 49)
## How close (px, between the slime's edge and a footprint's) the slime must be to use a station
## or the wheel, from any side.
const USE_GAP := 9.0
## Station sounds get this much softer (dB) when the slime is far across the room from them.
const FAR_QUIET_DB := 14.0
const NEAR_LOUDER_DB := 3.0
## The walkable floor: the ellipse the slime's center stays inside (inside the rim, less its size).
const FLOOR := Vector2(134, 64)
## Rows of the rotor sheet above this are the post and wheel; below, the goo pool at its foot.
const ROTOR_SPLIT := 31
## Footprint of the rotor's post (the same oval as its collision body).
const ROTOR_RADIUS := 5.0
const TURN_TIME := 0.55
const START := CENTER + Vector2(-20, 27)  # clear of the wheel and the station straight ahead
const ART := "res://assets/sprites/hub/"
## Warm (or cool) pools of light on the floor under each station: id -> color (alpha = strength).
## The door's torches and the cauldron flicker. Skipped for the flat hatch.
const POOLS := {
	"story": Color(1.0, 0.62, 0.25, 0.48),
	"upgrades": Color(0.55, 1.0, 0.45, 0.45),
	"coins": Color(1.0, 0.82, 0.3, 0.42),
	"random": Color(0.7, 0.45, 1.0, 0.48),
	"settings": Color(0.55, 0.8, 1.0, 0.35),
	"wheel": Color(1.0, 0.55, 0.8, 0.42),
	"wardrobe": Color(1.0, 0.78, 0.35, 0.42),
}
const POOL_SIZE := Vector2i(68, 32)
const FLICKER := ["story", "upgrades"]
const FPS := 6.0
const PROMPT_Y := 156.0
## Where the coin bag's board sits on screen.
const BOARD := Rect2(52, 8, 216, 164)
enum View { FRONT, SIDE, BACK }

## Stations that come to life now and then instead of looping: each entry plays a sequence of
## [frame, seconds] every `every` seconds (random in that range), then rests on its last frame.
## - the trapdoor blows open with a puff of dust and slams shut;
## - the wardrobe's mirror sparkles, and now and then its door swings open and shut;
## - the prize wheel spins, slowing down (built by _spin: it stops wherever it stops);
## - the settings gears whirr round for a moment.
const IDLE_ANIMS := {
	"quit": [{every = Vector2(5.0, 9.0), seq = [[1, 0.07], [2, 0.2], [3, 0.35], [1, 0.07], [0, 0.0]], sound = "puff"}],
	"wardrobe": [
		{every = Vector2(2.5, 5.0), seq = [[1, 0.08], [2, 0.14], [1, 0.08], [0, 0.0]]},
		{every = Vector2(9.0, 15.0), seq = [[3, 0.15], [4, 1.4], [3, 0.15], [0, 0.0]], sound = "creak"},
	],
	"wheel": [{every = Vector2(8.0, 14.0), spin = true}],
	"settings": [{every = Vector2(3.0, 7.0), spin = true, steps = Vector2i(12, 24)}],
}

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
var rotor_base: Sprite2D
## The station (or {id = "rotor"}) the slime is next to ({} = none).
var near: Dictionary = {}
var world: Node2D
var prompt: PanelContainer
var prompt_name: Label
var prompt_key: Label
var room: ColorRect
## The coin bag's board, its per-level counts, its totals line and its close hint.
var coin_board: Control
var board_rows: Array[Label] = []
var board_total: Label
var board_hint: Label
## The hat wheel panel (dev mode for now).
var hat_wheel: HatWheel
## Top-left pod: ticket balance and medal count.
var ticket_pod: PanelContainer
var ticket_label: Label
var medal_label: Label
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
	material.set_shader_parameter("rainbow", Progress.is_rainbow())
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
	rotor = _make_sprite("rotor", Vector2i(26, ROTOR_SPLIT))  # the post and wheel, y-sorted
	rotor.position = CENTER + Vector2(0, 6)
	rotor.offset = Vector2(-13, -36)
	rotor.material = _skin_material()
	world.add_child(rotor)
	# The goo pooled at its foot lies on the floor, under the slime, so the slime can stand on it
	# while the post and wheel still hide it from behind.
	rotor_base = _make_sprite("rotor", Vector2i(26, 36 - ROTOR_SPLIT))
	rotor_base.region_rect.position.y = ROTOR_SPLIT
	rotor_base.position = rotor.position
	rotor_base.offset = Vector2(-13, ROTOR_SPLIT - 36)
	rotor_base.material = rotor.material
	rotor_base.z_index = -1
	add_child(rotor_base)
	_add_body(rotor.position + Vector2(0, -2), 5.0, false)


func _build_stations() -> void:
	var web := OS.has_feature("web") or "--web-ui" in OS.get_cmdline_user_args()
	# Clockwise round the room from the back.
	_add_station("story", "STORY - LEVEL %d" % Progress.current_level, "door", Vector2i(30, 40), 4)  # torches flickering
	_add_station("upgrades", "UPGRADES", "cauldron", Vector2i(30, 28), 4)
	_add_station("coins", "COIN BAG", "coinbag", Vector2i(24, 26), 4)
	_add_station("random", "RANDOMIZER", "portal", Vector2i(30, 40), 6)
	_add_station("settings", "SETTINGS", "signpost", Vector2i(24, 34), 6)
	if not web:
		_add_station("quit", "QUIT", "hatch", Vector2i(28, 18), 4, true)
	_add_station("wheel", "HAT WHEEL", "wheel", Vector2i(32, 40), 24)
	_add_station("wardrobe", "SKINS & HATS", "wardrobe", Vector2i(28, 40), 5)
	step = TAU / stations.size()
	if not Progress.is_randomizer_unlocked():
		_station("random").sprite.modulate = Color(0.45, 0.45, 0.5)
	var back := _station(return_to)
	if not back.is_empty():
		turn = -stations.find(back) * step  # that station back at the back of the room


func _add_station(id: String, title: String, art: String, size: Vector2i, frames: int, flat := false) -> void:
	var sprite := _make_sprite(art, size)
	sprite.material = _skin_material()  # its goo in your skin
	var pool: Sprite2D = null
	if POOLS.has(id):
		pool = Fx.make_pool(POOL_SIZE, POOLS[id])
		pool.z_index = -2  # above the room (added after it), under every station sprite incl. rotor_base
		add_child(pool)
	if flat:  # lies on the floor, under everything
		sprite.z_index = -1
		sprite.offset = Vector2(-size.x / 2, -size.y / 2)
		add_child(sprite)
	else:
		world.add_child(sprite)
	var body: AnimatableBody2D = null if flat else _add_body(Vector2.ZERO, size.x / 2.0 - 4.0, true)
	var anims: Array = []
	for anim: Dictionary in IDLE_ANIMS.get(id, []):
		var copy := anim.duplicate(true)
		copy.next = randf_range(1.0, copy.every.y)  # each starts at its own moment
		anims.append(copy)
	stations.append({id = id, name = title, sprite = sprite, body = body, size = size, frames = frames,
		anims = anims, frame = 0, seq = [], seq_t = 0.0, pool = pool,
		flat = flat, view = View.FRONT, flipped = false})


func _make_sprite(art: String, size: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + art + ".png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, size.x, size.y)
	sprite.centered = false
	sprite.offset = Vector2(-size.x / 2, -size.y)  # its position is where it stands
	return sprite


## A footprint to bump into: a flat oval on the slanted floor, `radius` wide and half as deep
## (stations move with the room, so theirs are animatable). It's a real polygon rather than a
## squashed circle: physics shapes don't take uneven scaling, which made the slime clip and jump.
func _add_body(at: Vector2, radius: float, moving: bool) -> AnimatableBody2D:
	var shape := CollisionPolygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		points.append(Vector2(cos(a) * radius, sin(a) * radius * 0.5))
	shape.polygon = points
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
	slime.maze_assist = false  # no corridor lanes in a round room
	world.add_child(slime)
	slime.position = USE_RING * Vector2(0, -1) + CENTER + Vector2(0, 4) if not _station(return_to).is_empty() else START
	slime.apply_skin(Progress.skin_color(), Progress.is_rainbow(), Progress.is_stopwatch())
	slime.set_translucency(1.0 if Progress.jelly else 0.0)
	slime.jump_landed.connect(_on_jump_landed)
	var camera: Camera2D = slime.get_node("Camera2D")
	camera.enabled = false
	_put_on_hat()


## The slime's hat (again, after winning one on the hat wheel).
func _put_on_hat() -> void:
	if hat:
		if slime.launched.is_connected(hat.pop):
			slime.launched.disconnect(hat.pop)
		hat.queue_free()
		hat = null
	if Progress.selected_hat != Hats.NONE:
		hat = Hat.new()
		# A child of the slime, so it's y-sorted with it: behind the wheel and stations when the
		# slime is, in front when it's in front (the hat still places itself, even when knocked off).
		slime.add_child(hat)
		hat.setup(Progress.selected_hat, slime.sprite, slime)
		slime.launched.connect(hat.pop)


func _on_floor(at: Vector2) -> bool:
	return ((at - CENTER) / FLOOR).length() <= 1.0


## The prompt bar, a soft vignette and touch controls.
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
	prompt.add_theme_stylebox_override("panel", UIKit.panel_style())  # goo-framed, like the menus
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
	_build_coin_board(root)
	_build_ticket_pod(root)
	hat_wheel = HatWheel.new()
	hat_wheel.visible = false
	root.add_child(hat_wheel)
	hat_wheel.landed.connect(func(_id: String) -> void:
		_put_on_hat()
		_refresh_tickets()
		hat_wheel.refresh(_use_key()))
	UIKit.add_skin_text(root)
	_touch_controls = preload("res://scripts/ui/touch_controls.gd").new()
	add_child(_touch_controls)


## A small framed pod at the top left with the ticket balance (the cosmetic currency; the hat
## wheel spends it) and the medals won so far.
func _build_ticket_pod(root: Control) -> void:
	ticket_pod = PanelContainer.new()
	ticket_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	ticket_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ticket_pod)
	ticket_pod.position = Vector2(3, 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	ticket_pod.add_child(row)
	row.add_child(UIKit.make_icon("ticket", Color.WHITE))
	ticket_label = UIKit.make_label("", 8, Color8(255, 226, 150))
	row.add_child(ticket_label)
	row.add_child(UIKit.make_icon("medal", UIKit.GOLD))
	medal_label = UIKit.make_label("", 8, UIKit.GOLD)
	row.add_child(medal_label)
	_refresh_tickets()


func _refresh_tickets() -> void:
	ticket_label.text = str(Progress.tickets)
	medal_label.text = "%d/%d" % [Progress.medals_total(false), Progress.medals_max()]


## The coin bag's board: every story level's coins found out of its total (a gold check once it's
## all found), the story total and the coins in hand. Opened at the coin bag; F, Esc or JUMP closes.
func _build_coin_board(root: Control) -> void:
	coin_board = Control.new()
	coin_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_board.visible = false
	root.add_child(coin_board)
	coin_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.add_panel(coin_board, Rect2(BOARD.position, BOARD.size))
	var title := UIKit.make_label("COIN BAG", 8, UIKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(BOARD.position.x, BOARD.position.y + 7)
	title.size = Vector2(BOARD.size.x, 10)
	coin_board.add_child(title)
	for i in Levels.COUNT:
		var y := BOARD.position.y + 21 + i * 11
		var number := UIKit.make_label(str(i + 1), 8, UIKit.TEXT_DIM)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		coin_board.add_child(number)
		number.position = Vector2(BOARD.position.x + 8, y)
		number.size = Vector2(16, 10)
		var name_label := UIKit.make_label(Themes.display_name(Themes.BY_LEVEL[i]), 8, UIKit.TEXT)
		name_label.position = Vector2(BOARD.position.x + 30, y)
		coin_board.add_child(name_label)
		var count := UIKit.make_label("", 8, UIKit.TEXT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(BOARD.end.x - 66, y)
		count.size = Vector2(42, 10)
		coin_board.add_child(count)
		var icon := UIKit.make_icon("coin", Color.WHITE)
		icon.position = Vector2(BOARD.end.x - 20, y)
		coin_board.add_child(icon)
		board_rows.append(count)
	board_total = UIKit.make_label("", 8, UIKit.TEXT)
	board_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_total.position = Vector2(BOARD.position.x, BOARD.position.y + 133)
	board_total.size = Vector2(BOARD.size.x, 10)
	coin_board.add_child(board_total)
	var hint := UIKit.make_label("", 8, UIKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(BOARD.position.x, BOARD.position.y + 145)
	hint.size = Vector2(BOARD.size.x, 10)
	coin_board.add_child(hint)
	board_hint = hint


func open_coin_board() -> void:
	for i in Levels.COUNT:
		var found: int = Progress.coins_found_in(i + 1)
		var total: int = Levels.COINS[i]
		var count: Label = board_rows[i]
		count.text = "%d/%d" % [found, total]
		count.add_theme_color_override("font_color", UIKit.GOLD if found >= total else UIKit.TEXT)
		count.remove_from_group(SkinText.GROUP)  # keep the gold for finished levels
		if found < total:
			count.add_to_group(SkinText.GROUP)
	board_total.text = "STORY %d/%d   IN HAND %d" % [Progress.coins_earned(), Levels.total_coins(), Progress.coins()]
	var touch := _touch_controls != null and _touch_controls.visible
	board_hint.text = "TAP JUMP TO CLOSE" if touch else "%s TO CLOSE" % Progress.key_name(Progress.bindings.interact)
	coin_board.visible = true
	prompt.visible = false
	slime.frozen = true
	_sfx("coin", 0.8)
	for child in coin_board.get_parent().get_children():
		if child is SkinText:
			child.recolor()


func close_coin_board() -> void:
	coin_board.visible = false
	slime.frozen = false
	_show_prompt()


## The key that uses things here, as shown in hints (TAP JUMP on a touchscreen).
func _use_key() -> String:
	var touch := _touch_controls != null and _touch_controls.visible
	return "TAP JUMP" if touch else Progress.key_name(Progress.bindings.interact)


func open_hat_wheel() -> void:
	hat_wheel.refresh(_use_key())
	hat_wheel.visible = true
	prompt.visible = false
	slime.frozen = true


func close_hat_wheel() -> void:
	hat_wheel.visible = false
	slime.frozen = false
	_show_prompt()


func _physics_process(delta: float) -> void:
	if hat_wheel.visible:
		var touch := _touch_controls != null and _touch_controls.visible
		var pressed := Input.is_action_just_pressed("interact") or (touch and Input.is_action_just_pressed("jump"))
		if hat_wheel.spinning:
			return
		if Input.is_action_just_pressed("menu") or (pressed and not Progress.can_spin_hats()):
			close_hat_wheel()
		elif pressed and hat_wheel.spin():
			var wheel: Dictionary = _station("wheel")
			wheel.seq = _spin(wheel, Vector2i(30, 44))  # the wheel in the room whirls along
			wheel.seq_t = 0.0
		return
	if coin_board.visible:
		var touch := _touch_controls != null and _touch_controls.visible
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("menu") or (touch and Input.is_action_just_pressed("jump")):
			close_coin_board()
		return
	if Input.is_action_just_pressed("menu") and not slime.frozen:
		_sfx("click")
		slime.frozen = true
		UIKit.go(get_tree(), UIKit.TITLE_SCENE)
		return
	if turning:
		_turn_t = minf(_turn_t + delta / TURN_TIME, 1.0)
		var eased := _turn_t * _turn_t * (3.0 - 2.0 * _turn_t)
		turn = lerpf(_turn_from, _turn_to, eased)
		_place_all()
		if _turn_t >= 1.0:
			turning = false
			turn = wrapf(_turn_to, -PI, PI)
			_place_all()
	_update_near()
	# The interact key (F) uses the station or wheel you're next to; on a touchscreen there's no
	# such key, so right next to one JUMP uses it instead of leaping.
	var touch := _touch_controls != null and _touch_controls.visible
	slime.can_charge = near.is_empty() or not touch
	var used := Input.is_action_just_pressed("interact") or (touch and Input.is_action_just_pressed("jump"))
	if not near.is_empty() and used and slime.state == Slime.State.GLIDE:
		if near.id == "rotor":
			turn_room(-1 if Input.is_action_pressed("move_left") else 1)
		else:
			_use(near)


func _process(delta: float) -> void:
	_time += delta
	for station in stations:
		if not station.anims.is_empty():
			_play_idle_anims(station, delta)
		if station.frames > 1:
			_set_frame(station, _frame_of(station))
		var lit: bool = station == near
		if station.pool:
			var flicker := 1.0
			if station.id in FLICKER and not Progress.reduce_motion:
				flicker = 0.88 + 0.08 * sin(_time * 7.3 + station.sprite.position.x) + 0.04 * sin(_time * 17.0)
			station.pool.modulate.a = POOLS[station.id].a * flicker * (1.4 if lit else 1.0)
		if station.id != "random" or Progress.is_randomizer_unlocked():
			station.sprite.self_modulate = Color(1.25, 1.25, 1.25) if lit else Color.WHITE
	rotor.region_rect.position.x = (int(_turn_t * 12.0) % 4 if turning else 0) * 26
	var lit_rotor := Color(1.25, 1.25, 1.25) if near.get("id", "") == "rotor" else Color.WHITE
	rotor.self_modulate = lit_rotor
	rotor_base.self_modulate = lit_rotor


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
	if hit_wall and _gap_to(rotor.position + Vector2(0, -2), ROTOR_RADIUS) < 4.0:
		turn_room(-1 if wall_normal.x > 0.0 else 1)


## Puts every station on the ring for the current turn, with the view for where it stands.
func _place_all() -> void:
	for i in stations.size():
		var station := stations[i]
		var a := -PI / 2.0 + turn + i * step
		var base := CENTER + Vector2(cos(a) * RING.x, sin(a) * RING.y)
		station.sprite.position = base.round()
		if station.pool:
			station.pool.position = (base + Vector2(0, -2)).round()
		if station.body:
			station.body.position = base + Vector2(0, -2)
		var deg := rad_to_deg(wrapf(a, -PI, PI))
		var view := View.SIDE
		# Front and back within 40 degrees of straight across / straight ahead, side views otherwise
		# (so stations on the diagonals settle on their side view instead of flickering).
		if deg > -130.0 and deg < -50.0:
			view = View.FRONT
		elif deg > 50.0 and deg < 130.0:
			view = View.BACK
		station.view = view
		station.flipped = view == View.SIDE and absf(deg) < 90.0  # right-hand side faces left
		if not station.flat:
			station.sprite.flip_h = station.flipped
			_set_frame(station, _frame_of(station))
	(room.material as ShaderMaterial).set_shader_parameter("turn", turn)


## The frame a station shows now: its idle animation's, or (portal, cauldron, coin bag) a loop.
func _frame_of(station: Dictionary) -> int:
	if not station.anims.is_empty():
		return station.frame
	return int(_time * FPS) % station.frames


## Steps a station's current sequence, or starts the next one that's due.
func _play_idle_anims(station: Dictionary, delta: float) -> void:
	if station.seq.is_empty():
		for anim: Dictionary in station.anims:
			if _time >= anim.next:
				station.seq = _spin(station, anim.get("steps", Vector2i(26, 44))) if anim.get("spin", false) else anim.seq.duplicate(true)
				station.seq_t = 0.0
				station.frame = station.seq[0][0]
				var length := 0.0
				for step_: Array in station.seq:
					length += step_[1]
				anim.next = _time + length + randf_range(anim.every.x, anim.every.y)
				_idle_sound(anim.get("sound", ""), station)
				break
		return
	station.seq_t += delta
	while not station.seq.is_empty() and station.seq_t >= station.seq[0][1]:
		station.seq_t -= station.seq[0][1]
		station.seq.pop_front()
		if not station.seq.is_empty():
			station.frame = station.seq[0][0]
			if station.id == "wheel" and station.frame % 2 == 1:
				_sfx_quiet("click", 1.5, -22.0, station)  # the flapper ticking on a peg
			elif station.id == "quit" and station.frame == 0:
				_sfx_quiet("land", 0.7, -16.0, station)  # the lid slamming shut


## A spin from wherever it rests (the prize wheel, the gears): quick at first, slowing to a stop,
## `steps` frames long (random in the range).
func _spin(station: Dictionary, steps_range: Vector2i) -> Array:
	var seq: Array = []
	var steps := randi_range(steps_range.x, steps_range.y)
	var frame: int = station.frame
	for i in steps:
		frame = (frame + 1) % station.frames
		var slowing := float(i) / steps
		seq.append([frame, lerpf(0.035, 0.22, slowing * slowing)])
	seq.append([frame, 0.0])
	return seq


func _idle_sound(sound: String, station: Dictionary) -> void:
	match sound:
		"puff":
			_sfx_quiet("squish", 0.55, -16.0, station)  # a gust of air
		"creak":
			_sfx_quiet("charge", 0.6, -24.0, station)  # the door creaking open
			get_tree().create_timer(0.4).timeout.connect(func() -> void: _sfx_stop("charge"))


## A station's own sound: a little louder when the slime stands next to it, much softer from
## across the room.
func _sfx_quiet(sound: String, pitch: float, volume_db: float, station: Dictionary) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound, volume_db + station_volume(station), pitch)


## How much louder (dB, negative = softer) a station sounds from where the slime is.
func station_volume(station: Dictionary) -> float:
	var gap := _gap_to(station.sprite.position, _footprint(station))
	var far := clampf((gap - USE_GAP) / 90.0, 0.0, 1.0)
	return lerpf(NEAR_LOUDER_DB, -FAR_QUIET_DB, far)


func _sfx_stop(sound: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.stop(sound)


func _set_frame(station: Dictionary, frame: int) -> void:
	var row: int = 0 if station.flat else station.view
	station.sprite.region_rect = Rect2(frame * station.size.x, row * station.size.y, station.size.x, station.size.y)


func _update_near() -> void:
	var best := {}
	var best_gap := USE_GAP
	if not turning:
		for station in stations:
			var gap := _gap_to(station.sprite.position + (Vector2.ZERO if station.flat else Vector2(0, -2)), _footprint(station))
			if gap < best_gap:
				best_gap = gap
				best = station
		if best.is_empty() and _gap_to(rotor.position + Vector2(0, -2), ROTOR_RADIUS) < USE_GAP:
			best = {id = "rotor", name = "ROTATE"}
	if best == near:
		return
	near = best
	_show_prompt()


## A station's footprint radius (its collision oval's; a flat one's lies on the floor).
func _footprint(station: Dictionary) -> float:
	return station.size.x / 2.0 - 4.0


## How far the slime's edge is from a footprint oval (`radius` wide, half as deep, as the
## collision bodies) at `at`, measured from any side. Negative = standing on or in it.
func _gap_to(at: Vector2, radius: float) -> float:
	var v := slime.position - at
	if v.is_zero_approx():
		return -radius
	var dir := v.normalized()
	var edge := 1.0 / sqrt(pow(dir.x / radius, 2.0) + pow(dir.y / (radius * 0.5), 2.0))
	return v.length() - edge - Slime.RADIUS


func _show_prompt(note := "") -> void:
	prompt.visible = not near.is_empty()
	if near.is_empty():
		return
	prompt_name.text = near.name
	if note != "":
		prompt_key.text = note
	elif near.id == "random" and not Progress.is_randomizer_unlocked():
		prompt_key.text = "LOCKED"
	elif near.id == "wheel" and not (Progress.dev_tools or Hats.available):
		prompt_key.text = "COMING SOON"
	elif near.id == "wheel" and not Progress.hats_left().is_empty():
		prompt_key.text = "FREE" if Progress.spin_cost() == 0 else "%d TIX" % Progress.spin_cost()  # the next spin's price
	else:
		prompt_key.text = ""  # just its name: the interact key uses it
	prompt_key.visible = prompt_key.text != ""
	prompt.reset_size()
	var size := prompt.get_combined_minimum_size()
	prompt.size = size
	# Centered at the bottom, its goo drops clear of the screen edge.
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
			if Progress.dev_tools or Hats.available:  # hats are placeholders: dev mode only until released
				open_hat_wheel()
			else:
				_deny("COMING SOON")
		"coins":
			open_coin_board()
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
