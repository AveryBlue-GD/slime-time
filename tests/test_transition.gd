extends "res://tests/suite_base.gd"

## The goo wipe (autoload Transition): a screen change started while the previous arrival's uncover is still sliding
## keeps the sheet up for the whole cover (cleanup audit D2-03: the old uncover tween used to hide the sheet part-way,
## so the old screen showed through and the swap popped).


func _initialize() -> void:
	await process_frame
	root.get_node("Progress").saving_enabled = false
	var transition: CanvasLayer = root.get_node("Transition")
	var sheet: CanvasItem = transition.get("_sheet")
	var holder := Node.new()
	root.add_child(holder)
	current_scene = holder

	# An arrival (uncover, UNCOVER_TIME = 0.32 s) and, 0.2 s in, a new screen change (cover, COVER_TIME = 0.22 s).
	transition.reveal()
	for i in 12:  # 0.2 s at --fixed-fps 60
		await process_frame
	_check(sheet.visible and not transition.busy, "mid-uncover: the sheet is still sliding off, no change running")
	transition.go("res://tests/transition_target.tscn")
	var hidden_mid_cover := false
	for i in 12:  # up to 0.4 s after the reveal: past the old uncover's end (0.32 s), still inside the cover (0.42 s)
		await process_frame
		if transition.busy and not sheet.visible:
			hidden_mid_cover = true
	_check(not hidden_mid_cover, "a change started during an uncover keeps the sheet up until the swap")
	while transition.busy:
		await process_frame
	_check(current_scene != null and current_scene.name == "TransitionTarget", "the change still lands on the new screen")
	for i in 30:
		await process_frame
	_check(not sheet.visible, "and the sheet slides off afterwards")
	_result()
	quit(1 if failures else 0)
