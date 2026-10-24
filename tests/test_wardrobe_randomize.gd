extends "res://tests/suite_base.gd"

## Wardrobe RANDOMIZE (the dice beside JELLY / PASTEL): only owned things, a different look each press, saved, the
## demo's limits. Uses a throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_wardrobe_randomize.gd

var test_save := throwaway_save()
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.reset_progress()
	progress.saving_enabled = true
	progress.levels_cleared = 6
	progress.hard_cleared.assign([1, 2])
	progress.hats_owned.clear()
	progress.hats_owned.append_array([Hats.LIST[0].id, Hats.LIST[1].id])
	var dyes := Hats.dyes_for(Hats.LIST[0].id)
	if not dyes.is_empty():
		progress.hat_dyes_owned.append("%s:%s" % [Hats.LIST[0].id, dyes[0]])
	progress.cosmetics_owned.clear()
	progress.cosmetics_owned.append("ink")
	var screen: Node = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.dice_button != null and screen.dice_button.visible, "the dice button is on the wardrobe")
	_check(screen.dice_button.position.y == screen.jelly_button.position.y and screen.dice_button.position.x >= screen.pastel_button.position.x + screen.pastel_button.size.x, "it sits beside PASTEL on the bottom row")
	_check(screen.dice_button.size.x >= 16 and screen.dice_button.size.y >= UIKit.BUTTON_H, "touch-sized like the other bottom-row buttons")
	var changed := 0
	var seen_skins := {}
	for i in 60:
		var before: String = screen._look_key(screen.current_look())
		var moved: bool = screen.randomize_look()
		var look: Dictionary = screen.current_look()
		if screen._look_key(look) != before:
			changed += 1
		seen_skins[look.skin] = true
		_check(progress.is_skin_unlocked(look.skin, look.jelly, look.pastel), "worn skin is unlocked (%s)" % look.skin)
		_check(progress.is_hat_unlocked(look.hat), "worn hat is owned")
		_check(look.dye == "" or progress.owns_dye(look.hat, look.dye), "worn dye is owned")
		_check(progress.owns_cosmetic(look.trail) and progress.owns_cosmetic(look.paper), "trail and paper are owned")
		_check(look.trail in [Cosmetics.DEFAULT_TRAIL, "ink"], "only the owned trails (%s)" % look.trail)
		if i > 5 and not moved:
			_check(false, "a press changes the look")
	_check(changed >= 55, "nearly every press changes the look (%d / 60)" % changed)
	_check(seen_skins.size() >= 3, "it picks a variety of skins (%d)" % seen_skins.size())
	_check(not seen_skins.has(Skins.RAINBOW) and not seen_skins.has(Skins.STOPWATCH) and not seen_skins.has(Skins.CUSTOM), "locked skins never come up")
	# Saved like the pickers do
	var reloaded: Node = preload("res://scripts/progress.gd").new()
	reloaded.save_path = test_save
	reloaded.load_progress()
	var look: Dictionary = screen.current_look()
	_check(reloaded.selected_skin == look.skin and reloaded.selected_hat == look.hat and reloaded.trail_style == look.trail and reloaded.map_paper == look.paper, "the look is saved")
	reloaded.free()
	# Only on the SKINS page (hats, trails, papers, hub: hidden, so not in the focus order)
	for pg in ["hats", "trails", "papers", "hub"]:
		screen.show_page(pg)
		_check(not screen.dice_button.visible, "no dice on the %s page" % pg)
	screen.show_page("skins")
	_check(screen.dice_button.visible, "dice back on the skins page")
	# The toggle: default OFF, saved, ON rolls once at once, a new run re-rolls, a retry does not
	_check(not progress.random_look, "RANDOM LOOK is off by default")
	screen.dice_button.pressed.emit()
	_check(progress.random_look and screen._dice_frame.visible, "the dice toggles ON (lit)")
	_check(screen.random_look_text().contains("ON"), "status line says ON")
	var on_reload: Node = preload("res://scripts/progress.gd").new()
	on_reload.save_path = test_save
	on_reload.load_progress()
	_check(on_reload.random_look, "the toggle is saved")
	on_reload.free()
	var rolls := 0
	for i in 40:
		var k: String = screen._look_key(screen.current_look())
		if LookRoller.roll_for_run():
			rolls += 1
		var l2: Dictionary = screen.current_look()
		_check(progress.owns_cosmetic(l2.trail) and progress.is_hat_unlocked(l2.hat), "run roll uses owned things only")
	_check(rolls == 40, "every run start rolls while ON (%d)" % rolls)
	var kept: String = screen._look_key(screen.current_look())
	progress.keep_look_once = true
	_check(not LookRoller.roll_for_run() and screen._look_key(screen.current_look()) == kept, "a retry keeps the look")
	_check(not progress.keep_look_once and LookRoller.roll_for_run(), "the keep is used up; the next run rolls")
	_check(not LookRoller.roll_for_run(true), "skipped (preview / training) rolls nothing")
	screen.dice_button.pressed.emit()
	_check(not progress.random_look and not screen._dice_frame.visible and not LookRoller.roll_for_run(), "OFF: nothing rolls")
	screen.free()
	# Demo: only demo-available skins, no pastel
	Platform.demo_override = 1
	progress.reset_progress()
	progress.saving_enabled = false
	var demo_screen: Node = load("res://scenes/skins.tscn").instantiate()
	root.add_child(demo_screen)
	await process_frame
	for i in 30:
		demo_screen.randomize_look()
		var l: Dictionary = demo_screen.current_look()
		_check(Demo.skin_open(l.skin, l.jelly) and not (l.pastel and Skins.has_pastel(l.skin)), "demo look uses only demo skins (%s)" % l.skin)
	demo_screen.free()
	Platform.reset_overrides()
	# Dev mode: everything is owned, so anything can come up
	progress.dev_tools = true
	var dev_screen: Node = load("res://scenes/skins.tscn").instantiate()
	root.add_child(dev_screen)
	await process_frame
	var dev_seen := {}
	for i in 80:
		dev_screen.randomize_look()
		dev_seen[dev_screen.current_look().skin] = true
	_check(dev_seen.size() >= 6, "dev mode draws from every skin (%d)" % dev_seen.size())
	dev_screen.free()
	progress.dev_tools = false
	_result()
	quit(0 if failures == 0 else 1)
