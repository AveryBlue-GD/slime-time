# Comparables, itch.io positioning and "feels professional" for Slime Time

Advisor report, 2026-10-12. Scope: comparable small games, what separates amateur from pro presentation, a ranked polish budget and a playtest plan.

**Source honesty.** Items tagged **[F]** come from a page I fetched or a search result this session (URL given). Items tagged **[K]** are from my general knowledge of the game and I did not re-verify them now. Most "best practice" web sources are indie-marketing blogs, not data; where a number is repeated across blogs it may be one origin copied. I found no hard first-minute drop-off data anywhere. Nothing here is copied from a source; all is paraphrased.

## 0. Where Slime Time stands (from CLAUDE.md, game-design.md, handoff.md)

Strengths that are already above the typical jam game: a single palette-driven pixel look (320x180, 16x16 tiles, `PAL`), a generated pixel font with goo drips, goo-framed UI, a goo-wipe transition, 10 themed levels with their own tiles/fog/ambience, skin-tinted text, a hub room, records and a NEW RECORD banner, hard mode, save codes, touch controls, web build. That is a lot of cohesion.

Weak points relevant to this report:
- **The itch page and promo images are stale** (v2.2 images, old tagline with "!"; handoff). The page is the first thing 95% of visitors see, and it is the cheapest place to look pro.
- **Hat system is "COMING SOON" in normal play**, and hat wheel spins are dev-only. Visible placeholder features read as unfinished on a store page and in the first minutes.
- **Web is the main shop window** (friend on Android hit a blank hub; fix unconfirmed). A pro feel on web = loads, shows something fast, sound starts after a click, works on phones.
- Systems breadth (hub, hats, skins, jelly, hard mode, rainbow, randomizer) is large for a game whose core is "one-minute glide through fog". Risk: the first 60 seconds must be the core, not the hub.

## 1. Comparable games (24)

Grouped by what they teach us. "Takeaway" = what Slime Time should copy or avoid.

### A. Dark / light-and-fog maze games (closest in mechanic)

1. **The Fog (MundanePixel, 2 Minute Horror Game jam)** [F: https://mundanepixel.itch.io/the-fog]. Pixel dungeon maze where fog closes in; tags maze, fog, dark, pixel art; session "a few minutes"; name-your-price; one devlog entry ("I fixed the ending"); five screenshots. Visual: fog as the antagonist. Mechanic: tiny, one idea. Presentation: complete metadata (session length, inputs, engine). Comments praised the look and wished torches showed as small points of light through fog. Takeaway: our fog glimmers (coins twinkling through fog) answer exactly this wish; show it in a GIF. Also: declare "session length: a few minutes" in the sidebar.
2. **Dimlight (Phillips et al.)** [F: https://ianjhphillips.itch.io/dimlight]. Goblin, lantern with fuel and adjustable intensity, ghosts. Good: one-paragraph mechanic pitch, short controls list, size and version shown, install steps. Weak: thin description, dead "More information" link, no GIF, Windows-only. Takeaway: even decent concept pages leak credibility with dead links, no win condition stated, unnamed executables. Light as a spendable resource is the same tension as our slime meter.
3. **Moths to a Flame (duckduckgrem, Pixel Game Jam 2022)** [F: https://duckduckgrem.itch.io/moths-to-a-flame]. Night maze; your lantern guides you but also attracts creatures. Good: the "light helps and hurts" tension is stated in one line; browser-playable; audio credits listed. Weak: no goals/loss explained, state "In development" yet jam-finished. Takeaway: a one-line tension statement sells; web play removes friction. Idea for us: the trail helps you see but costs slime, which is the same trade-off, say it that way.
4. **Lightscape (kent-cream-jackets)** [F: https://kent-cream-jackets.itch.io/lightscape]. Pitch-dark pixel maze, three characters with different light, lantern freezes enemies, glowstick, compass, batteries. Good: page sections with an illustration per item (Characters, Items, Maze), atmospheric tag, comments praise art and atmosphere. Weak: no platform/controls/price, .rar download, captionless images, undefined "firefly". Takeaway: sectioned page with one image per concept reads pro; undefined items and archive formats read amateur.
5. **Dark Maze (kasoof, 1-Bit Jam)** [F: https://itch.io/jam/1-bit-jam-wow/rate/2224965]. Maze with monsters where you only see shadows. Ranked 450/542 with 3 ratings; the best category was the 1-bit graphics fit (4.3), and a rater praised "so much with so little" and tension. Takeaway: a strong constraint carries a look, but a thin loop scores middling; visuals alone did not rank it.
6. **Slime's Light (Werxzy, 1-Bit Jam, Pico-8)** [F: https://itch.io/jam/1-bit-jam-wow/rate/2222900]. Light-and-shadow puzzle with a slime-themed title; 24th overall of the jam's entries; commenters praised each new mechanic being taught without tutorial text, and said some level layouts were unclear. Takeaway: teach by level design, not text; confusion is about level clarity, which is also our risk with a fogged map.
7. **Into the Mist (throns, devlog)** [F: https://throns.itch.io/into-the-mist/devlog/733022/devlog-presentation-and-graphics]. Fog of war faked with a camera vignette; thin devlog on presentation. Takeaway: a vignette is the cheap fog; we already do far more (drifting noise mist, dithered edges, stepped fade). Our devlog should show the contrast with a before/after GIF.
8. **Shattered Pixel Dungeon (Evan Debenham)** [F: https://shatteredpixel.com/blog/shattered-pixel-dungeon-v050.html via search summary]. Open-source roguelike with a long solo-developer devlog run; a v0.5 art update added raised walls, characters standing on the floor, drop shadows, and an optional faint tile grid. Takeaway: years of small, visible, well-explained updates build trust; depth cues (shadow under the character) are a high-value, low-cost pro tell. We already ship a floor shadow on grounded frames.
9. **Darkest Dungeon (Red Hook)** [K]. Torch light level changes risk and rewards; heavy art direction, one strong visual identity (ink, desaturated reds). Takeaway: a single resource (light) tied to a visible meter, plus restraint in palette, makes tension legible. Our slime meter already does this.
10. **Don't Starve (Klei)** [K]. Hand-drawn look, a day/night darkness mechanic where darkness kills; strong UI cohesion and a distinctive title/menu. Our hub is explicitly Don't Starve-style (front/side/back station views), so this is a stated influence. Takeaway: ensure the hub does not outshine the core loop.

### B. Slime / blob protagonists

11. **Slime-san (Fabraz)** [F: interviews and reviews via search; https://nintendowire.com/news/2017/08/16/review-slime-san/ listed]. Pixel-art platformer; reviewer describes a five-colour restricted palette used for hazard/safe readability, which lets the game skip long tutorials; 100 levels from 400 small rooms; a chasing acid wall for pressure; team of three working full time; mechanics (dash, slow time) build puzzle-like routing. Takeaway: palette discipline doing gameplay work, and short chained rooms with fast retry. Our palette-tinted skins and per-theme fog colours are the same instinct; keep hazards (walls vs trail vs chalice) readable first.
12. **Slime Mama (Ludum Dare 46)** [F: https://rawg.io/games/slime-mama]. Retro pixel platformer, tags funny, short, physics, slime; playable on web; "feed the slime" premise. Takeaway: a one-line comedic premise plus web play is the standard shape of a jam hit; our tagline ("Escape the fog or dry trying") is in that tradition.
13. **Slime Rancher (Monomi Park)** [K]. 3D, but a masterclass in slime charm: squash, bounce, big expressive sounds, soft colour. Takeaway: the slime's motion and sound carry personality; we have squash/stretch frames and wet sounds, so make them the star of every GIF.
14. **Noita (Nolla Games)** [K]. Physics of goo and liquids as spectacle; GIF-friendly because the simulation produces unique moments. Takeaway: our goo trail reveal, splat shake and wall stains are our "unique moments"; capture them in GIFs, not static shots.

### C. Short-session arcade-puzzle / maze

15. **Tomb of the Mask (Happymagenta / Playgendary)** [F: https://en.wikipedia.org/wiki/Tomb_of_the_Mask via search]. 2016 pixel maze arcade-puzzle; store text sells "retro pixel art and 8-bit mazes"; Map mode of increasing stages plus an Arcade mode with rising lava. Takeaway: a pixel maze with a pressure mechanic (lava; our slime meter), two modes (story + arcade; our story + randomizer), and a one-sentence pitch. Also shows maze games can monetise on mobile.
16. **Minit (Nijman, Calis, Kallio, Johann)** [F: https://www.mcvuk.com/a-digital-memento-mori-how-minit-celebrates-life-every-60-seconds/]. Self-imposed two-colour art and 60-second lives treated as the framework for the whole design; team avoided a sequel because the format suits only one-minute ideas. Takeaway: constraints define identity. Our constraint "pitch black plus one goo palette" is already ours; protect it from feature creep. A short-run loop (restart is cheap) is the retention engine.
17. **Hoplite (Magma Fortress)** [F: search summary of reviews, e.g. https://indierpgs.com/2014/12/old-release-hoplite/]. Began as a seven-day roguelike contest entry; minimal visuals but dense and readable, few enemy types, each floor a few minutes. Takeaway: readability beats ornament; a game jam core can become a polished product by tightening, not expanding.
18. **Downwell (Ojiro Fumoto)** [K for design; search found no palette source]. Very limited palette per theme, vertical short runs, extremely GIF-able. Takeaway: a per-theme palette (we have 10 themes) plus short runs makes a coherent series. I could not confirm the "three colours" claim, so do not cite it.
19. **Super Hexagon / Vampire Survivors / Celeste** [K]. Different genres but the shared lesson: instant restart, a first few seconds that are all gameplay, and almost no menu friction. Vampire Survivors also shows a very simple look can sell when the loop is addictive and the store page shows the chaos.
20. **Mini Metro** [K]. Extreme restraint: flat colours, clean UI, ambient sound reacting to play; looks premium because nothing is off-style. Takeaway: restraint is the cheapest "pro" signal; we should cut anything that is not in the palette or font system.

### D. Jam hits and their page / devlog habits

21. **Ludum Dare / itch jam entries as a class** [F: itch devlog and post-jam advice from https://bugnet.io/blog/what-to-do-after-a-game-jam-ends and https://itch.io/post/1946151 style threads]. Common pro-leaning pattern: web-playable, 2-4 sentence pitch, controls listed, GIF at top, rate-for-rate community effort. Post-jam sorting of feedback into confusion / boredom / delight is a cheap analysis method.
22. **Signal Remnant (typetree) devlogs** [F: https://typetree.itch.io/signal-remnant/devlog/1009381/devlog-7-fog-of-war-poi]. A small game documenting fog-of-war visual polish as its own devlog. Takeaway: fog is a devlog-worthy topic with an audience; we can post "how our fog works" with GIFs.
23. **GDevelop / Pixel Game Jam entries such as Moths to a Flame** [F, see #3]. Shows that engine is irrelevant to perceived quality; the page sells.
24. **Little Nightmares / Limbo / Inside style dark atmospheres** [K]. Silhouette and fog carry tone with minimal detail; sound design does half the work. Our ambience beds and distant one-offs per theme are the same lever.

Pattern across these: the ones that feel professional have (a) one dominant constraint, (b) the pitch in one line, (c) a readable first screen, and (d) a page that shows motion. The ones that feel amateur are mostly page failures (dead links, undefined features, missing controls/price), not art failures.

## 2. What we do well vs comparables (visual, mechanical, presentation)

| Axis | Comparable bar | Slime Time |
|---|---|---|
| Visual cohesion | Slime-san, Mini Metro: one palette doing work | Strong: `PAL`, goo-shade skin swap, 10 theme atlases, tinted font |
| Light-as-resource | Dimlight, Darkest Dungeon | Strong and unique: trail IS the light, meter IS the cost |
| Juice | Vlambeer talk (shake, hit pause, camera kick) [F: https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects] | Splat shake, bursts, squash/stretch; check hit-pause and landing impact |
| UI | Cohesive frames, no raw defaults | Goo frames, pixel font, goo wipe: above average |
| Page/store | Sectioned, GIFs, dead-link free | Stale |
| Onboarding | Teach by level (Slime's Light) | Unknown: needs playtest |

## 3. Amateur vs pro: the working list

Ranked by how much each separates the two in small indie games (opinion synthesis; the cohesion/restraint/placement-of-effort points are repeated in [F: https://bugnet.io/blog/art-direction-beats-art-budget] and the wayline polish articles found in search, which are promotional blogs, so weigh accordingly).

1. **Cohesion.** One palette, one font, one frame style, one sound character. Mixed asset styles read amateur regardless of individual quality. Ours: mostly cohesive; audit for stragglers (placeholder hats, any default Godot control, any off-palette icon).
2. **Restraint.** Fewer elements, each finished. Hide COMING SOON features rather than show them (hats, wheel spins). A visible dead end is the commonest "unfinished" tell.
3. **Consistency of feedback.** Every action answers with sight + sound + motion, same scale across screens. Button click sound exists; check every interactive thing answers.
4. **First 60 seconds.** Straight into playable action with zero reading; first success inside 30 seconds; the fail state is cheap and clear. Our flow is title -> hub -> archway -> level; the hub is a barrier on a first visit (see section 6).
5. **Title screen.** Logo, one primary button, quiet motion in the backdrop, no clutter. Ours is good (gooey logo, slimes, tagline). Reduce first-time choices to one obvious button; consider labeling it PLAY on first launch (or auto-drop a new save into level 1).
6. **Readability at thumbnail size.** Store art and screenshots must communicate genre and mood at tiny size (Steam's smallest capsule is cited as 120x45; itch cover 630x500, 315x250 minimum) [F: https://app.cinevva.com/guides/itch-io-launch-guide, https://presskit.gg/blog/indie-game-marketing-mistakes].
7. **Motion on the page.** GIFs autoplay on hover in itch listings per one guide [F: search result summary]; strong first frame, 5-15 s loop, under about 10 MB.
8. **Complete metadata.** Controls, input, session length, price, platform, version, accessibility, contact. Missing metadata is the commonest amateur signal in the itch pages I fetched (#2, #3, #4).
9. **No dead ends or placeholders**: dead "More information" links, "in development" labels on a finished jam game, undefined items.
10. **Audio polish.** Ambience, quiet UI sounds, no clipping; web audio needs a click gate.
11. **Technical hygiene**: loads fast, no console errors, no blank screen on a phone, fullscreen works.
12. **Voice**: a consistent, short, confident copy tone (tagline, button words, notices). Ours is distinctive (ESCAPE THE FOG / OR DRY TRYING).

What does NOT separate them much: resolution, animation frame counts, particle quantity, feature count.

## 4. Store and page checklist (itch first; Steam notes if ever)

Sizes/specs from third-party guides [F: https://app.cinevva.com/guides/itch-io-launch-guide]; verify against itch's own docs before final upload.

**Cover (630x500, keep 315x250 legible).** One focal point: the slime lit against fog with the chalice glow in the distance, the title in the goo logo, no extra text. Test at 30% and at 315x250. Use the lime default skin for brand consistency (it is the starter; a skin-per-screenshot rule already exists in CLAUDE.md).

**First-frame-matters GIF (5-15 s, under about 10 MB, loops).** Needed GIFs, in priority order:
1. Glide revealing a corridor with the trail lighting up + a fog glimmer twinkling over a coin (the unique hook).
2. Charged leap -> splat on wall (shake + goo stain), the "oops" moment.
3. Slime meter nearly empty -> chalice reached (tension payoff).
4. The hub room turning (shows the world and charm).
5. Skins / jelly translucency.

**Screenshots (4-6, same aspect ratio; first 3 must sell the game).** Order: lit corridor in fog (hero), leap + splat, a different themed level (Frozen Fortress or Volcanic Vault) to show variety, hub, skins/upgrade screen, hard mode HUD. No menus first. No debug text. No dev-mode overlays. Per CLAUDE.md, each level's own first-run skin.

**Pitch (short description).** Lead with the hook and the tension in 2 sentences, e.g. concept: "A slime in a pitch-black maze. Your goo trail is your only light, and every step dries you out." Then a short feature bullet list (10 themed mazes, hard mode, skins and jelly, randomizer, no ads), controls, session length ("a level takes 1-3 minutes", measure it), save code note, a "Play in browser" call.

**Tags.** Use specific tags (not "action"): maze, pixel-art, atmospheric, dark, fog, puzzle, casual, singleplayer, short, 2D, relaxing (if playtests agree), plus slime. Use the genre that matches screenshots. Fill the engine (Godot), input (keyboard, gamepad if any, touchscreen), accessibility and language fields. Add "Short" with an honest play-time line.

**Platforms.** Web (HTML5) first as the embed (960x540 or 16:9 native 1280x720 scaled; enable mobile-friendly and fullscreen button; no scrollbars) [F: itch launch guide]; Windows build second. Mark web as the primary download so first click is play.

**Pricing.** itch treats any paid item as pay-what-you-want with the price as the minimum; "$0 or Donate" lets people skip payment [F: https://itch.io/docs/creators/pricing]. itch's own 2015 post says about 30% of money spent is above the minimum [F, same page; dated and self-reported]. A third-party guide suggests $2-5 for under 30 minutes of content [F: itch launch guide; a heuristic, not data]. Our volume of content (10 levels + hard + randomizer + hub) is big for the price. Recommendation: free web build with "$0 or Donate" and a suggested $3, optionally a small paid desktop build ($2-3 PWYW, minimum $1) with a note that the web version is the full game. Do not charge before the page is polished; a $1 minimum may look less credible than PWYW per one anecdotal forum comment (unverified).

**Devlog.** Posts appear in followers' feeds and the global devlog feed [F: https://itch.io/updates/introducing-devlogs.amp]. Cadence guidance in the sources I found is blogger opinion (weekly in one, 1-2 per month in another); pick what we can sustain and never promise more than that [F: https://www.wayline.io/blog/ultimate-guide-devlogs-indie-games, itch launch guide]. Structure: one-line recap, GIF, how/why, one question to the reader. Good topics unique to us: how the fog and trail reveal work; the 2 px reveal grid with stepped fade; generating 10 themed tile sets from Python; the Android WebGL bug (arrays indexed at run time) and its fix, which is a genuinely useful post for Godot users; hub room shader; the pixel font with shader drips.

**Community / feedback loop.** Short "what did you think of the first level?" prompts; reply to every comment in the first week; rate-and-comment on other entries in jams; add a visible "Report a bug / feedback" link (itch comments or a form). Do not spam; post in relevant itch/Godot/pixel-art communities with a GIF, once per milestone.

**Web demo discipline.** The web build is the demo. Needs: a click-to-start gate (browsers block autoplay audio until interaction; community-reported pattern [F: godot web export search]); small payload (downscale oversized textures, compress audio; other search results report texture size is the main payload driver [F]); itch does not offer transparent gzip/Brotli, per one forum answer [F, unverified]; Chrome is the best-tested browser, Safari has WebGL 2.0 quirks per official docs [F]; test on a real Android phone (the open handoff task).

**Trailer (optional, later).** If made: 30-60 s, gameplay in the first 5 seconds, no logo card up front, edit to the music, end on the chalice and the page call to action; this matches the Steam-page guidance repeated across blogs [F: https://www.gamedeveloper.com/business/a-beginner-s-guide-to-designing-indie-game-store-pages].

## 5. Polish budget: what to do first with limited time

Ordered by (visible pro-ness per hour). Each item cites the evidence and our constraint.

**Tier 0: free or under an hour (do now)**
1. **Fix page text and links.** New tagline without "!", pitch, controls, session length, tags, no dead links. (Amateur tell #8/#9.)
2. **Hide placeholders.** Hide or remove the HATS button and the wheel's COMING SOON text outside dev mode (or ship 3-4 real hats). Do the same for any locked-with-no-date teasing. (Restraint.)
3. **Confirm the Android fix on a real phone and the paste fix on itch**; if the page fails, nothing else matters. (Hygiene.)
4. **Click-to-start web gate** with the logo, so audio and fullscreen work and the first frame is the title, not a blank. (Web hygiene.)

**Tier 1: first 60 seconds (highest payoff, 1-3 days)**
5. **Fresh-save flow**: on a brand-new save, skip the hub and drop the player straight into level 1 with the controls shown as small in-world hints (arrow/WASD, hold SPACE to charge). Offer the hub after the first win ("HUB" button already exists). Verify the first splat is survivable and explained by the level, not text. Uses existing `Progress` flags.
6. **Level 1 and 2 as tutorials**: make the first leap opportunity obvious; the chalice glow visible early (a faint glow through fog) so the goal is clear within seconds. Slime's Light shows teaching by layout earns praise.
7. **One-line win/lose feedback**: the dry-up -> RESTART should be near-instant (<1 s) with the cause obvious. Instant retry is the retention loop in Minit/Hoplite-style games.
8. **Audit the title**: one primary action, quiet backdrop motion, no clutter; the version number small.

**Tier 2: the store assets (1-2 days; the user must ask for promo renders per CLAUDE.md)**
9. Cover (hero lit slime), 5 screenshots, 3 GIFs (trail + glimmer; leap + splat; chalice finish). Re-render only when the user asks "get this ready for itch".
10. Upload the new web zip; mark it the main download.

**Tier 3: feel (1-3 days)**
11. **Hit pause on splat**: freeze 3-6 frames (about 50-100 ms; range is a rule of thumb from a course page, not Vlambeer's number [F]). Keep screen shake small. Only if testers say splats feel soft.
12. Landing and chalice reward: a tiny scale pop and a rising sound; the NEW RECORD banner is already good.
13. Sound audit: no UI sound missing, no clipping on web, ambience faint (user preference).

**Tier 4: depth cues and trust (as time allows)**
14. A short, honest devlog (the Android shader bug post is the strongest).
15. A feedback link and a changelog on the page.
16. Real hats or remove them; decide the wheel currency or hide the wheel.

**Do not spend time on (yet):** more themes, more skins, more upgrades, a new hub station, a trailer, Steam page, extra languages, shader effects. They add breadth, not pro feel. Also avoid new shaders with run-time-indexed arrays (Android WebGL).

**Risks to feel:** hit pause and shake can nauseate if overdone (one course source warns big shake is bad [F]); a fresh-save skip of the hub may disappoint users who liked the hub, so keep the hub reachable at once after level 1; hiding hats loses nothing today since they are unavailable.

## 6. Playtest plan

Goal: find where new players get lost or bored in the first 5 minutes, and whether the fog/trail idea is understood without text. Method choices are practitioner advice, not research [F: https://www.wayline.io/blog/indie-dev-playtesting-usability-testing, https://bugnet.io/blog/how-to-playtest-your-game-and-learn-from-it].

**Who/how many.** 5-8 people who have never seen the game, in two groups: (a) non-gamers or casual gamers, (b) people who like pixel indies. Include at least 2 phone players on the web build (touch controls, rotate hint) and 1 Mac/Windows desktop player. Aim 5 at a time, fix, repeat. One issue blocking several testers outranks a one-off quirk.

**Setup.** Give them only the itch link or a fresh build, no explanation. Ask them to think aloud; sit behind and to the side; do not rescue them; if remote, ask for screen + face recording. Build stable, 15-30 minutes. Write 1-2 concrete questions per session. Use a fresh save and the real web build.

**What to observe/measure (behaviour over opinion).**
- Time to first movement; time to first leap attempt; time to first level clear (target: first clear under about 3 minutes).
- Whether they discover the trail is the light; whether they discover leaping and charge; when and why they press Esc/R.
- Deaths per level (L1 to L3); retries before first win; quit point (the minute they stop).
- Where they hesitate (more than about 5 seconds standing still), re-read, or mash.
- Splat frequency vs clean landings (is leaping read as a skill or a trap?).
- Hub: do they find the archway without help; how long do they wander; do they open skins/upgrades unprompted.
- Comprehension: can they say what the slime meter and coin counter mean afterwards.
- Technical: load time, blank screens, audio start, fullscreen, any console errors (browser F12).
- Phone: thumb comfort, joystick snap, JUMP reach, rotate hint, battery/heat.
- Afterward optionally: do they ask to play another level (the best retention signal).

**Questions to ask after (open, no leading).**
- "Tell me what the game is, in your own words."
- "What was your goal? What were you trying to do right before the first time you got stuck?"
- "What did the glowing trail do? What did the blue/green bar do?" (use our actual HUD terms)
- "Which moment felt best? Which felt worst or confusing?"
- "What would you tell a friend it's like?" (positioning: maps to comparable games)
- "What did you think the hub was for?"
- "Would you play another level? Why / why not?" (not "was it fun?")
- "How did the sound feel? Anything too loud, wet or repetitive?"

**Analysis.** Sort findings into confusion / boredom / delight [F: bugnet post-jam advice], then into usability, comprehension and balance. Fix the top 3 blockers before the next round. Keep a simple table: tester, device, time-to-first-clear, deaths, quit point, quotes.

**Cheap instrumentation (optional, later).** A local-only event log (level start/clear/dry-up, leap/splat counts, time) written next to the save, printed under a debug flag; testers can paste it. Do not add network telemetry without consent and a privacy note.

**Success criteria (suggested, not from a source).** 4 of 5 new players clear level 1 without help; median time to first clear under 3 minutes; at least 3 of 5 want a second level; no player has a blank or silent web start; zero dead links on the page.

## 7. Prioritised recommendations (impact vs effort)

| # | Action | Impact | Effort | Risk |
|---|---|---|---|---|
| 1 | Refresh itch text, tags, controls, session length, remove stale tagline | High | Low | None |
| 2 | Real-phone check of Android shader fix + paste fix | High | Low | Unknown results |
| 3 | Hide placeholder hats/wheel COMING SOON in normal play | Med-High | Low | None |
| 4 | New-save flow straight into level 1; hub after first win | High | Low-Med | Changes the user's intended hub-first flow; check with the user |
| 5 | Web click-to-start gate with logo | Med | Low | None |
| 6 | Playtest round 1 (5 people) | High | Med | None |
| 7 | Cover + 5 screenshots + 3 GIFs (only when the user asks) | High | Med | None |
| 8 | Devlog 1: fog/trail; devlog 2: Android shader bug | Med | Low-Med | None |
| 9 | Hit pause on splat, if testers say it's soft | Low-Med | Low | Overdone shake |
| 10 | PWYW pricing decision | Low-Med | Low | Pricing perception |

## 8. Sources

Fetched or surfaced this session:
- https://mundanepixel.itch.io/the-fog
- https://ianjhphillips.itch.io/dimlight
- https://duckduckgrem.itch.io/moths-to-a-flame
- https://kent-cream-jackets.itch.io/lightscape
- https://itch.io/jam/1-bit-jam-wow/rate/2224965 (Dark Maze)
- https://itch.io/jam/1-bit-jam-wow/rate/2222900 (Slime's Light, via search summary)
- https://rawg.io/games/slime-mama
- https://throns.itch.io/into-the-mist/devlog/733022/devlog-presentation-and-graphics
- https://typetree.itch.io/signal-remnant/devlog/1009381/devlog-7-fog-of-war-poi (via search listing only)
- https://www.mcvuk.com/a-digital-memento-mori-how-minit-celebrates-life-every-60-seconds/
- https://en.wikipedia.org/wiki/Tomb_of_the_Mask (via search summary)
- https://nintendowire.com/news/2017/08/16/review-slime-san/ and Slime-san interview links (via search summary; the interview page itself returned 403)
- https://shatteredpixel.com/blog/shattered-pixel-dungeon-v050.html (via search summary)
- https://indierpgs.com/2014/12/old-release-hoplite/ (via search summary)
- https://itch.io/docs/creators/pricing
- https://itch.io/blog/2/running-an-indie-game-store-2015 (via search summary)
- https://itch.io/updates/introducing-devlogs.amp (via search summary)
- https://app.cinevva.com/guides/itch-io-launch-guide
- https://www.gamedeveloper.com/business/a-beginner-s-guide-to-designing-indie-game-store-pages
- https://unity.com/blog/tips-strategies-for-marketing-indie-games, https://presskit.gg/blog/indie-game-marketing-mistakes, https://www.steampageanalyzer.com/blog/steam-store-page-mistakes (via search summaries; vendor claims)
- https://www.wayline.io/blog/ultimate-guide-devlogs-indie-games, https://www.wayline.io/blog/indie-dev-playtesting-usability-testing, https://bugnet.io/blog/how-to-playtest-your-game-and-learn-from-it, https://bugnet.io/blog/art-direction-beats-art-budget, https://bugnet.io/blog/what-to-do-after-a-game-jam-ends (blogs; opinion)
- https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects (screenshake recreation, via search summary)
- Godot web export forum/guide results (via search summary; unverified community claims)

Items tagged [K] (Darkest Dungeon, Don't Starve, Slime Rancher, Noita, Downwell, Super Hexagon, Vampire Survivors, Celeste, Mini Metro, Limbo/Inside) are from general knowledge only; I could not verify a Downwell palette claim, and I found no hard first-minute drop-off data.
