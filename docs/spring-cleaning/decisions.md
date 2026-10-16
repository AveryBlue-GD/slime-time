# Spring cleaning: owner decisions

| # | Topic | Decision (owner, 2026-10-15) |
|---|---|---|
| D1 | Cutscenes | Keep ALL current cutscenes (story intro, finale, first-launch trailer, STORY button, level banners, their sounds). |
| D2 | Ticket workshop (WORKSHOP_ENABLED=false) | Switched off "for now": keep intact behind its flag; not a cut feature. |
| D3 | Frame rate | Stable 60 fps on low-end PC and low-to-mid mobile is the floor; better rigs should run much higher (120/144/240 Hz) smoothly. |
| D4 | Gamepad (Steam Deck blocker B2) | Add a fixed default gamepad layout now (move, leap, interact, pause/back, abilities, full menu navigation). Button glyphs and remapping later. |
| D5 | High-refresh smoothness (B4) | Enable physics interpolation, verified with side-by-side captures at 60 and 144 Hz before keeping it; pixel art must stay on whole pixels; revert if it looks wrong. |
| D6 | Descent on mobile app kill (H7) | Save the in-progress Descent run so it resumes on relaunch at the start of the same floor (floor, meter, boons, pot, seed); no reroll exploit. |
| D7 | Local video clips / git-history purge | Pending (owner has not decided): keep the git-ignored mp4s; do not rewrite git history. |
| D8 | Language | English only. |
| D9 | Descent resume limit (QA phase 5 #1) | One resume per floor: after a floor has been resumed once, a further app kill / window close / tab reload on that floor offers only QUIT RUN (banks half, like a dry-up). Clearing a floor resets the count. (owner, 2026-10-16) |
| D10 | Mobile hub button (QA phase 5 #3) | The mobile hub button returns to the title (home icon): on iOS / Android the hub's touch pause button draws a small pixel-art house instead of pause bars, so the title and its STORY replay are discoverable. Desktop and web unchanged. (owner, 2026-10-16) |
| D11 | Descent cut from the randomizer for now | Descent cut from the randomizer for now: disabled behind `Economy.DESCENT_ENABLED := false` (test hook `Economy.descent_force`); kept intact. Why: it feels unfair when even a single level is hard to first-try. Off: the portal goes straight into a RANDOM MAZE (no mode menu), no run starts or resumes, no resume prompt, nothing in the hub / HUD / help text mentions it, and the ABYSS trail is hidden unless already owned (owners keep and can wear it). A saved `[descent_run]`, `[descent]` stats and milestones stay in the save untouched (not resumed, banked or deleted); flipping the flag back on restores everything. Abilities still work in randomizer mazes. (owner, 2026-10-16) |
