extends SceneTree

## Navigation / Esc / menu fuzzer. Boots the real scenes (title, hub, map table + map view, level select,
## upgrades, skins + hats page, settings, controls, save-code panel, reset confirm, quit hatch, hat wheel,
## pause menu in a story level and in a randomizer maze with the seed box, restart prompt, dry-up and win
## choices, story intro, victory) and sends REAL input events (Escape / P / Enter / Space / arrows / WASD / F / R /
## Tab, joypad B and A, mouse clicks and touches at the buttons' rects, rapid double presses, holds, presses during
## the goo wipe and on the exact frame a scene changes), asserting after each action:
##   one overlay owns input, the tree is paused only behind a pause overlay, a visible control has focus in every
##   menu (and stays inside the open modal), no engine/script errors, Engine.time_scale is 1, no input action
##   stays held, a way back exists (Esc ladder) and node counts do not grow over 50 enter/exit cycles.
## Then deterministic random walks (fixed seeds) from several start states; the first violation of a walk is
## printed with a replayable trace. Known open bugs (docs/qa-nav-report.md) are listed in KNOWN and only reported.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_nav_fuzz.gd
## Extra: `-- --nav-steps=N` (steps per walk), `-- --nav-seed=N`, `-- --nav-strict` (known bugs fail too),
##        `-- --nav-only=walks|scripted`, `-- --nav-variant=web|touch`,
##        `-- --nav-area-steps=N` (steps per area walk, default 2000; 0 skips them).
## Area walks: six more walks that start inside one area and keep steering back into it (`_area_op`,
## about a third of the inputs): the map table + map view, the SETTINGS panels, the pause menu, the
## dry-up choices, the win choices and a touch-driven level (2,000 inputs each by default).

const Lib := preload("res://tests/nav_fuzz_lib.gd")

## Open bugs found by this fuzzer (see docs/qa-nav-report.md): reported, not failed, until fixed.
const KNOWN := {
}

var L
var failures := 0
var found := {}  # tag -> first label
var walk_steps := 1200
var base_seed := 1234
var strict := false
var only := ""
var variant := ""
var only_walk := -1
var done := false
var rng := RandomNumberGenerator.new()
var current_walk := ""
## The area the current walk keeps steering back into ("" = a plain walk). See AREAS.
var area := ""
var area_steps := 2000
## Area walks: [area, state, start scene].
const AREAS := [["maps", "complete", "res://scenes/maps.tscn"], ["settings", "complete", "res://scenes/controls.tscn"],
	["pause", "complete", "res://scenes/main.tscn"], ["dry", "complete", "res://scenes/main.tscn"],
	["win", "complete", "res://scenes/main.tscn"], ["touch", "touch", "res://scenes/main.tscn"]]


func _initialize() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nav-steps="):
			walk_steps = int(arg.get_slice("=", 1))
		elif arg.begins_with("--nav-seed="):
			base_seed = int(arg.get_slice("=", 1))
		elif arg == "--nav-strict":
			strict = true
		elif arg.begins_with("--nav-only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--nav-walk="):
			only_walk = int(arg.get_slice("=", 1))
		elif arg.begins_with("--nav-area-steps="):
			area_steps = int(arg.get_slice("=", 1))
		elif arg.begins_with("--nav-variant="):
			variant = arg.get_slice("=", 1)
	L = Lib.new(self)
	var real: String = L.progress.REAL_SAVE_PATH
	print("real save untouched check: save_path=%s" % L.progress.save_path)
	var t0 := Time.get_ticks_msec()
	if only != "walks":
		await _scripted()
	if only != "scripted":
		await _walks()
	print("elapsed %.1fs  engine errors: %d" % [(Time.get_ticks_msec() - t0) / 1000.0, L.errlog.count])
	var unknown := 0
	for tag: String in found:
		var known := KNOWN.has(tag)
		print("  %s %-14s %s" % ["KNOWN " if known else "NEW   ", tag, found[tag]])
		if not known or strict:
			unknown += 1
	done = true
	var ok := failures == 0 and unknown == 0
	print("RESULT: %s" % ("PASS" if ok else "FAIL (%d failed checks, %d new/strict bug tags)" % [failures, unknown]))
	quit(0 if ok else 1)


func _finalize() -> void:
	if not done:
		print("UNEXPECTED QUIT: the game quit during the fuzz. Last inputs:")
		for line in L.trace.slice(maxi(0, L.trace.size() - 15)):
			print("   " + line)


# ------------------------------------------------------------------ reporting

## Records a bug under `tag` (first label wins). Known tags are reported but pass.
func bug(tag: String, label: String) -> void:
	if not found.has(tag):
		found[tag] = label
		print("  BUG  %-12s %s%s" % [tag, label, "" if current_walk == "" else "   (in " + current_walk + ")"])


func check(ok: bool, tag: String, label: String) -> void:
	if ok:
		print("  ok   " + label)
	else:
		bug(tag, label)
		if not KNOWN.has(tag):
			failures += 1


## Checks the invariants, filing each violation under its own tag. Returns the violations.
func inv(where: String, strict_focus := true) -> Array[String]:
	var v: Array[String] = L.invariants(strict_focus)
	for line in v:
		var tag := _tag_of(line, where)
		bug(tag, "%s: %s" % [where, line])
		if not KNOWN.has(tag):
			failures += 1
	return v


func _tag_of(line: String, where: String) -> String:
	var head := line.get_slice(":", 0)
	if head == "STUCK" and "menu" in line:
		return "TOUCH-MENU-STUCK"
	if head == "HUBFROZEN":
		return "HUB-FROZEN"
	if head == "OVERLAY" and L.kind() == "controls":
		return "SETTINGS-TAB"
	if head == "ERR" and ("outside the active scene tree" in line or "get_nodes_in_group" in line or "data.tree" in line):
		return "RACE-RELOAD"
	if head == "FOCUS" and L.kind() == "maps":
		return "MAPS-TAB"
	if head == "FOCUS" and L.kind() == "upgrades":
		return "UPG-FOCUS"
	if head == "FOCUS" and L.kind() == "controls":
		return "SETTINGS-TAB"
	if head == "FOCUS" and L.kind() == "main":
		return "PAUSE-FOCUS"
	return head + "-" + L.kind()


# ------------------------------------------------------------------ helpers

func hub_to(id: String) -> bool:
	var hub: Node2D = current_scene
	var st: Dictionary = hub._station(id)
	if st.is_empty():  # e.g. the trapdoor does not exist with --web-ui
		return false
	var at: Vector2 = st.sprite.position + (Vector2.ZERO if st.flat else Vector2(0, -2))
	var radius: float = hub._footprint(st)
	for a in 8:
		var dir := Vector2.from_angle(a * PI / 4.0)
		var edge := 1.0 / sqrt(pow(dir.x / radius, 2.0) + pow(dir.y / (radius * 0.5), 2.0))
		var spot := at + dir * (edge + Slime.RADIUS + 3.0)
		if not hub._on_floor(spot):
			continue
		hub.slime.position = spot
		hub.slime.velocity = Vector2.ZERO
		hub.near = {}
		hub._update_near()
		if hub.near.get("id", "") == id:
			return true
	return false


func esc() -> void:
	await L.tap(KEY_ESCAPE)


func goto_hub() -> Node2D:
	L.set_state("complete")
	return await _fresh_scene(L.HUB)


func _fresh_scene(path: String) -> Node:
	return await L.load_scene(path, 10)


func button_with(root: Node, text: String) -> Button:
	for b in L.clickables():
		if b is Button and (b as Button).text == text:
			return b
	return null


# ------------------------------------------------------------------ scripted scenarios

func _scripted() -> void:
	print("-- scripted: title / hub")
	L.set_state("complete")
	await _fresh_scene(L.TITLE)
	inv("title boot")
	for i in 5:
		await esc()
	await L.frames(30)
	check(L.kind() == "title", "TITLE-ESC", "Esc x5 on the title stays on the title (no quit, no navigation)")
	await L.tap(KEY_P)
	await L.frames(5)
	check(L.kind() == "title", "TITLE-ESC", "P on the title does nothing")
	await L.tap(KEY_ENTER)
	await L.tap(KEY_ENTER)  # second press during the wipe
	await L.settle()
	check(L.kind() == "hub", "TITLE-ENTER", "Enter (x2, second during the wipe) enters the hub once")
	inv("hub after title")

	print("-- hub: Esc, quit hatch, coin board")
	var hub: Node2D = current_scene
	await esc()
	await L.settle()
	check(L.kind() == "title", "HUB-ESC", "Esc in the hub goes to the title")
	await L.tap(KEY_ENTER)
	await L.settle()
	hub = current_scene
	check(hub_to("quit"), "HUB-TP", "slime can reach the trapdoor")
	await L.tap(KEY_F)
	await L.frames(3)
	check(hub.quit_menu.visible and L.focus() == hub.back_button, "HUB-QUIT", "F at the trapdoor opens the confirm with BACK focused")
	inv("quit menu")
	await esc()
	await L.frames(3)
	check(not hub.quit_menu.visible and L.kind() == "hub", "HUB-QUIT", "Esc closes the quit confirm (stays in the hub)")
	await L.tap(KEY_F)
	await L.frames(2)
	await L.tap(KEY_P)
	await L.frames(3)
	check(not hub.quit_menu.visible and L.kind() == "hub", "HUB-QUIT", "P closes the quit confirm")
	await L.tap(KEY_F)
	await L.frames(2)
	await L.action_both_same_frame()
	await L.frames(3)
	inv("quit menu double esc")
	check(L.kind() == "hub" or transition_busy(), "HUB-QUIT", "Esc+P in one frame with the confirm open never quits the app")
	await L.settle()
	hub = current_scene
	if L.kind() == "title":
		await L.tap(KEY_ENTER)
		await L.settle()
		hub = current_scene
	# coin board: opens, Esc closes, F closes
	check(hub_to("coins"), "HUB-TP", "slime can reach the coin bag")
	await L.tap(KEY_F)
	await L.frames(3)
	check(hub.coin_board.visible, "HUB-COINS", "F at the coin bag opens the board")
	await esc()
	await L.frames(3)
	check(not hub.coin_board.visible and L.kind() == "hub", "HUB-COINS", "Esc closes the coin board without leaving the hub")
	inv("coin board closed")

	print("-- hub: map table cannot be opened under another overlay")
	for overlay in ["quit", "coins"]:
		check(hub_to(overlay), "HUB-TP", "slime reaches %s" % overlay)
		await L.tap(KEY_F)
		await L.frames(3)
		var opened: bool = hub.quit_menu.visible if overlay == "quit" else hub.coin_board.visible
		check(opened, "HUB-OVER", "%s overlay opened" % overlay)
		hub_to("maps")  # teleport beside the map table behind the overlay
		await L.tap(KEY_F)
		await L.frames(20)
		check(L.kind() == "hub" and not transition_busy(), "HUB-OVER", "F at the map table under the %s overlay does not leave the hub" % overlay)
		inv("hub under %s overlay" % overlay)
		if not overlay_closed(hub):
			await esc()
			await L.frames(3)
		check(L.kind() == "hub" and overlay_closed(hub), "HUB-OVER", "the %s overlay closes without leaving the hub" % overlay)
	print("-- hub -> map table, immediately back and in again")
	check(hub_to("maps"), "HUB-TP", "slime can reach the map table")
	hub.turn_room(1)  # rotating while pressing: turning blocks use until it ends
	await L.tap(KEY_F)
	await L.frames(2)
	check(L.kind() == "hub" and not transition_busy(), "MAPS-TURN", "F while the hub is rotating does not open the map table")
	await L.frames(60)
	check(hub_to("maps"), "HUB-TP", "map table reachable after the turn")
	await L.tap(KEY_F)
	await L.settle()
	check(L.kind() == "maps", "MAPS-OPEN", "F at the map table opens the map select")
	var ms: Control = current_scene
	inv("map select")
	check(L.focus() is Button and not (L.focus() as Button).disabled, "MAPS-FOCUS", "a map tile has focus on opening")
	# Enter opens the view; Esc closes it; Esc leaves
	await L.tap(KEY_ENTER)
	await L.frames(3)
	check(ms.viewing, "MAPS-VIEW", "Enter on a tile opens its map")
	inv("map view")
	await esc()
	await L.frames(3)
	check(not ms.viewing and L.kind() == "maps", "MAPS-VIEW", "Esc closes the map view back to the select")
	await esc()
	await L.settle()
	check(L.kind() == "hub", "MAPS-ESC", "Esc in the select returns to the hub")
	check(current_scene.near.get("id", "") == "maps", "MAPS-RETURN", "the hub faces the map table on return")
	# re-enter immediately (no settle beyond the first frames)
	await L.tap(KEY_F)
	await L.settle()
	check(L.kind() == "maps", "MAPS-REENTER", "F right after returning enters the map table again")
	# double Esc in one frame from the view
	ms = current_scene
	await L.tap(KEY_ENTER)
	await L.frames(2)
	check(ms.viewing, "MAPS-VIEW", "view opens again")
	await L.action_both_same_frame()  # Esc + ui_cancel in one frame = ONE press of the same key twice
	await L.frames(3)
	check(L.kind() == "maps" or transition_busy(), "MAPS-DBL", "")
	await L.settle()
	print("   after Esc+ui_cancel in one frame from the view: kind=%s viewing=%s" % [L.kind(), ms.viewing if is_instance_valid(ms) and L.kind() == "maps" else "-"])
	# Esc x3 spaced: view -> select -> hub -> (hub) title
	await _maps_view_ladder()

	print("-- map view: Tab / arrows / holding Enter")
	await _maps_view_focus()

	print("-- map select: HARD, clicks, touch, locked tiles")
	await _maps_input()

	print("-- exact frame of a scene change")
	await _frame_of_change()

	print("-- other screens: Esc and focus")
	await _other_screens()

	print("-- game: pause / restart prompt / dry-up / win / seed box")
	await _game()

	print("-- story intro / victory")
	await _story()

	print("-- leaks: 50 hub <-> map table cycles")
	await _leaks()

	print("-- touch / web-ui / resize variants")
	await _variants()


func overlay_closed(hub: Node2D) -> bool:
	return not hub.quit_menu.visible and not hub.coin_board.visible and not hub.hat_wheel.visible


func transition_busy() -> bool:
	return L.transition.busy


func _maps_view_ladder() -> void:
	L.set_state("complete")
	await _fresh_scene(L.MAPS)
	var ms: Control = current_scene
	await L.tap(KEY_ENTER)
	await L.frames(2)
	for i in 6:
		await esc()
		await L.frames(2)
		inv("maps ladder %d" % i)
	await L.settle()
	check(L.kind() == "hub" or L.kind() == "title", "MAPS-LADDER", "Esc x6 from the map view lands on hub/title (got %s)" % L.kind())
	check(true, "", "")


func _maps_view_focus() -> void:
	L.set_state("complete")
	await _fresh_scene(L.MAPS)
	var ms: Control = current_scene
	await L.tap(KEY_ENTER)
	await L.frames(3)
	var ok := true
	for k in [KEY_TAB, KEY_DOWN, KEY_UP, KEY_LEFT, KEY_RIGHT, KEY_S, KEY_D]:
		await L.tap(k)
		await L.frames(2)
		var f: Control = L.focus()
		if f != null and not (f == ms.view_root or ms.view_root.is_ancestor_of(f)):
			ok = false
			bug("MAPS-TAB", "focus left the open map view with %s -> '%s'" % [OS.get_keycode_string(k), f.name])
			break
	check(ok, "MAPS-TAB", "keyboard focus stays on BACK while a map is viewed")
	# shift+tab / ui_focus_prev too
	L.action("ui_focus_next", true)
	await L.frames(1)
	L.action("ui_focus_next", false)
	await L.frames(2)
	var f2: Control = L.focus()
	check(f2 == null or ms.view_root.is_ancestor_of(f2) or f2 == ms.view_back, "MAPS-TAB", "ui_focus_next stays inside the map view")
	# what Tab then Enter/Space actually do under the open view
	for follow in [KEY_ENTER, KEY_SPACE]:
		L.set_state("complete")
		await _fresh_scene(L.MAPS)
		ms = current_scene
		await L.tap(KEY_ENTER)  # opens level 1's view
		await L.frames(3)
		var lvl: int = ms.viewed_level
		var hard_before: bool = ms.hard
		for t in 4:
			await L.tap(KEY_TAB)
			await L.frames(2)
		await L.tap(follow)
		await L.frames(3)
		# Focus stayed on the view's BACK, so Enter / Space just close the view (back on the same tile).
		var on_tile: bool = L.focus() is Button and L.focus().has_meta("level") and L.focus().get_meta("level") == lvl
		check(ms.viewed_level == lvl and ms.hard == hard_before and L.kind() == "maps" and (ms.viewing or on_tile), "MAPS-TAB",
			"Tab x4 then %s in the map view changes nothing under it (level %d -> %d, hard %s -> %s, closed back onto its tile: %s)" % [OS.get_keycode_string(follow), lvl, ms.viewed_level, hard_before, ms.hard, on_tile])
	# hold Enter: echoes must not close/reopen
	L.set_state("complete")
	await _fresh_scene(L.MAPS)
	ms = current_scene
	await L.tap(KEY_ENTER)
	await L.frames(3)
	await esc()
	await L.frames(3)
	L.key(KEY_ENTER, true)
	await L.frames(2)
	for i in 8:
		L.key(KEY_ENTER, true, true)
		await L.frames(1)
	L.key(KEY_ENTER, false)
	await L.frames(3)
	check(ms.viewing, "MAPS-HOLD", "holding Enter on a tile leaves its map open (echoes do not press BACK)")


func _maps_input() -> void:
	L.set_state("complete")
	await _fresh_scene(L.MAPS)
	var ms: Control = current_scene
	# touch the first tile, then BACK in the view
	var tile: Button = ms.tiles[0]
	await L.touch(tile.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(ms.viewing and ms.viewed_level == 1, "MAPS-TOUCH", "touching a tile opens its map")
	# tap where another tile is under the opaque view: nothing happens
	var other: Button = ms.tiles[5]
	var before: int = ms.viewed_level
	await L.click(other.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(ms.viewing and ms.viewed_level == before, "MAPS-CLICKTHRU", "clicking where a tile lies under the open view does nothing")
	await L.touch(ms.view_back.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(not ms.viewing, "MAPS-TOUCH", "touching BACK in the view closes it")
	inv("maps after touch")
	# HARD toggle
	var hard: CheckBox = ms.hard_box
	await L.click(hard.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(ms.hard and ms.tiles.size() == 10, "MAPS-HARD", "HARD checkbox switches the maps shown")
	inv("maps after HARD click")
	# keyboard: focus the checkbox & toggle with space and rebuild
	hard.grab_focus()
	await L.tap(KEY_SPACE)
	await L.frames(3)
	check(not ms.hard, "MAPS-HARD", "Space toggles HARD off")
	inv("maps after HARD space")
	# a locked level (mid state): click does nothing, Esc still leaves
	L.set_state("mid")
	await _fresh_scene(L.MAPS)
	ms = current_scene
	var locked_tile: Button = ms.tiles[7]
	check(locked_tile.disabled, "MAPS-LOCK", "mid state: a not-yet-surveyed tile is locked")
	await L.click(locked_tile.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(not ms.viewing, "MAPS-LOCK", "clicking a locked tile opens nothing")
	inv("maps mid")
	L.set_state("fresh")
	await _fresh_scene(L.MAPS)
	ms = current_scene
	var any_enabled := false
	for t: Button in ms.tiles:
		any_enabled = any_enabled or not t.disabled
	check(not any_enabled, "MAPS-LOCK", "fresh save: every tile locked")
	inv("maps fresh (all locked)")
	await esc()
	await L.settle()
	check(L.kind() == "hub", "MAPS-ESC", "Esc from an all-locked map select still returns to the hub")


func _frame_of_change() -> void:
	# For each leave-by-Esc screen: press Esc, then on the exact frame the next scene is current press
	# something else (Esc, Enter, F, R, Space) and check nothing breaks and we end somewhere sane.
	var screens := {"maps": L.MAPS, "level_select": L.LEVELS, "upgrades": L.UPGRADES, "skins": L.SKINS, "controls": L.SETTINGS, "key_controls": L.KEYS}
	for name: String in screens:
		for follow in [KEY_ESCAPE, KEY_ENTER, KEY_F, KEY_R, KEY_SPACE]:
			L.set_state("complete")
			await _fresh_scene(screens[name])
			var from: Node = current_scene
			await L.tap(KEY_ESCAPE)
			var guard := 0
			while current_scene == from and guard < 80:
				await L.frames(1)
				guard += 1
			# this is the first frame of the new scene
			await L.tap(follow)
			await L.settle(240)
			await L.frames(10)
			var v := inv("%s -> Esc -> %s on the exact frame the scene changes" % [name, OS.get_keycode_string(follow)])
			if not (L.kind() in ["hub", "title", "controls"]):
				bug("FRAMECHG", "%s: Esc then %s on the swap frame ended in %s" % [name, OS.get_keycode_string(follow), L.kind()])
				failures += 1
	print("   frame-of-change sweep done")


func _other_screens() -> void:
	# Esc in each screen reaches the hub (settings sub-pages one level up).
	for entry in [["level_select", L.LEVELS], ["upgrades", L.UPGRADES], ["skins", L.SKINS], ["controls", L.SETTINGS]]:
		L.set_state("complete")
		await _fresh_scene(entry[1])
		inv(entry[0] + " open")
		await esc()
		await L.settle()
		check(L.kind() == "hub", "ESC-" + entry[0], "Esc in %s returns to the hub (got %s)" % [entry[0], L.kind()])
	# key controls -> settings
	L.set_state("complete")
	await _fresh_scene(L.KEYS)
	var kc: Control = current_scene
	await L.tap(KEY_ENTER)  # focused row: start rebinding
	await L.frames(2)
	check(kc.waiting_for != "", "KEYS-REBIND", "Enter on a key row starts a rebind")
	await esc()
	await L.frames(3)
	check(kc.waiting_for == "" and L.kind() == "key_controls", "KEYS-REBIND", "Esc while rebinding cancels without leaving")
	inv("keys after cancel")
	await esc()
	await L.settle()
	check(L.kind() == "controls", "KEYS-ESC", "Esc on the key page returns to settings")
	# rebind to odd keys (Enter, Tab, Space, a letter) and verify menus still work
	L.set_state("complete")
	await _fresh_scene(L.KEYS)
	kc = current_scene
	for odd in [KEY_TAB, KEY_ENTER, KEY_SPACE, KEY_F, KEY_BACKSPACE, KEY_F1, KEY_F11]:
		kc._start_rebind("interact")
		await L.tap(odd)
		await L.frames(2)
		inv("keys rebind %s" % OS.get_keycode_string(odd))
	L.progress.reset_bindings()
	# settings: save code panel, reset confirm
	L.set_state("complete")
	await _fresh_scene(L.SETTINGS)
	var st: Control = current_scene
	st.save_code_button.pressed.emit()
	await L.frames(3)
	check(st.code_panel.visible, "SET-CODE", "SAVE CODE opens its panel")
	inv("code panel")
	for k in [KEY_TAB, KEY_DOWN, KEY_UP, KEY_RIGHT, KEY_LEFT]:
		await L.tap(k)
		await L.frames(2)
		var f: Control = L.focus()
		if f != null and not st.code_panel.is_ancestor_of(f):
			bug("SETTINGS-TAB", "focus escaped the SAVE CODE panel with %s -> '%s'" % [OS.get_keycode_string(k), f.name if f.name else ""])
			break
	await esc()
	await L.frames(3)
	if st.code_panel.visible and L.focus() is LineEdit:
		print("   note: Esc with a SAVE CODE text box focused only stopped editing (accepted design); a second Esc closes")
		inv("after first esc in a SAVE CODE box")
		await esc()
		await L.frames(3)
	check(not st.code_panel.visible and L.kind() == "controls", "SET-CODE", "Esc closes the save code panel only")
	await esc()
	await L.settle()
	check(L.kind() == "hub", "SET-ESC", "second Esc leaves settings")
	# typing "p" and Esc inside the paste box
	L.set_state("complete")
	await _fresh_scene(L.SETTINGS)
	st = current_scene
	st.save_code_button.pressed.emit()
	await L.frames(3)
	st.code_in.grab_focus()
	await L.tap(KEY_P)
	await L.frames(2)
	check(L.kind() == "controls" and st.code_in.text.to_lower() == "p", "SET-TYPE", "typing P into the paste box types, does not pause/leave (text='%s')" % st.code_in.text)
	await esc()
	await L.frames(3)
	if st.code_panel.visible:
		print("   note: first Esc inside the paste box only stopped editing (accepted design; focus now %s)" % L.focus())
		inv("after first esc in paste box (a control must still have focus)")
		await esc()
		await L.frames(3)
	check(L.kind() == "controls" and not st.code_panel.visible, "SET-TYPE", "Esc closes the panel after at most two presses")
	inv("after esc in paste box")
	# reset confirm
	st.reset_button.pressed.emit()
	await L.frames(3)
	check(st.reset_confirm.visible and L.focus() == st.cancel_button, "SET-RESET", "RESET PROGRESS asks first with CANCEL focused")
	for k in [KEY_TAB, KEY_DOWN, KEY_RIGHT]:
		await L.tap(k)
		await L.frames(2)
		var f: Control = L.focus()
		if f != null and not st.reset_confirm.is_ancestor_of(f):
			bug("SETTINGS-TAB", "focus escaped the RESET confirm with %s -> '%s'" % [OS.get_keycode_string(k), f.name])
			break
	st.cancel_button.grab_focus()
	await esc()
	await L.frames(3)
	check(not st.reset_confirm.visible and L.kind() == "controls", "SET-RESET", "Esc cancels the reset confirm (stays in settings)")
	# skins hats page
	L.set_state("dev")
	await _fresh_scene(L.SKINS)
	var sk: Control = current_scene
	sk.show_page("hats")
	await L.frames(3)
	inv("hats page")
	await esc()
	await L.settle()
	check(L.kind() == "hub", "SKINS-HATS-ESC", "Esc on the hats page returns to the hub")
	# hat wheel in the hub
	L.set_state("dev")
	var hub: Node2D = await _fresh_scene(L.HUB)
	check(hub_to("wheel"), "HUB-TP", "slime reaches the prize wheel")
	await L.tap(KEY_F)
	await L.frames(3)
	check(hub.hat_wheel.visible, "WHEEL-OPEN", "F at the prize wheel opens the hat wheel (dev)")
	inv("hat wheel open")
	await esc()
	await L.frames(3)
	check(not hub.hat_wheel.visible and L.kind() == "hub", "WHEEL-ESC", "Esc closes the hat wheel")
	await L.tap(KEY_F)
	await L.frames(2)
	await L.tap(KEY_F)  # spin
	await L.frames(2)
	var spun: bool = hub.hat_wheel.spinning
	await esc()  # ignored while spinning
	await L.frames(3)
	print("   wheel spinning=%s; Esc while spinning keeps it open: %s" % [spun, hub.hat_wheel.visible])
	for i in 600:
		if not hub.hat_wheel.spinning:
			break
		await L.frames(1)
	await esc()
	await L.frames(3)
	check(not hub.hat_wheel.visible and L.kind() == "hub", "WHEEL-ESC", "Esc closes the wheel after the spin ends")
	inv("wheel closed")
	# Esc in a hub whose wheel is opened -> the opening F must not also spin
	hub_to("wheel")


func _game() -> void:
	# --- story level pause
	L.set_state("complete")
	L.progress.start_story(2)
	var game: Node2D = await _fresh_scene(L.GAME)
	await L.frames(30)
	inv("level 2 running")
	await esc()
	await L.frames(3)
	check(game.pause_menu.visible and paused and L.focus() == game.pause_menu.buttons[0], "GAME-PAUSE", "Esc pauses with RESUME focused")
	inv("paused")
	await esc()
	await L.frames(3)
	check(not game.pause_menu.visible and not paused, "GAME-PAUSE", "Esc again resumes")
	await L.tap(KEY_P)
	await L.frames(3)
	check(game.pause_menu.visible and paused, "GAME-PAUSE", "P pauses too")
	await L.tap(KEY_R)  # paused: R must not open the restart prompt over the pause menu
	await L.frames(3)
	check(game.pause_menu.visible and not game.restart_prompt.visible, "GAME-R-PAUSED", "R while paused opens no second overlay")
	inv("paused + R")
	await L.tap(KEY_P)
	await L.frames(3)
	# Esc+ui_cancel in one frame: opens then closes (net zero)
	await L.action_both_same_frame()
	await L.frames(3)
	inv("same-frame double Esc")
	print("   same-frame double Esc in a level: pause visible=%s paused=%s" % [game.pause_menu.visible, paused])
	if game.pause_menu.visible:
		await esc()
		await L.frames(3)
	# restart prompt (coins in hand)
	await L.tap(KEY_R)
	await L.frames(3)
	check(game.restart_prompt.visible and paused, "GAME-RPROMPT", "R with coins in hand opens the restart prompt")
	inv("restart prompt")
	await esc()
	await L.frames(3)
	check(not game.restart_prompt.visible and not paused, "GAME-RPROMPT", "Esc cancels the restart prompt")
	await L.tap(KEY_R)
	await L.frames(2)
	await L.tap(KEY_R)
	await L.frames(3)
	check(not game.restart_prompt.visible and not paused, "GAME-RPROMPT", "R twice opens then closes the prompt")
	# R then Esc then Esc: prompt closes; second Esc pauses
	await L.tap(KEY_R)
	await L.frames(2)
	await esc()
	await L.frames(2)
	await esc()
	await L.frames(2)
	check(game.pause_menu.visible and not game.restart_prompt.visible, "GAME-RPROMPT", "R, Esc, Esc = prompt closed then pause open (one overlay)")
	inv("R esc esc")
	await esc()
	await L.frames(3)

	# --- same-frame double R (two reloads in one frame)
	game.restart_prompt.close()
	var before_errors: int = L.errlog.count
	L.key(KEY_R, true)
	L.key(KEY_R, false)
	L.key(KEY_R, true)
	L.key(KEY_R, false)
	await L.frames(10)
	inv("double R same frame")
	await L.settle()

	# --- QUIT TO HUB from the pause menu; keys during the wipe
	L.set_state("complete")
	L.progress.start_story(2)
	game = await _fresh_scene(L.GAME)
	await L.frames(20)
	await esc()
	await L.frames(3)
	var quit_btn := button_with(game, "QUIT TO HUB")
	check(quit_btn != null, "GAME-PAUSE", "pause menu has QUIT TO HUB")
	var slime_before: Vector2 = game.slime.position
	await L.click(quit_btn.get_global_rect().get_center(), 2)
	# during the wipe: Esc, R, jump, move
	var running_during_wipe := not paused
	L.key(KEY_RIGHT, true)
	await L.tap(KEY_ESCAPE)
	await L.tap(KEY_R)
	await L.frames(3)
	L.key(KEY_RIGHT, false)
	check(L.transition.busy or L.kind() != "main", "GAME-QUIT", "QUIT TO HUB starts the wipe")
	check(not (running_during_wipe and is_instance_valid(game) and game.slime.position != slime_before and L.transition.busy), "QUIT-RUNS",
		"the level stays frozen under the QUIT TO HUB wipe (slime %s -> %s while a direction is held)" % [slime_before, game.slime.position if is_instance_valid(game) else "-"])
	await L.settle()
	check(L.kind() == "hub" and not paused, "GAME-QUIT", "QUIT TO HUB lands in an unpaused hub (%s)" % L.kind())
	inv("hub after pause quit")
	check(not L.progress.return_to_game, "WIPE-UPG", "return_to_game false after quitting")
	# enter the map table immediately after returning from a level
	await L.tap(KEY_F)
	await L.settle()
	check(L.kind() in ["maps", "hub", "level_select"], "RETURN-ENTER", "F straight after arriving from a level opens something sane (%s)" % L.kind())
	inv("after return")

	# --- dry-up: Esc pause then resume; choices keep focus
	L.set_state("complete")
	L.progress.start_story(2)
	game = await _fresh_scene(L.GAME)
	await L.frames(20)
	game.slime_remaining = 0.1
	game.slime.position.x += 4.0
	await L.frames(120)
	check(game.finished and not game.won and game.hud.choice_buttons.size() >= 2, "DRY-CHOICES", "dry-up shows RESTART / UPGRADES")
	inv("dry-up choices")
	await esc()
	await L.frames(3)
	inv("dry-up pause")
	await esc()
	await L.frames(3)
	var f: Control = L.focus()
	check(f != null and f in game.hud.choice_buttons, "PAUSE-FOCUS", "after Esc, Esc over the dry-up choices a choice is focused (focus=%s)" % (f.name if f else "none"))
	# UPGRADES via Enter on the second choice, then Esc returns into the level
	game.hud.choice_buttons[1].grab_focus()
	await L.tap(KEY_ENTER)
	await L.settle()
	check(L.kind() == "upgrades" and L.progress.return_to_game, "DRY-UPG", "UPGRADES opens the upgrades screen in PLAY mode")
	await L.tap(KEY_ENTER)
	await L.tap(KEY_ESCAPE)  # Esc and PLAY race
	await L.settle()
	check(L.kind() == "main" and not L.progress.return_to_game, "DRY-UPG", "Esc / Enter on PLAY returns into the level once (%s)" % L.kind())
	inv("back from upgrades")

	# --- wipe + UPGRADES click bug: quit to hub from the dry-up pause, then press UPGRADES during the wipe
	L.set_state("complete")
	L.progress.start_story(2)
	game = await _fresh_scene(L.GAME)
	await L.frames(20)
	game.slime_remaining = 0.1
	game.slime.position.x += 4.0
	await L.frames(120)
	await esc()
	await L.frames(3)
	var quit2 := button_with(game, "QUIT TO HUB")
	await L.click(quit2.get_global_rect().get_center(), 1)
	await L.frames(2)
	var up_btn: Button = game.hud.choice_buttons[1] if game.hud.choice_buttons.size() > 1 else null
	if up_btn and is_instance_valid(up_btn) and up_btn.is_visible_in_tree():
		await L.click(up_btn.get_global_rect().get_center(), 1)
	await L.settle()
	check(L.kind() == "hub" and not L.progress.return_to_game, "WIPE-UPG",
		"UPGRADES clicked during the QUIT-TO-HUB wipe must not leave return_to_game set (kind=%s return_to_game=%s)" % [L.kind(), L.progress.return_to_game])
	if L.progress.return_to_game:
		# consequence: the hub's UPGRADES station now behaves like the dry-up detour
		hub_to("upgrades")
		await L.tap(KEY_F)
		await L.settle()
		await esc()
		await L.settle()
		print("   consequence: Esc in a normal UPGRADES visit then lands in %s (expected hub)" % L.kind())
		check(L.kind() == "hub", "WIPE-UPG", "after the stuck flag, Esc in UPGRADES from the hub lands in %s instead of the hub" % L.kind())
	L.progress.return_to_game = false

	# --- RESTART pressed just before a wipe (UPGRADES) swaps the scene
	for delay in [0, 6, 12]:
		L.set_state("complete")
		L.progress.start_story(2)
		game = await _fresh_scene(L.GAME)
		await L.frames(20)
		game.slime_remaining = 0.05
		game.slime.position.x += 4.0
		await L.frames(120)
		var e0: int = L.errlog.count
		var up_b: Button = game.hud.choice_buttons[1]
		var rs_b: Button = game.hud.choice_buttons[0]
		await L.click(up_b.get_global_rect().get_center(), 1)
		await L.frames(delay)
		if is_instance_valid(rs_b) and rs_b.is_inside_tree():
			await L.click(rs_b.get_global_rect().get_center(), 1)
		await L.settle(300)
		L.err_seen = e0  # reported through the invariant below
		var v := inv("UPGRADES click then RESTART click %d frames later" % delay)
		check(L.kind() == "upgrades", "RACE-LAND", "...and the screen lands on UPGRADES (got %s)" % L.kind())
		L.progress.return_to_game = false

	# --- win: Esc / pause over the next-step buttons, NEXT LEVEL / HUB
	L.set_state("complete")
	L.progress.start_story(3)
	game = await _fresh_scene(L.GAME)
	await L.frames(20)
	game._on_goal_body_entered(game.slime)
	await L.frames(60)
	check(game.won and game.hud.choice_buttons.size() == 3, "WIN-CHOICES", "win shows REPLAY / NEXT LEVEL / HUB")
	inv("win choices")
	await esc()
	await L.frames(3)
	await esc()
	await L.frames(3)
	f = L.focus()
	check(f != null and f in game.hud.choice_buttons, "PAUSE-FOCUS", "after Esc, Esc over the win choices a choice is focused")
	await L.tap(KEY_R)  # R after a win = replay
	await L.settle()
	check(L.kind() == "main", "WIN-R", "R after a win replays")
	inv("after replay")

	# --- randomizer: pause + seed box
	L.set_state("complete")
	L.progress.start_random()
	game = await _fresh_scene(L.GAME)
	await L.frames(30)
	await esc()
	await L.frames(3)
	check(game.pause_menu.seed_button.visible, "SEED-BTN", "pause menu in a randomizer maze shows the SEED button")
	await L.click(game.pause_menu.seed_button.get_global_rect().get_center(), 2)
	await L.frames(3)
	check(game.pause_menu.seed_edit.visible and L.focus() == game.pause_menu.seed_edit, "SEED-BOX", "clicking SEED opens the box focused")
	inv("seed box")
	await L.tap(KEY_P)  # typed into the box
	await L.frames(2)
	check(game.pause_menu.visible and game.pause_menu.seed_edit.visible, "SEED-BOX", "P inside the seed box types, keeps the menu")
	await esc()
	await L.frames(3)
	if game.pause_menu.seed_edit.visible:
		print("   note: first Esc in the seed box only stopped editing (accepted design); the next one closes it")
		inv("after first esc in the seed box (a control must still have focus)")
		await esc()
		await L.frames(3)
	check(game.pause_menu.visible and not game.pause_menu.seed_edit.visible, "SEED-BOX", "Esc closes the seed box first (pause stays)")
	inv("seed box closed")
	await esc()
	await L.frames(3)
	check(not game.pause_menu.visible and not paused, "SEED-BOX", "second Esc resumes")
	# type a new seed and Enter
	await esc()
	await L.frames(3)
	await L.click(game.pause_menu.seed_button.get_global_rect().get_center(), 2)
	await L.frames(3)
	game.pause_menu.seed_edit.text = "4242"
	await L.tap(KEY_ENTER)
	await L.settle()
	await L.frames(20)
	check(L.kind() == "main" and not paused, "SEED-ENTER", "a typed seed reloads the maze, unpaused")
	inv("after seed enter")
	game = current_scene
	# click-away closes the seed box
	await esc()
	await L.frames(3)
	await L.click(game.pause_menu.seed_button.get_global_rect().get_center(), 2)
	await L.frames(3)
	await L.click(Vector2(10, 10), 2)
	await L.frames(3)
	check(game.pause_menu.visible and not game.pause_menu.seed_edit.visible, "SEED-BOX", "clicking away closes the seed box, menu stays")
	await esc()
	await L.frames(3)
	check(not paused, "SEED-BOX", "...then Esc resumes")

	# --- pausing during the intro ease-in (goo sheet still sliding off)
	L.set_state("complete")
	L.progress.start_story(1)
	game = await _fresh_scene(L.GAME)
	L.set_state("complete")
	L.progress.start_story(1)
	change_scene_to_file(L.GAME)
	await L.frames(3)
	await esc()
	await L.frames(2)
	inv("pause during intro ease-in", false)
	await L.frames(40)
	if current_scene.pause_menu.visible:
		await esc()
		await L.frames(3)
	check(not paused, "INTRO-PAUSE", "pause/resume during the level's ease-in leaves the tree unpaused")
	inv("after intro pause")

	# --- level -> level select -> level (hub path) with Esc/enter bursts
	L.set_state("complete")
	await _fresh_scene(L.LEVELS)
	await L.tap(KEY_ENTER)
	await L.tap(KEY_ENTER)
	await L.tap(KEY_ESCAPE)
	await L.settle(240)
	inv("level select burst")
	if L.kind() == "main":
		await esc()
		await L.frames(3)
		var qb := button_with(current_scene, "QUIT TO HUB")
		if qb:
			await L.click(qb.get_global_rect().get_center(), 1)
		await L.settle()
		check(L.kind() == "hub", "BURST-HUB", "Enter,Enter,Esc in the level select then pause > QUIT lands in the hub (got %s)" % L.kind())


func _story() -> void:
	# intro from the title STORY button; Esc skips
	L.set_state("complete")
	var title: Control = await _fresh_scene(L.TITLE)
	title.story_button.pressed.emit()
	await L.settle(300)
	check(L.kind() == "story", "STORY-OPEN", "STORY plays the intro")
	await L.frames(30)
	await L.tap(KEY_ESCAPE)
	await L.tap(KEY_ESCAPE)
	await L.settle(300)
	check(L.kind() == "title", "STORY-ESC", "Esc (x2) skips the intro back to the title (got %s)" % L.kind())
	inv("title after intro")
	await L.tap(KEY_ENTER)  # focus on the enter button again?
	await L.settle()
	check(L.kind() == "hub", "STORY-RET", "Enter on the title after the intro enters the hub (got %s)" % L.kind())
	# P also skips
	title = await _fresh_scene(L.TITLE)
	title.story_button.pressed.emit()
	await L.settle(300)
	await L.frames(30)
	await L.tap(KEY_P)
	await L.settle(300)
	check(L.kind() == "title", "STORY-ESC", "P skips the intro too")
	# victory screen: Esc?
	L.set_state("complete")
	var vic: Control = await _fresh_scene(L.VICTORY)
	inv("victory")
	await esc()
	await L.frames(60)
	check(L.kind() != "victory", "VICTORY-ESC", "Esc on the victory screen leaves it (now %s)" % L.kind())
	# finale -> victory
	L.set_state("complete")
	L.progress.story_seen = L.progress.STORY_INTRO
	L.progress.start_story(10)
	var game: Node2D = await _fresh_scene(L.GAME)
	await L.frames(20)
	game._on_goal_body_entered(game.slime)
	await L.frames(int(game.WIN_FINAL_DELAY * 60) + 90)
	if game.hud.choice_buttons.size() == 3:
		game.hud.choice_buttons[1].grab_focus()
		await L.tap(KEY_ENTER)
		await L.settle(300)
		check(L.kind() == "story", "FINALE-OPEN", "CONTINUE after level 10 plays the finale (got %s)" % L.kind())
		await L.frames(30)
		await esc()
		await L.settle(300)
		check(L.kind() == "victory", "FINALE-ESC", "Esc skips the finale to the victory screen (got %s)" % L.kind())
		inv("victory after finale")


func _leaks() -> void:
	L.set_state("complete")
	var hub: Node2D = await _fresh_scene(L.HUB)
	var samples := {}
	for i in 51:
		hub = current_scene
		if not hub_to("maps"):
			bug("LEAK-TP", "cannot reach the map table in cycle %d" % i)
			break
		await L.tap(KEY_F)
		await L.settle()
		if L.kind() != "maps":
			bug("LEAK-NAV", "cycle %d: F at the map table did not open it (%s)" % [i, L.kind()])
			break
		var ms: Control = current_scene
		await L.tap(KEY_ENTER)
		await L.frames(2)
		await esc()
		await L.frames(2)
		await esc()
		await L.settle()
		if i == 5 or i == 50:
			await L.frames(30)
			samples[i] = L.perf()
	if samples.has(5) and samples.has(50):
		var a: Dictionary = samples[5]
		var b: Dictionary = samples[50]
		print("   cycle 5: %s\n   cycle 50: %s" % [a, b])
		check(b.nodes <= a.nodes + 2, "LEAK-NODES", "node count stable over 45 more map table cycles (%d -> %d)" % [a.nodes, b.nodes])
		check(b.orphans <= a.orphans + 2, "LEAK-ORPHANS", "orphan nodes stable (%d -> %d)" % [a.orphans, b.orphans])
		check(b.objects <= a.objects + 40, "GOO-WEAKREFS", "object count stable (%d -> %d)" % [a.objects, b.objects])
		check(b.root_children == a.root_children, "LEAK-ROOT", "no leaked root-level nodes (%d -> %d)" % [a.root_children, b.root_children])
	inv("after leak cycles")


func _variants() -> void:
	# touch controls visible: tapping at the hub
	L.set_state("touch")
	var hub: Node2D = await _fresh_scene(L.HUB)
	inv("hub touch")
	check(hub_to("maps"), "HUB-TP", "map table reachable (touch)")
	# JUMP uses the station on a touchscreen: press the jump action
	L.action("jump", true)
	await L.frames(2)
	L.action("jump", false)
	await L.settle()
	check(L.kind() == "maps", "TOUCH-USE", "JUMP next to the map table opens it on touch (got %s)" % L.kind())
	inv("maps touch")
	# the touch pause button must not leave the menu action held
	L.progress.start_story(2)
	var gm: Node = await _fresh_scene(L.GAME)
	await L.frames(10)
	var tcn: Node = null
	for c in gm.get_children():
		if c is CanvasLayer and "pause_rect" in c:
			tcn = c
	if tcn != null:
		await L.touch(tcn.pause_rect.get_center(), 2)
		await L.frames(3)
		check(gm.pause_menu.visible, "TOUCH-PAUSE", "touching the pause icon pauses")
		await L.touch(button_with(gm, "RESUME").get_global_rect().get_center(), 2)
		await L.frames(3)
		check(not Input.is_action_pressed("menu"), "TOUCH-MENU-STUCK", "after touch-pausing, the menu action is not left pressed")
		Input.action_release("menu")
	await _fresh_scene(L.HUB)
	# the stuck-action check: hold the left stick area then change scene
	var tc = null
	await esc()
	await L.settle()
	L.release_all()
	check(L.stuck_actions().is_empty(), "STUCK", "no input action stuck after leaving (touch): %s" % [L.stuck_actions()])
	await _web_child()
	# resize
	var old: Vector2i = root.size
	for sz in [Vector2i(1920, 1080), Vector2i(500, 900), Vector2i(320, 180)]:
		root.size = sz
		await L.frames(3)
		inv("resize %s" % sz)
	root.size = old


## The web build has no trapdoor (hub without QUIT): run a short walk in a child process with --web-ui.
func _web_child() -> void:
	if "--nav-child" in OS.get_cmdline_user_args():
		return
	var out := []
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--headless", "--fixed-fps", "60", "--quit-after", "300000",
		"-s", "res://tests/test_nav_fuzz.gd", "--", "--web-ui", "--nav-child", "--nav-only=walks", "--nav-steps=600", "--nav-seed=%d" % (base_seed + 5)]
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var text: String = "".join(out)
	var ok := "RESULT: PASS" in text
	print("   --web-ui child walk: exit=%d %s" % [code, "PASS" if ok else "FAIL"])
	if not ok:
		for line in text.split("\n"):
			if "VIOLATION" in line or "NEW " in line or "UNEXPECTED" in line or "SCRIPT ERROR" in line:
				print("      " + line)
	check(ok, "WEB-WALK", "a random walk with --web-ui (no trapdoor) is clean")


# ------------------------------------------------------------------ random walks

func _walks() -> void:
	var starts := [["complete", L.HUB], ["complete", L.MAPS], ["fresh", L.TITLE], ["mid", L.HUB], ["dev", L.HUB], ["complete", L.GAME], ["touch", L.LEVELS]]
	if variant != "":
		starts = [[variant if variant == "touch" else "complete", L.HUB]]
	var i := 0
	for s in starts:
		if only_walk < 0 or only_walk == i:
			await _walk(s[0], s[1], base_seed + i * 7919, walk_steps)
		i += 1
	if variant != "" or area_steps <= 0:
		return
	for a in AREAS:  # walk indices continue after the plain ones (replay one with --nav-walk=I)
		if only_walk < 0 or only_walk == i:
			area = a[0]
			await _walk(a[1], a[2], base_seed + i * 7919, area_steps)
			area = ""
		i += 1


func _walk(state: String, scene: String, wseed: int, steps: int) -> void:
	current_walk = "walk state=%s start=%s seed=%d%s" % [state, scene.get_file(), wseed, " area=" + area if area != "" else ""]
	rng.seed = wseed
	seed(wseed)
	L.set_state(state)
	if scene == L.GAME:
		L.progress.start_story(3)
	L.trace.clear()
	L.note("START " + current_walk)
	await _fresh_scene(scene)
	await _area_setup()
	var first_bad := ""
	var n := 0
	var cov := {}
	for step in steps:
		var op := await _random_op()
		n += 1
		_cover(cov)
		await L.frames(rng.randi_range(1, 3))  # real inputs are never in the same frame as the press before (the dbl_/_burst ops do that on purpose)
		if current_scene == null:
			await L.frames(2)
		var v: Array[String] = L.invariants(true)
		if v.is_empty() and L.held_keys.is_empty() and not Input.is_action_pressed("ui_accept") and step % 4 == 0:
			var stuck: Array[String] = L.stuck_actions()
			if not stuck.is_empty():
				await L.frames(3)  # a touch / joypad release may still be in flight
				stuck = L.stuck_actions()
				if not stuck.is_empty():
					v.append("STUCK: input actions held with nothing pressed: %s" % [stuck])
		if not v.is_empty():
			var tag := _tag_of(v[0], "walk")
			bug(tag, "step %d (%s): %s" % [step, op, v[0]])
			if first_bad == "" and (not KNOWN.has(tag) or strict):
				first_bad = v[0]
				failures += 1
				print("  VIOLATION in %s at step %d: %s" % [current_walk, step, v[0]])
				print("  scene now: %s, tree paused=%s, wipe busy=%s" % [L.kind(), paused, L.transition.busy])
				print("  replayable trace (replay with: -- --nav-walk=<index> --nav-seed=%d --nav-steps=%d; seed=%d state=%s start=%s):" % [base_seed, steps, wseed, state, scene.get_file()])
				for line in L.trace.slice(maxi(0, L.trace.size() - 40)):
					print("     " + line)
				break
	# end of walk: release everything, settle, check, then find the way back with Esc
	L.release_all()
	if not await L.settle(240):
		bug("WIPE-STUCK", "%s: the goo wipe never finished within 240 frames" % current_walk)
		failures += 1
	await L.frames(5)
	inv("walk end")
	print("     perf at walk end: %s" % [L.perf()])
	var back := await _escape_ladder()
	if not back:
		bug("NO-WAY-BACK", "%s: Esc ladder from %s never reached hub/title" % [current_walk, L.kind()])
		failures += 1
	L.release_all()
	await L.frames(3)
	var stuck: Array[String] = L.stuck_actions()
	if not stuck.is_empty():
		bug("STUCK", "%s: input actions still held after releasing everything: %s" % [current_walk, stuck])
		failures += 1
	var keys: Array = cov.keys()
	keys.sort()
	print("  walk done: %s (%d ops)\n     coverage: %s" % [current_walk, n, ", ".join(keys.map(func(k: String) -> String: return "%s=%d" % [k, cov[k]]))])
	current_walk = ""


# ------------------------------------------------------------------ area walks

## Puts an area walk's start scene into its area (a map open, a panel open, paused, dried up, won).
func _area_setup() -> void:
	var cs := current_scene
	match area:
		"maps":
			await L.tap(KEY_ENTER)  # opens the focused tile's map
		"settings":
			await L.click(cs.save_code_button.get_global_rect().get_center(), 1)
		"pause":
			await L.frames(20)
			await esc()
		"dry", "win", "touch":
			await L.frames(20)
	await L.frames(3)


## One step back toward the walk's area, with real input where there is one (harness only for the
## dry-up / win themselves, as the plain walks do): from the hub to its station, from the level select
## into a level, then the area's own move (open a map, open a panel, pause, dry up, win, touch).
func _area_op() -> void:
	var k: String = L.kind()
	var cs := current_scene
	if cs == null or L.transition.busy:
		await L.frames(2)
		return
	match k:
		"title":
			await L.tap(KEY_ENTER)
		"hub":
			var station: String = {"maps": "maps", "settings": "settings"}.get(area, "story")
			if not overlay_closed(cs):
				await esc()
			elif hub_to(station):
				L.note("(area) tp to %s + F" % station)
				await L.tap(KEY_F)
		"level_select", "story", "victory":
			if k != "victory" or rng.randf() < 0.5:
				await L.tap(KEY_ENTER)
			else:
				await esc()
		"maps":
			if area != "maps":
				await esc()
			elif not cs.viewing:
				var open: Array = cs.tiles.filter(func(t: Button) -> bool: return not t.disabled)
				if open.is_empty():
					await L.click(cs.hard_box.get_global_rect().get_center(), 1)
				else:
					var tile: Button = open[rng.randi() % open.size()]
					if rng.randf() < 0.5:
						await L.click(tile.get_global_rect().get_center(), 1)
					else:
						await L.touch(tile.get_global_rect().get_center(), 1)
			else:  # in the view: poke at where the hidden select's controls lie
				var under: Array = [cs.hard_box, cs.back_button] + cs.tiles
				var c: Control = under[rng.randi() % under.size()]
				await L.click(c.get_global_rect().get_center(), 1)
		"controls":
			if area != "settings":
				await esc()
			elif not cs.code_panel.visible and not cs.reset_confirm.visible:
				var b: Button = cs.save_code_button if rng.randf() < 0.5 else cs.reset_button
				await L.click(b.get_global_rect().get_center(), 1)
			else:  # a panel is open: click where the page's buttons lie under it, or type in the boxes
				var under: Array = [cs.save_code_button, cs.reset_button, cs.controls_button, cs.sound_button, cs.code_in, cs.code_out]
				var c: Control = under[rng.randi() % under.size()]
				await L.click(c.get_global_rect().get_center(), 1)
		"main":
			if area == "touch":
				var spots := [cs.touch_controls.pause_rect.get_center(), Vector2(40, 140), Vector2(282, 142), Vector2(rng.randi_range(0, 319), rng.randi_range(0, 179))]
				await L.touch(spots[rng.randi() % spots.size()], rng.randi_range(1, 6))
			elif cs.finished:
				if not cs.pause_menu.visible and rng.randf() < 0.3:
					await esc()  # pause over the choices
				else:
					await L.frames(1)
			elif area == "dry" or (area == "pause" and rng.randf() < 0.3):
				L.note("(harness) dry up the slime")
				cs.slime_remaining = 0.05
				cs.slime.position.x += 4.0
			elif area == "win" or (area == "pause" and rng.randf() < 0.3):
				L.note("(harness) reach the goal")
				cs._on_goal_body_entered(cs.slime)
			else:
				await esc()
		_:
			await esc()


## Counts which screens / overlays the walk has been in (printed per walk, to show what it reached).
func _cover(cov: Dictionary) -> void:
	var cs := current_scene
	if cs == null:
		return
	var tags: Array[String] = [L.kind()]
	match L.kind():
		"maps":
			if cs.viewing:
				tags.append("maps:view")
		"controls":
			if cs.code_panel.visible:
				tags.append("settings:codepanel")
			if cs.reset_confirm.visible:
				tags.append("settings:reset")
		"hub":
			if cs.quit_menu.visible:
				tags.append("hub:quit")
			if cs.coin_board.visible:
				tags.append("hub:coins")
			if cs.hat_wheel.visible:
				tags.append("hub:wheel")
		"main":
			if cs.pause_menu.visible:
				tags.append("game:pause")
				if cs.pause_menu.seed_edit.visible:
					tags.append("game:seedbox")
			if cs.restart_prompt.visible:
				tags.append("game:rprompt")
			if cs.finished and not cs.won:
				tags.append("game:dry")
			if cs.won:
				tags.append("game:won")
		"key_controls":
			if cs.waiting_for != "":
				tags.append("keys:rebinding")
		"skins":
			tags.append("skins:" + cs.page)
	for t in tags:
		cov[t] = int(cov.get(t, 0)) + 1


## Esc up to 6 times (with a pause-menu QUIT TO HUB fallback in a level): must reach the hub or title.
func _escape_ladder() -> bool:
	for i in 8:
		var k: String = L.kind()
		if k in ["hub", "title"] and not transition_busy():
			var hub_ok := true
			if k == "hub":
				var hub = current_scene
				hub_ok = not hub.quit_menu.visible and not hub.coin_board.visible and not hub.hat_wheel.visible
			if hub_ok:
				return true
		if k == "main":
			var g = current_scene
			if g.pause_menu.visible:
				var qb := button_with(g, "QUIT TO HUB")
				if qb:
					await L.click(qb.get_global_rect().get_center(), 1)
					await L.settle(240)
					continue
		await esc()
		await L.settle(240)
	return L.kind() in ["hub", "title"]


const OPS := ["esc", "esc", "esc", "p", "enter", "enter", "space", "up", "down", "left", "right", "w", "a", "s", "d", "tab", "shift_tab",
	"f", "f", "r", "click_btn", "click_btn", "click_btn", "click_rand", "touch_btn", "touch_rand", "dbl_esc", "esc_enter", "hold_dir",
	"hold_esc", "wait", "wait_wipe", "tp", "tp", "joy_b", "joy_a", "esc_f", "type", "act_cancel", "act_accept", "jump_tap", "enter_burst"]


## Picks the next input: uniform, but biased toward getting somewhere from the screens that are easy to bounce around in
## (and, in an area walk, back into its area about a third of the time).
func _pick_op() -> String:
	if area != "" and rng.randf() < 0.35:
		return "area"
	var r := rng.randf()
	match L.kind():
		"title":
			if r < 0.5:
				return "enter"
		"story":
			if r < 0.5:
				return "esc"
		"hub":
			if r < 0.4:
				return "tp_use"
		"main":
			if r < 0.04:
				return "dry"
			if r < 0.07:
				return "win"
	return OPS[rng.randi() % OPS.size()]


func _random_op() -> String:
	var op: String = _pick_op()
	var cs := current_scene
	var guard_quit := func() -> bool:
		var f: Control = L.focus()
		return L.would_quit(f) if f else false
	match op:
		"area":
			await _area_op()
		"esc":
			await L.tap(KEY_ESCAPE)
		"p":
			await L.tap(KEY_P)
		"enter", "space", "act_accept", "joy_a":
			if guard_quit.call():
				L.note("(skipped %s: focus is QUIT)" % op)
				return op
			match op:
				"enter":
					await L.tap(KEY_ENTER)
				"space":
					await L.tap(KEY_SPACE)
				"act_accept":
					L.note("action ui_accept")
					L.action("ui_accept", true)
					await L.frames(1)
					L.action("ui_accept", false)
				"joy_a":
					L.note("joy A")
					L.joy(JOY_BUTTON_A, true)
					await L.frames(1)
					L.joy(JOY_BUTTON_A, false)
		"up":
			await L.tap(KEY_UP)
		"down":
			await L.tap(KEY_DOWN)
		"left":
			await L.tap(KEY_LEFT)
		"right":
			await L.tap(KEY_RIGHT)
		"w":
			await L.tap(KEY_W, rng.randi_range(1, 6))
		"a":
			await L.tap(KEY_A, rng.randi_range(1, 6))
		"s":
			await L.tap(KEY_S, rng.randi_range(1, 6))
		"d":
			await L.tap(KEY_D, rng.randi_range(1, 6))
		"tab":
			await L.tap(KEY_TAB)
		"shift_tab":
			L.note("shift+tab")
			var e := InputEventKey.new()
			e.keycode = KEY_TAB
			e.physical_keycode = KEY_TAB
			e.shift_pressed = true
			e.pressed = true
			Input.parse_input_event(e)
			await L.frames(1)
			e = e.duplicate()
			e.pressed = false
			Input.parse_input_event(e)
		"f":
			await L.tap(KEY_F)
		"r":
			await L.tap(KEY_R)
		"click_btn", "touch_btn":
			var list: Array = L.clickables()
			if list.is_empty():
				return op
			var c: Control = list[rng.randi() % list.size()]
			if L.would_quit(c):
				L.note("(skipped click: QUIT)")
				return op
			var at := c.get_global_rect().get_center()
			if op == "click_btn":
				await L.click(at, rng.randi_range(1, 3))
			else:
				await L.touch(at, rng.randi_range(1, 3))
		"click_rand", "touch_rand":
			var at := Vector2(rng.randi_range(0, 319), rng.randi_range(0, 179))
			var hit: Control = null
			var skip := false
			for c in L.clickables():
				if L.would_quit(c) and c.get_global_rect().has_point(at):
					skip = true
			if skip:
				L.note("(skipped random click on QUIT)")
				return op
			if op == "click_rand":
				await L.click(at, 1)
			else:
				await L.touch(at, 1)
		"dbl_esc":
			L.note("Esc + P same frame")
			L.key(KEY_ESCAPE, true)
			L.key(KEY_P, true)
			await L.frames(1)
			L.key(KEY_ESCAPE, false)
			L.key(KEY_P, false)
		"esc_enter":
			if guard_quit.call():
				return op
			L.note("Esc + Enter same frame")
			L.key(KEY_ESCAPE, true)
			L.key(KEY_ENTER, true)
			await L.frames(1)
			L.key(KEY_ESCAPE, false)
			L.key(KEY_ENTER, false)
		"esc_f":
			L.note("Esc + F same frame")
			L.key(KEY_ESCAPE, true)
			L.key(KEY_F, true)
			await L.frames(1)
			L.key(KEY_ESCAPE, false)
			L.key(KEY_F, false)
		"hold_dir":
			var code: Key = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT][rng.randi() % 8]
			L.note("hold %s" % OS.get_keycode_string(code))
			L.key(code, true)
			var n := rng.randi_range(5, 40)
			for i in n:
				await L.frames(1)
				if i % 2 == 0:
					L.key(code, true, true)
			L.key(code, false)
		"hold_esc":
			L.note("hold Esc")
			L.key(KEY_ESCAPE, true)
			for i in rng.randi_range(5, 30):
				await L.frames(1)
				L.key(KEY_ESCAPE, true, true)
			L.key(KEY_ESCAPE, false)
		"wait":
			var n := rng.randi_range(1, 40)
			L.note("wait %d" % n)
			await L.frames(n)
		"wait_wipe":
			L.note("wait for wipe")
			await L.settle(120)
		"tp":
			if L.kind() == "hub":
				var ids := ["story", "maps", "coins", "random", "wardrobe", "upgrades", "wheel", "settings", "quit"]
				var id: String = ids[rng.randi() % ids.size()]
				L.note("tp to %s" % id)
				hub_to(id)
		"tp_use":
			if L.kind() == "hub":
				var ids := ["story", "maps", "coins", "random", "wardrobe", "upgrades", "wheel", "settings", "quit"]
				var id: String = ids[rng.randi() % ids.size()]
				L.note("tp to %s + F" % id)
				if hub_to(id):
					await L.tap(KEY_F)
		"dry":
			if L.kind() == "main" and not cs.finished:
				L.note("(harness) dry up the slime")
				cs.slime_remaining = 0.05
				cs.slime.position.x += 4.0
		"win":
			if L.kind() == "main" and not cs.finished:
				L.note("(harness) reach the goal")
				cs._on_goal_body_entered(cs.slime)
		"joy_b":
			L.note("joy B")
			L.joy(JOY_BUTTON_B, true)
			await L.frames(1)
			L.joy(JOY_BUTTON_B, false)
		"type":
			L.note("type")
			await L.tap([KEY_P, KEY_1, KEY_A, KEY_BACKSPACE][rng.randi() % 4])
		"act_cancel":
			L.note("action ui_cancel")
			L.action("ui_cancel", true)
			await L.frames(1)
			L.action("ui_cancel", false)
		"jump_tap":
			L.note("action jump")
			L.action("jump", true)
			await L.frames(rng.randi_range(1, 10))
			L.action("jump", false)
		"enter_burst":
			if guard_quit.call():
				return op
			L.note("Enter x3 burst")
			for i in 3:
				L.key(KEY_ENTER, true)
				L.key(KEY_ENTER, false)
			await L.frames(1)
	return op
