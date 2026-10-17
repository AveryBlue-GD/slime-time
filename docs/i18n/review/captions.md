# Story captions review (fix batch R4)

Earlier reviews (en.md, ja.md, ko.md, zh_CN.md, zh_TW.md, recheck-latin.md, recheck-cjk.md) said the
`story-intro-card-0..4` captures were "taken before the caption types in". There is no caption to wait for:
the intro and the finale are wordless by design (`scripts/story.gd`, `scripts/ui/story_screen.gd` header;
`tests/test_story.gd` checks the story screen makes no text call and loads no font). The only story text is
the level banner line under the area name as a story level starts (`story.level_1` .. `story.level_10`,
`Story.level_line`, placed by `scripts/hud.gd`); the suite's HUD states only showed L1, L7, L8 and L10.

New capture states (tests/capture_i18n.gd, after the suite's 56; 73 per locale):
- `story-line-l1` .. `story-line-l10`: each story level started, banner and line fully shown (before the fade;
  the driver checks the line is visible, alpha 1 and non-empty, and logs its y, line count and the name's y).
- `story-intro-card-0..4-still`, `story-finale-card-0..1-still`: each shot frozen on its Reduce Motion still
  (the old `story-intro-card-N` is the shot's first frame, mostly dark).

Run: `./tools/i18n_capture.sh --gate`, all 19 locales, real save md5 unchanged. Every line read upscaled 3x
(one stack of the 10 lines per locale). Missing glyphs: 0. Goo-ink: 0 on the new states.

## Per locale

| locale | lines | result |
|---|---|---|
| en | 1 line each, y 35 | clean (reference) |
| es pt_BR fr de it | 1 line, y 44 | clean; no clipping, accents clear of the name row, every line inside the 296 px column; it L7 / fr L8 end on a period whose drip looks like a comma at 1x (same in en, the font's drip) |
| ru pl tr | 1 line, y 44 | clean; ru uses ` - ` as the dash (glossary) |
| vi | 1 line, y 52 | clean; stacked marks (Ẩ Ằ Ễ) clear of the name above; L10 sits right above the slime, clear |
| id | 1 line, y 35 | clean; L2 `PARA PENAMBANG KABUR BURU-BURU. KAMU JUGA SEBAIKNYA.` is the widest line of all locales (x 17-304, inside 12-308) |
| ja ko zh_CN zh_TW | 1 line, y 41 / 45 | clean; zh `Q弹` mixes the slimy Q with the CJK font, reads fine (script gap applied); zh_TW centred `。` is the Taiwan convention |
| th | 1 line, y 47 | clean except L10: line moved under the slime (y 82), name stays on top (already in recheck-th-hi-ar.md, low, `scripts/hud.gd`, not text: the script's taller line cannot stay 2 px clear of L10's starting slime) |
| ar | 1 line, y 51 | RTL order right (sentence starts at the right, final period on the left), no reversed words, no isolates needed (no numbers). L10 under the slime (same rule, accepted as A4 fix) |
| hi | 1 line, y 52-53 | clean, matras whole; L10 under the slime (accepted H7 fix) |
| pseudo | 1-2 lines, y 62 | L2 / L7 / L8 wrap to 2 lines and go under the slime (y 103) with an orphan last word (`YÖÜ.___]`): expected for +40 % padding, no real locale wraps |

No text change needed; the one open layout row (th L10 under the slime) is hud.gd and stays with that
owner. Intro / finale stills: identical in every locale, no text drawn (0 texts checked on those states).
