class_name Story
extends RefCounted

## The light plot (see docs/story.md): a slime fleeing adventurers fell through the floor of a
## mountain-sized dungeon and splatted on its bottom level, the Dark Dungeon (level 1). Each
## level is a floor of the climb up; the Volcanic Vault (10) is the summit, and its crater is the
## way out to daylight. The text here is the single source for the intro, the level banners and
## the finale. Lines are uppercase (the pixel font) and at most MAX_WIDTH px wide at 8 px.

const MAX_WIDTH := 296.0

## Which sequence the story scene plays next ("intro" or "finale"), set by whoever opens it, and
## the scene to go to afterwards.
static var mode := "intro"
static var next_scene := ""

## Intro cards: art id (drawn by StoryScreen) and up to two lines of text each.
const INTRO: Array[Dictionary] = [
	{art = "run", lines = ["A SLIME. SOME ADVENTURERS.", "A LOT OF TORCHES."]},
	{art = "chase", lines = ["THEY WANTED EXPERIENCE POINTS.", "IT WANTED A NAP."]},
	{art = "crack", lines = ["THEN THE FLOOR", "GAVE UP."]},
	{art = "fall", lines = ["DOWN. AND DOWN.", "AND A BIT MORE DOWN."]},
	{art = "splat", lines = ["SPLAT. THE EXIT IS UP.", "ESCAPE THE FOG OR DRY TRYING."]},
]

const FINALE: Array[Dictionary] = [
	{art = "daylight", lines = ["THE CRATER SPITS YOU OUT", "INTO DAYLIGHT. A LITTLE DRY. FREE."]},
	{art = "search", lines = ["FAR BELOW, THE ADVENTURERS STILL SEARCH.", "THEY FIND A PUDDLE. IT COUNTS AS LOOT."]},
]

## One line under the area name when a level starts (story levels 1-10, bottom to top).
const LEVEL_LINES: Array[String] = [
	"SPLAT. IT IS DAMP. UP IS THAT WAY.",
	"THE MINERS LEFT IN A HURRY. SO WOULD YOU.",
	"SOMEONE SWEPT THE SAND. NOT RECENTLY.",
	"NOT TECHNICALLY SWIMMING. STILL NOT DRY.",
	"A SLIME IN SLIME. NOBODY WILL NOTICE.",
	"THE RESIDENTS ARE QUIET. SUSPICIOUSLY.",
	"COLDER NOW. SLIME DOES NOT SHIVER. IT JIGGLES.",
	"A CELL FOR THE FORGOTTEN. YOU ARE UNFORGETTABLE.",
	"SO SHINY. DAYLIGHT MUST BE CLOSE.",
	"HOT. THE WAY OUT IS THE CRATER. RUN.",
]


const SCENE := "res://scenes/story.tscn"


## Plays the intro or finale ("intro" / "finale"), then `next` (empty = the title / victory screen).
static func play(tree: SceneTree, which: String, next := "") -> void:
	mode = which
	next_scene = next
	UIKit.go(tree, SCENE)


## Whether the intro should play before level 1: only for a save that hasn't seen it.
static func intro_due(progress: Node) -> bool:
	return progress != null and not progress.dev_tools and not progress.has_seen_story(progress.STORY_INTRO)


static func level_line(level: int) -> String:
	if level < 1 or level > LEVEL_LINES.size():
		return ""
	return LEVEL_LINES[level - 1]


static func cards(which: String) -> Array[Dictionary]:
	return FINALE if which == "finale" else INTRO


## Width in px of the widest line in the story (at the 8 px pixel font), for the fit test.
static func widest_line() -> float:
	var font: Font = load("res://assets/fonts/pixel.fnt")
	var widest := 0.0
	var all: Array[String] = LEVEL_LINES.duplicate()
	for card_list in [INTRO, FINALE]:
		for card: Dictionary in card_list:
			all.append_array(card.lines)
	for line in all:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	return widest
