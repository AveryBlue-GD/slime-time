# Visual review: ko (Korean)

Reviewed 2026-10-17 against `en` from the `tools/i18n_capture.sh` captures (320x180 frames, 54 states; `map-table` /
`map-view` reviewed separately). Pixel positions are in 320x180 frame coordinates (x, y), measured from the frames.
Font: Fusion Pixel 10 px ko (Hangul from Galmuri, titles 20 px), digits in the slimy font.

No missing glyphs, no clipped or overflowing text, and every Hangul glyph comes from the ko subset (no fallback
font mixed in). No untranslated English beyond the allowed names (`F`, `ESC`, `F11`, `SPACE`, seeds). Korean keeps
spaces between words, so most numbers are separated; the problems are the places where a counter sticks to the number.
The `story-intro-card-*` captures show no caption in any locale, so those were not reviewable.

Summary: 0 high, 1 med, 6 low.

| State | Element / text | Problem | Severity | Suspected file / msgctxt |
|---|---|---|---|---|
| hub-resume, hud-descent-pot, level-select-hard, hat-wheel-wheel, result-randomizer-win, descent-boon-card, descent-summary, hat-wheel-shop | `12층`, `1층`, `10장`, `1회`, `11개`, `2번째`, `1층 클리어` (20 px title), `2층에서`, `3번` | The slimy digit touches the following Hangul syllable (0 px). hub-resume: the `2` of `12층` (x 140-145) runs into 층 (row 75-83). level-select-hard: the `0` of `10장` and the `1` of `1회` touch their syllables (y about 124). Native counters normally do attach to the number, so the text is right; the rendering needs 1 px or a thin space (U+2009) between a slimy digit and Hangul, fixed once in the font chain or `Loc.fill` | med | scripts/loc.gd (`fill`), scripts/language.gd; msgctxt `hub.resume.floor`, `hud.area.floor`, `levels.info_hard.2`, `descent.floor_cleared`, `descent.dried_up`, `hud.pod.pays_1` |
| title | tagline `안개를 탈출하라` / `말라비틀어지기 전에` | At this size 를, 출 and 틀 (three stacked parts) squeeze their ㄹ / ㅡ rows together, so 를 reads close to 틀. Readable, but the densest Hangul in the game | low | font (Fusion 10 px ko), locale/ko.po `title.tagline.1` / `.2` |
| pause-random | seed button `시드 1453026489-0` (x 164-262, y 108-128) | The text fills the button: ink x 169-259 in the fill x 167-260, about 3 px of padding on the left and 1 px on the right, so the last `0` touches the inner highlight and the text sits about 1 px right of centre | low | scripts/ui/pause_menu.gd (seed button width), UIKit.button_w; msgctxt `pause.seed` (budget max 92px, this text is 91 px) |
| hub-prompt-coins | prompt pod `코인 주머니` (x 127-194, y 150-174) | The taller and wider pod covers the bottom-left of the coin bag sprite by about 2 px (x 190-194, y 150-155); English's pod clears the bag | low | scripts/hub.gd (prompt pod placement) |
| upgrades-abilities | description line `점액 발사`, `3x3 폭발`, `벽 돌진` | The dim second line's last ink row sits right on the row's bottom goo band (0 px gap; English 1 px) | low | scripts/ui/upgrades_screen.gd (2-line row) |
| hud-randomizer | area name `- 수몰 신전 -` (y 57-66) | It moved down to clear the 2-line TIX pod, and its bottom row touches the top of the player slime | low | scripts/hud.gd `_place_area_texts` |
| wardrobe-skins / -hats / -trails | page title `스킨` / `모자` / `흔적` | Drawn in the 10 px body font (the fitting fallback), not the 20 px title size other screens use; looks weaker than English | low | scripts/ui/skins_screen.gd `_layout` |
