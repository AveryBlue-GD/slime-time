# Coin catch test (owner A/B, 2026-10-16)

Owner request: the coin pickup is far too sudden; it is hard to tell a coin was just picked up. This
prototype makes the pickup a short, readable moment.
**Status: kept, on by default for everyone (owner 2026-10-18).** `Economy.COIN_CATCH_TEST := true`;
with `false` (or `coincatch_force = 0`, or `--nocoincatch`) the old instant pickup runs. Credit and save still
happen at touch time. Flag plumbing stays until a follow-up removes it.

## What happens when it is on

1. **Touch** (same tick as today): the coin is credited and saved exactly as today
   (`Progress.collect_coin`, same coin key, same all-coins / rainbow check and message). Only the
   presentation waits: the HUD's coin counter and "N LEFT" hold the old number for now.
2. **Toss** (0.34 s): the coin flips up in an arc to 18 px above the slime's center, spinning 3x
   faster, with a gold sparkle trail and a small four-point glint at the top. The slime does an
   anticipation squash (0.14 s, its charge frames), then **hops** up to 5 px (0.34 s, launch/air frames)
   and catches the coin on its head just past the top of the hop (the coin sound plays here), then a
   landing squash (0.16 s). The hat goes up and down with it.
3. **Dissolve** (1.0 s): the coin sits in the slime and shrinks in whole even sizes (12 -> 2 px) while
   fading.
   - **Jelly** (see-through): the coin is tinted by the goo, sinks from the top of the body to its
     middle and fizzes smaller with tiny bubbles rising in the skin's light shade.
   - **Solid**: the coin shrinks into the top of the body, with a glint and a flat goo ripple that
     spreads to 8 px.
4. **Counter pop**: the coin counter (and "N LEFT") goes up by one with the HUD's usual gold flash,
   and a soft low fizz plays (`coin_fizz`, new, -8 dB).

The hop is **only on the sprite**: a whole-pixel offset added at the end of each slime tick and taken
off again at the start of the next one, plus the hop's frames while gliding. The physics body,
movement, controls, collisions, leap, run timer and slime meter don't change (a test leaps through a
coin with the flag off and on and checks the body's path, meter and timer match tick for tick). You
keep full control while it plays. During a leap the catch happens in the air: the hop adds onto
the leap's arc and the coin follows the moving slime. The show is a child of the slime and moves on
physics ticks in whole pixels, so physics interpolation above 60 Hz draws it smoothly with the slime
(the hat and the slime's light already follow the sprite's interpolated position).

## Edge cases

- **Several coins quickly**: each gets its own show (a 3 px sideways offset so they don't stack);
  a coin touched while a hop is under way joins that hop if it still has 0.16 s or more until its
  catch, otherwise the hop restarts. At most 3 run at once; a 4th finishes the oldest at once (its
  counter pop). Each coin is counted once (the counter shows the balance minus the coins still
  dissolving).
- **Pause** freezes it (the tree pauses; it resumes where it was).
- **Win / dry-up**: every show finishes at once in `_finish` (counter shows the full count, the hop
  is cancelled, the sprite drops back). **Restart / quit** reloads the scene: the shows go with it;
  the coin was saved at touch, so it is never lost or counted twice.
- **Reduce Motion**: no toss, no hop, no particles: the coin sits still in the slime and fades out
  over 1.2 s, the coin sound plays at touch, then the counter pops.
- **Skins**: jelly vs solid follows the jelly setting; bubbles and ripple use the skin's light shade
  (rainbow: rainbow bubbles). Stopwatch, Inkky and custom skins use the same path.
- **Performance**: nodes and particles are made once per coin at touch; per tick it only sets a few
  positions/scales and redraws the small glint/ripple while they show (no per-frame allocations).

## Numbers (scripts/economy.gd, `COIN_CATCH_*`)

| constant | value | meaning |
|---|---|---|
| `COIN_CATCH_SQUASH_TIME` / `_HOP_TIME` / `_LAND_TIME` | 0.14 / 0.34 / 0.16 s | hop: anticipation squash, hop, landing squash |
| `COIN_CATCH_HOP_PX` | 5 px | how high the sprite hops |
| `COIN_CATCH_CATCH_SHARE` | 0.6 | catch moment, share of the hop (touch -> catch 0.34 s) |
| `COIN_CATCH_TOSS_HEIGHT` | 18 px | coin's top above the slime's center |
| `COIN_CATCH_TOSS_SPIN` / `_SPARKLES` | 3x / 6 | spin speed while tossed, sparkles |
| `COIN_CATCH_MIN_TOSS` | 0.16 s | shortest toss when joining a hop under way |
| `COIN_CATCH_DISSOLVE_TIME` | 1.0 s | dissolve inside the slime |
| `COIN_CATCH_BUBBLES` | 8 | jelly bubbles |
| `COIN_CATCH_RIPPLE_TIME` / `_RIPPLE_PX` | 0.45 s / 8 px | solid: goo ripple |
| `COIN_CATCH_CALM_TIME` | 1.2 s | Reduce Motion fade |
| `COIN_CATCH_MAX` | 3 | shows at once |
| `COIN_CATCH_COIN_DB` / `_FIZZ_DB` | -4 / -8 dB | coin sound at the catch, fizz at the end |

Touch to counter pop: 0.34 + 1.0 = about 1.35 s (1.2 s with Reduce Motion).

## Try it

```
./tools/play.sh --dev --coincatch
```

`--coincatch` (now the default, harmless) and `--nocoincatch` (old instant pickup, for A/B) are debug launch
flags (an exported release build ignores them; nothing is saved). Add `--jelly` for the see-through slime.

## Code

`scripts/coin_catch.gd` (`CoinCatch`: toss, dissolve, glint/ripple drawing), `Slime.catch_hop` /
`cancel_catch_hop` / `_catch_frames` (the cosmetic hop), `game.gd` `_catch_coin` / `_on_coin_caught` /
`_end_coin_catches` / `_show_coins`, `--coincatch` in `progress.gd`, the `coin_fizz` recipe in
`tools/make_sounds.py` (`python3 tools/make_sounds.py coin_fizz`; no other WAV changed).

## Clip and strip

- Side-by-side clip (left = current, right = coin catch; top = solid Lime, bottom = jelly Lime; level 1,
  FULL BRIGHT, top hat: a glide into a coin, then a leap that catches one in the air; real time, then
  half speed): `coincatch/coincatch_side_by_side.mp4` (local only, git-ignored).
- Strip (4x zoom, 4 frames apart unless noted): current solid pickup; catch solid toss; catch solid
  dissolve (6 apart); catch jelly toss; catch jelly dissolve (6 apart); the mid-leap catch:
  [coincatch/coincatch_strip.png](coincatch/coincatch_strip.png).
- Re-record: `tests/demo_coin_catch.tscn` (its header has the `--write-movie` command; add
  `--coincatch` for the right side, `--jelly` for the bottom row).

## Tests

`tests/test_coin_catch.gd`: off by default and debug-only flag; flag off = today's pickup; on, solid
and jelly: credited and saved at touch with today's coin key, the HUD holds, toss height, hop height,
catch at the hop's catch moment, 1.0 s dissolve, counter pop, whole pixels, nothing left behind; the
same leap through a coin flag off/on = identical body path, meter and timer, catch in mid-leap; four
coins in four ticks (max 3 at once, all counted once); pause freezes it; dry-up and win mid-show;
restart mid-show; Reduce Motion (solid and jelly).
