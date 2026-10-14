extends SceneTree

## HEAT (upgrades v2 batch 4, docs/design/upgrades-v2.md C3; Heat, Economy.HEAT_*): the table and
## mask rules (BRITTLE/GROUNDED exclusion, max heat 10, 48 pickable masks), bounty math (25 a level,
## 250 in all, each tier once), Progress (heat unlocks with the plain hard clear, complete_heat pays
## once, EMBER on heat 7 everywhere, saves/codes/hostile values/reset), every modifier's effect in a
## real hard level, the win flow (bounty on the result, medals and records kept, dev toggles pay
## nothing, no heat outside hard story levels), and winnability: every pickable mask on every hard
## level by the numbers (a perfect route's meter x THIRSTY, a perfect walk's time vs RACE), plus the
## test autopilot walking all 10 hard levels at heat 10 (the hardest mask) and heat 9 (BRITTLE in
## place of GROUNDED) on levels 1-3. Prints the tightest margins.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_heat.gd

const MAIN := preload("res://scenes/main.tscn")
const AUTOPILOT := preload("res://tests/autopilot.gd")
const TEST_SAVE := "user://test_save_heat.cfg"
const Main := preload("res://scripts/game.gd")

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_table()
	_bounties()
	_state()
	_progress_rules()
	_saves()
	await _level_select()
	await _effects()
	await _win_flow()
	await _winnable()
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _state() -> void:
	progress.reset_progress()
	progress.saving_enabled = true
	progress.dev_tools = false
	progress.story_seen = 3
	progress.tutorial_seen = 3
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	progress.hard_mode = true
	progress.hard_cleared.assign(range(1, Levels.COUNT + 1))


func _table() -> void:
	var expect := {dim = 1, brittle = 1, fog = 2, grounded = 2, thirsty = 2, race = 3}
	for id: String in expect:
		_check(Heat.heat_of(id) == expect[id], "%s is heat %d" % [id, expect[id]])
		_check(Heat.NAMES.has(id) and Heat.ABOUT.has(id) and Heat.icon(id).get_size() == (Vector2(8, 8) if id == "race" else Vector2(9, 9)), "%s has a name, an about line and a 9x9 icon (RACE 8x8: an even pod)" % id)
	var masks := Heat.masks()
	var top := 0
	for mask in masks:
		top = maxi(top, Heat.points(mask))
		_check(not (Heat.has(mask, "brittle") and Heat.has(mask, "grounded")), "mask %d never has BRITTLE + GROUNDED" % mask)
	_check(masks.size() == 48, "48 pickable masks of 64 (%d)" % masks.size())
	_check(top == Economy.HEAT_MAX and Economy.HEAT_MAX == 10, "max heat 10 (%d)" % top)
	_check(Heat.points(Heat.ALL) == 11 and Heat.points(Heat.sanitize(Heat.ALL)) == 10, "all six would be 11; sanitized (no BRITTLE) 10")
	var g := Heat.bit("grounded")
	var b := Heat.bit("brittle")
	_check(Heat.toggle(b, "grounded") == g, "switching GROUNDED on drops BRITTLE")
	_check(Heat.toggle(g, "brittle") == g and Heat.blocked(g, "brittle"), "BRITTLE can't go on while GROUNDED is on")
	_check(Heat.toggle(g, "grounded") == 0 and Heat.toggle(0, "brittle") == b, "toggling flips a bit")
	_check(Heat.sanitize(-1) == Heat.sanitize(Heat.ALL) and Heat.sanitize(1 << 9) == 0 and Heat.toggle(0, "nope") == 0, "sanitize drops unknown bits")
	_check(Heat.flame(0) != Heat.flame(2) and Heat.flame(1) == Heat.flame(2) and Heat.flame(10) != Heat.flame(7) and Heat.flame(9) == Heat.flame(7), "flames: grey, then one look per tier")
	var fx := Heat.effects(0)
	_check(fx.relight < 0.0 and fx.fade == 1.0 and fx.refog == 1.0 and fx.splat == 1.0 and not fx.slide and not fx.grounded and fx.drain == 1.0 and fx.race == 0.0, "no heat: no effect")


func _bounties() -> void:
	_check(Heat.bounty(0, 2) == 3 and Heat.bounty(0, 4) == 8 and Heat.bounty(0, 7) == 15 and Heat.bounty(0, 10) == 25, "bounties 3 / +5 / +7 / +10")
	_check(Heat.bounty(2, 4) == 5 and Heat.bounty(3, 7) == 12 and Heat.bounty(7, 7) == 0 and Heat.bounty(9, 3) == 0 and Heat.bounty(0, 1) == 0, "only newly crossed tiers pay")
	_check(Heat.level_bounty() == 25 and Heat.total_bounty() == 250, "25 a level, 250 in all")
	_check(Heat.tier_of(1) == 0 and Heat.tier_of(3) == 2 and Heat.tier_of(6) == 4 and Heat.tier_of(9) == 7 and Heat.tier_of(10) == 10, "tiers")


func _progress_rules() -> void:
	_state()
	progress.hard_cleared.assign([1, 2])
	progress.tickets = 0
	_check(progress.complete_heat(3, 10).paid == 0 and progress.best_heat(3) == 0, "no heat on a level not yet cleared on hard")
	_check(progress.heat_for_run(3) == 0, "...and a run there plays without it")
	progress.heat_mods = Heat.bit("race") | Heat.bit("dim")
	_check(progress.heat_for_run(1) == progress.heat_mods, "a hard-cleared level plays with the picked modifiers")
	progress.hard_mode = false
	_check(progress.heat_for_run(1) == 0, "never in normal mode")
	progress.hard_mode = true
	var r: Dictionary = progress.complete_heat(1, 2)
	_check(r.paid == 3 and r.new_best and progress.tickets == 3 and progress.best_heat(1) == 2, "heat 2 pays 3 (%s)" % [r])
	r = progress.complete_heat(1, 2)
	_check(r.paid == 0 and not r.new_best and progress.tickets == 3, "the same heat again pays nothing")
	r = progress.complete_heat(1, 1)
	_check(r.paid == 0 and progress.best_heat(1) == 2, "a lower heat changes nothing")
	r = progress.complete_heat(1, 7)
	_check(r.paid == 12 and progress.tickets == 15 and progress.best_heat(1) == 7, "heat 7 pays the 4 and 7 tiers (12)")
	r = progress.complete_heat(1, 10)
	_check(r.paid == 10 and progress.tickets == 25 and progress.heat_paid == 25, "heat 10 pays the last 10: 25 for the level")
	_check(progress.complete_heat(1, 10).paid == 0 and progress.tickets == 25, "never again")
	_check(progress.complete_heat(2, 99).best == 10 and progress.tickets == 50, "heat clamps to 10")
	_check(progress.heat_total() == 20 and progress.heat_levels_at(7) == 2, "HEAT 20/100")
	_check(not progress.owns_cosmetic("ember") and not progress.cosmetic_earned("ember"), "no EMBER yet")
	progress.hard_cleared.assign(range(1, Levels.COUNT + 1))
	for level in range(3, Levels.COUNT):
		progress.complete_heat(level, 7)
	_check(not progress.owns_cosmetic("ember"), "9 of 10 levels at heat 7: still no EMBER")
	r = progress.complete_heat(Levels.COUNT, 8)
	_check(r.ember and progress.owns_cosmetic("ember") and progress.cosmetic_earned("ember"), "the tenth level at heat 7+ earns EMBER")
	_check(not "ember" in Cosmetics.ids() and "ember" in Cosmetics.trail_ids() and not progress.can_buy_cosmetic("ember") and Cosmetics.is_earned("ember"), "EMBER is earned, never sold, but in the wardrobe")
	_check(progress.equip_cosmetic("ember") and progress.trail_style == "ember", "and can be worn")
	_check(progress.tickets == 25 + 25 + 7 * 15 + 15 and progress.heat_paid == progress.tickets, "every bounty counted (%d)" % progress.tickets)
	_check(not progress.heat_crown(), "no flame crown below heat 10 everywhere")
	for level in range(1, Levels.COUNT + 1):
		progress.complete_heat(level, 10)
	_check(progress.heat_crown() and progress.tickets == 250 and progress.heat_paid == 250 and progress.heat_total() == 100, "all at 10: the crown, 250 tickets in all, HEAT 100/100")


func _saves() -> void:
	_state()
	progress.heat_mods = Heat.bit("fog") | Heat.bit("thirsty")
	progress.heat_best = {1: 10, 2: 7, 5: 4}
	progress.heat_paid = 25 + 15 + 8
	var file: ConfigFile = progress._write()
	_check(file.get_value("settings", "heat_mods") == progress.heat_mods and file.get_value("heat", "level_2") == 7 and file.get_value("heat", "paid") == 48, "written: [settings] heat_mods, [heat] level_N, paid")
	_state()
	progress._read(file)
	_check(progress.heat_mods == Heat.bit("fog") | Heat.bit("thirsty") and progress.best_heat(1) == 10 and progress.best_heat(2) == 7 and progress.best_heat(5) == 4 and progress.heat_paid == 48, "read back exactly")
	# Defaults: a save without the keys.
	var empty := ConfigFile.new()
	empty.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	empty.set_value("progress", "hard_cleared", [1, 2, 3])
	progress._read(empty)
	_check(progress.heat_mods == 0 and progress.heat_best.is_empty() and progress.heat_paid == 0, "missing keys default to no heat")
	_check(not progress._write().has_section("heat") and not progress._write().has_section_key("settings", "heat_mods"), "an unused HEAT writes nothing")
	# Hostile values.
	var bad := ConfigFile.new()
	bad.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	bad.set_value("progress", "hard_cleared", [1, 2, 3])
	bad.set_value("settings", "heat_mods", Heat.bit("brittle") | Heat.bit("grounded") | (1 << 12))
	bad.set_value("heat", "level_1", 99)
	bad.set_value("heat", "level_2", -4)
	bad.set_value("heat", "level_3", "hot")
	bad.set_value("heat", "level_4", 10)  # not cleared on hard: impossible
	bad.set_value("heat", "level_11", 10)
	bad.set_value("heat", "paid", 9999)
	bad.set_value("cosmetics", "owned", ["ember", "gold"])
	bad.set_value("cosmetics", "trail", "ember")
	progress._read(bad)
	_check(progress.heat_mods == Heat.bit("grounded"), "a mask with BRITTLE + GROUNDED and junk bits is sanitized (%d)" % progress.heat_mods)
	_check(progress.best_heat(1) == 10 and progress.best_heat(2) == 0 and progress.best_heat(3) == 0 and progress.best_heat(4) == 0 and not progress.heat_best.has(11), "best heats clamp 0-10, need the hard clear, junk is 0 (%s)" % [progress.heat_best])
	_check(progress.heat_paid == 25, "paid clamps to what the bests could have paid (%d)" % progress.heat_paid)
	_check(not progress.owns_cosmetic("ember") and progress.owns_cosmetic("gold") and progress.trail_style == Cosmetics.DEFAULT_TRAIL, "an EMBER trail without heat 7 everywhere is refused on load")
	bad.set_value("settings", "heat_mods", -7)
	progress._read(bad)
	_check(Heat.valid(progress.heat_mods), "a negative mask reads as a valid one")
	# EMBER kept with its condition.
	var good := ConfigFile.new()
	good.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	good.set_value("progress", "hard_cleared", range(1, Levels.COUNT + 1))
	for level in range(1, Levels.COUNT + 1):
		good.set_value("heat", "level_%d" % level, 7)
	good.set_value("cosmetics", "owned", ["ember"])
	good.set_value("cosmetics", "trail", "ember")
	progress._read(good)
	_check(progress.owns_cosmetic("ember") and progress.trail_style == "ember", "EMBER with heat 7 everywhere stays")
	# The save code carries it all, and stays small.
	progress.heat_mods = Heat.bit("race") | Heat.bit("dim")
	progress.heat_paid = 150
	var code: String = progress.save_code()
	var back: ConfigFile = progress.read_code(code)
	_check(back != null and back.get_value("settings", "heat_mods") == progress.heat_mods and back.get_value("heat", "level_10") == 7 and back.get_value("heat", "paid") == 150, "the save code round-trips HEAT")
	_check(code.length() < 4000, "the save code stays small with HEAT (%d chars)" % code.length())
	_state()
	progress._read(back)
	_check(progress.best_heat(10) == 7 and progress.owns_cosmetic("ember") and progress.heat_mods == Heat.bit("race") | Heat.bit("dim"), "and loads back")
	# Text through the allow-list validator.
	var text: String = progress._write().encode_to_text()
	var parsed: ConfigFile = preload("res://scripts/save_text.gd").parse(text.to_utf8_buffer())
	_check(parsed != null and parsed.get_value("heat", "level_3") == 7, "the save text passes the validator")
	# RESET PROGRESS clears HEAT.
	progress.reset_progress()
	_check(progress.heat_mods == 0 and progress.heat_best.is_empty() and progress.heat_paid == 0 and not progress.owns_cosmetic("ember"), "RESET PROGRESS clears HEAT")


## The level select's HEAT button and panel with real input: Enter opens it (focus on the first
## toggle, the rest of the screen locked), Enter / clicks flip toggles (saved, total updates),
## GROUNDED greys BRITTLE out, Esc closes the panel (focus back on HEAT) before leaving the screen,
## a click outside closes it; the button hides with HARD MODE off; the hub pod shows HEAT n/100.
func _level_select() -> void:
	_state()
	progress.heat_mods = 0
	progress.heat_best = {1: 10, 2: 4}
	var screen: Control = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	var panel: Control = screen.heat_panel
	_check(screen.heat_button.visible and screen.heat_button.text == "HEAT 0", "hard mode: a HEAT 0 button")
	_check(screen.info.text == screen.INFO_HARD, "hard mode: the info lines name the bounties")
	screen.heat_button.grab_focus()
	await _key(KEY_ENTER)
	_check(panel.visible and panel.toggles["dim"].has_focus(), "Enter opens the panel, focus on DIM")
	_check(screen.level_buttons[0].focus_mode == Control.FOCUS_NONE and screen.heat_button.focus_mode == Control.FOCUS_NONE, "the screen under it is focus-locked")
	await _key(KEY_ENTER)
	_check(progress.heat_mods == Heat.bit("dim") and panel.title.text == "HEAT 1/10" and panel.toggles["dim"].get_node("Check").visible, "Enter on DIM turns it on: HEAT 1/10")
	await _key(KEY_RIGHT)
	_check(panel.toggles["brittle"].has_focus() and panel.about.text == Heat.ABOUT.brittle, "arrows move between toggles; the about line follows")
	await _key(KEY_ENTER)
	await _click(panel.toggles["grounded"])
	_check(progress.heat_mods == Heat.bit("dim") | Heat.bit("grounded") and panel.toggles["brittle"].disabled, "GROUNDED drops BRITTLE and greys it out (%d)" % progress.heat_mods)
	await _click(panel.toggles["brittle"])
	_check(progress.heat_mods == Heat.bit("dim") | Heat.bit("grounded"), "a click on the greyed BRITTLE does nothing")
	var file := ConfigFile.new()
	_check(file.load(TEST_SAVE) == OK and file.get_value("settings", "heat_mods", 0) == progress.heat_mods, "toggles are saved at once")
	await _key(KEY_ESCAPE)
	_check(not panel.visible and screen.heat_button.has_focus() and screen.heat_button.text == "HEAT 3" and current_scene == screen, "Esc closes the panel only, focus back on HEAT 3")
	_check(screen.level_buttons[0].focus_mode != Control.FOCUS_NONE, "the screen is unlocked again")
	screen._open_heat()
	await process_frame
	await _click_at(Vector2(5, 5))
	_check(not panel.visible, "a click outside the panel closes it")
	screen._open_heat()
	await process_frame
	await _click(panel.done_button)
	_check(not panel.visible, "DONE closes it")
	var flame: TextureRect = screen.level_buttons[0].get_node_or_null("Flame")
	_check(flame != null and flame.texture == Heat.flame(10) and screen.level_buttons[1].get_node("Flame").texture == Heat.flame(4) and screen.level_buttons[2].get_node_or_null("Flame") == null, "tile flames show the best heat tier")
	screen.hard_mode_box.button_pressed = false
	await process_frame
	_check(not screen.heat_button.visible and screen.level_buttons[0].get_node_or_null("Flame") == null and screen.info.text == screen.INFO_NORMAL, "normal mode: no HEAT button, no flames")
	current_scene = null
	screen.free()
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	_check(hub.heat_label.visible and hub.heat_label.text == "14/100", "the hub pod shows HEAT 14/100 (%s)" % hub.heat_label.text)
	hub.free()
	progress.heat_best = {}
	hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	_check(not hub.heat_label.visible, "...and nothing before any heat clear")
	hub.free()
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	_check(title.get_node_or_null("CrownFlame0") == null, "no flame crown on the title")
	title.free()
	for level in range(1, Levels.COUNT + 1):
		progress.heat_best[level] = 10
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	_check(title.get_node_or_null("CrownFlame0") != null, "heat 10 everywhere: the title's flame crown")
	title.free()
	progress.heat_best = {}
	progress.heat_mods = 0


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame


func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame


## One hard level with `mask` picked; physics stopped so the test can drive it (frames: let it start).
func _spawn(level: int, mask: int, frames := 1) -> Node2D:
	progress.heat_mods = mask
	progress.start_story(level)
	var game: Node2D = MAIN.instantiate()
	game.level = level
	root.add_child(game)
	for i in frames:
		await physics_frame
	return game


func _effects() -> void:
	_state()
	progress.saving_enabled = false
	var plain := await _spawn(2, 0)
	_check(plain.heat == 0 and plain.relight_radius == 20.0 and plain.fade_after == Main.FADE_AFTER and plain.refog_after == 9.0 \
		and plain.splat_factor == 1.0 and plain.slime.can_charge and plain.race_limit == 0.0 and plain.hud.heat_pod == null, "heat 0: the hard level as before")
	var base_cost: float = plain.slime_cost_per_tile
	var par: float = plain.par_time
	var mat := plain.fog_sprite.material as ShaderMaterial
	_check(mat.get_shader_parameter("refog_after") == 9.0 and mat.get_shader_parameter("fade_after") == Vector4(1.5, 3.5, 6.0, 9.0), "the fog shader's steps are the plain ones")
	_check(_relit_behind(plain), "plain: the cell 16 px behind stays lit")
	_check(plain.fog_alpha_at(_start_pos(plain)) < 1.0, "plain: 5 s later the start is dim, not fogged")
	plain.free()

	var dim := await _spawn(2, Heat.bit("dim"))
	_check(dim.heat == 1 and dim.relight_radius == 10.0 and is_equal_approx(dim.fade_after[0], 0.9) and is_equal_approx(dim.fade_after[3], 5.4) and is_equal_approx(dim.refog_after, 5.4), "DIM: relight 10 px, fade steps x0.6 (%s)" % [dim.fade_after])
	_check(not _relit_behind(dim), "DIM: the cell 16 px behind is not kept lit")
	mat = dim.fog_sprite.material as ShaderMaterial
	_check(is_equal_approx(float(mat.get_shader_parameter("refog_after")), 5.4) and is_equal_approx((mat.get_shader_parameter("fade_after") as Vector4).x, 0.9), "DIM: the shader gets the shorter steps")
	_check(dim.slime_light.texture.get_width() < 100 and dim._lazy_ticks < Main.LAZY_RELIGHT_TICKS, "DIM: a smaller lantern; lazy uploads follow the shorter first step")
	_check(dim.hud.heat_pod.visible and dim.hud.heat_label.text == "HEAT 1" and dim.hud.heat_icons == ["dim"], "the HUD shows HEAT 1 and the moon")
	dim.free()

	var fog := await _spawn(2, Heat.bit("fog"))
	_check(fog.heat == 2 and is_equal_approx(fog.refog_after, 4.5) and fog.fade_after == Main.FADE_AFTER, "FOG BITES: fog returns after 4.5 s")
	_relit_behind(fog)
	_check(fog.fog_alpha_at(_start_pos(fog)) == 1.0, "FOG BITES: 5 s later the start is fog again")
	fog.free()
	var both := await _spawn(2, Heat.bit("fog") | Heat.bit("dim"))
	_check(is_equal_approx(both.refog_after, 2.7), "DIM + FOG BITES: 2.7 s")
	both.free()

	var brittle := await _spawn(2, Heat.bit("brittle"))
	var plain2 := await _spawn(2, 0)
	_check(brittle.splat_factor == 2.0 and brittle.slide_drains and not plain2.slide_drains, "BRITTLE: splats x2, the slide drains")
	var cost_b := _splat_cost(brittle)
	var cost_p := _splat_cost(plain2)
	_check(is_equal_approx(cost_b - cost_p, Main.splat_penalty(64.0)), "BRITTLE: a splat costs one more penalty (%.2f vs %.2f)" % [cost_b, cost_p])
	_check(_slide_cost(brittle) > 0.0 and _slide_cost(plain2) == 0.0, "BRITTLE: the knockback slide costs slime (free without)")
	brittle.free()
	plain2.free()

	var grounded := await _spawn(2, Heat.bit("grounded"), 3)
	_check(grounded.heat == 2 and not grounded.slime.can_charge and not grounded.touch_controls.jump_enabled, "GROUNDED: no charging, the touch JUMP struck out")
	Input.action_press("jump")
	for i in 30:
		await physics_frame
	_check(grounded.slime.state == Slime.State.GLIDE and grounded.slime.charge == 0.0, "GROUNDED: holding jump never charges a leap")
	Input.action_release("jump")
	await physics_frame
	grounded.free()

	var thirsty := await _spawn(2, Heat.bit("thirsty"))
	_check(is_equal_approx(thirsty.slime_cost_per_tile, base_cost * 1.08) and is_equal_approx(thirsty.par_time, par), "THIRSTY: drain x1.08, par unchanged")
	_check(is_equal_approx(thirsty.splat_factor, 1.08), "THIRSTY: splat penalties x1.08 too (%.3f)" % thirsty.splat_factor)
	thirsty.free()
	var thirsty_brittle := await _spawn(2, Heat.bit("thirsty") | Heat.bit("brittle"))
	_check(is_equal_approx(thirsty_brittle.splat_factor, 2.16), "THIRSTY + BRITTLE: splats x2.16 (%.3f)" % thirsty_brittle.splat_factor)
	thirsty_brittle.free()

	var race := await _spawn(2, Heat.bit("race"), 2)
	_check(race.heat == 3 and is_equal_approx(race.race_limit, par * 1.3), "RACE: a countdown of 1.3 x par (%.1f s)" % race.race_limit)
	_check(race.hud.countdown > 0.0 and race.hud.time_label.text == UIKit.format_time(race.race_limit - race.run_time), "RACE: the timer counts down (%s)" % race.hud.time_label.text)
	race.run_time = race.race_limit - 0.01
	for i in 3:
		await physics_frame
	_check(race.finished and not race.won and race.hud.message.text.begins_with("OUT OF TIME"), "RACE: at 0 the slime dries up (%s)" % race.hud.message.text)
	race.free()

	# A leap launched before 0:00 that lands on the chalice after it: no win, no bounty.
	var late := await _spawn(2, Heat.bit("race"), 2)
	var tickets_before: int = progress.tickets
	var best_before: int = progress.best_heat(2)
	late.run_time = late.race_limit + 0.2
	late.race_over = false
	late._on_goal_body_entered(late.slime)
	_check(late.finished and not late.won and late.hud.message.text.begins_with("OUT OF TIME"), "RACE: the chalice after 0:00 is no win (%s)" % late.hud.message.text)
	_check(progress.tickets == tickets_before and progress.best_heat(2) == best_before and late.heat_result.is_empty(), "RACE: a late landing pays no bounty and sets no best heat")
	late.free()
	var inside := await _spawn(2, Heat.bit("race"), 2)
	inside.run_time = inside.race_limit - 1.0
	inside._on_goal_body_entered(inside.slime)
	_check(inside.finished and inside.won and not inside.race_over, "RACE: just inside the limit the chalice still wins")
	inside.free()
	var pod := await _spawn(2, Heat.bit("race"), 2)
	var pod_row: Control = pod.hud._clock_icon.get_parent()
	_check(int(pod_row.get_combined_minimum_size().x) % 2 == 0, "RACE: the timer pod's content stays even (%s)" % pod_row.get_combined_minimum_size())
	pod.free()

	var top := await _spawn(2, Heat.sanitize(Heat.ALL))
	_check(top.heat == 10 and top.hud.heat_label.text == "HEAT 10" and top.hud.heat_icons.size() == 5, "all on: HEAT 10, five icons")
	top.free()
	# Where heat never applies.
	progress.hard_cleared.assign([1])
	var fresh := await _spawn(2, Heat.sanitize(Heat.ALL))
	_check(fresh.heat == 0 and fresh.slime.can_charge, "a level not yet cleared on hard plays without heat")
	fresh.free()
	progress.hard_mode = false
	var normal := await _spawn(1, Heat.sanitize(Heat.ALL))
	_check(normal.heat == 0 and normal.relight_radius == 20.0, "normal mode: no heat")
	normal.free()
	progress.hard_mode = true
	progress.start_random()
	progress.heat_mods = Heat.sanitize(Heat.ALL)
	var random: Node2D = MAIN.instantiate()
	root.add_child(random)
	await physics_frame
	_check(random.is_random() and random.hard_mode and random.heat == 0, "the hard randomizer: no heat")
	random.free()
	progress.mode = progress.MODE_STORY
	progress.heat_mods = 0


## Walks the slime one cell along the route (teleported, physics off), 2 s later: true if the start
## cell (16 px behind) was relit. Then moves 5 s on so fog_alpha_at(start) shows the fade / refog.
func _relit_behind(game: Node2D) -> bool:
	game.set_physics_process(false)
	game.set_process(false)
	var path: Array = MazeGenerator.shortest_path(game.maze, game.maze.start, game.maze.goal)
	var next := (MazeGenerator.cell_center(path[0], Main.TILE) + MazeGenerator.cell_center(path[1], Main.TILE)) / 2.0  # 16 px on
	game.elapsed += 2.0
	game._paint_goo(next, Main.TRAIL_RADIUS)
	game._relight(next)
	var lit: bool = game.fog_alpha_at(_start_pos(game)) == 0.0
	game.elapsed += 5.0
	var far := MazeGenerator.cell_center(path[mini(4, path.size() - 1)], Main.TILE)
	game._relight(far)
	return lit


func _start_pos(game: Node2D) -> Vector2:
	return MazeGenerator.cell_center(game.maze.start, Main.TILE)


## Slime a full-ish leap into a wall costs (physics off).
func _splat_cost(game: Node2D) -> float:
	game.set_physics_process(false)
	game.slime_remaining = 100.0
	game.slime.last_jump_traveled = 32.0
	game._on_jump_landed(64.0, true, Vector2.LEFT)
	return 100.0 - game.slime_remaining


## Slime 8 px of knockback slide costs (one game tick driven by hand, the slime's own physics off).
func _slide_cost(game: Node2D) -> float:
	game.set_physics_process(false)
	game.slime.set_physics_process(false)
	game.finished = false
	game.slime_remaining = 50.0
	game.last_slime_pos = game.slime.position
	game.slime.knocked_back = true
	game.slime.position += Vector2(8, 0)
	game._physics_process(1.0 / 60.0)
	return 50.0 - game.slime_remaining


func _win_flow() -> void:
	_state()
	progress.tickets = 0
	var mask := Heat.bit("fog") | Heat.bit("dim") | Heat.bit("race")  # heat 6: tiers 2 and 4
	var game := await _spawn(3, mask)
	current_scene = game
	game.run_time = 10.0
	game._on_goal_body_entered(game.slime)
	_check(game.heat_result.paid == 8 and progress.tickets == 8 and progress.best_heat(3) == 6, "a heat 6 clear pays 3 + 5 (%s)" % [game.heat_result])
	_check(game.hud.heat_row.visible and "HEAT 6" in game.hud.heat_texts and "BOUNTY +8" in game.hud.heat_texts, "the result shows HEAT 6 and BOUNTY +8 (%s)" % [game.hud.heat_texts])
	_check(progress.medals_for(3) == progress.TIER_GOLD and is_equal_approx(progress.best_time(3), 10.0), "heat runs keep hard medals and records (%d, %.1f)" % [progress.medals_for(3), progress.best_time(3)])
	var on_disk := ConfigFile.new()
	_check(on_disk.load(TEST_SAVE) == OK and on_disk.get_value("heat", "level_3", 0) == 6, "saved with the clear")
	current_scene = null
	game.free()
	game = await _spawn(3, mask)
	current_scene = game
	game.run_time = 12.0
	game._on_goal_body_entered(game.slime)
	_check(game.heat_result.paid == 0 and progress.tickets == 8 and "BEST HEAT 6" in game.hud.heat_texts, "the same heat again: nothing (%s)" % [game.hud.heat_texts])
	current_scene = null
	game.free()
	# Dev toggles pay nothing (dev mode, FULL BRIGHT used).
	progress.dev_tools = true
	game = await _spawn(4, Heat.sanitize(Heat.ALL))
	current_scene = game
	game.set_dev_bright(true)
	game._on_goal_body_entered(game.slime)
	_check(progress.best_heat(4) == 0 and progress.tickets == 8 and game.hud.heat_texts == ["HEAT 10"], "dev toggles: no bounty, no best heat (%s)" % [game.hud.heat_texts])
	current_scene = null
	game.free()
	progress.dev_tools = false
	progress.dev_bright = false
	# A heat-10 clear on a fresh level pays all 25 (and NEW BEST HEAT shows when no tier is crossed).
	game = await _spawn(5, Heat.sanitize(Heat.ALL))
	current_scene = game
	game._on_goal_body_entered(game.slime)
	_check(game.heat_result.paid == 25 and progress.tickets == 33, "heat 10 on a fresh level pays 25")
	current_scene = null
	game.free()
	game = await _spawn(6, Heat.bit("dim"))
	current_scene = game
	game._on_goal_body_entered(game.slime)
	_check(game.heat_result.paid == 0 and "NEW BEST HEAT!" in game.hud.heat_texts and progress.best_heat(6) == 1, "heat 1: a new best, no tier yet")
	current_scene = null
	game.free()
	progress.saving_enabled = false


## Winnability. By the numbers, for every pickable mask on every hard level: a perfect route's meter
## x THIRSTY stays under 100%, and a perfect walk (the autopilot's time, measured at heat 0) beats
## RACE. In game: the autopilot walks every level at heat 10 (DIM, FOG BITES, GROUNDED, THIRSTY, RACE)
## and levels 1-3 at heat 9 (BRITTLE for GROUNDED).
func _winnable() -> void:
	_state()
	progress.saving_enabled = false
	var drain: float = Economy.HEAT_MODS.thirsty.drain
	var limit: float = Economy.HEAT_MODS.race.limit
	var worst_meter := 0.0
	var worst_time := 0.0
	var top := Heat.sanitize(Heat.ALL)
	var nine := Heat.sanitize(Heat.ALL) & ~Heat.bit("grounded") | Heat.bit("brittle")
	for level in range(1, Levels.COUNT + 1):
		var game := await _spawn(level, top)
		game.add_child(AUTOPILOT.new())
		for i in 60 * 150:
			if game.finished:
				break
			await physics_frame
		var used: float = 100.0 - game.slime_remaining
		var perfect: float = game.perfect_usage * 100.0  # x THIRSTY already: the route at this run's cost
		var meter_margin: float = 100.0 - used
		var time_margin: float = 1.0 - game.run_time / game.race_limit
		print("  L%2d heat 10: walk uses %.1f%% (perfect route %.1f%%), %.1f s of %.1f s RACE (par %.1f)" % [level, used, perfect, game.run_time, game.race_limit, game.par_time])
		_check(game.won, "hard level %d is won at heat 10 by the autopilot walking" % level)
		# Every mask: the meter factor is 1 or THIRSTY's, the time limit none or RACE's.
		for mask in Heat.masks():
			var f := drain if Heat.has(mask, "thirsty") else 1.0
			var need := perfect / drain * f
			if need >= 100.0 or (Heat.has(mask, "race") and game.run_time >= game.par_time * limit):
				_check(false, "L%d mask %d is not winnable by a perfect walk" % [level, mask])
				break
		worst_meter = maxf(worst_meter, used)
		worst_time = maxf(worst_time, game.run_time / game.race_limit)
		_check(meter_margin > 3.0 and time_margin > 0.2, "L%d heat 10 margins: %.1f%% slime left, %.0f%% of the countdown left" % [level, meter_margin, time_margin * 100.0])
		game.free()
		if level <= 3:
			game = await _spawn(level, nine)
			game.add_child(AUTOPILOT.new())
			for i in 60 * 150:
				if game.finished:
					break
				await physics_frame
			_check(game.won and game.heat == 9, "hard level %d is won at heat 9 (BRITTLE, no GROUNDED)" % level)
			game.free()
	print("  tightest: the walk uses %.1f%% of the meter at heat 10; slowest walk %.0f%% of the RACE countdown" % [worst_meter, worst_time * 100.0])


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
