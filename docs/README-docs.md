# Docs index

Living docs are here; finished reports and superseded plans are in [archive/](archive/). Start with [../CLAUDE.md](../CLAUDE.md)
(rules, commands, read every session), then [NEXT-SESSION.md](NEXT-SESSION.md) (where the last session left off) and
[handoff.md](handoff.md).

## Living docs

| Doc | What it is |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | project rules, commands (macOS and Windows), workflow |
| [../tests/README.md](../tests/README.md) | what every file under `tests/` is: suites, demo scenes, tools, data |
| [../README.md](../README.md) | player-facing how to run and play |
| [handoff.md](handoff.md) | current state: modes, economy, build/test/launch, save safety, platforms, open tasks, standing preferences |
| [architecture.md](architecture.md) | detailed code layout and conventions (moved out of CLAUDE.md): font and pixel rules, every screen and script |
| [ui-rules.md](ui-rules.md) | final UI layout rules (spacing scale, button / pod / tile sizes, text, touch targets, safe areas); numbers are `UIKit` constants |
| [level-design.md](level-design.md) | spawn picker, story layouts v4, calibration, save migration, randomizer, hard-mode rebalance, trail maps, Descent (9), Heat (10) |
| [design/upgrades-v2.md](design/upgrades-v2.md) | implemented spec: coin tree, ticket store, workshop, Descent, Heat, Abilities v1, deviations |
| [story.md](story.md) | plot, wordless intro and finale, level banners, `story_seen` |
| [playtime-estimate.md](playtime-estimate.md) | model-based playtime priors (no playtest data yet) |
| [itch-release.md](itch-release.md) | fresh-start policy (release dir, save epoch, `SLIME2-` codes), desktop builds, release checks |
| [itch-update-guide.md](itch-update-guide.md) | step-by-step publishing of a new build to itch from a Mac |
| [qa-web-report.md](qa-web-report.md) | web/itch and phone QA, fixes W1-W5, the 5-minute phone checklist |
| [qa-release-report.md](qa-release-report.md) | save robustness, soak, extremes, exports; status table of fixes |
| [advisor/maps.md](advisor/maps.md) | open proposal: unlock/cost plan for trail maps |
| [tutorial/design.md](tutorial/design.md) | open proposal (2026-10-18): training maze after the intro + hub tour, behind `Economy.TUTORIAL_TEST`; sources in [tutorial/research.md](tutorial/research.md) |
| [perf/](perf/) | performance audits (dated 2026-10-13; what was applied since: [phase4-perf](spring-cleaning/phase4-perf.md)): [measurements](perf/measurements.md), [cpu](perf/cpu.md), [rendering](perf/rendering.md), [startup-memory-web](perf/startup-memory-web.md) |
| [spring-cleaning/](spring-cleaning/) | the 2026-10 studio spring cleaning: [decisions D1-D14](spring-cleaning/decisions.md), [baseline](spring-cleaning/baseline.md), phase reports ([assets](spring-cleaning/phase1-assets.md), [code](spring-cleaning/phase1-code.md), [docs](spring-cleaning/phase1-docs.md), [tests](spring-cleaning/phase2-tests.md), [UI audit](spring-cleaning/phase3-ui-audit.md) + [UI](spring-cleaning/phase3-ui.md), [perf audit](spring-cleaning/phase4-perf-audit.md) + [perf](spring-cleaning/phase4-perf.md), [platform audit](spring-cleaning/phase5-platform-audit.md) + [platform](spring-cleaning/phase5-platform.md): presets, Descent resume, port-time checklist), the `qa-*.md` reviews, the [soft bounce test](spring-cleaning/soft-bounce-test.md) (`--softbounce`), the [coin catch test](spring-cleaning/coin-catch-test.md) (`--coincatch`), before / after captures |
| [i18n/](i18n/plan.md) | localization (D15): [plan](i18n/plan.md) (all chunks A-J done), [inventory](i18n/inventory.md) (every string), [fonts](i18n/fonts.md), [style-guide](i18n/style-guide.md), [glossary/](i18n/glossary/) (one per locale, with doubts for native review), fit reports ([fit-report.md](i18n/fit-report.md)), [shots/](i18n/shots/); UI rules in [ui-rules.md](ui-rules.md) section 10 |
| `polish-shots/` | screenshots and videos referenced by the docs |

## Archive ([archive/](archive/))

- [handoff-history.md](archive/handoff-history.md): the long chronological per-feature history of the project up to 2026-10-15.
- [game-design.md](archive/game-design.md): the original 6-phase build brief.
- [hats-audit.md](archive/hats-audit.md), [polish-research.md](archive/polish-research.md): hat scale audit; early polish diagnosis.
- [qa-nav-report.md](archive/qa-nav-report.md): navigation/Esc fuzzer findings B1-B10 (fixed).
- Code reviews (all findings fixed): [review-maps](archive/review-maps.md), [review-abilities](archive/review-abilities.md),
  [review-upgrades-b1](archive/review-upgrades-b1.md), [b2](archive/review-upgrades-b2.md), [b3](archive/review-upgrades-b3.md), [b4](archive/review-upgrades-b4.md).
- Advisor research (2026-10-12): [comparables-presentation](archive/advisor/comparables-presentation.md), [flow-level-design](archive/advisor/flow-level-design.md),
  [graphics-shading](archive/advisor/graphics-shading.md), [juice-audio-ui](archive/advisor/juice-audio-ui.md), [roguelike-progression](archive/advisor/roguelike-progression.md).
- Perf results: [batch A](archive/perf/results-batch-a.md), [batch B](archive/perf/results-batch-b.md) (applied optimizations, before/after).
