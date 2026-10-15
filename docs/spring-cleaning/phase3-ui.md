# Phase 3: UI polish (fix pass)

Date: 2026-10-16, branch `spring-cleaning` (commits "UI polish (phase 3): ..."). Follows the audit
[phase3-ui-audit.md](phase3-ui-audit.md); the rules are final in [../ui-rules.md](../ui-rules.md) and live as constants
and helpers in `scripts/ui/ui_kit.gd`.

**Result:** all 7 High and all 24 Medium issues fixed; of the 32 Low ones 17 are fixed and 5 are recorded as
documented rule exceptions (U5, M4, R5, O1, AR1); the other 10 are listed under remaining issues. Every fix was re-measured from
rendered pixels (table below). Two new suites, `test_ui_layout` and `test_ui_touch`, guard the rules. `./tools/test_all.sh`:
72 suites, 0 failed. Story gameplay frames are pixel-identical to the `spring-cleaning-phase1` tag (only run-to-run
particle noise differs). Headless boot of every scene is clean. No gameplay, economy, save or cutscene-art change.

## How it was measured

The audit's capture driver (`tests/ui_cap.gd` in a scratch copy of the project, not committed) renders each screen in
the real game (Godot 4.7.2, windowed, `--fixed-fps 60`, throwaway saves only). It saves the frame, the frame with the
world hidden, and the frame with all text transparent; text ink = the difference. The same 92 states were captured
before (audit) and after. Coordinates are base pixels (320x180). `L/R` = margins, `x..y` = inclusive spans,
"body" = the 7 letter rows without drips.

Screenshots: [ui-after/](ui-after/) has every screen of [ui-before/](ui-before/) under the same file name (2x).
[ui-after/zoom/](ui-after/zoom/) has before (top) / after (bottom) crops of the main fixes at 2-6x.
`ui-after/aspect_ratios_touch.png` is the aspect-ratio and safe-area composite with the new touch layout.

## Issues fixed (measured before -> after)

| ID | Sev | What was measured | Before | After |
|---|---|---|---|---|
| H1 | High | HUD timer pod (g_l3): ink pads, content offset | pod 132..187 (56 w), pads L4 / R15, content 5.5 px left of the pod centre | pod 136..183 (48 w, exactly on the screen centre), pads L4 / R4, offset 0. Tabular digits (`UIKit.tabular_font`) keep the width constant while the time runs |
| H2 | Med | top-row pod heights meter / timer / level | 14 / 14 / 13 | 14 / 14 / 14 (`UIKit.POD_H` on every one-line pod) |
| H3 | Med | mirrored second-row pods, y | 19 vs 18 | 19 vs 19 (text bodies both on row 22) |
| H4 | Med | HEAT pod (g_hard_heat) | 94x15 at y18 | 94x14 at y19 (9 px icons in `UIKit.fit_icon` cells) |
| H5 | High | story line vs pods, L8 | body rows 31..37, 2 rows over the coins-left pod | rows 35..41, 2 px clear of every pod |
| H5 | High | story line vs the HEAT pod, L7 hard + 6 modifiers | rows 31..37, 2 rows over the HEAT pod | the area name and the line move under the HEAT pod (line rows 50..56). Checked on all 10 levels, HEAT, assist, dev badge, randomizer (`test_ui_layout`) |
| H6 | Low | DEV badge vs story line (L8, dev) | the line crossed the badge by 5 rows | the line moves under it, 2 px clear |
| H7 | Med | area / story texts under PAUSED and RESTART? | both visible through the dim (frozen mid-fade) | hidden when the pause menu or restart prompt opens |
| H8 | Low | 5-line result panel vs story line | could overlap within ~2.8 s | area texts hidden on the result (rewards / choices) |
| P1 | High | restart prompt insets above / below the buttons | 8 / 23 (panel 76 tall) | 8 / 8 (panel 61) |
| P2 | Low | pause panel insets | 7 / 4 | 8 / 8 (panel height follows the stack: 93, +16 with SEED, -16 in Descent) |
| P3 | Low | pause DEV panel right margin | R6 | R4 |
| P4 | High | SEED button, 10-digit seed | "SEED 4294967295-7" 106 px wide (column 100), into the goo band | 100 px, text "4294967295-7" with 16 / 15 px pads; "SEED " is kept whenever it fits |
| L1 | High | level grid margins | L30 / R38 | L34 / R34 |
| L2 | Med | big number drips vs record time (tile 1) | drips over the time's top 2 rows | number rows 35..48, drips + shadow end on row 53, time from row 54: no overlap (0 clear rows, see remaining issues) |
| L4 | Med | HEAT panel title, flame + text group | 124..184, centre 5.5 px left of the panel | 130..190, +0.5 |
| L5 | Low | RACE icon in its toggle | 16x16 art at the 18x18 cell's corner (1 px off) | centred in the 18x18 cell |
| L6 | Low | HEAT panel insets title / DONE | 7 / 13 | 8 / 8 (panel 142 -> 138 tall) |
| L7 | Low | level grid to info panel | 2 px | 4 px |
| M1 | Med | map table HARD checkbox | text row 168 (BACK 167), ink R6, box to y180 | row 167, ink R4, box ends y179 |
| M2 | Med | map table hint | rect 48..263 (bottom 181), ink 3.5 px left of centre | rect 48..271 (bottom 177), +0.5 |
| M3 | Low | map tile grid margins | L3 / R3 | L4 / R4 (tiles 155 wide) |
| U1 | Low | hub prompt ink pads | L9 / R8 | L8 / R8 |
| U2 | High | quit confirm "THE GAME CLOSES" | label 172 wide (sized before it was themed), ink 6.5 px right of centre | label 160, +0.5 (`UIKit.add_label` adds first, sizes after) |
| U3 | Med | hub quit / portal button heights | 15 | 13 |
| U4 | Low | portal insets top / bottom | 10 / 13 (gaps 9 / 5 / 5 / 11) | 8 / 8 (gaps 4 / 3 / 3 / 4) |
| U5b | Low | coin board content insets | L15 / R12 | L14 / R14 |
| U6 | Med | hat wheel header text rows: tab / title / balance | 13 / 12 / 12 | 12 / 12 / 12 |
| U6b | Low | header insets: WHEEL tab / balance icon | 8 / 10 | 8 / 8 |
| U7 | Med | shop grid in its panel | L14 / R12 | L13 / R13 |
| U8 | Med | selected tab vs hovered tab, face colour | both `#483e5e` (indistinguishable) | selected `#282234` with the bright goo, hovered `#483e5e` (`UIKit.set_selected`; also skins / hats / trails tiles and worn shop items) |
| G1 | Med | upgrades balance pod pads | L4 / R16 | L4 / R4 (label sized to its text, pod grows leftward) |
| G2 | Low | upgrade row gaps bar / - / + / cost | 4 / 2 / 5 | 4 / 4 / 5 (+ and the cost moved 2 px right) |
| C1 | Med | save code box height, line under it | 22 px (COPY 13), next line 0 px under | 13 px, 10 px; each line one pitch (12) over its row |
| C2 | Med | settings BACK / RESET | BACK (36,154) 120x13, RESET (164,154) 120x13 | BACK (4,164) 40x13, RESET PROGRESS (224,164) 92x13 R4 |
| K1 | Med | controls page bottom row | y160 | y164 (RESET KEYS centred) |
| R1 | High | Descent card over the HUD | 5 dimmed HUD pods under the title and pot | HUD hidden while a card is up |
| R2 | Med | Descent summary panel | 28..143: text uses 38..77, 66 empty rows under it | 57..116, insets 8 / 9 (incl. drips); title + panel centred above the buttons |
| R3 | Low | boon tile content insets | icon +7, 19 rows empty at the bottom | +13 when no tile in the row has a HAVE line (else as before) |
| R4 | Med | Descent buttons | card 96x15 @152, summary 84x15 @152 | card 96x13 @153, summary 84x13 gap 8 @153 (the result row) |
| T1 | Low | title STORY button | (4,163) | (4,164) |
| Y1 | Low | story pips, current pip | rows 160..163 (grew downward only) | rows 159..163, centred on the row (UI overlay only, cutscene art untouched) |
| TC1 | Low | JUMP vs joystick centres | (281.5, 141.5) vs (39.5, 139.5) | (279.5, 139.5) vs (39.5, 139.5): mirrored |
| X1 | Med | BACK rect across 8 screens | 4 variants: (4,164), (36,154) 120 wide, (4,160), (4,163) | (4,164) 40x13 everywhere (`UIKit.add_back_button`, `place_bottom_row`) |
| X2 | Med | button heights | 13, and 15 on 8 buttons | 13 everywhere but the title CTA (25) |
| X3 | Med | edge margins | 3 / 4 / 6 / 10 mixed | menus 4 (`EDGE`), HUD 3 (`HUD_EDGE`), Descent card 10 (documented) |
| X6 | Med | labels sized before entering the themed tree | cause of U2, M2 (and the save code box, C1) | `UIKit.add_label` helper; the offending call sites fixed |
| TT1/TT2 | Med | touch hit areas | 13 px buttons, upgrade - / + 2 px apart | `TouchButton`: 23 px hit areas, shared by distance (below) |
| — | — | ability price vs + text (found in the after pass) | price text 1 row above the + button's text | same row |

Also: the hub ticket pod (with its HEAT flame) is 14 tall, `upgrades` balance pod is 14 tall (`POD_H`), the map view's
bottom row uses the constants, and `GooBox` has a `"selected"` state.

### Touch targets

`TouchButton` (`scripts/ui/touch_button.gd`) is what `UIKit.make_button` now creates. With a touchscreen or `--touch`,
`_has_point` accepts the drawn rect grown by `HIT_PAD` (5); a point in the grown margin belongs to the nearest touch
target and never to a button when it is inside another target's rect, so hit areas cannot overlap. Art is unchanged and
desktop (no touchscreen) is exactly as before. Measured by `test_ui_touch` (pixel-centre scan of the hit areas):

| Target | Drawn | Hit area (touch) | At 2.0 pt/px (iPhone) / 2.29 dp/px (Android) |
|---|---|---|---|
| upgrade - and + (4 px apart now) | 16x13 | 23x23 each, split at the gap | 46 pt / 53 dp |
| BACK, bottom-row buttons | 40x13 | 50x23 | 46 pt tall |
| result row (84x13, gap 8) | 84x13 | 93x23 | 46 pt tall |
| hub QUIT / BACK | 56x13 | 66x23 | 46 pt tall |
| pause stack (pitch 16) | 100x13 | 16-20 tall (the stack pitch) | 32-40 pt: below 44, see remaining issues |

No pixel of the screen is claimed twice on upgrades (both tabs and the BUY? confirm), level select, settings, controls,
skins, map table, title, hub quit and portal, pause menu and the result row; real clicks (GUI input pipeline) in a
grown margin press the nearest button.

## Every screen reviewed

| Screen (captures) | Changes | Status |
|---|---|---|
| Title, fresh and returning (`title_*`) | STORY on the bottom row | ok (logo 0.5 px, T2) |
| Story intro / finale (`story_*`) | current pip centred | ok |
| Hub: room, prompts, ticket pod (`hub_*`) | prompt pads 8 / 8, ticket pod 14 | ok |
| Hub: coin board | insets 14 / 14 | ok (pitch 11, dense list) |
| Hub: portal menu, quit confirm | 13 px buttons, PANEL_PAD rhythm, centred note | ok |
| Hub: hat wheel WHEEL / SHOP / confirm | header baseline and insets, grid centred, selected tabs | ok |
| Hub: tree notice (`hub_notice`) | none | ok |
| Level select normal / fresh / hard, HEAT panel | grid centred, number drips, info panel gap, HEAT title group, RACE icon, panel padding | ok |
| Map table select / view / papers | hint centred, HARD box on the bar, grid margins 4 | ok |
| Upgrades COINS / TICKETS / confirm | balance pod, - / + gap, selected tabs, ability price row | ok (G4 header pod 14 vs tabs 13: text rows match, accepted) |
| Wardrobe skins / hats / trails / custom / solid | selected tile style | ok (S1 0.5 px) |
| Settings, save code, reset confirm | standard BACK, RESET bottom right, 13 px code box, line rhythm | ok |
| Controls (key remapping) | bottom row at 164 | ok |
| Victory | none needed | ok |
| In-level HUD (story, randomizer, HEAT, Descent, dev, touch) | timer pod, pod heights, HEAT pod, area / story placement | ok |
| Pause (story, randomizer, Descent, dev, 10-digit seed), restart prompt | padding, SEED fit, DEV panel edge, area texts hidden | ok |
| Dry-up / win / result variants | area texts hidden with the result; choice row constants | ok |
| Descent boon card and summary | HUD hidden, 13 px buttons on the result row, summary fitted, tile content | ok (R5 margins 10, documented) |
| Rotate cover | none | ok (O1) |
| Touch controls | JUMP mirrored with the joystick; TouchButton hit areas | ok |

## Aspect ratios and safe areas

Captured at 1280x720 (4x), 1280x800 (4x, 40 px bars), 2560x1080 (6x, 320 px pillars), 1024x768 (3x), 2340x1080 (6x),
2048x1536 (6x) and portrait 1080x2340 (3x; the OS clamped the window to 1080x1606): on every size the window's final
transform is a whole-number scale and the layout of the HUD, level select, portal, settings and upgrades is identical to
1280x720 (same control rects, none off screen). Nothing is clipped: everything stays inside 320x180
(`test_ui_layout` checks the extents of every screen it opens).

For Phase 5 (platform):
- **AR2 / home indicator (iPhone landscape):** the bottom row's art ends at y176 (its goo drops at 177-178 fall in the
  63 px home-indicator zone, the bar there is 45 px), and the new touch hit areas of bottom-row buttons reach y181, i.e.
  into the letterbox / indicator zone. Taps there land on BACK / the page button, which may compete with the system
  swipe. Consider honouring the safe area (shift the 320x180 view up by the inset) on iOS.
- **AR3 / exactly-16:9 phones:** no bars; rounded corners can clip the HUD pods' outer corners (3 px from the edges).
- Safari with its toolbars (5x, 1.67 pt per px): the 23 px hit areas are 38 pt, under 44.

## Gameplay frames vs the phase1 tag

The tag `spring-cleaning-phase1` was extracted to a scratch project and the same states captured with the HUD layer
hidden: story levels 1, 3, 8 and hard L7 with four HEAT modifiers are identical to the current build except 1-2 pixels,
the same run-to-run particle noise two captures of the current build show between themselves. (Randomizer mazes use a
fresh seed every run, so they are not comparable frame to frame.) With the HUD shown, the differences are confined to
what was moved on purpose: the top HUD rows y 3..56 (timer pod 132..187 -> 136..183, the level pod and second-row pods
1 px, the HEAT pod, the area name / story line) and the touch JUMP button (2 px up-left).

## Tests added

- `tests/test_ui_layout.gd`: on title, level select (normal, hard, HEAT panel), map table (select, view), upgrades (both
  tabs), skins, settings (+ SAVE CODE panel), controls, hub (quit, portal, coin board, hat wheel both tabs), the HUD on
  all 10 levels plus HEAT, assist, dev badge and randomizer, pause (story, randomizer with a 10-digit seed, Descent),
  restart prompt, Descent card and summary: every visible control inside 320x180; no two interactive controls
  overlapping; 8 px text buttons 13 tall; bottom-row BACK at (4,164) 40x13; centred labels on their screen's or panel's
  centre line; pods 14 / 23 tall on the 16 px row grid; timer pod centred with 4 / 4 pads; area and story lines 2 px clear
  of every pod; level grid centred; HEAT title group centred; PANEL_PAD insets (quit, portal, pause, restart, HEAT,
  Descent summary); SEED fits; hat wheel header baseline and insets; shop grid centred; upgrade - / + 4 apart; balance
  pod sized to its text; save code boxes 13 tall; Descent buttons on the result row; selected-tab style. 2100+ checks.
- `tests/test_ui_touch.gd`: hit areas as in the table above, exclusivity scans, real clicks in the margins, and the
  desktop (no touch) case.
- `tests/test_level_tiles.gd`: the time-under-number gap now expects the 16 px font's 4 drip rows (5-6 px), and the
  HEAT title rects come from the panel itself.

## Remaining issues (need a design decision, or out of scope)

| ID | Issue | Why not changed |
|---|---|---|
| L2 | Level tiles: the number's drips end right above the record time (0 clear rows, no overlap). One clear row needs the number 2 px above the tile centre (or a taller tile, which no longer fits above the info panel) | **done in the QA follow-up** (number 2 px up) |
| TT (stacks) | Dense stacks (pause / restart pitch 16, key rows 17, shop rows 15) give 16-20 px hit areas (32-40 pt), under 44 pt, because their gaps are 2-4 px | a touch layout with a 22 px pitch is a layout change per platform; owner decision |
| TT5 | HARD checkboxes (9 px box, 16 px row) and the volume slider keep their drawn hit areas (they are registered touch targets, so buttons never steal from them) | small; would need a TouchCheckBox |
| L3 | 16 px glyphs "4" and "6": ink 1 px left in their cell | **closed in the QA follow-up**: re-measured centred (a measuring artifact), font unchanged |
| T2 | Logo PNG 291 px wide (0.5 px) | asset change |
| U1b / X5 | Odd-width centred boxes (hub prompts) sit 0.5 px off; their inner pads are equal | rule: inner symmetry first |
| U5 / M4 | Coin board pitch 11, map view title 8 px | documented exceptions |
| S1 | Skins row 2 (6 tiles) 0.5 px off | odd remainder |
| G4 | Upgrades header: balance pod 14 tall vs tabs 13 (text rows match) | pods 14 / buttons 13 are both the rule |
| R5 | Descent card margins 10 (rule 4) | the three tiles and the buttons under them are designed as a unit; documented |
| AR1, O1 | 4:3 / tablets use 66% of the screen; the rotate cover is a 3x band in portrait | integer scaling by design |
| TT6 | The in-level touch pause button: 15x13 drawn, 25x23 hit | unchanged (already grown, borderline only with Safari bars) |
| AR2 / AR3 | Home indicator and rounded corners | Phase 5 (above) |

Not changed on purpose: cutscene art (only the pip overlay), gameplay, economy, saves, the workshop (still off behind
its flag), any text content.

## QA follow-up (2026-10-16)

Fixes for [qa-phase3-review.md](qa-phase3-review.md) and the owner decisions on L2 / L3. The Phase 3 base for any
comparison is `d0e0c77` (QA finding 2: the `spring-cleaning-phase2` tag sits after the main Phase 3 commit).
Captures: `ui-after/followup_*` and `ui-after/zoom/followup_*`.

| Item | Change | Evidence |
|---|---|---|
| QA 1 (area texts lost after an early pause / R) | `HUD.cover_area_texts()` hides the area name and story line while pause or the restart prompt is open and leaves their fade alone (it pauses with the tree). `uncover_area_texts()` on RESUME / CANCEL shows them again at full alpha for the rest of their hold, at least `AREA_RESHOW_TIME` 1 s. Only the results (`show_rewards` / `show_choices`) still end them (`hide_area_texts`) | `followup_restart_cancel_before/after.png` (level 5, prompt opened at frame 30, CANCEL at 50, frame 70: before no area texts, after both lines). `test_ui_layout`: texts back after pause RESUME (story, randomizer, Descent) and restart CANCEL; nothing comes back once the fade ended |
| L2 / QA 3 (tile number touching the record time) | Owner: number 2 px up. `NUMBER_Y` 13 -> 11: number body rows 11..24, drips to 28, shadow 29, rows 30..31 clear, time 32..38. The time's drip shadow touches the frame's bottom row 41, by design (rules §3) | 60 rendered tiles (normal + hard, tiles 1-10 all with a record time, 3 runs each, `demo_level_select -- all-times`): before 8 of 60 ran from the number into the time without a clear row; after 0, every tile has rows 30..31 clear. `followup_lvl_tiles_*`, `zoom/followup_lvl_tile9_10_*_6x.png`. `test_level_tiles` expects number row 11 and a gap of 7 |
| L3 ("4" / "6" 1 px left) | **No font change.** Re-measured on rendered tiles, the ink of every digit, "4" and "6" included, is centred in its tile (`measure_tiles.py`: ink 19..28, dx +0.0 on all ten tiles, normal and hard). The audit's L19 / R21 counts only glyph rows 0-3: "4" and "6" are the only digits with no right-column pixel there (their right column is on rows 4-5), so the measure missed it. The glyph cells are symmetric by construction (xoffset 1, advance = width + 2). `make_font.py` regenerates pixel-identical PNGs (only the PNG compression differs, so the files were left as they were) | `zoom/followup_l3_tile4_6x.png`, `zoom/followup_l3_tile6_6x.png`. A glyph redesign for optical balance would be a font-art decision, not a centring fix |
| QA 4 (constants vs literals) | `scripts/ui/` uses `UIKit.BUTTON_H` / `TAB_H` for every 13 px button and tab (the 31 literals), `FONT` / `FONT_BIG` for font sizes, `TITLE_Y`, `DENSE_PITCH` (map tiles), `GAP_XS` / `GAP_S` / `GAP_L` / `GAP_XL` (grid and stack separations, the settings column gap, the confirm pairs) and `CHOICE_GAP = GAP_L`. `POD_H2` and `TOUCH_MIN` stay rule values read by the tests. Not migrated: `hub.gd` and the pod code of `hud.gd` | Same values: a dump of every visible control's rect, font size and separation on the 23 screens `test_ui_layout` opens is identical before and after (682 lines) |
| QA 5 (touch hit areas on touchscreen desktops) | `UIKit.touch_active()` no longer asks whether touch hardware exists. `UIKit.note_pointer`, fed every root-window input event by the RotateHint autoload (before any node or the GUI), sets `touch_in_use` on a screen touch / drag or the mouse event Godot emulates from one (`DEVICE_ID_EMULATION`) and clears it on a real mouse event. `--touch` still forces it | `test_ui_touch`: mouse -> exact, touch -> grown, emulated tap -> grown, mouse -> exact, drag -> grown |

Runs: `test_ui_layout`, `test_ui_touch`, `test_level_tiles`, `test_nav_fuzz` (4 shards) and the full
`./tools/test_all.sh`: 73 suites, 0 failed.
