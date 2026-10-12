extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level, skin and hat, `--skin=ID` picks a skin, `--random` plays randomizer mazes, `--hard` turns on hard mode, `--touch` shows touch controls, `--hat=ID` wears a hat, `--globs=N` sets the glob balance, `--jelly` tries the see-through slime, `--upgrades=a,b,c` / `--coins=N` set upgrade levels and coins (for promo shots), `--quiet-window` (from tools/play.ps1) cleans up after a no-focus start.

const MODE_STORY := "story"
const MODE_RANDOM := "random"
const TUTORIAL_MOVE := 1
const TUTORIAL_LEAP := 2

## Remappable actions and their default (primary) keys. Movement also keeps the arrow keys
## as fixed secondary keys, so the game stays playable whatever gets remapped.
const DEFAULT_KEYS := {
	move_up = KEY_W, move_down = KEY_S, move_left = KEY_A, move_right = KEY_D,
	jump = KEY_SPACE, restart = KEY_R, interact = KEY_F,
}
const SECONDARY_KEYS := {move_up = KEY_UP, move_down = KEY_DOWN, move_left = KEY_LEFT, move_right = KEY_RIGHT}

var save_path := "user://save.cfg"
## Save codes start with this (the 1 is the format, in case it ever changes).
const SAVE_CODE_PREFIX := "SLIME1-"
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of story levels beaten so far (0-10). Also decides which skins are unlocked.
var levels_cleared := 0
## Bit set of wordless hints already used (TUTORIAL_MOVE / TUTORIAL_LEAP); saved, optional key.
var tutorial_seen := 0
## Dry-ups per story level since it was last cleared (not saved); drives the chalice beacon.
var dry_ups := {}
## Story level the game scene loads next.
var current_level := 1

## Save layout version, written to [meta] (a save without it is from before globs and medals).
const SAVE_VERSION := 2
## GLOBS: the renewable, cosmetic-only currency (never converted to or from coins). Faucets:
## a level's first clear, its medals, hard clears and (capped per day) randomizer wins. The only
## sink so far is the hat wheel.
const GLOBS_MAX := 99999
const GLOBS_FIRST_CLEAR := 4
const GLOBS_MEDAL := 2
const GLOBS_HARD_CLEAR := 8
const GLOBS_RANDOM_WIN := 2
## Randomizer wins that pay globs per UTC day.
const RANDOM_PAID_PER_DAY := 5
const SPIN_COST := 12
const RAINBOW_PITY_MAX := 40
## Level medals (a bitmask per level and mode): PAR (finish within the level's par time), CLEAN
## (not one wall splat) and COINS (every coin in the level; story only).
const MEDAL_PAR := 1
const MEDAL_CLEAN := 2
const MEDAL_COINS := 4
const MEDAL_ALL := 7
## Slime reserve (ASSIST): after this many dry-ups on one level in a session, the next attempt
## can be played with a bit more slime (never on hard mode; no medals, records or globs).
const ASSIST_AFTER := 3
const ASSIST_BONUS := 0.10
var globs := 0
var globs_lifetime := 0
## Which levels' first-clear globs have been paid (bit n-1 = level n), per mode: a clear played
## with the assist doesn't pay, so the +4/+8 waits for an unassisted one.
var clears_paid := 0
var hard_clears_paid := 0
## Medals per level (hard mode's under level + HARD_RECORDS): level -> bitmask.
var medals := {}
## Hat wheel: spins made in all, and spins since the rainbow hat was last rolled (pity).
var spins := 0
var rainbow_pity := 0
## UTC day number and how many randomizer wins were paid on it.
var random_pay_day := 0
var random_paid := 0
## Not saved: the level whose next attempt was chosen to be played with the slime reserve.
var assist_level := 0
## Tests set a day number here instead of reading the clock (-1 = use the clock).
var day_override := -1

var selected_skin := Skins.DEFAULT
## The hat the slime wears (Hats.NONE for none).
var selected_hat := Hats.NONE
## Hats won on the hat wheel (saved): they're off the wheel and can be worn.
var hats_owned: Array[String] = []
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
## Reduce motion: no screen shake, camera kick or hit-stop (see Game.motion_scale).
var reduce_motion := false
## Fog brightness: FOG_DARK, FOG_NORMAL (the default look) or FOG_BRIGHT (see Game.fog_look).
const FOG_DARK := 0
const FOG_NORMAL := 1
const FOG_BRIGHT := 2
var fog_brightness := FOG_NORMAL
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
## Randomizer mazes beaten in total (saved).
var randoms_won := 0
## Set by debug flags so a test session never overwrites the real save.
var saving_enabled := true
## Debug (--touch): show the on-screen touch controls even without a touchscreen.
var force_touch := false
## Not saved: a skin the current level forces (its first run is played in the newest skin earned).
## While set, it replaces the selected skin everywhere (slime, trail, HUD, menus).
var skin_override := ""


func _ready() -> void:
	# In a browser the save lives in the site's storage; asking for it to be kept as persistent
	# stops the browser from evicting it when space runs low (Chrome/Edge usually just agree).
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.storage && navigator.storage.persist) { navigator.storage.persist(); }", true)
	# The hub's use key isn't in project.godot's input map; it's made here (F by default).
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
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
		elif arg.begins_with("--globs="):  # this many globs in hand (not saved)
			saving_enabled = false
			globs = clampi(arg.trim_prefix("--globs=").to_int(), 0, GLOBS_MAX)
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
	_read(file)


## Takes everything from a save (the save file or a loaded save code).
func _read(file: ConfigFile) -> void:
	levels_cleared = clampi(_int(file, "progress", "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(_int(file, "progress", "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(_int(file, "progress", "current_level", 1), 1, highest_unlocked)
	randoms_won = maxi(_int(file, "progress", "randoms_won", 0), 0)
	# Saves from before the cues existed have no key: a returning player has seen it all.
	var returning := levels_cleared > 0 or randoms_won > 0
	tutorial_seen = maxi(_int(file, "progress", "tutorial_seen", TUTORIAL_MOVE | TUTORIAL_LEAP if returning else 0), 0)
	var color: Variant = file.get_value("skin", "custom_color", custom_color)
	custom_color = color if typeof(color) == TYPE_COLOR else custom_color
	hats_owned.assign(_strings(file.get_value("hats", "owned", [])))
	selected_hat = _string(file, "skin", "hat", Hats.NONE)
	if not is_hat_unlocked(selected_hat):
		selected_hat = Hats.NONE
	sound_on = _bool(file, "settings", "sound_on", true)
	volume = clampf(_float(file, "settings", "volume", volume), 0.0, 1.0)
	hard_mode = _bool(file, "settings", "hard_mode", false)
	reduce_motion = _bool(file, "settings", "reduce_motion", reduce_motion)
	fog_brightness = clampi(_int(file, "settings", "fog_brightness", fog_brightness), FOG_DARK, FOG_BRIGHT)
	skin_notices_seen.assign(_ints(file.get_value("progress", "skin_notices_seen", [])))
	hard_cleared.assign(_ints(file.get_value("progress", "hard_cleared", [])))
	best_times = {}
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + HARD_RECORDS]:
			if file.has_section_key("records", "level_%d" % key):
				best_times[key] = _float(file, "records", "level_%d" % key, 0.0)
	coins_found = {}
	for level in range(1, Levels.COUNT + 1):
		var found: Array = []
		found.assign(_strings(file.get_value("coins", "level_%d" % level, [])))
		if not found.is_empty():
			coins_found[level] = found
	upgrades = {}
	for upgrade: Dictionary in Upgrades.LIST:
		var level := clampi(_int(file, "upgrades", upgrade.id, 0), 0, Upgrades.MAX_LEVEL)
		if level > 0:
			upgrades[upgrade.id] = level
	while coins() < 0 and not upgrades.is_empty():  # never spend more than was found
		upgrades.erase(upgrades.keys()[0])
	for action: String in DEFAULT_KEYS:
		bindings[action] = _int(file, "controls", action, DEFAULT_KEYS[action])
	_read_wallet(file)
	# The skin last, once everything that unlocks skins (levels, hard clears, coins) is loaded.
	selected_skin = _string(file, "skin", "selected", Skins.DEFAULT)
	set_jelly(_bool(file, "skin", "jelly", true))
	if not is_skin_unlocked(selected_skin):  # e.g. a skin that moved, or a solid one no longer earned
		set_jelly(true)
		if not is_skin_unlocked(selected_skin):
			selected_skin = Skins.DEFAULT


## Globs, medals and hat-wheel counters. Every key is optional: a save from before them gets
## zeros (plus a one-time grant of the first-clear globs the player already earned).
func _read_wallet(file: ConfigFile) -> void:
	var has_wallet := file.has_section_key("wallet", "globs")
	globs = clampi(_int(file, "wallet", "globs", 0), 0, GLOBS_MAX)
	globs_lifetime = clampi(_int(file, "wallet", "globs_lifetime", globs), 0, 100 * GLOBS_MAX)
	clears_paid = clampi(_int(file, "wallet", "clears_paid", 0), 0, (1 << Levels.COUNT) - 1)
	hard_clears_paid = clampi(_int(file, "wallet", "hard_clears_paid", 0), 0, (1 << Levels.COUNT) - 1)
	random_pay_day = maxi(_int(file, "wallet", "random_day", 0), 0)
	random_paid = clampi(_int(file, "wallet", "random_paid", 0), 0, RANDOM_PAID_PER_DAY)
	spins = maxi(_int(file, "hats", "spins", 0), 0)
	rainbow_pity = clampi(_int(file, "hats", "rainbow_pity", 0), 0, RAINBOW_PITY_MAX)
	medals = {}
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + HARD_RECORDS]:
			var mask := clampi(_int(file, "medals", "level_%d" % key, 0), 0, MEDAL_ALL)
			if mask != 0:
				medals[key] = mask
	if not has_wallet and _int(file, "meta", "version", 1) < SAVE_VERSION:
		# A save from before globs: pay what it already earned, once (the next save writes the
		# wallet, so this can't happen twice).
		var all_paid := (1 << Levels.COUNT) - 1
		var cleared := clampi(levels_cleared, 0, Levels.COUNT)
		var hard_levels: Array[int] = []
		for level in hard_cleared:
			if level >= 1 and level <= Levels.COUNT and not level in hard_levels:
				hard_levels.append(level)
		clears_paid = ((1 << cleared) - 1) & all_paid
		for level in hard_levels:
			hard_clears_paid |= 1 << (level - 1)
		hard_clears_paid &= all_paid
		globs = mini(GLOBS_FIRST_CLEAR * cleared + GLOBS_HARD_CLEAR * hard_levels.size(), GLOBS_MAX)
		globs_lifetime = globs


## Type-safe save readers: a wrong-typed value (hand-edited or hostile save) gives the default.
static func _int(file: ConfigFile, section: String, key: String, default: int) -> int:
	var v: Variant = file.get_value(section, key, default)
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v):
		return int(v)
	return default


static func _float(file: ConfigFile, section: String, key: String, default: float) -> float:
	var v: Variant = file.get_value(section, key, default)
	if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v)):
		return float(v)
	return default


static func _bool(file: ConfigFile, section: String, key: String, default: bool) -> bool:
	var v: Variant = file.get_value(section, key, default)
	return v if typeof(v) == TYPE_BOOL else default


static func _string(file: ConfigFile, section: String, key: String, default: String) -> String:
	var v: Variant = file.get_value(section, key, default)
	return v if typeof(v) == TYPE_STRING else default


static func _strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			if typeof(item) == TYPE_STRING:
				out.append(item)
	return out


static func _ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			if typeof(item) == TYPE_INT:
				out.append(item)
	return out


func save_progress() -> void:
	if not saving_enabled:
		return
	_write().save(save_path)


## Everything that's saved, as a ConfigFile (written to the save file, or turned into a save code).
func _write() -> ConfigFile:
	var file := ConfigFile.new()
	file.set_value("meta", "version", SAVE_VERSION)
	file.set_value("progress", "levels_cleared", levels_cleared)
	file.set_value("progress", "highest_unlocked", highest_unlocked)
	file.set_value("progress", "current_level", current_level)
	file.set_value("progress", "randoms_won", randoms_won)
	file.set_value("progress", "tutorial_seen", tutorial_seen)
	file.set_value("skin", "selected", selected_skin)
	file.set_value("skin", "custom_color", custom_color)
	file.set_value("skin", "jelly", jelly)
	file.set_value("skin", "hat", selected_hat)
	file.set_value("hats", "owned", hats_owned)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "volume", volume)
	file.set_value("settings", "hard_mode", hard_mode)
	file.set_value("settings", "reduce_motion", reduce_motion)
	file.set_value("settings", "fog_brightness", fog_brightness)
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
	file.set_value("wallet", "globs", globs)
	file.set_value("wallet", "globs_lifetime", globs_lifetime)
	file.set_value("wallet", "clears_paid", clears_paid)
	file.set_value("wallet", "hard_clears_paid", hard_clears_paid)
	file.set_value("wallet", "random_day", random_pay_day)
	file.set_value("wallet", "random_paid", random_paid)
	file.set_value("hats", "spins", spins)
	file.set_value("hats", "rainbow_pity", rainbow_pity)
	for key: int in medals:
		file.set_value("medals", "level_%d" % key, medals[key])
	return file


## The whole save as a code to copy somewhere safe: "SLIME1-" and the save file, gzipped, in
## base64. Pasting it back with load_code restores the progress (in a browser whose storage was
## cleared, on another browser, or in the Windows version).
func save_code() -> String:
	var packed := _write().encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return SAVE_CODE_PREFIX + Marshalls.raw_to_base64(packed)


## The save inside a code, or null if it isn't a working Slime Time save code.
## Longest save code read (base64 characters); real ones are a few KB.
const MAX_SAVE_CODE_LENGTH := 65536


static func read_code(code: String) -> ConfigFile:
	code = code.strip_edges().replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
	if not code.begins_with(SAVE_CODE_PREFIX) or code.length() > MAX_SAVE_CODE_LENGTH:
		return null
	var packed := Marshalls.base64_to_raw(code.trim_prefix(SAVE_CODE_PREFIX))
	if packed.is_empty():
		return null
	var text := packed.decompress_dynamic(1 << 20, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var file := ConfigFile.new()
	if text == "" or file.parse(text) != OK or not file.has_section("progress"):
		return null
	return file


## Replaces the progress with the save in `code` (and saves it). False if the code doesn't work.
func load_code(code: String) -> bool:
	var file := read_code(code)
	if file == null:
		return false
	_read(file)
	apply_bindings()
	apply_volume()
	save_progress()
	return true


## Records a story win and picks the next level (back to 1 after beating the last one). On hard
## mode it also unlocks that level's solid skin.
func complete_level(level: int, save := true) -> void:
	if hard_mode and not level in hard_cleared:
		hard_cleared.append(level)
	levels_cleared = maxi(levels_cleared, level)
	dry_ups.erase(level)
	highest_unlocked = maxi(highest_unlocked, mini(level + 1, Levels.COUNT))
	current_level = level + 1 if level < Levels.COUNT else 1
	if save:
		save_progress()


## True until the first chalice: the title goes straight into level 1 and the hub waits.
func is_fresh_save() -> bool:
	return levels_cleared == 0 and randoms_won == 0 and hard_cleared.is_empty()


func has_seen_tutorial(bit: int) -> bool:
	return tutorial_seen & bit != 0


func mark_tutorial_seen(bit: int) -> void:
	if not has_seen_tutorial(bit):
		tutorial_seen |= bit
		save_progress()


func start_story(level: int) -> void:
	mode = MODE_STORY
	current_level = clampi(level, 1, highest_unlocked)


## Records a randomizer win (saved) and pays its globs (capped per UTC day; none while the
## assist was on). Returns the globs paid. The maze stays the same until the player picks NEW MAZE.
func complete_random(assisted := false) -> int:
	randoms_cleared += 1
	randoms_won += 1
	var paid := 0
	if not assisted:
		paid = random_globs_due()
		if utc_day() > random_pay_day:  # a new day: the cap starts over (never when the clock went back)
			random_pay_day = utc_day()
			random_paid = 0
		if paid > 0:
			random_paid += 1
		add_globs(paid, false)
	save_progress()
	return paid


# ---------------------------------------------------------------- globs and medals

## Today as a UTC day number (days since 1970).
func utc_day() -> int:
	return day_override if day_override >= 0 else int(Time.get_unix_time_from_system() / 86400.0)


## What a randomizer win would pay right now (0 once today's cap of paid wins is used).
func random_globs_due() -> int:
	if utc_day() > random_pay_day:
		return GLOBS_RANDOM_WIN
	return GLOBS_RANDOM_WIN if random_paid < RANDOM_PAID_PER_DAY else 0


## Adds globs (kept within 0-99,999; the amount actually added is returned). Saves unless told not to.
func add_globs(amount: int, save := true) -> int:
	var before := globs
	globs = clampi(globs + amount, 0, GLOBS_MAX)
	var added := globs - before
	if added > 0:
		globs_lifetime += added
	if save and added != 0:
		save_progress()
	return added


func medal_key(level: int) -> int:
	return _record_key(level)


## The medals won on `level` in the current mode (a MEDAL_* bit set).
func medals_for(level: int) -> int:
	return int(medals.get(medal_key(level), 0))


static func medal_count(mask: int) -> int:
	return int(mask & MEDAL_PAR != 0) + int(mask & MEDAL_CLEAN != 0) + int(mask & MEDAL_COINS != 0)


## Which medals a run earned (not saved anywhere): within `par` seconds, no wall splat, and (story
## only) every coin of the level.
func medals_earned(run_time: float, par: float, splats: int, all_coins: bool) -> int:
	var mask := 0
	if run_time <= par:
		mask |= MEDAL_PAR
	if splats == 0:
		mask |= MEDAL_CLEAN
	if all_coins and not hard_mode:
		mask |= MEDAL_COINS
	return mask


## Pays a cleared story level: its first-clear globs (+4, or +8 on hard mode) and +2 per medal won
## for the first time, then saves. A clear played with the slime reserve pays nothing and keeps
## the first-clear bonus waiting for an unassisted clear. Returns {globs, first, medals (earned
## this run), new_medals, assisted}. With `finish`, the best time and the level's cleared mark
## (record_time + complete_level) are written in that same save.
func record_clear(level: int, run_time: float, par: float, splats: int, all_coins: bool, assisted := false, finish := false) -> Dictionary:
	var result := {globs = 0, first = false, medals = 0, new_medals = 0, assisted = assisted}
	if assisted:
		return result
	var bit := 1 << (level - 1)
	var paid: int = hard_clears_paid if hard_mode else clears_paid
	if paid & bit == 0:
		result.first = true
		result.globs += GLOBS_HARD_CLEAR if hard_mode else GLOBS_FIRST_CLEAR
		if hard_mode:
			hard_clears_paid |= bit
		else:
			clears_paid |= bit
	var earned := medals_earned(run_time, par, splats, all_coins)
	var fresh := earned & ~medals_for(level)
	result.medals = earned
	result.new_medals = fresh
	result.globs += GLOBS_MEDAL * medal_count(fresh)
	if fresh != 0:
		medals[medal_key(level)] = medals_for(level) | fresh
	add_globs(result.globs, false)
	if finish:  # the record and the level's cleared mark land in the same save as the payment
		record_time(level, run_time, false)
		complete_level(level, false)
	save_progress()
	return result


## Medals won across the story in the current mode (for the hub / level select).
func medals_total() -> int:
	var total := 0
	for level in range(1, Levels.COUNT + 1):
		total += medal_count(medals_for(level))
	return total


# ---------------------------------------------------------------- slime reserve (assist)

## Whether the dry-up screen should offer the slime reserve: 3+ dry-ups on this story level since
## it was last cleared (this session), and never on hard mode.
func assist_offered(for_level: int) -> bool:
	return not hard_mode and for_level >= 1 and for_level <= Levels.COUNT \
			and int(dry_ups.get(for_level, 0)) >= ASSIST_AFTER


## Chooses to play `for_level`'s next attempt with the reserve. False if it isn't on offer.
func accept_assist(for_level: int) -> bool:
	if not assist_offered(for_level):
		return false
	assist_level = for_level
	return true


## True (once) if the attempt now starting was chosen to be an assisted one.
func take_assist(for_level: int) -> bool:
	var on := assist_level == for_level and assist_offered(for_level)
	assist_level = 0
	return on


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
## While `assisted` (the slime reserve is on) nothing is stored: those coins don't count later.
func collect_coin(level: int, cell: Vector2i, assisted := false) -> void:
	if assisted or has_coin(level, cell):
		return
	if not coins_found.has(level):
		coins_found[level] = []
	coins_found[level].append(coin_key(cell))
	save_progress()


func coins_found_in(level: int) -> int:
	var level_coins: Array = coins_found.get(level, [])
	if level >= 1 and level <= Levels.COINS.size():
		return mini(level_coins.size(), Levels.COINS[level - 1])
	return level_coins.size()


func coins_earned() -> int:
	var total := 0
	for level: int in coins_found:
		total += coins_found_in(level)
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
	return Hats.is_unlocked(id, hats_owned)


## The hats still on the hat wheel: the ones not won yet.
func hats_left() -> Array[String]:
	var left: Array[String] = []
	for id in Hats.ids():
		if not id in hats_owned:
			left.append(id)
	return left


## Whether the hat wheel can be spun right now: dev mode always (free); otherwise only once hats
## are out (Hats.available), with a hat left to win and the first spin or 12 globs to pay for it.
func can_spin_hats() -> bool:
	if hats_left().is_empty():
		return false
	if dev_tools:
		return true
	return Hats.available and spin_cost() <= globs


## What the next spin costs: nothing in dev mode and for the very first spin, else SPIN_COST.
func spin_cost() -> int:
	return 0 if dev_tools or spins == 0 else SPIN_COST


## One whole spin, done before the wheel starts turning: picks the hat (the rare rainbow hat gets
## more likely with every spin that misses it), takes the globs, wins the hat and saves, all
## together, so closing the game mid-spin can't lose a payment or a prize. `roll` (0-1) picks
## the hat; leave it -1 for a random one. Returns the hat's id, or "" if it can't spin.
func spin_hat(roll := -1.0) -> String:
	if not can_spin_hats():
		return ""
	var left := hats_left()
	var pick := Hats.pick(left, rainbow_pity, randf() if roll < 0.0 else roll)
	globs -= spin_cost()
	spins += 1
	rainbow_pity = 0 if Hats.get_hat(pick).get("flows", false) else mini(rainbow_pity + 1, RAINBOW_PITY_MAX)
	win_hat(pick)  # saves everything above too
	return pick


## A hat won on the wheel: it's yours (off the wheel), and the slime puts it on. Saved.
func win_hat(id: String) -> void:
	if id in hats_owned or Hats.get_hat(id).is_empty():
		return
	hats_owned.append(id)
	selected_hat = id
	save_progress()


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
func record_time(level: int, seconds: float, save := true) -> bool:
	var previous := best_time(level)
	if previous >= 0.0 and seconds >= previous:
		return false
	best_times[_record_key(level)] = seconds
	if save:
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
## volume, reduce motion, fog brightness and key bindings are kept (they are preferences).
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
	hats_owned.clear()
	custom_color = Color8(239, 125, 47)
	hard_mode = false
	best_times = {}
	skin_notices_seen.clear()
	hard_cleared.clear()
	coins_found = {}
	upgrades = {}
	skin_override = ""
	tutorial_seen = 0
	dry_ups = {}
	globs = 0
	globs_lifetime = 0
	clears_paid = 0
	hard_clears_paid = 0
	medals = {}
	spins = 0
	rainbow_pity = 0
	random_pay_day = 0
	random_paid = 0
	assist_level = 0
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

func set_volume(value: float, save := true) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	if save:
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
