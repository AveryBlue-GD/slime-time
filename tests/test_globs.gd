extends SceneTree

## Globs (the renewable cosmetic currency): wallet math for every faucet (first clears, medals, hard
## clears, randomizer wins capped per UTC day), no double payment, the hat wheel's atomic spin
## (free first spin, 12 globs after, picked + paid + won + saved before the wheel turns, rainbow
## pity), the wheel staying locked outside dev mode while hats are placeholders, and the save:
## round trip, an old save (no wallet) getting its earned first-clear globs once, the save code,
## RESET PROGRESS. Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_globs.gd

const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.dev_tools = false
	progress.hard_mode = false
	progress.reset_progress()

	# --- Faucets
	var win: Dictionary = progress.record_clear(1, 99.0, 10.0, 3, false)
	_check(win.first and win.globs == 4 and progress.globs == 4, "first clear of a level pays 4 (no medals: slow, splatted, coins missing)")
	win = progress.record_clear(1, 99.0, 10.0, 3, false)
	_check(win.globs == 0 and progress.globs == 4, "...and only once")
	win = progress.record_clear(1, 5.0, 10.0, 0, true)
	_check(win.globs == 6 and win.new_medals == Progress.MEDAL_ALL and progress.globs == 10, "all three medals pay 2 each, once they're won (+6)")
	win = progress.record_clear(1, 5.0, 10.0, 0, true)
	_check(win.globs == 0 and win.medals == Progress.MEDAL_ALL, "a medal pays only the first time it's won")
	win = progress.record_clear(2, 8.0, 10.0, 1, false)
	_check(win.globs == 6 and progress.medals_for(2) == Progress.MEDAL_PAR and win.new_medals == Progress.MEDAL_PAR, "level 2: first clear 4 + PAR medal 2")
	_check(progress.globs_lifetime == progress.globs, "lifetime globs count what was earned (%d)" % progress.globs_lifetime)
	progress.hard_mode = true
	win = progress.record_clear(1, 99.0, 10.0, 5, true)
	_check(win.first and win.globs == 8 and progress.medals_for(1) == 0, "first HARD clear pays 8, and hard medals are kept apart from the normal ones")
	win = progress.record_clear(1, 4.0, 10.0, 0, true)
	_check(win.medals == (Progress.MEDAL_PAR | Progress.MEDAL_CLEAN) and win.globs == 4, "no COINS medal on hard mode (par + clean = +4)")
	progress.hard_mode = false
	_check(progress.medals_for(1) == Progress.MEDAL_ALL, "...the normal medals are untouched")
	var before: int = progress.globs
	progress.coins_found = {1: ["1,1", "2,2"]}
	progress.upgrades = {"slime": 1}
	var coins_before: int = progress.coins()
	progress.add_globs(50)
	_check(progress.coins() == coins_before and progress.globs == before + 50, "globs and coins never mix")
	progress.add_globs(-progress.globs)
	_check(progress.globs == 0, "(spent down to zero)")
	progress.add_globs(1_000_000)
	_check(progress.globs == Progress.GLOBS_MAX, "the balance is capped at 99,999")
	progress.reset_progress()

	# --- Randomizer wins: capped per UTC day
	progress.day_override = 20000
	var paid := 0
	for i in 8:
		paid += progress.complete_random()
	_check(progress.globs == 10 and paid == 10 and progress.randoms_won == 8, "randomizer wins pay 2 each, 5 per day (%d globs from 8 wins)" % paid)
	progress.day_override = 20001
	_check(progress.random_globs_due() == 2 and progress.complete_random() == 2, "the next UTC day pays again")
	_check(progress.complete_random(true) == 0 and progress.globs == 12, "an assisted win never pays")
	progress.day_override = -1
	progress.reset_progress()

	# --- The hat wheel: locked outside dev mode while hats are placeholders
	progress.globs = 100
	_check(not Hats.available and not progress.can_spin_hats() and progress.spin_hat() == "" and progress.globs == 100,
		"hats not released: no spin outside dev mode, even with globs (nothing is taken)")
	Hats.available = true  # what follows is how it works once hats are real

	# --- Atomic spin
	progress.globs = 100
	var cost: int = progress.spin_cost()
	_check(cost == 0, "the first spin is free")
	var first: String = progress.spin_hat(0.0)
	_check(first != "" and first in progress.hats_owned and progress.globs == 100 and progress.spins == 1, "free spin: hat won, nothing paid (%s)" % first)
	_check(progress.spin_cost() == 12, "the next one costs 12")
	var second: String = progress.spin_hat(0.0)
	_check(second != "" and second != first and progress.globs == 88 and progress.hats_owned.size() == 2, "spin 2: pays 12, never a hat you own (%s)" % second)
	# The whole spin is saved at once: a fresh load sees the payment AND the prize.
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = TEST_SAVE
	reloaded.load_progress()
	_check(reloaded.globs == 88 and second in reloaded.hats_owned and reloaded.spins == 2, "payment and prize are saved together, before any animation")
	reloaded.free()
	progress.globs = 5
	_check(not progress.can_spin_hats() and progress.spin_hat() == "" and progress.globs == 5 and progress.hats_owned.size() == 2,
		"too few globs: no spin, nothing changes")
	progress.globs = 12
	_check(progress.spin_hat() != "" and progress.globs == 0, "exactly 12 is enough")
	progress.dev_tools = true
	progress.globs = 0
	_check(progress.can_spin_hats() and progress.spin_cost() == 0 and progress.spin_hat() != "" and progress.globs == 0, "dev mode spins free")
	progress.dev_tools = false

	# The wheel node asks Progress first: paid and won the moment spin() returns, before it turns.
	progress.reset_progress()
	progress.globs = 30
	progress.spins = 1
	var wheel: Control = load("res://scripts/ui/hat_wheel.gd").new()  # (loaded late: it names the Progress autoload)
	root.add_child(wheel)
	await process_frame
	_check(wheel.spin() and wheel.spinning and progress.globs == 18 and progress.hats_owned.size() == 1,
		"the wheel's spin is already paid and won while it's still turning")
	var landed_ids: Array[String] = []
	wheel.landed.connect(func(id: String) -> void: landed_ids.append(id))
	for i in 60 * 6:
		await physics_frame
		if not landed_ids.is_empty():
			break
	var landed: String = landed_ids[0] if not landed_ids.is_empty() else ""
	_check(landed == progress.hats_owned[0] and wheel.hats[wheel.wedge_at(wheel.turn)] == landed,
		"...and the wheel lands on exactly the hat it already won (%s)" % landed)
	_check(progress.globs == 18, "landing charges nothing more")
	wheel.free()

	# --- Rainbow pity
	_check(Hats.weight("rainbow") == 0.3 and is_equal_approx(Hats.weight("rainbow", 4), 0.3 + 4 * Hats.PITY_STEP) and Hats.weight("tophat", 9) == 1.0,
		"each missed spin fattens only the rainbow wedge")
	var ids := Hats.ids()
	_check(Hats.pick(ids, 0, 0.0) == "tophat" and Hats.pick(ids, 0, 0.9999) == "rainbow", "a roll walks along the wedges in wheel order")
	var odds: Array[int] = []
	for pity in [0, 10, 40]:
		var hits := 0
		for i in 1000:
			if Hats.pick(ids, pity, i / 1000.0) == "rainbow":
				hits += 1
		odds.append(hits)
	_check(odds[0] < odds[1] and odds[1] < odds[2], "rainbow odds grow with pity: %s in 1000" % [odds])
	progress.reset_progress()
	progress.globs = 1000
	progress.spins = 1
	var miss := 0
	for i in 3:
		progress.spin_hat(0.0)  # always the first hat left, never the rainbow
		miss += 1
	_check(progress.rainbow_pity == miss, "every spin that misses the rainbow adds pity (%d)" % progress.rainbow_pity)
	progress.hats_owned.assign(ids.filter(func(id: String) -> bool: return id != "rainbow"))
	_check(progress.spin_hat(0.0) == "rainbow" and progress.rainbow_pity == 0, "the last hat left is the rainbow one, and landing it resets the pity")
	_check(progress.hats_left().is_empty() and not progress.can_spin_hats(), "an empty wheel can't spin")
	Hats.available = false

	# --- The save: round trip
	progress.reset_progress()
	progress.levels_cleared = 4
	progress.hard_cleared.assign([1])
	progress.globs = 37
	progress.globs_lifetime = 120
	progress.clears_paid = 0b1011
	progress.hard_clears_paid = 1
	progress.medals = {1: 7, 3: 5, 101: 3}
	progress.spins = 4
	progress.rainbow_pity = 3
	progress.random_pay_day = 20000
	progress.random_paid = 2
	var text: String = progress._write().encode_to_text()
	_check("[meta]" in text and "version=2" in text and "[wallet]" in text and "[medals]" in text, "the save has [meta] version, [wallet] and [medals]")
	var file := ConfigFile.new()
	file.parse(text)
	var copy: Node = preload("res://scripts/progress.gd").new()
	copy._read(file)
	_check(copy.globs == 37 and copy.globs_lifetime == 120 and copy.clears_paid == 0b1011 and copy.hard_clears_paid == 1 and copy.medals == {1: 7, 3: 5, 101: 3}
		and copy.spins == 4 and copy.rainbow_pity == 3 and copy.random_pay_day == 20000 and copy.random_paid == 2, "everything survives a save and a load")
	var same := true
	var again_file: ConfigFile = copy._write()
	for section in ["meta", "wallet", "medals", "hats"]:
		for key in file.get_section_keys(section):
			same = same and again_file.get_value(section, key) == file.get_value(section, key)
	_check(same, "...key for key")
	copy.free()

	# --- Hostile / odd values are clamped
	var odd := ConfigFile.new()
	odd.parse(text)
	odd.set_value("wallet", "globs", 9_999_999)
	odd.set_value("wallet", "random_paid", "many")
	odd.set_value("medals", "level_2", 99)
	odd.set_value("hats", "rainbow_pity", -5)
	var tough: Node = preload("res://scripts/progress.gd").new()
	tough._read(odd)
	_check(tough.globs == Progress.GLOBS_MAX and tough.random_paid == 0 and tough.medals_for(2) == Progress.MEDAL_ALL and tough.rainbow_pity == 0,
		"out-of-range or wrong-typed wallet values are clamped")
	tough.free()

	# --- An old save (no [meta], no [wallet], no [medals]): loads, and is paid what it already earned, once
	var old := ConfigFile.new()
	old.set_value("progress", "levels_cleared", 6)
	old.set_value("progress", "highest_unlocked", 7)
	old.set_value("progress", "hard_cleared", [1, 2])
	old.set_value("coins", "level_1", ["2,3", "5,1"])
	old.set_value("records", "level_1", 12.5)
	old.set_value("hats", "owned", ["tophat"])
	var veteran: Node = preload("res://scripts/progress.gd").new()
	veteran._read(old)
	_check(veteran.levels_cleared == 6 and veteran.coins_earned() == 2 and veteran.best_times[1] == 12.5 and veteran.hats_owned == ["tophat"],
		"an old save still loads as before")
	_check(veteran.globs == 6 * 4 + 2 * 8 and veteran.clears_paid == 0b111111 and veteran.hard_clears_paid == 0b11 and veteran.medals.is_empty() and veteran.spins == 0,
		"...with the first-clear globs it already earned (%d) and no medals" % veteran.globs)
	var again := ConfigFile.new()
	again.parse(veteran._write().encode_to_text())
	var veteran2: Node = preload("res://scripts/progress.gd").new()
	veteran2._read(again)
	_check(veteran2.globs == veteran.globs and veteran2.clears_paid == veteran.clears_paid, "...once: loading its next save doesn't pay again")
	veteran.globs = 0
	var spent := ConfigFile.new()
	spent.parse(veteran._write().encode_to_text())
	veteran2._read(spent)
	_check(veteran2.globs == 0, "...even after the globs are spent")
	var replay: Dictionary = veteran.record_clear(3, 99.0, 1.0, 9, false)
	_check(replay.globs == 0 and not replay.first, "replaying an already cleared level doesn't pay the first-clear bonus again")
	veteran.free()
	veteran2.free()

	# --- Save codes (and the size cap)
	progress.reset_progress()
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.hard_cleared.assign(range(1, 11))
	for level in range(1, 11):
		progress.medals[level] = 7
		progress.medals[level + 100] = 3
	progress.globs = 99999
	progress.globs_lifetime = 5000
	progress.clears_paid = 1023
	progress.hard_clears_paid = 1023
	var code: String = progress.save_code()
	_check(code.length() < Progress.MAX_SAVE_CODE_LENGTH / 8, "even with every medal the save code stays small (%d of %d characters)" % [code.length(), Progress.MAX_SAVE_CODE_LENGTH])
	var snapshot: String = progress._write().encode_to_text()
	progress.reset_progress()
	_check(progress.globs == 0 and progress.medals.is_empty(), "RESET PROGRESS empties the wallet, medals and wheel counters")
	_check(progress.spins == 0 and progress.rainbow_pity == 0 and progress.clears_paid == 0 and progress.random_paid == 0, "...and the paid-clear flags and counters")
	_check(progress.load_code(code) and progress._write().encode_to_text() == snapshot, "a save code restores globs and medals exactly")
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
