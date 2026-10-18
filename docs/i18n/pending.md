# Pending translation catch-up (English-only mode)

The running list for the later "bring all languages in line" session (`docs/i18n/plan.md` "English-only mode",
`tests/i18n_mode.gd`). While `ENGLISH_ONLY` is on, game changes are made in English only; add one row per change here.
`python3 tools/i18n_extract.py --pending` gives the exact per-locale entry list; `./tools/i18n_capture.sh --gate` writes
`<out>/i18n_pending_warnings.json` with the screens / locales that warn. Empty the table when the catch-up is done.

| date | change | strings added / changed (ctx) | screens / locales with gate warnings |
|---|---|---|---|
