# Visual review: ru (Russian)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are
320x180 frame pixels (x, y). "Ink gap" = clear pixels between glyph ink and the inner orange stripe
of a goo frame (the drop shadow counts as ink). Missing-glyph check: 0 findings.

Summary: high 0, med 4, low 5. No clipped text, no untranslated English (ХАБ, ХАМЕЛЕОН, СЛАЙМАКАДЗЕ per glossary).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hub-prompt-random, hub-prompt-settings | station pill `РАНДОМАЙЗЕР`, `НАСТРОЙКИ` | the Й breve sits on row 159, directly under the pill's dark-red band row 158 (x 171-173): 0 px gap, the breve reads as part of the goo. English capitals start at row 162. The pill uses `UIKit.panel_style()` without the accent rows that buttons get. | med | `scripts/hub.gd:411` (prompt `panel_style()`), `hub.station.random`, `hub.station.settings` |
| key-controls | action labels (ВВЕРХ, ВНИЗ ... СЛАЙМАКАДЗЕ) | each label's letter body is 2 px above its key button's text (label rows 40-46 / 60-66 / 80-86, key text 42-48 / 62-68 / 82-88). In en both are on 33-39 / 50-56. Labels are centred on the taller accented button box, but the key text is pushed down by the accent top margin. | med | `scripts/ui/key_controls.gd` |
| settings | `● РУССКИЙ` (language button) | its text body is on rows 117-123, 2 px higher than the pitch of the column above (50 / 73 / 96, +23 each, so 119 expected); in en all four sit on a 20 px pitch (41/61/81/101). Globe + label row does not get the accent top margin. | med | `scripts/ui/controls.gd:177-198` |
| wardrobe-skins, -hats, -trails | page titles СКИНЫ / ШЛЯПЫ / СЛЕДЫ | title falls back to the 8 px font (rows 5-12) while en shows the 16 px slimy title; it reads as a caption, not a screen title. | med | `scripts/ui/skins_screen.gd` (fit_text fallback) |
| upgrades-coins, upgrades-abilities | title `УЛУЧШЕНИЯ` vs tab `БИЛЕТЫ` | title starts about 6 px right of the tab (x ~101 -> ~107); en keeps 16 px (x 97 -> 113). Crowded top row. | low | `scripts/ui/upgrades_screen.gd` |
| upgrades-coins / -abilities | tab `МОНЕТЫ` | ink gap 2 px left / 1 px right (x 9-43); en COINS 4 / 3. The Ы touches the right stripe visually. Same pattern on the widest tab of each group. | low | `scripts/ui/upgrades_screen.gd`, `UIKit.tab_widths` |
| hat-wheel-wheel / -shop | tab `КОЛЕСО` | ink gap 2 / 1 (x 21-55), en WHEEL 5 / 4; the last О sits on the stripe. | low | `scripts/ui/hat_wheel.gd` |
| hat-wheel-shop | row `КЕПКА С ПРОПЕЛЛЕРОМ` + price 45 | name ink ends x 130, price starts x 134: 3 px (2 px after shadow) between name and price; en has 30+ px. Fits, but reads as one string. | low | `scripts/ui/hat_wheel.gd`, `hat.propeller_cap` |
| descent-boon-card | title `ЭТАЖ 1 ПРОЙДЕН` | the Й breve reaches screen row 0-1 (en caps start row 4): no top margin, would touch a safe-area crop. | low | `scripts/ui/descent_card.gd` |

Checked and clean: title, level select (paging 5 + arrows), HEAT panel, upgrades rows, pause (all 3), restart, results (dry-up / win / randomizer: last-line ink gaps 8 / 4 vs en 7 / 5), Descent summary, hub overlays (notice, portal, coin board, quit, resume), HUD states, language, save code, reset confirm, victory, story cards (no text).
