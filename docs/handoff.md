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
