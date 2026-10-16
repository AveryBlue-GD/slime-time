# Soft bounce test (owner A/B, 2026-10-16)

A smaller, subtler take on wall hits than the reverted ricochet prototype (`c1c339d`, reverted in
`f2ae36d`). **Off by default**: with `Economy.SOFT_BOUNCE_TEST := false` the game plays exactly as before.

## What changes when it is on

A leap that touches a wall is sorted by angle (cos of the angle between the leap and the wall normal,
`SOFT_BOUNCE_HEAD_ON_COS` 0.94 = 20 deg):

- **Glancing hit** (more than ~20 deg off head-on, e.g. any diagonal leap in a 1-tile corridor): no
  ricochet. The slime squashes on the wall for 0.05 s (`SOFT_BOUNCE_SQUASH`, 3 ticks), is stunned
  0.1 s in all (`SOFT_BOUNCE_GLANCE_STUN`, was 0.3), then glides on **along the wall** at 60 % of its
  speed along the wall (`SOFT_BOUNCE_SPEED_SHARE`: 93 px/s for a 45 deg leap), braking evenly to a stop
  after 0.35 x the leap distance still left, clamped to **16-32 px** (`SOFT_BOUNCE_SLIDE_*`). A wall in
  the way (an inside corner) just ends the slide there. It plays a soft 'plap' (the existing splat
  sound at -9 dB, pitch 1.45, no new sound), sprays 6 goo droplets off the contact point and leaves
  the usual wall stain. No camera shake or kick, no hit-stop, a short 20 ms phone buzz.
- **Head-on hit** (within ~20 deg): still a splat (sound, stain, burst, shake, hit-stop as today), but
  stunned 0.18 s (`SOFT_BOUNCE_HEAD_STUN`, was 0.3), a 0.1 s recover (was 0.15), and a knockback
  **straight off the wall**, half today's distance (`SOFT_BOUNCE_HEAD_KNOCK` 0.5, at most 16 px),
  braking at 520 px/s^2 (twice the glide friction) - a short, snappy push instead of a slow slide.
- Both slides are moved by `Slime._soft_step` (move_and_slide, never bounces), so there is no
  rattling between corridor walls. STICKY's shorter splat stun still applies (the soft stuns are
  never longer than it).

**Cost**: unchanged. The leap is charged for the distance flown up to the wall plus the same splat
penalty (`splat_penalty`), and the slide after it is free, exactly like today's knockback.

## Numbers (scripts/economy.gd, `SOFT_BOUNCE_*`)

| constant | value | meaning |
|---|---|---|
| `SOFT_BOUNCE_HEAD_ON_COS` | 0.94 | head-on if within ~20 deg |
| `SOFT_BOUNCE_SQUASH` | 0.05 s | glance: held squashed on the wall |
| `SOFT_BOUNCE_GLANCE_STUN` | 0.1 s | glance: stun in all (was 0.3) |
| `SOFT_BOUNCE_SPEED_SHARE` | 0.6 | glance: share of the speed along the wall kept |
| `SOFT_BOUNCE_SLIDE_PER_LEFT` / `_MIN` / `_MAX` | 0.35 / 16 / 32 px | glance: slide length |
| `SOFT_BOUNCE_PLAP_DB` / `_PITCH` | -9 dB / 1.45 | glance: the splat sound, softer and higher |
| `SOFT_BOUNCE_DROPLETS` / `_DROPLET_SPEED` | 6 / 35 px/s | glance: goo droplets |
| `SOFT_BOUNCE_HEAD_STUN` / `_HEAD_RECOVER` | 0.18 s / 0.1 s | head-on stun and recover |
| `SOFT_BOUNCE_HEAD_KNOCK` / `_KNOCK_MAX` / `_DECEL` | 0.5 / 16 px / 520 | head-on knockback |

## Try it

```
./tools/play.sh --dev --softbounce
```

`--softbounce` is a debug launch flag (an exported release build ignores it; nothing is saved). To turn
it on for everyone, set `const SOFT_BOUNCE_TEST := true` in `scripts/economy.gd`.

## Clip and strip

- Side-by-side clip (left = current, right = soft bounce; level 1, FULL BRIGHT: full and half-power
  diagonal leaps in a corridor, a diagonal leap into a dead-end corner, a head-on leap; real time,
  then half speed): `softbounce/softbounce_side_by_side.mp4` (local only, git-ignored).
- Strip (top = current, bottom = soft; 8 frames of the full diagonal corridor leap, then 8 of the
  head-on leap, 5 frames apart): [softbounce/softbounce_strip.png](softbounce/softbounce_strip.png).
- Re-record: `tests/demo_soft_bounce.tscn` (its header has the `--write-movie` command; add
  `--softbounce` for the right side).

## Tests

`tests/test_soft_bounce.gd`: default off and debug-only flag; angles 0-60 deg off head-on -> splat vs
glance; stun lengths (18 / 11 / 6 ticks); glance slide 16-32 px along the wall with no reversals,
ricochets or sideways drift; head-on knockback shorter than today and straight; the same leap cost,
splat penalty and splat count with the flag off and on (free slides); an inside corner stops and the
slime glides out; determinism; no camera movement or hit-stop on a glance, none at all with Reduce
Motion; ~120 random leaps on levels 1-3 (all come to rest, no wall overlap, no tunnelling, no rattle).
