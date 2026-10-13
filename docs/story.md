# Story

A light plot. The intro and finale cinematics are **wordless**: no words, letters or numbers anywhere on screen; every beat is told by staging, silhouettes, animation, camera, light and color (warm torchlight for the chase, cold pale light at the bottom, warm dawn at the end) and small pixel pictograms drawn from bitmaps in code (crossed swords, a red "!" alarm, gold coins, a crescent moon, a sweat drop, loot sparkles, a depth gauge). The only story text is the level banners' one-liners in `scripts/story.gd` (uppercase, at most 296 px wide in the 8 px pixel font). `tests/test_story.gd` checks the banner lines, that no shot has lines or titles and the story screen makes no text calls / loads no font / has no label nodes, the timings, auto-advance through every shot, skip and the Reduce Motion stills. The scene is `scenes/story.tscn` (`scripts/ui/story_screen.gd`).

## Plot
A slime was running from a party of adventurers (they wanted experience points, it wanted a nap) when the floor gave up and it fell through the ceiling of a mountain-sized dungeon, down through every floor, and splatted on the bottom one, the Dark Dungeon. The way out is up: each of the 10 levels is a floor of the climb (a golden chalice marks the way up), and the Volcanic Vault at the summit ends in the crater, which spits the slime out into daylight. Far below, the adventurers still search and find only a puddle, which they count as loot.

The climb order is the level order: level 1 is the bottom, level 10 the top. The "fog" the tagline warns about is the dungeon's; "dry trying" is the slime meter.

## Intro (5 animated shots, about 24 s)
Shown once, automatically, the first time the game is launched on a fresh save (the launch trailer: it plays before the title, then a goo wipe leads into the title; PLAY on a fresh save then goes straight into level 1). Finishing or skipping it marks it seen. Replay it any time from the STORY button on the title screen. Each shot is a short scene drawn in code at 320x180 (`scripts/ui/story_screen.gd`, `StageArt`) behind letterbox bars that slide in. The bottom bar shows one pip per shot (current one lit in the slime's color) and a dim fast-forward mark; there is no text. A shot moves on by itself after its `time` (in `Story.INTRO`); any key, click or tap moves on early; Esc skips the whole thing.
1. **run** (4.6 s) *a slime is hunted*: a parallax torch-lit corridor (far arches, lit brick wall, flagstones, foreground pillars), the slime sprinting right with motion lines, a goo trail and a sweat drop; three adventurer silhouettes (knight, rogue, wizard) running after it with swinging torches, long shadows and sparks. Each adventurer pops a speech bubble with **crossed swords** (armor clank), the slime a red **"!" alarm**.
2. **chase** (4.0 s, 2x) *why*: the same chase up close, their huge shadows swaying on the wall; the adventurers' thought clouds show **gold coins** (loot), the slime's a **crescent moon** (it only wanted a nap).
3. **crack** (3.9 s, 2x) *cornered*: the slime skids to a stop against a **dead-end wall** (torch sconce, rubble), sweats; cracks spread through the floor with dust, grit and growing shakes, the adventurers close in, the slime's "!" pops; the floor breaks into falling chunks (three "!" from the adventurers), a red glow far below, a cartoon hang, and down it goes.
4. **fall** (4.8 s) *down through the mountain*: a cross-section of the mountain, the camera accelerating down past all ten floors (Volcanic Vault at the top to the Dark Dungeon at the bottom), each in its own palette and dressing. The slime always drops through a **hole in each floor slab** and falls down the open middle of every room: no prop, liquid or rock is ever drawn in the shaft (`SHAFT_L`..`SHAFT_R`), and each hole has its theme's lip (glowing split crust, crystal shards, an oubliette grate hanging open, broken ice with icicles, rubble, sludge / water / sand pouring down the hole's walls, a mine-shaft timber collar). The **Volcanic Vault** is a lava cavern: lavafalls pour from vents in both side walls into two lava pools, which sit against the walls and are held off from the hole by glowing basalt lips; the slime drops between the lips through a red-hot crack in the crust, with heat haze over the pools, embers and sparks rising past it, and a hot orange light on the slime (its colors tinted by each floor's light). A **depth gauge** at the right (ten colored slices widening like a mountain, a sun above the summit) shows the slime's marker sliding down. Speed lines and goo streaming off the slime.
5. **splat** (6.4 s) *the bottom*: a white flash, the splat (squash frames, a ring of goo droplets that stick, dust, shake, camera bounce), then the dark closes in and the camera slowly pushes in on the lone slime blinking in the pale shaft from the hole far above. From 2.6 s the depth gauge fades in big beside it: the marker at the very bottom slice, a dotted arrow climbing from it to the sun (the way out is up; this replaces the old title card).

Sounds (low and dark, `tools/make_sounds.py`): clank, crack, whoosh and sunrise were added for the story; it also uses crumble, splat, jump, land and coin.

**Reduce Motion:** each shot is simulated silently up to its `still` moment and frozen there (particles and pictograms included), with no shake, bounce or zoom; each still holds at least 4.5 s (`CALM_HOLD`), then moves on. The stills are picked to read without motion: the swords and "!" bubbles, the coin and moon thoughts, the cracked floor at the wall with the slime's "!", the slime in the lava cavern above the crust's crack with the gauge, the slime at the bottom with the gauge's arrow up, the slime on the crater rim at sunrise, and the adventurers over the sparkling puddle with the loot bubble.

Preview: `./tools/godot.sh --path . --write-movie /tmp/story.avi --fixed-fps 30 --quit-after 760 res://tests/demo_story.tscn -- --skin=lime --story=intro` (`--story=finale`, `--story=intro:3` to start at a shot, `--calm` for the stills; never saves; a recording ignores stray input). If the window gets covered while recording, macOS stops drawing it and the movie comes out short: add `--always-on-top --position 0,0 --resolution 320x180`. Key frames: `docs/polish-shots/story3_*.png`.

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
Shown after beating level 10 (once; keys as above), then the victory screen. Also wordless.
1. **daylight** (6.6 s) *out*: night turning to dawn over a dithered sky gradient, stars fading, the sun rising behind two ranges of peaks with turning rays; the crater glows and spits the slime out in a burst of lava sparks and goo, it lands on the rim, stretches toward the sun and celebrates; birds cross.
2. **search** (6.2 s) *meanwhile, far below*: back in the Dark Dungeon's room (the pale shaft plus their warm torches), the knight crouches over the slime's puddle, which glints with **sparkles**; a speech bubble with a **sparkling gold coin** pops over him (they count it as loot). Then a cut back to the sunrise with the slime celebrating, ending in a warm gold fade.

## Saving
`story_seen` (section `progress`, optional, bit 1 = intro seen, bit 2 = finale seen). A save without the key counts as past the intro if it has any progress, and past the finale if level 10 was cleared. RESET PROGRESS clears it; tests, headless/screenshot runs and dev mode (`--unlock-all`) start with both seen so levels start directly.
