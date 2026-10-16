# Bouncy leap test (A/B prototype)

Owner, 2026-10-16: "do a test where the slime is more bouncy: bouncing at a diagonal angle doesn't feel satisfying
in any way". This is a prototype behind one flag, **off by default**. Nothing changes for players until it is
switched on.

## Try it

- `./tools/play.sh --dev --bouncy` (or any launch plus `--bouncy`). It is a debug flag, so a release export ignores it,
  and like every flag it never writes the real save.
- Compare with `./tools/play.sh --dev` (today's splat).
- Side by side: `docs/spring-cleaning/bounce/bounce_side_by_side.mp4` (local only, git-ignored like the other clips:
  real time, then half speed). Strip: [bounce/bounce_strip.png](bounce/bounce_strip.png).
- Re-record: `tests/demo_bounce.tscn` (4 leaps in level 1, FULL BRIGHT; header shows the `--write-movie` command).
  Numbers: `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 20000 -s res://tests/bench_bounce.gd`.
- **Switch it on for everyone:** `scripts/economy.gd` `const BOUNCY_TEST := true`. All tuning is in the `BOUNCE_*`
  constants there.

## How a wall hit works today (flag off)

The maze is all 1-tile corridors (16 px) and the slime is 14 px wide, so a **diagonal leap touches a side wall after
about 1.4 px, on the first tick, every time**. Then (`Slime._land`, `_knock_back`, `_ricochet`):

- splat: 0.3 s stun (no control), splat sound, hit-stop up to 0.06 s, screen shake up to 3 px + a 3 px kick into the wall;
- the leftover leap turns into a knockback slide (`wall_bounce`: restitution 0.632 into the wall, 0.85 along it,
  friction 260 px/s^2) that rattles between the corridor walls (the splat frame flips n / s / n each tick);
- cost: the flight (0.5 x gliding cost) + the splat penalty 2-5 % of the meter; the knockback slide is free.

Measured (`bench_bounce`, level 1, full-power leap = 128 px at 220 px/s):

| scenario | out speed | no control | moves after contact | cost |
|---|---|---|---|---|
| corridor diagonal, full | 190 px/s, decaying | 0.32 s | 25 px, 3 rattles | 5.05 % |
| corridor diagonal, half | 141 px/s | 0.32 s | 18 px | 3.55 % |
| corridor diagonal, min | 63 px/s | 0.32 s | 6 px | 2.05 % |
| junction corner diagonal, full | 159 px/s | 0.32 s | 14 px (8 net), 3 rattles | 5.14 % |
| dead-end inside corner, full | 171 px/s | 0.32 s | 14 px, 3 rattles | 5.05 % |
| dead end head-on, full (from 3 cells back) | 80 px/s | 0.32 s | 12 px back | 8.02 % |

So a diagonal leap is a dead stop: a stun, a short sticky smear, and nothing gained.

## The bouncy version (flag on)

A wall hit during a leap no longer ends it (`Slime._fly_bouncy`, `_bounce_off`, `bounce_dir`):

1. **Reflect.** The leap direction splits into the part into the wall (comes back x `BOUNCE_RESTITUTION` 0.75) and the
   part along it (keeps `BOUNCE_TANGENT_KEEP` 0.95). The leftover distance and the flight speed scale by the length of
   the result (a 45 deg hit keeps 86 %). Within ~20 deg of head-on (`BOUNCE_HEAD_ON_COS` 0.94) the restitution is
   `BOUNCE_HEAD_ON_RESTITUTION` 0.5: the slime springs straight back at half speed. **Head-on hits bounce too** (no
   stun): consistent, and the meter penalty below still punishes them.
2. **Squash, then stretch.** The slime holds on the wall `BOUNCE_SQUASH_TIME` 0.05 s (head-on 0.1 s) showing its
   splat frame, then springs off showing the stretched end of the launch frames for `BOUNCE_STRETCH_TIME` 0.1 s, then
   flies (air frames) on a new hop (`BOUNCE_ARC_BASE` 2 px + `BOUNCE_ARC_PER_TILE` 1 px a tile, starting from the height
   it hit at, so the sprite never pops). Sheet frames only: no sprite scaling, pixels stay whole.
3. **Feedback** scaled by impact (speed into the wall / 220): a new `bounce` boing (`tools/make_sounds.py`; pitch
   0.85-1.3, -12 to -2 dB), a goo spray of 6-14 particles at the contact point and a wall stain, a camera kick of up to
   `BOUNCE_KICK` 3 px **in the bounce direction** plus a 1 px shake for 0.18 s (both skipped with Reduce Motion, like
   every shake), a short phone buzz.
4. **No jitter.** For `BOUNCE_GRACE` 0.12 s after a bounce, a wall parallel to one just bounced off (the facing wall
   of a corridor, the same wall again) is slid along instead of bounced: a diagonal leap in a corridor taps once and
   then zips along it. An inside corner gives one quick double bounce (the second wall at once, no second hold) and
   the slime comes back out. Grazes (`BOUNCE_GRAZE_COS` 0.15) just slide, at most `BOUNCE_MAX` 4 bounces per leap,
   a rebound shorter than `BOUNCE_MIN_LEFT` 6 px drops off the wall, a slime wedged with nowhere to slide lands.
   Rebound speed never drops under `BOUNCE_MIN_SPEED_SHARE` 0.45 x 220.
5. **Cost unchanged.** The leap is charged for the flight up to the first wall touch (0.5 x gliding) plus the splat
   penalty once per leap, exactly as the splat today; the rebound flight is free, like today's knockback slide.
   (Measured: identical cost in every scenario.) Changed rule: the rebound is a flight, so it leaves no goo trail
   and reveals nothing while airborne (the knockback slide did).

Measured with the flag on:

| scenario | out speed | in the air after contact | moves after contact | cost |
|---|---|---|---|---|
| corridor diagonal, full | 189 px/s, steady | 0.65 s | 86 px along the corridor, 1 bounce | 5.05 % |
| corridor diagonal, half | 189 px/s | 0.40 s | 48 px | 3.55 % |
| corridor diagonal, min | 189 px/s | 0.13 s | 11 px | 2.05 % |
| junction corner diagonal, full (head-on into the corner) | 113 px/s | 0.58 s | 44 px back | 5.14 % |
| dead-end inside corner, full | 158 px/s | 0.65 s | 64 px back out, 2 bounces | 5.05 % |
| dead end head-on, full (from 3 cells back) | 114 px/s | 0.27 s | 16 px back | 8.02 % |

## Guarantees and tests

- Deterministic at 60 Hz physics: only physics-tick state, no randomness in motion (only the sound's pitch jitter).
- No teleports: every move is `move_and_collide` (plus the existing 1-3 px corner leeway on straight leaps), so physics
  interpolation needs no reset. No tunnelling: a tick moves at most one flight step (3.7 px < the 7 px radius).
- Unchanged: gliding into walls (still slides), SLIMAKAZE dashes, the leeway for straight leaps that clip a corner,
  everything with the flag off. The hub plays the boing and the squash / stretch, without the camera / goo effects.
  There are no walls to leap over in this game (the leap arc is drawn only), so nothing changes there.
- `tests/test_bouncy.gd`: off by default and a debug-only flag; reflection math (45 deg, head-on, symmetry); the old
  splat with the flag off; corridor (1 bounce, carries on > 48 px, same cost as the splat, no wall overlap); inside
  corner (2 bounces, one squash hold, comes out); deterministic paths; camera kick in the bounce direction and none with
  Reduce Motion; goo burst; a fuzz of 100+ leaps from random off-centre spots in 8 directions on levels 1-3 (all land,
  never in a wall, no tick moves more than 8 px, at most `BOUNCE_MAX` bounces, never more than 2 within 10 ticks).
- `./tools/test_all.sh`: 78 suites pass with the flag off (default); the Web export builds.

## Open questions for the owner

- Should head-on hits keep the old stun splat (a stronger "don't leap into walls" lesson) and only angled hits bounce?
  One line in `Slime._bounce_off` (return to `_land(true, normal)` when `head_on`).
- The corridor zip makes a diagonal leap useful (it travels ~2/3 of the leap along the corridor for the splat's
  price). If that is too generous, lower `BOUNCE_TANGENT_KEEP` / `BOUNCE_RESTITUTION`, or charge the rebound flight too.
- The autoplay was not run or tuned with the flag on (it passes with the flag off, the default).
