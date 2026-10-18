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
