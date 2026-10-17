# Visual review: zh_TW (Traditional Chinese)

Reviewed 2026-10-17 against `en` from the `tools/i18n_capture.sh` captures (320x180 frames, 54 states; `map-table` /
`map-view` reviewed separately). Pixel positions are in 320x180 frame coordinates (x, y), measured from the frames.
Font: Fusion Pixel 12 px zh_tw (Cubic 11; titles 24 px), digits in the slimy font.

No missing glyphs, no clipped or overflowing text, and no Simplified forms (廳, 關, 體, 錢 and 獎 are all Taiwan-standard;
the centred `。` is the correct Taiwan form). The 12 px build fixed the 10 px collapses: 繁體 / 霧 / 關 are legible.
No untranslated English beyond the allowed names (`F`, `ESC`, `F11`, seeds; `Q彈` is a real word).
The `story-intro-card-*` captures show no caption in any locale, so those were not reviewable.

Summary: 1 high, 2 med, 5 low.

| State | Element / text | Problem | Severity | Suspected file / msgctxt |
|---|---|---|---|---|
| hud-randomizer | area name `- 沉沒祭壇 -` (x 128-192, y 60-73) | The 2-line TIX pod (`第1次` / `可得1券`, 2 x 17 px rows) pushes the area name down until it lies right on top of the player slime (x 153-166, y 63-80): the slime shows through 祭壇 and neither reads. In English the name is at y 43-51, well above the slime; ja / ko / zh_CN only touch it. `_clear_y` only clears the pods, not the player | high | scripts/hud.gd `_place_area_texts` / `_clear_y` |
| hub-prompt-story, hub-resume, hud-randomizer, hud-descent-pot, hat-wheel-wheel, hat-wheel-shop, hub-coin-board, result-win-l3, result-randomizer-win, descent-boon-card, descent-summary | `第1關`, `第12層`, `第1層`, `11頂`, `第1次`, `可得1券`, `第3關過關`, `第2次`, `第1層過關` (24 px title), `+1張`, `轉動3次`, `按F關閉`, `按F轉動` | A slimy digit or key letter runs into the next hanzi with 0-1 px between them. hub-prompt-story: the `1` (x 175-178) touches 關 (from x 180), rows 156-166, so `1關` reads as one dense glyph. descent-boon-card title: the 16 px slimy `1` stands between 24 px hanzi, 3 rows shorter at the top and glued to 層. hat-wheel-wheel: `按F轉動`, F is squeezed between 按 and 轉. Fix once (1 px or a thin space U+2009 next to a slimy digit / Latin key in CJK text), in `Loc.fill` or the font chain | med | scripts/loc.gd (`fill`), scripts/language.gd; msgctxt `hub.station.story`, `hub.resume.floor`, `hud.area.floor`, `hud.pod.attempt`, `hud.pod.pays_1`, `result.level_cleared`, `descent.floor_cleared`, `hub.coins.close_key` |
| result-win-l3 | NEW RECORD! banner | Only zh_TW drops to the compact banner: a small `新紀錄！ 0:13.6` line with small chalices (y 140-152) instead of the big 24 px headline (English and the other CJK locales show it big; zh_TW's own result-win-l10 shows it big too). The fallback is deliberate (hud.gd, results panel too tall), but this is the one state where the language looks worse than English | med | scripts/hud.gd (compact banner, around line 1095); locale/zh_TW.po `result.level_cleared` / the 4-line panel |
| wardrobe-skins, hub-coin-board, hub-resume | 燼 in `餘燼`, 寶 in `火山寶庫`, 繼續 (RESUME button) | Still dense at 12 px (燼, 寶 and the 糸 radicals of 繼 / 續 nearly fill in solid); readable, but the weakest glyphs left | low | font (Fusion 12 px zh_tw) |
| hub-coin-board | row numbers `1`..`10` beside the names | Top-aligned with the hanzi: the digit body (rows 60-66) is about 1.5 px above the name's centre (59-70); in English the number shares the name's baseline | low | scripts/hub.gd (coin board rows, `digit_top()`) |
| key-controls | page 1/2 | Only 3 binding rows fit per page (3 + 2), leaving about 40 px of empty space between row 3 (ends y 101) and the hint (y 144). English shows all 5 rows | low | scripts/ui/key_controls.gd (row budget, `stack_pages`) |
| upgrades-abilities | hint `先去隨機模式賺獎券` | Moved onto the bottom row next to BACK (y 168), while every other locale keeps it under the list; the dim second lines (`發射黏液`, `3x3爆破`, `穿牆衝刺`) also sit right on their rows' bottom goo band (0 px; English 1 px) | low | scripts/ui/upgrades_screen.gd |
| wardrobe-skins / -hats / -trails | page title `造型` / `帽子` / `軌跡` | In the 12 px body font (the fitting fallback), not the 24 px title other screens use | low | scripts/ui/skins_screen.gd `_layout` |
