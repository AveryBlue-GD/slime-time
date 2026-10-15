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
   refused. The pre-v5 save migrations were removed from the code (spring cleaning, 2026-10-15); every save of this
   epoch is version 5+. Only `_migrate_tree` / `_migrate_prices` (in-epoch coin tree 1/2 saves) remain.

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

## Desktop builds (Windows, macOS, Linux)

Presets in `export_presets.cfg` (export with the 4.7.2 templates; zips go to the Desktop as before):

- **Windows Desktop** (`build/windows/SlimeTime.exe`, x86_64, pck embedded). The exe carries the game icon and version
  info: `application/modify_resources=true` (Godot's own resource editor, no rcedit/Wine needed, also when exporting
  from a Mac), `application/icon="res://icon.ico"`, file/product version `1.0.0.0`, company and product "Slime Time",
  copyright `(c) 2026 Slime Time` (placeholders: change them to the real owner / version before a release).
  `icon.ico` (16, 32, 48, 64, 128, 256 px, nearest-neighbor from `icon.png`) is generated by
  `python3 -I tools/make_icon_ico.py` (rerun after changing `icon.png`); `config/windows_native_icon` uses it for the window.
- **macOS** (`build/macos/SlimeTime.zip` holding `Slime Time.app`): universal (x86_64 + arm64), bundle id
  `com.slimetime.game` (a placeholder: the owner may change it to a reverse-DNS id they control; changing it later
  gives the app a new identity but does not move the save, which is keyed by `custom_user_dir_name`), version 1.0.0,
  min macOS 10.13 (Intel) / 11.0 (Apple silicon), category Games, `codesign/codesign=3` = **ad-hoc signature**, no
  notarization, no entitlements (no JIT, sandbox or hardened-runtime exceptions needed). The arm64 slice needs
  `project.godot` `textures/vram_compression/import_etc2_astc=true` (set). Checked 2026-10-14: exports with no errors,
  `codesign -dv` = `Signature=adhoc`, `Format=app bundle with Mach-O universal (x86_64 arm64)`,
  `codesign --verify --deep --strict` clean, `Contents/MacOS/Slime Time --headless --quit-after 60` exits 0.
- **Linux** (`build/linux/SlimeTime.x86_64`, x86_64, pck embedded; added in the spring cleaning, phase 5): the Windows
  exclude filters, no console wrapper. Exported and checked with the 4.7.2 templates (78.7 MB, an x86-64 ELF, no tests / tools /
  docs in the pck); not run on a Linux machine yet. Android, iOS and Steam presets are port-time work with their own
  checklist: [spring-cleaning/phase5-platform.md](spring-cleaning/phase5-platform.md).
- **Gatekeeper (macOS players from itch):** an ad-hoc signed, un-notarized app downloaded in a browser is quarantined, and
  `spctl` rejects it. Players must **right-click (or Control-click) the app > Open > Open** the first time (on macOS 15+:
  try to open it once, then System Settings > Privacy & Security > "Open Anyway"), or run
  `xattr -dr com.apple.quarantine "/path/to/Slime Time.app"`. Put that line on the itch page. A warning-free app needs an
  Apple Developer ID ($99/yr): set `codesign/identity`, `codesign/apple_team_id`, `notarization/notarization=1`.

## Release build checks

- **Debug flags:** exported RELEASE builds ignore every launch flag after `--` except `--touch` and `--web-ui` (UI layout
  only). `--unlock-all`, `--story-complete`, `--autoplay*`, `--level=`, `--coins=`, `--tickets=`, `--medals=`,
  `--upgrades=`, `--skin=`, `--hat=`, `--maps=`, `--random`, `--hard`, `--jelly`, `--all-coins`, `--save-path=` only
  work in debug builds (the editor binary that `tools/play.sh`, `screenshot.sh` and `test_all.sh` use). A release launch
  with ignored flags prints `debug launch flags are ignored in release builds` and plays normally. Test:
  `tests/test_release_flags.gd`; by hand: run the exported app with `--headless --quit-after 60 -- --unlock-all`.
- **Save files:** saves are written atomically (`save.cfg.tmp`, read back, renamed over `save.cfg`). A save that can't be
  read is kept as `save.corrupt.cfg` (up to 3: `.corrupt.2.cfg`, `.corrupt.3.cfg`) next to it and the game starts fresh;
  to restore one by hand, quit the game and rename it back to `save.cfg`. Pasted codes and save files are checked by
  `scripts/save_text.gd` before they are parsed (docs/qa-release-report.md S1).
- When running an exported build on the dev Mac, use a fake home so the real save dir isn't touched:
  `HOME=/tmp/x CFFIXED_USER_HOME=/tmp/x "Slime Time.app/Contents/MacOS/Slime Time" --headless --quit-after 60`.
