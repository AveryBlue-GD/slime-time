extends SceneTree

## First-run skin rule: a story level's first run is played in the skin just earned by clearing
## the level before it (Ember for level 1); after a level is cleared, replays use the selected
## skin, and the randomizer always does. Uses a throwaway save file.
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

	# Brand-new player: level 1 is played in Ember (the original orange).
	progress.levels_cleared = 0
	progress.selected_skin = Skins.DEFAULT
	var game := await _spawn({level = 1})
	_check(game.skin_color == _color("ember") and progress.skin_override == "ember", "level 1's first run is played as Ember")
	_check("PLAYING AS EMBER" in game.hud.message.text, "the HUD says which skin the first run uses")
	game.free()
	_check(progress.skin_override == "", "leaving the level lifts the forced skin")

	# Cleared levels 1-2 (earned Lime and Ocean) with Ember selected.
	progress.levels_cleared = 2
	progress.select_skin("ember")
	game = await _spawn({level = 3})
	_check(game.skin_color == _color("ocean"), "level 3's first run is played in Ocean, earned by clearing level 2")
	var slime_mid: Color = (game.slime.sprite.material as ShaderMaterial).get_shader_parameter("mid")
	_check(slime_mid.is_equal_approx(Skins.shades(_color("ocean")).mid), "the slime itself wears the forced skin")
	game.free()

	game = await _spawn({level = 2})
	_check(game.skin_color == _color("ember"), "replaying a cleared level uses the selected skin (Ember)")
	game.free()
	progress.select_skin("lime")
	game = await _spawn({level = 1})
	_check(game.skin_color == _color("lime"), "...and switching skins applies on replays (Lime)")
	game.free()

	# Level 10's first run is played in Shadow (earned by level 9).
	progress.levels_cleared = 9
	game = await _spawn({level = 10})
	_check(game.skin_color == _color("shadow"), "level 10's first run is played in Shadow")
	game.free()

	# The randomizer never forces a skin.
	progress.levels_cleared = 0
	progress.selected_skin = Skins.DEFAULT
	game = await _spawn({random_seed = 4242})
	_check(progress.skin_override == "" and game.skin_color == _color("ember"), "the randomizer keeps the selected skin")
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
