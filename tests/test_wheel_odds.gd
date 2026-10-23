extends "res://tests/suite_base.gd"

## The prize wheel's odds (Economy.WHEEL_*, Progress.wheel_weight / wheel_pick / wheel_pool): 12 hats and
## 10 wheel trails; the propeller cap, raincloud, PULSE, GHOST and PIXEL are exactly as rare as the
## rainbow hat, every other prize has the ordinary odds; a save's
## FIRST spin (fresh save, RESET PROGRESS, a code that never spun, another epoch's save, a fresh
## Progress) is still random but never a rare hat; saves that already spun keep the full odds; later
## spins land on a rare hat at the documented rate; the wheel always comes to rest on the hat won.
## Uses throwaway saves only.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_wheel_odds.gd

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	Hats.available = true
	progress.reset_progress()

	# --- The rarity table: propeller == rainbow, everything else as it was
	var ids: Array[String] = Hats.ids() + Cosmetics.wheel_ids()  # every prize, in the wheel's pick order
	_check(progress.hats_left() == ids, "a fresh wheel holds every hat, then every wheel trail")
	_check(progress.is_rare_hat("pulse") and progress.is_rare_hat("ghost") and progress.is_rare_hat("pixel")
		and progress.wheel_weight("pulse") == progress.wheel_weight("rainbow") and progress.wheel_weight("ghost") == progress.wheel_weight("propeller")
		and progress.wheel_weight("pixel") == progress.wheel_weight("raincloud"), "PULSE, GHOST and PIXEL weigh exactly what the rare hats do")
	var common_trails := true
	for id in Cosmetics.wheel_ids():
		if not id in ["pulse", "ghost", "pixel"]:
			common_trails = common_trails and not progress.is_rare_hat(id) and progress.wheel_weight(id) == Economy.WHEEL_WEIGHT
	_check(common_trails, "the other seven wheel trails have the ordinary odds")
	_check("propeller" in ids and "rainbow" in ids, "(the propeller cap and the rainbow hat are on the wheel)")
	_check(progress.is_rare_hat("propeller") and progress.is_rare_hat("rainbow"), "the propeller cap and the rainbow hat are the rare ones")
	_check(progress.wheel_weight("propeller") == progress.wheel_weight("rainbow") and progress.wheel_weight("rainbow") == Economy.WHEEL_RARE_WEIGHT,
		"the propeller cap weighs exactly what the rainbow hat does (%.2f)" % progress.wheel_weight("propeller"))
	var unchanged := true
	for id in ids:
		if id == "rainbow":  # (the rainbow hat: 0.3 + pity, as before the table moved here)
			unchanged = unchanged and is_equal_approx(progress.wheel_weight(id), 0.3) and is_equal_approx(progress.wheel_weight(id, 7), 0.3 + 7 * Hats.PITY_STEP)
		if not progress.is_rare_hat(id):
			unchanged = unchanged and progress.wheel_weight(id) == Economy.WHEEL_WEIGHT
	_check(unchanged, "every other hat keeps its odds (rainbow pity too)")
	_check(progress.is_rare_hat("raincloud") and progress.wheel_weight("raincloud") == progress.wheel_weight("rainbow") and progress.wheel_weight("raincloud") == progress.wheel_weight("propeller"),
		"the raincloud hat weighs exactly what the rainbow hat and the propeller cap do")
	_check(progress.wheel_weight("raincloud", 9) == Economy.WHEEL_RARE_WEIGHT and progress.wheel_weight("propeller", 9) == Economy.WHEEL_RARE_WEIGHT, "pity only fattens the rainbow hat")
	# The documented odds (Economy, docs/handoff.md): 12 hats today, 9.43 % each ordinary, 2.83 % each rare.
	var total := 0.0
	var rares := 0
	for id in ids:
		total += progress.wheel_weight(id)
		rares += int(progress.is_rare_hat(id))
	_check(is_equal_approx(total, (ids.size() - rares) * Economy.WHEEL_WEIGHT + rares * Economy.WHEEL_RARE_WEIGHT), "the wheel's total weight is the table's")
	_check(ids.size() == 27 and rares == 6 and absf(100.0 / total - 4.39) < 0.01 and absf(100.0 * Economy.WHEEL_RARE_WEIGHT / total - 1.32) < 0.01,
		"the documented odds: 27 prizes, 4.39 %% per ordinary one, 1.32 %% per rare one")

	# --- A save's first spin: random, never rare
	progress.reset_progress()
	var pool: Array[String] = progress.wheel_pool()
	var common_count := 0
	for id in ids:
		common_count += int(not progress.is_rare_hat(id))
	var rare_in_pool := false
	for id in pool:
		rare_in_pool = rare_in_pool or progress.is_rare_hat(id)
	_check(progress.spins == 0 and pool.size() == common_count and not rare_in_pool, "a fresh save's first spin leaves the rare prizes out")
	var hit := {}
	var rare_rolls := 0
	for i in 1000:
		var id: String = progress.wheel_pick(pool, 0, i / 1000.0)
		hit[id] = true
		rare_rolls += int(progress.is_rare_hat(id))
	_check(rare_rolls == 0 and hit.size() == common_count, "every roll of a first spin lands on an ordinary hat, and any of them can come up (%d of %d)" % [hit.size(), common_count])
	# Real first spins over many seeds, each on a wiped save (RESET PROGRESS), even with rainbow pity maxed.
	var rare_firsts := 0
	var firsts := {}
	for s in 120:
		progress.reset_progress()
		progress.rainbow_pity = progress.RAINBOW_PITY_MAX if s % 2 == 0 else 0
		seed(s)
		var won: String = progress.spin_hat()
		firsts[won] = true
		rare_firsts += int(won == "" or progress.is_rare_hat(won))
	_check(rare_firsts == 0 and firsts.size() > 3, "120 wiped saves, 120 first spins: never a rare hat, still random (%d different)" % firsts.size())
	# The roll that would hit the last wedge (the rainbow hat) on a later spin: on a first spin it can't.
	progress.reset_progress()
	_check(not progress.is_rare_hat(progress.spin_hat(0.99999)) and progress.spins == 1, "the very last roll of a first spin is still an ordinary hat")
	# A fresh Progress (a new install), a code that never spun, and another epoch's save all count as a first spin.
	var fresh: Node = preload("res://scripts/progress.gd").new()
	fresh.save_path = throwaway_save("_fresh")
	fresh.dev_tools = false
	_check(fresh.spins == 0 and not progress.is_rare_hat(fresh.wheel_pick(fresh.wheel_pool(), 0, 0.99999)), "a brand-new save's first spin is never rare")
	progress.reset_progress()
	progress.tickets = 50
	var code: String = progress.save_code()
	progress.spins = 4
	_check(progress.load_code(code) and progress.spins == 0 and not progress.is_rare_hat(progress.spin_hat(0.99999)), "a save code that never spun: its first spin is never rare")
	var other_epoch := ConfigFile.new()
	other_epoch.set_value("meta", "epoch", progress.RELEASE_EPOCH + 7)
	other_epoch.set_value("hats", "spins", 9)
	var epoch_path := throwaway_save("_epoch")
	other_epoch.save(epoch_path)
	var reborn: Node = preload("res://scripts/progress.gd").new()
	reborn.save_path = throwaway_save("_reborn")
	reborn.dev_tools = false
	reborn.load_progress(epoch_path)
	_check(reborn.spins == 0 and not progress.is_rare_hat(reborn.wheel_pick(reborn.wheel_pool(), 0, 0.99999)), "another epoch's save starts fresh: first spin never rare")
	# With only rare hats left on a first spin (no real play gets there), the wheel still spins.
	progress.reset_progress()
	progress.hats_owned.assign(Hats.ids().filter(func(id: String) -> bool: return not progress.is_rare_hat(id)))
	progress.cosmetics_owned.assign(Cosmetics.wheel_ids().filter(func(id: String) -> bool: return not progress.is_rare_hat(id)))
	_check(progress.wheel_pool().size() == ids.size() - common_count, "only rare hats left on a first spin: they stay on (the wheel never jams)")

	# --- Saves that already spun are untouched: the full wheel
	var old := ConfigFile.new()
	old.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	old.set_value("meta", "version", progress.SAVE_VERSION)
	old.set_value("hats", "spins", 1)
	old.set_value("hats", "owned", ["tophat"])
	var old_path := throwaway_save("_old")
	old.save(old_path)
	var veteran: Node = preload("res://scripts/progress.gd").new()
	veteran.save_path = throwaway_save("_veteran")
	veteran.dev_tools = false
	veteran.load_progress(old_path)
	_check(veteran.spins == 1 and "rainbow" in veteran.wheel_pool() and "propeller" in veteran.wheel_pool() and "raincloud" in veteran.wheel_pool() and veteran.spin_cost() == Economy.SPIN_COST,
		"a save that used its free spin keeps every hat on the wheel, at the usual price")
	_check(veteran.wheel_pick(veteran.wheel_pool(), 0, 0.99999) == ids[-1], "...and a later spin can land on the last (rare) wedge")

	# --- Later spins: a rare hat comes up at the documented rate
	progress.reset_progress()
	progress.spins = 1
	var later: Array[String] = progress.wheel_pool()
	var later_total := 0.0
	for id in later:
		later_total += progress.wheel_weight(id)
	var expect: float = Economy.WHEEL_RARE_WEIGHT / later_total
	var n := 40000
	var counts := {"rainbow": 0, "propeller": 0, "raincloud": 0, "pulse": 0, "ghost": 0, "pixel": 0}
	seed(12345)
	for i in n:
		var id: String = progress.wheel_pick(later, 0, randf())
		if id in counts:
			counts[id] += 1
	var bound := 5.0 * sqrt(expect * (1.0 - expect) / n)  # 5 sigma
	for id: String in counts:
		var rate: float = counts[id] / float(n)
		_check(absf(rate - expect) < bound, "a later spin lands on the %s %.2f %% of the time (documented %.2f %%)" % [id, rate * 100.0, expect * 100.0])

	# --- The wheel comes to rest on the hat won: a first spin and later ones
	progress.reset_progress()
	progress.tickets = 100000
	var wheel: Control = load("res://scripts/ui/hat_wheel.gd").new()  # (loaded late: it names the Progress autoload)
	root.add_child(wheel)
	await process_frame
	var mismatches := 0
	var rare_first_lands := 0
	for t in 200:
		if t % 4 == 0:
			progress.reset_progress()  # every 4th: a first spin again
			progress.tickets = 100000
		var first: bool = progress.spins == 0
		if not wheel.spin():
			mismatches += 1
			continue
		var target: String = wheel._target
		mismatches += int(wheel.hats[wheel.wedge_at(wheel._to)] != target or not (target in progress.hats_owned or target in progress.cosmetics_owned))
		rare_first_lands += int(first and progress.is_rare_hat(target))
		wheel.spinning = false  # (skip the animation: where it stops is already set)
		wheel.turn = wheel._to
	_check(mismatches == 0 and rare_first_lands == 0, "200 spins: the wheel stops on the wedge of the hat won, and no first spin is rare (%d off)" % mismatches)
	# One played out in full, a first spin.
	progress.reset_progress()
	wheel._won = ""
	var landed_ids: Array[String] = []
	wheel.landed.connect(func(id: String) -> void: landed_ids.append(id))
	_check(wheel.spin(), "a fresh save's free spin starts the wheel")
	for i in int(wheel.SPIN_TIME * 60) + 60:
		await physics_frame
		if not landed_ids.is_empty():
			break
	var landed: String = landed_ids[0] if not landed_ids.is_empty() else ""
	var owned: Array[String] = progress.hats_owned + progress.cosmetics_owned
	_check(landed != "" and owned.size() == 1 and landed == owned[0] and wheel.hats[wheel.wedge_at(wheel.turn)] == landed and not progress.is_rare_hat(landed),
		"...it lands on exactly the hat it won, an ordinary one (%s)" % landed)
	# The rare slivers are spread evenly round the wheel, never side by side (the full wheel: 3 ordinary
	# wedges between each), and the order keeps every hat once.
	wheel.hats = ids
	var rare_at: Array[int] = []
	for i in wheel.hats.size():
		if progress.is_rare_hat(wheel.hats[i]):
			rare_at.append(i)
	var gaps: Array[int] = []
	for k in rare_at.size():
		gaps.append(posmod(rare_at[(k + 1) % rare_at.size()] - rare_at[k], wheel.hats.size()) - 1)
	var same: bool = wheel.hats.size() == ids.size()
	for id in ids:
		same = same and id in wheel.hats
	_check(rare_at.size() == 6 and gaps.max() - gaps.min() <= 1 and gaps.min() >= 2 and same, "the full wheel spreads the 6 rare prizes evenly: %s ordinary wedges between them" % [gaps])
	var some: Array[String] = ["tophat", "beanie", "party", "cap", "propeller", "raincloud", "rainbow"]
	wheel.hats = some
	_check(not progress.is_rare_hat(wheel.hats[0]) and progress.is_rare_hat(wheel.hats[2]) and not progress.is_rare_hat(wheel.hats[3]) and progress.is_rare_hat(wheel.hats[-1]),
		"with fewer hats left the rare ones still don't bunch where they can be split (%s)" % [wheel.hats])
	wheel.free()
	fresh.free()
	reborn.free()
	veteran.free()
	_result()
