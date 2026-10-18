# Tutorial research: how good games teach without stopping the game

Research for the training maze and the first hub visit ([design.md](design.md)). Written 2026-10-18 by the
tutorial-designer agent. Each point says where it came from: **[fetched]** = the page was read or a search result
quoted it; **[general]** = widely known design lore that I did not check against a source this session (treat it as
a prior, not a fact).

## 1. What the sources say

### Portal (Valve): one tool at a time, then layer them; playtests find the gaps
- Portal is "introducing a series of gameplay tools, then layering these tools into increasingly difficult
  puzzles" (Robin Walker, developer commentary). **[fetched]**
- The first portal room is "a visually unique room with memorable objects", so players have something to look
  back at when they step through, and the first portal is placed so players "will invariably see themselves"
  (Kim Swift). **[fetched]**
- Playtesters "would charge down the stairs without noticing" what made the portals, so the team added a
  short forced pause that points at it (Jason Brashill, chamber 02). **[fetched]**
- Early chambers generally have one correct answer so they teach that one thing; a glass wall went in to block
  an unintended shortcut (Chet Faliszek, chamber 04). Two extra chambers went in before the energy-ball room
  "to make the ... training more gradual" (Chris Chin, chamber 08). **[fetched]**
- Late in the game the visual hints are taken away so players must use the skill on their own (chamber 15).
  **[fetched]**
- Source: [Portal developer commentary (Portal Wiki)](https://theportalwiki.com/wiki/Portal_developer_commentary);
  also [Best of GDC: The secrets of Portal's huge success](https://www.gamedeveloper.com/pc/best-of-gdc-the-secrets-of-i-portal-i-s-huge-success).

### Super Meat Boy: the layout is the lesson; restarts are instant
- In world 1-1 you can't reach the middle platform in one jump, and missing it shows you how high you can jump.
  ([Alexi Irpan](https://www.alexirpan.com/2016/05/22/may-22.html)) **[fetched]**
- Levels usually offer one path and are built to make the learning quick
  ([Game Developer: Making Meat Boy Move](https://www.gamedeveloper.com/design/making-meat-boy-move)).
  **[fetched]**
- The instant restart keeps players practising a hard section instead of quitting
  ([Game Developer: Untold riches, level 5-3](https://www.gamedeveloper.com/design/untold-riches-super-meat-boy-level-5-3)).
  **[fetched]**
- **Takeaway for us:** a failure that costs seconds, not minutes, teaches rather than punishes. A Slime Time
  dry-up already offers RESTART after 0.25 s (`game.gd` `DRY_CHOICE_DELAY`).

### Celeste: low-cost failure, mechanics built up one by one, a moment of need
- Each new mechanic builds on the ones before, and dying only sends you back to the start of the screen, so
  failing costs little and becomes part of learning
  ([Notre Dame Kaneb Center blog](https://sites.nd.edu/kaneb/?p=2457)). **[fetched]**
- The Prologue teaches move and climb, then teaches the dash just as Madeline is about to fall into a chasm:
  the button prompt arrives when it is needed
  ([Celeste Wiki](https://celestegame.fandom.com/wiki/Celeste)). **[fetched]**
- Some players say parts of the layout teaching are unclear: a mechanic taught only by layout can be missed
  ([RAWG reviews](https://rawg.io/games/celeste/reviews), one reviewer, repeated). **[fetched]**
- **Takeaway:** show a prompt at the moment of need (at the long straight, not at the start), and back up layout
  teaching with a small glyph for anyone who misses it.

### Mega Man X intro stage (Sequelitis): teach through play and feedback, not on-screen prompts
- Egoraptor's well-known video argues for teaching "through gameplay and subtle feedback rather than through
  obtuse tutorials and on-screen prompts"; the intro stage is mostly a straight line from A to B that brings in
  the wall jump ([TV Tropes: Sequelitis](https://tvtropes.org/pmwiki/pmwiki.php/WebVideo/Sequelitis),
  [MM Network](https://themmnetwork.com/2011/11/01/sequelitis-takes-on-mega-man-and-mega-man-x/)). **[fetched]**
- A forced loss in a tutorial (the Vile fight) can feel arbitrary when nothing the player does changes it (TV
  Tropes' critique). **[fetched]**
- **Takeaway for the dry-up:** if the first attempt is built to run dry, it must feel like the player's own
  choice (they went for the coin) and must be easy to recover from. It must never feel like a cutscene that
  pretends to be play.

### Baba Is You: early levels explain the one idea; then the player is on their own
- The early levels "do a tremendous job at explaining the concept" before the difficulty rises
  ([davidyat.es review](https://davidyat.es/2021/03/27/review-baba-is-you/)). **[fetched]**
- Teikari starts each level from one interaction and builds the level around it; much of testing went into
  removing unintended solutions
  ([MCV: When we made Baba Is You](https://mcvuk.com/development-news/when-we-made-baba-is-you/),
  [Red Bull interview](https://www.redbull.com/ph-en/baba-is-you-interview)). **[fetched]**
- **Takeaway:** each beat of the training maze is built round one interaction (glide, leap, coin, dry-up,
  chalice), and the tests check that no shortcut skips a beat by accident.

### Hollow Knight (King's Pass), Dead Cells (Prisoners' Quarters): the tutorial is a real place in the world
- King's Pass is a short opening area that teaches movement, combat, soul and benches, with one lore tablet
  explaining Focus ([holdtoreset guide](https://holdtoreset.com/hollow-knight-kings-pass-guide/),
  [Fextralife walkthrough](https://hollowknight.wiki.fextralife.com/Walkthrough)); Team Cherry presents it as
  the "introduction to the world"
  ([Team Cherry blog](https://teamcherry.com.au/blog/kings-pass-and-fan-art-compilation)). **[fetched]**
- Dead Cells' first biome doubles as the tutorial and brings enemies in gradually; the start area holds the
  Training Room door ([Dead Cells Wiki](https://deadcells.wiki.gg/wiki/Prisoners%27_Quarters)). **[fetched]**
- **Takeaway:** the training maze should be a place in Slime Time's story (the puddle the slime splats into
  at the end of the intro), not a menu screen. That fits D1: the intro ends on the slime alone in the dark at the
  very bottom of the dungeon.

### Hades (House of Hades): the hub is taught over time
- Searches found guides, not Supergiant's own words: the House is the hub you return to after each run, and new
  systems are brought in gradually across runs
  ([Prima guide](https://primagames.com/gaming/hades-beginners-guide-and-tips),
  [Wayline on onboarding](https://www.wayline.io/blog/tutorials-onboarding-ux-retrospective)). A review of Hades II
  points out how hard a currency upgrade was to find with no hint in the game
  ([Digital Trends](https://uat4.www.digitaltrends.com/?p=3592802)). **[fetched, secondary]**
- **[general]** Hades brings in each hub station when it first becomes useful, through a character line, rather
  than with a tour.
- **Takeaway:** our hub tour should be one line per station and over in well under a minute. A station that
  isn't usable yet (RANDOMIZER is locked) gets one honest line saying so.

### Don't Starve: rotation is the unusual control
- Q / E turn the camera 45 degrees (pad: bumpers), and some players find the default direction backwards and
  rebind it ([BisectHosting controls guide](https://www.bisecthosting.com/es-es/blog/dont-starve-together-controls-guide-pc-controller-playstation-xbox-switch),
  [Klei forum](https://kleiforums.com/forums/topic/136995-rotate-settings-suggestion/)). **[fetched]**
- **Takeaway:** turning the hub is the one hub control that new players won't guess, so it is taught first and
  by doing (hit the wheel), and the line says which way it turns.

### Vampire Survivors: so few inputs that no tutorial is needed
- After the menus the game is the move stick plus one button, and weapons fire on their own
  ([Games Asylum](https://www.gamesasylum.com/2022/11/25/vampire-survivors-review/),
  [God is a Geek](https://www.godisageek.com/reviews/vampire-survivors-review/)). **[fetched]**
- **Takeaway:** Slime Time is nearly that simple (move + one leap button), so the tutorial must stay short.
  Its only unusual rules are that moving costs slime and that leaping is cheaper but leaves no trail.

### Mobile first-session (FTUE) practice
- Trash Tycoon: about a minute of unguided play confused players and raised churn; bringing mechanics in too
  fast lost 60% of players during the tutorial. The fix was gradual, linear steps with clear goals. Measure
  where players drop off; removing a single step can change retention
  ([Supersonic: Optimizing FTUE](https://supersonic.com/learn/blog/optimizing-ftue/)). **[fetched; vendor data]**
- Let returning players and genre veterans skip; mandatory tutorials can backfire; give small rewards without
  flooding currency ([MAF: FTUE mistakes](https://maf.ad/en/blog/ftue-mistakes/),
  [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/first-time-user-experience)). The cited
  Nielsen Norman result (people who skipped a tutorial did as well) is second-hand. **[fetched, secondary]**

## 2. Principles for Slime Time (drawn from the above)

1. **One interaction per beat**, in a line, with one obvious path (Portal, Baba, Meat Boy). No beat relies on
   the beat after it.
2. **Prompt at the moment of need** (Celeste's dash): the leap glyph appears at the long straight, the restart
   glyph at the dry-up row, the turn glyph next to the wheel.
3. **Failure is cheap and honest** (Meat Boy, Celeste): the first dry-up comes from the player's own choices,
   costs about 20 seconds, keeps the coin (true in the real game), and RESTART is one press.
4. **The tutorial is a place in the story** (King's Pass, Prisoners' Quarters): the puddle under the Dark
   Dungeon, straight after the intro's splat.
5. **Wordless in the maze, a few short lines in the hub.** The intro is wordless and the existing cues are
   keycaps. The hub has nine named stations, so a line each is the cheapest way to name them.
6. **Never block a returning player; everything can be skipped** (FTUE sources). Skipping only loses the
   lesson: the level 1-2 cues are still there as a safety net.
7. **Short, measured, and checked in playtests** (Supersonic): about 3 minutes from the end of the intro to
   level 1, timed by a test and a stopwatch playtest, with drop-off points listed for the owner to check.
