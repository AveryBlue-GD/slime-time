extends RefCounted

## The ONE switch of the i18n test suites (docs/i18n/plan.md "English-only mode"; owner decision 2026-10-18).
## Every i18n suite, tests/suite_base.gd and tools/i18n_capture.sh read ENGLISH_ONLY from this file.
##
## ON  (game changes are made in English only; the 17 other locales are brought in line later, on request):
##   - English stays fully enforced: English layout, English text in Loc, the extractor finds every player-visible
##     string wrapped, messages.pot up to date, placeholders valid, gate-off behaviour, untranslated -> English fallback.
##   - the 17 locales + pseudo: missing / fuzzy / stale translations, fit overflows, screen findings and per-locale
##     layout assertions are REPORTED (printed as "note  (english-only, <locale>) ..." and, for the fit / screens suites,
##     written to docs/i18n/fit-report*) but do not fail. tools/i18n_extract.py is run as `--check --partial`.
## OFF (the later "bring all languages in line" session): the strict behaviour, every locale enforced.
## Steps for that session: docs/i18n/plan.md "English-only mode".
const ENGLISH_ONLY := true
