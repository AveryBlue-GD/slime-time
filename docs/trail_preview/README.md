# Trail preview (branch `trail-preview`, 2026-10-22)

Ten proposed goo trail styles (ideas/trail-ideas.md) rendered in the real game: level 1, Lime skin,
the trailer director's autopilot route (`tools/trailer/take.tscn --take=play`, seeded), frame 420,
upscaled 3x. `contact_sheet.png` shows all 11 (default SKIN GOO first).

Re-capture one: `.\tools\screenshot.ps1 -Frames 420 -Scene res://tools/trailer/take.tscn -GameArgs --take=play,--level=1,--skin=lime,--trail=ID`

Ids: dried, frost, toxic, pixel, treasure, confetti, crystal, moss, ghost, pulse (Cosmetics.LIST,
`earned = "PREVIEW"`: not in the SHOP; colors in `Cosmetics.trail_cell_at`, TREASURE's dashes in
`trail_center`, animated FROST / TOXIC / GHOST via `fx` in assets/shaders/trail.gdshader).
PULSE is static (brighter bands by distance traveled). Known preview gaps: wall splat stains keep
the skin's goo; test_store / test_trails fail (they pin the old trail list and goo alpha).

## Prize wheel (2026-10-22)

The ten trails are prizes on the hat wheel now (`wheel = true` in Cosmetics.LIST: never sold;
Progress.hats_left lists hats then wheel trails, win_hat owns and wears a won trail). PULSE, GHOST
and PIXEL are rare (Economy.WHEEL_RARE, weight 0.3, like the rainbow hat, propeller and raincloud);
the other seven are common (1.0). Full wheel: 16 common at 5.62 % each, 6 rare at 1.69 % each.
The wheel was redrawn (bulb rim, shaded wedges, gold-trimmed rare wedges, new hub and pointer) and
has two looks, `--wheel-style=rewards` (default: every prize on its wedge) and `--wheel-style=odds`
(gems / stars only, an odds legend, the prize shown once it lands). Shots: `wheel/`
(`wheel_comparison.png`). Tests still written for a hats-only wheel fail (test_store, test_tickets,
test_wheel_odds, test_hats).

## Final (2026-10-22, owner's pick)

ODDS is the wheel's look (`--wheel-style=rewards` still shows the other for comparison, debug only).
HAT WHEEL is now PRIZE WHEEL in every player-facing text. Spins: the first free, then a flat 20
tickets (Economy.SPIN_COST; 420 for all 22 prizes). "{count} PRIZES TO WIN" sits at the top and
counts down as prizes are won. The wardrobe's TRAILS page fits all 17 trails in two rows of 9.
All 117 test suites pass; shots: `wheel/wheel_final_idle.png`, `wheel/wheel_final_landed.png`,
`wheel/wardrobe_trails.png`.
