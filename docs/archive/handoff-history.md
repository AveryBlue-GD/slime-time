# Handoff history (archived 2026-10-15)

> Archived long chronological history, moved out of [../handoff.md](../handoff.md), which now holds only the current state. Where this file disagrees with handoff.md or CLAUDE.md, those win (e.g. its "Current state" bullets below were the running log up to 2026-10-15; the workshop and abilities details changed several times).

## Current state (2026-10-15)

- **Abilities only in randomizer + Descent (latest, owner).** `Abilities.allowed_in(game)` = randomizer maze or Descent, not hard mode; every story level (normal, hard, HEAT) has no runner, HUD strip, touch buttons or key effect. TICKETS hint: KEYS 1 2 3 - RANDOM MAZES + DESCENT. The hard-mode randomizer stays off (hard mode = no upgrades). `test_abilities` runs on randomizer mazes (`_spawn`) and checks story normal/hard/HEAT inert (`_inert`).
- **Abilities: one charge only (latest, owner: too powerful).** `Economy.ABILITIES` charges = [1,1,1] for all three; L2/L3 only raise range/radius. HUD strip and touch buttons show the icon lit/dimmed, no pips. Tests in `tests/test_abilities.gd`; shots `docs/polish-shots/abilities3_*.png`.
- **Abilities v1 + plain COINS rows.** The cauldron's COINS rows lost their explanation lines (owner: "just let them be"): name, uniform bar, - / +, cost / MAX; RECOMMENDED sits under MORE SLIME's name; the BRIGHTNESS ring picture has no text. A TICKETS tab is back (`Economy.ABILITIES_ENABLED := true`; the workshop stays off) selling three active abilities, 3 levels each (ONE charge per attempt at every level; tiers only add strength): SLIME RIFLE (15/30/50 tickets, 2% slime, a shot that pierces walls for 8/11/14 tiles), SLIME SPLAT (18/35/55, 4%, bomb lobbed over walls 4/5/6 tiles, reveals 3x3), SLIMAKAZE (25/45/70, 30% on impact (into the goal too), dash to the wall + seeded splatter over walls within 6/7/8 tiles; with <= 30% left it dries you up). Keys 1 / 2 / 3 (remappable, CONTROLS page now two columns), touch buttons by JUMP, a HUD pod of icons (lit = ready, dimmed = used). On in story normal, randomizer and Descent; off in hard mode / HEAT. Par, payouts and seed codes untouched; reveals count for trail maps. Files: `scripts/abilities.gd`, `scripts/ability_runner.gd`, `Slime.State.DASH`, `game.gd` `reveal_tile` / `paint_streak` / `spend_slime` / `shake`, `[abilities]` save section, `--abilities=r,s,k` flag. Tests: `tests/test_abilities.gd`; demo `tests/demo_abilities.tscn`; shots `docs/polish-shots/abilities_*.png`. Rules: [design/upgrades-v2.md](../design/upgrades-v2.md) "Abilities v1".
- **MORE SLIME repriced: the premium track (latest, tree 3).** `Economy.COIN_TRACKS`: MORE SLIME 1, 4, 7, 9, 12, 20, 27 = 80 (was 55), SPEED 6, 9, 13, 18 = 46 (was 60), BRIGHTNESS 9, 12, 18 = 39 (was 50); still 165, same lengths and effects. MORE SLIME 1-4 cost what they did, so with the median coins found (MORE SLIME first) normal levels 1-7 start exactly as before and 8-10 one step lower (allowance 1.99 / 2.02 / 1.92, all >= the ~1.8 flat line; table in design/upgrades-v2.md A2.3). Coins in hand are DERIVED (`coins_earned - coins_spent`, spent = levels x current prices), so `Economy.TREE_VERSION` is 3 and tree 2 saves are repriced on load (`Progress._migrate_prices`, old prices in `Economy.TREE2_COSTS`): per track rounded down by coins invested, then levels bought back up to what was held while the coins found cover them; never negative, idempotent, freed coins join the one-time COINS RETURNED notice. The owner's "-4" in `upgrades3_b.png` was a debug shot: `--upgrades=3,2,1` over the real save's 40 coins (read-only) = 44 spent; now `Progress.settle_debug_coins` pads debug coins so debug flags never leave a negative balance, `--coins=N` works in any flag order, and the HUD / cauldron / hub board clamp the shown number at 0. No real-player path went negative (buy checks the price; load drops levels until spent <= found), except that an unmigrated repricing would have. Tests: `tests/test_slime_pricing.gd` (table, per-level meter, autopilot at median buys, repricing, no-negative display, debug flags); test_upgrades_v2 / test_autoplay_planner / test_story_complete updated. Shots `docs/polish-shots/upgrades4_{zero,partial,max}.png`.
- **Workshop switched OFF, upgrade bars uniform.** One flag, `Economy.WORKSHOP_ENABLED := false` (scripts/economy.gd), disables the ticket workshop (SECOND WIND, QUICK CHARGE, STICKY, MAGNET, GOO NOSE): `Progress.workshop_level` reads 0 and `workshop_open` is false (so nothing applies in story / randomizer / Descent / hard, no WIND tag, the randomizer payout ignores SECOND WIND, the hub cauldron '!' is off), the cauldron builds only the COINS page (no tab bar, no TICKETS page, no confirm). `Progress.workshop` keeps any saved levels (file, save code, reload; `workshop_saved_level`) so flipping the const to `true` restores everything with no other change. Test hook `Economy.workshop_force` (-1 follow the const, 0 off, 1 on): test_workshop / test_store / test_descent force it on; `tests/test_workshop_off.gd` covers the off state (and the flag-on screen). Descent boons, Heat, hats, trails, papers are unaffected. COINS bars: every track is one 83 px bar (x 139..222) of whole-pixel segments with 1 px gaps (7 x 11, 4 x 20, 3 x 27; `BAR_WIDTH`, `PIP_GAP` in upgrades_screen.gd), measured in test_workshop_off.gd; shots `docs/polish-shots/upgrades3_{a,b,c}.png` (0 / 3,2,1 / max). The older bullets below still describe the workshop as it behaves with the flag on.

Read [CLAUDE.md](../../CLAUDE.md) for the project facts and [README-docs.md](../README-docs.md) for the docs index. The sections
below this summary are the history (oldest first, newest last); where they disagree with this summary or with CLAUDE.md,
this summary and CLAUDE.md win.

**What exists.** Godot 4.7.2 pixel-art maze game (320x180). Title (first launch of a fresh save plays the wordless story
intro first) -> round rotating **hub** with 9 stations (story archway, MAP TABLE, upgrades cauldron, QUIT trapdoor with a
LEAVE THE HUB? confirm, coin bag, randomizer portal, settings signpost, hat wheel, wardrobe). 10 themed story levels
(coins at dead ends, upgrades, medals as 1-3 time tiers, wordless finale), **hard mode** (own bigger mazes, meter x
`HARD_SLIME_MULT`), the **randomizer** (unlocked after the story; the gold ticket voucher is the goal, no chalice; payout
5/4/3/2/1 by attempt; per-seed slime usage; seed codes `N-L`), **trail maps** (MAP TABLE), skins (10 presets, rainbow,
Stopwatch for 30 gold medals, CHAMELEON; jelly by default, solid via hard clears), SETTINGS (two columns) with a separate
CONTROLS page and SAVE CODE, 11 placeholder hats (live for players since batch 2), the ticket store (hat wheel + SHOP,
cauldron TICKETS workshop, trail styles, map papers), DESCENT runs and hard-mode HEAT. Save version 6 (+ `[meta] epoch` 1). 70 test suites (`./tools/test_all.sh`); 6 agents in `.claude/agents/`.

**Launch / test.** `./tools/play.sh` (real save), `--dev` (everything unlocked, nothing saved; F1 full bright, F2 no drain,
fn+F1/F2 on a Mac), `--story` (postgame state), `--autoplay [--speed=N]` (the game plays itself; F10 stops it), `--scene
res://tests/demo_*.tscn`. Windows: `tools/play.ps1 -Dev -Story -Autoplay`. Tests: `./tools/test_all.sh` (prints `suites: N
failed: 0`); one suite: `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_X.gd`.

**Save safety.** Only a plain launch touches `user://save.cfg`, which is now the release dir
(`~/Library/Application Support/SlimeTime_R1/save.cfg` on macOS; fresh-start policy, below and in
[itch-release.md](../itch-release.md)). The pre-release save at `~/Library/Application Support/Godot/app_userdata/Slime
Time/save.cfg` stays on disk untouched and is never read. Tests, tools, headless, movie, screenshot and dev runs write
a throwaway file (and may read the real save); `--story` / `--autoplay` use clean in-memory state. Never run the game
yourself when the owner may be playing; launch semantics and preferences are in "Decisions and standing preferences".

**Release hardening (2026-10-14).** Save codes and save.cfg pass the `scripts/save_text.gd` allow-list before
`ConfigFile.parse` (no code execution, no parser crash, bounded gzip: QA S1/S10/S11); saves are atomic (`.tmp` + rename,
retried on failure, `Progress.save_failed`); an unreadable save is kept as `save.corrupt.cfg` (3 rotating); a far-future
randomizer pay day counts as today; release exports ignore debug flags (only `--touch` / `--web-ui`); Windows exe has the
game icon + version info (`icon.ico` from `tools/make_icon_ico.py`); a macOS preset exists (universal, ad-hoc,
`com.slimetime.game` placeholder). Status tables: [qa-release-report.md](../qa-release-report.md),
[qa-web-report.md](../qa-web-report.md); builds: [itch-release.md](../itch-release.md). 59 test suites.

**Economy now (upgrades v2, all 4 batches done 2026-10-15; spec and deviations: [design/upgrades-v2.md](../design/upgrades-v2.md);
every number in `scripts/economy.gd`).** Two currencies. **Coins** (165, hidden in story levels) buy the core tree at the
cauldron's COINS tab: MORE SLIME 7 levels (x1.15 .. x2.0; 1,4,7,9,10,12,12), SPEED 4 (8,12,16,24), BRIGHTNESS 3 (12,16,22),
refundable; old-tree saves are remapped by coins invested (`[upgrades] tree = 2`, hub notice COINS RETURNED +N). **Tickets**
(randomizer wins, DESCENT pots, HEAT bounties) buy: hat wheel spins (free, then 12, 14 .. 30; 210 for all 11 hats), the
SHOP (TAILOR hats 45 / rainbow 80 after 3 spins, 5 trail styles, 3 map papers; 240 for cosmetics), and the cauldron's
TICKETS tab WORKSHOP (SECOND WIND, QUICK CHARGE, STICKY, MAGNET, GOO NOSE, 3 levels each; not refundable; off in hard
mode). Hats are live. **DESCENT** (portal -> RANDOM MAZE / DESCENT): chained randomizer-sized floors, boons, a ticket pot
(2 paying runs per UTC day; milestones floors 5/10/15/20; ABYSS trail at 10). **HEAT** (hard level select, HEAT button): six
modifiers, bounties 3/5/7/10 tickets at heat 2/4/7/10 per level (250 in all), flame badges, EMBER trail at heat 7+ everywhere.
Rules: level-design.md sections 9 (Descent) and 10 (Heat); per-batch history at the end of this file.

**How to test the new economy.** Suites: `test_upgrades_v2` (tree, migration), `test_store`, `test_workshop`, `test_trails`,
`test_descent`, `test_descent_runs`, `test_heat` (all 48 masks winnable; `tests/bench_heat.gd` is the 480-run sweep, minutes
long: `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 10000000 -s res://tests/bench_heat.gd`). By hand, with
saving off: `--upgrades=a,b,c` (new-tree levels, max 7/4/3), `--tickets=N` (a ticket balance), `--workshop=w,c,s,m,n`,
`--trail=ID`, `--paper=ID`, `--descent[=SEED]`, `--heat=dim,fog,race` (or a mask number), `--heat-best=10,7,4`, plus the
older `--dev` (buys free, owns every cosmetic), `--story` (postgame state) and `--unlock-all`. Demo scenes
(`./tools/play.sh --scene res://tests/demo_X.tscn`, most take `--shot=NAME`): `demo_store` (tickets, shop, trails, wind),
`demo_descent`, `demo_heat`, `demo_brightness`, `demo_level_select -- hard heat[-panel]`, `demo_hat_audit`. Review notes with
status: review-upgrades-b1..b4.md; hats live check: hats-audit.md.

**Open tuning questions (need playtests, all priors today).** Are 2 paying Descent runs a day and the pot sizes (1..4 a
floor, max 30) about right against the randomizer's 5 wins x up to 5 tickets? Do the workshop prices (see
`Economy.WORKSHOP`) feel worth it, and is SECOND WIND too strong on coin hunts? Hat wheel price curve and TAILOR 45/80 vs
the 210 total. Which HEAT modifiers do people pick; is 250 tickets for the whole HEAT ladder too generous or too slow; are
heat 4/7/10 reachable (RACE 1.3 x par, THIRSTY on L1 leaves only 7.4% slime for a perfect walk)? Cosmetic prices
(20..40) vs how fast tickets arrive. Whether the randomizer should still give 5 tickets on the first attempt now that
Descent and HEAT also pay.

**Known limitations.**
- Hats are live (`Hats.available = true`, batch 2) but still the 11 placeholder hats until the owner picks the real ones.
- Android and web are unverified on real devices (the Android shader fix is unconfirmed). The web build was QA'd in an
  itch-like cross-origin iframe with phone emulation ([qa-web-report.md](../qa-web-report.md)); the Web preset now uses the
  custom shell `tools/web_shell.html` (Godot 4.7.2's default + marked additions: save flush on hide, storage-blocked bar,
  context-lost RELOAD cover, friendly errors). On a Godot upgrade, re-base it on the new default shell.
- Difficulty numbers are priors, not playtest data ([playtime-estimate.md](../playtime-estimate.md): ~45 min median for the
  story on normal, ~2.1 h with hard).
- Trail maps are a trial (cost/unlock and the trapdoor's spot are undecided). Maps v3 is in: themed maps on
  (`map_select.THEMED_MAPS`), a thin red route whatever the skin, and select tiles that show made-up example mazes
  (never the real map) lit by the % uncovered.
- Windows build zip and itch promo images are out of date (v2.2); only rebuild when the owner asks.

**Fresh-start policy (public release).** Progress from pre-release builds never carries over
([itch-release.md](../itch-release.md)): `user://` is the release dir `SlimeTime_R1` (`project.godot`
`custom_user_dir_name`; web: `/userfs/SlimeTime_R1` in IndexedDB, which itch shares between all games), every save
and code carries `[meta] epoch` = `Progress.RELEASE_EPOCH` (1) and is ignored without it, and codes are `SLIME2-`
(old `SLIME1-` codes say THAT CODE IS FROM AN OLD VERSION). The owner's own local progress starts over too. A future
wipe bumps the dir name, `RELEASE_EPOCH` and the prefix together (see the doc). Test: `tests/test_fresh_start.gd`.

**Open tasks.**
1. Android / web device checks: upload the web zip and run the 5-minute checklist in [qa-web-report.md](../qa-web-report.md) section 6 on a real Android phone and an iPhone.
2. Tuning from playtests (story budgets, hard allowances, randomizer usage curve, ticket payouts, hat wheel price).
3. Optional map v1 as proposed in [advisor/maps.md](../advisor/maps.md) (unlock/cost plan for the trail maps).
4. Real hats from the owner (the wheel, SHOP and wardrobe already work with any `Hats.LIST`; more hats raise the wheel's
   total, see the spec C.1).
5. Optional: merge `v2` into `main`; update the itch page tagline when prepping a release.

The "Open tasks" list further down is from 2026-10-12 and is kept as history.
Notes below saying CLAUDE.md is "out of date (not edited)" were fixed on 2026-10-14; CLAUDE.md now matches the code.


## Original handoff (2026-10-12, history)

Written on the Windows PC before moving to the MacBook Pro. Read this with [CLAUDE.md](../../CLAUDE.md),
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
See [level-design.md](../level-design.md). `scripts/spawn_picker.gd` places the start for the randomizer
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
[level-design.md](../level-design.md) section 5; test `tests/test_random_usage.gd`. CLAUDE.md's line on
`Levels` (randomizer 18-24 x 10-13, 85%) is now out of date (not edited: off limits for the agent).

## Hat audit (2026-10-14)
Full Mad Hatter pass (findings, changes and what's still imperfect: `docs/archive/hats-audit.md`; shots
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
Details: [level-design.md](../level-design.md) section 6. Shots `docs/polish-shots/ticketgoal_*.png`.
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

Full write-up and table: [level-design.md section 7](../level-design.md). In short:
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
Full write-up: [level-design.md section 8](../level-design.md). In short:
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
Spec: [design/upgrades-v2.md](../design/upgrades-v2.md) A2 (owner rule: few big breakpoints, brightness visible per step).
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


## Upgrades v2, batch 2: hats live, ticket store, workshop, cosmetics (2026-10-15, save version 6)
Spec: [design/upgrades-v2.md](../design/upgrades-v2.md) B.2, C.1-C.3, D.1. Every number is in `scripts/economy.gd`
(`RANDOM_ATTEMPT_PAY` etc. moved there; `Progress` keeps aliases), so a balance pass edits one file.
- **Hats live**: `Hats.available = true` (kept as a switch). Wheel unchanged: free, 12, 14 ... 30 = 210 for all 11, no
  duplicates, rainbow pity. The overlay (`scripts/ui/hat_wheel.gd`) is now a full goo panel with **WHEEL | SHOP** tabs
  and a SPIN button (price + ticket icon; F / touch JUMP still spin); every hat won = an empty wheel ("EVERY HAT WON!
  NEW LOOKS IN THE SHOP") and the overlay opens on the SHOP. Spins stay atomic (pay + win + save before the animation).
  COMING SOON is gone everywhere (hub prompt, wheel, wardrobe).
- **SHOP**: sections HATS (the TAILOR: hats still on the wheel, 45 / rainbow 80, after 3 spins, `Progress.buy_hat`:
  atomic, counts as a spin, rainbow pity reset; a non-rainbow buy leaves pity as it is, a buy isn't a roll), TRAILS,
  PAPERS; 2-column goo tiles with price + ticket icon (OWNED / WORN once bought; pressing an owned one wears / takes it
  off), a picture of the focused trail / paper, and a BUY X? [price] BUY / BACK confirm (focus BACK, a dim sheet
  blocks clicks behind it, focus locked inside; Esc / B close the confirm first, then the overlay). Decision: three
  sections instead of one grid (19 tiles don't fit 320x180 with the status lines).
- **Cauldron**: COINS | TICKETS tabs top left, the pod top right follows the tab. TICKETS = the **WORKSHOP**
  (`scripts/workshop.gd`): 5 rows of name, effect now -> next, 3 pips, + and price with the ticket icon; not
  refundable; dimmed with "EARN TICKETS IN THE RANDOMIZER FIRST" until `tickets_lifetime > 0`. Rows are 25 px apart from
  y 24 (the spec's 24 px from 26 put the effect line on the goo band). The hub always opens it on COINS.
- **Workshop effects** (`game.gd` `_apply_workshop`, all off in hard mode and without a bought level; assisted runs
  keep them; dev toggles unchanged): SECOND WIND (`wind_state`: the first time the meter is 0 on the ground it refills to
  15/25/35% over 0.4 s, once per run, upgrade sound + goo ring; story only on levels already cleared on normal; in the
  randomizer `pay_attempt()` = attempt + 1 once it fired, so the pod and the payout drop one step live; HUD: a WIND tag
  under the meter column, bright when ready, dim once used, hidden when not on this run - a tag instead of an icon at the
  meter's end, which had no room), QUICK CHARGE (`Slime.charge_time` 1.2/0.95/0.7 s), STICKY (splat penalty x0.75/0.55/0.40,
  `Slime.splat_stun` 0.2/0.12/0.06), MAGNET (`coin_reach` 18/26/34 px, only coins whose fog cell was ever revealed and
  with no wall tile on the line, `clear_line`), GOO NOSE (`glimmer_rate` x1.5/2/3, `glimmer_reach` 200/240/300).
  Par is computed before any of it (base speed): unchanged. Autoplay starts at workshop 0 and ignores it.
- **Story difficulty impact**: none on first clears (tickets come only after the story, SECOND WIND is off on a level's
  first clear, the free hat spin is cosmetic). On replays (coin hunts, medals) of cleared levels: SECOND WIND adds one
  15-35% refill per run (coin hunts get much easier: a 35% refill is ~1/3 of an extra route on L10's 1.01 allowance);
  QUICK CHARGE saves up to 0.8 s per full leap (leap-heavy gold runs a bit faster, as SPEED already does; par ignores
  both); STICKY turns a 2-5% splat into 0.8-2%; MAGNET saves ~2 tiles each way per dead-end coin; GOO NOSE only shows
  coins sooner. Hard mode and its medals are untouched. Randomizer budgets don't count STICKY/MAGNET (small); SECOND
  WIND is paid for with one payout step.
- **Cosmetics** (`scripts/cosmetics.gd`, prices 20/25/30/35/40 + 25/25/40 = 240): trails INK (skin deep shade, alpha
  150), GLOW (alpha 170, halo 0.6), GOLD (chalice gold, alpha 185, any skin), CANDY (skin / white stripes every 12 px
  traveled on the ground, `game.trail_travel`), STARRY (skin goo + 1 px white specks: `trail.gdshader` `stars`, pixel
  hash, no arrays); all CPU-side cell colors (`Cosmetics.trail_cell`) except the specks; the default style is
  byte-identical to before (test_fog_bytes). The rainbow skin keeps its rainbow trail unless a style is worn.
  Papers BLUEPRINT / NIGHT (ink = skin color) / GOLD LEAF recolor `MapView.palette` (paper, ink, fog, marks, the frame's
  colors with its theme motif; the route stays red); the map view's PAPER button (shown once a paper is owned) cycles
  them; the select tiles keep the theme look. The wardrobe's page button cycles SKINS -> HATS -> TRAILS (owned styles
  worn by pressing; others a silhouette with their price). Dev mode owns every cosmetic and buys everything free.
- **Hub**: the wheel prompt shows the next spin's price with the ticket icon (FREE, or SHOP once every hat is won);
  the wheel and cauldron prompts add a gold "!" when the cheapest unowned item there is affordable
  (`Progress.store_affordable`). The hub ticket pod hides under the overlay.
- **Save**: still version 6 (spec D.1: all additive), epoch 1, `SLIME2-`. New optional keys: `[workshop] wind, charge,
  sticky, magnet, nose` (0-3, clamped; unknown ignored), `[cosmetics] owned` (allow-listed ids once each), `trail`,
  `paper` (back to the default unless owned and of the right kind), `[hats] bought`, `[wallet] tickets_spent`; written
  only once used. `_write` now stores copies of the owned arrays (a direct `_write` -> `_read` no longer aliases them).
  No `save_text.gd` change needed (a syntax allow-list). A full store's code is ~0.7 KB. RESET PROGRESS clears all of it.
- **Flags**: `--workshop=w,c,s,m,n`, `--trail=ID`, `--paper=ID` (own + wear; saving off).
- **Tests**: new `test_store.gd` (totals 210 / 423 / 240 / 873, hats live + no dupes + pity, TAILOR, atomic spin read
  back from the file, workshop + cosmetic buys (exact / short / double / max / dev), round trips through file and code,
  hostile values, reset, epoch; the TICKETS tab, the SHOP with its confirm, the TRAILS page, PAPER), `test_workshop.gd`
  (each effect in a real level: charge 44 vs 91 frames, splat 5% -> 2%, magnet fog / wall / reach, glimmers 32 vs 10,
  SECOND WIND once + first-clear gate + randomizer payout 5 -> 4 live, hard mode off, par unchanged), `test_trails.gd`
  (6 styles x 13 skins in a real level, previews, no errors). Nav fuzz: the lib treats the wheel overlay (or its
  confirm) as a modal, a "rich" start state, a scripted SHOP / confirm Esc ladder, and three new 2,000-input area walks
  (wheel + SHOP + confirm, cauldron tabs, wardrobe pages; the map walk now owns papers): zero violations (also seeds
  77 / 4242 / 9001). Updated: test_hub, test_tickets, test_hats (hats live by default), test_maps (player state).
- **Shots** (`tests/demo_store.tscn`, `--shot=tickets|shop|trails|wind|trail`): `docs/polish-shots/batch2_cauldron_tickets.png`,
  `batch2_wheel_shop.png`, `batch2_wardrobe_trails.png`, `batch2_trail_{gold,ink,glow,candy,starry}.png` (each on its
  level's skin), `batch2_second_wind.png`, `batch2_map_paper_{blueprint,night}.png`.
- Not built (spec, cosmetic): the cauldron preview ring, hat dyes / wallpapers (v2 ideas); Descent / Heat (batches 3-4).


## Upgrades v2, batch 3: DESCENT runs (2026-10-15, save version 6)
Spec: [design/upgrades-v2.md](../design/upgrades-v2.md) C2, D.1-D.3. Rules and numbers: [level-design.md](../level-design.md)
section 9; every number in `scripts/economy.gd` (`DESCENT_*`, `BOONS`).
- **Entry**: the portal (after the story) opens a goo panel RANDOMIZER: RANDOM MAZE (the randomizer as before) /
  DESCENT, a line BEST FLOOR n  PAID RUNS k/2, BACK (`hub.gd` `portal_menu`; focus RANDOM MAZE, up/down wrap, Esc =
  BACK, touch taps; a dim layer swallows clicks). The portal prompt shows BEST FLOOR n once a run was played. Labels
  per the batch brief (the spec said QUICK MAZE).
- **Run** (`scripts/descent.gd` `Descent` = pure rules; `Progress.descent_run` = the run, in memory only): floors
  chained by rebuilding the game scene from the run (`game.gd` `descent`, `_apply_descent`); the meter carries over
  (+60/50/40/35% refill, cap 100%); u = 0.30 + 0.05/floor (+-0.05, cap 0.85); size = the randomizer's (from the
  slime capacity: the owner's no-small-mazes rule beat the spec's route-sized floors); seeded per run seed; themes in
  story order; the exit is the chalice (spec); 2 goo drops per floor (+8%, deep dead ends, under the fog with a faint
  glow, glimmers/MAGNET/GOO NOSE apply, `scripts/goo_drop.gd`); a dry-up ends the run. Normal rules only (the
  HARD MODE setting is ignored in Descent), no ASSIST, no coins, no maps survey, no medals/records besides its own.
- **Boons** (all 11, `Economy.BOONS`): BIG GULP, DEEP TANK (2x), FEATHER LEAP, RUBBER BODY, SLICK (2x), BLAZE,
  CHALICE SENSE, BACKUP BLADDER (stacks; +25% when empty, after SECOND WIND), THRIFT (2x), GREEDY GOO (2x), GLASS
  SLIME. Offers: 3 distinct by weight, seeded by run + floor, non-stacking held / maxed stacks excluded. Icons are
  8x8 pixel art drawn from palette rows in code (`scripts/ui/boon_icons.gd`), 2x on the card, 1x in the HUD strip.
  Capacity boons keep the slime left in tiles; BLAZE past BRIGHTNESS 3 = reach 33 (reveal 42 px).
- **Cards** (`scripts/ui/descent_card.gd`, layer 15 under the pause menu): BOON card = FLOOR n CLEARED, meter + next
  refill, POT n (+gain) (PRACTICE / NO TICKETS / PAYS 1 when capped), 3 tiles (icon, name, two lines, HAVE x/2),
  CASH OUT +N / DESCEND (a tile picks and moves focus to DESCEND; DESCEND without a pick says PICK A BOON FIRST).
  SUMMARY = CASHED OUT / RUN OVER, the floor, BEST FLOOR n (NEW BEST! only past the best before this run), TIME,
  +N TICKETS (and why fewer: HALF THE POT (n), PRACTICE, DEV TOGGLES, MORE SLIME = MORE), milestone lines, the
  boons held; NEW RUN (focused) / HUB (faces the portal). Esc on either opens the pause menu.
- **HUD**: right column DESCENT FLOOR n, the pot pod (attempt pod reused, `hud.set_pot`), the boon strip
  (`hud.set_boons`, 8 per row; BIG GULP not shown, BLADDER only while unused); the area name + FLOOR n under them;
  the touch pause button moves under the strip.
- **Pay**: pot +1/+2/+3/+4 by floor band (+1 per GREEDY), max 30; CASH OUT = all, dry-up / QUIT TO HUB mid-floor =
  half, QUIT TO HUB on the boon card = cash out; GLASS x1.5 after halving, cap 30. 2 paying runs per UTC day
  (forward-only, far-future clamp; a run that banks 0 uses no slot), then PRACTICE; no MORE SLIME = max 1;
  dev-toggled runs (F1/F2 on any floor, carried as `tainted`) pay 0; dev mode pays unsaved (like the randomizer).
  Milestones (once ever, on reaching the floor, saved at once, outside the daily cap): 5 +10, 10 +15 + ABYSS trail,
  15 +20, 20 +25 = 70. SECOND WIND once per run.
- **No reload exploit**: an in-progress run is never saved; closing the app / web tab mid-run banks nothing and uses
  no paying slot (milestones and the best floor were already saved on reaching). A floor cannot be replayed: the
  pause menu has no RESTART in Descent (a note says what quitting banks), R does nothing, NEW RUN is a new seed.
- **ABYSS trail** (earned, never sold): `Cosmetics` entry with `earned`, left out of `Cosmetics.ids()` (the SHOP,
  totals) but in `trail_ids()` (wardrobe: locked tile says REACH DESCENT FLOOR 10); dark violet goo + specks;
  `can_buy_cosmetic` refuses it; a save claiming it without the floor-10 milestone drops it on load.
- **Save**: `[descent] best_floor, best_time, runs, paid_day, paid_runs, milestones` (written only once played;
  clamped on read: best floor <= 999, paid_runs <= 2, milestones 4 bits); no `save_text.gd` change; version 6, epoch 1;
  a played save's code ~650 chars; RESET PROGRESS clears it.
- **Flags**: `--descent` / `--descent=SEED` start a run. Autoplay bot: not extended (cheap demo instead:
  `tests/demo_descent.tscn --shot=demo` plays floors with the test autopilot, picking the first boon).
- **Tests**: `test_descent.gd` (tables, determinism, offers/stacking, refill/pot/bank maths, daily cap with clock
  back/forward/far future, slime cap, dev toggles, milestones once + ABYSS, saves/codes/clamps/reset, every boon in a
  real floor, drops + glimmers + MAGNET, SECOND WIND once per run, the card flow incl. CASH OUT / dry-up / quit, R
  ignored, the portal choice), `test_descent_runs.gd` (autopilot: 20 short runs all reach floor 4, 3 deep runs to
  floors 11 / 14 / 11; every floor entered with enough meter is cleared; carried meter = the maths). Nav fuzz: the
  portal choice and the card are modals; a scripted Descent Esc/focus ladder; a 10th area walk "descent" (2,000
  inputs; seeds 1234 / 77 / 4242 / 9001: zero violations). `test_attempt_restarts` goes through RANDOM MAZE now.
- **Shots** (`tests/demo_descent.tscn`): `docs/polish-shots/descent_portal.png`, `descent_floor.png` (floor 3, Lemon),
  `descent_boons.png`, `descent_cashout.png`, `descent_summary.png`; clip `descent_demo.mp4` (git-ignored, 48 s).
- Open (owner): playtest depth/tickets per day (knobs `DESCENT_REFILL`, `DESCENT_POT_PER_FLOOR`); real boon art if wanted.


## Upgrades v2, batch 4: hard-mode HEAT (2026-10-15, save version 6)
Spec: [design/upgrades-v2.md](../design/upgrades-v2.md) C3, D.1-D.3. Rules, numbers and the winnability sweep:
[level-design.md](../level-design.md) section 10; every number in `scripts/economy.gd` (`HEAT_MODS`, `HEAT_MAX`,
`HEAT_TIERS`, `HEAT_BOUNTY`, `HEAT_EMBER`); rules, icons and flames in `scripts/heat.gd` (`Heat`).
- **Modifiers** (global bitmask `Progress.heat_mods`, saved `[settings] heat_mods`): DIM 1 (keep-lit radius 20 -> 10 px,
  fade steps x0.6, lantern glow x0.6), BRITTLE 1 (splat penalty x2 and the knockback slide drains), FOG BITES 2 (fog
  returns after half the last fade step: 9 -> 4.5 s; with DIM 5.4 -> 2.7 s), GROUNDED 2 (no leaps; the touch JUMP is
  struck out), THIRSTY 2 (drain x1.08: gliding, leaps, splats), RACE 3 (countdown 1.3 x par in the timer pod with an
  hourglass, red under 10 s; at 0 the slime dries up: OUT OF TIME!). BRITTLE + GROUNDED never go together (GROUNDED
  drops BRITTLE; BRITTLE is greyed out while GROUNDED is on), so 48 of 64 masks, max heat 10. Par, routes and the meter
  size never change.
- **Where they apply**: hard STORY levels already cleared plainly on hard (`Progress.heat_for_run`); never normal mode,
  the randomizer (hard or not) or Descent. `game.gd` `_apply_heat` (after par, upgrades and workshop; hard mode has
  neither). The fog shader got a `refog_after` uniform (default 9 = the old `fade_after.w`, so plain hard runs are
  pixel-identical); the lazy-relight ticks follow the run's first fade step.
- **Level select**: in hard mode a HEAT n button bottom right (mirrors BACK) opens `HeatPanel`
  (`scripts/ui/heat_panel.gd`): HEAT n/10 with a flame, 6 toggles (2x code-drawn icon: moon, cracked block, fog with
  teeth, struck-out leap arrow, half-empty drop, hourglass; name; flame + `+N`; a check when on), a line about the
  focused one, DONE. Focus-locked; Esc / DONE / a click outside close it (Esc closes only the panel; focus returns to
  HEAT); each toggle saves at once. The info lines read HEAT UP LEVELS BEATEN ON HARD / HEAT 2 4 7 10 PAYS 3 5 7 10
  TICKETS ONCE in hard mode. Hard tiles show a 7x9 flame at the top left (mirrors the medal pips) in the best heat
  tier's colors (2 red, 4 orange, 7 yellow, 10 white-hot with a blue core); `test_level_tiles` checks it stays clear of
  the number, pips and time and that the number/lock centering is unchanged.
- **HUD / result**: a pod under the level name (flame, HEAT n, the active modifiers' icons); RACE's hourglass countdown;
  the win panel adds a row: flame, HEAT n, then BOUNTY +N (ticket icon), NEW BEST HEAT! or BEST HEAT n (the panel moves
  up 13 px so it clears the NEW RECORD! banner). The hub pod adds a flame and n/100 (sum of best heats) once any
  heat clear exists; heat 10 on every level puts a crown of 5 white-hot flames over the title logo.
- **Rewards**: `Progress.complete_heat(level, heat)` on an unassisted win without dev toggles pays every newly crossed
  tier once (3/5/7/10 = 25 a level, 250 in all; a clear can cross several), raises `heat_best[level]`. Decisions: the
  claimed bounties are DERIVED from the best heat (tiers <= best are paid; no separate claimed bitmask can disagree);
  `[heat] paid` keeps the tickets paid for stats, clamped on load to what the bests could have paid. Heat records are
  NOT separate: a heat run records hard best times and hard medals exactly like a plain hard run (no modifier makes a
  run faster); only the best heat per level is new. Dev mode pays (unsaved) like the randomizer; dev-toggled runs
  (F1/F2) earn no bounty and no best heat; there is no ASSIST in hard mode; the workshop stays off.
- **EMBER trail** (earned, never sold): every hard level at heat 7+ (`Economy.HEAT_EMBER`); hot orange goo with sparks
  (the shader's specks) and a strong halo; NEW TRAIL: EMBER TRAIL on the clear that earns it; refused on load without
  the condition (`cosmetic_earned("ember")`).
- **Save** (all optional, defaulted, version 6 / epoch 1 unchanged): `[settings] heat_mods` (sanitized: junk bits and
  BRITTLE+GROUNDED dropped), `[heat] level_N` (0-10, kept only for levels in `hard_cleared`), `[heat] paid`. Nothing
  written until used. A full HEAT state adds ~90 chars to a save code (a `--story` save with every map: 2711 -> 2799). RESET PROGRESS clears it all (incl.
  the picked modifiers).
- **Winnability**: by the numbers for all 48 masks x 10 levels in `test_heat`, the autopilot at heat 10 on all 10 levels
  and heat 9 (BRITTLE instead of GROUNDED) on L1-3 in `test_heat`, and the full sweep `tests/bench_heat.gd` (480 runs,
  0 lost). Tightest: THIRSTY on L1 (the walk uses 92.6%, 7.4% left); RACE: the slowest walk takes 58% of the countdown.
- **Flags**: `--heat=dim,fog,race` (or a mask number), `--heat-best=10,7,4`. Autoplay bot: unchanged (hard mode at heat
  0; `--autoplay-heat` not built: heat needs a prior hard clear, so the bot would have to replay every level).
- **Tests**: `test_heat.gd` (tables, masks, bounty maths, Progress rules, saves/codes/hostile values/reset, level select
  keyboard/mouse/Esc/focus lock, hub pod + title crown, every modifier in a real level, win flow paying once, dev toggles,
  winnability); `test_level_tiles` (flames + HEAT button/panel layout); `test_trails` (EMBER); nav fuzz: the HEAT panel
  is a modal and an 11th area walk "heat" (panel, HARD MODE flips, heat runs with wins / dry-ups / RACE time-outs).
- **Shots**: `docs/polish-shots/heat_level_select.png`, `heat_panel.png`, `heat_dim.png` (L3), `heat_fog.png` (L5),
  `heat_race.png` (L7, RACE + THIRSTY), `heat_result.png` (BOUNTY +8), `heat_ember.png`; demo `tests/demo_heat.tscn`,
  `tests/demo_level_select.tscn -- hard heat[-panel]`.
- Open (owner): playtest which heats people use (knobs: `HEAT_BOUNTY`, the modifier values); real flame/icon art if
  wanted.

