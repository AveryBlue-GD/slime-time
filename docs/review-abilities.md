# Review: Abilities v1 (862fcbc..09df1db, excluding docs/)

Read-only review against docs/design/upgrades-v2.md "Abilities v1". Most severe first.

1. **scripts/ability_runner.gd:219-226 + scripts/slime.gd:367-370 + scripts/game.gd:1879** - A SLIMAKAZE that reaches the chalice or ticket never pays its 30%. The goal is an Area2D (`body_entered`), and the dash moves the body by setting `position` at 640 px/s, so the overlap fires before the dash reaches its target. `_finish` then freezes the slime, `_dash_step` drops it to GLIDE with no `finish_dash()`, and `dash_hit` (which is where the 30% is taken) never fires. `dashing` also stays true, so `_paint_dash` keeps running on every physics frame through the end card.
   - **Failure scenario:** with 5% left, aim SLIMAKAZE down the chalice's dead-end corridor. The dash flies free (it counts as airborne, so no drain) and wins. The spec says "<= 30% left: the impact dries the slime up". In Descent, `clear_descent_floor(slime_remaining)` saves the uncharged 30% into `run.meter`, so it carries to the next floor. This works every time, because goals sit at dead ends where a dash naturally ends.
   - **Fix:** settle the dash in `_on_goal_body_entered` when `slime.state == DASH`. Call a runner hook that pays `Abilities.slime_cost("kaze")` and clears `dashing`, then dry up instead of winning if the meter is 0. Or have the dash target stop short of the goal and let the impact come first. Add a test: SLIMAKAZE into the goal with 20% left must not win, and with 60% left must win with 30% left.

2. **scripts/ui/touch_controls.gd:29, 96-100 (+ tests/test_abilities.gd:377-379)** - On touch, the ability buttons take touches that used to count as JUMP. The JUMP zone is the whole right half (`elif _jump_touch == -1` at line 113), not its drawn 19 px circle. Each ability's hit disc (r 13, 1 px from the JUMP circle) now takes priority there, and the ability fires on touch-down with no way to cancel.
   - **Failure scenario:** a thumb landing a little left of or above JUMP, where it always counted as JUMP, now fires an ability and leaves no leap. If the player owns only SLIMAKAZE, it gets slot 0 (directly left of JUMP, the most natural miss spot), so a missed leap costs a charge and 30% of the meter.
   - **Test passing for the wrong reason:** `jump_gap` measures against `JUMP_RADIUS`, not the half-screen zone JUMP actually catches.
   - **Fix:**
     - Fire on release, and only if the finger is still on the button.
     - Exclude a ring around JUMP (e.g. no ability hit within JUMP_RADIUS + 8).
     - Order slots so the cheapest ability sits nearest the thumb.
     - Test with touches at the JUMP circle's edge.

3. **scripts/game.gd:1236 (`reveal_tile`) vs 474/566** - Ability reveals light the goal's tile, but the chalice/ticket node stays `visible = false`. It only shows within `goal_reveal_distance` (24 px) of the slime.
   - **Failure scenario:** a SLIME RIFLE shot, a SLIME SPLAT burst or a SLIMAKAZE drop lands on the goal tile. The player sees an empty, lit floor tile where the goal is, which actively misleads them. `survey_goal` also stays false, so the trail map never marks a goal the player saw. The spec says these reveals are "real reveals".
   - **Fix:** in `reveal_tile`, if `tile` is the goal's tile, call `_show(goal)` and set `survey_goal = true`. If hiding the goal is intended, say so in the spec and the HUD.

4. **scripts/abilities.gd:161 + scripts/ability_runner.gd:205** - The SLIMAKAZE target snaps to the lane center across the dash direction, but the dash is a single `move_toward` from the slime's off-lane position. The sideways offset only closes in proportion along the whole dash, so it travels diagonally.
   - **Failure scenario:** the slime stands at a junction about 7 px off-lane, beside a wall corner (the open tile is behind it, the wall is diagonal-ahead). For the first one or two tiles, the body (r 7) overlaps the corner wall tile by up to about 6 px, drawn inside the wall. There is no collision because `position` is set directly. This is cosmetic only, since it ends on the lane.
   - **Fix:** snap the sideways axis first (one or two frames, or instantly), then dash straight along the lane.

5. **scripts/game.gd:708-712 vs 1310, 1852, 1874** - `shake()` sets `shake_span`, but the existing shake setters (leap landing, bumps) set only `shake_left`. If a landing or bump shake starts while an ability shake is still running, the old span is reused: `fade = min(SHAKE_TIME / 0.2, 1)` stays at 1. For example, a short hop lands within 0.2 s of a SLIME SPLAT burst, and the landing shake holds full strength instead of fading.
   - **Fix:** route those setters through `shake()`, or set `shake_span = SHAKE_TIME` in them.

6. **scripts/abilities.gd:166 + scripts/ability_runner.gd:233** - The splatter seed uses `game.attempt`, which only changes in the randomizer (game.gd:1535). In story and Descent it is always 1, so the same impact always gives the same splatter. In the randomizer, a restart re-rolls it, so a player can restart until a lucky spray reveals the goal area.
   - **Fix:** pick one rule (drop `attempt` from the seed, or count story/Descent attempts too) and update the docstring and the spec line "seeded by the maze, the attempt...".

**Checked and clean (no finding):**
- **Charges:** refill only by scene rebuild, and every path is a spec'd refill.
- **Timing guards:** abilities are blocked while paused (RestartPrompt and the pause menu pause the tree), after win or dry-up (`game.finished`), while airborne, charging or stunned, and mid-dash.
- **Dash bounds:** the dash can't leave the maze or cross a wall (the grid walk and `is_wall` treat out of bounds as wall). The diagonal snap goes along x. Rifle and splat never trigger a win or a coin.
- **Rifle and splat:** the rifle stops at the first wall. The splat's 3x3 clamps to the maze. Fog, trail and survey bytes are consistent with the existing reveal encodings.
- **Modes and costs:** hard and Heat get no runner, and the autoplay saves have no abilities. NO DRAIN skips the cost.
- **Saves:** values are clamped on read. Old saves with custom keys on 1-3 get spares in order.
- **Performance:** no per-frame spikes. The splatter is about 25 drops, and light textures are cached.
- **Nav:** the CONTROLS two-column neighbors, and the tab/confirm focus lock reuse the workshop's pattern.

## Status (2026-10-15): all six fixed

Regression tests in `tests/test_abilities.gd` (`_kaze_goal`, `_touch`, `_goal_reveals`, `_kaze_off_lane`, `_shake_spans`, `_splatter_rule`); each failed on the old code (29 checks) and passes now. Spec: docs/design/upgrades-v2.md "Abilities v1" (table and Decisions).

1. **Fixed.** `game._on_goal_body_entered` settles a dash first: `AbilityRunner.settle_at_goal()` stops it (`Slime.stop_dash`, no splat or splatter), ends the smear and pays the 30%. If the meter is then 0, it is a dry-up, not a win. A SECOND WIND or BACKUP BLADDER that fires there lands its refill at once, and the run wins (`_rescue_empty_meter`). The rule is the same in story, the randomizer and Descent; the Descent floor carries the meter after the cost. Tested at 20% and 60% in all three modes, plus the SECOND WIND case.
2. **Fixed.** Abilities fire on RELEASE, and only if the finger is still on the button (slide off = cancel; a pause or menu cancels, never fires). Each ability has its own spot, so owning only SLIMAKAZE no longer puts it next to JUMP: RIFLE (207,150) and SPLAT (207,122) sit nearest, SLIMAKAZE (181,136) farthest. With buttons shown, JUMP catches x >= 228 (full height, letterbox included, minus pause). An 8 px dead band (`DEAD_RING`) separates it from every hit disc. The test probes the real catch zone (touch down, check that `jump` is pressed) on a 2 px grid over the right half and the letterbox, and checks:
   - the gap is >= 8 px
   - every touch up to 25 px off JUMP's edge leaps
   - press, slide-off and release behave as above

   Without abilities, JUMP still catches the whole right half. Layout checked at 320x180 and on a 20:9 phone letterbox (2340x1080, 35 px bars at the base scale).
3. **Fixed.** When `game.reveal_tile` lights the goal's tile, it shows the chalice or ticket (`_show`, so FULL BRIGHT bookkeeping holds) and sets `survey_goal`, unless the run is over (a claimed ticket stays gone). Tested with a rifle and a splat in story and the randomizer, from more than `goal_reveal_distance` away.
4. **Fixed.** `Slime.dash` first slides straight sideways onto the target's lane (`_dash_lane`, at dash speed, so within a frame for a 7 px offset), then dashes along it. Tested from 6 px off-lane: there is no forward movement while off-lane.
5. **Fixed.** The landing, crumble and ricochet shakes now go through `shake()`, so each one restarts the fade over its own span. The crumble keeps the landing's kick. Tested: a wall landing or ricochet right after a SLIMAKAZE shake has span SHAKE_TIME or 0.6 x SHAKE_TIME.
6. **Fixed.** One rule in every mode: `Abilities.splatter_seed(maze_seed, impact, use)` (the maze, the impact tile and the SLIMAKAZE use index this attempt, never the attempt). Tested: attempt 1 and attempt 4 splatter the same tiles in story and the randomizer.
