# Release QA report (save robustness, soak, extremes, exports)

Date 2026-10-14, Godot 4.7.2, macOS arm64 (M3). Scope: break the game before the public itch.io release. No game code was
changed; everything here is new test / driver files under `tests/` plus this report. Scratch work lived in
`/private/tmp/claude-501/qa/`.

**Real saves:** `~/Library/Application Support/SlimeTime_R1/save.cfg` did not exist before, during or after (md5 n/a, still absent;
the dir exists with only dev logs / logs from test runs). The pre-release save
`~/Library/Application Support/Godot/app_userdata/Slime Time/save.cfg` md5 `6e9f56dac03e68a2287ad629aecca039` before and after.
All real-path boot experiments used a fake `HOME` (`/private/tmp/claude-501/qa/boot/home_*`); the owner's game was never touched.

## Status (2026-10-14, after the fix pass)

| Item | Status | Fix / where | Regression test |
|---|---|---|---|
| S1 code / save.cfg runs GDScript | **fixed** | `scripts/save_text.gd` (`SaveText`): every untrusted text (save.cfg via `Progress.load_progress`, pasted codes via `read_code` / `is_old_code`) passes a strict allow-list BEFORE `ConfigFile.parse` (`ConfigFile.load` is no longer used). Grammar: `[section]`, `key=value`, `;` comment lines; values = numbers, strings, true/false/null/nan/inf/inf_neg, arrays, dicts, and only `Color(4 numbers)`, `Array[int]([..])`, `Array[String]([..])`; any other identifier rejects the whole text; values type-checked again after parsing | `test_save_robust` `_injection` (31 payload variants x code + save.cfg, marker never set), `_validator`, `_full_round_trip`; `qa_poc_code_injection.gd --mode=object` now prints `not executed` |
| S11 deep nesting crash | **fixed** | SaveText limits run before parsing: 256 KB text, 64 KB line, depth 8, valid UTF-8 | `_limits` (200,000 / 100,000 / 10,000 / 9 levels, code and save.cfg); `--mode=nest` now returns normally |
| S10 gzip + trailing bytes hang | **fixed** | `SaveText.gunzip`: gzip magic, ISIZE trailer 1..256 KB, one bounded `decompress(isize)`, size must match; `decompress_dynamic` is gone | `_gzip` (PoC inputs extra 0..8, code pasted twice, stray `AAAA`, base64 stage, 4 MB zip bomb); `qa_poc_gzip_hang.gd` returns in 0.3 s |
| S2 corrupt save silently replaced | **fixed** | An existing save that can't be opened / fails the allow-list / doesn't parse is renamed to `save.corrupt.cfg` (older ones rotate to `.corrupt.2.cfg`, `.corrupt.3.cfg`; 3 kept) before starting fresh; if it can't be moved or copied, saving is turned off for the session. Only for the game's own save with saving on (dev runs that peek at the real save never move it). Another-epoch and empty files are not "corrupt" (policy). Not shown to the player (no UI change; `Progress.corrupt_backup` holds the path) | `_file_cases` (every junk file moved aside intact), `_overwrite_policy` |
| S9 non-atomic write | **fixed** | `Progress.write_atomic`: write `save.cfg.tmp`, read it back and compare, rename over `save.cfg`; on failure the old file stays, progress stays in memory, `save_failed` is set and the save is retried (5 s doubling to 60 s, and on the next save). A leftover `.tmp` next to a save is discarded at load; a lone complete one is recovered. Verified on the web build (IndexedDB holds `save.cfg`, no `.tmp`) | `_overwrite_policy` (blocked temp path, crash leftovers), `_dirs` (read-only / missing dir), `_disk_full` (runs `qa_poc_disk_full.gd` under `ulimit -f 1`: old save intact) |
| S3 / S3b future pay day locks payouts | **fixed** | `Progress._check_pay_day`: a stored day more than `PAY_DAY_AHEAD` (2) days after today counts as today (today's count kept), on read and before every payout check; smaller differences keep the forward-only rule | `_clock`; `test_tickets` (clock 5 days back: still capped, day reset to today) |
| X1 Windows exe icon / metadata | **fixed** | `icon.ico` (16-256 px, nearest-neighbor, `tools/make_icon_ico.py`), Windows preset `modify_resources=true` + icon, version 1.0.0.0, company/product "Slime Time", copyright placeholder; `config/windows_native_icon` | export checked: all 6 icon images and the version strings are in the exe |
| X2 debug flags in release builds | **fixed** | `Progress.game_args` / `user_args`: a release export (`OS.is_debug_build()` false) honors only `--touch` and `--web-ui`; everything else (incl. `--save-path=`) is ignored and the launch is a normal one | `test_release_flags.gd`; exported macOS release app run with `--unlock-all --story-complete --level=10 --coins=99 --save-path=... --autoplay --touch`: prints "debug launch flags are ignored in release builds (kept: --touch)", no hack save, quits on time |
| macOS preset (section 4) | **applied** | `[preset.2]` "macOS" in `export_presets.cfg` + `import_etc2_astc=true`; see [itch-release.md](itch-release.md) | export: universal (x86_64 arm64), `Signature=adhoc`, `codesign --verify --deep --strict` clean, headless smoke exit 0 |
| S4 zero / negative records | **fixed** | records below `MIN_RECORD` (0.001 s) are dropped on read and never recorded | `_matrix` |
| S6 unvalidated `[controls]` | **fixed** | `_read_bindings`: missing / non-key / duplicate keys fall back to the default, a remaining clash resets all bindings; `set_binding` ignores non-keys | `_matrix` |
| S7 gzip CRC not checked | open (low) | copy/paste never hits it; single-character typos never decode | - |
| S8 console noise | partly | the "no default was given" epoch error is gone; zlib still logs `Condition "err != 1"` for a broken code (console only) | `_code_fuzz` counts it as noise |
| Mangled codes (NBSP, zero-width, quotes, fence, period, BOM) | **fixed** | `_clean_code` strips them | `_gzip` |
| E1 `+5` seed, E2 20-digit seed error | **fixed** | `Levels.parse_seed_code` refuses `+` and over-long numbers before `to_int` | `test_extremes` `_seeds` |
| E3 dev-only / unknown upgrade bought | **fixed** | `buy_upgrade` refuses unknown ids and `power` outside dev mode | `test_extremes` `_economy` |
| M1 ~6-9 KB static memory per level start | open (info) | Checked: every GDScript-side cache is bounded (story mazes 20 keys, randomizer maze 1, tile sets per theme, light textures per size, map previews per percent, hat lifts / slime heads per frame); objects, nodes and resources stay flat. A 800-start soak: static 44.9 -> 48.4 MB in steps, i.e. engine-internal allocator growth, nothing to cap from script | - |
| Version-99 save downgrade, two windows last-writer-wins | open (by design / low) | unchanged | - |
| Exit warnings ("2 ObjectDB instances leaked", "1 resources still in use") on `--quit-after` | open (info, pre-existing) | also on the pre-fix HEAD; harmless at shutdown | - |

## Summary

| Severity | Count | Items |
|---|---|---|
| Critical | 1 | S1 pasted save code (or hand-made save.cfg) can run arbitrary GDScript |
| High | 2 | S10 pasted code that is gzip + trailing bytes freezes the game forever; S11 pasted code with deep nesting segfaults the game |
| Medium | 4 | S2 corrupt save is silently replaced (no backup), S9 non-atomic write truncates on disk full, S3 a wrong clock locks ticket payouts for years, X1 Windows exe has the default Godot icon / no metadata |
| Low / info | 12 | S4-S8, E1-E3, X2-X4, M1, N1 (below) |

Soaks: **no drift** (nodes/orphans flat, resources flat, memory creeps about 9 KB per level start, see M1). Autoplay x3 identical.
Nav fuzzer: 24 new seeds, 0 new violations. Windows and Web presets export with no errors or warnings. A macOS preset does
not exist; the text for one is in section 4 and it was built, ad-hoc signed and smoke-run in a scratch copy.

New files: `tests/test_save_robust.gd` (about 12 s), `tests/test_extremes.gd` (about 10 s) run by `test_all.sh`; long drivers / proofs
not run by it: `tests/qa_soak.gd`, `tests/qa_poc_code_injection.gd`, `tests/qa_poc_gzip_hang.gd`, `tests/qa_poc_disk_full.gd`.
`test_save_robust` prints known open bugs as `KNOWN` without failing; `-- --qa-strict` makes them fail.

---

## 1. Save robustness

### S1. CRITICAL: a pasted save code runs arbitrary code
Repro: `./tools/godot.sh --path . --headless -s res://tests/qa_poc_code_injection.gd -- --mode=object` prints
`VULNERABLE: pasted code executed script`. Expected: a code is data. Actual: `Progress._decode_code` hands the decompressed text to
`ConfigFile.parse`, and ConfigFile values may be `Object(Node,"script":Object(GDScript,"script/source":"..."))`; the script's `_init()` runs
during parsing, before the epoch check, even from `is_old_code`, which the SAVE CODE panel calls on every paste. A 227-character code does it.
Anyone who shares a "save code" on itch comments / Discord can run anything the player's user can (`OS.execute`; on the web
`JavaScriptBridge.eval`). The same hole exists for `save.cfg` itself (`load_progress` -> `ConfigFile.load`) and is expected to survive export
(exported scripts are tokens, but an embedded `script/source` is compiled at run time; the PoC was run from the editor binary, not from an export).
File: `scripts/progress.gd:709` (`_decode_code`) and `:396-397` (`load_progress`).
Fix (verified in a scratch script against all PoCs): never parse untrusted text before a guard. A real save contains no `Object`,
and nesting depth is at most 2 (arrays of strings/ints, Color). Guard used by `test_save_robust._safe_text`:
reject text containing `Object`, longer than 1 MiB, or with bracket depth above 8 (outside strings, reset at newlines). Read the file
with `FileAccess.get_as_text`, guard it, then `ConfigFile.parse`, instead of `ConfigFile.load`.

### S10. HIGH: a code that is a gzip stream plus ANY trailing bytes hangs the game (100% CPU, forever)
Repro: `./tools/godot.sh --path . --headless -s res://tests/qa_poc_gzip_hang.gd -- --extra=1` prints "calling is_old_code ..." and never
returns (`--extra=0` returns). Expected: THAT CODE DOESN'T WORK. Actual: `PackedByteArray.decompress_dynamic(..., COMPRESSION_GZIP)` (and
DEFLATE) loops forever when bytes follow the end of the stream. Natural triggers: the code pasted twice with no `=` padding in the middle,
a few stray `AAAA` after it, any hostile code. It happens inside `is_old_code` while pasting, so a player cannot even cancel. On the
web it freezes the tab. File: `scripts/progress.gd:708`. ZSTD does not hang; `decompress(isize, GZIP)` with `isize` read from the last 4
bytes does not hang either (fix in S1's scratch: read ISIZE, require 1..1 MiB, `decompress(isize, GZIP)`, require the output size to equal it).
(Found by my own fuzzer hanging at iteration 514; my fuzz now avoids that construction.)

### S11. HIGH: a short code with deeply nested `[` crashes the process (SIGSEGV, exit 139)
Repro: `... qa_poc_code_injection.gd -- --mode=nest` (a 615-character code decompresses to 200,000 nested brackets; depth 10,000 is
fine, 100,000 crashes). `ConfigFile.parse` recurses without a limit. Pasted into SETTINGS > SAVE CODE the game dies. A `save.cfg` with
the same text would crash on every launch (crash loop; the player must find and delete the file). Same fix as S1 (depth guard).

### S2. MEDIUM: the first save after an unreadable save.cfg overwrites it, with no way back
Repro: put `[meta]\nepoch=1\n[progress]\nlevels_cleared=5\n[wallet\nglobs=4\n` (a typo) in the save, launch: it boots as a fresh game
(verified with a real player launch under a fake HOME: alive, no crash, file unchanged by boot), then the first coin / level clear
writes a new save over it. Expected: the unreadable file is kept (e.g. renamed `save.cfg.corrupt-<time>`) and the player told.
Actual: nothing kept, nothing said. Also true for a save truncated by a crash, and an old-epoch file (that one is by policy).
Files: `scripts/progress.gd:395-405` (`load_progress` returns silently), `:601-604` (`save_progress`). Check: `test_save_robust` ("a backup ...
exists next to it", KNOWN).

### S9. MEDIUM: saves are written in place (non-atomic); a failed write leaves a truncated save, errors are ignored
Repro: `(ulimit -f 1; trap '' XFSZ; ./tools/godot.sh --path . --headless -s res://tests/qa_poc_disk_full.gd)`: the 56-byte save becomes a
512-byte prefix of the new one (cut mid-file, later sections gone) and the game does not notice. Disk full, quota, power loss, kill
during write all do this. A read-only user dir is silent too: no crash, old save intact, but the player is never told progress is not saved
(`test_save_robust` "read-only dir"). Fix: `ConfigFile.save(path + ".tmp")`, check the result, keep `save.cfg.bak`, then rename.
File: `scripts/progress.gd:604` (`_write().save(save_path)` ignores the returned Error).
Two game instances: last writer wins and each writes its whole in-memory state, so progress from the first window is silently lost
(by construction; not run with two real windows).

### S3. MEDIUM: one randomizer win under a wrong (future) system clock locks ticket payouts until that date
Repro (`test_save_robust` `_clock`): `day_override` = today + 70 years, win once, set the clock back. `complete_random` stores the future
day in `random_pay_day`; `utc_day() > random_pay_day` can then never be true, so after 5 more paying wins `random_payout` returns 0 until
the real date reaches the stored day. Expected: a future day is treated as corrupt. A save code carries the value, and a hostile save with
`random_day = INT64_MAX` is permanent (S3b). Moving the clock back is correctly still capped; forward 3 years resets the cap correctly.
File: `scripts/progress.gd:849-852`, `:890-896`, `_read_wallet:504`. Fix: clamp `random_pay_day` to `<= utc_day()` on read and when paying.

### Low
- S4: `[records] level_N = 0.0` (hand-made) is accepted and can never be beaten; negative / 1e-9 values likewise (`progress.gd:_read` records loop).
- S6: `[controls]` values are not validated: `jump=0` leaves the jump action with no key, two actions can share one key (fixable in the controls page). `progress.gd:_read` bindings loop.
- S7: gzip CRC is not checked: 580 of ~2,000 multi-bit-flipped codes still decode to a different valid save (single-character typos never did: 0 of ~2,000). Copy/paste is safe.
- S8: console noise: `_is_this_epoch` calls `file.get_value("meta","epoch", null)`, which logs an engine ERROR "no default was given" for every epoch-less / empty save at boot (`progress.gd:690`); corrupt files / codes log ConfigFile parse errors, "Decompression failed", "Unicode parsing error". About 18,000 such messages during the code fuzz. No crash.
- A code mangled by a chat app (non-breaking space, zero-width space, trailing period, quotes, markdown fence) is refused with THAT CODE DOESN'T WORK; plain spaces / newlines / tabs are accepted. `_clean_code` could also strip ` `, `​` and wrapping quotes.
- A save from the future (version 99, same epoch) loads and is rewritten as version 5, dropping unknown sections (downgrade eats data). Another epoch starts fresh by design.
- `buy_upgrade` accepts the dev-only `power` and any unknown id outside dev mode (E3, `progress.gd:1082`; not UI reachable).
- E1 `'+5'` is a valid typed seed but `'5-+1'` is not; E2 a 20-digit typed seed logs an engine ERROR (`to_int` overflow) then is refused correctly.

### What held up (all in `tests/test_save_robust.gd`, no engine/script errors)
Empty, 1-byte, NUL, whitespace, BOM, CRLF, invalid UTF-8, sections-only, lone brackets, unterminated strings, 5 MB text, 5 MB random bytes,
64 KB random bytes, 100 truncated / byte-flipped saves: every one boots to a sane state (all values inside documented ranges) and the load never
modifies the file. A hostile value (29 types incl. NaN, +-INF, INT64 limits, 1e308, 20 KB strings, nested arrays, dictionaries, Color, Vector2,
PackedByteArray) in every key of a real save, through both `_read` and a real file: 1,160 cases, 0 out of range. A 300,000-entry coin list reads in
18 ms and coins stay capped. Versions/epochs matrix (50 combinations) correct. 6,000 random Progress operations with 150 save-file and save-code round
trips: states in range and round trips exact. Missing user dir and read-only user dir: no crash. 20,000 mutated codes (flipped
chars/bits, SLIME1/2/3, `slime2-`, fullwidth digits, BOM, zero-width, 200 KB strings, other compression modes, zip bombs up to 4 MB): 0 partially applied,
slowest 4 ms, none loaded wrongly except valid ones. Boots with a fake `HOME` (plain launch): no save, empty, 100 KB random, 60 MB base64,
typo, version-3, epoch-7 version-99, read-only user dir (logs cannot be written, game runs), missing Library: all alive after 9 s.
Daily cap: 5 paying wins then 0; clock back stays capped; next day pays; +3 years resets.

## 2. Soak and leaks (`tests/qa_soak.gd`, headless, `--fixed-fps 60`)
Default (300 story starts incl. hard mode with wins / dry-ups / 3x restarts / hub trips, 100 randomizer mazes at MORE SLIME 0-7 with restarts and
wins, 100 map-table visits, 100 skin+hat screen visits, 60 each of hub / upgrades / level select / settings), 25 s: 0 engine errors;
nodes 186 -> 186, orphans 0, resources flat (99-109), objects flat. A 1,500-start + 400-maze run (96 s): nodes/orphans/resources flat; static
memory 38.6 -> 51.5 MB and RSS 158 -> 200 MB over 1,400 starts, rising in steps (M1, about 9 KB / start; harmless for a session, worth a glance
if someone restarts 5,000 times). Autoplay full campaign x3 (`--autoplay --speed=8 --autoplay-hold=0.05 --autoplay-quit`): 14.14 / 14.08 /
14.19 s, identical results (165/165 coins, 30/30 + 30/30 medals, 41 runs, 0 dry-ups, game time 1711 s), max RSS 191.5 / 190.3 / 193.1 MB, peak
footprint 78.0 / 76.5 / 80.0 MB: no drift. Nav fuzzer, 24 new seeds (9001-9006, 9011-9016, 9021-9026, 9031-9036, `--nav-only=walks`, 1,200
inputs each) plus touch and `--web-ui` variants: 0 new violations, 0 engine errors.

## 3. Extremes (`tests/test_extremes.gd`, all pass)
- Time-scale spikes: `Engine.time_scale` 60 (1 s physics steps) and 300 (5 s steps) with held directions + leaps on levels 1, 6, 10, one direct
  `_physics_process(5.0)`, an idle slime at scale 300: never inside a wall tile or outside the maze, no false win, no false dry-up, meter untouched
  while idle, no record written, run_time is the sum of the deltas (a real hitch is capped by the engine's 8 steps, no wall clock is used in play).
  Observation: at scale 300 `run_time` jumps 5 s per frame (595 s after 119 frames), so a hitch that the engine delivers as one big step *would*
  count toward the record time; Godot normally clamps it, the `--autoplay` speed code already keeps ticks at 1/60 s.
- Same tick: win + dry-up (goal first / dry first / both in one step): exactly one outcome and progress never goes backwards; three goal contacts in one frame: one record,
  medals once; coin + dry-up: coin counted once and not again after the restart; R on the win frame replays the level (R after a win = REPLAY, by design); five fast dry-up/retry
  cycles count 5; a ticket touched during the wipe pays once and lands in the hub; 200 Esc/P presses end with menu and tree pause agreeing; the chalice touched while paused wins only after resume; R x30
  leaves one scene.
- 32 setting combinations (Reduce Motion x fog x volume 0/1 x sound x jelly, story and hard) render; 12 fullscreen toggles; resize storm (100x100, 1x1, 4000x3000,
  8192x8192, 3000x100, 7x4000, 40 random sizes) on a level and on 8 menu scenes: no errors.
- 50 skin x hat x jelly/solid level renders (all skins incl. custom, rainbow, stopwatch; all 11 hats + none), the skins screen with each hat, stopwatch locked
  (select refused) and unlocked, unknown skin / hat ids still start a level.
- Seeds: 27 typed-seed strings incl. 0, -3, -1, `12345-99`, huge, junk, `1e3`, `0x10`, fullwidth digits (all refused except E1/E2 above);
  6 edge seeds x MORE SLIME 0/5/10 + hard: all mazes completable and replays identical.
- Economy: exactly enough / one short upgrade purchases, 50 + 100 purchase and refund spams (no negative balance or level), ticket clamps at 0 and 99,999
  (INT64_MAX add), wheel with exactly enough tickets, 1 short, all hats won, spin cost at INT64_MAX spins, spin on the frame of a scene change (charged
  once, hat kept), spin spam while spinning (charged once).
Not covered here: story intro / finale skip spam and tutorial cues (the nav fuzzer covers them), a real 5 s OS-level frame hitch, a real clock change
(only `day_override` and the stored day were driven), two real windows.

## 4. Native exports

| Preset | Result |
|---|---|
| Windows Desktop -> `/private/tmp/claude-501/qa/exp/win/SlimeTime.exe` | exit 0, no errors or warnings, 114 MB (embedded pck, x86_64) |
| Web -> `/private/tmp/claude-501/qa/exp/web/index.html` | exit 0, no errors or warnings; pck 5.0 MB, wasm 39.5 MB (note: another agent is changing the Web preset / shell concurrently) |
| macOS | **no preset in `export_presets.cfg`** (not edited). Scratch build below |

Pack contents (484 files from the export log): no `tests/`, `tools/`, `docs/`, `.claude/`, `build/`, `.screens`, `.md`, `.py`, `.sh`; scripts ship as tokens
(`script_export_mode=2`). Runtime check of the exported macOS app (`Slime Time.app/Contents/MacOS/Slime Time --headless --quit-after 60`, plain, with `foo --bar=1 -- --zzz --level=99`,
and `-- --unlock-all --level=10`): boots, no output, exit 0; only `logs/` is written under `SlimeTime_R1`, no `dev_attempts*.log`, no save created.

**X1 (medium, polish):** the Windows preset has `application/icon=""`, `modify_resources=false`: the exe carries the default Godot icon and no product / company / version
resources (cross-exporting from macOS needs `rcedit` + Wine for that; otherwise ship the desktop build as a zip with a note, or export on Windows).
**X2 (low):** none of the debug launch flags are gated by `OS.is_debug_build()`; in a release build `-- --unlock-all`, `--story-complete`, `--level=N`, `--hat=`, `--coins=`
still work from a command line (cheats only, never saved, not reachable on the web by a player).
**X3 (info):** the Web export is cross-origin-isolation independent (`thread_support=false`), good for itch.

### Proposed macOS preset (review; not applied)
Appended as `[preset.2]` to a scratch copy of the project and exported to a universal `.app` zip, ad-hoc signed
(`codesign -dv`: `Signature=adhoc`, `Format=app bundle with Mach-O universal (x86_64 arm64)`, `--verify --deep --strict` clean), 64 MB zip / 181 MB app:
```
[preset.2]

name="macOS"
platform="macOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*, .claude/*, build/*, assets/sprites/walls.png, assets/sprites/fillets.png, assets/ui/button_*.png"
export_path="build/macos/SlimeTime.zip"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.2.options]

export/distribution_type=0
binary_format/architecture="universal"
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
application/icon="res://icon.png"
application/icon_interpolation=4
application/bundle_identifier="com.slimetime.game"      ; owner: use a reverse-DNS id you control
application/signature=""
application/app_category="Games"
application/short_version="1.0.0"
application/version="1.0.0"
application/copyright=""
application/min_macos_version_x86_64="10.13"
application/min_macos_version_arm64="11.00"
display/high_res=true
codesign/codesign=3                                      ; ad-hoc (no Developer ID); verified clean
codesign/installer_identity=""
codesign/apple_team_id=""
codesign/identity=""
codesign/entitlements/custom_file=""
codesign/entitlements/allow_jit_code_execution=false
codesign/entitlements/allow_unsigned_executable_memory=false
codesign/entitlements/allow_dyld_environment_variables=false
codesign/entitlements/disable_library_validation=false
codesign/entitlements/audio_input=false
codesign/entitlements/camera=false
codesign/entitlements/location=false
codesign/entitlements/address_book=false
codesign/entitlements/calendars=false
codesign/entitlements/photos_library=false
codesign/entitlements/apple_events=false
codesign/entitlements/debugging=false
codesign/entitlements/app_sandbox/enabled=false
codesign/custom_options=PackedStringArray()
notarization/notarization=0
ssh_remote_deploy/enabled=false
```
(The scratch run also had all the `privacy/*_usage_description` keys left empty / false; Godot supplies defaults, and the game uses no mic/camera/location.)
**Required project change for the arm64 slice:** `project.godot [rendering] textures/vram_compression/import_etc2_astc=true`; without it the export fails with
"Cannot export for universal or arm64 if ETC2 ASTC texture format is disabled". That setting adds ETC2/ASTC imports (more import time, a larger pck); the scratch
export pck still fit the sizes above. Notes for the owner: ad-hoc / unsigned apps need right-click > Open (Gatekeeper) or `xattr -dr com.apple.quarantine` for itch
downloads; there are no entitlements to request (no JIT, no sandbox, no hardened runtime); real notarization needs an Apple Developer ID ($99/yr) and
`notarization/notarization=1` plus `codesign/identity`. Per-user data goes to `~/Library/Application Support/SlimeTime_R1` (unchanged by the preset).

## 5. Android / iOS notes
No native exports exist (the templates for both are installed; no presets). Mobile players use the web build. Checked in tests: `test_touch.gd` passes, nav fuzzer
`--nav-variant=touch` and `--nav-variant=web` pass (touch controls, `--web-ui`: no quit hatch). Real-device checks that remain (cannot be done headless):
Safari iOS / Chrome Android: touch joystick + leap tap latency and multi-touch, rotate hint in portrait, address-bar resize / 100vh, audio unlock on first tap, IndexedDB
save persistence after the tab is killed and after "clear site data", private-browsing storage failure behaviour (S2/S9 apply: silent), save code paste via the browser path, fullscreen API on iOS
(unsupported), low-end GPU frame time of the fog shaders, battery / thermal after 10 minutes, hardware back button, safe-area insets (notch), and a 4:3 tablet. A native
Android / iOS export would also need `import_etc2_astc=true`, keystore / provisioning, and an icon set.

## 6. Test suite
`./tools/test_all.sh 2>&1 | tail -15`, run at the end (other agents were editing `scripts/ui/controls.gd`, `rotate_hint.gd`, `tests/test_save_code.gd`, `tests/test_touch.gd`, `export_presets.cfg` at the same time): `suites: 57 failed: 0` (55 existing + `test_save_robust`, `test_extremes`).
