# Review: upgrades v2 batch 2 (fc9f64d..9fd6383, code only)

Reviewer: code-reviewer (read-only). Scope: `git diff fc9f64d..9fd6383 -- . ':!docs'` against
docs/design/upgrades-v2.md (B.2, B.3, C.1-C.3, D.1). Line numbers are from the tree at 9fd6383.

## Findings (most severe first)

1. **scripts/game.gd:620 and :1193 (GOO NOSE reach)**
   - Problem: GOO NOSE raises the glimmer reach to 200 / 240 / 300 px, but the view is 320x180 with no zoom (±160 x ±90 around the slime). `_spawn_glimmer` picks one hidden coin at random from everything in reach, so the extra reach mostly adds coins that are off screen. A glimmer on one of them can't be seen, and it uses up that glimmer's turn.
   - Failure scenario: with coins spread evenly, the share of glimmers you can see drops from about 65% (r 160) to about 46% / 32% / 20% (r 200 / 240 / 300). Multiplied by the x1.5 / x2 / x3 rate, the visible glimmers per distance come to about 1.06x / 0.98x / 0.94x of having no GOO NOSE. So a player pays 82 tickets for an upgrade that shows no more twinkles, and level 3 shows slightly fewer.
   - Fix: keep the reach, but only pick coins whose glimmer would be on screen (inside the camera rect, plus a small margin). Or clamp the reach to the view, or treat the reach as "in view" in the spec. Add a test that counts visible glimmers per 1000 px at each level.

2. **scripts/ui/upgrades_screen.gd:173 / :208 (workshop "+")**
   - Problem: one press of "+" spends tickets that can't be refunded. There is no confirm and no "-" to undo it. Before this change, "+" on this screen could always be undone (coin levels refund). The SHOP asks once for every ticket buy (C.3), but the workshop doesn't.
   - Failure scenario: a double-click or double-tap on SECOND WIND's "+" (common on touch, and on a mouse when the first click seems not to register) buys levels 1 and 2 at once: 15 + 30 = 45 tickets, which is several days of capped randomizer income, with no way back.
   - Fix: reuse the HatWheel-style confirm (BUY QUICK CHARGE 2? 25 [ticket] BUY / BACK, focus on BACK). At the least, ignore a second press on the same row for about 0.3 s after a buy.

3. **scripts/game.gd:474-478 (SECOND WIND refill)**
   - Problem: the refill clamps to an absolute target (`minf(remaining + rate*delta, _wind_target)`), and it finishes only once `remaining >= _wind_target`. Any gliding or leap cost during the 0.4 s refill gets topped back up, so that slime is free. While refilling, a leap that lands is fully refunded too, up to the target.
   - Failure scenario: SECOND WIND 3 gives 35% plus whatever is spent during the refill window. The extra is small (around 1% of a meter from gliding; more if a short leap lands inside the window). It isn't in the randomizer calibration, which assumes exactly 15 / 25 / 35%.
   - Fix: track how much is still to add (`_wind_left = target`), add `min(rate*delta, _wind_left)` and subtract that from `_wind_left`, and end the refill when `_wind_left <= 0`. Normal drain then applies during the refill.

4. **scripts/game.gd:1258-1269 (MAGNET, solid slime)**
   - Problem: the spec (B.2) says a magnetized coin "flies into the slime (existing `dissolve_into`)". Here, with jelly off, a coin up to 34 px away just bursts where it lies (`Fx.burst` + `queue_free`).
   - Failure scenario: a solid-skin player sees a coin vanish two cells away with nothing linking it to the slime. It reads as a bug or a glitch pickup.
   - Fix: when `d > Coin.REACH`, tween the coin to the slime first (or use `dissolve_into` for both slime types), then burst.

## Checked, no issue found

- **Tickets:** `_pay` clamps at 0; every `can_*` checks price <= balance; `buy_hat`, `buy_workshop` and `buy_cosmetic` pay, grant and save in one call. A second BUY press finds `_confirm_id == ""` and does nothing. Workshop levels can't go past max: the read is clamped, `--workshop=` is clamped, and `can_buy_workshop` checks.
- **Spin vs TAILOR:** they can't race. The tabs are disabled while the wheel turns, `show_tab` returns early while spinning, `spin()` refuses on the SHOP tab or with the confirm open, and the hub's F only spins on the WHEEL tab.
- **Pity:** only a TAILOR rainbow buy resets it. A plain TAILOR buy leaves it alone but still counts as a spin, so the price ramp can't be dodged.
- **SECOND WIND payout:** the pod, the payout and `complete_random` all use `pay_attempt()`, so the assert holds. The daily cap, seed-paid-today, replay cap and no-slime cap still apply on top. It is off in hard mode, on randomizer hard and on story first clears. Assist and dev toggles still void tickets. It resets per scene reload, so it is once per attempt.
- **Hard mode:** `_apply_workshop` returns early, so base charge, stun, reach and glimmer settings apply and the WIND tag stays hidden.
- **Par / medals:** par is set before the upgrades and workshop are applied. Faster QUICK CHARGE / STICKY times and SECOND WIND on medal replays are allowed by the spec (B.2, B.3), so this is intended.
- **MAGNET line of sight:** it uses a revealed-cell check plus a 2 px tile raycast against 16 px wall tiles, so it can't pull through a wall. At most it could clip a corner by under 2 px. The ticket goal is not a coin, so it isn't pulled.
- **GOO NOSE cost:** an O(coins) loop per glimmer, which is negligible.
- **Autoplay:** it starts from a clean in-memory state (workshop empty).
- **Saves:** the save round trip, hostile values (`_int`, `_strings`, allow-listed ids, wrong-kind trail/paper), the save-code size, and RESET PROGRESS completeness are all fine.
- **Focus and Esc:** the HatWheel confirm lock is cleared in place by `unlock_focus`. Esc closes the confirm first, then the overlay. The PAPER/BACK neighbours, the wardrobe TRAILS focus and the cauldron tabs are all fine.

## Status (fix pass 2026-10-15)

All four findings fixed, each with a test.
1. **GOO NOSE**: `_spawn_glimmer` now picks only coins inside the camera view (+8 px) and within reach (`glimmer_view_only`, tests that need far coins turn it off). Rates retuned to x1.4 / x1.8 / x2.3 (`Economy.WORKSHOP.nose`; spec updated). Measured visible glimmers per minute at levels 0-3 (dense coin field, `test_workshop`): 16.1 / 21.6 / 27.9 / 35.6, ratio 1.00 / 1.34 / 1.73 / 2.21.
2. **Workshop +**: opens a BUY / BACK confirm (focus-locked, Esc closes it first); buys and + presses within 0.3 s of a buy are ignored (`test_store`).
3. **SECOND WIND**: adds a fixed 15 / 25 / 35% (`_wind_left`); slime spent during the 0.4 s refill stays spent (`test_workshop`).
4. **MAGNET, solid slime**: the coin glides into the slime, then pops (`test_workshop`).
