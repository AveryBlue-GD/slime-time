extends "res://tests/suite_base.gd"

## IMP-07 ACHIEVEMENTS (Economy.ACHIEVEMENTS): goals derived from a crafted state, one toast and one progress_event per
## unlock, medal milestones (every 10 medals, normal + hard, pay 5 tickets once; an old save is paid once on load) and
## the [achievements] save round trip, plus the page itself.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_achievements.gd

var test_save := throwaway_save()
var events: Array = []


func _on_event(id: String, value: int) -> void:
	events.append([id, value])


func _initialize() -> void:
	await process_frame
	var p: Node = root.get_node("Progress")
	p.save_path = test_save
	p.dev_tools = false
	p.saving_enabled = true
	root.get_node("PlatformEvents").progress_event.connect(_on_event)
	p.notices.clear()

	_check(Achievements.ids().size() >= 20, "about 20 goals (%d)" % Achievements.ids().size())
	_check(Achievements.met_ids(p).is_empty(), "a fresh state meets none")

	# derived from a crafted state
	p.levels_cleared = 10
	p.hard_cleared.assign([1])
	p.randoms_won = 12
	p.spins = 1
	p.daily_best_streak = 7
	p.daily_day = 100
	for lvl in range(1, 11):
		p.medals[lvl] = 3  # 10 golds in normal mode
	var met: Array[String] = Achievements.met_ids(p)
	for id in ["clear_1", "clear_story", "hard_1", "rand_1", "rand_10", "wheel_1", "daily_1", "daily_7", "gold_1", "gold_10"]:
		_check(id in met, "%s is met by the crafted state" % id)
	for id in ["hard_all", "rand_50", "gold_20", "clean_win", "abilities", "hats_6"]:
		_check(not id in met, "%s is not" % id)

	# the first look at the state: toasts once, events once, milestones paid once
	var t0: int = p.tickets
	p.ach_known.clear()
	p.notices.clear()
	events.clear()
	p.save_progress()
	var n1: int = p.notices.size()
	_check(n1 >= 1 and p.ach_known.size() == met.size(), "every met goal is known after a save (%d)" % p.ach_known.size())
	_check(events.filter(func(e: Array) -> bool: return e[0] == "ach_clear_1").size() == 1, "...ach_clear_1 went through progress_event once")
	_check(p.medal_milestones_paid == 3 and p.tickets == t0 + 15, "30 medals: 3 milestones paid, +15 tickets (%d)" % (p.tickets - t0))
	p.save_progress()
	p.save_progress()
	_check(p.notices.size() == n1 and p.tickets == t0 + 15, "saving again: no new toast, no new pay")
	_check(events.filter(func(e: Array) -> bool: return e[0] == "ach_clear_1").size() == 1, "...no second event")

	# a new unlock toasts once
	p.notices.clear()
	p.hats_owned.assign(["a", "b", "c", "d", "e", "f"] as Array[String])
	p.save_progress()
	_check(p.notices.size() == 1 and "hats_6" in p.ach_known, "owning 6 hats toasts once")
	p.save_progress()
	_check(p.notices.size() == 1, "...and not again")

	# hard medals pool with normal ones: 10 more gives milestone 4
	for lvl in range(1, 11):
		p.medals[lvl + p.HARD_RECORDS] = 1
	p.save_progress()
	_check(Achievements.medals_earned(p) == 40 and p.medal_milestones_paid == 4 and p.tickets == t0 + 20, "hard medals count: 40 medals, 4 paid")
	_check(Achievements.next_milestone(40) == 50 and Achievements.next_milestone(23) == 30, "next milestone helper")

	# ability flags and the clean win
	p.note_ability_used("rifle")
	p.note_ability_used("splat")
	_check(not Achievements.met(p, "abilities"), "two abilities are not all three")
	p.note_ability_used("kaze")
	p.note_clean_random_win()
	_check(Achievements.met(p, "abilities") and Achievements.met(p, "clean_win") and "clean_win" in p.ach_known, "each ability used + a clean win unlock")

	# save round trip
	var file: ConfigFile = p._write()
	var known: Array = p.ach_known.duplicate()
	var flags: int = p.ach_flags
	var paid: int = p.medal_milestones_paid
	p.ach_known.clear()
	p.ach_flags = 0
	p.medal_milestones_paid = 0
	p._read(file)
	_check(p.ach_known == known and p.ach_flags == flags and p.medal_milestones_paid == paid, "[achievements] round trip")
	var tk: int = p.tickets
	p._read(file)
	_check(p.tickets == tk, "...reading again pays nothing")

	# an old save (no section): goals adopted silently, milestones already passed paid once with one notice
	file.erase_section("achievements")
	p.notices.clear()
	p._notice_keys.clear()
	p._read(file)
	p.check_achievements()  # (load_progress runs this after reading an owned real save)
	var base: int = p.tickets - 20
	var medal_notes: Array = p.notices.filter(func(s: String) -> bool: return s.contains("MEDALS"))
	_check(p.notices.size() == 1 and medal_notes.size() == 1, "an old save: one notice (%s)" % str(p.notices))
	_check(p.tickets == base + 20 and base >= 0 and p.medal_milestones_paid == 4 and p.ach_known.size() >= known.size() - 2, "...paid 4 milestones once, goals adopted (%d tickets)" % p.tickets)

	# the page
	var scene: Control = load("res://scenes/achievements.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.rows.size() == Achievements.PER_PAGE, "page 1 shows %d rows" % scene.rows.size())
	_check(scene.header.text == "MEDALS 40 / NEXT REWARD AT 50", "header: " + scene.header.text)
	var unlocked_rows: int = scene.rows.filter(func(r: Control) -> bool: return r.get_meta("unlocked")).size()
	_check(unlocked_rows == Achievements.list().slice(0, Achievements.PER_PAGE).filter(func(a: Dictionary) -> bool: return Achievements.met(p, a.id)).size(), "...unlocked rows match")
	scene.next_button.pressed.emit()
	await process_frame
	_check(scene.page == 1 and scene.rows.size() > 0, "NEXT PAGE turns the page")
	for i in scene.page_count():
		scene.page = i
		scene._show_page()
		for r: Control in scene.rows:
			var l: Label = null
			for c in r.get_children():
				if c is Label:
					l = c
			_check(l != null and l.get_minimum_size().x <= l.size.x, "row text fits (%s)" % l.text)
	scene.queue_free()
	_result()
