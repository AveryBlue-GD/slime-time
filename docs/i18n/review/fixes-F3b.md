# Fix pass F3b: settings, key controls, title, LANGUAGE, level select, map table

Scope: `scripts/ui/controls.gd`, `key_controls.gd`, `title.gd`, `language_screen.gd`, `level_select.gd`,
`map_select.gd` (wardrobe / upgrades / hat wheel / HEAT panel / hub: F3a, in parallel; UIKit untouched). Rules added to
`docs/ui-rules.md` 10.1 ("Text lines on the screens (fix pass F3b)", the paging keys of the level select and the map
table side by side, "A paged grid's rows are centred"). New test: `tests/test_i18n_f3b_layout.gd` (every locale).
Shots: `docs/i18n/shots/fixes-F3b/<state>_before.png` / `_after.png` (all 19 locales per sheet, 2x, order en es pt_BR
fr de it ru pl tr ja ko zh_CN zh_TW th vi id ar hi pseudo) and `language_en_{before,after}.png`.

Measured with `tools/i18n_capture.sh --measure-boxes` in two clean worktrees (HEAD b239a3f, and HEAD + these six
files: the other pass's files are not in either), all 56 states x 19 locales. Box numbers are box-relative: T = first
ink row, B = clear rows under the last, L / R = clear columns (shadow included). "Body" = the rows with >= 3 lit
pixels of the line (the letter body, marks and drips apart).

## Rendered check (goo-ink: glyph ink px on goo / in band rows), these screens

| | before (HEAD) | after |
|---|---|---|
| en | language 10/18 (+ save code 0/2) | language 0; save code 0/2 (English's own, unchanged) |
| es / pt_BR / fr / de / it / ru / pl / tr | 5-9 boxes each: title ENTER, settings LANGUAGE, info panel, map tiles, language names | 0 |
| ja / ko / zh_CN / zh_TW / th / ar / id | language names (8-10 px each) | 0 |
| vi | title, info panel, map tiles, settings, key-controls note on the SPACE key's drops, language | 0 |
| hi | title ENTER 5/9, language | 0 |
| pseudo | title 22/28, info panel 3-6, map tiles 1-6, settings 5/8, language | 0 |

Every finding left in the full capture is on another pass's screen (upgrades abilities, HEAT panel, hub notice,
results). English: every state byte-identical to HEAD except `language` (and the hat wheel's wheel, 56 px, which
differs between any two runs, README).

## Rows

| review row | locale(s) | state | result | measured before -> after |
|---|---|---|---|---|
| language button text 2 px high, Ñ / Ê on the frame (med) | es pt_BR fr de it ru pl tr pseudo | settings | fixed | name body rows 117-123 vs FOG 119-125 (-2) -> 119-125 (0); Ñ / Ê / Й from button row 1 -> 3 (goo 0); globe on the body (119-125) |
| `● TIẾNG VIỆT` 3 px high (med) | vi | settings | fixed | body 128-134 vs FOG 130-137 (-3) -> 131-137 (0); marks off the band rows 0-2 |
| (same cause) | ar | settings | fixed | body -1 -> 0 vs FOG |
| (same cause) | ja ko zh_CN zh_TW th hi | settings | already level | 0 before and after (their name font is the theme's: same line); hi globe on the headline (137-143) |
| action labels 2 px above the key text (med) | es pt_BR fr de it ru pl tr pseudo | key-controls | fixed | label body bottom - key body bottom -2 -> 0 on every row |
| labels 3 px above (med) | vi | key-controls | fixed | -3 -> 0 |
| (same cause) | th, hi | key-controls | fixed | label line 1 px over the key's (centred 1 / 1, 2 / 2 vs the theme's 2 / 0, 3 / 1) -> same line top |
| footer note 3 px under the last key row, 14 px over BACK (low) | es pt_BR de it ru pl tr | key-controls | fixed | note line 137 -> 141: 5 -> 9 clear rows under the rows, 14 -> 10 over BACK |
| (same, with marks) | fr | key-controls | fixed | note ink 134 -> 140 (FLÈCHES / ÉCRAN marks 2 -> 8 rows under the key rows), 10 over BACK |
| (seen) note marks on the SPACE key's drops | vi | key-controls | fixed | goo 2 px -> 0: note line 141 -> 145, centred (its stacked marks 3 rows under the key rows, 1 under their drops; 4 over BACK) |
| 3 rows a page, ~40 px empty band (low) | zh_TW | key-controls | fixed (centred) | rows 40..102 -> 54..116: 4 / 36 px -> 18 / 22 px title / note (th 33 -> 48, ar 33 -> 43, hi 33 -> 44) |
| `SALTAR (MANTÉN)` 4 px from SPACE (low) | es de fr | key-controls | not changed | the 4 px is the column GAP (GAP_M) at the widest label; the key column already narrowed for it |
| ENTER drips on the bottom outline | es pt_BR fr it pl (and de / tr / ru shifted) | title | fixed | T7 B0 -> T5 B2 (as English, h 25), the 16 px line from row 5 instead of the 8 px theme margins' 7 |
| ENTER Й breve on the band | ru, pseudo | title | fixed | T1 B0 -> T3 B1 (h 25 -> 28, ink from GOO_INK_ROW); tr T3 B0 -> T3 B1 (h 26) |
| ENTER marks on the lump row | vi | title | fixed | T2 -> T3 (h 25 -> 28) |
| ENTER matras on the lump row (H1 leftover) | hi | title | fixed | T2 -> T3 (h 26 -> 27, BIG_INK_TOP 1) |
| STORY `ストーリー` 1 px left (low) | ja | title | fixed | STORY L5 R7 -> L6 R6; ENTER L38 R40 -> L39 R39 |
| (same cause) | ko | title | fixed | STORY L5 R7 -> L6 R6; ENTER `허브로 가기` L34 R38 -> L36 R36 |
| (same cause) | zh_CN, zh_TW | title | fixed | ENTER L48 R50 -> L49 R49, L40 R42 -> L41 R41; STORY 10 / 11, 8 / 9 (the odd 1 px: 0.5 off, as English STORY 6 / 5) |
| `HİKAYE` / `CERITA` 2 / 1 px (low) | tr, id | title | fixed by F1 (verified) | L6 R5 = English |
| tagline lifted 5 px under ENTER to clear HISTORIA (low) | es pt_BR fr it | title | not changed | its second line is wider than the room beside STORY; lifting it is the documented fit (the slimes then stand level with ENTER) |
| tagline 를 / 틀 squeeze (low) | ko | title | not changed | font (Hangul fallback at 16 px); no layout cause |
| native-name accents 0-1 px under the frame (low; every locale) | all 19 | language | fixed (English changes) | T1 -> T3 (ESPAÑOL, PORTUGUÊS, РУССКИЙ, TIẾNG VIỆT), TÜRKÇE T2 -> T4; a row's slimy names on one line: ENGLISH / POLSKI T4 -> T6 (B3 -> B1, as an accented button); the other rows as before (FRANÇAIS T4, INDONESIA T7, scripts unchanged) |
| T5 हिन्दी's ि on the goo in Thai | th | language | already clear | T3 B4 in every locale before and after (F1 metrics) |
| H3 info-panel matras on the top drips (med) | hi | level-select-normal / -hard | fixed | first ink row 4 -> 5 under the panel's top edge: 1 clear row under the lumps (rows 1-3) |
| info-panel accents on the lump row (F1 leftover) | es pt_BR fr de it ru pl tr pseudo, vi | level-select-* | fixed | line top 7 -> 9 (vi 9 -> 11): marks from row 4 -> 6 (PANEL_INK_TOP); panel 2 px taller, goo 0 |
| two-line checkbox drips on the panel's bottom band | pseudo | level-select-* | fixed | rows [58 / 60] -> 0 (panel 1 row taller) |
| map-tile name marks on the lump row (F1 leftover) | es pt_BR fr ru pl pseudo, vi | map-table | fixed | tiles' first name ink T2 -> T3 (tr T3 -> T4, de / it T5 -> T6: the line 1 row lower everywhere accented); tiles stay 41 px (vi 33 -> 31): the % line at English's dense pitch |
| paged map table's empty band under 3 rows | ja ko zh_CN | map-table | fixed (centred) | rows 31..122: 0 / 34 px above / below -> 48..139: 17 / 17 |
| (same) | zh_TW, th, vi, ar, hi | map-table | fixed (centred) | 0 / 22 -> 11 / 11; 0 / 25 -> 12 / 13; 0 / 20 -> 13 / 13; 0 / 17 -> 8 / 9 (ar, hi) |
| CJK / Thai checkbox offset | ja ko zh_CN zh_TW th hi | map-table, level-select | checked, no change | the 9 px box's bottom row 3 rows over the text's last ink row in every locale, as English (en box 164-170 / caps 167-173; ja 164-170 / 165-173; th 163-168 / 163-171): `align_checkbox` already does it |
| H10 Latin runs dropped in Hindi lines (low) | hi | key-controls note | not fixed | `ESC` / `P` / `F11` sit on the shared baseline by design (language.gd font chain, not these files) |
| `PANTALLA COMPLETA: NO` fills its button (low) | es | settings | fixed by F1 (verified) | L6 R5 |
| save code panel 2 px in its band zone | en | settings-save-code | not changed | English's own (the rule's floor); no other locale has it |

## English

Byte-identical to HEAD in every state but `language` (the owner accepted the LANGUAGE change: a gated-only screen).
There ENGLISH, POLSKI move 2 px down (T4 -> T6, beside ESPAÑOL / PORTUGUÊS and РУССКИЙ / TÜRKÇE), the marked names
2 px down, TIẾNG VIỆT 2 px; the rows, the grid and BACK keep their places. `tests/test_i18n_f3b_layout.gd` pins the
English settings / key controls / title / map tile rects.

## Tests changed

- `tests/test_i18n_levels_layout.gd`: the map table's grid was pinned to `title_bottom() - 1`; now one page keeps that
  row (English) and a paged grid must be centred in the room to `BOTTOM_GAP` over the bottom row (+-1 px).
- `tests/test_i18n_settings_layout.gd`: the CONTROLS note keeps GAP_M (was GAP_L) over the bottom row, the room the
  centred Vietnamese note has; `test_i18n_f3b_layout.gd` asks GAP_L wherever the note is not centred.

## Local helpers (UIKit has none for these)

`title.gd`: `mark_rows(text, size)` (a text's own mark rows, from the font's i18n page; `UIKit.ink_above` gives the
locale's tallest), `ink_shift(text, size)` (CJK ink centring), `BIG_INK_TOP`. The LANGUAGE screen and the key controls
load `mark_rows` from title.gd at run time.
