# Visual review: pt_BR (Brazilian Portuguese)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are 320x180 frame
pixels (x, y). "Inset bar" = the light vertical stripe just inside a tab / button frame; "interior L/R" = clear
columns between glyph ink and the button fill's edge. Missing-glyph check: 0 findings. No untranslated English
beyond glossary choices (SKIN, SAVE, TICKET, SLIME, INKKY, CHAMELEON, SLIMAKAZE, key names); all caps.

Summary: high 1, med 6, low 5 (+ 3 also en).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| descent-boon-card | title `ANDAR 1 CONCLUÍDO` | the Í acute is cut by the top screen edge: title ink starts on row 0 (en `FLOOR 1 CLEARED` starts on row 4, no marks); only the lower part of the accent is drawn. The card title has no accent top margin. | high | `scripts/ui/descent_card.gd`, `descent.floor_cleared` |
| hub-prompt-story, -wardrobe, -wheel | station pills `HISTÓRIA - NÍVEL 1`, `SKINS E CHAPÉUS`, `ROLETA DE CHAPÉUS GRÁTIS !` | the marks (Ó x 140, Í x 179, É x 188 / x 172) are on row 159, directly under the pill's dark band row 158: 0 px gap, the accent merges with the goo. en capitals start on row 162. The pill uses `panel_style()` without the accent rows buttons get. | med | `scripts/hub.gd` (prompt pill), `hub.station.story`, `hub.station.wardrobe`, `hub.station.wheel` |
| hat-wheel-shop | price `45` + ticket in every row | price caps on rows 69-75 / 87-93 / 105-111, item names on 72-78 / 90-96 / 108-114: price 3 px higher than its name and close under the row's top frame. en: both on 64-70 / 79-85. | med | `scripts/ui/hat_wheel.gd` (shop row price y) |
| settings | language button `PORTUGUÊS (BR)` | caps on rows 117-123 while the NÉVOA button beside it has 119-125 (2 px high); the Ê circumflex is on row 115, right under the frame's top highlight row 114 (0 px). en: both 101-107. | med | `scripts/ui/controls.gd:177-210` (language button `label.position`) |
| key-controls | action labels (`CIMA` ... `SLIMAKAZE`) | label caps rows 40-46 / 60-66 / 80-86, key-button text 42-48 / 62-68 / 82-88: labels 2 px higher than the key text on the same row. en: both 33-39 / 50-56. | med | `scripts/ui/key_controls.gd` |
| wardrobe-skins / -hats / -trails | page titles `SKINS` / `CHAPÉUS` / `RASTROS` | drawn in the 8 px font (step-1 fallback) while en uses the 16 px slimy title; looks like a caption, not a screen title. | med | `scripts/ui/skins_screen.gd` (`_layout` step 1) |
| upgrades-coins, upgrades-abilities | tab `MOEDAS` | ink ends x 44, right inset bar at x 45: the S touches the bar (0 px); en `COINS` keeps 1 px. | med | `scripts/ui/upgrades_screen.gd`, `upgrades.tab_coins` |
| hat-wheel-shop | section tabs `CHAPÉUS`, `RASTROS` | last letter touches the right inset bar (0-1 px); en `HATS` / `TRAILS` 2+ px. | low | `scripts/ui/hat_wheel.gd`, `wheel.section.hats`, `wheel.section.trails` |
| level-select-*, upgrades, wardrobe, settings, key-controls, language | BACK `VOLTAR` | interior 2 / 2 px (en BACK 7 / 6): V and R touch the inset bars. | low | `scripts/ui/ui_kit.gd` (back button), `common.back` |
| title | tagline `ESCAPE DA NÉVOA / OU SEQUE TENTANDO` | 7 px under ENTRAR NA BASE (en 13 px) and closer to HISTÓRIA than in en; slimes stay low beside line 1 (inner edge 7 px from the É). Slightly unbalanced. | low | `scripts/ui/title.gd:107-145` |
| key-controls, pause-descent | footer note `SETAS MOVEM ...`; note `SAIR SACA METADE DO POTE` | the key note starts 3 px under the last key row (en 27 px); the Descent note is 7 px under the pause panel (en 18 px). | low | `scripts/ui/key_controls.gd`, `scripts/ui/pause_menu.gd` |
| hub-resume | `CONTINUAR` / `ABANDONAR` | interior 4 / 3 and 3 / 2 px (en 9 / 8, 5 / 4): the words fill their buttons. | low | `scripts/hub.gd` |
| hub-coin-board | HUD pill over the board | also en: pill x 4-76 overlaps the board's frame (board x ~50). | med (also en) | `scripts/hub.gd` |
| upgrades-abilities | `ATIRA GOSMA`, `BOMBA 3X3`, `INVESTIDA` | also en: description drips touch the row's bottom goo. | low (also en) | `scripts/ui/upgrades_screen.gd` |
| result-dry-up | `AJUDA: +10% SLIME, SEM MEDALHAS/TICKETS` | also en: third line drips on the bottom goo. | low (also en) | `scripts/game.gd` |

Checked and clean: level select (paged 5 + arrows), HEAT panel (`NÉVOA VORAZ` 6 px clear), settings save code /
reset confirm, hub notice / portal / quit / resume, HUD states (`NÍVEL`, `PRÊMIO 1 TIX`), pause story / random,
restart, results (`CÁLICE DEVORADO!`), Descent summary, victory (`VOCÊ ESCAPOU!` row 4, clear), language.
