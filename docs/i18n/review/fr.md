# Visual review: fr (French)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180), compared with `en` pixel by pixel. Coordinates are 320x180 frame
pixels (x, y). "Inset bar" = the light vertical stripe just inside a tab / button frame; "interior L/R" = clear
columns between glyph ink and the button fill's edge. Missing-glyph check: 0 findings. No untranslated English
beyond glossary choices (SKIN, SLIME, TICKET, INKKY, CHAMELEON, SLIMAKAZE, key names); all caps, U+202F before
`! ? :` rendered as a 2 px gap everywhere it is used.

Summary: high 1, med 7, low 7 (+ 3 also en).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| descent-boon-card | title `ÉTAGE 1 TERMINÉ` | both É acutes are cut by the top screen edge: title ink starts on row 0 (en `FLOOR 1 CLEARED` starts on row 4); only 1-2 px of each accent survive. The card title has no accent top margin. | high | `scripts/ui/descent_card.gd`, `descent.floor_cleared` |
| hat-wheel-wheel, hat-wheel-shop | tab `BOUTIQUE` | the B touches the left inset bar and the E the right one (0 px each side; interior x 74-123 incl. bars); en `SHOP` 8 / 8 px. | med | `scripts/ui/hat_wheel.gd`, `wheel.tab.shop` |
| hat-wheel-wheel | button `TOURNER  GRATUIT` | the button grows to x 113-206 (en 120-199) and the last T touches the right inset bar (0 px), left 1 px; en `SPIN  FREE` 14 / 13 px. | med | `scripts/ui/hat_wheel.gd`, `wheel.spin_free` |
| hub-prompt-upgrades, -settings, -random, -wheel | station pills `AMÉLIORATIONS`, `RÉGLAGES`, `MODE ALÉATOIRE`, `ROUE À CHAPEAUX GRATUIT !` | the É / À marks (x 139, 146, 164, 121) are on row 159, directly under the pill's dark band row 158: 0 px gap, the accent merges with the goo. en capitals start on row 162. | med | `scripts/hub.gd` (prompt pill `panel_style()`), `hub.station.*` |
| upgrades-coins, upgrades-abilities | title `AMÉLIORATIONS` | drawn in the 8 px font between the tabs and the coin pill, while en `UPGRADES` (and es / pt / de) use the 16 px slimy title: mixed title fonts across screens. | med | `scripts/ui/upgrades_screen.gd`, `upgrades.title` |
| wardrobe-skins / -hats / -trails | page titles `SKINS` / `CHAPEAUX` / `TRACES` | drawn in the 8 px font (step-1 fallback) while en uses the 16 px title. | med | `scripts/ui/skins_screen.gd` (`_layout` step 1) |
| settings | language button `FRANÇAIS` | caps on rows 117-123 while the BRUME button beside it has 119-125: 2 px high. en: both 101-107. | med | `scripts/ui/controls.gd:177-210` (language button `label.position`) |
| key-controls | action labels (`HAUT` ... `SLIMAKAZE`) | label caps rows 40-46 / 60-66 / 80-86, key-button text 42-48 / 62-68 / 82-88: labels 2 px higher than the key text. en: both 33-39 / 50-56. | med | `scripts/ui/key_controls.gd` |
| hat-wheel-wheel | title `ROUE À CHAPEAUX` | centred at x ~204 instead of 160 (pushed right by the wider ROUE / BOUTIQUE tabs); en, es, pt, de titles are centred. | low | `scripts/ui/hat_wheel.gd`, `hub.station.wheel` |
| level-select-heat-panel | modifier icons | the six icons drop to 1x (9 px) because `CLOUÉ AU SOL` / `LA BRUME MORD` are too long for the 2x layout; every other locale keeps the 2x icons, so the French panel looks emptier. `LA BRUME MORD` still ends 4 px from the tile frame. | low | `scripts/ui/heat_panel.gd` (`icon_scale` fallback), `heatmod.*.name` |
| key-controls | `SAUT (MAINTENIR)` and the footer note | label ends x 89, SPACE box starts x 94 (4 px; en 28 px); the note `FLÈCHES ACTIVES - ESC OU P : PAUSE - F11 : PLEIN ÉCRAN` starts right under the last key row (0-3 px, en 27 px). | low | `scripts/ui/key_controls.gd`, `keys.jump`, `keys.note.*` |
| level-select-hard, HUD | `CHAL. 0` (HEAT button), `CHAL. 10` (HUD pod) | abbreviated while the panel title and info lines say `CHALEUR`; reads as a different word. | low | `levels.heat`, `hud.pod.heat` |
| level-select-*, upgrades, wardrobe, settings, key-controls | BACK `RETOUR` | interior 2 / 2 px (en BACK 7 / 6): R touches both inset bars. | low | `scripts/ui/ui_kit.gd` (back button), `common.back` |
| title | tagline `FUIS LA BRUME / OU SÈCHE EN ESSAYANT` | moved up to 5 px under ENTRER AU QG (en 13 px) to clear HISTOIRE, slimes jump to the button line; more space under the tagline than above. | low | `scripts/ui/title.gd:107-145` |
| pause-descent, hub-resume, descent-summary | note `QUITTER ENCAISSE LA MOITIÉ DU POT`; `ABANDONNER`; `NOUVELLE PARTIE` | note 7 px under the pause panel (en 18 px); the two buttons fill their boxes (interior 3 / 2 px, en 5 / 4 and 21 / 20). | low | `scripts/ui/pause_menu.gd`, `scripts/hub.gd`, `scripts/descent.gd` |
| hub-coin-board | HUD pill over the board | also en: pill x 4-76 overlaps the board's frame (board x ~50). | med (also en) | `scripts/hub.gd` |
| upgrades-abilities | `TIRE DE LA BAVE`, `BOMBE 3X3`, `FONCE AU MUR` | also en: description drips touch the row's bottom goo. | low (also en) | `scripts/ui/upgrades_screen.gd` |
| result-dry-up | `AIDE : +10% DE SLIME, SANS MÉDAILLES/TICKETS` | also en: third line drips on the bottom goo; the line also spans x 37-301 of the panel (6 px each side). | low (also en) | `scripts/game.gd` |

Checked and clean: level select (paged, `DIFFICILE : ...` checkbox 4 px from the right goo), reset confirm
(`TOUT EFFACER ?`), save code, hub notice / portal / quit / resume, HUD states, pause story / random, restart
(`RECOMMENCER ?`), results win / randomizer, victory (`TU T'ES ÉCHAPPÉ !` row 4, clear), language.
