class_name Autoplay
extends Node

## `--autoplay` (tools/play.sh --autoplay [--speed=N]): the game plays the whole story campaign by
## itself, on screen, from a fresh in-memory state (progress.enable_autoplay: the real save is never
## read or written). An omniscient bot that knows the maze graph (AutoplayPlanner) plays the REAL
## game: real level scenes, physics, meter, coins, result screens, the restart prompt and the
## upgrades screen (buying through progress.buy_upgrade like the + button), real medal timing.
##
## Normal mode, each level 1-10: coin runs (as many coins as fit in the real meter, ending at the
## chalice when that loses nothing, otherwise ending with R -> RESTART), spending coins between
## runs (R prompt -> UPGRADES, priority MORE SLIME, SPEED, BRIGHTNESS), until every coin of the
## level is found; then a clean run on the shortest route for the medal (gold unless the timing
## says otherwise; up to GOLD_TRIES). Then hard mode 1-10 (no coins or upgrades there): the shortest
## route, walking (no leaps). Ends in the hub with AUTOPLAY COMPLETE and hands over control.
## F10 (fn+F10 on a Mac) stops it at once and hands over control where it is; leaving a level
## through the pause menu (Esc -> QUIT TO HUB) stops it too.
## Flags (after --): --speed=N (Engine.time_scale, default 3, 1-8; the physics tick rate rises
## with it so every tick is still 1/60 s of game time and runs play exactly as at 1x),
## --autoplay-cinematics (also play the story intro and finale), --autoplay-hold=S (scale the
## on-screen pauses, e.g. 0.05 for tests), --autoplay-quit (quit when done, printing a summary).

const FLAG := "--autoplay"
const CINEMATICS_FLAG := "--autoplay-cinematics"
const DEFAULT_SPEED := 3.0
const MAX_SPEED := 8.0
const STOP_KEY := KEY_F10
## Real-time pauses (seconds; x --autoplay-hold) so each moment can be seen.
const HOLD_MENU := 1.0
const HOLD_RESULT := 2.0
const HOLD_PROMPT := 0.6
const HOLD_SHOP_START := 0.6
const HOLD_SHOP_STEP := 0.35
const HOLD_SHOP_END := 1.4
const HOLD_DONE := 6.0
const HOLD_STOPPED := 2.5
## Clean runs per level and mode at most when the medal isn't gold yet.
const GOLD_TRIES := 3
## Runs per level and mode at most (a safety net; the plan needs far fewer).
const MAX_RUNS := 40

enum Phase { NORMAL, HARD, DONE }

var speed := DEFAULT_SPEED
var hold_scale := 1.0
var cinematics := false
var quit_when_done := false
var phase := Phase.NORMAL
var banner: AutoplayBanner
## Runs started per "n3" / "h3" (mode + level), clean (medal) runs, dry-ups, and coin runs that
## picked up nothing (coins out of reach).
var runs := {}
var clean_runs := {}
var dry_ups := 0
var unreachable := {}
## Honest notes about goals not met (also logged and shown at the end).
var notes: Array[String] = []
## Every run: {mode, level, attempt, kind, planned_coins, coins, tiles, meter, won, time, par, tier}.
var log_runs: Array[Dictionary] = []
var game_time := 0.0
var _start_ms := 0
var _start_frame := 0
var _scene: Node
var _token := 0
var _stopped := false
var _bot_pause := false
var _player_paused := false
var _base_ticks := 60
var _base_steps := 8
var _base_bus_db := 0.0
var _story_speed := false
var _status := "AUTOPLAY"
## The autoloads, looked up at run time (this script also loads where they aren't registered names).
@onready var progress: Node = get_node("/root/Progress")
@onready var transition: Node = get_node("/root/Transition")


## True when this launch asked for the autoplay (never on the web build).
static func requested(args: PackedStringArray) -> bool:
	if Platform.has_js():
		return false
	return FLAG in args or CINEMATICS_FLAG in args


func _ready() -> void:
	name = "Autoplay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			speed = clampf(arg.trim_prefix("--speed=").to_float(), 1.0, MAX_SPEED)
		elif arg.begins_with("--autoplay-hold="):
			hold_scale = maxf(arg.trim_prefix("--autoplay-hold=").to_float(), 0.0)
		elif arg == CINEMATICS_FLAG:
			cinematics = true
		elif arg == "--autoplay-quit":
			quit_when_done = true
	_start_ms = Time.get_ticks_msec()
	_start_frame = Engine.get_process_frames()
	_base_ticks = Engine.physics_ticks_per_second
	_base_steps = Engine.max_physics_steps_per_frame
	_base_bus_db = AudioServer.get_bus_volume_db(0)
	_set_speed(speed)
	# Sounds don't speed up, but they come N times as often: a little quieter above 1x.
	AudioServer.set_bus_volume_db(0, _base_bus_db - 10.0 * log(speed) / log(10.0) * 0.9)
	banner = AutoplayBanner.new()
	add_child(banner)
	_say("start: speed %.1fx, cinematics %s, fresh in-memory state (save path %s, saving %s)"
		% [speed, "on" if cinematics else "off", progress.save_path, "ON" if progress.saving_enabled else "off"])


## Engine.time_scale = `factor`, with the physics tick rate raised to match so a tick is still 1/60 s
## of game time (the simulation is the same as at 1x, only more ticks per real second).
func _set_speed(factor: float) -> void:
	Engine.time_scale = factor
	Engine.physics_ticks_per_second = roundi(_base_ticks * factor)
	Engine.max_physics_steps_per_frame = maxi(_base_steps, ceili(factor) * 2 + 2)


func _restore_engine() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _base_ticks
	Engine.max_physics_steps_per_frame = _base_steps
	AudioServer.set_bus_volume_db(0, _base_bus_db)


func _exit_tree() -> void:
	_restore_engine()


func _input(event: InputEvent) -> void:
	if _stopped:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == STOP_KEY or key.physical_keycode == STOP_KEY):
		get_viewport().set_input_as_handled()
		stop("F10")


func _process(_delta: float) -> void:
	if _stopped:
		return
	var tree := get_tree()
	var scene := tree.current_scene
	if scene != null and scene != _scene:
		if _player_paused and _token > 0:  # (the old scene is freed by now, so == null)
			stop("PAUSE MENU")  # left the level from the pause menu: the player takes over
			return
		_scene = scene
		_token += 1
		_on_scene(scene, _token)
	# Cleared only once the same scene plays on (a scene change leaves current_scene null for a
	# frame and drops the wipe's busy flag the frame the new scene arrives).
	# (A level stays paused under the wipe that leaves it from the R prompt's UPGRADES or the pause
	# menu's QUIT TO HUB; that pause isn't a new one: the player can't pause while a wipe runs.)
	if tree.paused and not _bot_pause and not transition.busy:
		_player_paused = true  # the player opened the pause menu: the bot waits
	elif not tree.paused and not transition.busy and scene != null and scene == _scene:
		_player_paused = false
	_refresh_banner()


# ---------------------------------------------------------------- scenes

func _on_scene(scene: Node, token: int) -> void:
	var path := scene.scene_file_path
	var story := path == Story.SCENE
	if story != _story_speed:  # cinematics play at their own pace
		_story_speed = story
		_set_speed(1.0 if story else speed)
	match path:
		UIKit.TITLE_SCENE:
			if await _hold(HOLD_MENU, token):
				_press(scene.enter_button)
		UIKit.HUB_SCENE:
			if phase == Phase.DONE:
				_complete(token)
			elif await _hold(HOLD_MENU, token):
				scene._use(scene._station("story"))
		"res://scenes/level_select.tscn":
			_drive_level_select(scene, token)
		UIKit.GAME_SCENE:
			_drive_game(scene, token)
		"res://scenes/upgrades.tscn":
			_drive_upgrades(scene, token)
		"res://scenes/victory.tscn":
			phase = Phase.HARD if phase == Phase.NORMAL else Phase.DONE
			if await _hold(HOLD_RESULT, token):
				_press(scene.buttons[2])  # HUB


func _drive_level_select(screen: Control, token: int) -> void:
	var hard := phase == Phase.HARD
	if not await _hold(HOLD_MENU, token):
		return
	if progress.hard_mode != hard:
		screen.hard_mode_box.button_pressed = hard  # the real checkbox (progress.set_hard_mode)
		if not await _hold(HOLD_MENU * 0.6, token):
			return
	var level := 1
	for i in range(1, Levels.COUNT + 1):
		if not _level_done(i, hard):
			level = i
			break
	_press(screen.level_buttons[level - 1])


func _drive_upgrades(screen: Control, token: int) -> void:
	if not await _hold(HOLD_SHOP_START, token):
		return
	var bought: Array[String] = []
	var id := _next_purchase()
	while id != "":
		var before: int = progress.upgrade_level(id)
		_press(screen.rows[id].plus)  # the + button: progress.buy_upgrade + its power-up sound
		if progress.upgrade_level(id) == before:
			break  # (never: the planner only picks what the coins pay for)
		bought.append("%s %d" % [id.to_upper(), progress.upgrade_level(id)])
		if not await _hold(HOLD_SHOP_STEP, token):
			return
		id = _next_purchase()
	_say("upgrades: bought %s (coins left %d)" % [", ".join(bought) if not bought.is_empty() else "nothing", progress.coins()])
	if not await _hold(HOLD_SHOP_END, token):
		return
	for child in screen.get_children():
		if child is Button and (child.text == "PLAY" or child.text == "BACK"):
			_press(child)
			return


# ---------------------------------------------------------------- playing a level

func _drive_game(game: Node, token: int) -> void:
	var hard: bool = game.hard_mode
	var level: int = game.level
	if game.is_random():
		stop("RANDOMIZER")
		return
	var key := _key(level, hard)
	# Coins in hand that buy the next upgrade: R -> RESTART? prompt -> UPGRADES first.
	if not hard and _next_purchase() != "":
		if not await _until(func() -> bool: return not transition.busy, token):
			return
		_open_restart_prompt(game, token, true)
		return
	var left := _coins_left(level, hard)
	var plan: Dictionary
	var kind := "clean"
	if not left.is_empty() and not unreachable.has(level):
		plan = AutoplayPlanner.plan_coin_run(game.maze, left, AutoplayPlanner.meter_tiles(game.slime_cost_per_tile))
		kind = "coins"
		if plan.coins.is_empty():
			unreachable[level] = true
			_note("L%d: %d coins out of reach of one meter, left behind" % [level, left.size()])
			plan = AutoplayPlanner.fastest_run(game.maze)
			kind = "clean"
	else:
		plan = AutoplayPlanner.fastest_run(game.maze)
	runs[key] = int(runs.get(key, 0)) + 1
	if kind == "clean":
		clean_runs[key] = int(clean_runs.get(key, 0)) + 1
	var meter := AutoplayPlanner.meter_tiles(game.slime_cost_per_tile)
	var entry := {mode = "hard" if hard else "normal", level = level, attempt = runs[key], kind = kind,
		planned_coins = plan.coins.size(), coins = 0, tiles = plan.tiles, meter = meter,
		ends_at_goal = plan.ends_at_goal, won = false, time = 0.0, par = game.par_time, tier = 0}
	log_runs.append(entry)
	var found_before: int = progress.coins_found_in(level)
	var pilot := RoutePilot.new()
	pilot.name = "AutoplayPilot"
	pilot.cells = plan.cells
	game.add_child(pilot)
	_say("%s L%d attempt %d: %s run, %d coins planned, %.1f of %.1f tiles (%.0f%% of the meter)%s [%.1f s, frame %d, %d fps]"
		% [entry.mode, level, entry.attempt, kind, plan.coins.size(), plan.tiles, meter,
		plan.tiles / meter * 100.0, "" if plan.ends_at_goal else ", then restart",
		(Time.get_ticks_msec() - _start_ms) / 1000.0, Engine.get_process_frames() - _start_frame, Engine.get_frames_per_second()])
	if not plan.ends_at_goal:
		await _until(func() -> bool: return pilot.is_inside_tree() and pilot._done or game.finished, token)
		if not _alive(token):
			return
		if not game.finished:
			entry.coins = progress.coins_found_in(level) - found_before
			entry.time = game.run_time
			game_time += game.run_time
			_say("  restart after %d coins, %.0f%% slime left" % [entry.coins, game.slime_remaining])
			_open_restart_prompt(game, token, false)
			return
	if not await _until(func() -> bool: return game.finished, token):
		return
	entry.coins = progress.coins_found_in(level) - found_before
	entry.time = game.run_time
	entry.won = game.won
	game_time += game.run_time
	if game.won:
		entry.tier = int(game.reward.get("tier", 0))
		_say("  WON in %s (par %s): %s, %d coins, %.0f%% slime left"
			% [UIKit.format_time(game.run_time), UIKit.format_time(game.par_time),
			["no medal", "BRONZE", "SILVER", "GOLD"][entry.tier], entry.coins, game.slime_remaining])
	else:
		dry_ups += 1
		_say("  DRIED UP after %d coins (planned %.1f tiles of %.1f)" % [entry.coins, plan.tiles, meter])
	if not await _until(func() -> bool: return _choices_shown(game), token):
		return
	if not await _hold(HOLD_RESULT if game.won else HOLD_MENU, token):
		return
	var buttons: Array = game.hud.choice_buttons
	if not game.won:
		# RESTART, or UPGRADES (the last button) when coins buy something.
		_press(buttons[-1] if not hard and _next_purchase() != "" else buttons[0])
		return
	if _wants_more(level, hard):
		_press(buttons[0])  # REPLAY
	else:
		if progress.medals_for(level) < progress.TIER_GOLD:
			_note("%s L%d: best medal %s after %d clean runs (gold needs %s)" % ["HARD" if hard else "NORMAL",
				level, ["NONE", "BRONZE", "SILVER", "GOLD"][progress.medals_for(level)], clean_runs.get(key, 0),
				UIKit.format_time(game.par_time)])
		_press(buttons[1])  # NEXT LEVEL / CONTINUE


## Ends an open coin run (or starts a shopping trip) through the real R key: the RESTART? prompt
## (coins in hand), then UPGRADES when coins buy something, else RESTART.
func _open_restart_prompt(game: Node, token: int, shopping: bool) -> void:
	_bot_pause = true
	var prompt: RestartPrompt = game.restart_prompt
	var press := InputEventAction.new()
	press.action = "restart"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = "restart"
	Input.parse_input_event(release)
	await _frames(3)
	if not _alive(token):
		_bot_pause = false
		return
	if not prompt.visible and progress.coins() > 0:
		prompt.open()  # (the key went elsewhere: open it the same way R does)
	if prompt.visible:
		if not await _hold(HOLD_PROMPT, token):
			_bot_pause = false
			return
		_press(prompt.buttons[1] if not game.hard_mode and _next_purchase() != "" else prompt.buttons[0])
	elif not shopping and not game.finished and game == get_tree().current_scene:
		game.retry("R")  # no coins in hand: R restarts at once (this is what it does)
	_bot_pause = false


## Whether to play this level again: coins left to find (normal), or no gold yet (a few tries).
func _wants_more(level: int, hard: bool) -> bool:
	var key := _key(level, hard)
	if int(runs.get(key, 0)) >= MAX_RUNS:
		_note("%s L%d: stopped after %d runs" % ["HARD" if hard else "NORMAL", level, MAX_RUNS])
		return false
	if not hard and not _coins_left(level, hard).is_empty() and not unreachable.has(level):
		return true
	return progress.medals_for(level) < progress.TIER_GOLD and int(clean_runs.get(key, 0)) < GOLD_TRIES


func _level_done(level: int, hard: bool) -> bool:
	var cleared: bool = (level in progress.hard_cleared) if hard else level <= progress.levels_cleared
	var medal := int(progress.medals.get(level + (progress.HARD_RECORDS if hard else 0), 0))
	return cleared and medal >= progress.TIER_GOLD and (hard or _coins_left(level, false).is_empty())


func _coins_left(level: int, hard: bool) -> Array[Vector2i]:
	var left: Array[Vector2i] = []
	if hard:
		return left
	for cell in Levels.story_coin_cells(level):
		if not progress.has_coin(level, cell):
			left.append(cell)
	return left


func _next_purchase() -> String:
	var levels := {}
	for id in AutoplayPlanner.PURCHASE_ORDER:
		levels[id] = progress.upgrade_level(id)
	return AutoplayPlanner.next_purchase(levels, progress.coins())


func _choices_shown(game: Node) -> bool:
	var buttons: Array = game.hud.choice_buttons
	return not buttons.is_empty() and is_instance_valid(buttons[0]) and buttons[0].is_visible_in_tree()


static func _key(level: int, hard: bool) -> String:
	return ("h%d" if hard else "n%d") % level


# ---------------------------------------------------------------- the end

func _complete(token: int) -> void:
	var wall := (Time.get_ticks_msec() - _start_ms) / 1000.0
	_status = "AUTOPLAY COMPLETE"
	_say("COMPLETE: coins %d/%d, medals %d/%d normal, %d/%d hard, %d runs, %d dry-ups, game time %.0f s, wall time %.0f s at %.1fx"
		% [progress.coins_earned(), Levels.total_coins(), progress.medals_total(false), progress.medals_max(),
		progress.medals_total(true), progress.medals_max(), log_runs.size(), dry_ups, game_time, wall, speed])
	for note in notes:
		_say("  not met: " + note)
	_restore_engine()
	print("AUTOPLAY SUMMARY " + JSON.stringify(summary(wall)))
	if not await _hold(HOLD_DONE, token):
		return
	_finish()


## Everything a test needs to check the run (and that the medals came from real timing).
func summary(wall := 0.0) -> Dictionary:
	var times := {}
	for key: int in progress.best_times:
		times[str(key)] = progress.best_times[key]
	var tiers := {}
	for key: int in progress.medals:
		tiers[str(key)] = progress.medals[key]
	var maps := {}  # the trail map surveys its real runs recorded (key -> clear, best ms, moves)
	for key: int in progress.maps:
		var survey: Dictionary = progress.maps[key]
		maps[str(key)] = {clear = survey.clear, best_ms = survey.best_ms, moves = survey.moves.size()}
	return {
		maps = maps,
		coins = progress.coins_earned(), total_coins = Levels.total_coins(),
		levels_cleared = progress.levels_cleared, hard_cleared = progress.hard_cleared,
		medals_normal = progress.medals_total(false), medals_hard = progress.medals_total(true),
		best_times = times, medals = tiers, upgrades = progress.upgrades, runs = log_runs,
		dry_ups = dry_ups, notes = notes, game_time = game_time, wall_time = wall, speed = speed,
		save_path = progress.save_path, saving = progress.saving_enabled, story_seen = progress.story_seen,
		scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		# Frames shown since the start: frames / 60 is the wall time on a screen keeping 60 fps
		# (with --fixed-fps 60 every frame stands for 1/60 s, however fast the machine renders).
		frames = Engine.get_process_frames() - _start_frame,
		time_scale = Engine.time_scale, ticks = Engine.physics_ticks_per_second,
	}


## Stops the autoplay where it is: the player takes over (the pilot lets go of the keys).
func stop(reason: String) -> void:
	if _stopped:
		return
	_stopped = true
	_say("stopped (%s); the player has control" % reason)
	var scene := get_tree().current_scene
	if scene and scene.has_node("AutoplayPilot"):
		scene.get_node("AutoplayPilot").queue_free()
	_restore_engine()
	banner.show_lines("AUTOPLAY STOPPED - YOUR TURN", "")
	await get_tree().create_timer(HOLD_STOPPED, true, false, true).timeout
	queue_free()


func _finish() -> void:
	_stopped = true
	if quit_when_done:
		get_tree().quit()
		return
	queue_free()


# ---------------------------------------------------------------- helpers

func _refresh_banner() -> void:
	var totals := "COINS %d/%d  MEDALS %d/%d" % [progress.coins_earned(), Levels.total_coins(),
		progress.medals_total(false), progress.medals_max()]
	if phase != Phase.NORMAL:
		totals += "  HARD %d/%d" % [progress.medals_total(true), progress.medals_max()]
	var scene := get_tree().current_scene
	var in_hub := scene != null and scene.scene_file_path == UIKit.HUB_SCENE
	if _status == "AUTOPLAY COMPLETE":
		banner.show_lines(_status + "  YOUR TURN", totals, in_hub)
		return
	if scene == null or scene.scene_file_path != UIKit.GAME_SCENE or scene.is_random():
		# Menus: one line, clear of their BACK button (x 4-44).
		var line := "AUTOPLAY  " + totals
		banner.show_lines(line if AutoplayBanner.text_width(line) <= 268 else totals, "", in_hub)
		return
	var level: int = scene.level
	var first := "AUTOPLAY  %s L%d" % ["HARD" if scene.hard_mode else "NORMAL", level]
	if not scene.hard_mode:
		first += "  COINS %d/%d" % [progress.coins_found_in(level), Levels.COINS[level - 1]]
	first += "  ATTEMPT %d" % maxi(int(runs.get(_key(level, scene.hard_mode), 0)), 1)
	if _choices_shown(scene) or scene.restart_prompt.visible:
		banner.show_lines(first, "")  # under the result buttons
	else:
		banner.show_lines(first, totals + ("  F10 STOP" if phase != Phase.NORMAL else "  PRESS F10 TO STOP"))


## Waits `seconds` of real time (x hold_scale), not counting time the player has the game paused.
## False if this scene is gone or the autoplay stopped meanwhile.
func _hold(seconds: float, token: int) -> bool:
	var left := seconds * hold_scale
	while left > 0.0:
		await get_tree().process_frame
		if not _alive(token):
			return false
		if not _player_paused:
			left -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	return _alive(token)


## Waits (frame by frame) until `ready` is true. False if the scene is gone or the autoplay stopped.
func _until(ready: Callable, token: int) -> bool:
	while _alive(token):
		if ready.call():
			return true
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _alive(token: int) -> bool:
	return not _stopped and token == _token and is_instance_valid(_scene)


func _press(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button.disabled:
		return
	button.grab_focus()
	button.pressed.emit()


func _note(text: String) -> void:
	if not text in notes:
		notes.append(text)
		_say("NOTE: " + text)


func _say(text: String) -> void:
	print("AUTOPLAY: " + text)
