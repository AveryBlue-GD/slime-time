# Review: upgrades v2 batch 4 (HEAT), 6d2db3b..53ae1fe (excluding docs/)

Checked against docs/design/upgrades-v2.md C3 and docs/level-design.md §10. Exploit paths checked first.

## Findings (most severe first)

1. **scripts/game.gd:521-524 - RACE can still be won after the countdown reaches 0:00.** The time-out only fires while `not slime.is_airborne()`. A leap launched just before 0:00 keeps flying, and the chalice's Area2D still catches an airborne slime, so `_on_goal_body_entered` records a normal win: the RACE heat (+3), its bounty tiers, the best heat and the medal. **Failure scenario:** the HUD shows 0:00.0 in red, the slime lands on the chalice about 0.3 s later (longer with ricochets), and the clear pays as a heat-10 clear. **Fix:** latch `race_over = true` once `run_time >= race_limit`. Then either end the run in `_on_goal_body_entered` when `race_over` is set (dry up / no win), or dry up at once even mid-leap.

2. **scripts/economy.gd:89 and scripts/heat.gd:26 (`_on_jump_landed`, game.gd:1238) - THIRSTY does not scale splat penalties.** The docs say it drains faster for "gliding, leaps and splats", but `splat_penalty() * splat_factor` is a flat meter percentage that never goes through `slime_cost_per_tile`. Only gliding and leap distance pay the x1.08. **Failure scenario:** the player reads "SLIME DRAINS 8% FASTER", but a splat costs the same with or without THIRSTY. The winnability math in level-design §10 is not affected, because a walk has no splats. **Fix:** multiply the splat penalty by `heat_fx.drain`, or drop "and splats" from the comment.

3. **scripts/hud.gd:454-455 with scripts/heat.gd:208 - the RACE hourglass breaks the timer pod's centering.** The clock icon is 8x8 and the code-drawn hourglass is 9x9. The pod's comment at hud.gd:181 says "an even-width pod sits exactly on center", and swapping the icon makes the content 9+3+37 = 49 px wide, an odd number. **Failure scenario:** in every RACE run the timer pod sits 1 px (0.5 px rounded) off the screen center. Its height may also grow by 1 px. No audit or test covers RACE. **Fix:** draw the hourglass as an 8x8 grid (or pad it into an 8-px-wide cell), or set `_clock_icon.custom_minimum_size` so the width stays even.

4. **tests/test_level_tiles.gd (new Flame branch, `rect.end.y + 3.0 <= ink.position.y + 14.0`) - the "flame inside the tile" check passes for the wrong reason.** It compares the flame's bottom with the number's ink bottom plus 14, not with the tile. It never checks the right or bottom edges, and vertical clearance from the digits is never tested; only x-clearance is. Today's layout is fine: the flame covers rows 5-13 and the digits start at row 14. **Failure scenario:** moving FLAME_POS down onto the digits, or out of the tile, would still pass. **Fix:** check `Rect2(Vector2(3,3), tile.size - Vector2(6,6)).encloses(rect)` and `rect.end.y + 1 <= ink.position.y` (or else the x test).

## Checked and found sound

- **Bounty farming:**
  - `complete_heat` runs only when `heat > 0 and not no_record` (assist or F1/F2). It runs before `record_clear`, which saves in the same frame, so quitting on the win frame loses nothing and gains nothing.
  - The heat mask is fixed at `_ready` (`heat_for_run` needs the plain hard clear), and HEAT can't change mid-run: the panel is only on the level select.
  - A RACE time-out goes through `_dry_up`, never a win (apart from finding 1).
  - Every debug flag (`--heat`, `--heat-best`, `--unlock-all`, `--story-complete`, autoplay) turns saving off.
  - Hostile saves and save codes clamp `heat_best` to 0-10 and drop it for levels with no hard clear. `paid` is stats only, and tickets are never derived from it.
  - `reset_progress` also clears tickets.
- **EMBER:** shop and gacha filter out `earned` items. On load it is dropped unless every level is at heat 7 or more (`_read_heat` runs before `_read_store`, after `hard_cleared`).
- **BRITTLE + GROUNDED:** enforced by `sanitize` on toggle, load, the `--heat` flag and `effects()`. The toggle is disabled in the panel.
- **No leaks:** normal mode, the randomizer, Descent (`hard_mode` false), story-complete and autoplay (clean state, mask 0) all play without heat. `_apply_heat` resets every field to neutral when the mask is 0.
- **THIRSTY and the workshop:** `workshop_level` is 0 in hard mode, and `_apply_workshop` runs before `_apply_heat`, so `splat_factor` composes correctly.
- **Fog:** DIM and FOG BITES match between the CPU (`fog_alpha_at`) and the shader (`refog_after`, `fade_after`). The outer fog copies `light_inner` and `refog_after`, and FULL BRIGHT and fog brightness interplay is unaffected. Lazy relight ticks were re-derived for DIM (0.275 s margin). No shader arrays are indexed at run time.
- **Level select:** the flame (5..11 x 5..13) clears the digits, pips and status. Esc closes the panel before leaving the screen. Focus lock/unlock and click-outside work. HEAT is hidden in normal mode. The HUD heat pod sits at row 2 in hard mode (no coin pod), so it doesn't overlap the touch pause button at y 35.

## Status (2026-10-15): all 4 findings fixed

1. **RACE race: fixed.** `game.gd` latches `race_over` once the countdown hits 0:00. A grounded slime dries up at once (OUT OF TIME!); one still airborne dries up when it lands, and `_on_goal_body_entered` refuses the win (dry-up, no bounty, no best heat, no record) if the limit has passed. Test: `test_heat.gd` "RACE: the chalice after 0:00 is no win" (+ a win just inside the limit).
2. **THIRSTY splats: fixed (made true, not dropped).** `splat_factor` is now `splat x drain`, so THIRSTY scales splat penalties x1.08 (x2.16 with BRITTLE). Tests: `test_heat.gd` splat factors. `tests/bench_heat.gd` re-run, 480 runs (48 masks x 10 hard levels), 0 lost: tightest slime 7.4% left (L1, THIRSTY), tightest time 58% of the countdown (L9 mask 32). Unchanged, since a perfect walk has no splats.
3. **Hourglass: fixed.** Redrawn 8x8 (`Heat.icon("race")`), so the pod content stays even and centered. Test: the icon is 8x8 and the pod row's minimum width is even.
4. **Flame-in-tile check: fixed.** `test_level_tiles.gd` now requires `Rect2(3,3, tile.size - 6)` to enclose the flame (all four edges) plus clearance from the number's ink.
