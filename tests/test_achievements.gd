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
	_check(p.medal_ms_mask == 3 and p.tickets == t0 and p.owns_cosmetic("blueprint") and p.owns_cosmetic("starry"), "30 medals: milestones 15 and 30 grant BLUEPRINT PAPER + STARRY TRAIL, no tickets (mask %d)" % p.medal_ms_mask)
	_check(p.medal_milestones_paid == 0, "...the old every-10 milestones pay nothing any more")
	for cos in ["goldleaf", "night", "ink", "candy", "butter_paper"]:
		_check(p.owns_cosmetic(cos), "goal reward %s granted" % cos)
	_check(not p.owns_cosmetic("prism_paper") and not p.owns_cosmetic("plum_paper") and not p.owns_cosmetic("clover_paper"), "...goals not met grant nothing")
	_check(p.ach_rewarded.size() == 5, "...five goals rewarded (%d)" % p.ach_rewarded.size())
	var owned_n: int = p.cosmetics_owned.size()
	p.save_progress()
	p.save_progress()
	_check(p.notices.size() == n1 and p.tickets == t0 and p.cosmetics_owned.size() == owned_n, "saving again: no new toast, no new reward")
	for id in Achievements.REWARDS:
		var kind: String = Cosmetics.kind_of(Achievements.REWARDS[id])
		_check(kind == Cosmetics.PAPER or kind == Cosmetics.TRAIL, "reward of %s is an existing paper or trail" % id)
	_check(Achievements.REWARDS.size() >= 7 and Achievements.REWARDS.size() <= 9, "about 8 goals grant a reward (%d)" % Achievements.REWARDS.size())
	var all_rewards: Array = Achievements.REWARDS.values() + Achievements.MILESTONES.map(func(m: Dictionary) -> String: return m.cosmetic)
	var uniq := {}
	for cos: String in all_rewards:
		uniq[cos] = true
	_check(uniq.size() == all_rewards.size() and not "rainbow" in all_rewards and not "stopwatch" in all_rewards, "every reward is a different cosmetic, no skins")
	_check(events.filter(func(e: Array) -> bool: return e[0] == "ach_clear_1").size() == 1, "...no second event")

	# a new unlock toasts once
	p.notices.clear()
	p.hats_owned.assign(["a", "b", "c", "d", "e", "f"] as Array[String])
	p.save_progress()
	_check(p.notices.size() == 1 and "hats_6" in p.ach_known, "owning 6 hats toasts once")
	p.save_progress()
	_check(p.notices.size() == 1, "...and not again")

	# hard medals pool with normal ones: 20 more gives milestone 45 (GOLD TRAIL)
	for lvl in range(1, 11):
		p.medals[lvl + p.HARD_RECORDS] = 2
	p.save_progress()
	_check(Achievements.medals_earned(p) == 50 and p.medal_ms_mask == 7 and p.owns_cosmetic("gold") and p.tickets == t0, "hard medals count: 50 medals, 45 paid GOLD TRAIL")
	# 60 medals with the cosmetic already owned (bought before): 20 tickets = one wheel spin instead
	p.cosmetics_owned.append("bubblegum_paper")
	for lvl in range(1, 11):
		p.medals[lvl + p.HARD_RECORDS] = 3
	p.save_progress()
	_check(Achievements.medals_earned(p) == 60 and p.medal_ms_mask == 15 and p.tickets == t0 + Economy.MEDAL_MILESTONE_TICKETS and Economy.MEDAL_MILESTONE_TICKETS == 20, "60 medals, cosmetic owned: +20 tickets")
	p.save_progress()
	_check(p.tickets == t0 + 20, "...once")
	_check(Achievements.next_milestone(50) == 60 and Achievements.next_milestone(23) == 30 and Achievements.next_milestone(60) == 0 and Achievements.next_milestone(0) == 15, "next milestone helper")
	_check(Achievements.wins_to_next_unlock(0) == 1 and Achievements.wins_to_next_unlock(1) == 4 and Achievements.wins_to_next_unlock(12) == 3 and Achievements.wins_to_next_unlock(100) == 0, "wins to the next unlock (%d, %d)" % [Achievements.wins_to_next_unlock(1), Achievements.wins_to_next_unlock(12)])

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
	var rewarded: Array = p.ach_rewarded.duplicate()
	var mask: int = p.medal_ms_mask
	p.ach_known.clear()
	p.ach_flags = 0
	p.medal_milestones_paid = 0
	p.ach_rewarded.clear()
	p.medal_ms_mask = 0
	p._read(file)
	_check(p.ach_known == known and p.ach_flags == flags and p.medal_milestones_paid == paid, "[achievements] round trip")
	_check(p.ach_rewarded == rewarded and p.medal_ms_mask == mask and mask == 15, "...rewarded goals and the milestone mask too")
	var tk: int = p.tickets
	p._read(file)
	_check(p.tickets == tk, "...reading again pays nothing")

	# a save from before IMP2-03 with the old every-10 milestones paid keeps that count and gets the new rewards once
	file.set_value("achievements", "milestones", 4)
	file.erase_section_key("achievements", "rewarded")
	file.erase_section_key("achievements", "ms_mask")
	p._read(file)
	_check(p.medal_milestones_paid == 4 and p.medal_ms_mask == 0 and p.ach_rewarded.is_empty(), "an IMP-07 save: old paid count kept, new rewards not yet granted")
	p.cosmetics_owned.clear()
	var tk2: int = p.tickets
	p.notices.clear()
	p._notice_keys.clear()
	var changed: bool = p.check_achievements()
	_check(changed and p.medal_milestones_paid == 4 and p.medal_ms_mask == 15 and p.ach_rewarded.size() == 5 and p.tickets == tk2, "...paid once on load (the old 4 stay 4, no tickets)")
	_check(p.notices.size() == 1 and p.notices[0].contains("NEW REWARDS"), "...in one merged notice (%s)" % str(p.notices))
	_check(not p.check_achievements() and p.notices.size() == 1, "...and not again")

	# an old save (no section): goals adopted silently, rewards and milestones granted with one notice
	file.erase_section("achievements")
	p.notices.clear()
	p._notice_keys.clear()
	p._read(file)
	p.cosmetics_owned.clear()
	var tk3: int = p.tickets
	p.check_achievements()  # (load_progress runs this after reading an owned real save)
	_check(p.notices.size() == 1 and p.tickets == tk3, "a save with no section: one notice (%s)" % str(p.notices))
	_check(p.medal_ms_mask == 15 and p.owns_cosmetic("blueprint") and p.owns_cosmetic("goldleaf") and p.ach_known.size() >= known.size() - 2, "...rewards granted, goals adopted")
	# one new reward alone says what it is
	p.notices.clear()
	p.ach_rewarded.erase("hard_1")
	p.cosmetics_owned.erase("night")
	p.check_achievements()
	_check(p.notices.size() == 1 and p.notices[0] == "NEW REWARD: NIGHT PAPER", "one late reward: " + str(p.notices))

	# the page
	var scene: Control = load("res://scenes/achievements.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.rows.size() == scene.pages()[0].size() and scene.page_count() >= 3, "page 1 shows %d rows of %d pages" % [scene.rows.size(), scene.page_count()])
	_check(scene.header.text == "MEDALS 60 / ALL MEDAL REWARDS WON", "header: " + scene.header.text)
	var unlocked_rows: int = scene.rows.filter(func(r: Control) -> bool: return r.get_meta("unlocked")).size()
	_check(unlocked_rows == scene.pages()[0].filter(func(i: int) -> bool: return Achievements.met(p, Achievements.list()[i].id)).size(), "...unlocked rows match")
	var reward_labels := 0
	for r: Control in scene.rows:
		for c in r.get_children():
			if c is Label and c.has_meta("reward"):
				reward_labels += 1
				_check(c.text.begins_with("REWARD: "), "reward line: " + c.text)
	_check(reward_labels >= 2, "page 1 shows REWARD lines (%d)" % reward_labels)
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
