class_name Demo
extends RefCounted

## The demo build (owner request 2026-10-19; design, knobs and the export rules: docs/demo-plan.md).
## ONE switch, Platform.is_demo() (an export preset with the custom feature `demo`, or the debug flag
## `--demo`), and a few gates that all ask this class; the full game (switch off) is unchanged.
##
## What the demo has: the intro + SPLASHDOWN tutorial, story levels 1..levels() with their coins,
## hard level 1..HARD_LEVELS, the cauldron with each coin upgrade capped at UPGRADE_CAP levels, the
## randomizer (after level levels()) as RANDOM_SEEDS fixed mazes with only the ABILITIES, the hat wheel,
## and the skins earnable in it. Everything else stays visible with a FULL GAME lock (names only).
## The end screen (END_SCENE) follows the last demo level's chalice and the last demo maze.
##
## Export stripping: every file only the full game needs is listed by full_only_paths() (export_cut() adds
## the catalogs while languages are off); tools/demo_paths.gd --write-presets puts it into the demo export
## presets and tools/build_demo.* exports + verifies them (docs/demo-plan.md section 8). The demo must run
## with them absent. Code the demo runs only ever `load()`s
## level data / theme art / ambience through paths it allows (can_load), never `preload`s them.

## ---------------------------------------------------------------- the knobs (one place)
## Story levels in the demo (1..LEVELS), and on the web build (WEB_LEVELS: a shorter web demo if wanted).
const LEVELS := 3
const WEB_LEVELS := 3
## Hard-mode levels in the demo (1..HARD_LEVELS; hard level 1 unlocks jelly Lime as usual).
const HARD_LEVELS := 1
## Each coin upgrade can be bought up to this level in the demo (the rest of its bar shows FULL).
const UPGRADE_CAP := 2
## The randomizer (opens after the last demo level) and the hat wheel, per platform: the web demo
## leaves both out by default (a lighter, shorter demo for the Shorts / browser audience).
const RANDOMIZER := true
const WEB_RANDOMIZER := false
const HAT_WHEEL := true
const WEB_HAT_WHEEL := false
## The demo's randomizer mazes, played in this order (then replayed in turn). Picked for a middling
## usage (about half to two thirds of the meter: tools/demo_paths.gd --seeds lists candidates).
const RANDOM_SEEDS: Array[int] = [1016, 1063, 1015]  # usage 50 / 57 / 62 %: dungeon, mossy, sandstone
## Abilities that work (and can be bought) in the demo.
const ABILITIES: Array[String] = ["rifle"]
## The store page the WISHLIST buttons open (OS.shell_open). Empty = every WISHLIST button is hidden.
const WISHLIST_URL := ""
## The demo's end screen.
const END_SCENE := "res://scenes/demo_end.tscn"
## The end screen's teaser cards: later story levels shown by area name and a stylised (made-up)
## map in their colors. Only names and colors: no later level data or art is needed.
const TEASER_LEVELS: Array[int] = [4, 6, 7, 9, 10]
## The end screen was seen (Progress.story_seen bit; the full game ignores it).
const END_SEEN_BIT := 4  # (= Progress.STORY_DEMO_END: keep the two in step)

## ---------------------------------------------------------------- tests
## Tests: treat every full-only path as absent (can_load false), as in a stripped demo export.
static var strip_test := false
## Tests: full-only paths something asked can_load about while strip_test was on (should stay empty
## for anything the demo actually plays).
static var denied: Array[String] = []


## The demo switch (Platform.is_demo: the `demo` export feature or the --demo flag).
static func on() -> bool:
	return Platform.is_demo()


## Story levels in this demo (all of them in the full game).
static func levels() -> int:
	if not on():
		return Levels.COUNT
	return WEB_LEVELS if Platform.is_web() else LEVELS


## Hard levels in this demo (all of them in the full game).
static func hard_levels() -> int:
	return mini(HARD_LEVELS, levels()) if on() else Levels.COUNT


## The last playable story level of the mode.
static func last_level(hard := false) -> int:
	return hard_levels() if hard else levels()


## True if story level `level` (of the mode) can be played: always in the full game.
static func level_open(level: int, hard := false) -> bool:
	return level >= 1 and level <= last_level(hard)


## The highest level coin upgrade `id` can be bought to here.
static func upgrade_cap(id: String) -> int:
	var top := Upgrades.max_level(id)
	return mini(UPGRADE_CAP, top) if on() else top


## HEAT (hard mode's modifiers): a full-game feature.
static func heat_open() -> bool:
	return not on()


## The SHOP (TAILOR hats, trails, papers): a full-game feature (shown with a FULL GAME lock).
static func shop_open() -> bool:
	return not on()


static func randomizer_open() -> bool:
	if not on():
		return true
	return WEB_RANDOMIZER if Platform.is_web() else RANDOMIZER


static func hat_wheel_open() -> bool:
	if not on():
		return true
	return WEB_HAT_WHEEL if Platform.is_web() else HAT_WHEEL


## Ability `id` works / can be bought here.
static func ability_open(id: String) -> bool:
	return not on() or id in ABILITIES


## Skin `id` (opaque, or `jelly`) can be earned / worn in the demo: the opaque skins of the demo's
## levels (Lime and the rewards of levels 1..levels()) and the jelly ones of its hard levels.
static func skin_open(id: String, jelly: bool) -> bool:
	if not on():
		return true
	if Skins.get_preset(id).is_empty():
		return false  # (custom, rainbow, stopwatch: full game)
	return Skins.jelly_level(id) <= hard_levels() if jelly else Skins.unlock_level(id) <= levels()


## The art themes the demo has: those of its story levels (randomizer mazes pick from these).
static func themes() -> Array[String]:
	var out: Array[String] = []
	for level in range(1, levels() + 1):
		var id := Themes.for_level(level)
		if not id in out:
			out.append(id)
	return out


## The randomizer seed for the demo's `index`-th maze (0-based, wrapping round).
static func random_seed(index: int) -> int:
	return RANDOM_SEEDS[posmod(index, RANDOM_SEEDS.size())]


## True once every demo maze has been won (randoms_won counts the wins).
static func randoms_done(won: int) -> bool:
	return won >= RANDOM_SEEDS.size()


## The WISHLIST buttons show only with a store page to open.
static func wishlist_shown() -> bool:
	return on() and WISHLIST_URL != ""


## Opens the store page (a new browser tab on the web; the Steam overlay later, through Platform).
static func open_wishlist() -> void:
	if WISHLIST_URL != "":
		OS.shell_open(WISHLIST_URL)


## The FULL GAME lock's text (tiles, prompts, status lines).
static func full_game_text() -> String:
	# i18n: lock label on demo-locked levels, skins, upgrades and the shop; max 52px, 1 line
	return Loc.t("demo.full_game", "FULL GAME")


## ---------------------------------------------------------------- what the demo leaves out
## Files only the full game opens that no level number or theme names: the victory screen (shown only
## after the level-10 chalice: Game.VICTORY_SCENE, Story's finale). Add a file here only if no demo
## path can reach it (tests/test_demo_export.gd checks that each one exists).
const FULL_ONLY_FILES: Array[String] = ["res://scenes/victory.tscn", "res://scripts/ui/victory.gd"]


## Every res:// file only the full game needs, for the demo export's exclude list (docs/demo-plan.md):
## the data of the story levels past levels() and hard levels past hard_levels(), the tile art and
## ambience of the themes no demo level or maze uses, and FULL_ONLY_FILES. `web`: the web demo's list
## (its own levels()). Imported files: the .png / .wav and their .import (the exporter then leaves out
## the imported copy; tools/build_demo checks the exported pack).
static func full_only_paths(web := false) -> PackedStringArray:
	var out := PackedStringArray(FULL_ONLY_FILES)
	var count := WEB_LEVELS if web else LEVELS
	for level in range(count + 1, Levels.COUNT + 1):
		out.append(Levels.data_path(level))
	for level in range(mini(HARD_LEVELS, count) + 1, Levels.COUNT + 1):
		out.append(Levels.data_path(level, true))
	var kept: Array[String] = []
	for level in range(1, count + 1):
		kept.append(Themes.for_level(level))
	for id: String in Themes.BY_LEVEL:
		if id in kept:
			continue
		for kind in ["walls", "floors", "fillets", "border"]:
			var path := Themes.atlas_path(id, kind)
			out.append(path)
			out.append(path + ".import")
		var bed := "res://assets/sounds/ambient_%s.wav" % id
		out.append(bed)
		out.append(bed + ".import")
		for k in 16:
			var event := "res://assets/sounds/ambient_%s_%d.wav" % [id, k]
			if FileAccess.file_exists(event) or FileAccess.file_exists(event + ".import"):
				out.append(event)
				out.append(event + ".import")
	return out


## Everything a demo export leaves out (its preset's exclude_filter, written by
## `tools/demo_paths.gd --write-presets`): full_only_paths(web), plus the translation catalogs
## (locale/*.po: every locale's strings, the later levels' banner lines too) while the languages gate is
## off (Economy.LANGUAGES_TEST false: the game never loads them). With the gate on they ship.
static func export_cut(web := false) -> PackedStringArray:
	var out := full_only_paths(web)
	if not Economy.LANGUAGES_TEST:
		for path: String in Language.CATALOGS:
			out.append(path)
	return out


static var _stripped_cache := {}


## full_only_paths(web), computed once (the strip simulation asks it for every load).
static func _stripped(web: bool) -> PackedStringArray:
	if not _stripped_cache.has(web):
		_stripped_cache[web] = full_only_paths(web)
	return _stripped_cache[web]


## True if `path` may be loaded in this build: everything in the full game; in a demo, anything that
## exists (a stripped export simply lacks the full-only files). With strip_test on, the full-only
## paths count as absent (and are noted in `denied`), as in a stripped export.
static func can_load(path: String) -> bool:
	if strip_test and path in _stripped(Platform.is_web()):
		if not path in denied:
			denied.append(path)
		return false
	return ResourceLoader.exists(path)
