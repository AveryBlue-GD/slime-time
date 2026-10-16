# Korean (ko) glossary

Register: 해요체 for sentences addressed to the player (`복사했어요!`), plain `-다` narration for result titles
and story one-liners (deadpan narrator: `말라버렸다`, `철퍽. 축축하다.`), nouns / noun phrases for buttons and labels.
Spaces between words as usual Korean. Latin inside Korean stays capitals (`SLIME TIME`, `LV`, `PX`, `X1.5`, key names).
Widths: Hangul is 10 px per syllable at size 10 (20 px in 16 px titles), measured with Fusion Pixel 10 px ko;
every budgeted string was measured with placeholders filled wide (888, `카멜레온`).
Particles after placeholders are avoided (`{key} 눌러 닫기`, `{keys} 입력`), since 을/를, 은/는, 로/으로 depend
on the filled value.

## Terms

| English | Korean | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | kept in Latin (logo); `SLIME TIME은` (pronounced 타임) |
| slime | 슬라임 | |
| goo | 점액 | |
| chalice | 성배 | |
| slime meter | 게이지 | (not shown as a string yet) |
| ticket / TIX | 티켓 (counter `장`) | TIX is written 티켓 too |
| coin | 코인 (counter `개`) | |
| maze | 미로 (counter `개`) | |
| level | 레벨 | `L{level}` written as `레벨 {level}` |
| LV (unit) | LV | kept |
| hard mode / HARD | 하드 모드 / 하드 | |
| HEAT | 열기 | as in Korean Hades |
| upgrade | 업그레이드 | |
| hub | 허브 | |
| randomizer | 랜덤마이저 | station / portal / victory button |
| random maze | 랜덤 미로 | |
| descent | 하강; DESCEND = 내려가기 | |
| run (Descent / paid run) | 도전 | PAID RUN = 유료 도전, NEW RUN = 새 도전, QUIT RUN = 도전 종료 |
| floor | 층 (`{floor}층`) | |
| pot | 판돈 | CASH OUT = 정산 |
| boon | 축복 | |
| skin / jelly skin | 스킨 / 젤리 스킨 | |
| hat | 모자 | |
| trail | 흔적 | |
| paper (map paper) | 종이 | |
| hat wheel / wheel | 모자 룰렛 / 룰렛 | SPIN = 돌리기; "prize wheel" also 모자 룰렛 |
| tailor | 재단사 | |
| shop | 상점 | |
| wardrobe | 옷장 | |
| leap | 도약 | |
| glide | 활주 | |
| splat (wall hit cost) | 철퍼덕 | SPLAT COST = 철퍼덕 비용 |
| seed | 시드 | |
| assist | 도움 | |
| medal: bronze / silver / gold | 동메달 / 은메달 / 금메달 | |
| attempt | 시도 | |
| practice | 연습 | |
| MAX / MAXED | 최대 | |
| ON / OFF | 켬 / 끔 | |
| CLEARED | 클리어 | |
| UNLOCKED | 해금 | LOCKED = 잠김 |
| DRIED UP | 말라버렸다 | |

## Kept names (transliterated)

| English | Korean |
|---|---|
| INKKY | 잉키 |
| CHAMELEON | 카멜레온 |
| SLIMAKAZE | 슬라이마카제 |

## Translated names

Abilities: 슬라임 라이플, 슬라임 폭탄 (SLIME SPLAT), 슬라이마카제. Skins: 라임, 민트, 레몬, 바다, 포도, 진홍, 서리,
풍선껌, 불씨, 무지개, 스톱워치. Levels: 암흑 던전, 이끼 광산, 사암 성소, 수몰 신전, 독성 터널, 으스스한 지하묘지,
얼어붙은 요새, 흑요석 지하감옥, 수정 동굴, 화산 금고. Upgrades: 슬라임 추가, 속도, 밝기, 벽 파워. Workshop: 기사회생
(HUD pod: 회생), 빠른 충전, 끈적끈적, 자석, 점액 코.

## Open doubts (for a native reviewer)

- `title.tagline` ESCAPE THE FOG / OR DRY TRYING -> `안개를 탈출하라` / `말라비틀어지기 전에`: the dry / die pun is
  lost; "before you shrivel up" keeps the gallows tone. Better pun welcome.
- `ability.kaze.name` SLIMAKAZE -> `슬라이마카제` (by sound, per style guide); `슬라임카제` would read more like a pun.
- `ability.splat.name` SLIME SPLAT -> `슬라임 폭탄` (its description is a 3x3 bomb); the wall-hit "splat" is `철퍼덕`,
  so the two no longer share a word as in English.
- `result.chalice` CHALICE CONSUMED! -> `성배를 삼켰다!` (the slime swallows it).
- `workshop.nose` GOO NOSE -> `점액 코` (literal); `workshop.wind` SECOND WIND -> `기사회생` (idiom "back from the
  brink"), HUD pod `회생`.
- `heatmod.brittle.name` BRITTLE -> `허약`; `heatmod.fog.name` FOG BITES -> `안개의 습격`.
- `boon.*` names are playful onomatopoeia (`벌컥벌컥`, `미끌미끌`, `활활`, `알뜰살뜰`): check they read well on cards.
- `victory.unlocked` / `result.unlocked_custom` Henry Ford joke (ANY COLOR YOU LIKE) -> `원하는 색 아무거나`: the
  quote is not well known in Korean, kept as plain meaning.
- Story lines: `story.level_2` SO WOULD YOU -> `너라도 그랬겠지` uses 너 (narrator talking to the slime);
  `story.level_4` STILL NOT DRY -> `그래도 마를 일은 없다` (turned positive for the slime).
- Level names: alliteration only in `사암 성소`; `화산 금고` (VOLCANIC VAULT) may sound odd, `화산 보물고` is an option.
- `randomizer` -> `랜덤마이저` (gamer loanword); a kid-friendlier alternative would be `랜덤 포털`.
- Pending: the new key `language.title` (LANGUAGE, from the uncommitted language screen) is not in messages.pot yet;
  suggested `언어`.
