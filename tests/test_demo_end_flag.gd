extends "res://tests/suite_base.gd"

## Debug `--demo --demo-end` (Progress.enable_demo_end_test): the demo one level from its end, nothing saved:
## levels 1-3 cleared as chalices clear them, level 4 (the demo's last) next, no intro or tutorial due.

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.hard_mode = false
	Platform.demo_override = 1
	progress.saving_enabled = true
	progress.reset_progress()
	DirAccess.remove_absolute(test_save)
	progress.enable_demo_end_test()
	progress.save_progress()  # (saving is off now: writes nothing)
	var last: int = Demo.levels()
	_check(last == 4, "the demo's last story level is 4")
	_check(progress.levels_cleared == last - 1 and progress.highest_unlocked == last and progress.current_level == last,
		"levels 1-3 cleared, level 4 unlocked and next")
	_check(not progress.saving_enabled and not FileAccess.file_exists(test_save), "nothing is saved")
	_check(not progress.is_fresh_save() and not progress.tutorial_due() and not progress.hub_tour_due(),
		"no fresh-save start, training or hub tour")
	_check(progress.has_seen_story(progress.STORY_INTRO) and not progress.has_seen_story(progress.STORY_DEMO_END),
		"the intro counts as seen, the demo's end screen not yet")
	_check(not progress.is_randomizer_unlocked(), "the randomizer (and with it the preview) waits for level 4")
	progress.complete_level(last, false)
	_check(progress.levels_cleared == last and progress.is_randomizer_unlocked(), "level 4's chalice opens the randomizer")
	Platform.reset_overrides()
	_result()
	quit(0 if failures == 0 else 1)
