# Visual review: vi (Vietnamese)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer), compared
with `en`. Coordinates are 320x180 frame pixels. The vi metrics (button 18, 5 ink rows above) work on
themed buttons and most panels. They do not work on surfaces that ignore the accent rows (hub pills,
the first line of result panels). SLIME / SKIN / SEED are glossary loanwords. Missing-glyph check: 0 findings.

Summary: high 2, med 7, low 3.

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hub-prompt-* (all 9) | pills `CỔNG NGẪU NHIÊN`, `THOÁT`, `TÚI XU`, `BÀN BẢN ĐỒ`, `CÀI ĐẶT`, `TRUYỆN - MÀN 1`, `NÂNG CẤP`, `SKIN & MŨ`, `VÒNG QUAY MŨ MIỄN PHÍ` | stacked marks are drawn inside the pill's goo band (rows 157-160): the Ổ hook and Ẫ tilde overlap the orange band (x 126-129, 160-163, 192-193 in hub-prompt-random). Marks are hidden or unreadable; the pill keeps English height. | high | `scripts/hub.gd:411` (prompt `panel_style()` without accent rows) |
| result-win-l3, result-win-l10 | first panel line `NUỐT TRỌN CHÉN THÁNH!`, `BẠN ĐÃ THOÁT CẢ 10 MÊ CUNG!` | marks are drawn on the band's lump row: in l10, mark pixels at (119,44), (121,44) alternate with lump pixels at (120,44), (122,44) under band rows 41-43. Ã / Á / Ả / Ố merge with the goo. | high | `scripts/game.gd` (result panel first-line y / panel margins), `result.escaped_all`, `result.chalice` |
| descent-summary | panel line 1 `KHÔ CẠN Ở TẦNG 2` | the grave of Ầ has its top pixel at (177,47), directly under a band pixel at (177,46): 0 px gap, sitting on a lump. | med | `scripts/ui/descent_card.gd` |
| hud-randomizer | level name `- ĐỀN CHÌM -` | drawn over the top 2-3 px of the player slime (name y ~62-66, slime top ~65). In en the name sits 15 px above the slime (y 47). The name is pushed down by the taller HUD pills. | med | `scripts/hud.gd` |
| hat-wheel-shop | every row: name vs price `45` + ticket | the price sits about 2 px above the name's line top and about 4 px above its letter body (name 57-65 including marks, price 55-61). en is aligned. | med | `scripts/ui/hat_wheel.gd` |
| key-controls | action labels (ĐI LÊN ...) | label body 3 px above the key text (SANG PHẢI body ~103-109 vs D 106-112). | med | `scripts/ui/key_controls.gd` |
| settings | `● TIẾNG VIỆT` | 3 px above the button pitch (text 128-134, pitch predicts 131). | med | `scripts/ui/controls.gd:177-198` |
| wardrobe-skins, -hats, -trails | titles SKIN / MŨ / VỆT | 8 px fallback titles. On skins the JELLY toggle `THẠCH: TẮT` also moves to the top-left corner (x 5-80, y 5-21), away from its en place in the bottom row. | med | `scripts/ui/skins_screen.gd` |
| hub-portal | `CỔNG NGẪU NHIÊN` panel title, `MÊ CUNG NGẪU NHIÊN` button | the Ẫ tilde ends 1 px under the band / button frame (not touching, but the tightest in vi). | low | `scripts/hub.gd` (portal panel) |
| hub-coin-board | two-column rows `1 NGỤC TỐI TĂM` | number-to-name gap about 3 px vs 6 px in en, so `1NGỤC` reads as one token. | low | `scripts/hub.gd` (coin board vi layout) |
| upgrades-abilities | footer `HÃY KIẾM VÉ Ở CỔNG NGẪU NHIÊN TRƯỚC` | moved into the bottom row beside VỀ (y ~170) instead of under the list as in en. It fits, but the layout is inconsistent with the coins page. | low | `scripts/ui/upgrades_screen.gd` |

Checked and clean: title (ink gaps 2 / 1-2 on CỐT TRUYỆN, marks clear of the frame), level select + HEAT panel, pause (2-column), restart, result-dry-up and randomizer-win (first-line marks 2 px clear), hub notice / quit / resume, language, save code, reset (XÓA SẠCH TIẾN ĐỘ?), victory, story cards.
