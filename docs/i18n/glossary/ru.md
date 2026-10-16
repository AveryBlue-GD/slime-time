# Russian (ru) glossary

Neutral Russian game register, ALL CAPS. The player is addressed with the short informal imperative
(`ПРОЙДИ`, `ЖМИ`, `ВЫБЕРИ`) and no pronoun where possible, which is what Russian games do; `ТЫ` / `ТВОЙ`
only where a sentence needs it. Past-tense forms about the slime are masculine (`ВЫСОХ`, the hero is
`СЛАЙМ`, m.). **Ё is always written** (`ПОГЛОЩЁН`, `ЕЩЁ`, `ЗВЁЗДНЫЙ`). Quotes `«…»` (none used yet).
Dash in UI lines: the English `-` is kept as is. Plurals: 3 forms (1 / 2-4 / 5+), every `{count}` entry
has its own case forms (`БИЛЕТ / БИЛЕТА / БИЛЕТОВ`); where agreement with a number the code does not
pluralize is needed, the number goes after a colon or in parentheses (`ПРОЙДИ ВСЕ УРОВНИ ({count})`).
Widths were measured with `assets/fonts/pixel.fnt` (Cyrillic capitals are 6 px with spacing).

## Terms

| English | Russian | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated (logo) |
| slime (the hero) | СЛАЙМ | `СТЕКЛЯННЫЙ СЛАЙМ`, story 5 / 7 |
| slime (meter, substance), goo | СЛИЗЬ | `+30% СЛИЗИ`, `БОЛЬШЕ СЛИЗИ`, `СЛИЗЬ ПОД СКИН` |
| chalice | КУБОК | `КУБОК ПОГЛОЩЁН!`, `ЧУТЬЁ НА КУБОК` |
| ticket / TIX | БИЛЕТ / БИЛ. | `БИЛ.` only where English has TIX and room is short |
| coin | МОНЕТА | coin bag = МЕШОК МОНЕТ |
| maze | ЛАБИРИНТ | random maze = СЛУЧАЙНЫЙ ЛАБИРИНТ; HUD area line with HARD / CODE drops СЛУЧАЙНЫЙ for width |
| level / LV / L | УРОВЕНЬ / УР. | |
| hard mode / HARD | СЛОЖНЫЙ РЕЖИМ / СЛОЖНО | `НА СЛОЖНОМ` = on hard |
| HEAT | ЖАР | |
| upgrade(s) | УЛУЧШЕНИЯ | `ПРОКАЧКА` once (hard-mode checkbox, width) |
| hub | ХАБ | |
| randomizer | РАНДОМАЙЗЕР | |
| seed | СИД | |
| descent / descend | СПУСК / ВНИЗ | |
| floor | ЭТАЖ | |
| run | ЗАБЕГ | paid run = ПЛАТНЫЙ ЗАБЕГ; HUD pod: `ЗАБЕГ {slot}/{total}` |
| pot | БАНК | cash out = ЗАБРАТЬ (БАНК); half the pot = ПОЛБАНКА |
| quit run | СДАТЬСЯ | 56 px button |
| practice | ПРАКТИКА | |
| boon | ДАР | |
| skin / jelly skin | СКИН / ЖЕЛЕЙНЫЙ СКИН, ЖЕЛЕ | |
| hat | ШЛЯПА | |
| trail | СЛЕД | |
| paper (map paper) | БУМАГА | |
| wheel / hat wheel / prize wheel | КОЛЕСО / КОЛЕСО ШЛЯП / КОЛЕСО ПРИЗОВ | |
| spin | КРУТИ (button), ВРАЩЕНИЕ (count) | `КРУТИ  ДАРОМ` = SPIN FREE (76 px) |
| shop | ЛАВКА | МАГАЗИН does not fit the 44 px tab |
| tailor | ПОРТНОЙ | |
| free | БЕСПЛАТНО / ДАРОМ | ДАРОМ on the spin button |
| leap / jump | ПРЫЖОК; keycap and touch button `ПРЫГ` (27 / 34 px) | |
| glide | СКОЛЬЖЕНИЕ | |
| splat (wall hit) | ШЛЕПОК | `ЦЕНА ШЛЕПКА`, `ШЛЕПКИ X2` |
| assist | ФОРА | short, fits the 60 px HUD pod |
| restart | ЗАНОВО | |
| resume | ПРОДОЛЖИТЬ (pause), ДАЛЕЕ (hub 56 px) | |
| medals | БРОНЗА / СЕРЕБРО / ЗОЛОТО; best = РЕКОРД: … | |
| record / best | РЕКОРД / ЛУЧШИЙ | |
| PX | ПКС | |
| X (multiplier) | X (Latin) | `X1.5`, `3X3` |
| MAX / MAXED | МАКС | |
| pad | ПАД | |

## Kept names (transliterated)

| English | Russian |
|---|---|
| INKKY | ИНККИ |
| CHAMELEON | ХАМЕЛЕОН (the Russian word is the sound form) |
| SLIMAKAZE | СЛАЙМАКАДЗЕ (keeps the КАМИКАДЗЕ pun) |

## Names

Abilities: СЛИЗЕМЁТ (slime rifle), СЛИЗЕБОМБА (slime splat). Levels (alliteration kept where possible):
ТЁМНАЯ ТЕМНИЦА, МШИСТЫЕ ШАХТЫ, ПЕСЧАНОЕ СВЯТИЛИЩЕ, ЗАТОПЛЕННЫЙ ХРАМ, ТОКСИЧНЫЕ ТОННЕЛИ, КОШМАРНЫЕ КАТАКОМБЫ,
ЗАМЁРЗШАЯ ЗАСТАВА, ОБСИДИАНОВЫЙ ОСТРОГ, КРИСТАЛЬНЫЕ ПЕЩЕРЫ, ВУЛКАНИЧЕСКИЙ СКЛЕП. Skins: ЛАЙМ, МЯТА, ЛИМОН,
ОКЕАН, ВИНОГРАД, КАРМИН, ИНЕЙ, ЖВАЧКА, УГОЛЁК, РАДУГА, СЕКУНДОМЕР. Upgrades: БОЛЬШЕ СЛИЗИ, СКОРОСТЬ, ЯРКОСТЬ,
СТЕНОБОЙ (wall power). Tools: ВТОРОЕ ДЫХАНИЕ (HUD pod `ВДОХ`), БЫСТРЫЙ ЗАРЯД, ЛИПКОСТЬ, МАГНИТ, СЛИЗИСТЫЙ НЮХ.

## For a native reviewer

- `workshop.nose` СЛИЗИСТЫЙ НЮХ: pun on слизистая (nasal mucosa) for GOO NOSE. Check it reads as funny, not gross.
- `ability.kaze.name` СЛАЙМАКАДЗЕ: transliteration + камикадзе pun.
- `title.tagline` СБЕГИ ИЗ ТУМАНА / ИЛИ ВЫСОХНИ В ПУТИ: the "dry trying" pun is lost, rhythm kept.
- `result.chalice` КУБОК ПОГЛОЩЁН!: is ПОГЛОЩЁН the right comic weight for CONSUMED?
- Story lines: `story.level_4` (ФОРМАЛЬНО НЕ ПЛАВАНИЕ. НО И НЕ СУХО.), `story.level_7` (ДРОЖИТ / КОЛЫШЕТСЯ for
  shiver / jiggle), `story.level_8` (ТЕБЯ ЗАБЫТЬ НЕЛЬЗЯ), `story.level_9` (ДО СВЕТА РУКОЙ ПОДАТЬ: an idiom about
  hands, for a slime with no hands: intended as a joke).
- `result.unlocked_custom` / `victory.unlocked` ЛЮБОЙ ЦВЕТ НА ВЫБОР: the Henry Ford joke is not well known in
  Russian; kept literal.
- `paper.blueprint` СИНЬКА (the real term for blueprint paper), `paper.goldleaf` СУСАЛЬНОЕ ЗОЛОТО.
- `upgrade.power` СТЕНОБОЙ (coined, "wall-breaker"); `heatmod.grounded` НА ЗЕМЛЕ.
- `hud.area.random_code` КОД УР.{code} (ТВОЙ {own}): unclear what LV / YOU mean exactly in context.
- **Width overflows (`# overflow:` in the po)**: `upgrades.tab_coins` МОНЕТЫ and `upgrades.tab_tickets`
  БИЛЕТЫ are 35 px for a 32 px budget (40 px tab). No natural 5-letter word; the tab needs ~4 px more.
- `keys.jump` ПРЫЖОК (ДЕРЖИ) 77 px and `keys.interact` ДЕЙСТВИЕ (ХАБ) 77 px vs the 76 px note (labels are 84 wide).
