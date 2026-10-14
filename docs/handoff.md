# Handoff: where Slime Time stands (updated 2026-10-14)

## Current state (2026-10-14)

Read [CLAUDE.md](../CLAUDE.md) for the project facts and [README-docs.md](README-docs.md) for the docs index. The sections
below this summary are the history (oldest first, newest last); where they disagree with this summary or with CLAUDE.md,
this summary and CLAUDE.md win.

**What exists.** Godot 4.7.2 pixel-art maze game (320x180). Title (first launch of a fresh save plays the wordless story
intro first) -> round rotating **hub** with 9 stations (story archway, MAP TABLE, upgrades cauldron, QUIT trapdoor with a
LEAVE THE HUB? confirm, coin bag, randomizer portal, settings signpost, hat wheel, wardrobe). 10 themed story levels
(coins at dead ends, upgrades, medals as 1-3 time tiers, wordless finale), **hard mode** (own bigger mazes, meter x
`HARD_SLIME_MULT`), the **randomizer** (unlocked after the story; the gold ticket voucher is the goal, no chalice; payout
5/4/3/2/1 by attempt; per-seed slime usage; seed codes `N-L`), **trail maps** (MAP TABLE), skins (10 presets, rainbow,
Stopwatch for 30 gold medals, CHAMELEON; jelly by default, solid via hard clears), SETTINGS (two columns) with a separate
CONTROLS page and SAVE CODE, 11 placeholder hats. Save version 6 (+ `[meta] epoch` 1). 61 test suites; 6 agents in `.claude/agents/`.

**Launch / test.** `./tools/play.sh` (real save), `--dev` (everything unlocked, nothing saved; F1 full bright, F2 no drain,
fn+F1/F2 on a Mac), `--story` (postgame state), `--autoplay [--speed=N]` (the game plays itself; F10 stops it), `--scene
res://tests/demo_*.tscn`. Windows: `tools/play.ps1 -Dev -Story -Autoplay`. Tests: `./tools/test_all.sh` (prints `suites: N
failed: 0`); one suite: `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_X.gd`.

**Save safety.** Only a plain launch touches `user://save.cfg`, which is now the release dir
(`~/Library/Application Support/SlimeTime_R1/save.cfg` on macOS; fresh-start policy, below and in
[itch-release.md](itch-release.md)). The pre-release save at `~/Library/Application Support/Godot/app_userdata/Slime
Time/save.cfg` stays on disk untouched and is never read. Tests, tools, headless, movie, screenshot and dev runs write
a throwaway file (and may read the real save); `--story` / `--autoplay` use clean in-memory state. Never run the game
yourself when the owner may be playing; launch semantics and preferences are in "Decisions and standing preferences".

**Release hardening (2026-10-14).** Save codes and save.cfg pass the `scripts/save_text.gd` allow-list before
`ConfigFile.parse` (no code execution, no parser crash, bounded gzip: QA S1/S10/S11); saves are atomic (`.tmp` + rename,
retried on failure, `Progress.save_failed`); an unreadable save is kept as `save.corrupt.cfg` (3 rotating); a far-future
randomizer pay day counts as today; release exports ignore debug flags (only `--touch` / `--web-ui`); Windows exe has the
game icon + version info (`icon.ico` from `tools/make_icon_ico.py`); a macOS preset exists (universal, ad-hoc,
`com.slimetime.game` placeholder). Status tables: [qa-release-report.md](qa-release-report.md),
[qa-web-report.md](qa-web-report.md); builds: [itch-release.md](itch-release.md). 59 test suites.

**Upgrades v2 (2026-10-15, batch 1 of [design/upgrades-v2.md](design/upgrades-v2.md) done).** Core coin tree with big
breakpoints: MORE SLIME 7 levels, SPEED 4, BRIGHTNESS 3 (165 coins, same maxima); all economy numbers in
`scripts/economy.gd`. Old-tree saves are remapped by coins invested (`[upgrades] tree = 2`, save version 6, one-time hub
notice COINS RETURNED +N). Seed codes carry MORE SLIME 0-7. Batches 2-4 (hats + store + ticket workshop, Descent, Heat)
are not built; details in the section at the end.

**Known limitations.**
- Hats are placeholders: `Hats.available = false`, so the hat wheel says COMING SOON and hats can't be worn outside dev mode.
- Android and web are unverified on real devices (the Android shader fix is unconfirmed). The web build was QA'd in an
  itch-like cross-origin iframe with phone emulation ([qa-web-report.md](qa-web-report.md)); the Web preset now uses the
  custom shell `tools/web_shell.html` (Godot 4.7.2's default + marked additions: save flush on hide, storage-blocked bar,
  context-lost RELOAD cover, friendly errors). On a Godot upgrade, re-base it on the new default shell.
- Difficulty numbers are priors, not playtest data ([playtime-estimate.md](playtime-estimate.md): ~45 min median for the
  story on normal, ~2.1 h with hard).
- Trail maps are a trial (cost/unlock and the trapdoor's spot are undecided). Maps v3 is in: themed maps on
  (`map_select.THEMED_MAPS`), a thin red route whatever the skin, and select tiles that show made-up example mazes
  (never the real map) lit by the % uncovered.
- Windows build zip and itch promo images are out of date (v2.2); only rebuild when the owner asks.

**Fresh-start policy (public release).** Progress from pre-release builds never carries over
([itch-release.md](itch-release.md)): `user://` is the release dir `SlimeTime_R1` (`project.godot`
`custom_user_dir_name`; web: `/userfs/SlimeTime_R1` in IndexedDB, which itch shares between all games), every save
and code carries `[meta] epoch` = `Progress.RELEASE_EPOCH` (1) and is ignored without it, and codes are `SLIME2-`
(old `SLIME1-` codes say THAT CODE IS FROM AN OLD VERSION). The owner's own local progress starts over too. A future
wipe bumps the dir name, `RELEASE_EPOCH` and the prefix together (see the doc). Test: `tests/test_fresh_start.gd`.

**Open tasks.**
1. Android / web device checks: upload the web zip and run the 5-minute checklist in [qa-web-report.md](qa-web-report.md) section 6 on a real Android phone and an iPhone.
2. Tuning from playtests (story budgets, hard allowances, randomizer usage curve, ticket payouts, hat wheel price).
3. Optional map v1 as proposed in [advisor/maps.md](advisor/maps.md) (unlock/cost plan for the trail maps).
4. Real hats from the owner, then set `Hats.available = true` (nothing else is needed); hat wheel currency is already tickets.
5. Optional: merge `v2` into `main`; update the itch page tagline when prepping a release.

The "Open tasks" list further down is from 2026-10-12 and is kept as history.
Notes below saying CLAUDE.md is "out of date (not edited)" were fixed on 2026-10-14; CLAUDE.md now matches the code.


## Original handoff (2026-10-12, history)

Written on the Windows PC before moving to the MacBook Pro. Read this with [CLAUDE.md](../CLAUDE.md),
which describes the whole project and the commands for both machines.

## Where we left off

- **Branch `v2`** has all the current work (`main` is older). Latest commits are on GitHub:
  https://github.com/AveryBlue-GD/slime-time (private), with tags `v1.0`, `v2.0`-`v2.2`, `v2-before-themes`, `pre-hub`.
- **All 21 test suites pass** on Windows, also through the new `tools/test_all.sh`.
- **Moving to the Mac:** `tools/*.sh` twins of the PowerShell tools were added and tested (pointed at the Windows
  Godot); CLAUDE.md has a "Commands on macOS / Linux" section. The user has a setup prompt to paste into Claude Code
  on the Mac (install Godot 4.7.2 + export templates, clone, `git checkout v2`, import, run tests, copy the save,
  screenshot, launch). Their (pre-release, so no longer loadable) save is also on OneDrive: `Desktop/SlimeTime-for-Mac/save.cfg` (plus
  `slime-time.bundle`, a full repo backup that's no longer needed now GitHub has it).
- **Itch:** the newest web build is zipped at `Desktop\SlimeTime-Web-itch.zip` (copy in `Desktop\SlimeTime-v2.3`).
  It includes everything up to the paste fix (ec12f7f). The Windows build zip and the promo images were **not**
  rebuilt for v2.3 (still v2.2). Whether the user has uploaded the new web zip to itch is unknown.

## Recent work (this session, newest last)

1. Hats wrap round the slime: redrawn to its measured dome in three widths (narrow / normal / wide) that follow
   its squash and stretch, with much more detail.
2. Hats trimmed (the user found the wide ones, especially the cowboy hat and baseball cap, too big).
3. New rare **rainbow hat** (rainbow arching over the head from two clouds, colors flowing), on a thin rainbow
   sliver of the hat wheel: wedges are sized by odds (`Hats.weight`, rainbow 0.3 = about 3% with all 11 hats).
4. Hat y-sorted with the slime in the hub (it went in front of the wheel when the slime was behind it).
5. Text drips reroll each time a screen opens; letters with a single bottom pixel (4, 7, i, T...) rarely drip.
6. Hub polish: the hat tracks the slime through bonks and bounces (a small jolt, no flying off and snapping back);
   fog around the room; the slime walks over the wheel's goo foot but stays behind its post; the wheel's prompt
   says ROTATE; no keys on prompts; goo-framed prompt; stations usable from any side; station sounds soft from
   afar, louder up close.
7. **Android fix (unconfirmed on a real phone):** a friend's Android phone showed the hub with no slime, stations
   or wheel in every browser. Cause: shaders using arrays indexed at run time, which many Android GPUs fail to
   compile in WebGL (Godot then draws nothing). `slime_skin.gdshader` was rewritten without arrays, and the
   BAYER dither arrays in `fog`, `atmosphere` and `goo_wipe` became a `bayer4()` function. Looks identical on PC.
8. **Save code paste fix:** pasting a code into the browser version didn't work (Godot's Ctrl+V on the web runs
   before the browser hands over the text). Added a PASTE button and a page `paste` listener. Untested in a real
   browser.
9. Mac tooling, CLAUDE.md updates, GitHub push.

## Open tasks

- **Confirm the Android fix:** upload the new web zip to itch and have the friend retest the hub and a level.
  If it still fails, get the phone model; next step would be a debug build that reports which shader fails.
- **Confirm the browser paste fix** on itch (PASTE button and Ctrl+V in the SAVE CODE panel).
- **Mac setup:** under way. The Mac has already cloned the repo and pushed one fix (e69e447, a re-import of
  `pixel_big.png.import`). Check that all the tests pass there and that the save came over; fix anything
  macOS-specific (case-sensitive paths, `python3`), then commit and push.
- **Hats are placeholders.** `Hats.available = false` (COMING SOON outside dev mode) until the user decides the
  real hat list.
- **Hat wheel currency:** spins are dev-mode only "until we add a currency later". Not designed yet.
- **Itch page text** still shows the old tagline with a "!"; update it the next time the user asks for itch prep.
- **Windows build + promo images** are out of date (v2.2); rebuild only when the user asks.
- Optional: merge `v2` into `main` so GitHub's default branch is current (offered, not asked for).
- Earlier brainstorm of more upgrades (no decision made; only Slime, Speed and Brightness exist, plus dev-only
  wall power).

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

## Flow phase 1A (retry, first launch, wordless teaching)
- Dry-up retry buttons appear after `DRY_CHOICE_DELAY` (0.25 s); RESTART is focused (SPACE/Enter/R). R mid-run restarts at once unless coins are in hand on a non-hard run (then the RESTART/UPGRADES/CANCEL prompt stays, so the upgrades shortcut survives). Randomizer dry-up keeps the same maze (buttons RESTART / NEW MAZE / UPGRADES).
- Fresh save (`Progress.is_fresh_save()`: nothing cleared) -> title button PLAY -> level 1; the hub is reached via the win buttons / pause menu until a level is cleared, then the title says ENTER THE HUB.
- `scripts/tutorial_cues.gd` (levels 1-2, story, not hard): WASD/d-pad glyph until first move, SPACE/JUMP key after wandering without a leap (fade on use, saved as optional `progress/tutorial_seen`), gold chevron beacon toward the chalice after 6 s idle or a dry-up on that level (`Progress.dry_ups`, not saved). Test: `tests/test_flow.gd`; screenshot: `tests/demo_cues.tscn` (`--beacon`).

## Phase 1B (feel + light)
Jump input buffer (Slime.JUMP_BUFFER), camera kick + sprite-only hit-stop (Reduce Motion skips them), SFX pitch variation (Sfx.VARY), low-slime heartbeat/lowwarn sounds, web audio unlock blip, lantern above the fog, fog shader without arrays (vec4 uniforms), Settings: MOTION (FULL/LESS) and FOG (DARK/NORMAL/BRIGHT) saved as optional keys; both survive RESET PROGRESS. Tests: tests/test_phase1b.gd. Unverified: web/Android build, 13->9 tap trim not done.

## Phase 2 (look polish)
`assets/shaders/trail.gdshader` (dark rim, top-left bevel, rare twinkle on the goo trail; twinkle off with Reduce Motion); `slime_skin.gdshader` `gloss`/`shine_motion`/`charge` (shine sweep, dithered backlit underside, charge tension; only `Slime` turns gloss on, logos/menus stay plain); `scripts/ambient.gd` `Ambient` (one capped CPUParticles2D per theme, z 11 above the fog so motes float in the dark, none with Reduce Motion; table in `BY_THEME`); chalice gold twinkle within 64 px before it is seen (`CHALICE_GLIMMER_*`; no hum sound added); hub floor darker + `Hub.POOLS` light pools (`Fx.make_pool`); HUD pods got a 2 px frame (dark outline + rim + top highlight, `make_ui_art.py` `HUD_POD`); title button uses the 16 px font. Tests: `tests/test_polish.gd`. Shots: `docs/polish-shots/phase2_*`.

## Phase 3 (ticket vouchers, medals, assist, seeds)
Reworked after the first Phase 3 pass: globs became TICKET VOUCHERS and medals became time tiers.
- **Ticket vouchers** (`Progress.tickets`, cosmetic only, never mixed with coins; icon `assets/ui/icon_ticket.png`, a gold notched voucher from `tools/make_ui_art.py`): they come ONLY from the randomizer. A win pays 2 (`TICKETS_RANDOM_WIN`), +1 when it beats that maze's par time (`TICKETS_UNDER_PAR`), for the first 5 wins per UTC day (`RANDOM_PAID_PER_DAY`, `random_pay_day`/`random_paid`; the clock going back never reopens the cap), so 15 a day at most. First clears, hard clears and medals pay nothing; an assisted run pays nothing. `Progress.complete_random(assisted, under_par)` pays and saves; `Hud.show_rewards` shows `+N TICKETS` / `UNDER PAR` (or `DAILY TICKET LIMIT REACHED`) and the hub's top-left pod shows the balance and `N/30` medals. The old one-time retro grant for old saves is gone: an existing balance is kept as it is.
- **Hat wheel**: `Progress.spin_hat()` picks (rainbow pity: +0.15 wedge weight per missed spin), charges `SPIN_COST` (12; first spin free; dev mode free), wins and saves BEFORE the wheel animates; the wheel only plays out the landing. **`Hats.available` is still false**: outside dev mode the hub says COMING SOON and `can_spin_hats()` is false. Flip it to true when the real hats are in; nothing else is needed. 12 tickets is one spin per ~1 to 2 days of capped randomizer play.
- **Medals** (`[medals] level_N` = best tier 0-3, hard under N+100): by clear TIME against the level's par (`Levels.par_for_path`: solution path / base speed 72 x 1.35 + 1 s, independent of speed upgrades; `Levels.level_par(level, hard)` gives it without playing). `Progress.tier_for`: gold (3) <= par, silver (2) <= 1.3 x par, bronze (1) = any unassisted clear (the test autopilot's perfect glide finishes ~28% under par, so gold needs a tidy route, not perfection). Hard mode uses the same thresholds and keeps its own tiers, which do NOT count toward `Progress.all_medals()` (true when all normal-mode levels are tier 3; reserved for a future special skin, not used yet). `record_clear(level, run_time, par, assisted, finish)` returns `{tier, best, new_best, assisted}`; the result screen shows 3 medal icons, the tier name and NEW BEST! when it raised the saved tier (a first clear counts); level-select tiles show 1-3 gold pips; the hub pod shows `N/30` (normal mode). CLEAN and COINS medals no longer exist and medals pay no tickets.
- **Save migration**: `[meta] version` is now 3. A save with version < 3 (or none) has its medal bitmasks replaced when read (`Progress._migrate_medals`): a level's tier comes from its stored best time vs par when there is one (hard likewise), else bronze if the level was cleared, else none; the old PAR/CLEAN/COINS bits are dropped. It is a pure function of the old data, so reading the same old save/save code repeatedly gives the same result, and the next save is version 3 (small ints are then read as tiers). Hostile values are clamped (bad times fall back to bronze). `[wallet] clears_paid` / `hard_clears_paid` are no longer read or written. The ticket balance still lives under `[wallet] globs` / `globs_lifetime` (old key names kept on purpose so old saves and `SLIME1-` codes load). Newer saves loaded in an older build would misread tiers as bitmasks; that is not handled.
- **Slime reserve (ASSIST)**: after 3 dry-ups on one story level this session the dry-up screen adds an ASSIST button (+10% slime for that one attempt; never hard mode / randomizer). Assisted wins clear the level but earn no tier/tickets and set no record.
- **Seeds**: the randomizer pause menu shows `SEED n` (press it to copy / type another seed to rebuild that maze); the win text names the seed.
- Save additions (all optional, defaulted): `[meta] version`, `[wallet] globs, globs_lifetime, random_day, random_paid`, `[hats] spins, rainbow_pity`, `[medals] level_N`. RESET PROGRESS clears them. Debug flags `--tickets=N`, `--medals=3,2,1` (tiers for levels 1, 2, ...).
- Tests: `test_tickets` (faucet, cap, wheel, save, migration, save codes), `test_medals` (tiers, par, all_medals, pips), `test_mercy`, `test_seed`, `test_hub`; demos `demo_rewards` (`--random`, `--slow`, `--best=N`), `demo_wheel`, `demo_dry --dry-ups`. Shots: `docs/polish-shots/tickets_*`.

## Randomizer rework (tickets in the maze, random start, size by slime, rising wheel price)
- **Random start** (`MazeGenerator.generate_random`): the noise maze, then a seeded start cell among cells whose farthest cell is >= 75% of the longest route (24 seeded tries, then the best seen); the chalice is the cell farthest from it. Adds `maze.ref_steps` (the longest route); `game.gd` calibrates the slime cost per tile on `ref_steps` (so a shorter route only leaves slack, a perfect run uses <= 85%) while par, medals and the ticket use the real start. **Story levels are untouched** (`generate`, start always the corner, no `ref_steps`): their coin keys are `level + cell`, the par and best times derive from the corner-start path, and the 165 coins/dead ends/tutorial cues are all tuned to it, so a different spawn would change keys, par and saved records.
- **Ticket pickup** (removed: see "Ticket goal" below) (`scripts/ticket_spawn.gd` `TicketSpawn`, `scripts/ticket_pickup.gd`): one per randomizer maze, seeded cell. Fraction f = route tiles from the start x slime cost per tile (already includes MORE SLIME) / 100. Eligible 10% <= f <= 60% and start->ticket->chalice <= 92% of the meter; weight = 0.04 + (f/0.6)^2 per cell (now cubed, see below). Over 300 seeds: <20% 6%, 20-30% 12%, 30-40% 17%, 40-50% 28%, 50-60% 38%. Hidden until within 26 px (like the chalice), glints through the fog within 80 px, HUD pod FIND IT / FOUND.
- **Payout** (superseded: see "Ticket goal" below) (`Progress.random_tickets_due`): win 1, +2 pickup, +1 under par (fresh seed), max 4; no MORE SLIME bought -> capped at 1 in all. Daily cap (5 paying wins), seed-repeat rules, assisted = 0 unchanged. Result text: TICKET FOUND! +N / NO TICKET FOUND +N, MORE SLIME = MORE (when capped).
- **Size** (superseded by "Randomizer slime usage" below) (`Levels.random_cells`): base 18-24 x 10-13 times sqrt(1 + 0.1 x slime level), max 30x16 (25x14 average at level 10); hard mode no growth.
- **Wheel price** (`Progress.spin_cost_after`): first spin free, then 12, 14, 16 ... capped at 40; shown in the wheel hint and the hub prompt. Saved only through the existing `[hats] spins`.
- Tests: `tests/test_random_tickets.gd` (new), updated `test_tickets`, `test_rainbow`. Shots: `docs/polish-shots/random_*.png`.

## Jelly swap, skin atmosphere, story
- **JELLY toggle** (`skins_screen.gd _toggle_jelly`): switching also wears the worn skin's other version when it is unlocked (`Progress.select_skin(id, view_jelly)`); otherwise the worn skin stays and the status line says `SOLID LOCKED - HARD CLEAR L#` (or the existing jelly lock text). Test `test_jelly_swap`.
- **Skin atmosphere** (`Skins.atmosphere_color/tinted`, `Themes.fog_colors(theme, tint)`, `Ambient.create(theme, reduce, tint)`, `Game.atmosphere_tint`): fog colors lean 32% and motes 40% toward the worn skin's hue at the theme color's own brightness (so fog stays as dark as before; Dark/Normal/Bright untouched); rainbow and stopwatch use neutral warm gold. Trail, light halo and splat bursts were already skin-colored. Shots `docs/polish-shots/skinfx_*.png`; test `test_atmosphere`.
- **Story** (see `docs/story.md`): `scripts/story.gd` (all text), `scenes/story.tscn` + `scripts/ui/story_screen.gd` (intro/finale cards), `Progress.story_seen` (bits, optional key, reset by RESET PROGRESS; tests and `--unlock-all` start with both seen). Intro: plays automatically on the first launch of a fresh save (`Story.launch_due`, checked by the boot title in `title.gd`, then wipes into the title; PLAY on a fresh save goes straight to level 1), replay via the title's STORY button. Finale: `Game.play_next` after level 10 (once). Level banners: `Hud.show_area_name(name, line)`. Demo `tests/demo_story.tscn`; test `test_story`; shots `docs/polish-shots/story_*.png`.

## Story layouts v4 + spawn picker (2026-10-13)
See [level-design.md](level-design.md). `scripts/spawn_picker.gd` places the start for the randomizer
(per seed: 33% outer edge ring, 30% within 2 cells of it, 37% anywhere; route >= 60% of the longest)
and for the 10 story levels (a fixed class per level in `Levels.DATA.spawn`, cell drawn from the level
seed: 4 edge, 3 near, 3 interior). Story mazes were rebuilt (`MazeGenerator.generate_level`: straighter
runs, shortcut loops on L6-10, coins in deep dead ends first) on searched seeds whose routes stay within
~5% of the old ones. Both modes calibrate the meter on the real start-to-chalice route (the randomizer
no longer uses the longest route, `ref_steps` is gone). `[meta] version` 4: old saves keep each level's
coin COUNT (re-mapped to the new coin cells), tiers, records and hard data (`Progress._migrate_coins`).
The "Story levels are untouched" note in the randomizer section above is superseded. Overview shots:
`tests/demo_overview.tscn` -> `docs/polish-shots/spawn_*.png`.

## Randomizer slime usage (2026-10-13)
Each randomizer seed rolls a usage u (median 0.58, middle half 0.42-0.72, ~2.5% at or under 0.20,
~2.2% at or over 0.90, range 0.10-0.95); the player's meter is fixed (136 tiles x MORE SLIME) and the
route is built to u of it (the maze size followed u until the size rework below). Spawn
classes unchanged; the chalice sits exactly at the target route; tickets adapt (NONE HERE when no
cell fits). (The win text no longer shows slime usage: USED N% / EFFICIENT! removed 2026-10-14.) Story levels untouched. See
[level-design.md](level-design.md) section 5; test `tests/test_random_usage.gd`. CLAUDE.md's line on
`Levels` (randomizer 18-24 x 10-13, 85%) is now out of date (not edited: off limits for the agent).

## Hat audit (2026-10-14)
Full Mad Hatter pass (findings, changes and what's still imperfect: `docs/hats-audit.md`; shots
`docs/polish-shots/hats_before_*` / `hats_after_*`). Hats are fitted to the slime's measured head in five widths
(NARROW / NORMAL / WIDE / SQUEEZED for sideways splats / BROAD) plus LOOSE (off the head: flying, hat wheel);
`Hats.lift` raises a hat 1-3 px in the few frames where it would cover the eyes; head_point ignores sparkles.
Diagnostic contact sheets: `tests/demo_hat_audit.tscn` (`-- --unlock-all --out=/abs/dir`); checks:
`tests/test_hat_fit.gd` (also runs `python3 tools/make_hats.py --check`).

## Dev toggles (2026-10-14)
Dev mode only (`--unlock-all`, i.e. `./tools/play.sh --dev`; `Progress.dev_tools`). In a level:
- **F1 = FULL BRIGHT**: hides the fog layers (maze fog + outer fog) and the HUD vignette and shows the chalice
  and ticket, so the whole maze, its border, coins, chalice and ticket are seen at full brightness. The fog/trail
  bytes and reveal/fade logic keep running untouched underneath; F1 again restores exactly the normal fog (the
  chalice/ticket go back to whether they were really reached meanwhile).
- **F2 = NO DRAIN**: gliding and leaping cost no slime (never dries up); F2 again and the meter drains on from
  where it is.
- On a Mac keyboard press **fn+F1 / fn+F2** (or turn on "Use F1, F2, etc. keys as standard function keys").
  The pause menu (Esc / P) also has a DEV panel with BRIGHT / DRAIN switches. A key a control was remapped
  onto is left to that control.
- A pink `DEV BRIGHT NO DRAIN` tag shows under the meter while either is on (never built in normal play).
- Kept for the session across restarts (`Progress.dev_bright` / `dev_no_drain`), never saved. A run with either
  used is marked like an assisted run: no medal, record or tickets (the result says DEV TOGGLES: ...); the win
  flow is otherwise unchanged. Code: `game.gd` "dev toggles" section, `hud.set_dev_badge`, `pause_menu.gd`
  `_build_dev_panel`. Test: `tests/test_dev_toggles.gd`.

## Maze border art (2026-10-14)
The unbreakable edge outside the maze used to be one ring of identical plain bricks. Now
`MazeTiles.add_border` lays the ring (collides exactly as before: full wall square, `BORDER_SOURCE`) plus
`EDGE_FOG` more tiles of bedrock (no collision, `BORDER_DEEP_SOURCE`; the same art) from each theme's
`assets/sprites/themes/<id>_border.png` (16x8 tiles, `tools/make_theme_art.py`, section "the border"):
- **Corner terrain:** each tile corner is rim stone or bedrock (`MazeTiles._corner_stone`: corners on the maze
  edge always stone; one tile out about 45%, two out about 12%, by a smooth integer value noise along the edge plus
  jitter), so the darker, heavier rim (the theme's own wall constructions, in patches) ends in a wobbly outlined
  edge of varying depth; corners round off naturally. Atlas column = corner mask, rows 0-3 variants.
- **Bedrock** (hue-shifted dark rock: shadows lean violet, lights warm) with sparser "deep" variants further out,
  themed props (row 4: roots + moss in Mossy Mines, sand strata + fossils in Sandstone Sanctum, ice cracks in
  Frozen Fortress, faint lava seams in Volcanic Vault, crystals in Crystal Caverns, bones/skulls, pipes + toxic
  drips, barnacles + seaweed, obsidian glass ...), decorated rim stone (row 5) and eight themed 2x2 boulders
  (rows 6-7) spaced apart.
- Picked by `MazeTiles.border_cells(size, ring, depth, salt)`: pure 64-bit integer hashing of the tile and the
  level's tile seed (`border_hash`), so it is the same every build and on web/desktop; story maze layouts, coin
  keys and the maze's own wall/floor tiles are untouched (art only). No floor under the border (opaque art).
- The border sources are added to a theme's tile set the first time a level needs them (the menu backdrop never
  does; that keeps menus pixel-identical). Static tiles, no shaders, no per-frame work.
- In normal play only the ring shows (when revealed, e.g. by the Brightness light); everything else is under
  the outer fog. F1 (dev FULL BRIGHT) or `tests/demo_overview.tscn` show it all.
- Shots: `docs/polish-shots/border_before_<level>.png` / `border_after_<level>.png` (overview),
  `border_before_edge_*` / `border_after_edge_*` (in-game frame at the top-left corner, Brightness 10,
  `tests/demo_edge.tscn`), `border_after_bright_*` (same with FULL BRIGHT). Test: `tests/test_border.gd`
  (collision, determinism, no overlap with the maze, reveal, `make_theme_art.py --check`).
- `python3 tools/make_theme_art.py` now rewrites only atlases whose pixels changed; `--check` compares.
- Verified: non-border pixels identical to before in 51 frames (title, hub, levels 1-10, hard, randomizer,
  brightness 10, pause) with the border region erased in both trees. CLAUDE.md's "Maze edge" line (a ring of plain
  `BORDER` wall tiles) is now out of date (not edited: off limits for the agent).

## Ticket goal (2026-10-14)
Randomizer mazes (all modes, hard too) have no chalice any more: the gold ticket voucher is the goal,
standing on the old chalice cell (`scripts/ticket_goal.gd` `TicketGoal`, made by `game._make_goal`,
which frees the Chalice node; same 6 px grab circle, so mazes, meter, par and seed codes are unchanged;
`game.goal` is the chalice or the ticket). A win pays by attempt at that maze: 5, 4, 3, 2, then 1 from
the 5th (`Progress.RANDOM_ATTEMPT_PAY`, `random_payout`). Attempts = every start of the same maze (dry-up
RESTART, R / pause restart, REPLAY MAZE, back from UPGRADES), in memory per seed code (`random_attempts`,
not saved), cleared by NEW MAZE / a new maze from the hub. Caps kept: 5 paying wins per UTC day (25/day max),
seed already paid today = 0, typed/replayed seed = 1, no MORE SLIME = 1, assist / dev toggles = 0. HUD pod
`TRY 2  4 TIX` (now `ATTEMPT 2` / `TIX AVAILABLE 4/5`, see below); result `TICKET! ATTEMPT 2 = +4` (+ REPLAYED SEED / MORE SLIME = MORE). The optional pickup
(`TicketSpawn`, `TicketPickup`, FIND IT pod) and the old payout (1 / +2 pickup / +1 under par) are gone.
Details: [level-design.md](level-design.md) section 6. Shots `docs/polish-shots/ticketgoal_*.png`.
CLAUDE.md still says the chalice is the exit everywhere and lists `chalice.gd` only (not edited: off limits).

## No goal glints (2026-10-14)
Owner request: the occasional glint on the chalice and the ticket is gone. Removed: the chalice's
rim glint animation (`chalice.gd` now holds frame 0 of `chalice_sheet.png`; the HUD NEW RECORD
banner still cycles the sheet), the gold twinkle through the fog within 64 px of an unseen goal
(`game.gd` `CHALICE_GLIMMER_*`, `_spawn_goal_glimmer`) and the ticket's top-edge glint
(`ticket_goal.gd` `GLINT_*`). Kept: both goals' pulsing glow, the ticket's 1 px bob (none with
Reduce Motion), the coin glimmers, and the tutorial beacon on levels 1-2. Test: `tests/test_polish.gd`.

## Randomizer maze size no longer follows u (2026-10-14)
Short-route seeds used to make small mazes (down to 10x6). Now every randomizer maze is sized for
the longest route any seed asks for at its MORE SLIME level (`Levels.random_max_route_cells`, u =
0.95) plus the seed's size dice, never below `Levels.random_floor_cells` (18x10 grown by
sqrt(1 + 0.1 x level)) and at most 36x20; u only sets how far the ticket is from the spawn (it can
be close for a rare low-u seed). Average area 189 -> 413 cells at MORE SLIME 0, 367 -> 715 at 5,
516 -> 720 at 10; under the floor 48% / 34% / 26% -> 0%. u distribution, route targets, 136-tile
meter, spawn classes, seed codes' format and story/hard mazes unchanged (golden story + hard lines
byte-identical; MORE SLIME 0/5/10 golden lines rewritten). Build worst case 18 ms (same as batch B),
mean up (7 ms at level 10). Details: level-design.md section 5; benchmark `tests/bench_random_size.gd`;
tests `test_random_usage`, `test_maze_golden`; shots `docs/polish-shots/size_*.png`.

## Attempt pod wording (2026-10-14)
The randomizer HUD pod now reads `ATTEMPT n` over `TIX AVAILABLE k/5` (k = what a win pays now, caps
applied: 5/5, 4/5, 3/5, 2/5, 1/5 from the 5th; 1/5 capped; dim 0/5 when nothing). Two lines because
one line ran into the area name; the area name and the touch pause button move to y 44 in
randomizer mazes. Result screen unchanged (`TICKET! ATTEMPT 2 = +4`). Shots
`docs/polish-shots/size_hud_attempt1.png` / `size_hud_attempt3.png` (`tests/demo_random_ticket.tscn --attempt=N`).

## Attempt pod on restarts (2026-10-14)
Owner report: the pod stayed on `TIX AVAILABLE 5/5` after restarts (except after drying up). Every real
restart route was driven end to end in `tests/test_attempt_restarts.gd` (R at once, R prompt RESTART,
pause-menu RESTART, dry-up RESTART, win REPLAY MAZE, dry-up UPGRADES -> PLAY; normal and dev mode,
headless and windowed with real key events, `tests/demo_attempts.tscn`): the counter and the pod's text
were already right on the restarted run's first frame, and the win paid what the pod showed. What
the player saw was one digit changing silently under the restart's goo wipe. Changes: `game.ticket_offer()`
is the one number the pod shows and a win pays (dev toggles / assist = 0, every Progress cap); the
pod pops when that number changed since it last showed this maze (`Progress.random_offer_shown`,
not saved, cleared with `random_attempts`): after the wipe clears (0.2 s) the TIX AVAILABLE line
flashes white twice and the pod frame brightens, fading out by ~0.5 s (`Hud.ATTEMPT_POP_*`); none
with Reduce Motion, none when the number stays (1/5 from the 5th on). Shots
`docs/polish-shots/attempts_1/2/3.png` (after real R restarts) and `attempts_2_pop.png` (mid-flash).

## Attempt pod: re-derived every frame, no "/5" (2026-10-14)
Owner report: in dev mode (`./tools/play.sh --dev`), Esc then pause-menu RESTART left the pod on
`TIX AVAILABLE 5/5`. Not reproducible: a driver with the exact launch (`-- --unlock-all`, the real
save read-only, saving off), entering through the hub portal and sending real Esc / Down / Enter
key events and real mouse clicks on RESTART (at once, after moving, after drying up, after DEV panel
toggles, during the reveal wipe), windowed and headless, counted 1-10 every time. By code, a pause
RESTART reloads the scene and `_count_attempt` always runs in `_ready`; the counter's key (seed code)
only changes on a new/typed maze. The no-MORE-SLIME cap (1) does NOT apply in dev mode
(`Progress.random_payout` skips it when `dev_tools`), so the owner's dev launch counts 5, 4, 3, 2, 1, 1 (shots `attempts3_*.png`, result `attempts3_result.png`);
normal play keeps the cap. Hardening: `game.payout()` is
the one computation behind the pod and the win (dev toggles / assist = 0; dev mode pays the same,
only unsaved; the win asserts it paid that); `game._process` re-derives the pod every frame
(`Hud.set_attempt` only touches the label when the text changes, so a stale pod can't survive a
frame). Format now `ATTEMPT n` over `TIX AVAILABLE k` (5, 4, 3, 2, 1; 1 capped; dim 0). Pop on a
restart that changes k kept (not with Reduce Motion). `Progress.enable_dev_mode()` = what
`--unlock-all` does (tests use it). `tests/test_attempt_restarts.gd`: every route (R, R prompt,
pause by keys and by mouse, Esc after dry-up, dry-up RESTART, UPGRADES round trip, REPLAY MAZE) x
attempts 1-6 x normal and dev launch, autopilot wins paying exactly the shown k with the result line,
plus hub/NEW MAZE resets, typed seed, no MORE SLIME, daily cap, assist, dev toggles, stale-label fix.
Shots `docs/polish-shots/attempts2_1..6.png` (dev launch, real pause-menu restarts, `tests/demo_attempts.tscn --route=pause --shots=`).

## Dev attempts log (2026-10-14)
Dev mode only (`Progress.dev_tools`, i.e. `./tools/play.sh --dev`): `scripts/dev_log.gd` (`DevLog`) appends one line per
event (ms ticks, event, level/random, seed code, attempt, ticket offer/table/cap, the pod's text, dev-toggle/assist flags,
and which restart route led to a rebuilt maze) to a plain text file, truncated at each launch and capped at ~200 KB.
Events: maze built, pause opened, R prompt opened, each restart route (R, pause RESTART, dry-up RESTART, prompt RESTART,
REPLAY MAZE, NEW MAZE, typed seed, ASSIST, UPGRADES return), pod text changes, win (paid), quit to hub. Inert outside dev
mode and on the web; touches no save. macOS path: `~/Library/Application Support/SlimeTime_R1/dev_attempts.log`
(only for a hand-played `play.sh --dev`); tests, headless, movie and screenshot runs write `dev_attempts_<pid>.log` instead
(stale ones are deleted after 6 h). Test: `tests/test_dev_log.gd`.

## Autoplay: watch the game beat itself (2026-10-14)
`./tools/play.sh --autoplay [--speed=N]` (Windows `tools/play.ps1 -Autoplay [-Speed N] [-Cinematics]`; game flag
`--autoplay`): the game plays the whole story campaign on screen by itself, from a fresh in-memory state
(`Progress.enable_autoplay`, the `--story-complete` pattern: the real save is never read or written, saving off,
throwaway path). Not dev mode (F1/F2 stay off). Inert without the flag and on the web (`Autoplay.requested`).
- **Real game:** real level scenes, physics, fog/trail, meter, coin pickups, result screens and buttons, the R
  RESTART? prompt and the upgrades screen's + buttons (`Progress.buy_upgrade`), medals from the real run timer.
  The bot only presses the movement actions (`RoutePilot`, the old test autopilot's steering, now shared:
  `tests/autopilot.gd` extends it) and the real buttons/keys.
- **Planner** (`scripts/autoplay/autoplay_planner.gd`): knows the maze graph. Per normal level: coin runs =
  nearest-neighbour tour over the coins left + 2-opt/or-opt, trimmed (costliest detour first) to fit
  `0.97 x meter - 0.75` tiles of the game's own meter (`100 / slime_cost_per_tile`), topped up by cheapest
  insertion; legs never touch the chalice early. Ends at the chalice when that collects as many coins as an open
  route, else the run ends with R -> RESTART (or UPGRADES). Coins are spent whenever they buy the next level in
  the order MORE SLIME -> SPEED -> BRIGHTNESS (via R -> UPGRADES at a run's start, or the dry-up UPGRADES button).
  When a level's coins are all found: a clean run on the shortest route (walking, no leaps) for gold (up to 3
  tries). Then victory -> HUB -> STORY archway -> level select HARD MODE box -> hard 1-10, shortest route each.
  Victory -> HUB -> `AUTOPLAY COMPLETE` (top-right in the hub) and control goes to the player; the end state
  stays in memory (165 coins, all upgrades maxed, 30/30 + 30/30, finale seen).
- **Result (measured):** 165/165 coins, every upgrade maxed, gold on all 10 normal and all 10 hard levels, 41 runs
  (23 coin runs, 2 of which already won gold; 18 clean runs), 0 dry-ups; hard 10 by walking used 97% of its meter before
  the hard rebalance below, 78% after (game time now 1711 s). Nothing was out
  of reach, so no leaps are used. Game time 1594 s. Wall time (= frames / 60; a windowed run on the MacBook
  matched this, the game renders 1000+ fps): **~11.2 min at --speed=3, ~5.6 min at --speed=8**, ~0.2 min
  headless with `--autoplay-hold=0.05`.
- **Speed:** `Engine.time_scale = N` and `physics_ticks_per_second = 60 x N` (max steps per frame raised), so
  every tick is 1/60 s of game time and a run plays exactly as at 1x; master volume a little lower above 1x
  (sounds come N times as often); all restored on stop/finish. The story screen plays at 1x.
- **Banner** (`autoplay_banner.gd`, layer 110, bottom-right, band only as wide as its text): `AUTOPLAY  NORMAL L3
  COINS 9/14  ATTEMPT 2` over `COINS 31/165  MEDALS 6/30  PRESS F10 TO STOP` (one line under result buttons and
  in menus). Holds on screens are real time (result 2 s, upgrades ~2-3 s with each purchase visible).
- **Stopping:** F10 (fn+F10 on a Mac) hands over control in place (pilot freed, keys released, 1x); leaving a level
  from the pause menu (Esc -> QUIT TO HUB) does too. Without `--autoplay-cinematics` intro/finale are marked
  seen and skipped; tutorials are marked seen.
- Other flags: `--autoplay-hold=S` (scale the on-screen pauses), `--autoplay-quit` (quit at the end, printing
  `AUTOPLAY SUMMARY {json}`). Log lines start with `AUTOPLAY:`.
- Tests: `tests/test_autoplay_planner.gd` (routes walkable, fit the meter, end on the chalice, paper campaign
  finds 165 coins, meter = the game's, flag inert) and `tests/test_autoplay.gd` (the whole campaign in a child
  process at 8x headless, ~13 s: 165/165, 10 + 10 clears, medal tiers = tier_for(real best time, par), no
  dry-ups, hub at 1x, real save md5/mtime unchanged; F10 and pause-menu hand-over in process).

## Hard-mode rebalance (2026-10-14, save version 5)

Full write-up and table: [level-design.md section 7](level-design.md). In short:
- Hard meter = v4 hard meter x `Levels.HARD_SLIME_MULT` (shipped +10% per level, L1 x1.1 .. L10 x2.0; **the
  single knob**, edit it for a flat +10% etc.). Route = meter / `HARD_ALLOWANCE` (1.12 at L1 rising to 1.28 at
  L10, so a perfect run uses 87.5% .. 77.7%). Mazes grow to fit (12x7 .. 36x20, cap `HARD_MAX_CELLS` = the
  randomizer's 36x20), the chalice on the start's farthest cell exactly `route` away, more dead ends than before
  on every level; built once per session in <= 9 ms headless. Par follows the new routes (17 .. 90 s).
- Normal story mazes and every randomizer maze (hard randomizer too) are byte-identical (golden test); only the 10
  hard story golden lines were rewritten. Upgrades stay off in hard mode; tutorial cues never run there.
- Save version 5: older saves/codes keep hard clears and hard medal tiers but lose their hard BEST TIMES (set on
  the old, shorter mazes); everything else untouched; idempotent. `--story-complete` hard times use the new par.
- Autoplay: all 10 hard levels gold on the first walking attempt (12.3 .. 67.9 s, 14-24% slime left).
- CLAUDE.md's hard-mode line ("HARD_TARGETS 89%-100% budgets ... 85%+") is now stale (not edited: owner-only file).
- Tests: `tests/test_hard_rebalance.gd` (tables, ratios, mazes, par, migration, story-complete) + updated
  `test_phase3`, `test_hard_mode`, `test_spawn_picker`, `test_layout_migration`, `test_tickets` (version 5).
- Shots: `docs/polish-shots/hard_before_l1/l5/l10.png`, `hard_after_l1/l5/l10.png`.

## Trail maps: the MAP TABLE (trial, 2026-10-14)

Owner request: maps that help the player study a story level without taking away the dark-fog discovery.
Full write-up: [level-design.md section 8](level-design.md). In short:
- **Survey** (`scripts/survey.gd` `Survey`, `Progress.maps`, saved under a new optional `[maps]` section, no
  version bump): per story level, normal (key = level) and hard (level + 100) separately: every maze tile
  EVER revealed (bitset, merged over all attempts, across dry-ups, restarts and sessions), one route (start
  cell + 2-bit moves: the fastest unassisted clear, replaced only by a faster one; before any clear, the last
  attempt that moved, flagged and drawn faint as LAST TRY), its time, and whether the goal was seen/reached.
  Coins come from the existing `coins_found` keys (nothing new stored). Randomizer mazes record nothing (fresh
  each time); assisted runs, dev mode (`--unlock-all`) and dev-toggled runs (F1/F2) record nothing; only the
  running scene records (tests' and demos' loose game nodes don't).
- **Capture** (`game.gd` "trail map survey" section): one byte write per newly revealed fog cell into
  `survey_tiles` (in `_paint_cells`, `_reveal_light`, `_reveal_wall`, where the fog is revealed anyway), a
  per-tick tile check that appends a move byte when the slime enters a new cell, and one commit when the run
  ends (`_finish`) or is left (`_exit_tree`). Fog/trail bytes and order unchanged: gameplay frames
  pixel-identical to the baseline (HEAD 791ab83 worktree, 50 frames: the game as the running scene (survey
  live) on levels 1 (through the win screen), 5, 10, 10 with Brightness 10, 7 standing still, hard 3, rainbow,
  randomizer seed 5, plus demo/title/level select/pause; 0 differing pixels; baseline vs baseline also 0).
  Cost: `_survey_step` ~0.2 us per physics tick; a fresh full trail disc ~3 us more (~5%) for the byte writes.
  Autoplay records surveys of all 20 levels (`tests/test_autoplay.gd` checks routes = best clears).
- **Size:** a full survey is <= 568 base64 chars in save.cfg; the save code with all 20 levels fully surveyed
  is 2,543 chars (543 without maps; cap 65,536); a pathological worst case (random bits, 2,000-move routes on
  all 20) is 19,447. RESET PROGRESS clears maps and the first-time hint. Hostile values are dropped or clamped.
- **Seeds:** `--story-complete` seeds all 20 levels fully surveyed (every tile, shortest route as the clear in
  the record time, goal seen); dev launches (`--unlock-all`) start with no maps; `--maps=full` seeds them (any
  launch; not saved).
- **Hub:** a 9th station, the MAP TABLE (`tools/make_hub_art.py` `maptable.png`, 30x36 x 4 lantern frames,
  rows front/side/back like the other stations; warm flickering light pool). Ring order is now story, MAP
  TABLE, upgrades, QUIT trapdoor, coin bag, randomizer, settings, prize wheel, wardrobe (step TAU/9; on the
  web 8 without the trapdoor): the trapdoor moved between the two short stations because next to the tall
  signpost/wheel it overlapped them at the 40-degree spacing. The front/back view arcs are now 35 degrees
  (`Hub.VIEW_ARC`, was 40) so no ring spot rests on a view edge with 7-9 stations; 8-station layouts are
  unchanged. Other stations' art, the rotor, the room shader and vignette are untouched. Contact sheets of
  every rotation state: `docs/polish-shots/map_hub_before_sheet.png` (8 states + mid-turn) and
  `map_hub_after_sheet.png` (9 + mid-turn). CLAUDE.md's hub station order is now out of date (not edited).
- **Screen** (`scenes/maps.tscn`, `scripts/ui/map_select.gd`, drawing in `scripts/ui/map_view.gd` `MapView`):
  MAP TABLE select with 10 goo-framed tiles (two columns, 1-5 / 6-10: thumbnail, name, `L# NN%`, route
  marker = gold drop + best time or dim drop + LAST TRY; NO SURVEY YET and locked until a run there was
  recorded), a HARD switch (view only; the game's mode is unchanged), a one-time hint line (`[maps] hint_seen`).
  A tile opens the MAP VIEW: seen floor (parchment) and walls (ink), unseen tiles dark, the route (goo color
  with a dark edge; faint without it for LAST TRY), found coins on seen tiles, the start ring, the goal X only
  once seen; integer cell/wall px (`MapView.layout`: 36x20 cells fit at 5+2 px), title, SURVEY % and route
  below. BACK / Esc / B: view -> select -> hub (facing the table). Static images, nothing per frame.
- **Tests:** `tests/test_maps.gd` (capture, rules, save/old save/codes/hostile/reset, seeds incl. child
  launches, the screen and its navigation incl. touch, no unseen tile drawn), `tests/test_hub_maps.gd` (every
  rotation state, native and web: views, no overlaps by opaque bounding boxes, pools, y-sorting, use from every
  reachable side), `tests/test_hub.gd` updated for the new ring. Demo `tests/demo_maps.tscn`
  (`--story-complete --map=N [--map-hard] [--partial=N]`). Shots `docs/polish-shots/map_*.png`.
- **Open for the owner:** this is a trial. Decide whether maps should cost something / unlock later, whether
  the select should show the % of walls too, and whether the trapdoor's new spot is fine.

## Map review + navigation QA fixes (2026-10-14)

Fixes for [review-maps.md](review-maps.md) (5 findings) and [qa-nav-report.md](qa-nav-report.md) (B1-B10), each
with a regression test; the fuzzer's `KNOWN` table is now empty, so any of them coming back fails it.
- **Survey layout fingerprint** (review 1, 2): the packed survey is now **version 2** with a 16-byte header; bytes
  12-15 hold `Survey.fingerprint(maze)` (MD5 of size + start + goal + walls, first 32 bits; stable across
  platforms/engine versions). `Survey.fits` compares size **and** fingerprint. Old version-1 surveys can't be
  checked, so `unpack` drops them (those levels show NO SURVEY YET until their next run; the real save's trial
  surveys go this way). A stale survey is dropped by `Progress.survey_for` (tile locked, nothing drawn) and
  replaced by a blank one in `record_survey`, so a slower clear on a re-laid maze sets the new best route.
  `Survey.blank(maze)` now takes the maze. Save code: 2,687 chars with all 20 levels fully surveyed (cap 65,536);
  worst case 19,567.
- **Map never draws on unseen tiles** (review 4): `MapView` clips the route (a step is drawn only if both cells and
  the passage tile were seen), start ring, goal X, coins and thumbnail marks to seen tiles. Sighting the chalice
  marks the goal tile seen (`Survey.mark_seen` in `record_survey`) so its X still shows. Test: a survey with a
  route over unseen tiles, coins on unseen cells and an unseen goal at every view size + thumbnail, and a same-size
  survey of another layout (draws nothing).
- **BEST ROUTE vs record** (review 5): the map shows a route's time only when it is the level's record (same value
  as the level select, `map_select.route_best`); when the record is faster (set before maps existed) the tile says
  ROUTE (no time) and the view `ROUTE 1:02.3  SET A NEW BEST`.
- **Focus locks** (review 3 / B1, B2): `UIKit.lock_focus(screen, modal)` / `unlock_focus` set every focusable
  control outside an open panel to FOCUS_NONE and back. Used by the map view (plus `view_back.focus_next/previous`
  to itself), the SETTINGS SAVE CODE and RESET panels, the pause menu and the R prompt.
- **Pause over result buttons** (B3): the pause menu remembers the focus owner and restores it on resume.
- **Wipe races** (B4, B5, N3): `retry`, `retry_assisted`, `go_to_upgrades`, `go_to_hub`, `replay`, `play_next`
  return while `_leaving()`; `SkinText.recolor` and `Game._ease_in` return when out of the tree.
- **Level frozen under QUIT TO HUB** (B9): the pause menu's QUIT TO HUB and the R prompt's UPGRADES hide the
  overlay but keep the tree paused; `Transition.go` unpauses as it swaps scenes. Nothing can win, dry up or be
  clicked during the wipe.
- **Touch pause** (B6): the `menu` press is released when the finger lifts (or on pause / exit).
- **Victory** (B7): Esc / P / B go to the hub; level 10's CONTINUE now reaches it through the goo wipe.
- **GooBox WeakRefs** (B10): dead refs pruned every 32 registrations (50 hub <-> map cycles: objects 5,549 -> 5,537).
- **Text boxes** (B8, kept by design): the first Esc only stops editing; focus then goes to COPY (SAVE CODE) or
  RESUME (seed box) instead of nowhere, and the second Esc closes the panel / box.
- **Found while fixing:** keeping the level paused under the UPGRADES wipe made `--autoplay` think the player had
  paused and stop (test_autoplay caught it); autoplay now ignores a pause while a wipe is leaving.
- **Fuzzer:** six area walks added (`AREAS`: map table + view, SETTINGS panels, pause, dry-up choices, win choices,
  touch level; 2,000 inputs each, about a third steering back into the area; `--nav-area-steps=N`). Default run:
  7 x 1,200 + 6 x 2,000 = 20,400 random inputs, passes. Eight extra seed runs (about 290,000 more inputs) found
  no new violations.
- **Pixel check:** a HEAD (6cf59c9) worktree vs this tree, 37 frames (title, hub, levels 1/5/10, hard 3, rainbow
  10, randomizer seed 5, pause, dry-up choices, touch level 2): 0 differing pixels.

## Trail maps v2: decluttered screens, wall-line maze diagram, themed mockup (2026-10-14)

Owner feedback: the MAP TABLE tiles were cluttered, and a route that U-turns into the corridor next door looked
like one wide corridor (the wall between was lost under the route's dark edge).
- **Select tiles** (`scripts/ui/map_select.gd`): just the thumbnail, the level's name and the % of its floor
  uncovered (`72%`, gold at 100%); no `L#`, best time, route drop, ROUTE / LAST TRY or NO SURVEY YET (a locked tile:
  lock in the thumbnail, dim name, `0%`). HARD switch and BACK kept; the first-open hint is `PLAY TO FILL THEM IN`.
- **Map view**: the level's name (+ `HARD`), the map, one line `NN% UNCOVERED`; no times, no SET A NEW BEST
  (`route_best` / `route_text` removed; the level select shows the records). A last-try route is drawn faint,
  without text. The map area grew to 316x149 (`MAP_AREA`).
- **Drawing** (`scripts/ui/map_view.gd`, rewritten): the maze's tile grid (cells on odd tiles, walls between) is
  drawn as a diagram: per seen cell a floor block, then the line on each of its sides (ink where the tile between
  is a wall, floor where it is open), posts at its corners. Sizes `[floor px, wall px]` from 21+3 (level 1) down to
  6+1 (36x20 cells, 253x141 px). Route: a band `route_width` (about 1/3 of the floor, same parity, so it is exactly
  centered with floor on both sides) through cell centers: a hairpin's legs are separated by floor, the wall line,
  floor. Goo color, edged in the outline shade when there are 3+ px of floor beside it; otherwise the goo's dark
  shade when the goo is too close to the parchment in brightness (`route_color`, `ROUTE_CONTRAST` 0.22: lemon,
  lime). Coins are gold discs, the start a ring, the goal a symmetric X.
- **Spoilers:** floor only on seen cells; a wall line or doorway only when at least one of its two cells was seen
  (a doorway into the dark shows as a gap: you saw it from the seen side); posts only at seen cells' corners; route
  steps only between two seen cells; coins/start/goal only on seen cells; a foreign or stale survey draws nothing.
  The wall tiles' own seen bits are no longer used for drawing (the cell bits decide).
- **Thumbnails:** the same diagram at 2+1 or 1+1 px when the maze fits 36x20 px (levels 1-5 normal), else one
  block per cell (levels 6-10, all hard mazes: wall lines would not fit). Dimmer colors than the view.
- **Themed maps (mockup, OFF):** `MapView.render(..., theme)` / `thumbnail(..., theme)` draw a level in its theme's
  palette (`MapView.THEMED`: paper tinted to the theme, ink walls and a trail color from the theme's tile palette in
  `tools/make_theme_art.py`, the theme's fog behind) with a 4 px themed frame (`_draw_frame`: stone joints, moss
  tufts, sand strata, wave crests, pipe bolts + toxic drips, bones, frost, glossy glints, crystals, lava glow;
  integer hashing, accent studs in the corners). Off in the game: `map_select.THEMED_MAPS = false`;
  `tests/demo_maps.tscn -- --themed` turns it on there. Sheets for the owner: `docs/polish-shots/map_themed_sheet.png`
  (all 10 levels), `map_themed_l5.png`, `map_themed_l10.png`, and the default style `map_default_sheet.png`. To
  enable: set `THEMED_MAPS = true` (nothing else needed).
- **Demo:** `tests/demo_maps.tscn` also takes `--uturn=N [--uturn-try]` (a walk along level N's shortest route to a
  few cells past its first hairpin, only the tiles beside it seen) and `--themed`.
- **Tests** (`tests/test_maps.gd` `_test_drawing`, screen checks updated): no pixel on unseen cells at all 17 sizes,
  plain and themed (route, coins, goal over unseen cells included); no line or post between two unseen cells; every
  wall beside a seen cell drawn; 36 hairpins on levels 5/10 normal + hard keep a whole wall line between their legs
  with floor on both sides, and the demo's partial U-turn too; every story/hard maze (36x20 max) fits 316x149 at
  whole pixels, themed too; thumbnails clean on unseen cells and inside 36x20; tiles show exactly name + %; no
  times or route labels on either screen; THEMED_MAPS off.
- **Shots:** before/after `docs/polish-shots/map_v2_select_before.png` / `map_v2_select.png`,
  `map_v2_view_uturn_before.png` / `map_v2_view_uturn.png` (level 5, grape), plus `map_v2_view_hard10.png`,
  `map_v2_view_l3.png`, `map_v2_view_partial_l7.png` (faint last try with a hairpin); themed select `map_themed_select.png`.
- **Pixel check:** HEAD (cc2d7fe) worktree vs this tree, the batch capture set (title, hub, rainbow hub, level
  select, levels 1/5/10 autopilot, Brightness 10, standing still, hard 3, rainbow 10, randomizer seed 5, story
  intro, pause; 51 frames): 0 differing pixels. Web export (Web preset) to a temp dir: OK.
- **Open for the owner:** look at the themed sheet and decide; thumbnails of levels 6-10 and hard mazes stay blocks.

## Trail maps v3: red route, example-maze tiles, themed maps on (2026-10-14)

Owner feedback on v2 + the themed mockup:
- **Route color:** a thin red line (`MapView.ROUTE` = (222, 24, 40)) whatever skin is equipped, on every palette;
  `route_color`, `ROUTE_CONTRAST`, the goo/edge colors and every skin input to MapView are gone (`palette(theme)`,
  `render(maze, survey, sizes, coins, theme)`; map_select no longer reads the skin). 1 px through the corridor
  centers; to center it exactly every map size now has an odd floor (`SIZES`: 21+3 ... 5+2, 5+1; 36x20 cells now
  5+2 plain / 5+1 themed). The last try is dashed (2 on / 2 off) and 30% faded toward the paper. The goal X is
  drawn in the ink now (a red X would merge with the route's end).
- **Select tiles = example mazes, not the real map** (`MapView.preview` / `example`): an 8x4-cell made-up maze per
  level and mode (growing tree from integer hashing of the level number; 20 distinct, identical for everyone,
  nothing from the real layout), drawn at 3+1 px in the level's palette with a 1 px frame in its motif (35x19 px).
  Locked: dim sealed frame + lock. Surveyed: floor(% x 32) cells lit, breadth first from its start, rest dark; the
  red example route only with a recorded route (faint for a last try); a gold frame (`PREVIEW_GOLD`) at 100%. The
  tile still shows just name + %. Example mazes and textures are cached (static) by state; nothing per frame.
- **Map view:** unchanged (the player's real survey, spoiler rules, coins, start/goal, `NN% UNCOVERED`) except the
  red route and themed rendering, now on: `map_select.THEMED_MAPS = true` (set false to return to the parchment
  style everywhere, previews included). `tests/demo_maps.tscn` adds `--set=N:P[:best|try]`, `--lock=N`, `--plain`.
- **Tests** (`tests/test_maps.gd`): odd floors / 1 px route; same red on every palette, contrasting every paper;
  the opened map identical with lime, lemon, crimson, inkky and frost equipped; palettes for all 10 levels (hard
  uses its level's); example mazes whole, distinct (20), not a real level's size, deterministic when rebuilt,
  cached; lit cells = floor(% x 32) (0/5/22/40/60/85/99/100%), none locked; route only when recorded; gold only at
  100%; two different surveys of level 5 at the same 37% give byte-identical tiles; no `_process` on the screen;
  the existing no-unseen-leak checks (plain + themed, all sizes) still pass. `./tools/test_all.sh`: 54 suites, 0 failed.
- **Shots:** `docs/polish-shots/map_v3_select.png` (locked 4/9, 22%, 22% + try, 60% + try/best, 85%, 100%),
  `map_v3_view_l3_lemon.png` (light), `map_v3_view_l8_inkky.png` (dark), `map_v3_view_l10_ember.png`,
  `map_v3_view_l5_crimson_uturn.png` (red skin, partial hairpin), `map_v3_view_l7_lime_lasttry.png` (dashed),
  `map_v3_previews_sheet.png` (10 levels x locked / 22% / 60% try / 100% best / hard 100%, 6x).
- **Pixel check:** HEAD (d18cc85) worktree vs this tree, batch capture set (51 frames: title, hub, rainbow hub,
  level select, levels 1/5/10, Brightness 10, standing still, hard 3, rainbow 10, randomizer, story, pause):
  0 differing pixels. Web export to a temp dir: OK. Real save md5 unchanged.

## Release hardening pass (2026-10-14)

Fixes for docs/qa-release-report.md and qa-web-report.md (each item, its fix and test are in the Status table there):
S1/S11 allow-list validator (`SaveText`), S10 bounded gunzip, S2 corrupt-save backups, S9 atomic writes + retry,
S3 pay-day clamp (`PAY_DAY_AHEAD`; `test_tickets` updated: a clock 5 days back keeps the cap but the stored day becomes
today), S4/S6/E1/E2/E3 small validation fixes, mangled-code cleaning, X1 Windows icon/metadata, X2 release flag gating
(`Progress.game_args`, `user_args`; game code reads flags through `user_args()`), macOS preset, web O3 (ROTATE YOUR
DEVICE) and O4 (FULLSCREEN disabled without the Fullscreen API). The QA PoCs in `tests/qa_poc_*.gd` now show the fixed
behavior and their inputs run in `test_save_robust.gd` every time. M1 (memory per level start) was checked: no unbounded
script cache; left open as engine-internal.


## Touch: level 1 move hint stuck on screen (2026-10-14)

Reported from a phone on the itch web build (fresh save, level 1): the d-pad glyph stayed after moving with the touch
joystick; gone after a hub round trip; fine with WASD. **Root cause (not the input device):** `TutorialCues` already
detects the first move / leap from the slime itself (position displaced; any state but GLIDE/STUNNED = a charge), so
touch was detected and `tutorial_seen` was saved (hence gone after a restart). But `_process` only called
`queue_redraw()` while an alpha was > 0, so the frame where the alpha reached 0 was never redrawn and the canvas kept
the last drawn glyph. At 60 fps that stale frame is ~5% alpha (invisible with WASD on a desktop); a long frame on the
first glide (a phone browser's stall as the trail, drips and sounds start; `delta * FADE_SPEED >= 1`) took the alpha
from 1 to 0 in one step and left the full glyph on screen. Same flaw for the SPACE/JUMP key and the chalice beacon.
**Fix** (`scripts/tutorial_cues.gd`): `drawn_alpha` remembers what the last `_draw()` showed and one more redraw runs
after everything reaches 0; a fade step uses at most `MAX_FADE_STEP` (1/30 s), so a hitch can't skip the fade. Also
`scripts/ui/touch_controls.gd` only releases actions it pressed itself (`_held`): with the controls up (`--touch`), the
first keyboard key hid them via `_release_all()`, which released that key's own move action (the slime didn't move).
**Test** `tests/test_touch_cues.gd` (real InputEventScreenTouch/ScreenDrag on the joystick, a tap on JUMP, vs keys; normal
and `--touch` UI; `--web-ui` only changes the hub): move glyph cleared in 22 frames and JUMP key in 21 for keys and
touch alike, both bits in the saved `tutorial_seen`, beacon cleared after a move by either device, a 0.5 s frame
mid-fade still fades and clears. The old code fails 16 of its checks. Shots: `tests/demo_touch_hint.tscn` (`--hitch`)
-> `docs/polish-shots/touchhint_1_before.png`, `_2_fading.png`, `_3_after.png`.

## Level select: roomier tiles (2026-10-14)
Tiles are 48x42 (grid at (30,22), 3 px gaps; was 44x38 crammed). The 14 px digits / lock stay ink-centered on the tile, in every state (locked, open, cleared, with time), so the number never jumps. The 7 px record time sits 3 px under the digits and 3 px above the frame's bottom edge (the 2 px letter drips, which the text shader grows under every glyph, fill 2 of each 3, leaving 1 clear). Gotcha fixed: the 8 px time Label's minimum width (52) was wider than the tile, so it grew and the "centered" time sat ~3 px right; it now uses `clip_text` with a 9 px high box. Info panel (14,111) 292x48, HARD toggle y=143, BACK unchanged. `tools/measure_tiles.py --gaps` prints the pixel gaps above/below the time; `tools/zoom_crop.py` makes the 4-8x crops (`docs/polish-shots/levelselect2_*.png`). `tests/test_level_tiles.gd` checks the geometry (gaps 1-3 px, margins, centering, no overlap, widest times).

## Upgrades v2, batch 1: core coin tree rework (2026-10-15, save version 6)
Spec: [design/upgrades-v2.md](design/upgrades-v2.md) A2 (owner rule: few big breakpoints, brightness visible per step).
- **`scripts/economy.gd` (`Economy`)**: the one tuning table. `COIN_TRACKS` = MORE SLIME costs 1,4,7,9,10,12,12 (x1.15 ...
  x2.00), SPEED 8,12,16,24 (x1.12, 1.25, 1.37, 1.50), BRIGHTNESS 12,16,22 (light reach +8 / +16 / +25 px), dev WALL POWER
  4 free levels (x2.5 per level of the old damage formula). 55 + 60 + 50 = 165. `REVEAL_RADIUS` 9 / `RELIGHT_RADIUS` 20
  (= `game.gd` `TRAIL_RADIUS` / `LIGHT_RADIUS`, test-checked): reveal 9/17/25/34 px, relight 20/28/36/45 px, lit area
  +257% / +116% / +85% per step. Later batches add their tables here.
- **`Upgrades`** API is per track: `max_level(id)`, `cost(id, level)`, `total_cost(id, level)`, `value(id, level)`,
  `slime_factor` / `slime_percent` / `speed_factor` / `light_reach` / `reveal_radius` / `relight_radius`,
  `migrate_level(id, old_level)`. `MAX_LEVEL` is gone; the `about` strings are gone (the screen prints effects).
- **Upgrades screen**: one 10x6 pip per level (4 px gap), right-aligned against the -/+ buttons whatever the track
  length; the second line is the effect now -> next (`SLIME X1.45 -> X1.60`, `LIGHT 9 -> 17 PX  +257% AREA`, `MAXED`);
  the buy sound rises over the track's length. Shots: `docs/polish-shots/upgrades2_{fresh,mid,bright2,maxed}.png`.
  Not built (deferred, cosmetic): the RECOMMENDED tag on MORE SLIME and the 1 s light-ring preview on a BRIGHTNESS buy
  (the screen has no slime preview to draw it on).
- **Migration** (`Progress._migrate_tree`, run in `_read` before the never-spend-more-than-found check): a save without
  `[upgrades] tree = 2` (or with a non-int / lower mark) holds old 0-10 levels; each track maps to the highest new level
  whose cumulative cost fits the coins invested (n(n+1)/2), the rest is back in hand automatically (coins are derived).
  SLIME 10 -> 7, SPEED 10 -> 3 (+19), BRIGHTNESS 10 -> 3 (+5), SLIME 5 -> 3 (+3). Old dev power p -> floor(p / 2.5)
  (not counted as coins returned). `tree_refund_notice` (saved as `[upgrades] refund_notice` until shown, clamped to coins
  in hand) drives the hub panel UPGRADES REWORKED / COINS RETURNED +N (5 s, then fades; `hub.gd` `_show_tree_notice`,
  `Progress.take_tree_refund_notice` clears and saves it). Save codes migrate through the same `_read`. New-tree levels
  clamp to each track's top. `SaveText` is a syntax allow-list (no key names), so the new keys needed no change there.
  RELEASE_EPOCH stays 1; pre-epoch saves are still never read.
- **Randomizer / seed codes**: meter = 136 tiles x `slime_factor(L)`; the route maths is now in 1/100000 tiles with the
  factor in hundredths, so an equal factor gives exactly the old route; floor size grows with sqrt(factor). Codes `N-L`
  carry L 0-7; a typed old L 8-10 clamps to 7 (old 10 = new 7: same maze), old 1-7 builds the new level's maze.
  Golden data rewritten on purpose: `random s 5` lines became `random s 4` (new mazes, x1.60) and `random s 10` became
  `random s 7` with byte-identical digests; story, level 0 and hard lines unchanged.
- **Flags**: `--upgrades=a,b,c` takes new-tree levels (clamped 7/4/3); `--story-complete` keeps 0 upgrades + all coins.
  `tools/promo/make_promo.ps1` flags re-mapped (0,0,10 -> 0,0,3; 0,0,8 / 0,0,6 -> 0,0,2; 6,4,7 -> 4,1,2), not re-rendered.
- **Ticket cap** unchanged (no MORE SLIME = 1 ticket); SLIME 1 still costs 1 coin.
- **Story difficulty check** (playtime-estimate.md note): with the design's median coins before levels 2-10, the meter at
  each level start is -4.2% .. +3.6% vs the old tree (spec table: worst -7% at L5, -6% at L8; every allowance >= 1.82);
  the test autopilot wins every normal level at those levels and at SLIME 0; `--autoplay` still gets 165/165 coins, buys
  7/4/3 and golds all 20 normal + hard levels; the planner campaign on paper takes 33 runs.
- **Tests**: new `tests/test_upgrades_v2.gd` (table, radii, real-level reveal per level, migration of every old level per
  track incl. hostile values, file + code paths, idempotence, notice once, seed codes, route equivalence, screen layout
  in 4 states); `test_fog_bytes` replays the new radii against the reference fog; updated coins/extremes/planner/
  autoplay/random/tickets/save tests. Shots of the light: `tests/demo_brightness.tscn` ->
  `docs/polish-shots/brightness2_{0,1,2,3}.png` (level 4, same frame).
