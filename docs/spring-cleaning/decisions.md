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
