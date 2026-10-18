# Map coin reveal test (owner, 2026-10-18)

Owner request: "make the coins disappear on the map if the player has picked them up but show them if they
revealed them even through a wall with the increased brightness. Limit this to dev mode only for now on showing
them with the brightness but apply the change to have the collected coins disappear from the map to both."

## What changed for everyone
- The MAP TABLE's trail maps never draw a collected coin (`Progress.map_coins`). Normal mode therefore shows no
  coin marks at all (before: every found coin was a dot). Start ring and goal X are unchanged.

## The dev-only test
- Switch: `Economy.MAP_COIN_REVEAL_TEST := false` (= on for everyone too; stays false for now) and
  `Economy.mapcoinreveal_force`; `Economy.map_coin_reveal_on(dev)` is true in every dev launch and never outside
  dev. `--nocoinreveal` (debug builds) sets the force to 0: off in dev too, for A/B.
- Reveal: during a run, an uncollected coin is "revealed" once its cell center is within the slime's light
  (`relight_radius` = `Game.LIGHT_RADIUS` 20 px + the BRIGHTNESS reach: 20 / 28 / 36 / 45 px at levels 0-3) by
  straight-line distance, walls ignored. A coin one cell over behind a wall (32 px) is reached from BRIGHTNESS 2.
  F1 FULL BRIGHT reveals every coin of the level.
- Stored per level and mode in the survey as `seen_coins` (merged over runs like the seen tiles). The map draws the
  revealed coins that are not collected, also on fog cells (seen through a wall). Hard maps have no coins.
- Recording: while the test is on, dev runs (F1 / F2 ones too) record their survey into memory for the session
  only (`Game._commit_survey`); dev mode never saves (`saving_enabled` is off), and `Survey.pack` never writes
  `seen_coins`, so no new key reaches any save. Outside dev nothing about recording changed. Dev launches still
  start with no maps (`enable_dev_mode`), so play a level first.

## How to try
1. `./tools/play.sh --dev` (add `--upgrades=0,0,3` for BRIGHTNESS 3; `--nocoinreveal` for the A/B).
2. Play a story level for a bit (or press F1 / fn+F1 for FULL BRIGHT), then QUIT TO HUB.
3. Open the MAP TABLE and that level's map: the revealed, uncollected coins are dots; collected ones are gone.

Screens: `tests/demo_maps.tscn -- --unlock-all --partial=3 --reveal=3 --map=3` (dev, revealed coins on fog) vs
`-- --story-complete --map=3` (normal, no coin marks).

## Tests
`tests/test_map_coin_reveal.gd` (collected never drawn in normal and dev, reveal through a wall by radius,
BRIGHTNESS 0..3, F1, never outside dev, `--nocoinreveal` child launch, dev in-memory recording with the save md5
unchanged, hard separate); `tests/test_maps.gd` and `tests/test_i18n_maps.gd` keep passing.

## Decide
Keep (dev only / for everyone: set the constant to `true`, then decide whether `seen_coins` is saved, which needs
a survey format bump) or revert (remove the flag, `seen_coins`, `map_coins`' dev branch and the dev recording).
