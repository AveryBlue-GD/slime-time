class_name Story
extends RefCounted

## The light plot (see docs/story.md): a slime fleeing adventurers fell through the floor of a
## mountain-sized dungeon and splatted on its bottom level, the Dark Dungeon (level 1). Each
## level is a floor of the climb up; the Volcanic Vault (10) is the summit, and its crater is the
## way out to daylight. The intro and the finale are wordless (told in pictures by StoryScreen);
## the only story text is the level banners' lines, uppercase (the pixel font) and at most
## MAX_WIDTH px wide at 8 px.

const MAX_WIDTH := 296.0

## Which sequence the story scene plays next ("intro" or "finale"), set by whoever opens it, and
## the scene to go to afterwards.
static var mode := "intro"
static var next_scene := ""

## Intro shots: art id (a short animated scene drawn by StoryScreen), how long it plays (s) before
## moving on by itself, and the moment a Reduce Motion still freezes on (s). No text: every beat
## is told by staging, light and pictograms.
const INTRO: Array[Dictionary] = [
	{art = "run", time = 4.6, still = 1.9},
	{art = "chase", time = 4.0, still = 1.9},
	{art = "crack", time = 3.9, still = 2.3},
	{art = "fall", time = 4.8, still = 0.9},
	{art = "splat", time = 6.4, still = 5.0},
]

const FINALE: Array[Dictionary] = [
	{art = "daylight", time = 6.6, still = 5.4},
	{art = "search", time = 6.2, still = 2.6},
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


## True once the game's boot title has been reached (so the launch trailer is only ever offered once per run).
static var launched := false


## The launch trailer: the first time the game opens the title (the current scene, i.e. a real
## launch, not a test instancing it) on a save that hasn't seen the intro.
static func launch_due(title: Node, progress: Node) -> bool:
	return not launched and title.is_inside_tree() and title.get_tree().current_scene == title \
		and intro_due(progress)


## Whether the intro should play automatically: only for a save that hasn't seen it.
static func intro_due(progress: Node) -> bool:
	return progress != null and not progress.dev_tools and not progress.has_seen_story(progress.STORY_INTRO)


static func level_line(level: int) -> String:
	if level < 1 or level > LEVEL_LINES.size():
		return ""
	return LEVEL_LINES[level - 1]


static func cards(which: String) -> Array[Dictionary]:
	return FINALE if which == "finale" else INTRO


## How long a sequence plays if nobody presses anything (s).
static func length(which: String) -> float:
	var total := 0.0
	for card in cards(which):
		total += card.time
	return total


## Width in px of the widest level line (at the 8 px pixel font), for the fit test.
static func widest_line() -> float:
	var font: Font = load("res://assets/fonts/pixel.fnt")
	var widest := 0.0
	for line in LEVEL_LINES:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	return widest
