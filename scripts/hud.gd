extends CanvasLayer

## Three framed pods along the top: slime meter (goo-drop icon + segmented bar in the skin's
## color + percent), run timer (clock icon), level name. Plus a center message on a panel, the
## gold NEW RECORD! banner with sparkling chalices, and a soft vignette under it all.

## Four 25% chunks: 12 px each with 1 px gaps (4 * 12 + 3 = 51).
const BAR_SIZE := Vector2(51, 6)
const SEGMENTS := 4
const CHUNK := 12
const POD_MARGIN := 3
## Below this percent the meter turns red and pulses.
const LOW_PERCENT := 20.0
## Seconds the area name stays up before fading.
const AREA_NAME_TIME := 2.0
## The area texts show at least this long again after a pause or restart prompt closes over them.
const AREA_RESHOW_TIME := 1.0
## Where the area name sits (its line box top): under the timer, between the second-row pods.
const AREA_TOP := 20
## In a randomizer maze: clear of the two-line attempt pod.
const AREA_TOP_UNDER_ATTEMPT := 44
## The story line sits this far under the area name (a 12 px line pitch would put it on the
## second-row pods' bottom rows), and always 2 px clear of every pod it would cross (_place_area_texts).
const STORY_GAP := 15
## Clear space kept between the area name / story line (drips included) and any HUD pod.
const TEXT_CLEARANCE := 2
const FRAME_COLOR := Color8(26, 28, 44)
const LOW_COLOR := Color8(220, 40, 50)
const GOLD := Color8(255, 205, 117)
const CHALICE_FPS := 5.0
## One frame of assets/sprites/chalice_sheet.png (4 frames side by side).
const CHALICE_FRAME := Vector2(16, 20)

var fill: ColorRect
var _shine: ColorRect
var _drop: TextureRect
var _low := false
var _pulse := 0.0
var goo_color := Color8(239, 125, 47)
var _rainbow := false
var _hue := 0.0
var label: Label
var level_label: Label
var message: Label
## The area's name (the level theme), shown under the top bar as a maze starts, then fading.
var area_label: Label
## A story line under the area name (see Story.level_line).
var story_label: Label
var _area_tween: Tween
## How long the current area texts hold before their fade (see show_area_name).
var _area_hold := 0.0
## Where the area name goes when nothing is in its way (AREA_TOP, or under the attempt pod).
var _area_base := float(AREA_TOP)
var _message_panel: PanelContainer
var time_label: Label
## Coins in hand (top bar, beside the slime meter), and coins still to find in this story level
## (top bar, beside the level name; hidden in randomizer mazes, which have none).
var coin_label: Label
var coins_left_label: Label
var _coins_left_pod: Control
## Randomizer only: the attempt on this maze and the tickets a win would pay now
## ("ATTEMPT 2" over "TIX AVAILABLE 4").
var attempt_pod: Control
var attempt_label: Label
var _attempt_icon: TextureRect
## The attempt pod's pop (set_attempt): a bright copy of the TIX AVAILABLE line, flashed over it.
var _attempt_flash: Label
var _attempt_tween: Tween
## Pop timing: wait for the restart's goo wipe (Transition.UNCOVER_TIME 0.32 s) to clear the top of
## the screen, blink bright, dim, bright, then fade (about half a second in all).
const ATTEMPT_POP_DELAY := 0.2
const ATTEMPT_POP_BLINK := 0.08
const ATTEMPT_POP_FADE := 0.34
const ATTEMPT_POP_COLOR := Color(1.6, 1.5, 1.2)
const ATTEMPT_FLASH_TINT := Color.WHITE
const ATTEMPT_POP_PANEL := Color(2.2, 2.0, 1.6)
## DESCENT: the boons held this run, an 8x8 icon each (stacks repeat; unused BACKUP BLADDERs only).
var boon_pod: Control
var boon_strip: GridContainer
## The ids the strip shows, in order (for tests).
var boon_icons: Array[String] = []
const BOON_COLUMNS := 8
## Shown only when a level is beaten faster than its saved record.
var record_banner: CenterContainer
var record_time_label: Label
var _chalices: Array[TextureRect] = []
var _chalice_clock := 0.0
## Buttons offered after a win (replay / next).
var choice_buttons: Array[Button] = []
var _choice_root: Control
var _skin_text: SkinText
## Under the result text: the level's medal tier or the tickets earned (see show_rewards).
var rewards_row: HBoxContainer
var rewards_texts: Array[String] = []
## Shown on the left while an attempt is played with the slime reserve (ASSIST).
var assist_pod: Control
## The ticket workshop's SECOND WIND (set_wind): a drop + WIND tag under the meter, full color while
## ready, dim once used, hidden when it isn't on this run (not bought, hard mode, a first clear).
var wind_pod: Control
var _wind_icon: TextureRect
var wind_state := ""
const WIND_TINT := Color8(170, 236, 255)
const WIND_USED := Color(0.45, 0.45, 0.5, 0.75)
## Dev mode only: a tag naming the dev toggles that are on (made on first use, so it never exists
## in normal play; see set_dev_badge).
var dev_badge: Control
## ABILITIES v1: a pod under the meter with each owned ability's icon and its single use as lit (ready) / dimmed (used)
## (set_abilities; hidden without any).
var ability_pod: Control
var ability_row: HBoxContainer
var ability_items: Array[Dictionary] = []
## HEAT runs: a pod under the level with a flame, the heat and the modifiers' icons (set_heat); the
## timer's clock becomes an hourglass counting down with RACE (set_countdown); the result's heat
## line (show_heat_result).
var heat_pod: Control
var heat_label: Label
var heat_icons: Array[String] = []
var heat_row: HBoxContainer
var heat_texts: Array[String] = []
var _clock_icon: TextureRect
var _message_center: CenterContainer
## The result panel moves up by this when the HEAT line adds a row, so its bottom stays clear of
## the NEW RECORD! banner (13 = the row's 9 px + the 4 px gap).
const HEAT_ROW_LIFT := 13
var _lift := 0
## The rewards row's widest English layout; a wider translation wraps its last text (_wrap_rewards).
const REWARDS_W := 296
var _rewards_row2: HBoxContainer
## The result text as shown in English layout (show_message); _fit_result may pair its lines.
var _message_text := ""
const MESSAGE_PAIR_GAP := "   "
var _fit_queued := false
var _banner_words: BoxContainer
var _banner_title: Label
var countdown := -1.0
const HEAT_TINT := Color8(255, 170, 90)
const RACE_LOW := 10.0
var _dev_label: Label
var _left_bar: BoxContainer
var _right_bar: BoxContainer
var _vignette: ColorRect
const DEV_TINT := Color8(255, 120, 220)
const MEDAL_OWNED := Color8(150, 134, 100)
const MEDAL_OFF := Color8(70, 74, 96)
const TIER_COLORS: Array[Color] = [Color8(70, 74, 96), Color8(214, 140, 84), Color8(206, 214, 232), Color8(255, 205, 117)]
const TICKET_TINT := Color8(255, 226, 150)
const TICKET_DIM := Color(0.55, 0.55, 0.6)
const NEW_BEST_COLOR := Color8(255, 245, 190)
const ASSIST_TINT := Color8(110, 236, 214)


func _ready() -> void:
	var vignette := ColorRect.new()
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = preload("res://assets/shaders/atmosphere.gdshader")
	vignette_material.set_shader_parameter("mist_strength", 0.0)
	# Corners only and light: it must not darken the lit trail (the fog shader has its own edge fall-off).
	vignette_material.set_shader_parameter("vignette_strength", 0.3)
	vignette_material.set_shader_parameter("vignette_start", 0.6)
	vignette_material.set_shader_parameter("vignette_end", 1.15)
	vignette.material = vignette_material
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_vignette = vignette

	# The top bar, mirrored: the meter on the left with the coins in hand under it, the timer in
	# the middle, the level on the right with the coins left to find here under it.
	var left_bar := _make_bar(Control.PRESET_TOP_LEFT)
	_left_bar = left_bar
	var right_bar := _make_bar(Control.PRESET_TOP_RIGHT)
	_right_bar = right_bar

	# Left pod: goo drop, segmented meter, percent.
	var meter_row := _make_pod(left_bar)
	_drop = UIKit.make_icon("drop", goo_color)
	meter_row.add_child(_drop)
	meter_row.add_child(_build_meter())
	label = _make_label()
	label.custom_minimum_size = Vector2(22, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter_row.add_child(label)

	# Coins in hand.
	var coin_row := _make_pod(left_bar)
	coin_row.add_child(UIKit.make_icon("coin", Color.WHITE))
	coin_label = _make_label()
	coin_row.add_child(coin_label)

	# The slime reserve tag (hidden unless this attempt is assisted).
	var assist_row := _make_pod(left_bar)
	assist_pod = assist_row.get_parent()
	assist_row.add_child(UIKit.make_icon("drop", ASSIST_TINT))
	# i18n: HUD pod, max 60px, 1 line; {percent} = extra slime, e.g. 25
	assist_row.add_child(UIKit.make_label(Loc.t("hud.pod.assist", "ASSIST +{percent}%", {percent = roundi(Progress.ASSIST_BONUS * 100.0)}), 8, GOLD))
	assist_pod.visible = false

	# SECOND WIND (hidden unless it's on this run).
	var wind_row := _make_pod(left_bar)
	wind_pod = wind_row.get_parent()
	_wind_icon = UIKit.make_icon("drop", WIND_TINT)
	wind_row.add_child(_wind_icon)
	# i18n: HUD pod, short for the SECOND WIND upgrade, max 40px, 1 line
	wind_row.add_child(UIKit.make_label(Loc.t("hud.pod.wind", "WIND"), 8, WIND_TINT))
	wind_pod.visible = false

	# ABILITIES (hidden unless this run has any).
	ability_row = _make_pod(left_bar)
	ability_row.add_theme_constant_override("separation", 5)
	ability_pod = ability_row.get_parent()
	ability_pod.visible = false

	# Center pod: clock + run time.
	var time_row := _make_pod(null)
	_clock_icon = UIKit.make_icon("clock", UIKit.TEXT)
	time_row.add_child(_clock_icon)
	time_label = _make_label()
	# Tabular digits: the time keeps its width as it runs ("0:00.0" = 28 px), so the pod (sized to
	# it) never changes size. A 4 px separation makes the content even (8 + 4 + 28 = 40): the 48 px
	# pod sits exactly on the screen's center with ink pads of 4 / 4.
	time_label.add_theme_font_override("font", UIKit.tabular_font())
	time_row.add_theme_constant_override("separation", 4)
	time_row.add_child(time_label)

	# The level name, and under it the coins still hidden in this level (a dim coin).
	var level_row := _make_pod(right_bar)
	level_label = _make_label()
	level_row.add_child(level_label)
	var left_row := _make_pod(right_bar)
	_coins_left_pod = left_row.get_parent()
	left_row.add_child(UIKit.make_icon("coin", Color(0.75, 0.75, 0.8)))
	coins_left_label = _make_label(SkinText.ROLE_DIM)
	left_row.add_child(coins_left_label)

	# Randomizer mazes: the attempt and the tickets a win would pay now (see set_attempt).
	var attempt_row := _make_pod(right_bar)
	attempt_pod = attempt_row.get_parent()
	_attempt_icon = UIKit.make_icon("ticket", Color.WHITE)
	attempt_row.add_child(_attempt_icon)
	attempt_label = UIKit.make_label("", 8, TICKET_TINT)
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	attempt_row.add_child(attempt_label)
	_attempt_flash = UIKit.make_label("", 8, ATTEMPT_FLASH_TINT)
	_attempt_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_attempt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attempt_flash.modulate.a = 0.0
	attempt_label.add_child(_attempt_flash)
	attempt_pod.visible = false

	# DESCENT: the run's boons as a strip of icons (see set_boons), under the pot pod.
	var boon_row := _make_pod(right_bar)
	boon_pod = boon_row.get_parent()
	boon_strip = GridContainer.new()
	boon_strip.columns = BOON_COLUMNS
	boon_strip.add_theme_constant_override("h_separation", 1)
	boon_strip.add_theme_constant_override("v_separation", 1)
	boon_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boon_row.add_child(boon_strip)
	boon_pod.visible = false

	area_label = _make_label(SkinText.ROLE_DIM)
	area_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_area_base = _area_top()
	area_label.offset_top = _area_base
	area_label.offset_bottom = _area_base + 10
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.visible = false
	add_child(area_label)
	story_label = _make_label(SkinText.ROLE_DIM)
	story_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	story_label.offset_top = _area_base + _story_gap()
	story_label.offset_bottom = _area_base + _story_gap() + 10
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.visible = false
	add_child(story_label)

	var message_center := CenterContainer.new()
	_message_center = message_center
	message_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_center.offset_top = 20
	message_center.offset_bottom = -40
	message_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_center)
	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_center.add_child(_message_panel)
	var message_box := VBoxContainer.new()
	message_box.add_theme_constant_override("separation", 4)
	message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.add_child(message_box)
	message = _make_label(SkinText.ROLE_TITLE)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_box.add_child(message)
	rewards_row = HBoxContainer.new()
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.add_theme_constant_override("separation", 6)
	rewards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards_row.visible = false
	message_box.add_child(rewards_row)
	heat_row = HBoxContainer.new()
	heat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	heat_row.add_theme_constant_override("separation", 4)
	heat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_row.visible = false
	message_box.add_child(heat_row)
	# The panel shows whenever the message does.
	message.visibility_changed.connect(func() -> void: _message_panel.visible = message.visible)
	message.visible = false
	_message_panel.visible = false

	_build_record_banner()
	_build_choice_row()
	set_slime(100.0)
	set_time(0.0)
	_skin_text = SkinText.new()
	_skin_text.theme_owner = _choice_root
	add_child(_skin_text)


func set_slime(percent: float) -> void:
	fill.size.x = roundf(BAR_SIZE.x * clampf(percent, 0.0, 100.0) / 100.0)
	_shine.size.x = fill.size.x
	_low = percent < LOW_PERCENT
	fill.color = LOW_COLOR if _low else goo_color
	if not _low:
		fill.modulate = Color.WHITE
	label.text = Loc.t("hud.slime_percent", "{percent}%", {percent = ceili(percent)})  # i18n: slime meter, max 24px, grows to 40px (the pod widens)


## A column of pods anchored to a top corner, each hugging that side; the right one grows
## leftward.
func _make_bar(preset: Control.LayoutPreset) -> BoxContainer:
	var bar := VBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_theme_constant_override("separation", 2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_preset(preset)
	var edge := UIKit.hud_edge()  # (POD_MARGIN, unless a phone's safe area cuts deeper)
	bar.offset_top = edge.y
	if preset == Control.PRESET_TOP_RIGHT:
		bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bar.offset_left = -edge.x
		bar.offset_right = -edge.x
	else:
		bar.offset_left = edge.x
		bar.offset_right = edge.x
	return bar


## A framed pod: in `bar`, or (null) on its own centered at the top. Returns its row to fill.
func _make_pod(bar: BoxContainer) -> HBoxContainer:
	var pod := PanelContainer.new()
	pod.add_theme_stylebox_override("panel", UIKit.panel_style(true))
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Every one-line pod is POD_H tall (an 8 px icon sets it; text-only pods match), so pods in a
	# row share their bottom edge and the mirrored second-row pods start on the same row.
	pod.custom_minimum_size.y = UIKit.pod_h()
	if bar:
		bar.add_child(pod)
		var right := bar.grow_horizontal == Control.GROW_DIRECTION_BEGIN
		pod.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	else:
		# A CenterContainer keeps it on whole pixels as the time's width changes.
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		center.offset_top = UIKit.hud_edge().y
		center.add_child(pod)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod.add_child(row)
	return row


## The slime bar: dark frame, sunken track, goo fill with a 1 px shine, segment ticks.
func _build_meter() -> Control:
	var meter := Control.new()
	meter.custom_minimum_size = BAR_SIZE + Vector2(2, 2)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_rect(meter, Vector2.ZERO, BAR_SIZE + Vector2(2, 2), FRAME_COLOR)
	_add_rect(meter, Vector2.ONE, BAR_SIZE, Color8(40, 34, 52))
	fill = _add_rect(meter, Vector2.ONE, BAR_SIZE, goo_color)
	_shine = _add_rect(meter, Vector2.ONE, Vector2(BAR_SIZE.x, 1), Color(1, 1, 1, 0.35))
	for i in range(1, SEGMENTS):
		_add_rect(meter, Vector2(i * (CHUNK + 1), 1), Vector2(1, BAR_SIZE.y), Color(FRAME_COLOR, 0.6))
	return meter


func _add_rect(parent: Control, at: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = at
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## Updates the coin counts: `total` in hand, and `found` of the `here` coins in this level
## (`here` = 0 hides that pod: randomizer mazes have no coins). `pop` flashes the total gold
## (a coin was just picked up).
func set_coins(total: int, found: int, here: int, pop := false) -> void:
	coin_label.text = str(clampi(total, 0, 999))  # never shows a negative balance
	# i18n: HUD coin pod, max 60px, grows to 128px (the pod widens under the timer row), 1 line; {count} = coins still hidden in the level
	var left_text := Loc.t("hud.pod.all_found", "ALL FOUND") if found >= here \
		else Loc.n("hud.pod.coins_left", "{count} LEFT", "{count} LEFT", here - found)
	var resized := left_text != coins_left_label.text  # (a wider pod: the area texts check it again)
	coins_left_label.text = left_text
	if _coins_left_pod.visible != (here > 0):
		_coins_left_pod.visible = here > 0
		resized = true
	if resized:
		_pods_changed()
	if pop:
		coin_label.add_theme_color_override("font_color", GOLD)
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_callback(func() -> void: _skin_text.recolor())


## The attempt pod (randomizer mazes only): which attempt at this maze it is and the tickets a win
## would pay right now (every cap applied), counting down attempt by attempt: "ATTEMPT 1" over
## "TIX AVAILABLE 5", then 4, 3, 2 and 1 from the 5th; 1 when capped, dim 0 when a win would pay
## nothing. Called every frame by the game (only a changed text touches the label).
## `pop`: the number just changed (a restart): the TIX AVAILABLE line flashes bright twice and
## fades back (ATTEMPT_POP_*, about half a second, after the restart's goo wipe has cleared the top).
func set_attempt(attempt: int, payout: int, pop := false) -> void:
	var tix := _tix_line(payout)
	# i18n: HUD attempt pod, line 1, max 80px, grows to 128px (the pod widens under the timer row); {n} = which try at this maze
	var text := Loc.lines([Loc.t("hud.pod.attempt", "ATTEMPT {n}", {n = mini(attempt, 99)}), tix])
	if text == attempt_label.text and attempt_pod.visible and not pop:
		return  # called every frame: only a change touches the label
	attempt_pod.visible = true
	# The two-line pod reaches down to y 40: the area name moves under it instead of under the timer.
	_area_base = _area_top_under_attempt()
	area_label.offset_top = _area_base
	area_label.offset_bottom = _area_base + 10
	attempt_label.text = text
	_pods_changed()
	var color := TICKET_TINT if payout > 0 else MEDAL_OWNED
	attempt_label.add_theme_color_override("font_color", color)
	_attempt_icon.modulate = Color.WHITE if payout > 0 else TICKET_DIM
	# The flash: a bright copy of the second line drawn over it (the first line left blank).
	_attempt_flash.text = Loc.lines([" ", tix])
	if _attempt_tween:
		_attempt_tween.kill()
		_attempt_tween = null
	_attempt_flash.modulate.a = 0.0
	_attempt_icon.self_modulate = Color.WHITE
	attempt_pod.self_modulate = Color.WHITE
	if not pop:
		return
	var flash := func(a: float) -> void:
		_attempt_flash.modulate.a = a
		_attempt_icon.self_modulate = Color.WHITE.lerp(ATTEMPT_POP_COLOR, a)
		attempt_pod.self_modulate = Color.WHITE.lerp(ATTEMPT_POP_PANEL, a)
	_attempt_tween = create_tween()
	_attempt_tween.tween_interval(ATTEMPT_POP_DELAY)
	_attempt_tween.tween_method(flash, 1.0, 1.0, ATTEMPT_POP_BLINK)
	_attempt_tween.tween_method(flash, 0.25, 0.25, ATTEMPT_POP_BLINK)
	_attempt_tween.tween_method(flash, 1.0, 0.0, ATTEMPT_POP_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_attempt_tween.tween_callback(func() -> void: _attempt_tween = null)


## DESCENT: the pot pod (in the attempt pod's place): "POT 6" with the ticket icon, and a second
## line: PAID RUN n/2 (the day's paid slot this run took on floor 1, or will take), or why it pays
## less: PRACTICE (no paid slot left today), NO TICKETS (dev toggles), PAYS 1 (no MORE SLIME). `gain`
## > 0 adds "+N" (the floor just cleared). Dim when it pays nothing.
func set_pot(pot: int, cap: String, gain := 0, slot := 0) -> void:
	# i18n: HUD pot pod, line 1, max 80px, grows to 128px (the pod widens under the timer row); {count} = tickets in the pot, {gain} = just added
	var text := Loc.n("hud.pod.pot_gain", "POT {count} +{gain}", "POT {count} +{gain}", pot, {gain = gain}) if gain > 0 \
		else Loc.n("hud.pod.pot", "POT {count}", "POT {count}", pot)
	var why := ""
	# i18n: HUD pot pod, line 2 (why it pays less), max 80px each, grows to 128px (the pod widens under the timer row)
	match cap:
		"practice":
			why = Loc.t("hud.pod.practice", "PRACTICE")
		"dev":
			why = Loc.t("hud.pod.no_tickets", "NO TICKETS")
		"slime":
			why = Loc.t("hud.pod.pays_1", "PAYS 1")
		"":
			if slot > 0:
				# i18n: HUD pot pod, line 2, max 80px, grows to 128px (the pod widens under the timer row); {slot} of {total} paid runs today
				why = Loc.t("hud.pod.paid_run", "PAID RUN {slot}/{total}", {slot = slot, total = Economy.DESCENT_PAID_PER_DAY})
	if why != "":
		text = Loc.lines([text, why])
	if text == attempt_label.text and attempt_pod.visible:
		return
	attempt_pod.visible = true
	_area_base = _area_top_under_attempt()
	area_label.offset_top = _area_base
	area_label.offset_bottom = _area_base + 10
	story_label.offset_top = _area_base + UIKit.line_pitch()  # the floor number under the area name
	story_label.offset_bottom = _area_base + UIKit.line_pitch() + 10
	attempt_label.text = text
	_pods_changed()
	var pays := cap == "" or cap == "slime"
	attempt_label.add_theme_color_override("font_color", TICKET_TINT if pays else MEDAL_OWNED)
	_attempt_icon.modulate = Color.WHITE if pays else TICKET_DIM


## DESCENT: shows the run's boons (Descent.IDS order; stacks repeat; BIG GULP, used at once, and
## used BACKUP BLADDERs are left out). Hidden when there are none.
func set_boons(boons: Dictionary, bladders_left := 0) -> void:
	for child in boon_strip.get_children():
		child.queue_free()
	boon_icons.clear()
	for id in Descent.IDS:
		var n := Descent.held(boons, id)
		if id == "gulp":
			n = 0
		elif id == "bladder":
			n = bladders_left
		for i in n:
			boon_strip.add_child(BoonIcons.make(id))
			boon_icons.append(id)
	boon_pod.visible = not boon_icons.is_empty()
	_pods_changed()


## ABILITIES: `items` = [{id, left, max}] (AbilityRunner.strip): the icon, lit while its one use is
## left, dimmed once used. A use that just went pops its icon (not with
## Reduce Motion).
func set_abilities(items: Array[Dictionary]) -> void:
	var before := {}
	for item in ability_items:
		before[item.id] = int(item.left)
	ability_items = items.duplicate(true)
	for child in ability_row.get_children():
		ability_row.remove_child(child)
		child.queue_free()
	var progress := get_node_or_null("/root/Progress")
	var still: bool = progress != null and progress.reduce_motion
	for item in items:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Abilities.make_icon(item.id)
		icon.modulate = Color.WHITE if int(item.left) > 0 else Color(0.5, 0.5, 0.55, 0.7)
		group.add_child(icon)
		ability_row.add_child(group)
		if before.has(item.id) and int(item.left) < int(before[item.id]) and not still:
			icon.modulate = Color(2.0, 2.0, 2.0)
			icon.create_tween().tween_property(icon, "modulate",
				Color.WHITE if int(item.left) > 0 else Color(0.5, 0.5, 0.55, 0.7), 0.35)
	ability_pod.visible = not items.is_empty()
	_pods_changed()


## True while the attempt pod's pop is still playing (or waiting for the goo wipe to clear).
func attempt_flashing() -> bool:
	return _attempt_tween != null and _attempt_tween.is_valid() and _attempt_tween.is_running()


func set_time(seconds: float) -> void:
	time_label.text = UIKit.format_time(seconds)


## RACE: the timer counts down `seconds` left (an hourglass instead of the clock; red under RACE_LOW).
func set_countdown(seconds: float) -> void:
	seconds = maxf(seconds, 0.0)
	if countdown < 0.0:
		_clock_icon.texture = Heat.icon("race")
		_clock_icon.modulate = Color.WHITE
	countdown = seconds
	time_label.text = UIKit.format_time(seconds)
	var low := seconds < RACE_LOW
	if low != time_label.has_theme_color_override("font_color"):
		if low:
			time_label.add_theme_color_override("font_color", LOW_COLOR)
		else:
			time_label.remove_theme_color_override("font_color")


## HEAT: the pod under the level name (a flame in the run's tier color, HEAT n, and the icon of each
## modifier on). Built the first time it is needed.
func set_heat(heat: int, ids: Array[String]) -> void:
	if heat_pod == null:
		var row := _make_pod(_right_bar)
		heat_pod = row.get_parent()
		heat_pod.name = "HeatPod"
		row.add_theme_constant_override("separation", 2)
		row.add_child(UIKit.fit_icon(Heat.make_rect(Heat.flame(heat))))
		heat_label = UIKit.make_label("", 8, HEAT_TINT)
		row.add_child(heat_label)
		for id in ids:
			row.add_child(UIKit.fit_icon(Heat.make_rect(Heat.icon(id))))
	heat_label.text = Loc.t("hud.pod.heat", "HEAT {heat}", {heat = heat})  # i18n: HUD pod, max 50px, grows to 128px (the pod widens under the timer row); {heat} = heat level
	heat_icons = ids.duplicate()
	heat_pod.visible = heat > 0
	_pods_changed()


## The result's HEAT line (a heat run's clear): the flame and HEAT n, then the bounty it paid
## (+N TICKETS), NEW BEST HEAT, or the best so far. `result` = Progress.complete_heat's ({} when the
## run could earn nothing: dev toggles).
func show_heat_result(heat: int, result: Dictionary) -> void:
	for child in heat_row.get_children():
		child.queue_free()
	heat_texts.clear()
	heat_row.add_child(Heat.make_rect(Heat.flame(heat)))
	# i18n: result heat row (one line with icons), max 120px each; {heat} = heat level
	_heat_text(Loc.t("result.heat", "HEAT {heat}", {heat = heat}), HEAT_TINT)
	var paid := int(result.get("paid", 0))
	if paid > 0:
		heat_row.add_child(UIKit.make_icon("ticket", Color.WHITE))
		# i18n: max 120px; {count} = tickets the heat bounty paid (after a ticket icon)
		_heat_text(Loc.n("result.heat_bounty", "BOUNTY +{count}", "BOUNTY +{count}", paid), TICKET_TINT)
	elif result.get("new_best", false):
		_heat_text(Loc.t("result.heat_new_best", "NEW BEST HEAT!"), NEW_BEST_COLOR)  # i18n: max 120px
	elif not result.is_empty():
		_heat_text(Loc.t("result.heat_best", "BEST HEAT {heat}", {heat = int(result.best)}), MEDAL_OWNED)  # i18n: max 120px
	if not heat_row.visible:
		_message_center.offset_top -= HEAT_ROW_LIFT
		_message_center.offset_bottom -= HEAT_ROW_LIFT
		_lift = HEAT_ROW_LIFT
	heat_row.visible = true
	_queue_fit()


func _heat_text(text: String, color: Color) -> void:
	heat_row.add_child(UIKit.make_label(text, 8, color))
	heat_texts.append(text)


## The assist tag in the top bar.
func set_assist(on: bool) -> void:
	assist_pod.visible = on
	_pods_changed()


## SECOND WIND's tag: "" hides it, "ready" full color, "refilling" flashes bright, "used" dim.
func set_wind(state: String) -> void:
	wind_state = state
	wind_pod.visible = state != ""
	_pods_changed()
	match state:
		"ready":
			wind_pod.modulate = Color.WHITE
		"refilling":
			wind_pod.modulate = Color(1.8, 1.8, 1.8)
			var tween := wind_pod.create_tween()
			tween.tween_property(wind_pod, "modulate", WIND_USED, 0.6)
		"used":
			wind_pod.modulate = WIND_USED


## Dev mode: a DEV tag under the meter naming the toggles that are on ("" hides it). Only ever
## called by the dev toggles, so normal play never builds it.
func set_dev_badge(text: String) -> void:
	if text == "" and dev_badge == null:
		return
	if dev_badge == null:
		var row := _make_pod(_left_bar)
		dev_badge = row.get_parent()
		_dev_label = UIKit.make_label("", 8, DEV_TINT)
		row.add_child(_dev_label)
	_dev_label.text = "DEV " + text
	dev_badge.visible = text != ""
	_pods_changed()


## The corner vignette (off while the dev FULL BRIGHT toggle is on).
func set_vignette(on: bool) -> void:
	_vignette.visible = on


## Under the result text. A story clear shows its medal tier as three icons (gold up to the tier
## won this run, dim gold up to an older better tier, dark for the rest), the tier name and NEW BEST
## when it raised the saved one. `info` is Progress.record_clear's result. A randomizer win shows
## the ticket vouchers it paid ({tickets, attempt, cap}: "TICKET! ATTEMPT 2 = +4", plus why when
## capped to 1: cap "replay" = REPLAYED SEED; cap "slime" (no MORE SLIME bought) shows no reason line,
## since the game never nudges toward an upgrade, D12); `capped` says the day's
## limit is used up, `repeat` that this seed already paid today.
## An assisted run says it earns nothing instead.
func show_rewards(info: Dictionary) -> void:
	hide_area_texts()  # the result panel can reach up to them
	for child in rewards_row.get_children():
		child.queue_free()
	if _rewards_row2:
		for child in _rewards_row2.get_children():
			child.queue_free()
		_rewards_row2.visible = false
	rewards_texts.clear()
	if info.get("dev", false):
		_reward_label("DEV TOGGLES: NO MEDALS, RECORDS OR TICKETS", MEDAL_OWNED)
	elif info.get("offer", false):
		# i18n: result reward line, max 296px; wraps onto 2 lines past that (broken at a space), lines 2; {percent} = extra slime, e.g. 25
		_reward_label(Loc.t("result.assist_offer", "ASSIST: +{percent}% SLIME, NO MEDALS/TICKETS",
			{percent = roundi(Progress.ASSIST_BONUS * 100.0)}), MEDAL_OWNED)
	elif info.get("assisted", false):
		_reward_label(Loc.t("result.assisted", "ASSIST: NO MEDALS, RECORDS OR TICKETS"), MEDAL_OWNED)  # i18n: max 296px
	elif info.has("tier"):
		var tier: int = info.tier
		var best: int = info.best
		for i in range(1, 4):
			var color: Color = TIER_COLORS[tier] if tier >= i else (MEDAL_OWNED if best >= i else MEDAL_OFF)
			rewards_row.add_child(UIKit.make_icon("medal", color))
		_reward_label(_medal_name(tier), TIER_COLORS[tier])
		if info.new_best:
			_reward_label(Loc.t("result.new_best", "NEW BEST!"), NEW_BEST_COLOR)  # i18n: medal row, max 90px
		elif best > tier:
			_reward_label(_best_medal(best), MEDAL_OWNED)
	elif info.get("repeat", false):
		# i18n: result reward line, max 296px; wraps onto 2 lines past that (broken at a space), lines 2
		_reward_label(Loc.t("result.seed_paid", "SEED ALREADY PAID TODAY - TRY NEW MAZE"), MEDAL_OWNED)
	elif info.get("capped", false):
		_reward_label(Loc.t("result.ticket_limit", "DAILY TICKET LIMIT REACHED"), MEDAL_OWNED)  # i18n: max 296px
	else:
		rewards_row.add_child(UIKit.make_icon("ticket", Color.WHITE))
		if info.has("attempt"):
			# i18n: after a ticket icon, max 160px, grows to 270px (the rewards row; past 296 its last text takes a second row); {n} = which try, {count} = tickets paid
			_reward_label(Loc.n("result.ticket_attempt", "TICKET! ATTEMPT {n} = +{count}", "TICKET! ATTEMPT {n} = +{count}",
				int(info.tickets), {n = int(info.attempt)}), TICKET_TINT)
		else:
			# i18n: after a ticket icon, max 160px; {count} = tickets paid
			_reward_label(Loc.n("result.tickets", "+{count} TICKETS", "+{count} TICKETS", int(info.tickets)), TICKET_TINT)
		match info.get("cap", ""):
			"replay":
				_reward_label(Loc.t("result.replayed_seed", "REPLAYED SEED"), MEDAL_OWNED)  # i18n: max 120px
	rewards_row.visible = true
	_wrap_rewards()
	_queue_fit()


## `text` with every line wider than the text column (REWARDS_W) broken onto two balanced lines at a
## space (a translation; English lines all fit, so English is unchanged).
static func _break_long(text: String) -> String:
	var lines := text.split("\n")
	for i in lines.size():
		if UIKit.text_w(lines[i]) > REWARDS_W:
			lines[i] = UIKit.break_line(lines[i], REWARDS_W)
	return "\n".join(lines)


## A rewards row wider than the text column (a translation) puts its last text on a second centred
## row under it, so the result panel never reaches the screen's sides.
func _wrap_rewards() -> void:
	var items := rewards_row.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	var labels := items.filter(func(c: Node) -> bool: return c is Label)
	if labels.size() < 2:
		return
	var width := float(rewards_row.get_theme_constant("separation") * (items.size() - 1))
	for item: Control in items:
		width += UIKit.text_w((item as Label).text) if item is Label else item.get_combined_minimum_size().x
	if width <= REWARDS_W:
		return
	if _rewards_row2 == null:
		_rewards_row2 = HBoxContainer.new()
		_rewards_row2.alignment = BoxContainer.ALIGNMENT_CENTER
		_rewards_row2.add_theme_constant_override("separation", 6)
		_rewards_row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rewards_row.get_parent().add_child(_rewards_row2)
		rewards_row.get_parent().move_child(_rewards_row2, rewards_row.get_index() + 1)
	var last: Label = labels[-1]
	rewards_row.remove_child(last)
	_rewards_row2.add_child(last)
	_rewards_row2.visible = true


## A medal tier's name (1 bronze, 2 silver, 3 gold) on the result's medal row.
static func _medal_name(tier: int) -> String:
	# i18n: medal row, max 60px each
	match tier:
		1:
			return Loc.t("result.medal.bronze", "BRONZE")
		2:
			return Loc.t("result.medal.silver", "SILVER")
		3:
			return Loc.t("result.medal.gold", "GOLD")
	return ""


## The older better tier on the medal row ("BEST GOLD").
static func _best_medal(tier: int) -> String:
	# i18n: medal row, max 90px each; the medal name is part of the line so it can agree with "best"
	match tier:
		1:
			return Loc.t("result.best_medal.bronze", "BEST BRONZE")
		2:
			return Loc.t("result.best_medal.silver", "BEST SILVER")
		3:
			return Loc.t("result.best_medal.gold", "BEST GOLD")
	return ""


## The attempt pod's second line: the tickets a win would pay now.
static func _tix_line(payout: int) -> String:
	# i18n: HUD attempt pod, line 2, max 80px; TIX = tickets; {count} = tickets a win pays now
	return Loc.n("hud.pod.tix_available", "TIX AVAILABLE {count}", "TIX AVAILABLE {count}", payout)


func _reward_label(text: String, color: Color) -> void:
	var l := UIKit.make_label(_break_long(text), 8, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # (two lines when a translation is too long)
	rewards_row.add_child(l)
	rewards_texts.append(text)


## The gold NEW RECORD! banner (big text + the new time) between two sparkling chalices.
func show_record(seconds: float) -> void:
	record_time_label.text = UIKit.format_time(seconds)
	record_banner.visible = true
	_queue_fit()


## Shows a row of buttons, each [text, Callable]; button `focus` (default: the last) gets
## keyboard focus.
func show_choices(options: Array, focus := -1) -> void:
	hide_area_texts()
	var row: HBoxContainer = _choice_root.get_child(0).get_child(0)
	for child in row.get_children():
		child.queue_free()
	choice_buttons.clear()
	# One width for the row (CHOICE_SIZE in English), from the longest translation.
	var widths := UIKit.tab_widths(options.map(func(o: Array) -> String: return o[0]), int(UIKit.CHOICE_SIZE.x))
	for i in options.size():
		var option: Array = options[i]
		var button := UIKit.make_button(option[0], option[1], Vector2(widths[i], UIKit.choice_size().y))
		UIKit.note_text_w(button, options.map(func(o: Array) -> String: return o[0]), int(UIKit.CHOICE_SIZE.x))
		row.add_child(button)
		choice_buttons.append(button)
	_choice_root.visible = true
	_queue_fit()
	_skin_text.recolor()
	choice_buttons[focus].grab_focus()


func _build_choice_row() -> void:
	_choice_root = Control.new()
	_choice_root.theme = UIKit.make_theme()
	_choice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.visible = false
	add_child(_choice_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = UIKit.choice_y() - 1
	center.offset_bottom = UIKit.choice_y() + UIKit.button_h() + 2
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.CHOICE_GAP)
	center.add_child(row)


func _build_record_banner() -> void:
	record_banner = CenterContainer.new()
	record_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	record_banner.offset_top = 109
	record_banner.offset_bottom = 150
	record_banner.visible = false
	add_child(record_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	record_banner.add_child(row)
	var words := BoxContainer.new()  # (vertical; one row in the compact banner, _set_banner_compact)
	words.vertical = true
	words.add_theme_constant_override("separation", 5)  # room for the title's drips (they hang below its line box)
	_banner_words = words
	var title := _gold_label(Loc.t("result.new_record", "NEW RECORD!"), 16)  # i18n: big 16 px font, max 200px
	_banner_title = title
	record_time_label = _gold_label("", 8)
	words.add_child(title)
	words.add_child(record_time_label)
	row.add_child(_make_chalice())
	row.add_child(words)
	row.add_child(_make_chalice())


func _make_chalice() -> TextureRect:
	var chalice := TextureRect.new()
	var frame := AtlasTexture.new()
	frame.atlas = preload("res://assets/sprites/chalice_sheet.png")
	frame.region = Rect2(Vector2.ZERO, CHALICE_FRAME)
	chalice.texture = frame
	# Drawn at 2x (whole pixels stay crisp) to match the big NEW RECORD! text.
	chalice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chalice.stretch_mode = TextureRect.STRETCH_SCALE
	chalice.custom_minimum_size = CHALICE_FRAME * 2
	chalice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chalices.append(chalice)
	return chalice


## Gold text that keeps its color whatever the skin (not in the SkinText group).
func _gold_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.material = UIKit.text_material()
	UIKit.use_big_font(l, size)
	return l


## Shows the area name for a moment, then fades it out.
func show_area_name(text: String, story_line := "") -> void:
	area_label.text = Loc.t("hud.area.name", "- {name} -", {name = text})  # i18n: {name} = level / area name, max 296px
	area_label.visible = true
	area_label.modulate.a = 1.0
	story_label.text = story_line
	_wrap_story_line()
	story_label.visible = story_line != ""
	story_label.modulate.a = 1.0
	_place_area_texts()
	_area_hold = AREA_NAME_TIME + (1.0 if story_line != "" else 0.0)
	_fade_area_texts(_area_hold)


## Holds the area texts for `hold` seconds, then fades them out.
func _fade_area_texts(hold: float) -> void:
	if _area_tween:
		_area_tween.kill()
	var tween := create_tween()
	_area_tween = tween
	tween.tween_interval(hold)
	tween.tween_property(area_label, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(story_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		area_label.visible = false
		story_label.visible = false)


## Moves the area name and the story line down (each as a whole line) until their text, drips
## included, is TEXT_CLEARANCE clear of every pod showing in the top corners (the HEAT pod, an
## ASSIST or DEV tag, a long line under the coin pods). Pods are measured by their minimum sizes, so
## it works before the bars have sorted.
func _place_area_texts() -> void:
	var pods := pod_rects()
	var y := _clear_y(area_label, _area_base, pods)
	area_label.offset_top = y
	area_label.offset_bottom = y + 10
	if story_label.text != "":
		var story_top := y + (UIKit.line_pitch() if attempt_pod.visible else _story_gap())
		story_top = _clear_y(story_label, story_top, pods)
		story_label.offset_top = story_top
		story_label.offset_bottom = story_top + 10


## The first line top from `top` down at which `label`'s centered text clears every rect in `pods`.
func _clear_y(label: Label, top: float, pods: Array[Rect2]) -> float:
	var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var lines := label.text.count("\n") + 1  # (a story line broken by _wrap_story_line)
	var x := roundf((UIKit.SCREEN.x - width) / 2.0)
	var metrics := UIKit.metrics()
	var above := float(metrics.ink_above)
	var tall := float(UIKit.text_block_h(lines) + int(metrics.ink_below))  # line boxes + drips (TEXT_BODY + TEXT_DRIP in English)
	var moved := true
	while moved:
		moved = false
		var ink := Rect2(x, top - above, width, above + tall).grow(TEXT_CLEARANCE)
		for pod in pods:
			if ink.intersects(pod):
				top = pod.end.y + TEXT_CLEARANCE + above
				moved = true
	return top


## Where the visible pods of the two top-corner bars sit (from their minimum sizes, so before the
## containers sort too), and the centered timer pod.
func pod_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var edge := UIKit.hud_edge()
	for bar: BoxContainer in [_left_bar, _right_bar]:
		var y := float(edge.y)
		for pod: Control in bar.get_children():
			if not pod.visible:
				continue
			var size := pod.get_combined_minimum_size()
			var x := float(edge.x) if bar == _left_bar else UIKit.SCREEN.x - edge.x - size.x
			out.append(Rect2(x, y, size.x, size.y))
			y += size.y + 2
	var timer_pod := time_label.get_parent().get_parent() as Control
	var timer_size := timer_pod.get_combined_minimum_size()
	out.append(Rect2(floorf((UIKit.SCREEN.x - timer_size.x) / 2.0), edge.y, timer_size.x, timer_size.y))
	return out


## A pod showed or hid while the area name is up (the HUD is filled in after the banner starts):
## its texts move clear of it.
func _pods_changed() -> void:
	if area_label.visible:
		_place_area_texts()


## A pause menu or the restart prompt opened over the area name and story line: they hide while it
## is open (they would show through around its panel). Their fade, paused with the tree, is kept for
## uncover_area_texts.
func cover_area_texts() -> void:
	area_label.visible = false
	story_label.visible = false


## The pause menu or restart prompt closed: the area texts come back if they were still up, at full
## alpha and for the rest of their hold, but at least AREA_RESHOW_TIME so they can be read again.
func uncover_area_texts() -> void:
	if _area_tween == null or not _area_tween.is_valid() or not _area_tween.is_running():
		return
	var hold := maxf(_area_hold - _area_tween.get_total_elapsed_time(), AREA_RESHOW_TIME)
	area_label.visible = true
	area_label.modulate.a = 1.0
	story_label.visible = story_label.text != ""
	story_label.modulate.a = 1.0
	_place_area_texts()
	_fade_area_texts(hold)


## Hides the area name and story line for good (the run ended: the result panel can reach up to
## them).
func hide_area_texts() -> void:
	if _area_tween:
		_area_tween.kill()
		_area_tween = null
	area_label.visible = false
	story_label.visible = false


func set_level_text(text: String) -> void:
	level_label.text = text
	# A translation too long for the room right of the timer pod wraps onto two lines there (the pod
	# grows down, never over the timer); English names always fit on one.
	var timer_pod := time_label.get_parent().get_parent() as Control
	var timer_right := (UIKit.SCREEN.x + timer_pod.get_combined_minimum_size().x) / 2.0
	var pod := level_label.get_parent().get_parent() as Control
	var style := pod.get_theme_stylebox("panel")
	var room := floorf(UIKit.SCREEN.x - UIKit.hud_edge().x - timer_right - UIKit.GAP_XS - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT))
	var wide := UIKit.locale() != UIKit.Lang.SOURCE_LOCALE and UIKit.text_w(text) > room  # (English: the source layout)
	if wide:
		level_label.text = wrap_text(text, room)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if wide else HORIZONTAL_ALIGNMENT_LEFT
	_pods_changed()


func set_skin_color(color: Color, rainbow := false) -> void:
	goo_color = color
	fill.color = color
	_drop.modulate = color
	_rainbow = rainbow


## Rainbow skin: the meter cycles through the rainbow (unless it's low and flashing red).
func _process(delta: float) -> void:
	if record_banner.visible:
		_chalice_clock += delta
		var frame := int(_chalice_clock * CHALICE_FPS) % 4
		for i in _chalices.size():
			# Glints alternate between the two chalices.
			(_chalices[i].texture as AtlasTexture).region.position.x = ((frame + i * 2) % 4) * CHALICE_FRAME.x
	if _low:
		_pulse += delta
		fill.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), 0.5 + 0.5 * sin(_pulse * 10.0))
	if not _rainbow:
		return
	_hue = fposmod(_hue + delta * 0.25, 0.83)
	goo_color = Color.from_hsv(_hue, 0.8, 0.95)
	_drop.modulate = goo_color
	if fill.color != LOW_COLOR:
		fill.color = goo_color


## Shows a message for a few seconds (unless something else replaces it meanwhile).
func flash_message(text: String, seconds: float) -> void:
	show_message(text)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(message) and message.text == text:
		message.visible = false


func show_message(text: String) -> void:
	text = _break_long(text)
	message.text = text
	_message_text = text
	message.visible = true
	_queue_fit()


## The result screen in a taller script (docs/ui-rules.md section 10): English keeps its source
## layout (the message panel centred in rows 20..140, the record banner at 109..150, the choice row
## at CHOICE_Y). Where a taller line makes those collide, the panel is centred in the room between the
## HUD pods above it and the banner (or choice row) below; the banner sits CHOICE_GAP_Y over the choice
## row; then, only while the panel still does not fit, the banner goes compact (NEW RECORD! and the
## time on one 8 px line between 1x chalices) and the panel's rows pack GAP_XS apart. Nothing scales.
func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_result.call_deferred()


func _fit_result() -> void:
	_fit_queued = false
	if UIKit.button_h() == UIKit.BUTTON_H or not message.visible:
		return  # (English metrics: the source layout as built)
	var metrics := UIKit.metrics()
	var choices := _choice_root.visible
	var below := float(UIKit.choice_y() if choices else int(UIKit.SCREEN.y) - 40)
	# The banner: GAP_S over the choice row (150 = 153 - 3 in English), as tall as its words.
	_banner_words.add_theme_constant_override("separation", int(metrics.ink_below) + 3)
	_set_banner_compact(false)
	if record_banner.visible:
		_place_banner(below)
		below = record_banner.offset_top
	(_message_panel.get_child(0) as BoxContainer).add_theme_constant_override("separation", 4)
	message.text = _message_text
	var top := _panel_top()
	if _message_panel.get_combined_minimum_size().y > below - UIKit.GAP_XS - top and record_banner.visible:
		_set_banner_compact(true)
		_place_banner(float(UIKit.choice_y() if choices else int(UIKit.SCREEN.y) - 40))
		below = record_banner.offset_top
	if _message_panel.get_combined_minimum_size().y > below - UIKit.GAP_XS - top:
		(_message_panel.get_child(0) as BoxContainer).add_theme_constant_override("separation", UIKit.GAP_XS)
	if _message_panel.get_combined_minimum_size().y > below - UIKit.GAP_XS - top:
		message.text = _pair_lines(_message_text)
		top = _panel_top()
	_message_center.offset_top = top
	_message_center.offset_bottom = below - UIKit.GAP_XS - UIKit.SCREEN.y


## The result lines after the first (the title) paired up, MESSAGE_PAIR_GAP apart, wherever two fit
## the text column: "TIME 0:00.0   SEED 123-4" (the last step for a tall script's result panel).
static func _pair_lines(text: String) -> String:
	var lines := text.split("\n")
	var out: Array[String] = [lines[0]]
	var i := 1
	while i < lines.size():
		var pair := lines[i] + MESSAGE_PAIR_GAP + lines[i + 1] if i + 1 < lines.size() else ""
		if pair != "" and UIKit.text_w(pair) <= REWARDS_W:
			out.append(pair)
			i += 2
		else:
			out.append(lines[i])
			i += 1
	return "\n".join(out)


## The highest row the result panel may start on: GAP_XS under every HUD pod its columns would cross
## (the English 20, less a heat row's lift, at the most).
func _panel_top() -> float:
	var width := _message_panel.get_combined_minimum_size().x
	var span := Rect2((UIKit.SCREEN.x - width) / 2.0, 0, width, 1)
	var top := 20.0 - _lift
	for pod: Rect2 in pod_rects():
		if pod.position.x < span.end.x and pod.end.x > span.position.x:
			top = maxf(top, pod.end.y + UIKit.GAP_XS)
	return top


## The record banner's rows: ending GAP_S over `above` (the choice row), as tall as its contents.
func _place_banner(above: float) -> void:
	var row := record_banner.get_child(0) as Control
	var h := row.get_combined_minimum_size().y if not _banner_words.vertical else maxf(41.0, row.get_combined_minimum_size().y)
	record_banner.offset_bottom = above - UIKit.GAP_S
	record_banner.offset_top = record_banner.offset_bottom - h


## Compact banner: the title in the 8 px font beside the time, the chalices at 1x.
func _set_banner_compact(on: bool) -> void:
	_banner_words.vertical = not on
	_banner_title.add_theme_font_size_override("font_size", 8 if on else 16)
	if on:
		_banner_title.add_theme_font_override("font", UIKit.font_for(UIKit.FONT))
	else:
		UIKit.use_big_font(_banner_title, 16)
	for chalice in _chalices:
		chalice.custom_minimum_size = CHALICE_FRAME * (1 if on else 2)


## The area name's line top under the timer pod (AREA_TOP in English): lower by a taller pod and by
## the line's accent room.
func _area_top() -> int:
	return AREA_TOP + UIKit.pod_h() - UIKit.POD_H + int(UIKit.metrics().ink_above)


## The same under the two-line attempt / pot pod (AREA_TOP_UNDER_ATTEMPT in English).
func _area_top_under_attempt() -> int:
	return AREA_TOP_UNDER_ATTEMPT + UIKit.pod_h() - UIKit.POD_H + UIKit.pod_h2() - UIKit.POD_H2 + int(UIKit.metrics().ink_above)


## The story line's distance under the area name (STORY_GAP in English): a taller line pitch and the
## accent room above the story line come on top.
func _story_gap() -> int:
	return STORY_GAP + UIKit.line_pitch() - UIKit.LINE_PITCH + int(UIKit.metrics().ink_above)


## A story line wider than the screen's text column (EDGE in from each side) wraps onto two centred
## lines in that column (a translation; English lines are all shorter).
func _wrap_story_line() -> void:
	var column := UIKit.SCREEN.x - 2.0 * UIKit.EDGE
	if story_label.text != "" and UIKit.text_w(story_label.text) > column:
		story_label.text = wrap_text(story_label.text, column)


## `text` broken onto lines no wider than `width` (at spaces, U+200B for Thai, or between any two
## characters for Chinese / Japanese), each line as full as it goes: explicit line breaks, so the
## label's size is known before any container sorts (an autowrapping label in a bar is not).
static func wrap_text(text: String, width: float) -> String:
	var parts_at_gap := text.split("  ", false)  # the texts' own separator first ("LEVEL 7/10  HARD")
	if parts_at_gap.size() == 2 and UIKit.text_w(parts_at_gap[0]) <= width and UIKit.text_w(parts_at_gap[1].strip_edges()) <= width:
		return parts_at_gap[0].strip_edges() + "\n" + parts_at_gap[1].strip_edges()
	var anywhere := UIKit.autowrap_mode() == TextServer.AUTOWRAP_ARBITRARY
	var parts: Array[String] = []
	var word := ""
	for i in text.length():  # parts keep their break: "WORD " / "WORD\u200b" / one CJK character
		var ch := text[i]
		word += ch
		if anywhere or ch == " " or ch == "\u200b":
			parts.append(word)
			word = ""
	if word != "":
		parts.append(word)
	var lines: Array[String] = [""]
	for part in parts:
		if lines[-1] != "" and UIKit.text_w((lines[-1] + part).strip_edges()) > width:
			lines[-1] = lines[-1].strip_edges()
			lines.append("")
		lines[-1] += part
	lines[-1] = lines[-1].strip_edges()
	return "\n".join(lines)


func _make_label(role := SkinText.ROLE_TEXT) -> Label:
	var l := Label.new()
	l.material = UIKit.text_material()
	l.set_meta("role", role)
	l.add_to_group(SkinText.GROUP)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_constant_override("line_spacing", UIKit.line_spacing())
	l.add_theme_color_override("font_shadow_color", Color(FRAME_COLOR, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l
