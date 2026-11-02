# Audit B: state and saves (progress.gd and friends)

Scope (every line read): scripts/progress.gd (3,683 lines), save_file.gd, save_text.gd, economy.gd, upgrades.gd, skins.gd, hats.gd, hat.gd, cosmetics.gd, achievements.gd, boards.gd, descent.gd, demo.gd, stopwatch.gd, survey.gd, workshop.gd, look_roller.gd, dev_log.gd. I checked callers across scripts/ and tests/ with grep. Nothing was modified and Godot was not run.

## 1. Map

**Files and what they do**
- `progress.gd` (autoload `Progress`, 264 funcs, 146 vars, read by 49 scripts). It holds all player state and does a lot more: parsing launch/debug flags, choosing the save path, atomic writes and retries, setting aside corrupt saves, save codes, the achievement check, tutorial state, randomizer pay and attempts, daily/weekly mazes, boards and the ghost side file, the demo's FULL GAME PREVIEW snapshot, Descent runs, coins and upgrades plus the tree migrations, the hat wheel, dyes, the ticket store, skins, audio buses, key bindings and trail-map surveys.
- `save_file.gd` (`SaveFile`, static, takes `p` = Progress): turns a ConfigFile into Progress state (`read`, `_read_wallet/_descent/_boards/_maps`, `read_store`) and back (`write`). It also has the type-safe getters `get_int/float/bool/string`, `strings`, `ints`.
- `save_text.gd`: an allow-list scanner for any untrusted text (save.cfg, the ghosts file, pasted codes). It runs before `ConfigFile.parse`, so a save can't trigger object or script instantiation, and it caps parse depth. Limits: 256 KB, 64 KB per line, nesting depth 8. It only allows the constructors `Color` / `Array[int]` / `Array[String]`. It also has a bounded `gunzip` that uses the ISIZE trailer.
- `economy.gd`: every tuning number and feature switch, with `*_force` test hooks. `upgrades.gd`: coin-tree maths, demo prices, and old-tree/tree-2 maths for migration. `workshop.gd`: ticket workshop tables (switched off). `descent.gd`: pure Descent rules (switched off, D11).
- `skins.gd` / `hats.gd` / `cosmetics.gd`: catalogs, unlock predicates and looks. `hat.gd`: the per-frame hat sprite. `stopwatch.gd`: the stopwatch skin's clock. `look_roller.gd`: RANDOM LOOK. `achievements.gd`: goals derived from state, plus REWARDS and MILESTONES. `boards.gd`: daily/weekly board entries (`ms*8+weekday`), weekly seeds and the ghost file codec. `survey.gd`: trail-map bitsets and pack/unpack (format v2 with a layout fingerprint). `demo.gd`: every demo gate and knob, and the export exclude list. `dev_log.gd`: a log file written only in dev mode.

**Save format and versioning**
- The file is `user://save.cfg`. user:// is `SlimeTime_R1`. Sections: meta, progress, skin, hats, settings, records, coins, upgrades, controls, wallet (tickets live under the old `globs` keys), workshop, abilities, cosmetics, medals (`level_N`, hard modes at N+100), maps (base64 Survey v2 plus `coins_N`), descent, achievements, hub, boards, daily, and descent_run (only while a run is saved). Most keys are optional and fall back to defaults. Every value gets clamped or type-checked on read.
- `[meta] version` = `SAVE_VERSION` 7 and `[meta] epoch` = `RELEASE_EPOCH` 1. `[meta] demo` = true for saves the demo wrote.
- Migrations are keyed on `[upgrades] tree`, not on the save version:
  - tree 1 goes through `_migrate_tree` (old 3x10 tree remapped by coins invested).
  - tree < 3 goes through `_migrate_prices` (tree-2 levels repriced).
  - Both are idempotent because the next write stores tree 3. `load_progress` re-saves any save with version < 7 (progress.gd:854).
- Codes are `"SLIME2-"` + base64(gzip(the same text, built with `for_code`)). Codes leave out descent_run, language, hub, boards and attempt_base. `read_code` checks prefix, length ≤ 65536, the base64 regex, bounded gunzip, the allow-list, `[progress]` present and the epoch. `is_old_code` recognises `SLIME1-` and other-epoch codes.

**When saves are written and how failures are handled**
- `save_progress()` runs at once on almost every state change: coin pickups, clears, purchases, settings changes, slider release, hub/wheel actions, Descent floor snapshots. That's about 55 call sites in progress.gd. `begin/end_save_batch` (used by LookRoller) merges several changes into one write, and a deferred close stops an open batch from swallowing later saves.
- Every save runs `check_achievements()` first. Writes are skipped when saving is off (any debug flag, tests, headless), under `demo_guard`, or while the demo preview runs.
- `write_atomic`:
  1. Writes `save.cfg.tmp`.
  2. Reads it back and compares bytes.
  3. Renames it over the save, with one retry.
  - On failure the old file stays. `save_failed` triggers a one-per-session toast and retries after 5 s doubling to 60 s. `flush_save` retries when the app goes to the background.
- On launch, `_recover_temp_save` deletes a stray .tmp. If save.cfg is missing, it promotes a .tmp that passes the checks.

**Reading a damaged or foreign save**
- Unreadable (fails the allow-list, too big, won't parse): renamed or copied to `save.corrupt.cfg` with 3 rotating backups and a toast. If the backup can't be made, saving turns off.
- Fails the allow-list but has a peeked `version` > 7: copied to `save.newer.cfg`, saving turns off and a toast shows.
- Other or missing epoch, including an empty file: copied to `save.oldepoch.cfg`, then a fresh start that the next save overwrites.
- Valid but from a newer version: same handling as the newer case above.
- Tests, tools, headless, dev and movie runs use `user://test_save_run_<pid>.cfg`. Dev and headless runs may read the real save, but `owned` = false, so it is never set aside, migrated or written. `--story`, `--autoplay`, `--tutorial` and `--demo` start from a clean in-memory state. The ghosts side file (`ghosts.cfg`) goes through the same allow-list and atomic write.

**Scoring, tickets, medals and unlocks**
- **Medals:** `tier_for(time, par)` gives gold if ≤ par, silver if ≤ 1.3×par, bronze otherwise. `record_clear` keeps the best tier per level key (hard = +100) and records nothing for assisted runs. `all_medals()` means 30/30 on normal.
- **Coins:** derived, not stored. Coins in hand = coins found (per level, capped at `Levels.COINS`) minus the tree cost of the levels bought at today's prices (demo prices in the demo). On load, levels are dropped until the balance is ≥ 0.
- **Randomizer pay** (`random_payout`):
  - The base comes from the attempt table [10,8,6,4,2,1], times the length factor (0.4–1.5, flat 1.4 on hard), rounded, minimum 1.
  - Then the caps: daily cap (switched off), seed already paid today = 0, typed/replayed seed = 1, no MORE SLIME = 1.
  - The daily maze pays a flat 20 once per UTC day. Ticket pickups pay 1 each, held until the win. A maze abandoned after a move carries its attempt count into the next maze (`_abandon_base`, saved as `[wallet] attempt_base`).
  - The weekly pays 2–20 by time vs par, and only the improvement over what that week already paid. The daily streak pays +10 every 7th day, with one streak saver per 7 days.
- **Achievement rewards:** goal rewards (cosmetics) and medal milestones (15/30/45/60 medals: a cosmetic, or 20 tickets if already owned) are paid inside `check_achievements` at save time.
- **Wheel:** first spin free, then a flat 20. Roll = `hash([wheel_seed, spins])`, so it's deterministic per save. Rare items get weight 0.3, and the rainbow hat has pity. The first spin never lands on a rare item.
- **Skins:** `Skins.is_unlocked`: opaque by levels cleared, jelly by hard clears, rainbow by all 165 coins, stopwatch by all medals, pastel by randomizer wins (every 5; rainbow at 100). The look is recomputed on every load.

**Demo vs full game**
- One switch, `Demo.on()` (`Platform.is_demo`). Every gate asks Demo: levels 1–4, hard 1, upgrade caps 3/2/1 at the demo's own prices that total 34 coins, the RIFLE ability only, SHOP closed, wheel ≤ 2 hats after the end screen, pastel/custom/rainbow/stopwatch locked.
- The demo writes `[meta] demo`. A save or code without that marker sets `demo_guard`: it is played in memory and never written.
- The preview (`begin_demo_preview`) snapshots `_write()` plus `_PREVIEW_LIVE_KEYS`, borrows a full-game look, maxes abilities and upgrades, writes nothing, and `end_demo_preview` puts everything back with `_read`.
- The full game reads demo saves and drops the marker on the next write. Achievements are never written by the demo.

**How other systems read and write Progress**
- Mostly through methods: `collect_coin`, `record_clear`, `complete_random`, `buy_*`, `select_*`, `spin_hat`, `record_survey`, `post_board`, and so on. Each one saves.
- About 30 fields are written directly from outside:
  - settings toggles in controls.gd (`sound_on`, `reduce_motion`, `fog_brightness`, `relaxed`, ...), followed by an explicit save
  - run state in game.gd and pause_menu.gd (`random_seed`, `random_daily`, `random_weekly`, `random_seed_fresh`, `keep_look_once`, `relaxed_level`, `return_to_game`, ...)
  - `Progress.custom_color` in skins_screen
- Static helpers reach the autoload through `Engine.get_main_loop().root.get_node("Progress")` (Boards, LookRoller).
- `Skins.jelly` / `Skins.pastel` are static mirrors kept in step by `set_jelly` / `set_pastel`.

## 2. Findings

Severity counts: critical 0, high 0, medium 3, low 16.

### B-01: A retried save can wipe the only remaining copy (Windows rename path)
- **Severity:** medium (save loss, but only after two failures in a row)
- **Category:** bug
- **Where:** progress.gd:1299-1318 (`write_atomic`), progress.gd:947-956 (`_recover_temp_save`)
- **Evidence:**
  - The function's own comment says that on Windows Godot "removes then renames". If the rename then fails, `if FileAccess.file_exists(path): ... # else ... the verified temp file is now the only copy and stays`, and it returns false.
  - That schedules `_schedule_save_retry`, and any normal save also goes back into `write_atomic(save_path, ...)`, which does `FileAccess.open(temp, FileAccess.WRITE)` (:1303). That truncates the only good copy first.
  - If this write fails or doesn't verify (the same full disk or AV lock that broke the rename), `DirAccess.remove_absolute(g_temp)` (:1309) runs unconditionally. Neither `save.cfg` nor `.tmp` is left. If the player then quits, all progress is gone, because `_recover_temp_save` has nothing to promote.
  - The same thing happens on a first-ever save whose rename fails twice.
- **Fix:** At the top of `write_atomic`, if `path` is missing and `temp` exists, try to promote `temp` to `path` first. Otherwise write to a second temp name, and never delete a temp while `path` is missing.
- **Behavior risk:** none
- **Confidence:** medium. The code path is certain; the Windows remove-then-rename behaviour is taken from the code's own comment and not checked against engine source.

### B-02: RESET PROGRESS keeps the parked randomizer abandon penalty, and it gets saved
- **Severity:** medium
- **Category:** bug
- **Where:** progress.gd:3329-3421 (`reset_progress`), save_file.gd:441-448, progress.gd:2627-2641
- **Evidence:**
  - `reset_progress` clears `random_attempts` / `random_attempt_base` / `random_moved`. It does not clear `random_attempt_carry`, `random_daily`, `random_weekly`, `random_maze_won`, `daily_run_day` or `random_map`.
  - Path: abandon a random maze after a move (`start_daily` parks `random_attempt_carry = _abandon_base()`, up to 5), go back to the hub (`random_daily` stays true), then SETTINGS > RESET PROGRESS.
  - `SaveFile.write` then stores `abandon = p.random_attempt_carry` as `[wallet] attempt_base` in the freshly reset save. `_read_wallet` turns that back into `random_attempts = {"saved": n}` / `random_moved = true`, and every later save writes it again.
  - The first random maze after re-beating the story starts at attempt n+1, so it pays 1 instead of 10 tickets.
- **Fix:** Reset the runtime randomizer fields in `reset_progress`: `random_attempt_carry = 0`, `random_daily/weekly/maze_won = false`, `daily_run_day = 0`, `discard_random_map()`.
- **Behavior risk:** changes gameplay/economy (corrects a payout)
- **Confidence:** high

### B-03: The ACHIEVEMENTS page derives "unlocked" live, so WIN A WEEKLY MAZE re-locks after a save-code import
- **Severity:** medium
- **Category:** bug
- **Where:** achievements.gd:93; scripts/ui/achievements_screen.gd:189,194; save_file.gd:202-203,496
- **Evidence:**
  - The page counts and draws each goal with `Achievements.met(p, a.id)`, not `p.ach_known`. `weekly_1` is `not p.board_weekly.is_empty()`.
  - Boards are never put in a code (`write`: `... not for_code ...`) and are never read from one (`if not from_code: _read_boards`). So a player who imports their code on a new device, or after browser storage was cleared, sees WIN A WEEKLY MAZE as locked and the unlocked count one short.
  - Meanwhile `ach_known` still lists the goal, its reward (`cobalt_paper`) stays owned, and the hub "!" counts it.
- **Fix:** Draw a goal as unlocked when `id in p.ach_known or Achievements.met(...)`. Alternatively, derive `weekly_1` from a stat that codes carry.
- **Behavior risk:** none
- **Confidence:** high

### B-04: A migrated save overwrites the only pre-migration copy
- **Severity:** low
- **Category:** architecture
- **Where:** progress.gd:850-855; save_file.gd:77-80
- **Evidence:** `_migrate_tree` / `_migrate_prices` rewrite upgrade levels in memory, and then `if ... version < SAVE_VERSION: save_progress()` (plus a possible earlier `check_achievements()` save) replaces save.cfg. No `save.premigration.cfg` is kept, so a bad future migration can't be rolled back. Corrupt, newer and other-epoch saves all get backups; migrated saves are the one load path that doesn't.
- **Fix:** Copy the file to `<save>.v<old>.cfg` once before the first write after a migration.
- **Behavior risk:** none
- **Confidence:** high

### B-05: Backup copies before an overwrite are unchecked
- **Severity:** low
- **Category:** unchecked-error
- **Where:** progress.gd:824, 832, 841
- **Evidence:** `DirAccess.copy_absolute(... other_epoch_backup_path(...))` ignores its return value, and the fresh start that follows is overwritten by the next save. If the copy fails (permissions, disk full), the other-epoch save is lost without warning. The newer-save copies (:824, :841) are safe only because saving is switched off right after.
- **Fix:** Check the result. On failure, set `saving_enabled = false` (as `_set_aside_corrupt` does) or show a notice.
- **Behavior risk:** none
- **Confidence:** high

### B-06: The demo preview snapshot misses some runtime fields
- **Severity:** low
- **Category:** bug
- **Where:** progress.gd:2222-2223 (`_PREVIEW_LIVE_KEYS`), 2258-2267, 2315-2316
- **Evidence:** `begin_demo_preview` clears `random_tickets_held` and sets `random_daily = false`. Neither these nor `random_maze_won` / `random_attempt_carry` are in `_PREVIEW_LIVE_KEYS`, while `random_tickets_taken` is. After `end_demo_preview`, a random maze that had held (unpaid) pickups keeps them "taken" with no held list, so `begin_random_attempt` (:1739-1745) never puts them back. In normal demo flow the preview is the first randomizer use, so this is hard to reach.
- **Fix:** Add `random_tickets_held`, `random_maze_won`, `random_daily`, `random_weekly` and `random_attempt_carry` to `_PREVIEW_LIVE_KEYS`.
- **Behavior risk:** none
- **Confidence:** medium

### B-07: Ending the preview treats a guarded full-game save as a demo save
- **Severity:** low
- **Category:** bug
- **Where:** progress.gd:2251, 2314; save_file.gd:81-91, 378-379
- **Evidence:** `_preview_save = _write()`. In the demo, `write` always sets `[meta] demo = true`, so `end_demo_preview` → `_read(before)` sees `is_demo_save(file)` and applies the demo-save fix-ups: upgrades clamped to `Demo.upgrade_cap` and `_drop_priciest_level` until the balance is ≥ 0, where only coins from levels 1–4 count. For a player whose full-game save is guarded in the demo, upgrades drop for the rest of the session. It is in memory only, because guarded saves are never written.
- **Fix:** Snapshot without the demo marker (pass a flag to `SaveFile.write`), or skip the demo fix-ups when restoring the preview.
- **Behavior risk:** none
- **Confidence:** medium

### B-08: Every save rebuilds the localized achievement list two or three times
- **Severity:** low
- **Category:** hot-path (needs measurement)
- **Where:** progress.gd:1195, 1202, 1215; achievements.gd:18-47, 50-54, 131-136
- **Evidence:**
  - `check_achievements` runs at the top of every `save_progress`.
  - `Achievements.met_ids` → `ids()` → `list()` builds 24 dictionaries with `Loc.t(...)` each time. It's called twice per check, and again inside the per-new-goal loop.
  - Saves happen on each coin pickup, clear and purchase.
- **Fix:** Cache the id list as a const array and build `list()` only for the page and toasts.
- **Behavior risk:** none
- **Confidence:** high on the code; perf impact unmeasured

### B-09: The hat sprite redoes catalog lookups every frame
- **Severity:** low
- **Category:** hot-path (needs measurement)
- **Where:** hat.gd:119-164 → hats.gd:306-331, 92-98, 357-359
- **Evidence:**
  - `Hat._process` → `_follow` calls `Hats.dye_region` every frame. That calls `region` → `get_hat` (linear scan), `frames` (another scan), and for animated hats on 7 of 8 frames `anim_column`, which does `LIST.duplicate()` + `sort_custom` per call.
  - `dyes_for` calls `get_hat(id)` once per dye (11×).
  - `Hats.lift` builds a `"%s:%d:%s:%d"` key string per frame.
- **Fix:** Precompute anim columns and dye lists into static dicts, and cache the region per (width, frame) in Hat.
- **Behavior risk:** none
- **Confidence:** high on the code; perf impact unmeasured

### B-10: The "start a fresh random maze" reset block is copied 5 times
- **Severity:** low
- **Category:** duplication
- **Where:** progress.gd:1998-2006 (`start_daily`), 2106-2114 (`start_weekly`), 2260-2267 (`begin_demo_preview`), 2637-2647 (`new_random_maze`), 3378-3384 (`reset_progress`)
- **Evidence:** The same `random_seed_fresh/attempt_base/moved/maze_won` assignments plus `random_attempts/offer_shown/tickets_taken/tickets_held.clear()` appear five times. B-02 is one of the copies falling out of step.
- **Fix:** Add one `_reset_random_maze_state()` helper.
- **Behavior risk:** none
- **Confidence:** high

### B-11: The daily seed hash is copied, and it relies on 64-bit signed wraparound
- **Severity:** low
- **Category:** duplication
- **Where:** progress.gd:1977-1982; boards.gd:36-43
- **Evidence:** "the same integer hash as Progress.daily_seed, copied". The intermediate `x * 2246822519` and `x * 3266489917`, with x up to 0xFFFFFFFF, exceed 2^63, so the result depends on the engine's int64 multiply wrapping. The low 32 bits are still right when it wraps, which happens in practice on x86, ARM and wasm.
- **Fix:** Move it to one static helper (e.g. in Boards, which both can name), and mask after each multiply by splitting the multiply into 16-bit halves.
- **Behavior risk:** none, as long as the output is kept identical
- **Confidence:** high on the duplication; medium on the overflow claim

### B-12: Tool-flag detection is duplicated and the copies have drifted
- **Severity:** low
- **Category:** duplication
- **Where:** progress.gd:761-773 (`_is_non_player_run`), 797-801; dev_log.gd:48-57 (`_is_owner_launch`)
- **Evidence:** The two lists differ. progress.gd has `--dev`, `--unlock-all`, `--editor`, `-e` and `--export*`; dev_log.gd lacks them. The 6-hour stale-file cleanup is also written twice (progress.gd:753 and dev_log.gd:102, `6 * 3600`).
- **Fix:** Have DevLog call `Progress._is_non_player_run()` (it's static), and share a `STALE_SECONDS` const.
- **Behavior risk:** none
- **Confidence:** high

### B-13: Base64 validation is duplicated and missing from the ghost decoder
- **Severity:** low
- **Category:** duplication / unchecked-error
- **Where:** progress.gd:1378, 1383; survey.gd:230-237; boards.gd:161-163
- **Evidence:** Two separate copies of the `^[A-Za-z0-9+/]+={0,2}$` regex exist. `Boards.decode_pts` calls `Marshalls.base64_to_raw(text)` on untrusted ghosts.cfg text with no check, which logs engine errors on a damaged file. Both other decoders refuse first because of that ("would log engine errors").
- **Fix:** Put one shared `is_base64(text)` in save_text.gd and use it in all three places.
- **Behavior risk:** none
- **Confidence:** high

### B-14: The ghosts file is read fully before its size is checked
- **Severity:** low
- **Category:** unchecked-error
- **Where:** boards.gd:193
- **Evidence:** `SaveText.parse(FileAccess.get_file_as_bytes(path))` loads the whole file and only then rejects anything over `MAX_BYTES`. `Progress._load_checked` (progress.gd:861-866) checks `get_length()` before reading.
- **Fix:** Open the file, check its length, then read (reuse `_load_checked`).
- **Behavior risk:** none
- **Confidence:** high

### B-15: Dead or test-only code
- **Severity:** low
- **Category:** dead-code
- **Where and evidence:**
  - achievements.gd:171 `milestones_reached`: 0 references anywhere, tests included.
  - progress.gd:1185 `check_achievements(silent := false)`: no caller passes `silent`.
  - descent.gd:28-46: the `NAMES` / `ABOUT` dicts are only reachable as fallbacks after `match` statements that cover every id.
  - upgrades.gd:121 `relight_radius`, hats.gd:335 `sheet_columns`, workshop.gd:76 `full_cost`: used only by tests.
  - The pre-ONE_ASSIST reserve path (progress.gd:1925-1963 `assist_offered/accept_assist/take_assist`, `ASSIST_BONUS`; callers game.gd:520,3121, hud.gd:241,875) can't run while `Economy.ONE_ASSIST` (a const) is true.
- **Fix:** Delete the first three. Keep the test-only helpers or move them into the tests. Decide whether the ONE_ASSIST=false path is still wanted.
- **Behavior risk:** none
- **Confidence:** high

### B-16: Demo story bits are defined twice
- **Severity:** low
- **Category:** duplication
- **Where:** progress.gd:92-98; demo.gd:89, 99, 101
- **Evidence:** `Demo.PREVIEW_SEEN_BIT := 16  # (= Progress.STORY_DEMO_PREVIEW: keep the two in step)`, and the same for `END_SEEN_BIT` / `RANDOM_END_SEEN_BIT`. The two copies are kept in step only by comments.
- **Fix:** Define them once (in Demo), and make Progress alias them or use them directly.
- **Behavior risk:** none
- **Confidence:** high

### B-17: Stale numbers in comments and a misfiled section
- **Severity:** low
- **Category:** hygiene
- **Where and evidence:**
  - progress.gd:122-123 says the wheel is "free, then 12, +2 per spin taken, up to 40" and that hats are never sold. Actually `SPIN_COST` = 20, `SPIN_STEP` = 0, `SPIN_COST_MAX` = 20.
  - hats.gd:6 says "12 tickets rising by 2 per spin".
  - demo.gd:60-61 says "A randomizer win pays at most 5 tickets ... (full: 15)". Pay is now up to 10 and the RIFLE costs 30.
  - progress.gd:2816-2818 has two doc lines for `hats_left`.
  - progress.gd:2650 has an empty "skins" section header.
  - The "slime reserve (assist)" section (progress.gd:1921-2091) also holds the random/daily maze code.
- **Fix:** Correct the numbers, or point the comments at the Economy names, and re-head the sections.
- **Behavior risk:** none
- **Confidence:** high

### B-18: The default custom color is a repeated literal
- **Severity:** low
- **Category:** magic-number
- **Where:** progress.gd:346, 355, 3342
- **Evidence:** `Color8(239, 125, 47)` appears three times: the defaults of `custom_color` and `hub_custom`, and the reset. It equals the Ember preset color (skins.gd:72).
- **Fix:** Use one `DEFAULT_CUSTOM_COLOR` const.
- **Behavior risk:** none
- **Confidence:** high

### B-19: progress.gd is a god object
- **Severity:** low
- **Category:** architecture
- **Where:** progress.gd (3,683 lines, 264 funcs, 146 vars)
- **Evidence:**
  - Every saved field has to be added in four places: the var declaration, `reset_progress` (:3329), `SaveFile.read` and `SaveFile.write`. Runtime randomizer state is also reset by hand in five places. B-02 and B-06 are both cases of these lists getting out of step.
  - It could be split into these pieces with no change to the save format:
    - (a) `LaunchFlags`: `_ready`'s flag loop :474-612, the enable_* debug states, `game_args/user_args`, the save-path choice.
    - (b) `SaveStore`: `load_progress`, `write_atomic`, retry, corrupt/newer/epoch backups, codes; currently :804-1418.
    - (c) `RandomRuns`: attempts, payouts, daily/weekly, boards/ghosts, random map; :1697-2215, :2583-2648.
    - (d) `DescentState`: :2326-2581.
    - (e) `DemoPreview`: :2216-2324.
    - (f) `TicketStore`: wheel, dyes, workshop, abilities, cosmetics, hub news; :2803-3238.
  - Progress would keep the fields and delegate, like `SaveFile` does today. A field registry (name, section, default, reset?) would also replace the four parallel lists.
- **Fix:** Split in the order (b), (c), (a). Generate `reset_progress` from the defaults table.
- **Behavior risk:** none
- **Confidence:** high

## Checked and found fine (not findings)
- The writer and the allow-list agree on every value type written: typed arrays, int-keyed board dicts holding `Array[int]`, Color, and floats in `d.de±XX` form. Maps are stored as base64 strings, and seen coins are packed as ints.
- No signal is connected more than once in scope. `_watch_window_mode` connects once, and the retry timer is guarded by `_retry_pending`.
- Repeat daily wins can't pay twice: game.gd:2202-2204 `daily_repeat()` passes `assisted=true`.
- Store and hub affordability scans run only when `near` changes (hub.gd:2213-2231), not every frame.
- Migration order in `SaveFile.read` is correct: coins → upgrades → migrations → balance fix → descent → store → skin.
