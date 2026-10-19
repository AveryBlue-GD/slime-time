# Tutorial design: the training maze and the first hub visit

Status: **chunks A and B built (2026-10-18): gate, flags, save bits, the intro hand-off, the SPLASHDOWN maze (section 14); C-H in progress.** **Gate ON: shipped 2026-10-18 after the owner's playtest.** Owner request, 2026-10-18: a tutorial that plays
directly after the intro, a training maze showing jumping, coins and the chalice, and how drying up works, then
talking the player into the hub to show rotating and what each station does. Research and sources:
[research.md](research.md). The maze's name is a placeholder (**TRAINING** in code and text) until the owner
picks one (section 12).

## 1. Today's first launch (what the tutorial hooks into)

- `title.gd` `_ready`: `Story.launch_due` (fresh save, intro not seen, the booted title) hands off to
  `story.tscn` with `Story.next_scene = TITLE_SCENE`. The intro is five wordless shots (about 24 s) ending on the
  **splat**: the slime alone at the bottom of the dungeon, with a depth gauge pointing up. Esc skips the rest,
  any key moves on a shot, and `finish()` marks `STORY_INTRO` seen (D1: all of this stays as it is).
- The title then shows **PLAY** while `Progress.is_fresh_save()` (no level, randomizer or hard clear), and PLAY
  goes straight into level 1. The hub opens only after the first chalice.
- Levels 1-2 draw `TutorialCues` (a child of the slime): a WASD / d-pad glyph until the first move, then a SPACE /
  JUMP / A keycap after 48 px of wandering and 1 s idle, if the player hasn't leapt yet. Each fades on first use and
  is saved as bits in `Progress.tutorial_seen` (`TUTORIAL_MOVE` 1, `TUTORIAL_LEAP` 2). The chalice beacon is gone
  (D13). A save without the key that has any progress counts as having seen both.
- The hub: nine stations clockwise from the back (story archway, MAP TABLE, UPGRADES cauldron, QUIT trapdoor on
  desktop only, COIN BAG, RANDOMIZER locked, SETTINGS, HAT WHEEL, COSMETICS). The **wheel in the middle** turns the
  room one station (`turn_room`, interact key F / X next to it, or leap into it; hold LEFT to turn the other way;
  JUMP on touch). The prompt at the bottom names the station you're next to. Esc opens the hub MENU (BACK / SETTINGS / QUIT TO TITLE).

## 2. The new flow

```
first launch, fresh save, gate on
  intro (unchanged, skippable)  --goo wipe-->  TRAINING maze  --chalice-->  hub + tour  --archway-->  level select (L1)  --> L1
                                                  | Esc: pause, SKIP TRAINING          | Esc / B / SKIP: tour off
                                                  v                                    v
                                                hub + tour                           free hub
```

- **Hook:** when the tutorial is due, `title.gd` sets `Story.next_scene` to the training maze instead of the
  title. Esc on the intro still marks the intro seen and leads into the maze. The intro's last shot (the slime alone
  in the dark) cuts straight to the same slime in the dark maze, so the story carries on.
- **Due rule:** `Economy.tutorial_on()` and `Progress.is_fresh_save()` and `tutorial_seen == 0` (no bit at all).
  Every existing save has progress, or has moved in level 1 (bit 1), or gets bits 1|2 by default when loaded, so it
  never sees the tutorial. A save code loaded later is read the same way. RESET PROGRESS clears `tutorial_seen`,
  so a reset game gets the intro and the tutorial again, which matches what happens to the intro today.
- **After it:** finishing (or skipping) the maze sets `TUTORIAL_TRAINING`, together with `TUTORIAL_MOVE |
  TUTORIAL_LEAP` once the player has really moved and leapt, so the level 1-2 cues don't teach it a second time.
  A player who skips before moving or leaping keeps those cues as a safety net. While the gate is on,
  `is_fresh_save()` also needs the training bit unset. After training the title says ENTER THE HUB and the
  hub is open before level 1, because the tour ends at the archway.
- **Returning player:** never sees any of this. No prompt, no menu entry forced on them, no save change.
- **Replay:** a **TRAINING** button in SETTINGS (the MORE column, under SAVE CODE; ui-polisher fits it), which
  plays the maze and then the tour, saves nothing new and returns to the hub. The title's STORY button stays
  the intro only (D1). Alternative for the owner: a small TRAINING tile on the level select (Q6).

## 3. The training maze: beats in order

The maze is hand-made, not generated: 12x6 cells = **25x13 tiles** (400x208 px, a little over one 320x180
screen, so the camera barely scrolls). It uses the Dark Dungeon tiles and fog (no new art; in the story it is the
sump under level 1). Corridors are 1 tile wide on the usual cell grid (`MazeGenerator` format: cell (cx, cy) =
tile (2cx+1, 2cy+1)), so all the game code (fog, trail, coins, chalice, HUD) runs unchanged.

```
    tile x: 0         1         2
            0123456789012345678901234
  y  0      #########################
     1      #################C###G..#      C = coin (dead end, 2 cells deep)
     2      #################.#####.#      G = golden chalice (exit)
     3      #################.#####.#
     4      #################.#####.#      B4: the dry-up usually lands around here
     5      #####..-----------#####.#      - = the long straight (12 tiles): leap lesson
     6      #####.###########.#####.#          (a full 8-tile leap from its west end stops
     7      #####.###########.#####.#           4 tiles short of the wall: no splat)
     8      #####.###########.#####.#
     9      #S....###########.#####.#      S = start (a dead-end pocket: one way to go)
    10      #################.#####.#
    11      #################.......#
    12      #########################
```

Route lengths (tiles, centre to centre): start to the straight 8, the straight 12, fork to coin 4 (8 there and
back), fork to chalice 24. **Direct route 44, with the coin 52.**

| # | Beat | Space (tiles) | What teaches it | Cue |
|---|---|---|---|---|
| B1 | **Glide, trail reveals the dark.** Two short legs and a corner from a pocket with one way out. | S to (5,5), 8 | The fog opens only where the goo goes; a dead-end pocket means any first press works. | Existing move glyph (WASD / d-pad), fades on first move. |
| B2 | **Leap.** A 12-tile straight. Hold to charge (the slime stops, the movement keys aim, landing dots show), release. A leap costs half as much slime per tile but leaves no goo in the air. | (5,5) to (17,5), 12 | Length: a full leap stops short of the far wall, so the first leap never splats. A second full leap splats into the wall: the free lesson in overshooting. | Leap keycap shown **on entering the straight** (moment of need), not after 48 px of wandering. Under it a 2 px fill bar fills while the key is held (teaches *hold*). |
| B3 | **Coin at a dead end.** At the fork the north arm ends 2 cells up in a coin. | fork to C, 4 | A forced glimmer (`_spawn_glimmer`) over the coin when the slime reaches the fork: the real rule (coins sit at dead ends, glimmers tell) shown once. Picked up with the normal coin catch (D16). | None (the glimmer is the cue). |
| B4 | **The meter, and drying up.** Attempt 1 starts with the meter **low** (see below). The low-slime heartbeat starts at 20%; the meter pod pulses once at the first drain. The player runs dry around the fork / coin arm. | anywhere after ~26 tiles | The meter visibly empties as they move; standing still costs nothing (they learn that too). | HUD: one pulse of the meter pod at the first drain (no arrow, no text). |
| B5 | **The dry-up row.** DRIED UP, then a row with **RESTART** only (focused; SPACE / Enter / A / tap). | - | RESTART is one press. The coin stays found (as in the real game: saved at touch), the fog resets, the meter starts **full** and fills up visibly as the run starts. | The accept glyph pulses beside RESTART. |
| B6 | **Chalice exit.** Attempt 2, full meter: the 24-tile leg round the south and up the east side to the chalice. | fork to G, 24 | The chalice shows up in the dark within 24 px as usual; touching it wins. | None. |
| B7 | **Into the hub.** Win panel: a short line (below), one button **HUB** (focused). | - | The goo wipe goes into the hub; the tour starts. | - |

**Meter numbers (proposal, `scripts/training.gd`):** full meter **90 tiles** (the direct route uses 49%, close to
level 1's 45% target, so attempt 2 is generous even with wandering). Attempt 1 starts at **26 tiles (29%)**. In the
story the slime has just splatted from the top of a mountain, and its goo is stuck all over the walls (the intro's
splat leaves droplets that stick), so starting low fits.
- Gliding to the coin costs 24 tiles, so a beginner who glides gets the coin and dries up about 2 tiles out of the
  coin arm. The coin is collected on that attempt, and it reads as "I went for the coin".
- Reaching the chalice on attempt 1 needs at least 44 tiles of gliding, or about 22-25 with a perfect chain of
  leaps sized exactly to every straight. Only an expert manages that. That player wins on attempt 1, skips B5, and
  the real dry-up row teaches itself the first time it happens in level 1 (as now). This is accepted on purpose:
  we never cheat the rules to force a loss (research: Mega Man X / Vile).
- A wanderer may dry up before the coin. That's fine: the coin is still there on attempt 2.
- Option for the owner (Q3): start full (no staged dry-up). The dry-up then shows up only if it happens on its own.

**Exclusions in the maze** (like Descent's `level < 1` rules): no survey / MAP TABLE entry, no records, medals,
par or timer pod, no `dry_ups` count or ASSIST, no first-run skin (the default opaque Lime), no hard mode / HEAT /
abilities, no tickets. The level pod shows the maze's name, and the area banner shows its name and a one-line
joke (e.g. "THE BOTTOM. DAMP. YOU WILL LIVE."). The HUD's coin pod shows the coin while the run lasts. Whether
it's **banked** is Q2: the recommendation is a practice coin that isn't saved, so the 165-coin total, the coin tree
(`Upgrades.full_tree_cost`), rainbow and the economy stay untouched.

**Pause in the maze:** Esc / START opens the normal pause menu with **SKIP TRAINING** where QUIT TO HUB would be
(RESUME stays first and focused). SKIP sets the training bit and goes to the hub with the tour. R opens the restart
prompt as in any level (RESTART / CANCEL; no UPGRADES, since the hub isn't introduced yet).

## 4. Prompt style

- **Maze: wordless glyphs**, in the existing `TutorialCues` style (white 1 px keycap, dark fill, a 1 px stepped
  bob, fading on use). This keeps to the wordless intro and to what levels 1-2 already show. No pointing arrows
  and no chalice beacon (D13).
- **Hub: one short line per station** (owner: "talk the player into"), uppercase in the 8 px font, at most
  ~240 px, in a goo panel at the top of the screen (the bottom is the station prompt). The voice is the **hub
  itself** (the room is a giant slime with eyes on its back wall), dry and funny like the level banners.
  Text-free variant: Q4.
- **Per input device**, always through the existing seams, re-checked every frame so a mid-tour device switch
  follows:
  | | Keyboard | Gamepad | Touch |
  |---|---|---|---|
  | move | the bound keys (`_key_text`, follows remaps): W A S D or arrows | d-pad glyph | d-pad glyph over the joystick half |
  | leap | bound key (SPACE) + hold bar | `Platform.prompt_for("jump")` = A + hold bar | JUMP keycap (`Loc.t("tutorial.jump")`) + hold bar |
  | restart row | accept key (SPACE / ENTER) | A | the button itself pulses |
  | hub: use / turn | bound interact key (F) | X | JUMP (right next to the wheel / station) |
  | skip | Esc | B | a small SKIP button (top right, safe area) |
  Pad glyph art is later work (handoff item 7). Until then letters in keycaps, as `prompt_for` already gives.
- Fix inside the gate: the SPACE keycap reads "SPAC" (handoff 8e). The tutorial widens the keycap only while
  the gate is on, so English stays pixel-identical with the gate off.

## 5. The hub walkthrough (tour)

The slime arrives standing **next to the wheel** (in USE_GAP), with the archway at the back. Every step is one
press of the use key at the wheel: the room turns one station clockwise, the station now at the back gets its
"lit" highlight (pool x1.4, already in `_process`), and its line replaces the last. The player drives the pace
(about 0.55 s per turn plus reading time). A full turn of the room ends back at the archway.

| Step | At the back | Line (draft, English) |
|---|---|---|
| 0 | archway (start) | THIS IS HOME. IT TURNS. HIT THE WHEEL. *(+ use-key glyph by the wheel)* |
| 1 | MAP TABLE | MAPS OF EVERY FLOOR YOU HAVE SMEARED. |
| 2 | UPGRADES | COINS GO IN. STRONGER GOO COMES OUT. |
| 3 | QUIT (desktop only) | THE TRAPDOOR. FOR BEDTIME. |
| 4 | COIN BAG | COINS STILL HIDING ON EACH FLOOR. *(practice-coin variant: THE PRACTICE COIN WAS FAKE. SORRY.)* |
| 5 | RANDOMIZER (locked) | LOCKED. CLIMB ALL 10 FLOORS FIRST. |
| 6 | SETTINGS | SOUND, KEYS, FOG. THE BORING SIGN. |
| 7 | HAT WHEEL | SPIN FOR HATS. THE FIRST SPIN IS FREE. |
| 8 | COSMETICS | SKINS, HATS, TRAILS. DRY UP IN STYLE. |
| 9 | archway again | THE WAY UP. WALK IN. *(use-key glyph over the archway; the line stays until it is used)* |

- On step 2 a second line: HOLD LEFT TO TURN BACK (once).
- The lines describe and never recommend (D12: no "buy MORE SLIME"). The hat wheel line states a fact the
  prompt already shows (FREE).
- The tour is over when the archway comes back round. Using the archway opens the level select with level 1
  focused, and the player plays level 1 as today.
- **Skippable at any time:** Esc / B / the touch SKIP ends the tour (the first Esc in the tour skips the tour
  and doesn't go to the title). Walking off and using any station also ends it quietly. Either way
  `TUTORIAL_HUB` is set and the tour never comes back (except from the TRAINING replay).
- Never blocking: the slime can move, leap and use stations during the tour. Nothing is locked.

## 6. Timings (targets, to be measured)

| Part | Target | Basis |
|---|---|---|
| Intro (unchanged) | 24 s | `Story.length("intro")` |
| Attempt 1 | 30-45 s | 26 tiles at 4.5 tiles/s = 6 s of gliding + reading, charging (1.5 s), exploring |
| Dry-up + RESTART | 3-5 s | `DRY_CHOICE_DELAY` 0.25 s + one press |
| Attempt 2 + win | 25-40 s | 52 tiles = 12 s of gliding + the unknown leg |
| Hub tour | 35-50 s | 9 turns x (0.55 s + ~3 s reading) + walking to the archway |
| **From the intro's end to level 1** | **about 2-2.5 min, never over 4** | |

Measured by: (a) a headless test driving the autopilot through the maze and pressing through the tour, which
asserts an upper bound for the scripted path; (b) a stopwatch playtest by the owner with someone who has never
played. Drop-off points to watch in that playtest: before the first leap, at the dry-up row, and at turn 1 of the
tour.

## 7. Fit with the level 1-2 cues (teach once)

- The training maze sets `TUTORIAL_MOVE` / `TUTORIAL_LEAP` through the same `mark_tutorial_seen` once the player
  has really moved or leapt, so the level 1-2 cues stay off after it. A skip before that leaves them on: they are
  the safety net.
- The training cues reuse the TutorialCues drawing (keycaps, d-pad, `key_size`). The drawing moves to static
  helpers, so both nodes draw identical keycaps and nothing in levels 1-2 changes by a pixel.
- Level 1's banner line ("SPLAT. IT IS DAMP. UP IS THAT WAY.") still works after the maze. The maze's own banner
  must not repeat the splat joke.

## 8. Save and flag plan

- **Gate:** `Economy.TUTORIAL_TEST := false` + `static var tutorial_force := -1` + `Economy.tutorial_on()`, the
  same pattern as `COIN_CATCH_TEST` / `LANGUAGES_TEST`. With it off, nothing in this document runs and nothing new
  is saved. A test asserts the save bytes and the English screens are unchanged.
- **Debug flag:** `--tutorial` (debug builds only, in `Progress` flag parsing): `tutorial_force = 1` plus a
  **clean in-memory fresh state** like `--story` (the real save is never read or written; throwaway path). It plays
  intro, then maze, then tour. `--tutorial=maze` starts in the maze and `--tutorial=hub` in the tour (for quick
  looks and screenshots). `./tools/play.sh --tutorial` works through the existing pass-through of game flags.
- **Saved state when it ships:** two new bits in the existing `[progress] tutorial_seen` integer:
  `TUTORIAL_TRAINING := 4`, `TUTORIAL_HUB := 8`. No new key, no save version bump, no migration: older builds
  ignore the extra bits, and the field is already optional with a default. The bits are written only while the gate
  is on, so with the gate off a save never holds them. A separate `tutorial_done` key isn't needed (the bit
  is the flag). If the owner wants it named, it can be a read-only `Progress.tutorial_done()`.
- **Replay** (SETTINGS TRAINING) runs with `saving_enabled` unchanged but writes nothing: no bits, no coin, no
  survey.
- **Never the real save:** every test uses the suite's throwaway save (`suite_base.gd`), and `--tutorial` never
  reads it.

## 9. Test plan (new suites; each prints `RESULT: PASS`)

- `test_tutorial_flow.gd`: gate off = today's flow exactly (intro, title, PLAY, L1; `tutorial_seen` bytes
  unchanged). Gate on + fresh save: intro then maze, intro skip (Esc) then maze, maze win then hub tour, tour end
  then archway then level select. Returning saves (levels_cleared > 0; bits 1|2 by default; a save code) never
  see it. RESET PROGRESS makes it due again. Title says ENTER THE HUB after training.
- `test_training_maze.gd`: the layout parses (25x13, start, goal, coin cell at a dead end, `is_completable`);
  route lengths 44 / 52; a glide-only autopilot run with the attempt-1 meter **dries up** after the coin; the
  same route with the full meter wins with at least 40% left; the coin stays collected across RESTART; nothing is
  written to records, medals, maps, dry_ups, coins_found, tickets; no first-run skin; the HUD has no timer or
  medal pod. A full leap from the straight's west end does not splat.
- `test_training_cues.gd`: the move glyph shows until the first move and the leap glyph only on entering the
  straight. Keyboard / pad / touch glyph text through `Platform` overrides, with a remapped jump key showing its
  new key. MOVE / LEAP bits set only after a real move / leap. The level 1 cues are off after a full training and
  on after an early skip. With the gate off, the levels 1-2 cue pixels match the golden shots.
- `test_hub_tour.gd`: the slime spawns inside USE_GAP of the wheel. Each use turns one station and shows that
  station's line; 9 steps on desktop, 8 where `Platform.can_quit()` is false (no trapdoor line). Esc / B / SKIP
  ends the tour without going to the title, using any station ends it, and the bit is saved once. No line names an
  upgrade (D12 guard: no line contains MORE SLIME / SPEED / BRIGHTNESS).
- Existing suites to extend: `test_save_isolation` (with `--tutorial`), `test_nav_fuzz` (random input through
  maze and tour: no stuck state), `test_story` (next_scene into the maze), `test_ui_layout` / `test_ui_touch` (tour
  panel, SKIP button size, SETTINGS TRAINING button), `i18n_extract.py --check` (every new line via `Loc.t` with an
  `# i18n:` hint), `./tools/i18n_capture.sh --gate` + docs/i18n/pending.md row.
- One screenshot per beat (B1, B2, B5, B6, tour step 0 and 9) into `docs/tutorial/shots/` for the owner.

## 10. Risks

- **The staged dry-up feels rigged.** Mitigation: it comes from the meter rules alone (no hidden drain), only the
  starting level differs (explained by the splat), recovery costs about 20 s, and the coin is kept. Fallback: Q3
  "start full".
- **An expert wins attempt 1** and never sees the row. Accepted (section 3). Level 1 teaches the row as today.
- **A different start meter from the real game** could teach "levels start low". Mitigation: attempt 2 visibly
  fills the meter to full at the start, and every story level starts full.
- **Opening the hub before level 1** changes the fresh-save flow (title PLAY to ENTER THE HUB, first chalice no
  longer opens the hub). Check every `is_fresh_save()` use (today only `title.gd`) and `go_to_hub` after an L1
  win (it already returns to the archway).
- **Esc in the hub** opens the hub MENU everywhere else (BACK / SETTINGS / QUIT TO TITLE). In the tour the first Esc skips the tour. Must be tested so
  players can't get stuck in a loop and Android back behaves the same.
- **Touch:** JUMP both leaps and uses stations next to them. A player leaping near the wheel turns the room by
  accident (already true today); the tour line must stay correct when that happens.
- **Text growth:** nine new lines plus the banner, all English-only now (owner 2026-10-18), logged in pending.md
  for later locales. Keep them under 240 px so translations have room.
- **Web / phone first-session hitches:** the maze scene is the game scene (preloaded by the title), so no new
  load. The tour adds one node to the hub.
- **Story continuity:** the intro ends on "the way out is up" and the maze sits below level 1. A banner joke
  covers it.

## 11. Implementation chunks (for building in parallel later)

Each chunk owns its files and no other chunk edits them. Chunk A lands first because it fixes the interface the
others use.

| Chunk | Agent | Owns | Delivers |
|---|---|---|---|
| **A. Gate, flags, save bits, hook** | gameplay-dev | `scripts/economy.gd`, `scripts/progress.gd`, `scripts/ui/title.gd`, `scripts/story.gd` (no change to `story_screen.gd` beyond `next_scene`) | `Economy.TUTORIAL_TEST` / `tutorial_force` / `tutorial_on()`; `--tutorial[=maze\|hub]` clean state; `Progress.MODE_TRAINING`, `TUTORIAL_TRAINING` / `TUTORIAL_HUB`, `tutorial_due()`, `hub_tour_due()`, `start_training(replay)`, `finish_training(skipped)`; `is_fresh_save()` gate rule; the title hand-off; `test_tutorial_flow.gd` |
| **B. Training maze** | gameplay-dev | new `scripts/training.gd` (layout, meter numbers, beat cells), `scripts/game.gd` (MODE_TRAINING branch: maze from layout, attempt meter, exclusions, RESTART-only row, HUB-only win row, forced glimmer), `scripts/ui/pause_menu.gd` (SKIP TRAINING), `scripts/ui/restart_prompt.gd` | `test_training_maze.gd` |
| **C. Training cues + HUD pulse** | tutorial-designer (or gameplay-dev) | `scripts/tutorial_cues.gd` (move drawing into static helpers, pixel-identical), new `scripts/training_cues.gd`, `scripts/hud.gd` (meter pod pulse, accept glyph by RESTART) | `test_training_cues.gd`, golden check of the L1-2 cues |
| **D. Hub tour** | gameplay-dev | new `scripts/hub_tour.gd` (steps, lines, skip), `scripts/hub.gd` (hooks only: spawn by the wheel, `room_turned` signal, Esc to tour first, tour node when due) | `test_hub_tour.gd` |
| **E. Replay entry** | gameplay-dev | `scripts/ui/controls.gd` (TRAINING button) | nav-fuzz, settings layout |
| **F. UI pass** | ui-polisher | layout constants in `scripts/ui/ui_kit.gd` if new (tour panel, SKIP), screenshots | `test_ui_layout` / `test_ui_touch`, `docs/tutorial/shots/` |
| **G. Text + i18n bookkeeping** | i18n-engineer | `locale/messages.pot` (extract), `docs/i18n/pending.md` | `i18n_extract.py --check`, `i18n_capture.sh --gate` |
| **H. Verify** | qa-tester, code-reviewer | none (reports only) | full suite, timing run, review |

Order: A, then B + C + D + E in parallel (B and C agree on the cue trigger API: `game.training_beat(name)`), then F
+ G, then H. Gate stays off until the owner has played `./tools/play.sh --tutorial` and signed off.

## 12. Open questions for the owner

1. **Name of the maze** (placeholder TRAINING): e.g. THE SUMP, THE PUDDLE, SPLASHDOWN, THE DRAIN, GOO SCHOOL.
2. **Does the coin count?** (a) practice coin, not saved (recommended: 165 total and economy untouched); (b) a real
   166th coin (needs economy / rainbow / tree changes); (c) a small cosmetic reward for finishing instead.
3. **Forced dry-up?** (a) attempt 1 starts low at 29%, so most players dry up once (recommended); (b) start full and
   teach the dry-up only if it happens.
4. **Hub lines as text, or wordless?** (a) one short line per station in the hub's voice (recommended); (b)
   wordless: only the station highlight and the existing name prompt.
5. **Who talks in the hub?** The room itself (its eyes), a narrator panel with no speaker, or a new character
   (needs art).
6. **Replay entry:** SETTINGS > TRAINING (recommended), a tile on the level select, or none.
7. **Does the tour turn by itself** after the first player-driven turn (shorter), or does the player press each
   turn (recommended: teaches by doing, about 9 presses)?
8. **Show the title once** between the intro and the maze, or go straight in as asked (recommended: straight in;
   the title is seen on the next launch or by Esc from the hub)?
9. **The dry-up row in the maze:** RESTART only (recommended), or the real row with UPGRADES / MAP greyed out?

## 13. Owner answers (2026-10-18)

- Name: **SPLASHDOWN** (the training maze's banner and level name; English only for now).
- Coin: a **practice coin**: collected and celebrated, never saved; the 165 story coins, medals and coin-gated unlocks stay unchanged.
- Dry-up: **start low on purpose**: the first attempt starts with little slime so most players dry up just after the coin, then RESTART with the coin kept and a full meter.
- Hub tour: **short text lines, no voiced audio**: one short line per station as the room turns to it; skippable. No voice-over.
- Still open: replay location (proposed TRAINING button in SETTINGS), whether the hub turns itself after the first turn (default: no, the player turns it).

## 14. API for chunks B-E (chunk A, built 2026-10-18)

Everything below is inert with the gate off (`Economy.tutorial_on()` false): nothing is due and no bit is written,
so saves stay byte-identical (`tests/test_tutorial_flow.gd`). Chunk A owns `scripts/economy.gd`, `scripts/progress.gd`,
`scripts/ui/title.gd`, `scripts/story.gd`; later chunks call these and never edit them (ask chunk A's owner).

- **Gate:** `Economy.TUTORIAL_TEST := false`, `Economy.tutorial_force` (-1 const / 0 off / 1 on; tests set it),
  `Economy.tutorial_on()`.
- **Debug flag** (`Progress.tutorial_flag(args)`, `enable_tutorial_test(which)`): `--tutorial` = clean in-memory
  fresh save, saving off, the real save never read: intro, then training, then tour. `--tutorial=maze`: intro seen,
  the boot title opens the maze. `--tutorial=hub`: training bits set, the boot title opens the hub with the tour due
  (`take_tutorial_launch()`, read once by the boot title). `./tools/play.sh --tutorial[=maze|hub]`.
- **Constants:** `Progress.MODE_TRAINING` ("training", in `Progress.mode`, never saved); bits in `tutorial_seen`:
  `TUTORIAL_TRAINING := 4`, `TUTORIAL_HUB := 8` (next to `TUTORIAL_MOVE` 1, `TUTORIAL_LEAP` 2);
  `Progress.TRAINING_SCENE` = `res://scenes/main.tscn` (the maze is the game scene in MODE_TRAINING),
  `Progress.TOUR_SCENE` = `res://scenes/hub.tscn`.
- **Queries:** `tutorial_due()` (gate, not dev, `is_fresh_save()`, `tutorial_seen == 0`); `hub_tour_due()` (gate,
  not dev, and `tour_replay` or TRAINING set without HUB); `in_training()` (`mode == MODE_TRAINING`);
  `training_replay` (this run is the SETTINGS replay: write nothing); `training_skipped` (the last run ended in
  SKIP TRAINING); `is_fresh_save()` is also false once TRAINING is set while the gate is on (title: ENTER THE HUB).
- **Training run (chunk B):** `prepare_training(replay) -> String` (sets MODE_TRAINING, returns the scene) and
  `start_training(replay)` (the same behind the goo wipe). On the chalice's HUB button:
  `UIKit.go(get_tree(), Progress.finish_training(false))`; on SKIP TRAINING: `finish_training(true)`. It returns the
  hub, puts `mode` back to story, and (gate on, not a replay) saves TRAINING plus the MOVE / LEAP bits the cues
  reported. **Stub:** until game.gd defines `func training_beat(name: String)` (checked by
  `Progress.training_built()`), `prepare_training` calls `finish_training(true)` at once and returns the hub, so
  `--tutorial` plays the intro and lands in the hub. Chunk B: adding `training_beat` switches it to the maze; then
  ask chunk A to drop the stub branch.
- **Cue trigger contract (B emits, C listens):** game.gd (MODE_TRAINING only) defines
  `signal training_cue(name: String)` and `func training_beat(name: String) -> void` that emits it once per name
  per attempt. Names: `"start"` (attempt begins: move glyph), `"straight"` (slime enters the long straight: leap
  keycap + hold bar), `"fork"` (forced glimmer over the coin), `"first_drain"` (meter pod pulse), `"dry"` (dry-up
  row shown: accept glyph by RESTART), `"restart"` (attempt 2 starts), `"chalice"` (win panel). Chunk C's
  `training_cues.gd` connects to `training_cue`, and the HUD pulse reads the same names. C calls
  `Progress.note_training_input(Progress.TUTORIAL_MOVE / TUTORIAL_LEAP)` on a real move / leap, never
  `mark_tutorial_seen` (that would write during a replay).
- **Chunk B as built (2026-10-18):** `scripts/training.gd` (`Training`: `LAYOUT`, `FULL_METER_TILES` 90,
  `FIRST_METER_TILES` **28** (31%, not 26: the glide-only autopilot then takes the coin at ~23.4 tiles and dries up
  back at the fork; 26 left only ~2.6 tiles of slack for hesitation before the coin), `STRAIGHT_FROM` / `FORK` beat tiles, and
  the run state that survives RESTART's scene reload: `Training.attempt`, `Training.coin_taken`). `game.gd` has
  `var training`, `training_attempt`, `training_beat(name)`, `leave_training(skipped) -> String` (the pause menu's
  SKIP TRAINING and the win row's HUB both go through it). It makes `res://scripts/training_cues.gd` (if present) a
  child of the slime and calls its `setup(game, slime, progress)` before the first beat. Beat timing: `"start"`
  on every attempt (deferred one frame after `_ready`, so nodes connected in `_ready` get it), then `"restart"`
  on attempt 2 on; `"straight"`, `"fork"`, `"first_drain"` again on each attempt (once per name per attempt);
  `"dry"` and `"chalice"` when their button row (RESTART / HUB) has just been shown. R mid-run opens
  `RestartPrompt.open(false)` (RESTART / CANCEL). Upgrades and the ticket workshop are off in the maze, so the
  staged dry-up is the same on a SETTINGS replay. The stub branch in `prepare_training` is gone;
  `Progress.training_built()` is gone.
- **Hub tour (chunk D):** the hub adds its tour node when `Progress.hub_tour_due()`; at the end (archway), on a
  skip (Esc / B / SKIP) or when a station is used, it calls `Progress.finish_hub_tour()` (saves HUB unless replay).
- **Replay (chunk E):** SETTINGS' TRAINING button calls `Progress.start_training(true)`; the maze and then the tour
  play, nothing is saved, and the tour ends in the hub.
- **Hand-off:** `Story.launch_next(Progress)` is what the boot title gives the launch intro as `Story.next_scene`:
  the title, or the training scene when due (Esc on the intro goes there too). The title's PLAY on a due save
  (intro seen, quit before the training ended) calls `start_training(false)`. `story_screen.gd` is unchanged.
- **Chunk F as built (UI pass, 2026-10-18):** rules and measurements in [docs/ui-rules.md](../ui-rules.md) "Tutorial UI",
  shots in [shots/](shots/) (x4; `tests/demo_tutorial_ui.tscn` and `tests/demo_training_cues.tscn` make them). Training
  keycaps 11 px (letters off the top edge: the 9 px key's A read as H), the accept glyph centred on RESTART's frame and
  GAP_M off it, the tour line with no key on touch (it ran into the joystick and JUMP), the SKIP pod mirrored in
  right-to-left, SETTINGS' TRAINING in the MORE column under SAVE CODE (bottom-row centre only when LANGUAGE has that
  cell). Review fixes in the same pass: the coin bag line follows the practice coin (`Progress.training_coin`, session
  only), R / pause RESTART mid-run repeats the attempt (only a dry-up's RESTART is attempt 2, `Training.mark_restart(next)`),
  the SKIP pod also takes a left click. The tutorial states are in `test_i18n_screens` / `i18n_capture.sh` now.
