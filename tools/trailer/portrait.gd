extends Node

## Marketing only: 9:16 portrait reconstructions of three menus for the vertical Shorts, built from the
## game's real pieces (tiles, slime previews and their skin shader, HatWheel's wheel drawing and spin,
## MapView maps on the real papers, GooBox frames, the menu backdrop, UIKit's theme) but laid out for a
## 180x320 frame (x6 = 1080x1920). The game never uses this scene. tools/trailer/trailer.py runs it for a
## take with "scene": "portrait" in trailer.json:
##   godot --write-movie build/trailer/takes/ID/f.png --fixed-fps 60 --resolution 320x180 \
##       --quit-after N res://tools/trailer/portrait.tscn -- --view=VIEW --frames-dir=DIR [flags]
## The movie run paces the frames and records the audio; the portrait view saves its own frames
## (DIR/p00000000.png ...), as card.gd does. Game flags are Progress's debug flags (--story-complete,
## --skin=ID, --tickets=N ...): nothing is saved, the real save is never read. The global RNG is seeded
## (--rng=N, default 1), so a take renders the same every time.
##
## Views (--view=):
##   skins   the COSMETICS wardrobe: the try-on stage on top (a big slime acting out the showcase
##           routine), the status line, the skin tiles (5 a row), JELLY: OFF / ON. --cycle=a,b,c flips
##           skins every --every=F frames from --cycle-at=F; --jelly-at=F turns JELLY on; --no-jelly
##           hides the switch (a take whose 3-line caption pushes the layout down, --top=90).
##   wheel   the hat wheel, big: HatWheel's own drawing (wedges sized by the odds, the rare slivers
##           spread round it, the flapper) and a real seeded spin at --spin-at=F; the won hat pops onto
##           the slime on the little stage under it.
##   papers  the map of story level --open=N (default 4) on the real paper, big, with the PAPERS page's
##           tiles under it; --every=F flips to the next paper from --cycle-at=F (--own-cosmetics=all).
##   flip    the "how many looks" Short: a big slime acting out the showcase routine while its look flips
##           (skin incl. jelly / pastel / CHAMELEON colors, hat and dye, trail) through FLIP_PLAN's
##           phases (skins only, hats, dyes, trails, CHAMELEON colors, then everything, faster and
##           faster), with the trail strip and the look's names under the stage. Seeded (--rng).
##           The dyes show on the WIZARD HAT (worn on through the trails and CHAMELEON phases).
##           --plan-from=F starts FLIP_PLAN at frame F (a later stretch as its own take, e.g. under a
##           3-line caption with --top=92); --no-names hides the names (too fast to read there).
## Promo rule (owner, 2026-10-20): the RAINBOW and STOPWATCH skins are only ever shown as the skins
## screen's locked silhouettes (one story coin is taken out of the count, so the line under the stage
## is true), and never worn.

const SIZE := Vector2i(180, 320)
const SECRET_SKINS := [Skins.RAINBOW, Skins.STOPWATCH]
const Stage := preload("res://tools/trailer/portrait_stage.gd")
const SkinsScreen := preload("res://scripts/ui/skins_screen.gd")
## Everything stays below the caption room at the top: --top=Y (default 70 = under a 2-line goo caption,
## which ends by y ~66; 90 = under 3 lines). The map papers view starts at 62 (its captions are 1 line).
const TOP := 70

var view := "skins"
var top := TOP
var opts := {}
var frame := 0
var root: Control
var _view: SubViewport
var _dir := ""
var _saved := 0
var _cycle: Array = []

# skins
var stage: Control
var status: Label
var tiles := {}
var view_jelly := false
var jelly_button: Button
var _grid: Control
# wheel
var wheel: HatWheel
var result: Label
# papers
var map_panel: Panel
var map_rect: TextureRect
var map_floor: ColorRect
var paper_name: Label
var paper_line: Label
var paper_tiles := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
		elif arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif arg.begins_with("--"):
			opts[arg.trim_prefix("--")] = "1"
	seed(int(opts.get("rng", "1")))
	_dir = String(opts.get("frames-dir", ""))
	top = _int("top", 62 if view == "papers" else TOP)
	Progress.saving_enabled = false
	Progress.tutorial_seen = 3
	Progress.maps_hint_seen = true
	if Progress.selected_skin in SECRET_SKINS:
		Progress.selected_skin = Skins.DEFAULT
	# The opaque RAINBOW locks itself without every coin (and the line under the stage stays true).
	for level in range(Levels.COUNT, 0, -1):
		var found: Array = Progress.coins_found.get(level, [])
		if not found.is_empty():
			found.pop_back()
			break
	if Progress.all_medals():
		Progress.medals[Levels.COUNT] = Progress.TIER_GOLD - 1
	if opts.has("jelly"):
		Progress.set_jelly(true)
	if opts.has("own-hats"):
		Progress.hats_owned.assign(Array(Hats.ids()) if opts["own-hats"] == "all" else Array(String(opts["own-hats"]).split(",")))
	if opts.has("own-cosmetics"):
		Progress.cosmetics_owned.assign(Array(Cosmetics.ids()) if opts["own-cosmetics"] == "all" else Array(String(opts["own-cosmetics"]).split(",")))
	if opts.has("cycle"):
		_cycle.assign(String(opts.cycle).split(","))
	_build.call_deferred()


func _int(key: String, fallback: int) -> int:
	return int(opts.get(key, str(fallback)))


func _build() -> void:
	_view = SubViewport.new()
	_view.size = SIZE
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.snap_2d_transforms_to_pixel = true
	add_child(_view)
	root = Control.new()
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.size = Vector2(SIZE)
	root.theme = UIKit.make_theme()
	_view.add_child(root)
	root.add_child(MenuBackdrop.new())
	match view:
		"skins":
			_build_skins()
		"wheel":
			_build_wheel()
		"papers":
			_build_papers()
		"flip":
			_build_flip()
		_:
			push_error("portrait: no view %s" % view)


func _label(text: String, color: Color, y: float, height := 10.0) -> Label:
	var label := UIKit.make_label(text, UIKit.FONT, color)  # i18n: ignore (marketing scene: the screens' own strings)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.position = Vector2(4, y)
	label.size = Vector2(SIZE.x - 8, height)
	root.add_child(label)
	return label


func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", GooBox.make_panel())
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	return panel


# ------------------------------------------------------------------ skins

const TILE := Vector2(34, 30)
const COLUMNS := 5
const GAP := 2


func _build_skins() -> void:
	view_jelly = Progress.jelly
	Progress.custom_color = Color.from_hsv(randf(), randf_range(0.55, 1.0), 1.0)  # (the screen's random wheel color)
	stage = Stage.new(Vector2(172, 72), 3)
	stage.position = Vector2(4, top)
	root.add_child(stage)
	status = _label("", UIKit.TEXT, top + 74, 20)
	_grid = Control.new()
	_grid.position = Vector2(roundf((SIZE.x - (COLUMNS * TILE.x + (COLUMNS - 1) * GAP)) / 2.0), top + 96)
	root.add_child(_grid)
	jelly_button = UIKit.make_button("", func() -> void: pass, Vector2(80, UIKit.button_h()))
	jelly_button.position = Vector2((SIZE.x - 80) / 2, top + 96 + 3 * TILE.y + 2 * GAP + 5)
	jelly_button.visible = not opts.has("no-jelly")
	root.add_child(jelly_button)
	_fill_tiles()
	_try_on(Progress.selected_skin)


func _skin_ids() -> Array[String]:
	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append_array([Skins.CUSTOM, Skins.RAINBOW, Skins.STOPWATCH])
	return ids


func _base_color(id: String) -> Color:
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.STOPWATCH:
		return Skins.STOPWATCH_BASE
	if id == Skins.CUSTOM:
		return Progress.custom_color
	return Skins.get_preset(id).color


func _locked(id: String) -> bool:
	return id in SECRET_SKINS or not Progress.is_skin_unlocked(id, view_jelly)


## The skins screen's tiles (_make_tile): a slime preview in the skin, a silhouette while locked;
## 13 tiles in rows of 5, the short last row centred.
func _fill_tiles() -> void:
	for child in _grid.get_children():
		child.queue_free()
	tiles.clear()
	var ids := _skin_ids()
	for i in ids.size():
		var id := ids[i]
		var tile := UIKit.make_button("", func() -> void: pass, TILE)
		var preview := UIKit.make_slime_preview(_base_color(id), 1, id == Skins.RAINBOW, view_jelly, id == Skins.STOPWATCH)
		preview.position = TILE / 2.0 + Vector2(0, -2)
		if _locked(id):
			preview.modulate = Color(0, 0, 0, 0.85)
			preview.pause()
		tile.add_child(preview)
		var row := i / COLUMNS
		var in_row := mini(COLUMNS, ids.size() - row * COLUMNS)
		var row_x := (COLUMNS - in_row) * (TILE.x + GAP) / 2.0
		tile.position = Vector2(roundf(row_x + (i % COLUMNS) * (TILE.x + GAP)), row * (TILE.y + GAP))
		tile.size = TILE
		_grid.add_child(tile)
		tiles[id] = tile
	jelly_button.text = Loc.t("skins.jelly.on", "JELLY: ON") if view_jelly else Loc.t("skins.jelly.off", "JELLY: OFF")  # i18n: ignore (the screen's own strings)


## A skin on the stage, its tile selected (or, locked, the silhouette and the screen's locked line).
func _try_on(id: String) -> void:
	var locked := _locked(id)
	if not locked:
		Progress.select_skin(id, view_jelly)
	stage.show_skin(_base_color(id), id == Skins.RAINBOW, view_jelly, locked, id == Skins.STOPWATCH)
	for tile_id: String in tiles:
		UIKit.set_selected(tiles[tile_id], not locked and tile_id == id)
	tiles[id].grab_focus()
	status.text = _status(id, locked)


## The skins screen's status line (_refresh) for the cases the trailer shows.
func _status(id: String, locked: bool) -> String:
	if not locked:
		return Loc.t("skins.selected", "{name}  (SELECTED)", {name = Skins.display_name(id)})  # i18n: ignore (the screen's own string)
	if id == Skins.STOPWATCH:
		return Loc.n("skins.locked_medals", "LOCKED - EARN ALL {count} MEDALS ({have}/{count})", "LOCKED - EARN ALL {count} MEDALS ({have}/{count})", Progress.medals_max(), {have = Progress.medals_total(false)})  # i18n: ignore (the screen's own string)
	if view_jelly:
		return Loc.t("skins.locked_jelly", "JELLY LOCKED - HARD CLEAR L{level}", {level = Skins.jelly_level(id)})  # i18n: ignore (the screen's own string)
	if id == Skins.RAINBOW:
		return Loc.n("skins.locked_coins", "LOCKED - FIND EVERY COIN ({have}/{count})", "LOCKED - FIND EVERY COIN ({have}/{count})", Levels.total_coins(), {have = Progress.coins_earned()})  # i18n: ignore (the screen's own string)
	return Loc.t("skins.locked_level", "LOCKED - CLEAR LEVEL {level}", {level = Skins.unlock_level(id)})  # i18n: ignore (the screen's own string)


func _skins_tick() -> void:
	if opts.has("jelly-at") and frame == _int("jelly-at", 0) and not view_jelly:
		view_jelly = true
		Sfx.play("click", -6.0)
		_fill_tiles()
		_try_on(Progress.selected_skin)
		jelly_button.grab_focus()
	var at := _int("cycle-at", 20)
	var every := _int("every", 30)
	if _cycle.is_empty() or frame < at or (frame - at) % every != 0:
		return
	_try_on(_cycle[((frame - at) / every) % _cycle.size()])


# ------------------------------------------------------------------ wheel

const WHEEL_RADIUS := 70.0


func _build_wheel() -> void:
	Progress.spins = maxi(Progress.spins, 1)  # past the free first spin: a real ticket spin
	_panel(Rect2(4, top - 6, 172, 166))
	wheel = HatWheel.new()
	root.add_child(wheel)
	wheel.wheel_center = Vector2(90, top + 80)  # (the flapper's cap on row `top`)
	wheel.wheel_radius = WHEEL_RADIUS
	wheel.landed.connect(_on_landed)
	_hide_wheel_chrome()
	stage = Stage.new(Vector2(96, 44), 2, false)
	stage.position = Vector2(42, top + 164)
	root.add_child(stage)
	stage.show_skin(Progress.skin_color(), false, Progress.jelly)
	result = _label(Loc.n("wheel.hats_left", "{count} HAT TO WIN", "{count} HATS TO WIN", Progress.hats_left().size()), UIKit.GOLD, top + 212)  # i18n: ignore (the wheel's own string)


## Only the wheel itself (HatWheel._draw) shows: its header, tabs, SPIN button, status lines, try-on
## slimes and 320x180 panel are the landscape screen's.
func _hide_wheel_chrome() -> void:
	for child in wheel.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _on_landed(id: String) -> void:
	var hat := Hat.new()
	hat.scale = stage.slime.scale
	stage.add_child(hat)
	hat.setup(id, stage.slime)
	stage.celebrate()
	result.text = Loc.t("wheel.won", "YOU WON THE {name}!", {name = Hats.display_name(id)})  # i18n: ignore (the wheel's own string)


func _wheel_tick() -> void:
	_hide_wheel_chrome()
	if frame == _int("spin-at", 40) and wheel.spin():
		result.text = "..."  # i18n: ignore (the wheel's own spinning line)


# ------------------------------------------------------------------ papers

func _build_papers() -> void:
	map_panel = _panel(Rect2(4, top + 2, 172, 104))
	map_floor = ColorRect.new()
	map_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_floor)
	map_rect = TextureRect.new()
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_rect)
	paper_name = _label("", UIKit.GOLD, top + 112)
	paper_line = _label("", UIKit.TEXT_DIM, top + 123)
	var ids := Cosmetics.paper_ids()
	var tile_size := SkinsScreen.TILE_SIZE
	var gap := 3.0
	var left := roundf((SIZE.x - ids.size() * tile_size.x - (ids.size() - 1) * gap) / 2.0)
	for i in ids.size():
		var id: String = ids[i]
		var tile := UIKit.make_button("", func() -> void: pass, tile_size)
		var map := TextureRect.new()
		map.texture = ImageTexture.create_from_image(SkinsScreen.paper_preview(id, Progress.skin_color(), not Progress.owns_cosmetic(id)))
		map.size = map.texture.get_size()
		map.position = ((tile_size - map.size) / 2.0).floor()
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(map)
		tile.position = Vector2(left + i * (tile_size.x + gap), top + 142)
		tile.size = tile_size
		root.add_child(tile)
		paper_tiles[id] = tile
	_show_paper()


## The MAP TABLE's view (map_select open_view) of level --open on the worn paper, in its theme, as big
## as fits the panel; the PAPERS tiles' highlight on the worn one.
func _show_paper() -> void:
	var level := _int("open", 4)
	var maze := Levels.story_maze(level, false)
	var survey: Dictionary = Progress.survey_for(level, false)
	var theme := Themes.for_level(level)
	var paper: String = Progress.map_paper
	var area := Vector2i(int(map_panel.size.x) - 8, int(map_panel.size.y) - 8)
	var sizes := MapView.layout(maze.cells, area, true)
	var image := MapView.render(maze, survey, sizes, Progress.map_coins(level, false), theme, paper, Progress.skin_color())
	map_rect.texture = ImageTexture.create_from_image(image)
	map_rect.size = Vector2(image.get_size())
	map_rect.position = (map_panel.position + (map_panel.size - map_rect.size) / 2.0).floor()
	map_floor.color = MapView.palette(theme, paper, Progress.skin_color()).fog
	map_floor.position = map_panel.position + Vector2(3, 3)
	map_floor.size = map_panel.size - Vector2(6, 6)
	map_panel.move_to_front()
	map_rect.move_to_front()
	paper_name.text = Cosmetics.display_name(paper)
	paper_line.text = Loc.t("maps.uncovered", "{percent}% UNCOVERED", {percent = roundi(Survey.completeness(survey, maze) * 100.0)})  # i18n: ignore (the map view's own string)
	for id: String in paper_tiles:
		UIKit.set_selected(paper_tiles[id], id == paper)
	paper_tiles[paper].grab_focus()


func _papers_tick() -> void:
	var every := _int("every", 0)
	if every <= 0 or frame < _int("cycle-at", 40) or (frame - _int("cycle-at", 40)) % every != 0 or frame == _int("cycle-at", 40):
		return
	var papers: Array[String] = []
	for id in Cosmetics.paper_ids():
		if Progress.owns_cosmetic(id):
			papers.append(id)
	Progress.equip_cosmetic(papers[(papers.find(Progress.map_paper) + 1) % papers.size()])
	Sfx.play("click", -6.0)
	_show_paper()


# ------------------------------------------------------------------ flip

## [from frame, what flips, every N frames]: "skin", "hat", "dye", "trail", "chameleon" flip only
## that part (the rest stays as it is); "all" re-rolls the whole look; a 4th entry eases `every`
## down to that many frames by the next phase.
const FLIP_PLAN := [
	[0, "all", 24],
	[180, "skin", 10],
	[420, "hat", 12],
	[630, "dye", 10],
	[810, "trail", 14],
	[990, "chameleon", 6],
	[1170, "all", 8, 2],
	[1470, "all", 2],
]
const FLIP_STAGE := Vector2(172, 130)
const FLIP_PX := 4
const NEVER := 1 << 30
const DYE_HAT := "wizard"
## The secret RAINBOW and STOPWATCH (and the pastel rainbow) are never worn (the promo rule).
const PRESET_IDS := ["lime", "mint", "lemon", "ocean", "grape", "crimson", "frost", "shadow", "bubblegum", "ember"]

## The look on the stage: skin id (a preset or CHAMELEON), jelly, pastel, CHAMELEON's color, hat
## ("" = none), dye ("" = the hat's own color), trail style.
var look := {skin = "ocean", jelly = false, pastel = false, color = Color.WHITE, hat = "tophat", dye = "", trail = Cosmetics.DEFAULT_TRAIL}
var flip_rng := RandomNumberGenerator.new()
var flip_hat: Hat
var trail_rect: TextureRect
var skin_line: Label
var hat_line: Label
var trail_line: Label
var _flips := 0
var _next_flip := 0


func _build_flip() -> void:
	flip_rng.seed = int(opts.get("rng", "1"))
	stage = Stage.new(FLIP_STAGE, FLIP_PX)
	stage.position = Vector2(4, top)
	root.add_child(stage)
	trail_rect = TextureRect.new()
	trail_rect.scale = Vector2(FLIP_PX, FLIP_PX)
	trail_rect.position = Vector2(4, top + FLIP_STAGE.y + 3)
	trail_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trail_rect)
	var y := top + FLIP_STAGE.y + 3 + 7 * FLIP_PX + 2
	skin_line = _label("", UIKit.TEXT, y)
	hat_line = _label("", UIKit.GOLD, y + 9)
	trail_line = _label("", UIKit.TEXT_DIM, y + 18)
	for line in [skin_line, hat_line, trail_line]:
		line.visible = not opts.has("no-names")
	_show_look()


## [what flips, every N frames] at frame `at` (FLIP_PLAN).
func _flip_phase(at: int) -> Array:
	var phase: Array = FLIP_PLAN[0]
	var next_at := NEVER
	for i in FLIP_PLAN.size():
		if FLIP_PLAN[i][0] <= at:
			phase = FLIP_PLAN[i]
			next_at = FLIP_PLAN[i + 1][0] if i + 1 < FLIP_PLAN.size() else NEVER
	var every: float = phase[2]
	if phase.size() > 3:
		var t := clampf(float(at - phase[0]) / float(next_at - phase[0]), 0.0, 1.0)
		every = lerpf(phase[2], phase[3], t * t)
	return [phase[1], maxi(roundi(every), 1)]


func _flip_tick() -> void:
	if frame < _next_flip:
		return
	var phase := _flip_phase(frame + _int("plan-from", 0))
	var every: int = phase[1]
	if frame > 1:
		_flip(phase[0])
		_flips += 1
		if every >= 6 or _flips % 3 == 0:
			Sfx.play("click", -10.0)
	_next_flip = frame + every


func _pick(options: Array, current: Variant) -> Variant:
	var pick: Variant = options[flip_rng.randi_range(0, options.size() - 1)]
	while options.size() > 1 and pick == current:
		pick = options[flip_rng.randi_range(0, options.size() - 1)]
	return pick


## CHAMELEON's colors: the skins screen's wheel (ColorWheel: 24 hues x 6 saturations, full value).
func _chameleon_color() -> Color:
	var hue := flip_rng.randi_range(0, int(ColorWheel.HUE_STEPS) - 1) / ColorWheel.HUE_STEPS
	var sat := flip_rng.randi_range(1, int(ColorWheel.SAT_STEPS)) / ColorWheel.SAT_STEPS
	return Color.from_hsv(hue, sat, 1.0)


func _roll_skin() -> void:
	var before := "%s%s%s" % [look.skin, look.jelly, look.pastel]
	while "%s%s%s" % [look.skin, look.jelly, look.pastel] == before:
		look.skin = Skins.CUSTOM if flip_rng.randf() < 0.12 else PRESET_IDS[flip_rng.randi_range(0, PRESET_IDS.size() - 1)]
		look.jelly = flip_rng.randf() < 0.5
		look.pastel = look.skin != Skins.CUSTOM and flip_rng.randf() < 0.4
	if look.skin == Skins.CUSTOM:
		look.color = _chameleon_color()


func _roll_hat() -> void:
	look.hat = _pick(Array(Hats.ids()), look.hat)
	look.dye = ""


func _roll_dye() -> void:
	var dyes: Array = [""]
	dyes.append_array(Hats.dyes_for(look.hat))
	look.dye = _pick(dyes, look.dye)


## The trails a player can wear (ABYSS is DESCENT's, switched off).
func _trails() -> Array:
	return Array(Cosmetics.trail_ids()).filter(func(id: String) -> bool: return not Cosmetics.get_item(id).has("earned"))


func _flip(what: String) -> void:
	match what:
		"skin":
			_roll_skin()
		"hat":
			_roll_hat()
		"dye":
			if look.hat != DYE_HAT:
				look.hat = DYE_HAT
				look.dye = ""
			_roll_dye()
		"trail":
			look.trail = _pick(_trails(), look.trail)
		"chameleon":
			look.skin = Skins.CUSTOM
			look.pastel = false
			look.color = _chameleon_color()
		_:
			_roll_skin()
			if flip_rng.randf() < 0.9:
				_roll_hat()
				_roll_dye()
			else:
				look.hat = ""
			look.trail = _pick(_trails(), look.trail)
	_show_look()


## The look's base color, as Progress.skin_color gives it (a pastel version: its PASTEL color).
func _look_color() -> Color:
	if look.skin == Skins.CUSTOM:
		return look.color
	return Skins.PASTEL[look.skin] if look.pastel else Skins.get_preset(look.skin).color


func _show_look() -> void:
	if flip_hat:
		flip_hat.queue_free()
		flip_hat = null
	Skins.pastel = look.pastel  # (read when the material is made)
	stage.show_skin(look.color if look.skin == Skins.CUSTOM else Skins.get_preset(look.skin).color, false, look.jelly, false, false, false)
	Skins.pastel = false
	if look.hat != "":
		flip_hat = Hat.new()
		flip_hat.scale = stage.slime.scale
		stage.add_child(flip_hat)
		flip_hat.setup(look.hat, stage.slime, null, look.dye)
	trail_rect.texture = ImageTexture.create_from_image(Cosmetics.trail_preview(look.trail, _look_color(), false, Vector2i(int(FLIP_STAGE.x) / FLIP_PX, 7)))
	var skin_name := Skins.display_name(look.skin)
	if look.pastel:
		skin_name = "PASTEL " + skin_name  # i18n: ignore (marketing scene)
	if look.jelly:
		skin_name += " JELLY"  # i18n: ignore (marketing scene)
	skin_line.text = skin_name
	skin_line.add_theme_color_override("font_color", Skins.shades(_look_color()).light)
	if look.hat == "":
		hat_line.text = ""
	elif look.dye == "":
		hat_line.text = Hats.display_name(look.hat)
	else:
		hat_line.text = "%s %s" % [Hats.dye_name(look.dye), Hats.display_name(look.hat)]  # i18n: ignore (marketing scene)
	trail_line.text = Cosmetics.display_name(look.trail)


# ------------------------------------------------------------------ frames

func _physics_process(_delta: float) -> void:
	frame += 1
	if root == null:
		return
	match view:
		"skins":
			_skins_tick()
		"wheel":
			_wheel_tick()
		"papers":
			_papers_tick()
		"flip":
			_flip_tick()


func _process(_delta: float) -> void:
	if _view == null or _dir == "":
		return
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png(_dir.path_join("p%08d.png" % _saved))
	_saved += 1
