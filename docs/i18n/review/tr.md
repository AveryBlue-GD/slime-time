# Visual review: tr (Turkish)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer), compared
with `en`. Coordinates are 320x180 frame pixels. Casing check: every İ / I is right (SİKKE, BİLET,
HİKAYE, ÇIKIŞ, KILIK, SEVİYE, GELİŞTİRMELER, %100 / +%10 percent order); no combining dots, no
lowercase. Missing-glyph check: 0 findings.

Summary: high 0, med 6, low 2.

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hub-prompt-coins, -story, -upgrades, -quit, -wheel | pills `SİKKE KESESİ`, `HİKAYE - SEVİYE 1`, `GELİŞTİRMELER`, `ÇIKIŞ`, `ŞAPKA ÇARKI` | the İ dot sits on row 160, next to a goo lump at (136-139,159-160), so it merges with the band (SİKKE at x 135). The Ç / Ş cedillas reach the bottom band on row 170 (x 170, 108, 148). The pill has no accent rows. | med | `scripts/hub.gd:411` (prompt `panel_style()`), `hub.station.*` |
| hat-wheel-shop | every row: name vs price `45` + ticket | price and icon 3 px above the name body (name 54-62, price 51-57; en 49-56 / 49-56). Visible on SİLİNDİR ŞAPKA, BERE ... | med | `scripts/ui/hat_wheel.gd` |
| key-controls | action labels (YUKARI ... SLIMAKAZE) | label body 2 px above the key text (SOLA rows 80-86 vs A 82-88). | med | `scripts/ui/key_controls.gd` |
| settings | `● TÜRKÇE` | 2 px above the button pitch (117 vs 119 expected). | med | `scripts/ui/controls.gd:177-198` |
| upgrades-coins, -abilities | title `GELİŞTİRMELER` | 8 px fallback instead of the 16 px title. | med | `scripts/ui/upgrades_screen.gd` |
| wardrobe-skins, -hats, -trails | KILIK / ŞAPKA / İZLER | 8 px fallback titles. | med | `scripts/ui/skins_screen.gd` |
| title | corner button `HİKAYE` | ink x 9-41 in a 4-45 frame: 2 px left / 1 px right (en STORY 3 / 4). The final E touches the stripe. | low | `scripts/ui/title.gd`, `title.story` |
| hat-wheel-wheel | tab `DÜKKAN` | ink gap 3 / 1 (x 67-101), en SHOP 9 / 7. | low | `scripts/ui/hat_wheel.gd` |

Checked and clean: Descent boon cards and summary, level select + HEAT panel (2x icons), pause, restart, results, hub overlays, coin board, HUD (%100, SEVİYE pills), language, save code, reset, victory, story cards.
