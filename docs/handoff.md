# Handoff: where Slime Time stands (2026-10-12)

Written on the Windows PC before moving to the MacBook Pro. Read this with [CLAUDE.md](../CLAUDE.md),
which describes the whole project and the commands for both machines.

## Where we left off

- **Branch `v2`** has all the current work (`main` is older). Latest commits are on GitHub:
  https://github.com/AveryBlue-GD/slime-time (private), with tags `v1.0`, `v2.0`-`v2.2`, `v2-before-themes`, `pre-hub`.
- **All 21 test suites pass** on Windows, also through the new `tools/test_all.sh`.
- **Moving to the Mac:** `tools/*.sh` twins of the PowerShell tools were added and tested (pointed at the Windows
  Godot); CLAUDE.md has a "Commands on macOS / Linux" section. The user has a setup prompt to paste into Claude Code
  on the Mac (install Godot 4.7.2 + export templates, clone, `git checkout v2`, import, run tests, copy the save,
  screenshot, launch). Their save is also on OneDrive: `Desktop/SlimeTime-for-Mac/save.cfg` (plus
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
- **Ticket pickup** (`scripts/ticket_spawn.gd` `TicketSpawn`, `scripts/ticket_pickup.gd`): one per randomizer maze, seeded cell. Fraction f = route tiles from the start x slime cost per tile (already includes MORE SLIME) / 100. Eligible 10% <= f <= 60% and start->ticket->chalice <= 92% of the meter; weight = 0.04 + (f/0.6)^2 per cell. Over 300 seeds: <20% 6%, 20-30% 12%, 30-40% 17%, 40-50% 28%, 50-60% 38%. Hidden until within 26 px (like the chalice), glints through the fog within 80 px, HUD pod FIND IT / FOUND.
- **Payout** (`Progress.random_tickets_due`): win 1, +2 pickup, +1 under par (fresh seed), max 4; no MORE SLIME bought -> capped at 1 in all. Daily cap (5 paying wins), seed-repeat rules, assisted = 0 unchanged. Result text: TICKET FOUND! +N / NO TICKET FOUND +N, MORE SLIME = MORE (when capped).
- **Size** (`Levels.random_cells`): base 18-24 x 10-13 times sqrt(1 + 0.1 x slime level), max 30x16 (25x14 average at level 10); hard mode no growth.
- **Wheel price** (`Progress.spin_cost_after`): first spin free, then 12, 14, 16 ... capped at 40; shown in the wheel hint and the hub prompt. Saved only through the existing `[hats] spins`.
- Tests: `tests/test_random_tickets.gd` (new), updated `test_tickets`, `test_rainbow`. Shots: `docs/polish-shots/random_*.png`.

## Jelly swap, skin atmosphere, story
- **JELLY toggle** (`skins_screen.gd _toggle_jelly`): switching also wears the worn skin's other version when it is unlocked (`Progress.select_skin(id, view_jelly)`); otherwise the worn skin stays and the status line says `SOLID LOCKED - HARD CLEAR L#` (or the existing jelly lock text). Test `test_jelly_swap`.
- **Skin atmosphere** (`Skins.atmosphere_color/tinted`, `Themes.fog_colors(theme, tint)`, `Ambient.create(theme, reduce, tint)`, `Game.atmosphere_tint`): fog colors lean 32% and motes 40% toward the worn skin's hue at the theme color's own brightness (so fog stays as dark as before; Dark/Normal/Bright untouched); rainbow and stopwatch use neutral warm gold. Trail, light halo and splat bursts were already skin-colored. Shots `docs/polish-shots/skinfx_*.png`; test `test_atmosphere`.
- **Story** (see `docs/story.md`): `scripts/story.gd` (all text), `scenes/story.tscn` + `scripts/ui/story_screen.gd` (intro/finale cards), `Progress.story_seen` (bits, optional key, reset by RESET PROGRESS; tests and `--unlock-all` start with both seen). Intro: title PLAY on a fresh save, replay via the title's STORY button. Finale: `Game.play_next` after level 10 (once). Level banners: `Hud.show_area_name(name, line)`. Demo `tests/demo_story.tscn`; test `test_story`; shots `docs/polish-shots/story_*.png`.
