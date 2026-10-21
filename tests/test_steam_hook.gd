extends "res://tests/suite_base.gd"

## The Steam seam of the demo's WISHLIST (QA must-fix 5, docs/steam-setup.md): Platform.steam_api starts
## GodotSteam once, only in the Steam build; Platform.open_store_page opens the Steam overlay on the store page
## there (no browser), and the browser elsewhere; Demo.store_url / wishlist_shown follow WISHLIST_URL or the
## Steam app id, and WISHLIST never shows in a phone app. A fake Steam object stands in for the GDExtension.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_steam_hook.gd


## Records what the game asked of "Steam".
class FakeSteam:
	extends RefCounted
	var init_status := 0
	var overlay := true
	var inits := 0
	var opened: Array = []

	func steamInitEx() -> Dictionary:
		inits += 1
		return {status = init_status, verbal = "fake"}

	func isOverlayEnabled() -> bool:
		return overlay

	func activateGameOverlayToStore(app_id: int, flag: int) -> void:
		opened.append([app_id, flag])


func _initialize() -> void:
	await process_frame
	_api()
	_overlay()
	_wishlist()
	Platform.reset_overrides()
	Demo.steam_app_override = -1
	_result()
	quit(1 if failures else 0)


func _api() -> void:
	Platform.reset_overrides()
	var fake := FakeSteam.new()
	Platform.steam_override = fake
	_check(not Platform.is_steam() and Platform.steam_api() == null and fake.inits == 0, "not the Steam build: no Steam API, never started")
	Platform.reset_overrides()
	Platform.override = "steam"
	Platform.steam_override = fake
	_check(Platform.steam_api() == fake and Platform.steam_api() == fake and fake.inits == 1, "the Steam build: steamInitEx once, then reused")
	Platform.reset_overrides()
	Platform.override = "steam"
	_check(Platform.steam_api() == null, "the Steam build without the GodotSteam extension: null (no error)")
	Platform.reset_overrides()
	Platform.override = "steam"
	var failing := FakeSteam.new()
	failing.init_status = 2
	Platform.steam_override = failing
	_check(Platform.steam_api() == null and Platform.steam_api() == null and failing.inits == 1,
		"Steam not running (steamInitEx fails): null, asked once")


func _overlay() -> void:
	Platform.reset_overrides()
	Platform.override = "steam"
	var fake := FakeSteam.new()
	Platform.steam_override = fake
	_check(not Platform.steam_overlay_ready(0), "no app id: no overlay")
	_check(Platform.steam_overlay_ready(480), "the Steam build with an app id: the overlay is ready")
	Platform.open_store_page("https://example.invalid/should-not-open", 480)
	_check(fake.opened == [[480, 0]], "open_store_page: the Steam overlay on the store page (%s), no browser" % [fake.opened])
	fake.overlay = false
	_check(not Platform.steam_overlay_ready(480), "overlay switched off by the player: not ready (the browser is used)")
	Platform.open_store_page("", 480)
	_check(fake.opened.size() == 1, "overlay off and no URL: nothing opens")


func _wishlist() -> void:
	Platform.reset_overrides()
	Platform.demo_override = 1
	Demo.steam_app_override = -1
	_check(Demo.store_url() == Demo.WISHLIST_URL and Demo.wishlist_shown() == (Demo.WISHLIST_URL != "" or Demo.STEAM_APP_ID > 0),
		"the shipped knobs: WISHLIST shows only with a store page (%s)" % Demo.store_url())
	Demo.steam_app_override = 480
	if Demo.WISHLIST_URL == "":
		_check(Demo.store_url() == "https://store.steampowered.com/app/480/", "a Steam app id alone: its store page (%s)" % Demo.store_url())
	_check(Demo.wishlist_shown(), "demo on the desktop with a store page: WISHLIST shows")
	for kind in ["ios", "android"]:
		Platform.override = kind
		_check(not Demo.wishlist_shown(), "%s app: no WISHLIST (stores don't allow pointing at another store)" % kind)
	Platform.override = "web"
	_check(Demo.wishlist_shown(), "web demo: WISHLIST shows (a new browser tab)")
	Platform.override = ""
	Platform.demo_override = 0
	_check(not Demo.wishlist_shown(), "the full game: no WISHLIST")
	Demo.steam_app_override = -1
