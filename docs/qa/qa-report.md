# Dry Trying: pre-demo QA report

2026-10-20. Four reviewers read the project snapshot from `C:\Users\conav\code\slime-time`:
- bugs and saves
- gameplay, balance and the first 10 minutes
- UX, touch, accessibility and performance
- store and platform readiness

This was a code review only: nobody ran Godot, the builds or a phone, so every time and size figure is an estimate. **CONFIRMED** means the code path was traced; **PLAUSIBLE** means it needs a playtest. File paths are relative to the project root.

---

## A. Must fix before the demo (17)

### Bugs and saves

1. **The demo can wipe a newer full-game save (CONFIRMED).** The demo and the full game share `SlimeTime_R1/save.cfg`.
   - If a later full-game save fails the demo's parser, the demo moves it to `save.corrupt.cfg` and starts fresh.
   - If the save is from another epoch, the demo returns before `_guard_full_save`, so the save gets overwritten (`progress.gd:670-676`).
   - Fix: when a save can't be parsed or has another epoch, turn saving off for the session (`demo_guard = true`) instead. Also guard against `[meta] version > SAVE_VERSION`.
2. **The randomizer end screen is missed for good if the 3rd win isn't followed by NEW MAZE (CONFIRMED).** `game.gd:2645` checks `randoms_won == Demo.RANDOM_WINS` only inside `play_next`. Choosing HUB or REPLAY on that win skips the pitch forever.
   - Fix: add an "end seen" bit and test `>=` instead.

### End screen and wishlist funnel

3. **The end screen advertises HEAT (CONFIRMED).** The level 9 teaser card says "HARD MODE AND HEAT" (`scripts/ui/demo_end.gd:69`). That breaks your rule 1 on the best-converting screen.
   - Fix: replace it with something like "CRYSTAL CAVERNS" or "2 MORE ABILITIES".
4. **The teasers sell things the demo already gives.**
   - "JELLY SKINS AND HATS" (`:67`): the demo already has jelly Lime and Mint plus two hats.
   - "HARD MODE": hard level 1 is in the demo.
   - "ENDLESS MAZES" (`:49`): the demo's randomizer is already endless.
   - Fix: use lines that are only true of the full game: "6 MORE AREAS", "2 MORE ABILITIES", "THE SHOP", "MAZES THAT LOOP BACK". Add 1-2 real stills of later themes.
5. **The wishlist button is hidden and has nowhere to go.**
   - `Demo.WISHLIST_URL` is empty (`demo.gd:51`), so finishers see only KEEP PLAYING.
   - On Steam, `OS.shell_open` opens a browser instead of the Steam overlay.
   - Fix: get the Steam page live first, then set the URL. Route the Steam build through the overlay (GodotSteam `activateGameOverlayToStore`).
6. **The Slime Rifle can't be bought before the "3 abilities" pitch.** It costs 15 tickets (`economy.gd:314`), a win pays at most 5, and the pitch fires after win 3. So nobody tries the one demo ability before being told about three.
   - Fix: a demo price of 5 or less, or grant rifle level 1 when the randomizer opens.

### Store and platform

7. **The full game may already be free on itch.** The docs describe a public web, Windows and Mac build there (`docs/itch-release.md`, `handoff.md:117`).
   - Fix: check that page. Before the demo, unpublish it or swap in the Web Demo, and rename it from Slime Time.
8. **Steam timing.** Paying the $100 Steam Direct fee starts a **30-day wait** before you can release anything. The page must also sit in "Coming Soon" for 2 weeks before a release.
   - Next Fest: **registration closes Jan 10, 2027**, the build is due Jan 25, and the fest runs Feb 22 to Mar 1 ([Steamworks](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027)).
   - Fix: pay this week.
9. **There's no Steam build setup.** No Steam export presets, no app or demo app IDs, no GodotSteam. `Platform.is_steam()` is always false (`platform.gd:78`).
   - Fix: create the base app and the demo app, add `steam` and `demo,steam` presets, and set up the depots.
10. **No store art exists.** The only icon is 64x64. Steam needs these sizes:

    | Asset | Size |
    |---|---|
    | Header | 920x430 |
    | Small capsule | 462x174 |
    | Main capsule | 1232x706 |
    | Vertical capsule | 748x896 |
    | Library capsule | 600x900 |
    | Library hero | 3840x1240 |
    | Logo | 1280 wide |

    - Fix: make a capsule set for the base app and one for the demo app. Screenshots at 1920x1080, which is exactly 6x the game's resolution.
11. **Steam Deck: prompts start as keyboard keys** (`platform.gd:54`). Next Fest has many Deck players.
    - Fix: start in pad mode on a Deck, and do one controller-only playthrough before the demo goes out.
12. **Steam content survey and AI disclosure.** You have to answer these honestly. The music is made in code from the game's own sounds. Check where the 17 translations came from before they ship.

### Phone players (Shorts traffic lands here)

13. **The game is small in a phone browser.** With the browser bars showing, the integer scale drops to about 4x and the game fills roughly 45% of the screen. Text is tiny and taps get missed.
    - Fix: a one-tap "PLAY FULLSCREEN" gate in `web_shell.html` that also locks landscape.
14. **The portrait "ROTATE YOUR DEVICE" cover is unreadable.** It uses the 8 px font, which comes out about 1.3 mm tall (`rotate_hint.gd:27`). TikTok viewers arrive in portrait.
    - Fix: build it as an HTML overlay in the web shell, with a big icon and text, plus an "open in Chrome/Safari" hint for in-app browsers.
15. **Download size and load time haven't been measured.** The engine alone is a 39.5 MB wasm, roughly 10 MB compressed.
    - Fix: measure on 4G and check that itch serves it compressed. Build a size-optimised web template (about half the size), and show a branded progress bar.
16. **A 24-second intro plays before the player gets control, and touch has no "skip all"** (`story.gd:22-26`, `story_screen.gd:128-138`).
    - Fix: add a visible SKIP button. Consider dropping the intro from the web demo, or making it optional from the title screen.
17. **No profiling on a budget Android phone.**
    - The fog and trail textures are re-uploaded every frame while the slime moves (`game.gd:1473-1481`).
    - fps is uncapped, so on 120 Hz phones the per-frame work runs twice as often.
    - Fix: set `Engine.max_fps = 60` on web and mobile, and profile levels 1-3 on a cheap phone.

### Docs and playtests (cheap)

- **Fix the stale demo docs.** CLAUDE.md, handoff.md and a comment in `pause_menu.gd:175` still say "levels 1-3" and "3 fixed mazes". The code has 4 levels on desktop (3 on web) and random mazes. brief.md says "Dank Dungeon"; the game says Dark Dungeon.
- **Time the demo with 3-5 first-time players per platform.**
  - Estimate for desktop: 20-35 minutes, which is on target.
  - Estimate for web: 10-15 minutes, at the "too thin" line.
- **The tutorial keycaps show QWERTY letters to AZERTY players** (`tutorial_cues.gd:193`). This is a one-line fix with `keyboard_get_label_from_physical`.

---

## B. Before full release (14)

### Saves

1. **A failed rename on Windows can delete the only copy of the save** (`progress.gd:1215-1217`; PLAUSIBLE).
   - Fix: keep the temp file if the target is already gone.
2. **Save failures are never shown, and quitting doesn't flush the save.** `title.gd:375` and `hub.gd:743` call `quit()` directly. On the web, a blocked IndexedDB loses progress silently.
   - Fix: show a SAVE FAILED notice, and call `flush_save()` on quit and on close requests.
3. **On the web, going to the background doesn't force the save into IndexedDB.**
   - Fix: call `JavaScriptBridge.force_fs_sync()` in `enter_background()`.
4. **Demo-to-full carry-over silently drops an upgrade level.** Demo prices total 34 coins; the full game's total 36 for the same levels.
   - Fix: let the full game keep the levels a demo save already bought.
5. **The web demo and the web full game probably share one save on itch's shared origin.** If so, a full-game player's demo session is never saved. Test it.

### Economy and replay loop

6. **The ticket grind is behind a hard daily wall.** There are about 790 tickets of things to buy, and the only live source is capped at 25 a day. That's 32+ days of perfect play, more like 50.
   - Fix: diminishing returns after the cap, plus one-time bounties for milestones.
7. **Medals pay almost nothing.** The only reward is the Stopwatch skin.
   - Fix: a few tickets per new medal tier. This also helps item 6.
8. **A hidden 1-ticket cap applies to players who skipped MORE SLIME** (`progress.gd:1732`). On top of that, MORE SLIME makes random mazes longer, not easier.
   - Fix: show a reason, or drop the cap in the demo.
9. **The first random mazes can need up to 95% of the meter, with no assist.**
   - Fix: in the demo, keep the first 3 mazes at or below about 75%. Soften the drop in payout per attempt.

### Mobile stores

10. **Apple doesn't allow demos on the App Store** (Guideline 2.2). The demo switch only works at export time.
    - Fix: decide between a paid app and a free app with a "Full Game" unlock (StoreKit / Play Billing). Make the demo check work at runtime and hide Steam WISHLIST on mobile.
11. **iOS requirements.** No preset yet. You need:
    - Xcode 26 and the iOS 26 SDK on a Mac
    - a Team ID
    - a privacy manifest, and a privacy policy URL ("Data Not Collected" fits)
    - the new age rating questionnaire
    - iPad screenshots
    - testing on a notched iPhone
12. **Google Play requirements.**
    - Set target API 36 explicitly.
    - Personal accounts need **12 testers opted in for 14 days** before production. Start recruiting early.
    - Fill in the Data safety form and the IARC rating.
13. **The bundle IDs are still `com.slimetime.*`, and the mobile preset drafts say "Slime Time".** These IDs are permanent once uploaded.
    - Fix: pick `com.<studio>.drytrying` now.

### Accessibility and controls

14. **Accessibility and controls are thin.**
    - The pause menu buttons sit too close together for touch.
    - There's no clean-text or larger-text option.
    - Leaping is hold-to-charge only, with no one-handed or left-handed layout.
    - Gamepad glyphs are Xbox only, with no remapping.
    - Settings have only one volume and no vibration toggle.
    - Trail contrast depends on the skin (INKKY on Obsidian Oubliette is dark on dark).
    - Mac and Windows downloads are unsigned, so Gatekeeper and SmartScreen warn players.

---

## C. Nice to have (9)

- Hard level 1 is a dry-up loop for newcomers (87.5% of the meter, no assist). Label it as a challenge.
- The tutorial gives a coin, then the tour says "THE PRACTICE COIN WAS FAKE." Check the tone in a playtest.
- "FULL" on a capped upgrade reads as "maxed". Use a lock icon or "FULL GAME".
- Dead ends after the pitch ("DAILY TICKET LIMIT", "NO MORE HATS IN THE DEMO") could carry a quiet WISHLIST button.
- Small per-frame allocations: HUD strings rebuilt every tick, button lists for the rainbow skin text.
- Reduce Motion ignores the OS setting, and the menu backdrop keeps drifting when it's on.
- Check that the web build's texture import works on Android: ETC2 is off and the virtual keyboard is off.
- A hand-edited `[meta] demo` value that isn't true/false can break loading (`progress.gd:1409`).
- Keep `SlimeTime_R1` and the `SLIME2-` code prefix, since renaming them strands saves. Just keep them out of store copy.

## What checked out

- The demo's coin prices equal its coins exactly (34 on desktop, 22 on web).
- The hat cap and the free first spin work as designed.
- ASSIST appears after 3 dry-ups.
- Coins are kept across dry-ups.
- Scene transitions and pausing on focus loss are robust.
- The demo loads no stripped content.
- Web threads are off, so no SharedArrayBuffer is needed and it works in in-app browsers.
- Touch hit areas grow with distance.
