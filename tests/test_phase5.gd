extends SceneTree

## Phase 5 checks: skins unlock and recolor slime/trail/HUD, the custom color unlocks after the
## game is beaten, key remapping works and saves, walls and floor dim together, randomizer mazes
## are always completable (and beatable), and the menu screens build correctly.
## Uses a throwaway save file; your real save is never written.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_phase5.gd

const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")
const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")
const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node
var last_result := -1


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	_reset_progress()

	# --- Skins
	var starter: Color = Skins.get_preset(Skins.DEFAULT).color
	_check(Skins.PRESETS.size() == 10 and starter.g > starter.r and starter.g > starter.b, "10 preset skins; the starter (Lime) is green")
	var matched := true
	for level in range(2, Levels.COUNT + 1):  # each level's first-run skin suits its theme
		matched = matched and Skins.get_preset(progress.forced_skin_for(level)).unlock == level - 1
	_check(matched and progress.forced_skin_for(10) == "ember" and progress.forced_skin_for(7) == "frost",
		"skins unlock in theme order (Frost for the Frozen Fortress, Ember for the Volcanic Vault)")
	var unlock_levels := {}
	for preset: Dictionary in Skins.PRESETS:
		unlock_levels[preset.unlock] = true
	_check(unlock_levels.size() == 10 and Skins.unlock_level(Skins.CUSTOM) == 10, "a new skin per level 1-9; custom after level 10")
	progress.select_skin("ocean")
	_check(progress.selected_skin == Skins.DEFAULT, "locked skins can't be selected")
	progress.levels_cleared = 3
	progress.select_skin("ocean")
	_check(progress.skin_color() == Skins.get_preset("ocean").color, "clearing level 3 unlocks Ocean")
	progress.selected_skin = Skins.CUSTOM
	_check(progress.skin_color() == starter, "the custom skin stays locked before beating the game")
	progress.levels_cleared = 10
	progress.custom_color = Color(0.2, 0.4, 1.0)
	_check(progress.skin_color() == Color(0.2, 0.4, 1.0), "after level 10 the custom color applies")

	# --- Skin in game: slime, trail and HUD all use it.
	_reset_progress()
	progress.levels_cleared = 3  # Ocean unlocks with level 3
	progress.select_skin("ocean")
	var game := await _spawn({level = 1})
	var ocean_mid: Color = Skins.shades(Skins.get_preset("ocean").color).mid
	var slime_mid: Color = (game.slime.sprite.material as ShaderMaterial).get_shader_parameter("mid")
	var start: Vector2 = game.slime.position
	var trail: Color = game.trail_image.get_pixelv(game._cell_at(start))
	_check(slime_mid.is_equal_approx(ocean_mid), "slime sprite is recolored to the skin")
	_check(_close(trail, ocean_mid) or _close(trail, Skins.shades(Skins.get_preset("ocean").color).dark),
		"goo trail is the skin's color")
	_check(game.hud.fill.color == Skins.get_preset("ocean").color, "slime meter is the skin's color")

	# --- Walls and floor dim in lockstep.
	var wall_point := Vector2(start.x, 8.0)
	var floor_now: float = game.fog_alpha_at(start)
	var wall_now: float = game.fog_alpha_at(wall_point)
	var path := MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var far := MazeGenerator.cell_center(path[path.size() / 2], 16)
	game.slime.position = far
	game.last_slime_pos = far
	var lockstep := absf(wall_now - (floor_now + (1.0 - floor_now) * game.WALL_FOG_ALPHA)) < 0.01
	var steps := []
	for wait in [4.0, 5.0, 4.0]:
		await _wait(wait)
		var f: float = game.fog_alpha_at(start)
		var w: float = game.fog_alpha_at(wall_point)
		lockstep = lockstep and absf(w - (f + (1.0 - f) * game.WALL_FOG_ALPHA)) < 0.01
		steps.append("%.2f/%.2f" % [f, w])
	_check(lockstep, "wall next to the trail dims at the same moments as the floor (floor/wall: %s)" % ", ".join(steps))
	game.free()

	# --- Key remapping
	_reset_progress()
	progress.set_binding("jump", KEY_J)
	_check(_has_key("jump", KEY_J) and not _has_key("jump", KEY_SPACE), "jump can be remapped to J")
	progress.set_binding("restart", KEY_J)
	_check(progress.bindings.restart == KEY_J and progress.bindings.jump == KEY_R, "taking a used key swaps the two actions' keys")
	progress.set_binding("move_up", KEY_I)
	_check(_has_key("move_up", KEY_I) and _has_key("move_up", KEY_UP), "remapped movement keeps the arrow keys")
	var reloaded: Node = PROGRESS_SCRIPT.new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.bindings == progress.bindings, "key bindings are saved and loaded")
	reloaded.free()
	progress.reset_bindings()
	_check(_has_key("jump", KEY_SPACE) and _has_key("move_up", KEY_W), "reset restores the default keys")

	# --- Randomizer: always completable, and different every time.
	var all_ok := true
	var shortest := 9999
	var with_loops := 0
	var seen := {}
	for i in 300:
		var seed_value := 1000 + i * 7919
		var config := Levels.random_config(seed_value)
		var maze := MazeGenerator.generate_noise(config.cells, seed_value)
		all_ok = all_ok and MazeGenerator.is_completable(maze)
		shortest = mini(shortest, maze.goal_steps)
		seen[maze.walls] = true
		var passages := 0
		for y in maze.cells.y:
			for x in maze.cells.x:
				passages += MazeGenerator.open_neighbors(maze, Vector2i(x, y)).size()
		if passages / 2 > maze.cells.x * maze.cells.y - 1:
			with_loops += 1
	_check(all_ok, "300 random mazes: every cell reachable, chalice always reachable")
	_check(seen.size() == 300, "every seed gives a different maze")
	_check(shortest >= 15, "random mazes always have a real route (shortest: %d cells)" % shortest)
	_check(with_loops > 200, "noise adds loops to most random mazes (%d/300)" % with_loops)
	for seed_value in [11, 22222, 987654321]:
		game = await _spawn({random_seed = seed_value})
		game.add_child(AUTOPILOT.new())
		for i in 60 * 120:
			if game.finished:
				break
			await physics_frame
		_check(last_result == 1 and game.slime_remaining > 0.0,
			"random maze %d (%dx%d) beaten with %.0f%% slime left" % [seed_value, game.maze.cells.x, game.maze.cells.y, game.slime_remaining])
		game.free()

	# --- Menu screens
	_reset_progress()
	progress.highest_unlocked = 3
	progress.levels_cleared = 2
	progress.levels_cleared = 2
	var screen: Control = await _open("res://scenes/level_select.tscn")
	var enabled: int = screen.level_buttons.filter(func(b: Button) -> bool: return not b.disabled).size()
	_check(enabled == 3, "level select: levels 1-3 open, the rest locked (%d open)" % enabled)
	screen.free()
	screen = await _open("res://scenes/skins.tscn")
	_check(screen.tiles.size() == 12 and not screen.custom_panel.visible, "skins screen: 12 tiles, color wheel hidden until unlocked")
	screen._refresh(Skins.RAINBOW)
	_check("FIND EVERY COIN" in screen.status.text, "the rainbow skin says to find every coin (%s)" % screen.status.text)
	screen._on_tile("mint")
	var actor: AnimatedSprite2D = screen.showcase.slime
	var actor_start := actor.position
	for i in 90:
		await process_frame
	_check(screen.showcase.visible and actor.position != actor_start and actor.animation != "idle",
		"clicking a skin plays it on the preview stage (now %s at %s)" % [actor.animation, actor.position])
	screen._on_tile(Skins.RAINBOW)
	_check(screen.showcase.slime != actor and screen.showcase.slime.modulate.r == 0.0, "...a locked one as a silhouette")
	screen.free()
	progress.levels_cleared = 10
	progress.selected_skin = Skins.CUSTOM
	screen = await _open("res://scenes/skins.tscn")
	_check(screen.custom_panel.visible, "after beating the game the color wheel shows")
	screen._refresh(Skins.RAINBOW)
	_check("FIND EVERY COIN" in screen.status.text, "...even after level 10 it still wants every coin (%s)" % screen.status.text)
	screen.free()
	screen = await _open("res://scenes/controls.tscn")
	_check(screen.key_buttons.size() == 7 and screen.key_buttons.jump.text == "SPACE" and screen.key_buttons.interact.text == "F",
		"controls screen lists 7 actions (jump = %s, interact = %s)" % [screen.key_buttons.jump.text, screen.key_buttons.interact.text])
	screen.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _reset_progress() -> void:
	progress.levels_cleared = 0
	progress.highest_unlocked = 1
	progress.current_level = 1
	progress.selected_skin = Skins.DEFAULT
	progress.mode = progress.MODE_STORY
	progress.reset_bindings()


func _spawn(settings: Dictionary) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	last_result = -1
	game.level_finished.connect(func(won: bool) -> void: last_result = 1 if won else 0)
	await physics_frame
	return game


func _open(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	await process_frame
	return screen


func _has_key(action: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _wait(seconds: float) -> void:
	for i in int(seconds * 60):
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
