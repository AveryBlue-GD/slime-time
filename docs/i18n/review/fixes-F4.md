# Fix pass F4: translation-side causes

Fixes made only in `locale/*.po` and `docs/i18n/glossary/*.md`, for review rows whose cause is the translation
text itself. Layout and font rows are handled by the code passes. Checked with `tools/i18n_extract.py --check`
(0 errors) and with tests/test_i18n_fit, test_i18n_screens, test_i18n_glyphs, test_i18n_rtl and test_i18n_catalog
(all PASS on the working tree, 2026-10-17). No new characters, so the font subsets stay as they are.

| Review row | Key(s) | Before | After | Note |
|---|---|---|---|---|
| ar A1 (signs on the wrong side) | `boon.gulp.desc_1` / `_2` | `+30% سلايم` / `فورا` | `30% سلايم` / `إضافي فورا` | Reworded with no sign. Isolates (U+2066 / U+2069) typed into the msgstr were tried, but they fail test_i18n_glyphs (the fonts have no glyph for them), so the lines are reworded instead |
| ar A1 | `boon.tank.desc_1` | `الخزان +15%` | `خزان أكبر 15%` | "a tank 15% bigger" |
| ar A1 | `boon.slick.desc_1` | `انزلاق +15%` | `انزلاق 15%` | reads on with desc_2 `أسرع`: "glide 15% faster" |
| ar A1 | `boon.blaze.desc_2` | `+1 سطوع` | `سطوع أعلى` | "brighter" (the 80 px line has no room for "+1 level") |
| ar A1 | `boon.thrift.desc_2` | `+15%` | `أكثر 15%` | "15% more" after `تعبئة الطوابق` |
| ar A1 | `boon.greedy.desc_1` / `_2` | `+1 تذكرة/طابق` / `الخزان -10%` | `تذكرة/طابق` / `خزان أقل 10%` | "+1" dropped (a ticket per floor); `تذكرة زائدة/طابق` (93 px) is too wide for the 80 px line |
| ar A1 (grep of every ar msgstr) | `heatmod.race.desc` | `1.3 X الوقت` | `1.3 ضعف الوقت` | the Arabic word for "times", no Latin X next to the number |
| ar A1 (checked, unchanged) | `boon.bladder.desc_2`, `heatmod.thirsty.desc`, `ability.splat.desc`, `boon.glass.*`, `levels.info_hard.2` | `25%`, `8%`, `3X3`, `X1.5`, `X2`, number lists | | unsigned numbers keep their order; `+{count}`-style placeholders go through `Loc.fill` |
| ar A6 | `settings.volume` | `الصوت` | `علو الصوت` | `مستوى الصوت` (76 px) and `شدة الصوت` (62 px) are over the 60 px budget |
| ar A7 | `pause.quit_hub` | `الساحة` | `عودة للساحة` | the suggested `العودة إلى الساحة` fills the 97 px button and widens the pause panel (test_i18n_screens) |
| zh_CN 模 / 继续 (med) | `hub.station.random`, `hub.portal.title`, `victory.randomizer`, `upgrades.hint_tickets`, `upgrades.hint_tickets_locked` | `随机模式` | `随机关卡` | `随机迷宫` is already the RANDOM MAZE button in the same panel; 关卡 is in the font |
| zh_CN 继续 | `pause.resume` / `hub.resume.resume` / `result.choice.continue` / `hub.resume.spent` | `继续` / `继续` / `继续` / `本层已经继续过了` | `回到游戏` / `回到本局` / `前进` / `本层已回来过一次` | `接着玩` needs 接, which is not in the subset (fonttools is not installed here), so the words use characters already in the font. Not changed: `descent.descend` / `descent.confirm` `继续深入` (not flagged) |
| zh_CN 佩 (low) + shared key | `skins.wearing` | `（佩戴中）` | `（使用中）` | simpler glyphs; the key is shared by hats and trails |
| zh_TW (same check) | `skins.wearing` | `（戴著）` | `（使用中）` | also shared with trails. 繼續 / 隨機模式 left as they are (12 px font, no review row) |
| ja hub-notice | `hub.notice.returned` | `コイン返却+{count}` | `コイン返却 +{count}` | |
| ja wardrobe brackets | `skins.selected`, `skins.wearing` | `{name}  （…）` | `{name} （…）` | one space; the full-width bracket's bearing is the second |
| pl wardrobe-trails | `skins.wearing` | `(NA GŁOWIE)` | `(W UŻYCIU)` | "in use", right for a hat and a trail |
| (same cause, de / vi) | `skins.wearing` | de `(AUFGESETZT)`, vi `(ĐANG ĐỘI)` | de `(AKTIV)`, vi `(ĐANG DÙNG)` | both meant "on the head" but are shown for trails too |

Not changed (left for a native or for the code passes):

- ja 報酬枠 (`hub.portal.info` and 6 more keys) and 霧 in the tagline: dense at 10 px, but 報酬枠 is the glossary
  term in 7 strings; changing it to something like チケット枠 is a terminology call for a native reviewer.
- zh_CN 级 in 升级 and 雾 / 袋 / 烬: there is no simpler natural word; a font matter.
- ko tagline 를 / 틀: a font matter. fr `CHAL.` / it `CAL.`: abbreviated to fit, no reviewer fix in the text.
- Digit-to-CJK gaps (ja / ko / zh): a central fix in `Loc.fill` / the font chain, so no spaces were added.
- hi `skins.wearing` `(पहनी है)` is feminine (fits a topi, not a trail); left for a native Hindi reviewer.
- The `i18n:` note in scripts/descent.gd says boon lines are max 112 px, but the tile leaves 80 px (96 - 2 x 8)
  and the boon lines carry no budget for test_i18n_fit. That is a code note, left for the code owners.
