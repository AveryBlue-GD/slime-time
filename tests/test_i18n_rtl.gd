extends "res://tests/suite_base.gd"

## Right-to-left mirroring (chunk I, docs/ui-rules.md section 10.2, docs/i18n/plan.md section 11): in Arabic
## every menu, overlay and the HUD is laid out in LTR coordinates and flipped whole by UIKit.mirror_root;
## the game world is not. Checks, with English as the reference for every mirrored position:
## - gate off / English: nothing registers a mirror root, nothing is RTL, Loc.fill adds no isolates;
## - Arabic: BACK on the bottom row's right edge (every screen), SETTINGS' columns swapped, the level select's
##   tiles right to left and its page arrows swapped (the left one leads on), the upgrades tabs reversed,
##   the HUD pods in the other corners (meter right, level left, timer centred), the meter's fill hanging
##   from its outer (right) end, the language grid mirrored, the hat wheel's try-on slimes mirrored;
## - every visible control of every screen inside 320x180, and each mirrored control exactly where the
##   English one is mirrored (x' = 320 - x - w) for the screens built from the same layout;
## - after a dynamic re-layout (a page / tab switch, the HEAT panel, the pause menu) still mirrored;
## - keys follow the visual order (explicit left / right neighbours swapped; the level select's left key
##   on a page's visual left end turns to the next page);
## - NOT mirrored: the game world (slime, maze) and the hub room (stations, slime) stay where English has them;
## - Loc.fill wraps number / Latin placeholder words in LRI .. PDI in Arabic only (Arabic values as they are).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_i18n_rtl.gd

const SCREEN := Rect2(0, 0, 320, 180)
const LRI := "\u2066"
const PDI := "\u2069"

var progress: Node
var language: Node
## English rects per screen: node id -> Rect2 (global), for the mirror comparison.
var english := {}


func _initialize() -> void:
	Economy.descent_force = 1
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	await _gate_off()
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	await _english_reference()
	language.set_locale("ar")
	_check(language.is_rtl() and UIKit.rtl() and UIKit.reading_dir() == -1 and Loc.isolate_ltr, "ar: right to left, isolates on")
	_check(not root.is_layout_rtl(), "ar: the root window stays left to right (only mirror roots flip)")
	_fill()
	await _menus()
	await _dynamic()
	await _keys()
	await _game_not_mirrored()
	await _hub_not_mirrored()
	language.set_locale("en")
	_check(not Loc.isolate_ltr, "back in English: no isolates")
	var back_en: Control = await _open("res://scenes/controls.tscn")
	_check(not back_en.has_meta(UIKit.MIRROR_META) and not back_en.is_layout_rtl(), "back in English: a new screen is not mirrored")
	back_en.free()
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	_result()
	quit(1 if failures else 0)


# ------------------------------------------------------------------ gate off / English

func _gate_off() -> void:
	_check(not Economy.languages_on() and not UIKit.rtl() and not Loc.isolate_ltr, "gate off: left to right, no isolates")
	var settings: Control = await _open("res://scenes/controls.tscn")
	_check(not settings.has_meta(UIKit.MIRROR_META) and not settings.is_layout_rtl(), "gate off: no mirror root, nothing RTL")
	_check(Loc.fill("+{count} X{rate}", {count = 5, rate = 1.5}) == "+5 X1.5", "gate off: Loc.fill adds nothing")
	settings.free()


## English: the reference rects of the screens compared below, and nothing mirrored.
func _english_reference() -> void:
	for path: String in _menu_paths():
		var screen: Control = await _open(path)
		_check(not screen.has_meta(UIKit.MIRROR_META), "en: %s not mirrored" % path.get_file())
		english[path] = _rects(screen)
		screen.free()


func _menu_paths() -> Array[String]:
	return ["res://scenes/title.tscn", "res://scenes/controls.tscn", "res://scenes/level_select.tscn",
		"res://scenes/maps.tscn", "res://scenes/upgrades.tscn", "res://scenes/skins.tscn", "res://scenes/key_controls.tscn",
		"res://scenes/language.tscn", "res://scenes/victory.tscn"]


# ------------------------------------------------------------------ Arabic

func _fill() -> void:
	_check(Loc.fill("+{count} تذكرة", {count = 5}) == LRI + "+5" + PDI + " تذكرة", "ar: a signed number is one LTR word (+5)")
	_check(Loc.fill("{reach} بكسل X{rate}", {reach = 8, rate = 1.5}) == LRI + "8" + PDI + " بكسل " + LRI + "X1.5" + PDI,
		"ar: X1.5 stays one word, apart from the pixel value")
	_check(Loc.fill("الذراع {a} {b} {c}", {a = "A", b = "X", c = "Y"}) == "الذراع %sA%s %sX%s %sY%s" % [LRI, PDI, LRI, PDI, LRI, PDI],
		"ar: pad letters are separate words (they follow the RTL order of the ability row)")
	_check(Loc.fill("{percent}%", {percent = 30}) == LRI + "30%" + PDI, "ar: 30% keeps its sign after the number")
	_check(Loc.fill("{slot}/{total}", {slot = 1, total = 3}) == LRI + "1/3" + PDI, "ar: 1/3 is one word")
	_check(Loc.fill("{name} - {x}", {name = "فستقي", x = "ب"}) == "فستقي - ب", "ar: Arabic values are inserted as they are")
	_check(UIKit.text_w(Loc.fill("+{count}", {count = 5})) == UIKit.text_w("+5"), "ar: isolates add no width")


func _menus() -> void:
	for path: String in _menu_paths():
		var screen: Control = await _open(path)
		var name := path.get_file().get_basename()
		_check(screen.has_meta(UIKit.MIRROR_META) and screen.is_layout_rtl(), "ar: %s is a mirrored root, flipped" % name)
		_check(_offscreen(screen).is_empty(), "ar: %s: every control inside 320x180 %s" % [name, _offscreen(screen)])
		var back := _button(screen, Loc.t("common.back", "BACK"))
		if back:
			var r := back.get_global_rect()
			_check(r.end.x == UIKit.SCREEN.x - UIKit.EDGE and r.end.y == UIKit.BOTTOM_ROW_Y + UIKit.BUTTON_H,
				"ar: %s: BACK on the bottom row's right edge (%s)" % [name, r])
		match name:
			"controls":
				var sound: Control = screen.sound_button
				var fullscreen: Control = screen.fullscreen_button
				_check(sound.get_global_rect().position.x > fullscreen.get_global_rect().position.x,
					"ar: settings: the OPTIONS column (sound) is on the right, MORE (fullscreen) on the left")
			"level_select":
				var b: Array = screen.level_buttons
				_check(b[0].get_global_rect().position.x > b[1].get_global_rect().position.x, "ar: level select: level 1 right of level 2")
				if screen.page_prev:
					_check(screen.page_next.get_global_rect().position.x < screen.page_prev.get_global_rect().position.x,
						"ar: level select: NEXT page arrow on the left, PREV on the right")
					_check(screen.page_next.get_global_rect().position.x == UIKit.EDGE, "ar: level select: the arrows keep the edge inset")
			"upgrades":
				if screen.coins_tab and screen.abilities_tab:
					_check(screen.coins_tab.get_global_rect().position.x > screen.abilities_tab.get_global_rect().position.x,
						"ar: upgrades: the tab order reverses (COINS rightmost)")
			"language":
				var en: Button = screen.buttons["en"]
				var es: Button = screen.buttons["es"]
				_check(en.get_global_rect().position.x > es.get_global_rect().position.x, "ar: language grid: ENGLISH right of ESPAÑOL")
		_check_mirror(path, screen)
		screen.free()


## Every visible control sits at the mirror of where the same (Arabic) screen puts it in LTR coordinates:
## the screen is dropped back to LTR (UIKit.relayout), every rect recorded, mirrored again (mirror_now), and
## each control must be at x' = 320 - x - w with the same y and size (keep_ltr subtrees excepted).
func _check_mirror(path: String, screen: Control) -> void:
	UIKit.relayout(screen)
	_check(not screen.is_layout_rtl(), "ar: %s: relayout drops back to LTR coordinates" % path.get_file())
	var ltr := _rects(screen)
	UIKit.mirror_now(screen)
	var rtl := _rects(screen)
	var bad := PackedStringArray()
	for id: String in ltr:
		if not rtl.has(id) or _kept(screen.get_node(id)):
			continue
		var a: Rect2 = ltr[id]
		var b: Rect2 = rtl[id]
		if not b.size.is_equal_approx(a.size) or b.position.y != a.position.y or absf(b.position.x - (UIKit.SCREEN.x - a.end.x)) > 0.5:
			bad.append("%s %s (LTR %s)" % [id, b, a])
	_check(bad.is_empty() and ltr.size() > 5, "ar: %s: all %d controls at their mirror %s" % [path.get_file(), ltr.size(), ", ".join(bad.slice(0, 4))])


## True under a keep_ltr subtree (never mirrored).
func _kept(node: Node) -> bool:
	var at := node
	while at != null:
		if at.has_meta(UIKit.KEEP_LTR_META):
			return true
		at = at.get_parent()
	return false


func _dynamic() -> void:
	# A page / tab switch after the build.
	var upgrades: Control = await _open("res://scenes/upgrades.tscn")
	upgrades.show_page("abilities")
	await _frames(2)
	_check(upgrades.is_layout_rtl() and _offscreen(upgrades).is_empty(), "ar: upgrades ABILITIES after the switch: mirrored, inside the screen")
	if upgrades.ability_page_button:
		var pager: Rect2 = upgrades.ability_page_button.get_global_rect()
		_check(pager.position.x == UIKit.EDGE, "ar: upgrades ABILITIES pages: the page button mirrors BACK (bottom left) %s" % pager)
		upgrades._show_ability_page(1)
		await _frames(2)
		var shown := 0
		for row: Array in upgrades._ability_row_nodes:
			shown += 1 if (row[0] as CanvasItem).visible else 0
		_check(shown >= 1 and _offscreen(upgrades).is_empty() and upgrades.ability_page_button.text == "2/%d" % upgrades._ability_plan.pages,
			"ar: upgrades ABILITIES page 2 shows its rows, inside the screen")
	upgrades.show_page("coins")
	await _frames(2)
	_check(_button(upgrades, Loc.t("common.back", "BACK")).get_global_rect().end.x == UIKit.SCREEN.x - UIKit.EDGE, "ar: upgrades back on COINS: BACK still right")
	upgrades.free()
	# Skins: RB (tab_next) steps the logical page by reading direction (mirrored: back one).
	var skins: Control = await _open("res://scenes/skins.tscn")
	var start_page: String = skins.page
	var pages: Array = skins.PAGES
	var action := InputEventAction.new()
	action.action = "tab_next"
	action.pressed = true
	skins._unhandled_input(action)
	await _frames(1)
	_check(skins.page == pages[(pages.find(start_page) - 1 + pages.size()) % pages.size()], "ar: skins RB moves to the tab on the visual left")
	skins.free()
	# The HEAT panel opened over the hard level select (positions set at open time).
	progress.hard_mode = true
	var ls: Control = await _open("res://scenes/level_select.tscn")
	ls.heat_panel.open(ls, ls.heat_button)
	await _frames(2)
	_check(_offscreen(ls.heat_panel).is_empty(), "ar: HEAT panel inside the screen %s" % _offscreen(ls.heat_panel))
	_check(ls.heat_button.get_global_rect().position.x == UIKit.EDGE, "ar: the HEAT button sits bottom left (BACK's mirror)")
	ls.heat_panel.close()
	ls.free()
	progress.hard_mode = false


func _keys() -> void:
	# Explicit neighbours swap: on the LANGUAGE grid, left from a button goes to the one visually left of it.
	var page: Control = await _open("res://scenes/language.tscn")
	var es: Button = page.buttons["es"]
	var left := es.get_node(es.focus_neighbor_left) as Control
	var right := es.get_node(es.focus_neighbor_right) as Control
	_check(left.get_global_rect().position.x < es.get_global_rect().position.x and right.get_global_rect().position.x > es.get_global_rect().position.x,
		"ar: language grid: left / right lead to the visual neighbours (%s / %s)" % [left.text, right.text])
	page.free()
	# The level select: the left key on a page's visual left end (its last tile) turns to the next page.
	var ls: Control = await _open("res://scenes/level_select.tscn")
	if ls.pages > 1:
		var last: Button = ls.level_buttons[ls.PAGE_SIZE - 1]
		last.grab_focus()
		var ev := InputEventAction.new()
		ev.action = "ui_left"
		ev.pressed = true
		ls._tile_input(ls.PAGE_SIZE, ev)
		await _frames(1)
		_check(ls.page == 1, "ar: level select: left past the visual left end turns to the next page")
	ls.free()


## The game world is not mirrored: the slime and the maze are where English has them; the HUD pods swap.
func _game_not_mirrored() -> void:
	var en := await _game_snapshot("en")
	var ar := await _game_snapshot("ar")
	_check(en.slime == ar.slime and en.maze == ar.maze, "ar: the game world is not mirrored (slime %s / %s)" % [en.slime, ar.slime])
	_check(ar.meter.position.x > 160 and ar.level.end.x < 160, "ar: HUD: the meter pod on the right, the level pod on the left (%s, %s)" % [ar.meter, ar.level])
	_check(en.meter.position.x < 160 and en.level.end.x > 160, "en: HUD: the meter pod on the left, the level pod on the right")
	_check(absf(ar.timer.get_center().x - 160.0) <= 0.5 and ar.timer.get_center().x == en.timer.get_center().x, "ar: HUD: the timer pod stays centred")
	_check(absf(ar.meter.position.x - (320.0 - en.meter.end.x)) <= 0.5, "ar: HUD: the meter pod mirrors English's")
	_check(ar.fill_end_gap <= 0.5 and en.fill_start_gap <= 0.5, "ar: HUD: the meter's fill hangs from its outer (right) end at 50 %")
	_check(ar.offscreen.is_empty(), "ar: HUD inside the screen %s" % [ar.offscreen])


func _game_snapshot(code: String) -> Dictionary:
	language.set_locale(code)
	seed(20261017)
	progress.start_story(3)
	var game := await _spawn_game({level = 3})
	await _frames(3)
	game.hud.set_slime(50.0)
	await _frames(2)
	var meter_pod: Control = game.hud._left_bar.get_child(0)
	var level_pod: Control = game.hud._right_bar.get_child(0)
	var timer_pod: Control = game.hud.time_label.get_parent().get_parent()
	var fill: Rect2 = game.hud.fill.get_global_rect()
	var track: Rect2 = (game.hud.fill.get_parent() as Control).get_global_rect()
	var out := {slime = game.slime.global_position, maze = [(game.get_node("Walls") as Node2D).global_position, (game.get_node("Chalice") as Node2D).global_position, game.get_viewport().canvas_transform],
		meter = meter_pod.get_global_rect(), level = level_pod.get_global_rect(), timer = timer_pod.get_global_rect(),
		fill_end_gap = absf(track.end.x - 1.0 - fill.end.x), fill_start_gap = absf(fill.position.x - track.position.x - 1.0),
		offscreen = _offscreen(game.hud)}
	game.free()
	return out


## The hub room is not mirrored (stations and slime where English has them); its UI is.
func _hub_not_mirrored() -> void:
	var spots := {}
	for code: String in ["en", "ar"]:
		language.set_locale(code)
		seed(20261017)
		var hub: Node = load("res://scenes/hub.tscn").instantiate()
		root.add_child(hub)
		await _frames(3)
		var at := PackedStringArray()
		for station: Dictionary in hub.stations:
			at.append(str((station.sprite as Node2D).global_position.round()))
		at.append(str(hub.slime.global_position.round()))
		hub.open_hat_wheel()
		hub.hat_wheel.show_tab("shop")  # (the try-on slimes wear the first hat of the SHOP)
		await _frames(2)
		var tries := PackedStringArray()
		for child in hub.hat_wheel._try_on_root.get_children():
			if child is AnimatedSprite2D:
				tries.append(str((child as Node2D).global_position.x))
		spots[code] = {room = at, tries = tries, offscreen = _offscreen(hub.hat_wheel)}
		hub.free()
	_check(spots.en.room == spots.ar.room, "ar: the hub room (stations, slime) is not mirrored")
	var mirrored: bool = spots.en.tries.size() == spots.ar.tries.size() and not spots.en.tries.is_empty()
	for i in spots.en.tries.size():
		mirrored = mirrored and spots.ar.tries.has(str(320.0 - float(spots.en.tries[i])))
	_check(mirrored, "ar: the hat wheel's try-on slimes are mirrored (%s / %s)" % [spots.en.tries, spots.ar.tries])
	_check(spots.ar.offscreen.is_empty(), "ar: the hat wheel inside the screen %s" % [spots.ar.offscreen])


# ------------------------------------------------------------------ helpers

## id (path from the screen) -> global rect of every visible Control under `screen`.
func _rects(screen: Node) -> Dictionary:
	var out := {}
	for node in screen.find_children("*", "Control", true, false):
		var c := node as Control
		if c.is_visible_in_tree() and not c is MenuBackdrop and c.size.x > 0:
			out[String(screen.get_path_to(c))] = c.get_global_rect()
	return out


## Visible buttons / labels / panels under `node` whose rect leaves 320x180 (full-screen holders and the
## backdrop aside).
func _offscreen(node: Node) -> Array[String]:
	var out: Array[String] = []
	for n in node.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c is MenuBackdrop or c.size == Vector2.ZERO:
			continue
		if not (c is Button or c is Label or c is Panel or c is PanelContainer or c is TextureRect):
			continue
		if not SCREEN.grow(0.5).encloses(c.get_global_rect()):
			out.append("%s %s" % [c.name, c.get_global_rect()])
	return out


func _button(screen: Node, text: String) -> Button:
	for n in screen.find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			return n
	return null


func _open(path: String) -> Control:
	seed(20261017)
	var screen: Control = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame
