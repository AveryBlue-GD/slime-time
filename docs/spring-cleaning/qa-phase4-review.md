# QA review: spring cleaning phase 4 (performance)

Date: 2026-10-16. Reviewer: code-reviewer + perf-profiler verifier (read-only on game code).
Scope: the phase 4 commits `b8b2bf6`..`90e3d4c` (`b8b2bf6`, `a824578`, `d86a841`, then `db9f2bf`..`90e3d4c`), checked against
[phase4-perf.md](phase4-perf.md), [phase4-perf-audit.md](phase4-perf-audit.md) and decisions D3/D5.

Method: everything ran from scratch worktrees (`/private/tmp/claude-501/qa4_wt` at `90e3d4c`, `qa4_base` at `9f965f0` = phase 3
end), with a fake `HOME`. No real save was read or written, and no Godot process I did not start was touched. Both worktrees were
removed afterwards. Tools (scratch only): a pacing probe, a frame-sequence capture plus pixel diff, and a maze-output dump.

## Findings (most severe first)

1. **`scripts/ui/skin_text.gd:132` (`_label_shown`), together with `scripts/hub.gd:654`: a stale rainbow color overwrites the coin
   board's gold counts.**
   - Problem: while the coin board is hidden, the per-frame rainbow step (`_recolor_labels`, flow) stores a `DUE` color on each
     hidden group label and hooks `visibility_changed`. `open_coin_board` then takes the finished-level counts out of the SkinText
     group and gives them a gold override. When it shows the board, `_label_shown` still applies the stale `DUE` color, so the
     gold is gone. The `recolor()` that follows only touches labels still in the group.
   - Failure scenario: rainbow skin, hub, open the coin bag. Every "N/N" count that should be gold is drawn in the pale rainbow
     text color for as long as the board is open. Measured: frames 12-29 of my rainbow hub sequence differ from phase 3 by 557 px,
     all inside the count column (x 213-241). Phase 3 draws them gold.
   - Fix: in `_label_shown`, apply `DUE` only when `label.is_in_group(GROUP)` (and drop the meta otherwise). A broader option:
     clear `DUE` whenever a label leaves the group or gets its own override. This file is in the ui-polisher's area, so
     coordinate the change.

2. **`scripts/ui/transition.gd:56-66` (`follow_frame_rate`) and `scripts/game.gd:726-733` (`_set_pixel_cam`): one hitch flips
   interpolation off and back on, and each flip snaps the camera.**
   - Problem: the estimate is an EMA of frame time with weight 0.1, so a single long frame can push it under 66 fps:
     - at 75 Hz, a frame of 32 ms or more (two missed vsyncs);
     - at 90 Hz, about 52 ms;
     - at 120 Hz, about 77 ms;
     - at 144 Hz, about 89 ms;
     - at 240 Hz, about 114 ms.
     The estimate then needs 4-29 frames to climb back above 72. Each switch calls `_set_pixel_cam`. Turning off runs
     `camera.reset_smoothing()` and turning on sets `_cam_fresh`, so both snap the eased camera onto the slime.
   - Failure scenario, measured: `--fixed-fps 75` on L5 with one simulated 50 ms frame (an extra `follow_frame_rate(0.05)`).
     Interpolation went off for 18 frames, and the slime jumped on screen by 9 px at the off switch and by 12 px at the on
     switch, 0.24 s later with no hitch to hide it. The control run had no jump.
   - Who sees it: 75 Hz players after any two dropped frames, 90 Hz players after a 52+ ms hitch, and 120-240 Hz players after an
     80-115 ms hitch mid-play (a first-use compile on web, an autosave, a background spike).
   - At 60 Hz there is no flip-flop: 10 simulated minutes with ±3 ms jitter and bursty 8/25 ms pairs gave 0 switches.
   - Fix:
     - Make the switch time-based: stay below 66 fps for about 0.5 s before turning off, and leave frames over about 50 ms out
       of the estimate.
     - Make the switch seamless: seed `_cam_smooth` from the camera's current eased center when turning on, and do not
       `reset_smoothing()` when turning off. Camera2D smoothing carries on from where the pixel camera was.

3. **`scripts/ui/title.gd:122` (`_start_preload`) on the first-launch path (low; the doc is wrong).**
   - Problem: on a first launch the title hands off to the story before `_start_preload` runs (`title.gd:30`). The cold load of
     main, hub and story (about 0.37 s on the M3, more on phones) therefore happens when the title is first opened after the
     trailer, inside a covered goo wipe. It does not happen "under the boot screen", as phase4-perf.md section 6 says.
   - Impact: no functional problem. On web the trailer -> title -> PLAY path works and the console shows no errors (checked in
     a local web export). The stall just moves to a frozen wipe.
   - Fix: correct the doc, or run the preload in the trailer path's first title (or from the story scene) before the hand-off.

4. **`scripts/maze_generator.gd:420-421` (`shortest_path`): no guard for a target that cannot be reached (low, latent).**
   - Problem: with an unreachable `to`, `came_from[target]` is -1. The walk-back then indexes `came_from[-1]` (the packed
     array's last element), so it returns a garbage path or loops forever. The old Dictionary code failed with an error instead.
   - Impact: every current caller passes reachable cells in connected mazes (the survey guards bounds), so nothing hits this
     today.
   - Fix: `if came_from[target] < 0: return []` before the walk-back.

No other issues found.

## Verified (no finding)

**(1) Physics interpolation**

- **Switch thresholds:** on above 72, off below 66.
  - At `--fixed-fps 60`: interpolation stays off. Every frame of a 5 s autopilot run (slime marker pixel, camera origin, light,
    hat, tick fraction) is byte-identical to phase 3, so 60 Hz adds no lag.
  - At 75 / 144 / 240 Hz: it is on.
- **Renderer mirror:** a magenta marker drawn by the renderer as the slime's child sat exactly where `drawn_shift` predicted (a
  script-placed cyan marker) in **100 % of frames** at 75 / 144 / 240 Hz.
- **Pacing.** Slime on-screen 1 px back-and-forth, per second:

  | Refresh | phase 3 | phase 4 |
  |---|---|---|
  | 60 Hz | 6.0 | 6.0 |
  | 144 Hz | 24.8 | **0** |
  | 240 Hz | 17.4 | **0** |

  - On the interpolated ideal pixel: 100 % at 144 Hz, 99.9 % at 240 Hz.
  - Light/fog hole off the drawn slime: 0 frames.
  - Hat-on-head offset reversals: 0.
  - This confirms the doc's claims. Its twitch counts (33 / 22) use a different metric.
- **Same simulation:** the physics position is identical at every tick at 144 and 240 Hz, phase 3 against phase 4 (300 ticks
  each). `test_interpolation` covers run time, meter and trail.
- **Teleport resets:**
  - Level start, restart, replay and Descent floors all reload the scene, and `game._ready` resets the slime after placing it.
  - The hub resets after placing its slime.
  - The SLIMAKAZE `flush` resets after the slime jumps to the wall.
  - Lane snap, knockback and corner slip move the slime inside physics ticks.
  - There are no dev F-key teleports (F1/F2 are bright and drain).
  - Autoplay only reloads scenes.
  - Menu previews are AnimatedSprite2D under the OFF root.
  - The hub hat (a child of the slime) takes off its parent's shift correctly.

**(2) Border layers**

- 0 differing pixels against phase 3:
  - all 10 story themes, hard 3, hard 10, randomizer and Descent;
  - 3 frames each, 1-3 s into an autopilot run (fog reveal included);
  - each case built twice.
- Draw calls: 92-130 (Descent 122, hard 120-125) -> 27-30. L6 and the randomizer were already at 28-31 in my frames.
- `test_border` checks collision and light reveal.

**(3) Rainbow recolor:** 0 px against phase 3 over every frame sequence:

- skins: 20 frames over 1 s;
- hub before the coin board opens (frames 0-11), the hub quit menu, and the hub after closing the board;
- upgrades: 20 frames, including a COINS -> ABILITIES page switch;
- level select, map table, settings;
- L10 HUD;
- pause menu, open and resumed.

The only difference is finding 1.

**(4) Fill cache**

- The key covers every input that `_fill` and `border_cells` read: size, walls, seed, tile level, theme and fillet for the fill;
  size, ring, depth, salt and theme for the border.
- The stored tile data and damage are copies made at fill time, so wall damage during play never leaks into the cache.
- It is a single slot, so memory stays bounded.
- A second build of each of the 15 cases above, served from the cache, is pixel-identical to phase 3.
- The menu backdrop's fill evicts the slot, which only costs a missed hit.

**(5) Descent drops:** 380 mazes produced byte-identical output, old code against new. The mazes: 20 story (normal and hard), 300
randomizer (mixed hard and slime levels) and 60 Descent floors. The output compared: `dead_end_depths` (keys and order),
`shortest_path` in both directions, `coin_cells` and `Descent.drop_cells`.

**(6) Title preload**

- The loads are plain, so no threaded loader is involved and nothing can deadlock.
- The web export has `thread_support=false`. It boots in a browser through the first-launch trailer -> title -> level 1 with no
  console errors.
- The preloaded scenes are held for the session (a few MB).

**(7) Wipe warm-up:** title frames 0-11 are pixel-identical to phase 3. The sheet is `MOUSE_FILTER_IGNORE`. The `busy` and tween
guards hold if `go()` or `reveal()` lands in the warm-up frame.

**(8) HUD pods:** `_pod_inputs` covers every input of `payout()`, `random_payout` and `descent_payout`. Boons only change between
floors, which means a scene reload.

**(9) Buy guard:** the SceneTreeTimer is process-always and ignores time scale, so it works while paused and at any
`time_scale`. A double tap within the frame is blocked by the flag. A screen freed early auto-disconnects the timer. `test_store`
pins 0.2 s / 0.4 s.

**(10) Exports and tests**

- Web, Windows and macOS release exports build with 0 errors.
- `./tools/test_all.sh` in the worktree: **73 suites, 0 failed** (96 s).

## Harness notes (for the next pixel QA)

Two things make base-vs-base frames differ unless they are pinned (both pinned identically in both scratch trees):

- `GooBox` seeds its lumps from the canvas item RID (`goo_box.gd:216`).
- `UIKit.text_material` seeds text drips with `randi()` per scene.

`MenuBackdrop` drift and the hat rainbow run on the wall clock, so they were hidden or avoided.
