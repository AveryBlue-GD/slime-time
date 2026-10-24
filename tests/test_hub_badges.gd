extends "res://tests/suite_base.gd"

## The hub's gold "!" badges never cover a visible station name or each other, whatever way the room is turned
## (IMP2-06 fix). Every station's news is forced on, the names held visible, and the room swept through a full turn.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_hub_badges.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	progress.levels_cleared = Levels.COUNT
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await _physics_frames(3)
	var safe := UIKit.safe_rect()
	var checked := 0
	var shifted := 0
	var bad := 0
	for step in 72:
		hub.turn = TAU * step / 72.0
		hub._place_all()
		for id: String in hub.badges:
			hub.badges[id].text = "!"
			hub.badges[id].visible = true
		hub.near = {}
		hub._names_t = 0.0
		await _physics_frames(3)
		for id: String in hub.badge_art:
			_check(not hub.badge_art[id].node.visible, "no badge %s while the names show" % id)
		hub._names_t = hub.NAMES_TIME
		for id: String in hub.badges:  # (a refresh may have reset the forced news)
			hub.badges[id].text = "!"
			hub.badges[id].visible = true
		await _physics_frames(30)  # (the stagger and the pop-in are over, the bob has moved)
		var rects: Array[Rect2] = []
		var labels: Array[Rect2] = []
		for id: String in hub.name_labels:
			var label: Label = hub.name_labels[id]
			if label.visible and hub.name_layer.visible:
				labels.append(Rect2(label.position, label.size))
		for id: String in hub.badge_art:
			var node: TextureRect = hub.badge_art[id].node
			if not node.visible:
				continue
			checked += 1
			var r := Rect2(node.position, Vector2(hub.BADGE_SIZE))
			rects.append(r)
			_check(node.position == node.position.round(), "badge %s on whole pixels" % id)
			# IMP3-03: the badge stays with its station through the turn (within its head rect: the sprite's width
			# plus a badge on each side, from the head up to a badge or two above it)
			var prop: Dictionary = {}
			for candidate: Dictionary in hub._all_props():
				if candidate.id == id:
					prop = candidate
			var at: Vector2 = prop.sprite.position
			var head := Rect2(at.x - prop.size.x / 2.0 - 12.0, at.y - prop.size.y - 2.0 * hub.BADGE_SIZE.y - 8.0, prop.size.x + 24.0, 2.0 * hub.BADGE_SIZE.y + 12.0)
			head.position.y = maxf(head.position.y, safe.position.y)  # (a station at the very top: its badge sits on the safe edge)
			head.size.y = maxf(head.size.y, 2.0 * hub.BADGE_SIZE.y + 12.0)
			if not head.encloses(r):
				bad += 1
				_check(false, "badge %s follows its station at turn %d (%s outside head rect %s)" % [id, step, r, head])
			_check(safe.encloses(r), "badge %s inside the safe rect (%s)" % [id, r])
			for l in labels:
				if r.intersects(l):
					bad += 1
					_check(false, "badge %s covers a name at turn %d (%s vs %s)" % [id, step, r, l])
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					bad += 1
					_check(false, "two badges overlap at turn %d (%s %s)" % [step, rects[i], rects[j]])
	# No Label "!" is drawn but the prompt's own bang (the badges are sprites; the logical labels are invisible).
	hub.near = hub.stations_by_id("wheel") if hub.has_method("stations_by_id") else {}
	await _physics_frames(5)
	var stray := 0
	for n in hub.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text == "!" and l.is_visible_in_tree() and l != hub.prompt_bang and l.self_modulate.a > 0.0 and l.get_theme_color("font_color").a > 0.0:
			stray += 1
	_check(stray == 0, "no stray visible ! label in the hub (%d)" % stray)
	# IMP3-03: the UPGRADES / WHEEL news waits for something newly affordable since the station was last used.
	progress.hub_seen.clear()
	progress.tickets = 500
	_check(progress.hub_news("wheel", true), "never opened: an affordable wheel has news")
	progress.hub_mark_seen("wheel")
	_check(not progress.hub_news("wheel", true), "opened, nothing new: no news")
	progress.tickets += 5
	_check(progress.hub_news("wheel", true) and not progress.hub_news("wheel", false), "more money and affordable: news again; not affordable: none")
	progress.hub_mark_seen("wheel")
	progress.tickets -= 50
	_check(not progress.hub_news("wheel", true) and progress.hub_seen["wheel"] == progress.tickets, "spent: the marker follows down")
	progress.tickets += 1
	_check(progress.hub_news("wheel", true), "gaining after the spend is news")
	_check(checked > 100, "many badges were checked (%d)" % checked)
	_check(bad == 0, "no badge covers a name or another badge")
	current_scene = null
	hub.free()
	_result()
	quit(1 if failures > 0 else 0)
