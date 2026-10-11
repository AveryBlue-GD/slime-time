extends SceneTree

## The hub (the title screen): the room has every station; next to one the prompt names it and
## the jump key uses it instead of leaping (and leaps as usual away from them); the randomizer
## portal stays locked (and says so) until the story is beaten; coming back from a station puts
## the slime in front of it. Starts from a fresh state (tests never read the real save).
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hub.gd

var failures := 0
var progress: Node
## Loaded once the autoloads exist (the hub script uses Progress).
var HubScript: GDScript
var hub_scene: PackedScene


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	HubScript = load("res://scripts/hub.gd")
	hub_scene = load("res://scenes/hub.tscn")
	progress.levels_cleared = 0

	# --- The room and its stations
	HubScript.return_to = ""
	var hub: Node2D = await _open()
	var ids: Array = hub.stations.map(func(s: Dictionary) -> String: return s.id)
	_check(ids == ["wardrobe", "wheel", "story", "upgrades", "random", "settings", "quit"],
		"the room has every station: %s" % ", ".join(ids))
	_check(hub.slime.position == HubScript.START and hub.near.is_empty() and not hub.prompt.visible,
		"the slime starts in the middle of the room, nothing to use there")

	# --- Away from stations the jump key leaps as usual
	Input.action_press("jump")
	await _frames(3)
	_check(hub.slime.state == Slime.State.CHARGING, "away from stations, the jump key charges a leap")
	Input.action_release("jump")
	await _frames(60)
	hub.free()

	# --- Next to a station: the prompt, and the jump key uses it
	HubScript.return_to = "upgrades"
	hub = await _open()
	_check(hub.slime.position.distance_to(hub._station("upgrades").use) < HubScript.USE_REACH and hub.near.id == "upgrades",
		"coming back from a station puts the slime in front of it")
	_check(hub.prompt.visible and hub.prompt_name.text == "UPGRADES", "the prompt names the station (%s)" % hub.prompt_name.text)
	_check(not hub.slime.can_charge, "...and the jump key won't charge a leap there")
	hub.free()

	# --- The randomizer portal is locked until the story is beaten
	HubScript.return_to = "random"
	hub = await _open()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(hub.prompt_key.text.begins_with("BEAT ALL") and not hub.slime.frozen and hub.slime.state == Slime.State.GLIDE,
		"the locked portal says what unlocks it and you stay in the room (%s)" % hub.prompt_key.text)
	_check(hub._station("random").sprite.modulate != Color.WHITE, "...and it looks dimmed")
	hub.free()
	progress.levels_cleared = Levels.COUNT
	hub = await _open()
	_check(hub._station("random").sprite.modulate == Color.WHITE and hub.prompt_key.text != "LOCKED",
		"beating the story opens the portal")
	hub.free()

	# --- Using a station leaves for its screen
	HubScript.return_to = "settings"
	hub = await _open()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(hub.slime.frozen and HubScript.return_to == "settings", "the signpost opens the settings (and remembers it)")
	hub.free()
	HubScript.return_to = ""

	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _open() -> Node2D:
	var hub: Node2D = hub_scene.instantiate()
	root.add_child(hub)
	await _frames(2)
	return hub


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
