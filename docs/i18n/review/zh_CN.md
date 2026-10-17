# Visual review: zh_CN (Simplified Chinese)

Reviewed 2026-10-17 against `en` from the `tools/i18n_capture.sh` captures (320x180 frames, 54 states; `map-table` /
`map-view` reviewed separately). Pixel positions are in 320x180 frame coordinates (x, y), measured from the frames.
Font: Fusion Pixel 10 px zh_hans (titles 20 px), digits in the slimy font.

No missing glyphs, no clipped or overflowing text, no Traditional forms (every glyph is the zh_hans shape), and no
untranslated English beyond the allowed names (`F`, `ESC`, `F11`, `LV`, seeds; `Q弹` in the L7 line is a real
Chinese word). The full-width `？` / `！` are correct in the .po; the font simply draws them narrow.
The `story-intro-card-*` captures show no caption in any locale, so those were not reviewable.

Summary: 0 high, 3 med, 5 low.

| State | Element / text | Problem | Severity | Suspected file / msgctxt |
|---|---|---|---|---|
| hub-prompt-story, hub-resume, hud-randomizer, hud-descent-pot, hat-wheel-wheel, hat-wheel-shop, hub-coin-board, result-win-l3, result-randomizer-win, descent-boon-card, descent-summary | `第1关`, `第12层`, `第1层`, `11顶`, `第1次`, `可得1券`, `第3关通关`, `第2次`, `第1层通关` (20 px title), `每层+1券`, `最远6格`, `转动3次`, `+1张`, `按F关闭`, `按F转动` | A slimy digit (or the key letter F) runs into the next hanzi. hub-prompt-story: the `1` (x 175-177) is 0-1 px from 关 (x 178-186), rows 159-165, so `1关` reads as one character. hub-resume: the `2` of `12层` touches 层. In the HUD pods (`第1次`, `可得1券`) the digit sticks to 次 / 券 and the count is hard to pick out. Fix once: 1 px or a thin space (U+2009) between a slimy digit / Latin key and a CJK neighbour, in `Loc.fill` or the font chain, not per string | med | scripts/loc.gd (`fill`), scripts/language.gd; msgctxt `hub.station.story`, `hub.resume.floor`, `hud.area.floor`, `hud.pod.attempt`, `hud.pod.pays_1`, `result.level_cleared`, `descent.floor_cleared`, `boon.greedy.desc_1`, `boon.sense.desc_2`, `hub.coins.close_key` |
| hub-prompt-random, hub-portal (orange title), upgrades-abilities (hint), victory, pause-random | 模 in `随机模式`; 继续 (hub-resume RESUME button x 96-152, y 106-122, pause, result-win-l10) | At 10 px, 模's 艹 / 日 / 大 parts merge into one block (it reads like 稹), and 继续's 纟 radicals fill in solid so both characters are mush. These are a button and the mode's name, so they are seen often. Options: `随机迷宫` (already used for the button), `继续` -> `接着玩`, or the 12 px build for these words | med | font (Fusion 10 px zh_hans); locale/zh_CN.po `hub.portal.title` / `hub.station.random`, `hub.resume.resume`, `pause.resume` |
| hud-l8-assisted | story line `关押被遗忘者的牢房。而你令人难忘。` | The line is short enough to clear the pods sideways, so it stays on the ASSIST pod's row: the pod ends at x 67 and the text starts at x 75 (8 px), y 45-54, so it reads as part of the pod. In English (and ja / ko / zh_TW) the line sits under the pod | med | scripts/hud.gd `_place_area_texts` / `_clear_y` (TEXT_CLEARANCE too small sideways) |
| upgrades-coins / -abilities (title), hub-prompt-upgrades, restart-prompt, result-dry-up | 级 in `升级` | 纟 + 及 at 10 px: the 及 half collapses into a hook (20 px title: x 140-175, y 5-25), so it reads close to 绥 | low | font; locale/zh_CN.po `upgrades.title` |
| title, hub-coin-board, wardrobe-skins, wardrobe-trails | 雾 in `逃离迷雾`, 袋 in `钱袋`, 烬 in `余烬`, 佩 in `（佩戴中）` | Dense at 10 px (雨 + 务 is solid, 袋's 衣 is muddy); readable from context | low | font (Fusion 10 px) |
| pause-random | seed button `种子 1453026489-0` (x 164-262, y 108-128) | The text fills the button: ink x 167-259 in the fill x 166-260, about 1 px of padding on each side, so the last `0` touches the inner highlight | low | scripts/ui/pause_menu.gd; msgctxt `pause.seed` (budget max 92px) |
| upgrades-abilities | description line `发射黏液`, `3X3爆破`, `穿墙冲刺` | The dim second line's last ink row sits right on the bottom goo band (0 px; English 1 px) | low | scripts/ui/upgrades_screen.gd (2-line row) |
| hud-randomizer, wardrobe-* | area name `- 沉没祭坛 -` touches the top of the player slime (y 66); the wardrobe page titles `皮肤` / `帽子` / `拖尾` are in the 10 px body font, not a 20 px title | Layout fallbacks that look weaker than English | low | scripts/hud.gd `_place_area_texts`; scripts/ui/skins_screen.gd `_layout` |
