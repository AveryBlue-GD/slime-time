# DRY TRYING: 4 weeks of posts (Oct 21 - Nov 17, 2026)

Source of truth for the posting calendar. Edit this file in place; it goes to `docs/marketing/posts-4-weeks.md` in
the repo. Last updated 2026-10-20, checked against brief.md, trailer.md and rules.md at `spring-cleaning` 8046e5e.

Platforms: TikTok, Instagram Reels, YouTube Shorts (English) and Douyin, Bilibili (Chinese). Rules applied: no HEAT
or DESCENT, RAINBOW and STOPWATCH only as silhouettes, only brief.md facts, no carry-over promise, COMING SOON until
there's a store link, never the old name.

---

## How to use this

- **Upload natively** to each app on the same day; never repost a watermarked video.
- **Time:** English posts 6-9 pm US Eastern. Chinese posts 8-10 pm Beijing time (8-10 am US Eastern).
- **Call to action:** "COMING SOON" + "Follow for more" until Conner shares the Steam link. When the page goes live
  (planned early November), switch every caption to "Wishlist: link in bio" and put "WISHLIST ON STEAM" in the
  end card's `store` slot in `tools/trailer/trailer.json`.
- **Hooks** are the opening on-screen caption. Swapping one is a text edit in `trailer.json` plus a ~3 minute
  re-render. Keep each hook to 1-2 goo lines (about 13 letters per line). The goo lettering has A-Z, 0-9 and
  `? ! . , : ; = + ' -` only, so no emoji or % on screen.
- **Chinese on-screen text:** `python3 tools/trailer/trailer.py --lang zh` renders every Short with the Chinese
  lines below in the same goo lettering (`short_A_zh.mp4` etc.; glyphs in `tools/trailer/goo_cjk/`, lines in
  `tools/trailer/captions_zh.json`, both made from this table). Dense characters (愿, 望, 雾) read heavier than the
  English letters: have a native speaker check a cut before posting. Terms follow `docs/i18n/glossary/zh_CN.md`.
- **Douyin** usually needs a mainland Chinese phone number to sign up; if that isn't possible, skip it and post
  only to Bilibili (and Xiaohongshu with the same files). Chinese posts start in week 2 so the accounts exist first.
- **Track** each post's 3-second hold and comments in the sheet at the bottom; the best hook each week gets re-cut.

---

## The Shorts and their 3 hooks

A, B and C exist now. D-G are new cuts from existing game footage; each needs a new take in `trailer.json` (noted).

| Short | Status | Hook 1 | Hook 2 | Hook 3 |
|---|---|---|---|---|
| **A** "Can you escape before you dry up?" (24 s, music: Fog Pulse) | Ready | CAN YOU ESCAPE / BEFORE YOU DRY UP? (current) | YOUR GOO IS / YOUR LIGHT | YOUR LIGHT IS / RUNNING OUT |
| **B** "1000+ ways to dress your slime" (26.9 s with ANIMATED HATS, music: Goo Rush) | Ready | 1000+ SLIME / LOOKS (replaces the 3-line hook) | WHICH HAT? | THIS HAT / RAINS (open on the raincloud beat) |
| **C** "Beat the story... then the real game starts" (19 s, music: Goo Rush) | Ready | BEAT THE STORY... (current) | 10 LEVELS. / THEN ENDLESS. | ONE MORE RUN? |
| **D** Close call: reaching the chalice with almost no goo | New take (a level run with `--meter` low near the goal) | 1 TILE LEFT | ALMOST DRY | JUST ENOUGH |
| **E** The fail: drying up one tile from the chalice | New take (same run, one move short) | SO CLOSE... | DRIED UP! | NOOO |
| **F** Full-light reveal: the whole dark maze lit at once | New take (`tests/demo_overview.tscn`) | LIGHTS ON | THE WHOLE / MAZE, LIT | IT WAS / THIS BIG |
| **G** Dev clip: the logo drips differently every time | New take (`title` mode, several title visits) | NEW DRIPS / EVERY TIME | MADE IN CODE | NO TWO LOGOS |

### Chinese versions of the hooks

| Short | Hook 1 | Hook 2 | Hook 3 |
|---|---|---|---|
| A | 你能在干涸前逃出去吗？ | 黏液就是你的光 | 你的光快耗尽了 |
| B | 1000+种史莱姆造型 | 选哪顶帽子？ | 这顶帽子会下雨 |
| C | 通关剧情…… | 10个关卡，然后无尽挑战 | 再来一局？ |
| D | 只差一格 | 快干涸了 | 刚刚好 |
| E | 就差一点…… | 干涸了！ | 不——！ |
| F | 开灯！ | 整座迷宫被点亮 | 原来迷宫这么大 |
| G | 每次滴落都不一样 | 用代码画出来的 | 没有两个相同的标志 |

### Chinese versions of every on-screen line in A, B and C

| English (as rendered) | Chinese |
|---|---|
| CAN YOU ESCAPE / BEFORE YOU DRY UP? | 你能逃出去吗 / 在干涸之前？ |
| 10 DARK MAZES | 10座黑暗迷宫 |
| LEAP INTO / THE DARK | 跃入黑暗 |
| FIND THE CHALICE | 找到圣杯 |
| THEN: ENDLESS / RANDOM MAZES | 然后：无尽随机迷宫 |
| HARD MODE | 困难模式 |
| BEAT YOUR RECORDS | 刷新你的纪录 |
| UNLOCK SKINS | 解锁皮肤 |
| JELLY SKINS | 果冻皮肤 |
| WIN HATS | 赢取帽子 |
| GOO TRAILS | 黏液拖尾 |
| MAP PAPERS | 地图纸张 |
| 1000+ WAYS TO / DRESS YOUR SLIME | 1000+种方式 / 打扮你的史莱姆 |
| 12 HATS | 12顶帽子 |
| ANIMATED HATS | 会动的帽子 |
| SPIN TO WIN THEM | 转动转盘赢取 |
| EARN THEM ALL: | 全部靠实力赢取： |
| ESCAPE THE FOG | 逃出迷雾 |
| LEAP! | 跳！ |
| WIN TICKETS | 赢取奖券 |
| BEAT THE STORY... | 通关剧情…… |
| ...THEN THE / REAL GAME STARTS | ……真正的游戏才开始 |
| ENDLESS MAZES | 无尽迷宫 |
| SPIN FOR HATS | 转盘赢帽子 |
| = JELLY SKINS | = 果冻皮肤 |
| CHASE GOLD | 冲击金牌 |
| ALL GOLD = A / SECRET SKIN | 全金牌 = 隐藏皮肤 |
| COLLECT IT ALL | 全部收集 |
| End card: ESCAPE THE FOG / BEFORE YOU DRY UP | 在干涸之前 / 逃出迷雾 |
| End card store slot: COMING SOON | 即将推出 |
| End card store slot (later): WISHLIST ON STEAM | 加入Steam愿望单 |

---

## Hashtags

| Platform | Tags (3-5) |
|---|---|
| TikTok | #indiegame #pixelart #gaming #slime #indiedev |
| YouTube Shorts | #indiegame #pixelart #shorts |
| Instagram Reels | #indiegame #pixelart #gamedev #cozygames |
| Douyin | #独立游戏 #像素游戏 #史莱姆 #游戏推荐 |
| Bilibili | Section: 单机游戏 (single-player games). Tags: 独立游戏, 像素, 史莱姆, 迷宫, 解谜, 游戏推荐 |

---

## Week 1: Oct 21-27 (3 Shorts, test the hooks)

English only; set up the Chinese accounts this week. Same plan as the playbook's first week.

| Day | Short + hook | Platforms | Caption | Pinned comment |
|---|---|---|---|---|
| Wed Oct 21 | A, hook 1 (music) | TikTok, Reels, Shorts | Your goo is your light. Don't run dry. 🟢 | What would you name this slime? 👀 |
| Fri Oct 23 | B, hook 1 (music) | TikTok, Reels, Shorts | Which look are you picking? 🎩 | Drop your hat + skin combo below 👇 |
| Sat Oct 24 | B's raincloud beat as a GIF | X, Bluesky, r/IndieGaming weekly thread | This hat rains. #screenshotsaturday #pixelart | |
| Sun Oct 25 | A, hook 3 | TikTok, Reels, Shorts | Every move costs slime. How far can you get? | How far would you get? 1-10 |
| Mon Oct 26 | C, hook 1 (music) | TikTok, Reels, Shorts | Beat the story. Then the real game starts. | Story first or endless mazes first? |
| Tue Oct 27 | C | X, Bluesky; r/godot | I render my trailers straight from the game with Godot's movie writer. | Review the week's numbers |

## Week 2: Oct 28 - Nov 3 (4 Shorts, Chinese channels start)

| Day | Short + hook | Platforms | English caption | Chinese caption (Douyin / Bilibili) |
|---|---|---|---|---|
| Wed Oct 28 | Week 1's best Short, its best hook re-cut with hook 2 | TikTok, Reels, Shorts | Pitch black maze. One slime. Don't run dry. | |
| Wed Oct 28 | A, Chinese hook 2 (黏液就是你的光) | Douyin, Bilibili | | 黏液就是你的光，每走一步都在消耗。你能在干涸前找到圣杯吗？即将推出，关注我看更多！ |
| Fri Oct 30 | B, hook 2 (WHICH HAT?) | TikTok, Reels, Shorts | 13 skins. 12 hats. 1000+ looks. Which one? | |
| Sat Oct 31 | F, hook 1 (LIGHTS ON) | TikTok, Reels, Shorts; #ScreenshotSaturday GIF on X, Bluesky | This whole maze was dark the entire time. | |
| Sun Nov 1 | B, Chinese hook 3 (这顶帽子会下雨) | Douyin, Bilibili | | 13款皮肤、12顶帽子、超过1000种搭配，你选哪一套？评论区晒出你的组合！ |
| Mon Nov 2 | C, hook 2 (10 LEVELS. THEN ENDLESS.) | TikTok, Reels, Shorts | 10 levels. Then endless mazes. | |
| Tue Nov 3 | G, hook 1 (NEW DRIPS EVERY TIME) | TikTok, Shorts; X, Bluesky; r/godot | The logo drips differently every time you open the game. It's drawn in code. | |

Bilibili title for Oct 28: 【独立游戏】黏液就是你的光：在漆黑迷宫里逃出去，别干涸！
Bilibili title for Nov 1: 【独立游戏】1000+种搭配！给你的史莱姆戴上会下雨的帽子

## Week 3: Nov 4-10 (5 Shorts; the Steam page should go live)

When the page is live: switch every caption's last line to "Wishlist: link in bio" / 「Steam愿望单链接在主页」 only if the
Chinese store page exists, else keep 即将推出.

| Day | Short + hook | Platforms | English caption | Chinese caption (Douyin / Bilibili) |
|---|---|---|---|---|
| Wed Nov 4 | D, hook 1 (1 TILE LEFT) | TikTok, Reels, Shorts | Made it with one drop to spare. | |
| Thu Nov 5 | D, Chinese hook 1 (只差一格) | Douyin, Bilibili | | 只剩最后一滴黏液……能到终点吗？ |
| Fri Nov 6 | E, hook 1 (SO CLOSE...) | TikTok, Reels, Shorts | One tile. ONE tile. Would you have made it? | |
| Sat Nov 7 | A, hook 2 (YOUR GOO IS YOUR LIGHT), music | TikTok, Reels, Shorts; #ScreenshotSaturday on X, Bluesky | Your goo is your light. Every move costs slime. | |
| Sun Nov 8 | C, Chinese hook 2 (10个关卡，然后无尽挑战) | Douyin, Bilibili | | 通关10个关卡之后，真正的游戏才开始：无尽随机迷宫、困难模式和金牌挑战。 |
| Mon Nov 9 | B, hook 3 (THIS HAT RAINS) | TikTok, Reels, Shorts | This hat rains. This one spins. 🌧️ | |
| Tue Nov 10 | F, hook 2 (THE WHOLE MAZE, LIT) | TikTok, Reels, Shorts | This is what the maze looked like the whole time. | |

Bilibili title for Nov 8: 【独立游戏】通关剧情之后，真正的游戏才开始

## Week 4: Nov 11-17 (5 Shorts; the itch web demo, once the QA must-fixes are in)

| Day | Short + hook | Platforms | English caption | Chinese caption (Douyin / Bilibili) |
|---|---|---|---|---|
| Wed Nov 11 | E, hook 2 (DRIED UP!) | TikTok, Reels, Shorts | Dried up one tile from the chalice. Again. | |
| Thu Nov 12 | E, Chinese hook 1 (就差一点……) | Douyin, Bilibili | | 就差一格！干涸了……你能做得更好吗？ |
| Fri Nov 13 | C, hook 3 (ONE MORE RUN?) | TikTok, Reels, Shorts | Beat the story. Then one more run. And one more. | |
| Sat Nov 14 | F, Chinese hook 3 (原来迷宫这么大) | Douyin, Bilibili; F hook 3 (IT WAS THIS BIG) on TikTok, Reels, Shorts | It was this big the whole time. | 一直在黑暗里走，原来迷宫这么大！ |
| Sun Nov 15 | D, hook 3 (JUST ENOUGH) | TikTok, Reels, Shorts | Just enough goo. Every time? Not quite. | |
| Mon Nov 16 | Demo announcement: the week's best Short with "FREE DEMO" as the hook | TikTok, Reels, Shorts, X, Bluesky, Reddit (r/WebGames, r/playmygame) | Free demo is out. Play it in your browser. | Only when the web demo is live; demo link in bio |
| Tue Nov 17 | G, hook 3 (NO TWO LOGOS) | TikTok, Shorts; X, Bluesky | No two logos are the same. | |

Bilibili title for Nov 12: 【独立游戏】就差一格就到终点……然后干涸了

---

## Tracking sheet (fill in as you go)

| Date | Short + hook | Platform | Views (48 h) | 3-second hold | Comments | Follows | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
