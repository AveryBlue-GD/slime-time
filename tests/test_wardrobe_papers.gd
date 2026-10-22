extends "res://tests/suite_base.gd"

## The wardrobe (hub station COSMETICS) and its PAPERS page (owner 2026-10-18): the page order
## SKINS -> HATS -> TRAILS -> PAPERS (page button and LB / RB), a tile per map paper (parchment, then
## the sold ones; unowned ones a silhouette and never worn), wearing one is the MAP TABLE's PAPER
## setting both ways (Progress.map_paper), and the layout: the paper row centred under the title, every
## map picture centred in its tile like the trails' strips, title / grid / status / rule in order and
## clear of each other, BACK and the page button one width, EDGE from each side, on every page.
## English source layout; never touches a save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_wardrobe_papers.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	_check(progress.save_path != progress.REAL_SAVE_PATH, "tests save to a throwaway file (%s)" % progress.save_path)
	progress.reset_progress()
	progress.dev_tools = false
	await _hub_name()
	await _pages()
	await _papers()
	await _layout()
	_result()
	quit(1 if failures else 0)


func _open() -> Control:
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	await process_frame
	return screen


func _close(screen: Control) -> void:
	current_scene = null
	screen.free()


func _hub_name() -> void:
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	var found := false
	for station: Dictionary in hub.stations:
		if station.id == "wardrobe":
			found = station.name == "COSMETICS"
	_check(found, "the hub's wardrobe station is called COSMETICS")
	hub.free()


func _pages() -> void:
	var screen := await _open()
	_check(screen.PAGES == ["skins", "hats", "trails", "papers", "hub"], "five pages: SKINS, HATS, TRAILS, PAPERS, HUB")
	var seen: Array[String] = []
	var buttons: Array[String] = []
	for i in 5:
		seen.append(screen._title.text)
		buttons.append(screen.page_button.text)
		screen.page_button.pressed.emit()
		await process_frame
	_check(seen == ["SKINS", "HATS", "TRAILS", "PAPERS", "HUB"] and screen.page == "skins", "the page button cycles SKINS -> HATS -> TRAILS -> PAPERS -> HUB -> SKINS (%s)" % [seen])
	_check(buttons == ["HATS", "TRAILS", "PAPERS", "HUB", "SKINS"], "the page button names the next page (%s)" % [buttons])
	for page: String in screen.PAGES:
		screen.show_page(page)
		var grids := 0
		for which: String in screen.PAGES:
			grids += int(screen.grid_for(which).visible)
		_check(grids == 1 and screen.grid_for(page).visible, "%s: only its own grid shows" % page)
	screen.show_page("papers")
	_check(screen.rule_text("papers") == screen._rule.text and "SHOP" in screen._rule.text, "PAPERS: the tip says where to buy papers (%s)" % screen._rule.text)
	_check(not screen.showcase.visible and not screen.custom_panel.visible and not screen.jelly_button.visible, "PAPERS: no stage, wheel or JELLY switch")
	var action := InputEventAction.new()
	action.action = "tab_next"
	action.pressed = true
	screen._unhandled_input(action)
	_check(screen.page == "hub", "RB on PAPERS goes on to HUB")
	screen._unhandled_input(action)
	_check(screen.page == "skins", "RB on HUB wraps to SKINS")
	action.action = "tab_prev"
	screen._unhandled_input(action)
	_check(screen.page == "hub", "LB on SKINS wraps to HUB")
	_close(screen)


func _papers() -> void:
	progress.reset_progress()
	progress.cosmetics_owned.assign(["night"])
	var screen := await _open()
	screen.show_page("papers")
	await process_frame
	_check(screen.paper_tiles.keys() == Cosmetics.paper_ids(), "a tile per paper, parchment first (%s)" % [screen.paper_tiles.keys()])
	_check(screen.paper_tiles[Cosmetics.DEFAULT_PAPER].has_focus() and "PARCHMENT" in screen.status.text and "WEARING" in screen.status.text,
		"focus on the worn paper, the status line says so (%s)" % screen.status.text)
	screen.paper_tiles["blueprint"].pressed.emit()
	_check(progress.map_paper == Cosmetics.DEFAULT_PAPER and "TIX IN THE SHOP" in screen.status.text, "an unowned paper says its price and isn't worn (%s)" % screen.status.text)
	screen.paper_tiles["night"].pressed.emit()
	_check(progress.map_paper == "night" and "WEARING" in screen.status.text, "an owned paper is worn (%s)" % screen.status.text)
	_check(screen.paper_tiles["night"].get_meta("selected", false) and not screen.paper_tiles[Cosmetics.DEFAULT_PAPER].get_meta("selected", false), "the worn paper's tile is highlighted")
	# Locked tiles: the silhouette (same picture for every paper: no colors given away).
	var locked: Image = (screen.paper_tiles["blueprint"].get_child(-1) as TextureRect).texture.get_image()
	var locked2: Image = (screen.paper_tiles["goldleaf"].get_child(-1) as TextureRect).texture.get_image()
	_check(locked.get_data() == locked2.get_data(), "unowned papers show one silhouette")
	_check(_near(locked.get_pixel(1, 1), screen.LOCKED_INK) and locked.get_pixel(0, 0).a == 0.0, "the silhouette: dark floor, clear wall lines")
	_close(screen)
	# The MAP TABLE's PAPER button and the wardrobe share the setting.
	var maps: Control = load("res://scenes/maps.tscn").instantiate()
	root.add_child(maps)
	await process_frame
	_check(maps.owned_papers() == ([Cosmetics.DEFAULT_PAPER, "night"] as Array[String]), "the map view's PAPER button cycles the same owned papers")
	maps.cycle_paper()
	_check(progress.map_paper == Cosmetics.DEFAULT_PAPER, "PAPER in the map view: night -> parchment")
	maps.free()
	screen = await _open()
	screen.show_page("papers")
	await process_frame
	_check(screen.paper_tiles[Cosmetics.DEFAULT_PAPER].get_meta("selected", false) and screen.paper_tiles[Cosmetics.DEFAULT_PAPER].has_focus(), "...and the wardrobe shows parchment worn")
	_close(screen)


func _layout() -> void:
	progress.reset_progress()
	progress.cosmetics_owned.assign(["blueprint", "night", "goldleaf", "ink"])
	var screen := await _open()
	var back: Button = null
	for child in screen.get_children():
		if child is Button and child.text == "BACK":
			back = child
	for page: String in screen.PAGES:
		screen.show_page(page)
		await process_frame
		var b := back.get_global_rect()
		var p: Rect2 = screen.page_button.get_global_rect()
		_check(b == Rect2(4, 164, 40, 13) and p == Rect2(270, 164, 46, 13),
			"%s: BACK %s as on every screen, the page button %s one width for every page name, EDGE from the right" % [page, b, p])
		_check(UIKit.button_w(screen.page_button.text, 0) <= p.size.x, "%s: the page button fits %s" % [page, screen.page_button.text])
		var grid: Control = screen.grid_for(page)
		var g := Rect2()
		for row: Control in grid.get_children():
			for tile: Control in row.get_children():
				g = tile.get_global_rect() if g.size == Vector2.ZERO else g.merge(tile.get_global_rect())
		_check(absf(g.get_center().x - UIKit.SCREEN.x / 2.0) <= 0.5, "%s: the tiles centred (an odd-width row: half a px left) (%s, off %.1f)" % [page, g, g.get_center().x - 160.0])
		_check(UIKit.title_bottom() <= g.position.y and g.end.y <= screen.status.get_global_rect().position.y
			and screen.status.get_global_rect().end.y <= screen._rule.get_global_rect().position.y, "%s: title, grid, status, rule in order" % page)
		_check(Rect2(Vector2.ZERO, UIKit.SCREEN).encloses(g) and not g.intersects(b) and not g.intersects(p), "%s: the grid on screen, clear of the bottom row" % page)
	# Every paper's map picture: centred in its tile like a trail strip in its (smaller) tile, whole pixels.
	screen.show_page("papers")
	await process_frame
	var strip: Control = screen.trail_tiles["ink"].get_child(-1)
	var strip_tile: Control = screen.trail_tiles["ink"]
	_check(strip.position == ((strip_tile.size - strip.size) / 2.0).floor(), "a trail strip is centred in its tile (%s in %s)" % [strip.position, strip_tile.size])
	for id: String in screen.paper_tiles:
		var tile: Control = screen.paper_tiles[id]
		var map: TextureRect = tile.get_child(-1)
		var at := map.position
		var left := at.x
		var right := tile.size.x - at.x - map.size.x
		_check(map.size == Vector2(33, 17) and at == at.round() and absf(left - right) <= 1.0 and at.y == floorf((tile.size.y - map.size.y) / 2.0),
			"%s: its 33x17 map in the tile at %s (left %d, right %d; centred top to bottom like a trail strip in its smaller tile)" % [id, at, left, right])
		_check(Rect2(Vector2.ZERO, tile.size).encloses(Rect2(at, map.size)), "%s: the map inside its tile" % id)
	_close(screen)


## Colors equal to 8 bits (an RGBA8 image's pixel against a float color).
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004 and absf(a.a - b.a) < 0.004
