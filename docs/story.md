# Story

A light plot told in one-liners. All text lives in `scripts/story.gd` (uppercase, at most 296 px wide in the 8 px pixel font; `tests/test_story.gd` checks this). The scene is `scenes/story.tscn` (`scripts/ui/story_screen.gd`).

## Plot
A slime was running from a party of adventurers (they wanted experience points, it wanted a nap) when the floor gave up and it fell through the ceiling of a mountain-sized dungeon, down through every floor, and splatted on the bottom one, the Dark Dungeon. The way out is up: each of the 10 levels is a floor of the climb (a golden chalice marks the way up), and the Volcanic Vault at the summit ends in the crater, which spits the slime out into daylight. Far below, the adventurers still search and find only a puddle, which they count as loot.

The climb order is the level order: level 1 is the bottom, level 10 the top. The "fog" the tagline warns about is the dungeon's; "dry trying" is the slime meter.

## Intro (5 cards)
Shown once, on a fresh save, when PLAY is pressed on the title (before level 1). Replay it any time from the STORY button on the title screen. Any key, click or tap goes to the next card; Esc skips the whole thing. Reduce Motion draws the cards as stills.
1. A SLIME. SOME ADVENTURERS. / A LOT OF TORCHES.
2. THEY WANTED EXPERIENCE POINTS. / IT WANTED A NAP.
3. THEN THE FLOOR / GAVE UP.
4. DOWN. AND DOWN. / AND A BIT MORE DOWN.
5. SPLAT. THE EXIT IS UP. / ESCAPE THE FOG OR DRY TRYING.

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

## Finale
Shown after beating level 10 (once; Esc / any key as above), then the victory screen.
1. THE CRATER SPITS YOU OUT / INTO DAYLIGHT. A LITTLE DRY. FREE.
2. FAR BELOW, THE ADVENTURERS STILL SEARCH. / THEY FIND A PUDDLE. IT COUNTS AS LOOT.

## Saving
`story_seen` (section `progress`, optional, bit 1 = intro seen, bit 2 = finale seen). A save without the key counts as past the intro if it has any progress, and past the finale if level 10 was cleared. RESET PROGRESS clears it; tests and dev mode (`--unlock-all`) start with both seen so levels start directly.
