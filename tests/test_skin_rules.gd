extends SceneTree

## First-run skin rule: the very first attempt at a new story level equips the skin just earned
## by clearing the level before it (it stays equipped, so the menus match); after that the
## player's choice is kept, even before the level is cleared. Hard mode and the randomizer never
## change the skin. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_skin_rules.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = "user://test_save.cfg"
	progress.randoms_won = 0
	progress.skin_notices_seen.clear()
	progress.hard_mode = false

	# Brand-new player: Lime is already on, so level 1 just starts (no notice).
	progress.levels_cleared = 0
	progress.selected_skin = Skins.DEFAULT
	var game := await _spawn({level = 1})
	_check(game.skin_color == _color("lime") and not game.hud.message.visible, "level 1 starts in Lime, no notice needed")
	game.free()

	# Cleared levels 1-2 (earned Mint and Lemon) with Mint on: level 3's first try equips Lemon.
	progress.levels_cleared = 2
	progress.select_skin("mint")
	game = await _spawn({level = 3})
	_check(game.skin_color == _color("lemon") and progress.selected_skin == "lemon",
		"level 3 (Sandstone Sanctum)'s first attempt equips Lemon, earned by clearing level 2")
	_check("NEW SKIN EQUIPPED: LEMON" in game.hud.message.text, "...and says so")
	_check(progress.skin_color() == _color("lemon"), "...and it stays on, so the menus match it")
	game.free()

	# After that the player can switch, even before the level is cleared.
	progress.select_skin("mint")
	game = await _spawn({level = 3})
	_check(game.skin_color == _color("mint"), "a second attempt keeps the skin the player picked (Mint)")
	game.free()
	game = await _spawn({level = 2})
	_check(game.skin_color == _color("mint"), "replaying a cleared level uses the selected skin")
	game.free()

	# Level 10 (the Volcanic Vault)'s first attempt equips Ember (earned by level 9).
	progress.levels_cleared = 9
	game = await _spawn({level = 10})
	_check(game.skin_color == _color("ember") and progress.selected_skin == "ember", "level 10's first attempt equips Ember")
	game.free()

	# Hard mode and the randomizer never change the skin.
	progress.skin_notices_seen.clear()
	progress.select_skin("lime")
	progress.set_hard_mode(true)
	game = await _spawn({level = 10})
	_check(progress.selected_skin == "lime", "hard mode doesn't equip a new skin")
	game.free()
	progress.set_hard_mode(false)
	game = await _spawn({random_seed = 4242})
	_check(game.skin_color == _color("lime"), "the randomizer keeps the selected skin")
	game.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _spawn(settings: Dictionary) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	await physics_frame
	return game


func _color(id: String) -> Color:
	return Skins.get_preset(id).color


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
