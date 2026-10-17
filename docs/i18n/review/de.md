# Visual review: de (German)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are 320x180 frame
pixels (x, y). "Inset bar" = the light vertical stripe just inside a tab / button frame; "interior L/R" = clear
columns between glyph ink and the button fill's edge. Missing-glyph check: 0 findings. All caps, `SS` for ß.

Summary: high 0, med 6, low 6 (+ 3 also en).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| upgrades-coins, upgrades-abilities | tab `MÜNZEN` | ink x 9-44, right inset bar at x 45: the N touches the bar (0 px); 36 px in a "max 32px" budget (noted in the glossary as "still fits"). en `COINS` keeps 1 px. | med | `scripts/ui/upgrades_screen.gd`, `upgrades.tab_coins` |
| hub-prompt-coins, hub-prompt-wardrobe | station pills `MÜNZBEUTEL`, `SKINS & HÜTE` | the Ü dots (x 138 / 140, x 177 / 179) are on row 160, one row under the pill's goo drips (row 159, x 137-144 above MÜNZBEUTEL): the dots touch the drip. en capitals start on row 162. | med | `scripts/hub.gd` (prompt pill `panel_style()`), `hub.station.coins`, `hub.station.wardrobe` |
| hat-wheel-shop | price `45` + ticket in every row | price caps on rows 69-75 / 87-93 / 105-111, item names on 72-78 / 90-96 / 108-114: price 3 px higher than its name. en: both on 64-70 / 79-85. | med | `scripts/ui/hat_wheel.gd` (shop row price y) |
| wardrobe-skins / -hats / -trails | page titles `SKINS` / `HÜTE` / `SPUREN` | drawn in the 8 px font (step-1 fallback) while en uses the 16 px slimy title. | med | `scripts/ui/skins_screen.gd` (`_layout` step 1) |
| key-controls | action labels (`NACH OBEN` ... `SLIMAKAZE`) | label caps rows 40-46 / 60-66 / 80-86, key-button text 42-48 / 62-68 / 82-88: labels 2 px higher than the key text. en: both 33-39 / 50-56. | med | `scripts/ui/key_controls.gd` |
| settings | language button `DEUTSCH` | caps on rows 117-123 while the NEBEL button beside it has 119-125: 2 px high. en: both 101-107. | med | `scripts/ui/controls.gd:177-210` (language button `label.position`) |
| settings, pause-story / -random / -descent | volume row `LAUTSTÄRKE` | the label leaves the slider ~22 px of track (en VOLUME ~45 px); the knob range halves. | low | `scripts/ui/ui_kit.gd` (volume row), `settings.volume` |
| key-controls | `SPRUNG (HALTEN)` and the footer note | label ends x 87, SPACE box starts x 92 (4 px; en 28 px); the note starts 3 px under the last key row (en 27 px). | low | `scripts/ui/key_controls.gd`, `keys.jump`, `keys.note.*` |
| descent-boon-card | boon name `GIERIGER GLIBBER` | 3 px from the card's fill edge on each side (en names >= 10 px); the 4-line `GUMMIKÖRPER` card pushes its icon up. | low | `scripts/ui/descent_card.gd`, `boon.greedy.name` |
| level-select-*, upgrades, wardrobe, settings, key-controls | BACK `ZURÜCK` | interior 2 / 2 px (en BACK 7 / 6): Z and K touch the inset bars. | low | `scripts/ui/ui_kit.gd` (back button), `common.back` |
| title, hub-prompt-story, hub-coin-board | `STORY` (title button), `STORY - LEVEL 1`, `STORY 165/165` | English word kept (glossary uses STORY / LEVEL / UPGRADES / SHOP as German gaming loanwords). Consistent, but the only screen words left in English; confirm it is intended. | low | `title.story`, `hub.station.story`, `glossary/de.md` |
| pause-descent | note `BEENDEN ZAHLT DEN HALBEN POTT AUS` | 7 px under the pause panel (en 18 px). | low | `scripts/ui/pause_menu.gd` |
| hub-coin-board | HUD pill over the board | also en: pill x 4-76 overlaps the board's frame (board x ~53). | med (also en) | `scripts/hub.gd` |
| upgrades-abilities | `SPUCKT GLIBBER`, `BOMBE 3X3`, `DURCH WÄNDE` | also en: description drips touch the row's bottom goo. | low (also en) | `scripts/ui/upgrades_screen.gd` |
| result-dry-up | `HILFE: +10% SCHLEIM, KEINE MEDAILLEN/TICKETS` | also en: third line drips on the bottom goo. | low (also en) | `scripts/game.gd` |

Checked and clean: title (tagline keeps the en 13 px gap), level select (paged, `LEVELAUSWAHL`), HEAT panel
(two-line names), settings save code / reset confirm (`ALLES LÖSCHEN?` Ö 3 px under the goo), hub notice
(`ÜBERARBEITET` clear of the drips) / portal / quit / resume, HUD states, restart, results, Descent summary,
victory, hat wheel tabs / spin button (`GRATIS DREHEN` 4 / 2 px), language.
