# Audit C: hub, HUD, tutorial / training, abilities, story, autoplay

Read-only audit of branch `cleanup/audit-2026-11-02`, 2026-11-02. I read every line of the files in scope. I traced callers and dead code with greps across `scripts/`, `scenes/`, `tests/` and `tools/`. Godot was not run, so every perf item says "needs measurement". Items already fixed in `docs/perf/cpu.md` are not reported again. Item 10, `station == near`, is still open and appears below as C-05.

## Map

**scripts/hub.gd (Node2D, `scenes/hub.tscn` is only this script)**: the hub room and every menu in it.
- `_ready`: clears the demo preview, the random map and RELAXED. Builds the room (`hub_room.gdshader` ColorRect, floor ellipse walls, rotor). Builds 8-9 ring stations plus the DAILY sign in `extras`, then the slime and hat. `_build_ui` makes the prompt, names, badges, coin board, ticket pod, quit / portal / resume / hub-menu overlays, the wishlist sign, the HatWheel, SkinText and the TouchControls. Then, if `Progress.hub_tour_due()`, it creates the tour (`hub_tour.gd`). It finishes with `_place_all` and the deferred `open_resume_menu`.
- `_physics_process` handles input. Each open overlay eats Esc / B first, in this order: hub menu, resume, quit, portal, hat wheel, coin board. After that come the tour's back press, Esc for the hub menu (the D10 home tap goes to the title), the turn animation (`turn_room` -> `room_turned` signal, which the tour listens to), `_glide_step` (touch tap-to-glide presses real move actions), `_update_near` and F / R / interact through `_use`.
- `_process` runs every frame: `_place_hints()` (the label solver and badge placement, C-01), idle animations and sprite frames, the light pools' flicker, highlight modulates, the station-name fade (`NAMES_TIME` 3 s after `_ready`, never shown again) and the rotor frame.
- `_use(station)` -> `_leave(station, scene)` sets the static `return_to` and runs `UIKit.go` to level_select / maps / skins / upgrades / controls / boards / main. In-place overlays: the coin board, the hat wheel, quit, portal (Descent on), and resume (`Progress.descent_resume*`).
- Coming back: `game.gd:3211/3331` and `demo_end.gd:219` set `Hub.return_to` by `load("res://scripts/hub.gd").set(...)`. `_build_stations` turns the room so that station sits at the back.
- Progress reads: hub color / rainbow, tickets, medals, `hub_news` / `hub_mark_seen`, daily / weekly / boards state, descent resume, demo gates (`Demo.*`), `store_affordable`, `can_spin_hats`.

**scripts/hub_tour.gd (Node, a child of the hub, only while a tour is due)**: the guided first visit (no skip; blocks every station until the room has turned all the way round, then holds the room and draws an arrow to the archway; `TUTORIAL_HUB` is saved only when the archway is used), or the free tour after a SETTINGS training replay (a SKIP pod, Esc skips).
- The hub calls into it: `back_pressed`, `blocks`, `wait_note`, `holds_room`, `guide_line`, `line_for`, `key_text`, `lit_id`, `station_used`.
- `_process` per frame: the hint timer, re-showing the prompt when the device changes, the arrow bob. Lines go into the hub's own prompt (`hub._show_prompt`).

**scripts/hud.gd (CanvasLayer in `main.tscn`, a child of game)**: the top pods (meter with coins under it; timer; level, coins left, attempt / pot, boons; ASSIST / WIND / ABILITIES / DEV tags), the area name and story line, the result panel plus rewards row, the NEW RECORD banner, the choice row, the vignette and the training direction line.
- game.gd drives it: `set_slime` and `set_time` every physics tick (`game.gd:691, 743`), `set_attempt` / `set_pot` when the pod inputs change, plus `set_coins`, `show_message` / `show_rewards` / `show_choices` / `stage_result` and `show_area_name`.
- `_process` per frame: training steps (training mode, or the ability coach's line only), the chalice frames while the banner shows, the low-meter pulse, and the rainbow hue on the meter.
- Training hook: `game.training_cue` -> `_on_training_cue` (meter pulse on "first_drain", the accept glyph by RESTART on "dry").
- Non-English locales re-fit through `_queue_fit` -> `_fit_result` (deferred). English goes through `_away_from_slime` (UI-09).

**Tutorial and training flow**: `title.gd` -> `Story.play("intro")` -> `Story.launch_next`, which returns `Progress.prepare_training` (the training maze in `main.tscn` with `Progress.MODE_TRAINING`). `training.gd` (static `Training`) holds the layout, the meter numbers, the lines and the attempt / coin state across RESTART reloads (`mark_restart` / `begin_run`). game.gd loads `training_cues.gd` by path (`game.gd:1780-1790`) as a child of the slime; it draws the move / leap keycaps through `TutorialCues`' static drawing helpers and reports input through `Progress.note_training_input`. The chalice leads to HUB -> `Progress.finish_training` (sets `tour_replay` for replays) -> hub -> `hub_tour.gd`. Levels 1-2 use `tutorial_cues.gd` (`game.gd:595`), which saves bits through `mark_tutorial_seen`.

**Abilities**: `abilities.gd` (static `Abilities`) holds the rules: `allowed_in` (randomizer and Descent only), prices, charges, aim geometry, the splatter RNG, icons. `ability_runner.gd` (Node2D, `AbilityRunner.create` from `game.gd:593`) reads the keys and touch signals each physics tick, runs aim mode, and drives the in-flight GooShot / GooBomb / SplatDrop nodes, which call `game.reveal_tile` / `_paint_goo` / `spend_slime`. It pushes `strip()` to `hud.set_abilities` and `touch_controls.set_abilities`. `ability_coach.gd` (`AbilityCoach.create`, `game.gd:594`) holds the slime (`slime.hold`), locks the other abilities (`runner.set_locked`), shows lines on the HUD training line, has its own SKIP pod (layer 3), and marks `tutorial_seen` bits 16/32/64/128.

**scripts/story.gd (static `Story`)**: the intro / finale card tables, `play()` (sets the static `mode` / `next_scene`, goo wipe to `story.tscn`, whose `story_screen.gd` plays it), `launch_due` / `launch_next` / `intro_due`, level banner lines from `scripts/level_data/`. `victory.tscn` / `demo_end.tscn` / `story.tscn` are bare one-node scenes, each pointing at its `scripts/ui/*.gd`.

**scripts/autoplay/** (`--autoplay`, debug only, never on the web): `Progress.enable_autoplay` adds an `Autoplay` node to the root. That node watches `current_scene` every frame and drives the real buttons and the hub's `_use`, using `AutoplayPlanner` (BFS plus a coin tour with 2-opt / or-opt), a `RoutePilot` (presses move actions toward the waypoints) and an `AutoplayBanner` (CanvasLayer 110, `show_lines` every frame).

## Findings

| id | sev | category | where |
|---|---|---|---|
| C-01 | medium | hot-path | hub.gd:2025, 712-787 |
| C-02 | medium | bug | hub.gd:291-295, 621, 636 |
| C-03 | medium | bug | hub.gd:2012, 2257, 2279, 636 |
| C-04 | medium | bug | hub.gd:2393-2395, 372, 472, 2365 |
| C-05 | low | hot-path | hub.gd:2031, 2040, 2116 |
| C-06 | low | hot-path | hud.gd:470-530; ability_coach.gd:154-156, 290-312 |
| C-07 | low | bug | hud.gd:606-610, 1424-1430 |
| C-08 | low | bug | hud.gd:1533-1549 |
| C-09 | low | bug | hub.gd:650-668 |
| C-10 | low | duplication | hub_tour.gd:72-155 / ability_coach.gd:265-338 / hub.gd:2454 |
| C-11 | low | duplication | hub.gd overlay lists (1809, 1858, 1937, 2049, 1409) |
| C-12 | low | dead-code | hud.gd:11, 30, 33 |
| C-13 | low | dead-code | ability_runner.gd:348-349; autoplay_planner.gd:218-219 |
| C-14 | low | hygiene | abilities.gd:4-17; ability_runner.gd:405; hub.gd:25-35, 1463-1465 |
| C-15 | low | hygiene | hub.gd:1840, 1859; hud.gd:494 |
| C-16 | low | magic-number | hub.gd (literal 320 / 180 / 160, repeated tints) |
| C-17 | low | hot-path | autoplay.gd:159, 461-484; autoplay_banner.gd:66 |
| C-18 | low | architecture | game.gd:1780-1790 vs training_cues.gd |
| C-19 | low | bug | autoplay.gd:224-227 |

### C-01: the hub re-runs the station-name label solver every frame, long after the names are hidden
- **Severity**: medium. **Category**: hot-path (needs measurement).
- **Where**: `scripts/hub.gd:2025` (`_process` -> `_place_hints()`), solver `712-787`, touch weighting `725-728`.
- **Evidence**: `_process` calls `_place_hints()` every frame without any condition. `_place_all` calls it again while the room turns. For each of the 9-10 props, `_solve_label` builds an obstacle list and scores about 44 candidate rects against every obstacle and every other prop. When the touch controls are visible, each touch circle is appended 40 times for SETTINGS / QUIT and 3 times for the others: `for _w in (40 if station.id == "settings" or station.id == "quit" else 3): obstacles.append(circle)`. That comes to roughly 100 obstacles for those two props, on phones, the slowest target. The names are visible only for `NAMES_TIME` (3 s) after `_ready`. `_names_t` is written only at `hub.gd:178` and `2042` (plus `test_hub_badges.gd`), so the names never come back. Once they are hidden, nothing reads the label positions: `_clear_badges` and `_place_badge` use them only while `name_layer.visible`, and so does `prop_at`.
- **Fix plan**: in `_place_hints`, run `_solve_label` only while `name_layer.visible` (keep the badge placement every frame). Replace the 40x / 3x duplicate obstacles with a cost weight.
- **Behavior risk**: none (the labels are hidden whenever the solve is skipped).
- **Confidence**: high that the work is wasted; the cost is not measured. The 2026-10-13 hub figure of 0.04-0.07 ms predates UI-24.

### C-02: the "!" badges skip their tour gate, so a "!" shows over the prize wheel during the guided first tour
- **Severity**: medium. **Category**: bug.
- **Where**: `scripts/hub.gd:291-295`, `621`, `636-637`.
- **Evidence**: `has_news()` starts with `if tour != null: return false`. Its only caller is `_refresh_badges` (`667`), which runs from `_build_hints` (`621`, inside `_build_ui` at line 291) and `_refresh_tickets` (`1503`, also inside `_build_ui`). `tour = HubTour.new()` comes after that, at line 293, so the gate is always open at build time. On a fresh post-training save, `spin_cost()` returns 0 while `spins == 0` (progress.gd:2852), so `can_spin_hats()` is true and `hub_news("wheel", true)` is true (empty `hub_seen`). The wheel's badge therefore pops in 3 s into the guided tour. Walking up to the wheel then shows the prompt's "!" too, while `_use` answers "AFTER THE TOUR" (`2374`).
- **Fix plan**: call `_refresh_badges()` after `tour.setup(self)` in `_ready`, and again when the tour ends (see C-03).
- **Behavior risk**: changes output (no badges during the tour, as the gate intended).
- **Confidence**: high for the code path; medium for which badges show (it depends on the save).

### C-03: once a replayed tour has ended, the hub stays in tour mode for the rest of the visit
- **Severity**: medium. **Category**: bug.
- **Where**: `scripts/hub.gd:2012`, `2257`, `2279`, `636`; `hub_tour.gd:221-228`.
- **Evidence**: `skip()` and `station_used()` set `over = true`, but `hub.tour` is never cleared. The hub gates on `tour != null`, not on whether the tour is still active:
  - R no longer turns the room: `... and tour == null and ...` at 2012.
  - `weekly_unplayed()` returns false: `if tour != null or ...` at 2257.
  - The DAILY sign skips its WEEKLY / BOARDS choice: `... and tour == null` at 2279.

  After a SETTINGS training replay (`Progress.tour_replay`, progress.gd:1530), a player who skips the tour (Esc / SKIP) and walks to the DAILY sign with today's daily already won sees DAILY MAZE plus a time. Pressing it runs `Progress.start_daily()` (2400), where it should open BOARDS or the WEEKLY. R stays dead until the player leaves the hub.
- **Fix plan**: add `func _tour_active() -> bool: return tour != null and not tour.over` and use it at those gates (keep `tour != null` where the tour's own over-handling is needed). Alternatively, the tour can tell the hub when it ends so the hub sets `tour = null` (after the arrow is freed) and calls `_refresh_badges()`.
- **Behavior risk**: changes gameplay feel (R and the sign work again after a skipped replay).
- **Confidence**: high.

### C-04: coming back from BOARDS (from the DAILY sign) resets the room instead of facing the sign
- **Severity**: medium. **Category**: bug.
- **Where**: `scripts/hub.gd:2393-2395`, `372`, `472`, `2365-2369`.
- **Evidence**: `"daily": if sign_boards: ... _leave(station, "res://scenes/boards.tscn")` passes the DAILY sign, which lives in `extras`, so `return_to = "daily"`. Back in the hub, `_build_stations` (`var back := _station(return_to)`) and `_spawn_slime` look it up with `_station()`, which searches only `stations`. The lookup returns `{}`, so the room stays at `turn = 0` (archway at the back) and the slime spawns at `START`, away from the portal and sign. The daily / weekly paths call `_leave(_station("random"), ...)` (2401) and are fine. `boards_screen.gd` goes back to `UIKit.HUB_SCENE` by default.
- **Fix plan**: `_leave(_station("random"), "res://scenes/boards.tscn")`, as the daily start does, or make the `return_to` lookup map an extra to its `anchor`.
- **Behavior risk**: changes output (where the hub opens).
- **Confidence**: high.

### C-05: deep Dictionary comparisons in the hub every frame and every tick (cpu.md item 10, still open)
- **Severity**: low. **Category**: hot-path (needs measurement).
- **Where**: `scripts/hub.gd:2031`, `2040`, `2116`.
- **Evidence**:
  - `var lit: bool = station == near or ...` and `prop.sprite.self_modulate = ... if prop == near else ...` compare station dicts by value every frame. The matching one recurses into its `anims` / `seq` arrays.
  - New since cpu.md: `_place_extras` does `stations.find(_station(prop.anchor))` on every `_place_all` (each physics tick while turning). `Array.find` on a Dictionary also compares by value.
- **Fix plan**: use `is_same(station, near)` in `_process`. Cache the anchor's ring index in the extra's dict when it is built.
- **Behavior risk**: none.
- **Confidence**: high.

### C-06: the training / coach line is laid out again every frame while it shows
- **Severity**: low. **Category**: hot-path (needs measurement).
- **Where**: `scripts/hud.gd:470-477` -> `_place_training_line` `485-500` -> `_training_line_top_y` `511-530`; `ability_coach.gd:154-156`, `290-312`.
- **Evidence**: every frame, `_training_line_step` calls `_place_training_line()`. That calls `get_combined_minimum_size()`, `pod_rects()` (a new Array plus a min-size query for each pod) and `_ink_rect` (a font `get_string_size` for the area / story line). On top of that, the coach calls `hud.pod_rects()` from `_refresh_skip` on every physics tick. Only the training maze, the demo preview and a randomizer player's first ability runs are affected.
- **Fix plan**: re-place only when an input changes (slime / joystick / buttons rect, row visibility, pods changed); cache `pod_rects()` per frame.
- **Behavior risk**: none.
- **Confidence**: medium.

### C-07: with the rainbow skin, the meter's empty-segment outlines never recolor
- **Severity**: low. **Category**: bug.
- **Where**: `scripts/hud.gd:606-610`, `1404`, `1424-1430`.
- **Evidence**: `_track_outline`'s draw lambda uses `Color(_meter_color(), 0.55)` and reads `goo_color` when it draws. With the rainbow skin, `_process` changes `goo_color` and the fill every frame, but only `set_skin_color` (1404) calls `_track_outline.queue_redraw()`. The outlines keep the hue from their last redraw while the fill cycles (UI-04 says they are in the skin's colour).
- **Fix plan**: queue a redraw of `_track_outline` in the rainbow branch of `_process`, or decide the frozen hue is intended and document it.
- **Behavior risk**: changes output (rainbow only).
- **Confidence**: medium (it may be accepted as is).

### C-08: the result staging keeps running under the pause menu, and its doc comment is on the wrong function
- **Severity**: low. **Category**: bug.
- **Where**: `scripts/hud.gd:1533-1549`; `game.gd:3411-3413`.
- **Evidence**:
  - The comment `## Waits seconds (not while paused); false if a key press cut it short.` sits above `progress_node()`, not above `_stage_wait`.
  - `_stage_wait` subtracts `get_process_delta_time()` after `await get_tree().process_frame`. That signal still fires while the tree is paused, so the wait does count paused time.
  - game.gd opens the pause menu on Esc even after `finished`. The ~1.2 s win staging therefore finishes behind the pause menu, and a `ui_accept` press in that menu also skips it.
- **Fix plan**: skip the decrement while `get_tree().paused`, and move the comment onto `_stage_wait`.
- **Behavior risk**: changes output (the staging resumes after unpausing).
- **Confidence**: medium.

### C-09: the DAILY "NEW IN {h}H" badge and all hub news are never refreshed during a visit
- **Severity**: low. **Category**: bug.
- **Where**: `scripts/hub.gd:650-668`.
- **Evidence**: `_refresh_badges` runs only at build and on `_refresh_tickets` (after the hat wheel or a quit Descent run). The hours count down without the label changing. At UTC midnight the sign keeps showing "won" (no "!"). The prompt does handle the day change (`_sign_day`, 2227), but the badge does not.
- **Fix plan**: re-run `_refresh_badges()` when `Progress.utc_day()` or `daily_hours_left()` changes. A cheap per-second check in `_process` is enough.
- **Behavior risk**: changes output.
- **Confidence**: high.

### C-10: the SKIP pod and the input helpers are copied between the tour, the coach and the hub
- **Severity**: low. **Category**: duplication.
- **Where**: `hub_tour.gd:72-119, 145-155` vs `ability_coach.gd:265-330`; `hub.gd:2454-2458` vs `ability_coach.gd:334-338`.
- **Evidence**: `_build_skip`, `skip_rect` (the same TOUCH_MIN growth) and the tap / click `_input` are near-identical in both files. `_interact_pressed()` (Transition.interact_free) is byte-identical in hub.gd and ability_coach.gd. Small `_sfx` wrappers repeat in hub.gd, hub_tour.gd (through `hub._sfx`) and ability_runner.gd.
- **Fix plan**: one `UIKit.make_skip_pod()` / `skip_rect()` helper and one shared `interact_pressed()` (on Transition, say).
- **Behavior risk**: none.
- **Confidence**: high.

### C-11: the hub's "is an overlay open" list is written out five times
- **Severity**: low. **Category**: duplication.
- **Where**: `scripts/hub.gd:1809-1810`, `1858-1859` (`_blocking_overlay`), `1937-1938`, `2049`, `1409-1410`.
- **Evidence**: `hub_menu.visible or quit_menu.visible or portal_menu.visible or resume_menu.visible or hat_wheel.visible or coin_board.visible` appears in five places, in three different orders. A new overlay (achievements, say) would have to be added to all five. The four overlay builders and closers (`1029`, `1116`, `1237`, `1371`; `1103`, `1200`, `1337`, `1438`) each repeat the same dim + panel + freeze + `menu_open` + `_show_prompt` steps, and they have already drifted: `close_quit_menu` omits `gui_release_focus()`, while the other three closers carry the comment "(no hidden button keeps the keyboard)".
- **Fix plan**: use `_blocking_overlay()` everywhere, plus a single `_open_overlay(node, focus)` / `_close_overlay(node)` pair.
- **Behavior risk**: none.
- **Confidence**: high.

### C-12: unused and duplicate constants in hud.gd
- **Severity**: low. **Category**: dead-code.
- **Where**: `scripts/hud.gd:11`, `30`, `33`.
- **Evidence**: `const POD_MARGIN := 3` is referenced only in comments (hud.gd:554, ui_kit.gd:27); layout uses `UIKit.hud_edge()`. `FRAME_COLOR` is `Color8(26, 28, 44)` and `GOLD` is `Color8(255, 205, 117)`, identical to `UIKit.BG` / `UIKit.GOLD` (ui_kit.gd:11, 19).
- **Fix plan**: delete `POD_MARGIN`; alias the colours to the UIKit ones.
- **Behavior risk**: none.
- **Confidence**: high.

### C-13: two no-op code paths
- **Severity**: low. **Category**: dead-code.
- **Where**: `ability_runner.gd:348-349`; `autoplay_planner.gd:218-219`.
- **Evidence**: `_fire_rifle`: `var from := lane` followed by `if dir.x != 0 and dir.y != 0: from = lane` assigns the same value again. `best_route`: `if order.is_empty() and end_goal and length(order, true) > limit: current = length(order, true)`. `current` already equals `length(order, end_goal)` there (set at 197 / 217).
- **Fix plan**: delete both branches (keep the comment as an `elif` note).
- **Behavior risk**: none.
- **Confidence**: high.

### C-14: stale header and doc comments
- **Severity**: low. **Category**: hygiene.
- **Where**: `abilities.gd:4-17`; `ability_runner.gd:405`; `hub.gd:25-35, 1463-1465`.
- **Evidence**:
  - abilities.gd says "three active abilities ... keys 1 / 2 / 3" and "reveals the 3x3 tiles". `LIST` has four (SLIME SENSE on M), and `Economy.SPLAT_AREA = 2` makes the blast 5x5 (economy.gd:612).
  - ability_runner.gd:405 says `# 96 for a 3x3 blast`; at SPLAT_AREA 2 it is 160.
  - The hub.gd header says "Esc goes back to it [the title]" (Esc now opens the hub menu) and "on a touchscreen, JUMP does" (now a tap; JUMP always leaps, 2009-2010).
  - The `_build_ticket_pod` doc comment (1463-1464) sits above `wishlist_sign`.
- **Fix plan**: update the comments.
- **Behavior risk**: none.
- **Confidence**: high.

### C-15: lines joined with stray tabs where a `\` continuation was lost
- **Severity**: low. **Category**: hygiene.
- **Where**: `hub.gd:1840`, `1859`; `hud.gd:494`.
- **Evidence**: `return prop_at(pos).get("id", "") == near.id <TAB><TAB><TAB>or (near.sprite...` and `... or resume_menu.visible <TAB><TAB><TAB>or hat_wheel.visible ...` each sit on one physical line with tabs in the middle. They parse fine but read as broken formatting.
- **Fix plan**: restore the line continuations.
- **Behavior risk**: none.
- **Confidence**: high.

### C-16: hub.gd hard-codes screen sizes and tints
- **Severity**: low. **Category**: magic-number.
- **Where**: `scripts/hub.gd`.
- **Evidence**:
  - Screen literals `320.0` / `180.0` / `160.0` appear at 912, 935, 953, 966-967, 982-985, 1065, 1177, 1291, 1621, 1620, 2357. hud.gd uses `UIKit.SCREEN` for the same job.
  - The highlight `Color(1.25, 1.25, 1.25)` appears 3 times (2038, 2040, 2057), the locked dim `Color(0.45, 0.45, 0.5)` twice (368, 370) and the overlay dim `Color(0, 0, 0, 0.45)` 4 times.
  - The one-column coin board uses `68` / `22` / `7` (1636-1638) next to the named `BOARD_COUNT_W` / `BOARD_SIDE`.
- **Fix plan**: switch to `UIKit.SCREEN`; add named consts `LIT`, `LOCKED_TINT`, `DIM`.
- **Behavior risk**: none.
- **Confidence**: high.

### C-17: the autoplay banner is rebuilt every frame
- **Severity**: low. **Category**: hot-path (debug tool only; needs measurement).
- **Where**: `autoplay.gd:159`, `461-484`; `autoplay_banner.gd:66`.
- **Evidence**: `_process` calls `_refresh_banner()` every frame. That formats 2-3 strings, calls `progress.coins_earned()` / `medals_total()`, and calls `show_lines`, which recomputes both widths and `Skins.shades(progress.skin_color())` (a shade dictionary) just to colour the 1 px edge.
- **Fix plan**: build the strings and refresh only when they change; compute the shades once.
- **Behavior risk**: none.
- **Confidence**: high (autoplay only).

### C-18: game.gd still loads the training cues as an optional "chunk C"
- **Severity**: low. **Category**: architecture.
- **Where**: `game.gd:1780-1790` (cross-file; the consumer is `training_cues.gd`).
- **Evidence**: `if ResourceLoader.exists(TRAINING_CUES_SCRIPT): var cues: Node = (load(...) as GDScript).new(); if cues.has_method("setup"): cues.call("setup", ...)`. Chunk C has shipped: `training_cues.gd` has `class_name TrainingCues`, and hud.gd references it directly (434, 447), so the existence and method guards can never fail.
- **Fix plan**: `var cues := TrainingCues.new(); cues.setup(self, slime, progress)`.
- **Behavior risk**: none.
- **Confidence**: high.

### C-19: autoplay finds the upgrades screen's exit button by its English text
- **Severity**: low. **Category**: bug (debug tool).
- **Where**: `autoplay.gd:224-227`.
- **Evidence**: `if child is Button and (child.text == "PLAY" or child.text == "BACK")`. The labels come from `Loc.t("upgrades.play")` / `Loc.t("common.back")`. Under `--lang=xx` (or any non-English locale) nothing matches, and the bot waits on the upgrades screen forever.
- **Fix plan**: use the screen's back-button reference (or compare against `Loc.t` of the same keys).
- **Behavior risk**: none.
- **Confidence**: medium.

### Checked and not reported
- Awaits on freed objects: `_stage_wait`, `_stagger_button`, `flash_message`, `show_share_line`, `Autoplay._hold` / `_until`. Each re-checks `is_instance_valid` / `is_inside_tree`, and Godot 4 drops coroutines whose instance was freed.
- Lambdas connected to the autoloads (`PlatformEvents.input_kind_changed` in hub.gd:578) and to `create_timer` (hub.gd:2184) capture `self`, so Godot drops them when the hub is freed.
- Tweens are bound to their own nodes.
- No double-connects: `_hook_training` is guarded, and `TrainingCues.setup` / `AbilityRunner.create` run once per scene.
- Guided tour softlock: the hub menu (QUIT TO TITLE) stays reachable, the wheel, a leap into it and a touch tap all turn the room, and `blocks()` leaves the archway open once the tour is done.
- Ability coach softlock: SKIP (F / X / a tap) is always offered while the slime is held, and `game.finished` ends the coach.
- The test-only helpers are part of the tested API: `hub._on_floor`, `hud.training_line_text`, `hud.attempt_flashing`, `Story.widest_line`, `AutoplayPlanner.simulate_campaign`.
- The four scene files are trivial, one node each.
