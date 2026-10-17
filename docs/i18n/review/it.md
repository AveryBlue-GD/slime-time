# Visual review: it (Italian)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are 320x180 frame
pixels (x, y). "Inset bar" = the light vertical stripe just inside a tab / button frame; "interior L/R" = clear
columns between glyph ink and the button fill's edge. Missing-glyph check: 0 findings. No untranslated English
beyond glossary choices (SKIN, SLIME, TICKET / TIX, INKKY, CHAMELEON, SLIMAKAZE, key names); all caps.

Summary: high 0, med 6, low 7 (+ 3 also en).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hat-wheel-wheel, hat-wheel-shop | tab `NEGOZIO` | the N touches the left inset bar and the O the right one (interior 2 / 1 px incl. bars at x 69-110); en `SHOP` 8 / 8 px. | med | `scripts/ui/hat_wheel.gd`, `wheel.tab.shop` |
| hub-prompt-random | station pill `MODALITÀ CASUALE` | the À grave (x 156) is on row 159, directly under the pill's dark band row 158: 0 px gap. en capitals start on row 162. | med | `scripts/hub.gd` (prompt pill `panel_style()`), `hub.station.random` |
| upgrades-coins, upgrades-abilities | title `POTENZIAMENTI` | drawn in the 8 px font between the tabs and the coin pill, while en `UPGRADES` uses the 16 px slimy title: mixed title fonts across screens. | med | `scripts/ui/upgrades_screen.gd`, `upgrades.title` |
| wardrobe-skins / -hats / -trails | page titles `SKIN` / `CAPPELLI` / `SCIE` | drawn in the 8 px font (step-1 fallback) while en uses the 16 px title. | med | `scripts/ui/skins_screen.gd` (`_layout` step 1) |
| key-controls | action labels (`SU` ... `SLIMAKAZE`) | label caps rows 40-46 / 60-66 / 80-86, key-button text 42-48 / 62-68 / 82-88: labels 2 px higher than the key text. en: both 33-39 / 50-56. | med | `scripts/ui/key_controls.gd` |
| settings | language button `ITALIANO` | caps on rows 117-123 while the NEBBIA button beside it has 119-125: 2 px high. en: both 101-107. | med | `scripts/ui/controls.gd:177-210` (language button `label.position`) |
| hat-wheel-wheel | title `RUOTA DEI CAPPELLI` | centred at x ~199 instead of 160 (pushed right by the wider RUOTA / NEGOZIO tabs); en, es, pt, de titles are centred. | low | `scripts/ui/hat_wheel.gd`, `hub.station.wheel` |
| hat-wheel-shop | section tab `CAPPELLI` | C and I touch the inset bars on both sides (0-1 px); en `HATS` 2+ px. | low | `scripts/ui/hat_wheel.gd`, `wheel.section.hats` |
| hud-l7-hard-heat-63 | level pill `LIVELLO 7/10  DIFFICILE` | the pill starts 5 px right of the timer pill (en: 39 px); the top row reads as one bar. | low | `scripts/hud.gd`, `hud.area.level_hard` |
| descent-boon-card | boon name `FIUTO DEL CALICE` | 3 px from the card's fill edge on each side (en names >= 10 px). | low | `scripts/ui/descent_card.gd`, `boon.sense.name` |
| level-select-hard, HUD | `CAL. 0` (HEAT button), `CAL. 10` (HUD pod) | abbreviated while the panel title says `CALORE`. | low | `levels.heat`, `hud.pod.heat` |
| title | tagline `FUGGI DALLA NEBBIA / O SECCA NEL TENTATIVO` | moved up to 5 px under ENTRA IN BASE (en 13 px) to clear STORIA, slimes jump to the button line; ~20 px empty under the tagline vs 5 px above. | low | `scripts/ui/title.gd:107-145` |
| pause-descent, hub-resume, key-controls | note `USCENDO INCASSI METÀ DELLA POSTA`; `ABBANDONA`; key note | Descent note 7 px under the pause panel (en 18 px); ABBANDONA interior 3 / 2 px (en QUIT RUN 5 / 4); key note 3 px under the last key row (en 27 px). | low | `scripts/ui/pause_menu.gd`, `scripts/hub.gd`, `scripts/ui/key_controls.gd` |
| hub-coin-board | HUD pill over the board | also en: pill x 4-76 overlaps the board's frame (board x ~53). | med (also en) | `scripts/hub.gd` |
| upgrades-abilities | `SPARA BAVA`, `BOMBA 3X3`, `SCATTO AL MURO` | also en: description drips touch the row's bottom goo. | low (also en) | `scripts/ui/upgrades_screen.gd` |
| result-dry-up | `AIUTO: +10% DI SLIME, NIENTE MEDAGLIE/TICKET` | also en: third line drips on the bottom goo. | low (also en) | `scripts/game.gd` |

Checked and clean: level select (paged), HEAT panel (two-line names, tiles grow), upgrades rows (`PIÙ SLIME`,
`VELOCITÀ`), settings save code / reset confirm, hub notice / portal / quit / resume, other hub prompts, HUD
L1 / L8 / L10 / randomizer / descent, pause story / random, restart (`RICOMINCIARE?`), results, Descent summary,
victory, language.
