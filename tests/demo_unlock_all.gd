extends Node

## Watchable demo: a brand-new save, played through the real game flow with the autopilot:
## hub -> story door -> level select -> levels 1-10 (a skin unlocks with each, equipped on its next level's first
## try; the color wheel with the last) -> victory screen -> PICK YOUR COLOR -> the skins screen.
## Uses its own throwaway save file, so the real save is never touched. Run it with:
## .\tools\play.ps1 -Scene res://tests/demo_unlock_all.tscn

const DEMO_SAVE := "user://demo_fresh_save.cfg"
## Pauses so each moment can be seen: on the title, on each win (to read what unlocked), etc.
const TITLE_PAUSE := 2.5
const WIN_PAUSE := 3.5
const VICTORY_PAUSE := 5.0

const TITLE := "res://scenes/hub.tscn"
const LEVEL_SELECT := "res://scenes/level_select.tscn"
const GAME := "res://scenes/main.tscn"
const VICTORY := "res://scenes/victory.tscn"
const SKINS := "res://scenes/skins.tscn"


func _ready() -> void:
	_fresh_save()
	# The driver lives on the root so it survives every scene change.
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred(TITLE)


## Points Progress at the demo's own save file and resets it to a brand-new game (sound,
## volume and key bindings are kept).
func _fresh_save() -> void:
	Progress.save_path = DEMO_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DEMO_SAVE))
	Progress.levels_cleared = 0
	Progress.highest_unlocked = 1
	Progress.current_level = 1
	Progress.selected_skin = Skins.DEFAULT
	Progress.custom_color = Color8(239, 125, 47)
	Progress.hard_mode = false
	Progress.best_times = {}
	Progress.skin_notices_seen.clear()
	Progress.mode = Progress.MODE_STORY
	Progress.randoms_cleared = 0
	Progress.randoms_won = 0
	Progress.skin_override = ""
	Progress.selected_hat = Hats.NONE
	Progress.coins_found = {}
	Progress.upgrades = {}
	Progress.save_progress()


class Driver:
	extends Node

	var _wait := 0.0
	var _handled: Node = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_wait -= delta
		var scene := get_tree().current_scene
		if _wait > 0.0 or scene == null or Transition.busy:
			return
		match scene.scene_file_path:
			TITLE:  # the hub: glide to the story door and use it
				_once(scene, TITLE_PAUSE, func() -> void: scene._use(scene._station("story")))
			LEVEL_SELECT:
				_once(scene, 1.0, func() -> void: _press(scene.level_buttons[Progress.current_level - 1]))
			GAME:
				_play(scene)
			VICTORY:
				_once(scene, VICTORY_PAUSE, func() -> void: _press(scene.buttons[0]))  # PICK YOUR COLOR
			SKINS:
				_once(scene, 1.5, func() -> void: queue_free())

	## In a level: hand it to the autopilot, then after a win move on (or, once the rainbow
	## skin is earned, go and look at the skins).
	func _play(game: Node) -> void:
		if not game.has_node("Autopilot"):
			var pilot: Node = preload("res://tests/autopilot.gd").new()
			pilot.name = "Autopilot"
			game.add_child(pilot)
			return
		if not game.won or game.hud.choice_buttons.is_empty() or not game.hud.choice_buttons[-1].is_visible_in_tree():
			return
		if game == _handled:
			return
		_handled = game
		_wait = WIN_PAUSE
		await get_tree().create_timer(WIN_PAUSE).timeout
		if not is_instance_valid(game):
			return
		_press(game.hud.choice_buttons[-1])  # NEXT LEVEL / CONTINUE

	## Runs `action` once per screen, after `pause` seconds on it.
	func _once(scene: Node, pause: float, action: Callable) -> void:
		if scene == _handled:
			return
		_handled = scene
		_wait = pause
		await get_tree().create_timer(pause).timeout
		if is_instance_valid(scene) and get_tree().current_scene == scene:
			action.call()

	func _press(button: Button) -> void:
		button.grab_focus()
		button.pressed.emit()
