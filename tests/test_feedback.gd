extends "res://tests/suite_base.gd"

## Playtest feedback round: R mid-run asks RESTART / UPGRADES / CANCEL (and pauses); a straight
## leap that only clips a wall by a pixel or two slips past instead of splatting (a real hit still
## splats); slimes are opaque by default and JELLY ON shows jelly skins unlocked on hard mode;
## RESET PROGRESS waits for CONFIRM, then wipes progress but keeps the settings.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_feedback.gd

const MAIN := preload("res://scenes/main.tscn")
var test_save := throwaway_save()

var progress: Node


func _initialize() -> void:
	Economy.r_always_force = 0  # (these cover the RESTART / UPGRADES prompt; test_chill_lane covers R always restarting)
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	progress.dev_tools = false
	progress.levels_cleared = 2

	# --- R mid-run with no coins to spend restarts at once; with coins it asks first
	var game := await _play(1)
	_press("restart")
	await _frames(40)
	_check(current_scene != null and (not is_instance_valid(game) or game.is_queued_for_deletion() or current_scene != game) and not paused, "R mid-run with no coins restarts at once")
	if current_scene != null and current_scene != game:
		current_scene.free()
	current_scene = null
	progress.coins_found = {1: ["0,0"]}
	game = await _play(1)
	_press("restart")
	await _frames(3)
	_check(game.restart_prompt.visible and paused and current_scene == game, "R mid-run opens RESTART / UPGRADES / CANCEL and pauses")
	_press("restart")
	await _frames(3)
	_check(not game.restart_prompt.visible and not paused, "R again (or Esc) cancels and the run carries on")
	_press("restart")
	await _frames(3)
	game.restart_prompt.buttons[1].pressed.emit()  # UPGRADES
	await _frames(40)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/upgrades.tscn" and not paused,
		"UPGRADES goes to the upgrades screen (its PLAY button returns to the level)")
	progress.return_to_game = false

	# --- Corner leeway: a leap a couple of pixels off-center slides through the corridor
	current_scene = null
	game = await _play(1)
	current_scene = null
	var lane := _straight(game, 3)
	_check(not lane.is_empty(), "found a straight corridor")
	var dir := Vector2(lane.dir)
	var hit := {wall = false}
	game.slime.jump_landed.connect(func(_d: float, wall: bool, _n: Vector2) -> void: hit.wall = wall)
	var start := MazeGenerator.cell_center(lane.cell, 16) + dir.orthogonal() * 2.0  # 2 px off the lane's center line
	game.slime.position = start
	game.last_slime_pos = start
	game.slime.facing = dir
	await physics_frame
	game.slime.launch(20.0)  # about 2.5 tiles, well inside the corridor
	await _frames(40)
	_check(not hit.wall and game.slime.last_jump_traveled > 30.0,
		"a leap that only grazes the wall slips past (flew %.0f px, no splat)" % game.slime.last_jump_traveled)
	game.slime.position = MazeGenerator.cell_center(lane.cell, 16)
	game.slime.facing = -dir if not (lane.cell - lane.dir) in MazeGenerator.open_neighbors(game.maze, lane.cell) else dir.orthogonal()
	await physics_frame
	var straight_into_wall := _wall_dir(game, lane.cell)
	game.slime.facing = straight_into_wall
	game.slime.launch(100.0)
	await _frames(40)
	_check(hit.wall, "a leap square into a wall still splats")
	game.free()

	# --- Opaque by default; JELLY ON shows the jelly skins, which unlock on hard mode (D14)
	progress.levels_cleared = 2
	progress.hard_cleared.clear()
	progress.selected_skin = Skins.DEFAULT
	progress.set_jelly(false)
	_check(not progress.is_skin_unlocked("rainbow") and Skins.get_preset("gold").is_empty(), "no gold skin; rainbow locked")
	var preview := UIKit.make_slime_preview(Color.RED)
	_check((preview.material as ShaderMaterial).get_shader_parameter("translucency") == 0.0, "slimes are opaque by default")
	preview.free()
	var skins: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(skins)
	await process_frame
	_check(skins.jelly_button.text == "JELLY: OFF" and skins.tiles.size() == 13, "the skins screen has a JELLY switch, off (13 skins)")
	_check(progress.is_skin_unlocked("mint", false), "clearing level 1 unlocks opaque mint")
	skins.jelly_button.pressed.emit()
	_check(skins.jelly_button.text == "JELLY: ON" and not progress.is_skin_unlocked("mint", true),
		"JELLY ON shows the jelly skins: locked until their level is beaten on hard")
	skins._on_tile("mint")
	_check("JELLY LOCKED - HARD CLEAR L1" in skins.status.text and not progress.jelly, "...it says which hard level unlocks it (%s)" % skins.status.text)
	progress.hard_cleared.assign([1, 2])
	skins._on_tile("mint")
	_check(progress.selected_skin == "mint" and progress.jelly, "beating the level on hard unlocks it, and picking it wears it as jelly")
	var jelly_preview := UIKit.make_slime_preview(Color.RED)
	_check((jelly_preview.material as ShaderMaterial).get_shader_parameter("translucency") == 1.0, "...and every slime is jelly now")
	jelly_preview.free()
	skins.free()
	game = await _play(2)
	current_scene = null
	_check((game.slime.sprite.material as ShaderMaterial).get_shader_parameter("translucency") == 1.0, "the level's slime is jelly too")
	game.free()
	progress.set_jelly(false)
	progress.hard_cleared.clear()

	# --- RESET PROGRESS needs CONFIRM
	progress.select_skin("mint")
	progress.upgrades = {"slime": 3}
	progress.sound_on = false
	var screen: Control = load("res://scenes/controls.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.reset_button.text == "RESET PROGRESS" and not screen.reset_confirm.visible, "settings have a RESET PROGRESS button")
	screen.reset_button.pressed.emit()
	_check(screen.reset_confirm.visible and progress.levels_cleared == 2, "pressing it only asks: ERASE ALL PROGRESS? (nothing wiped yet)")
	screen.cancel_button.pressed.emit()
	_check(not screen.reset_confirm.visible and progress.levels_cleared == 2, "CANCEL keeps everything")
	screen.reset_button.pressed.emit()
	screen.confirm_button.pressed.emit()
	_check(progress.levels_cleared == 0 and progress.coins_earned() == 0 and progress.upgrades.is_empty()
		and progress.selected_skin == Skins.DEFAULT, "CONFIRM wipes levels, coins, upgrades and skins")
	_check(not progress.sound_on, "...but keeps the settings")
	screen.free()
	progress.sound_on = true

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	_result()
	quit(1 if failures else 0)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## A direction from `cell` that runs straight into a wall.
func _wall_dir(game: Node2D, cell: Vector2i) -> Vector2:
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not (cell + d) in MazeGenerator.open_neighbors(game.maze, cell):
			return Vector2(d)
	return Vector2.UP


func _straight(game: Node2D, length: int) -> Dictionary:
	for y in game.maze.cells.y:
		for x in game.maze.cells.x:
			for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var cell := Vector2i(x, y)
				var ok := true
				for i in length:
					ok = ok and (cell + dir) in MazeGenerator.open_neighbors(game.maze, cell)
					cell += dir
				if ok:
					return {cell = Vector2i(x, y), dir = dir}
	return {}


func _play(level: int) -> Node2D:
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	current_scene = game
	await physics_frame
	return game


func _frames(count: int) -> void:
	for i in count:
		await process_frame


