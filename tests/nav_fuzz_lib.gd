extends RefCounted

## Shared driver for the navigation fuzzer (tests/test_nav_fuzz.gd and tests/demo_nav_*.gd): boots the
## real scenes inside a SceneTree script, sends real input events (Input.parse_input_event: keys, actions,
## joypad buttons, mouse and touch at the buttons' rects), and checks invariants after every action.
## Never touches a real save (Progress is switched to in-memory before anything runs).

const TITLE := "res://scenes/title.tscn"
const HUB := "res://scenes/hub.tscn"
const GAME := "res://scenes/main.tscn"
const MAPS := "res://scenes/maps.tscn"
const LEVELS := "res://scenes/level_select.tscn"
const UPGRADES := "res://scenes/upgrades.tscn"
const SKINS := "res://scenes/skins.tscn"
const SETTINGS := "res://scenes/controls.tscn"
const KEYS := "res://scenes/key_controls.tscn"
const STORY := "res://scenes/story.tscn"
const VICTORY := "res://scenes/victory.tscn"

## Scenes that are menus: a control must hold keyboard focus once they have settled.
const MENU_KINDS := ["title", "level_select", "maps", "upgrades", "skins", "controls", "key_controls", "victory"]


## Counts engine/script errors (ERROR, SCRIPT ERROR, warnings are ignored) with their first lines.
class ErrLog extends Logger:
	var count := 0
	var lines: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == 1:  # warning
			return
		if "Clipboard is not supported" in rationale:  # headless display server: COPY / PASTE buttons
			return
		count += 1
		if lines.size() < 20:
			lines.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


var tree: SceneTree
var progress: Node
var transition: Node
var errlog := ErrLog.new()
var err_seen := 0
var trace: Array[String] = []
var frame := 0
var scene_changed_frame := 0
var _last_scene: Node
var held_keys := {}
var quit_blocked := 0
var null_scene_checks := 0


func _init(t: SceneTree) -> void:
	tree = t
	progress = t.root.get_node("Progress")
	transition = t.root.get_node("Transition")
	progress.saving_enabled = false
	assert(progress.save_path != progress.REAL_SAVE_PATH)
	OS.add_logger(errlog)
	Input.use_accumulated_input = false


# ------------------------------------------------------------------ state

## A start state: "complete" (--story-complete + full maps), "fresh" (new player), "mid" (3 levels
## cleared, maps of levels 1-3 only), "dev" (--unlock-all), "touch" (complete + touch), "rich" (complete
## + 300 tickets, 3 spins taken (the TAILOR open), a trail and two map papers owned, a workshop level).
func set_state(kind: String) -> void:
	progress.reset_progress()
	progress.maps = {}
	progress.maps_hint_seen = false
	progress.return_to_game = false
	progress.dev_tools = false
	progress.force_touch = false
	progress.reduce_motion = false
	progress.reset_bindings()
	(load("res://scripts/hub.gd") as GDScript).set("return_to", "")
	Hats.available = true
	progress.saving_enabled = false
	progress.story_seen = progress.STORY_INTRO | progress.STORY_FINALE
	progress.tutorial_seen = progress.TUTORIAL_MOVE | progress.TUTORIAL_LEAP
	Story.launched = true
	match kind:
		"complete":
			progress.enable_story_complete()
		"touch":
			progress.enable_story_complete()
			progress.force_touch = true
		"rich":
			progress.enable_story_complete()
			progress.tickets = 300
			progress.tickets_lifetime = 300
			progress.spins = 3
			progress.cosmetics_owned.assign(["gold", "blueprint", "night"])
			progress.workshop = {charge = 1}
		"mid":
			progress.levels_cleared = 3
			progress.highest_unlocked = 4
			progress.current_level = 4
			progress.seed_full_surveys()
			for key in progress.maps.keys():
				if int(key) % 100 > 3:  # keep levels 1-3 (normal key = level, hard = level + HARD_RECORDS)
					progress.maps.erase(key)
		"dev":
			progress.enable_dev_mode()
			Hats.available = true
			progress.tickets = 200
			progress.seed_full_surveys()
		"fresh":
			pass
	progress.saving_enabled = false


func kind_of(scene: Node) -> String:
	if scene == null:
		return ""
	var path: String = scene.scene_file_path
	if path == "":
		return ""
	return path.get_file().get_basename()


func kind() -> String:
	return kind_of(tree.current_scene)


## Loads a scene directly (the way the tests do) and lets it settle.
func load_scene(path: String, settle := 8) -> Node:
	release_all()
	tree.paused = false
	tree.change_scene_to_file(path)
	await frames(settle)
	return tree.current_scene


# ------------------------------------------------------------------ frames

func frames(n: int) -> void:
	for i in n:
		await tree.process_frame
		frame += 1
		if tree.current_scene != _last_scene:
			_last_scene = tree.current_scene
			scene_changed_frame = frame


## Waits until no goo wipe is running (or `limit` frames pass); true if it ended.
func settle(limit := 150) -> bool:
	for i in limit:
		await frames(1)
		if not transition.busy and not transition._sheet.visible and frame - scene_changed_frame >= 3:
			return true
	return false


# ------------------------------------------------------------------ input

func note(line: String) -> void:
	trace.append("[%d] %s" % [frame, line])


func key(code: Key, down := true, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	e.echo = echo
	if code >= KEY_0 and code <= KEY_Z:
		e.unicode = code if code < KEY_A else code + 32
	if down:
		held_keys[code] = true
	else:
		held_keys.erase(code)
	Input.parse_input_event(e)


func tap(code: Key, hold := 1) -> void:
	note("tap %s hold=%d" % [OS.get_keycode_string(code), hold])
	key(code, true)
	await frames(hold)
	key(code, false)


func action(name: String, down := true) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = down
	e.strength = 1.0 if down else 0.0
	Input.parse_input_event(e)


func joy(button: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)


func mouse(pos: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = pos
	e.global_position = pos
	e.pressed = down
	e.button_mask = (1 << (button - 1)) if down else 0
	Input.parse_input_event(e)


func click(pos: Vector2, hold := 1) -> void:
	note("click %s" % pos)
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	mouse(pos, true)
	await frames(hold)
	mouse(pos, false)


func touch(pos: Vector2, hold := 1) -> void:
	note("touch %s" % pos)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = true
	Input.parse_input_event(e)
	await frames(hold)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)


func release_all() -> void:
	for code in held_keys.keys():
		key(code, false)
	held_keys.clear()
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			Input.action_release(a)


## True when pressing `button`/Enter on the focus would quit the game (the hub's QUIT).
func would_quit(button: Control) -> bool:
	var hub := tree.current_scene
	return kind() == "hub" and hub.quit_menu.visible and button == hub.quit_button


# ------------------------------------------------------------------ queries

## Visible, mouse-reachable controls of the running scene (+ overlays) worth clicking.
func clickables() -> Array[Control]:
	var out: Array[Control] = []
	if tree.current_scene == null:
		return out
	_collect(tree.current_scene, out)
	return out


func _collect(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			if (c is BaseButton or c is LineEdit or c is Range) and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and c.get_global_rect().size.x > 0 and Rect2(0, 0, 320, 180).encloses(c.get_global_rect().grow(-0.5)):
				out.append(c)
		_collect(child, out)


func focus() -> Control:
	return tree.root.gui_get_focus_owner()


## The topmost modal panel of the current scene (focus must stay inside it), or null.
func modal() -> Node:
	var cs := tree.current_scene
	match kind():
		"maps":
			return cs.view_root if cs.viewing else null
		"controls":
			if cs.code_panel.visible:
				return cs.code_panel
			if cs.reset_confirm.visible:
				return cs.reset_confirm
		"hub":
			if cs.quit_menu.visible:
				return cs.quit_menu
			if cs.portal_menu.visible:
				return cs.portal_menu
			if cs.hat_wheel.visible:
				return cs.hat_wheel.modal()  # the buy confirm while it's open, else the whole overlay
		"main":
			if cs.restart_prompt.visible:
				return cs.restart_prompt
			if cs.pause_menu.visible:
				return cs.pause_menu
			if cs.descent_card != null and cs.descent_card.visible:
				return cs.descent_card.modal()  # DESCENT: the boon card or the run summary
	return null


## How many overlays that each "own" input are open at once (must be <= 1).
func overlay_count() -> int:
	var cs := tree.current_scene
	var n := 0
	match kind():
		"controls":
			n += int(cs.code_panel.visible) + int(cs.reset_confirm.visible)
		"hub":
			n += int(cs.quit_menu.visible) + int(cs.coin_board.visible) + int(cs.hat_wheel.visible) + int(cs.portal_menu.visible)
		"main":
			n += int(cs.restart_prompt.visible) + int(cs.pause_menu.visible)
	return n


func perf() -> Dictionary:
	return {
		nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		objects = int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		root_children = tree.root.get_child_count(),
	}


# ------------------------------------------------------------------ invariants

## Violations right now as ["TAG: text", ...]. `strict`: the screen must have settled (focus checks).
func invariants(strict := true) -> Array[String]:
	var out: Array[String] = []
	if errlog.count > err_seen:
		out.append("ERR: engine/script error: " + errlog.lines[mini(err_seen, errlog.lines.size() - 1)])
		err_seen = errlog.count
	var cs := tree.current_scene
	var busy: bool = transition.busy
	if cs == null:
		null_scene_checks += 1
		if not busy and null_scene_checks > 6:  # a reload/swap leaves current_scene null for a frame or two
			out.append("SCENE: no current scene for %d checks while no transition is running" % null_scene_checks)
		return out
	null_scene_checks = 0
	if Engine.time_scale != 1.0:
		out.append("TIME: Engine.time_scale = %s" % Engine.time_scale)
	if progress.saving_enabled:
		out.append("SAVE: saving_enabled flipped on (real save at risk)")
	var k := kind()
	var overlay_pause := false
	if k == "main":
		overlay_pause = cs.pause_menu.visible or cs.restart_prompt.visible
	if not busy and tree.paused != overlay_pause:
		out.append("PAUSE: tree.paused=%s but pause overlay=%s in %s" % [tree.paused, overlay_pause, k])
	if overlay_count() > 1:
		out.append("OVERLAY: %d overlays own input at once in %s" % [overlay_count(), k])
	var settled := not busy and frame - scene_changed_frame >= 2
	if settled and k == "hub" and overlay_count() == 0 and cs.slime.frozen and frame - scene_changed_frame >= 8:
		out.append("HUBFROZEN: the hub's slime is frozen with no overlay open and no wipe running (stuck: can't move, use stations or leave)")
	if settled and strict:
		var f := focus()
		var m := modal()
		if k in MENU_KINDS or m != null:
			if f == null or not f.is_visible_in_tree():
				out.append("FOCUS: no visible focused control in %s%s" % [k, " (modal %s)" % m.name if m else ""])
			elif m != null and not (m == f or m.is_ancestor_of(f)):
				out.append("FOCUS: focus on '%s' (%s) escaped the modal %s in %s" % [_name(f), f.get_path(), m.name, k])
		elif k == "main" and cs.finished and not cs.hud.choice_buttons.is_empty() and m == null:
			var inside := false
			for b in cs.hud.choice_buttons:
				inside = inside or (is_instance_valid(b) and b.is_visible_in_tree() and (f == b))
			if not inside:
				out.append("FOCUS: level result choices shown but none is focused")
		if f != null and f.is_visible_in_tree() and k == "hub" and m == null and f is BaseButton and (f as BaseButton).disabled:
			out.append("FOCUS: disabled control focused")
	return out


func _name(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	return c.name


## True when no input action is still held (call after every key/touch was released).
func stuck_actions() -> Array[String]:
	var out: Array[String] = []
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			out.append(String(a))
	return out


## Two Escape presses delivered within one frame (a hitch, or a very fast double tap).
func action_both_same_frame() -> void:
	note("Esc, Esc in one frame")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(1)
