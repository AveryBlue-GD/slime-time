extends SceneTree

## The hub (the title screen): a slime-shaped room with the stations evenly round its rim facing
## the center and a wheel in the middle. Checks: every station is there, evenly spaced; each
## shows the right view for where it stands (front at the back of the room, sides mirrored, backs
## up close); hitting the wheel (jump key beside it, or leaping into it) turns the room one station
## round; next to a station the prompt names it and the jump key uses it instead of leaping (and
## leaps as usual elsewhere); the randomizer portal stays locked until the story is beaten; coming
## back from a station turns the room to face it; the title logo fades once you move.
## Starts from a fresh state (tests never read the real save).
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

	# --- The room, its stations and their views
	HubScript.return_to = ""
	var hub: Node2D = await _open()
	var ids: Array = hub.stations.map(func(s: Dictionary) -> String: return s.id)
	_check(ids == ["story", "upgrades", "random", "settings", "quit", "wheel", "wardrobe"],
		"the room has every station: %s" % ", ".join(ids))
	_check(is_equal_approx(hub.step, TAU / 7.0), "...evenly spaced round the rim")
	var story: Dictionary = hub._station("story")
	_check(story.view == HubScript.View.FRONT and story.sprite.region_rect.position.y == 0.0,
		"the station at the back of the room shows its front")
	var right: Dictionary = hub._station("random")
	var left: Dictionary = hub._station("wheel")
	_check(right.view == HubScript.View.SIDE and right.sprite.flip_h and left.view == HubScript.View.SIDE and not left.sprite.flip_h,
		"stations at the sides show their side, facing the center (mirrored on the right)")
	_check(hub._station("settings").view == HubScript.View.BACK, "stations up close show their back")
	_check(hub.logo_layer != null and hub.near.is_empty() and not hub.prompt.visible,
		"a fresh start shows the logo; the slime starts with nothing to use")

	# --- Away from stations the jump key leaps as usual, and moving fades the logo
	Input.action_press("jump")
	await _frames(3)
	_check(hub.slime.state == Slime.State.CHARGING, "away from stations, the jump key charges a leap")
	Input.action_release("jump")
	await _frames(70)
	_check(hub.logo_layer == null or hub.logo_layer.has_meta("fading"), "moving fades the logo")
	hub.free()

	# --- The wheel turns the room one station round
	HubScript.return_to = "story"
	hub = await _open()
	hub.slime.position = hub.rotor.position + Vector2(0, 8)
	await _frames(2)
	_check(hub.near.get("id", "") == "rotor" and hub.prompt_name.text == "TURN THE ROOM", "the wheel offers to turn the room")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(hub.turning and hub.slime.state == Slime.State.GLIDE, "hitting it starts the room turning (no leap)")
	await _frames(int(HubScript.TURN_TIME * 60) + 4)
	_check(not hub.turning and hub._station("upgrades").view == HubScript.View.FRONT and hub._station("story").view == HubScript.View.SIDE,
		"...one station round: the next one comes to the back, facing you")
	hub.free()

	# --- Next to a station: the prompt, and the jump key uses it
	HubScript.return_to = "upgrades"
	hub = await _open()
	_check(hub._station("upgrades").view == HubScript.View.FRONT and hub.logo_layer == null,
		"coming back from a station turns the room to face it (no logo)")
	_check(hub.prompt.visible and hub.prompt_name.text == "UPGRADES" and not hub.slime.can_charge,
		"standing at it, the prompt names it and the jump key won't leap (%s)" % hub.prompt_name.text)
	hub.free()

	# --- The randomizer portal is locked until the story is beaten
	HubScript.return_to = "random"
	hub = await _open()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(hub.prompt_key.text.begins_with("BEAT ALL") and not hub.slime.frozen,
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
