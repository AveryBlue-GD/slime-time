# itch.io release notes

## Fresh-start policy

**Rule (owner, 2026-10-14):** progress from builds before the public release never carries over. Every
player of the public build (web/itch on desktop, Android and iOS browsers; the Windows and macOS builds)
starts from a fresh save, including anyone who played an earlier build, and old save codes don't load.

### How it works

Two independent locks, so one slip can't let old progress in:

1. **A new user data directory.** `project.godot` sets `application/config/use_custom_user_dir=true` and
   `application/config/custom_user_dir_name="SlimeTime_R1"` (R1 = release epoch 1). `user://` (and with it
   `user://save.cfg`, `Progress.REAL_SAVE_PATH`) now resolves to:

   | Platform | Release save (new) | Pre-release save (old, never read) |
   |---|---|---|
   | macOS | `~/Library/Application Support/SlimeTime_R1/save.cfg` | `~/Library/Application Support/Godot/app_userdata/Slime Time/save.cfg` |
   | Windows | `%APPDATA%\SlimeTime_R1\save.cfg` | `%APPDATA%\Godot\app_userdata\Slime Time\save.cfg` |
   | Linux | `~/.local/share/SlimeTime_R1/save.cfg` | `~/.local/share/godot/app_userdata/Slime Time/save.cfg` |
   | Web (itch) | `/userfs/SlimeTime_R1/save.cfg` in the page's IndexedDB | `/userfs/<godot dir>/app_userdata/Slime Time/save.cfg` |

   Godot builds the path in `OS::get_user_data_dir()`: with the custom dir on it is
   `<data dir>/<custom_user_dir_name>`, otherwise `<data dir>/<Godot dir>/app_userdata/<config/name>`. On the
   web, `OS_Web::get_user_data_dir(dir)` is `"/userfs".path_join(dir)`; `/userfs` is the IndexedDB-backed
   (IDBFS) folder Godot syncs, so the folder name is the only thing that separates one save from another.
   That matters on itch: every HTML5 game is served from the same origin (`html-classic.itch.zone`, one
   folder per upload), so every Godot web game on itch shares one browser IndexedDB `/userfs`, and a new
   upload of this game sees whatever an old upload wrote. A new folder name is what makes the public
   build blind to the old save. The old files are never deleted or changed: they stay on disk / in the
   browser and are simply never read (nothing in the game names the old path).
   Android/iOS here means their **browsers** (the web build), so the web row applies.

2. **A release epoch inside every save and code.** `Progress.RELEASE_EPOCH = 1` is written as `[meta]
   epoch` on every save and code. `load_progress` and `read_code` only accept a save whose epoch is
   exactly this int; a save without it (every pre-release build) or with another epoch starts fresh (the
   file is left as it is until the next save overwrites it). Codes now start `SLIME2-`
   (`Progress.SAVE_CODE_PREFIX`); old `SLIME1-` codes, and old code bodies re-labelled `SLIME2-`, are
   refused. The pre-v5 save migrations (`_migrate_*`) are still in the code but can't run for a real
   player any more (every save of this epoch is version 5+); they are tested through `_read` directly.

Tests: `tests/test_fresh_start.gd` (dir name / epoch / prefix agree, `OS.get_user_data_dir()`, fresh start
on a missing or epoch-less save, the code round trip, old codes refused with the message (LOAD and the web
paste path), 5,000 hostile codes, real saves untouched). Tests, tools, headless, movie, screenshot and dev
runs still use throwaway files (`user://test_save_run_<pid>.cfg`), now inside the new dir.

### What players see

- **New or returning player, any platform:** the game starts like a first launch (story intro, level 1,
  default settings and keys). Nothing tells them an old save existed.
- **Pasting an old `SLIME1-` code** in SETTINGS > SAVE CODE: `THAT CODE IS FROM AN OLD VERSION`, and LOAD
  never arms. A broken code still says `THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE`.
- **The owner** too: a plain `./tools/play.sh` launch reads the new dir, so local progress starts over.
  The old file is still at the old path if it's ever wanted, but it can't be loaded by the game.

### Bumping the epoch (a future wipe)

Change all three together (the test fails if they disagree):

1. `project.godot`: `application/config/custom_user_dir_name="SlimeTime_R2"`.
2. `scripts/progress.gd`: `RELEASE_EPOCH := 2` and `SAVE_CODE_PREFIX := "SLIME3-"`.
3. Update the paths in this doc, `docs/handoff.md` and `CLAUDE.md`, run `./tools/test_all.sh`, and fix the
   tests that build codes with the old prefix by hand (`grep -rn SLIME tests/`).

Never reuse an old dir name. To keep progress across a release instead, don't bump anything.
