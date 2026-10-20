extends Node

## Trailer director: plays ONE scripted moment of the real game (a "take") so the movie writer can
## record it. tools/trailer/trailer.py runs it once per take listed in tools/trailer/trailer.json:
##   godot --write-movie build/trailer/takes/ID/f.png --fixed-fps 60 --resolution 320x180 \
##       --quit-after N res://tools/trailer/take.tscn -- --take=MODE [game flags] [take flags]
## Game flags (--story-complete, --level=N, --skin=ID, --hard, --random, --trail=ID, --hat=ID,
## --tickets=N ...) are Progress's debug flags, so nothing is ever saved and the real save is never
## read (a res://tools/ scene is a tool run). The global RNG is seeded (--rng=N, default 1), so a
## take renders the same every time.
##
## Modes (--take=):
##   play     a story level (--level=N) or a randomizer maze (--random --seed=N) played by the
##            autopilot; the level is the current scene, so the real win flow (chalice, NEW RECORD,
##            medal, tickets) runs. --record = a fake slow old record (NEW RECORD! on the win),
##            --hide-hud, --pilot-at=F (frames before the autopilot starts), --leap=N (a charged
##            leap down the first straight N+ cell corridor of the route into its end wall: splat),
##            --skip=CELLS (start this many cells along the route, so a take opens mid-maze),
##            --bright (dev FULL BRIGHT; only with --unlock-all), --meter=P (start with P% slime:
##            the slime dries up on the way, the real dry-up screen).
##   win      a level won at once (the slime is dropped on the goal after --win-at=F frames): the
##            medal / tickets banner; --random --seed=N for a randomizer win (tickets).
##   hops     a level (--level=N) where the slime leaps back and forth along the longest straight
##            corridor, the hat popping off; --cycle=hat ids changes the hat every hop, --every=F,
##            --power=0..100 (leap charge), --lane-at=C (start C cells along the corridor).
##   skins    the wardrobe: flips through --cycle=a,b,c every --every=F frames; --jelly-at=F turns
##            JELLY on (every skin's see-through version).
##   hats     the wardrobe's HATS page flipping through --cycle=... (hats).
##   trails   the wardrobe's TRAILS page flipping through --cycle=... (trail styles).
##   wheel    the hub's hat wheel: opens at --open-at=F, spins at --spin-at=F (seeded, lands on a
##            hat), closes at --close-at=F (back to the hub, the new hat on).
##   hub      the hub; the slime glides right for --walk=F frames from --walk-at=F.
##   maps     the MAP TABLE with --open=N (that level's map view) on --paper=ID; --every=F flips to
##            the next owned paper every F frames (with --own-cosmetics=all).
##   title    the title screen.
## Any mode: RAINBOW / STOPWATCH skins are blacked out (see _black_out_secret_skins); --jelly = the see-through jelly version of the worn skin; --own-hats=a,b|all and
## --own-cosmetics=a,b|all = hats / shop trails and papers owned (so --hat=ID can be worn).

const MAIN := "res://scenes/main.tscn"

var mode := "play"
var opts := {}
var frame := 0
var game: Node2D
var pilot: Node
var screen: Node
var _cycle: Array = []
var _leap_frame := -1
var _leap_cell := Vector2i.ZERO
var _leap_dir := Vector2.ZERO
var _lane := {}
var _hops := 0
var _hop_wait := 40


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="):
			mode = arg.trim_prefix("--take=")
		elif arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif arg.begins_with("--"):
			opts[arg.trim_prefix("--")] = "1"
	seed(int(opts.get("rng", "1")))
	Progress.saving_enabled = false
	Progress.tutorial_seen = 3  # no first-time hints in the shots
	Progress.maps_hint_seen = true
	_black_out_secret_skins()
	if opts.has("jelly"):
		Progress.set_jelly(true)
	if opts.has("own-hats"):  # hats owned (a list, or "all"), so --hat=ID can be worn
		Progress.hats_owned.assign(_list("own-hats", Hats.ids()))
		if opts.has("hat"):
			Progress.selected_hat = String(opts.hat)
	if opts.has("own-cosmetics"):  # shop trails / papers owned (a list, or "all")
		Progress.cosmetics_owned.assign(_list("own-cosmetics", Cosmetics.ids()))
	if opts.has("cycle"):
		_cycle.assign(String(opts.cycle).split(","))
	# Outlive scene changes (hub / title flows): sit on the root, not under the current scene.
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	_start.call_deferred()


## Promo rule (owner, 2026-10-20): the RAINBOW and STOPWATCH skins never appear in colour in promo
## material. A take asked to wear one wears its level's first-run skin instead. In the wardrobe both
## show as the skins screen's own locked silhouettes (the "more to unlock" tease):
## - opaque RAINBOW: one story coin is taken out of the count (it needs every coin), so the screen
##   itself draws it locked ("LOCKED - FIND EVERY COIN");
## - STOPWATCH: locked as long as any medal is below gold (--story-complete has silver on 6-10; the
##   medal guard below keeps it so if the base flags ever give 30 golds);
## - jelly RAINBOW: it opens with hard level 10, like EMBER's and CHAMELEON's jelly, so instead of
##   un-clearing L10 its tile and preview are drawn as the locked silhouette here (_blackout_tiles,
##   _show_secret). The RAINBOW HAT is a hat and stays.
const SECRET_SKINS := [Skins.RAINBOW, Skins.STOPWATCH]


func _black_out_secret_skins() -> void:
	if Progress.selected_skin in SECRET_SKINS:
		var level_skin := Skins.skin_for_level(maxi(Progress.current_level - 1, 0))
		push_warning("trailer: %s is never shown in promos; wearing %s" % [Progress.selected_skin, level_skin])
		Progress.selected_skin = level_skin
	if mode in ["skins", "hats", "trails"]:
		for level in range(Levels.COUNT, 0, -1):
			var found: Array = Progress.coins_found.get(level, [])
			if not found.is_empty():
				found.pop_back()
				break
		if Progress.all_medals():  # guard (see above)
			Progress.medals[Levels.COUNT] = Progress.TIER_GOLD - 1


## A secret skin the screen would show unlocked in the current view (jelly rainbow).
func _secret_open(id: String) -> bool:
	return id in SECRET_SKINS and Progress.is_skin_unlocked(id, screen.view_jelly)


## Gives such a skin's grid tile the screen's locked look (black, still).
func _blackout_tiles() -> void:
	for id: String in SECRET_SKINS:
		if screen.tiles.has(id) and _secret_open(id):
			var preview: AnimatedSprite2D = screen.tiles[id].get_meta("preview")
			preview.modulate = Color(0, 0, 0, 0.85)
			preview.pause()


## Focusing such a skin: the locked silhouette on the stage and the screen's own locked line.
func _show_secret(id: String) -> void:
	screen.tiles[id].grab_focus()
	screen._refresh(id)
	screen.showcase.show_skin(screen._base_color(id), id == Skins.RAINBOW, screen.view_jelly, true, id == Skins.STOPWATCH)
	screen.status.text = Loc.t("skins.locked_jelly", "JELLY LOCKED - HARD CLEAR L{level}", {level = Skins.jelly_level(id)})  # i18n: ignore (the screen's own string)


func _list(key: String, all: Array[String]) -> Array:
	return Array(all) if opts[key] == "all" else Array(String(opts[key]).split(","))


func _int(key: String, fallback: int) -> int:
	return int(opts.get(key, str(fallback)))


func _start() -> void:
	await get_tree().process_frame
	match mode:
		"play", "win", "hops":
			_start_level()
		"skins", "hats", "trails":
			screen = load("res://scenes/skins.tscn").instantiate()
			_make_current(screen)
			await get_tree().process_frame
			if mode != "skins":
				screen.show_page(mode)
		"wheel", "hub":
			if mode == "wheel":
				Progress.spins = maxi(Progress.spins, 1)  # past the free first spin: a real ticket spin
			screen = load(UIKit.HUB_SCENE).instantiate()
			_make_current(screen)
		"maps":
			screen = load("res://scenes/maps.tscn").instantiate()
			_make_current(screen)
			await get_tree().process_frame
			if opts.has("open"):
				screen.open_view(_int("open", 1))
		"title":
			screen = load(UIKit.TITLE_SCENE).instantiate()
			_make_current(screen)


func _make_current(node: Node) -> void:
	var tree := get_tree()
	if tree.current_scene != null and tree.current_scene != self:
		tree.current_scene.queue_free()
	tree.root.add_child(node)
	tree.current_scene = node


func _start_level() -> void:
	var level := Progress.current_level
	game = load(MAIN).instantiate()
	if opts.has("random") or Progress.mode == Progress.MODE_RANDOM:
		var maze_seed := _int("seed", 777)
		Progress.start_random()
		Progress.random_seed = maze_seed
		game.random_seed = maze_seed
	else:
		var hard: bool = Progress.hard_mode
		Progress.start_story(level)
		Progress.hard_mode = hard
		game.level = level
		if opts.has("record"):
			Progress.best_times[level + (Progress.HARD_RECORDS if hard else 0)] = 999.0
	_make_current(game)
	await get_tree().process_frame
	if opts.has("hide-hud"):
		game.hud.visible = false
	if opts.has("bright"):
		game.set_dev_bright(true)
	if opts.has("skip"):
		var route := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
		var cell: Vector2i = route[mini(_int("skip", 0), route.size() - 2)]
		game.slime.position = MazeGenerator.cell_center(cell, game.TILE)
		game.last_slime_pos = game.slime.position  # (no trail painted across the jump)
	if opts.has("meter"):  # start with this much slime (percent): a short run to a real dry-up
		game.slime_remaining = float(opts.meter)
	if mode == "play" and not opts.has("pilot-at"):
		_add_pilot(opts.has("skip"))
	if mode == "hops":
		_lane = _longest_lane()
		var at: int = clampi(_int("lane-at", 0), 0, _lane.length)
		game.slime.position = MazeGenerator.cell_center(_lane.from + _lane.dir * at, game.TILE)
		game.last_slime_pos = game.slime.position


func _add_pilot(from_here := false) -> void:
	pilot = preload("res://tests/autopilot.gd").new()
	if from_here:
		var here := Vector2i((game.slime.position / float(game.TILE)).floor())
		pilot.cells = MazeGenerator.shortest_path(game.maze, here, game.maze.goal)
	game.add_child(pilot)
	if opts.has("leap") and _leap_frame < 0:
		_plan_leap.call_deferred()


func _physics_process(_delta: float) -> void:
	frame += 1
	match mode:
		"play":
			if opts.has("pilot-at") and frame == _int("pilot-at", 0):
				_add_pilot(opts.has("skip"))
			if opts.has("leap"):
				_leap_tick()
		"hops":
			if game != null and _lane.size() > 0:
				_hops_tick()
		"win":
			if game != null and frame == _int("win-at", 60):
				game.slime.position = game.goal.position
		"skins", "hats", "trails":
			if screen != null:
				_wardrobe_tick()
		"wheel":
			if screen == null:
				return
			if frame == _int("open-at", 40):
				screen.open_hat_wheel()
			elif frame == _int("spin-at", 90):
				if screen.hat_wheel.spin():
					screen._spin_room_wheel()
			elif frame == _int("close-at", 100000):
				screen.close_hat_wheel()
		"maps":
			var every := _int("every", 0)
			if screen != null and every > 0 and frame > _int("cycle-at", 40) and frame % every == 0:
				screen.cycle_paper()
		"hub":
			var at := _int("walk-at", 30)
			if frame == at:
				Input.action_press("move_right")
			elif frame == at + _int("walk", 90):
				Input.action_release("move_right")


## --leap=N: on the way, at the first straight run of N..7 cells along the route that ends in a wall
## (from route cell --leap-from=C on), the pilot steps aside and the slime charges (--charge=F
## frames, default 50) and leaps down it into the wall (the splat); --resume-after=F frames later
## (default 50) a fresh pilot takes the shortest route on from where it landed.
func _plan_leap() -> void:
	var route: Array[Vector2i] = pilot.cells if not pilot.cells.is_empty() else pilot.route()
	var want := _int("leap", 5)
	for i in range(_int("leap-from", 2), route.size() - 2):
		var dir: Vector2i = route[i + 1] - route[i]
		var k := 1
		while i + k + 1 < route.size() and route[i + k + 1] - route[i + k] == dir:
			k += 1
		if k >= want and k <= 7 and game.is_wall_tile(route[i + k] + dir):
			_leap_cell = route[i]
			_leap_dir = Vector2(dir)
			return
	push_warning("trailer: no straight run of %d cells for --leap" % want)


func _leap_tick() -> void:
	if _leap_frame < 0 and pilot != null and _leap_dir != Vector2.ZERO 			and game.slime.position.distance_to(MazeGenerator.cell_center(_leap_cell, game.TILE)) < 4.0:
		pilot.queue_free()
		pilot = null
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		game.slime.facing = _leap_dir
		Input.action_press("jump")
		_leap_frame = frame
	elif _leap_frame > 0 and frame == _leap_frame + _int("charge", 50):
		game.slime.facing = _leap_dir
		Input.action_release("jump")
	elif _leap_frame > 0 and frame == _leap_frame + _int("charge", 50) + _int("resume-after", 50):
		_add_pilot(true)


## --take=hops: the slime leaps back and forth along the level's longest straight corridor (as
## tests/demo_hat_hops.gd), its hat popping off each time; --cycle=hat ids swaps the hat on every hop.
func _hops_tick() -> void:
	game.slime_remaining = 100.0
	_hop_wait -= 1
	if _hop_wait > 0 or game.slime.state != Slime.State.GLIDE or game.slime.velocity.length() > 5.0:
		return
	_hop_wait = _int("every", 66)
	if not _cycle.is_empty() and game.hat != null:
		game.hat.setup(_cycle[_hops % _cycle.size()], game.slime.sprite, game.slime)
	game.slime.facing = Vector2(_lane.dir) * (1.0 if _hops % 2 == 0 else -1.0)
	game.slime.launch(float(opts.get("power", "70")))
	_hops += 1


func _longest_lane() -> Dictionary:
	var best := {from = game.maze.start, dir = Vector2i.RIGHT, length = 0}
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var cell := Vector2i(x, y)
				var length := 0
				while (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell):
					cell += dir
					length += 1
				if length > best.length or (length == best.length and dir.x != 0):
					best = {from = Vector2i(x, y), dir = dir, length = length}
	return best


func _wardrobe_tick() -> void:
	if opts.has("jelly-at") and frame == _int("jelly-at", 0) and not screen.view_jelly:
		screen._toggle_jelly()
	if mode == "skins":
		_blackout_tiles()
	var every := _int("every", 30)
	if _cycle.is_empty() or frame < _int("cycle-at", 20) or (frame - _int("cycle-at", 20)) % every != 0:
		return
	var i := ((frame - _int("cycle-at", 20)) / every) % _cycle.size()
	var id: String = _cycle[i]
	match mode:
		"skins":
			if _secret_open(id):
				_show_secret(id)
				return
			screen._on_tile(id)
			if screen.tiles.has(id):
				screen.tiles[id].grab_focus()
		"hats":
			if screen.hat_tiles.has(id):
				screen._on_hat_tile(id)
				screen.hat_tiles[id].grab_focus()
		"trails":
			if screen.trail_tiles.has(id):
				screen._on_trail_tile(id)
				screen.trail_tiles[id].grab_focus()
