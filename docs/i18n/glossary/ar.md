# Arabic (ar) glossary

Modern Standard Arabic, light and playful game register. The player is addressed with the masculine
singular imperative / 2nd person (the usual neutral game form): `العب`, `اجتز`, `ربحت`. Text is written in
logical order; the engine does shaping and RTL, the layout is mirrored (chunk I). No bidi control characters
are used. Western digits (`0-9`, `.`) everywhere. Arabic comma `،` and question mark `؟`; `!` as usual.
No diacritics (harakat, shadda, tanween) are written: Unifont's marks stack badly at 16 px and the UI reads
fine without them. Measured with the real chain (slimy font + Unifont 16): every Arabic letter is 8 px,
the space 4 px, digits 6 px, so Arabic needs fewer letters than English for the same width.

## Terms

| English | Arabic | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated (logo) |
| slime (hero, meter, substance) | سلايم | transliteration, as Arabic gamers say it; `سلايم أكثر` = MORE SLIME |
| goo | دبق | trail / ability material (`يطلق الدبق`) |
| chalice | الكأس | `ابتلعت الكأس!` = CHALICE CONSUMED! |
| meter | عداد | |
| ticket / TIX | تذكرة / تذاكر | TIX is never abbreviated in Arabic; full word |
| coin | عملة / عملات | COINS tab (32 px) uses `نقود` |
| maze | متاهة / متاهات | |
| level | مستوى / المستوى | |
| hard mode / HARD | الوضع الصعب / صعب | |
| HEAT | لهب | chosen for width (pods 50-52 px); a flame icon sits next to it |
| heat modifiers | (names translated, see po) | |
| upgrade | ترقية / ترقيات | |
| hub | الساحة | |
| randomizer | متاهات عشوائية | random maze = متاهة عشوائية |
| seed | البذرة | |
| descent | الهبوط | floor = طابق; DESCEND = انزل |
| pot | الجرة | HUD pods use `جرة` (no article) for width |
| cash out / bank half | اصرف / يصرف نصف الجرة | |
| boon | منحة | |
| run | جولة | paid run = جولة مدفوعة |
| skin | مظهر / مظاهر | |
| jelly (skin) | هلام / هلامي | |
| hat | قبعة / قبعات | |
| hat wheel / prize wheel | عجلة القبعات / عجلة الجوائز | |
| spin | أدر (button), دورة (count) | |
| tailor | الخياط | |
| wardrobe | الخزانة | |
| trail | أثر / آثار | |
| paper (map) | ورق / أوراق | |
| map table | طاولة الخرائط | |
| leap / jump | قفز / قفزة | |
| glide | انزلاق | |
| splat | فرقعة | |
| assist | مساعدة (HUD pod: عون, 60 px) | |
| medal | ميدالية; BRONZE / SILVER / GOLD = برونزية / فضية / ذهبية | |
| record / best | رقم قياسي / الأفضل | |
| ON / OFF | مفعل / معطل | for every toggle |
| BACK | رجوع | |
| gamepad (PAD) | الذراع | |
| PX | بكسل | |
| X (multiplier), 3X3 | X1.5, 3X3 kept | `×` not checked in the font |
| list separator | `، ` | |

## Kept names, transliterated

| Name | Arabic |
|---|---|
| INKKY | إنكي |
| CHAMELEON | كاميليون |
| SLIMAKAZE | سلايماكازي |

Skin colours are translated: LIME فستقي (pistachio green), MINT نعناعي, LEMON ليموني, OCEAN بحري,
GRAPE عنبي, CRIMSON قرمزي, FROST صقيع, BUBBLEGUM علكة, EMBER جمر, RAINBOW قوس قزح, STOPWATCH ساعة إيقاف.

Levels: الدهليز الداكن (Dark Dungeon, alliteration kept), مناجم الطحالب, محراب الرمال, المعبد الغارق,
الأنفاق السامة, السراديب المرعبة, الحصن المتجمد, جب السبج, كهوف الكريستال (alliteration kept), القبو البركاني.

## Plurals (6 forms)

0 zero, 1 one, 2 two (dual), 3 = 3-10 (plural noun: `{count} تذاكر`), 4 = 11-99 (singular accusative:
`{count} تذكرة`, `{count} طابقا`), 5 = 100+ (singular genitive: `{count} طابق`). Short numeric labels
(`+{count} تذكرة`, `جرة {count}`, `بقي {count}`) keep the digit in every form; prose forms 1 / 2 use the word
(`تذكرة واحدة`, `تذكرتين`, `قبعتان`).

## Bidi spots to look at on screen (no control characters inserted)

- A leading `+` or `-` before a number in an RTL line shows on the number's right (`30%+`, `888+`): the usual
  look in Arabic UIs, but check `boon.gulp.desc_1`, `hub.notice.returned`, `result.tickets`, `descent.*`.
- `result.ticket_attempt` (`تذكرة! محاولة {n} = +{count}`) and `levels.info_hard.2` (`لهب 2 4 7 10 يدفع 3 5 7 10`):
  numbers separated by spaces / `=` are laid out right to left, so they read correctly right to left, but look
  reversed to an LTR eye. Check the HEAT-to-tickets pairs read correctly.
- `upgrades.hint_pad` (`الذراع {a} {b} {c}`): pad letters like `A X Y` form one LTR run (A left, Y right),
  while the mirrored ability row may put ability 1 on the right. Number keys (`1 2 3`) do reverse. Check the
  order matches the icons.
- `workshop.nose.value` was reordered to `{reach} بكسل X{rate}` so `X1.5` does not glue to the pixel value.
- `keys.note.*`, `hub.coins.close_key`, `savecode.click_box`, `rotate.body`: Latin key names / SLIME TIME sit
  inside Arabic text; every such line starts with an Arabic word so an auto-direction label still picks RTL.
- Browser dialogs (`savecode.prompt_*`) end with Arabic + `:` so the colon lands correctly in an LTR dialog.
- `->` in `workshop.*.next` relies on bidi mirroring (`>` shows as `<` in RTL) so the arrow points from the
  current value (right) to the next one (left).

## Width notes (measured, placeholders = 888)

- Over budget only with the synthetic 888 fill: `hud.pod.paid_run` (94 / 80; English is 90 too),
  `upgrades.buy_confirm` (142 / 140 with a long name). `upgrades.tab_tickets` is 40 px against the shared
  32 px budget line, but the TICKETS tab is 44 wide (as in English).
- Shortened to fit: NEXT LEVEL = `التالي`, REPLAY MAZE = `العب مجددا`, PRESS KEY = `اضغط`, QUIT TO HUB =
  `الساحة` (pause button), hard-mode checkbox `صعب: متاهات أخرى، لا ترقيات، ضباب يعود`, key notes
  `الأسهم للحركة` (drops "always"), `hud.area.random_code` drops `عشوائية`.

## Doubts for a native reviewer

- `سلايم` (transliteration) for slime vs. a native word (`هلام` clashes with jelly, `وحل` = mud). And `دبق` for goo.
- HEAT = `لهب` (flame) chosen for width; `حرارة` would be more literal but does not fit the HUD pods.
- Tagline pun: `اهرب من الضباب` / `أو جف وأنت تحاول` (parody of `أو مت وأنت تحاول`, "die trying").
- CHALICE CONSUMED! = `ابتلعت الكأس!` ("you swallowed the chalice").
- Story lines: SPLAT = `طاخ` onomatopoeia; level 5 `سلايم وسط الوحل` (the "slime in slime" pun is lost);
  level 7 `بل يترجرج` (jiggles); level 8 `أما أنت فلا تنسى`.
- Henry Ford joke (ANY COLOR YOU LIKE) = `بأي لون يعجبك`: the joke does not exist in Arabic, kept literal.
- Names: OBSIDIAN OUBLIETTE = `جب السبج` (السبج may be unfamiliar), PARCHMENT = `ورق عتيق`, LIME = `فستقي`,
  OCEAN = `بحري`, GOO NOSE = `أنف لزج` (playful "gooey nose"), BACKUP BLADDER = `مثانة احتياطية`, GROUNDED =
  `ملتصق بالأرض`, top hat = `قبعة عالية`.
- `مفعل / معطل` for every ON / OFF; `الذراع` for the gamepad (`يد التحكم` is the longer alternative).
- Gender of the hidden `{name}`: status lines avoid agreement (`(قيد الارتداء)`, `(مختار)`, `اضغط للبس`).
