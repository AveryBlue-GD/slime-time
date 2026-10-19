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
	{art = "search", time = 6.2, still = 2.7},
]

## The line under the area name when a level starts (story levels 1-10, bottom to top) lives in that
## level's data file (scripts/level_data/level_NN.gd, `line()`), so a demo export without a level's file
## has none of its text either (docs/demo-plan.md).


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


## The scene the launch intro wipes into: the title, or (tutorial test on, a fresh save that is due:
## Progress.tutorial_due) the SPLASHDOWN training maze, set up here (Progress.prepare_training). Esc on
## the intro leads to the same scene. With the gate off this is always the title (today's flow).
static func launch_next(progress: Node) -> String:
	if progress != null and progress.tutorial_due():
		return progress.prepare_training(false)
	return UIKit.TITLE_SCENE


## Whether the intro should play automatically: only for a save that hasn't seen it.
static func intro_due(progress: Node) -> bool:
	return progress != null and not progress.dev_tools and not progress.has_seen_story(progress.STORY_INTRO)


static func level_line(level: int) -> String:
	if level < 1 or level > Levels.COUNT or not Levels.has_data(level):
		return ""
	return level_line_text(level)


## A level's banner line, English source (the extractor reads the Loc calls in scripts/level_data/).
static func level_line_text(level: int) -> String:
	var script := Levels.level_script(level)
	return script.call("line") if script != null else ""


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
	for level in range(1, Levels.COUNT + 1):
		widest = maxf(widest, font.get_string_size(level_line_text(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	return widest
