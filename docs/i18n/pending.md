# Pending translation catch-up (English-only mode)

The running list for the later "bring all languages in line" session (`docs/i18n/plan.md` "English-only mode",
`tests/i18n_mode.gd`). While `ENGLISH_ONLY` is on, game changes are made in English only; add one row per change here.
`python3 tools/i18n_extract.py --pending` gives the exact per-locale entry list; `./tools/i18n_capture.sh --gate` writes
`<out>/i18n_pending_warnings.json` with the screens / locales that warn. Empty the table when the catch-up is done.

| date | change | strings added / changed (ctx) | screens / locales with gate warnings |
|---|---|---|---|
| 2026-10-18 | Wardrobe renamed COSMETICS (hub station); new PAPERS page (map papers, after TRAILS) | changed: `hub.station.wardrobe` (SKINS & HATS -> COSMETICS, fuzzy in every locale); added: `skins.page_papers` (PAPERS), `skins.rule_papers` (BUY MAP PAPERS IN THE PRIZE WHEEL'S SHOP); hint widened: `skins.name_price` | none (en gate PASS; all 19 locales on the 5 wardrobe / hub-prompt states: 0 warnings, the new lines fall back to English) |
| 2026-10-18 | MAP TABLE: collected coins no longer drawn on the maps (everyone); dev-only map coin reveal test (revealed uncollected coins, `--nocoinreveal`) | none (no player-visible text added or changed) | none (en gate PASS, 0 warnings) |
| 2026-10-18 | Dry-up choice row: MAP button (story levels only) opens the MAP TABLE on that level and mode; with the ASSIST offer the four buttons share the row (72 px each) | added: `result.choice.map` (MAP) | none (en gate PASS, 0 warnings; other locales fall back to English) |
| 2026-10-18 | New hat RAINCLOUD (a wheel hat, animated rain); propeller cap now animated (no text) | added: `hat.raincloud` (RAINCLOUD), `hat.raincloud.desc` (ITS VERY OWN DRIZZLE; Hats.about, not on a screen yet) | none (en gate PASS, 0 warnings; other locales fall back to English) |
| 2026-10-18 | Dry-up 4-button row: text budget corrected to 62 px (72 px buttons) | comments only (`result.choice.assist`, `result.choice.map`) | dry-up 4-button row: fr RECOMMENCER (and pseudo) overflow offscreen at 72 px, fix in catch-up |
| 2026-10-18 | Tutorial chunk A (gate `Economy.TUTORIAL_TEST` off, `--tutorial` flag, save bits, intro hand-off) | none (no player-visible text added or changed; the maze / tour lines come with chunks B-D) | none |
| 2026-10-18 | Tutorial chunk E: SETTINGS TRAINING button (bottom row, centre; only with the tutorial gate on) replays the training maze | added: `settings.training` (TRAINING) | none |
| 2026-10-18 | Tutorial chunk C: SPLASHDOWN training cues (move glyph, leap key + hold bar, meter pod pulse, accept keycap by RESTART; TutorialCues drawing moved to static helpers, levels 1-2 pixel-identical) | none (reuses `tutorial.jump`; key names are the OS's, `# i18n: ignore`) | none (en gate PASS, 0 warnings) |
