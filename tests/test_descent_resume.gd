extends "res://tests/suite_base.gd"

## DESCENT resume across an app kill (owner decision D6; Progress.descent_resume, [descent_run]; rules in
## docs/spring-cleaning/phase5-platform.md "Descent resume"): the run is saved at every floor start and right after
## every cleared floor; a relaunch (the save read back into a fresh state) resumes that floor's start or its boon
## card with the same seed, maze, meter, boons, pot, time and paid slot; the offers can't be rerolled, the slot is
## never taken twice and a run banks once (CASH OUT, dry-up, quit, or QUIT RUN on the resume prompt, which banks
## like the pause menu's QUIT TO HUB); save codes never carry a run; hostile [descent_run] values are dropped or
## clamped; the hub asks on arrival and at the portal.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_descent_resume.gd

const SEED := 4242
const SaveText := preload("res://scripts/save_text.gd")
var progress: Node
var save_file := ""


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	save_file = throwaway_save()
	_saved_points()
	_offers_and_slot()
	_banking()
	_codes()
	_hostile()
	await _game_resumes()
	await _hub_prompt()
	_one_resume_per_floor()
	await _hub_spent_prompt()
	_boon_excludes()
	progress.reset_progress()
	_result()
	quit(1 if failures else 0)


func _state() -> void:
	progress.save_path = save_file
	progress.saving_enabled = true
	progress.reset_progress()
	progress.dev_tools = false
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.upgrades = {slime = 4}
	progress.day_override = 20000
	progress.save_progress()


## The app is killed and launched again: memory is gone, the save is read into a fresh state.
func _relaunch() -> void:
	progress.descent_run = {}
	progress.mode = progress.MODE_STORY
	progress.descent_resume = {}
	progress.tickets = -1
	progress.load_progress(save_file)


func _saved() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(save_file)
	return file


func _saved_points() -> void:
	_state()
	progress.start_descent(SEED)
	_check(_saved().has_section("descent_run") and _saved().get_value("descent_run", "floor") == 1, "a new run is saved at floor 1's start")
	_check(SaveText.parse(FileAccess.get_file_as_bytes(save_file)) != null, "the saved run passes the save allow-list")
	_relaunch()
	_check(progress.descent_resume_pending() and progress.descent_resume.floor == 1 and progress.descent_resume.seed == SEED, "relaunch: the run waits to be resumed")
	_check(progress.resume_descent() and progress.descent_active() and progress.mode == progress.MODE_DESCENT, "RESUME: the run is live again")
	var cfg: Dictionary = Descent.floor_config(progress.descent_run.seed, progress.descent_run.floor, 4)
	_check(cfg.seed == Descent.floor_seed(SEED, 1), "the same floor maze (seed %d)" % cfg.seed)
	progress.clear_descent_floor(55.0, 40.0)
	var pot: int = progress.descent_run.pot
	_check(_saved().get_value("descent_run", "cleared") == 1 and _saved().get_value("descent_run", "pot") == pot, "a cleared floor is saved (its pot %d)" % pot)
	var offers: Array[String] = progress.descent_offers()
	progress.descend(offers[1])
	var meter: float = progress.descent_run.meter
	_check(_saved().get_value("descent_run", "floor") == 2 and is_equal_approx(_saved().get_value("descent_run", "meter"), meter), "floor 2's start is saved (meter %.1f)" % meter)
	# killed mid-floor 2: nothing new was saved during the floor
	progress.descent_run.meter = 3.0
	_relaunch()
	progress.resume_descent()
	var run: Dictionary = progress.descent_run
	_check(run.floor == 2 and is_equal_approx(run.meter, meter) and run.boons == {offers[1]: 1} and run.pot == pot and run.cleared == 1,
		"killed mid-floor: resumes floor 2's start (meter, boons, pot as they were)")
	_check(is_equal_approx(run.time, 40.0), "the run time of the cleared floors is kept")


func _offers_and_slot() -> void:
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	var offers: Array[String] = progress.descent_offers()
	var paid: int = progress.descent_paid
	_check(paid == 1 and progress.descent_run.slot == 1, "clearing floor 1 takes today's first paid slot")
	_relaunch()
	progress.resume_descent()
	_check(progress.descent_offers() == offers, "killed on the boon card: the same offers (no reroll) %s" % [offers])
	_check(progress.descent_run.slot == 1 and progress.descent_paid == paid, "the run keeps its slot; no new slot is taken")
	progress.clear_descent_floor(60.0, 30.0)
	_check(progress.descent_paid == paid, "clearing the resumed floor again takes nothing more")
	# Killed while a floor-start snapshot has no slot yet: the slot is taken once, on the first clear.
	_state()
	progress.start_descent(SEED)
	_relaunch()
	progress.resume_descent()
	progress.clear_descent_floor(60.0, 30.0)
	_check(progress.descent_paid == 1, "a floor-1 resume takes the slot once")


func _banking() -> void:
	# Mid-floor: QUIT RUN banks half the pot, once.
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	progress.descend(progress.descent_offers()[0])
	progress.clear_descent_floor(60.0, 30.0)
	progress.descend(progress.descent_offers()[0])
	var pot: int = progress.descent_run.pot
	_relaunch()
	var before: int = progress.tickets
	var result: Dictionary = progress.quit_saved_descent()
	_check(result.get("tickets", -1) == Descent.bank(pot, false, progress.descent_run.boons) and progress.tickets == before + result.tickets,
		"QUIT RUN mid-floor banks half the pot (%d of %d)" % [result.get("tickets", -1), pot])
	_check(not progress.descent_resume_pending() and not _saved().has_section("descent_run"), "...and the saved run is gone")
	_check(progress.quit_saved_descent().is_empty() and progress.tickets == before + result.tickets, "it can't bank twice")
	_relaunch()
	_check(not progress.descent_resume_pending(), "a relaunch after banking finds no run")
	# On the boon card: QUIT RUN cashes out (as QUIT TO HUB on the card does).
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	pot = progress.descent_run.pot
	_relaunch()
	result = progress.quit_saved_descent()
	_check(result.get("cashed", false) and result.tickets == Descent.bank(pot, true, {}), "QUIT RUN on the boon card cashes out the whole pot (%d)" % pot)
	# CASH OUT / dry-up clear the save.
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	progress.end_descent(true)
	_check(not _saved().has_section("descent_run") and progress.descent_resume.is_empty(), "CASH OUT clears the saved run")
	_state()
	progress.start_descent(SEED)
	progress.end_descent(false, false, 12.0)
	_check(not _saved().has_section("descent_run"), "a dry-up clears the saved run")
	# A new run from the portal with one saved: the saved one banks first (never lost silently).
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	progress.descend(progress.descent_offers()[0])
	_relaunch()
	var runs: int = progress.descent_runs
	progress.start_descent(SEED + 1)
	_check(progress.descent_runs == runs + 1 and progress.descent_run.seed == SEED + 1 and progress.descent_resume.seed == SEED + 1, "starting a new run banks the saved one first")
	# Dev-toggled runs pay nothing and keep no save.
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0, true)
	_check(progress.descent_resume.is_empty() and not _saved().has_section("descent_run"), "a dev-toggled run is not kept")


func _codes() -> void:
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	var code: String = progress.save_code()
	var file: ConfigFile = progress.read_code(code)
	_check(file != null and not file.has_section("descent_run"), "a save code never carries the run (it could bank on two devices)")
	var forged: ConfigFile = progress._write()
	forged.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	progress.descent_resume = {}
	progress._read(forged, true)
	_check(progress.descent_resume.is_empty(), "a code with a [descent_run] section loads without it")
	progress._read(forged)
	_check(not progress.descent_resume.is_empty(), "(the same section in the save file is read)")


func _base_run() -> ConfigFile:
	var f := ConfigFile.new()
	f.set_value("descent_run", "format", progress.DESCENT_RUN_FORMAT)
	f.set_value("descent_run", "seed", 77)
	f.set_value("descent_run", "floor", 3)
	f.set_value("descent_run", "cleared", 2)
	f.set_value("descent_run", "meter", 50.0)
	f.set_value("descent_run", "boons", {"tank": 1, "bladder": 1})
	f.set_value("descent_run", "bladders", 1)
	f.set_value("descent_run", "pot", 5)
	f.set_value("descent_run", "time", 80.0)
	f.set_value("descent_run", "slot", 1)
	f.set_value("descent_run", "bonuses", [[5, 10]])
	return f


func _hostile() -> void:
	var ok: Dictionary = progress.read_descent_run(_base_run())
	_check(ok.floor == 3 and ok.boons == {"tank": 1, "bladder": 1} and ok.bladders == 1 and ok.pot == 5, "a well-formed run reads back")
	var cases := {
		"another format": ["format", 2], "seed 0": ["seed", 0], "seed too big": ["seed", Economy.DESCENT_SEED_MAX + 1],
		"floor 0": ["floor", 0], "floor past the max": ["floor", 100000], "cleared ahead of the floor": ["cleared", 7],
		"boons not a dictionary": ["boons", "tank"], "unknown boon": ["boons", {"cheat": 1}], "RUBBER with GLASS": ["boons", {"rubber": 1, "glass": 1}],
		"more boons than floors": ["boons", {"gulp": 5}], "a boon count of 0": ["boons", {"tank": 0}], "a float boon count": ["boons", {"tank": 1.5}],
	}
	for label: String in cases:
		var f := _base_run()
		f.set_value("descent_run", cases[label][0], cases[label][1])
		_check(progress.read_descent_run(f).is_empty(), "dropped: %s" % label)
	var f := _base_run()
	f.set_value("descent_run", "pot", 999)
	f.set_value("descent_run", "meter", -5.0)
	f.set_value("descent_run", "slot", 9)
	f.set_value("descent_run", "bladders", 7)
	f.set_value("descent_run", "time", "x")
	f.set_value("descent_run", "boons", {"tank": 9})
	var clamped: Dictionary = progress.read_descent_run(f)
	_check(clamped.pot == Economy.DESCENT_POT_MAX and clamped.meter == 0.0 and clamped.slot == Economy.DESCENT_PAID_PER_DAY and clamped.bladders == 0
		and clamped.time == 0.0 and clamped.boons == {"tank": 2}, "out-of-range values are clamped (%s)" % [clamped])
	_check(progress.read_descent_run(ConfigFile.new()).is_empty(), "no section: no run (older saves)")
	var text := _base_run().encode_to_text()
	_check(SaveText.parse(text.to_utf8_buffer()) != null, "the section's text passes the allow-list")


func _game_resumes() -> void:
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	var offers: Array[String] = progress.descent_offers()
	_relaunch()
	progress.resume_descent()
	var game: Node2D = BASE_MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	for i in 4:
		await process_frame
	_check(game.descent and game.finished and game.won and game.descent_card != null and game.descent_card.visible, "resumed on the boon card: the floor stays cleared, the card is up")
	_check(progress.descent_offers() == offers, "with the same offers")
	current_scene = null
	game.free()
	progress.descend(offers[0])
	var meter: float = progress.descent_run.meter
	_relaunch()
	progress.resume_descent()
	game = BASE_MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	_check(game.descent and not game.finished and game.maze_seed == Descent.floor_seed(SEED, 2) and is_equal_approx(game.slime_remaining, meter),
		"resumed at floor 2's start: its maze (seed %d), the meter %.1f" % [game.maze_seed, game.slime_remaining])
	current_scene = null
	game.free()
	await process_frame


func _hub_prompt() -> void:
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	progress.descend(progress.descent_offers()[0])
	_relaunch()
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 3:
		await process_frame
	_check(hub.resume_menu.visible and hub.slime.frozen and root.gui_get_focus_owner() == hub.resume_button, "hub: a saved run asks on arrival (RESUME focused)")
	_check(hub.resume_lines[1].text == "FLOOR 2 - POT %d" % progress.descent_resume.pot, "the prompt says where it stands: %s" % hub.resume_lines[1].text)
	hub.close_resume_menu()
	_check(not hub.resume_menu.visible and progress.descent_resume_pending(), "closing it keeps the run saved")
	hub.open_portal_menu()
	hub._start_descent()
	_check(hub.resume_menu.visible and not hub.portal_menu.visible and progress.descent_resume_pending(), "the portal's DESCENT asks again instead of starting a new run")
	var before: int = progress.tickets
	hub._quit_saved_descent()
	_check(not hub.resume_menu.visible and not progress.descent_resume_pending() and progress.tickets >= before, "QUIT RUN banks it and closes the prompt")
	current_scene = null
	hub.free()
	_state()
	progress.start_descent(SEED)
	_relaunch()
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 3:
		await process_frame
	hub._resume_descent()
	_check(progress.descent_active() and progress.descent_run.floor == 1 and root.get_node("Transition").busy, "RESUME goes to the floor")
	for i in 120:
		await process_frame
		if not root.get_node("Transition").busy:
			break
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn" and current_scene.descent, "...and plays it")
	var cs := current_scene
	current_scene = null
	if is_instance_valid(cs):
		cs.free()
	paused = false
	await process_frame


## Owner decision D9: one resume per floor. A second kill on a floor already resumed leaves only QUIT RUN (banks
## half, as a dry-up); clearing the floor starts the count over; a boon card is never limited; no reroll, the slot
## once, the bank once.
func _one_resume_per_floor() -> void:
	_state()
	progress.start_descent(SEED)
	progress.clear_descent_floor(60.0, 30.0)
	var paid: int = progress.descent_paid
	progress.descend(progress.descent_offers()[0])
	var pot: int = progress.descent_run.pot
	_relaunch()
	_check(not progress.descent_resume_spent() and progress.resume_descent(), "first kill on floor 2: RESUME works")
	_check(_saved().get_value("descent_run", "resumes", 0) == 1, "the resume is counted and saved at once")
	progress.descent_run.meter = 2.0  # about to dry up...
	_relaunch()  # ...killed again on the same floor
	_check(progress.descent_resume_pending() and progress.descent_resume_spent(), "second kill on floor 2: the floor's resume is spent")
	_check(not progress.resume_descent() and not progress.descent_active(), "RESUME is refused")
	var before: int = progress.tickets
	var boons: Dictionary = progress.descent_resume.boons
	var result: Dictionary = progress.quit_saved_descent()
	_check(not result.get("cashed", true) and result.get("tickets", -1) == Descent.bank(pot, false, boons) and progress.tickets == before + result.tickets,
		"QUIT RUN banks half the pot (%d of %d), like a dry-up" % [result.get("tickets", -1), pot])
	_check(progress.quit_saved_descent().is_empty() and not _saved().has_section("descent_run") and progress.descent_paid == paid,
		"banked once, the run is gone, no new slot taken")
	# A cleared floor starts the count over; the boon card can be resumed any number of times.
	_state()
	progress.start_descent(SEED)
	_relaunch()
	progress.resume_descent()
	_check(progress.descent_run.resumes == 1, "floor 1 resumed once")
	progress.clear_descent_floor(60.0, 30.0)
	_check(_saved().get_value("descent_run", "resumes", -1) == 0, "clearing the floor resets the count (boon card saved with 0)")
	var offers: Array[String] = progress.descent_offers()
	for i in 3:
		_relaunch()
		_check(progress.resume_descent() and progress.descent_offers() == offers, "boon card resume %d: allowed, the same offers" % (i + 1))
	progress.descend(offers[2])
	_relaunch()
	_check(progress.resume_descent() and progress.descent_run.floor == 2, "the next floor gets its own resume")
	_relaunch()
	_check(progress.descent_resume_spent() and not progress.resume_descent(), "...and only one")
	# A new run from the portal still banks the spent one first.
	var runs: int = progress.descent_runs
	progress.start_descent(SEED + 1)
	_check(progress.descent_runs == runs + 1 and progress.descent_run.seed == SEED + 1 and not progress.descent_resume_spent(), "a new run banks the spent one and starts fresh")
	# Hostile / older saves: no key = 0, clamped to 1, ignored on a boon card.
	var f := _base_run()
	_check(progress.read_descent_run(f).resumes == 0, "no resumes key (older save): not resumed yet")
	f.set_value("descent_run", "resumes", 99)
	_check(progress.read_descent_run(f).resumes == progress.DESCENT_RESUMES_PER_FLOOR, "resumes 99 clamps to %d" % progress.DESCENT_RESUMES_PER_FLOOR)
	f.set_value("descent_run", "resumes", "x")
	_check(progress.read_descent_run(f).resumes == 0, "a non-number resumes reads as 0")
	f.set_value("descent_run", "resumes", 1)
	f.set_value("descent_run", "cleared", 3)
	_check(progress.read_descent_run(f).resumes == 0, "a boon card is never limited")
	_check(SaveText.parse(f.encode_to_text().to_utf8_buffer()) != null, "the key passes the allow-list")


## The hub prompt for a spent floor: QUIT RUN only (focused, centred), what it banks; RESUME hidden.
func _hub_spent_prompt() -> void:
	_state()
	progress.start_descent(SEED)
	_relaunch()
	progress.resume_descent()
	_relaunch()
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 3:
		await process_frame
	_check(hub.resume_menu.visible and not hub.resume_button.visible and hub.resume_quit.visible and root.gui_get_focus_owner() == hub.resume_quit,
		"hub: a spent floor shows only QUIT RUN (focused)")
	_check(hub.resume_lines[0].text == "FLOOR ALREADY RESUMED" and hub.resume_lines[2].text == "QUIT RUN BANKS HALF", "the prompt says why: %s / %s" % [hub.resume_lines[0].text, hub.resume_lines[2].text])
	var q: Button = hub.resume_quit
	_check(q.get_node(q.focus_neighbor_left) == q and q.get_node(q.focus_next) == q, "focus stays on QUIT RUN")
	_check(absf(q.position.x + q.size.x / 2.0 - (hub.RESUME_PANEL.position.x + hub.RESUME_PANEL.size.x / 2.0)) <= 0.5, "QUIT RUN centred in the panel")
	hub._resume_descent()
	_check(not progress.descent_active() and hub.resume_menu.visible, "RESUME can't be forced")
	hub._quit_saved_descent()
	_check(not hub.resume_menu.visible and not progress.descent_resume_pending(), "QUIT RUN banks it and closes the prompt")
	current_scene = null
	hub.free()
	await process_frame


## QA phase 5 #5: the saved boons are checked with the table's `excludes` rule (Descent.boons_compatible), not by
## name; for real runs over many seeds it accepts and rejects exactly what the RUBBER / GLASS check did, and a
## run read back offers exactly the same boons (golden comparison).
func _boon_excludes() -> void:
	var table := {"a": {excludes = "b"}, "b": {}, "c": {}}
	_check(not Descent.boons_compatible({"a": 1, "b": 1}, table) and not Descent.boons_compatible({"b": 1, "a": 1}, table)
		and Descent.boons_compatible({"a": 1, "c": 2}, table), "any table pair that excludes each other is refused")
	var rng := RandomNumberGenerator.new()
	var same := true
	var offers_same := true
	var reads := 0
	for run_seed in range(1, 401):
		rng.seed = run_seed
		var held := {}
		for id: String in Descent.IDS:
			if rng.randf() < 0.3:
				held[id] = 1
		same = same and Descent.boons_compatible(held) == not (held.has("rubber") and held.has("glass"))
		var run := Descent.new_run(run_seed * 7919 % Economy.DESCENT_SEED_MAX + 1)
		for floor_no in range(1, 9):
			Descent.clear_floor(run, 50.0, 20.0)
			var offers: Array[String] = Descent.offers(run.seed, run.floor, run.boons)
			var f := ConfigFile.new()
			f.set_value("descent_run", "format", progress.DESCENT_RUN_FORMAT)
			for key: String in ["seed", "floor", "cleared", "boons", "meter", "pot"]:
				f.set_value("descent_run", key, run[key])
			var back: Dictionary = progress.read_descent_run(f)
			reads += 1
			offers_same = offers_same and not back.is_empty() and Descent.offers(back.seed, back.floor, back.boons) == offers
			if offers.is_empty():
				break
			Descent.descend(run, offers[rng.randi() % offers.size()])
	_check(same, "the table rule matches the old RUBBER / GLASS check on 400 random boon sets")
	_check(offers_same, "%d saved runs (400 seeds) read back with identical offers" % reads)
