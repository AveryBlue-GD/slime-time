# D2 — UI scripts audit (scripts/ui/ minus ui_kit / story / hat_wheel / skins / controls / upgrades / goo* / skin_text* / *backdrop*)

Read in full: achievements_screen, boards_screen, boon_icons, color_wheel, demo_end, descent_card, intro_card, key_controls,
language_screen, level_select, map_select, map_view, pause_menu, random_map_view, restart_prompt, rotate_hint, skin_showcase,
title, touch_button, touch_controls, transition, victory (+ scenes title, level_select, maps, key_controls, language,
achievements, boards, upgrades, victory, demo_end: each is a single root Control with the script, no other content).
Callers checked in game.gd, hub.gd, hud.gd, progress.gd, platform_events.gd, ability_*.gd, tests/.

## Map

**Scene changes.** Everything goes through `UIKit.go(tree, path)` -> autoload `Transition.go` (transition.gd:101): if `busy`
it returns silently; else paints the goo sheet, tweens a 0.22 s cover, sets `tree.paused = false`, `change_scene_to_file`,
waits one frame, then `_uncover()` (0.32 s tween, last step hides the sheet). `reveal()` = only the uncover half (level
start / reload). Restart, typed seed and the dry-up retry use `reload_current_scene()` directly (no cover). Transition is
also the frame-rate follower that switches physics interpolation (`follow_frame_rate`, per frame, skipped headless) and the
toast system (`_pump_notice`, per frame: one toast at a time from `Progress.notices`, WEAR IT offers via F or a tap).
No UI blocks input during a wipe (the sheet is MOUSE_FILTER_IGNORE; nothing checks `busy` except the game, pause menu and
restart prompt).

**Screens (Control scenes, built entirely in `_ready`, nothing per frame unless noted).**
- title.gd: main scene. First launch hands off to the story intro (deferred plain scene change); debug `--tutorial`.
  Builds logo, 2 slime previews (+hat), ENTER/PLAY, STORY, QUIT (desktop), tagline; preloads game/hub/story scenes once per
  session; warms shaders + `Transition.warm_up()`. Per frame: `_process` hops the two slimes; inner `LogoDrip._process`
  animates one drip and calls `queue_redraw()` every frame. `_input`: 5 taps on the build stamp = dev mode (test builds).
- intro_card.gd: 1.8 s launch card over the title on cold launch; per frame `_apply` (fog shader params, UI alpha,
  `_art.queue_redraw`); `_input` consumes any press and skips after 0.15 s; frees itself deferred.
- level_select.gd: 10 tiles (paged in tall locales), HARD checkbox rebuilds the grid; tile press = `start_story` + go.
- map_select.gd (+ map_view.gd static drawer, RefCounted): 10 tiles with cached example previews; a tile opens an opaque
  in-scene view rendered once into an Image (`MapView.render`, frame drawn per pixel in GDScript); PAPER re-renders.
- random_map_view.gd: overlay opened from a randomizer dry-up (game.gd), same renderer, PROCESS_MODE_ALWAYS, Esc closes.
- key_controls.gd: rebind page; `_input` captures the next key while `waiting_for`; note follows PlatformEvents.input_kind_changed
  (lambda, auto-disconnected with the node).
- language_screen.gd: 18 language buttons; `_pick` saves (Language.pick) then go(self) to rebuild.
- achievements_screen.gd / boards_screen.gd: static lists; `back_scene` static set by SETTINGS.
- victory.gd, demo_end.gd (`_process` flips teaser cards every 3.2 s), descent_card.gd (DESCENT is OFF, D11: built by game.gd,
  reachable only with `Economy.descent_force`).
- skin_showcase.gd: skins-screen stage; per frame `_pose` + `_age_trail` (trail redraw), used by skins_screen.gd.
- color_wheel.gd, boon_icons.gd (cached 8x8 textures), touch_button.gd (TouchButton: grown hit area on touch, nearest-target rule).

**Pause.** pause_menu.gd (CanvasLayer 20, PROCESS_MODE_ALWAYS, child of main.tscn): `open()` from game.gd `_unhandled_input`
(`menu`) or `pause_for_background` (PlatformEvents focus loss); sets `tree.paused = true`, locks the level's focus, pops in.
Esc/B/Back -> `resume()` (unpauses unconditionally). QUIT keeps the tree paused under the wipe (Transition unpauses on swap).
restart_prompt.gd (layer 21) is the same pattern for R. rotate_hint.gd (autoload, layer 100, ALWAYS): on a portrait
touchscreen shows a cover, remembers `_was_paused`, pauses, re-pauses every frame if something unpaused it, and on landscape
restores `_was_paused` (only if the scene did not change). The game's own nodes are pausable, so while paused only
ALWAYS nodes (pause menu, prompt, RotateHint, Transition, RandomMapView, PlatformEvents) handle input.

**Touch.** touch_controls.gd (CanvasLayer 15 in main.tscn; the hub makes its own): `_input` (before GUI) tracks finger indices
for joystick (left half), JUMP (right half), pause (presses the `menu` action via `Input.parse_input_event`), ability buttons
(fire on release on the same button), hub tap claims, WEAR IT toast taps; every ScreenTouch is set handled (buttons still work
through the emulated mouse click, which arrives first). Releases are tracked by index, so a finger lifted anywhere still
releases its control; pause / exit-tree / keyboard or pad press / `menu_open` release everything held. Drawing is one
Control `_draw` redrawn on input events and blink edges only. RotateHint feeds every window event to `UIKit.note_pointer`.

## Findings

### D2-01 — high — bug — scripts/ui/touch_controls.gd:155-156 (with :435-438)
- Evidence: `hide_controls()` ("Hides the controls (e.g. when a level ends and menu buttons take over)") is called by
  game.gd `_finish` (game.gd:2901), the resumed boon card (:629) and the preview card (:3265). But `_input` does
  `if event is InputEventScreenTouch: visible = true` and then `_touch_down` with no "hidden on purpose" check. So the first
  tap on the win / dry-up result (layer 1 HUD) brings the joystick, JUMP and pause (layer 15) back on top of the result panel
  and choice row, and the touch also presses `jump` (right half) or the move actions (left half) while the slime is frozen.
  test_next_steps.gd:30 only checks right after the win ("touch controls get out of the way of the buttons"), never after a tap.
- Fix: add a `suppressed` flag set by `hide_controls()` (cleared by a new `show_controls()` the game calls where it wants them
  back, e.g. `_close_preview_card`), and return early from touch handling while it is set (same shape as `menu_open`).
- Behavior risk: changes behavior (also removes the accidental "tap right half = `jump` = skip result staging" in hud.gd:1547).
- Confidence: high.

### D2-02 — high — bug (softlock) — scripts/ui/rotate_hint.gd:131-132, :150-156 (with pause_menu.gd:397-399, restart_prompt.gd:125-127)
- Evidence: path: pause menu open (tree paused) -> phone turned upright: `set_shown(true)` stores `_was_paused = true` ->
  while the cover is up a non-touch input reaches the pause menu (Android back = `menu` via PlatformEvents.go_back, Esc/P on a
  tablet keyboard, pad B/START, or Enter/A on RESUME, which still has focus under the cover) -> `resume()` hides the menu and
  unpauses -> next frame RotateHint `_process` re-pauses ("something unpaused it under the cover") -> phone turned sideways:
  `tree.paused = _was_paused (true) and same scene` -> tree paused, pause menu hidden. game.gd `_unhandled_input`, the touch
  pause button and `pause_for_background` all need an unpaused tree, so nothing can reopen or resume: softlock. The same holds
  for the restart prompt (Esc/R/back -> `close()`). tests/test_touch.gd:92-117 never unpauses while covered.
- Fix: in `_process`'s re-pause branch also clear `_was_paused = false` (whoever unpaused under the cover meant "running").
- Behavior risk: changes behavior (only in that sequence). Not rated critical only because it needs a non-touch input
  while the portrait cover is up (Android back makes it reachable once Android ships).
- Confidence: high on the code path; not reproduced on a device.

### D2-03 — high — bug — scripts/ui/transition.gd:111 (with :143-151)
- Evidence: `go()` does `_tween = create_tween()` without killing the previous tween. If `go()` starts while the previous
  arrival's uncover tween (0.32 s) is still running (a player who presses BACK / a tile within 0.32 s of a screen appearing;
  `busy` is already false then), both tweens run; the old one's final `tween_callback(func(): _sheet.visible = false)` fires
  mid-cover (or, if the cover ends first, during the next uncover, since `_uncover()` kills only `_tween`, i.e. the new one).
  Result: the sheet vanishes part-way, the old screen shows uncovered and the swap pops, or the reveal pops instead of sliding.
- Fix: `if _tween: _tween.kill()` at the start of `go()` (as `_uncover` already does).
- Behavior risk: changes look (only in that race; normal wipes identical).
- Confidence: high on the logic; visual effect not captured.

### D2-04 — medium — bug — scripts/ui/level_select.gd:312-316, title.gd:408-413, victory.gd:251-253, boards_screen.gd:260-269, demo_end.gd:175-177, language_screen.gd:203-206
- Evidence: each handler mutates Progress before calling `UIKit.go`, and `Transition.go` silently returns while `busy`; input
  is not blocked during the 0.22 s cover. E.g. tap level 3 then level 4 within the cover: `start_story(4)` runs, the second
  go() is refused, and the game scene (built after the cover) plays level 4. Likewise PLAY DAILY then PLAY WEEKLY plays the
  weekly; victory RANDOMIZER during an Esc-to-hub wipe runs `new_random_maze` (clears attempts / random map) and still lands
  in the hub; a language tapped after BACK is saved and SETTINGS opens in it.
- Fix: a `UIKit.leaving(tree)` helper (Transition.busy) checked first in these handlers, or make `UIKit.go` return bool and
  mutate only after success.
- Behavior risk: changes behavior (second press ignored).
- Confidence: high (path read end to end); needs a fast double tap.

### D2-05 — medium — bug — scripts/ui/touch_controls.gd:161-172
- Evidence: a released InputEventScreenTouch is handled the same whether or not `event.canceled` is set (no use of
  `canceled` anywhere in the repo). An OS-cancelled touch (system gesture, palm rejection, notification pull) therefore
  releases JUMP as a real leap (`_release("jump")`), fires an ability whose button is still under the finger
  (`ability_tapped`), emits a hub `tapped` (glide) for a short touch, and fires/cancels an aim.
- Fix: on `canceled`, take the `_release_all()`-style path for that index (release without firing / tapping).
- Behavior risk: changes behavior (cancelled touches no longer act).
- Confidence: medium (depends on how often the platforms deliver cancel; Godot 4.7 does set the flag).

### D2-06 — medium — hot-path — scripts/ui/skin_showcase.gd:217-224 (with :77-94, :204-214)
- Evidence: `_age_trail()` ends with an unconditional `_trail.queue_redraw()` every frame while any trail cell exists, although
  its doc says "redraws when a cell crossed an alpha step" (alpha is quantized to 4 steps, `_cell_alpha`). Each redraw draws
  7 rows per cell via `Cosmetics.trail_cell_at` + `hash(Vector2i)`, and `_cell_alpha` calls `_reduce_motion()`, which does
  `root.get_node("Progress")`, once per cell per draw. With Reduce Motion on, the static tail is redrawn every frame unchanged.
- Fix: redraw only when a cell was added/dropped or some cell's quantized alpha changed (cache the last step per cell or the
  next step time); read reduce_motion once per frame. Output pixel-identical.
- Behavior risk: none. Needs measurement (skins screen only).
- Confidence: high on the redundancy.

### D2-07 — medium — hot-path — scripts/ui/map_view.gd:562-617 (also :253-259)
- Evidence: `_draw_frame` loops over every pixel of the framed map (`for y in h: for x in w`, up to ~320x150) and `continue`s
  for everything deeper than FRAME (4 px), so ~90% of the iterations do nothing; it runs on every map open and every PAPER
  press (map_select.open_view) and in RandomMapView. The posts loop in `_draw_maze` allocates a 4-element array literal per
  post (`for d in [Vector2i(-1, -1), ...]`). GDScript per-pixel loops are slow on web/phones.
- Fix: iterate only the four FRAME-wide bands (same per-pixel colour logic, same order of writes); hoist the offsets array to
  a const. Pixel-identical.
- Behavior risk: none. Needs measurement.
- Confidence: high on the wasted iterations.

### D2-08 — low — hot-path — scripts/ui/title.gd:504-515
- Evidence: `LogoDrip._process` calls `queue_redraw()` every frame, including the 1.5-3 s waits where `_draw` returns
  immediately (`_tip < 0`) and between 0.05 s animation steps. (title `_process` also builds `"air_" + side` strings and
  `StringName(anim)` per slime per frame.)
- Fix: redraw only while `_tip >= 0` and once when it goes back to -1 (or only on step boundaries). Pixel-identical.
- Behavior risk: none. Needs measurement.
- Confidence: high.

### D2-09 — low — unchecked-error — scripts/ui/transition.gd:116 (also title.gd:100, :107)
- Evidence: `get_tree().change_scene_to_file(scene)` result ignored; on failure (e.g. a path a demo export cut,
  `Demo.full_only_paths`) the wipe uncovers the old screen with no log of which call failed.
- Fix: check the Error and `push_error` with the path (keep the uncover).
- Behavior risk: none.
- Confidence: high.

### D2-10 — low — dead-code — scripts/ui/intro_card.gd:62, :186, :197-198
- Evidence: `was_skipped()` has no caller in scripts/, tests/ or tools/ (grep); `_skipped` exists only for it.
- Fix: delete both.
- Behavior risk: none.
- Confidence: high.

### D2-11 — low — dead-code — scripts/ui/map_view.gd:128-130
- Evidence: `route_width(_floor_px)` always returns 1 and is called only by tests/test_maps.gd:696, :747 (the renderer
  hard-codes 1 px in `_draw_route`).
- Fix: drop it with those two test lines (or keep deliberately as test API).
- Behavior risk: none.
- Confidence: high.

### D2-12 — low — duplication — boards_screen.gd:10, key_controls.gd:269, language_screen.gd:23, victory.gd:122
- Evidence: scene paths re-declared as literals: `GAME_SCENE := "res://scenes/main.tscn"` (= `UIKit.GAME_SCENE`), SETTINGS
  `"res://scenes/controls.tscn"` in two files (and controls.gd / hub.gd), skins `"res://scenes/skins.tscn"`.
- Fix: use `UIKit.GAME_SCENE`; add `UIKit.SETTINGS_SCENE` / `SKINS_SCENE` constants.
- Behavior risk: none.
- Confidence: high.

### D2-13 — low — hygiene — scripts/ui/touch_controls.gd:167
- Evidence: a lost line continuation left five literal tab characters in the middle of one line:
  `... or event.index == _pause_touch \t\t\t\t\tor event.index == _tap_touch`. Parses, but reads as broken.
- Fix: restore `\` + newline (or one line).
- Behavior risk: none.
- Confidence: high.

### D2-14 — low — hygiene — scripts/ui/transition.gd:326-328
- Evidence: `_input` sets `_wore_msec = Time.get_ticks_msec()` right after `wear_notice()` returned true, but
  `wear_notice()` already set it (:290).
- Fix: drop the duplicate assignment.
- Behavior risk: none.
- Confidence: high.

Checked and not reported: lambda connects to autoload signals (key_controls :105, rotate_hint :105) are freed with their
owner; no double-connected signals found; touch release outside a control is tracked by index; pause menu cannot open during
a wipe (game.gd `_leaving`); RotateHint vs Transition unpause is handled; descent_card is dormant (DESCENT off).
