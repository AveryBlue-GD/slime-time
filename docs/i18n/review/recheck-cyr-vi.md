# Re-check after F1-F4 + leftovers: ru, pl, tr, vi, id, pseudo

Fresh captures of all 56 states (map-table and map-view included) per locale, compared with `en` and with the
first-round captures. Coordinates are 320x180 frame pixels (x, y). "Clear" = columns / rows with no ink between
glyph ink (its drop shadow counted as ink) and a frame's inner orange stripe. Every locale: 56 of 56 states
captured, 0 missing glyphs, goo-ink gate 0 px in every state (`json/goo_ink_<locale>.json` empty).

Status words: **fixed** = gone in the new capture (measured); **accepted** = left on purpose in leftovers.md / a
fix pass, with my verdict on the reason; **still there** = visible and not accepted.

## ru

| original row (state / element) | status | measured now |
|---|---|---|
| hub-prompt-random / -settings: Й breve under the pill band (med) | fixed (F1) | pills taller, marks start on row 6 like English capitals; 0 goo-ink px |
| key-controls: labels 2 px above key text (med) | fixed (F3b) | label / key ink rows start together: 42 / 62 / 82 / 102 / 122 on both |
| settings: `● РУССКИЙ` 2 px above the pitch (med) | fixed (F3b) | rows 119-127 in both columns (pitch 50 / 73 / 96 / 119) |
| wardrobe-*: 8 px titles (med) | fixed (F3a) | СКИНЫ / ШЛЯПЫ / СЛЕДЫ in the 16 px title font |
| upgrades-*: title crowding the БИЛЕТЫ tab (low) | fixed (F3a) | tab outline ends x 103, title ink from x 113: 9 clear columns |
| upgrades tab МОНЕТЫ touching the stripe (low) | fixed (F1) | stripes x 6 / 48, ink 10-44: 3 clear left, 2 right of the shadow |
| hat-wheel tab КОЛЕСО (low) | fixed (F1) | stripe x 18 / 60, ink 22-56: 3 / 2 clear |
| hat-wheel-shop: КЕПКА С ПРОПЕЛЛЕРОМ 3 px from its price (low) | fixed (leftovers) | `КЕПКА-ПРОПЕЛЛЕР`, 22 clear columns to the price |
| descent-boon-card: title Й on screen rows 0-1 (low) | fixed (F2) | first title ink row 4, as English |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| map-table (page 1) | tile `ПЕСЧАНОЕ СВЯТИЛИЩЕ` | name ink ends x 153, shadow x 154, tile stripe x 156: 1 clear column (en's tightest name, OBSIDIAN OUBLIETTE / SANDSTONE SANCTUM, keeps 8; pl 8, tr 14). The name only wraps when it is wider than the box, so it is drawn flush against the frame instead of on two lines like `КОШМАРНЫЕ / КАТАКОМБЫ`. | low | `scripts/ui/map_select.gd` (tile name width / wrap threshold) |

## pl

| original row | status | measured now |
|---|---|---|
| hub pills WYJŚCIE / STÓŁ MAP / SKÓRKI I CZAPKI acutes on the band (med) | fixed (F1) | pill T6, 0 goo-ink px |
| hat-wheel-shop price 3 px above the name (med) | fixed (F3a) | price rows on the name's rows (54-60 on 54-61) |
| level-select-heat-panel icons at 1x (med) | fixed (F3a) | 6 x 2x icons, GRYZĄCA / MGŁA on two lines |
| key-controls labels 2 px above keys (med) | fixed (F3b) | rows start together (42 / 62 / 82 / 102 / 122) |
| settings `● POLSKI` 2 px high (med) | fixed (F3b) | 119-126 in the right column, 119-127 left |
| upgrades title ULEPSZENIA 8 px (med) | fixed (F3a) | 16 px title |
| wardrobe titles 8 px (med) | fixed (F3a) | SKÓRKI / CZAPKI / ŚLADY 16 px |
| descent-boon-card `ZUŻYWAJĄ SZLAMU` 0 px from the stripe (low) | fixed (F2) | wraps to `ZUŻYWAJĄ / SZLAMU`, >= 4 px inside the tile; see the new 1x-icon finding it caused |
| hud-l7 name in the HEAT pod's row (low) | fixed (F2) | name under the pods |
| restart-prompt title 6 px from the KOMPLET pill (low) | not an error | geometry unchanged from round 1: title ink x 75-244, dimmed pill from x 257, 12 clear columns (more than GAP_L) |
| wardrobe-trails `(NA GŁOWIE)` for a trail (low) | fixed (F4) | `(W UŻYCIU)` |
| tabs MONETY / CZAPKI / SKÓRKI touching the stripe (low) | fixed (F1) | L6 R5 boxes, as English |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| descent-boon-card | the three boon icons | icons now drawn at 1x (about 6 px; chalice rows 54-59) above the names, where round 1 and en / ru / tr / id draw them at 2x. The F2 side room wraps `NOS DO / KIELICHA / WIDZISZ / WYJŚCIE / Z 6 PÓL` onto 5 lines and the tile then falls back to the small icon (last drips row 121, band row 124). Regression from F2; the same pattern as the HEAT-panel 1x icons fixed in F3a. | med | `scripts/ui/descent_card.gd` (boon tile icon scale fallback) |
| map-view | title `PIASKOWA ŚWIĄTYNIA` | the Ś acute is on screen rows 0-1 (en's capitals start row 3): no top margin, cut by any top safe-area crop. `view_title_y()` is `max(3, 1 + accent_room())`, so an accented line keeps English's y and its marks go above it. | low | `scripts/ui/map_select.gd:396` (`view_title_y`) |

## tr

| original row | status | measured now |
|---|---|---|
| hub pills: İ dot and Ç / Ş cedillas on the bands (med) | fixed (F1) | pills taller, 0 goo-ink px; SİKKE KESESİ, ŞAPKA ÇARKI, ÇIKIŞ clear of both bands |
| hat-wheel-shop price above the name (med) | fixed (F3a) | 54-60 on the name's 54-61 |
| key-controls labels 2 px above keys (med) | fixed (F3b) | rows start together |
| settings `● TÜRKÇE` 2 px high (med) | fixed (F3b) | 119-127 both columns |
| upgrades title GELİŞTİRMELER 8 px (med) | fixed (F3a) | 16 px title, centre moved right of the tabs |
| wardrobe titles KILIK / ŞAPKA / İZLER 8 px (med) | fixed (F3a) | 16 px |
| title corner button HİKAYE 2 / 1 (low) | fixed (F1) | L6 R5, as English |
| hat-wheel tab DÜKKAN 3 / 1 (low) | fixed (F1) | ink x 70-104 between band x 66 and stripe x 107: 3 / 2 clear |

Turkish casing re-read in every state: İ / I correct everywhere (SİKKE, ÇIKIŞ, GERİ, İPTAL, RASTGELE, HEPSİ VAR,
SEVİYE, ŞAPKA ÇARKI, KADEH YUTULDU), no lower-case leaks, no untranslated text.

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| map-view | title `KUMTAŞI MABEDİ` | the İ dot is on screen row 1 (en capitals from row 3); same cause as pl. | low | `scripts/ui/map_select.gd:396` |

## vi

| original row | status | measured now |
|---|---|---|
| hub-prompt-* marks inside the pill band (high) | fixed (F1) | pills T6 (99x23), 0 goo-ink px in all 9 |
| result-win-l3 / -l10 first-line marks on the lump row (high) | fixed (F2) | first line 4 rows lower, marks 1 row under the lumps |
| descent-summary Ầ on a lump (med) | fixed (F2) | panel 4 rows taller, 0 goo-ink px |
| hud-randomizer name over the slime (med) | fixed (F2) | `- ĐỀN CHÌM -` line top 30, clear of the slime |
| hat-wheel-shop price above the name (med) | fixed (F3a) | 60-66 on name body 60 |
| key-controls labels 3 px above keys (med) | fixed (F3b) | label / key rows start together (43 / 64 / 85 / 106 / 127) |
| settings `● TIẾNG VIỆT` 3 px high (med) | fixed (F3b) | body 131-139 in both columns |
| wardrobe titles 8 px, JELLY moved top-left (med) | titles fixed (F3a); JELLY accepted | 16 px SKIN / MŨ / VỆT. JELLY top left: leftovers "the layout every accented locale shares" - agree, ru / pl / tr use the same corner and it mirrors the upgrades tabs |
| hub-portal Ẫ 1 px under the band (low) | fixed (F1) | dialog text from `panel_text_top()`, 0 band px |
| hub-coin-board `1NGỤC` 3 px gap (low) | fixed (F1) | BOARD_NAME_GAP 6 |
| upgrades-abilities hint on the bottom row beside VỀ (low) | accepted (leftovers) | centred, 20 clear columns from BACK; agree - it is what keeps the three rows on one page |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| descent-boon-card | the three boon icons | icons drawn at 1x (round 1: 2x) because `THÂN CAO SU / VA TƯỜNG / KHÔNG TỐN / SLIME` now takes 4 lines in the 8 px side room; same regression as pl. | med | `scripts/ui/descent_card.gd` |
| map-view | the map | parchment 201 x 126 (x 59-259, y 23-148) vs 227 x 142 in en / ru / pl / tr / id / pseudo: the taller vi title line costs the map 11 % of its size, although the line needs only ~5 more rows. Unchanged since round 1 (not a regression), but visibly worse than English. | low | `scripts/ui/map_select.gd` (`view_map_area`) |

## id

| original row | status | measured now |
|---|---|---|
| title corner button CERITA 2 / 1 (low) | fixed (F1) | frame x 4-49, ink 10-42: 4 / 5 clear |
| result-win-l3 `LEVEL BERIKUT` filling the button (low) | fixed (F1 pad) | stripe x 117 / 199, ink 124-194: 6 / 3 clear (round 1: 2 / 2) |
| result-win-l3 `EMAS  REKOR BARU!` 3 px from the stripe (low) | accepted (F2, leftovers) | ink to x 225, shadow 226, stripe 230: 3 clear. Agree: inside REWARDS_W and the >= 2 px rule |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| descent-boon-card | tile 3 `+1 TIKET/LANTAI`, tile 1 `TAK MAKAN SLIME` | the wider side room now breaks `+1 TIKET/` / `LANTAI` at the slash (one unit split over two lines; en `+1 TIX/FLOOR` is one line) and wraps tile 1 to 4 lines; icons stay 2x. Readable, but the slash break reads as a typo. | low | `scripts/ui/descent_card.gd` (wrap; or a shorter `boon.greedy_goo.desc`) |

## pseudo

| original row | status | measured now |
|---|---|---|
| descent-summary rewards line past both borders (high) | fixed (F2) | panel widens to the line + 8 px each side |
| descent-boon-card fallback: icon top-left, text top-anchored, empty bottom (med) | partly fixed (F2) | right-stripe touch gone, marks off the goo; icons still 1x in the top-left corner and tile 3 leaves ~13 empty rows under its text. F2 calls the one-row start "by design"; I accept it for pseudo only, but pl / vi now hit the same 1x fallback (new findings there). Still open as low. |
| hub-prompt-* marks on the band (med) | fixed (F1) | T6, 0 goo-ink px |
| hud-l8-assisted / hud-l10 story line over the slime (med) | fixed (F2) | lines clear of the slime |
| hud-l1 name 2 px from the ALL FOUND pill (low) | fixed (F2) | name under the pod (line top 44) |
| restart-prompt title 2 px from the ALL FOUND pill (low) | still there | title ink x 95-224, dimmed pill frame from x 228 on the same rows: 3 clear columns. Not in any fix pass or leftovers. |
| hat-wheel-wheel SPIN acute on the top band (low) | fixed (F1) | 0 goo-ink px |
| 8 px fallback titles (low) | partly fixed | upgrades and wardrobe now 16 px; settings-save-code `[_ŚÁVÉ ÇÖĐÉ_]` and settings-reset-confirm `[___ÉRÁŚÉ ÁŁŁ PRÖĞRÉŚŚ?___]` still in the 8 px font (pseudo only; ru / pl / tr / vi keep 16 px there) |
| hub-notice covering cabinet and chair (low) | fixed (F3a) | box (100, 8) 120x57, clear of the side props |

New findings:

| state | element | problem | severity | suspected file |
|---|---|---|---|---|
| map-view | title `[__ŚÁŃĐŚTÖŃÉ ŚÁŃÇTÚM___]` | marks on screen row 0, same cause as pl. | low | `scripts/ui/map_select.gd:396` |
| upgrades-coins | footer note | breaks `...ÍŃ THÉ ŚTÖRÝ` / `MÁŽÉŚ________]`: a one-word orphan line between the two notes (3 lines total), the bracket padding pushed the last word over. Pseudo-only stress, but shows the note has no balanced break. | low | `scripts/ui/upgrades_screen.gd` (coins note wrap) |

## Counts

| locale | original rows | fixed | accepted (agree) / not an error | still open | new |
|---|---|---|---|---|---|
| ru | 9 | 9 | 0 | 0 | low 1 |
| pl | 12 | 11 | 1 not an error | 0 | med 1, low 1 |
| tr | 8 | 8 | 0 | 0 | low 1 |
| vi | 11 | 9 (+ titles of the wardrobe row) | 2 (JELLY corner, ABILITIES hint) | 0 | med 1, low 1 |
| id | 3 | 2 | 1 (REKOR BARU) | 0 | low 1 |
| pseudo | 9 | 6 | 0 | low 3 (boon fallback remainder, restart pill 3 px, save-code / reset titles 8 px) | low 2 |

No regressions in the other states against round 1 (HUD, hub, results, pause, Descent summary, level select, HEAT
panel, settings, language, victory, story cards): every difference is a listed fix or the capture's new stable goo
lumps. The one regression is the 1x boon icons in pl and vi (F2 side room).
