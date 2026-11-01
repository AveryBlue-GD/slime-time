extends "res://tests/suite_base.gd"

## The first-visit hub tour (chunk D of docs/tutorial/design.md, scripts/hub_tour.gd): it appears only
## when Progress.hub_tour_due() (gate on, training done, no TUTORIAL_HUB yet, or a SETTINGS replay); the
## slime starts by the wheel; each time the player turns the room, the station now at the back is lit and
## its line shows in the prompt box (with the use key: F / X; none on touch); the turn-back hint shows once;
## a full turn ends at the archway. The first visit is guided (owner, 2026-10-27): no SKIP pod, Esc opens the
## hub MENU and B does nothing to it, the other stations say AFTER THE TOUR, and at the end the room holds
## still, THE WAY UP, WALK IN shows wherever the slime is, an arrow points into the archway, and only using
## the archway saves TUTORIAL_HUB. A SETTINGS replay is the free tour: Esc / B / the SKIP pod / using a
## station ends it at any step. The web's 8 stations (no trapdoor) too; gate off: no tour, as today.
## An autopilot reads each line for READ_TIME seconds, turns, then walks to the archway: the tour's length.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hub_tour.gd

## Seconds the autopilot spends reading each line (design.md section 6: ~3 s).
const READ_TIME := 3.0

var progress: Node
var HubScript: GDScript
var TourScript: GDScript
var hub_scene: PackedScene
var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = true
	progress.save_path = test_save
	progress.dev_tools = false
	HubScript = load("res://scripts/hub.gd")
	TourScript = load("res://scripts/hub_tour.gd")
	hub_scene = load("res://scenes/hub.tscn")

	await _gate_off()
	await _full_tour()
	await _no_skips()
	await _skips()
	await _station_ends_it()
	await _devices()
	await _layout()
	await _web_and_replay()
	await _timing()

	Economy.tutorial_force = -1
	Platform.reset_overrides()
	progress.reset_progress()
	_result()
	quit(1 if failures > 0 else 0)


## A save the tour is due for: the training done (gate on), no TUTORIAL_HUB. `replay`: the SETTINGS replay's
## tour (the free one, skippable) instead of the first, guided one.
func _due_save(replay := false) -> void:
	Economy.tutorial_force = 1
	progress.reset_progress()
	progress.dev_tools = false
	progress.tutorial_seen = progress.TUTORIAL_MOVE | progress.TUTORIAL_LEAP | progress.TUTORIAL_TRAINING
	progress.training_skipped = false
	progress.training_coin = true
	progress.tour_replay = replay
	HubScript.return_to = "settings"  # (the tour ignores it: it starts at the archway)


func _open() -> Node2D:
	var hub: Node2D = hub_scene.instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(2)
	return hub


func _press(action: String) -> void:
	Input.action_press(action)
	await _physics_frames(2)
	Input.action_release(action)
	await _physics_frames(1)


## Hits the wheel and waits until the room is still again.
func _turn(hub: Node2D, back := false) -> void:
	if back:
		Input.action_press("move_left")
	await _press("interact")
	if back:
		Input.action_release("move_left")
	for i in 120:
		if not hub.turning:
			break
		await physics_frame
	await _physics_frames(2)


func _close(hub: Node2D) -> void:
	current_scene = null
	hub.free()
	await _physics_frames(2)


# --- Gate off (and gate on but not due): no tour, the hub as today
func _gate_off() -> void:
	Economy.tutorial_force = 0
	progress.reset_progress()
	progress.tutorial_seen = progress.TUTORIAL_TRAINING  # (only a gate-on build writes it; off, nothing is due)
	HubScript.return_to = ""
	var hub := await _open()
	_check(hub.tour == null and hub.slime.position == HubScript.START and hub.near.is_empty() and not hub.prompt.visible,
		"gate off: no tour; the slime starts at START with nothing to use, as today")
	hub.slime.position = hub.rotor.position + Vector2(0, 8)
	await _physics_frames(2)
	_check(hub.prompt_name.text == "ROTATE" and hub.prompt_key.text == "", "gate off: the wheel's prompt is ROTATE, as today")
	await _turn(hub)
	_check(hub.prompt_name.text == "ROTATE" and hub.back_station().id == "maps", "gate off: a turn brings MAP TABLE to the back; still ROTATE")
	await _close(hub)
	Economy.tutorial_force = 1
	progress.tutorial_seen = progress.TUTORIAL_TRAINING | progress.TUTORIAL_HUB
	hub = await _open()
	_check(hub.tour == null, "gate on, the tour already seen: no tour")
	await _close(hub)
	progress.tutorial_seen = progress.TUTORIAL_TRAINING
	progress.dev_tools = true
	hub = await _open()
	_check(hub.tour == null, "gate on, dev mode: no tour")
	await _close(hub)
	progress.dev_tools = false


# --- A full turn of the room, one line per station, ending at the archway
func _full_tour() -> void:
	await _due_save()
	var hub := await _open()
	var tour: Node = hub.tour
	_check(tour != null and hub.back_station().id == "story", "due: the tour is there, the archway at the back")
	_check(hub.near.get("id", "") == "rotor" and hub.slime.position == hub.rotor.position + TourScript.SPAWN_FROM_WHEEL,
		"...the slime starts next to the wheel")
	_check(hub.prompt_name.text == "HOME. IT TURNS, HIT THE WHEEL" and hub.prompt_key.text == "F" and hub.prompt.visible,
		"...the prompt box says HOME. IT TURNS, HIT THE WHEEL F")
	_check(tour.guided and tour.skip_pod == null and tour.arrow == null, "...guided (the first visit): no SKIP pod, no arrow yet")
	var heard: Array = []
	hub.room_turned.connect(func(id: String, _dir: int) -> void: heard.append(id))
	var expected := {
		maps = "MAPS OF EVERY LEVEL YOU SMEARED", upgrades = "COINS GO IN, STRONGER GOO COMES OUT",
		quit = "THE TRAPDOOR, FOR BEDTIME", coins = "THE PRACTICE COIN WAS FAKE. SORRY",
		random = "LOCKED: BEAT ALL %d LEVELS FIRST" % Levels.COUNT, settings = "SOUND, KEYS, FOG. THE BORING SIGN",
		wheel = "SPIN FOR PRIZES, THE FIRST IS FREE", wardrobe = "SKINS, HATS, TRAILS. DRY UP IN STYLE",
	}
	var widest := 0
	for i in range(1, hub.stations.size()):
		await _turn(hub)
		var id: String = hub.back_station().id
		var want: String = expected.get(id, "?")
		widest = maxi(widest, UIKit.text_w(want))
		var station: Dictionary = hub._station(id)
		var lit: bool = station.sprite.self_modulate == Color(1.25, 1.25, 1.25) \
			or (id == "random" and station.pool.modulate.a > HubScript.POOLS[id].a * 1.3)  # (the locked portal: its pool only)
		_check(heard.back() == id and hub.prompt_name.text == want and hub.prompt_key.text == "F" and lit and not tour.done,
			"turn %d: room_turned(%s); %s F; the station lit" % [i, id, hub.prompt_name.text])
		if i == 2:
			_check(not tour.hint_on, "...no turn-back hint yet")
			await _wait_seconds(TourScript.HINT_DELAY + 0.1)
			_check(tour.hint_on and hub.prompt_name.text == "HOLD A TO TURN IT BACK" and hub.prompt_key.text == "F",
				"after %.0f s at turn 2: %s F (once)" % [TourScript.HINT_DELAY, hub.prompt_name.text])
	_check(widest <= 192 and hub.prompt.size.x <= 320 - 2 * UIKit.EDGE, "every line fits its 192 px budget (widest %d px)" % widest)
	_check(not progress.has_seen_tutorial(progress.TUTORIAL_HUB), "...nothing saved before the end")
	await _turn(hub)
	_check(hub.back_station().id == "story" and tour.done and not tour.over and not progress.has_seen_tutorial(progress.TUTORIAL_HUB)
		and progress.hub_tour_due(), "a full turn ends at the archway: done, but not saved before the archway is used")
	_check(hub.prompt_name.text == "THE WAY UP, WALK IN" and hub.prompt_key.text == "", "...THE WAY UP, WALK IN (no key)")
	var story: Dictionary = hub._station("story")
	_check(tour.arrow != null and tour.arrow.position.distance_to(story.sprite.position) <= TourScript.ARROW_BELOW + TourScript.ARROW_BOB + 1.0,
		"...an arrow on the floor in front of the archway")
	_check(story.sprite.self_modulate == Color(1.25, 1.25, 1.25), "...the archway lit")
	await _wait_seconds(TourScript.HINT_DELAY + 0.5)
	_check(hub.prompt_name.text == "THE WAY UP, WALK IN", "...the last line stays")
	await _turn(hub)
	_check(not tour.over and hub.back_station().id == "story" and hub.prompt_name.text == "THE WAY UP, WALK IN",
		"the wheel again: the room holds still, the archway stays at the back")
	hub.slime.position = hub.rotor.position + Vector2(70, 20)
	await _physics_frames(3)
	_check(hub.near.is_empty() and hub.prompt.visible and hub.prompt_name.text == "THE WAY UP, WALK IN",
		"...away from everything the line still shows")
	hub.slime.position = hub._station("coins").sprite.position + Vector2(0, -14)
	await _physics_frames(3)
	_check(hub.near.get("id", "") == "coins" and hub.prompt_name.text == "THE WAY UP, WALK IN", "...by another station too")
	await _press("interact")
	_check(not hub.coin_board.visible and not tour.over and hub.prompt_name.text == "COIN BAG" and hub.prompt_key.text == "AFTER THE TOUR",
		"...which stays shut: COIN BAG AFTER THE TOUR")
	_check(not tour.back_pressed() and not tour.over, "Esc / B don't end it (Esc opens the hub menu)")
	_check(tour.blocks("maps") and not tour.blocks("story"), "only the archway is open")
	tour.station_used("story")  # (the archway's use; its level select isn't opened here)
	_check(tour.over and tour.arrow == null and progress.has_seen_tutorial(progress.TUTORIAL_HUB) and not progress.hub_tour_due()
		and _saved_bits() & progress.TUTORIAL_HUB != 0, "using the archway ends the tour: TUTORIAL_HUB saved, no longer due")
	await _close(hub)


# --- The guided tour can't be skipped: Esc opens the hub menu (the tour stays), B, a tap or a click top right do nothing
func _no_skips() -> void:
	for step in [0, 4, 8]:
		await _due_save()
		var hub := await _open()
		var tour: Node = hub.tour
		for i in step:
			await _turn(hub)
		await _press("ui_cancel")
		_check(not tour.over and not hub.hub_menu.visible, "guided, %d turns: B does nothing" % step)
		var corner := Vector2(320 - UIKit.HUD_EDGE - 10, UIKit.HUD_EDGE + 7)
		_send_touch(0, corner, true)
		await _physics_frames(2)
		_send_touch(0, corner, false)
		_send_click(corner, MOUSE_BUTTON_LEFT)
		await _physics_frames(2)
		_check(not tour.over, "...a tap or a click where the SKIP pod was: nothing")
		await _press("menu")
		_check(not tour.over and hub.hub_menu.visible and not progress.has_seen_tutorial(progress.TUTORIAL_HUB),
			"...Esc opens the hub menu; the tour stays, nothing saved")
		await _press("menu")
		_check(not hub.hub_menu.visible and not hub.slime.frozen and not tour.over, "...and Esc closes it again")
		await _close(hub)


# --- A SETTINGS replay's tour: skip at every step with Esc, B, a tap or a left click on the SKIP pod
func _skips() -> void:
	var ways := ["menu", "ui_cancel", "touch", "click"]
	for step in 9:
		await _due_save(true)
		var hub := await _open()
		var tour: Node = hub.tour
		for i in step:
			await _turn(hub)
		var how: String = ways[step % ways.size()]
		if how == "touch":
			var at: Vector2 = Rect2(tour.skip_pod.position, tour.skip_pod.size).get_center()
			_send_touch(0, at, true)
			await _physics_frames(2)
			_send_touch(0, at, false)
			await _physics_frames(2)
		elif how == "click":
			_send_click(Vector2(160, 90), MOUSE_BUTTON_LEFT)  # (off the pod: nothing)
			_send_click(tour.skip_rect().get_center(), MOUSE_BUTTON_RIGHT)  # (not the left button: nothing)
			await _physics_frames(2)
			_check(not tour.over, "a click off the SKIP pod, or a right click on it, doesn't skip")
			_send_click(Rect2(tour.skip_pod.position, tour.skip_pod.size).get_center(), MOUSE_BUTTON_LEFT)
			await _physics_frames(2)
		else:
			await _press(how)
		_check(tour.over and tour.skipped and not progress.tour_replay and not hub.slime.frozen and not tour._layer.visible
			and hub.prompt_name.text == "ROTATE" and _saved_bits() & progress.TUTORIAL_HUB == 0,
			"replay, skip after %d turns (%s): over, still in the hub, ROTATE again, nothing saved" % [step, how])
		_check(not hub.hub_menu.visible, "...the skipping press doesn't also open the hub menu (%s)" % how)
		if how == "menu":
			await _press("menu")
			_check(hub.hub_menu.visible and hub.menu_back.has_focus(), "...after the tour, Esc opens the hub menu (%s)" % how)
			await _press("menu")
			_check(not hub.hub_menu.visible and not hub.slime.frozen, "...and Esc closes it again")
		await _close(hub)


func _send_click(at: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = _to_window(at)
		event.global_position = _to_window(at)
		Input.parse_input_event(event)


# --- Guided: the stations wait for the tour; a replay: using a station ends the tour quietly
func _station_ends_it() -> void:
	for replay in [false, true]:
		await _due_save(replay)
		var hub := await _open()
		var tour: Node = hub.tour
		await _turn(hub)
		var bag: Dictionary = hub._station("coins")
		hub.slime.position = bag.sprite.position + Vector2(0, -14)
		await _physics_frames(3)
		_check(hub.near.get("id", "") == "coins" and hub.prompt_name.text == "COIN BAG", "away from the wheel: the station's own prompt (COIN BAG)")
		await _press("interact")
		if replay:
			_check(hub.coin_board.visible and tour.over and not tour.skipped and not progress.tour_replay,
				"replay: using a station (the coin bag) ends the tour quietly")
		else:
			_check(not hub.coin_board.visible and not tour.over and hub.prompt_key.text == "AFTER THE TOUR"
				and not progress.has_seen_tutorial(progress.TUTORIAL_HUB), "guided: the coin bag stays shut, AFTER THE TOUR")
			hub.slime.position = hub._station("story").sprite.position + Vector2(0, 16)
			await _physics_frames(3)
			await _press("interact")
			_check(hub.near.get("id", "") == "story" and not hub.slime.frozen and not tour.over and hub.prompt_key.text == "AFTER THE TOUR",
				"guided: the archway too, before the room has come round")
		await _close(hub)


# --- Pad and touch: the right glyphs (Platform seam)
func _devices() -> void:
	await _due_save(true)  # (a replay: its SKIP pod's key too)
	var hub := await _open()
	var tour: Node = hub.tour
	Platform.last_input = Platform.INPUT_PAD
	await _physics_frames(3)
	_check(hub.prompt_key.text == "X" and tour.skip_key.text == "B", "pad: the line's key is X, SKIP B")
	await _turn(hub)
	await _turn(hub)
	await _wait_seconds(TourScript.HINT_DELAY + 0.1)
	_check(hub.prompt_name.text == "HOLD LEFT TO TURN IT BACK", "pad: HOLD LEFT TO TURN IT BACK")
	Platform.last_input = Platform.INPUT_KEYS
	hub._touch_controls.visible = true
	await _physics_frames(3)
	_check(not hub.prompt_key.visible and not tour.skip_key.visible, "touch: no key after the line (the JUMP button is on screen); SKIP alone (tap it)")
	var rect: Rect2 = tour.skip_rect()
	_check(rect.size.x >= UIKit.TOUCH_MIN and rect.size.y >= UIKit.TOUCH_MIN, "touch: SKIP's tap area is at least %d px (%s)" % [UIKit.TOUCH_MIN, rect.size])
	hub._touch_controls.visible = false
	await _turn(hub, true)
	_check(hub.back_station().id == "maps" and hub.prompt_name.text == "MAPS OF EVERY LEVEL YOU SMEARED", "holding left turns back: the line follows (MAP TABLE)")
	await _close(hub)


# --- UI pass (docs/ui-rules.md, Tutorial UI): on every device, every line of the tour (each station, the
# turn-back hint, the end) keeps the prompt box centred, inside the screen, within the 192 px line budget and
# clear of the touch joystick / JUMP; the SKIP pod is a HUD pod mirroring the ticket pod (same top, height and
# edge) and on touch its tap area stays off the pause button.
func _layout() -> void:
	for device in ["keys", "pad", "touch"]:
		await _due_save()
		var hub := await _open()
		var tour: Node = hub.tour
		Platform.last_input = Platform.INPUT_PAD if device == "pad" else Platform.INPUT_KEYS
		hub._touch_controls.visible = device == "touch"
		await _physics_frames(3)
		var bad: Array[String] = []
		var widest := 0.0
		for step in hub.stations.size() + 1:
			if step == 2:
				await _wait_seconds(TourScript.HINT_DELAY + 0.1)
				bad.append_array(_prompt_faults(hub, device))
				widest = maxf(widest, hub.prompt_name.get_combined_minimum_size().x)
			bad.append_array(_prompt_faults(hub, device))
			widest = maxf(widest, hub.prompt_name.get_combined_minimum_size().x)
			if step < hub.stations.size():
				await _turn(hub)
		_check(tour.done and hub.prompt_name.text == "THE WAY UP, WALK IN", "%s: the walk ends on the last line" % device)
		_check(bad.is_empty(), "%s: every tour line's prompt box centred, on screen, clear of the touch controls (%s)" % [device, ", ".join(bad)])
		_check(widest <= 192.0, "%s: the widest tour line is within its 192 px budget (%d px)" % [device, widest])
		await _close(hub)
	await _due_save(true)  # (the SKIP pod: a replay's)
	var hub2 := await _open()
	var tour2: Node = hub2.tour
	for device in ["keys", "pad", "touch"]:
		Platform.last_input = Platform.INPUT_PAD if device == "pad" else Platform.INPUT_KEYS
		hub2._touch_controls.visible = device == "touch"
		await _physics_frames(3)
		var skip := Rect2(tour2.skip_pod.position, tour2.skip_pod.size)
		var ticket := Rect2(hub2.ticket_pod.position, hub2.ticket_pod.size)
		_check(skip.position.y == ticket.position.y and skip.size.y == ticket.size.y and skip.size.y == UIKit.pod_h()
			and 320.0 - skip.end.x == ticket.position.x and skip.position.x == roundf(skip.position.x),
			"%s: the SKIP pod mirrors the ticket pod (SKIP %s, ticket %s)" % [device, skip, ticket])
		_check(not skip.intersects(ticket), "%s: SKIP and the ticket pod apart" % device)
		if device == "touch":
			_check(not tour2.skip_rect().intersects(hub2._touch_controls.pause_rect),
				"touch: SKIP's tap area (%s) off the pause button (%s)" % [tour2.skip_rect(), hub2._touch_controls.pause_rect])
	hub2._touch_controls.visible = false
	Platform.last_input = Platform.INPUT_KEYS
	await _close(hub2)


## What's wrong with the prompt box as it stands ([] = nothing).
func _prompt_faults(hub: Node2D, device: String) -> Array[String]:
	var out: Array[String] = []
	var text: String = hub.prompt_name.text
	if not hub.prompt.visible:
		return ["%s hidden" % text]
	var box := Rect2(hub.prompt.position, hub.prompt.size)
	if absf(box.position.x - (320.0 - box.end.x)) > 1.0 or box.position.x != roundf(box.position.x):
		out.append("%s off centre (%s)" % [text, box])
	if box.position.x < UIKit.EDGE or box.end.x > 320 - UIKit.EDGE or box.end.y > 180:
		out.append("%s off screen (%s)" % [text, box])
	if device == "touch":
		var touch: Node = hub._touch_controls
		for circle in [[touch.JOY_HOME, touch.JOY_RADIUS], [touch.JUMP_CENTER, touch.JUMP_RADIUS]]:
			var nearest := Vector2(clampf(circle[0].x, box.position.x, box.end.x), clampf(circle[0].y, box.position.y, box.end.y))
			if nearest.distance_to(circle[0]) < circle[1] + UIKit.GAP_XS:
				out.append("%s on a touch control (%s)" % [text, box])
	return out


# --- The web's 8 stations (no trapdoor); a SETTINGS replay writes nothing
func _web_and_replay() -> void:
	await _due_save()
	Platform.override = "web"
	var hub := await _open()
	var tour: Node = hub.tour
	var ids: Array = []
	for i in hub.stations.size():
		await _turn(hub)
		ids.append(hub.back_station().id)
	_check(hub.stations.size() == 8 and not "quit" in ids and tour.done and ids.back() == "story",
		"web (no trapdoor): 8 turns end at the archway (%s)" % ", ".join(ids))
	await _close(hub)
	Platform.override = ""

	progress.tutorial_seen = progress.TUTORIAL_TRAINING | progress.TUTORIAL_HUB
	progress.save_progress()
	progress.tour_replay = true
	progress.training_skipped = true
	progress.training_coin = false
	hub = await _open()
	_check(hub.tour != null and hub.prompt_name.text == "HOME. IT TURNS, HIT THE WHEEL", "a SETTINGS replay: the tour again")
	for i in 4:
		await _turn(hub)
	_check(hub.prompt_name.text == "COINS STILL HIDING IN EACH LEVEL", "...no practice coin picked up: the coin bag's plain line")
	var before := FileAccess.get_file_as_string(test_save)
	await _press("menu")
	_check(hub.tour.over and not progress.tour_replay and FileAccess.get_file_as_string(test_save) == before,
		"...skipped: nothing written")
	await _close(hub)


# --- The autopilot: read each line, turn, then walk into the archway
func _timing() -> void:
	await _due_save()
	var hub := await _open()
	var tour: Node = hub.tour
	var start := Time.get_ticks_msec()
	var frames := 0
	while not tour.done:
		await _wait_seconds(READ_TIME)
		frames += int(READ_TIME * 60)
		var before := Engine.get_physics_frames()
		await _turn(hub)
		frames += Engine.get_physics_frames() - before
		if frames > 60 * 120:
			break
	await _wait_seconds(READ_TIME)  # (THE WAY UP, WALK IN)
	frames += int(READ_TIME * 60)
	var walk_from := Engine.get_physics_frames()
	await _walk(hub, [hub.rotor.position + Vector2(-22, 8), hub.rotor.position + Vector2(-22, -40), hub._station("story").sprite.position + Vector2(0, 16)])
	var reached: bool = hub.near.get("id", "") == "story"
	frames += Engine.get_physics_frames() - walk_from
	var seconds := frames / 60.0
	print("hub tour: %.1f s (reading %.1f s a line, %d stations, the walk to the archway %.1f s; %d ms real)" % [seconds, READ_TIME,
		hub.stations.size(), (Engine.get_physics_frames() - walk_from) / 60.0, Time.get_ticks_msec() - start])
	_check(tour.done and reached and hub.prompt_name.text.begins_with("STORY - LEVEL 1"), "the autopilot ends at the archway: STORY - LEVEL 1")
	_check(seconds >= 35.0 and seconds <= 50.0, "the tour takes %.1f s (target 35-50 s, upper bound 50)" % seconds)
	await _close(hub)


## Glides the slime through `points` (like a player with the arrow keys) until a station is in reach of
## the last one's or 10 s pass.
func _walk(hub: Node2D, points: Array) -> void:
	var dirs := {move_left = Vector2.LEFT, move_right = Vector2.RIGHT, move_up = Vector2.UP, move_down = Vector2.DOWN}
	for i in 600:
		if hub.near.get("id", "") == "story" or points.is_empty():
			break
		var to: Vector2 = points[0] - hub.slime.position
		if to.length() < 4.0:
			points.pop_front()
			continue
		for action: String in dirs:
			var along: float = to.dot(dirs[action])
			if along > 2.0:
				Input.action_press(action)
			else:
				Input.action_release(action)
		await physics_frame
	for action: String in dirs:
		Input.action_release(action)
	await _physics_frames(2)


func _saved_bits() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(test_save) != OK:
		return 0
	for section in cfg.get_sections():
		if cfg.has_section_key(section, "tutorial_seen"):
			return int(cfg.get_value(section, "tutorial_seen"))
	return 0
