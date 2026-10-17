# Leftover pass (after fix passes F1-F4)

The rows the fix passes left (their "not fixed" / "left" sections), fixed where they are visible errors, else one line
why they are not. Measured with `tools/i18n_capture.sh --measure-boxes`, all 19 locales x 56 states, before = HEAD
ab54329 (the consolidation commit, byte-identical to d71415d) and after = this pass, both with the capture's stable
goo lumps (README "Reproducibility"). Box-relative ink: T = first ink row, B = rows under the last ink (B3: the last
ink on h - 4, right over the bottom lumps, as every English pod; B4 = 1 clear row), L / R = clear columns.
Shots (one state, all 19 locales, 2x): `docs/i18n/shots/leftovers/<state>_before.png` / `_after.png`.
Test: `tests/test_i18n_leftovers_layout.gd` (every locale; fails on HEAD in en, es, fr, de, ko, zh_CN, zh_TW, th, hi,
pseudo). Rules: `docs/ui-rules.md` 10.1 "Leftover pass rules", "Rendered goo-ink gate".

## Fixed

| Locale(s) | State | Row | Measured before -> after |
|---|---|---|---|
| zh_TW, hi (th too) | upgrades-abilities | slimy-digit drips of `3X3爆破` / `बम 3X3` touching the bottom lumps | the tag rises by the rows its own ink (drips counted, `UIKit.ink_rows(..., true)`) is past h - 5: zh_TW row 2 B3 -> B4, hi row 2 B3 -> B4, th row 3 (ุ) B4 -> B5; the other rows as before |
| zh_TW | result-randomizer-win | `第2次 = +4` drips on the bottom goo (goo-ink 1 px) | last row 1 row taller (`UIKit.drip_excess`): B2 -> B3, goo-ink 1 -> 0; result-dry-up B3 -> B4 |
| pseudo | result-win-l3 | 18 px on the panel's bottom goo (F2 read it as the `_` drips: it was the banner title's 16 px marks, 6 rows over its line box) | the panel ends GAP_XS over the banner title's own marks (`UIKit.mark_rows`): B0 -> B4, goo-ink 18 -> 0; panels already clear of them (es, fr, vi ...) unchanged |
| en (owner-accepted) | settings-save-code | 4 px of the SETTINGS title's drips in the panel's band zone (T3) | English hides the page labels under the panel's band rows: T3 -> T6, goo-ink 4 -> 0; RESET confirm and every other English state byte-identical |
| ru | hat-wheel-shop | КЕПКА С ПРОПЕЛЛЕРОМ 4 clear columns before its price | `hat.propeller` -> `КЕПКА-ПРОПЕЛЛЕР` (the usual Russian name; no truncation): 4 -> 22 columns, the grown tiles keep GAP_L (F3a rule) |
| es, de, fr | key-controls | SALTAR (MANTÉN) / longest label 4 px (GAP) from its key | label column + 4 where both columns still fit: es ink to key 5 -> 9 clear columns (gap 4 -> 8); keys 64 -> 60 wide (fr 62 -> 58), still >= PRESS KEY |
| ko, zh_CN | pause-random | `시드 1453026489-0` / `种子 …` filling the 100 px SEED button (L4 R4) | the long form needs BUTTON_TEXT_PAD each side, else the code alone (as English for a 10-digit seed): L4 R4 -> L17 R16 |
| zh_CN, zh_TW | wardrobe-* | `{name}  （…）`: two spaces before the full-width bracket (ja got one in F4) | one space: name to bracket 14 -> 10 (zh_CN), 16 -> 12 (zh_TW) clear columns; the rest is the bracket's own bearing |

Goo-ink check (glyph ink px on goo / in band rows), before -> after: en 0/4 -> 0, zh_TW 1/1 -> 0, pseudo 18/8 -> 0;
every other locale 0 -> 0. `./tools/i18n_capture.sh --gate` now passes with an empty `tools/i18n_goo_ink_allow.txt`.

## Not errors (left as they are)

- hi H10 (Latin runs `ESC` / `P` / `F11` dropped in Hindi lines): the slimy and Devanagari fonts share one baseline by design; raising the slimy glyphs would move every mixed line.
- ar A5 (the wardrobe's try-on slime not mirrored): game art, deliberately never flipped (ui-rules 10.2 "What does not mirror").
- ko title tagline 를 / 틀 / 출: the squeeze is inside the 10 px Fusion bitmaps (ㄹ over ㅡ rows touching) at 2x; 2 px glyph spacing on the tagline (tried, FontVariation `spacing_glyph`) leaves the syllables as drawn, so only another font or wording would change it (a native's call).
- vi / zh_TW ABILITIES hint on the bottom row: centred and clear of BACK (vi 20, zh_TW 63 clear columns), not crowded; it is the plan step that keeps the rows on one page.
- vi / zh_TW wardrobe rule line over the bottom-row stage: 5 (vi) / 2 (zh_TW) clear rows over the stage's frame, the F3a rule's 2.
- hi H9 (REPLAY / COINS padding): every button in every locale keeps 4+ columns from its edge to its ink (English's own minimum, `--measure-boxes`).
- ar / hi result-win-l3 compact banner: their four tall lines do not fit with the big banner even with paired lines (F2 COMPACT_OK).
- Story line continued under the slime (it / vi L7 hard, hi / ar / zh_TW L8): readable, and the only free place under the pods.
- fr dry-up line x 37-301 and id `REKOR BARU!` 3 px from the stripe: inside REWARDS_W / >= 2 px clear (F2 rules).
- vi JELLY in the top-left corner: the layout every accented locale shares with the stage on the bottom row (F3a).
- en wardrobe empty band under the status lines: English's own layout, unchanged.
- ar ABILITIES on two pages: no smaller Arabic size exists (Kufi merges dots under 12 px).
- es / pt_BR / fr / it title tagline lifted 5 px clear of STORY: the documented fit (F3b).
- ja 報酬枠, zh_CN 级 / 雾 / 袋 / 烬, fr `CHAL.` / it `CAL.`: terminology or font density for a native reviewer (F4), legible as drawn.
- hi `(पहनी है)` feminine for trails: wording for a native Hindi reviewer (F4), not a layout error.
- scripts/descent.gd `i18n:` note (boon lines "max 112px", the tile leaves 80): a comment, not a pixel; the boon tiles' 8 px side room is checked by test_i18n_f2_layout.
