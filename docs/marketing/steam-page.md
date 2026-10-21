# DRY TRYING: Steam page copy (paste-ready)

Source of truth for the Steam store page. Edit this file in place; it goes to `docs/marketing/steam-page.md` in the repo.
Last updated 2026-10-20, checked against brief.md and rules.md at `spring-cleaning` 8046e5e.

Rules applied: only brief.md's facts; no HEAT or DESCENT; RAINBOW and STOPWATCH skins only as black locked
silhouettes; no promise that demo progress carries over; never the old name; COMING SOON until the page exists.

---

## 1. Short description

Paste into **Store Page Admin > Description > Short description** (300 characters max).

**Pick (251 characters):**

> A slime glides through pitch-black, fog-filled mazes. Its goo trail lights the way, but every move drains it. Find the golden chalice before you dry up, then take on endless random mazes, hard mode and medals, and dress your slime in over 1,000 looks.

Alternative (220 characters), more numbers up front:

> Light up pitch-black mazes with your goo trail, but every move costs slime. Clear 10 themed levels, then chase medals in endless random mazes and hard mode, and dress your slime in 13 skins, 12 hats and over 1,000 looks.

---

## 2. About This Game

Paste into **Description > About This Game**. Steam's editor takes this BBCode. Replace each `[img]` line with an
animated GIF uploaded through the editor's image button (keep each GIF under ~5 MB; 616 px wide displays without
scaling), or delete the line.

```
[h2]ESCAPE THE FOG. BEFORE YOU DRY UP.[/h2]
You're a slime in a pitch-black maze. Every move leaves a glowing goo trail that lights the way, and every move drains your slime. Plan your route, leap into the dark, and reach the golden chalice before you dry up.

[img]GIF 1: the slime gliding into the dark, the trail lighting the maze[/img]

[h2]GLIDE, LEAP, SPLAT[/h2]
[list]
[*]Glide through the fog and light the maze with your trail
[*]Leap over gaps and splat off walls
[*]Budget every drop of slime
[/list]

[h2]10 THEMED LEVELS[/h2]
From the Dark Dungeon to the Volcanic Vault, each level has its own look and its own slime skin. 165 hidden coins to find.

[img]GIF 2: three level themes, one after another[/img]

[h2]THEN THE REAL GAME STARTS[/h2]
[list]
[*]Endless random mazes that pay tickets
[*]Hard mode with its own mazes
[*]Best times and gold, silver and bronze medals on every level
[/list]

[img]GIF 3: a random maze run ending at the chalice[/img]

[h2]DRESS YOUR SLIME[/h2]
[list]
[*]13 skins, each with a see-through jelly version earned on hard mode
[*]12 hats to win on the prize wheel
[*]Goo trails and map papers
[*]Over 1,000 combinations
[/list]

[img]GIF 4: the wardrobe flipping skins, a hat popping onto the slime[/img]

[h2]LEARN BY PLAYING[/h2]
A wordless intro and a short tutorial, SPLASHDOWN, teach you everything by playing.
```

When the demo is live, add this line under the first paragraph (no carry-over wording, on purpose):

```
[b]Free demo:[/b] the intro, the tutorial and the first 4 levels.
```

---

## 3. Tags (Store Page Admin > Tags)

Steam allows up to 20 and weights the first ones most, so order matters.

| # | Tag | Why |
|---|---|---|
| 1 | Puzzle | Route and slime budgeting is the core |
| 2 | Maze | The most specific description of the game |
| 3 | Pixel Graphics | 320x180 pixel art |
| 4 | Cute | The slime, skins and hats |
| 5 | Atmospheric | Fog, darkness, light trail |
| 6 | Exploration | Lighting up dark mazes |
| 7 | Casual | Short runs, gentle tutorial |
| 8 | Replay Value | Endless random mazes, medals |
| 9 | Procedural Generation | Endless random mazes |
| 10 | Character Customization | 13 skins, 12 hats, trails |
| 11 | 2D | |
| 12 | Singleplayer | |
| 13 | Dark | Pitch-black mazes |
| 14 | Cozy | The cosmetic grind and calm tone |
| 15 | Time Attack | Best times and medals |
| 16 | Indie | |
| 17 | Collectathon | 165 coins, cosmetics |
| 18 | Minimalist | Optional: fits the dark look |

Leave slots 19-20 empty until Steam's "suggested tags" show what players add.

---

## 4. Other store fields

| Field | Value |
|---|---|
| Name | DRY TRYING (never the old name) |
| Developer / Publisher | Conner's studio name (to fill in) |
| Genre | Indie, Casual |
| Release date | "Coming soon" (no date until Conner sets one) |
| Platforms | Windows, macOS, Linux (per brief.md; phones say nothing yet) |
| Languages | English: interface and subtitles. No full audio (there's no voice). Add others only when switched on in the build. |
| Controller support | Partial or full controller support: the game has a gamepad layer (stick/D-pad, A leap, START pause). Mark "full" only after one controller-only playthrough (QA item 11). |
| Steam Deck | Request a compatibility review once the pad-mode fix is in (QA item 11). |
| Mature content survey | None of the categories apply. |
| AI content disclosure | **Conner must answer this personally and honestly.** Steam asks about pre-generated and live AI content in what ships (art, sound, text). Check how the 17 translations were made before they ship (QA item 12). |
| Price | Conner's call. |

---

## 5. Capsule art specs and briefs

Sizes from Steamworks (also in qa-report.md item 10). Make one set for the base app and one for the demo app (the
demo set can add a small "DEMO" sticker, like the title screen's).

| Asset | Size (px) | Text on it | Brief |
|---|---|---|---|
| Header capsule | 920 x 430 | Logo only | Slime bottom-left, trail curling into dark fog, logo top-right. Must read at 50% size. |
| Small capsule | 462 x 174 | Logo only | The smallest place people see the game (search, lists). Logo fills most of the width; slime glow on the left. |
| Main capsule | 1232 x 706 | Logo only | Front page and big lists. Slime center-left, lit trail behind it, golden chalice glinting in the dark top-right, logo across the top. |
| Vertical capsule | 748 x 896 | Logo only | Used in sales and seasonal pages. Logo top, slime and trail spiraling down. |
| Library capsule | 600 x 900 | Logo only | Library grid. Same art as the vertical capsule, recropped. |
| Library hero | 3840 x 1240 | **No text, no logo** | Wide dark maze lit by a long goo trail; keep the middle clear for the logo overlay. |
| Library logo | 1280 wide (PNG, transparent) | Logo | Render with `tools/make_title.py` at high scale; the drip variant you like best. |
| Page background | 1438 x 810 (optional) | None | Dark fog texture, low contrast. |

Art rules:
- Use the game's own pixels: render at whole-number scales (nearest neighbour), never smoothed.
- Never show RAINBOW or STOPWATCH skins in colour. Lime (level 1) is the safest hero skin.
- No review quotes, award logos or "discount" text on capsules (Valve rule).
- Test the small capsule at real size next to other games before deciding.

---

## 6. Screenshots and captions

Steam wants at least 5 screenshots at 1920 x 1080 (exactly 6x the game's 320x180). Upload in this order: the first 4
show on the store page without clicking. Steam screenshots have no caption field, so use the caption as the file
name, the alt line in your press kit, and the social post text when the same image is shared.

| # | What to capture | Caption |
|---|---|---|
| 1 | Mid-run in Dark Dungeon: the slime, a long glowing trail, fog all around | Your goo trail is your only light. |
| 2 | Slime low on goo, a few tiles from the chalice | Every move drains you. Reach the chalice before you dry up. |
| 3 | A charged leap over a gap in Mossy Mines | Glide, leap and splat off walls. |
| 4 | The cosmetics screen: a jelly skin, a hat, locked silhouettes visible | 13 skins, 12 hats, over 1,000 looks. |
| 5 | Level select or a 3x3 grid of different level themes | 10 themed levels, from the Dark Dungeon to the Volcanic Vault. |
| 6 | A random maze run with tickets showing | Then the real game starts: endless random mazes. |
| 7 | Hard mode mid-run (never its win panel) | Hard mode, with its own mazes. |
| 8 | A medal result (gold/silver/bronze) on a level | Best times and medals on every level. |
| 9 | The prize wheel spinning with a hat about to land | Spin the wheel. Win a hat. |
| 10 | Map table with a map paper | Map papers for every maze. |

Check each shot before upload: no HEAT screens, numbers or flame icons; no DESCENT; RAINBOW and STOPWATCH only as
silhouettes; no HUD clutter you wouldn't want translated.

---

## 7. Simplified Chinese store text (for when zh_CN is switched on)

Terms follow `docs/i18n/glossary/zh_CN.md`. The logo stays Latin (DRY TRYING), like the in-game logo. Add Simplified
Chinese to the store page only when the build has it switched on (rules: don't send players to an English-only game).

**Short description (91 characters):**

> 你是一只史莱姆，困在漆黑的迷雾迷宫里。黏液拖尾为你照亮道路，但每一步都在消耗黏液。在干涸之前找到金色圣杯，然后挑战无尽的随机迷宫、困难模式和奖牌，用超过1000种搭配打扮你的史莱姆。

**About This Game:**

```
[h2]在干涸之前，逃出迷雾。[/h2]
你是一只困在漆黑迷宫里的史莱姆。每走一步都会留下发光的黏液拖尾，照亮前路，也会消耗你的黏液。规划路线，跃入黑暗，在干涸之前抵达金色圣杯。

[h2]滑行、跳跃、撞墙[/h2]
[list]
[*]在迷雾中滑行，用拖尾照亮迷宫
[*]跳过缺口，撞墙反弹
[*]精打细算每一滴黏液
[/list]

[h2]10个主题关卡[/h2]
从黑暗地牢到火山宝库，每个关卡都有独特的风格和专属皮肤。还有165枚隐藏金币等你寻找。

[h2]通关之后，真正的游戏才开始[/h2]
[list]
[*]无尽的随机迷宫，赢取奖券
[*]困难模式，拥有专属迷宫
[*]每个关卡都有最佳时间和金、银、铜牌
[/list]

[h2]打扮你的史莱姆[/h2]
[list]
[*]13款皮肤，每款都有在困难模式中解锁的透明果冻版本
[*]12顶帽子，在奖品转盘上赢取
[*]黏液拖尾和地图纸张
[*]超过1000种搭配
[/list]

[h2]边玩边学[/h2]
无文字的开场动画和简短教程 SPLASHDOWN，让你在游玩中学会一切。
```

Machine-quality draft: have a native speaker check it before it goes live.
