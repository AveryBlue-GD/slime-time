# HEAT removed (2026-10-20)

The owner scrapped **HEAT** (hard mode's six optional modifiers, upgrades v2 batch 4) "for now". Players never see
it: no HEAT button or panel on the level select, no flames on hard tiles, no HEAT pod in the HUD or the hub's ticket
pod, no heat line on the result panel, no RACE countdown, no title flame crown, no EMBER trail. Hard mode itself
plays exactly as it did without HEAT (same mazes, meter, fog, par, medals, jelly skins).

The last state with HEAT is the git tag **`pre-heat-removal`** (commit 8046e5e on `spring-cleaning`).

## What was removed

Code
- `scripts/heat.gd` (`Heat`: modifier ids, masks, points, bounties, effects, code-drawn icons and flames) and
  `scripts/ui/heat_panel.gd` (`HeatPanel`, the level select's modifier toggles), with their `.uid` files.
- `scripts/economy.gd`: `HEAT_MODS`, `HEAT_MAX`, `HEAT_TIERS`, `HEAT_BOUNTY`, `HEAT_EMBER`.
- `scripts/progress.gd`: `heat_mods`, `heat_best`, `heat_paid`, `_read_heat`, the `[heat]` / `[settings] heat_mods`
  writes, `heat_unlocked`, `heat_for_run`, `set_heat_mods`, `best_heat`, `heat_total`, `heat_levels_at`,
  `complete_heat`, `heat_crown`, the `--heat=` / `--heat-best=` debug flags, the `"heat"` progress event.
- `scripts/game.gd`: `_apply_heat` and its run state (`heat`, `heat_mask`, `heat_fx`, `fade_after`, `refog_after`,
  `relight_radius`, `race_limit`, `race_over`, `slide_drains`, `heat_result`, `_lazy_ticks`), the RACE countdown and
  OUT OF TIME! dry-up, the bounty / EMBER lines of the win. The fog and light now use the constants these defaulted to
  (`FADE_AFTER`, `LIGHT_RADIUS`, `LAZY_RELIGHT_TICKS`), so the picture is unchanged.
- `scripts/hud.gd`: the HEAT pod (`set_heat`), the result's heat row (`show_heat_result`), the RACE hourglass
  (`set_countdown`, `countdown`, `RACE_LOW`, `HEAT_TINT`, `HEAT_ROW_LIFT`).
- `scripts/ui/level_select.gd`: the HEAT button and panel, the tiles' flame badge; hard mode's info line is now the
  one line the demo already used (BEAT A LEVEL ON HARD FOR ITS JELLY SKIN).
- `scripts/hub.gd`: the ticket pod's HEAT n/100. `scripts/ui/title.gd`: the flame crown.
  `scripts/ui/touch_controls.gd`: GROUNDED's struck-out JUMP (`jump_enabled`). `scripts/ui/ui_kit.gd`: `fit_icon`
  (only HEAT's 7x9 / 9x9 icons used it). `scripts/demo.gd`: `heat_open`.

The EMBER trail: **removed** (not kept as an unobtainable item). It could only be earned with HEAT 7+ on every hard
level, so nobody can get it any more. `scripts/cosmetics.gd` lost its item, colors (`EMBER*`), texts and trail look.
The wardrobe's TRAILS page has 6 tiles (ABYSS stays hidden while DESCENT is off). The EMBER *skin* (level 10's
skin) is unrelated and unchanged.

Strings (32 ctx keys, gone from `locale/messages.pot` and every `.po` via `tools/i18n_extract.py --merge`):
`heat.about_default`, `heat.done`, `heat.points`, `heat.title`, `heatmod.{dim,brittle,fog,grounded,thirsty,race}.{name,desc}`,
`hud.pod.heat`, `levels.heat`, `levels.info_hard.1`, `levels.info_hard.2`, `result.heat`, `result.heat_best`,
`result.heat_bounty`, `result.heat_new_best`, `result.out_of_time`, `trail.ember.{name,desc,unlock}`. Logged in
[i18n/pending.md](i18n/pending.md). The translations are still in the tagged `.po` files.

Tests and tools
- Deleted: `tests/test_heat.gd`, `tests/bench_heat.gd`, `tests/demo_heat.gd` / `.tscn`.
- Added: `tests/test_heat_removed.gd` (an old save with `[heat]`, `[settings] heat_mods` and an owned / worn EMBER
  trail loads cleanly, keeps its tickets and everything else, the next save drops the HEAT keys; same save version).
- HEAT cases dropped from: `test_abilities`, `test_demo`, `test_descent_off`, `test_level_tiles`, `test_platform`,
  `test_store`, `test_trails`, `test_ui_layout`, `test_nav_fuzz` / `nav_fuzz_lib` (the HEAT area walk), the i18n
  layout suites (`f2`, `f3a`, `game`, `levels`, `r1`, `r2`, `rtl`, `screens`, `fit`), `capture_i18n`,
  `demo_level_select` (`-- heat`, `-- heat-panel`).
- Docs: the living docs no longer describe HEAT; the design notes ([level-design.md](level-design.md) section 10,
  [design/upgrades-v2.md](design/upgrades-v2.md) C3) are kept and marked REMOVED. The Steam plan
  ([spring-cleaning/phase5-platform.md](spring-cleaning/phase5-platform.md)) has no HEAT achievement or progress event.

## Old saves

No save-version bump. A save written while HEAT existed may hold `[settings] heat_mods`, `[heat] level_N` / `paid`
and `"ember"` in `[cosmetics] owned` / `trail`. They are simply not read any more: the tickets the bounties paid stay
in the wallet, an owned or worn EMBER trail drops back to the default trail (the store never kept a cosmetic it
doesn't know), and the next save writes none of these keys. Save codes behave the same.
`tests/test_heat_removed.gd` checks all of it.

## Bringing it back

Either, on top of the current branch:

```bash
git revert <the HEAT removal commit(s) on cleanup-no-heat>
```

(`git log --oneline pre-heat-removal..cleanup-no-heat` lists them; the removal is one commit, "Scrap HEAT ...").
Or take single files back from the tag, e.g.:

```bash
git checkout pre-heat-removal -- scripts/heat.gd scripts/ui/heat_panel.gd tests/test_heat.gd
```

then re-add the hooks listed above (game.gd `_apply_heat`, Progress, HUD, level select, hub, title) from
`git show pre-heat-removal:<file>`, run `python3 tools/i18n_extract.py --merge` (the strings come back, untranslated
unless the `.po` files are restored from the tag too), and run the full suite. Old saves still carry their HEAT data
only until they are next saved; after that the best heats and the EMBER trail are gone for those players.
