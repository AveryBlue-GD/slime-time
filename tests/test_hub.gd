extends SceneTree

## The hub (the title screen): a slime-shaped room with the stations evenly round its rim facing
## the center and a wheel in the middle. Checks: every station is there, evenly spaced; each
## shows the right view for where it stands (front at the back of the room, sides mirrored, backs
## up close); hitting the wheel (interact key beside it) turns the whole room one station round,
## the floor drawn for the new turn; next to a station the prompt names it and the interact key (F)
## uses it while SPACE still leaps; the randomizer portal stays locked until the story is beaten;
## coming back from a station turns the room to face it.
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

	# --- The title screen leads into the hub
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _frames(2)
	var texts: Array = []
	for node in title.find_children("*", "Label", true, false):
		texts.append(node.text)
	_check(title.enter_button.text == "ENTER THE HUB" and "ESCAPE THE FOG OR DRY TRYING" in texts and ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn",
		"the game opens on the title: ENTER THE HUB, then the tagline (no !)")
	title.free()

	# --- The room, its stations and their views
	HubScript.return_to = ""
	var hub: Node2D = await _open()
	var ids: Array = hub.stations.map(func(s: Dictionary) -> String: return s.id)
	_check(ids == ["story", "upgrades", "coins", "random", "settings", "quit", "wheel", "wardrobe"],
		"the room has every station: %s" % ", ".join(ids))
	_check(is_equal_approx(hub.step, TAU / 8.0), "...evenly spaced round the rim")
	var story: Dictionary = hub._station("story")
	_check(story.view == HubScript.View.FRONT and story.sprite.region_rect.position.y == 0.0,
		"the station at the back of the room shows its front")
	var right: Dictionary = hub._station("random")
	var left: Dictionary = hub._station("wheel")
	_check(right.view == HubScript.View.SIDE and right.sprite.flip_h and left.view == HubScript.View.SIDE and not left.sprite.flip_h,
		"stations at the sides show their side, facing the center (mirrored on the right)")
	_check(hub._station("settings").view == HubScript.View.BACK, "stations up close show their back")
	_check(hub.near.is_empty() and not hub.prompt.visible, "the slime starts in the room with nothing to use")

	# --- Away from stations the jump key leaps as usual
	Input.action_press("jump")
	await _frames(3)
	_check(hub.slime.state == Slime.State.CHARGING, "away from stations, the jump key charges a leap")
	Input.action_release("jump")
	await _frames(70)
	hub.free()

	# --- The wheel turns the room one station round
	HubScript.return_to = "story"
	hub = await _open()
	hub.slime.position = hub.rotor.position + Vector2(0, 8)
	await _frames(2)
	_check(hub.near.get("id", "") == "rotor" and hub.prompt_name.text == "TURN THE ROOM", "the wheel offers to turn the room")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(hub.turning and hub.slime.state == Slime.State.GLIDE, "hitting it (F) starts the room turning (no leap)")
	await _frames(int(HubScript.TURN_TIME * 60) + 4)
	_check(not hub.turning and hub._station("upgrades").view == HubScript.View.FRONT and hub._station("story").view == HubScript.View.SIDE,
		"...one station round: the next one comes to the back, facing you")
	var floor_turn: float = (hub.room.material as ShaderMaterial).get_shader_parameter("turn")
	_check(is_equal_approx(floor_turn, hub.turn) and not is_zero_approx(floor_turn), "...and the floor and rim turn with it (turn %.2f)" % floor_turn)
	hub.free()

	# --- Bumping into things is smooth: no lane tugging, no clipping or jumps
	HubScript.return_to = ""
	hub = await _open()
	var slime: Slime = hub.slime
	slime.position = hub.rotor.position + Vector2(-3, 30)  # below the wheel, a little off-center
	var start_y := slime.position.y
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(absf(slime.position.y - start_y) < 0.5, "gliding sideways doesn't tug toward grid lanes (y moved %.2f)" % (slime.position.y - start_y))
	await _frames(30)
	slime.position = hub.rotor.position + Vector2(-3, 30)
	var largest := 0.0
	var last := slime.position
	Input.action_press("move_up")
	for i in 90:  # glide up into the wheel's post and keep pushing
		await physics_frame
		largest = maxf(largest, slime.position.distance_to(last))
		last = slime.position
	Input.action_release("move_up")
	var limit: float = slime.max_speed / 60.0 + 0.5
	_check(largest <= limit, "pushing into the wheel never jumps (largest step %.2f px, a frame's glide is %.2f)" % [largest, limit])
	_check(slime.position.y > hub.rotor.position.y - 2.0, "...and the slime doesn't pass through it")
	hub.free()

	# --- Next to a station: the prompt, and the jump key uses it
	HubScript.return_to = "upgrades"
	hub = await _open()
	_check(hub._station("upgrades").view == HubScript.View.FRONT, "coming back from a station turns the room to face it")
	_check(hub.prompt.visible and hub.prompt_name.text == "UPGRADES" and hub.prompt_key.text == "F",
		"standing at it, the prompt names it and its key (%s %s)" % [hub.prompt_name.text, hub.prompt_key.text])
	Input.action_press("jump")
	await _frames(3)
	_check(hub.slime.state == Slime.State.CHARGING and not hub.slime.frozen, "...SPACE still leaps there (F is the use key)")
	Input.action_release("jump")
	hub.free()

	# --- The randomizer portal is locked until the story is beaten
	HubScript.return_to = "random"
	hub = await _open()
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(hub.prompt_key.text.begins_with("BEAT ALL") and not hub.slime.frozen,
		"the locked portal says what unlocks it and you stay in the room (%s)" % hub.prompt_key.text)
	_check(hub._station("random").sprite.modulate != Color.WHITE, "...and it looks dimmed")
	hub.free()
	progress.levels_cleared = Levels.COUNT
	hub = await _open()
	_check(hub._station("random").sprite.modulate == Color.WHITE and hub.prompt_key.text != "LOCKED",
		"beating the story opens the portal")
	hub.free()

	# --- Stations come to life now and then
	HubScript.return_to = ""
	hub = await _open()
	var seen := {}
	for id in ["wardrobe", "quit", "wheel", "settings"]:
		var station: Dictionary = hub._station(id)
		for anim: Dictionary in station.anims:
			anim.next = 1e9  # hold them all...
		seen[id] = [station.frame]
	hub._station("wardrobe").anims[1].next = 0.0  # ...then fire the wardrobe door,
	hub._station("quit").anims[0].next = 0.0      # the trapdoor,
	hub._station("wheel").anims[0].next = 0.0     # a wheel spin
	hub._station("settings").anims[0].next = 0.0  # and the gears turning
	for i in 360:
		await process_frame
		for id in seen:
			var frame: int = hub._station(id).frame
			if frame != seen[id][-1]:
				seen[id].append(frame)
	_check(4 in seen.wardrobe and seen.wardrobe[-1] == 0, "the wardrobe door swings open and shut again (frames %s)" % [seen.wardrobe])
	var puffed: int = seen.quit.find(2)
	_check(puffed > 0 and seen.quit.find(0, puffed) > puffed, "the trapdoor blows open with a puff and slams shut (frames %s)" % [seen.quit])
	_check(seen.wheel.size() > 20, "the prize wheel spins round (%d steps)" % (seen.wheel.size() - 1))
	_check(seen.settings.size() > 10, "the settings gears turn (%d steps)" % (seen.settings.size() - 1))
	var rest: int = hub._station("wheel").frame
	for i in 60:
		await process_frame
	_check(hub._station("wheel").frame == rest, "...and stops where it stops")
	hub.free()

	# --- The coin bag's board: coins found per level
	progress.coins_found = {2: ["a", "b", "c"]}
	for i in Levels.COINS[0]:
		progress.coins_found[1] = progress.coins_found.get(1, []) + ["c%d" % i]
	HubScript.return_to = "coins"
	hub = await _open()
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(hub.coin_board.visible and hub.slime.frozen, "F at the coin bag opens the coin board (and holds the slime still)")
	_check(hub.board_rows[0].text == "%d/%d" % [Levels.COINS[0], Levels.COINS[0]] and hub.board_rows[1].text == "3/%d" % Levels.COINS[1]
		and hub.board_rows[9].text == "0/%d" % Levels.COINS[9], "...showing each level's coins found (%s, %s, %s)" % [hub.board_rows[0].text, hub.board_rows[1].text, hub.board_rows[9].text])
	_check(hub.board_rows[0].get_theme_color("font_color") == UIKit.GOLD, "...a level with every coin found shows in gold")
	_check(("%d/%d" % [Levels.COINS[0] + 3, Levels.total_coins()]) in hub.board_total.text, "...and the story total (%s)" % hub.board_total.text)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(not hub.coin_board.visible and not hub.slime.frozen, "F again closes it")
	hub.free()
	progress.coins_found = {}

	# --- Using a station leaves for its screen
	HubScript.return_to = "settings"
	hub = await _open()
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
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
