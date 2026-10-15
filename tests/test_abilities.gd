extends SceneTree

## ABILITIES v1 (docs/design/upgrades-v2.md "Abilities v1"): SLIME RIFLE (reveals exactly the floor
## tiles to the first wall, and the walls around them), SLIME SPLAT (lands up to 4 tiles ahead, reveals
## exactly the 3x3 around it), SLIMAKAZE (dashes to the wall, costs 30%, a deterministic splatter;
## never kills unless the meter holds <= 30%), fog bytes and survey tiles in step, charges per attempt
## and their refill, slime costs, the input actions (defaults 1 / 2 / 3, remapping, old saves keep
## their bindings), touch buttons, the HUD strip, off in hard mode / HEAT / with the flag off, on in
## the randomizer and Descent, par and payout untouched, the TICKETS tab purchase flow (exact tickets,
## confirm, max level, locked), saves and hostile values. Never touches the real save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_abilities.gd

const MAIN := preload("res://scenes/main.tscn")
const TILE := 16

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_check(Economy.abilities_on() and not Economy.workshop_on(), "abilities on, the workshop still off")
	await _rifle()
	await _splat()
	await _kaze()
	await _kaze_kill_and_refuse()
	await _charges()
	await _inputs()
	await _touch()
	await _modes()
	await _store()
	_saves()
	_bindings_migration()
	progress.reset_progress()
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- helpers

func _state(levels: Dictionary) -> void:
	Economy.abilities_force = -1
	progress.reset_progress()
	progress.saving_enabled = false
	progress.dev_tools = false
	progress.tutorial_seen = 3
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.hard_mode = false
	progress.mode = progress.MODE_STORY
	progress.abilities = levels.duplicate()


func _spawn(level := 1, random_seed := 0) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	if random_seed != 0:
		progress.mode = progress.MODE_RANDOM
		progress.random_seed = random_seed
		game.random_seed = random_seed
	elif level > 0:
		game.level = level
	root.add_child(game)
	await physics_frame
	await physics_frame
	return game


func _stop(game: Node2D) -> void:
	for id in Abilities.ids():
		Input.action_release(Abilities.action(id))
	game.free()
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _start_tile(game: Node2D) -> Vector2i:
	return Vector2i((game.slime.position / TILE).floor())


## Revealed fog cells in a tile (0-64).
func _revealed_cells(game: Node2D, tile: Vector2i) -> int:
	var rect: Rect2i = game._tile_cells(tile)
	var n := 0
	for cy in range(rect.position.y, rect.end.y):
		for cx in range(rect.position.x, rect.end.x):
			if game._fog_bytes.decode_u32((cy * game._cells.x + cx) * 4) >= 0x10000:
				n += 1
	return n


## Every maze tile's state: floor -> revealed cells, wall -> revealed (1/0).
func _snapshot(game: Node2D) -> Dictionary:
	var out := {}
	for y in game.maze.size.y:
		for x in game.maze.size.x:
			var t := Vector2i(x, y)
			out[t] = (1 if game.revealed_walls.has(t) else 0) if game.is_wall_tile(t) else _revealed_cells(game, t)
	return out


func _changed(before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in before:
		if before[t] != after[t]:
			out.append(t)
	return out


## A direction from the slime's tile with at least `min_tiles` floor tiles ahead (ZERO if none).
func _dir_with(game: Node2D, min_tiles: int) -> Vector2i:
	for d: Vector2i in MazeGenerator.DIRS:
		if Abilities.line_tiles(game.maze, _start_tile(game), d).size() >= min_tiles:
			return d
	return Vector2i.ZERO


func _aim(game: Node2D, dir: Vector2i) -> void:
	game.slime.facing = Vector2(dir)


# ---------------------------------------------------------------- SLIME RIFLE

func _rifle() -> void:
	_state({rifle = 1})
	var game := await _spawn(4)
	var dir := _dir_with(game, 2)
	_aim(game, dir)
	var tiles := Abilities.rifle_tiles(game.maze, _start_tile(game), dir)
	var wall: Vector2i = tiles[-1] + dir
	var before := _snapshot(game)
	var meter: float = game.slime_remaining
	_check(game.abilities != null and game.abilities.charges.rifle == 1, "SLIME RIFLE 1: one charge on the run")
	var fired: bool = game.abilities.use("rifle")
	game.abilities.flush()
	var after := _snapshot(game)
	var full := true
	var surveyed := true
	for t in tiles:
		full = full and after[t] == 64
		surveyed = surveyed and game.survey_tiles[t.y * game.maze.size.x + t.x] == 1
	_check(fired and full and after[wall] == 1 and surveyed,
		"the shot reveals all %d floor tiles to the wall (every fog cell), the wall it hits, and marks them seen" % tiles.size())
	var stray := []
	var path := {}
	for t in tiles:
		path[t] = true
	for t in _changed(before, after):
		if not game.is_wall_tile(t) and not path.has(t):
			stray.append(t)
		if game.is_wall_tile(t):
			var near := false
			for p in tiles:
				near = near or (absi(p.x - t.x) <= 1 and absi(p.y - t.y) <= 1)
			if not near:
				stray.append(t)
	_check(stray.is_empty(), "...and nothing else: only walls bordering the line change (stray %s)" % [stray])
	var beyond := wall + dir
	_check(game.is_wall_tile(beyond) or after[beyond] == before[beyond], "the tile past the wall stays as it was")
	var decoded: Dictionary = Main()._fog_decode(Color8(0, 0, 0, 0))
	var cell: Rect2i = game._tile_cells(tiles[-1])
	var v: int = game._fog_bytes.decode_u32((cell.position.y * game._cells.x + cell.position.x) * 4)
	decoded = Main()._fog_decode(Color8(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255))
	_check(decoded.revealed and not decoded.wall and absf(decoded.lit - game.elapsed) < 0.1,
		"a revealed floor cell decodes as floor, lit just now (fresh glow, then the usual fade)")
	var streak := 0
	var trail_cell := Rect2i(game._tile_cells(tiles[-1]))
	for cy in range(trail_cell.position.y, trail_cell.end.y):
		for cx in range(trail_cell.position.x, trail_cell.end.x):
			if game._trail_bytes[(cy * game._cells.x + cx) * 4 + 3] != 0:
				streak += 1
	_check(streak > 0 and streak <= 24, "a thin goo streak crosses the last tile (%d of 64 cells goo'd)" % streak)
	_check(is_equal_approx(meter - game.slime_remaining, Economy.ABILITIES.rifle.slime) and game.abilities.charges.rifle == 0,
		"one shot costs %.0f%% of the meter and its charge" % Economy.ABILITIES.rifle.slime)
	_check(not game.abilities.use("rifle"), "no charges left: it doesn't fire")
	await _stop(game)


func Main() -> GDScript:
	return load("res://scripts/game.gd")


# ---------------------------------------------------------------- SLIME SPLAT

func _splat() -> void:
	_state({splat = 1})
	var game := await _spawn(4)
	var dir := _dir_with(game, 2)
	_aim(game, dir)
	var land := Abilities.lob_tile(game.maze, _start_tile(game), dir)
	var ahead := Abilities.line_tiles(game.maze, _start_tile(game), dir)
	_check(land == ahead[mini(ahead.size(), Economy.SPLAT_RANGE) - 1], "the bomb lands %d tiles ahead at most, short of a wall" % Economy.SPLAT_RANGE)
	var before := _snapshot(game)
	game.abilities.use("splat")
	_check(not game.abilities.flying.is_empty(), "...it flies first (a lob)")
	game.abilities.flush()
	var after := _snapshot(game)
	var area := Abilities.burst_tiles(game.maze, land)
	var ok := area.size() == 9
	for t in area:
		ok = ok and (after[t] == 1 if game.is_wall_tile(t) else after[t] == 64)
	var stray := []
	for t in _changed(before, after):
		if not t in area:
			stray.append(t)
	_check(ok and stray.is_empty(), "the burst reveals exactly the 3x3 around the landing tile %s (stray %s)" % [land, stray])
	_check(game.abilities.get_children().any(func(c: Node) -> bool: return c is Sprite2D), "...with a fading glow")
	await _stop(game)
	# A wall right ahead: it bursts at the slime's own tile.
	_state({splat = 1})
	game = await _spawn(1)
	for d: Vector2i in MazeGenerator.DIRS:
		if game.is_wall_tile(_start_tile(game) + d):
			_check(Abilities.lob_tile(game.maze, _start_tile(game), d) == _start_tile(game), "against a wall the bomb lands at the slime's feet")
			break
	await _stop(game)


# ---------------------------------------------------------------- SLIMAKAZE

func _kaze() -> void:
	var results := []
	for run in 2:
		_state({kaze = 1})
		var game := await _spawn(6)
		var dir := _dir_with(game, 2)
		_aim(game, dir)
		var start := _start_tile(game)
		var stop := Abilities.dash_tile(game.maze, start, dir)
		var before := _snapshot(game)
		var meter: float = game.slime_remaining
		var fired: bool = game.abilities.use("kaze")
		await _frames(1)
		_check(fired and game.slime.state == Slime.State.DASH and game.slime.is_airborne(), "SLIMAKAZE: the slime dashes (no drain while it flies)")
		game.abilities.flush()
		var impact := Vector2i((game.slime.position / TILE).floor())
		_check(game.slime.position.is_equal_approx(Abilities.dash_point(stop, dir)) and impact == stop and game.slime.state == Slime.State.STUNNED,
			"...to the last floor tile before the wall %s, splatted (stunned)" % [stop])
		_check(is_equal_approx(meter - game.slime_remaining, Economy.ABILITIES.kaze.slime),
			"...costing %.0f%% of the meter (%.1f -> %.1f)" % [Economy.ABILITIES.kaze.slime, meter, game.slime_remaining])
		var blobs := Abilities.splatter(game.maze, impact, Abilities.splatter_seed(game.maze_seed, game.attempt, impact, 0))
		var after := _snapshot(game)
		var all_lit := true
		var in_zone := true
		for b in blobs:
			all_lit = all_lit and after[b.tile] == 64 and game.survey_tiles[b.tile.y * game.maze.size.x + b.tile.x] == 1
			in_zone = in_zone and Vector2(b.tile - impact).length() <= Economy.KAZE_RADIUS
		_check(blobs.size() >= 3 and all_lit and in_zone, "the splatter reveals %d tiles within %.1f tiles of the impact, all seen" % [blobs.size(), Economy.KAZE_RADIUS])
		var allowed := {}
		for b in blobs:
			allowed[b.tile] = true
		var t := start
		while true:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					allowed[t + Vector2i(dx, dy)] = true
			if t == stop:
				break
			t += dir
		var stray := []
		for c in _changed(before, after):
			if not allowed.has(c):
				var near := false
				for b in blobs:
					near = near or (absi(b.tile.x - c.x) <= 1 and absi(b.tile.y - c.y) <= 1)
				if not near or not game.is_wall_tile(c):
					stray.append(c)
		_check(stray.is_empty(), "nothing outside the dash lane, the splatter and their walls changes (stray %s)" % [stray])
		results.append(after)
		await _stop(game)
	_check(results[0] == results[1], "the same maze, attempt and impact splatter the same tiles (deterministic)")
	var maze: Dictionary = Levels.story_maze(6, false)
	var a := Abilities.splatter(maze, Vector2i(5, 5), 77)
	_check(a == Abilities.splatter(maze, Vector2i(5, 5), 77) and a != Abilities.splatter(maze, Vector2i(5, 5), 78) or a.size() <= 1,
		"splatter: same seed same tiles, another seed others")


func _kaze_kill_and_refuse() -> void:
	_state({kaze = 1})
	var game := await _spawn(6)
	var dir := _dir_with(game, 2)
	_aim(game, dir)
	game.slime_remaining = 20.0
	game.abilities.use("kaze")
	game.abilities.flush()
	await _frames(game.slime.splat_stun * 60 + 60)
	_check(game.slime_remaining == 0.0 and game.finished and not game.won, "SLIMAKAZE with 20% left (<= its 30%): the impact dries the slime up")
	await _stop(game)
	_state({kaze = 1})
	game = await _spawn(1)
	for d: Vector2i in MazeGenerator.DIRS:
		if game.is_wall_tile(_start_tile(game) + d):
			_aim(game, d)
			var meter: float = game.slime_remaining
			_check(not game.abilities.use("kaze") and game.abilities.charges.kaze == 1 and game.slime_remaining == meter,
				"a wall right ahead: SLIMAKAZE doesn't fire (charge and slime kept)")
			break
	await _stop(game)


# ---------------------------------------------------------------- charges

func _charges() -> void:
	for level in [1, 2, 3]:
		_check(Abilities.charges("rifle", level) == level and Abilities.charges("kaze", level) == level, "level %d = %d charges" % [level, level])
	_state({rifle = 2, splat = 3})
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	_check(game.abilities.charges == {rifle = 2, splat = 3} and game.abilities.levels.size() == 2, "owned abilities only, charges by level")
	var a: bool = game.abilities.use("rifle")
	game.abilities.flush()
	var b: bool = game.abilities.use("rifle")
	game.abilities.flush()
	var c: bool = game.abilities.use("rifle")
	_check(a and b and not c, "two shots, then none")
	var pods: int = game.hud.ability_row.get_child_count()
	_check(game.hud.ability_pod.visible and pods == 2, "the HUD strip shows the two owned abilities")
	game.slime_remaining = Economy.ABILITIES.splat.slime
	_check(not game.abilities.use("splat") and game.abilities.charges.splat == 3, "SPLAT needs more slime than it costs (never kills)")
	game.slime_remaining = 50.0
	game.slime.state = Slime.State.CHARGING
	_check(not game.abilities.use("splat"), "not while charging a leap (only gliding / still)")
	game.slime.state = Slime.State.GLIDE
	await _stop(game)
	game = await _spawn(4)  # a restart = a new attempt
	_check(game.abilities.charges == {rifle = 2, splat = 3}, "a restart refills every charge")
	await _stop(game)


# ---------------------------------------------------------------- inputs

func _inputs() -> void:
	_state({rifle = 1, splat = 1, kaze = 1})
	var keys := []
	for id in Abilities.ids():
		var events := InputMap.action_get_events(Abilities.action(id))
		keys.append((events[0] as InputEventKey).physical_keycode if not events.is_empty() else 0)
	_check(keys == [KEY_1, KEY_2, KEY_3], "actions ability_rifle / _splat / _kaze default to 1 / 2 / 3")
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	Input.action_press("ability_rifle")
	await _frames(2)
	Input.action_release("ability_rifle")
	_check(game.abilities.charges.rifle == 0, "pressing the rifle action fires it")
	await _stop(game)
	progress.set_binding("ability_splat", KEY_Q)
	var q := InputMap.action_get_events("ability_splat")
	_check(progress.bindings.ability_splat == KEY_Q and (q[0] as InputEventKey).physical_keycode == KEY_Q, "remappable: SLIME SPLAT on Q")
	progress.set_binding("ability_splat", KEY_SPACE)
	_check(progress.bindings.ability_splat == KEY_SPACE and progress.bindings.jump == KEY_Q, "taking JUMP's key swaps them")
	progress.reset_bindings()
	_check(progress.bindings.ability_splat == KEY_2 and progress.bindings.jump == KEY_SPACE, "RESET KEYS restores them")
	var page: Control = load("res://scenes/key_controls.tscn").instantiate()
	root.add_child(page)
	await process_frame
	var inside := true
	for action: String in page.key_buttons:
		inside = inside and Rect2(0, 20, 320, 120).encloses(page.key_buttons[action].get_global_rect())
	_check(page.key_buttons.size() == 10 and page.key_buttons.ability_kaze.text == "3" and inside, "the CONTROLS page lists the 3 ability keys (10 rows, all on screen)")
	page.free()


func _touch() -> void:
	_state({rifle = 1, kaze = 2})
	progress.force_touch = true
	var game := await _spawn(4)
	_aim(game, _dir_with(game, 1))
	var tc: TouchControls = game.touch_controls
	_check(tc.abilities.size() == 2 and tc.ability_at(TouchControls.ABILITY_SLOTS[0]) == 0 and tc.ability_at(TouchControls.ABILITY_SLOTS[1]) == 1
		and tc.ability_at(TouchControls.ABILITY_SLOTS[2]) == -1, "touch: a button per owned ability, in order")
	var jump_gap := TouchControls.ABILITY_SLOTS.all(func(p: Vector2) -> bool:
		return p.distance_to(TouchControls.JUMP_CENTER) > TouchControls.JUMP_RADIUS + TouchControls.ABILITY_RADIUS and p.x > 160.0)
	_check(jump_gap, "the buttons sit on the right half, clear of JUMP")
	tc._touch_down(3, TouchControls.ABILITY_SLOTS[0])
	await _frames(2)
	tc._touch_up(3)
	await _frames(1)
	_check(game.abilities.charges.rifle == 0 and not Input.is_action_pressed("ability_rifle") and not Input.is_action_pressed("jump"),
		"tapping the first button fires SLIME RIFLE (no JUMP, nothing left held)")
	progress.force_touch = false
	await _stop(game)


# ---------------------------------------------------------------- modes

func _modes() -> void:
	_state({rifle = 3})
	progress.hard_mode = true
	progress.hard_cleared.assign([1])
	var game := await _spawn(1)
	_check(game.abilities == null and not game.hud.ability_pod.visible and game.touch_controls.abilities.is_empty(), "hard mode: no abilities")
	await _stop(game)
	progress.heat_mods = 1  # DIM
	game = await _spawn(1)
	_check(game.heat > 0 and game.abilities == null, "a HEAT run (hard): no abilities")
	await _stop(game)
	progress.heat_mods = 0
	progress.hard_mode = false
	game = await _spawn(1)
	var par: float = game.par_time
	_check(game.abilities != null, "story normal: on")
	await _stop(game)
	_state({})
	game = await _spawn(1)
	_check(game.abilities == null and is_equal_approx(game.par_time, par), "no abilities owned: none; par is the same either way")
	await _stop(game)
	_state({rifle = 1})
	game = await _spawn(0, 4242)
	var pay: Dictionary = game.payout()
	_check(game.abilities != null, "randomizer: on")
	game.abilities.use("rifle")
	game.abilities.flush()
	_check(game.payout() == pay, "using one leaves the randomizer payout as it was (%s)" % [pay])
	await _stop(game)
	_state({kaze = 1})
	progress.start_descent(777)
	game = await _spawn(0)
	_check(game.descent and game.abilities != null and game.abilities.charges.kaze == 1, "Descent: on (charges per floor)")
	await _stop(game)
	_state({rifle = 1})
	Economy.abilities_force = 0
	game = await _spawn(1)
	_check(game.abilities == null and progress.ability_level("rifle") == 0 and progress.abilities.rifle == 1, "flag off: no abilities, the saved level kept")
	await _stop(game)
	Economy.abilities_force = -1


# ---------------------------------------------------------------- the TICKETS tab

func _store() -> void:
	_state({})
	progress.tickets = 0
	progress.tickets_lifetime = 0
	var script: GDScript = load("res://scripts/ui/upgrades_screen.gd")
	script.set("open_tab", "abilities")
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.page == "abilities" and screen.ability_page.visible and screen.ability_rows.size() == 3 and screen.abilities_tab.text == "TICKETS"
		and "EARN TICKETS" in screen.hint.text and screen.abilities_tab.has_focus(), "TICKETS tab: 3 abilities, locked before any ticket")
	screen.free()
	progress.tickets = 15
	progress.tickets_lifetime = 15
	script.set("open_tab", "abilities")
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var rows: Dictionary = screen.ability_rows
	_check(rows.rifle.cost.text == "15" and not rows.rifle.plus.disabled and rows.splat.plus.disabled and rows.rifle.tag.text == "SHOOTS GOO"
		and screen.coin_label.text == "15" and "1 2 3" in screen.hint.text, "15 tickets: SLIME RIFLE affordable (15), SPLAT (18) not; tag, pod and keys hint")
	rows.rifle.plus.pressed.emit()
	_check(screen.confirm.visible and screen.confirm_label.text == "BUY SLIME RIFLE 1?" and screen.confirm_price.text == "15" and progress.tickets == 15,
		"+ opens BUY SLIME RIFLE 1? (nothing spent yet)")
	screen.confirm_buy.pressed.emit()
	_check(progress.ability_level("rifle") == 1 and progress.tickets == 0 and not screen.confirm.visible and rows.rifle.cost.text == "30",
		"BUY: level 1 for exactly 15 tickets; the next costs 30")
	progress.abilities = {rifle = 3}
	progress.tickets = 999
	screen._refresh()
	_check(rows.rifle.cost.text == "MAX" and rows.rifle.plus.disabled and not rows.rifle.ticket.visible and not progress.buy_ability("rifle"),
		"max level: MAX, + off, can't buy")
	_check(progress.store_affordable("upgrades"), "the hub's '!' at the cauldron counts the abilities")
	await _press_ui(screen, "ui_cancel")
	screen.free()
	# The COINS page: no explanation lines left.
	script.set("open_tab", "coins")
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var texts := []
	for node in screen.coin_page.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var plain := texts.all(func(t: String) -> bool: return not ("->" in t or " PX" in t or "SLIME X" in t.to_upper() or "AREA" in t))
	_check(plain and "RECOMMENDED" in texts and "MORE SLIME" in texts, "COINS: names, bars, costs and the RECOMMENDED tag only (%s)" % [texts])
	screen.free()
	script.set("open_tab", "coins")


func _press_ui(_screen: Control, _action: String) -> void:
	await process_frame


# ---------------------------------------------------------------- saves

func _saves() -> void:
	_state({rifle = 2, kaze = 1})
	var file: ConfigFile = progress._write()
	_check(file.get_value("abilities", "rifle") == 2 and file.get_value("abilities", "kaze") == 1 and not file.has_section_key("abilities", "splat")
		and file.get_value("controls", "ability_splat") == KEY_2, "saved: [abilities] levels (owned only) and the ability keys")
	progress.abilities = {}
	progress._read_store(file)
	_check(progress.abilities == {rifle = 2, kaze = 1}, "read back")
	var hostile := ConfigFile.new()
	hostile.set_value("abilities", "rifle", 99)
	hostile.set_value("abilities", "splat", -4)
	hostile.set_value("abilities", "kaze", "lots")
	hostile.set_value("abilities", "laser", 3)
	progress._read_store(hostile)
	_check(progress.abilities == {rifle = 3}, "hostile values clamp (99 -> 3, -4 / text / unknown ids -> nothing): %s" % [progress.abilities])
	progress.abilities = {rifle = 3, splat = 3, kaze = 3}
	var code: String = progress.save_code()
	var back: ConfigFile = progress.read_code(code)
	_check(back != null and back.get_value("abilities", "splat") == 3 and code.length() < 4000, "a save code carries them (%d chars)" % code.length())
	progress.reset_progress()
	_check(progress.abilities.is_empty(), "RESET PROGRESS clears the abilities")


## A save from before the abilities with JUMP on 1 keeps every binding; the ability keys take spares.
func _bindings_migration() -> void:
	var file := ConfigFile.new()
	for action: String in ["move_up", "move_down", "move_left", "move_right", "restart", "interact"]:
		file.set_value("controls", action, progress.DEFAULT_KEYS[action])
	file.set_value("controls", "jump", KEY_1)
	progress._read_bindings(file)
	_check(progress.bindings.jump == KEY_1 and progress.bindings.ability_rifle == KEY_2 and progress.bindings.ability_splat == KEY_3
		and progress.bindings.ability_kaze == KEY_4, "an old save with JUMP on 1 keeps it; the abilities get 2 / 3 / 4 (%s)" % [progress.bindings])
	progress.reset_bindings()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
