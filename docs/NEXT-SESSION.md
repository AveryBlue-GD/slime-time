# Next session: start here

Written 2026-10-18 for a fresh Claude Code session on another machine (the owner's desktop). Read this, then `CLAUDE.md`,
`docs/handoff.md` and `docs/spring-cleaning/decisions.md` (owner decisions D1-D16; D15 = localization, D16 = coin catch for everyone).
Desktop setup: `git pull` on `spring-cleaning` (the work was committed and pushed from the Mac; Windows commands are in CLAUDE.md).

## Where things are
- **The game is now called Dry Trying** (renamed 2026-10-19 by the owner; formerly Slime Time): logo (`tools/make_title.py`, 12 drip variants picked per title visit), window title, web page, exports (`DryTrying.exe` / `.zip` / `.x86_64`) and docs. Kept on purpose: the save dir `SlimeTime_R1`, the `SLIME2-` code prefix, the bundle id `com.slimetime.game`, repo / file / class names, font family names, the Desktop release-zip names. The promo images and release zips are out of date (re-render only when asked). Open: the tagline ESCAPE THE FOG / OR DRY TRYING now repeats the name.
- **Branch: `spring-cleaning`** (commit and push when finishing on one machine, pull on the other). It is NOT merged into `v2` yet - the owner hasn't decided.
  Tags: `spring-cleaning-baseline` (before), `spring-cleaning-final` (after the 6-phase cleanup), plus phase tags.
- The spring-cleaning report is `docs/spring-cleaning/FINAL-REPORT.md` (removed / optimized / UI / platforms / issues).
- Since that report, owner-requested changes on the same branch:
  - D11 Descent cut from the randomizer for now (`Economy.DESCENT_ENABLED = false`, kept intact).
  - D12 no upgrade recommendations anywhere (RECOMMENDED tag and "MORE SLIME = MORE" removed).
  - D13 the level 1-2 tutorial chalice beacon removed (movement/jump glyph hints stay).
  - D14 opaque skins = normal-mode unlocks and the default; jelly = hard-mode reward.
  - Intro cutscene: crumbling, irregular floor holes in the crack and fall shots.
  - A full "bouncy" ricochet was tried and REVERTED (owner: didn't feel good).

## Localization (D15), OFF by default, English-only until the game is finalized
17 languages + English behind `Economy.LANGUAGES_TEST` (plan/as-built: `docs/i18n/plan.md`; fonts, style guide, glossaries, fit reports beside it).
Try: `./tools/play.sh --dev --languages`, `--lang=ar` (not saved), `--lang=pseudo`.
**ENGLISH-ONLY rule:** `tests/i18n_mode.gd` has `ENGLISH_ONLY := true` (every i18n suite and `tools/i18n_capture.sh` read it); new text is not translated and
falls back to English. After each text/UI change run `./tools/i18n_capture.sh --gate` and add a row to `docs/i18n/pending.md` (the catch-up list). A request that says
"all languages" is done in every language at once. Catch-up steps: `docs/i18n/plan.md`.
Reviews: `docs/i18n/review/` (per-locale findings, `fixes-*.md`, `recheck-*.md`, `leftovers.md` = accepted exceptions). The capture gate (73 states x 19 locales,
~1 min) needs a window and isn't part of test_all.

## Open tests and the tutorial (OFF by default, decide keep / tune / revert)
| Test | Flag | Launch | Doc |
|---|---|---|---|
| Soft bounce | `Economy.SOFT_BOUNCE_TEST` | `./tools/play.sh --dev --softbounce` | `docs/spring-cleaning/soft-bounce-test.md` |
| Map coin reveal (dev only: uncollected coins the light revealed show on the MAP TABLE) | `Economy.MAP_COIN_REVEAL_TEST` (dev on, `--nocoinreveal` off) | `./tools/play.sh --dev`, play, F1, MAP TABLE | `docs/spring-cleaning/map-coin-reveal-test.md` |
| SPLASHDOWN tutorial (training maze after the intro + hub tour; SETTINGS > TRAINING replays it) | `Economy.TUTORIAL_TEST` (**true**: shipped) | `./tools/play.sh --tutorial`, `--tutorial=maze`, `--tutorial=hub` | `docs/tutorial/design.md` (sections 13-14 = owner answers + API), shots `docs/tutorial/shots/` |

The owner playtested the tutorial and shipped it (2026-10-18): `TUTORIAL_TEST := true`, so every fresh save gets the training maze and hub tour
(existing saves never do; the launch flags still replay it on a clean in-memory save).
Hat wheel (2026-10-18): the three rare slivers are spread evenly round the wheel (`HatWheel.spread_rares`, drawing order only; odds and picks unchanged).
Decided: D16 coin catch is on for everyone (`--nocoincatch` for A/B; flag plumbing removal is a follow-up; `docs/spring-cleaning/coin-catch-test.md`).
Also since the last handoff: collected coins are hidden on the maps; map coins draw in their level's metal; MAP TABLE paging fixed; the dry-up row has a MAP button
(story levels; BACK returns to the level); the wardrobe is now COSMETICS with a PAPERS page; propeller hat animated, new RAINCLOUD hat; wheel rare tier =
rainbow, propeller, raincloud at weight 0.3 (ordinary 10.10 %, rare 3.03 %), a save's first free spin is never rare.

## Other open owner decisions
- TAILOR still sells the propeller hat at 45 tickets (rainbow 80) though it is rare on the wheel: reprice?
- German keeps STORY / LEVEL / SHOP as English loanwords (`docs/i18n/glossary/de.md`): keep?
- Level 1-2 cue issues seen but left pixel-identical: d-pad arrowheads point inward, SPACE's S touches its key edge, pad A is hard to read in a 29 px key.
- "+1 TICKETS" English singular: fix?
- Ship the languages (later, after finalizing; flip `LANGUAGES_TEST` and `LANGUAGES_ENABLED` in `tools/web_shell.html` together).
- Merge / push `spring-cleaning` into `v2`?
- `stash@{0}` is redundant (same content as committed files): drop it.
- Older: dense touch button stacks (32-40 pt targets); perf clips; Mac fullscreen check; local mp4s / old screenshots in history; affordability nudges.
- Workshop and Descent stay behind flags (`WORKSHOP_ENABLED`, `DESCENT_ENABLED` = false).

## How the owner likes to work
- **English only (owner, 2026-10-18):** game changes are made and checked in English only. Don't translate new or
  changed strings and don't fix layouts for the other 17 languages; they fall back to English for new text. The owner
  will update all other languages together once the game is finalized (reconfirmed 2026-10-18); only when the owner
  asks to "bring the other languages in line" do the catch-up (steps in `docs/i18n/plan.md`, English-only
  mode switch in the i18n tests). Still wrap new text in `Loc.t` / `Loc.n` with `# i18n:` hints so the catch-up works.
  After every text/UI change, still run `./tools/i18n_capture.sh --gate` (English strict, other languages = warnings)
  and add a row to `docs/i18n/pending.md` (change, strings, warnings), so the catch-up is a known list.
  Exceptions: changes without text need no language work; a request that says "all languages" is done in every
  language right away (translations + capture review for that change).
- "launch" = `./tools/play.sh` (REAL save); "dev mode" = `./tools/play.sh --dev`; "story mode" =
  `--story`; "autoplay" = `--autoplay [--speed=N]`. Run launches in the background and close the previous game first
  (`pkill -f "Godot.app/Contents/MacOS/Godot.*--unlock-all"` closes only dev launches; a plain launch has no flags, so
  check before killing). Close a playing real-save game only by its own PID, never by quitting the Godot app: agents may be running Godot captures.
- Big tasks: split across the agents in `.claude/agents/` with the best model per job (new: `i18n-engineer`, `localizer`, `tutorial-designer`; Opus for design, gameplay feel,
  reviews, UI/perf/platform; Sonnet for docs/tests/small fixes; Haiku for plain test runs). Each change gets an
  independent review/QA agent; nobody verifies their own work.
- New gameplay ideas go behind a test flag + debug launch flag first, so the owner can A/B them; revert cleanly if rejected. Never touch the real save.
- Commit small steps with explicit `git add <paths>` and the Co-Authored-By line from the session's attribution
  instruction. Push only when asked ("commit and push"); the owner syncs machines that way.
- Keep replies short; the owner tests in the running game and gives feel-based feedback.

## Gotchas learned the hard way
- Never touch real saves: tests/tools use throwaway saves; the real one is
  `~/Library/Application Support/SlimeTime_R1/save.cfg` (fresh-start epoch R1; old saves are never read).
- `tools/screenshot.sh` clears `.screens/` - parallel agents should capture with `--write-movie` to their own paths.
- `tools/job_timeout.pl` once overwrote the Godot binary when called with a missing argument (now guarded). If
  `/Applications/Godot.app/Contents/MacOS/Godot --version` doesn't print `4.7.2.stable.official.ed1daf0bf`, reinstall
  from https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip
- Tooling flakes: `i18n_capture.sh` sometimes dies mid-locale ("incomplete captures"; rerun); real-save md5 checks in tests can fail while the owner is playing (rerun when not).
- Agents running `test_all.sh` at the same time as other agents can see flaky failures; rerun a failing suite alone.
- Agents sometimes leave background shells/loops running; check `ps` for stray `zsh -c` / `sleep` loops at the end.
- `./tools/test_all.sh` runs in parallel (~2 min, `-j N`, `JOB_TIMEOUT`); 111 suites.
