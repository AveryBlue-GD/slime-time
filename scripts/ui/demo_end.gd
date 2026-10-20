class_name DemoEnd
extends Control

## The demo's end screen (docs/demo-plan.md): the pitch for the full game. Opens after the chalice of
## the demo's last level (CONTINUE: the first time it is the only button, so every finisher sees it), after
## the demo's last randomizer maze is first won (a locked level's tile does nothing: docs/demo-plan.md).
## Top to bottom: the title and a line in the story voice; WISHLIST (only with a store page:
## Demo.WISHLIST_URL); a teaser of later areas (cards that flip by themselves every CARD_TIME s, < >
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
const MAP_POS := Vector2(38, 67)
const TEXT_X := 116
const TEXT_W := 168
const DOTS_Y := 122
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
var dots: Array[ColorRect] = []
var _clock := 0.0


## Opens the end screen (`why`: FROM_STORY or FROM_RANDOM).
static func open(tree: SceneTree, why := FROM_STORY) -> void:
	from = why
	UIKit.go(tree, SCENE)


## The line under the title (the story voice; after the randomizer, what the full game adds there).
static func top_line(why: String) -> String:
	if why == FROM_RANDOM:
		# i18n: demo end screen, line under the title, max 300px, 1 line
		return Loc.t("demo.end.random", "THE FULL GAME HAS ENDLESS MAZES AND 3 ABILITIES")
	# i18n: demo end screen, line under the title (the story's voice: the slime climbs to daylight), max 300px, 1 line
	return Loc.t("demo.end.line", "THE WAY OUT IS STILL UP THERE")


## What's new in a teaser card's area (Demo.teasers() order: the first card, the area right after the
## demo, counts the areas still to come).
static func feature_line(level: int) -> String:
	if level == Demo.levels() + 1:
		# i18n: demo end screen teaser card, max 168px, 1 line; {count} = story areas past the demo (6, web 7)
		return Loc.t("demo.teaser.more_areas", "{count} MORE AREAS", {count = Levels.COUNT - Demo.levels()})
	# i18n: demo end screen teaser card, max 168px, 1 line
	match level:
		6:
			return Loc.t("demo.teaser.loops", "MAZES THAT LOOP BACK")
		7:
			return Loc.t("demo.teaser.shop", "THE SHOP: TRAILS AND HATS")
		9:
			return Loc.t("demo.teaser.abilities", "NEW ABILITIES")
	return Loc.t("demo.teaser.out", "THE WAY OUT, MAYBE")


func _ready() -> void:
	# i18n: demo end screen title, max 296px, 16 px font
	UIKit.setup_screen(self, Loc.t("demo.end.title", "END OF THE DEMO"))
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
	map_rect.scale = Vector2(2, 2)
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
	map_rect.texture = MapView.preview(level, false, 100, 2, false, theme)
	area_label.text = Themes.display_name(theme)
	# i18n: demo end screen teaser card, {level} = a story level number; max 168px, 1 line
	level_label.text = Loc.t("demo.teaser.level", "LEVEL {level} - FULL GAME", {level = level})
	feature_label.text = feature_line(level)
	for i in dots.size():
		dots[i].color = UIKit.GOLD if i == card else UIKit.TEXT_OFF


func _flip(step: int) -> void:
	show_card(card + step)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= CARD_TIME:
		show_card(card + 1)


func _keep_playing() -> void:
	(load("res://scripts/hub.gd") as GDScript).set("return_to", "random" if from == FROM_RANDOM else "story")
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
