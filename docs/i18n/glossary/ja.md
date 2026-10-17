# Japanese (ja) glossary

Register: casual game Japanese (plain form, no keigo; the browser dialogs `savecode.prompt_*` are the
only polite lines, as OS dialogs usually are). No spaces between words, except where the English uses
spaces as layout between two values. Full-width `、。！？：（）「」` in text. Half-width `( )` only
around bare numbers (`賞金{pot}(+{gain})`, `ジャンプ(長押し)` for width). Western digits. Latin
units and kept names stay in capitals (`LV`, `PX`, `X1.5`, `3X3`, `SLIME TIME`, `ESC`, `START`).

Width: every kana / kanji is 10 px in Fusion Pixel 10 (20 px in the 16 px titles). So a 32 px button
holds 3 glyphs, 27 px holds 2. Common kanji only, nothing dense where kana reads naturally.

## Terms

| English | ja | Notes |
|---|---|---|
| slime | スライム | |
| goo | ネバネバ | trail descriptions, `ネバネバを撃つ` |
| chalice | 聖杯 | |
| slime meter / tank | スライム / タンク | `TANK +15%` → `タンク+15%` |
| ticket / TIX | チケット / 枚 (counter) | `+{count} TICKETS` → `チケット+{count}`; `{price} TIX` → `{price}枚` |
| coin | コイン | |
| maze | 迷路 | `RANDOM MAZE` → ランダム迷路 |
| level | レベル | `L{level}` kept as `L{level}` |
| floor (Descent) | 地下{floor}階 | `BEST FLOOR` → 最深 地下{n}階 |
| heat | ヒート | |
| hard / hard mode | ハード / ハードモード | |
| upgrade(s) | 強化 | |
| hub | 拠点 | `HUB` button → 拠点へ |
| randomizer | ランダマイザー | |
| Descent | 降下 | `DESCEND` → 降りる |
| run (Descent) | 挑戦 | `QUIT RUN` → 挑戦終了, `NEW RUN` → 新しく挑戦 |
| pot | 賞金 | |
| cash out | 換金 | |
| paid runs | 報酬枠 | runs that still pay tickets today |
| boon | 加護 | |
| skin / jelly skin | スキン / ゼリースキン | `JELLY: ON` → ゼリー：オン |
| hat | 帽子 | |
| trail | 軌跡 | |
| paper (map paper) | 紙 | |
| hat wheel / wheel | 帽子ルーレット / 抽選 (tab, 36 px) | `SPIN` → 回す |
| shop | お店 | short enough for the 44 px tab |
| tailor | 仕立て屋 | |
| wardrobe | 衣装部屋 | |
| leap / jump | ジャンプ | touch button and keycap: 跳ぶ (2 glyphs fit 27 px); prompts quote it: 「跳ぶ」をタップ |
| glide | 滑走 | |
| splat (wall crash) | 激突 | heat BRITTLE, RUBBER BODY, STICKY |
| assist | アシスト; HUD pod 補助 | pod is 60 px |
| seed | シード | |
| medal | メダル (銅 / 銀 / 金) | |
| dry up | ひからびる | |
| restart | リスタート | |
| back | 戻る | |
| map table | 地図テーブル | |
| save code | セーブコード | |
| list separator | 、 | |

## Kept / transliterated names

| English | ja |
|---|---|
| SLIME TIME | SLIME TIME (Latin, logo) |
| INKKY | インキー |
| CHAMELEON | カメレオン |
| SLIMAKAZE | スライマカゼ (kamikaze pun survives by sound) |

## Descriptive names chosen

Skins: ライム, ミント, レモン, オーシャン, グレープ, クリムゾン, フロスト, バブルガム, 残り火, レインボー, ストップウォッチ.
Hats: 帽子なし, シルクハット, ニット帽, パーティー帽, 野球帽, カウボーイハット, コック帽, 魔法使いの帽子, バイキングの兜, プロペラ帽, 王冠, 虹色の帽子.
Levels: 暗黒ダンジョン, コケむした鉱山, 砂岩の聖域, 水没した神殿, どくどくトンネル, 不気味な地下墓地, 氷の要塞, 黒曜石の地下牢, 水晶の洞窟, 火山の奥底.
Abilities: スライムライフル, スライムボム, スライマカゼ. Upgrades: スライム増量, スピード, 明るさ, 壁パワー. Tools: 起死回生, 急速チャージ, ねばり, マグネット, ネバ鼻.

## Doubts for a native reviewer

- `title.tagline.1/2` 霧から逃げろ / ひからびる前に: the "dry trying / die trying" pun is lost; only the meaning is kept.
- `result.chalice` 聖杯を飲みこんだ！: "CHALICE CONSUMED!" read as the slime swallowing the chalice.
- `workshop.nose` ネバ鼻 ("GOO NOSE", a goose pun in English): a made-up word, may read oddly.
- `ability.splat.name` スライムボム: "SPLAT" became "bomb" (the description is BOMB 3X3), so it no longer shares a word with 激突 (wall splat).
- `tutorial.jump` / `touch.jump` 跳ぶ vs ジャンプ elsewhere: forced by the 27 / 34 px space. Check that players connect them.
- `heatmod.*.name`: 薄暗い, もろい, 迫る霧, 地べた (GROUNDED, the "punished kid" pun is lost), のどカラカラ, 競走.
- `theme.sewers` どくどくトンネル: playful onomatopoeia for "TOXIC TUNNELS" alliteration. `theme.volcanic` 火山の奥底 is free ("depths", not "vault").
- `story.level_8` uses 君: the only direct "you" in the game. `story.level_2` 気持ちはわかる turns "SO WOULD YOU" into "can't blame them".
- `victory.unlocked` / `result.unlocked_custom` 好きな色にできる: the Henry Ford joke ("any color you like") doesn't carry over.
- `hud.pod.paid_run` / `hub.portal.info` 報酬枠: the term for "paid runs" is my own coinage.
- `wheel.tab.wheel` 抽選 vs the title 帽子ルーレット: the tab is too narrow (36 px) for ルーレット.
- `hud.area.random_code` is 226 px with 888 fills, the same as English, over the 200 px area budget.
- New `language.title` (LANGUAGE) is not in messages.pot yet: suggest 言語.
- Fix pass F4: `hub.notice.returned` コイン返却 +{count} (space before the sign); `skins.selected` / `skins.wearing`
  keep one space before the full-width bracket (the bracket's own bearing is the second). Not changed: 報酬枠
  (dense at 10 px, review ja.md) is used in 7 strings; a simpler term (チケット枠?) is a glossary decision for a native.
