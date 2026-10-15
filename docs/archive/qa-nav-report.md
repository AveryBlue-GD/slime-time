# Navigation / Esc / menu QA report

> Archived navigation QA: all findings fixed (B8 kept by design); the fuzzer is `tests/test_nav_fuzz.gd`, state in [../handoff.md](../handoff.md).

**Status (2026-10-14): B1-B7, B9, B10 fixed; B8 kept by design (the first Esc in a text box only stops editing;
focus now stays on a button and the second Esc closes), with N3's `_leaving()` guards. Each has a regression check
and the fuzzer's `KNOWN` table is empty. Six area walks were added (see the Running section and
[handoff.md](../handoff.md)).** The report below describes the bugs as found.

Driver: `tests/test_nav_fuzz.gd` (+ `tests/nav_fuzz_lib.gd`). It boots the real scenes in a SceneTree script with an in-memory
save (`--story-complete`-style state via `Progress.enable_story_complete()`, plus fresh / mid-progress / dev / touch states),
sends real input events (`Input.parse_input_event`: keys, `ui_*` actions, joypad A/B, mouse clicks and touches at the buttons'
rects, same-frame double presses, holds with echoes, presses during the goo wipe and on the exact frame a scene changes) and
checks invariants after every action: one overlay owns input, `paused` only behind a pause overlay, a visible focused control in
every menu (and inside the open modal), no engine/script errors (an `OS.add_logger` Logger counts them), `Engine.time_scale` 1,
no input action left held, a way back (Esc ladder, with the pause menu's QUIT TO HUB in a level), node/object counts over 50
hub <-> map table cycles, `saving_enabled` stays off. Then deterministic random walks (7 start states, fixed seeds, 1,200 inputs
each by default; `-- --nav-steps=2000 --nav-seed=N --nav-walk=I` replays one walk) and a `--web-ui` child-process walk.
The real save (`~/Library/Application Support/Godot/app_userdata/Slime Time/save.cfg`) was never touched: md5 before and after
`6e9f56dac03e68a2287ad629aecca039` (tests run on a per-process throwaway save, `saving_enabled=false`).

The suite runs in about 27 s, is deterministic (two runs produce identical output) and passes: open bugs below are listed in its
`KNOWN` table, printed as `BUG`/`KNOWN`, and do not fail it; any new violation fails it. When a bug is fixed, delete its line from
`KNOWN` (and run with `-- --nav-strict` to see every known bug counted as a failure). About 70,000 random inputs over more than
20 walk seeds found nothing beyond the list below.

Verified OK (no bug): Esc x5 / P on the title; Enter x2 into the hub; Esc in the hub goes to the title (design, see N1); quit
hatch confirm opens with BACK focused, Esc / P close it, Esc+P in one frame never quits; coin board; hat wheel (Esc ignored while
spinning, closes after); F while the hub rotates opens nothing; opening the map table under the quit / coin overlay does nothing;
map select -> view -> Esc -> Esc -> hub (view closes first, then the select leaves; the hub faces the table; F again re-enters at
once); Esc x6 in the map view lands in the hub/title and never quits; echoes of a held Enter / Esc do not press BACK; locked tiles
do nothing; an all-locked select still has a working BACK; clicking where a tile lies under the open view does nothing; touch on
tiles and BACK; HARD checkbox by click and Space; Esc in level select / upgrades / skins / hats page / settings / key page;
rebinding (Esc cancels the rebind only; odd keys do not break menus); pause (Esc, P, same-frame double Esc), R while paused
opens no second overlay, restart prompt (R / Esc / R again), pause in the ease-in, seed box (Esc, click-away, typed seed
reload); dry-up UPGRADES -> PLAY / Esc returns into the level; story intro Esc / P skip; finale Esc -> victory; resize; hub <->
map table node count stays flat over 50 cycles; the map table with the touch JUMP; no scene change leaves `Engine.time_scale` or
the tree paused.

## Bugs (10, plus 3 notes)

### B1. Map view: Tab / Shift+Tab move focus under the opaque view (medium)
Repro: hub -> MAP TABLE, Enter on level 1's tile (view opens), Tab four times, Enter.
Expected: focus stays on BACK while a map is shown. Actual: Tab moves keyboard focus to the (hidden) tiles / HARD box under the view;
focus is invisible; Enter on it switches the view to another level (level 1 -> 7 above) or toggles HARD with the view still up.
Trace: `tests/test_nav_fuzz.gd` -> scripted "map view: Tab"; walk `--nav-walk=3 --nav-seed=1234` hits it (step 892).
Cause: `view_back.set_focus_neighbor` is set for the four directions only; `focus_next` / `focus_previous` are not.
File: `scripts/ui/map_select.gd:183-184` (`_build_view`). Fix: also set `focus_next` / `focus_previous` on `view_back`, or disable the
tiles and HARD box (`focus_mode = NONE`) in `open_view` and restore in `close_view`.

### B2. Settings: arrows / Tab leave the SAVE CODE and ERASE ALL PROGRESS panels; Enter then stacks a second panel (medium)
Repro: hub -> SETTINGS, SAVE CODE (or RESET PROGRESS), press Right / Down / Tab until focus lands on a button behind the dim
panel (seen: SAVE CODE panel + Right -> focus on SAVE CODE behind it), Enter.
Expected: focus is confined to the open panel. Actual: focus goes to buttons behind the panel; Enter opens another panel
(`code_panel` and `reset_confirm` both visible, "2 overlays own input"), or can press CONTROLS / BACK (leaves settings) with no visible focus.
Files: `scripts/ui/controls.gd:104` (`_build_code_panel`), `:248` (`_build_reset_confirm`). Fix: confine focus (focus neighbours to
self on the panel's edge buttons, `focus_mode = NONE` on the page controls while a panel is open).
Walk: `--nav-seed=31337` (step 86), `--nav-seed=777` (step 96).

### B3. After pausing over the dry-up / win buttons, nothing is focused and no key restores it (medium)
Repro: any level, dry up (or win), wait for the RESTART / UPGRADES (REPLAY / NEXT LEVEL / HUB) buttons, Esc, Esc.
Expected: focus returns to the choice that had it. Actual: no focused control; Enter, Space, Down, Right and Tab all do nothing
(R and the mouse still work; a gamepad-only player has no way to choose).
File: `scripts/ui/pause_menu.gd:126` (`resume()` hides the pause menu whose RESUME button owned focus) -> remember
`get_viewport().gui_get_focus_owner()` in `open()` and `grab_focus()` it in `resume()`; `scripts/hud.gd:461` only grabs focus once.
Walk: `--nav-seed=1234` (step 285).

### B4. UPGRADES (or RESTART) pressed during the QUIT TO HUB wipe leaves `return_to_game` stuck (medium)
Repro: dry up, Esc (pause), QUIT TO HUB, and within the 0.22 s wipe click UPGRADES (`tests`: scripted "wipe + UPGRADES").
Expected: land in the hub, nothing changes. Actual: land in the hub with `Progress.return_to_game == true`; the next hub UPGRADES visit
shows PLAY and Esc / PLAY starts a level instead of returning to the hub (verified: ends in `main.tscn`).
Cause: `go_to_upgrades` sets the flag before `UIKit.go`, which is ignored while `Transition.busy`. The pause menu's `_quit` unpauses
first, so the dry-up buttons are clickable during the wipe.
Files: `scripts/game.gd:1554-1558` (`go_to_upgrades`; `retry` 1540, `replay` 1580, `play_next` 1588 have the same missing
`_leaving()` guard), `scripts/ui/pause_menu.gd:172-176`.

### B5. RESTART / REPLAY / NEXT pressed in the last frames of a wipe races the scene change: 13 script errors (low-medium)
Repro: dry up, click UPGRADES, click RESTART exactly 12 frames later (0.2 s; frames 0-8 and 13+ are clean): the reload and the wipe's
`change_scene_to_file` land in the same frame, the reloaded level is freed before its deferred calls run.
Actual stderr: `SkinText.recolor` -> `get_tree().get_nodes_in_group` on null (`skin_text.gd:65`), `Game._ease_in` -> "Can't use get_node() with
absolute paths from outside the active scene tree" (`game.gd:411`), `skin_text.gd:46-48,110,115` (13 errors). Ends in UPGRADES correctly.
Files: same missing `_leaving()` guard as B4 (`scripts/game.gd:1540,1580,1588`); also make `SkinText.recolor` return when
`not is_inside_tree()` and `_ease_in` check `is_inside_tree()`. Found by walk `--nav-seed=1234` (step 1647) and scripted.

### B6. Touch pause button leaves the `menu` action pressed forever (medium on touch / mobile web)
Repro: `--touch` (or any touch), tap the pause icon (top right) in a level or the hub; `Input.is_action_pressed("menu")` stays true
(pause opens, resume, still true).
Actual: `touch_controls._touch_down` parses `InputEventAction menu pressed=true` and never a release. Everything that polls
`Input.is_action_just_pressed("menu")` (hub: Esc -> title, closing the quit confirm / hat wheel) never triggers again until a keyboard Esc is
pressed and released; the hub's own touch pause button works exactly once.
File: `scripts/ui/touch_controls.gd:79-83` (send the release event on the next frame / `_touch_up`).
Walk: `--nav-seed=7` (step 612), `--nav-seed=8` (step 1252) via the STUCK invariant.

### B7. Victory screen has no back path (low)
Repro: finish level 10 -> CONTINUE (or hub dev: open `victory.tscn`), press Esc / P / B. Nothing happens; every other screen goes back.
File: `scripts/ui/victory.gd` (no `_unhandled_input`; also its buttons use `UIKit.go` but `game.play_next` reaches it with a plain
`change_scene_to_file` at `game.gd:1598`, so there is no wipe). Suggest Esc -> hub.

### B8. Esc in a text box only stops editing (low)
Repro: SETTINGS -> SAVE CODE, click / Tab into the paste box, Esc: the panel stays open and (after typing) focus is dropped
(`focus_owner == null`); a second Esc closes it. Same in the pause menu's SEED box: first Esc is eaten by the LineEdit, second closes the box,
third resumes. File: `scripts/ui/controls.gd:324`, `scripts/ui/pause_menu.gd:191` (`LineEdit` consumes `ui_cancel` first). Fix: handle
`ui_cancel` in the line edits' `gui_input`, so the first Esc closes the box / panel.

### B9. QUIT TO HUB / restart-prompt UPGRADES unpause the level for the length of the wipe (low)
Repro: pause, QUIT TO HUB, hold a direction: the slime keeps moving / draining under the goo for ~13 frames (344.0 -> 345.75 px in the
test); a chalice or a dry-up in that window is recorded. File: `scripts/ui/pause_menu.gd:172-176`, `scripts/ui/restart_prompt.gd:61-64`
(`close()` / `resume()` before `UIKit.go`). Fix: freeze the slime (`slime.frozen = true`) or let `Transition.go` do the unpausing (it already does).

### B10. `GooBox._boxes` / `_themes` WeakRef lists only shrink on a skin recolor (low)
Every screen opened leaks ~17 RefCounted `WeakRef` objects (`Performance.OBJECT_COUNT` +17 per scene change in every scene; nodes stay flat,
orphans 0; 50 map-table cycles: 5,514 -> 6,272 objects). Harmless for hours of play, but unbounded. File: `scripts/ui/goo_box.gd:16,19,42,47`
(prune dead refs in `_init` / `track_theme` every N appends).

## Notes (design, not filed as bugs)
- N1. Esc in the hub goes to the title with no confirm (`hub.gd:565-568`). Because Esc from any hub screen first returns to the hub, a quick
  Esc, Esc (about 0.3 s apart, after the wipe) goes settings -> hub -> title; Esc x3 from the map view reaches the title. Never quits the app.
- N2. `level_select._fill_grid` (`level_select.gd:50-56`) queue_frees the old tiles without `remove_child` (map_select does it right); a click
  in the same frame as the HARD toggle lands on a doomed tile and drops focus. Unreachable by a human (needs two events in one frame).
- N3. The level result buttons, pause menu and dry-up buttons are still live behind a running goo wipe (root of B4/B5/B9); a `_leaving()` guard
  in `retry` / `replay` / `play_next` / `go_to_upgrades` would close all three.

## Running
`./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_nav_fuzz.gd`
Options after `--`: `--nav-steps=N`, `--nav-seed=N`, `--nav-walk=I` (replay walk I; area walks are 7-12), `--nav-only=walks|scripted`, `--nav-strict`
(known bugs fail), `--nav-variant=touch`, `--nav-area-steps=N` (inputs per area walk, default 2000; 0 skips them).
