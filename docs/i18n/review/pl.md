# Visual review: pl (Polish)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer), compared
with `en`. Coordinates are 320x180 frame pixels. "Ink gap" = clear pixels between glyph ink (with its
drop shadow) and a goo frame's inner orange stripe. Missing-glyph check: 0 findings.

Summary: high 0, med 7, low 5. No clipped text; `INTRO` on the title is the glossary choice (pl.md: STORY / FABUŁA does not fit).

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hub-prompt-quit, hub-prompt-maps, hub-prompt-wardrobe | station pill `WYJŚCIE`, `STÓŁ MAP`, `SKÓRKI I CZAPKI` | the acute over Ś / Ó sits on row 159 directly under the pill's goo band (row 158), merging with a lump at (161-162,159), (153,159), (136,159). The pill has no accent rows. | med | `scripts/hub.gd:411` (prompt `panel_style()`), `hub.station.*` |
| hat-wheel-shop | every row: name vs price `45` + ticket | price digits and ticket icon sit 3 px above the name: name body rows 54-61, price 51-57 (row 1). In en both are 49-56. | med | `scripts/ui/hat_wheel.gd` (shop tile price label / icon y) |
| level-select-heat-panel | the six modifier icons | the icons drop to 1x (about 6 px; moon at x 18-23) while en / ru / tr draw them at 2x. The cause is the long names (`GRYZĄCA MGŁA`, `UZIEMIENIE`, `PRAGNIENIE`). The panel looks emptier and worse than English; ru wraps the name onto 2 lines instead. | med | `scripts/ui/heat_panel.gd:161-172` (icon_scale fallback), `heat.mod.*` |
| key-controls | action labels (W GÓRĘ ... SLIMAKAZE) | label body 2 px above the key text (e.g. `W LEWO` rows 80-86 vs key `A` 82-88; en aligned 67-73 / 67-73). | med | `scripts/ui/key_controls.gd` |
| settings | `● POLSKI` | text body on rows 117-123, 2 px above the column pitch (50 / 73 / 96 -> 119). In en the pitch is even. | med | `scripts/ui/controls.gd:177-198` |
| upgrades-coins, upgrades-abilities | title `ULEPSZENIA` | falls back to the 8 px font (x ~132-190, y 12-19); en has the 16 px title. Reads as a label floating between tabs and the coin counter. | med | `scripts/ui/upgrades_screen.gd` (fit_text fallback) |
| wardrobe-skins, -hats, -trails | titles SKÓRKI / CZAPKI / ŚLADY | 8 px fallback instead of the 16 px title. | med | `scripts/ui/skins_screen.gd` |
| descent-boon-card | card 1 `ZUŻYWAJĄ SZLAMU` | ink spans x 15-101 with its shadow on x 102 and the dashed stripe on x 103: 0 px clear on the right, 2 px on the left. en `SPLATS COST` has 15+ px each side. | low | `scripts/ui/descent_card.gd`, `boon.rubber_body.desc` |
| hud-l7-hard-heat-63 | level name `- LODOWA TWIERDZA -` and HEAT pill | the name moves up into the pill row (y 26-35); its right dash ends at x ~210 and the pill frame starts at x 214: 4 px gap. en keeps the name on its own row below. | low | `scripts/hud.gd` |
| restart-prompt | title `ZACZĄĆ OD NOWA?` | 16 px title on rows 28-46 runs to x ~245, 6 px from the dimmed `KOMPLET` pill (x 258), same rows. | low | `scripts/ui/restart_prompt.gd` |
| wardrobe-trails | `MAŹ SKÓRKI  (NA GŁOWIE)` | the shared key `skins.wearing` says "on the head" for a trail (and a skin). Text issue, visible on screen. | low | `locale/pl.po` `skins.wearing` |
| upgrades tabs, wardrobe page button | `MONETY` (x 9-43), `CZAPKI` / `SKÓRKI` (x 279-311) | ink gap 2-3 px left / 1 px right vs en 4-7 / 3-5. The last letter touches the stripe. | low | `UIKit.tab_widths` / `button_w` callers |

Checked and clean: title, level select (5 per page + arrows), upgrade rows, pause (3), results (last line 7 / 5 like en), NOWA WYPRAWA (5 / 4), Descent summary, hub overlays, coin board, HUD, language, save code, reset, victory, story cards.
