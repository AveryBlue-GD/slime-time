extends SceneTree

## Level themes + rounded corners: every story level has its own theme (level 1 is the original
## Dungeon art), random mazes pick a theme from their seed (the same seed always gets the same
## one, and different seeds vary), themes recolor tiles and fog, the HUD names the area, and
## inner corners get fillet tiles.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/test_themes.gd

const MAIN := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	await process_frame
	root.get_node("Progress").save_path = "user://test_save.cfg"

	var ids := {}
	for level in range(1, Levels.COUNT + 1):
		ids[Themes.for_level(level)] = true
	_check(ids.size() == Levels.COUNT, "each story level has its own theme (%d different)" % ids.size())
	_check(Themes.for_level(1) == Themes.DUNGEON, "level 1 keeps the original dungeon look")

	var random_ids := {}
	for seed_value in range(1, 40):
		random_ids[Themes.for_seed(seed_value)] = true
	_check(Themes.for_seed(1234) == Themes.for_seed(1234), "a random maze keeps its theme on replay")
	_check(random_ids.size() >= 6, "random mazes pick from many themes (%d seen)" % random_ids.size())

	var game := await _spawn({level = 1})
	_check("dungeon_walls" in _wall_texture(game).resource_path, "level 1 uses the dungeon art")
	var constructions := {}
	for tile: Vector2i in game.wall_layer.get_used_cells():
		constructions[game.wall_layer.get_cell_atlas_coords(tile).y / 12] = true
	_check(constructions.size() == MazeTiles.CONSTRUCTIONS, "a level mixes all %d wall constructions (%d used)" % [MazeTiles.CONSTRUCTIONS, constructions.size()])
	_check(game.fillet_layer.get_used_cells().size() > 0, "inner corners get rounded fillets (%d)" % game.fillet_layer.get_used_cells().size())
	var fillets_on_floor := true
	for tile: Vector2i in game.fillet_layer.get_used_cells():
		fillets_on_floor = fillets_on_floor and not game.is_wall_tile(tile)
	_check(fillets_on_floor, "fillets only sit on floor tiles")
	_check(game.hud.area_label.visible and "DANK DUNGEON" in game.hud.area_label.text, "the HUD names the area (%s)" % game.hud.area_label.text)
	var alliterative := true
	for id: String in Themes.ALL:
		var words: PackedStringArray = Themes.display_name(id).split(" ")
		alliterative = alliterative and words.size() == 2 and words[0][0] == words[1][0]
	_check(alliterative, "every area name is alliterative")
	game.free()

	game = await _spawn({level = 7})
	_check(game.theme == "frozen" and "frozen_walls" in _wall_texture(game).resource_path,
		"level 7 is the Frozen Fortress, with its own tile art (%s)" % _wall_texture(game).resource_path)
	var fog := game.fog_sprite.material as ShaderMaterial
	_check(fog.get_shader_parameter("fog_mist") == Themes.ALL.frozen.fog[1], "...and its fog is tinted to match")
	game.free()

	game = await _spawn({random_seed = 777})
	_check(game.theme == Themes.for_seed(777), "a random maze uses its seed's theme (%s)" % game.theme)
	game.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _wall_texture(game: Node2D) -> Texture2D:
	return (game.wall_layer.tile_set.get_source(MazeTiles.WALL_SOURCE) as TileSetAtlasSource).texture


func _spawn(settings: Dictionary) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	for key: String in settings:
		game.set(key, settings[key])
	root.add_child(game)
	await physics_frame
	return game


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
