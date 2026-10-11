extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level and skin, `--skin=ID` picks a skin, `--random` plays randomizer mazes, `--hard` turns on hard mode, `--touch` shows touch controls, `--hat=ID` wears a hat, `--quiet-window` (from tools/play.ps1) cleans up after a no-focus start.

const MODE_STORY := "story"
const MODE_RANDOM := "random"

## Remappable actions and their default (primary) keys. Movement also keeps the arrow keys
## as fixed secondary keys, so the game stays playable whatever gets remapped.
const DEFAULT_KEYS := {
	move_up = KEY_W, move_down = KEY_S, move_left = KEY_A, move_right = KEY_D,
	jump = KEY_SPACE, restart = KEY_R,
}
const SECONDARY_KEYS := {move_up = KEY_UP, move_down = KEY_DOWN, move_left = KEY_LEFT, move_right = KEY_RIGHT}

var save_path := "user://save.cfg"
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of story levels beaten so far (0-10). Also decides which skins are unlocked.
var levels_cleared := 0
## Story level the game scene loads next.
var current_level := 1

var selected_skin := Skins.DEFAULT
## The hat the slime wears (Hats.NONE for none); hats unlock from randomizer wins.
var selected_hat := Hats.NONE
var custom_color := Color8(239, 125, 47)
## Glow strength for the custom skin, 0-1.
var glow := 0.6
var sound_on := true
## Master volume, 0-1 (applied to the Master audio bus).
var volume := 0.8
## Hard mode: explored areas that fully dim are swallowed by fog again (no faint memory).
var hard_mode := false
## Record (fastest) clear time per story level, in seconds.
var best_times := {}
## Levels whose "first run: playing as ..." notice has already been shown.
var skin_notices_seen: Array[int] = []
## action -> physical keycode of its primary key.
var bindings := DEFAULT_KEYS.duplicate()

## Not saved: what "play" means right now.
var mode := MODE_STORY
var random_seed := 1
var randoms_cleared := 0
## Randomizer mazes beaten in total (saved); unlocks the rainbow skin.
var randoms_won := 0
## Set by debug flags so a test session never overwrites the real save.
var saving_enabled := true
## Debug (--touch): show the on-screen touch controls even without a touchscreen.
var force_touch := false
## Not saved: a skin the current level forces (its first run is played in the newest skin earned).
## While set, it replaces the selected skin everywhere (slime, trail, HUD, menus).
var skin_override := ""


func _ready() -> void:
	load_progress()
	apply_bindings()
	apply_volume()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)
		elif arg == "--unlock-all":
			saving_enabled = false
			levels_cleared = Levels.COUNT
			highest_unlocked = Levels.COUNT
			randoms_won = maxi(randoms_won, Skins.RAINBOW_RANDOMS)
		elif arg == "--touch":
			force_touch = true
		elif arg == "--hard":
			saving_enabled = false
			hard_mode = true
		elif arg == "--random":
			start_random()
		elif arg.begins_with("--skin="):
			saving_enabled = false
			selected_skin = arg.trim_prefix("--skin=")
		elif arg.begins_with("--hat="):
			saving_enabled = false
			selected_hat = arg.trim_prefix("--hat=")
		elif arg == "--quiet-window":
			_after_quiet_start.call_deferred()


## Debug (--quiet-window, used by tools/play.ps1 and screenshot.ps1): the window was opened
## without taking focus via a temporary override.cfg. Delete that file right away (so normal runs
## aren't affected) and make the window focusable again, so clicking it lets you play.
func _after_quiet_start() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://override.cfg"))
	get_window().set_flag(Window.FLAG_NO_FOCUS, false)


## F11 toggles fullscreen anywhere in the game (desktop and browser).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


func load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	levels_cleared = clampi(file.get_value("progress", "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(file.get_value("progress", "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(file.get_value("progress", "current_level", 1), 1, highest_unlocked)
	randoms_won = maxi(file.get_value("progress", "randoms_won", 0), 0)
	selected_skin = file.get_value("skin", "selected", Skins.DEFAULT)
	if not is_skin_unlocked(selected_skin):  # e.g. a skin that has moved to a later level
		selected_skin = Skins.DEFAULT
	custom_color = file.get_value("skin", "custom_color", custom_color)
	selected_hat = file.get_value("skin", "hat", Hats.NONE)
	if not is_hat_unlocked(selected_hat):
		selected_hat = Hats.NONE
	glow = clampf(file.get_value("skin", "glow", glow), 0.0, 1.0)
	sound_on = file.get_value("settings", "sound_on", true)
	volume = clampf(file.get_value("settings", "volume", volume), 0.0, 1.0)
	hard_mode = file.get_value("settings", "hard_mode", false)
	skin_notices_seen.assign(file.get_value("progress", "skin_notices_seen", []))
	best_times = {}
	for level in range(1, Levels.COUNT + 1):
		if file.has_section_key("records", "level_%d" % level):
			best_times[level] = float(file.get_value("records", "level_%d" % level))
	for action: String in DEFAULT_KEYS:
		bindings[action] = int(file.get_value("controls", action, DEFAULT_KEYS[action]))


func save_progress() -> void:
	if not saving_enabled:
		return
	var file := ConfigFile.new()
	file.set_value("progress", "levels_cleared", levels_cleared)
	file.set_value("progress", "highest_unlocked", highest_unlocked)
	file.set_value("progress", "current_level", current_level)
	file.set_value("progress", "randoms_won", randoms_won)
	file.set_value("skin", "selected", selected_skin)
	file.set_value("skin", "custom_color", custom_color)
	file.set_value("skin", "hat", selected_hat)
	file.set_value("skin", "glow", glow)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "hard_mode", hard_mode)
	file.set_value("progress", "skin_notices_seen", skin_notices_seen)
	for level: int in best_times:
		file.set_value("records", "level_%d" % level, best_times[level])
	for action: String in bindings:
		file.set_value("controls", action, bindings[action])
	file.save(save_path)


## Records a story win and picks the next level (back to 1 after beating the last one).
func complete_level(level: int) -> void:
	levels_cleared = maxi(levels_cleared, level)
	highest_unlocked = maxi(highest_unlocked, mini(level + 1, Levels.COUNT))
	current_level = level + 1 if level < Levels.COUNT else 1
	save_progress()


func start_story(level: int) -> void:
	mode = MODE_STORY
	current_level = clampi(level, 1, highest_unlocked)


## Records a randomizer win (saved). The maze stays the same until the player picks NEW MAZE.
func complete_random() -> void:
	randoms_cleared += 1
	randoms_won += 1
	save_progress()


func start_random() -> void:
	mode = MODE_RANDOM
	new_random_maze()


func new_random_maze() -> void:
	random_seed = randi_range(1, 2_000_000_000)


# ---------------------------------------------------------------- skins

## Randomizer mode opens once all the story levels are beaten.
func is_randomizer_unlocked() -> bool:
	return levels_cleared >= Levels.COUNT


func is_hat_unlocked(id: String) -> bool:
	return Hats.is_unlocked(id, randoms_won)


## Wears hat `id` (if unlocked) and saves.
func select_hat(id: String) -> void:
	if is_hat_unlocked(id):
		selected_hat = id
		save_progress()


func is_skin_unlocked(id: String) -> bool:
	return Skins.is_unlocked(id, levels_cleared, randoms_won)


## The skin in use right now: a level's forced first-run skin, else the selected one.
func active_skin() -> String:
	return skin_override if skin_override != "" else selected_skin


## Skin a story level must be played in, or "" for free choice: a level's first run (before it
## has ever been cleared) uses the skin just earned by clearing the level before it (Lime for
## level 1). Once the level is cleared, replays use whatever skin is selected.
## Record time for a level in seconds, or -1 if it has never been cleared with a time.
func best_time(level: int) -> float:
	return best_times.get(level, -1.0)


## Saves `seconds` as the level's record if it's the first time or faster. Returns true only when
## an existing record was beaten (a first clear just sets the record).
func record_time(level: int, seconds: float) -> bool:
	var previous := best_time(level)
	if previous >= 0.0 and seconds >= previous:
		return false
	best_times[level] = seconds
	save_progress()
	return previous >= 0.0


## True (once per level, saved) when the level's forced-skin notice should be shown.
func take_skin_notice(level: int) -> bool:
	if level in skin_notices_seen:
		return false
	skin_notices_seen.append(level)
	save_progress()
	return true


func set_hard_mode(on: bool) -> void:
	hard_mode = on
	save_progress()


func forced_skin_for(level: int) -> String:
	return Skins.skin_for_level(level - 1) if level > levels_cleared else ""


## True when the rainbow skin is in use (and unlocked).
func is_rainbow() -> bool:
	return active_skin() == Skins.RAINBOW and is_skin_unlocked(Skins.RAINBOW)


func skin_color() -> Color:
	var id := active_skin()
	if skin_override == "" and not is_skin_unlocked(id):
		return Skins.get_preset(Skins.DEFAULT).color
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.CUSTOM:
		return custom_color
	return Skins.get_preset(id).color


## Glow strength in play: only the custom skin glows, and only once the game is beaten.
func glow_amount() -> float:
	if active_skin() == Skins.CUSTOM and is_skin_unlocked(Skins.CUSTOM):
		return glow
	return 0.0


func select_skin(id: String) -> void:
	if is_skin_unlocked(id):
		selected_skin = id
		save_progress()


# ---------------------------------------------------------------- sound

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_progress()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


# ---------------------------------------------------------------- controls

## Binds `keycode` as the primary key for `action`. If another action used that key, the two
## swap keys so no key is ever bound twice.
func set_binding(action: String, keycode: int) -> void:
	for other: String in bindings:
		if other != action and bindings[other] == keycode:
			bindings[other] = bindings[action]
	bindings[action] = keycode
	apply_bindings()
	save_progress()


func reset_bindings() -> void:
	bindings = DEFAULT_KEYS.duplicate()
	apply_bindings()
	save_progress()


func apply_bindings() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _key_event(bindings[action]))
		var secondary: int = SECONDARY_KEYS.get(action, 0)
		if secondary != 0 and secondary != bindings[action]:
			InputMap.action_add_event(action, _key_event(secondary))


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()


static func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event
