extends Node

## Capture scenario for the tutorial's UI pass (docs/tutorial/design.md sections 4-5; gate forced on, a clean
## in-memory state, nothing saved). Prints "CAPTURE <name> <frame>" at each moment for picking movie frames.
##   --shot=tour      the hub tour: the first line, each turn's line (CAPTURE turn<N>), the turn-back hint,
##                    the end line (THE WAY UP, WALK IN)
##   --shot=pause     the training maze with the pause menu open (a first run: no SKIP TRAINING)
##   --shot=settings  SETTINGS with the TRAINING button
##   --shot=hub_plain the hub by the wheel with the gate off (the ROTATE prompt as before)
##   --shot=settings_plain / l1_cue / l1_dry  gate off: SETTINGS, level 1's move glyph, level 1's dry-up row
##                    (before / after proofs that the normal screens are unchanged)
##   --device=keys|pad|touch
##   --out=DIR  saves each capture as DIR/<name>.png (320x180, the frame as drawn); without it, pick the
##              frames from a --write-movie run
## ./tools/godot.sh --path . --fixed-fps 60 --quit-after 1500 res://tests/demo_tutorial_ui.tscn -- --shot=tour \
##     --device=pad --out=/tmp/x

var shot := "tour"
var device := "keys"
var frame := 0
var scene: Node
var _printed := {}
var _turns := 0
var _wait := 0
var out_dir := ""
## Captures waiting for their frame: name -> physics frame.
var _pending := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.get_slice("=", 1)
		elif arg.begins_with("--device="):
			device = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
	seed(20261018)  # (the menu backdrop and the text drips: the same frame every run)
	var plain := shot in ["hub_plain", "settings_plain", "l1_cue", "l1_dry"]
	Economy.tutorial_force = 0 if plain else 1
	Progress.saving_enabled = false
	Progress.reset_progress()
	Progress.dev_tools = false
	Progress.force_touch = device == "touch"
	match shot:
		"tour", "hub_plain":
			Progress.tutorial_seen = Progress.TUTORIAL_MOVE | Progress.TUTORIAL_LEAP | Progress.TUTORIAL_TRAINING
			Progress.training_coin = true
			scene = load("res://scenes/hub.tscn").instantiate()
		"pause":
			Progress.prepare_training(false)
			scene = load("res://scenes/main.tscn").instantiate()
		"settings", "settings_plain":
			scene = load("res://scenes/controls.tscn").instantiate()
		"l1_cue", "l1_dry":
			Progress.current_level = 1
			scene = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(scene)


func _capture(what: String, delay := 0) -> void:
	if not _printed.has(what):
		_printed[what] = true
		print("CAPTURE %s %d" % [what, Engine.get_frames_drawn() + delay])  # (the movie frame number)
		_pending[what] = frame + maxi(delay, 0)


func _save_due() -> void:
	for what: String in _pending.keys():
		if frame >= int(_pending[what]):
			_pending.erase(what)
			if out_dir != "":
				_save(what)


func _save(what: String) -> void:
	RenderingServer.force_draw(false)  # (a hidden or covered window may skip its own draws)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var name_dev := "%s_%s" % [what, device]
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_dev + ".png"))


func _physics_process(_delta: float) -> void:
	frame += 1
	if UIKit._text_material:
		UIKit._text_material.set_shader_parameter("seed", 1234.0)  # (the same drips every run)
	_save_due()
	Platform.last_input = {keys = Platform.INPUT_KEYS, pad = Platform.INPUT_PAD, touch = Platform.INPUT_TOUCH}[device]
	if frame == 2:
		get_tree().current_scene = scene
	if frame < 3:
		return
	match shot:
		"tour":
			_tour()
		"hub_plain":
			if frame == 4:
				scene.slime.position = scene.rotor.position + Vector2(0, 8)
			elif frame == 60:
				_capture("plain")
		"pause":
			if frame == 80:
				scene.pause_menu.open()
			elif frame == 110:
				_capture("pause")
		"settings", "settings_plain":
			if frame == 38:
				for node in scene.find_children("*", "MenuBackdrop", true, false):
					node.visible = false  # (it drifts with the clock: off, so two runs compare pixel for pixel)
			elif frame == 40:
				_capture(shot)
		"l1_cue":
			if frame == 80:
				_capture(shot)
		"l1_dry":
			if frame == 20:
				scene.slime_remaining = 0.0
			elif frame == 120:
				_capture(shot)


## Stands by the wheel: 60 frames on each line (CAPTURE line<N>: the line after N turns), then one turn;
## after the second turn it waits for the turn-back hint (CAPTURE hint); ends on the last line (CAPTURE end).
func _tour() -> void:
	var tour: Node = scene.tour
	if tour == null or scene.turning:
		return
	_wait += 1
	if _turns == 2 and not tour.hint_shown:
		if _wait == 50:
			_capture("line2")
		return  # (the hint comes after HINT_DELAY by the wheel)
	if _turns == 2 and tour.hint_on and not _printed.has("hint"):
		_capture("hint", 20)
		_wait = -40
		return
	if _wait == 50:
		_capture("end" if tour.done else "line%d" % _turns)
	if _wait < 60 or tour.done:
		return
	_wait = 0
	_turns += 1
	scene.turn_room(1)
