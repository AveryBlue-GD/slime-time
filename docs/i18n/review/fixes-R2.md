# Fix pass R2: UIKit / Language / settings / HEAT panel / map screens

Scope: the rows of recheck-latin.md, recheck-cyr-vi.md, recheck-th-hi-ar.md owned by `scripts/ui/ui_kit.gd`,
`scripts/language.gd`, `scripts/ui/controls.gd`, `scripts/ui/heat_panel.gd`, `scripts/ui/map_select.gd`, plus the
review note on `tests/test_i18n_settings_layout.gd`. Rules: `docs/ui-rules.md` 10.1 "Fix pass R2 rules".
Measured from `tools/i18n_capture.sh --measure-boxes` frames (all 19 locales, 73 states) and pixel dumps of them:
before = HEAD 68d775d (the ar HEAT frame re-captured from it), after = this pass. Box-relative: B = rows from the
last ink to the box's last row (the border), so B2 = 1 clear row over the border; R = columns to the box's right edge.
Shots (one state, all 19 locales, 2x): `docs/i18n/shots/fixes-R2/<state>_before.png` / `_after.png`.
Tests: `tests/test_i18n_r2_layout.gd` (new, every locale), `tests/test_i18n_f1_marks.gd` (bottom border rows),
`tests/test_i18n_settings_layout.gd` (note room). `./tools/i18n_capture.sh --gate`: PASS, 0 goo-ink px in every locale.
English: all 73 states byte-identical to before.

## Fixed

| Row | Locale(s) | Cause / fix | Measured before -> after |
|---|---|---|---|
| HEAT icons overflow their toggles (high) | ar | an RTL layout mirrors a control by its `size` (x' = W - x - w), not its 2x `scale`: the 9 px box drawn 18 wide landed 9 px right. The icon is kept out of the mirroring (`UIKit.keep_ltr`) and placed at the mirrored drawn width | DIM moon x 297-306 (on the frame 305-307) -> 288-297, 7 clear columns to the frame; icon box 286-303 = 4 px from the toggle's right edge, as LTR's 4 from the left. FOG cloud 97-114 (across two toggles) -> box 88-105 inside its toggle 13-109 |
| lower matras on the bottom border (med, regression) | hi | the trimmed 17 px line ends on ु ू; 21 px buttons (3 / 1) put them on the row over the border, shadow on it. `UIKit.button_h()` adds `BOTTOM_INK_ROOM` (2) under a `LINE_TRIM` line: 22 px, 3 / 2 (upper matras still from row 3). LANGUAGE screen keeps METRICS 21 (English unchanged) | settings SOUND ू ends 74, border 75 -> ends 74, row 75 clear, border 76; every hi button / VOLUME box B1 -> B2 (settings 5 boxes, pause-story / -random / -descent 4 each, victory, portal, results, wheel, boon card); first ink row T3 kept |
| NIEBLA VORAZ 2 clear px (low) | es (fr GROUNDED too) | a name filling the room to `BUTTON_TEXT_PAD` takes two lines where the panel fits them and no smaller font exists; two-line names wrap `NAME_ROOM_PAD` (GAP_S) inside the room | es FOG toggle R5 -> R39 (NIEBLA / VORAZ), fr GROUNDED R5 -> R27; English min R8 |
| map-view title marks on rows 0-1 (low) | pl, tr, pseudo (pt_BR too) | `view_title_y(text)` = 3 + that line's own `mark_rows`; the map area follows it | title first ink: pl 0 -> 3, tr 1 -> 3, pseudo 0 -> 3, pt_BR 0 -> 3, vi 2 -> 3; en / es / fr / de / ru 3 (unchanged) |
| tile name 1 px from the frame (low) | ru, fr | names wrap past `name_room()` = 155 - 43 - TEXT_PAD - GAP_S (105) | ПЕСЧАНОЕ / СВЯТИЛИЩЕ, SANCTUAIRE DE / SABLE on two lines; tightest R: ru 5 -> 12, fr 4 -> 14 (en 12); no other locale changed |
| short VOLUME slider (low) | de (ru tr pl vi th ar pseudo too) | the columns widen (both, centred) until the slider is `VOLUME_SLIDER_MIN` 66 (English's) beside its label, while they fit | slider track: de 42 -> 66, ru 48 -> 66, tr 46 -> 66, pl 54 -> 66 (en 66); de columns 120 -> 144 wide (x 12..308) |
| SAVE CODE / RESET titles in the 8 px font (low) | pseudo | SAVE CODE: a step with the column's gaps one scale step closer (GAP_S) before the 8 px title; RESET: a title wider than the panel takes two balanced 16 px lines (`two_lines`, `big_line_spacing`) | both titles 8 px -> 16 px; SAVE CODE panel 312x172 (in EDGE), RESET panel 81 -> 117 tall |
| test note room loosened to GAP_M (review) | - | GAP_L over the bottom row unless the note is centred (as near the rows' bottom as the bottom row): only vi and pseudo; English pinned at NOTE_GAP 14 | test only |

## Not fixed (layout does not allow)

- vi map-view map 205x130 (en 231x146): the map needs 146 rows; with the name's stacked marks from row 3 the area is
  rows 16..156 (141) above vi's 18 px bottom row. Unchanged size (was 142 rows, same step).
- Side effect of the title rule: in a locale whose map name has marks (pl, tr, pt_BR, pseudo, vi) the maps that need
  144+ rows drop one size step (L3, L4, L5, L2 hard: e.g. pl L3 231x146 -> 205x130); the others keep their size.
  The tests keep the area over the bottom row, so it cannot borrow those 3 rows.
- ar: the lowest dots still end on the row over a button's bottom border (21 px, 2 / 0, e.g. settings MORE column);
  the same fix (22 px) would regrow every Arabic layout and was not in this pass's list; `test_i18n_f1_marks`
  lists ar in `BOTTOM_ROW_OPEN`.
- pseudo HEAT FOG / GROUNDED names keep R5: two-line names would make its panel taller than the screen.
- The pause menu's VOLUME slider (pause_menu.gd, 100 px column: de 22 px) is the HUD / pause owner's.

## Outside this pass's files (needed by the fix)

`tests/test_ui_kit_locale.gd` and `tests/test_language_screen.gd` pinned hi `button_h()` to METRICS 21; they now
expect the trimmed line's 22 (the LANGUAGE screen rows keep 21).

## Follow-up: Arabic bottom row (closes the open ar item above)

Same rule as Devanagari, from the Language METRICS ink rows: `UIKit.button_h()` adds `UIKit.bottom_ink_room()`
(the rows a taller script's line box lacks for `BOTTOM_INK_ROOM`, 1 clear row + the border, under its `ink_bottom`):
hi 2 (trimmed line, unchanged 22), ar 1. Arabic buttons / tabs / pills / VOLUME boxes 21 -> 22, margins 2 / 0 ->
2 / 1, pods 22 -> 23; first ink row stays 3; the LANGUAGE screen's rows keep METRICS 21. English byte-identical.

| measure (ar, --measure-boxes, every button / box of every state) | before | after |
|---|---|---|
| clear rows between the last ink and the bottom border (min) | 0 (21 px: settings MORE, wheel shop tiles, results NEXT) | 1 (22 px) |
| settings MORE / وضع ملء الشاشة: last ink / border | row 19 / 20 | row 19, row 20 clear, border 21 |
| goo-ink gate (ar, en) | 0 | 0 |

Knock-on, checked on every ar capture (settings, pause, hub prompts, upgrades, wardrobe, HEAT panel, LANGUAGE,
results, boon card, save code): nothing clips or overlaps (box rects on screen, no sibling overlaps).
- Wardrobe: the JELLY corner (EDGE + 22 + GAP_XS) pushes the grid to row 28 and no 16 px-title plan fitted (the
  title fell to 8 px). New last 16 px plan `flush` (skins_screen.gd): the stage's frame on the bottom-row
  buttons' bottom border (row 176) instead of the row over it (175); only Arabic takes it, the other 18
  locales' wardrobe captures are byte-identical. Rule line ink ends 127, stage 129 (1 clear row).
  `tests/test_i18n_game_layout.gd` (not this pass's file) skips ar; its stage bound `end.y <= 176` would need
  `bottom_row_y() + button_h()` (177, the buttons' end) for the flush plan if ar is added there.
- Wheel shop: grid top 58 -> 60, room 68 -> 66 < 70 for three 22 px rows: two rows per page (pages already
  existed), as Devanagari.

Tests: `test_i18n_f1_marks` drops `BOTTOM_ROW_OPEN` (every taller script enforced), `test_ui_kit_locale` checks
`button_h()` from the ink rows for every locale, `test_i18n_r2_layout` pins ar 22 (2 / 1) and the wardrobe plan /
stage rows. Shots: `docs/i18n/shots/fixes-R2/ar-dots_*_{before,after}.png` (3x).
