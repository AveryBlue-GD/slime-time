# Review: trail map trial (791ab83..HEAD, excluding docs)

> Archived code review of the trail map trial: all five findings fixed; the current map rules are in [../handoff.md](../handoff.md) and [../architecture.md](../architecture.md).

Read-only review. Nothing was run against the real save. Findings are listed most severe first.

**Status (2026-10-14): all five fixed** (survey format version 2 with a layout fingerprint, stale surveys dropped,
focus locked in the map view, marks clipped to seen tiles with a stronger leak test, route time shown only when it
is the record). Details in [handoff.md](../handoff.md), "Map review + navigation QA fixes".

1. scripts/survey.gd:48 (`fits`), also used at scripts/progress.gd:1356 and scripts/ui/map_select.gd:193 - **Surveys are matched to a maze by tile size only. There is no layout fingerprint.**
   - Normal mazes come from the shared MazeGenerator with fixed seeds. Hard mazes have already been re-laid once (HARD_LAYOUT_VERSION and `_migrate_hard_times`). A later change to generator tuning or to a level config can keep `cells` the same while changing walls, start or goal.
   - Failure scenario: a player has seen 60% of normal level 4. An update re-lays the level at the same size. The map table then:
     - paints the old seen bitset over the new layout, which shows floor and walls of the new maze that were never seen there (a spoiler), and reports a wrong SURVEY %;
     - draws the goal X at the new goal location because the stale `goal` flag is still set;
     - has `route_cells` follow the old moves through the new maze's open passages until the first wall, so the route traces real, unseen corridors.
   - `record_survey` also keeps OR-merging new runs into the stale bitset, so the damage never clears.
   - Fix: store a 32-bit layout hash in the packed header (for example `hash(maze.walls)` mixed with start and goal; bump VERSION to 2) and compare it in `fits()`. On a mismatch, treat the survey as absent: lock the tile, and have `record_survey` start from `Survey.blank`.

2. scripts/progress.gd:1363 - **A stale clear can block a valid route forever.** This is the same root cause as finding 1, but it needs its own handling.
   - Failure scenario: a stale survey from an older layout of the same size keeps `clear = true` and its `best_ms`. If the new layout's route is longer (the hard rebalance lengthened routes), no new clear is ever faster.
   - Result: BEST ROUTE keeps showing the old time with a route that is cut off at the first new wall, and a correct route is never stored.
   - Fix: the fingerprint check from finding 1 covers this. Without it, at least drop `clear`/`best_ms`/`moves` when `route_cells` does not reach `maze.goal`.

3. scripts/ui/map_select.gd:184 - **Focus can leave the map view through Tab.** The view's BACK button has all four `focus_neighbor` sides pointed at itself, but `focus_next`/`focus_previous` are not set. `ui_focus_next` (Tab by default) therefore walks the tree to the select's controls, which are covered but still visible.
   - Failure scenario: while viewing a map, the player presses Tab and then Enter or Space. Depending on where focus lands, this:
     - opens another level's map;
     - silently toggles HARD and rebuilds the hidden grid, so after `close_view` the viewed level's tile may be locked in the other mode;
     - or presses the select's BACK and leaves straight to the hub.
   - hub.gd:398-399 already guards its quit panel this way.
   - Fix: also set `view_back.focus_next` and `focus_previous` to itself. Alternatively, set the select's `grid`, `hard_box` and `back_button` to `focus_mode = FOCUS_NONE` (or `process_mode` disabled) while `viewing`, and restore them in `close_view`.

4. tests/test_maps.gd:395-408 - **The "never draws an unseen tile" test passes on a survey that cannot leak.** It renders a blank survey with only part of one row seen: there is no route, no coins, the goal flag is false, and the start tile is excluded from the check.
   - The paths that could draw over fog are never exercised: the route line, coin dots, the goal X and stale or foreign routes.
   - Fix: also render a survey that has a last-try route, found coins on both seen and unseen cells, and `goal = false`. Assert that no route, coin or X pixel lands in the centers of unseen tiles. Add a same-size foreign-layout case once finding 1 is fixed.

5. scripts/progress.gd:1363 together with scripts/ui/map_select.gd (tile and view line) - **BEST ROUTE can disagree with the level's record.** The survey's `best_ms` starts empty for existing players and only counts clears recorded after this update.
   - Failure scenario: a player whose record is 0:45 clears again in 1:02. The map table shows "BEST ROUTE 1:02" while the level select shows BEST 0:45.
   - Fix: label it "ROUTE" or "LATEST CLEAR" when `best_ms` is greater than `best_times[key]`. Alternatively, accept a clear as the route when it is within the record but there is no route yet, and keep the wording "best route" only when the two match.

## Checked with no issue found

- Capture indexing: `_paint_cells` and `_reveal_light` index with `maze.size`, and border tiles are skipped or bounds-checked. `_reveal_wall` is bounds-checked. Odd tile to cell conversion with `>> 1` is correct, and negative tiles are rejected.
- Exclusions: assisted, dev_toggled (F1/F2), dev_tools, randomizer and loose game nodes are all excluded.
- Once-only commit: the survey is committed exactly once across win, dry-up and `_exit_tree`, and reload creates a fresh node.
- Route rules: a slower clear does not replace the route; a last try is replaced only by an attempt that moved.
- Save format: `&` binds tighter than `==`/`!=` in GDScript, so the flag and bit tests are right. The pack/unpack lengths and the size and length checks are consistent. Hostile, oversized and non-string values are dropped. The worst-case save code (20 surveys of 2000 moves each, roughly 24 KB) stays under the 64 KB cap.
- Reset, old saves and keys: reset clears both the surveys and the hint; old saves load with an empty `{}`. Hard keys use +100 and do not collide.
- Seeding: `--maps=full` and `--story-complete` only seed in saving-disabled runs, and dev mode clears the surveys without saving.
- Map view sizing: the 36x20 maze fits at (5,2), 254x142 px. `Image.fill_rect` clips and `_draw_x` bounds-checks.
- Hub: return_to works by id. The 9-station and 8-station (web) VIEW_ARC states, overlaps, any-side use and pools are covered by test_hub_maps. Esc is guarded by Transition `busy`.
- Per-tick cost is negligible and nothing is allocated per frame.
