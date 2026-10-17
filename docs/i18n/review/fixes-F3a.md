# Fix pass F3a: wardrobe, upgrades, hat wheel, HEAT panel, hub leftovers

Scope: `scripts/ui/skins_screen.gd`, `scripts/ui/upgrades_screen.gd`, `scripts/ui/hat_wheel.gd`,
`scripts/ui/heat_panel.gd`, `scripts/hub.gd` (coin-board digits, the one-time notice); new test
`tests/test_i18n_f3a_layout.gd`; `tests/test_i18n_game_layout.gd` updated where it pinned the old layouts.
Settings / keys / title / LANGUAGE / level select / map select are F3b's.
Measured with `./tools/i18n_capture.sh --measure-boxes` (all 19 locales x 56 states), before = HEAD b239a3f,
after = this pass. Box-relative ink: T = first ink row, B = rows under the last ink (B3 = the ink touches the
bottom goo's lumps, B4 = 1 clear row), L / R = clear columns.
Shots: `docs/i18n/shots/fixes-F3a/<state>_before.png` / `_after.png` (one state, all 19 locales, 2x).

## English
Pixel-identical except **upgrades-abilities** (en review row: the tags' drips on the goo). Checked in two
clean worktrees (HEAD vs HEAD + only this pass's five scripts), en and id captured, compared pixel by
pixel: en differs in that one state only. (id has English metrics but longer texts: its notice, SHOP tiles
and HEAT panel take the locale paths below, so it changes there too.)

## Rules settled (for docs/ui-rules.md 10.1, owned by F3b)
- **Keep the 16 px title by making room**: a screen tries its 16 px title with the layout's other steps
  (stage on the bottom row, gaps one scale step closer, smaller crisp font) before the 8 px font.
- **Off-centre title**: a 16 px title wider than the room centred between header items moves only as
  far as it must, GAP_L clear of the tabs (GAP_M if that does not fit), never centred in the leftover room.
- **Ink-based placement in a taller script**: line positions come from Language `ink_top` / `ink_bottom`
  (and a 16 px title from its shaped glyphs), so a line box's empty rows are not counted as gaps; line
  *boxes* still never overlap (`test_i18n_screens` overlap check).
- **Two-line rows in goo panels** (ABILITIES): the first line's ink from row `PANEL_INK_TOP` 6, the last
  line's ink 1 row over the bottom lumps (h - 5); fallbacks in order: hint on the bottom row, rows GAP_XS
  apart, last ink on h - 4, first ink on row 5, the old 2 / 2 insets, the smaller font, pages.
- **Name next to a price / icon**: in a right-to-left layout a name keeps 1 px more from its border /
  icon (Kufi has no side bearing). A price label sits on its name's text row (box top - 1, as English).
- **Toggle name fitting** (HEAT): one line (up to BUTTON_TEXT_PAD from the edge) -> smaller font -> two
  lines if the panel still fits the screen -> 1x icon only in the toggles whose name needs it.
- **Mixed digit rows in CJK**: digits beside CJK names go `ink_drop` (1) rows down (coin board).

## Per-row results

| Locale(s) | State | Row | Result | Measured before -> after |
|---|---|---|---|---|
| es pt_BR fr de it ru pl tr vi ja ko zh_CN zh_TW pseudo (med/low) | wardrobe-skins / -hats / -trails | page title in the 8 px (CJK: 10 / 12 px body) font | fixed | title 8 px -> 16 px (CJK 20 px, zh_TW 24 px) in all 18 translations. Accented: stage on the bottom row (top 128), grid 17 -> 29, status 86 -> 98, rule 98 -> 110, rule ink ends 118, 9 clear rows over the stage. es / pt_BR / fr / de / it / pseudo (BACK / page button too wide to flank the stage): page button top right (JELLY's mirror), BACK its own width, stage centred (x 50). CJK grid 30, zh_TW 34 (rows GAP_XS apart). test: `wardrobe ...: the 16 px title` |
| th T3 | wardrobe-* | title at the 11 px body size | fixed | 16 px title (สกิน ink rows 7-19), grid 27, rule 109, stage 128 |
| hi, ar | wardrobe-* | (title at body size, not flagged) | fixed too | 16 px title; hi status / rule in the 12 px font (as before), ar the snug plan (rule's deepest ink 1 row over the stage) |
| ar A2 (high) | wardrobe-skins | hint on the stage's top border, ى / ي tails covered | fixed | rule ink rows 116-127 (cut by the stage at 128) -> 110-123, 4 clear rows (124-127) over the stage; 0 text px under the stage |
| vi | wardrobe-skins | JELLY in the top-left corner | not changed (by design) | the 16 px title and the two lines need the stage on the bottom row in vi (as before this pass); every accented locale now shares that layout (JELLY top left like the upgrades tabs) |
| ar A5 | wardrobe-skins | try-on slime not mirrored | not mine | `skin_showcase.gd` / UIKit Node2D mirroring |
| ar A8 | wardrobe-trails | page button مظاهر tail touching | fixed by F1 (verified) | L 5 R 6 (BUTTON_TEXT_PAD 5) |
| pl | wardrobe page button, upgrades tabs | CZAPKI / SKÓRKI / MONETY 1 px right | fixed by F1 (verified) | L 6 R 5 |
| en (low) | wardrobe-hats / -trails | empty band under the status lines | not changed | not a defect; English must stay pixel-identical here |
| ja | wardrobe | `（` gap | fixed by F4 | one space |
| fr, it, pl, tr, pseudo (med), ru (low) | upgrades-coins / -abilities | title in the 8 px font (ru crowding the tab) | fixed | 16 px in every locale. Off-centre where the tabs leave no centred room (GAP_L from the tabs): fr / it / tr title centre 180 (x 106-254), pl 170, ru 166, pseudo 187; tabs GAP_L clear, pod GAP_M+ clear (test) |
| en, de, fr, es, pt_BR, it, id, pseudo (low, also en) | upgrades-abilities | tag drips on the bottom goo, name on the top lump row | fixed | en panel 27 -> 30 (pitch 30 -> 33): T4 B3 -> T6 B4 on all three rows (name ink from row 6, drips 1 row over the lumps); accented 31 -> 34, T7 B3 -> T9 B4; goo-ink en 33 / 113 -> 0 px in these panels |
| ja, ko, zh_CN (low) | upgrades-abilities | tag 0 px from the bottom goo, name right under the top band | fixed | 32 -> 34: T5 B3-5 -> T6 B4-6 |
| zh_TW (low) | upgrades-abilities | same | partly | 36 -> 37 (rows GAP_XS apart): T5 -> T6, B4 / B4 on rows 1 / 3; row 2 `3X3爆破` B3 -> B3 (its slimy 3 / X drips reach 1 row past zh_TW's ink_bottom; a 38 px row does not fit the content area) |
| th T4 (low) | upgrades-abilities | ุ under พ on the bottom border | fixed | 38 -> 39 (GAP_XS): T5 -> T7, B5-7 -> B4-6 |
| vi | upgrades-abilities | marks in the band (goo-ink rows 4, 29) | fixed | 32 -> 38: T4 / T7 B2 -> T8 / T11 B4; 0 goo-ink px |
| hi | upgrades-abilities | (goo-ink: matra on rows 2-4) | fixed | small-font rows placed by their measured ink (0-12 of 16): T2-6 -> T6-10, 0 goo-ink px; row 2 `बम 3X3` B3 (slimy drips), one page kept |
| zh_TW, vi (low) | upgrades-abilities | hint on the bottom row beside BACK | not changed | the rows only fit the content area with the hint there (as before) |
| ar | upgrades-abilities | (two pages) | kept | rows 42 -> 46 (clean margins), 2 a page as before |
| de es pt_BR pl tr vi (med) | hat-wheel-shop | price 3 px over the item name | fixed | price digit rows (first tile) de / es / pt_BR / pl 51-57 -> 54-60 on names 54-61 (en: 49-55 on 49-56); tr 51-57 -> 54-60; vi 55-61 -> 60-66 on name body 60 (marks 57). The fixed `y = 2` became `text_y - 1` (2 in English) |
| ar A10 | hat-wheel-shop | right-aligned names 2 px from the inner border | fixed | name ink R 4 -> 5 (English L 5) |
| ru | hat-wheel-shop | КЕПКА С ПРОПЕЛЛЕРОМ 3 px before its price | not fixed | the tiles are already at their widest (143, GRID_MIN_INSET 6); a grown tile now keeps GAP_L there where the panel has room (id TOPI BALING-BALING) |
| fr, it (low) | hat-wheel-wheel | title centred at x ~204 / ~199 | fixed (as near as fits) | ROUE À CHAPEAUX ink x 164 -> 139 (centre ~204 -> ~179), RUOTA DEI CAPPELLI ~199 -> ~174: GAP_L after the SHOP tab, no longer centred in the leftover room |
| fr it es ru tr pt_BR (med/low) | hat-wheel tabs | BOUTIQUE / NEGOZIO / RULETA / КОЛЕСО / DÜKKAN / CAPPELLI / CHAPÉUS / RASTROS touching the bars | fixed by F1 (verified) | widest tabs L 6 R 5 |
| pseudo | hat-wheel-wheel | SPIN acute on the top band | fixed by F1 (verified) | 0 goo-ink px |
| pl (med), fr, ar A9 (low) | level-select-heat-panel | every icon dropped to 1x | fixed | fr / pl: 6 x 1x -> 6 x 2x (LA BRUME MORD, GRYZĄCA MGŁA on two lines, as ru / de / it); ar: 6 x 1x -> 5 x 2x + 1x only on ملتصق بالأرض (two-line names would not fit the screen) |
| ar A9 | level-select-heat-panel | GROUNDED's name 2 px from its icon | fixed | name 1 px further from the icon in right-to-left (3 clear columns) |
| es, hi H8 (low) | level-select-heat-panel | NIEBLA VORAZ / कटखना कोहरा 1 px from the frame | fixed | toggles GAP_XS apart across (96 -> 97 wide), names up to BUTTON_TEXT_PAD (5) from the edge: right clear columns es 4 -> 5, hi 6 -> 7 (incl. the 3 goo columns: 1 -> 2 clear) |
| vi | level-select-heat-panel | (goo-ink: marks on row 2 of DIM / FOG / GROUNDED) | fixed | name line from row 8 (marks from row 3): 0 goo-ink px |
| zh_TW (low) | hub-coin-board | digits 1.5 px over the hanzi centre | fixed | number `1` body rows 44-50 (centre 47) -> 45-51 (48) on 黑暗地牢 43-53 (48); counts and coins with them; zh_CN 52 -> 53 on 53 too |
| pseudo (low) | hub-notice | wide notice covering the cabinet and the chair | fixed | box (71, 24) 179x33 -> (100, 8) 120x57: lines broken at the balanced space, clear of every station but the one straight behind it (as English), 3 rows over the wheel. id too: 138 -> 110 wide |
| hi, ar | hub-notice | (two tall lines reaching the wheel, 24..70 on its top 68) | fixed | moved up to end GAP_S over the wheel: y 24 -> 18 |
| zh_TW | hub-notice | (goo-ink: 1 px on the bottom zone) | fixed | bottom margin +1 in a taller script: 0 goo-ink px |

## Tests
- `tests/test_i18n_f3a_layout.gd` (new, headless, all 19 locales): the rows above (16 px titles, no
  overlaps, rule line over the stage, ability rows' ink clear of the goo, SHOP price rows, HEAT 2x icons
  and name room, coin-board digit drop, notice clear of stations and wheel) and the English pins.
- `tests/test_i18n_game_layout.gd`: English ABILITIES pitch 30 -> 33; ABILITIES rows may be GAP_XS apart
  (the plan's gap); the wardrobe's top-right page button; a taller script's title by its glyphs' ink.
- Passing: test_i18n_f3a_layout, test_i18n_game_layout, test_i18n_screens, test_i18n_f1_marks,
  test_i18n_f2_layout, test_i18n_rtl, test_i18n_levels_layout, test_i18n_hub_layout, test_i18n_fit,
  test_ui_layout, test_heat, test_level_tiles and the full `./tools/test_all.sh`.

## Helpers missing in UIKit (moved since: leftover pass, `UIKit.title_ink_end` / `UIKit.ink_rows`)
- `skins_screen._title_ink_end(texts)`: the 16 px title's last inked row from its shaped glyphs.
- `upgrades_screen.ink_rows(texts, font)` and the same in `skins_screen.ink_rows`: 8 px ink rows of given
  texts in a font (the smaller crisp size has no Language ink metrics).
