# QA review: spring cleaning phase 5 (platform readiness)

Reviewer: code-reviewer (QA gate), 2026-10-16. Scope: `1c80a9b`..`031a23e` on `spring-cleaning` (seam, Android back,
lifecycle pause, pad layer, safe areas, Descent resume D6, Linux preset, make_promo.sh, Steam seam, cues, report), read
against [phase5-platform.md](phase5-platform.md), [phase5-platform-audit.md](phase5-platform-audit.md) and
[decisions.md](decisions.md) D4 / D6. Game code was read only. Every test ran in a scratch worktree of `031a23e` with a
fake HOME (removed afterwards); no real save was touched and no Godot process was killed.

## Verdict

**Pass, with one owner decision to take (finding 1).** Nothing is a crash, a lost save, a double bank or a softlock. The
Descent resume does what D6 asks: no reroll, the paid slot is taken once, the run banks once, codes never carry it, and
hostile data is dropped or clamped. The force-quit trade-off the report names is reachable without a force-quit on
desktop and web, and it removes dry-up risk from Descent. Its payout stays under the daily cap (quantified below).

## Gates (run independently in the worktree)

- `./tools/test_all.sh`: **76 suites, 0 failed** (115 s, 6 jobs), including the four nav-fuzz shards with the pad,
  stick, Android-back and background ops, `test_gamepad`, `test_platform` and `test_descent_resume`.
- Linux export with the 4.7.2 templates: `SlimeTime.x86_64`, 78.7 MB, an x86-64 ELF. The embedded pck has no
  `res://tests/`, `tools/`, `docs/`, `.claude`, `_archive` (the only `icon.ico` hit is the project setting's name).
- Extra probes of my own (scratch scripts, not committed):
  - Kill-farm: 20 relaunches before a dry-up on floor 12. The pot (30), the floor and the tickets were unchanged each
    time. A third run on the same day, killed and then quit with QUIT RUN, still pays 0 (cap `practice`).
  - Hostile `[descent_run]`: a string floor, cleared > floor, an array of boons, non-string or non-int boon entries,
    seed 0 and format 2 are all dropped. Pot 99999 is clamped to 30, meter -50 to 0, bladders without the boon to 0,
    slot 9 to 2, and junk bonuses are filtered. No script errors.
  - Hub resume prompt: shown on arrival. Android back closes it and the run stays saved. A second back goes to the
    title.
  - Background: the hub never pauses. A level pauses once, and a second enter / leave never toggles it twice.
  - Lambdas on `PlatformEvents.input_kind_changed` from key_controls and the hub are disconnected when those scenes
    are freed (0 connections left, no errors on emit).
  - Pad-only save-code panel: the focus graph reaches COPY, both boxes, PASTE, LOAD and CLOSE with the D-pad. B
    closes the panel, then SETTINGS. HEAT panel: B closes the panel first, then the level select.
  - iOS hub (`Platform.override = "ios"`): tapping the touch pause button in the hub goes to the title (see finding 3).

## Findings (most severe first)

1. **scripts/progress.gd:1703 (`resume_descent`), with docs/spring-cleaning/phase5-platform.md:99: the floor can be
   retried as often as the player likes, without a force-quit.**
   - **Problem.** A mid-floor snapshot can be resumed any number of times.
   - **How it happens.** On desktop, closing the window (X, Cmd+Q or Alt+F4) is a free retry: nothing handles
     `WM_CLOSE_REQUEST`, so it counts as an app kill. On the web, reloading or closing the tab does the same. So
     "force-quit just before drying up" takes one click on two of the three shipping platforms. The player then
     replays the same maze with the same starting meter until they clear it, and never pays the dry-up (half the pot,
     run over).
   - **How much it can pay.** The pot never grows without a clear, so tickets can't be farmed beyond the existing
     ceiling. That ceiling is 2 paid runs a day x `DESCENT_POT_MAX` 30 = 60 tickets a day, or 1 per run without MORE
     SLIME. What the exploit changes is that every paid run reaches that ceiling: the pot hits 30 on floor 12, so a
     run banks 30 every time instead of risking 15 or less on a dry-up. The one-off milestones (10 + 15 + 20 + 25 =
     70 tickets) and the ABYSS trail become certain.
   - **Severity.** Medium for the economy and the challenge. It is not a dupe.
   - **Recommended fix** (smallest; keeps D6's protection against one OS kill): add a `resumes` key to
     `DESCENT_RESUME_KEYS` (optional on read, default 0, still format 1). RESUME of a mid-floor snapshot
     (`cleared < floor`) sets it to 1 and saves. When a pending mid-floor snapshot has `resumes >= 1`, the hub prompt
     shows only QUIT RUN ("QUIT RUN BANKS HALF", the dry-up's result). That allows one retry per floor at most. A
     boon-card snapshot needs no limit.
   - **Optional for the owner.** On desktop, a mid-floor `NOTIFICATION_WM_CLOSE_REQUEST` could bank as QUIT TO HUB,
     because a window close there is deliberate. D6 currently lists "or a closed window" as a resume case, so this is
     the owner's call.
2. **scripts/game.gd:2230 (`pause_for_background`) with :511 / :534 (`_ease_in`): going to the background during a
   scene change into a level leaves the level running.**
   - **Problem.** `pause_for_background` returns early while `_leaving()` is true. Nothing pauses the level once the
     wipe ends.
   - **Failure scenario.** In my probe, a background during the hub-to-level wipe left the level unpaused: run clock
     at 1.80 s after 120 background frames. Desktop and web keep running while unfocused, so alt-tabbing during the
     wipe (also DESCEND's and RETRY's reloads) runs the clock and a RACE countdown with nobody playing. On a phone,
     the level runs as soon as the app comes back.
   - **Status.** The report lists this as remaining. It is a real, reproducible gap with a 2-line fix.
   - **Fix.** At the end of `_ease_in` (or deferred from `_ready`):
     `if PlatformEvents.in_background: pause_for_background()`.
   - **Note.** game.gd is being edited right now for the phase 4 interpolation fix; make this change after that
     lands.
3. **docs/spring-cleaning/phase5-platform.md:228 (and the brief's item 9): the note "iOS title screen reachable only at
   launch" is wrong.**
   - **What actually happens.** On a touchscreen the hub draws the touch pause button: `TouchControls` is visible and
     `menu_open` is false. A tap sends `menu` (scripts/ui/touch_controls.gd:129-135), and the hub turns `menu` into
     a change to the title (scripts/hub.gd:862-865). I checked this with `Platform.override = "ios"`: the tap reached
     `title.tscn`. iOS and Android can already get back to the title and its STORY replay.
   - **Smallest fix.** Correct the note. If the owner finds two pause bars a poor sign for "back to title", the
     smallest UI change is a touch-controls flag `hub_mode` (set by hub.gd) that draws a door / home glyph in the same
     rect instead of the bars. That is about 5 lines in `_draw_controls`, with no new button or layout. No new hub or
     settings route is needed.
4. **scripts/progress.gd:472 (`toggle_fullscreen`) / :297: the saved fullscreen choice gets out of step when the player
   leaves fullscreen with the OS controls.**
   - **Problem.** `fullscreen` is written only by F11 and the SETTINGS button.
   - **Failure scenario.** On macOS, a player who leaves fullscreen with the window's green button or View > Exit Full
     Screen still has `[settings] fullscreen=true` saved, so every launch opens fullscreen again. Windows has no such
     OS path for this window mode.
   - **Severity.** Low.
   - **Fix.** On desktop, sync it from the window when the mode changes: handle `NOTIFICATION_WM_SIZE_CHANGED` in
     Progress, or read `is_fullscreen()` once at `NOTIFICATION_WM_CLOSE_REQUEST`, and save if it differs.
   - **Not checked.** I did not open a real window to confirm that `is_fullscreen()` reads FULLSCREEN right after
     `window_set_mode` on macOS, where the native fullscreen transition is animated. The headless tests can't see
     this. A 10-second manual check on the Mac: F11, quit, relaunch.
5. **scripts/progress.gd:881 (`read_descent_run`): the boon exclusion check is hard-coded to rubber / glass.**
   - **Problem.** The check is `boons.has("rubber") and boons.has("glass")` instead of using the table's `excludes`.
   - **Failure scenario.** A future boon pair that excludes each other in `Economy.BOONS` would pass validation from a
     hand-made save. Today it is exact. This is a latent bug only.
   - **Fix.** For each held id, reject when `Descent.held(boons, String(Descent.boon(id).get("excludes", ""))) > 0`.

## Checked and fine

- **Descent resume (D6).**
  - Snapshots are taken at every floor start (including floor 1, a NEW RUN and DESCEND before the reload) and at the
    clear (the boon card). Nothing is saved mid-floor.
  - CASH OUT, a dry-up (`_dry_up` banks before the wipe), QUIT TO HUB and QUIT RUN each clear the snapshot in the
    same save. A kill at any of those moments can't bank twice or reroll.
  - Offers come from the seed, the floor and the boons held, so a boon-card resume shows the same three.
  - Goo drops are seeded. SECOND WIND, the bladders and the meter go back to their floor-start values, as the owner
    rule says.
  - The slot is taken and saved with the clear. Milestones are paid once, inside the snapshot's save.
  - `start_descent` banks a pending run first. RESET clears it. Codes are neither written with it nor read with it.
    Older saves have no section and load as before.
  - A parked practice run banks into the next day's slot when it ends. That uses a slot, so it does not raise the
    daily cap.
- **Gamepad (D4).**
  - The layer is re-added after every `apply_bindings` (key change, RESET KEYS, load, code load), and keys are kept.
  - LB / RB act as tabs only in menus, and the hat wheel guards them during its confirm.
  - A pad press cancels a rebind wait instead of trapping it.
  - The left stick snaps to 8 directions with a 0.35 dead zone, and the prompt switch ignores drift below 0.5.
  - Descent cards, the pause menu, the dry-up and win results, the hat wheel, the save-code panel, HEAT and SETTINGS
    are all navigable and escapable with a pad.
- **Android back.** It never quits (`quit_on_go_back=false`). It sends exactly one `menu` tap. Menus back out, a level
  pauses and resumes, the hub goes to the title and the title ignores it.
- **Lifecycle.** Only a running level pauses. Story, title, trailer and menus are never paused. Nothing pauses headless,
  in movie captures (screenshot.sh, promo shots) or under `--autoplay`. The promo cover's game sits in a SubViewport, so
  it is not `current_scene` and can't be paused. A web `visibilitychange` together with FOCUS_OUT pauses only once.
  Inputs are released both ways, and a failed save is retried.
- **Seam.**
  - The web still has no QUIT (`can_quit` is desktop only, and `--web-ui` counts as web).
  - Fullscreen is remembered only on desktop and applied only on a real player launch.
  - The safe area applies only on native mobile or with a test override; desktop and web keep the full view and
    margin 3.
  - Every JavaScriptBridge call is guarded by `has_js()`.
- **Hat wheel (H4).** JUMP no longer spins. The touch controls stand down under the overlay, and BACK shows on touch.
- **Linux preset.** It uses the same filters as Web plus `icon.ico`. It exports cleanly; see the gates above.

## Housekeeping

The worktree `/private/tmp/claude-501/qa5_wt`, its fake HOME and the scratch Linux export were removed after the run.
