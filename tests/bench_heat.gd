extends SceneTree

## HEAT winnability sweep (not a test_* suite: ~480 runs): the test autopilot walks every hard level
## with every pickable modifier mask (Heat.masks(), 48 of 64) and must win each; prints the tightest
## slime and time margins per level and overall. Never saves.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 10000000 -s res://tests/bench_heat.gd

const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.saving_enabled = false
	progress.reset_progress()
	progress.saving_enabled = false
	progress.story_seen = 3
	progress.tutorial_seen = 3
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	progress.hard_mode = true
	progress.hard_cleared.assign(range(1, Levels.COUNT + 1))
	var lost := 0
	var runs := 0
	var tightest := {left = 100.0, at = "", time = 0.0, time_at = ""}
	for level in range(1, Levels.COUNT + 1):
		var low := 100.0
		var slow := 0.0
		for mask in Heat.masks():
			progress.heat_mods = mask
			progress.start_story(level)
			var game: Node2D = MAIN.instantiate()
			game.level = level
			root.add_child(game)
			await physics_frame
			game.add_child(AUTOPILOT.new())
			for i in 60 * 150:
				if game.finished:
					break
				await physics_frame
			runs += 1
			if not game.won:
				lost += 1
				print("  LOST: L%d mask %d (heat %d): %s" % [level, mask, game.heat, game.hud.message.text.replace("\n", " ")])
			var left: float = game.slime_remaining
			low = minf(low, left)
			if left < tightest.left:
				tightest.left = left
				tightest.at = "L%d mask %d %s" % [level, mask, Heat.ids_in(mask)]
			if game.race_limit > 0.0:
				var share: float = game.run_time / game.race_limit
				slow = maxf(slow, share)
				if share > tightest.time:
					tightest.time = share
					tightest.time_at = "L%d mask %d" % [level, mask]
			game.free()
		print("  L%2d: 48 masks, least slime left %.1f%%, slowest walk %.0f%% of RACE" % [level, low, slow * 100.0])
	print("runs %d, lost %d; tightest slime: %.1f%% left (%s); tightest time: %.0f%% of the countdown (%s)"
		% [runs, lost, tightest.left, tightest.at, tightest.time * 100.0, tightest.time_at])
	print("RESULT: %s" % ("PASS" if lost == 0 else "FAIL"))
	quit(0 if lost == 0 else 1)
