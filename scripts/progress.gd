extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level, skin and hat, `--skin=ID` picks a skin, `--random` plays randomizer mazes, `--hard` turns on hard mode, `--touch` shows touch controls, `--hat=ID` wears a hat, `--tickets=N` sets the ticket balance, `--jelly` tries the see-through slime, `--upgrades=a,b,c` / `--coins=N` set upgrade levels and coins (for promo shots), `--quiet-window` (from tools/play.ps1) cleans up after a no-focus start, `--save-path=user://x.cfg` saves to that file. Any debug flag, test, headless or movie run saves to a per-process throwaway file, never user://save.cfg.

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

const REAL_SAVE_PATH := "user://save.cfg"
## Throwaway saves are this + the process id + ".cfg" (deleted on start and on quit).
const THROWAWAY_PREFIX := "user://test_save_run_"
## Where progress is saved. Only a normal launch uses the real save; tests, demo scenes, headless,
## movie/screenshot and dev runs get a per-process throwaway file (see _default_save_path), and
## `--save-path=user://x.cfg` picks one explicitly.
var save_path := _default_save_path()
## Save codes start with this (the 1 is the format, in case it ever changes).
const SAVE_CODE_PREFIX := "SLIME1-"
## The stopwatch skin's "notice seen" mark in skin_notices_seen (level numbers are 1-10).
const STOPWATCH_NOTICE := 200
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of story levels beaten so far (0-10). Also decides which skins are unlocked.
var levels_cleared := 0
## Bit set of wordless hints already used (TUTORIAL_MOVE / TUTORIAL_LEAP); saved, optional key.
var tutorial_seen := 0
## Story beats shown (bits STORY_INTRO / STORY_FINALE). Optional in saves; RESET PROGRESS clears it.
var story_seen := 0
const STORY_INTRO := 1
const STORY_FINALE := 2
## Dry-ups per story level since it was last cleared (not saved); drives the chalice beacon.
var dry_ups := {}
## Story level the game scene loads next.
var current_level := 1

## Save layout version, written to [meta]. 2 = globs + per-level medal bitmasks (PAR/CLEAN/COINS);
## 3 = TICKET VOUCHERS (randomizer-only, kept under the old [wallet] globs keys) + medal TIERS.
## Anything older than 3 gets its medals converted when it is read (see _migrate_medals).
## 4 = the redesigned story layouts (random-class spawns, docs/level-design.md): coin keys from an
## older save are re-mapped by COUNT to the new layout's coins (see _migrate_coins).
const SAVE_VERSION := 4
## The first save version whose story coin keys / best times belong to the current layouts.
const LAYOUT_VERSION := 4
## TICKET VOUCHERS: the renewable, cosmetic-only currency (never converted to or from coins). The
## ONLY faucet is the randomizer, whose goal IS a ticket: a win pays by how many attempts that maze
## took (RANDOM_ATTEMPT_PAY: first try 5, then 4, 3, 2, and 1 from the fifth on), at most 5 paying
## wins per UTC day (so at most 25 a day). A player with no MORE SLIME upgrade bought, and a typed or
## replayed seed, get at most 1 per win. The only sink so far is the hat wheel (12, then +2 for each
## spin already taken, up to 40).
## (Saved under the old [wallet] keys "globs" and "globs_lifetime" so existing saves still load.)
const TICKETS_MAX := 99999
## Tickets a randomizer win pays on attempt 1, 2, 3 ... of that maze; later attempts pay the last.
const RANDOM_ATTEMPT_PAY: Array[int] = [5, 4, 3, 2, 1]
## Payout cap for a player who has bought no MORE SLIME upgrade ("excess slime"), and for a typed or
## replayed seed (a memorized seed can't be farmed).
const TICKETS_NO_SLIME_CAP := 1
const TICKETS_REPLAY_CAP := 1
## Randomizer wins that pay tickets per UTC day.
const RANDOM_PAID_PER_DAY := 5
const PAID_SEEDS_MAX := 10
## Hat wheel price: the first spin is free, the second costs SPIN_COST, each later one SPIN_STEP more
## (spins already taken beyond the second), never above SPIN_COST_MAX.
const SPIN_COST := 12
const SPIN_STEP := 2
const SPIN_COST_MAX := 40
const RAINBOW_PITY_MAX := 40
## Spins kept when a save is read (a hostile save can't push the price math anywhere odd).
const SPINS_MAX := 100000
## Level medals: the best clear-time tier per level and mode (a small int, saved under [medals]).
## Gold (3) = at or under the level's par time, silver (2) = within SILVER_FACTOR x par, bronze (1)
## = any unassisted clear. Hard mode keeps its own tiers (same thresholds) that don't count toward
## all_medals().
const TIER_NONE := 0
const TIER_BRONZE := 1
const TIER_SILVER := 2
const TIER_GOLD := 3
const GOLD_FACTOR := 1.0
const SILVER_FACTOR := 1.3
## Slime reserve (ASSIST): after this many dry-ups on one level in a session, the next attempt
## can be played with a bit more slime (never on hard mode; no medals, records or tickets).
const ASSIST_AFTER := 3
const ASSIST_BONUS := 0.10
var tickets := 0
var tickets_lifetime := 0
## Best medal tier per level (hard mode's under level + HARD_RECORDS): key -> 1..3.
var medals := {}
## Hat wheel: spins made in all, and spins since the rainbow hat was last rolled (pity).
var spins := 0
var rainbow_pity := 0
## UTC day number and how many randomizer wins were paid on it.
var random_pay_day := 0
var random_paid := 0
## Seeds that paid a randomizer win on random_pay_day (newest last, at most PAID_SEEDS_MAX): the
## same seed pays nothing again that day.
var random_paid_seeds: Array[int] = []
## Not saved: false once the current seed was typed in or already won (replayed), which pays at most
## TICKETS_REPLAY_CAP. NEW MAZE makes it true again.
var random_seed_fresh := true
## Not saved: attempts (starts, incl. dry-up retries and restarts) per randomizer maze this session,
## keyed by random_attempt_key (the seed code). NEW MAZE clears it.
var random_attempts := {}
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
## Dev toggles (Game.set_dev_bright / set_dev_no_drain; F1 / F2 in a level): kept for the session so
## they survive restarts, never saved.
var dev_bright := false
var dev_no_drain := false
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
## Not saved: the MORE SLIME level the current seed's maze is built for (part of its seed code),
## or -1 until the maze is built, which then takes the player's own level.
var random_level := -1
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
	if save_path == _throwaway_save_path():
		_clear_throwaway_saves()  # fresh every run
	if _is_test_or_tool_run():
		story_seen = STORY_INTRO | STORY_FINALE  # tests start levels directly; story tests reset this
	elif save_path == _throwaway_save_path():
		load_progress(REAL_SAVE_PATH)  # dev/headless/movie runs read the player's save, never write it
	else:
		load_progress()
	apply_bindings()
	apply_volume()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)
		elif arg == "--unlock-all":
			saving_enabled = false
			story_seen = STORY_INTRO | STORY_FINALE
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
		elif arg.begins_with("--medals="):  # medal tiers for levels 1, 2, ... e.g. 3,2,1 (not saved)
			saving_enabled = false
			var tiers := arg.trim_prefix("--medals=").split(",")
			for i in mini(tiers.size(), Levels.COUNT):
				medals[i + 1] = clampi(tiers[i].to_int(), 0, TIER_GOLD)
		elif arg.begins_with("--tickets="):  # this many tickets in hand (not saved)
			saving_enabled = false
			tickets = clampi(arg.trim_prefix("--tickets=").to_int(), 0, TICKETS_MAX)
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


## Removes this run's throwaway save when the game quits (only the autoload owns it).
func _exit_tree() -> void:
	if _owns_throwaway_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _owns_throwaway_save() -> bool:
	return save_path == _throwaway_save_path() and get_parent() != null and get_parent() == get_tree().root


## A per-process scratch save, so concurrent test runs never share (and corrupt) one file.
static func _throwaway_save_path() -> String:
	return "%s%d.cfg" % [THROWAWAY_PREFIX, OS.get_process_id()]


## Deletes this run's throwaway save (fresh, deterministic start) and any left behind by runs that
## crashed more than a few hours ago (another run's live file is never that old... and is not ours).
func _clear_throwaway_saves() -> void:
	var own := ProjectSettings.globalize_path(save_path)
	DirAccess.remove_absolute(own)
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var prefix := THROWAWAY_PREFIX.trim_prefix("user://")
	var now := Time.get_unix_time_from_system()
	for file in dir.get_files():
		if file.begins_with(prefix) and file.ends_with(".cfg"):
			var path := "user://" + file
			if now - FileAccess.get_modified_time(path) > 6 * 3600:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## True for anything that is not the player just playing: a script (tests), a scene under
## res://tests/ or res://tools/, headless, movie/screenshot capture, editor/CLI tool modes, and
## any debug flag after `--` (dev mode, --level=, --skin=...). Only `--quiet-window` (tools/play.ps1's
## normal launch) and `--save-path=` are allowed on a player launch.
static func _is_non_player_run() -> bool:
	const TOOL_FLAGS := ["-s", "--script", "--headless", "--write-movie", "--quit", "--quit-after",
		"--fixed-fps", "--import", "--check-only", "--doctor", "--dev", "--unlock-all", "--editor", "-e"]
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg in TOOL_FLAGS or arg.begins_with("--write-movie=") or arg.begins_with("--script=") \
				or arg.begins_with("--export") or arg.begins_with("res://tests/") \
				or arg.begins_with("res://tools/") or arg.ends_with(".gd"):
			return true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("-") and arg != "--quiet-window" and not arg.begins_with("--save-path="):
			return true
	return DisplayServer.get_name() == "headless"


## The real save for a normal launch, otherwise a throwaway per process. `--save-path=user://x.cfg`
## (before or after `--`) picks a file explicitly; the real save is refused outside a normal launch.
static func _default_save_path() -> String:
	var explicit := ""
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			explicit = arg.trim_prefix("--save-path=")
	var non_player := _is_non_player_run()
	if explicit != "" and not (non_player and _is_real_save(explicit)):
		return explicit
	return _throwaway_save_path() if non_player else REAL_SAVE_PATH


## True if `path` is the player's real save file (however it's spelled).
static func _is_real_save(path: String) -> bool:
	return ProjectSettings.globalize_path(path).simplify_path() == ProjectSettings.globalize_path(REAL_SAVE_PATH).simplify_path()


## Tests, screenshots and promo renders (scripts and scenes under res://tests/ or res://tools/)
## start from a fresh default state instead of the player's save, so whatever the player last
## did (hard mode on, jelly off...) can't change what they check or show.
static func _is_test_or_tool_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("res://tools/"):
			return true
	return false


## Loads `path` (default: save_path). Saving still only ever goes to save_path.
func load_progress(path := "") -> void:
	var file := ConfigFile.new()
	if file.load(save_path if path == "" else path) != OK:
		return
	_read(file)
	# An older save was migrated in memory; write it back once so the migration (which builds
	# every story maze) doesn't rerun on each launch.
	if _int(file, "meta", "version", 0) < SAVE_VERSION:
		save_progress()


## Takes everything from a save (the save file or a loaded save code).
func _read(file: ConfigFile) -> void:
	levels_cleared = clampi(_int(file, "progress", "levels_cleared", 0), 0, Levels.COUNT)
	highest_unlocked = clampi(_int(file, "progress", "highest_unlocked", 1), 1, Levels.COUNT)
	current_level = clampi(_int(file, "progress", "current_level", 1), 1, highest_unlocked)
	randoms_won = maxi(_int(file, "progress", "randoms_won", 0), 0)
	# Saves from before the cues existed have no key: a returning player has seen it all.
	var returning := levels_cleared > 0 or randoms_won > 0
	tutorial_seen = maxi(_int(file, "progress", "tutorial_seen", TUTORIAL_MOVE | TUTORIAL_LEAP if returning else 0), 0)
	# Saves from before the story: a returning player has already played past the intro (and a
	# beaten game past the finale).
	story_seen = maxi(_int(file, "progress", "story_seen", (STORY_INTRO if returning else 0) | (STORY_FINALE if levels_cleared >= Levels.COUNT else 0)), 0)
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
	if _int(file, "meta", "version", 1) < LAYOUT_VERSION:
		_migrate_coins()
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


## Story coins from a save made on the pre-v4 layouts: their keys name cells of the old mazes. Each
## level keeps its COUNT of found coins (as counted before, capped at Levels.COINS), now as the first
## N coins of the new layout (Levels.coin_keys order), so coins_earned, and with it the coins spent
## on upgrades, stays exactly the same and nobody's balance can go negative. A pure function of
## the old data: reading the same old save or SLIME1- code again gives the same result, and the
## next save is version 4, which is never migrated again.
func _migrate_coins() -> void:
	for level: int in coins_found.keys():
		var count := coins_found_in(level)
		if level < 1 or level > Levels.COUNT or count <= 0:
			coins_found.erase(level)
			continue
		var keys: Array = []
		keys.assign(Levels.coin_keys(level).slice(0, count))
		coins_found[level] = keys


## Tickets, medals and hat-wheel counters. Every key is optional: a save from before them gets
## zeros. The ticket balance sits under the old [wallet] keys "globs" / "globs_lifetime" (the old
## clears_paid / hard_clears_paid / retro-grant keys are ignored: tickets now come only from the
## randomizer, and an existing balance is kept as it is). Medals from a save older than version 3
## are bitmasks and get converted to tiers (_migrate_medals).
func _read_wallet(file: ConfigFile) -> void:
	tickets = clampi(_int(file, "wallet", "globs", 0), 0, TICKETS_MAX)
	tickets_lifetime = clampi(_int(file, "wallet", "globs_lifetime", tickets), 0, 100 * TICKETS_MAX)
	random_pay_day = maxi(_int(file, "wallet", "random_day", 0), 0)
	random_paid = clampi(_int(file, "wallet", "random_paid", 0), 0, RANDOM_PAID_PER_DAY)
	random_paid_seeds.assign(_ints(file.get_value("wallet", "paid_seeds", [])).slice(-PAID_SEEDS_MAX))
	spins = clampi(_int(file, "hats", "spins", 0), 0, SPINS_MAX)
	rainbow_pity = clampi(_int(file, "hats", "rainbow_pity", 0), 0, RAINBOW_PITY_MAX)
	medals = {}
	# Older saves, and a version 3 save with best times but no [medals] section at all, get tiers from
	# their best times; otherwise stored tiers count when 1-3 (anything else is 0).
	var version := _int(file, "meta", "version", 1)
	var migrate := version < 3 or (not file.has_section("medals") and not best_times.is_empty())
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + HARD_RECORDS]:
			var stored := _int(file, "medals", "level_%d" % key, 0)
			var tier := _migrate_medals(key, version < LAYOUT_VERSION) if migrate else (stored if stored >= TIER_BRONZE and stored <= TIER_GOLD else TIER_NONE)
			if tier > 0:
				medals[key] = tier


## The tier for a level key from a version 1-2 save: its best time against the level's par when it
## has one (so nobody loses a medal they would have earned), else bronze when the level was cleared,
## else none (the old bitmask bits themselves are dropped). Needs best_times / levels_cleared / hard_cleared read first.
## A pure function of the old data, so reading the same old save twice gives the same result.
## `legacy`: the times were set on the pre-v4 layouts, so they are measured against those pars
## (Levels.legacy_par), giving exactly the tiers this migration gave before the redesign.
func _migrate_medals(key: int, legacy := true) -> int:
	var hard := key > HARD_RECORDS
	var level := key - HARD_RECORDS if hard else key
	var best: float = best_times.get(key, -1.0)
	if is_finite(best) and best > 0.0:
		return tier_for(best, Levels.legacy_par(level, hard) if legacy else Levels.level_par(level, hard))
	var cleared := (level in hard_cleared) if hard else (level <= levels_cleared)
	return TIER_BRONZE if cleared else TIER_NONE


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
	file.set_value("progress", "story_seen", story_seen)
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
	file.set_value("wallet", "globs", tickets)  # (the old name; see _read_wallet)
	file.set_value("wallet", "globs_lifetime", tickets_lifetime)
	file.set_value("wallet", "random_day", random_pay_day)
	file.set_value("wallet", "random_paid", random_paid)
	file.set_value("wallet", "paid_seeds", random_paid_seeds)
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


func has_seen_story(bit: int) -> bool:
	return story_seen & bit != 0


func mark_story_seen(bit: int) -> void:
	if not has_seen_story(bit):
		story_seen |= bit
		save_progress()


func mark_tutorial_seen(bit: int) -> void:
	if not has_seen_tutorial(bit):
		tutorial_seen |= bit
		save_progress()


func start_story(level: int) -> void:
	mode = MODE_STORY
	current_level = clampi(level, 1, highest_unlocked)


## Records a randomizer win (saved) and pays its tickets for winning on `attempt` (see
## random_payout: the attempt table, capped at 1 for a typed / replayed seed or no MORE SLIME bought;
## 0 once today's 5 paying wins are used, while assisted (or dev toggles), or for a seed that already
## paid today). Returns the tickets paid. The maze stays the same until the player picks NEW MAZE.
func complete_random(assisted := false, seed_value := 0, attempt := 1) -> int:
	randoms_cleared += 1
	randoms_won += 1
	var paid := 0
	if not assisted:
		if utc_day() > random_pay_day:  # a new day: the cap starts over (never when the clock went back)
			random_pay_day = utc_day()
			random_paid = 0
			random_paid_seeds.clear()
		paid = random_tickets_due(attempt, seed_value)
		if paid > 0:
			random_paid += 1
			if seed_value != 0:
				random_paid_seeds.append(seed_value)
				while random_paid_seeds.size() > PAID_SEEDS_MAX:
					random_paid_seeds.remove_at(0)
		add_tickets(paid, false)
	if seed_value != 0:
		random_seed_fresh = false  # winning it again is a replay
	save_progress()
	return paid


## The key random_attempts counts a maze's starts under: its seed code (+ hard mode).
static func random_attempt_key(seed_value: int, seed_level: int, hard := false) -> String:
	return Levels.seed_code(seed_value, seed_level) + ("H" if hard else "")


## Counts one more start of the maze under `key` and returns which attempt this is (1 = first).
func begin_random_attempt(key: String) -> int:
	random_attempts[key] = int(random_attempts.get(key, 0)) + 1
	return random_attempts[key]


## Tickets a win pays on attempt `attempt` before any cap: 5, 4, 3, 2, then 1 from the fifth on.
static func tickets_for_attempt(attempt: int) -> int:
	return RANDOM_ATTEMPT_PAY[clampi(attempt, 1, RANDOM_ATTEMPT_PAY.size()) - 1]


# ---------------------------------------------------------------- tickets and medals

## Today as a UTC day number (days since 1970).
func utc_day() -> int:
	return day_override if day_override >= 0 else int(Time.get_unix_time_from_system() / 86400.0)


## What a randomizer win on `attempt` would pay right now (see random_payout).
func random_tickets_due(attempt := 1, seed_value := 0) -> int:
	return random_payout(attempt, seed_value).tickets


## What a randomizer win on `attempt` of the maze `seed_value` would pay right now, and why it is
## less than the table says: {tickets, table, cap} with cap "" (full), "daily" (today's paying wins
## are used up: 0), "paid" (this seed already paid today: 0), "replay" (a typed or replayed seed: 1)
## or "slime" (no MORE SLIME bought: 1). Assisted / dev-toggled runs are the caller's (they pay 0).
func random_payout(attempt := 1, seed_value := 0) -> Dictionary:
	var table := tickets_for_attempt(attempt)
	var open := utc_day() > random_pay_day or random_paid < RANDOM_PAID_PER_DAY
	if not open:
		return {tickets = 0, table = table, cap = "daily"}
	if seed_paid_today(seed_value):
		return {tickets = 0, table = table, cap = "paid"}
	if not random_seed_fresh and table > TICKETS_REPLAY_CAP:
		return {tickets = TICKETS_REPLAY_CAP, table = table, cap = "replay"}
	if int(upgrades.get("slime", 0)) <= 0 and table > TICKETS_NO_SLIME_CAP:
		return {tickets = TICKETS_NO_SLIME_CAP, table = table, cap = "slime"}
	return {tickets = table, table = table, cap = ""}


## True when `seed_value` already paid a win on the current UTC day.
func seed_paid_today(seed_value: int) -> bool:
	return seed_value != 0 and utc_day() <= random_pay_day and seed_value in random_paid_seeds


## Adds tickets (kept within 0-99,999; the amount actually added is returned). Saves unless told not to.
func add_tickets(amount: int, save := true) -> int:
	var before := tickets
	tickets = clampi(tickets + amount, 0, TICKETS_MAX)
	var added := tickets - before
	if added > 0:
		tickets_lifetime += added
	if save and added != 0:
		save_progress()
	return added


func medal_key(level: int) -> int:
	return _record_key(level)


## The best medal tier (0-3) won on `level` in the current mode.
func medals_for(level: int) -> int:
	return clampi(int(medals.get(medal_key(level), 0)), 0, TIER_GOLD)


## The tier a clear in `run_time` seconds earns on a level with par time `par`: gold at or under
## par, silver within SILVER_FACTOR x par, bronze for any other clear.
static func tier_for(run_time: float, par: float) -> int:
	if run_time <= par * GOLD_FACTOR:
		return TIER_GOLD
	if run_time <= par * SILVER_FACTOR:
		return TIER_SILVER
	return TIER_BRONZE


## Records a cleared story level: its medal tier (kept when it is the best so far) and, with
## `finish`, the best time and the level's cleared mark (record_time + complete_level) in that same
## save. A clear played with the slime reserve earns nothing. Returns {tier (this run's), best
## (the saved tier now), new_best (this run raised it, first clear included), assisted}.
func record_clear(level: int, run_time: float, par: float, assisted := false, finish := false) -> Dictionary:
	var result := {tier = 0, best = medals_for(level), new_best = false, assisted = assisted}
	if assisted:
		return result
	var tier := tier_for(run_time, par)
	result.tier = tier
	if tier > result.best:
		medals[medal_key(level)] = tier
		result.best = tier
		result.new_best = true
	if finish:
		record_time(level, run_time, false)
		complete_level(level, false)
	save_progress()
	return result


## Medal tiers won across the story in one mode (the current one unless `hard` says otherwise).
func medals_total(hard: Variant = null) -> int:
	var total := 0
	var offset := HARD_RECORDS if (hard_mode if hard == null else hard) else 0
	for level in range(1, Levels.COUNT + 1):
		total += clampi(int(medals.get(level + offset, 0)), 0, TIER_GOLD)
	return total


## The most medals there are to win in one mode (3 per level).
static func medals_max() -> int:
	return Levels.COUNT * TIER_GOLD


## True when every normal-mode level has a gold (tier 3). Hard-mode tiers don't count. (A future
## STOPWATCH skin unlocks on this.)
func all_medals() -> bool:
	return medals_total(false) == medals_max()


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
	random_level = -1
	random_seed_fresh = true
	random_attempts.clear()  # a new maze starts counting at attempt 1


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
## are out (Hats.available), with a hat left to win and the first spin or 12 tickets to pay for it.
func can_spin_hats() -> bool:
	if hats_left().is_empty():
		return false
	if dev_tools:
		return true
	return Hats.available and spin_cost() <= tickets


## What the next spin costs: nothing in dev mode and for the very first spin, then SPIN_COST plus
## SPIN_STEP for every spin already taken after the second, up to SPIN_COST_MAX.
func spin_cost() -> int:
	return 0 if dev_tools or spins == 0 else spin_cost_after(spins)


## The price of the spin that follows `taken` spins (0 = the free first one).
static func spin_cost_after(taken: int) -> int:
	if taken <= 0:
		return 0
	# The step count is clamped first, so no input (not even one near 2^62) can overflow into a negative price.
	return clampi(SPIN_COST + SPIN_STEP * mini(taken - 1, 20), SPIN_COST, SPIN_COST_MAX)


## One whole spin, done before the wheel starts turning: picks the hat (the rare rainbow hat gets
## more likely with every spin that misses it), takes the tickets, wins the hat and saves, all
## together, so closing the game mid-spin can't lose a payment or a prize. `roll` (0-1) picks
## the hat; leave it -1 for a random one. Returns the hat's id, or "" if it can't spin.
func spin_hat(roll := -1.0) -> String:
	if not can_spin_hats():
		return ""
	var left := hats_left()
	var pick := Hats.pick(left, rainbow_pity, randf() if roll < 0.0 else roll)
	tickets -= spin_cost()
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
	return Skins.is_unlocked(id, levels_cleared, hard_cleared, jelly if jelly_version == null else jelly_version, coins_earned(), all_medals())


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
	story_seen = 0
	dry_ups = {}
	tickets = 0
	tickets_lifetime = 0
	medals = {}
	spins = 0
	rainbow_pity = 0
	random_pay_day = 0
	random_paid = 0
	random_paid_seeds.clear()
	random_seed_fresh = true
	random_attempts.clear()
	assist_level = 0
	save_progress()


## True when the rainbow skin is in use (and unlocked).
func is_rainbow() -> bool:
	return active_skin() == Skins.RAINBOW and is_skin_unlocked(Skins.RAINBOW)


## True when the stopwatch skin is in use (and unlocked).
func is_stopwatch() -> bool:
	return active_skin() == Skins.STOPWATCH and is_skin_unlocked(Skins.STOPWATCH)


func skin_color() -> Color:
	var id := active_skin()
	if skin_override == "" and not is_skin_unlocked(id):
		return Skins.get_preset(Skins.DEFAULT).color
	if id == Skins.STOPWATCH:
		return Skins.STOPWATCH_BASE
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
