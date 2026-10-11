extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level, skin and hat, `--skin=ID` picks a skin, `--random` plays randomizer mazes, `--hard` turns on hard mode, `--touch` shows touch controls, `--hat=ID` wears a hat, `--jelly` tries the see-through slime, `--upgrades=a,b,c` / `--coins=N` set upgrade levels and coins (for promo shots), `--quiet-window` (from tools/play.ps1) cleans up after a no-focus start.

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
## Coins picked up in the story levels: level -> Array of coin keys ("x,y" cells). Each coin can
## only be collected once; they're saved the moment they're grabbed.
var coins_found := {}
## Upgrade levels bought with coins: id -> level (see Upgrades).
var upgrades := {}
## Set when the upgrades screen was opened from a dry-up: its back button then says PLAY and
## returns to the level (not saved).
var return_to_game := false
## Jelly (the default): every slime is see-through and collected coins sink in and dissolve.
## Off = the solid versions of the skins, which unlock on hard mode (saved; skins screen toggle).
var jelly := true
## Dev mode (--unlock-all): dev-only upgrades (wall power) show up and there are plenty of coins.
var dev_tools := false
const DEV_COINS := 999
## Spending coins dev mode adds (0 when --coins sets an exact amount).
var dev_coins := DEV_COINS
## --all-coins: every coin counts as found, wherever it is.
var all_coins_debug := false
var custom_color := Color8(239, 125, 47)
var sound_on := true
## Master volume, 0-1 (applied to the Master audio bus).
var volume := 0.8
## Hard mode: explored areas that fully dim are swallowed by fog again (no faint memory).
var hard_mode := false
## Record (fastest) clear time per story level, in seconds.
var best_times := {}
## Levels whose "first run: playing as ..." notice has already been shown.
var skin_notices_seen: Array[int] = []
## Levels beaten on hard mode (each unlocks the solid version of that level's skin).
var hard_cleared: Array[int] = []
## action -> physical keycode of its primary key.
var bindings := DEFAULT_KEYS.duplicate()

## Not saved: what "play" means right now.
var mode := MODE_STORY
var random_seed := 1
var randoms_cleared := 0
## Randomizer mazes beaten in total (saved; unlocks hats).
var randoms_won := 0
## Set by debug flags so a test session never overwrites the real save.
var saving_enabled := true
## Debug (--touch): show the on-screen touch controls even without a touchscreen.
var force_touch := false
## Not saved: a skin the current level forces (its first run is played in the newest skin earned).
## While set, it replaces the selected skin everywhere (slime, trail, HUD, menus).
var skin_override := ""


func _ready() -> void:
	if not _is_test_or_tool_run():
		load_progress()
	apply_bindings()
	apply_volume()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)
		elif arg == "--unlock-all":
			saving_enabled = false
			dev_tools = true
			levels_cleared = Levels.COUNT
			highest_unlocked = Levels.COUNT
			randoms_won = maxi(randoms_won, Hats.LIST.map(func(h: Dictionary) -> int: return h.wins).max())
			hard_cleared.assign(range(1, Levels.COUNT + 1))
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
		elif arg.begins_with("--upgrades="):  # e.g. --upgrades=6,4,7: slime, speed, brightness
			saving_enabled = false
			var levels := arg.trim_prefix("--upgrades=").split(",")
			for i in mini(levels.size(), 3):
				upgrades[Upgrades.LIST[i].id] = clampi(levels[i].to_int(), 0, Upgrades.MAX_LEVEL)
		elif arg.begins_with("--coins="):  # exactly this many coins in hand (no dev bonus)
			saving_enabled = false
			dev_coins = 0
			coins_found = {0: []}
			for i in arg.trim_prefix("--coins=").to_int() + coins_spent():
				coins_found[0].append("debug%d" % i)
		elif arg == "--all-coins":  # every story coin found (for rainbow screenshots); not saved
			saving_enabled = false
			dev_coins = 0
			all_coins_debug = true
			coins_found = {}
			for level in range(1, Levels.COUNT + 1):
				coins_found[level] = []
				for i in Levels.COINS[level - 1]:
					coins_found[level].append("debug%d" % i)
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


## Tests, screenshots and promo renders (scripts and scenes under res://tests/ or res://tools/)
## start from a fresh default state instead of the player's save, so whatever the player last
## did (hard mode on, jelly off...) can't change what they check or show.
static func _is_test_or_tool_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("res://tools/"):
			return true
	return false


func load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	levels_cleared = clampi(file.get_value("progress", "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(file.get_value("progress", "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(file.get_value("progress", "current_level", 1), 1, highest_unlocked)
	randoms_won = maxi(file.get_value("progress", "randoms_won", 0), 0)
	custom_color = file.get_value("skin", "custom_color", custom_color)
	selected_hat = file.get_value("skin", "hat", Hats.NONE)
	if not is_hat_unlocked(selected_hat):
		selected_hat = Hats.NONE
	sound_on = file.get_value("settings", "sound_on", true)
	volume = clampf(file.get_value("settings", "volume", volume), 0.0, 1.0)
	hard_mode = file.get_value("settings", "hard_mode", false)
	skin_notices_seen.assign(file.get_value("progress", "skin_notices_seen", []))
	hard_cleared.assign(file.get_value("progress", "hard_cleared", []))
	best_times = {}
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + HARD_RECORDS]:
			if file.has_section_key("records", "level_%d" % key):
				best_times[key] = float(file.get_value("records", "level_%d" % key))
	coins_found = {}
	for level in range(1, Levels.COUNT + 1):
		var found: Array = file.get_value("coins", "level_%d" % level, [])
		if not found.is_empty():
			coins_found[level] = found
	upgrades = {}
	for upgrade: Dictionary in Upgrades.LIST:
		var level := clampi(int(file.get_value("upgrades", upgrade.id, 0)), 0, Upgrades.MAX_LEVEL)
		if level > 0:
			upgrades[upgrade.id] = level
	while coins() < 0 and not upgrades.is_empty():  # never spend more than was found
		upgrades.erase(upgrades.keys()[0])
	for action: String in DEFAULT_KEYS:
		bindings[action] = int(file.get_value("controls", action, DEFAULT_KEYS[action]))
	# The skin last, once everything that unlocks skins (levels, hard clears, coins) is loaded.
	selected_skin = file.get_value("skin", "selected", Skins.DEFAULT)
	set_jelly(file.get_value("skin", "jelly", true))
	if not is_skin_unlocked(selected_skin):  # e.g. a skin that moved, or a solid one no longer earned
		set_jelly(true)
		if not is_skin_unlocked(selected_skin):
			selected_skin = Skins.DEFAULT


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
	file.set_value("skin", "jelly", jelly)
	file.set_value("skin", "hat", selected_hat)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "hard_mode", hard_mode)
	file.set_value("progress", "skin_notices_seen", skin_notices_seen)
	file.set_value("progress", "hard_cleared", hard_cleared)
	for level: int in best_times:
		file.set_value("records", "level_%d" % level, best_times[level])
	for level: int in coins_found:
		file.set_value("coins", "level_%d" % level, coins_found[level])
	for id: String in upgrades:
		file.set_value("upgrades", id, upgrades[id])
	for action: String in bindings:
		file.set_value("controls", action, bindings[action])
	file.save(save_path)


## Records a story win and picks the next level (back to 1 after beating the last one). On hard
## mode it also unlocks that level's solid skin.
func complete_level(level: int) -> void:
	if hard_mode and not level in hard_cleared:
		hard_cleared.append(level)
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

# ---------------------------------------------------------------- coins and upgrades

static func coin_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func has_coin(level: int, cell: Vector2i) -> bool:
	return all_coins_debug or coin_key(cell) in coins_found.get(level, [])


## Picks up a coin (once) and saves right away, so it counts even if the run ends in a dry-up.
func collect_coin(level: int, cell: Vector2i) -> void:
	if has_coin(level, cell):
		return
	if not coins_found.has(level):
		coins_found[level] = []
	coins_found[level].append(coin_key(cell))
	save_progress()


func coins_found_in(level: int) -> int:
	return coins_found.get(level, []).size()


func coins_earned() -> int:
	var total := 0
	for level: int in coins_found:
		total += coins_found[level].size()
	return total


func coins_spent() -> int:
	var total := 0
	for id: String in upgrades:
		total += Upgrades.total_cost(upgrades[id])
	return total


## Coins in hand (found minus what's in the upgrade tree).
func coins() -> int:
	return coins_earned() - coins_spent() + (dev_coins if dev_tools else 0)


func upgrade_level(id: String) -> int:
	if Upgrades.get_upgrade(id).get("dev", false) and not dev_tools:
		return 0
	return int(upgrades.get(id, 0))


## Puts coins into an upgrade (one level). Returns false if it's maxed or too expensive.
func buy_upgrade(id: String) -> bool:
	var level := upgrade_level(id)
	if level >= Upgrades.MAX_LEVEL or coins() < Upgrades.cost(level):
		return false
	upgrades[id] = level + 1
	save_progress()
	return true


## Takes one level's coins back out of an upgrade.
func refund_upgrade(id: String) -> bool:
	var level := upgrade_level(id)
	if level <= 0:
		return false
	if level == 1:
		upgrades.erase(id)
	else:
		upgrades[id] = level - 1
	save_progress()
	return true


func set_jelly(on: bool) -> void:
	jelly = on
	Skins.jelly = on


## Randomizer mode opens once all the story levels are beaten.
func is_randomizer_unlocked() -> bool:
	return levels_cleared >= Levels.COUNT


func is_hat_unlocked(id: String) -> bool:
	if dev_tools and not Hats.get_hat(id).is_empty():
		return true  # dev mode can try on every hat, even before they're released
	return Hats.is_unlocked(id, randoms_won)


## Wears hat `id` (if unlocked) and saves.
func select_hat(id: String) -> void:
	if is_hat_unlocked(id):
		selected_hat = id
		save_progress()


## Whether skin `id` can be worn: as jelly, or (`jelly_version` false) in its solid version.
func is_skin_unlocked(id: String, jelly_version: Variant = null) -> bool:
	if dev_tools:
		return true
	return Skins.is_unlocked(id, levels_cleared, hard_cleared, jelly if jelly_version == null else jelly_version, coins_earned())


## The skin in use right now: a level's forced first-run skin, else the selected one.
func active_skin() -> String:
	return skin_override if skin_override != "" else selected_skin


## Hard mode keeps its own records: saved under the level number + this.
const HARD_RECORDS := 100


func _record_key(level: int) -> int:
	return level + HARD_RECORDS if hard_mode else level


## Record time for a level (on the current mode) in seconds, or -1 if never cleared with a time.
func best_time(level: int) -> float:
	return best_times.get(_record_key(level), -1.0)


## Saves `seconds` as the level's record if it's the first time or faster. Returns true only when
## an existing record was beaten (a first clear just sets the record).
func record_time(level: int, seconds: float) -> bool:
	var previous := best_time(level)
	if previous >= 0.0 and seconds >= previous:
		return false
	best_times[_record_key(level)] = seconds
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


## The skin earned by the level before `level` (Lime for level 1): the one a new level's very
## first attempt is played in, if the level hasn't been cleared yet.
func forced_skin_for(level: int) -> String:
	return Skins.skin_for_level(level - 1) if level > levels_cleared else ""


## The very first attempt at a new level equips the skin just earned (it stays equipped, so the
## menus match it; the player can change it any time after). Returns it, or "" if nothing changed.
## Each level does this once (saved).
func equip_first_run_skin(level: int) -> String:
	var skin := forced_skin_for(level)
	if skin == "" or level in skin_notices_seen or not is_skin_unlocked(skin):
		return ""
	skin_notices_seen.append(level)
	var changed := selected_skin != skin or not jelly
	selected_skin = skin
	set_jelly(true)
	save_progress()
	return skin if changed else ""


## Wipes all progress: levels, records, coins, upgrades, skins, hats and randomizer wins. Sound,
## volume and key bindings are kept.
func reset_progress() -> void:
	levels_cleared = 0
	highest_unlocked = 1
	current_level = 1
	mode = MODE_STORY
	randoms_cleared = 0
	randoms_won = 0
	selected_skin = Skins.DEFAULT
	set_jelly(true)
	selected_hat = Hats.NONE
	custom_color = Color8(239, 125, 47)
	hard_mode = false
	best_times = {}
	skin_notices_seen.clear()
	hard_cleared.clear()
	coins_found = {}
	upgrades = {}
	skin_override = ""
	save_progress()


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


## Wears skin `id` as jelly or (`jelly_version` false) solid, if that version is unlocked.
func select_skin(id: String, jelly_version: Variant = null) -> void:
	var as_jelly: bool = jelly if jelly_version == null else jelly_version
	if is_skin_unlocked(id, as_jelly):
		selected_skin = id
		set_jelly(as_jelly)
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
