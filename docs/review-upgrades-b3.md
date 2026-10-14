# Review: upgrades v2 batch 3 (Descent), 64882d4..6d2db3b (excluding docs/)

Read-only review against docs/design/upgrades-v2.md C2 and docs/level-design.md section 9. Most severe first.

1. **scripts/game.gd:1465 (`_arm_survey`) + 1503 (`_commit_survey`): Descent floors overwrite story level 1's map.** `_survey_live` excludes only `is_random()`, and a Descent floor has `level == 0`. So every floor end (clear, dry-up, quit, and `_exit_tree` on DESCEND's reload) calls `record_survey(0, false, ...)`. `Progress.survey_key` clamps 0 to 1, `Survey.fits` fails on the Descent maze, and `maps[1]` is replaced by a blank survey of that floor and saved.
   - **What breaks:** a player who has mapped level 1 (seen tiles, best route, clear time) plays one Descent floor and their level-1 map is wiped. It is wiped again on every floor, and each floor also does an extra save write.
   - **Why tests miss it:** test_descent spawns games that are not `current_scene`, so `_survey_live` is false there.
   - **Fix:** add `and not descent` to `_arm_survey`. As a guard, make `record_survey` ignore `level < 1`.

2. **scripts/descent.gd:203-207 (`splat_factor`): RUBBER BODY cancels GLASS SLIME's drawback.** RUBBER returns 0 before GLASS is checked, so with both held, splats cost nothing and GLASS becomes a free pot x1.5. Both are non-stacking and can come up in the same run.
   - **What breaks:** a run that holds both banks up to 50% more with no downside (for example, half of a 20 pot gives 10, x1.5 gives 15). That breaks the trade-off GLASS is described with in spec C2.2.
   - **Fix (owner call):** stop offering either one once the other is held (in `can_offer`), or give GLASS a drawback RUBBER does not remove.

3. **scripts/progress.gd:1524-1545 (`end_descent`): the daily "2 paid runs" can be dodged by abandoning runs.** A slot is used only when a run banks something at its end. Closing the window or tab mid-run banks nothing and uses no slot (as does a quit with pot <= 1).
   - **What breaks:** a player can drop any run that is going badly (Alt-F4 before it dries up or cashes out) and keep both slots for strong runs. This pushes the daily take toward the 60 ceiling. Spec C2.3's exploit check says "quitting early only loses", but here quitting also keeps the slot.
   - **Fix (design):** use the slot when floor 1 is first cleared and keep an "open run" flag in `[descent]`, so the next launch banks it as a dry-up. Or accept it and say so in level-design.md section 9 ("a slot is used only by a run that banks").

4. **scripts/game.gd:1879-1881 (`_finish`): a dev-toggled Descent clear calls `complete_level(0)`.** The guard `not is_random() and (assisted or dev_toggled)` doesn't exclude Descent.
   - **What breaks:** `current_level` resets to 1 (the hub's CONTINUE level). If the HARD MODE setting is on, 0 is added to `hard_cleared`. Then it saves. This is dev mode only, so it hits the throwaway save, but the in-session state is wrong.
   - **Fix:** use `not is_random() and not descent and (...)`.

5. **scripts/game.gd:1635 (`cash_out`) and 1655 (`quit_descent`, won branch): dev toggles switched on during the boon card are ignored.** Both call `end_descent(true)` without `dev_toggled`. The floor's toggles were folded into the run when the floor was cleared, but F1/F2 (or the pause menu's dev panel) can still be switched on while the card is open.
   - **What breaks:** the run is paid while the HUD pot pod says NO TICKETS. Dev mode only.
   - **Fix:** pass `dev_toggled` in both calls.

6. **scripts/game.gd:1623-1640 (`descend_with` / `cash_out`) and :331-334 (`_ready`): pressing DESCEND and CASH OUT in the same frame soft-locks the run.** This takes a two-finger tap, or a mouse click plus a key. `descend` moves the run down a floor and queues a reload. `cash_out` then ends the run. The reloaded scene sees a non-empty `descent_run` and plays the new floor of an ended run.
   - **What breaks:** clearing that floor adds nothing to the pot, DESCEND does nothing, and CASH OUT only shows the old summary.
   - **Fix:** in `_ready`, require `descent_active()` (else go to the hub), and/or disable the card's buttons after the first press.

7. **scripts/descent.gd:189-190 + economy.gd BOONS.greedy (max 2): GREEDY GOO x2 makes deep floors unclearable.** Capacity is 0.80 of the base meter, while u reaches 0.80-0.85 from floor 11 (jitter) and on every floor from 12. Those floors need 100-106% of a full meter, and a floor is entered with carry plus only 35% refill.
   - **What breaks:** such floors can't be cleared on the route alone, only with both drops and/or SECOND WIND or a BLADDER. Section 9's solvability note ("every floor entered with more meter than its perfect run needs is cleared") doesn't mention this.
   - **Fix:** document it as the trade-off, or cap GREEDY at 1 stack (capacity 0.90 >= 0.85).

8. **scripts/game.gd:1582 (`_refresh_descent_pod`): the pot pod contradicts the summary.** The pod keeps calling `descent_payout` every frame after the run has ended. Once the day's second paid run banks, the pod behind the summary flips to "PRACTICE" (dim) while the summary says "+N TICKETS".
   - **Fix:** stop refreshing when `descent_run.ended`, or show `result.cap`.

## Checked and found fine

- Pot cap with GLASS (clamped to 30 after x1.5) works.
- Banking twice is blocked by `descent_active()`, and `clear_descent_floor` and `descend` are guarded.
- Milestones pay once (bitmask saved on reach), never on a dev-toggled run, and are not repeatable via RESET (which zeroes tickets).
- ABYSS is dropped on load unless its floor or milestone backs it. A hand-made save code can still claim it, the same as tickets.
- Floor seeds fit in 31 bits. Offers are seeded and R / RESTART / seed box are disabled in Descent, so offers can't be rerolled.
- SECOND WIND fires once per run (`wind_used`). Carry-over and capacity maths match the spec. Boon stacks are capped, so no negative or overflowing values.
- `descent_run` is cleared by load and reset. Every route into the game scene sets `mode`.
- Per-floor reload leaks nothing: the one-shot `process_frame` connection is cleaned up and the strip's children are freed.

## Status (2026-10-15, gameplay-dev): all 8 fixed, each with a regression test in `tests/test_descent.gd`

1. **Fixed.** `_arm_survey` excludes `descent`; `record_survey`, `record_clear` and `complete_level` ignore level < 1.
   Audited the other per-level side effects (records, medals, coins, tutorial cues, story flags, current level,
   unlocks, first-run skin, assist, dry-up count, heat): all were already skipped for Descent. Test
   `_story_untouched` plays a full run (clear floor 1, DESCEND via the card = a real `reload_current_scene`,
   dry-up on floor 2) with the game as `current_scene`, and checks every saved key outside [descent] / [wallet] is
   byte-identical (level 1 survey included). It fails on the old code (5 checks).
2. **Fixed** (owner-call option 1): `BOONS.rubber/glass.excludes`, `Descent.can_offer` never offers one while the
   other is held. Documented in economy.gd, level-design.md section 9 and spec C2.2.
3. **Fixed** (design option 1, without the open-run flag): a run takes its paid slot when it first clears floor 1,
   saved at once (`Progress._take_descent_slot`); it banks into that slot later (even after midnight, even with a
   pot that banks 0). A dry-up / quit on floor 1 takes none; a dev-toggled run takes none. A run with no slot left
   is PRACTICE unless a new day began by the time it banks. HUD pod and summary say PAID RUN n/2. Test `_paid_slots`.
4. **Fixed.** `_finish` skips `complete_level` for Descent (and `complete_level` ignores level 0). Test in
   `_story_untouched` (a dev-toggled floor clear keeps current_level and hard clears).
5. **Fixed.** `cash_out` / `quit_descent` pass `dev_toggled or assisted` at bank time. Test `_card_guards`.
6. **Fixed.** Both: one action per card (`_descent_acted`; `cash_out` also needs `descent_active()`), and a floor
   built for an already-banked run doesn't play: it shows the summary (NEW RUN / HUB). Test `_card_guards`.
7. **Fixed** (cap option): GREEDY GOO `max = 1` (capacity 0.90 >= u 0.85). Test in `_offers`.
8. **Fixed.** `_refresh_descent_pod` shows the banked result's cap / slot once the run has ended. Test `_card_guards`.
