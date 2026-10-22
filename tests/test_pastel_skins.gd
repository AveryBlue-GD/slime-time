extends "res://tests/suite_base.gd"

## PASTEL skins (owner, 2026-10-22): each preset's pastel version (opaque and jelly) unlocks with
## randomizer wins, one every 5 (Lime 5 ... Ember 50), the rainbow's at 100; CHAMELEON and the
## STOPWATCH have none. The pastel look is saved, survives a reload, falls back when not earned, and a
## randomizer win at a milestone names the new skin (Game). Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_pastel_skins.gd

var progress: Node
var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.enable_story_complete()  # story beaten on normal and hard, every coin
	progress.saving_enabled = true
	progress.save_path = test_save

	# The milestones.
	var expected := {lime = 5, mint = 10, lemon = 15, ocean = 20, grape = 25, crimson = 30, frost = 35,
		shadow = 40, bubblegum = 45, ember = 50, rainbow = 100}
	for id: String in expected:
		_check(Skins.pastel_wins(id) == expected[id] and Skins.pastel_unlocked_at(expected[id]) == id,
			"%s's pastel version unlocks at %d randomizer wins" % [id, expected[id]])
	_check(not Skins.has_pastel(Skins.STOPWATCH) and not Skins.has_pastel(Skins.CUSTOM)
		and Skins.pastel_wins(Skins.STOPWATCH) == -1, "no pastel STOPWATCH or CHAMELEON")
	_check(Skins.pastel_unlocked_at(7) == "" and Skins.pastel_unlocked_at(55) == "", "no milestone between them or after Ember")

	# Unlocks follow the wins, for the opaque and the jelly version alike.
	progress.randoms_won = 4
	_check(not progress.is_skin_unlocked("lime", false, true) and progress.is_skin_unlocked("lime", false, false),
		"4 wins: pastel Lime locked, plain Lime open")
	progress.randoms_won = 5
	_check(progress.is_skin_unlocked("lime", false, true) and progress.is_skin_unlocked("lime", true, true),
		"5 wins: pastel Lime open, opaque and jelly")
	_check(not progress.is_skin_unlocked("mint", false, true), "...pastel Mint still locked")
	progress.randoms_won = 99
	_check(progress.is_skin_unlocked("ember", true, true) and not progress.is_skin_unlocked(Skins.RAINBOW, false, true),
		"99 wins: every preset pastel, not the rainbow's")
	progress.randoms_won = 100
	_check(progress.is_skin_unlocked(Skins.RAINBOW, false, true) and progress.is_skin_unlocked(Skins.RAINBOW, true, true),
		"100 wins: pastel RAINBOW, opaque and jelly")
	_check(not progress.is_skin_unlocked(Skins.STOPWATCH, false, true) and not progress.is_skin_unlocked(Skins.STOPWATCH, true, true)
		and not progress.is_skin_unlocked(Skins.CUSTOM, false, true), "...never a pastel STOPWATCH or CHAMELEON")
	progress.hard_cleared.clear()
	_check(not progress.is_skin_unlocked("lime", true, true), "pastel jelly also needs the jelly version (hard mode)")
	progress.hard_cleared.assign(range(1, Levels.COUNT + 1))

	# Wearing it: the color, and the skins without one drop the pastel look.
	progress.select_skin("ocean", false, true)
	_check(progress.pastel and Skins.pastel and progress.skin_color() == Skins.PASTEL.ocean, "pastel Ocean worn: its color is the pastel one")
	progress.select_skin(Skins.CUSTOM)
	_check(progress.selected_skin == Skins.CUSTOM and not progress.pastel and progress.skin_color() == progress.custom_color,
		"picking CHAMELEON wears it plain (no pastel version)")

	# Saved and read back; a pastel look not earned falls back to the plain skin.
	progress.select_skin("grape", true, true)
	progress.save_progress()
	progress.set_pastel(false)
	progress.set_jelly(false)
	progress.load_progress()
	_check(progress.selected_skin == "grape" and progress.pastel and progress.jelly, "pastel jelly Grape survives a reload")
	progress.randoms_won = 3
	progress.save_progress()
	progress.load_progress()
	_check(progress.selected_skin == "grape" and not progress.pastel and progress.jelly,
		"a pastel look not earned (3 wins) loads as the plain jelly skin")

	# The skins screen: PASTEL shows the pastel grid without CHAMELEON / STOPWATCH; the worn skin follows.
	progress.randoms_won = 12
	progress.select_skin("mint", false, false)
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.pastel_button.visible and screen.pastel_button.text == "PASTEL: OFF", "PASTEL: OFF on the skins page")
	screen._toggle_pastel()
	_check(screen.view_pastel and not screen.tiles.has(Skins.CUSTOM) and not screen.tiles.has(Skins.STOPWATCH)
		and screen.tiles.has(Skins.RAINBOW), "PASTEL: ON leaves out CHAMELEON and STOPWATCH")
	_check(progress.pastel and progress.selected_skin == "mint", "...and the worn Mint (10 wins) turns pastel")
	screen._refresh("lemon")
	_check(screen.status.text == "PASTEL LOCKED - WIN 15 RANDOM MAZES (12/15)", "pastel Lemon says what it needs: " + screen.status.text)
	progress.levels_cleared = 3
	screen._refresh("ember")
	_check(screen.status.text == "PASTEL LOCKED - WIN 50 RANDOM MAZES (12/50)", "pastel Ember says its wins even while plain Ember is locked: " + screen.status.text)
	progress.levels_cleared = Levels.COUNT
	screen.show_page("hats")
	_check(Skins.pastel == progress.pastel, "other pages draw the worn look")
	screen.show_page("skins")
	screen._toggle_pastel()
	_check(not progress.pastel and Skins.pastel == false and screen.tiles.has(Skins.STOPWATCH), "PASTEL: OFF again")
	screen.queue_free()
	await process_frame

	# Every randomizer win counts toward the next one.
	progress.randoms_won = 19
	progress.complete_random(true)
	_check(progress.randoms_won == 20 and progress.is_skin_unlocked("ocean", false, true), "the 20th win opens pastel Ocean")
	_result()
