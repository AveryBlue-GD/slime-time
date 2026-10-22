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
