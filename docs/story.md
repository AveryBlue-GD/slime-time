# Story

A light plot told in one-liners. All text lives in `scripts/story.gd` (uppercase, at most 296 px wide in the 8 px pixel font, title cards in the 16 px font; `tests/test_story.gd` checks this, the timings, auto-advance through every shot, skip and the Reduce Motion stills). The scene is `scenes/story.tscn` (`scripts/ui/story_screen.gd`).

## Plot
A slime was running from a party of adventurers (they wanted experience points, it wanted a nap) when the floor gave up and it fell through the ceiling of a mountain-sized dungeon, down through every floor, and splatted on the bottom one, the Dark Dungeon. The way out is up: each of the 10 levels is a floor of the climb (a golden chalice marks the way up), and the Volcanic Vault at the summit ends in the crater, which spits the slime out into daylight. Far below, the adventurers still search and find only a puddle, which they count as loot.

The climb order is the level order: level 1 is the bottom, level 10 the top. The "fog" the tagline warns about is the dungeon's; "dry trying" is the slime meter.

## Intro (5 animated shots, about 24 s)
Shown once, on a fresh save, when PLAY is pressed on the title (before level 1). Replay it any time from the STORY button on the title screen. Each shot is a short scene drawn in code at 320x180 (`scripts/ui/story_screen.gd`, `StageArt`) behind letterbox bars that slide in, with its lines typed on in the bottom bar. A shot moves on by itself after its `time` (in `Story.INTRO`); any key, click or tap moves on early; Esc skips the whole thing.
1. **run** (4.6 s): a parallax torch-lit corridor (far arches, lit brick wall, flagstones, foreground pillars), the slime sprinting with motion lines and a goo trail, three adventurer silhouettes (knight, rogue, wizard) running with swinging torches, long shadows, sparks, "!" pop-ups and an armor clank. A SLIME. SOME ADVENTURERS. / A LOT OF TORCHES.
2. **chase** (4.0 s): the same chase at 2x, their huge shadows swaying on the wall, gold "XP!" pops over them and sleepy Z's trailing the slime. THEY WANTED EXPERIENCE POINTS. / IT WANTED A NAP.
3. **crack** (3.9 s, 2x): the slime skids to a stop, "?", cracks spread through the floor slab with dust, grit and growing shakes, the adventurers arrive, the floor breaks into falling chunks, a cartoon hang, and down it goes. THEN THE FLOOR / GAVE UP.
4. **fall** (4.8 s): a cross-section of the mountain, the camera accelerating down past all ten floors (Volcanic Vault at the top to the Dark Dungeon at the bottom), each in its own palette and dressing (lava, crystals, chains, icicles, skulls, sludge, water, sand, mine props, torches) with a diagram label (FLOOR N + name), speed lines and goo streaming off the slime. DOWN. AND DOWN. / AND A BIT MORE DOWN.
5. **splat** (6.4 s): a white flash, the splat (squash frames, a ring of goo droplets that stick, dust, shake, camera bounce), then the dark closes in and the camera slowly pushes in on the lone slime blinking in the pale shaft from the hole; the title card DARK DUNGEON / FLOOR 1 OF 10 fades in. SPLAT. THE EXIT IS UP. / ESCAPE THE FOG OR DRY TRYING.

Sounds (low and dark, `tools/make_sounds.py`): clank, crack, whoosh and sunrise were added for the story; it also uses crumble, splat, jump, land and coin.

**Reduce Motion:** each shot is simulated silently up to its `still` moment and frozen there (particles included), with no shake, bounce or zoom; text fades in whole; each still holds at least 4.5 s (`CALM_HOLD`), then moves on.

Preview: `./tools/godot.sh --path . --write-movie /tmp/story.avi --fixed-fps 30 --quit-after 760 res://tests/demo_story.tscn -- --skin=lime --story=intro` (`--story=finale`, `--story=intro:3` to start at a shot, `--calm` for the stills; never saves). Key frames: `docs/polish-shots/story2_*.png`.

## Level banners
Shown under the area name for a few seconds when a story level starts (not in the randomizer).

1. Dark Dungeon: SPLAT. IT IS DAMP. UP IS THAT WAY.
2. Mossy Mines: THE MINERS LEFT IN A HURRY. SO WOULD YOU.
3. Sandstone Sanctum: SOMEONE SWEPT THE SAND. NOT RECENTLY.
4. Sunken Shrine: NOT TECHNICALLY SWIMMING. STILL NOT DRY.
5. Toxic Tunnels: A SLIME IN SLIME. NOBODY WILL NOTICE.
6. Creepy Catacombs: THE RESIDENTS ARE QUIET. SUSPICIOUSLY.
7. Frozen Fortress: COLDER NOW. SLIME DOES NOT SHIVER. IT JIGGLES.
8. Obsidian Oubliette: A CELL FOR THE FORGOTTEN. YOU ARE UNFORGETTABLE.
9. Crystal Caverns: SO SHINY. DAYLIGHT MUST BE CLOSE.
10. Volcanic Vault: HOT. THE WAY OUT IS THE CRATER. RUN.

## Finale (2 shots, about 13 s)
Shown after beating level 10 (once; keys as above), then the victory screen.
1. **daylight** (6.6 s): night turning to dawn over a dithered sky gradient, stars fading, the sun rising behind two ranges of peaks with turning rays; the crater glows and spits the slime out in a burst of lava sparks and goo, it lands on the rim, stretches toward the sun and celebrates; birds cross. THE CRATER SPITS YOU OUT / INTO DAYLIGHT. A LITTLE DRY. FREE.
2. **search** (6.2 s): back in the Dark Dungeon's room (the pale shaft plus their warm torches), the knight crouches over the puddle, "+1 LOOT"; then a cut back to the sunrise with the slime celebrating, ending in a warm gold fade. FAR BELOW, THE ADVENTURERS STILL SEARCH. / THEY FIND A PUDDLE. IT COUNTS AS LOOT.

## Saving
`story_seen` (section `progress`, optional, bit 1 = intro seen, bit 2 = finale seen). A save without the key counts as past the intro if it has any progress, and past the finale if level 10 was cleared. RESET PROGRESS clears it; tests and dev mode (`--unlock-all`) start with both seen so levels start directly.
