# Review: upgrades v2 batch 1 (bc98bd1..fc9f64d, docs excluded)

> Archived review of upgrades v2 batch 1; superseded by the implemented spec [../design/upgrades-v2.md](../design/upgrades-v2.md) (tree 3 repricing changed the numbers).

Spec: docs/design/upgrades-v2.md (A2, D.1, D.2). This was a read-only review. No tests were run, because a batch 2 agent is working in the tree.

## Verified correct (no finding)
- **Economy table.** The costs and values match A2.1 exactly: 55 + 60 + 50 = 165. The maxima are x2.0, x1.5 and +25 px. Dev power is 4 free levels at x2.5 the old formula, so new level 4 equals old 10.
- **Migration** (`Progress._read`, `_migrate_tree`, `Upgrades.migrate_level`):
  - It maps by coins invested and rounds down. All 33 old (track, level) pairs match the spec examples.
  - It is gated on `[upgrades] tree >= 2` and runs before the "never spend more than found" loop.
  - Coins are derived, so the balance can't go negative.
  - It is idempotent, because the next write always carries tree = 2 and `load_progress` writes back any version below 6.
  - The save-code path uses the same `_read`.
  - Hostile values clamp: levels clamp to 0-10 for old saves and to the track max for new ones. `refund_notice` is clamped to [0, coins in hand].
  - Dev runs read the real save but write only the throwaway, so the real notice stays pending.
- **Buying.** `buy_upgrade` checks the max first, so `cost()` returning 0 when maxed can't be exploited. The `+` button state uses the same check.
- **Randomizer.** `random_route_cells_for` in hundredths is exactly the old sum at an equal factor. The golden file's 2,000 level-7 lines are byte-identical to the old level-10 lines after relabelling. Every level-0, hard and story line is unchanged.
- **Seed codes.** Levels 0-10 are accepted, 8-10 clamp to 7, and 11+ or malformed input gives ZERO.
- **Other spec points.**
  - The no-MORE-SLIME ticket cap is unchanged.
  - Par is taken before `_apply_upgrades`, so it doesn't depend on speed.
  - Reveal and relight both use `TRAIL_RADIUS` / `LIGHT_RADIUS` + `light_reach`. These equal the Economy radii, and the test asserts it.
  - The autoplay planner uses `cost(id, level)` and `max_level(id)`.
  - No code under scripts/ still uses `MAX_LEVEL` or an old multiplier formula.

## Findings (most severe first; none blocks shipping)

1. **scripts/ui/upgrades_screen.gd:107-121: two A2 screen items are missing.**
   - Problem: A2.3 asks for a dim RECOMMENDED tag on MORE SLIME until it is maxed. The spec calls skipping MORE SLIME "the model's biggest risk for normal mode". A2.2 asks for a 1 s light ring at the new radius when BRIGHTNESS is bought. Neither is built.
   - Failure: a new player can put the first 8-12 coins into SPEED or BRIGHTNESS and hit the L5/L8 allowance dips (-6/-7%) the model warns about. Nothing on the screen steers them.
   - Fix: add the dim tag to the slime row while `level < max_level("slime")`, and add the one-shot ring preview in `_change` for brightness. Or explicitly move both items to a later batch in the spec.

2. **tests/test_random_usage.gd:116, 174, 224; tests/test_extremes.gd:511; tests/test_tickets.gd:82; tests/test_border.gd:59: tests still pass old levels (10, or speed 5) and rely on clamping.**
   - Problem: these tests pass, but they no longer test what their labels say. `_game(s, 10, 10)` puts `progress.random_level = 10` straight into `game.seed_level`, which is not clamped (game.gd:304; only `parse_seed_code` clamps). The maze is built at 7, but the HUD and attempt-key paths see a 10 that production can never produce. "MORE SLIME 0/5/10" now means factors 1.0/1.75/2.0. Level 4 (x1.60), the new mid-golden level, gets no real-maze or autopilot usage coverage.
   - Fix: change the lists to [0, 4, 7] and the pairs to `..., 7]`, use `random_route_cells(s, false, 7)` (the pinned values stay the same), use speed 4, and use `light_reach(3)`. Optionally clamp `seed_level` in game.gd:304 with `Levels.max_slime_level()` as a safety net.

3. **tests/bench_random_size.gd:16-17: the benchmark still uses the old size floor and levels.**
   - Problem: it loops over [0, 5, 10] and computes the floor as `sqrt(1 + 0.1 x level)`. `random_config` now clamps 10 to 7, and level 5 means x1.75, not x1.5.
   - Failure: the "share under the size floor" at L5 is measured against a smaller floor than the real one (19x11 instead of 24x13), so it under-reports.
   - Fix: use `Levels.random_floor_cells(level)` and loop over [0, 4, 7].

4. **CLAUDE.md:22 (levels.gd bullet): a stale description.**
   - Problem: it still says `random_cells` grows by "sqrt(1 + 0.1 x level)". The code now uses `sqrt(Upgrades.slime_factor(L))`.
   - Fix: update the wording. The coins + upgrades bullet was already updated.

No correctness bugs found in migration, buying, the economy, seed codes, the randomizer, brightness or par.

## Status (fix pass 2026-10-15)

All four findings fixed.
1. RECOMMENDED tag on MORE SLIME until maxed; BRIGHTNESS buy shows a 1 s old-vs-new light-radius preview (disc and ring, to scale) in the hint area (`test_upgrades_v2`; shots `docs/polish-shots/fixes_b12_*.png`).
2. Tests use the real top levels (7 / 4 / 3 / speed 4); `game.seed_level` is clamped to 0-7; `test_random_usage` builds real mazes and runs the autopilot at MORE SLIME 4.
3. `tests/bench_random_size.gd` uses `Levels.random_floor_cells` and levels 0 / 4 / 7.
4. CLAUDE.md levels.gd bullet corrected (growth is sqrt of the MORE SLIME factor).
