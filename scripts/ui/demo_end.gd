class_name DemoEnd
extends Control

## The demo's end screen (docs/demo-plan.md): the pitch for the full game. Opens after the chalice of
## the demo's last level (CONTINUE: the first time it is the only button, so every finisher sees it), after
## the demo's last randomizer maze is first won (a locked level's tile does nothing: docs/demo-plan.md).
## Top to bottom: the title and a line in the story voice; WISHLIST (only with a store page:
## Demo.store_url()); a teaser of later areas (cards that flip by themselves every CARD_TIME s, < >
## flip them; each is an area name, its level and what's new there, beside a made-up map in that area's
## colors: MapView's example maze, no real level data or art); KEEP PLAYING (hub). No line about the demo's
## progress reaching the full game (owner, 2026-10-19: nothing on screen says or implies it carries over).

const SCENE := "res://scenes/demo_end.tscn"
const FROM_STORY := "story"
const FROM_RANDOM := "random"
## Why it opened (FROM_*), set by open().
static var from := FROM_STORY

const CARD_TIME := 3.2
## The teaser card: a goo panel with the map (2x) on its left and three text lines beside it.
const CARD := Rect2(28, 58, 264, 58)
## CON-01: the map at 1x (35 x 19 with its frame), centred in the card's left column (x 28..116).
const MAP_SIZE := Vector2(35, 19)
const MAP_POS := Vector2(28 + 44 - 18, 58 + 20)
const TEXT_X := 116
const TEXT_W := 168
const DOTS_Y := 122
## The randomizer hint's row (story end on a demo with the randomizer): between the dots and KEEP PLAYING.
const RANDOM_HINT_Y := 140
const WISHLIST_Y := 40
const KEEP_W := 88

var wishlist_button: Button
var keep_button: Button
var arrows: Array[Button] = []
var card := 0
var map_rect: TextureRect
var area_label: Label
var level_label: Label
var feature_label: Label
## "NOW TRY THE RANDOMIZER IN THE HUB" (null when not shown: random_hint_shown()).
var random_hint: Label
var dots: Array[ColorRect] = []
var _clock := 0.0


## Opens the end screen (`why`: FROM_STORY or FROM_RANDOM).
static func open(tree: SceneTree, why := FROM_STORY) -> void:
	from = why
	UIKit.go(tree, SCENE)


## The line under the title (the story voice; after the randomizer, what the full game adds there).
static func top_line(why: String) -> String:
	if why == FROM_RANDOM:
		# Only what the demo doesn't have (its randomizer is already endless, with SLIME RIFLE).
		# i18n: demo end screen, line under the title, max 300px, 1 line; {count} = abilities the demo lacks (2)
		return Loc.t("demo.end.random", "THE FULL GAME ADDS {count} ABILITIES AND THE SHOP", {count = more_abilities()})
	# i18n: demo end screen, line under the title (the story's voice: the slime climbs to daylight), max 300px, 1 line
	return Loc.t("demo.end.line", "THE WAY OUT IS STILL UP THERE")


## Abilities the full game has that this demo doesn't (the web demo has no randomizer, so none of them).
static func more_abilities() -> int:
	var have := Demo.ABILITIES.size() if Demo.randomizer_open() else 0
	return Economy.ABILITIES.size() - have


## What's new in a teaser card's area (Demo.teasers() order: the first card, the area right after the
## demo, counts the areas still to come). Every line names only full-game content (QA must-fix 4): the demo
## already has jelly skins, hats, hard level 1, endless random mazes (which loop back) and SLIME RIFLE.
static func feature_line(level: int) -> String:
	if level == Demo.levels() + 1:
		# i18n: demo end screen teaser card, max 168px, 1 line; {count} = story areas past the demo (6, web 7)
		return Loc.t("demo.teaser.more_areas", "{count} MORE AREAS", {count = Levels.COUNT - Demo.levels()})
	match level:
		6:
			# i18n: demo end screen teaser card, max 168px, 1 line; {count} = hard levels past the demo (9)
			return Loc.t("demo.teaser.hard", "{count} MORE HARD LEVELS", {count = Levels.COUNT - Demo.hard_levels()})
		7:
			# i18n: demo end screen teaser card, max 168px, 1 line (the SHOP: hat dyes, goo trails, map papers)
			return Loc.t("demo.teaser.shop", "THE SHOP: TRAILS AND PAPERS")
		9:
			# i18n: demo end screen teaser card, max 168px, 1 line; {count} = abilities the demo lacks (2, web 3)
			return Loc.t("demo.teaser.abilities", "{count} MORE ABILITIES", {count = more_abilities()})
	# i18n: demo end screen teaser card, max 168px, 1 line (the last area: the story's voice)
	return Loc.t("demo.teaser.out", "THE WAY OUT, MAYBE")


func _ready() -> void:
	# i18n: demo end screen title, max 296px, 16 px font
	UIKit.setup_screen(self, Loc.t("demo.end.title", "END OF THE DEMO"))
	get_node("/root/Progress").end_demo_preview()  # (after the FULL GAME PREVIEW maze: the save's own state is back)
	get_node("/root/Progress").mark_story_seen(Demo.END_SEEN_BIT)
	if from == FROM_RANDOM:
		get_node("/root/Progress").mark_story_seen(Demo.RANDOM_END_SEEN_BIT)
	var line := UIKit.make_label(top_line(from), UIKit.FONT, UIKit.TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(line)
	line.position = Vector2(0, UIKit.title_bottom() + UIKit.GAP_M)
	line.size = Vector2(UIKit.SCREEN.x, UIKit.line_h())

	# i18n: demo end screen button (opens the store page), max 80px, 1 line
	var wish_text := Loc.t("demo.wishlist", "WISHLIST")
	wishlist_button = UIKit.make_button(wish_text, Demo.open_wishlist, Vector2(UIKit.button_w(wish_text, 88), UIKit.button_h()))
	add_child(wishlist_button)
	wishlist_button.size = wishlist_button.custom_minimum_size
	wishlist_button.position = Vector2(UIKit.center_x(wishlist_button.size.x), WISHLIST_Y)
	wishlist_button.visible = Demo.wishlist_shown()
	UIKit.add_touch_target(wishlist_button)

	UIKit.add_panel(self, CARD)
	map_rect = TextureRect.new()
	map_rect.position = MAP_POS
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_rect)
	area_label = UIKit.make_label("", UIKit.FONT, UIKit.GOLD)
	add_child(area_label)
	area_label.position = Vector2(TEXT_X, CARD.position.y + 11)
	level_label = UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)
	add_child(level_label)
	level_label.position = Vector2(TEXT_X, CARD.position.y + 11 + UIKit.line_pitch())
	feature_label = UIKit.make_label("", UIKit.FONT, UIKit.TEXT)
	feature_label.clip_text = true  # (one line: a longer translation is cut at the card's inner edge)
	add_child(feature_label)
	feature_label.position = Vector2(TEXT_X, CARD.position.y + 11 + 2 * UIKit.line_pitch() + UIKit.GAP_XS)
	feature_label.size = Vector2(TEXT_W, UIKit.line_h() + UIKit.TEXT_DRIP)
	arrows = UIKit.add_page_arrows(self, _flip, CARD.position.y + (CARD.size.y - UIKit.button_h()) / 2.0, UIKit.EDGE, UIKit.SCREEN.x - UIKit.EDGE)
	for arrow in arrows:
		UIKit.add_touch_target(arrow)
	var count := Demo.teasers().size()
	for i in count:
		var dot := ColorRect.new()
		dot.size = Vector2(3, 3)
		dot.position = Vector2(UIKit.center_x(count * 6 - 3) + i * 6, DOTS_Y)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		dots.append(dot)

	if random_hint_shown():
		# i18n: demo end screen, under the teaser cards (the demo's random mazes open after its last level; RANDOMIZER = the hub station's name), max 296px, 1 line
		random_hint = UIKit.make_label(Loc.t("demo.end.try_random", "NOW TRY THE RANDOMIZER IN THE HUB"), UIKit.FONT, UIKit.GOLD)
		random_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(random_hint)
		random_hint.position = Vector2(0, RANDOM_HINT_Y)
		random_hint.size = Vector2(UIKit.SCREEN.x, UIKit.line_h())

	# i18n: demo end screen button, back to the hub; max 80px, 1 line
	var keep_text := Loc.t("demo.keep_playing", "KEEP PLAYING")
	keep_button = UIKit.make_button(keep_text, _keep_playing, Vector2(UIKit.button_w(keep_text, KEEP_W), UIKit.button_h()))
	add_child(keep_button)
	keep_button.size = keep_button.custom_minimum_size
	UIKit.place_bottom_row(keep_button, 1)
	UIKit.add_touch_target(keep_button)
	show_card(0)
	(wishlist_button if wishlist_button.visible else keep_button).grab_focus()


## Shows teaser card `index` (wrapping round).
func show_card(index: int) -> void:
	var levels := Demo.teasers()
	card = posmod(index, levels.size())
	_clock = 0.0
	var level: int = levels[card]
	var theme := Themes.for_level(level)
	map_rect.texture = MapView.preview(level, false, 100, 2, false, theme, true)
	area_label.text = Themes.display_name(theme)
	# i18n: demo end screen teaser card, {level} = a story level number; max 168px, 1 line
	level_label.text = Loc.t("demo.teaser.level", "LEVEL {level} - FULL GAME", {level = level})
	feature_label.text = feature_line(level)
	for i in dots.size():
		dots[i].color = _skin_color() if i == card else UIKit.TEXT_OFF  # (CON-26: not gold, gold is for rewards)


func _skin_color() -> Color:
	var progress := get_node_or_null("/root/Progress")
	var base: Color = progress.skin_color() if progress else Skins.get_preset(Skins.DEFAULT).color
	return SkinText.color_for(SkinText.ROLE_TITLE, base)


func _flip(step: int) -> void:
	show_card(card + step)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= CARD_TIME:
		show_card(card + 1)


## After the story's end, a demo with a randomizer points the player at it (owner, 2026-10-21); KEEP PLAYING
## then puts the slime by the RANDOMIZER portal.
static func random_hint_shown() -> bool:
	return from == FROM_STORY and Demo.randomizer_open()


func _keep_playing() -> void:
	(load("res://scripts/hub.gd") as GDScript).set("return_to", "random" if from == FROM_RANDOM or random_hint_shown() else "story")
	UIKit.go(get_tree(), UIKit.HUB_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_keep_playing()
	elif event.is_action_pressed("tab_next") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_flip(1)
	elif event.is_action_pressed("tab_prev") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_flip(-1)
