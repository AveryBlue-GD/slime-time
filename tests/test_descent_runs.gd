extends "res://tests/suite_base.gd"

## DESCENT with the autopilot (the shortest route, no detours for goo drops): runs of real floors,
## the meter carried from floor to floor exactly as the rules say (Progress.descend), the first
## boon offered picked each time. Checks every floor's perfect run uses its u of the meter (over the
## run's capacity), the carried meter + refill matches the maths, every floor entered with more
## meter than its route needs is cleared (so every floor is solvable at its target usage with the
## carried meter), a run only ends when the meter really falls short, and (spec D.3 gate) 20 short
## runs all reach floor 4. Deep runs go on until the slime runs out (or floor DEEP_MAX).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 900000 -s res://tests/test_descent_runs.gd
## Extra: `-- --runs=N` short runs (default 20), `-- --deep=N` deep runs (default 3).

const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")
## Short runs stop once they reach this floor (the spec's gate).
const GATE_FLOOR := 4
const DEEP_MAX := 14
## A floor entered with at least this much more meter than its perfect run needs must be cleared (the
## autopilot cuts corners a little and pays a few px of start/turn wobble).
const MARGIN := 3.0

var progress: Node
var short_runs := 20
var deep_runs := 3


func _initialize() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			short_runs = int(arg.get_slice("=", 1))
		elif arg.begins_with("--deep="):
			deep_runs = int(arg.get_slice("=", 1))
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	var t0 := Time.get_ticks_msec()
	var reached_gate := 0
	for i in short_runs:
		var level: int = [0, 2, 4, 7][i % 4]
		var deepest := await _run(1000 + i * 7919, level, GATE_FLOOR)
		if deepest >= GATE_FLOOR:
			reached_gate += 1
	_check(reached_gate == short_runs, "%d/%d autopilot runs reach floor %d" % [reached_gate, short_runs, GATE_FLOOR])
	for i in deep_runs:
		var level: int = [0, 4, 7][i % 3]
		var deepest := await _run(5000 + i * 104729, level, DEEP_MAX)
		print("  deep run %d (MORE SLIME %d): reached floor %d" % [i, level, deepest])
		_check(deepest >= 6, "a deep run with the shortest route and first-offer boons gets to floor 6+ (%d)" % deepest)
	print("  elapsed %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	progress.reset_progress()
	_result()
	quit(0 if failures == 0 else 1)


## Plays one run until it dries up or reaches `stop_floor`; returns the floor reached.
func _run(run_seed: int, slime_level: int, stop_floor: int) -> int:
	progress.reset_progress()
	progress.saving_enabled = false
	progress.levels_cleared = 10
	progress.highest_unlocked = 10
	progress.tutorial_seen = 3
	progress.upgrades = {slime = slime_level} if slime_level > 0 else {}
	progress.start_descent(run_seed)
	var run: Dictionary = progress.descent_run
	var bad := ""
	while true:
		var floor_no: int = run.floor
		if floor_no >= stop_floor:
			break
		var game: Node2D = MAIN.instantiate()
		root.add_child(game)
		await physics_frame
		var start: float = game.slime_remaining
		var need: float = game.perfect_usage * 100.0
		var expect := Descent.usage_permille(run_seed, floor_no) / 10.0 / Descent.capacity(run.boons)
		if absf(need - expect) > 2.0 and bad == "":
			bad = "floor %d: a perfect run needs %.1f%%, u says %.1f%%" % [floor_no, need, expect]
		if absf(start - float(run.meter)) > 0.01 and bad == "":
			bad = "floor %d starts at %.1f%%, the run says %.1f%%" % [floor_no, start, run.meter]
		game.add_child(AUTOPILOT.new())
		for f in 60 * 300:
			if game.finished:
				break
			await physics_frame
		var won: bool = game.won
		var left: float = game.slime_remaining
		game.free()
		if not won:
			if start >= need + MARGIN and bad == "":
				bad = "floor %d entered with %.1f%% (needs %.1f%%) but the autopilot dried up" % [floor_no, start, need]
			if not run.ended and bad == "":
				bad = "floor %d: the dry-up did not end the run" % floor_no
			break
		var offers: Array[String] = progress.descent_offers()
		var pick: String = offers[0]
		var cap_before := Descent.capacity(run.boons)
		progress.descend(pick)
		var want := clampf(left * cap_before / Descent.capacity(run.boons) + (30.0 if pick == "gulp" else 0.0) + Descent.floor_refill(run.floor, run.boons), 0.0, 100.0)
		if absf(float(run.meter) - want) > 0.01 and bad == "":
			bad = "floor %d: carried %.1f%% + refill should be %.1f%%, got %.1f%%" % [run.floor, left, want, run.meter]
	var reached: int = run.floor
	_check(bad == "", "run %d (MORE SLIME %d): floors played to %d, pot %d%s" % [run_seed, slime_level, reached, run.pot, "" if bad == "" else " - " + bad])
	return reached


