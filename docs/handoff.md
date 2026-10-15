# Handoff: where Slime Time stands (updated 2026-10-15)

Read [../CLAUDE.md](../CLAUDE.md) first (rules, commands), then this file. Code layout: [architecture.md](architecture.md). Docs
index: [README-docs.md](README-docs.md). The long per-feature history (everything up to 2026-10-15, including the superseded
back-and-forth on abilities and the workshop) is in [archive/handoff-history.md](archive/handoff-history.md).

## What the game is

Godot 4.7.2 pixel-art maze game, 320x180 base, `gl_compatibility`. A slime glides through a fogged maze; its goo trail reveals the
map, moving drains the slime meter, the golden chalice is the exit. Flow: title (first launch of a fresh save plays the wordless
intro) -> round rotating **hub** with 9 stations (story archway, MAP TABLE, upgrades cauldron, QUIT trapdoor, coin bag, randomizer
portal, settings signpost, hat wheel, wardrobe).

## Modes

- **Story:** 10 themed levels, coins at dead ends (165 in all), 1-3 tier time medals, wordless finale.
- **Hard mode:** own bigger mazes, meter x `Levels.HARD_SLIME_MULT`, no upgrades; **HEAT** (hard level select): six modifiers,
  bounties 3/5/7/10 tickets at heat 2/4/7/10 per level.
- **Randomizer** (after the story): the gold ticket voucher is the goal (payout 5/4/3/2/1 by attempt), seed codes `N-L`.
- **DESCENT:** chained randomizer-sized floors, boons, a ticket pot (2 paying runs per UTC day; milestones floors 5/10/15/20).
- **Trail maps** (MAP TABLE): per-level map of every tile seen plus the fastest route (a trial: cost/unlock undecided).
- Skins (10 presets, rainbow, Stopwatch for 30 gold medals, CHAMELEON; jelly default), 11 placeholder hats (live since upgrades v2
  batch 2), SETTINGS with a separate CONTROLS page and SAVE CODE.

## Economy (every number in `scripts/economy.gd`; spec: [design/upgrades-v2.md](design/upgrades-v2.md))

- **Coins** buy the core tree at the cauldron's COINS tab (refundable, tree 3): MORE SLIME 7 levels (1,4,7,9,12,20,27 = 80), SPEED 4
  (6,9,13,18 = 46), BRIGHTNESS 3 (9,12,18 = 39); coins in hand are derived (`coins_earned - coins_spent`); tree 2 saves are repriced on load.
- **Tickets** (randomizer, Descent pots, HEAT bounties) buy hat wheel spins, the SHOP (TAILOR hats, rainbow, 5 trail styles, 3 map
  papers) and the three **abilities** (SLIME RIFLE / SPLAT / SLIMAKAZE, keys 1/2/3, one charge per attempt; they work ONLY in
  randomizer mazes and Descent, never in story/hard/HEAT: `Abilities.allowed_in`).
- The ticket **workshop** (SECOND WIND, QUICK CHARGE, ...) is switched OFF (`Economy.WORKSHOP_ENABLED := false`); saved levels are
  kept, flipping the const restores it.

## Build, test, launch

- Launch: `./tools/play.sh` (real save), `--dev` (everything unlocked, nothing saved; F1 full bright, F2 no drain), `--story`
  (postgame state), `--autoplay [--speed=N]` (F10 stops), `--scene res://tests/demo_*.tscn`. Windows: `tools/play.ps1 -Dev -Story -Autoplay`.
- Tests: `./tools/test_all.sh` (70 suites, prints `suites: N failed: 0`, about 6 minutes; baseline in
  [spring-cleaning/baseline.md](spring-cleaning/baseline.md)). One suite:
  `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_X.gd`.
- Debug flags for economy work: `--upgrades=a,b,c`, `--tickets=N`, `--trail=ID`, `--paper=ID`, `--descent[=SEED]`, `--heat=...`,
  `--abilities=r,s,k`, `--coins=N`, `--unlock-all`; none of them saves.
- Exports: Web (custom shell `tools/web_shell.html`), Windows Desktop, macOS presets in `export_presets.cfg`; steps in
  [itch-release.md](itch-release.md) and [itch-update-guide.md](itch-update-guide.md).

## Save safety

Only a plain launch touches the real save: `user://save.cfg` in the release dir `SlimeTime_R1` (`~/Library/Application
Support/SlimeTime_R1/save.cfg` on macOS). The pre-release save (`.../Godot/app_userdata/Slime Time/save.cfg`) is never read. Tests,
tools, headless, movie, screenshot and dev runs write a throwaway file; `--story` / `--autoplay` use clean in-memory state. Saves
and codes carry `[meta] epoch` (`Progress.RELEASE_EPOCH` = 1, codes `SLIME2-`); save version 6. Saves are atomic and untrusted
text passes `scripts/save_text.gd` first ([qa-release-report.md](qa-release-report.md)). Fresh-start policy and how to bump
it: [itch-release.md](itch-release.md). Never run the game when the owner may be playing.

## Platforms

Desktop (macOS dev machine, Windows) and web/itch are the shipped targets. Android and iPhone web are unverified on real devices
(the Android shader fix is unconfirmed; web QA in an itch-like iframe with phone emulation: [qa-web-report.md](qa-web-report.md),
5-minute phone checklist in its section 6). Windows build zip and itch promo images are out of date (v2.2); rebuild only when asked.
Targets for the ports (owner): stable 60 fps on low-end PCs and low-to-mid mobile, smooth scaling to 120/144/240 Hz, English only.
Perf notes: [perf/](perf/).

## Open tasks and open questions

1. Real-device checks on Android and iPhone (web zip, checklist above).
2. Tuning from playtests (all numbers are priors, see [playtime-estimate.md](playtime-estimate.md)): story budgets, hard allowances,
   randomizer/Descent/HEAT ticket payouts, hat wheel and cosmetic prices, whether the randomizer should still pay 5 tickets first try.
3. Real hats from the owner (the wheel, SHOP and wardrobe work with any `Hats.LIST`).
4. Trail maps: decide cost/unlock ([advisor/maps.md](advisor/maps.md)).
5. Optional: merge `v2` into `main`; update the itch tagline when prepping a release.
6. Re-base `tools/web_shell.html` on the new default shell on a Godot upgrade.

## Decisions and standing preferences

- **Launching:** "launch" = the real save, "dev mode" = everything unlocked and nothing saved. On Windows always
  `tools/play.ps1` in the background (right-most monitor, no focus steal); on the Mac `tools/play.sh [--dev]`.
- **Story-complete launch (postgame testing):** `./tools/play.sh --story` (Windows `tools/play.ps1 -Story`; the game
  flag `--story-complete`, `Progress.enable_story_complete`) starts as a player who beat all 10 levels on normal
  AND hard with all 165 coins found and none spent (upgrades left to buy), story intro/finale and tutorial seen,
  randomizer, level select and every jelly/solid skin (rainbow too) open. Best times: normal 1-5 at 0.95 x par
  (gold), 6-10 and all hard levels at 1.15 x par (silver); medals derive from them (25/30 normal, 20/30 hard, so
  the stopwatch skin stays locked). Not dev mode: no dev tools, F1/F2 off. Starts from a clean in-memory state:
  the real save is never read or written (throwaway path, saving off). Test: `tests/test_story_complete.gd`.
- **Ask before release work:** don't re-render itch promo images or rebuild release zips unless asked
  ("get this ready for itch"); quick verification screenshots are fine. "Prep only the itch file" = just the
  web zip.
- **Screenshots:** each level shown with its own first-run skin; rainbow only with every coin found.
- **Sound:** keep pitches low and dark and ambience faint.
- **Words:** "glide" (moving) and "leap" (SPACE) stay as they are; the user retracted a rename.
- **Hub design:** Don't Starve style round room that rotates with the wheel in the middle; F = interact,
  SPACE = leap; Esc in the hub goes back to the title; the title screen has an ENTER THE HUB button and the tagline
  ESCAPE THE FOG / OR DRY TRYING (no "!").
- **Rainbow skin:** normal mode unlocks it by finding every story coin; its solid version needs hard level 10
  (like the custom color's). The color-wheel skin is called CHAMELEON; the shadow skin is "Inkky".
- **Jelly** (see-through) slimes are the default; solid versions are unlocked by hard-mode clears.
- **Hats:** compact (brims 2-3 px past the head); rainbow hat at reduced odds on the wheel.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Keeping machines in sync:
  "commit and push" when finishing on one, "pull" when starting on the other.
