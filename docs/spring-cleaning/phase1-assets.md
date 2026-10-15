# Phase 1: asset audit (asset-auditor)

## Removed (unreferenced, with .import and generator output)
| File | Bytes | Why |
|---|---|---|
| assets/sprites/walls.png, fillets.png | 15,510 + 220 | Superseded by per-theme atlases (`Themes.atlas_path`); only a comment mentioned them. Already in the export exclude list. |
| assets/ui/button_{normal,hover,pressed,disabled}.png | ~400 | Buttons are goo styleboxes (`UIKit.button_style`); never loaded. |
| assets/ui/panel.png | 113 | Never loaded; **was shipped in the pck** (not excluded). |

`tools/make_placeholder_art.py` and `tools/make_ui_art.py` no longer write them (BUTTONS/PANEL data removed; wall/fillet drawing functions kept, `make_theme_art.py` imports them).
Everything else is referenced: sounds via `Sfx` / `ambient_<theme>[_n].wav` string paths, theme atlases via `Themes.atlas_path`, hub art via `ART + name`, ui icons via `UIKit.make_icon`. Nothing needed `_archive/` (not created).

## Generators in sync
All generators were rerun into a temp copy and diffed. Every PNG is **pixel-identical**; WAVs and icon.png/icon.ico are byte-identical. `make_theme_art.py --check` (40 atlases) and `make_hats.py --check` pass. The earlier icon_lock.png "drift" is byte-only: PNG bytes depend on the local zlib build (many PNGs differ in size by a few bytes when regenerated on this Mac), so do not commit regenerated PNGs unless pixels changed. Only the two `--check` modes exist; the other generators have none (checks compare pixels, not bytes).

## Optimization
- Source PNGs total ~0.7 MB; Godot ships the lossless `.ctex` imports, so re-compressing sources would not shrink the pck and risks churn. Not done. Import settings verified: textures lossless, no mipmaps; audio QOA (mode 2), untouched.
- Export: `icon.ico` (100,907 bytes, only used at Windows export time) excluded from the **Web** preset; stale exclude entries replaced by `_archive/*` in all presets.
- Web pck: **5,293,612 -> 5,192,064 bytes (-101,548)**. pck holds only res://scripts, scenes, assets, .godot/imported, icon.png: no tests/tools/docs/_archive. Engine wasm unchanged (39,514,754).

## docs/polish-shots
Tracked 335 images before; **256 deleted** (15.8 MB), 80 kept (6.1 MB): everything named by living docs (abilities*, finale2_*, hard_before_l1*, size_u100_ms0*, spawn_level*, story3_*, ticketgoal_goal, abilities2_before) plus the latest looks (border_after_*, phase2_after_l*, brightness*). Deleted: superseded before/after sets, attempts_*, usage_*, upgrades*, touchhint_*, tickets_*, story_intro/finale/banner, etc. (`git show <commit>^:docs/polish-shots/<file>`). Added between commits 6c94f32 (2026-10-12) and b4bf685 (2026-10-15); recover with `git log --diff-filter=D --name-only -- docs/polish-shots`.
Archived docs that mention deleted names (text only, no embeds): docs/archive/handoff-history.md (43), docs/archive/advisor/graphics-shading.md (1). No living doc broken.
Untracked, git-ignored, **not deleted** (irrecoverable): descent_demo.mp4 29.6 MB, story_intro.mp4 6.0 MB, story_finale.mp4 1.0 MB: owner decides.

## Repo weight / owner decisions
.git is 74 MB on disk (pack ~25 MiB at baseline); the deleted screenshots stay in history. Rewriting history to purge docs/polish-shots is the owner's call; not done.
Marketing: no stale promo images are committed (`/itch-images/` is git-ignored and absent); `tools/promo/*` (cover, jump_shot, make_promo.ps1) kept untouched.
Decisions: delete the local mp4s? purge history? Wavs: ambient beds 1 MB each are source WAVs (shipped as QOA); fine.
