# Visual review: ja (Japanese)

Reviewed 2026-10-17 against `en` from the `tools/i18n_capture.sh` captures (320x180 frames, 54 states; `map-table` /
`map-view` reviewed separately). Pixel positions are in 320x180 frame coordinates (x, y). Measured from the frames
(ink maps of the text colours), not from code. Font: Fusion Pixel 10 px ja (titles 20 px), digits in the slimy font.

No missing glyphs (`missing_glyphs.json` is empty for ja), no clipped or overflowing text, no SC glyph forms and no
untranslated English except the allowed names (`SPACE`, `ESC`, `F11`, `LV`, seeds).
The `story-intro-card-*` captures show no caption in any locale (English included), so those were not reviewable.

Summary: 0 high, 1 med, 8 low.

| State | Element / text | Problem | Severity | Suspected file / msgctxt |
|---|---|---|---|---|
| hub-resume, hub-prompt-story, hub-coin-board, hud-l1 (and every HUD level pod), hud-randomizer, hud-descent-pot, level-select-hard, hat-wheel-wheel, hat-wheel-shop, result-win-l3, result-win-l10, result-randomizer-win, descent-boon-card, descent-summary, key-controls | numbers next to kana / kanji: `地下12階`, `レベル1/10`, `ストーリー165/165`, `手持ち165`, `10枚`, `ヒート2`, `11個`, `1回目`, `報酬1枚`, `3回まわす`, `レベル3クリア`, `10個の`, `地下1階クリア` (title), `賞金0(+0)`, `1階ごとに+1枚`, `F11で` | The slimy digit runs into the next CJK glyph with 0-1 px between them. hub-resume: the `2` of `12` (x 143-148) touches the 阝 of 階 (starts x 148), rows 75-83, so `12階` reads as one blob. level-select-hard: the `0` of `10枚` touches 枚 (about x 258, y 124). English always has a space there. Fix it once, not per string: a thin space (U+2009, about 2 px) or 1 px of spacing between a slimy-font digit and a following / preceding CJK character in `Loc.fill`, or in the font fallback | med | scripts/loc.gd (`fill`), scripts/language.gd (font chain); msgctxt `hub.resume.floor`, `hud.area.level`, `hud.area.floor`, `hub.coins.total`, `levels.info_hard.2`, `hud.pod.attempt`, `hud.pod.pays_1`, `hud.pod.heat`, `descent.floor_cleared`, `descent.pot`, `boon.greedy.desc_1`, `result.level_cleared`, `keys.note.desktop_f11` |
| title | STORY button `ストーリー` (x 4-61, y 161-177) | Text is 1 px left of centre: ink x 8-55 in the fill x 7-58, so 1 px pad on the left and 3 px on the right (English `STORY`: 3 / 3) | low | scripts/ui/title.gd (story button), UIKit.button_w |
| hub-portal, title, level-select, hub-prompt-coins | `報酬枠2/2` (x 132-165, y 70-80), `霧から逃げろ`, `迫る霧`, `コイン袋` | At 10 px, 報 / 酬 and 霧 (19 strokes) fill in solid, and the 衣 part of 袋 is muddy. Still readable from context, but the worst glyphs in the locale. A simpler word (`報酬` alone, or `チケット枠`) would read better | low | locale/ja.po `hub.portal.info`, `title.tagline.1` |
| hub-prompt-coins, hub-prompt-maps | prompt pod `コイン袋` / `地図テーブル` (y 150-174) | The pod is 3 px taller than English (pod_h 17) and covers the bottom-left corner of the coin bag sprite by about 2 px (x 190-196, y 150-155). English's pod (y 157-173) clears it | low | scripts/hub.gd (prompt pod placement) |
| upgrades-abilities | description line `ネバネバを撃つ`, `3X3を爆破`, `壁へ突進` | The last ink row of the dim second line (y 64 in row 1) sits right on the row's bottom goo band (y 65): 0 px gap. English keeps 1 px of clear body. The name line also starts right under the top band (0 px) | low | scripts/ui/upgrades_screen.gd (2-line row, pod_h2) |
| hub-notice | `コイン返却+888` | No space before `+888`; English (`COINS RETURNED +888`) and zh/ko keep one, and the `+` touches 却 | low | locale/ja.po `hub.notice.returned` |
| hud-randomizer | area name `- 水没した神殿 -` (x 115-205, y 57-66) | It moved down to clear the 2-line TIX pod, and its bottom row touches the top of the player slime (y 66) | low | scripts/hud.gd `_place_area_texts` / `_clear_y` |
| wardrobe-skins / -hats / -trails | page title `スキン` / `帽子` / `軌跡` | Drawn in the 10 px body font (the fitting step 1/2 of `_layout`), while every other screen keeps a big 20 px title. A deliberate fallback, but it looks weaker than English's 16 px title | low | scripts/ui/skins_screen.gd `_layout` |
| wardrobe-skins / -hats / -trails | `残り火　（選択中）` | The two layout spaces plus the full-width bracket's own side bearing leave a gap of about 14 px between the name and `（` (English: 10 px) | low | locale/ja.po `skins.selected`, `skins.wearing` (one space would do) |
