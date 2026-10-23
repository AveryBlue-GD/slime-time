class_name SaveFile
extends RefCounted

## Reading and writing the save (Progress's state <-> a ConfigFile), split out of progress.gd.
## Every function is static and takes `p` = the Progress node whose fields it reads or fills;
## Progress._read / _write / _read_store call in here. Save paths, atomic writes, retries and save
## codes stay in Progress.


## Fills `p` from a save (see Progress._read).
static func read(p: Node, file: ConfigFile, from_code := false) -> void:
	p.levels_cleared = clampi(get_int(file, "progress", "levels_cleared", 0), 0, Levels.COUNT)
	p.highest_unlocked = clampi(get_int(file, "progress", "highest_unlocked", 1), 1, Levels.COUNT)
	p.current_level = clampi(get_int(file, "progress", "current_level", 1), 1, p.highest_unlocked)
	p.randoms_won = maxi(get_int(file, "progress", "randoms_won", 0), 0)
	# Saves from before the cues existed have no key: a returning player has seen it all.
	var returning: bool = p.levels_cleared > 0 or p.randoms_won > 0
	p.tutorial_seen = maxi(get_int(file, "progress", "tutorial_seen", p.TUTORIAL_MOVE | p.TUTORIAL_LEAP if returning else 0), 0)
	# Saves from before the story: a returning player has already played past the intro (and a
	# beaten game past the finale).
	p.story_seen = maxi(get_int(file, "progress", "story_seen", (p.STORY_INTRO if returning else 0) | (p.STORY_FINALE if p.levels_cleared >= Levels.COUNT else 0)), 0)
	var color: Variant = file.get_value("skin", "custom_color", p.custom_color)
	p.custom_color = color if typeof(color) == TYPE_COLOR else p.custom_color
	p.hats_owned.assign(strings(file.get_value("hats", "owned", [])))
	p.hat_dyes_owned.clear()
	for key in strings(file.get_value("hats", "dyes", [])):
		if p._dye_key_valid(key) and not key in p.hat_dyes_owned:
			p.hat_dyes_owned.append(key)
	p.hat_dyes = {}
	for key in strings(file.get_value("hats", "dyes_worn", [])):
		if key in p.hat_dyes_owned:
			p.hat_dyes[key.get_slice(":", 0)] = key.get_slice(":", 1)
	p.selected_hat = get_string(file, "skin", "hat", Hats.NONE)
	p.hub_skin = get_string(file, "skin", "hub", "")
	var hub_tint: Variant = file.get_value("skin", "hub_custom", p.hub_custom)
	p.hub_custom = hub_tint if typeof(hub_tint) == TYPE_COLOR else p.hub_custom
	if not p.is_hat_unlocked(p.selected_hat):
		p.selected_hat = Hats.NONE
	p.sound_on = get_bool(file, "settings", "sound_on", true)
	p.volume = clampf(get_float(file, "settings", "volume", p.volume), 0.0, 1.0)
	p.music_volume = clampf(get_float(file, "settings", "music_volume", p.music_volume), 0.0, 1.0)
	p.level_music = get_bool(file, "settings", "level_music", true)
	p.hard_mode = get_bool(file, "settings", "hard_mode", false)
	p.reduce_motion = get_bool(file, "settings", "reduce_motion", p.reduce_motion)
	p.vibration = get_bool(file, "settings", "vibration", p.vibration)
	p.relaxed = get_bool(file, "settings", "relaxed", false)
	p.fog_brightness = clampi(get_int(file, "settings", "fog_brightness", p.fog_brightness), p.FOG_DARK, p.FOG_BRIGHT)
	p.fullscreen = get_bool(file, "settings", "fullscreen", false)
	if not from_code:  # a code never brings a language: the device keeps its own
		p.language = locale_code(get_string(file, "settings", "language", ""))
	p.skin_notices_seen.assign(ints(file.get_value("progress", "skin_notices_seen", [])))
	p.hard_cleared.assign(ints(file.get_value("progress", "hard_cleared", [])))
	p.best_times = {}
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + p.HARD_RECORDS]:
			if file.has_section_key("records", "level_%d" % key):
				var best := get_float(file, "records", "level_%d" % key, 0.0)
				if best >= p.MIN_RECORD:  # a 0 s / negative record (hand-made) could never be beaten (S4)
					p.best_times[key] = best
	p.coins_found = {}
	for level in range(1, Levels.COUNT + 1):
		var found: Array = []
		found.assign(strings(file.get_value("coins", "level_%d" % level, [])))
		if not found.is_empty():
			p.coins_found[level] = found
	p.upgrades = {}
	var tree := get_int(file, "upgrades", "tree", 1)
	var new_tree := tree >= 2  # levels of the 7 / 4 / 3 tracks (tree 2 prices or later)
	for upgrade: Dictionary in Upgrades.LIST:
		var top: int = Upgrades.max_level(upgrade.id) if new_tree else Economy.OLD_TREE_LEVELS
		var level := clampi(get_int(file, "upgrades", upgrade.id, 0), 0, top)
		if level > 0:
			p.upgrades[upgrade.id] = level
	p.tree_refund_notice = clampi(get_int(file, "upgrades", "refund_notice", 0), 0, Upgrades.full_tree_cost()) if new_tree else 0
	if not new_tree:
		p._migrate_tree()
	if tree < Economy.TREE_VERSION:
		p._migrate_prices()
	if Demo.on() and p.is_demo_save(file):  # a demo save from older, higher caps: back to today's (the coins return)
		for id: String in p.upgrades.keys():
			if p.upgrades[id] > Demo.upgrade_cap(id):
				if Demo.upgrade_cap(id) > 0:
					p.upgrades[id] = Demo.upgrade_cap(id)
				else:
					p.upgrades.erase(id)
	var guarded: bool = Demo.on() and not p.is_demo_save(file)  # a full save in the demo: in memory only, left alone
	if p.is_demo_save(file):  # bought at the demo's prices (Demo.PRICES): over this build's, a level at a time back
		while p._coins_balance() < 0 and p._drop_priciest_level():
			pass
	while p._coins_balance() < 0 and not p.upgrades.is_empty() and not guarded:  # never spend more than was found
		p.upgrades.erase(p.upgrades.keys()[0])
	p.tree_refund_notice = clampi(p.tree_refund_notice, 0, maxi(p.coins(), 0))  # (a hand-made save can't claim more)
	_read_bindings(p, file)
	_read_wallet(p, file)
	_read_descent(p, file, from_code)
	read_store(p, file)
	_read_maps(p, file)
	# The skin last, once everything that unlocks skins (levels, hard clears, coins) is loaded.
	p.selected_skin = get_string(file, "skin", "selected", Skins.DEFAULT)
	# The saved look is only a wish: what is unlocked is recomputed from the progress above (normal
	# clears, coins, medals, hard clears) under the current rules (D14: opaque = normal mode, jelly =
	# hard mode, pastel = randomizer wins). A look that is not unlocked falls back to that skin
	# without pastel, then to its opaque version, then to Lime.
	p.set_jelly(get_bool(file, "skin", "jelly", false))
	p.set_pastel(get_bool(file, "skin", "pastel", false) and Skins.has_pastel(p.selected_skin))
	if not p.is_skin_unlocked(p.selected_skin):  # e.g. a skin that moved, or a jelly one not earned on hard
		p.set_pastel(false)
		if not p.is_skin_unlocked(p.selected_skin):
			p.set_jelly(false)
			if not p.is_skin_unlocked(p.selected_skin):
				p.selected_skin = Skins.DEFAULT
	p.ach_seeded = file.has_section("achievements")
	p.ach_known = strings(file.get_value("achievements", "known", []))
	p.ach_flags = clampi(get_int(file, "achievements", "flags", 0), 0, 63)
	p.medal_milestones_paid = clampi(get_int(file, "achievements", "milestones", 0), 0, 100000)


## Key bindings from [controls] (S6): a key that is missing, not a key code, or already taken by
## another action falls back to that action's default; if that leaves two actions on one key, every
## binding goes back to the defaults (the CONTROLS page can change them again).
static func _read_bindings(p: Node, file: ConfigFile) -> void:
	var used := {}
	for action: String in p.DEFAULT_KEYS:
		var key := get_int(file, "controls", action, p.DEFAULT_KEYS[action])
		if key <= 0 or key > p.KEY_MAX_CODE or used.has(key) or key in p.RESERVED_KEYS:
			key = p.DEFAULT_KEYS[action]
		if used.has(key) and action.begins_with("ability_"):
			# (an ability key missing from an older save, or broken: the first free spare, so the
			# player's other bindings are kept)
			for spare in p.ABILITY_SPARE_KEYS:
				if not used.has(spare):
					key = spare
					break
		if used.has(key):
			p.bindings = p.DEFAULT_KEYS.duplicate()
			return
		used[key] = true
		p.bindings[action] = key
	return


## Tickets, medals and hat-wheel counters. Every key is optional: a save from before them gets
## zeros. The ticket balance sits under the old [wallet] keys "globs" / "globs_lifetime" (the old
## clears_paid / hard_clears_paid / retro-grant keys are ignored: tickets now come only from the
## randomizer, and an existing balance is kept as it is).
static func _read_wallet(p: Node, file: ConfigFile) -> void:
	p.tickets = clampi(get_int(file, "wallet", "globs", 0), 0, p.TICKETS_MAX)
	p.tickets_lifetime = clampi(get_int(file, "wallet", "globs_lifetime", p.tickets), 0, 100 * p.TICKETS_MAX)
	p.random_pay_day = maxi(get_int(file, "wallet", "random_day", 0), 0)
	p.random_paid = clampi(get_int(file, "wallet", "random_paid", 0), 0, p.RANDOM_PAID_PER_DAY)
	p._check_pay_day()
	p.random_paid_seeds.assign(ints(file.get_value("wallet", "paid_seeds", [])).slice(-p.PAID_SEEDS_MAX))
	p.spins = clampi(get_int(file, "hats", "spins", 0), 0, p.SPINS_MAX)
	p.rainbow_pity = clampi(get_int(file, "hats", "rainbow_pity", 0), 0, p.RAINBOW_PITY_MAX)
	# A save or code from before the wheel had a seed gets one from its own text, so loading the same
	# old code again still rolls the same hats.
	p.wheel_seed = get_int(file, "hats", "seed", 0)
	if p.wheel_seed == 0 and file.has_section("progress"):
		p.wheel_seed = hash(file.encode_to_text()) | 1
	p.medals = {}
	# A save with best times but no [medals] section at all gets tiers from its best times; otherwise
	# stored tiers count when 1-3 (anything else is 0).
	var from_times: bool = not file.has_section("medals") and not p.best_times.is_empty()
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + p.HARD_RECORDS]:
			var stored := get_int(file, "medals", "level_%d" % key, 0)
			var tier: int = _tier_from_record(p, key) if from_times else (stored if stored >= p.TIER_BRONZE and stored <= p.TIER_GOLD else p.TIER_NONE)
			if tier > 0:
				p.medals[key] = tier


## DESCENT records and the daily counter ([descent]), and the saved run ([descent_run], not from a code).
static func _read_descent(p: Node, file: ConfigFile, from_code := false) -> void:
	p.descent_best_floor = clampi(get_int(file, "descent", "best_floor", 0), 0, p.DESCENT_FLOOR_MAX)
	p.descent_best_time = clampf(get_float(file, "descent", "best_time", 0.0), 0.0, 1.0e7)
	p.descent_runs = clampi(get_int(file, "descent", "runs", 0), 0, 100 * p.TICKETS_MAX)
	p.descent_pay_day = maxi(get_int(file, "descent", "paid_day", 0), 0)
	p.descent_paid = clampi(get_int(file, "descent", "paid_runs", 0), 0, Economy.DESCENT_PAID_PER_DAY)
	p._check_descent_day()
	p.descent_milestones = clampi(get_int(file, "descent", "milestones", 0), 0, (1 << Economy.DESCENT_MILESTONES.size()) - 1)
	p.daily_day = maxi(get_int(file, "daily", "day", 0), 0)
	p.daily_best_ms = clampi(get_int(file, "daily", "best_ms", 0), 0, 1000 * 100000)
	p.daily_streak = clampi(get_int(file, "daily", "streak", 0), 0, 100000)
	p.daily_best_streak = maxi(clampi(get_int(file, "daily", "best_streak", 0), 0, 100000), p.daily_streak)
	if p.daily_day > p.utc_day() + p.PAY_DAY_AHEAD:  # a future clock or a hand-made save: no daily on record
		p.daily_day = 0
		p.daily_best_ms = 0
		p.daily_streak = 0
	p.descent_run = {}
	p.descent_resume = {}
	if not from_code:
		p.descent_resume = p.read_descent_run(file)


## The ticket store (upgrades v2 batch 2), all optional with defaults: [workshop] levels clamped to
## each track (unknown keys ignored), [cosmetics] owned (allow-listed ids only, no repeats) and the
## worn trail / paper (back to the default unless owned), [hats] bought, [wallet] tickets_spent.
## Tickets can't be re-derived, so nothing is dropped as "couldn't have paid": only clamped.
static func read_store(p: Node, file: ConfigFile) -> void:
	p.workshop = {}
	for id in Workshop.ids():
		var level := clampi(get_int(file, "workshop", id, 0), 0, Workshop.max_level(id))
		if level > 0:
			p.workshop[id] = level
	p.abilities = {}
	for id in Abilities.ids():
		var ability_level := clampi(get_int(file, "abilities", id, 0), 0, Abilities.max_level(id))
		if ability_level > 0:
			p.abilities[id] = ability_level
	var owned: Array[String] = []
	for id in strings(file.get_value("cosmetics", "owned", [])):
		if Cosmetics.is_earned(id) and not p.cosmetic_earned(id):
			continue  # an earned cosmetic (ABYSS) counts only with its milestone
		if not Cosmetics.get_item(id).is_empty() and not id in owned:
			owned.append(id)
	p.cosmetics_owned.assign(owned)
	p.trail_style = get_string(file, "cosmetics", "trail", Cosmetics.DEFAULT_TRAIL)
	if not p.owns_cosmetic(p.trail_style) or Cosmetics.kind_of(p.trail_style) != Cosmetics.TRAIL:
		p.trail_style = Cosmetics.DEFAULT_TRAIL
	p.map_paper = get_string(file, "cosmetics", "paper", Cosmetics.DEFAULT_PAPER)
	if not p.owns_cosmetic(p.map_paper) or Cosmetics.kind_of(p.map_paper) != Cosmetics.PAPER:
		p.map_paper = Cosmetics.DEFAULT_PAPER
	p.hats_bought = clampi(get_int(file, "hats", "bought", 0), 0, Hats.LIST.size())
	p.tickets_spent = clampi(get_int(file, "wallet", "tickets_spent", 0), 0, 100 * p.TICKETS_MAX)


## The tier for a level key from its best time against the level's par when it has one, else bronze
## when the level was cleared, else none. Needs best_times / levels_cleared / hard_cleared read first.
static func _tier_from_record(p: Node, key: int) -> int:
	var hard: bool = key > p.HARD_RECORDS
	var level: int = key - p.HARD_RECORDS if hard else key
	var best: float = p.best_times.get(key, -1.0)
	if is_finite(best) and best > 0.0 and Levels.has_data(level, hard):  # (a demo export lacks later levels' pars)
		return p.tier_for(best, Levels.level_par(level, hard))
	var cleared: bool = (level in p.hard_cleared) if hard else (level <= p.levels_cleared)
	return p.TIER_BRONZE if cleared else p.TIER_NONE


## Trail map surveys ([maps] level_N, optional). Each is checked by Survey.unpack: anything broken,
## hostile or out of range is dropped (that level just has no survey yet); keys outside the 20 story
## levels are ignored. Old version-1 surveys (no layout fingerprint) are dropped by unpack; a survey of
## another layout is dropped when it's first used (survey_for) or replaced by the next run (record_survey).
static func _read_maps(p: Node, file: ConfigFile) -> void:
	p.maps = {}
	for level in range(1, Levels.COUNT + 1):
		for key in [level, level + p.HARD_RECORDS]:
			var survey := Survey.unpack(file.get_value("maps", "level_%d" % key, ""))
			if not survey.is_empty():
				var coins := _read_seen_coins(file.get_value("maps", "coins_%d" % key, []), survey)
				if not coins.is_empty():
					survey.seen_coins = coins
				p.maps[key] = survey
	p.maps_hint_seen = get_bool(file, "maps", "hint_seen", false)


## A survey's revealed coins ([maps] coins_N: cell x + y * 256 each, saved beside level_N): only
## cells inside the survey's maze, no repeats, at most 64 (Progress.map_coins then keeps only the
## level's real coin cells); anything else is dropped.
static func _read_seen_coins(value: Variant, survey: Dictionary) -> Array:
	var cells: Array = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_INT32_ARRAY and typeof(value) != TYPE_PACKED_INT64_ARRAY:
		return cells
	var size := Vector2i((int(survey.w) - 1) / 2, (int(survey.h) - 1) / 2)
	for code: Variant in value:
		if typeof(code) != TYPE_INT or cells.size() >= 64:
			continue
		var cell := Vector2i(int(code) % 256, int(code) / 256)
		if int(code) >= 0 and cell.x < size.x and cell.y < size.y and not cell in cells:
			cells.append(cell)
	return cells


## Type-safe save readers: a wrong-typed value (hand-edited or hostile save) gives the default.
static func get_int(file: ConfigFile, section: String, key: String, default: int) -> int:
	var v: Variant = file.get_value(section, key, default)
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v):
		return int(v)
	return default


static func get_float(file: ConfigFile, section: String, key: String, default: float) -> float:
	var v: Variant = file.get_value(section, key, default)
	if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v)):
		return float(v)
	return default


static func get_bool(file: ConfigFile, section: String, key: String, default: bool) -> bool:
	var v: Variant = file.get_value(section, key, default)
	return v if typeof(v) == TYPE_BOOL else default


## A saved locale code as written by Language.pick ("es", "pt_BR"...), or "" if it doesn't look like one.
## Whether it is a supported locale is Language's call.
static func locale_code(text: String) -> String:
	var ok := text.length() <= 8 and RegEx.create_from_string("^[a-z]{2,3}(_[A-Z]{2})?$").search(text) != null
	return text if ok else ""


static func get_string(file: ConfigFile, section: String, key: String, default: String) -> String:
	var v: Variant = file.get_value(section, key, default)
	return v if typeof(v) == TYPE_STRING else default


static func strings(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			if typeof(item) == TYPE_STRING:
				out.append(item)
	return out


static func ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			if typeof(item) == TYPE_INT:
				out.append(item)
	return out


## The save as a ConfigFile (see Progress._write).
static func write(p: Node, for_code := false) -> ConfigFile:
	var file := ConfigFile.new()
	file.set_value("meta", "version", p.SAVE_VERSION)
	file.set_value("meta", "epoch", p.RELEASE_EPOCH)
	if Demo.on():
		file.set_value("meta", "demo", true)  # (the full game reads every demo save and drops the marker)
	file.set_value("progress", "levels_cleared", p.levels_cleared)
	file.set_value("progress", "highest_unlocked", p.highest_unlocked)
	file.set_value("progress", "current_level", p.current_level)
	file.set_value("progress", "randoms_won", p.randoms_won)
	file.set_value("progress", "tutorial_seen", p.tutorial_seen)
	file.set_value("progress", "story_seen", p.story_seen)
	file.set_value("skin", "selected", p.selected_skin)
	file.set_value("skin", "custom_color", p.custom_color)
	file.set_value("skin", "jelly", p.jelly)
	file.set_value("skin", "pastel", p.pastel)
	if p.hub_skin != "":
		file.set_value("skin", "hub", p.hub_skin)
		file.set_value("skin", "hub_custom", p.hub_custom)
	file.set_value("skin", "hat", p.selected_hat)
	file.set_value("hats", "owned", p.hats_owned.duplicate())
	if not p.hat_dyes_owned.is_empty():
		file.set_value("hats", "dyes", p.hat_dyes_owned.duplicate())
	var worn: Array[String] = []
	for hat: String in p.hat_dyes:
		worn.append("%s:%s" % [hat, p.hat_dyes[hat]])
	if not worn.is_empty():
		file.set_value("hats", "dyes_worn", worn)
	file.set_value("settings", "sound_on", p.sound_on)
	file.set_value("settings", "volume", p.volume)
	file.set_value("settings", "music_volume", p.music_volume)
	if not p.level_music:
		file.set_value("settings", "level_music", false)
	file.set_value("settings", "hard_mode", p.hard_mode)
	file.set_value("settings", "reduce_motion", p.reduce_motion)
	file.set_value("settings", "vibration", p.vibration)
	file.set_value("settings", "fog_brightness", p.fog_brightness)
	if p.fullscreen:
		file.set_value("settings", "fullscreen", true)
	if p.relaxed:
		file.set_value("settings", "relaxed", true)
	if p.language != "" and not for_code:
		file.set_value("settings", "language", p.language)
	file.set_value("progress", "skin_notices_seen", p.skin_notices_seen)
	file.set_value("progress", "hard_cleared", p.hard_cleared)
	for level: int in p.best_times:
		file.set_value("records", "level_%d" % level, p.best_times[level])
	for level: int in p.coins_found:
		file.set_value("coins", "level_%d" % level, p.coins_found[level])
	file.set_value("upgrades", "tree", Economy.TREE_VERSION)
	for id: String in p.upgrades:
		file.set_value("upgrades", id, p.upgrades[id])
	if p.tree_refund_notice > 0:
		file.set_value("upgrades", "refund_notice", p.tree_refund_notice)
	for action: String in p.bindings:
		file.set_value("controls", action, p.bindings[action])
	file.set_value("wallet", "globs", p.tickets)  # (the old name; see _read_wallet)
	file.set_value("wallet", "globs_lifetime", p.tickets_lifetime)
	file.set_value("wallet", "random_day", p.random_pay_day)
	file.set_value("wallet", "random_paid", p.random_paid)
	file.set_value("wallet", "paid_seeds", p.random_paid_seeds)
	file.set_value("hats", "spins", p.spins)
	file.set_value("hats", "rainbow_pity", p.rainbow_pity)
	if p.wheel_seed == 0:
		p.wheel_seed = randi() | 1
	file.set_value("hats", "seed", p.wheel_seed)
	# The ticket store: written only once used, so a save without it stays as small as before.
	if p.hats_bought > 0:
		file.set_value("hats", "bought", p.hats_bought)
	if p.tickets_spent > 0:
		file.set_value("wallet", "tickets_spent", p.tickets_spent)
	for id: String in p.workshop:
		file.set_value("workshop", id, p.workshop[id])
	for id: String in p.abilities:
		file.set_value("abilities", id, p.abilities[id])
	if not p.cosmetics_owned.is_empty():
		file.set_value("cosmetics", "owned", p.cosmetics_owned.duplicate())
	if p.trail_style != Cosmetics.DEFAULT_TRAIL:
		file.set_value("cosmetics", "trail", p.trail_style)
	if p.map_paper != Cosmetics.DEFAULT_PAPER:
		file.set_value("cosmetics", "paper", p.map_paper)
	for key: int in p.medals:
		file.set_value("medals", "level_%d" % key, p.medals[key])
	for key: int in ([] if for_code and p.dev_tools else p.maps.keys()):  # a dev session's in-memory maps stay out of save codes
		file.set_value("maps", "level_%d" % key, Survey.pack(p.maps[key]))
		var seen_coins: Array = p.maps[key].get("seen_coins", [])
		if not seen_coins.is_empty():
			file.set_value("maps", "coins_%d" % key, seen_coins.map(func(cell: Vector2i) -> int: return cell.x + cell.y * 256))
	if p.maps_hint_seen:
		file.set_value("maps", "hint_seen", true)
	# DESCENT records and its daily counter: written only once a run has been played.
	if p.descent_best_floor > 0 or p.descent_runs > 0 or p.descent_pay_day > 0 or p.descent_milestones > 0:
		file.set_value("descent", "best_floor", p.descent_best_floor)
		file.set_value("descent", "best_time", p.descent_best_time)
		file.set_value("descent", "runs", p.descent_runs)
		file.set_value("descent", "paid_day", p.descent_pay_day)
		file.set_value("descent", "paid_runs", p.descent_paid)
		file.set_value("descent", "milestones", p.descent_milestones)
	if Economy.ACHIEVEMENTS and p.ach_seeded and not Demo.on():  # (a demo save carries no goals: the full game would toast them all)
		file.set_value("achievements", "known", p.ach_known.duplicate())
		file.set_value("achievements", "flags", p.ach_flags)
		file.set_value("achievements", "milestones", p.medal_milestones_paid)
	if p.daily_day > 0:
		file.set_value("daily", "day", p.daily_day)
		file.set_value("daily", "best_ms", p.daily_best_ms)
		file.set_value("daily", "streak", p.daily_streak)
		file.set_value("daily", "best_streak", p.daily_best_streak)
	# A Descent run in progress (D6): written only while one is saved.
	if not p.descent_resume.is_empty() and not for_code:
		file.set_value("descent_run", "format", p.DESCENT_RUN_FORMAT)
		for key: String in p.DESCENT_RESUME_KEYS:
			file.set_value("descent_run", key, p.descent_resume[key])
	return file
