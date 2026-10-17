# Visual review: es (Spanish, Latin American)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are 320x180 frame
pixels (x, y). "Inset bar" = the light vertical stripe just inside a tab / button frame; "interior L/R" = clear
columns between glyph ink and the button fill's edge. Missing-glyph check: 0 findings. No untranslated English
beyond glossary choices (SKIN, SLIME, INKKY, CHAMELEON, SLIMAKAZE, key names), casing all caps.

Summary: high 0, med 5, low 7 (+ 3 also en).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| upgrades-coins, upgrades-abilities | tab `MONEDAS` | ink x 9-50, the right inset bar is at x 51: the S touches the bar (0 px), left 3 px. en `COINS` keeps 1 px right / 3 px left. 41 px of text in a "max 32px" budget. | med | `scripts/ui/upgrades_screen.gd`, `upgrades.tab_coins` |
| hat-wheel-shop | price `45` + ticket in every row | price caps on rows 69-75 / 87-93 / 105-111, the item names on 72-78 / 90-96 / 108-114: the price sits 3 px higher than its name and close under the row's top frame. en: both on 64-70 / 79-85. | med | `scripts/ui/hat_wheel.gd` (shop row price label y vs accent top margin) |
| settings | language button `ESPAÑOL` | caps on rows 117-123 while the NIEBLA button beside it has 119-125 (2 px high); the Ñ tilde is on row 115, right under the frame's top highlight row 114 (0 px). en: both rows 101-107. The label is centred on the box ignoring the accent top margin other buttons get. | med | `scripts/ui/controls.gd:177-210` (language button `label.position`) |
| key-controls | action labels (`ARRIBA` ... `SLIMAKAZE`) | label caps rows 40-46 / 60-66 / 80-86, key-button text 42-48 / 62-68 / 82-88: labels 2 px higher than the key text on the same row. en: both 33-39 / 50-56. | med | `scripts/ui/key_controls.gd` |
| wardrobe-skins / -hats / -trails | page titles `SKINS` / `GORROS` / `RASTROS` | drawn in the 8 px font (step-1 fallback for the taller line pitch) while en uses the 16 px slimy title; every other screen keeps the big title, so the wardrobe reads as titleless. | med | `scripts/ui/skins_screen.gd` (`_layout` step 1) |
| hat-wheel-wheel / -shop | tab `RULETA`, section tab `RASTROS` | ink 2 px left / 1 px right of the inset bars (`RULETA` x 21-55 in 18-56); `RASTROS` S touches the right bar. en `WHEEL` 5 / 5. | low | `scripts/ui/hat_wheel.gd`, `wheel.tab.wheel`, `wheel.section.trails` |
| level-select-heat-panel | toggle `NIEBLA VORAZ` | ink ends x 303 (shadow x 304), tile frame at x 305: 1 px clear; en and the other es names keep >= 5 px. | low | `scripts/ui/heat_panel.gd`, `heatmod.fog.name` |
| key-controls | `SALTAR (MANTÉN)` and the footer note | label ends x 87, SPACE box starts x 92 (4 px; en 28 px); the note `FLECHAS MUEVEN - ESC O P PAUSA - F11 PANTALLA COMPLETA` starts 3 px under the last key row (en 27 px). Crowded bottom half. | low | `scripts/ui/key_controls.gd`, `keys.jump`, `keys.note.*` |
| title | tagline `ESCAPA DE LA NIEBLA / O SÉCATE EN EL INTENTO` | moved up to 5 px under ENTER (en 13 px) to clear HISTORIA, and the two slimes jump up to the button line; more space under the tagline than above it. | low | `scripts/ui/title.gd:107-145` |
| pause-descent | note `SALIR COBRA LA MITAD DEL POZO` | 7 px under the taller pause panel; en 18 px. | low | `scripts/ui/pause_menu.gd` |
| hub-resume, descent-summary, settings | `CONTINUAR` / `ABANDONAR`, `OTRO DESCENSO`, `PANTALLA COMPLETA: NO` | text fills its button: interior 3 / 2 px (en RESUME 9 / 8, NEW RUN 21 / 20, FULLSCREEN 17 / 16). Fits, looks cramped. | low | `scripts/hub.gd`, `scripts/descent.gd`, `scripts/ui/controls.gd` (`settings.fullscreen.*`) |
| level-select-*, upgrades, wardrobe, settings | BACK `ATRÁS` | interior 4 / 2 px (en BACK 7 / 6); the Á accent 1 px under the top frame. | low | `scripts/ui/ui_kit.gd` (back button), `common.back` |
| hub-coin-board | HUD pill over the board | also en: pill x 4-76 overlaps the board's frame (board x ~50). | med (also en) | `scripts/hub.gd` |
| upgrades-abilities | `DISPARA BABA`, `BOMBA 3X3`, `EMBESTIDA` | also en: description drips touch the row's bottom goo. | low (also en) | `scripts/ui/upgrades_screen.gd` |
| result-dry-up | `AYUDA: +10% SLIME, SIN MEDALLAS/BOLETOS` | also en: third line drips on the bottom goo. | low (also en) | `scripts/game.gd` |

Checked and clean: level select (paged 5 + arrows, info box), reset confirm (`¿BORRAR EL PROGRESO?`), save
code, hub notice / portal / quit / resume, all hub prompts (no accent reaches the pill band), HUD states, pause
story / random (two-column), restart (`¿REINICIAR?`), results, Descent boon card, victory, language.
