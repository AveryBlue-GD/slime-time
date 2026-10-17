# Visual review: pseudo (pseudo-locale stress test)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer), compared
with `en`. Pseudo pads every string with `[__ __]` and accents (accented metrics), so findings show
where real long translations will break. Missing-glyph check: 0 findings.

Summary: high 1, med 3, low 5.

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| descent-summary | rewards line `[______+1 TÍÇKÉT  HÁŁF THÉ PÖT (2)_______]` | overflows the panel: the ticket icon sits on the panel's left border (x ~41) and the closing `]` touches the right border (x ~278). No wrap or fit is applied to this line. | high | `scripts/ui/descent_card.gd` (summary rewards row) |
| descent-boon-card | boon cards | fallback layout moves the icon to the card's top-left corner and top-anchors the text, leaving ~25 px empty at the bottom. `[_ĞRÉÉĐÝ ĞÖÖ_]` ends 1 px from the card's right stripe (x ~307). | med | `scripts/ui/descent_card.gd` |
| hub-prompt-* | all station pills | acute / ring / caron marks sit on or under the pill's goo band (rows 159-160), same cause as ru / pl / tr / vi. | med | `scripts/hub.gd:411` |
| hud-l8-assisted, hud-l10 | story line (2 lines) | the story line runs across the player slime (l8: second line y ~92-98 over the slime at ~88-100, x ~160; l10: the line at y ~62-68 crosses the slime top at x ~160). | med | `scripts/hud.gd` |
| hud-l1, hud-l1-all-found | level name `[_- [_ĐÁRK ĐÜÑĞÉÖÑ__] -_]` | ends about 2 px from the `[_ÁŁŁ FÖÜÑĐ_]` pill on the same row. | low | `scripts/hud.gd` |
| restart-prompt | title `[_RÉŠTÁRT?_]` | ends about 2 px from the ALL FOUND pill (same rows). | low | `scripts/ui/restart_prompt.gd` |
| hat-wheel-wheel | button `[_ŚPÏÑ FRÉÉ_]` | the acute top pixel touches the button's top band (0 px). | low | `scripts/ui/hat_wheel.gd` |
| settings-save-code, settings-reset-confirm, upgrades, wardrobe | screen / panel titles | fall back to the 8 px font (documented fit_text step, but visibly weaker than en). | low | `UIKit.fit_text` callers |
| hub-notice | notice box | the widened box covers the cabinet (left) and the chair (right) props of the hub. | low | `scripts/hub.gd` (notice) |

Checked: title, level select (wrapping checkbox), HEAT panel, key controls (1/2 paging), pause, results, coin board, hat wheel shop (3-line footer fits), language, victory, story cards.
