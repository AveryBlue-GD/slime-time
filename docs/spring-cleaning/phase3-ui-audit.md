# Phase 3: UI audit (ui-polisher, audit half)

Date: 2026-10-15, branch `spring-cleaning`. Read-only audit: no game or test file was changed. The fixes are proposals
for the fix half. The rules derived from the current screens are in the draft [../ui-rules.md](../ui-rules.md).

## How this was measured

- Every screen was rendered by the real game (Godot 4.7.2, windowed, `--fixed-fps 60`) from a scratch copy of the project
  (`/private/tmp/claude-501/ui_proj`, which is not committed). A small driver scene loads the screen, opens the sub-state by
  calling the screen's own functions (`open_view(3)`, `pause_menu.open()`, `_on_goal_body_entered(slime)`, ...), and then saves
  three 320x180 frames from the root viewport:
  1. `pretty`: what the player sees.
  2. `flat`: the same frame with the drifting menu backdrop and the 2D world hidden, so UI pixels can be measured.
  3. `notext`: `flat` with every Label, Button and LineEdit text made transparent (only colors change, no layout change).
  The text ink is `flat` minus `notext`: exactly the letter pixels, with no guessing from color thresholds. The letter
  body is the 7-row window (14 rows at 16 px) holding the most ink, so the 2 px drips (4 px at 16 px) are not counted as
  letters. All rects come from `get_global_transform_with_canvas()`. Pixel probes (ASCII maps of exact colors) were used to
  confirm every finding below.
- Throwaway saves only (test-run state, `--story-complete`, `--unlock-all` and other debug flags). The real save was never
  read or written, and no Godot process that this audit did not start was touched.
- Coordinates are base pixels (320x180). `L/R/T/B` = margins, `x..y` = inclusive ink span, "body" = letter rows without drips.
- Severity: **High** = visibly wrong in normal play (overlap, overflow, obvious off-centre of 3 px or more, large empty
  areas). **Med** = noticeable near-miss (1-2 px mismatch on prominent or mirrored elements, the same component in different
  sizes). **Low** = subtle (0.5-1 px), systemic, dev-only or a rare edge case.

Screenshots (2x) of every audited state are in [ui-before/](ui-before/). Zoomed crops of the main issues are in
[ui-before/zoom/](ui-before/zoom/). The aspect-ratio composite is `ui-before/aspect_ratios_touch.png`.

## Summary

| Severity | Count |
|---|---|
| High | 7 |
| Med | 24 |
| Low | 32 |
| **Total** | **63** |

These are the IDs in the tables below, plus AR1-AR3. Rows marked "ok" are checks that passed. Rows that point to another
ID are not counted twice.

The worst problems (the 7 High items, then the most widespread Med items):
1. **HUD timer pod** (always on screen): the content sits 6 px left of the pod's centre (L4 / R15).
2. **Level-select grid** is 4 px left of centre (L30 / R38) above a symmetric panel.
3. **Hub quit confirm**: "THE GAME CLOSES" is 6 px right of centre (its label box is 172 px wide instead of 160).
4. **Pause SEED button**: with a 10-digit seed it is 6 px wider than the column and runs into the panel's goo frame.
5. **Restart prompt**: 20 px of empty panel below the last button, against 1 px above the first.
6. **Story line under the HUD pods**: it touches or overlaps the second-row pods (0 px gap). Long lines (L2, L7, L8) and
   the HEAT pod make it worse.
7. **Descent card and summary**: the titles and the pot text are drawn over the dimmed HUD pods. The summary panel is
   mostly empty.
8. **Inconsistent chrome**: BACK has 3 positions or sizes. Buttons are 13 or 15 px tall. HUD pods are 13, 14 or 15 px tall,
   which also puts the mirrored second-row pods 1 px apart.
9. **Selected tabs use the hover style**, so a hovered tab looks selected.

## Per-screen issues

### Title (fresh save "PLAY", returning "ENTER THE HUB") — `title_fresh.png`, `title_return.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| T1 | STORY button | at (4,163) 40x13. Every other bottom-left button is at (4,164) (B=3). It sits 1 px higher | `story_button.position.y = 164` (use the shared bottom-row constant) | Low |
| T2 | Logo | texture 291 px wide at x=15. Ink 17..301 (L17 / R18), 0.5 px off because the width is odd | trim or pad the logo PNG to an even width, or accept | Low |
| — | PLAY / ENTER button, tagline, slimes | button 176x25 centred, text dx +0.0. Tagline lines centred. Slimes 36..74 and 245..283 (exactly mirrored) | — | ok |

### First-launch story intro / finale (UI parts only) — `story_intro0.png`, `story_intro2.png`, `story_finale.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| Y1 | Shot pips | the pips are 4x3 at rows 160..162. The current pip is 4x4 (rows 160..163), so it grows only downward and is not centred on the row | make the current pip 4x5 (rows 159..163) or 4x3 in a brighter colour | Low |
| — | Pip row and skip mark | 5 pips span 146..173 (centre 159.5, exact). The finale's 2 pips span 155..164 (exact). The ">>\|" mark spans 302..312 (R7) and its rows 159..163 are centred on the pip row | — | ok |

### Hub: pods, prompts — `hub_fresh.png`, `hub_story.png`, `hub_wheel.png`, `hub_random_locked.png`, `hub_deny.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| U1 | Station prompt pod | on every prompt the ink starts 9 px from the pod's left edge and ends 8 px from its right edge (STORY - LEVEL 1: pod 112..207, ink 121..199). The cause is the font's 1 px letter gap on the left of each label | one rule for HBox pods: drop the left content margin by 1 (or right +1) so the ink pads are equal | Low |
| U1b | Odd-width prompts | "RANDOMIZER LOCKED" pod is 115 wide (L103 / R102). "...BEAT ALL 10 LEVELS" is 179 wide (L71 / R70) | round the pod width up to even | Low |
| — | Ticket/medal pod | (3,3) 69x14. The icon (ink 6 rows) next to the 7-row text is 0.5 px off, which can't be avoided | — | ok |

### Hub: coin board — `hub_coinboard.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| U5 | Row pitch | rows step 11 px (7 + 4). Every other multi-line text uses 12 (7 + `LINE_SPACING` 5) | `21 + i * 12` won't fit 10 rows plus the totals in 164 px, so keep 11 and record it as the dense-list exception in the rules, or shrink the header | Low |
| U5b | Horizontal balance | content ink 67..255 inside panel 52..267: left inset 15 ("10"; 19 for 1-9), right inset 12. The block sits 1.5 px right of the panel centre | move the number column right 2 px or the coin column left 2 px | Low |

### Hub: randomizer portal menu — `hub_portal.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| U4 | Vertical rhythm | panel 34..145. Gaps: title body to RANDOM MAZE 9, between buttons 5, DESCENT to PAID RUNS 5, PAID RUNS to BACK 11. Top inset 10, bottom inset 13 | equal gaps (e.g. 6 / 4 / 4 / 6) and equal top and bottom insets | Low |
| U3 | Button height | RANDOM MAZE, DESCENT and BACK are 15 px tall. The standard button is 13 px | use 13 | Med |

### Hub: trapdoor quit confirm — `hub_quitmenu.png`, `zoom/hub_quit_note_offcenter_4x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| U2 | "THE GAME CLOSES" | label rect (80,78) is **172** px wide; the code sets 160. Its ink 124..208 is centred on x=166, **6 px right** of the panel centre. The title above is centred (121..199) | set the size after `add_child` (probable cause: the size is set before the label is in the themed tree, so its minimum width comes from the default font) or anchor it to the panel | **High** |
| U3 | QUIT / BACK | 56x15 (15 tall) | 13 tall | (counted in U3) |

### Hub: prize wheel WHEEL / SHOP / TAILOR + confirm — `hub_hatwheel.png`, `hub_hatshop*.png`, `hub_hatconfirm.png`, `zoom/hatshop_header_grid_3x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| U6 | Header row baselines | the title "HAT WHEEL"/"SHOP" body and the balance "60" are at y=12. The WHEEL/SHOP tab text is at y=13 (tabs at y10 h13). This is a 1 px baseline step across one row | move the tabs to y=9, or the title and balance to y=13 | Med |
| U6b | Header insets | WHEEL tab is 8 px from the panel's left edge (16-8). The balance icon is 10 px from its right edge (311-301) | match at 8 | Low |
| U7 | Shop grid | columns 22..159 and 162..299 in panel 8..311: left inset 14, right inset 12. The grid sits 1 px right of the panel centre | `GRID_LEFT = [21, 161]` | Med |
| U8 | Tab "selected" state | the selected tab gets the hover stylebox (face #483e5e, bright goo). A hovered unselected tab looks exactly the same, so you can't tell which tab is selected while hovering (WHEEL/SHOP, HATS/TRAILS/PAPERS, COINS/TICKETS) | a separate "selected" style (e.g. pressed face + title-colour underline) | Med |
| — | Confirm panel | (86,60) 148x58: L86 / R86. BUY and BACK are 48x13 with insets 20/20 and a gap of 12. The text is centred | — | ok |
| — | Section tabs, rows | HATS/TRAILS/PAPERS are 52x13, gap 4, span 78..241 (centred). Row text has 3/3 vertical insets. Price and icon line up | — | ok |

### Level select incl. HARD, HEAT panel, flame badges — `lvl_normal.png`, `lvl_fresh.png`, `lvl_hard.png`, `lvl_heat_on.png`, `zoom/levelselect_tile_drips_6x.png`, `zoom/heat_title_group_4x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| L1 | Level grid | `GRID_POS` (30,22). The grid is 252 wide and spans 30..281, so **L30 / R38**: 4 px left of centre. The info panel below is (14,111) 292x48 (L14 / R14), so the grid sits inset 16 on the left and 24 on the right | `GRID_POS.x = 34` | **High** |
| L2 | Big number drips into the record time | the number body is rows 36..49 and its 16 px drips reach row 52. The time body starts at row 53, a 0 px gap, so a drip runs straight into "0:13.8" | `STATUS_Y` 31 → 33 (the time's drips end at 63 = tile bottom 63, so trim the tile to 44 or move the number up 1) | Med |
| L3 | Glyphs "4", "6" (16 px) | ink L19 / R21 in the 48-px tile, 1 px left. Other digits are exact | fix the glyph ink in `make_font.py` (big font) | Low |
| L4 | HEAT panel title | "HEAT 6/10" text (136..184) is centred on its own and the flame (124..130) hangs to its left. The flame + text group is centred at 154, **6 px left** | centre the icon + text group (HBox in a CenterContainer) | Med |
| L5 | HEAT toggles | the RACE icon is 16x16, the other five are 18x18, so it sits 1 px off inside its toggle | draw RACE at 18x18 or centre each icon in an 18x18 cell | Low |
| L6 | HEAT panel padding | panel 20..161. The title starts 7 px below the top. DONE ends 13 px above the bottom | DONE y 136 → 133, or panel height -6 | Low |
| L7 | Grid to info panel | gap 2 px (108 → 111). Elsewhere a section gap is ≥ 4 | GRID_POS.y 22 → 21 and panel y 111 → 112 (fits) | Low |
| — | Tiles | number centred (dx 0). Flame badge at (+5,+5) and medal pips at (+40,+5), mirrored 5 px insets. Time centred (dx +0.5). HARD checkbox L25 / R25. HEAT 0 button R4. HEAT toggles 84x34, gap 4, insets 8/8, content 7/7 vertical | — | ok |

### Map table (select, view, papers) — `maps_sel.png`, `maps_sel_empty.png`, `maps_view.png`, `maps_view_paper.png`, `zoom/maps_bottom_bar_3x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| M1 | Bottom-bar baselines | BACK and hint body at 167..173. HARD checkbox text at 168..174 (1 px low). Checkbox rect (270,164) 44x16 goes to y=180 (B=0). The ink right margin is 6 against the 4 px edge rule | CheckBox y 164 → 163 (or h 13) and x so the ink ends at 315 | Med |
| M2 | Hint "PLAY TO FILL THEM IN" | label rect 48..263 (not centred). Ink 103..209 is **3.5 px left** of the screen centre. Its rect bottom is 181 (1 px off screen). The map view's line is centred correctly (rect 48..271) | same rect as the view: (48,167) 224x10 | Med |
| M3 | Grid margins / line pitch | tile grid L3 / R3 (edge rule is 4). Tile text pitch is 11 (name 24, % at 35) against 12 | x 4 with tiles 155 wide, or accept 3 as the dense-grid exception. Pitch 12 if the 26 px tile allows it (24 → 23) | Low |
| M4 | View title size | the map view's title is 8 px (gold). Every other screen title is 16 px | intentional (map space). Record it in the rules | Low |

### Upgrades: COINS / TICKETS tabs + confirm — `upg_coins.png`, `upg_coins_fresh.png`, `upg_abil.png`, `upg_abil_confirm.png`, `zoom/upgrades_coin_pod_4x.png`, `zoom/upgrades_row_gaps_4x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| G1 | Balance pod (top right) | pod 269..315. Icon 273..280 and "147" 285..299, so the inside padding is **4 on the left, 16 on the right** (the label reserves 28 px for 15 px of digits). The content sits 6 px left of centre | size the label to its text (pod shrinks or grows from the right edge), or centre the text in a fixed width | Med |
| G2 | Row control gaps | bar to "-" 3 px, "-" to "+" 2 px, "+" to cost 4 px. With the 1 px focus ring only 1 px of gap remains | one gap (4) everywhere in the row | Low |
| G4 | Header row | tabs are 13 tall (4..16), the pod is 14 (4..17), so their bottoms differ by 1 | pod 13 or tabs 14, per the pod-height rule | Low |
| — | Rows, - / + glyphs | COINS rows (10,y) 300x23, step 26, text insets 3/3. The "-" row 37 and the "+" rows 35..39 are centred on the cost body 34..40. Disabled "-" is dim. The ticket confirm is the shared one (ok) | — | ok |

### Wardrobe: skins / hats / trails / custom / solid — `skins_*.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| S1 | Second tile row (6 tiles) | 32..286: L32 / R33. The odd remainder puts it 0.5 px off | accept, or 2 px gaps on that row | Low |
| — | Everything else | 7-col grid 11..308 (L11 / R11), status lines centred, showcase panel L50 / R50, bottom row BACK (4,164) / JELLY centred / HATS R4. Custom wheel and preview are centred as a group | — | ok |

### Settings + save code + reset confirm — `settings.png`, `settings_code.png`, `settings_reset.png`, `zoom/savecode_box_label_3x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| C1 | SAVE CODE panel | the code box (LineEdit) is **22 px tall** (58..79) while COPY beside it is 13 (58..70) and the paste box is 13. The line "TO LOAD A SAVE..." starts at row 80, **0 px** under the box | box height 13 (one row, scrolls) or 22 with COPY centred on it. Line at ≥ 83 | Med |
| C2 | BACK / RESET PROGRESS | BACK is a 120x13 column button at (36,154). Every other screen has BACK 40x13 at (4,164) | keep the 2-column layout but use the standard BACK at (4,164). RESET can stay in the right column | Med |
| — | Columns | 36..155 and 164..283 (L36 / R36, gap 8), row pitch 20, all button text dx +0.5. Reset confirm panel (24,48) 272x82 L24 / R24, CONFIRM/CANCEL 70x13 gap 12 centred | — | ok |

### Controls (key remapping) — `keys.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| K1 | BACK / RESET KEYS | at y=**160** (B=7). Every other screen's bottom row is at y=164 (B=3) | y 164 (the hint at 140 still has 13 px of room) | Med |
| — | Grids | left 4..155, right 164..315 (L4 / R4), row pitch 17, key text centred | — | ok |

### Randomizer portal / Descent: boon card, cash out, summary — `g_descent.png`, `g_descent_card.png`, `g_descent_summary.png`, `zoom/descent_card_title_over_hud_3x.png`, `zoom/descent_summary_empty_panel_2x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| R1 | Card/summary over the HUD | the "FLOOR 1 CLEARED" title (label y4, body 4..17) and "RUN OVER" (y8, body 8..21) sit on top of the HUD top row (pods at 3..16), which still shows under the 0.82 dim. The card's "POT 1 (+1)" (262,28) lies over the dimmed pot pod (234..316, 18..40), so two pot texts overlap | hide the HUD's pods while the card or summary is open (or an opaque sheet), or start the card content at y ≥ 20 | **High** |
| R2 | Summary panel | panel (40,28) 240x116. The text lines use 38..78 and the panel face below is empty for **58 px** (79..136) | fit the panel to its content (~60 px) and centre it vertically above the buttons | Med |
| R3 | Boon tiles | 96x78. Icon at +7 from the top. The last line ends 19 px above the tile bottom, so the content is top-heavy by 12 px | move the content down 6 | Low |
| R4 | Button sizes | card CASH OUT / DESCEND are 96x15. Summary NEW RUN / HUB are 84x15 with gap 12. The in-level result row is 84x13 with gap 8 at y153 | 84x13, gap 8, y153 (the same row as the result screens) | Med |
| R5 | Side margins | card tiles and buttons sit at L10 / R10. The menu edge rule is 4 (and the tiles fit at 4 with gap 6 → 102 wide) | 4, or record 10 as the card margin | Low |

### Trapdoor quit confirm — see Hub (U2, U3).

### In-level HUD (meter, timer/hourglass, level pod, coins, ticket pod ATTEMPT/TIX, ability strip, heat pod, dev badge) — `g_l3.png`, `g_random_abil.png`, `g_hard_heat.png`, `g_descent.png`, `g_dev.png`, `g_l8*.png`, `g_l7_hard_heat.png`, `zoom/hud_*`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| H1 | Timer / hourglass pod | pod 132..187 (screen-centred). Icon 136..143 and "0:01.8" ink 148..172 (label box 37 px for 25 px of ink). The inside padding is **4 left, 15 right**, so the content sits 6 px left of the pod centre (the same with the HEAT hourglass "1:00.7") | centre the text in a fixed-width label (`HORIZONTAL_ALIGNMENT_CENTER`) and size the pod to icon + gap + widest time, or size it to content | **High** |
| H2 | Pod heights (top row) | meter pod 3..16 (14), timer 3..16 (14), level pod 3..15 (**13**): the bottom edges differ by 1 px across the top row | one pod height, 14 (`custom_minimum_size.y = 14` on all HUD pods) | Med |
| H3 | Mirrored second-row pods | coins pod at y=19 (text body 22..28). Coins-left pod at y=**18** (body 21..27). This follows from H2 (VBox gap 2 after a 13- or 14-px pod) | fixed by H2 | Med |
| H4 | HEAT pod | 94x15 (**15** tall) because the modifier icons are 9x9 (UI icons are 8x8). Its flame is 7x9 | 8x8 icons in the pod (or 14 tall with the icons overlapping the frame by 0) | Med |
| H5 | Story line vs pods | the line's body is at rows 31..37. The coin pod ends at row 32 (x ≤ 37) and the coins-left pod at row 31 (x ≥ 246). So L8 "A CELL FOR THE FORGOTTEN..." (ink 28..292) touches the coin pod's corner and overlaps the coins-left pod's bottom row. With the HEAT pod (rows 18..32, x 208..316) L7's line runs **0 px** under it for 76 px | move the story line to y ≥ 35 (pods end at 32 + 2 px clearance), or cap its width at 200 px (wrap to two lines) | **High** |
| H6 | DEV badge (dev mode only) | badge (3,35) 112x13 overlaps the story line (rows 31..37). "A CELL FOR..." crosses the badge's top border | put the badge under the area texts (y ≥ 48) or at the bottom left | Low |
| H7 | Area/story text under modals | pausing during the first ~2.8 s freezes the fade, so "PAUSED"/"RESTART?" (label y30, body 30..43) is drawn over "SOMEONE SWEPT..." (31..37). In randomizer mazes the area name (44..50) sits right under "PAUSED" | hide `area_label` / `story_label` while the pause menu or restart prompt is open | Med |
| H8 | Win panel vs story line | a 5-line result (HEAT win) puts the message panel top at ~33, over the story line if you win within ~2.8 s | same fix as H7 (hide the area texts on finish) | Low |
| — | Ability strip, attempt pod, meter | ability pod (3,35) 42x14 under the coins pod. The attempt pod (218,18) 99x23 has its icon centred on the two lines. The meter bar, segment ticks and "100%" line up (rows 6..12) | — | ok |

### Pause menu (incl. DEV panel), restart prompt — `g_pause*.png`, `g_restart.png`, `g_pause_seed10.png`, `zoom/restart_prompt_empty_bottom_3x.png`, `zoom/pause_seed_button_overflow_4x.png`, `zoom/pause_title_over_areaname_3x.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| P4 | SEED button (randomizer) | with a 10-digit seed (common: 1647250167 was seen in a normal run) "SEED 4294967295-7" makes the button **106 px** wide (110..215) while the column is 100 px. It runs 6 px into the panel's right goo band. Even a 9-digit seed leaves text margins of 5/4 | fix the button at 100 and shorten the text ("4294967295-7" with a seed icon, or the "SEED" word on hover), or widen the panel to 132 | **High** |
| P1 | Restart prompt | panel (100,52) 120x76. Buttons fill 60..104. The panel face is empty for **20 px** under CANCEL (105..124) and 1 px above RESTART | panel height 76 → 58 (match the pause panel: buttons flush, then the band) | **High** |
| P2 | Panel padding | pause and restart buttons sit right against the goo band (0 px top and bottom). Other panels use the 6/5 content margin | give the button stacks the panel content margins (6 top / 5 bottom) | Low |
| P3 | DEV panel | (226,55) 88x50, R=6 (edge rule 4) | x 228 | Low |
| — | Pause stack | buttons 100x13, pitch 16, all text dx +0.5. The panel is centred (L100 / R100) | — | ok |

### Dry-up / win / result screens (story, randomizer, hard/HEAT, assisted, L10) — `g_dry*.png`, `g_win_*.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| — | Choice row | every variant: 84x13, gap 8, y153, centred (2 buttons L72 / R72, 3 buttons L26 / R26). Messages centred | — | ok |
| — | Record banner | "NEW RECORD!" ink 101..218 (centred), chalices mirrored | — | ok |

### Tutorial glyphs / beacon — `g_l1_fresh.png`, `g_l1_tut2.png`
No layout issues found. The key glyphs are centred over the slime and the beacon arrow sits at the wall edge. They are world-space sprites (snapped).

### Rotate cover — `rotate.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| O1 | Cover in portrait | the cover is the 320x180 viewport, so on 1080x2340 it is a 960x540 band (3x) in the middle of the screen with 900 px of black above and below. The 8 px text is 24 px physical | acceptable (no new features). Record it in the rules | Low |

### Touch controls (`--touch`) — `g_touch.png`, `g_touch_abil.png`, `hub_touch.png`

| # | Element | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| TC1 | Mirrored thumbs | joystick home (40,140) r20: left margin 20, bottom 20. JUMP (282,142) r19: right margin 18, bottom 19. The centres are 2 px apart vertically | `JUMP_CENTER = (280,140)` (or the joystick to 142) | Low |
| — | Pause bars, labels | the bars are inset 4/4 and 3/3 in the 15x13 button (symmetric). The JUMP label is centred | — | ok |

### Transitions
The goo wipe (`transition.gd`) is a full-screen shader sheet that hides itself at the end. The only UI tweens are on
modulate/alpha (coin pop, attempt flash, area-name fade, tree notice) and the coin fly-in (world space, freed at the end).
No positional UI tween can end off-position. **No issues.**

### Systemic / cross-screen

| # | Issue | Measured | Proposed fix | Sev |
|---|---|---|---|---|
| X1 | BACK placement | (4,164) 40x13 on 6 screens. (4,160) on Controls. A (36,154) 120x13 column button on Settings. 56x15 in the hub menus | one constant `UIKit.BOTTOM_ROW_Y = 164`, `UIKit.EDGE = 4`, `add_back_button` everywhere | Med |
| X2 | Button heights | 13 px for 56 distinct buttons, 15 px for 8 (hub quit/portal, Descent card/summary), 25 px for the title CTA | 13 everywhere except the title CTA | Med |
| X3 | Edge margins | menus 4 (BACK, tabs, HEAT, PAPER), HUD 3, map grid 3, Descent card 10, DEV panel 6 | 4 for menus, 3 for HUD pods (both recorded as rules) | Med |
| X4 | Pod heights | 13 (text-only), 14 (with an 8 px icon), 15 (HEAT), 23 (two lines) | 14 for one line, 23 for two | (H2/H4) |
| X5 | Odd sizes under centring | 0.5 px offsets wherever a centred box has an odd width (logo 291, prompts 115/179, skins row 2) | even widths for centred boxes | Low |
| X6 | Label sizing before `add_child` | the probable cause of U2. Any label sized before it joins the themed tree can grow to the default font's width | always add first, then size (lint rule) | Med |

## Aspect ratios, letterboxing, safe areas

Stretch mode `viewport` + `integer`: the game always renders 320x180 and blits it at the largest integer scale. The scale
was confirmed in-engine from `Window.get_final_transform()` at each size (sizes taller than this Mac's screen were clamped
by the OS and computed the same way).
Nothing is ever cut off and UI positions never change. The only cost is the unused area.

| Resolution | Scale | Content | Bars L/R | Bars T/B | Screen used |
|---|---|---|---|---|---|
| 1280x720 (16:9) | 4x | 1280x720 | 0 | 0 | 100% |
| 1920x1080 (16:9) | 6x | 1920x1080 | 0 | 0 | 100% |
| 1366x768 | 4x | 1280x720 | 43 | 24 | 88% |
| 1280x800 (16:10, Steam Deck) | 4x | 1280x720 | 0 | 40 | 90% |
| 2560x1080 (21:9) | 6x | 1920x1080 | 320 | 0 | 75% |
| 1024x768 (4:3) | 3x | 960x540 | 32 | 114 | 66% |
| 2340x1080 (Android 19.5:9) | 6x | 1920x1080 | 210 | 0 | 82% |
| 2532x1170 (iPhone 14, full) | 6x | 1920x1080 | 306 | 45 | 70% |
| 2048x1536 (iPad) | 6x | 1920x1080 | 64 | 228 | 66% |
| 2732x2048 (iPad Pro 12.9) | 8x | 2560x1440 | 86 | 304 | 66% |
| 1080x2340 (portrait) | 3x | 960x540 | 60 | 900 | 21% (rotate cover on touch) |

Findings:
- **AR1 (Low)**: 4:3 and tablets use only 66% of the screen. This is an integer-scaling design choice, not a bug. No change
  is proposed (a non-integer or "expand" mode would be a feature). Recorded in the rules.
- **AR2 (Low, safe area)**: the web shell sets `viewport-fit=cover` and the game has no safe-area code. On iPhone landscape
  the pillarbox (306 px) is wider than the notch inset (141 px), so nothing sits under the notch. The bottom bar is only
  45 px against the 63 px home-indicator zone, so game rows 177..179 fall under the indicator. The bottom-row buttons end
  at y=176 (just clear) but their goo drips (177..178) are inside it. With Safari's toolbar showing, the scale drops to 5x
  and the bars grow (60 px), which is clear.
- **AR3 (Low, safe area)**: on a phone that is exactly 16:9 (1920x1080 panel, no pillarbox) the HUD pods sit at 18 px
  physical from the edges. A rounded corner of radius ≥ ~25 px clips the meter pod's and level pod's outer corners, and the
  bottom-left BACK (4,164) likewise. Android 19.5:9 / 20:9 phones get 210-240 px pillars and are clear (punch-hole
  cameras sit within ~110 px).
- **AR4 (ok)**: touches in the black pillars still reach the controls (x < 0 counts as the joystick's half, x > 320 as
  JUMP's), so the bars are usable thumb space. Good.

Composite: `ui-before/aspect_ratios_touch.png`. Row by row (left, right): 1280x720, 1920x1080, 1280x800, 2560x1080, 1024x768,
2340x1080 (red = corner/camera zones), 2532x1170 iPhone (red = notch inset, corners, home indicator), 2048x1536, 2732x2048,
1080x2340 portrait (raw scaling; on a touchscreen the rotate cover shows).

## Touch targets

The effective physical size of 1 game px is (integer scale) / (device pixel ratio) points:
- 2340x1080 Android (DPR 2.625, 6x): **2.29 dp** per game px.
- iPhone 14 landscape, full screen (DPR 3, 6x): **2.0 pt**. With Safari bars (5x): **1.67 pt**.
- iPhone SE (DPR 2, 4x): **2.0 pt**.
- iPad (DPR 2, 6x): **3.0 pt**. iPad Pro (8x): **4.0 pt**.

Threshold: 44 pt / 48 dp, i.e. 19-26 game px depending on the device.

| # | Target | Size (game px) | Physical (worst..best phone) | Verdict | Sev |
|---|---|---|---|---|---|
| TT1 | Standard menu button height | 13 | 22 pt .. 30 dp | too short on every phone (width is fine) | Med |
| TT2 | Upgrade "-" / "+" | 16x13, 2 px apart | 27x22 pt .. 37x30 dp, gap 3-5 pt | too small and too close (mis-taps) | Med |
| TT3 | Tabs (COINS/TICKETS, WHEEL/SHOP, HATS/TRAILS/PAPERS) | 40-52 x 13 | height 22-30 | short | (TT1) |
| TT4 | Shop rows | 138x13 | height 22-30 | short | (TT1) |
| TT5 | Checkboxes (HARD), volume slider | row 16 px, slider 10 px, grabber ~8 px | 17-23 pt (slider) | too small. Dragging is fine, tapping a value is hard | Low |
| TT6 | In-level pause | 15x13 drawn, 25x23 hit (+5 margin) | hit 42x38 pt (1.67) .. 57x53 dp | borderline with Safari bars, fine otherwise. The drawn button looks smaller than its hit area | Low |
| TT7 | Ability buttons | r11 drawn, r13 hit (26 px) | 43 .. 60 | ok (borderline at 5x) | ok |
| TT8 | JUMP, joystick | r19 (38 px), floating joystick on the left half | 63 .. 87 | ok | ok |
| TT9 | Level tiles 48x42, skin tiles 40x30, map tiles 156x26, heat toggles 84x34, boon tiles 96x78 | | ≥ 50 | ok | ok |

Proposed direction for the fix half (no new features): a 13 px button is the pixel-art norm on desktop. For touch, the
cheapest fix is a larger **hit area** than the drawn button (as already done for the pause button): grow every Button's
click rect by ~4 px vertically when `TouchControls`/touch is active, and keep ≥ 4 px between adjacent targets
(upgrade "-"/"+": gap 2 → 4).

## Not captured / limits

- The hub "UPGRADES REWORKED / COINS RETURNED" notice only shows after a v2 tree migration (`take_tree_refund_notice`). It
  was reviewed in code only (centred with `roundf`, y=24) and looks fine.
- Hover/pressed/focus/disabled states were rendered on SETTINGS and UPGRADES (`st_hover.png`, `st_hold.png`):
  - normal: face #332c40, dark goo #280109.
  - hover: face #483e5e and a brighter goo frame.
  - pressed: face #282234.
  - focus: a 1 px ring in the title colour, 1 px outside the button. Keyboard only: a mouse-click focus shows no ring
    (engine behaviour, fine).
  - disabled: dim face and `TEXT_OFF` text.
  The text never moves between states (as documented). The only state problem is U8.
- Real-device checks (notch, corners, DPR) are computed from published device metrics, not measured on devices.
