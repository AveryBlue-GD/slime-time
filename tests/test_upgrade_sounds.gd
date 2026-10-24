extends "res://tests/suite_base.gd"

## The cauldron's buy sounds: a power-up (higher per level), the sparkle one on a track's last level, a gentle
## descending one on a refund, and the gold pulse over the bought bar (none with Reduce Motion). Throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_upgrade_sounds.gd

var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	var p: Node = root.get_node("Progress")
	p.save_path = test_save
	p.saving_enabled = false
	p.dev_tools = false
	p.dev_tools = true  # (dev coins: plenty to spend; saving is off)
	p.dev_coins = 500
	p.reduce_motion = false
	for name in ["upgrade", "upgrade_max", "refund", "place"]:
		_check(name in Sfx.SOUNDS and FileAccess.file_exists("res://assets/sounds/%s.wav" % name), "%s is a loaded sound" % name)
	# IMP4-07: the 0.3 s "saved / place" sting exists, is short, and plays on desktop / web (not on a phone)
	var place := load("res://assets/sounds/place.wav") as AudioStreamWAV
	_check(place != null and place.get_length() > 0.2 and place.get_length() < 0.45, "the place sting is about 0.3 s")
	_check(root.get_node("Sfx").play_place() == not Platform.is_mobile_native(), "Sfx.play_place plays off phones only")
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var top: int = Upgrades.max_level("slime")
	var pips: Array = screen.rows["slime"].pips
	screen._change("slime", true)
	_check(p.upgrade_level("slime") == 1 and screen.last_played == "upgrade", "buy: the power-up (%s)" % screen.last_played)
	_check((pips[0] as ColorRect).modulate != Color.WHITE, "...with a gold pulse on the bar")
	screen._change("slime", false)
	_check(p.upgrade_level("slime") == 0 and screen.last_played == "refund", "refund: its own descending sound (%s)" % screen.last_played)
	for i in top - 1:
		screen._change("slime", true)
	_check(screen.last_played == "upgrade", "levels before the last: the plain power-up")
	screen._change("slime", true)
	_check(p.upgrade_level("slime") == top and screen.last_played == "upgrade_max", "the track's last level adds the sparkle (%s)" % screen.last_played)
	screen._change("slime", false)
	p.reduce_motion = true
	for pip: ColorRect in pips:
		pip.modulate = Color.WHITE
	screen._change("slime", true)
	_check((pips[0] as ColorRect).modulate == Color.WHITE and screen.last_played == "upgrade_max", "Reduce Motion: sound, no pulse")
	screen.free()
	p.reduce_motion = false
	_result()
	quit(0 if failures == 0 else 1)
