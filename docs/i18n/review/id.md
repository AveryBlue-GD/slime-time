# Visual review: id (Indonesian)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer), compared
with `en`. Indonesian uses English metrics (ui-rules 10), so layouts match en almost pixel for pixel.
UPGRADE, RUN, POT, LEVEL, SEED, SKIN, SLIME are glossary loanwords (docs/i18n/glossary/id.md), not
untranslated text. Missing-glyph check: 0 findings.

Summary: high 0, med 0, low 3. Effectively clean.

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| title | corner button `CERITA` | ink x 9-41 in a 4-45 frame: 2 px left / 1 px right (en STORY 3 / 4). The A touches the right stripe. | low | `scripts/ui/title.gd`, `title.story` |
| result-win-l3 | `NEXT LEVEL` slot `LEVEL BERIKUT` | fills the 84 px button (ink about 2 px from each stripe vs en 9-10). | low | `scripts/game.gd`, `result.next_level` |
| result-win-l3 | line 4 `EMAS  REKOR BARU!` | ends about 3 px from the panel's right stripe (en NEW BEST! about 6 px). | low | `scripts/game.gd` |

Checked and clean: every other state (level select keeps one 10-tile page; the info panel and BALIK / PANAS row keep en's 1 px drip gap; hub overlays; HUD; pause; Descent; wardrobe and upgrades keep 16 px titles).
