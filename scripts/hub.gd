extends Node2D

## The hub: the slime's room, where every menu lives (the title screen leads here). It's shaped like a giant slime
## (glossy goo rim, the slime's eyes on the back, jelly-cube floor; all in your skin's colors) and
## seen at a slant. The stations stand evenly spaced around the rim, all facing the center:
## - archway: STORY (level select, with the hard mode switch)
## - map table: MAP TABLE (the trail maps of the story levels: scripts/ui/map_select.gd)
## - coin bag: a board of the coins found in each story level (no screen change)
## - portal: RANDOMIZER (dimmed and locked until the story is beaten)
## - wardrobe: COSMETICS (pages SKINS / HATS / TRAILS / PAPERS)
## - cauldron: UPGRADES
## - prize wheel: HAT WHEEL: WHEEL | SHOP (HatWheel). Spin for a random hat you don't have yet (won
##   hats come off the wheel); the first spin is free, then 12 tickets, 2 more for each spin taken
##   (up to 40). The SHOP sells hats (the TAILOR, after 3 spins), trail styles and map papers. The
##   prompt shows the next spin's price with the ticket icon (SHOP once every hat is won) and a "!"
##   when something there is affordable (the cauldron's too, for its TICKETS workshop; none while Economy.WORKSHOP_ENABLED is off). The
##   top-left pod shows the ticket balance and medals won.
## - gear signpost: SETTINGS
## - trapdoor: QUIT (not in a browser, where quitting would leave a dead page); asks first with a
##   small LEAVE THE HUB? panel: QUIT or BACK (focus starts on BACK; Esc / menu = BACK)
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
const MAP_SCENE := "res://scenes/maps.tscn"
## Warm (or cool) pools of light on the floor under each station: id -> color (alpha = strength).
## The door's torches and the cauldron flicker. Skipped for the flat hatch.
const POOLS := {
	"story": Color(1.0, 0.62, 0.25, 0.48),
	"maps": Color(1.0, 0.74, 0.42, 0.4),
	"upgrades": Color(0.55, 1.0, 0.45, 0.45),
	"coins": Color(1.0, 0.82, 0.3, 0.42),
	"random": Color(0.7, 0.45, 1.0, 0.48),
	"settings": Color(0.55, 0.8, 1.0, 0.35),
	"wheel": Color(1.0, 0.55, 0.8, 0.42),
	"wardrobe": Color(1.0, 0.78, 0.35, 0.42),
}
const POOL_SIZE := Vector2i(68, 32)
const FLICKER := ["story", "maps", "upgrades"]
const FPS := 6.0
const PROMPT_Y := 156.0
## The prompt's height in English (one 7 px line in the goo frame): its bottom edge is PROMPT_Y + this.
const PROMPT_H := 18.0
## A taller prompt's bottom edge may come down to this far above the safe area's bottom (its goo drops,
## 2 rows under the box, stay on screen).
const PROMPT_LOW := 3.0
## Where the coin bag's board sits on screen.
const BOARD := Rect2(52, 8, 216, 164)
## Its title's top and the room under the hint (inside the panel); the count column's box (English);
## the gap between its two columns (when ten rows don't fit the height).
const BOARD_TOP := 7.0
const BOARD_BOTTOM := 12.0
const BOARD_COUNT_W := 42.0
const BOARD_COLUMN_GAP := 8.0
## Two columns: their inset from the panel's sides, and the room between a row's number box and its name
## (English's one column: the 16 px number box ends 6 px before the name).
const BOARD_SIDE := 7.0
const BOARD_NAME_GAP := 6
## The trapdoor's confirm panel.
## Both dialogs follow docs/ui-rules.md: content PANEL_PAD (8) inside the top and bottom edges,
## 13 px buttons, 12 px line pitch, centered on the screen.
const QUIT_PANEL := Rect2(80, 63, 160, 54)
## The portal's mode choice (RANDOM MAZE / DESCENT, BACK).
const PORTAL_PANEL := Rect2(70, 45, 180, 89)
## A saved DESCENT run's prompt (three lines, RESUME / QUIT RUN).
const RESUME_PANEL := Rect2(80, 57, 160, 66)
## Esc's menu over the hub (MENU, then BACK / SETTINGS / QUIT TO TITLE stacked): PANEL_PAD, the title,
## HUB_MENU_TITLE_GAP, three buttons GAP_S apart, PANEL_PAD; centred.
const HUB_MENU_PANEL := Rect2(94, 53, 132, 74)
## Its buttons' width in English (the pause stack's; one width for all three, a longer text widens all of them).
const HUB_MENU_BUTTON_W := 100
## The gap between the title's line box and the first button (4 px under the drips in English).
const HUB_MENU_TITLE_GAP := 6
## The confirm panels' buttons: this far in from the panel's sides; the gap between the last line's
## box and the buttons (4 px under the drips in English).
const DIALOG_INSET := 16.0
const DIALOG_GAP := 6.0
enum View { FRONT, SIDE, BACK }
## A station within this many degrees of straight across the room shows its front, of straight
## ahead its back, else its side. Kept clear of every ring spot for 7-9 stations (spots 40-51 degrees
## apart), so no station ever rests on the edge between two views and flickers.
const VIEW_ARC := 35.0

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

const HubTour := preload("res://scripts/hub_tour.gd")
## The room came to rest after a turn: the station now at the back and the way it turned (1 = clockwise,
## -1 = back). The first-visit tour (scripts/hub_tour.gd) listens.
signal room_turned(back_id: String, direction: int)
## The first-visit tour (docs/tutorial/design.md section 5), only while Progress.hub_tour_due(); else null.
var tour: Node = null
var _turn_dir := 1

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
## The ticket icon after a price in the prompt (the next spin's).
var prompt_icon: TextureRect
## "!" when something in that station's ticket store is affordable now (Progress.store_affordable).
var prompt_bang: Label
var room: ColorRect
## The coin bag's board, its per-level counts, its totals line and its close hint.
var coin_board: Control
var board_rows: Array[Label] = []
var board_total: Label
var board_hint: Label
var board_panel: Panel
var board_title: Label
var board_numbers: Array[Label] = []
var board_names: Array[Label] = []
var board_icons: Array[TextureRect] = []
## Where the board is in the current language (BOARD in English).
var board_rect := BOARD
## The prize wheel overlay (WHEEL | SHOP).
var hat_wheel: HatWheel
## The trapdoor's confirm panel (a dim layer, the panel, QUIT and BACK).
var quit_menu: Control
var quit_button: Button
## Where the dialogs' panels are in the current language (QUIT_PANEL / PORTAL_PANEL / RESUME_PANEL in
## English; wider or taller for a longer text or a taller script).
var quit_rect := QUIT_PANEL
var resume_rect := RESUME_PANEL
var resume_panel: Panel
var portal_panel: Panel
var portal_title: Label
var back_button: Button
## The portal's mode choice (upgrades v2 batch 3): RANDOM MAZE (the randomizer as before), DESCENT
## (a run of floors, Descent) with its best floor and today's paying runs, BACK. Esc = BACK.
var portal_menu: Control
var maze_button: Button
var descent_button: Button
var portal_back: Button
var portal_info: Label
## A Descent run saved by a killed app / closed window (Progress.descent_resume, owner decision D6): shown on
## arrival and at the portal's DESCENT. RESUME plays on from that floor's start (or its boon card), QUIT RUN banks
## it as quitting from the pause menu would; Esc / B / back closes it and the run stays saved. A floor already
## resumed once (D9, Progress.descent_resume_spent) shows only QUIT RUN (banks half).
var resume_menu: Control
var resume_button: Button
var resume_quit: Button
var resume_lines: Array[Label] = []
## Esc's menu over the hub: MENU with BACK (focused), SETTINGS (as the signpost) and QUIT TO TITLE.
## Esc / B / START closes it. On iOS / Android the touch home button still goes straight to the title (D10).
var hub_menu: Control
var hub_menu_panel: Panel
var hub_menu_title: Label
var menu_back: Button
var menu_settings: Button
var menu_quit: Button
## Where the hub menu's panel is in the current language (HUB_MENU_PANEL in English).
var hub_menu_rect := HUB_MENU_PANEL
## Set when the touch controls' home button (D10, mobile native) was tapped; cleared by the `menu` press it makes.
var _home_tap := false
## Top-left pod: ticket balance and medal count.
var ticket_pod: PanelContainer
var ticket_label: Label
## The ticket pod's HEAT total (hidden until a level has been cleared with heat).
var heat_flame: TextureRect
var heat_label: Label
var medal_label: Label
var _touch_controls: CanvasLayer
var _time := 0.0
## The one-time UPGRADES REWORKED / COINS RETURNED +N panel (null when there is nothing to show).
var tree_notice: PanelContainer
## Seconds the tree notice stays up before it fades.
const TREE_NOTICE_TIME := 5.0
## The notice's narrowest side padding (it is PANEL_PAD): the goo panel's side band and lumps take its
## first 4 columns, so 5 keeps the text's ink 1 clear column off the lumps, as the panel's rows keep 1 clear
## row over its bottom lumps (fix pass R3; 4 had the last digit on the right lump).
const NOTICE_MIN_PAD := UIKit.GAP_M + 1


func _ready() -> void:
	var tour_due: bool = Progress.hub_tour_due()
	if tour_due:
		return_to = ""  # (the tour starts with the archway at the back)
	_build_room()
	_build_stations()
	_spawn_slime()
	if tour_due:
		slime.position = rotor.position + HubTour.SPAWN_FROM_WHEEL  # next to the wheel
		slime.reset_physics_interpolation()
	_build_ui()
	if tour_due:
		tour = HubTour.new()
		add_child(tour)  # (after the touch controls: a tap on its SKIP pod reaches it first)
		tour.setup(self)
	_place_all()
	_fit_tree_notice()
	_update_near()
	if Progress.descent_resume_pending():
		open_resume_menu.call_deferred()


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
	var can_quit := Platform.can_quit()  # (desktop only: not the web, iOS or Android)
	# Clockwise round the room from the back.
	# i18n: station names are prompt-box labels, max 110px, grows to 200px (the prompt box widens, centred), 1 line
	_add_station("story", Loc.t("hub.station.story", "STORY - LEVEL {level}", {level = Progress.current_level}), "door", Vector2i(30, 40), 4)  # torches flickering
	_add_station("maps", Loc.t("hub.station.map_table", "MAP TABLE"), "maptable", Vector2i(30, 36), 4)  # lantern flickering
	_add_station("upgrades", Loc.t("hub.station.upgrades", "UPGRADES"), "cauldron", Vector2i(30, 28), 4)
	if can_quit:
		_add_station("quit", Loc.t("hub.station.quit", "QUIT"), "hatch", Vector2i(28, 18), 4, true)
	_add_station("coins", Loc.t("hub.station.coins", "COIN BAG"), "coinbag", Vector2i(24, 26), 4)
	_add_station("random", Loc.t("hub.station.random", "RANDOMIZER"), "portal", Vector2i(30, 40), 6)
	_add_station("settings", Loc.t("hub.station.settings", "SETTINGS"), "signpost", Vector2i(24, 34), 6)
	_add_station("wheel", Loc.t("hub.station.wheel", "HAT WHEEL"), "wheel", Vector2i(32, 40), 24)
	_add_station("wardrobe", Loc.t("hub.station.wardrobe", "COSMETICS"), "wardrobe", Vector2i(28, 40), 5)
	step = TAU / stations.size()
	if not Progress.is_randomizer_unlocked():
		_station("random").sprite.modulate = Color(0.45, 0.45, 0.5)
	if not Demo.hat_wheel_open():  # (a demo without the hat wheel: the web demo by default)
		_station("wheel").sprite.modulate = Color(0.45, 0.45, 0.5)
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


## The prompt's goo frame (its top margin follows the shown line's marks, _show_prompt).
var _prompt_style: StyleBox


## The stations and the rotor share one skin material (all the same parameters, never changed
## per station).
var _station_material: ShaderMaterial


func _skin_material() -> ShaderMaterial:
	if _station_material == null:
		_station_material = Skins.make_material(Progress.skin_color(), Progress.is_rainbow())
		_station_material.set_shader_parameter("translucency", 0.0)
	return _station_material


## Your slime, in your skin (jelly or solid) and hat, with the camera held still on the room.
func _spawn_slime() -> void:
	slime = preload("res://scenes/slime.tscn").instantiate()
	slime.z_index = 0  # y-sorted with the stations
	slime.maze_assist = false  # no corridor lanes in a round room
	world.add_child(slime)
	slime.position = USE_RING * Vector2(0, -1) + CENTER + Vector2(0, 4) if not _station(return_to).is_empty() else START
	slime.reset_physics_interpolation()  # placed, not moved
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
	_prompt_style = UIKit.panel_style()  # goo-framed, like the menus
	_prompt_style.content_margin_left -= 1  # the 1 px letter gap left of the name: ink pads 8 / 8
	prompt.add_theme_stylebox_override("panel", _prompt_style)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	prompt.add_child(row)
	prompt_name = UIKit.make_label("", 8, UIKit.TEXT)
	prompt_key = UIKit.make_label("", 8, UIKit.TEXT_DIM)
	row.add_child(prompt_name)
	row.add_child(prompt_key)
	prompt_icon = UIKit.make_icon("ticket", Color.WHITE)
	row.add_child(prompt_icon)
	prompt_bang = UIKit.make_label("!", 8, UIKit.GOLD)
	row.add_child(prompt_bang)
	prompt.visible = false
	_build_coin_board(root)
	_build_ticket_pod(root)
	_build_quit_menu(root)
	_build_portal_menu(root)
	_build_resume_menu(root)
	_build_hub_menu(root)
	_build_wishlist_sign(root)
	hat_wheel = HatWheel.new()
	hat_wheel.visible = false
	root.add_child(hat_wheel)
	hat_wheel.landed.connect(func(_id: String) -> void:
		_put_on_hat()
		_refresh_tickets()
		hat_wheel.refresh(_spin_key()))
	hat_wheel.close_requested.connect(func() -> void:
		if hat_wheel.visible and not hat_wheel.spinning:
			_sfx("click", 0.8)
			close_hat_wheel())
	hat_wheel.changed.connect(func(id: String) -> void:
		if id == "":
			_spin_room_wheel()  # the SPIN button started a spin
		elif not Hats.get_hat(id).is_empty():
			_put_on_hat()  # bought from the TAILOR: worn at once
		_refresh_tickets())
	_show_tree_notice(root)
	UIKit.add_skin_text(root)
	UIKit.mirror_root(root)  # (right-to-left languages: flipped once built, docs/ui-rules.md 10.2)
	_touch_controls = preload("res://scripts/ui/touch_controls.gd").new()
	add_child(_touch_controls)
	_touch_controls.home_icon = Platform.is_mobile_native()  # (D10: its button goes to the title)
	_touch_controls.pause_tapped.connect(func() -> void:
		_home_tap = _touch_controls.home_icon)  # (elsewhere its `menu` press opens the hub menu, like Esc)
	PlatformEvents.input_kind_changed.connect(func(_kind: String) -> void:
		if hat_wheel.visible:
			hat_wheel.set_spin_key(_spin_key()))  # (the spin hint names the device in use: F / X)


## Once after the upgrades v2 migration gave coins back (Progress.take_tree_refund_notice, which
## clears it for good): a goo panel at the top, UPGRADES REWORKED / COINS RETURNED +N, for
## TREE_NOTICE_TIME seconds, then it fades out.
func _show_tree_notice(root: Control) -> void:
	var returned: int = Progress.take_tree_refund_notice()
	if returned <= 0:
		return
	tree_notice = PanelContainer.new()
	var notice_style := UIKit.panel_style()
	if UIKit.tall_script():  # (two lines of a taller script: its last line's lowest ink 1 row clear of the lumps, zh_TW)
		notice_style.content_margin_bottom += 1
	tree_notice.add_theme_stylebox_override("panel", notice_style)
	tree_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tree_notice)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.line_spacing())
	tree_notice.add_child(column)
	# i18n: max 150px each, grows to 280px (the notice widens, centred), 1 line each
	for line: Array in [[Loc.t("hub.notice.reworked", "UPGRADES REWORKED"), UIKit.GOLD], [Loc.t("hub.notice.returned", "COINS RETURNED +{count}", {count = returned}), UIKit.TEXT]]:
		var label := UIKit.make_label(line[0], 8, line[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	tree_notice.reset_size()
	var size := tree_notice.get_combined_minimum_size()
	tree_notice.size = size
	tree_notice.position = Vector2(roundf((320.0 - size.x) / 2.0), 24.0)
	_sfx("coin")
	var fade := tree_notice.create_tween()
	fade.tween_interval(TREE_NOTICE_TIME)
	fade.tween_property(tree_notice, "modulate:a", 0.0, 0.5)
	fade.tween_callback(tree_notice.hide)


## The notice is as wide as its lines; wider than the room between the stations on its rows (a long
## translation: pseudo's notice covered the cabinet and the chair), it first narrows its side padding
## (PANEL_PAD down to NOTICE_MIN_PAD) and, where the room on the two sides differs, sits off the centre;
## then the same with the stations GAP_XS (not GAP_S) clear (fix pass R3: es / pt_BR / fr / it / de / id /
## ru / tr keep two lines); failing that, each line that is too wide breaks onto two at the space that
## balances them (fix pass F3a) and it moves up to stay clear of the wheel. The room is measured on the
## stations' ink in their resting frame; an idle animation that would reach under the notice (the
## wardrobe's door swing) waits until the notice has faded. The station straight behind it (across the
## centre) doesn't count (the English notice covers its foot too). English: unchanged (it fits).
func _fit_tree_notice() -> void:
	if tree_notice == null:
		return
	var box := Rect2(tree_notice.position, tree_notice.size)
	var wheel_top := rotor.position.y + rotor.offset.y
	var side := _notice_room(int(box.position.y), int(wheel_top - UIKit.GAP_S), UIKit.GAP_S)
	var room := 2.0 * minf(160.0 - side.x, side.y - 160.0)
	if box.size.x <= room:
		if box.end.y > wheel_top - UIKit.GAP_S:  # (a taller script's two lines reached the wheel: hi, ar)
			tree_notice.position.y = maxf(UIKit.EDGE, wheel_top - UIKit.GAP_S - box.size.y)
		_hold_anims_under_notice()  # (fr / it: the open door would come 1 column from the box; English: none)
		return
	var style := tree_notice.get_theme_stylebox("panel")
	var text_w := box.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	for gap: int in [UIKit.GAP_S, UIKit.GAP_XS]:
		var free := _notice_room(int(box.position.y), int(wheel_top - UIKit.GAP_S), gap)
		for pad: int in range(UIKit.PANEL_PAD - 1, NOTICE_MIN_PAD - 1, -1):  # (8 fit no more: 7 .. 5)
			var w := text_w + 2 * pad
			if w > free.y - free.x:
				continue
			style.content_margin_left = pad
			style.content_margin_right = pad
			tree_notice.reset_size()
			tree_notice.size = tree_notice.get_combined_minimum_size()
			var x := clampf(roundf((320.0 - w) / 2.0), free.x, free.y - w)
			tree_notice.position = Vector2(x, minf(box.position.y, wheel_top - UIKit.GAP_S - tree_notice.size.y))
			_hold_anims_under_notice()
			return
	var text_room := int(room - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT))
	for label: Label in tree_notice.get_child(0).get_children():
		if UIKit.text_w(label.text) > text_room:
			label.text = UIKit.break_line(label.text, text_room)
	tree_notice.reset_size()
	var size := tree_notice.get_combined_minimum_size()
	tree_notice.size = size
	# (taller now: it rises as far as it must to end GAP_S over the wheel in the middle, over the station
	# straight behind it, never above the HUD row)
	var y := clampf(wheel_top - UIKit.GAP_S - size.y, UIKit.EDGE, box.position.y)
	tree_notice.position = Vector2(roundf((320.0 - size.x) / 2.0), roundf(y))
	_hold_anims_under_notice()


## The free columns for the notice on screen rows `top` .. `bottom`: Vector2(left, right), `gap` columns
## clear of the ink of every station left / right of the centre in its resting frame (frame 0; every frame
## of a looping station). The station straight behind (across the centre) doesn't count.
func _notice_room(top: int, bottom: int, gap: int) -> Vector2:
	var left := 0.0
	var right := 320.0
	for station: Dictionary in stations:
		if station.flat:
			continue
		var frames: Array = [0] if not station.anims.is_empty() else range(maxi(1, station.frames))
		var cols := _station_ink_cols(station, top, bottom, frames)
		if cols.y < 160.0:
			left = maxf(left, cols.y + 1.0 + gap)
		elif cols.x >= 160.0:
			right = minf(right, cols.x - gap)
	return Vector2(left, right)


## Postpones each station idle animation whose frames would reach within GAP_XS of the notice (the
## wardrobe's door swinging open toward it) until the notice has faded. English: nothing is held.
func _hold_anims_under_notice() -> void:
	var box := Rect2(tree_notice.position, tree_notice.size)
	for station: Dictionary in stations:
		if station.flat:
			continue
		for anim: Dictionary in station.anims:
			var frames: Array = range(maxi(1, station.frames))
			if anim.has("seq"):
				frames = anim.seq.map(func(step: Array) -> int: return step[0])
			var cols := _station_ink_cols(station, int(box.position.y), int(box.end.y), frames)
			if cols.x > cols.y or (cols.x <= 160.0 and cols.y >= 160.0):
				continue
			if cols.y + UIKit.GAP_XS >= box.position.x and cols.x - UIKit.GAP_XS < box.end.x:
				anim.next = maxf(anim.next, _time + TREE_NOTICE_TIME + 0.5)


## A station's ink columns on screen rows `top` .. `bottom` (end excluded) over `frames` of its current
## view: Vector2(first x, last x), (INF, -INF) when it has no ink on those rows.
func _station_ink_cols(station: Dictionary, top: int, bottom: int, frames: Array) -> Vector2:
	var sprite: Sprite2D = station.sprite
	var size: Vector2i = station.size
	var origin := (sprite.position + sprite.offset).round()
	var image := sprite.texture.get_image()
	var row: int = 0 if station.flat else station.view
	var cols := Vector2(INF, -INF)
	for frame: int in frames:
		for y in range(maxi(top - int(origin.y), 0), mini(bottom - int(origin.y), size.y)):
			for x in size.x:
				var at := Vector2i(frame * size.x + x, row * size.y + y)
				if at.x >= image.get_width() or at.y >= image.get_height() or image.get_pixelv(at).a <= 0.0:
					continue
				var screen_x := origin.x + (size.x - 1 - x if sprite.flip_h else x)
				cols = Vector2(minf(cols.x, screen_x), maxf(cols.y, screen_x))
	return cols


## The trapdoor's confirm panel: LEAVE THE HUB? with QUIT and BACK (BACK has the focus, so a
## stray press doesn't quit). Static, so Reduce Motion needs nothing extra.
func _build_quit_menu(root: Control) -> void:
	quit_menu = Control.new()
	quit_menu.visible = false
	root.add_child(quit_menu)
	quit_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # swallows clicks on the room behind
	dim.color = Color(0, 0, 0, 0.45)
	quit_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UIKit.add_panel(quit_menu, QUIT_PANEL)
	var lines: Array[Label] = [
		UIKit.add_label(quit_menu, Loc.t("hub.quit.title", "LEAVE THE HUB?"), Rect2(), 8, UIKit.GOLD),
		UIKit.add_label(quit_menu, Loc.t("hub.quit.subtitle", "THE GAME CLOSES"), Rect2(), 8, UIKit.TEXT_DIM),
	]
	quit_button = UIKit.make_button(Loc.t("hub.quit.button", "QUIT"), _confirm_quit, Vector2(56, UIKit.button_h()))
	quit_menu.add_child(quit_button)
	back_button = UIKit.make_button(Loc.t("common.back", "BACK"), close_quit_menu, Vector2(56, UIKit.button_h()))
	quit_menu.add_child(back_button)
	quit_rect = _layout_pair_dialog(panel, QUIT_PANEL, lines, [quit_button, back_button])
	quit_button.focus_next = quit_button.get_path_to(back_button)
	back_button.focus_next = back_button.get_path_to(quit_button)


## Lays out a centered confirm panel (the trapdoor's, the saved run's): `lines` on line_pitch()
## PANEL_PAD from the top, DIALOG_GAP, then the button pair DIALOG_INSET in from the sides (equal
## widths from the longer word). English: exactly `english` (QUIT_PANEL / RESUME_PANEL); a longer
## text widens the panel, a taller script makes it taller (docs/ui-rules.md section 10). Returns
## the panel's rect.
func _layout_pair_dialog(panel: Panel, english: Rect2, lines: Array[Label], buttons: Array[Button]) -> Rect2:
	var widths := UIKit.tab_widths([buttons[0].text, buttons[1].text], 56)
	for b in buttons:
		UIKit.note_text_w(b, [buttons[0].text, buttons[1].text], 56)
	var w := maxf(english.size.x, 2 * DIALOG_INSET + widths[0] + widths[1] + DIALOG_INSET)
	w = maxf(w, _widest(lines) + 2 * UIKit.PANEL_PAD)
	var text_top := UIKit.panel_text_top()  # (PANEL_PAD; lower by the first line's marks' rows)
	var h := text_top + UIKit.PANEL_PAD + (lines.size() - 1) * UIKit.line_pitch() + UIKit.line_h() + DIALOG_GAP + UIKit.button_h()
	var rect := Rect2(UIKit.center_x(w), floorf((180.0 - h) / 2.0), w, h)
	panel.position = rect.position
	panel.size = rect.size
	_stack_lines(lines, rect, rect.position.y + text_top)
	var buttons_y := rect.end.y - UIKit.PANEL_PAD - UIKit.button_h()
	for i in buttons.size():
		var b := buttons[i]
		b.custom_minimum_size = Vector2(widths[i], UIKit.button_h())
		b.size = b.custom_minimum_size
		b.position = Vector2(rect.position.x + DIALOG_INSET if i == 0 else rect.end.x - DIALOG_INSET - widths[i], buttons_y)
	return rect


## Puts `lines` (one-line labels) one line_pitch() apart from `top`, spanning `rect`'s width.
func _stack_lines(lines: Array[Label], rect: Rect2, top: float) -> void:
	for i in lines.size():
		lines[i].position = Vector2(rect.position.x, top + i * UIKit.line_pitch())
		lines[i].size = Vector2(rect.size.x, maxi(10, UIKit.line_h()))


## The widest text among `labels` (measured).
func _widest(labels: Array[Label]) -> float:
	var w := 0
	for label in labels:
		w = maxi(w, UIKit.text_w(label.text))
	return w


func open_quit_menu() -> void:
	quit_menu.visible = true
	prompt.visible = false
	slime.frozen = true
	if _touch_controls != null:
		_touch_controls.menu_open = true  # taps go to the buttons, not the joystick
	_sfx("click")
	back_button.grab_focus()


func close_quit_menu() -> void:
	quit_menu.visible = false
	slime.frozen = false
	if _touch_controls != null:
		_touch_controls.menu_open = false
	_show_prompt()


func _confirm_quit() -> void:
	get_tree().quit()


## Esc's menu: MENU over BACK / SETTINGS / QUIT TO TITLE (BACK has the focus; up / down wrap). Static.
func _build_hub_menu(root: Control) -> void:
	hub_menu = Control.new()
	hub_menu.visible = false
	root.add_child(hub_menu)
	hub_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # swallows clicks on the room behind
	dim.color = Color(0, 0, 0, 0.45)
	hub_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_menu_panel = UIKit.add_panel(hub_menu, HUB_MENU_PANEL)
	# i18n: the hub's Esc menu title, max 116px, 1 line (a longer one widens the panel)
	hub_menu_title = UIKit.add_label(hub_menu, Loc.t("hub.menu.title", "MENU"), Rect2(), 8, UIKit.GOLD)
	var size := Vector2(HUB_MENU_BUTTON_W, UIKit.button_h())
	menu_back = UIKit.make_button(Loc.t("common.back", "BACK"), func() -> void: close_hub_menu(), size)
	menu_settings = UIKit.make_button(Loc.t("hub.station.settings", "SETTINGS"), _hub_menu_settings, size)
	# i18n: hub Esc menu button, max 90px, 1 line (a longer one widens all three); goes back to the title screen
	menu_quit = UIKit.make_button(Loc.t("hub.menu.quit_title", "QUIT TO TITLE"), _hub_menu_quit, size)
	var order: Array[Button] = [menu_back, menu_settings, menu_quit]
	for b in order:
		hub_menu.add_child(b)
	_layout_hub_menu()
	for i in order.size():
		var b := order[i]
		b.focus_neighbor_top = b.get_path_to(order[(i + order.size() - 1) % order.size()])
		b.focus_neighbor_bottom = b.get_path_to(order[(i + 1) % order.size()])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom


## The title, HUB_MENU_TITLE_GAP, the three buttons GAP_S apart (equal widths from the longest word),
## PANEL_PAD above and below: HUB_MENU_PANEL in English, wider for a longer text, taller for a taller script.
func _layout_hub_menu() -> void:
	var buttons: Array[Button] = [menu_back, menu_settings, menu_quit]
	var texts := buttons.map(func(b: Button) -> String: return b.text)
	var bw: int = UIKit.tab_widths(texts, HUB_MENU_BUTTON_W)[0]
	for b in buttons:
		UIKit.note_text_w(b, texts, HUB_MENU_BUTTON_W)
	var bh := UIKit.button_h()
	var w := maxf(HUB_MENU_PANEL.size.x, bw + 2 * DIALOG_INSET)
	w = maxf(w, _widest([hub_menu_title]) + 2 * UIKit.PANEL_PAD)
	var text_top := UIKit.panel_text_top()  # (PANEL_PAD; lower by the title's marks' rows)
	var h := text_top + UIKit.line_h() + HUB_MENU_TITLE_GAP + buttons.size() * bh + (buttons.size() - 1) * UIKit.GAP_S + UIKit.PANEL_PAD
	var rect := Rect2(UIKit.center_x(w), floorf((180.0 - h) / 2.0), w, h)
	hub_menu_panel.position = rect.position
	hub_menu_panel.size = rect.size
	_stack_lines([hub_menu_title], rect, rect.position.y + text_top)
	var y := rect.position.y + text_top + UIKit.line_h() + HUB_MENU_TITLE_GAP
	for b in buttons:
		b.custom_minimum_size = Vector2(bw, bh)
		b.size = b.custom_minimum_size
		b.position = Vector2(UIKit.center_x(bw, rect.position.x, rect.size.x), y)
		y += bh + UIKit.GAP_S
	hub_menu_rect = rect


func open_hub_menu() -> void:
	hub_menu.visible = true
	prompt.visible = false
	slime.frozen = true
	if _touch_controls != null:
		_touch_controls.menu_open = true  # taps go to the buttons, not the joystick
	_sfx("click")
	menu_back.grab_focus()


func close_hub_menu() -> void:
	hub_menu.visible = false
	get_viewport().gui_release_focus()  # (no hidden button keeps the keyboard)
	if _touch_controls != null:
		_touch_controls.menu_open = false
	slime.frozen = false
	_show_prompt()


## SETTINGS: the settings screen, as the signpost opens it (its BACK returns in front of the signpost).
func _hub_menu_settings() -> void:
	if not hub_menu.visible:
		return
	close_hub_menu()
	_leave(_station("settings"), "res://scenes/controls.tscn")


## QUIT TO TITLE: the goo wipe to the title (what Esc in the hub did before the menu).
func _hub_menu_quit() -> void:
	if not hub_menu.visible:
		return
	close_hub_menu()
	_sfx("click")
	slime.frozen = true
	UIKit.go(get_tree(), UIKit.TITLE_SCENE)


## The portal's mode choice: RANDOM MAZE and DESCENT stacked, a line with the Descent best floor and
## today's paying runs, BACK under them (focus starts on RANDOM MAZE; up / down wrap).
func _build_portal_menu(root: Control) -> void:
	portal_menu = Control.new()
	portal_menu.visible = false
	root.add_child(portal_menu)
	portal_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # swallows clicks on the room behind
	dim.color = Color(0, 0, 0, 0.45)
	portal_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portal_panel = UIKit.add_panel(portal_menu, PORTAL_PANEL)
	portal_title = UIKit.add_label(portal_menu, Loc.t("hub.portal.title", "RANDOMIZER"), Rect2(), 8, UIKit.GOLD)
	maze_button = UIKit.make_button(Loc.t("hub.portal.random_maze", "RANDOM MAZE"), _start_random_maze, Vector2(120, UIKit.button_h()))
	portal_menu.add_child(maze_button)
	descent_button = UIKit.make_button(Loc.t("hub.portal.descent", "DESCENT"), _start_descent, Vector2(120, UIKit.button_h()))
	portal_menu.add_child(descent_button)
	portal_info = UIKit.add_label(portal_menu, "", Rect2(), 8, UIKit.TEXT_DIM)
	portal_back = UIKit.make_button(Loc.t("common.back", "BACK"), close_portal_menu, Vector2(56, UIKit.button_h()))
	portal_menu.add_child(portal_back)
	_layout_portal_menu()
	var order: Array[Button] = [maze_button, descent_button, portal_back]
	for i in order.size():
		var b := order[i]
		b.focus_neighbor_top = b.get_path_to(order[(i + order.size() - 1) % order.size()])
		b.focus_neighbor_bottom = b.get_path_to(order[(i + 1) % order.size()])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom


## Title, the two modes (stack_pitch apart), the info line, BACK: gaps of 6 / 3 / 5 / 6 px between
## the lines' boxes and the buttons (4 / 3 / 3 / 4 below the drips in English), PANEL_PAD above and
## below; PORTAL_PANEL in English, wider for a longer text, taller for a taller script.
func _layout_portal_menu() -> void:
	var line := UIKit.line_h()
	var bh := UIKit.button_h()
	var mode_w: int = UIKit.tab_widths([maze_button.text, descent_button.text], 120)[0]
	var back_w := UIKit.button_w(portal_back.text, 56)
	for b: Button in [maze_button, descent_button]:
		UIKit.note_text_w(b, [maze_button.text, descent_button.text], 120)
	UIKit.note_text_w(portal_back, [portal_back.text], 56)
	var w := maxf(PORTAL_PANEL.size.x, mode_w + 2 * 30)
	w = maxf(w, _widest([portal_title, portal_info]) + 2 * UIKit.PANEL_PAD)
	var text_top := UIKit.panel_text_top()  # (PANEL_PAD; lower by the title's marks' rows)
	var h := text_top + UIKit.PANEL_PAD + line + 6 + bh + UIKit.GAP_S + bh + 5 + line + 6 + bh
	var rect := Rect2(UIKit.center_x(w), floorf((180.0 - h) / 2.0), w, h)
	portal_panel.position = rect.position
	portal_panel.size = rect.size
	var y := rect.position.y + text_top
	_stack_lines([portal_title], rect, y)
	y += line + 6
	for b: Button in [maze_button, descent_button]:
		b.custom_minimum_size = Vector2(mode_w, bh)
		b.size = b.custom_minimum_size
		b.position = Vector2(UIKit.center_x(mode_w, rect.position.x, rect.size.x), y)
		y += bh + UIKit.GAP_S
	y += 5 - UIKit.GAP_S
	_stack_lines([portal_info], rect, y)
	portal_back.custom_minimum_size = Vector2(back_w, bh)
	portal_back.size = portal_back.custom_minimum_size
	portal_back.position = Vector2(UIKit.center_x(back_w, rect.position.x, rect.size.x), rect.end.y - UIKit.PANEL_PAD - bh)


func open_portal_menu() -> void:
	UIKit.relayout(portal_menu)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	var best: int = Progress.descent_best_floor
	var left: int = Progress.descent_paid_left()
	# i18n: max 170px, 1 line; the spaces are spacing, not words
	var paid := {left = left, total = Economy.DESCENT_PAID_PER_DAY, best = best}
	if best > 0:
		portal_info.text = Loc.t("hub.portal.info_best", "BEST FLOOR {best}   PAID RUNS {left}/{total}", paid)
	else:
		portal_info.text = Loc.t("hub.portal.info", "PAID RUNS {left}/{total}", paid)
	_layout_portal_menu()  # (the info line's width can widen the panel)
	portal_menu.visible = true
	prompt.visible = false
	slime.frozen = true
	if _touch_controls != null:
		_touch_controls.menu_open = true
	_sfx("click")
	for child in portal_menu.get_parent().get_children():
		if child is SkinText:
			child.recolor()
	maze_button.grab_focus()


func close_portal_menu() -> void:
	portal_menu.visible = false
	get_viewport().gui_release_focus()
	slime.frozen = false
	if _touch_controls != null:
		_touch_controls.menu_open = false
	_show_prompt()


func _start_random_maze() -> void:
	if not portal_menu.visible:
		return
	portal_menu.visible = false
	_begin_random_maze()


func _begin_random_maze() -> void:
	Progress.start_random()
	_leave(_station("random"), UIKit.GAME_SCENE)


func _start_descent() -> void:
	if not portal_menu.visible:
		return
	if Progress.descent_resume_pending():  # a saved run first: resume it or quit it
		close_portal_menu()
		open_resume_menu()
		return
	portal_menu.visible = false
	Progress.start_descent()
	_leave(_station("random"), UIKit.GAME_SCENE)


## The saved-run prompt: DESCENT RUN SAVED, where it stands, what quitting banks; RESUME (focused) and QUIT RUN.
func _build_resume_menu(root: Control) -> void:
	resume_menu = Control.new()
	resume_menu.visible = false
	root.add_child(resume_menu)
	resume_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()  # swallows clicks on the room behind
	dim.color = Color(0, 0, 0, 0.45)
	resume_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resume_panel = UIKit.add_panel(resume_menu, RESUME_PANEL)
	for i in 3:
		var color: Color = [UIKit.GOLD, UIKit.TEXT, UIKit.TEXT_DIM][i]
		resume_lines.append(UIKit.add_label(resume_menu, "", Rect2(), 8, color))
	resume_button = UIKit.make_button(Loc.t("hub.resume.resume", "RESUME"), _resume_descent, Vector2(56, UIKit.button_h()))
	resume_menu.add_child(resume_button)
	resume_quit = UIKit.make_button(Loc.t("hub.resume.quit_run", "QUIT RUN"), _quit_saved_descent, Vector2(56, UIKit.button_h()))
	resume_menu.add_child(resume_quit)
	resume_rect = _layout_pair_dialog(resume_panel, RESUME_PANEL, resume_lines, [resume_button, resume_quit])
	_link_resume_buttons(false)


## RESUME <-> QUIT RUN; with the floor's resume spent (D9) RESUME is hidden and QUIT RUN, centred, links to itself.
func _link_resume_buttons(spent: bool) -> void:
	resume_button.visible = not spent
	resume_rect = _layout_pair_dialog(resume_panel, RESUME_PANEL, resume_lines, [resume_button, resume_quit])
	if spent:
		resume_quit.position.x = UIKit.center_x(resume_quit.size.x, resume_rect.position.x, resume_rect.size.x)
	for b: Button in [resume_button, resume_quit]:
		var other := b if spent else (resume_quit if b == resume_button else resume_button)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)


func open_resume_menu() -> void:
	if not Progress.descent_resume_pending() or quit_menu.visible or portal_menu.visible or hat_wheel.visible or coin_board.visible \
			or hub_menu.visible:
		return
	UIKit.relayout(resume_menu)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	var run: Dictionary = Progress.descent_resume
	var on_card := int(run.cleared) >= int(run.floor)
	var spent: bool = Progress.descent_resume_spent()
	_link_resume_buttons(spent)
	# i18n: max 150px each, 1 line each
	var floor_args := {floor = int(run.floor), pot = int(run.pot)}
	resume_lines[0].text = Loc.t("hub.resume.spent", "FLOOR ALREADY RESUMED") if spent else Loc.t("hub.resume.saved", "DESCENT RUN SAVED")
	if on_card:
		resume_lines[1].text = Loc.t("hub.resume.floor_cleared", "FLOOR {floor} CLEARED - POT {pot}", floor_args)
		resume_lines[2].text = Loc.t("hub.resume.cashes_out", "QUIT RUN CASHES OUT")
	else:
		resume_lines[1].text = Loc.t("hub.resume.floor", "FLOOR {floor} - POT {pot}", floor_args)
		resume_lines[2].text = Loc.t("hub.resume.banks_half", "QUIT RUN BANKS HALF")
	_link_resume_buttons(spent)  # (again: the lines' widths can widen the panel)
	resume_menu.visible = true
	prompt.visible = false
	slime.frozen = true
	if _touch_controls != null:
		_touch_controls.menu_open = true
	for child in resume_menu.get_parent().get_children():
		if child is SkinText:
			child.recolor()
	(resume_quit if spent else resume_button).grab_focus()


func close_resume_menu() -> void:
	resume_menu.visible = false
	get_viewport().gui_release_focus()
	slime.frozen = false
	if _touch_controls != null:
		_touch_controls.menu_open = false
	_show_prompt()


func _resume_descent() -> void:
	if not resume_menu.visible or not Progress.resume_descent():
		return
	resume_menu.visible = false
	_leave(_station("random"), UIKit.GAME_SCENE)


func _quit_saved_descent() -> void:
	if not resume_menu.visible:
		return
	Progress.quit_saved_descent()
	_sfx("coin", 0.8)
	close_resume_menu()
	_refresh_tickets()


## A small framed pod at the top left with the ticket balance (the cosmetic currency; the hat
## wheel spends it) and the medals won so far.
## The demo's WISHLIST sign: a small button under the ticket pod once the end screen was seen (only with a
## store page to open, Demo.WISHLIST_URL; hidden otherwise).
var wishlist_sign: Button


func _build_wishlist_sign(root: Control) -> void:
	if not (Demo.wishlist_shown() and Progress.has_seen_story(Demo.END_SEEN_BIT)):
		return
	# i18n: hub sign (demo build, opens the store page), max 80px, 1 line
	var text := Loc.t("demo.wishlist", "WISHLIST")
	wishlist_sign = UIKit.make_button(text, Demo.open_wishlist, Vector2(UIKit.button_w(text, 56), UIKit.button_h()))
	wishlist_sign.focus_mode = Control.FOCUS_NONE  # (the hub is walked, not tabbed: a click / tap opens it)
	root.add_child(wishlist_sign)
	wishlist_sign.size = wishlist_sign.custom_minimum_size
	wishlist_sign.position = Vector2(UIKit.hud_edge()) + Vector2(0, UIKit.pod_h() + UIKit.GAP_XS)
	UIKit.add_touch_target(wishlist_sign)


func _build_ticket_pod(root: Control) -> void:
	ticket_pod = PanelContainer.new()
	ticket_pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	ticket_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ticket_pod)
	ticket_pod.position = Vector2(UIKit.hud_edge())
	ticket_pod.custom_minimum_size.y = UIKit.pod_h()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	ticket_pod.add_child(row)
	row.add_child(UIKit.make_icon("ticket", Color.WHITE))
	ticket_label = UIKit.make_label("", 8, Color8(255, 226, 150))
	row.add_child(ticket_label)
	row.add_child(UIKit.make_icon("medal", UIKit.GOLD))
	medal_label = UIKit.make_label("", 8, UIKit.GOLD)
	row.add_child(medal_label)
	# HEAT: the sum of every hard level's best heat, once there is any (HEAT n/100).
	heat_flame = Heat.make_rect(Heat.flame(Economy.HEAT_MAX))
	row.add_child(UIKit.fit_icon(heat_flame))  # (7x9: kept to the pod's 14 px height)
	heat_label = UIKit.make_label("", 8, Color8(255, 170, 90))
	row.add_child(heat_label)
	_refresh_tickets()


func _refresh_tickets() -> void:
	ticket_label.text = str(Progress.tickets)
	medal_label.text = "%d/%d" % [Progress.medals_total(false), Progress.medals_max()]
	heat_label.text = "%d/%d" % [Progress.heat_total(), Economy.HEAT_MAX * Levels.COUNT]
	heat_flame.get_parent().visible = Progress.heat_total() > 0 and Demo.heat_open()  # (the demo: no HEAT, even from a full save)
	heat_flame.visible = heat_flame.get_parent().visible
	heat_label.visible = heat_flame.visible


## The coin bag's board: every story level's coins found out of its total (a gold check once it's
## all found), the story total and the coins in hand. Opened at the coin bag; F, Esc or JUMP closes.
func _build_coin_board(root: Control) -> void:
	coin_board = Control.new()
	coin_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_board.visible = false
	root.add_child(coin_board)
	coin_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_panel = UIKit.add_panel(coin_board, Rect2(BOARD.position, BOARD.size))
	board_title = UIKit.make_label(Loc.t("hub.station.coins", "COIN BAG"), 8, UIKit.GOLD)
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# (placed as in English while they are made, then fitted by _layout_coin_board: sizing a label
	# shapes its text, and the English board must allocate in the same order to keep its goo)
	board_title.position = Vector2(BOARD.position.x, BOARD.position.y + 7)
	board_title.size = Vector2(BOARD.size.x, 10)
	coin_board.add_child(board_title)
	for i in Levels.COUNT:
		var y := BOARD.position.y + 21 + i * 11
		var number := UIKit.make_label(str(i + 1), 8, UIKit.TEXT_DIM)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		coin_board.add_child(number)
		number.position = Vector2(BOARD.position.x + 7, y)
		number.size = Vector2(16, 10)
		board_numbers.append(number)
		var name_label := UIKit.make_label(Themes.display_name(Themes.BY_LEVEL[i]), 8, UIKit.TEXT)
		name_label.position = Vector2(BOARD.position.x + 29, y)
		coin_board.add_child(name_label)
		board_names.append(name_label)
		var count := UIKit.make_label("", 8, UIKit.TEXT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(BOARD.end.x - 68, y)
		count.size = Vector2(42, 10)
		coin_board.add_child(count)
		var icon := UIKit.make_icon("coin", Color.WHITE)
		icon.position = Vector2(BOARD.end.x - 22, y)
		coin_board.add_child(icon)
		board_icons.append(icon)
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
	_layout_coin_board()


## The board: the title, a row per level (number, name, coins found / total, coin icon), the story
## total and the close hint, centered on the screen. English: BOARD, one column on DENSE_PITCH. A
## longer text widens it (up to the safe width); when the ten rows don't fit the screen's height on
## dense_pitch() (the taller scripts), the levels go in two columns of five, sized to their texts
## (names in the script's smaller size if the two columns are still too wide).
func _layout_coin_board() -> void:
	var line := UIKit.line_h()
	var dense := UIKit.dense_pitch()
	var box_h := maxi(10, line)
	var max_h := 180.0 - 2 * UIKit.EDGE
	var count_w := 0
	for i in Levels.COUNT:
		count_w = maxi(count_w, UIKit.text_w(board_rows[i].text if board_rows[i].text != "" else "%d/%d" % [Levels.COINS[i], Levels.COINS[i]]))
	# One column (English): the rows from 21 below the top, the total 2 under the last row's pitch,
	# the hint a line_pitch() under it, 12 below.
	var rows := Levels.COUNT
	var after_title := 7.0
	var columns := 1
	# (a title with marks starts lower by their rows, so they keep off the goo band: accent_room)
	var title_top := BOARD_TOP + (UIKit.accent_room() if UIKit.ink_above(board_title.text) > 0 else 0)
	var content := title_top + line + after_title + rows * dense + 2 + UIKit.line_pitch() + line
	if content + UIKit.GAP_M > max_h:  # (the room under the hint may shrink to GAP_M first)
		columns = 2
		rows = ceili(Levels.COUNT / 2.0)
		after_title = UIKit.GAP_M
		content = title_top + line + after_title + rows * dense + 2 + UIKit.line_pitch() + line
	var h := minf(max_h, content + BOARD_BOTTOM)
	# Widths: number box, name, count box, coin icon; English one column: 7 | 16 | 6 | name ... | 42 | 4 | 8 | 14.
	var w := BOARD.size.x
	var col_w: Array[float] = []
	var num_w: Array[int] = []
	if columns == 1:
		var names := 0
		for label in board_names:
			names = maxi(names, UIKit.text_w(label.text))
		w = maxf(w, 29 + names + 4 + BOARD_COUNT_W + 4 + 8 + 14)
	else:
		for small in [false, true]:
			if small:
				var language: Node = get_node_or_null("/root/Language")
				var font: Font = language.small_font(UIKit.locale()) if language and language.has_method("small_font") else null
				if font == null:
					break
				for label in board_names:
					label.add_theme_font_override("font", font)
			col_w.clear()
			num_w.clear()
			for c in 2:
				var names := 0
				var last := mini((c + 1) * rows, Levels.COUNT)
				for i in range(c * rows, last):
					names = maxi(names, UIKit.text_w(board_names[i].text, UIKit.FONT, board_names[i].get_theme_font("font")))
				num_w.append(UIKit.text_w(str(last)))
				col_w.append(num_w[c] + BOARD_NAME_GAP + names + UIKit.GAP_M + count_w + UIKit.GAP_M + 8)
			w = BOARD_SIDE + col_w[0] + BOARD_COLUMN_GAP + col_w[1] + BOARD_SIDE
			if w <= 320 - 2 * UIKit.EDGE:
				break
	# (the total and hint lines span the board: a longer translation widens it too)
	w = maxf(w, maxf(UIKit.text_w(board_total.text), UIKit.text_w(board_hint.text)) + 2 * UIKit.PANEL_PAD)
	w = minf(w, 320 - 2 * UIKit.EDGE)
	board_rect = Rect2(UIKit.center_x(w), floorf((180.0 - h) / 2.0), w, h)
	board_panel.position = board_rect.position
	board_panel.size = board_rect.size
	var top := board_rect.position.y
	board_title.position = Vector2(board_rect.position.x, top + title_top)
	board_title.size = Vector2(w, box_h)
	var rows_y := top + title_top + line + after_title
	for i in Levels.COUNT:
		var c := i / rows
		var y := rows_y + (i % rows) * dense
		if columns == 1:  # (English)
			var left := board_rect.position.x + 7
			board_numbers[i].position = Vector2(left, y)
			board_numbers[i].size = Vector2(16, box_h)
			board_names[i].position = Vector2(left + 22, y)
			board_rows[i].position = Vector2(board_rect.end.x - 68, y)
			board_rows[i].size = Vector2(BOARD_COUNT_W, box_h)
			board_icons[i].position = Vector2(board_rect.end.x - 22, y)
		else:
			# A column: number (right-aligned in the widest number's width), name, count (right-aligned), coin.
			var left := board_rect.position.x + BOARD_SIDE + (0.0 if c == 0 else col_w[0] + BOARD_COLUMN_GAP)
			var right := left + col_w[c]
			# (CJK: the hanzi / kana ink reaches ink_drop 1 row lower than the slimy digits' body, so the
			# number, the count and its coin go 1 row down to share the name's middle: zh_TW's digits sat
			# 1.5 px over it, fix pass F3a; 0 in every other script)
			var drop := int(UIKit.metrics().get("ink_drop", 0))
			board_numbers[i].position = Vector2(left, y + drop)
			board_numbers[i].size = Vector2(num_w[c], box_h)
			board_names[i].position = Vector2(left + num_w[c] + BOARD_NAME_GAP, y)
			board_rows[i].position = Vector2(right - 8 - UIKit.GAP_M - count_w, y + drop)
			board_rows[i].size = Vector2(count_w, box_h)
			# (the coin on the digits' 7 px body, which sits on the line's baseline in a taller script)
			board_icons[i].position = Vector2(right - 8, y + drop + UIKit.digit_top())
			board_names[i].size = Vector2(0, box_h)
	var total_y := rows_y + (rows - 1) * dense + dense + 2
	board_total.position = Vector2(board_rect.position.x, total_y)
	board_total.size = Vector2(w, box_h)
	board_hint.position = Vector2(board_rect.position.x, total_y + UIKit.line_pitch())
	board_hint.size = Vector2(w, box_h)


func open_coin_board() -> void:
	UIKit.relayout(coin_board)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	for i in Levels.COUNT:
		var found: int = Progress.coins_found_in(i + 1)
		var total: int = Levels.COINS[i]
		var count: Label = board_rows[i]
		count.text = "%d/%d" % [found, total]
		count.add_theme_color_override("font_color", UIKit.GOLD if found >= total else UIKit.TEXT)
		count.remove_from_group(SkinText.GROUP)  # keep the gold for finished levels
		count.remove_meta(SkinText.DUE)  # (a rainbow color it was due while hidden is stale now)
		if found < total:
			count.add_to_group(SkinText.GROUP)
	# i18n: max 200px, grows to 280px (the board widens), 1 line; the spaces are spacing, not words
	board_total.text = Loc.t("hub.coins.total", "STORY {have}/{total}   IN HAND {hand}", {have = Progress.coins_earned(), total = Levels.total_coins(), hand = maxi(Progress.coins(), 0)})
	var touch := _touch_controls != null and _touch_controls.visible
	# i18n: max 200px, 1 line; {key} = a key or pad button name
	if touch:
		board_hint.text = Loc.t("hub.coins.close_touch", "TAP JUMP TO CLOSE")
	else:
		board_hint.text = Loc.t("hub.coins.close_key", "{key} TO CLOSE", {key = Platform.prompt_for("ui_cancel", Progress.key_name(Progress.bindings.interact))})
	_layout_coin_board()  # (the texts' widths can widen it)
	coin_board.visible = true
	prompt.visible = false
	# (the pod would sit on the board's top-left frame; the board shows the coins. Faded, not hidden: shown
	# again, its labels would shape their text anew and move every later goo box's lumps)
	ticket_pod.modulate.a = 0.0
	slime.frozen = true
	_sfx("coin", 0.8)
	for child in coin_board.get_parent().get_children():
		if child is SkinText:
			child.recolor()


func close_coin_board() -> void:
	coin_board.visible = false
	ticket_pod.modulate.a = 1.0
	slime.frozen = false
	_show_prompt()


## The key that uses things here, as shown in hints (TAP JUMP on a touchscreen, X on a gamepad).
func _use_key() -> String:
	return Loc.t("hub.prompt.tap_jump", "TAP JUMP") if _touch() else Platform.prompt_for("interact", Progress.key_name(Progress.bindings.interact))


## True while the touch controls are in use here.
func _touch() -> bool:
	return _touch_controls != null and _touch_controls.visible


## The hat wheel's spin key for its hint: none on touch (the SPIN button; a tap elsewhere never spins).
func _spin_key() -> String:
	return "" if _touch() else _use_key()


## Opens the prize wheel's overlay (WHEEL | SHOP, see HatWheel), focus inside it. On touch, the touch controls
## stand down (no tap is a JUMP, so none can spin) and the overlay shows its BACK button.
func open_hat_wheel() -> void:
	hat_wheel.visible = true
	hat_wheel.show_close(_touch() or UIKit.touch_active())
	hat_wheel.refresh(_spin_key(), true)
	prompt.visible = false
	ticket_pod.visible = false  # (the overlay shows the balance itself)
	slime.frozen = true
	if _touch_controls != null:
		_touch_controls.menu_open = true


func close_hat_wheel() -> void:
	if _touch_controls != null:
		_touch_controls.menu_open = false
	hat_wheel.close_confirm()
	hat_wheel.visible = false
	get_viewport().gui_release_focus()  # (no hidden button keeps the keyboard)
	ticket_pod.visible = true
	_refresh_tickets()
	slime.frozen = false
	_show_prompt()


## The prize wheel in the room whirls along with a spin of the overlay's wheel.
func _spin_room_wheel() -> void:
	var wheel: Dictionary = _station("wheel")
	wheel.seq = _spin(wheel, Vector2i(30, 44))
	wheel.seq_t = 0.0


func _physics_process(delta: float) -> void:
	var home_tap := _home_tap  # (the D10 home button's tap: the `menu` press it makes is that tap's)
	if Input.is_action_just_pressed("menu"):
		_home_tap = false
	if hub_menu.visible:
		if Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel"):
			_sfx("click", 0.8)
			close_hub_menu()
		return
	if resume_menu.visible:
		if Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel"):
			_sfx("click", 0.8)
			close_resume_menu()  # (the run stays saved: asked again next time)
		return
	if quit_menu.visible:
		if Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel"):
			_sfx("click", 0.8)
			close_quit_menu()
		return
	if portal_menu.visible:
		if Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel"):
			_sfx("click", 0.8)
			close_portal_menu()
		return
	if hat_wheel.visible:
		# Only the interact key (F / X) or the SPIN button spins: never JUMP, which a touchscreen presses for any
		# tap on the right half (a paid spin by accident, audit H4).
		var pressed := Input.is_action_just_pressed("interact")
		if hat_wheel.spinning:
			return
		if Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel"):
			_sfx("click", 0.8)
			if not hat_wheel.back():  # Esc / B: the buy confirm first, then the overlay
				close_hat_wheel()
		elif (Input.is_action_just_pressed("tab_next") or Input.is_action_just_pressed("tab_prev")) and not hat_wheel.confirm.visible:
			hat_wheel.show_tab("shop" if hat_wheel.tab == "wheel" else "wheel")  # LB / RB: WHEEL <-> SHOP
		elif pressed and hat_wheel.tab == "wheel" and not hat_wheel.confirm.visible:
			if hat_wheel.spin():
				_spin_room_wheel()
				_refresh_tickets()
			elif not Progress.can_spin_hats():
				close_hat_wheel()  # (F on a wheel that can't spin: as before, it closes)
		return
	if coin_board.visible:
		var touch := _touch_controls != null and _touch_controls.visible
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel") \
				or (touch and Input.is_action_just_pressed("jump")):
			close_coin_board()
		return
	if tour != null and not slime.frozen and (Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_cancel")) \
			and tour.back_pressed():
		_sfx("click", 0.8)  # (Esc / B skips the tour first, and stays in the hub)
		return
	if Input.is_action_just_pressed("menu") and not slime.frozen:
		if home_tap:  # (iOS / Android: the touch home button goes straight to the title, D10)
			_sfx("click")
			slime.frozen = true
			UIKit.go(get_tree(), UIKit.TITLE_SCENE)
		else:
			open_hub_menu()  # Esc / START / the touch pause button: MENU (BACK, SETTINGS, QUIT TO TITLE)
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
			room_turned.emit(back_station().id, _turn_dir)
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
		var lit: bool = station == near or (tour != null and station.id == tour.lit_id())
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
	_turn_dir = direction
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
		# Front and back within VIEW_ARC of straight across / straight ahead, side views otherwise
		# (so stations on the diagonals settle on their side view instead of flickering).
		if absf(deg + 90.0) < VIEW_ARC:
			view = View.FRONT
		elif absf(deg - 90.0) < VIEW_ARC:
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
			best = {id = "rotor", name = Loc.t("hub.prompt.rotate", "ROTATE")}
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
	var price := false
	var line: String = tour.line_for(near.id) if tour != null and note == "" else ""
	prompt_name.text = near.name if line == "" else line
	if note != "":
		prompt_key.text = note
	elif line != "":
		prompt_key.text = tour.key_text()  # (the tour's line by the wheel: the key that turns the room)
	elif near.id == "story" and not Demo.level_open(Progress.current_level, Progress.hard_mode):
		prompt_key.text = Demo.full_game_text()  # (the demo: the next level is in the full game)
	elif (near.id == "random" and not Demo.randomizer_open()) or (near.id == "wheel" and not Demo.hat_wheel_open()):
		prompt_key.text = Demo.full_game_text()
	elif near.id == "random" and not Progress.is_randomizer_unlocked():
		prompt_key.text = Loc.t("hub.prompt.locked", "LOCKED")
	elif near.id == "random" and Economy.descent_on() and Progress.descent_best_floor > 0:
		prompt_key.text = Loc.t("hub.prompt.best_floor", "BEST FLOOR {floor}", {floor = Progress.descent_best_floor})  # Descent's record
	elif near.id == "wheel" and (Progress.hats_left().is_empty() or not (Progress.dev_tools or Hats.available)):
		prompt_key.text = Loc.t("hub.prompt.shop", "SHOP")  # every hat won: the overlay opens on its SHOP
	elif near.id == "wheel":
		var cost: int = Progress.spin_cost()  # the next spin's price, with the ticket icon
		prompt_key.text = Loc.t("hub.prompt.free", "FREE") if cost == 0 else str(cost)
		price = cost > 0
	else:
		prompt_key.text = ""  # just its name: the interact key uses it
	# "!" when something in that station's store is affordable (the cheapest unowned item).
	prompt_bang.visible = note == "" and near.id in ["wheel", "upgrades"] and Progress.store_affordable(near.id)
	prompt_icon.visible = price and note == ""
	prompt_key.visible = prompt_key.text != ""
	# (the goo's top room is the marks this line has: a line without any sits as in English)
	var margins := UIKit.panel_v_margins(prompt_name.text + prompt_key.text)
	if _prompt_style.content_margin_top != margins.x or _prompt_style.content_margin_bottom != margins.y:
		_prompt_style.content_margin_top = margins.x
		_prompt_style.content_margin_bottom = margins.y
	prompt.reset_size()
	var size := prompt.get_combined_minimum_size()
	prompt.size = size
	# Centered at the bottom, its goo drops clear of the screen edge: its bottom edge where the English
	# prompt's is; a taller prompt (accents, a taller script) first grows down, to PROMPT_LOW above the
	# safe area's bottom (its drops still inside), then up, so it keeps clear of the stations' sprites
	# (the coin bag's corner) as far as it can.
	var bottom := minf(PROMPT_Y + PROMPT_H, UIKit.safe_rect().end.y - 6.0)
	if size.y > PROMPT_H:
		bottom = maxf(bottom, minf(PROMPT_Y + size.y, UIKit.safe_rect().end.y - PROMPT_LOW))
	prompt.position = Vector2(roundf((320.0 - size.x) / 2.0), bottom - size.y)


## The station at the back of the room now (facing you across it).
func back_station() -> Dictionary:
	return stations[posmod(roundi(-turn / step), stations.size())]


func _station(id: String) -> Dictionary:
	for station in stations:
		if station.id == id:
			return station
	return {}


## Uses a station: opens its screen, or says why it can't.
func _use(station: Dictionary) -> void:
	if tour != null:
		tour.station_used(station.id)
	match station.id:
		"story":
			_leave(station, "res://scenes/level_select.tscn")
		"maps":
			_leave(station, MAP_SCENE)
		"wardrobe":
			_leave(station, "res://scenes/skins.tscn")
		"upgrades":
			_leave(station, "res://scenes/upgrades.tscn")
		"settings":
			_leave(station, "res://scenes/controls.tscn")
		"random":
			if Progress.is_randomizer_unlocked():
				if Economy.descent_on():
					open_portal_menu()  # RANDOM MAZE or DESCENT
				else:
					_begin_random_maze()  # Descent is cut (D11): straight into a random maze
			elif not Demo.randomizer_open():
				_deny(Demo.full_game_text())
			elif Demo.on():
				# i18n: hub prompt (demo build), max 110px, 1 line; {level} = the demo's last level
				_deny(Loc.t("hub.prompt.demo_clear", "CLEAR LEVEL {level}", {level = Demo.levels()}))
			else:
				_deny(Loc.t("hub.prompt.beat_all", "BEAT ALL {count} LEVELS", {count = Levels.COUNT}))
		"wheel":
			if Demo.hat_wheel_open():
				open_hat_wheel()
			else:
				_deny(Demo.full_game_text())
		"coins":
			open_coin_board()
		"quit":
			open_quit_menu()


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
