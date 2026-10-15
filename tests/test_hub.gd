extends "res://tests/suite_base.gd"

## The hub (the title screen): a slime-shaped room with the stations evenly round its rim facing
## the center and a wheel in the middle. Checks: every station is there, evenly spaced; each
## shows the right view for where it stands (front at the back of the room, sides mirrored, backs
## up close); hitting the wheel (interact key beside it) turns the whole room one station round,
## the floor drawn for the new turn; next to a station the prompt names it and the interact key (F)
## uses it while SPACE still leaps; the randomizer portal stays locked until the story is beaten;
## coming back from a station turns the room to face it.
## Starts from a fresh state (tests never read the real save).
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_hub.gd

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
	progress.levels_cleared = 1  # an existing save (a fresh one plays level 1; see test_flow)

	# --- The title screen leads into the hub
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _physics_frames(2)
	var texts: Array = []
	for node in title.find_children("*", "Label", true, false):
		texts.append(node.text)
	_check(title.enter_button.text == "ENTER THE HUB" and "ESCAPE THE FOG\nOR DRY TRYING" in texts and ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn",
		"the game opens on the title: ENTER THE HUB, then the tagline (no !)")
	title.free()

	# --- The room, its stations and their views
	HubScript.return_to = ""
	var hub: Node2D = await _open()
	progress.hard_mode = false
	hub._refresh_tickets()
	_check(hub.medal_label.text == "0/%d" % (Levels.COUNT * 3), "the hub's medal count is out of 3 per level (%s)" % hub.medal_label.text)
	progress.medals = {1: 3, 2: 2, 101: 3}
	progress.hard_mode = true
	hub._refresh_tickets()
	_check(hub.medal_label.text == "5/%d" % (Levels.COUNT * 3), "...and always counts the normal mode's tiers, hard mode or not (%s)" % hub.medal_label.text)
	progress.medals = {}
	progress.hard_mode = false
	var ids: Array = hub.stations.map(func(s: Dictionary) -> String: return s.id)
	_check(ids == ["story", "maps", "upgrades", "quit", "coins", "random", "settings", "wheel", "wardrobe"],
		"the room has every station: %s" % ", ".join(ids))
	_check(is_equal_approx(hub.step, TAU / 9.0), "...evenly spaced round the rim")
	var story: Dictionary = hub._station("story")
	_check(story.view == HubScript.View.FRONT and story.sprite.region_rect.position.y == 0.0,
		"the station at the back of the room shows its front")
	var right: Dictionary = hub._station("upgrades")
	var left: Dictionary = hub._station("wheel")
	_check(right.view == HubScript.View.SIDE and right.sprite.flip_h and left.view == HubScript.View.SIDE and not left.sprite.flip_h,
		"stations at the sides show their side, facing the center (mirrored on the right)")
	_check(hub._station("coins").view == HubScript.View.BACK and hub._station("random").view == HubScript.View.BACK,
		"stations up close show their back")
	_check(hub.near.is_empty() and not hub.prompt.visible, "the slime starts in the room with nothing to use")

	# --- Away from stations the jump key leaps as usual
	Input.action_press("jump")
	await _physics_frames(3)
	_check(hub.slime.state == Slime.State.CHARGING, "away from stations, the jump key charges a leap")
	Input.action_release("jump")
	await _physics_frames(70)
	hub.free()

	# --- The wheel turns the room one station round
	HubScript.return_to = "story"
	hub = await _open()
	hub.slime.position = hub.rotor.position + Vector2(0, 8)
	await _physics_frames(2)
	_check(hub.near.get("id", "") == "rotor" and hub.prompt_name.text == "ROTATE", "the wheel offers to rotate the room")
	for side: Vector2 in [Vector2(0, -9), Vector2(13, -2), Vector2(-13, -2)]:
		hub.slime.position = hub.rotor.position + side
		await _physics_frames(2)
		_check(hub.near.get("id", "") == "rotor", "...from any side of it too (%s)" % side)
	_check(hub.rotor_base.z_index < 0 and hub.rotor.get_parent() == hub.world and hub.rotor_base.region_rect.position.y == HubScript.ROTOR_SPLIT,
		"the goo at the wheel's foot lies under the slime; the post and wheel are y-sorted with it")
	var far_station: Dictionary = hub._station("story")
	var near_volume: float = hub.station_volume(far_station)
	hub.slime.position = far_station.sprite.position + Vector2(18, 10)
	await _physics_frames(2)
	_check(hub.near.get("id", "") == "story", "a station can be used from beside it, not just in front")
	_check(hub.station_volume(far_station) > near_volume + 8.0, "a station sounds much louder up close than from across the room (%.0f vs %.0f dB)" % [hub.station_volume(far_station), near_volume])
	hub.slime.position = hub.rotor.position + Vector2(0, 8)
	await _physics_frames(2)
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.turning and hub.slime.state == Slime.State.GLIDE, "hitting it (F) starts the room turning (no leap)")
	await _physics_frames(int(HubScript.TURN_TIME * 60) + 4)
	_check(not hub.turning and hub._station("maps").view == HubScript.View.FRONT and hub._station("story").view == HubScript.View.SIDE,
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
	await _physics_frames(20)
	Input.action_release("move_right")
	_check(absf(slime.position.y - start_y) < 0.5, "gliding sideways doesn't tug toward grid lanes (y moved %.2f)" % (slime.position.y - start_y))
	await _physics_frames(30)
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

	# --- The story prompt is just its name and level; Esc goes back to the title
	HubScript.return_to = "story"
	hub = await _open()
	_check(hub.prompt_name.text.begins_with("STORY - LEVEL") and hub.prompt_key.text == "", "the story prompt has no key after it (%s)" % hub.prompt_name.text)
	current_scene = hub
	Input.action_press("menu")
	await _physics_frames(2)
	Input.action_release("menu")
	_check(hub.slime.frozen, "Esc in the hub heads back to the title")
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/title.tscn":
			break
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/title.tscn", "...and lands on it")
	if current_scene and current_scene.scene_file_path == "res://scenes/title.tscn":
		var title_scene := current_scene
		current_scene = null
		title_scene.free()
	if is_instance_valid(hub):
		hub.free()

	# --- Next to a station: the prompt, and the jump key uses it
	HubScript.return_to = "upgrades"
	hub = await _open()
	_check(hub._station("upgrades").view == HubScript.View.FRONT, "coming back from a station turns the room to face it")
	_check(hub.prompt.visible and hub.prompt_name.text == "UPGRADES" and hub.prompt_key.text == "",
		"standing at it, the prompt names it, with no key after it (%s %s)" % [hub.prompt_name.text, hub.prompt_key.text])
	Input.action_press("jump")
	await _physics_frames(3)
	_check(hub.slime.state == Slime.State.CHARGING and not hub.slime.frozen, "...SPACE still leaps there (F is the use key)")
	Input.action_release("jump")
	hub.free()

	# --- The randomizer portal is locked until the story is beaten
	HubScript.return_to = "random"
	hub = await _open()
	Input.action_press("interact")
	await _physics_frames(2)
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

	# --- The hat wheel (dev mode for now): spins land on a hat you don't have, which comes off it
	progress.hats_owned.clear()
	progress.selected_hat = Hats.NONE
	HubScript.return_to = "wheel"
	hub = await _open()
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.hat_wheel.visible and hub.hat_wheel.tab == "wheel" and not hub.hat_wheel.spin_button.disabled and "FREE" in hub.hat_wheel.spin_button.text,
		"hats are live: a player's first visit opens the wheel with a FREE spin")
	hub.free()
	progress.dev_tools = true
	hub = await _open()
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.hat_wheel.visible and hub.hat_wheel.hats.size() == Hats.LIST.size(), "in dev mode it opens with every hat on the wheel (%d)" % hub.hat_wheel.hats.size())
	var won: Array[String] = []
	for spin_number in 3:
		Input.action_press("interact")
		await _physics_frames(2)
		Input.action_release("interact")
		_check(hub.hat_wheel.spinning, "spin %d starts the wheel" % (spin_number + 1))
		for i in int(hub.hat_wheel.SPIN_TIME * 60) + 10:
			await physics_frame
		var hat_id: String = progress.selected_hat
		won.append(hat_id)
		var under: String = hub.hat_wheel.hats[hub.hat_wheel.wedge_at(hub.hat_wheel.turn)]
		_check(not hub.hat_wheel.spinning and under == hat_id and hat_id in progress.hats_owned and not hat_id in progress.hats_left() and hub.hat != null,
			"...lands on %s (the wedge under the pointer): won, worn, and off the wheel (%d left)" % [hat_id, progress.hats_left().size()])
	var unique := {}
	for id in won:
		unique[id] = true
	_check(unique.size() == 3 and progress.hats_left().size() == Hats.LIST.size() - 3, "three spins, three different hats")
	_check(hub.hat.get_parent() == hub.slime and hub.hat.z_index == 0 and hub.slime.get_parent() == hub.world,
		"the hat is y-sorted with the slime (behind the wheel when the slime is)")
	# The rainbow hat is the rare one: a thinner wedge, and landed on less often.
	var wheel = hub.hat_wheel
	progress.rainbow_pity = 0  # (the three spins above missed it: pity would fatten its wedge)
	var saved_hats: Array[String] = wheel.hats.duplicate()
	wheel.hats = Hats.ids()
	var rare: int = wheel.hats.find("rainbow")
	_check(rare >= 0 and wheel.sizes[rare] < wheel.sizes[0] * 0.5, "the rainbow hat's wedge is a thin sliver (%.2f vs %.2f)" % [wheel.sizes[rare], wheel.sizes[0]])
	var rainbow_picks := 0
	var top_hat_picks := 0
	for i in 4000:
		var pick: int = wheel.hats.find(Hats.pick(wheel.hats, 0, randf()))
		rainbow_picks += int(pick == rare)
		top_hat_picks += int(pick == 0)
	_check(rainbow_picks > 0 and rainbow_picks < top_hat_picks * 0.5, "the rainbow hat comes up far less often (%d vs %d for the top hat)" % [rainbow_picks, top_hat_picks])
	wheel.hats = saved_hats
	progress.hats_owned.assign(Hats.ids())
	hub.hat_wheel._won = ""
	hub.hat_wheel.refresh("F")
	_check(hub.hat_wheel.hats.is_empty() and "EVERY HAT" in hub.hat_wheel.result.text and not hub.hat_wheel.spin(), "once every hat is won, the wheel says so and won't spin")
	hub.free()
	progress.dev_tools = false
	progress.hats_owned.clear()
	progress.selected_hat = Hats.NONE

	# --- The coin bag's board: coins found per level
	progress.coins_found = {2: ["a", "b", "c"]}
	for i in Levels.COINS[0]:
		progress.coins_found[1] = progress.coins_found.get(1, []) + ["c%d" % i]
	HubScript.return_to = "coins"
	hub = await _open()
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.coin_board.visible and hub.slime.frozen, "F at the coin bag opens the coin board (and holds the slime still)")
	_check(hub.board_rows[0].text == "%d/%d" % [Levels.COINS[0], Levels.COINS[0]] and hub.board_rows[1].text == "3/%d" % Levels.COINS[1]
		and hub.board_rows[9].text == "0/%d" % Levels.COINS[9], "...showing each level's coins found (%s, %s, %s)" % [hub.board_rows[0].text, hub.board_rows[1].text, hub.board_rows[9].text])
	_check(hub.board_rows[0].get_theme_color("font_color") == UIKit.GOLD, "...a level with every coin found shows in gold")
	_check(("%d/%d" % [Levels.COINS[0] + 3, Levels.total_coins()]) in hub.board_total.text, "...and the story total (%s)" % hub.board_total.text)
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(not hub.coin_board.visible and not hub.slime.frozen, "F again closes it")
	hub.free()

	# --- Rainbow skin: the flowing text color a hidden board label is due must not land on a count
	# that left the skin-text group for its gold (QA phase 4, finding 1).
	for level in range(1, Levels.COUNT + 1):
		progress.coins_found[level] = []
		for i in Levels.COINS[level - 1]:
			progress.coins_found[level].append("r%d" % i)
	var kept_skin: String = progress.selected_skin
	progress.selected_skin = Skins.RAINBOW
	_check(progress.is_rainbow(), "every coin found: the rainbow skin is on")
	hub = await _open()
	for i in 10:
		await process_frame  # the rainbow flows while the board is hidden
	hub.open_coin_board()
	for i in 3:
		await process_frame
	var gold := true
	for row: Label in hub.board_rows:
		gold = gold and row.get_theme_color("font_color") == UIKit.GOLD
	_check(gold, "rainbow skin: every finished level's count on the coin board stays gold once it shows")
	hub.close_coin_board()
	hub.free()
	progress.selected_skin = kept_skin
	progress.coins_found = {}

	# --- Using a station leaves for its screen
	HubScript.return_to = "settings"
	hub = await _open()
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.slime.frozen and HubScript.return_to == "settings", "the signpost opens the settings (and remembers it)")
	hub.free()
	HubScript.return_to = ""

	# --- The trapdoor asks first: LEAVE THE HUB? with QUIT and BACK
	HubScript.return_to = "quit"
	hub = await _open()
	_check(not hub.quit_menu.visible, "the confirm panel starts closed")
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.quit_menu.visible and hub.slime.frozen and not hub.prompt.visible, "F at the trapdoor opens the confirm panel instead of quitting (slime held, prompt hidden)")
	_check(hub.back_button.has_focus() and not hub.quit_button.has_focus(), "...with the focus on BACK, so a stray press doesn't quit")
	var panel_ok := true
	for button: Button in [hub.quit_button, hub.back_button]:
		var rect := Rect2(button.global_position, button.size)
		panel_ok = panel_ok and Rect2(hub.QUIT_PANEL).encloses(rect) and button.size.x >= 40
	_check(panel_ok and Rect2(0, 0, 320, 180).encloses(hub.QUIT_PANEL) and not hub.QUIT_PANEL.intersects(Rect2(hub.ticket_pod.global_position, hub.ticket_pod.size)),
		"...buttons sit inside the panel, which fits 320x180 and clears the ticket pod")
	_check(hub._touch_controls.menu_open, "...touch controls step aside so taps reach the buttons")
	var ui_right := InputEventAction.new()
	ui_right.action = "ui_left"
	ui_right.pressed = true
	Input.parse_input_event(ui_right)
	await _physics_frames(3)
	_check(hub.quit_button.has_focus(), "...a controller / arrow key moves the focus to QUIT")
	hub.back_button.grab_focus()
	Input.action_press("menu")
	await _physics_frames(2)
	Input.action_release("menu")
	_check(not hub.quit_menu.visible and not hub.slime.frozen, "Esc / menu closes it")
	_check(not hub.quit_menu.visible and not hub.slime.frozen and not hub._touch_controls.menu_open, "...BACK in effect: control returns to the slime")
	Input.action_press("interact")
	await _physics_frames(2)
	Input.action_release("interact")
	_check(hub.quit_menu.visible, "it opens again at the trapdoor")
	hub.back_button.pressed.emit()
	await _physics_frames(2)
	_check(not hub.quit_menu.visible and not hub.slime.frozen and hub.quit_button.pressed.get_connections().size() >= 2, "BACK button closes it; QUIT is wired up (not pressed here)")
	hub.free()
	HubScript.return_to = ""

	_result()
	quit(1 if failures else 0)


func _open() -> Node2D:
	var hub: Node2D = hub_scene.instantiate()
	root.add_child(hub)
	await _physics_frames(2)
	return hub


