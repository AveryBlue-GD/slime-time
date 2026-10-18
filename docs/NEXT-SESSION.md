# Next session: start here

Written 2026-10-16 at the end of a long session, for a fresh Claude Code window. Read this, then `CLAUDE.md`,
`docs/handoff.md` and `docs/spring-cleaning/decisions.md` (owner decisions D1-D15; D15 = localization).

## Where things are
- **Branch: `spring-cleaning`** (all work pushed). It is NOT merged into `v2` yet - the owner hasn't decided.
  Tags: `spring-cleaning-baseline` (before), `spring-cleaning-final` (after the 6-phase cleanup), plus phase tags.
- The spring-cleaning report is `docs/spring-cleaning/FINAL-REPORT.md` (removed / optimized / UI / platforms / issues).
- Since that report, owner-requested changes on the same branch:
  - D11 Descent cut from the randomizer for now (`Economy.DESCENT_ENABLED = false`, kept intact).
  - D12 no upgrade recommendations anywhere (RECOMMENDED tag and "MORE SLIME = MORE" removed).
  - D13 the level 1-2 tutorial chalice beacon removed (movement/jump glyph hints stay).
  - D14 opaque skins = normal-mode unlocks and the default; jelly = hard-mode reward.
  - Intro cutscene: crumbling, irregular floor holes in the crack and fall shots.
  - A full "bouncy" ricochet was tried and REVERTED (owner: didn't feel good).

## Localization (D15), done through chunk J, OFF by default
English + 17 languages on branch `spring-cleaning` (plan/as-built: `docs/i18n/plan.md`; fonts, style guide, per-locale glossaries, fit reports beside it).
Try: `./tools/play.sh --dev --languages` (saved language or OS locale; LANGUAGE screen in settings), `./tools/play.sh --dev --lang=ar` (any locale, not saved), `--lang=pseudo`.
Gate: `Economy.LANGUAGES_TEST`. Open items (a-g) are in `docs/handoff.md` open task 8: ship decision, native review (ar, hi, th), font licenses, unverified web/device checks, ticket singular, 1 px row height. (The two old English layout bugs, "SPAC" and the random-maze pod over the timer, are fixed.)
Verified 2026-10-17: the MAP TABLE shows all 10 maps once in every locale, normal and hard, hard maps separate (`tests/test_i18n_maps.gd`); every locale reviewed screen by screen and re-reviewed after fixes (`docs/i18n/review/`: per-locale findings, `fixes-*.md`, `recheck-*.md`, `leftovers.md` = accepted exceptions). Before any UI change: `./tools/i18n_capture.sh --locales all --states all --out /tmp/x --gate` (73 states x 19 locales, ~1 min; fails on text ink on goo, missing glyphs or a changed real save; needs a window, not part of test_all).
Owner questions still open: German keeps STORY / LEVEL / SHOP as English loanwords (glossary/de.md): keep?

## Open tests the owner is trying (both OFF by default, decide keep / tune / revert)
| Test | Flag | Launch | Doc |
|---|---|---|---|
| Soft bounce (short stun, smooth slide along the wall on glancing hits) | `Economy.SOFT_BOUNCE_TEST` | `./tools/play.sh --dev --softbounce` | `docs/spring-cleaning/soft-bounce-test.md` |
| Coin catch (coin tossed up, slime hops to catch, ~1 s dissolve, counter pops after) | `Economy.COIN_CATCH_TEST` | `./tools/play.sh --dev --coincatch` | `docs/spring-cleaning/coin-catch-test.md` |
Both together: `./tools/play.sh --dev --coincatch --softbounce`. To keep one for everyone, set its constant to `true`
(and then remove the flag plumbing / test-only paths as a follow-up).

## Other open owner decisions
- Merge `spring-cleaning` into `v2`?
- Dense touch button stacks (pause, restart, key rows, shop) reach only 32-40 pt targets on phones.
- Judge the high-refresh smoothing clips (`docs/spring-cleaning/perf/*.mp4`, local only).
- Manual Mac fullscreen check: green button / F11, quit, relaunch.
- Local videos (~105 MB of git-ignored mp4s) and purging old screenshots from git history: keep or remove?
- Remaining affordability nudges (hub "!" on the hat wheel/cauldron, UPGRADES button after a dry-up): keep?
- The disabled ticket workshop (`WORKSHOP_ENABLED = false`) and Descent (`DESCENT_ENABLED = false`) stay behind flags.

## How the owner likes to work
- **English only (owner, 2026-10-18):** game changes are made and checked in English only. Don't translate new or
  changed strings and don't fix layouts for the other 17 languages; they fall back to English for new text. Only when
  the owner asks to "bring the other languages in line" do the catch-up (steps in `docs/i18n/plan.md`, English-only
  mode switch in the i18n tests). Still wrap new text in `Loc.t` / `Loc.n` with `# i18n:` hints so the catch-up works.
  After every text/UI change, still run `./tools/i18n_capture.sh --gate` (English strict, other languages = warnings)
  and add a row to `docs/i18n/pending.md` (change, strings, warnings), so the catch-up is a known list.
  Exceptions: changes without text need no language work; a request that says "all languages" is done in every
  language right away (translations + capture review for that change).
- "launch" = `./tools/play.sh` (REAL save); "launch in dev mode" = `./tools/play.sh --dev`; "story mode" =
  `--story`; "autoplay" = `--autoplay [--speed=N]`. Run launches in the background and close the previous game first
  (`pkill -f "Godot.app/Contents/MacOS/Godot.*--unlock-all"` closes only dev launches; a plain launch has no flags, so
  check before killing - never close the owner's real-save game without saying so).
- Big tasks: split across the agents in `.claude/agents/` with the best model per job (Opus for design, gameplay feel,
  reviews, UI/perf/platform; Sonnet for docs/tests/small fixes; Haiku for plain test runs). Each change gets an
  independent review/QA agent; nobody verifies their own work.
- New gameplay ideas go behind a flag + debug launch flag first, so the owner can A/B them; revert cleanly if rejected.
- Commit small steps with explicit `git add <paths>` and the Co-Authored-By line from the session's attribution
  instruction; push to `origin spring-cleaning`. Pushing is fine (the owner asked for it throughout).
- Keep replies short; the owner tests in the running game and gives feel-based feedback.

## Gotchas learned the hard way
- Never touch real saves: tests/tools use throwaway saves; the real one is
  `~/Library/Application Support/SlimeTime_R1/save.cfg` (fresh-start epoch R1; old saves are never read).
- `tools/screenshot.sh` clears `.screens/` - parallel agents should capture with `--write-movie` to their own paths.
- `tools/job_timeout.pl` once overwrote the Godot binary when called with a missing argument (now guarded). If
  `/Applications/Godot.app/Contents/MacOS/Godot --version` doesn't print `4.7.2.stable.official.ed1daf0bf`, reinstall
  from https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip
- Agents running `test_all.sh` at the same time as other agents can see flaky failures; rerun a failing suite alone.
- Agents sometimes leave background shells/loops running; check `ps` for stray `zsh -c` / `sleep` loops at the end.
- `./tools/test_all.sh` runs in parallel (~2 min, `-j N`, `JOB_TIMEOUT`); 91 suites.
