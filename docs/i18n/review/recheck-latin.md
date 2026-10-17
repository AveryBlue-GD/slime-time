# Re-check after F1-F4 + leftovers: en, es, pt_BR, fr, it, de

Re-review of the fresh capture (`tools/i18n_capture.sh`, all 56 states incl. map-table / map-view, stable goo
lumps) against the rows in `en.md`, `es.md`, `pt_BR.md`, `fr.md`, `it.md`, `de.md`, the fix-pass notes
(`fixes-F1..F4.md`) and `leftovers.md`. The old capture was compared state by state. Most states differ from it
pixel by pixel because the goo lumps are now seeded from the tree, so changes were judged by measuring, not by
pixel diff.

Measurements are in 320x180 frame pixels. "L / R" = clear columns between glyph ink and the box's inner border
(dark-red inner edge; with the light inset bar counted as the border it is +1). For reference, English's tightest
text-sized buttons (RESET PROGRESS, QUIT RUN) are L4 R2 / L4 R3, and the translations' text-sized buttons now
sit at L3 R2 to L4 R3 (BUTTON_TEXT_PAD 5).

Capture logs, these six locales: 56 of 56 states each; 0 missing-glyph findings; goo-ink check 0 px on goo and
0 px in band / lump rows.

Story intro cards 0-4 still show no caption text in any locale (the frame is captured before the caption
types in), so the story captions are still not reviewable from the capture.

## en

| original row | state | status | evidence (new capture) |
|---|---|---|---|
| HUD pill over the COIN BAG board (med) | hub-coin-board | fixed | the ticket / chalice pod is hidden while the board is open (all 6 locales) |
| ability description drips touch the bottom goo (low) | upgrades-abilities | fixed | rows 33 px apart, goo-ink 0 |
| dry-up third line drips on the bottom goo (low) | result-dry-up | fixed | panel 44 tall, goo-ink 0 |
| PORTUGUÊS / TIẾNG VIỆT marks under the frame (low) | language | fixed | marks clear of the top band in every locale (goo-ink 0) |
| empty band under the wardrobe status lines (low) | wardrobe-hats / -trails | accepted (agree) | English layout left unchanged on purpose; not a defect |

New findings: none.

## es

| original row | state | status | evidence |
|---|---|---|---|
| tab MONEDAS S touches the bar (med) | upgrades-* | fixed | MONEDAS L3 R2 (was R0); en COINS L4 R3 |
| price 3 px above the name (med) | hat-wheel-shop | fixed | price and name ink both start on row 54 (first tile) |
| ESPAÑOL 2 px higher than NIEBLA (med) | settings | fixed | letter bodies both on rows 119-127; Ñ tilde from row 116, goo-ink 0 |
| action labels 2 px above the key text (med) | key-controls | fixed | ARRIBA and W both start on row 42 |
| wardrobe titles in the 8 px font (med) | wardrobe-* | fixed | 16 px slimy title on all three pages |
| RULETA / RASTROS touch the bars (low) | hat-wheel-* | fixed | RULETA L3 R2, RASTROS L3 R2 |
| NIEBLA VORAZ 1 px from the tile frame (low) | level-select-heat-panel | partly fixed, still open (low) | ink now ends on x 302, frame at 305: 2 clear columns (was 1). English names keep >= 5 |
| SALTAR (MANTÉN) 4 px from SPACE; footer note crowding (low) | key-controls | fixed | ~8 px from the label to the SPACE key (leftovers); footer note 9 rows under the last key row |
| tagline lifted 5 px (low) | title | accepted (agree) | the second line is wider than the room beside HISTORIA; documented fit (F3b) |
| pause note 7 px under the panel (low) | pause-descent | still there (low) | 5 clear rows from the panel's lumps (row 151) to the note (row 157); en 16. No pass touched `pause_menu.gd` for this |
| CONTINUAR / ABANDONAR / OTRO DESCENSO / PANTALLA COMPLETA fill their buttons (low) | hub-resume, descent-summary, settings | fixed | CONTINUAR L4 R3, ABANDONAR L3 R2 (was L2 R1), OTRO DESCENSO L3 R2, PANTALLA COMPLETA: NO L3 R2 (was L2 R1) |
| ATRÁS tight, Á under the frame (low) | level select, upgrades, wardrobe, settings | fixed | L3 R2 (BACK width from `button_w`), goo-ink 0 |
| HUD pill over the board (also en) | hub-coin-board | fixed | see en |
| ability description drips (also en) | upgrades-abilities | fixed | see en |
| dry-up third line (also en) | result-dry-up | fixed | see en |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| hub-notice | `MEJORAS RENOVADAS` / `MONEDAS DEVUELTAS +888` | new since the old capture: the notice now has 3 lines (`MONEDAS` alone on line 2, `DEVUELTAS +888` on line 3), box x 103-216, rows 10-61 (was 2 lines, x 89-230). This follows from F3a's symmetric room between the stations (2 x min(left, right) = ~136 px). It reads fine, but it is taller and less tidy than English's 2 lines. A room measured per side, or a one-line `MONEDAS +888`, would keep 2 lines | low | `scripts/hub.gd` `_fit_tree_notice`, `hub.notice.returned` |

## pt_BR

| original row | state | status | evidence |
|---|---|---|---|
| title `ANDAR 1 CONCLUÍDO` Í cut by the screen edge (high) | descent-boon-card | fixed | title ink from row 4 (accent included), as English |
| station pill marks merge with the band (med) | hub-prompt-story / -wardrobe / -wheel | fixed | accented pills grow; goo-ink 0 |
| price 3 px above the name (med) | hat-wheel-shop | fixed | both start on row 54 |
| PORTUGUÊS (BR) 2 px high, Ê on the frame (med) | settings | fixed | bodies level with NÉVOA (rows 119-127), Ê from 116, goo-ink 0 |
| key labels 2 px high (med) | key-controls | fixed | both on row 42 |
| wardrobe titles in the 8 px font (med) | wardrobe-* | fixed | 16 px title |
| tab MOEDAS touches the bar (med) | upgrades-* | fixed | L3 R2 |
| section tabs CHAPÉUS / RASTROS touch the bar (low) | hat-wheel-shop | fixed | L3 R2 to the inner border (L4 R2 / L4 R3 to the inset bar) |
| VOLTAR touches the bars (low) | many | fixed | L3 R2 |
| tagline 7 px under ENTER (low) | title | accepted (agree) | documented fit |
| key note 3 px under the rows; Descent note 7 px under the pause panel (low) | key-controls, pause-descent | key note fixed; pause note still there (low) | key note 9 rows under the rows; pause note 5 clear rows under the panel (en 16) |
| CONTINUAR / ABANDONAR fill their buttons (low) | hub-resume | fixed | L4 R3 / L3 R2 |
| HUD pill over the board (also en) | hub-coin-board | fixed | |
| ability description drips (also en) | upgrades-abilities | fixed | |
| dry-up third line (also en) | result-dry-up | fixed | |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| hub-notice | `MOEDAS` / `DEVOLVIDAS +888` | 3 lines instead of 2, same cause as es | low | `scripts/hub.gd` `_fit_tree_notice` |
| result-randomizer-win | result panel vs the player slime | new since the old capture: the randomizer level pod now wraps (`LABIRINTO` / `ALEATÓRIO #1`), which pushes the pods and the panel ~6 px lower than es. The slime's top half now shows above the panel and sits on its top frame (es shows only a sliver; in English the panel hides it) | low | `scripts/hud.gd` (result panel top from the pod stack) |

## fr

| original row | state | status | evidence |
|---|---|---|---|
| title `ÉTAGE 1 TERMINÉ` accents cut (high) | descent-boon-card | fixed | title ink from row 4, both É whole |
| tab BOUTIQUE touches both bars (med) | hat-wheel-* | fixed | L4 R3 |
| TOURNER  GRATUIT T touches the bar (med) | hat-wheel-wheel | fixed | L3 R2 (button x 112-207) |
| station pill marks on the band (med) | hub-prompt-upgrades / -settings / -random / -wheel | fixed | goo-ink 0, accented pills taller |
| AMÉLIORATIONS title in the 8 px font (med) | upgrades-* | fixed | 16 px; centred at ~180, GAP_L clear of the tabs (by design), 30 px clear of the coin pod |
| wardrobe titles in the 8 px font (med) | wardrobe-* | fixed | 16 px |
| FRANÇAIS 2 px high (med) | settings | fixed | bodies on rows 119-127 for both buttons |
| key labels 2 px high (med) | key-controls | fixed | both on row 42 |
| wheel title centred at x ~204 (low) | hat-wheel-wheel | partly fixed, accepted (agree) | starts GAP_L after BOUTIQUE (centre ~179); a centred title would overlap the tabs |
| HEAT icons dropped to 1x (low) | level-select-heat-panel | fixed | 6 icons at 2x, LA BRUME MORD on two lines |
| SAUT (MAINTENIR) 4 px from SPACE; footer note on the rows (low) | key-controls | fixed | label to key ~7 px; note marks 8 rows under the key rows |
| `CHAL.` abbreviation (low) | level-select-hard, HUD | accepted (agree) | terminology for a native reviewer (F4); legible |
| RETOUR touches the bars (low) | many | fixed | L3 R2 |
| tagline lifted (low) | title | accepted (agree) | documented fit |
| pause note 7 px; ABANDONNER / NOUVELLE PARTIE fill their buttons (low) | pause-descent, hub-resume, descent-summary | buttons fixed; pause note still there (low) | ABANDONNER L3 R2 (was L2 R1), NOUVELLE PARTIE L3 R3; note 5 clear rows under the panel (en 16) |
| HUD pill over the board (also en) | hub-coin-board | fixed | |
| ability description drips (also en) | upgrades-abilities | fixed | |
| dry-up third line (also en; line spans x 37-301) | result-dry-up | fixed; span accepted (agree) | drips 2 rows clear; the width is inside REWARDS_W |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| map-table | tile name `SANCTUAIRE DE SABLE` (row 3, left) | ink ends on x 154. The tile's light inset bar is on x 156, so 1 clear column (2 to the dark edge). English's longest name (OBSIDIAN OUBLIETTE) keeps 9. The name fits on one line by 1 px, while CATACOMBES GLAUQUES next to it wraps. The same in the old capture, but not reviewed before (maps were with another reviewer) | low | `scripts/ui/map_select.gd` (tile name wrap threshold: keep BUTTON_TEXT_PAD / GAP_S before the inset), `level.3.name` |
| hub-notice | `AMÉLIORATIONS` / `REVUES` / `PIÈCES RENDUES +888` | 3 lines instead of 2 (the title phrase is now split), same cause as es | low | `scripts/hub.gd` `_fit_tree_notice` |

## it

| original row | state | status | evidence |
|---|---|---|---|
| tab NEGOZIO touches both bars (med) | hat-wheel-* | fixed | L3 R2 |
| `MODALITÀ CASUALE` À on the band (med) | hub-prompt-random | fixed | pill taller, goo-ink 0 |
| POTENZIAMENTI in the 8 px font (med) | upgrades-* | fixed | 16 px, centred at ~180 (by design) |
| wardrobe titles in the 8 px font (med) | wardrobe-* | fixed | 16 px (`SKIN` / `CAPPELLI` / `SCIE`) |
| key labels 2 px high (med) | key-controls | fixed | both on row 42 |
| ITALIANO 2 px high (med) | settings | fixed | bodies on rows 119-127 |
| wheel title centred at x ~199 (low) | hat-wheel-wheel | partly fixed, accepted (agree) | GAP_L after NEGOZIO (centre ~174) |
| section tab CAPPELLI touches the bars (low) | hat-wheel-shop | fixed | L3 R2 to the inner border |
| level pill 5 px from the timer (low) | hud-l7-hard-heat-63 | fixed | `LIVELLO 7/10` / `DIFFICILE` on two lines, clear of the timer |
| FIUTO DEL CALICE 3 px from the card edge (low) | descent-boon-card | fixed | wraps to `FIUTO DEL` / `CALICE`, 8 px side room |
| `CAL.` abbreviation (low) | level-select-hard, HUD | accepted (agree) | as fr |
| tagline lifted (low) | title | accepted (agree) | documented fit |
| pause note 7 px; ABBANDONA fills; key note 3 px (low) | pause-descent, hub-resume, key-controls | ABBANDONA and key note fixed; pause note still there (low) | ABBANDONA L3 R2; key note 9 rows under the rows; pause note 5 clear rows (en 16) |
| HUD pill over the board (also en) | hub-coin-board | fixed | |
| ability description drips (also en) | upgrades-abilities | fixed | |
| dry-up third line (also en) | result-dry-up | fixed | |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| hub-notice | `POTENZIAMENTI` / `RIVISTI` / `MONETE RESE +888` | 3 lines instead of 2, same cause as es | low | `scripts/hub.gd` `_fit_tree_notice` |

## de

| original row | state | status | evidence |
|---|---|---|---|
| tab MÜNZEN N touches the bar (med) | upgrades-* | fixed | ink x 10-44, bars at 6 / 47: L3 R2 (was R0) |
| Ü dots touch the pill drips (med) | hub-prompt-coins / -wardrobe | fixed | pills taller, goo-ink 0 |
| price 3 px above the name (med) | hat-wheel-shop | fixed | both start on row 54 |
| wardrobe titles in the 8 px font (med) | wardrobe-* | fixed | 16 px |
| key labels 2 px high (med) | key-controls | fixed | both on row 42 |
| DEUTSCH 2 px high (med) | settings | fixed | bodies on rows 119-126 / 119-127 |
| LAUTSTÄRKE leaves a short slider (low) | settings, pause-* | still there (low) | track x 108-148 = 41 px vs English VOLUME 84-150 = 67 px. No pass addressed it |
| SPRUNG (HALTEN) 4 px from SPACE; footer note (low) | key-controls | fixed | label to key ~8 px; note 9 rows under the rows |
| GIERIGER GLIBBER 3 px from the card edge (low) | descent-boon-card | fixed | wraps to two lines, 8 px side room |
| ZURÜCK touches the bars (low) | many | fixed | L3 R2 |
| `STORY` / `LEVEL` / `SHOP` kept in English (low) | title, hub-prompt-story, hub-coin-board, hat wheel | still there (low, owner decision) | unchanged. No fix pass or leftover line says whether the glossary choice is confirmed |
| pause note 7 px (low) | pause-descent | still there (low) | 5 clear rows under the panel (en 16) |
| HUD pill over the board (also en) | hub-coin-board | fixed | |
| ability description drips (also en) | upgrades-abilities | fixed | |
| dry-up third line (also en) | result-dry-up | fixed | |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| hub-notice | `UPGRADES` / `ÜBERARBEITET` / `MÜNZEN ZURÜCK +888` | 3 lines instead of 2, same cause as es | low | `scripts/hub.gd` `_fit_tree_notice` |

## Checked, nothing new

title, level select (normal / hard / HEAT panel), upgrades coins / abilities, wardrobe (3 pages), settings, reset
confirm, save code, key controls, language, hub and all 9 prompts, coin board, portal, quit, resume, every HUD
state, pause (3), restart, results (win L3 / L10, dry-up, randomizer), Descent boon card and summary, victory,
hat wheel (wheel / shop), map-table, map-view. All text-sized buttons and tabs in these locales measure at least
L3 R2. The goo-ink gate is clean for all six locales.
