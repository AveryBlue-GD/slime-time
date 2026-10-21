extends Control

## Skin select. Slimes are opaque by default (those unlock with the story levels); the JELLY ON / OFF
## switch shows the same skins as see-through jelly instead, each unlocked by beating its level on
## hard mode (D14; the stopwatch opens both versions together with all 30 medals). A tile per skin (locked ones are silhouettes); for the custom
## skin, once the game is beaten, a color wheel. The page button cycles SKINS -> HATS -> TRAILS -> PAPERS:
## the hats page has a tile per hat (plus no hat), each shown on a slime in your skin; the TRAILS page
## (upgrades v2 batch 2) a tile per goo trail style (the skin's own goo plus the five sold in the
## prize wheel's SHOP, Cosmetics), each a little strip of that goo in your skin; owned ones are worn
## by pressing them, the others are silhouettes saying where to buy them. The PAPERS page works the same
## for the map papers (Cosmetics, sold in the same SHOP): a tile per paper, each a little example map
## drawn on it (MapView.render); wearing one is the MAP TABLE's PAPER setting (Progress.map_paper).
##
## Layout (320x180, mirrored left/right): title, a 7-wide grid, the status line, a hint, the
## custom color panel or the preview stage (the clicked skin acting out a little routine, see
## SkinShowcase), and a bottom row of BACK | JELLY | HATS. On the hats page COLOR takes JELLY's place:
## it opens a picker of the worn hat's own color and every dye you own of it (Hats.dyes_for, bought in
## the prize wheel's SHOP): a tile each (swatch and name), the worn one lit; pressing one puts it on,
## Esc / B closes it.

const TILE_SIZE := Vector2(40, 30)
const GRID_COLUMNS := 7
const GRID_GAP := 3
const GRID_TOP := 23
const STATUS_TOP := 89
const RULE_TOP := 100
const CUSTOM_TOP := 112
const WHEEL_SIZE := 48
const WHEEL_GAP := 40
## A locked paper's silhouette (the trails' locked dark, Cosmetics.trail_preview).
const LOCKED_INK := Color(0.08, 0.08, 0.12, 0.9)
## The tip line of a page. i18n: one line, max 300px.
static func rule_text(which: String) -> String:
	match which:
		"jelly": return Loc.t("skins.rule_jelly", "JELLY SKINS UNLOCK ON HARD MODE")
		"hats": return Loc.t("skins.rule_hats", "WIN HATS ON THE PRIZE WHEEL IN THE HUB")
		"trails": return Loc.t("skins.rule_trails", "BUY TRAILS IN THE PRIZE WHEEL'S SHOP")
		"papers": return Loc.t("skins.rule_papers", "BUY MAP PAPERS IN THE PRIZE WHEEL'S SHOP")
	return Loc.t("skins.rule_skins", "NEW LEVELS EQUIP YOUR NEWEST SKIN")


## A page's name, for the screen title and the page button. i18n: title max 296px (16 px font), button max 32px (40 wide, 4 px margins).
static func page_title(which: String) -> String:
	match which:
		"hats": return Loc.t("skins.page_hats", "HATS")
		"trails": return Loc.t("skins.page_trails", "TRAILS")
		"papers": return Loc.t("skins.page_papers", "PAPERS")
	return Loc.t("skins.page_skins", "SKINS")


## The pages, in the order the page button cycles them.
const PAGES := ["skins", "hats", "trails", "papers"]

var tiles := {}
var hat_tiles := {}
var trail_tiles := {}
var paper_tiles := {}
var status: Label
var custom_panel: Control
var wheel: ColorWheel
var big_preview: AnimatedSprite2D
## The animated preview of the clicked skin (where the custom panel goes when that's not shown).
var showcase: SkinShowcase
var skin_text: SkinText
## "skins", "hats", "trails" or "papers".
var page := "skins"
## Which version of the skins the grid shows: jelly (true) or opaque (false, the default).
var view_jelly := false
var page_button: Button
var jelly_button: Button
## Hats page: COLOR, in JELLY's place (opens the color picker; disabled when the worn hat has no dye).
var color_button: Button
## The color picker: a dim sheet, its panel, its tiles by dye ("" = the hat's own), the focus lock.
var _picker_blocker: ColorRect
var _picker: Panel
var picker_tiles := {}
var _picker_lock := {}
## A picker tile's size, the gap between tiles and the panel's inset round them.
const PICK_TILE := Vector2(84, 13)
const PICK_GAP := 2
const PICK_PAD := 8
var _skin_grid: VBoxContainer
var _hat_grid: VBoxContainer
var _trail_grid: VBoxContainer
var _paper_grid: VBoxContainer
var _title: Label
var _rule: Label


func _ready() -> void:
	skin_text = UIKit.setup_screen(self, page_title("skins"))
	for child in get_children():
		if child is Label and child.text == page_title("skins"):
			_title = child
	view_jelly = Progress.jelly
	# A fresh random color on the wheel every visit (any hue, never washed out).
	Progress.custom_color = Color.from_hsv(randf(), randf_range(0.55, 1.0), 1.0)
	Progress.save_progress()
	_skin_grid = _make_grid()
	_fill_skin_grid()

	_hat_grid = _make_grid()
	var hat_ids: Array[String] = [Hats.NONE]
	for hat: Dictionary in Hats.LIST:
		hat_ids.append(hat.id)
	for id in hat_ids:
		_add_to_grid(_hat_grid, _make_hat_tile(id))
	_trail_grid = _make_grid()
	for id in Cosmetics.trail_ids():
		if Progress.cosmetic_visible(id):  # ABYSS is hidden while Descent is off, unless owned
			_add_to_grid(_trail_grid, _make_trail_tile(id))
	_paper_grid = _make_grid()
	for id in Cosmetics.paper_ids():
		if Progress.cosmetic_visible(id):
			_add_to_grid(_paper_grid, _make_paper_tile(id))

	status = _centered_label("", UIKit.TEXT, STATUS_TOP)
	_rule = _centered_label(rule_text("skins"), UIKit.TEXT_DIM, RULE_TOP)
	_build_custom_panel()
	showcase = SkinShowcase.new()
	add_child(showcase)
	showcase.position = Vector2(roundf((320 - SkinShowcase.STAGE_SIZE.x) / 2.0), CUSTOM_TOP)

	# Bottom row: BACK and HATS the same width at the same distance from each edge, the jelly
	# switch centered between them.
	var back := UIKit.add_back_button(self)
	page_button = UIKit.make_button(page_title("hats"), func() -> void: show_page(PAGES[(PAGES.find(page) + 1) % PAGES.size()]), back.custom_minimum_size)
	page_button.position = Vector2(320 - back.position.x - back.custom_minimum_size.x, back.position.y)
	add_child(page_button)
	jelly_button = UIKit.make_button("", _toggle_jelly, Vector2(80, UIKit.button_h()))
	jelly_button.position = Vector2((320 - 80) / 2, back.position.y)
	add_child(jelly_button)
	# i18n: wardrobe hats page button (the worn hat's color), max 72px, 1 line
	color_button = UIKit.make_button(Loc.t("skins.hat_color", "COLOR"), open_color_picker, Vector2(80, UIKit.button_h()))
	add_child(color_button)
	_layout(back)
	color_button.position = jelly_button.position
	color_button.custom_minimum_size.x = jelly_button.size.x
	color_button.size.x = jelly_button.size.x
	show_page("skins")


## Fits the page to the locale's text sizes (docs/ui-rules.md section 10), the first plan that fits
## (_PLANS, in order): the 16 px title first (fix pass F3a: it used to drop to the 8 px font first),
## with the stage in its English place; then the stage on the bottom row between BACK and the page
## button (ending on row 176, like them) and JELLY in the top-left corner; then the gaps one scale step
## closer (GAP_S -> GAP_XS: tile rows, grid to status, rule to stage); then the status / rule lines in
## the script's smaller crisp font (Devanagari 12 px); then (snug) the rule line's deepest possible ink
## one row over the stage; then (flush) the stage one row lower, its frame on the bottom-row buttons' bottom
## border (row 176) instead of the row over it (Arabic's 22 px buttons, fix pass R2: the JELLY corner pushes
## the grid down one row); only then the same steps with the title in the 8 px font. Every
## line is placed by its ink (Language ink_top / ink_bottom; the title by its glyphs, the rule line by
## its texts' glyphs in a taller script) and no two line boxes overlap, so a taller script's empty
## line-box rows don't count as room, and no text inks the stage's frame.
## The bottom row: BACK and the page button keep one width (BACK's, or the longest page name's).
## English metrics keep the source layout untouched.
const _PLANS := [
	{big = true, low = false, tight = false, small = false},
	{big = true, low = true, tight = false, small = false},
	{big = true, low = true, tight = true, small = false},
	{big = true, low = true, tight = true, small = true},
	{big = true, low = true, tight = true, small = false, snug = true},
	{big = true, low = true, tight = true, small = false, snug = true, flush = true},
	{big = false, low = false, tight = false, small = false},
	{big = false, low = true, tight = false, small = false},
	{big = false, low = true, tight = true, small = false},
	{big = false, low = true, tight = true, small = true},
]
## The page button's least width when it leaves the bottom row (BACK's English width).
const _PAGE_MIN_W := 40
## The plan the layout took (an entry of _PLANS plus its rows; empty in English), for the layout tests.
var layout_plan := {}


func _layout(back: Button) -> void:
	var metrics := UIKit.metrics()
	if UIKit.button_h() == UIKit.BUTTON_H:
		# English metrics (en, id, the gate off): the source layout as built, BACK 40 wide as on every screen;
		# the page button one width for every page name (TRAILS / PAPERS: 46), ending EDGE from the right edge.
		var english := [page_title("skins"), page_title("hats"), page_title("trails"), page_title("papers")]
		var page_w: int = UIKit.tab_widths(english, int(back.custom_minimum_size.x))[0]
		UIKit.note_text_w(page_button, english, int(back.custom_minimum_size.x))
		page_button.custom_minimum_size.x = page_w
		page_button.size.x = page_w
		page_button.position.x = UIKit.SCREEN.x - UIKit.EDGE - page_w
		return
	var bottom_texts := [back.text, page_title("skins"), page_title("hats"), page_title("trails"), page_title("papers")]
	var w: int = UIKit.tab_widths(bottom_texts, int(back.custom_minimum_size.x))[0]
	for b: Button in [back, page_button]:
		UIKit.note_text_w(b, bottom_texts, int(back.custom_minimum_size.x))
	if w != int(back.custom_minimum_size.x):
		back.custom_minimum_size.x = w
		back.size.x = w
	page_button.custom_minimum_size.x = w
	page_button.size.x = w
	page_button.position.x = UIKit.SCREEN.x - UIKit.EDGE - w
	var jelly_w := UIKit.tab_widths([_jelly_text(true), _jelly_text(false)], 80)[0]
	var small: Font = null
	var language := get_node_or_null("/root/Language")
	if language and language.has_method("small_font"):
		small = language.small_font(UIKit.locale())
	var stage_x := roundf((UIKit.SCREEN.x - SkinShowcase.STAGE_SIZE.x) / 2.0)
	var ink_top := int(metrics.get("ink_top", 0))
	var ink_bottom := int(metrics.get("ink_bottom", UIKit.TEXT_BODY + UIKit.TEXT_DRIP - 1))
	var titles: Array[String] = []
	for which: String in PAGES:
		titles.append(page_title(which))
	var big_end := UIKit.title_ink_end(titles, _title.get_theme_font("font"))  # (the 16 px title's last inked row, its shadow included)
	if UIKit.tall_script():  # (its line box ends there too: no text box over the grid)
		big_end = maxi(big_end, UIKit.title_top() + int(_title.get_theme_font("font").get_height(UIKit.FONT_BIG)) - 2)
	# The rule line's last inked row: the script's ink_bottom, or in a taller script the rule texts' own
	# glyphs (Arabic: 15 of the 17 any translation reaches), measured as the upgrades screen does (ink_rows).
	var rule_last := ink_bottom
	if UIKit.tall_script():
		var rules: Array[String] = []
		for which: String in ["skins", "jelly", "hats", "trails", "papers"]:
			rules.append(rule_text(which))
		rule_last = mini(ink_bottom, UIKit.ink_rows(rules, _rule.get_theme_font("font")).y)
	var page_w: int = UIKit.tab_widths(titles, _PAGE_MIN_W)[0]  # (the page button alone, top right)
	var stage_h := int(SkinShowcase.STAGE_SIZE.y)
	var low_stage_top := int(UIKit.SCREEN.y) - 4 - stage_h  # (its frame on row 175, over the bottom row's edge)
	var flush_stage_top := UIKit.bottom_row_y() + UIKit.button_h() - stage_h  # (its frame on row 176, as the buttons')
	var plan := {}
	for option: Dictionary in _PLANS:
		if option.small and small == null:
			continue
		# BACK / the page button too wide to flank the stage: the page button goes to the top-right corner
		# (JELLY's mirror) and the stage beside BACK (centred if it can be, else as near as it fits)
		var top_page: bool = option.low and UIKit.EDGE + w + UIKit.GAP_XS > stage_x
		var low_x := stage_x
		if top_page:
			low_x = maxf(stage_x, UIKit.EDGE + UIKit.back_size().x + UIKit.GAP_XS)
			if low_x + SkinShowcase.STAGE_SIZE.x > UIKit.SCREEN.x - UIKit.EDGE:
				continue
		var gap := UIKit.GAP_XS if option.tight else GRID_GAP
		var title_y := UIKit.title_top()
		var title_end := big_end  # (English: 21, so the grid starts on GRID_TOP 23)
		if not option.big:
			var above := int(metrics.ink_above)
			title_y = UIKit.TITLE_Y + above if not option.low else UIKit.EDGE + UIKit.button_v_margins().x
			title_end = title_y + UIKit.line_h() + int(metrics.ink_below) + 1  # (+ the shadow's 2 rows, less 1)
		var grid_top := title_end + 2  # (one clear row under the title's shadow)
		if option.big and option.low:
			# JELLY in the top-left corner (and the page button in the top-right one), beside the title: the
			# title clear of them (JELLY: the skins page's title; the page button: every page's)
			var title_w := UIKit.text_w(page_title("skins"), UIKit.FONT_BIG)
			if UIKit.center_x(title_w) < UIKit.EDGE + jelly_w + UIKit.GAP_M:
				continue
			var clear := true
			for text in titles:
				var tw := UIKit.text_w(text, UIKit.FONT_BIG)
				clear = clear and (not top_page or UIKit.center_x(tw) + tw <= UIKit.SCREEN.x - UIKit.EDGE - page_w - UIKit.GAP_M)
			if not clear:
				continue
		if option.low:
			grid_top = maxi(grid_top, UIKit.EDGE + UIKit.button_h() + UIKit.GAP_XS)
		var line := UIKit.line_h()
		var pitch := UIKit.dense_pitch()
		var first := ink_top  # (the line's first / last inked rows, from its top)
		var last := ink_bottom
		if option.small:
			line = int(small.get_height(UIKit.FONT))
			pitch = line
			first = 0
			last = line - 1
		else:
			last = rule_last
		var grid_end := grid_top + 2 * int(TILE_SIZE.y) + gap
		var status_top := maxi(grid_end, grid_end + gap - first)  # STATUS_TOP in English (the marks' rows over it; its box under the grid)
		var rule_top := status_top + pitch  # RULE_TOP
		var rule_end := rule_top + last + 1
		var stage_top := rule_end + GRID_GAP  # CUSTOM_TOP
		var fits := stage_top + stage_h + UIKit.GAP_S <= UIKit.bottom_row_y()
		if option.low:
			stage_top = flush_stage_top if option.get("flush", false) else low_stage_top
			# (snug: the rule line's lowest possible ink, Language ink_bottom, one clear row over the stage:
			# Arabic, whose rule lines ink 2-3 rows less than the deepest tail any translation has)
			fits = rule_end + (1 if option.get("snug", false) else gap) <= stage_top
		fits = fits and rule_top + line <= stage_top  # (the line box over the stage too)
		plan = option.merged({top_page = top_page, stage_x = low_x if option.low else stage_x, title_y = title_y, grid_top = grid_top, gap = gap, status_top = status_top, rule_top = rule_top,
			rule_end = rule_end, stage_top = stage_top, fits = fits})
		if fits:
			break
	if plan.is_empty():
		return
	layout_plan = plan
	if not plan.big:
		_title.add_theme_font_override("font", UIKit.font_for(UIKit.FONT))
		_title.add_theme_font_size_override("font_size", UIKit.FONT)
		_title.offset_top = plan.title_y
		_title.offset_bottom = plan.title_y + UIKit.line_h()
	for grid: Control in [_skin_grid, _hat_grid, _trail_grid, _paper_grid]:
		grid.position.y = plan.grid_top
		if plan.gap != GRID_GAP:
			grid.add_theme_constant_override("separation", plan.gap)
	for pair: Array in [[status, plan.status_top], [_rule, plan.rule_top]]:
		var label: Label = pair[0]
		label.offset_top = pair[1]
		label.offset_bottom = pair[1] + 10
		if plan.small:
			label.add_theme_font_override("font", small)
	showcase.position = Vector2(plan.stage_x, plan.stage_top)
	custom_panel.position.y = plan.stage_top
	if plan.top_page:  # (BACK keeps its own width; the page button, its page names', top right)
		var back_w := int(UIKit.back_size().x)
		back.custom_minimum_size.x = back_w
		back.size.x = back_w
		UIKit.note_text_w(back, [back.text], int(UIKit.BACK_SIZE.x))
		page_button.custom_minimum_size.x = page_w
		page_button.size.x = page_w
		page_button.position = Vector2(UIKit.SCREEN.x - UIKit.EDGE - page_w, UIKit.EDGE)
		UIKit.note_text_w(page_button, titles, _PAGE_MIN_W)
	jelly_button.custom_minimum_size.x = jelly_w
	jelly_button.size.x = jelly_w
	UIKit.note_text_w(jelly_button, [_jelly_text(true), _jelly_text(false)], 80)
	if plan.low:
		jelly_button.position = Vector2(UIKit.EDGE, UIKit.EDGE)
	else:
		jelly_button.position.x = UIKit.center_x(jelly_w)


## A label centered across the screen, `top` = its top edge.
func _centered_label(text: String, color: Color, top: int) -> Label:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + 10
	return label


## A tile grid centered across the screen: rows of GRID_COLUMNS tiles, a shorter last row
## centered under the others (see _add_to_grid).
func _make_grid() -> VBoxContainer:
	var grid := VBoxContainer.new()
	grid.position = Vector2(roundf((320 - _grid_width()) / 2.0), GRID_TOP)
	grid.add_theme_constant_override("separation", GRID_GAP)
	add_child(grid)
	return grid


func _grid_width() -> float:
	return GRID_COLUMNS * TILE_SIZE.x + (GRID_COLUMNS - 1) * GRID_GAP


func _add_to_grid(grid: VBoxContainer, tile: Control) -> void:
	var row: HBoxContainer = grid.get_child(-1) if grid.get_child_count() > 0 else null
	if row == null or row.get_child_count() >= GRID_COLUMNS:
		row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size.x = _grid_width()
		row.add_theme_constant_override("separation", GRID_GAP)
		grid.add_child(row)
	row.add_child(tile)


## (Re)builds the skin tiles for the version on view (opaque or jelly).
func _fill_skin_grid() -> void:
	for child in _skin_grid.get_children():
		_skin_grid.remove_child(child)
		child.queue_free()
	tiles.clear()
	var ids: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		ids.append(preset.id)
	ids.append(Skins.CUSTOM)
	ids.append(Skins.RAINBOW)
	ids.append(Skins.STOPWATCH)
	for id in ids:
		_add_to_grid(_skin_grid, _make_tile(id))


## The tile grid of page `which`.
func grid_for(which: String) -> VBoxContainer:
	match which:
		"hats": return _hat_grid
		"trails": return _trail_grid
		"papers": return _paper_grid
	return _skin_grid


## Switches between the skins, hats, trails and papers pages.
func show_page(which: String) -> void:
	UIKit.relayout(self)  # (right-to-left: lay out in LTR coordinates, mirrored at the frame's end)
	page = which
	var hats := page == "hats"
	var trails := page == "trails"
	var papers := page == "papers"
	_skin_grid.visible = page == "skins"
	_hat_grid.visible = hats
	_trail_grid.visible = trails
	_paper_grid.visible = papers
	jelly_button.visible = page == "skins"
	color_button.visible = hats
	_title.text = page_title(page)
	page_button.text = page_title(PAGES[(PAGES.find(page) + 1) % PAGES.size()])
	if hats:
		_rule.text = rule_text("hats")
		custom_panel.visible = false
		showcase.visible = false
		_refresh_hats()
		hat_tiles[Progress.selected_hat].grab_focus()
	elif trails:
		_rule.text = rule_text("trails")
		custom_panel.visible = false
		showcase.visible = false
		_refresh_trails()
		trail_tiles[Progress.trail_style].grab_focus()
	elif papers:
		_rule.text = rule_text("papers")
		custom_panel.visible = false
		showcase.visible = false
		_refresh_papers()
		paper_tiles[Progress.map_paper].grab_focus()
	else:
		_refresh()
		_preview(Progress.selected_skin)
		tiles[Progress.selected_skin].grab_focus()


## JELLY ON / OFF: shows the other version of every skin.
func _toggle_jelly() -> void:
	view_jelly = not view_jelly
	# The worn skin follows the switch when its other version is unlocked; otherwise it stays
	# as it is and the status line says the other version is still locked (_refresh).
	var worn: String = Progress.selected_skin
	if view_jelly != Progress.jelly and Progress.is_skin_unlocked(worn, view_jelly):
		Progress.select_skin(worn, view_jelly)
		skin_text.recolor()
		(big_preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if Progress.jelly else 0.0)
	_fill_skin_grid()
	_refresh()
	jelly_button.grab_focus()
	_preview(Progress.selected_skin)


func _make_tile(id: String) -> Button:
	var unlocked: bool = Progress.is_skin_unlocked(id, view_jelly)
	var tile := UIKit.make_button("", func() -> void: _on_tile(id), TILE_SIZE)
	var color: Color = _base_color(id)
	var preview := UIKit.make_slime_preview(color, 1, id == Skins.RAINBOW, view_jelly, id == Skins.STOPWATCH)
	preview.position = TILE_SIZE / 2.0 + Vector2(0, -2)
	if not unlocked:
		preview.modulate = Color(0, 0, 0, 0.85)
		preview.pause()
	tile.add_child(preview)
	tile.set_meta("preview", preview)
	tiles[id] = tile
	return tile


## A hat tile: a slime in the selected skin wearing the hat (a silhouette while locked).
func _make_hat_tile(id: String) -> Button:
	var unlocked: bool = Progress.is_hat_unlocked(id)
	var tile := UIKit.make_button("", func() -> void: _on_hat_tile(id), TILE_SIZE)
	var preview := UIKit.make_slime_preview(Progress.skin_color(), 1, Progress.is_rainbow(), null, Progress.is_stopwatch())
	preview.position = TILE_SIZE / 2.0 + Vector2(0, 2)
	tile.add_child(preview)
	if id != Hats.NONE:
		var hat := Hat.new()
		tile.add_child(hat)
		hat.setup(id, preview, null, Progress.hat_dye_of(id))
		tile.set_meta("hat", hat)
		if not unlocked:
			hat.modulate = Color(0, 0, 0, 0.85)
	if not unlocked:
		preview.modulate = Color(0, 0, 0, 0.85)
		preview.pause()
	hat_tiles[id] = tile
	return tile


## A trail tile: a little strip of that style's goo in the worn skin (drawn like the game's trail:
## 2 px cells through trail.gdshader); a dark silhouette until it's bought.
func _make_trail_tile(id: String) -> Button:
	var owned: bool = Progress.owns_cosmetic(id)
	var tile := UIKit.make_button("", func() -> void: _on_trail_tile(id), TILE_SIZE)
	var look := Cosmetics.trail_look(id, Progress.skin_color(), Progress.is_rainbow())
	var strip := TextureRect.new()
	strip.texture = ImageTexture.create_from_image(Cosmetics.trail_preview(id, Progress.skin_color(), Progress.is_rainbow(), Vector2i(16, 9), not owned))
	strip.size = Vector2(32, 18)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.position = ((TILE_SIZE - strip.size) / 2.0).floor()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owned:
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/trail.gdshader")
		material.set_shader_parameter("stars", 1.0 if look.stars else 0.0)
		material.set_shader_parameter("animate", 0.0 if Progress.reduce_motion else 1.0)
		strip.material = material
	tile.add_child(strip)
	tile.focus_entered.connect(func() -> void:
		if page == "trails":
			_refresh_trails(id))
	trail_tiles[id] = tile
	return tile


func _on_trail_tile(id: String) -> void:
	if Progress.owns_cosmetic(id):
		Progress.equip_cosmetic(id)
	_refresh_trails(id)


## The trails page's status line (for `focus_id`, or the worn style) and tile highlights.
func _refresh_trails(focus_id := "") -> void:
	var id: String = focus_id if focus_id != "" else Progress.trail_style
	if Progress.owns_cosmetic(id):
		# i18n: {name} = the hat's, trail's or paper's name; status line, max 300px, 1 line. The two spaces are spacing.
		if id == Progress.trail_style:
			status.text = Loc.t("skins.wearing", "{name}  (WEARING)", {name = Cosmetics.display_name(id)})
		else:
			status.text = Cosmetics.display_name(id)
	else:
		if Cosmetics.is_earned(id):
			# i18n: {name} = the trail's name, {how} = its unlock condition; max 300px, 1 line
			status.text = Loc.t("skins.name_how", "{name} - {how}", {name = Cosmetics.display_name(id), how = Cosmetics.earned_how(id)})
		else:
			# i18n: {name} = the trail's or paper's name, {price} = tickets; max 300px, 1 line
			status.text = Loc.n("skins.name_price", "{name} - {price} TIX IN THE SHOP", "{name} - {price} TIX IN THE SHOP", Cosmetics.price(id), {name = Cosmetics.display_name(id), price = Cosmetics.price(id)})
	for tile_id: String in trail_tiles:
		UIKit.set_selected(trail_tiles[tile_id], tile_id == Progress.trail_style)


## A paper tile: a little example map drawn on that paper (paper_preview, 33x17, centred like the trails'
## strips); a dark silhouette of the map (as the trails' are) until it's bought.
func _make_paper_tile(id: String) -> Button:
	var owned: bool = Progress.owns_cosmetic(id)
	var tile := UIKit.make_button("", func() -> void: _on_paper_tile(id), TILE_SIZE)
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(paper_preview(id, Progress.skin_color(), not owned))
	map.size = map.texture.get_size()
	map.position = ((TILE_SIZE - map.size) / 2.0).floor()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(map)
	tile.focus_entered.connect(func() -> void:
		if page == "papers":
			_refresh_papers(id))
	paper_tiles[id] = tile
	return tile


## The papers page's picture of paper `paper` (`ink`: the skin color, NIGHT draws in it): the first
## level's MAP TABLE example maze (MapView.example: made up, the same for everyone), fully seen with its
## route and a coin, unthemed (the paper's own colors; parchment = the plain map), its outer wall line
## the frame. `locked`: the same map as a silhouette (Cosmetics.trail_preview's dark; the wall lines
## left clear), whatever the paper.
static func paper_preview(paper: String, ink: Color, locked := false) -> Image:
	var ex := MapView.example(1, false)
	var maze: Dictionary = ex.maze
	var survey := Survey.full(maze, 1.0)
	var coins: Array[Vector2i] = [Vector2i(maze.cells.x - 1 - maze.start.x, maze.cells.y - 1 - maze.start.y)]
	if locked:
		paper = Cosmetics.DEFAULT_PAPER
	var image := MapView.render(maze, survey, MapView.EXAMPLE_SIZES, coins, "", paper, ink)
	if locked:
		var wall: Color = MapView.palette("", paper, ink).wall
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, Color(0, 0, 0, 0) if image.get_pixel(x, y).is_equal_approx(wall) else LOCKED_INK)
	return image


func _on_paper_tile(id: String) -> void:
	if Progress.owns_cosmetic(id):
		Progress.equip_cosmetic(id)
	_refresh_papers(id)


## The papers page's status line (for `focus_id`, or the worn paper) and tile highlights (the same
## lines as the trails page's).
func _refresh_papers(focus_id := "") -> void:
	var id: String = focus_id if focus_id != "" else Progress.map_paper
	if Progress.owns_cosmetic(id):
		if id == Progress.map_paper:
			status.text = Loc.t("skins.wearing", "{name}  (WEARING)", {name = Cosmetics.display_name(id)})
		else:
			status.text = Cosmetics.display_name(id)
	else:
		status.text = Loc.n("skins.name_price", "{name} - {price} TIX IN THE SHOP", "{name} - {price} TIX IN THE SHOP", Cosmetics.price(id), {name = Cosmetics.display_name(id), price = Cosmetics.price(id)})
	for tile_id: String in paper_tiles:
		UIKit.set_selected(paper_tiles[tile_id], tile_id == Progress.map_paper)
		# redraw: NIGHT is drawn in the skin color, which may have changed since the page was built
		var map := paper_tiles[tile_id].get_child(0) as TextureRect
		map.texture = ImageTexture.create_from_image(paper_preview(tile_id, Progress.skin_color(), not Progress.owns_cosmetic(tile_id)))


## The custom color panel, mirrored about the center: the wheel on the left, the big preview
## on the right.
func _build_custom_panel() -> void:
	custom_panel = Control.new()
	custom_panel.position = Vector2(0, CUSTOM_TOP)
	add_child(custom_panel)
	var span := WHEEL_SIZE + WHEEL_GAP + WHEEL_SIZE  # wheel, gap, preview
	var left := roundf((320 - span) / 2.0)
	wheel = ColorWheel.new()
	wheel.position = Vector2(left, 0)
	wheel.size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	custom_panel.add_child(wheel)
	UIKit.add_touch_target(wheel)  # (a finger on the wheel is never taken by a tile's grown touch margin)
	wheel.set_color(Progress.custom_color)
	wheel.color_changed.connect(func(_c: Color) -> void: _on_custom_changed())

	big_preview = UIKit.make_slime_preview(Progress.custom_color, 2)
	big_preview.position = Vector2(left + span - WHEEL_SIZE / 2.0, WHEEL_SIZE / 2.0)
	custom_panel.add_child(big_preview)


## The color a skin's tile and preview are made from.
func _base_color(id: String) -> Color:
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.STOPWATCH:
		return Skins.STOPWATCH_BASE
	if id == Skins.CUSTOM:
		return Progress.custom_color
	return Skins.get_preset(id).color


func _on_tile(id: String) -> void:
	if Progress.is_skin_unlocked(id, view_jelly):
		Progress.select_skin(id, view_jelly)
		skin_text.recolor()
		(big_preview.material as ShaderMaterial).set_shader_parameter("translucency", 1.0 if Progress.jelly else 0.0)
	_refresh(id)
	_preview(id)


## Plays skin `id` (in the version on view) on the preview stage.
func _preview(id: String) -> void:
	var color: Color = _base_color(id)
	showcase.show_skin(color, id == Skins.RAINBOW, view_jelly, not Progress.is_skin_unlocked(id, view_jelly), id == Skins.STOPWATCH)


func _on_hat_tile(id: String) -> void:
	Progress.select_hat(id)
	_refresh_hats(id)


## The worn hat's colors to turn through with COLOR: its own, then each dye of it you own.
func _hat_colors(hat: String) -> Array[String]:
	var colors: Array[String] = [""]
	for dye in Hats.dyes_for(hat):
		if Progress.owns_dye(hat, dye):
			colors.append(dye)
	return colors


## COLOR: the picker of the worn hat's colors (its own and every dye you own of it), two columns of
## tiles in a panel centred over the grid; focus on the worn color, locked inside until it closes.
func open_color_picker() -> void:
	var hat := Progress.selected_hat
	var colors := _hat_colors(hat)
	if colors.size() < 2:
		return
	close_color_picker()
	_picker_blocker = ColorRect.new()
	_picker_blocker.color = Color(0, 0, 0, 0.45)
	_picker_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker_blocker)
	_picker_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker_blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_color_picker())
	var rows := ceili(colors.size() / 2.0)
	var tile_h := UIKit.button_h()
	var box := Vector2(2 * PICK_TILE.x + PICK_GAP + 2 * PICK_PAD, PICK_PAD + UIKit.line_pitch() + rows * (tile_h + PICK_GAP) - PICK_GAP + PICK_PAD)
	_picker = UIKit.add_panel(self, Rect2((Vector2(320, 180) - box) / 2.0, box).abs())
	_picker.position = _picker.position.round()
	var heading := UIKit.make_label(Hats.display_name(hat), UIKit.FONT, UIKit.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(0, PICK_PAD - 2)
	heading.size = Vector2(box.x, 10)
	_picker.add_child(heading)
	picker_tiles.clear()
	for i in colors.size():
		var dye := colors[i]
		var tile := UIKit.make_button("", func() -> void: _pick_hat_color(dye), Vector2(PICK_TILE.x, tile_h))
		var x := PICK_PAD + (i % 2) * (PICK_TILE.x + PICK_GAP)
		if i == colors.size() - 1 and i % 2 == 0:
			x = roundf((box.x - PICK_TILE.x) / 2.0)  # (a last color alone on its row: centred)
		tile.position = Vector2(x, PICK_PAD + UIKit.line_pitch() + (i / 2) * (tile_h + PICK_GAP))
		var swatch := ColorRect.new()
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = Hats.dye_color(dye) if dye != "" else UIKit.TEXT_DIM
		swatch.size = Vector2(5, 5)
		swatch.position = Vector2(4, UIKit.button_v_margins().x + 1)
		swatch.material = Hats.flow_material() if Hats.dye_flows(dye) else null
		tile.add_child(swatch)
		var dye_label := UIKit.make_label(Hats.dye_name(dye), UIKit.FONT, UIKit.TEXT)
		dye_label.position = Vector2(12, UIKit.button_v_margins().x)
		tile.add_child(dye_label)
		UIKit.set_selected(tile, dye == Progress.hat_dye_of(hat))
		_picker.add_child(tile)
		picker_tiles[dye] = tile
	_picker_lock = UIKit.lock_focus(self, _picker)
	(picker_tiles.get(Progress.hat_dye_of(hat), picker_tiles[""]) as Button).grab_focus()


## Closes the color picker (if open) and puts the focus back on COLOR.
func close_color_picker() -> void:
	if _picker == null:
		return
	UIKit.unlock_focus(_picker_lock)
	_picker.queue_free()
	_picker_blocker.queue_free()
	_picker = null
	_picker_blocker = null
	picker_tiles.clear()
	if color_button.visible:
		color_button.grab_focus()


## A picker tile: puts the worn hat on in that color (saved), on its tile too, and closes the picker.
func _pick_hat_color(dye: String) -> void:
	var hat := Progress.selected_hat
	Progress.wear_dye(hat, dye)
	var tile: Button = hat_tiles.get(hat)
	if tile and tile.has_meta("hat"):
		var worn: Hat = tile.get_meta("hat")
		worn.setup(hat, worn.body, null, Progress.hat_dye_of(hat))
	close_color_picker()
	_refresh_hats(hat)


func _on_custom_changed() -> void:
	wheel.value = 1.0
	Progress.custom_color = wheel.get_color()
	Progress.save_progress()
	Skins.apply_to(big_preview.material, Progress.custom_color)
	Skins.apply_to(tiles[Skins.CUSTOM].get_meta("preview").material, Progress.custom_color)
	skin_text.recolor()


## Updates the status line (for `focus_id`, or the worn skin), the highlights and the custom panel.
func _refresh(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_skin
	var worn_here: bool = view_jelly == Progress.jelly
	if not Progress.is_skin_unlocked(id, view_jelly):
		if not Demo.skin_open(id, view_jelly):
			# i18n: status line (demo build), max 300px, 1 line; {name} = a skin name
			status.text = Loc.t("skins.demo_locked", "{name} - IN THE FULL GAME", {name = Skins.display_name(id)})
		elif id == Skins.STOPWATCH:  # both versions open together
			# i18n: {count} = medals needed (30), {have}/{count} = progress; status line, max 312px (EDGE to EDGE, centred), 1 line
			status.text = Loc.n("skins.locked_medals", "LOCKED - EARN ALL {count} MEDALS ({have}/{count})", "LOCKED - EARN ALL {count} MEDALS ({have}/{count})", Progress.medals_max(), {have = Progress.medals_total(false)})
		elif view_jelly:
			# i18n: {level} = the level number to clear on hard mode; status line, max 300px, 1 line
			status.text = Loc.t("skins.locked_jelly", "JELLY LOCKED - HARD CLEAR L{level}", {level = Skins.jelly_level(id)})
		elif id == Skins.RAINBOW:
			# i18n: {have}/{count} = coins found / in the game; status line, max 300px, 1 line
			status.text = Loc.n("skins.locked_coins", "LOCKED - FIND EVERY COIN ({have}/{count})", "LOCKED - FIND EVERY COIN ({have}/{count})", Levels.total_coins(), {have = Progress.coins_earned()})
		elif id == Skins.CUSTOM:
			# i18n: {count} = number of levels (10); status line, max 300px, 1 line
			status.text = Loc.n("skins.locked_levels", "LOCKED - BEAT ALL {count} LEVELS", "LOCKED - BEAT ALL {count} LEVELS", Levels.COUNT)
		else:
			# i18n: {level} = a level number; status line, max 300px, 1 line
			status.text = Loc.t("skins.locked_level", "LOCKED - CLEAR LEVEL {level}", {level = Skins.unlock_level(id)})
	else:
		if worn_here and id == Progress.selected_skin:
			# i18n: {name} = the skin's name; status line, max 300px, 1 line. The two spaces are spacing.
			status.text = Loc.t("skins.selected", "{name}  (SELECTED)", {name = Skins.display_name(id)})
		else:
			status.text = Skins.display_name(id)
	for tile_id: String in tiles:
		var selected: bool = worn_here and tile_id == Progress.selected_skin
		UIKit.set_selected(tiles[tile_id], selected)
	jelly_button.text = _jelly_text(view_jelly)
	_rule.text = rule_text("jelly" if view_jelly else "skins")
	var custom_ready: bool = worn_here and Progress.selected_skin == Skins.CUSTOM and Progress.is_skin_unlocked(Skins.CUSTOM)
	# The color wheel while the custom skin is worn, unless another skin was just clicked to preview.
	custom_panel.visible = custom_ready and page == "skins" and (focus_id == "" or focus_id == Skins.CUSTOM)
	showcase.visible = page == "skins" and not custom_panel.visible
	if custom_ready:
		wheel.value = 1.0


## The JELLY switch's text for either state (its width is measured from both, _layout).
static func _jelly_text(on: bool) -> String:
	# i18n: max 72px (button 80 wide, 4 px margins), 1 line; the two states are whole strings
	return Loc.t("skins.jelly.on", "JELLY: ON") if on else Loc.t("skins.jelly.off", "JELLY: OFF")


## The hats page's status line (for `focus_id`, or the worn hat) and tile highlights.
func _refresh_hats(focus_id := "") -> void:
	var id := focus_id if focus_id != "" else Progress.selected_hat
	if Progress.is_hat_unlocked(id):
		var name := Hats.display_name(id)
		if Progress.hat_dye_of(id) != "":
			name = Loc.t("wheel.dye_title", "{hat} - {dye}", {hat = name, dye = Hats.dye_name(Progress.hat_dye_of(id))})
		if id == Progress.selected_hat:
			# i18n: {name} = the hat's, trail's or paper's name; status line, max 300px, 1 line. The two spaces are spacing.
			status.text = Loc.t("skins.wearing", "{name}  (WEARING)", {name = name})
		else:
			status.text = name
	else:
		# i18n: status line, max 300px, 1 line
		status.text = Loc.t("skins.locked_hat", "LOCKED - WIN IT ON THE HAT WHEEL")
	for tile_id: String in hat_tiles:
		var tile: Button = hat_tiles[tile_id]
		UIKit.set_selected(tile, tile_id == Progress.selected_hat)
	color_button.disabled = _hat_colors(Progress.selected_hat).size() < 2


func _unhandled_input(event: InputEvent) -> void:
	if _picker != null:
		if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
			close_color_picker()  # (Esc / B: the picker first)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
	elif event.is_action_pressed("tab_next") or event.is_action_pressed("tab_prev"):
		var step := 1 if event.is_action_pressed("tab_next") else -1  # LB / RB: the previous / next page
		step *= UIKit.reading_dir()  # (mirrored: RB goes to the tab on the visual left)
		show_page(PAGES[(PAGES.find(page) + step + PAGES.size()) % PAGES.size()])
		get_viewport().set_input_as_handled()
