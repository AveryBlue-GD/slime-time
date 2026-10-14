# Slime Time

A 2D pixel-art maze game made in Godot. You're a slime in a maze hidden by fog. Your goo trail clears the fog as you glide, but every move costs slime. Find the golden chalice before you dry up! Beat all 10 story levels, then try hard mode and the Randomizer, where a gold ticket is the goal.

## How to play it

1. Download **Godot 4.7** (free, standard version) from https://godotengine.org/download
2. Unzip this folder somewhere.
3. Open Godot, click **Import**, and pick the `project.godot` file in this folder.
4. Click **Import & Edit**, then press **F5** (or the ▶ button, top right) to play.

## Controls

| Key | Action |
|---|---|
| WASD / arrow keys | Glide |
| Hold Space | Charge a jump (arrows aim), release to leap |
| R | Restart the level |
| Esc or P | Pause (volume, sound, restart, quit). In a browser in fullscreen, Esc exits fullscreen, so use P |
| F11 | Toggle fullscreen |

Keys can be remapped from the hub: **SETTINGS** (the gear signpost) > **CONTROLS**. In the hub, **F** uses the station you stand next to.

### On a phone or tablet

Play the browser version sideways. Touch controls appear automatically:
- **Left thumb:** drag anywhere on the left half to glide (a joystick appears under your thumb).
- **Right thumb:** hold **JUMP** to charge, aim with the joystick, let go to leap.
- **Top-right:** pause.

## Tips

- Jumping costs half as much slime as gliding the same distance, but hitting a wall costs extra. Judge the distance well!
- Areas you've explored slowly fog back over, so remember your way.
- Every level is timed. Your record for each level shows on Level Select; beat it for a NEW RECORD! Clear times also earn bronze, silver and gold medals.
- Story levels hide coins at dead ends. Spend them at the **cauldron** on upgrades (more slime, speed, brightness); finding all 165 is also how you earn the rainbow slime.
- Each level you clear unlocks a new slime color. Beat level 10 for the CHAMELEON color wheel; hard-mode clears unlock solid (non-jelly) versions; 30 gold medals unlock the Stopwatch slime.
- After the story, the **Randomizer** (portal in the hub) builds a new maze from a seed code; the gold ticket voucher at the end pays 5 tickets on a first try, fewer on retries.
- The **map table** in the hub keeps a map of every tile you have seen and your fastest route on each story level.
- Hats are still being designed: the hat wheel says COMING SOON.

## Launching from the terminal (macOS / Linux)

`./tools/play.sh` plays with your real save. `--dev` unlocks everything and saves nothing (F1 = full bright, F2 = no drain in a level; fn+F1 / fn+F2 on a Mac). `--story` starts as a player who has beaten the story. `--autoplay [--speed=N]` lets the game play itself. On Windows use `tools\play.ps1` with `-Dev`, `-Story`, `-Autoplay`. Tests: `./tools/test_all.sh`. More in [CLAUDE.md](CLAUDE.md) and [docs/README-docs.md](docs/README-docs.md).
