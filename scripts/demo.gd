class_name Demo
extends RefCounted

## The demo build (owner request 2026-10-19; design, knobs and the export rules: docs/demo-plan.md).
## ONE switch, Platform.is_demo() (an export preset with the custom feature `demo`, or the debug flag
## `--demo`), and a few gates that all ask this class; the full game (switch off) is unchanged.
##
## What the demo has: the intro + SPLASHDOWN tutorial, story levels 1..levels() with their coins,
## hard level 1..HARD_LEVELS, the cauldron with each coin upgrade capped (UPGRADE_CAPS), the
## randomizer (after level levels(): new random mazes in the demo's themes, as in the full game, with only the
## ABILITIES; the end screen after RANDOM_WINS wins), the hat wheel
## (opens with the end screen, at most HATS_MAX hats), and the skins earnable in it. Later story / hard levels are plain locks (like any level not unlocked yet,
## no FULL GAME text); the other full-game content stays visible with a FULL GAME lock (names only).
## The end screen (END_SCENE) follows the last demo level's chalice and the last demo maze.
##
## Export stripping: every file only the full game needs is listed by full_only_paths() (export_cut() adds
## the catalogs while languages are off); tools/demo_paths.gd --write-presets puts it into the demo export
## presets and tools/build_demo.* exports + verifies them (docs/demo-plan.md section 8). The demo must run
## with them absent. Code the demo runs only ever `load()`s
## level data / theme art / ambience through paths it allows (can_load), never `preload`s them.

## ---------------------------------------------------------------- the knobs (one place)
## Story levels in the demo (1..LEVELS), and on the web build (WEB_LEVELS: 4 like the desktop since
## 2026-10-21, owner; a shorter web demo is one number away, with its caps and prices below).
const LEVELS := 4
const WEB_LEVELS := 4
## Hard-mode levels in the demo (1..HARD_LEVELS; hard level 1 unlocks jelly Lime as usual).
const HARD_LEVELS := 1
## How far each coin upgrade can be bought in the demo (the rest of its bar shows FULL); an upgrade not
## listed stays at 0. WEB_UPGRADE_CAPS: the web demo's (the same while it has the same levels).
const UPGRADE_CAPS := {"slime": 3, "speed": 2, "brightness": 1}
const WEB_UPGRADE_CAPS := UPGRADE_CAPS
## The demo's own coin prices (PRICES[id][i] = coins for level i + 1, one per capped level; the full
## game's are Economy.COIN_TRACKS). They add up to EXACTLY the coins levels 1..levels() hide (coins_total():
## levels 1-4: 6 + 9 + 7 + 12 = 34, on desktop and web; tests/test_demo.gd checks it): every coin found buys
## every demo upgrade level, 0 left over (docs/demo-plan.md section 2).
const PRICES := {"slime": [1, 4, 6], "speed": [6, 8], "brightness": [9]}  # 11 + 14 + 9 = 34
const WEB_PRICES := PRICES  # (a 3-level web demo would be {"slime": [1, 5], "speed": [7], "brightness": [9]}: 22)
## Hats the demo's wheel gives at most: with this many hats owned it doesn't spin.
const HATS_MAX := 2
## The randomizer (opens after the last demo level) and the hat wheel, per platform. The web demo has both
## since 2026-10-21 (owner: no FULL GAME on them; their lines read as on the desktop demo); false would
## show them dimmed with a FULL GAME lock.
const RANDOMIZER := true
const WEB_RANDOMIZER := true
const HAT_WHEEL := true
const WEB_HAT_WHEEL := true
## Randomizer wins before the end screen's pitch (shown once, after the RANDOM_WINS-th win), with every maze a
## new random one (random seed and start, a theme drawn from themes()), as in the full game. Only while PREVIEW is
## off: with it on the demo's randomizer is the preview maze from its first use (owner, 2026-10-23).
const RANDOM_WINS := 3
## The first GENTLE_MAZES randomizer mazes (counted by wins) are drawn only from seeds whose perfect route
## uses at most GENTLE_MAX_USAGE permille of the meter (Levels.random_usage_permille: about 70% of seeds),
## so a first random maze isn't a 90%+ marathon. Later ones: any seed, as in the full game.
const GENTLE_MAZES := 3
const GENTLE_MAX_USAGE := 750
## Abilities that work (and can be bought) in the demo.
const ABILITIES: Array[String] = ["rifle"]
## The demo's own ticket prices for the first levels of an ability (ABILITY_PRICES[id][i] = tickets for
## level i + 1; later levels keep Economy.ABILITIES' prices). A randomizer win pays at most 5 tickets and
## the pitch comes after RANDOM_WINS wins, so SLIME RIFLE level 1 must be in reach before it (full: 15).
const ABILITY_PRICES := {"rifle": [5]}
## The store page the WISHLIST buttons open (Platform.open_store_page). Empty = the Steam page of
## STEAM_APP_ID, if set. With neither, every WISHLIST button is hidden.
const WISHLIST_URL := ""
## The FULL game's Steam app id (not the demo's): the Steam build opens its store page in the Steam overlay,
## other builds in the browser. 0 = no Steam page yet (docs/steam-setup.md).
const STEAM_APP_ID := 0
## Tests: a Steam app id to use instead of STEAM_APP_ID (-1 = the constant).
static var steam_app_override := -1
## The demo's end screen.
const END_SCENE := "res://scenes/demo_end.tscn"
## The end screen's teaser cards: later story levels shown by area name and a stylised (made-up)
## map in their colors. Only names and colors: no later level data or art is needed. The first card is
## always the area right after the demo's last level (teasers(): 5), then these.
const TEASER_LEVELS: Array[int] = [6, 7, 9, 10]
## The FULL GAME PREVIEW (owner idea, 2026-10-22): the demo's randomizer portal leads into one hand-picked
## maze (PREVIEW_SEED at MORE SLIME PREVIEW_LEVEL, a demo theme) played with every ability at its top level and a
## random look from the full game (Progress.begin_demo_preview: skin, jelly / pastel, hat + dye, trail, paper), with
## no ticket pickups or pay, after a short card (game.gd); its win or dry-up goes straight to the randomizer's end
## screen. Everything it borrows is in memory only: the save is not written while it runs and the whole state from
## before it comes back as it ends (Progress.end_demo_preview). From the portal's first use after level 4 (owner, 2026-10-23:
## no random mazes first; the first run has the ability tutorial, PREVIEW_SEEN_BIT), then every time (Progress.demo_preview_replay:
## no new seeds, RESTART replays it, no NEW MAZE); false = no preview (the RANDOM_WINS random mazes instead).
const PREVIEW := true
const PREVIEW_SEED := 1854
const PREVIEW_LEVEL := 3
## The preview was started (Progress.story_seen bit, saved before it starts).
const PREVIEW_SEEN_BIT := 16  # (= Progress.STORY_DEMO_PREVIEW: keep the two in step)
## True while the preview runs (set by Progress.begin_demo_preview / end_demo_preview; never saved).
static var preview := false
## TRY THE FULL GAME: the button into the FULL GAME PREVIEW maze (the level 4 win row, the end screen).
static func try_full_game_text() -> String:
	# i18n: button (demo: plays the FULL GAME PREVIEW maze), on the win row beside CONTINUE and on the end screen's bottom row, max 120px, 1 line
	return Loc.t("demo.try_full_game", "TRY THE FULL GAME")


## The end screen was seen (Progress.story_seen bit; the full game ignores it).
const END_SEEN_BIT := 4  # (= Progress.STORY_DEMO_END: keep the two in step)
## The randomizer's end screen (after the preview maze, or RANDOM_WINS wins without it) was seen (Progress.story_seen bit).
const RANDOM_END_SEEN_BIT := 8  # (= Progress.STORY_DEMO_RANDOM_END: keep the two in step)

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


## The highest level coin upgrade `id` can be bought to here (UPGRADE_CAPS; 0 if not listed).
static func upgrade_cap(id: String) -> int:
	var top := Upgrades.max_level(id)
	var caps: Dictionary = WEB_UPGRADE_CAPS if Platform.is_web() else UPGRADE_CAPS
	return mini(int(caps.get(id, 0)), top) if on() else top


## The demo's price list for coin upgrade `id` on this platform (PRICES / WEB_PRICES; [] if not listed).
## Upgrades.cost / total_cost use it while the demo is on.
static func prices(id: String) -> Array:
	var table: Dictionary = WEB_PRICES if Platform.is_web() else PRICES
	return table.get(id, [])


## The ticket prices of ability `id`'s levels here: Economy.ABILITIES' `full` list, its first levels
## replaced by ABILITY_PRICES while the demo is on. Abilities.cost / total_cost use it.
static func ability_prices(id: String, full: Array) -> Array:
	if not on():
		return full
	var out := full.duplicate()
	var demo: Array = ABILITY_PRICES.get(id, [])
	for i in mini(demo.size(), out.size()):
		out[i] = demo[i]
	return out


## True if the next randomizer maze must be a gentle one (`won`: randomizer wins so far).
static func gentle_maze(won: int) -> bool:
	return on() and won < GENTLE_MAZES


## Coins hidden in the demo's story levels (1..levels(); every level's in the full game).
static func coins_total() -> int:
	var total := 0
	for level in range(1, levels() + 1):
		total += int(Levels.COINS[level - 1])
	return total


## The coin bag's row for story level `level` shows "?/?": a level past the demo's last.
static func coins_hidden(level: int) -> bool:
	return on() and level > levels()


## The hat wheel in the demo: "" = it spins as usual (always in the full game); "closed" = not before
## the demo is completed (`done`: its last level cleared or the end screen seen); "full" = `owned` hats
## reach HATS_MAX (a guarded full save that owns more: no spins either).
static func wheel_block(done: bool, owned: int) -> String:
	if not on():
		return ""
	if not done:
		return "closed"
	return "full" if owned >= HATS_MAX else ""


## The end screen's teaser levels on this platform: the area after the demo's last level, then the
## TEASER_LEVELS past it (the full game: TEASER_LEVELS).
static func teasers() -> Array[int]:
	var first := levels() + 1
	if first > Levels.COUNT:
		return TEASER_LEVELS.duplicate()
	var out: Array[int] = [first]
	for level in TEASER_LEVELS:
		if level > first:
			out.append(level)
	return out


## The SHOP (hat dyes, papers): a full-game feature (shown with a FULL GAME lock).
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
	return not on() or preview or id in ABILITIES


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


## The full game's Steam app id (STEAM_APP_ID, or the tests' steam_app_override).
static func steam_app_id() -> int:
	return steam_app_override if steam_app_override >= 0 else STEAM_APP_ID


## The store page's web address: WISHLIST_URL, else the Steam page of STEAM_APP_ID, else "".
static func store_url() -> String:
	if WISHLIST_URL != "":
		return WISHLIST_URL
	return "https://store.steampowered.com/app/%d/" % steam_app_id() if steam_app_id() > 0 else ""


## The WISHLIST buttons show only with a store page to open, and never in a phone app (the App Store and
## Google Play don't allow pointing players at another store).
static func wishlist_shown() -> bool:
	return on() and not Platform.is_mobile_native() and store_url() != ""


## Opens the store page: the Steam overlay in the Steam build, else the browser (a new tab on the web).
static func open_wishlist() -> void:
	Platform.open_store_page(store_url(), steam_app_id())


## The FULL GAME lock's text (hub prompts and tour lines of the web demo's randomizer / hat wheel).
static func full_game_text() -> String:
	# i18n: lock label (demo build) on the hub's randomizer portal / hat wheel prompt when they are left out; max 52px, 1 line
	return Loc.t("demo.full_game", "FULL GAME")


## Why the demo's hat wheel doesn't spin (`block`: Demo.wheel_block's "closed" / "full"): the hub tour's
## line by the wheel and the wheel's own status line.
static func wheel_block_text(block: String) -> String:
	if block == "full":
		# i18n: hat wheel status line and hub tour line (demo build: the wheel's hats are used up), max 192px, 1 line
		return Loc.t("demo.wheel_full", "NO MORE HATS IN THE DEMO")
	# i18n: hat wheel status line and hub tour line (demo build: the wheel opens after the last demo level), max 192px, 1 line; {level} = the demo's last level (4)
	return Loc.t("demo.wheel_closed", "SPIN FOR PRIZES AFTER LEVEL {level}", {level = levels()})


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
