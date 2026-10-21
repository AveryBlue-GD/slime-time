extends "res://tests/suite_base.gd"

## First-run skin rule: the very first attempt at a new story level equips the skin just earned
## by clearing the level before it (it stays equipped, so the menus match); after that the
## player's choice is kept, even before the level is cleared. Hard mode and the randomizer never
## change the skin. Uses a throwaway save file.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_skin_rules.gd

const MAIN := preload("res://scenes/main.tscn")

var progress: Node


var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.randoms_won = 0
	progress.skin_notices_seen.clear()
	progress.hard_mode = false

	# Promo captures (--promo): the secret skins stay locked even in dev mode, everything else stays open.
	var dev_before: bool = progress.dev_tools
	progress.dev_tools = true
	progress.promo_secrets_locked = true
	_check(not progress.is_skin_unlocked(Skins.RAINBOW) and not progress.is_skin_unlocked(Skins.STOPWATCH)
		and progress.is_skin_unlocked("frost"), "--promo: RAINBOW and STOPWATCH locked (silhouettes), other skins open")
	progress.promo_secrets_locked = false
	_check(progress.is_skin_unlocked(Skins.RAINBOW), "...without it, dev mode opens RAINBOW as before")
	progress.dev_tools = dev_before

	# Brand-new player: Lime is already on, so level 1 just starts (no notice).
	progress.levels_cleared = 0
	progress.selected_skin = Skins.DEFAULT
	var game := await _spawn_game({level = 1})
	_check(game.skin_color == _color("lime") and not game.hud.message.visible, "level 1 starts in Lime, no notice needed")
	game.free()

	# Cleared levels 1-2 (earned Mint and Lemon) with jelly Mint on (hard L1 beaten): level 3's
	# first try equips Lemon, opaque (the normal-mode version, D14).
	progress.levels_cleared = 2
	progress.hard_cleared.assign([1])
	progress.select_skin("mint", true)
	_check(progress.selected_skin == "mint" and progress.jelly, "(setup: jelly Mint worn)")
	game = await _spawn_game({level = 3})
	_check(not progress.jelly and not Skins.jelly, "...the first-run skin is equipped opaque")
	progress.hard_cleared.clear()
	_check(game.skin_color == _color("lemon") and progress.selected_skin == "lemon",
		"level 3 (Sandstone Sanctum)'s first attempt equips Lemon, earned by clearing level 2")
	_check("NEW SKIN EQUIPPED: LEMON" in game.hud.message.text, "...and says so")
	_check(progress.skin_color() == _color("lemon"), "...and it stays on, so the menus match it")
	game.free()

	# After that the player can switch, even before the level is cleared.
	progress.select_skin("mint")
	game = await _spawn_game({level = 3})
	_check(game.skin_color == _color("mint"), "a second attempt keeps the skin the player picked (Mint)")
	game.free()
	game = await _spawn_game({level = 2})
	_check(game.skin_color == _color("mint"), "replaying a cleared level uses the selected skin")
	game.free()

	# Level 10 (the Volcanic Vault)'s first attempt equips Ember (earned by level 9).
	progress.levels_cleared = 9
	game = await _spawn_game({level = 10})
	_check(game.skin_color == _color("ember") and progress.selected_skin == "ember", "level 10's first attempt equips Ember")
	game.free()

	# Hard mode and the randomizer never change the skin.
	progress.skin_notices_seen.clear()
	progress.select_skin("lime")
	progress.set_hard_mode(true)
	game = await _spawn_game({level = 10})
	_check(progress.selected_skin == "lime", "hard mode doesn't equip a new skin")
	game.free()
	progress.set_hard_mode(false)
	game = await _spawn_game({random_seed = 4242})
	_check(game.skin_color == _color("lime"), "the randomizer keeps the selected skin")
	game.free()

	_result()
	quit(1 if failures else 0)


func _color(id: String) -> Color:
	return Skins.get_preset(id).color


