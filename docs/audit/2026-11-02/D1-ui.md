# D1 audit: UI kit, story, hat wheel, skins, settings, upgrades, goo / skin text / backdrop

Scope, every line read: `scripts/ui/ui_kit.gd` (1788), `story_screen.gd` (2416), `hat_wheel.gd` (1609),
`skins_screen.gd` (1147), `controls.gd` (1080), `upgrades_screen.gd` (880), `goo_box.gd` (321), `skin_text.gd` (195),
`menu_backdrop.gd` (87). Scenes: `scenes/story.tscn`, `skins.tscn`, `controls.tscn` and `upgrades.tscn` are each one root
Control with the script and nothing else. `HatWheel` has no scene: `hub.gd:551` builds it with `HatWheel.new()`. GooBox,
SkinText and MenuBackdrop have no scenes either. This was a read-only pass: no file was changed and Godot was not run.

## Map

- **ui_kit.gd (`UIKit`, static RefCounted)**: the shared UI kit. It holds the layout constants (docs/ui-rules.md) and
  per-locale metrics (`metrics()`, `button_h()`, `line_pitch()` and the rest, cached per locale). It measures and fits
  text (`text_w`, `fit_text`, `wrapped_lines`, `ink_rows`), mirrors screens for right-to-left languages (`mirror_root`,
  `relayout`, deferred `_set_mirrored`) and has layout budgets (`content_rect`, `stack_pages`, `grid_budget`).
  Widget factories: `make_label` (adds the label to the `skin_text` group with a role taken from GOLD / TEXT /
  TEXT_DIM), `make_button` (a TouchButton plus a click sound), `add_back_button`, `add_panel`, `add_ticket_confirm`,
  `make_volume_slider`, `make_slime_preview`, `add_page_arrows`. Focus helpers: `lock_focus` / `unlock_focus`,
  `cover_behind`. Shared resources: `text_material()` (one ShaderMaterial, its seed rerolled once per scene),
  `clean_big_material()`, `tabular_font()`, `plain_font()`.
  **Theming:** `setup_screen(root, title)` gives the root a fresh `make_theme()`, adds a `MenuBackdrop` and the title,
  and adds a `SkinText` with `theme_owner = root`. `make_theme()` builds GooBox button styles (normal, hover, pressed
  twice, disabled), two focus StyleBoxFlats, slider StyleBoxFlats, a GooBox panel style for Panel and PanelContainer,
  and LineEdit wells, then registers the theme with `GooBox.track_theme`. `set_selected()` gives one button its own
  "selected" GooBox override. No per-frame work.
- **goo_box.gd (`GooBox extends StyleBox`)**: the slime frames on buttons and panels. Static state: `goo_color`,
  weak lists of live boxes and themes (pruned every 32 registrations), and `_drawn` (the canvas items drawn since the
  last tint). `_draw` caches the RNG layout per (canvas item, w, h) as merged same-shade runs and replays it with the
  current shades. Recolor paths: `set_goo_color` (theme signals held, one change emitted per theme) and `tint`
  (rainbow, every frame: it scans every Control in the tree and redraws those whose canvas item drew goo).
  **perf docs cpu.md #1 fixes 1 and 4 and rendering.md #4 are FIXED** (layout cache, run merging, one emit per theme).
- **skin_text.gd (`SkinText extends Node`, PROCESS_MODE_ALWAYS)**: colours the labels in the `skin_text` group by role,
  and the button, check box, slider and focus colours in `theme_owner`'s theme. `_process`: with the rainbow skin it
  runs `recolor(shared, flow=true)` every frame. The shared part (group labels and `GooBox.tint`) runs only once per
  frame (`_shared_frame`). The flow path then sets theme colours with signals blocked and sends THEME_CHANGED to each
  visible Button under the owner; hidden labels and buttons are hooked to catch up when they show. Without rainbow,
  `_process` only checks `_is_rainbow()`. **cpu.md #1 fixes 2 and 3 and rendering.md #3 (batched theme edits) are
  FIXED.** What is still open is in D1-05.
- **menu_backdrop.gd (`MenuBackdrop`)**: the drifting dim maze behind every menu. Its tile cells are cached statically
  (cpu.md #6 FIXED; `MazeTiles.make_tile_set` is cached too), and clip_contents is off (rendering.md #11 FIXED).
  `_process` moves `_maze_root` from the engine clock every frame (listed in cpu.md under "not problems").
- **story_screen.gd** (story.tscn root): the wordless intro and finale. Entry points: `_ready` reads `Story.mode` /
  `next_scene`, then `show_card`, `advance`, `finish` (emits `done`, then `UIKit.go`). Inner classes: `Cover` (bars,
  fades, depth gauge, progress line, skip pod) and `StageArt` (camera, a dictionary particle system, every shot drawn
  in immediate mode). It draws its foreground through `Layer`. `_process`: every frame it steps the stage (physics
  substeps of at most 1/30 s) and calls `queue_redraw` on `art`, `front` and `cover`. No UIKit theme: only
  `make_slime_preview` and `UIKit.go`. **cpu.md #7 is PARTLY FIXED**: heroes and torches are computed once per step
  in `_emit`; the rest is in D1-07.
- **hat_wheel.gd (`HatWheel`, built by the hub)**: the WHEEL and SHOP overlay. It is under the hub root, so it uses the
  hub's theme and SkinText (`hub.gd:521/569`). Entry points the hub calls: `refresh`, `show_tab`, `spin`, `back`,
  `set_spin_key`, `show_close`, `modal`. It emits `landed`, `changed` and `close_requested`. It has a first-visit coach
  (`CoachArrow`). The ticket confirm comes from `UIKit.add_ticket_confirm` and locks focus while open. `_process`: while
  spinning it redraws every frame; while idle on the WHEEL it redraws only when the bulb step (260 ms) or the rainbow
  hat's flow step changes, plus the coach arrow while the coach runs. `_draw` paints the wheel by hand.
- **skins_screen.gd** (skins.tscn): the wardrobe, five pages (SKINS, HATS, TRAILS, PAPERS, HUB). Each page is a grid of
  goo tiles in VBox/HBox rows. It has JELLY / PASTEL / dice toggles, a hat COLOR picker (its own panel and focus lock),
  a custom colour wheel and a `SkinShowcase` stage. `_layout` picks a per-locale plan from `_PLANS`. No `_process`.
  Grids are rebuilt on page shows and toggles. The status line and selection are refreshed on every tile focus.
- **controls.gd** (controls.tscn, SETTINGS): a two-column grid (`_plan_page`), the SAVE CODE panel (web clipboard
  bridges, removed again in `_exit_tree`) and the RESET confirm. Both panels use `lock_focus` / `_cover_page`.
  `_process` sets the FULLSCREEN button text every frame.
- **upgrades_screen.gd** (upgrades.tscn, cauldron): COINS / TICKETS (abilities) / TOOLS (workshop, test hook) tabs.
  Rows are panels, pips (`HudTrack`), and - / + buttons. It has a ticket confirm with a 0.3 s buy guard and a 1 s
  BRIGHTNESS preview canvas. `show_page` calls `skin_text.recolor` deferred on every tab switch. No `_process`.
- **How theming is shared**: each screen root has its own Theme (from `setup_screen`, or `make_theme` plus
  `add_skin_text` on the hub, the pause menu and the restart prompt). All GooBoxes read the one static
  `GooBox.goo_color`. Labels follow the skin through the global `skin_text` group, whose roles come from the colour
  passed to `make_label`. Button text follows it through the theme colours that SkinText writes. In gameplay there are
  three SkinTexts (HUD, pause menu, restart prompt); the per-frame shared work runs once per frame.

## Findings

### D1-01 (high, bug): the demo's gold FULL cost is repainted dim by SkinText
- **Where:** `scripts/ui/upgrades_screen.gd:742` (also 469, 449)
- **Evidence:** `_refresh` sets `row.cost.add_theme_color_override("font_color", UIKit.GOLD if capped else
  UIKit.TEXT_DIM)`. But `cost` was made with `UIKit.make_label("", UIKit.FONT, UIKit.TEXT_DIM)` (line 469), and
  `ui_kit.gd:1462-1465` therefore adds it to `SkinText.GROUP` with role `dim`. `show_page` (called from `_ready`)
  calls `_refresh()` and then `skin_text.recolor.call_deferred()` (449). The deferred `_recolor_labels` then sets
  every group label's `font_color` to `color_for("dim", skin)`, so the gold is overwritten before the first frame
  draws. With the rainbow skin it is overwritten every frame. Gold shows only between a later +/- press (`_change`
  calls `_refresh` without a recolor) and the next tab switch.
- **Reachable:** demo build, any coin track at its `Demo.upgrade_cap`. `tests/test_demo.gd:482` checks only the text.
  `hub.gd:613/1671` handles the same case with `remove_from_group(SkinText.GROUP)`.
- **Fix plan:** when `capped`, call `row.cost.remove_from_group(SkinText.GROUP)` (or keep the cost label out of the
  group and colour it from the skin in `_refresh`).
- **Behavior risk:** changes look (it restores the gold the code intends).
- **Confidence:** high.

### D1-02 (medium, hot-path): the PAPERS page re-renders all 12 paper maps on every focus move
- **Where:** `scripts/ui/skins_screen.gd:883-889`; triggered from 838-840
- **Evidence:** each paper tile's `focus_entered` calls `_refresh_papers(id)`. Its loop does this for every paper
  tile (`Cosmetics.paper_ids()`: DEFAULT plus 11):
  - `paper_preview()`: `Survey.full`, `MapView.render`, and for locked papers a `get_pixel` / `set_pixel` loop over
    the whole image;
  - a new `ImageTexture.create_from_image` (a GPU upload);
  - a new `MapView.flow_material` (a new ShaderMaterial for flowing papers).

  The comment says this is because "the skin color may have changed since the page was built". The skin cannot change
  while focus moves between paper tiles: it changes only through the skins page, the dice, or `apply_look`, all of
  which go through `show_page` / `_refresh_after_look`.
- **Fix plan:** re-render the maps in a separate `_redraw_papers()` called from `show_page("papers")` and
  `_refresh_after_look`. Focus moves update only the status line and selection.
- **Behavior risk:** none (same images, made less often).
- **Confidence:** high. Perf: needs measurement.

### D1-03 (medium, leak): `GooBox._drawn` grows for the whole session unless the rainbow skin is on
- **Where:** `scripts/ui/goo_box.gd:128` and `188`
- **Evidence:** `_draw` records `_drawn[item] = true` for every canvas item that ever draws a goo box. The dictionary
  is replaced only in `tint()` (119-120), which only the rainbow flow calls (`skin_text.gd:75`). `set_goo_color`
  and `prune()` never touch it. With any other skin, every button, panel and tile of every screen ever opened stays
  in the dictionary under the RID of a freed canvas item.
- **Size:** about one entry per goo control per screen open, unbounded. Marked medium, not high, because each entry
  is small and equipping rainbow clears it.
- **Fix plan:** clear `_drawn` in `set_goo_color` and `prune()`. Better, record items only while a tint is running
  (an `_tinting` flag set by SkinText), because only `tint` reads the dictionary.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-04 (medium, bug): the GooBox layout cache key keeps only the low 32 bits of the RID
- **Where:** `scripts/ui/goo_box.gd:189`
- **Evidence:** `var key := Vector3i(seed_ids.get(item.get_id(), item.get_id()), w, h)`. `RID.get_id()` is 64 bits:
  in Godot's RID allocator the validator is in the high half and the reused slot index in the low half. Vector3i
  components are int32, so the key is in effect (slot index, w, h). A theme's GooBox lives as long as its screen, and
  screens rebuild tiles (`hat_wheel.show_section` on every section switch or purchase, the skins grids on JELLY /
  PASTEL / page shows). A new tile that lands in a freed slot with the same size gets the old tile's cached lumps.
  `_layout` itself seeds from the full id (220), so the uncached result would differ.
- **Why it matters:** docs/ui-rules.md and architecture.md promise that measuring and caching never move lumps, and
  that optimizations are pixel-identical. Today a tile's lumps depend on which tiles were there before it.
- **Fix plan:** key by the full id, e.g. `_layouts[item.get_id()]` holding a `{Vector2i(w, h): layout}` dictionary,
  or a String / Array key.
- **Behavior risk:** changes look (rebuilt tiles get the lumps their own RID would give).
- **Confidence:** medium. It rests on the RID bit layout and on Vector3i truncating rather than erroring; a quick
  headless check would settle it.

### D1-05 (medium, hot-path): cpu.md #1 rainbow residual: tree scans and re-shaped labels every frame
- **Where:** `scripts/ui/goo_box.gd:121`, `skin_text.gd:86-94` and `123`
- **Evidence:** the fixes from cpu.md #1 and rendering.md #3 are in. What remains with rainbow on, every frame:
  - `GooBox.tint` runs `tree.root.find_children("*", "Control", true, false)`: a full tree walk plus an Array of
    every Control.
  - Each SkinText's `_flow` runs two more subtree walks (`find_children("*", "Button")` and `"HSlider"`). Gameplay has
    three SkinTexts, so that is seven walks a frame.
  - Every visible group label gets `add_theme_color_override`, which re-shapes its text (D1-14 adds to this on outlined
    labels).
  - The title role calls `lift_to_contrast`, which calls `luminance` up to 26 times, and each call allocates two Array
    literals (`ui_kit.gd:1395-1396`).
  - `GooBox._shades()` (158-168) builds 1-2 Dictionaries for every box on every redraw.
- **Fix plan:** keep the Button/HSlider lists and the goo-control list per SkinText, invalidated on
  `child_entered_tree` / `child_exiting_tree`. Use const arrays in `luminance`. Memoize `_shades()` per
  (goo_color, state).
- **Behavior risk:** none. The same nodes get the same calls; keep the label overrides themselves (rendering.md: no
  `modulate` route).
- **Confidence:** high that the work exists. Perf: needs measurement.

### D1-06 (low, hot-path): `UIKit.set_selected` is not idempotent, and wardrobe focus moves call it on every tile
- **Where:** `scripts/ui/ui_kit.gd:1597-1605`; callers `skins_screen.gd:749, 824, 884, 1071, 1131`
- **Evidence:** every `set_selected(b, true)` makes a new `button_style("selected")` GooBox, which starts with an
  empty `_layouts`, so its RNG layout is built again. Every `set_selected(b, false)` calls
  `remove_theme_stylebox_override` twice; each call sends NOTIFICATION_THEME_CHANGED (minimum-size update and a
  redraw) even when no override exists. `_refresh_trails`, `_refresh_hub`, `_refresh_papers` and `_refresh_hats` run on
  every tile focus and loop over all tiles (13-25 per page). So each arrow press re-themes and redraws the whole grid.
- **Fix plan:** return early when `button.get_meta("selected", false) == on`.
- **Behavior risk:** none. Same style and same lumps: the seed comes from the canvas item, not the box.
- **Confidence:** high. Perf: needs measurement.

### D1-07 (medium, hot-path): cpu.md #7 (story allocations) is still mostly open
- **Where:** `scripts/ui/story_screen.gd:1057-1058`, `1253`, `312` / `670-750`, `1316-1324`
- **Evidence:** fixed so far: `_emit` computes heroes and torches once per step (594-601). Still open:
  - `_bayer` returns `[0.0, 0.5, 0.75, 0.25][...]`, an Array literal per brick; it is called per brick in
    `_draw_bricks`, `_draw_dead_end`, `_draw_chamber` and twice per cell in `_draw_room`.
  - `_flame` builds `[0.0, 1.0, 2.0, 1.0]` on every call.
  - Particles are still Dictionaries read with `get()` / `has()`, and `_update_parts` allocates a new `keep` array
    each substep.
  - `_hero` creates three lambdas (`rc`, `r`, `poly`) per call, and `poly` makes a PackedVector2Array per polygon.
  - `_draw_corridor` calls `_wall_torches()` again, and `_draw_pops` calls `_heroes()` again each draw.
  - cpu.md measured 0.27-0.74 ms per frame on the M3.
- **Fix plan:** const BAYER and FLAME_H arrays; direct `canvas.draw_rect` instead of the lambdas; typed particle
  storage. Keep the RNG call order.
- **Behavior risk:** none if the RNG order is kept.
- **Confidence:** high. Perf: needs measurement.

### D1-08 (low, bug): `_hold_look_note` resumes after an await on a freed screen
- **Where:** `scripts/ui/skins_screen.gd:245-255`
- **Evidence:** `await get_tree().create_timer(LOOK_NOTE_TIME).timeout` (2 s) in an instance method. If the player
  presses the dice and then leaves (Esc goes to the hub through the wipe) before 2 s, the screen is freed while the
  coroutine waits. The `is_inside_tree()` check comes after the resume. GDScript reports "Resumed function after
  await, but class instance is gone" in debug builds, and test_all fails a log that contains SCRIPT ERROR. There is no
  effect in release builds.
- **Fix plan:** use `get_tree().create_timer(...).timeout.connect(_end_look_note.bind(mine))`; the connection to a
  method of self drops when the screen is freed.
- **Behavior risk:** none.
- **Confidence:** medium (depends on the engine's resume check).

### D1-09 (low, dead-code): story layers store a translated name that is never read
- **Where:** `scripts/ui/story_screen.gd:343`
- **Evidence:** `layers.append({..., name = Themes.display_name(id), ...})`. No `layer.name` or `.name` read exists in
  the file (grep), and none in `tests/` (test_story checks only that no text calls are made). The screen is wordless
  by design, so this costs 10 `Loc` lookups per story open for nothing.
- **Fix plan:** drop the `name` key.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-10 (low, dead-code): the hat wheel's "trails" SHOP section cannot be reached in the game
- **Where:** `scripts/ui/hat_wheel.gd:793-794, 866-867, 877, 970-971, 1220-1231`
- **Evidence:** `SECTIONS := ["hats", "papers"]` (line 90). Every `show_section` caller passes a SECTIONS id or
  `section`, and `test_store.gd:439` asserts that there is no trails section. Only `tests/demo_store.gd:64` (a
  watchable demo) still defaults to `show_section("trails")`. The trail preview branch of `_show_preview` (shader
  material, 2x scale) runs only on that path.
- **Fix plan:** remove the trails branches and switch demo_store's default to "papers". The `_show_preview` TRAIL code
  can go too, if no other caller appears.
- **Behavior risk:** none in the game. The demo scene's default shot changes.
- **Confidence:** high.

### D1-11 (low, hot-path): cpu.md #10: the FULLSCREEN text is set every frame
- **Where:** `scripts/ui/controls.gd:938-945`
- **Evidence:** `_process` calls `Progress.is_fullscreen()` and `Loc.t(...)` every frame and assigns the button text.
  Button ignores an equal text, so the cost is the lookup and the String. Still open from cpu.md (cited there as
  line 294).
- **Fix plan:** cache the last state and set the text only when it flips (F11 still updates within a frame).
- **Behavior risk:** none.
- **Confidence:** high. Perf: needs measurement.

### D1-12 (low, hot-path): the story Cover redraws every frame under Reduce Motion
- **Where:** `scripts/ui/story_screen.gd:160`
- **Evidence:** under `calm` the stage is frozen (`art.step` is skipped), but `cover.queue_redraw()` still runs every
  frame. The Cover's output changes only when `floorf(60 * progress_ratio())` changes (about every 0.3 s on an 18-25 s
  intro), on the first-card alpha ramp, and when `hint_time` crosses 0.
- **Fix plan:** when `calm`, redraw only when the filled pixel count, `hint_time > 0`, or the fade alpha changes.
- **Behavior risk:** none.
- **Confidence:** high. Perf: needs measurement (small).

### D1-13 (low, hot-path): every `make_theme()` builds 8 check-box textures from 2 images
- **Where:** `scripts/ui/ui_kit.gd:558-562` and `1201-1205`
- **Evidence:** each screen open (and the hub, pause menu, restart prompt, HUD choice and others) calls `_check_slot`
  eight times. Each call does `load().get_image()` (a GPU readback on desktop GL), `Image.create`, `blit_rect` and
  `ImageTexture.create_from_image` (an upload). Four of the results are copies of "off" and four of "on".
- **Fix plan:** two static cached textures, rebuilt only if the slot geometry ever changes.
- **Behavior risk:** none.
- **Confidence:** high. Perf: needs measurement.

### D1-14 (low, hygiene): `outline_label` re-applies 16 theme overrides on every redraw of the label
- **Where:** `scripts/ui/ui_kit.gd:1486-1492`
- **Evidence:** the `draw` handler calls `add_theme_font_size_override` and `add_theme_font_override` on all 8 copies
  every time the label draws. Each call sends THEME_CHANGED to that copy, which re-shapes and redraws it, even when
  nothing changed. The only caller is `hud.gd:1163` (gold labels outside the group), so in practice this happens only
  on text or size changes.
- **Fix plan:** apply the overrides only when the font or size differs from what the copy already has.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-15 (low, duplication): the ticket-confirm open and close code is copied three times
- **Where:** `scripts/ui/upgrades_screen.gd:583-598` vs `602-616`; `hat_wheel.gd:1355-1368`; close paths in
  `upgrades_screen.gd:646-657` and `hat_wheel.gd:1371-1396`
- **Evidence:** each copy fills the label and price, shows the panel and blocker, calls `lock_focus` if not locked,
  and focuses BACK. The close paths unlock and refocus. `_buy_workshop` and `_buy_ability` differ only in names and
  price getters.
- **Fix plan:** have `UIKit.add_ticket_confirm` return a small object with `open(text, price)` / `close()` and the
  lock inside it.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-16 (low, duplication): repeated code inside skins_screen
- **Where:** `scripts/ui/skins_screen.gd:808-824` vs `874-884`; `534-536` vs `593-596`; `539-544` vs `585-588`
- **Evidence:**
  - The trails and papers status lines are the same code; the papers version has no earned branch.
  - `_fill_skin_grid` writes out `_clear_grid` again inline.
  - The list of skin ids (PRESETS plus CUSTOM, RAINBOW, STOPWATCH) is built twice.
- **Fix plan:** one `_cosmetic_status(id, worn)`, use `_clear_grid`, and one `_skin_ids()`.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-17 (low, hygiene): PLAY rewires BACK by disconnecting "the last connection"
- **Where:** `scripts/ui/upgrades_screen.gd:195`
- **Evidence:** `back.pressed.disconnect(back.pressed.get_connections()[-1].callable)` relies on `make_button`
  connecting the sound lambda first and the handler last. A future connection in TouchButton or make_button would
  silently remove the wrong one. `UIKit.add_back_button(root, on_press)` already accepts a handler.
- **Fix plan:** `back = UIKit.add_back_button(self, _leave if Progress.return_to_game else Callable())`, then set the
  PLAY text.
- **Behavior risk:** none.
- **Confidence:** high.

### D1-18 (low, magic-number): the workshop rows ignore the per-locale metrics
- **Where:** `scripts/ui/upgrades_screen.gd:531-552` (`UIKit.BUTTON_H` at 540; fixed `TICKET_ROW_TOP/HEIGHT`,
  `y + 1`, `y + 11`, `y + 2`)
- **Evidence:** docs/ui-rules.md calls "a 13 px literal or `UIKit.BUTTON_H` used as a pitch" a bug in a taller locale.
  The COINS and ABILITIES rows were moved to `_plan_*`; the workshop rows were not. This matters only with the
  workshop test hook (`Economy.workshop_on()`), so it is latent.
- **Fix plan:** plan these rows like `_plan_coins`, or document the workshop as English-only while it is a test hook.
- **Behavior risk:** none in English.
- **Confidence:** high.

### Perf-doc items checked and found fixed (not reported)
- cpu.md #1 fixes 1-4: GooBox layout cache and run merging, batched theme edits, one shared recolor per frame, one
  emit per theme.
- rendering.md #3 (theme propagations) and #4 (per-pixel rects).
- cpu.md #6 (backdrop maze and tile set cache).
- rendering.md #11 (backdrop clip_contents).
- cpu.md #7 hero/torch part (once per step in `_emit`).

Still open: cpu.md #7 remainder (D1-07), #10 controls (D1-11), and the rainbow residual (D1-05).
