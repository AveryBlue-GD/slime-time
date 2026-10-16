# Polish (pl) glossary

Informal 2nd person singular, ALL CAPS with `Ą Ć Ę Ł Ń Ó Ś Ź Ż`. **Gender-neutral wording**: Polish past tense
and adjectives about "you" are gendered (`UCIEKŁEŚ / UCIEKŁAŚ`), so lines about the player use imperatives,
impersonal forms or nouns (`UCIECZKA UDANA!`, `ODBLOKOWANO`, `WYGRANA: {name}!`, `CIEBIE NIKT NIE ZAPOMNI`).
Lines about the slime itself are masculine (`WYSCHNIĘTY`, the hero is `SZLAM`, m.). Status words use the neuter
(`ZABLOKOWANE`). Where a kept or variable name would need a case ending, a colon avoids it (`KUPIĆ: {name}?`).
Quotes `„…”` (none used yet). The English ` - ` dash is kept. Plurals: 3 forms (1 / 2-4, 22-24 / rest), each
with its own case (`BILET / BILETY / BILETÓW`); where the code does not pluralize, the number goes after a
colon or in a fixed-count form (`UKOŃCZONE LABIRYNTY: {count}`, `UKOŃCZ {count} POZIOMÓW` with 10 levels).
Widths measured with `assets/fonts/pixel.fnt` (sum of advances, `{x}` = 888, big font x2).

## Terms

| English | Polish | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated; `Slime Time` in the mixed-case browser dialogs |
| slime (hero, meter, substance) | SZLAM | `WIĘCEJ SZLAMU`, `SZLAM W SZLAMIE`, m. |
| goo | MAŹ | `PLUJE MAZIĄ`, `MAŹ SKÓRKI`, `NOS DO MAZI` |
| chalice | KIELICH | `KIELICH POŁKNIĘTY!` |
| ticket / TIX | BILET / BIL. | `BIL.` only where English has TIX |
| coin | MONETA | coin bag = SAKIEWKA |
| maze | LABIRYNT | random maze = LOSOWY LABIRYNT |
| level / LV / L | POZIOM / LV | `LV` kept in the HUD code line |
| hard mode / HARD | TRYB TRUDNY / TRUDNY | `NA TRUDNYM` = on hard |
| HEAT | ŻAR | as in the Polish Hades |
| upgrade(s) | ULEPSZENIA | |
| hub | BAZA | `DO BAZY`, `W BAZIE` |
| randomizer | TRYB LOSOWY | |
| seed | ZIARNO | |
| descent / descend | ZEJŚCIE / ZEJDŹ | |
| floor (Descent) | PIĘTRO | |
| run (Descent) | WYPRAWA | paid run = WYPRAWA Z NAGRODĄ, HUD `NAGRODA {slot}/{total}` |
| pot | PULA | |
| cash out | WYPŁAĆ | |
| boon | DAR | |
| bounty | PREMIA | |
| practice | TRENING | |
| skin / jelly skin | SKÓRKA / ŻELOWA SKÓRKA | toggle `ŻEL: WŁ. / WYŁ.` |
| hat | CZAPKA | generic, fits the 44 px tab; hat wheel = KOŁO CZAPEK |
| wardrobe | GARDEROBA | |
| tailor | KRAWIEC | |
| shop | SKLEP | |
| trail | ŚLAD | |
| paper (map) | PAPIER | |
| spin | KRĘĆ / ZAKRĘCENIE | |
| leap / jump | SKOK | touch key and keycap too |
| glide | ŚLIZG | |
| splat (hitting a wall) | PLASK | |
| medal / record / best | MEDAL / REKORD | `REKORD: ZŁOTO` = best medal |
| attempt | PRÓBA | |
| assist | POMOC | |
| restart | OD NOWA | title `ZACZĄĆ OD NOWA?` |
| back | WRÓĆ | |
| locked | ZABLOKOWANE | |
| par (time) | NORMA | |
| on / off | WŁ. / WYŁ. | |
| MAX / MAXED | MAKS | |

## Names

- Kept: `SLIME TIME`, `INKKY`, `CHAMELEON`, `SLIMAKAZE`.
- Abilities: SZLAMOMIOT, SZLAMOBOMBA, SLIMAKAZE.
- Skins: LIMONKA, MIĘTA, CYTRYNA, OCEAN, WINOGRONO, KARMAZYN, SZRON, INKKY, BALONÓWKA, ŻARZEWIE, TĘCZA, STOPER, CHAMELEON.
- Levels: MROCZNE LOCHY, OMSZAŁA KOPALNIA, PIASKOWA ŚWIĄTYNIA, ZATOPIONA KAPLICA, TRUJĄCE TUNELE, KOSZMARNE KATAKUMBY,
  LODOWA TWIERDZA, OBSYDIANOWA CELA, KRYSZTAŁOWE GROTY, KRYPTA WULKANU.
- Hats: BEZ CZAPKI, CYLINDER, ZIMOWA CZAPKA, IMPREZOWA CZAPKA, BEJSBOLÓWKA, KAPELUSZ KOWBOJA, CZAPKA KUCHARZA,
  KAPELUSZ MAGA, HEŁM WIKINGA, CZAPKA ZE ŚMIGŁEM, KORONA, TĘCZOWA CZAPKA.
- Upgrades: WIĘCEJ SZLAMU, SZYBKOŚĆ, JASNOŚĆ, SIŁA NA ŚCIANY. Workshop: DRUGI ODDECH (HUD `ODDECH`), SZYBKI ŁADUNEK,
  LEPKOŚĆ, MAGNES, NOS DO MAZI.

## Doubts for a native reviewer

- `upgrades.tab_coins` MONETY (36 px) exceeds the 32 px budget (fits inside the 40 px tab); marked `# overflow:`.
- `upgrades.tab_tools` GRATY (slang "gear", 30 px) because NARZĘDZIA / SPRZĘT do not fit 32 px; workshop is off.
- `title.story` INTRO (STORY / FABUŁA is 36 px on the 32 px corner button; the button replays the intro).
- Slime = SZLAM (not ŚLUZ / GLUT / SLIME): please confirm it reads cute enough for kids.
- `title.tagline.1/2` UCIEKNIJ PRZED MGŁĄ / ZANIM WYSCHNIESZ: the dry / die pun is lost.
- `result.dried_up` WYSCHNIĘTY (masculine, about the slime) vs. a neutral noun like WYSCHNIĘCIE.
- Story lines 2 (NIC DZIWNEGO), 7 (SZLAM SIĘ CHYBOCZE for "it jiggles"), 8: deadpan rewrites, check rhythm.
- `ability.rifle.name` SZLAMOMIOT (coined, like "miotacz"), `ability.kaze.desc` TARAN ŚCIAN.
- `paper.blueprint` ŚWIATŁOKOPIA (the real term, maybe too technical for players).
- `heatmod.race.desc` "1.3 X NORMY" for par time; `upgrade.power` SIŁA NA ŚCIANY (meaning of WALL POWER unclear).
- `hub.resume.floor_cleared` uses ZDANE (not ZALICZONE) for the 150 px limit.
- `skins.locked_medals` "WSZYSTKIE {count} MEDALI" (genitive after 5+) is colloquial but common.
- `language.title` (JĘZYK) is filled for the new key that the working-tree code has but the committed
  messages.pot does not yet.
