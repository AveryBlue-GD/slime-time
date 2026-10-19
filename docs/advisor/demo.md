# Demo strategy: how to adjust the draft scope (advisor, 2026-10-19)

Goal: turn players of the free demo (Steam Next Fest + itch web build fed by Shorts) into wishlists and buyers.
Read the evidence with care. Most Next Fest numbers are developers reporting on themselves (Chris Zukowski's surveys), and
nobody has firm data on the best demo length. Anything not tied to a link below comes from general knowledge.

## Ranked recommendations (impact vs effort)

**1. Release the Steam demo weeks or months BEFORE Next Fest, not during it. (High impact, low effort)**
Zukowski's Feb 2026 survey: games whose demo was out months early got about 2.5x the median fest wishlists. Wishlists
held before the fest predicted fest results best (r = 0.825)
([steampageanalyzer](https://www.steampageanalyzer.com/blog/do-steam-demos-increase-sales)). He advises against debuting
a demo during the fest ([Oct 2024 fest](https://howtomarketagame.com/2024/11/04/how-was-the-october-2024-steam-next-fest/)).
Steam notifies wishlisters once, when the demo first goes live, and the "first playable" date can't be undone
([Valve demo changes](https://howtomarketagame.com/?p=4010)). So: get the store page live now, ship the demo early, and
schedule the notification. Freeze the build during the fest; changing a demo mid-fest is a listed failure mode
([best practices](https://www.steampageanalyzer.com/blog/steam-demo-best-practices)).

**2. Aim for 20-40 minutes and measure it. Keep 3 levels; add level 4 only if playtests come in short. (High, low)**
Best practice puts the target at 20-40 minutes. Under 15 feels thin, over 60 lowers the urge to buy, and if fewer than 40% of
players finish, the demo is too long ([best practices](https://www.steampageanalyzer.com/blog/steam-demo-best-practices)).
Others quote a loose 30-90 minutes ([steampageanalyzer](https://www.steampageanalyzer.com/blog/do-steam-demos-increase-sales)).
My guess (not measured): intro + SPLASHDOWN + L1-3 with coins + 3 randomizer mazes is about 20-30 minutes for a new player.
Time 3-5 fresh players before choosing between 3 and 4 levels. Use playtests, not autoplay, which runs far faster than a
first-time player. Hard mode L1 and coin hunting are optional extra time. They don't hold up the end screen, so they're fine.

**3. Make the end screen the main pitch: WISHLIST first, a short teaser, KEEP PLAYING second. (High, medium)**
The end screen converts best of all wishlist spots. The pause menu comes second. The main menu is weakest because the
player hasn't played yet. Don't use pop-ups during play. A wishlist prompt reportedly lifts conversion from about 12% to
about 20% ([best practices](https://www.steampageanalyzer.com/blog/steam-demo-best-practices)). Terra Nil and Death Trash
put WISHLIST on the title and pause menus ([neat demo ideas](https://howtomarketagame.com/2021/06/21/neat-ideas-for-your-games-demo/)).
Adjustments:
- Fire the end screen right after the L3 chalice, before the randomizer opens, so every finisher sees it.
- Keep the slideshow to 4-6 stills that show what's new, not just new colours: L6+ loops, the frozen and volcanic themes,
  jelly skins, hats. Make it skippable at once.
- Add a quiet WISHLIST entry to the pause menu and a hub signpost. Leave the title button small.
- On Steam, open the store through the overlay. On the web, open the Steam page in a new tab.

**4. Keep the randomizer, but present it as a taste of the replay loop. (Medium-high, low)**
For systems-driven games, a demo works as a free sample of a loop that keeps deepening. Narrative games risk giving the hook
away ([steampageanalyzer](https://www.steampageanalyzer.com/blog/do-steam-demos-increase-sales)). Dry Trying sits between the
two: the story is the hook and the randomizer is the reason to come back. Keep the 3 fixed mazes and one ability. After the
third maze, show a "the full game has endless mazes + 3 abilities" card with the WISHLIST button.

**5. Treat the web demo as its own, shorter product. (High for the Shorts funnel, medium)**
Shorts viewers bounce quickly. Capital Command's 10-minute median playtime was put down to Steam shoppers bouncing
([Oct 2022 fest](https://howtomarketagame.com/2022/11/04/steam-next-fest-october-2022-how-did-games-perform/)). One itch
browser demo turned 5,300 plays into about 3% wishlists, a single anecdote ([itch post](https://itch.io/post/13889871)). A broken web build
makes people assume the PC build is broken too, so the web build needs its own scope list and a long-session test
([gamineai opinion](https://gamineai.com/blog/your-itch-browser-demo-is-not-free-marketing-stop-unscoped-html5-sku-2026)).
Proposal: web = intro, SPLASHDOWN, L1-2 (or L1-3) and the same end screen with a big Steam link. Skip the randomizer and hat
wheel on the web to keep the download light. Test it on Android Chrome. That matches the Shorts audience, which is
mostly on phones.

**6. Make "your progress carries over" true on every route, or don't say it. (Medium, medium)**
A carry-over that fails right after purchase can cost the sale
([bugnet QA](https://bugnet.io/blog/qa-checklist-for-a-demo-release-on-steam)). Octopath Traveler 2's demo saves failed on
Steam Deck ([Prima](https://primagames.com/news/psa-octopath-traveler-2-demo-save-progress-isnt-carrying-over-on-steam-deck)).
Our case: the Steam demo has its own app ID, so Steam Cloud won't share saves between demo and full game. Locally both builds
use `SlimeTime_R1/save.cfg` if they keep the same `custom_user_dir_name`, so carry-over works on the same machine. Web saves
live in browser IndexedDB and can never reach Steam. So on the web end screen, show the `SLIME2-` save code with "paste this
into the full game". Also make sure a full-game code loaded into the demo is clamped (the load already drops anything unpaid).

**7. Turn the languages on for the demo, or match the Shorts to English. (Medium, low code / high review)**
Multilingual Shorts that send people to an English-only demo waste the traffic. `LANGUAGES_TEST` is off and translations
are paused. At minimum, ship the locales you post Shorts in. The demo's text is small (L1-3, the hub, the end screen), so
they're cheap to review first. General knowledge, no source.

**8. Show the full game's size openly; keep the stingy parts honest. (Low-medium, low)**
Death Trash fences off areas with "DEMO" to show how big the game is without giving it away
([neat demo ideas](https://howtomarketagame.com/2021/06/21/neat-ideas-for-your-games-demo/)). Our FULL GAME level locks and
silhouette skins do the same thing. Lock the shop with a "FULL GAME" sign, not a hidden station. Give the paid wheel spin
enough tickets from the 3 mazes to be affordable once, so the demo doesn't feel like it is taking things away.

**9. Track the drop-off.** A demo-to-wishlist conversion of about 15-25% is healthy and under 10% points to a problem
([best practices](https://www.steampageanalyzer.com/blog/steam-demo-best-practices)). One in 5-6 is the Oct 2024 median.
Use Steamworks demo stats, and add a feedback button on the title (They Always Run, Death Trash).

## Feel risks
- The end screen is an interruption. Keep it skippable with no waiting, and drop KEEP PLAYING into the hub without a reload.
- Capping upgrades at 2 tiers changes how L3 plays for players who don't buy. Check L3 par and drain at tier 2, not at max.
- Don't let wishlist buttons show up in menus during play beyond pause. The game's calm darkness is the selling point.
