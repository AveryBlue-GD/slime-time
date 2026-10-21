# DRY TRYING: marketing kit v1

Written 2026-10-20, synced to `spring-cleaning` at 8046e5e. Sources: docs/marketing/brief.md, trailer.md, music.md, docs/demo-plan.md, docs/advisor/demo.md, the three Short contact sheets. Rules from rules.md apply to every line below (no HEAT, no DESCENT, secret skins only as silhouettes, only brief.md claims, no carry-over promise, COMING SOON until a store link exists).

## 0. Calls I made (change any of them)

- **Level 1 is DARK DUNGEON.** Settled: brief.md now says Dark Dungeon too.
- **Platforms in copy: Windows, macOS, Linux and web.** Phones are not built yet (there's no Android or iOS export preset), so copy says nothing about phones until they exist. Exception: one optional line, "Phones later", on itch.
- **English first.** The game's 17 other languages are switched off, so multilingual posts would send people to an English-only demo (advisor item 7). Translate posts only for the languages that are switched on in the demo.
- **Lead Short: A with music (Fog Pulse).** It explains the game in 2 seconds and asks a question, which drives comments.
- **"Free" has three unavoidable costs:** Steam Direct is $100 per app (the demo needs no extra fee), the Apple Developer Program is $99 a year, and a Google Play account is $25 one time. Everything else here is $0.

## 1. Timeline to Steam Next Fest (Feb 22 - Mar 1, 2027)

Valve's dates: registration closes **Jan 10, 2027**, the demo build is due **Jan 25**, and all items are due **Feb 8** ([Steamworks](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027)). The advisor's research: demos released months early got about 2.5x the median wishlists.

| When | What |
|---|---|
| Now - Nov 1 | **Check the old Slime Time itch page.** If the full game is public there, unpublish it or swap in the demo before any Short drives traffic. Make the accounts with one handle everywhere (e.g. @drytrying): TikTok, YouTube, Instagram, Bluesky, X, Reddit. Pay Steam Direct now (it starts a 30-day wait before any release) and start the store page (capsules, 5+ screenshots, the copy below). Post Short A. |
| Early Nov | **Steam "Coming Soon" page live.** Put its link in `Demo.WISHLIST_URL` and the end cards ("WISHLIST ON STEAM" in the `store` slot). Post every Short from now on with "Wishlist: link in bio". |
| Mid Nov | **itch.io web demo live** (levels 1-3) once the QA must-fixes are done (see ../qa/qa-report.md, section A), especially the HEAT teaser line on the end screen and the phone fullscreen/rotate fixes. It's the landing page for phone viewers: short, loads fast, big Steam button. |
| Early Dec | **Steam demo live** (levels 1-4). Steam notifies wishlisters once, at first launch, so do it after a few weeks of Shorts. |
| By Jan 10 | Register for Next Fest. |
| By Jan 25 | Final demo build uploaded, then **frozen** (no mid-fest changes). |
| Feb 8 | All Next Fest items in (trailer, page polish). Make the horizontal 45-60 s trailer by now (trailer.md "Later"). |
| Feb 22 - Mar 1 | Next Fest: post daily, livestream on Steam if possible, reply to every comment. |

## 2. Shorts: hooks and captions

Post the same video natively to TikTok, YouTube Shorts and Instagram Reels (upload it separately on each, never a watermarked repost). On-screen text stays as rendered; the caption below goes in the post text.

### Short A, "Can you escape before you dry up?" (music cut)

- **A1 (pick):** "Your goo is your light. Don't run dry. 🟢"
- A2: "Every move costs slime. How far can you get?"
- A3: "Pitch black maze. One slime. Don't run dry."
- Pinned comment: "What would you name this slime? 👀"

(I dropped a "no refills" idea: the game has refill effects such as SECOND WIND in `economy.gd:99`, so the claim isn't safe.)

### Short B, "1000+ ways to dress your slime" (music cut, 26.9 s with the ANIMATED HATS beat: the raincloud raining over Lime, the propeller cap spinning on Mint)

- **B1 (pick):** "Which look are you picking? 🎩"
- B2: "13 skins. 12 hats. 1000+ looks."
- B3: "Spin the wheel. Win a hat. Dress your slime."
- B4: "This hat rains. This one spins. 🌧️" (leans on the new ANIMATED HATS beat)
- On-screen fix: the hook wraps to 3 goo lines (trailer.md lists it as a known rough edge). "1000+ SLIME LOOKS" fits on 2 lines and translates more easily. It's a one-line change in `trailer.json`.
- Pinned comment: "Drop your hat + skin combo below 👇"

### Short C, "Beat the story... then the real game starts" (music cut)

- **C1 (pick):** "Beat the story. Then the real game starts."
- C2: "10 levels. Then endless mazes."
- C3: "Chase every gold medal. Unlock the secret skin."
- Checked: the "ALL GOLD = A SECRET SKIN" beat shows only the black silhouette, and "30 medals" matches the code (`stopwatch.gd:4`). Consider adding "30 medals" to brief.md's claim list.

### Hashtags (3-5, no more)

- TikTok: #indiegame #pixelart #gaming #slime #indiedev
- Shorts: #indiegame #pixelart #shorts
- Reels: #indiegame #pixelart #gamedev #cozygames

### Cheap new variants (no new footage)

The whole pipeline is driven by captions in `tools/trailer/trailer.json`, so new hooks are a text edit plus a re-render of about 3 minutes. Hooks to test on the same footage:

- "POV: YOUR LIGHT IS RUNNING OUT"
- "DON'T DRY UP"
- "THIS SLIME LIGHTS THE MAZE"
- "1 SLIME. 10 MAZES." (A's opening beat)
- "WHICH SKIN?" (B's opening beat)

Keep each to 1-2 goo lines.

## 3. Posting schedule (sustainable, $0)

- **Weeks 1-2:** 3 Shorts a week (Mon A, Wed B, Fri C) on TikTok, Shorts and Reels on the same day, around 6-9 pm in the target time zone (start with US Eastern). Note which hook holds viewers past 3 seconds.
- **Week 3 on:** 4-5 a week. Re-cut the best performer with new hooks, then add:
  - "can you beat this?" clips of one level
  - a dev-log clip (how the drippy logo is drawn in code)
  - a "this whole maze was dark" full-bright reveal (`tests/demo_overview.tscn`)
- **Weekly:** one Reddit post (section 6) and one Bluesky/X thread.
- **Douyin, Bilibili and other China channels:** wait until the zh_CN text is switched on in the demo. Douyin generally needs a mainland phone number to sign up. Bilibili or a Chinese-speaking creator partner are the realistic routes.

## 4. itch.io page copy

**Tagline field (pick 1):**
- **I1 (pick):** "Escape the fog before you dry up."
- I2: "A slime, a dark maze, and not enough goo."
- I3: "Light the maze with your trail. Don't run dry."

**Description:**

> **ESCAPE THE FOG. BEFORE YOU DRY UP.**
>
> You're a slime in a pitch-black maze. Your goo trail lights the way, but every move drains you. Find the golden chalice before you dry up.
>
> - Glide, leap and splat off walls
> - 10 themed levels and 165 hidden coins
> - Endless random mazes, hard mode, and gold, silver and bronze medals
> - 13 skins (each with a jelly version), 12 hats, over 1,000 looks
>
> **Free demo:** the intro, the tutorial and the first 3 levels, right in your browser.
> Full game: COMING SOON on Steam.

(Once the Steam page exists: replace the last line with "Wishlist on Steam" and a link.)

## 5. Steam copy

**Short description (max 300 characters, pick 1):**
- **S1 (pick):** "A slime glides through pitch-black, fog-filled mazes. Its goo trail lights the way, but every move drains it. Find the golden chalice before you dry up, then take on endless random mazes, hard mode and medals, and dress your slime in over 1,000 looks."
- S2: "Light up dark mazes with your goo trail, but every move costs slime. 10 themed levels, endless random mazes, hard mode and medals, plus 13 skins and 12 hats to collect."
- S3: "A cozy-dark pixel maze game: budget your slime, light the fog, reach the chalice."

**About this game (headers + short lines, easy to translate):**

> **ESCAPE THE FOG. BEFORE YOU DRY UP.**
> Every move leaves a glowing goo trail, and every move drains your slime. Plan your route, leap into the dark, and reach the golden chalice.
>
> **10 THEMED LEVELS**
> From the Dark Dungeon to the Volcanic Vault. 165 hidden coins to find.
>
> **THEN THE REAL GAME STARTS**
> Endless random mazes. Hard mode. Best times and gold, silver and bronze medals on every level.
>
> **DRESS YOUR SLIME**
> 13 skins, each with a see-through jelly version earned on hard mode. 12 hats from the prize wheel. Goo trails and map papers. Over 1,000 combinations.

**Tags to choose:** Puzzle, Maze, Pixel Graphics, Cute, Casual, Singleplayer, Exploration, Atmospheric, Replay Value, 2D, Dark, Relaxing, Cozy.

## 6. Community posts

- **Reddit, r/IndieGaming or r/indiegames** (follow each sub's self-promo rules; post the video natively):
  "My slime lights up the maze with its trail, but every move drains it. Here's the first trailer for Dry Trying."
- **r/godot:** lead with the tech, e.g. "I render my trailers straight from the game with Godot's movie writer, and caption them in the logo's own drippy lettering", then link the Short.
- **r/PixelArt:** a still of the skins screen (silhouettes kept) plus a lit maze.
- **Bluesky/X, opening post:** "Dry Trying: a slime, a pitch-black maze, and not enough goo. Coming soon. #indiedev #pixelart" with Short A.
- **Screenshot Saturday** (#screenshotsaturday) every week: one GIF, one line.

## 7. Next asks for Conner

1. Pay Steam Direct and create the app so the store page can go live in early November.
2. Add "30 medals" to brief.md's claim list (Dank Dungeon is fixed).
3. Pick a handle and make the accounts.
