# Game: "Slime Time" — build it in this Godot project

Follow the rules in CLAUDE.md (320x180 base resolution, 16x16 tiles, nearest-neighbor, palette in tools/make_placeholder_art.py). Replace the current top-down sandbox with this game. Build it in the phases listed at the bottom, and after each phase run the tests, take a screenshot, check it, and commit.

## Core concept
The player is a slime in a maze that starts completely black. The only way to reveal the map is to leave a trail of goo. Each level's exit is a golden chalice. Moving uses up slime; if it hits 0% the level restarts.

## Movement & trail
- **Free movement:** the slime glides smoothly in any direction (8-way input, analog-feeling), with acceleration and a bit of slippery deceleration, so it feels gooey rather than snappy.
- The slime paints a continuous goo trail on the floor wherever it goes. Reveal works at a fine grid (e.g. 4x4 px cells under the slime's footprint), so the map is uncovered in smooth, organic blobs, not whole tiles. [default]
- **Walls touching the trail also become visible** (fully textured, slightly dimmer than the goo-lit floor).
- **Light fades back:** areas near the slime stay fully lit; once it moves away they darken in steps (after ~1.5, 3.5, 6 and 9 s) down to a dim memory of the path, never fully black. Walls dim at the same moments as the floor (a constant shade darker). Returning relights them.
- The chalice is hidden until the trail comes within about 1 tile of it. [default]
- Walking costs slime per pixel traveled (tuned so crossing one 16 px tile costs about 1%). Standing still costs nothing. [default]

## Slime meter
- A HUD bar labeled "Slime remaining" starts at 100%.
- At 0%: the slime dries up (short animation), then the level restarts with the map black again.

## Charge jump (high risk / high reward)
- Hold Space to charge from 0 to 100 (a meter appears above the slime; full charge takes about 1.5s). Release to launch in the current movement or facing direction.
- Jump distance scales with charge, from about 1 to 8 tiles. While charging, show a faint dotted landing marker so skilled players can judge distance, but it does NOT reveal what lies in between. [default]
- Clean landing: costs **less** than gliding the same distance (about half). [default]
- Hitting a wall mid-jump: the slime **splats** against it, is stunned briefly (0.3 s), and pays half the glide cost of the distance actually flown plus a penalty from 2% (tiny hop) to 5% (full-power leap); still more than carefully gliding there, but not crushing. The screen shakes, the splat leaves a goo stain on the wall, and the slime is thrown back off the wall (reflected) by ~40% of the jump distance it had left, so hard leaps bounce further; that slide costs no extra slime.
- No trail is left mid-air (only a landing splat and any wall splat), so jumping saves slime but reveals less of the map. [default]

## Walls & floors: varied textures
- Use many tile variants so no two stretches of maze look the same:
  - **Walls:** at least 4 damage levels — intact stone, cracked, crumbling (missing chunks), and badly broken with rubble at the base — plus mossy and stained versions. Mix damage levels across each level; deeper levels have more broken walls. [default]
  - **Floors:** plain stone, cracked flagstone, moss patches, puddles, scattered pebbles/bones, and worn spots.
  - Wall tiles have proper edges and corners (autotiling via a Godot terrain set) so the maze shapes read cleanly.
- Pick variants with seeded randomness weighted per level, so a given level always looks the same.
- Broken walls are cosmetic only (they still block), unless I decide otherwise later.

## Levels
- 10 levels that get harder: larger mazes, more dead ends, and a tighter slime budget.
- Generate mazes procedurally from a fixed seed per level, so each level is the same every time it's played. [default]
- **Every level must be beatable:** compute the shortest path to the chalice and set the slime budget so a perfect glide uses about 60% (level 1) down to about 90% (level 10). Add a test that checks this for all 10 levels.
- Touching the chalice → short celebration → next level loads immediately. After level 10 → a victory screen.
- Save progress (highest level reached, unlocked skins, selected skin, custom color, glow) to `user://save.cfg`.

## Skins
- The default skin is **Ember (orange)**. Clearing each of levels 1–9 unlocks a new preset color skin.
- **Beating the game (level 10) unlocks the finale reward:**
  - A **custom color wheel** (hue/saturation wheel plus a brightness slider).
  - **Luminescence:** the slime glows and actually lights up the dark maze around it (a PointLight2D with an adjustable intensity/radius slider, tinted to the slime's color). The glow reveals the area around the slime as it moves, on top of the trail.
  - The glow does not exist anywhere before the game is beaten — not on preset skins and not in early levels.
- Skins are done with a palette-swap shader on one set of grayscale/indexed sprites, not by redrawing sprites for every color.
- Add a skin select screen reached from the title menu, with locked skins shown as silhouettes and the finale reward shown as "???".

## Sprites (generated by an expanded tools/make_placeholder_art.py, 16x16)
- Gliding: **at least 16 frames** — an 8-direction squish-and-stretch cycle (2+ frames per direction, more for the main 4), plus a 2–4 frame idle wobble.
- Jumping: **at least 20 frames** — charge squash (4, getting flatter as the charge rises), launch (2), airborne stretch (4), clean landing (4), wall splat (4, with goo spattered on the wall), and recovery (2).
- Other: dry-up / death (4), chalice sparkle (4), celebration (4).
- Goo trail: several blob variants so the trail doesn't look stamped.
- Bundle the frames into sprite sheets and play them with AnimatedSprite2D.

## Randomizer mode
- From the title screen. Every win generates a brand-new maze from a fresh seed; dying retries the same maze.
- Mazes are shaped by noise (corridors follow noise ridges; a second noise layer knocks out walls to add loops) and are **always completable**: built as a spanning tree over every cell, only ever removing walls afterwards, then verified with a breadth-first search. The slime budget comes from the real shortest path.

## Screens & UI
Title screen (Continue / Level select / Randomizer / Skins / Controls / Quit) → game → level-complete message (with any skin unlocked) → next level. Controls screen remaps every action (arrow keys always work too). Esc returns to the title. HUD: slime % (in the skin's color), jump charge meter, level number.

## Build in phases (stop and show me after each)
1. Free gliding movement, goo trail, black map that the trail reveals (with walls next to the trail visible), slime meter, one test maze with the chalice.
2. Charge jump, clean landing vs. wall splat costs, and headless tests for both.
3. Varied wall and floor tile sets (damage levels, autotiling), maze generator, 10 levels with difficulty scaling, solvability test, save file.
4. Full slime sprite set and animations.
5. Skins, palette-swap shader, unlock flow, and the post-game color wheel with luminescence.
6. Title, level select, pause menus, and polish (screen shake on splat, sounds if possible).
