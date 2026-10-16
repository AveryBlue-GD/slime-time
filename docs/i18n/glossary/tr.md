# Turkish (tr) glossary

Standard Turkish, informal `sen` (imperatives `GEÇ`, `SEÇ`, `BAS`), ALL CAPS with correct dotted / dotless
casing: `i → İ`, `ı → I` (`SEVİYE`, `KILIK`, `ISI`). Never a lowercase i / ı or U+0307 in a capital word.
Kept Latin names keep their own letters (`SLIMAKAZE`, `INKKY`, `CHAMELEON`, `SLIME TIME`, `START`, `ESC`),
they are not Turkish-cased. Nouns after numbers stay singular (`3 BİLET`), so both plural forms are the
same text. **Percent sign goes before the number** (`%{percent}`, `+%30`, `-%10`), as Turkish writes it.
Suffixes are never glued onto a placeholder; numbers take an ordinal dot instead (`{level}. SEVİYEYİ GEÇ`)
or the phrase is turned (`KURUDUN: KAT {floor}`). Apostrophe `'` before a suffix on a quoted name
(`ZIPLA'YA`, `YÜKLE'YE`, `RASTGELE'DEN`). Quotes `“…”` (none used yet).
Widths measured with `assets/fonts/pixel.fnt` (`İ` and `I` are 4 px, other capitals 6 px).

## Terms

| English | Turkish | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated (logo) |
| slime (hero, meter, substance), goo | BALÇIK | one word for all; `DAHA ÇOK BALÇIK`, `+%30 BALÇIK` |
| chalice | KADEH | `KADEH YUTULDU!` |
| ticket / TIX | BİLET | TIX also BİLET (short enough) |
| coin | SİKKE | COINS tab `SİKKE` (32 px); coin bag = SİKKE KESESİ |
| maze | LABİRENT | random maze = RASTGELE LABİRENT |
| level / LV / L | SEVİYE / SV | |
| hard mode / HARD | ZOR MOD / ZOR | `ZORDA` = on hard |
| HEAT | ISI | |
| upgrade(s) | GELİŞTİRMELER; button `GELİŞTİR` | |
| hub | ÜS | `ÜSSE GİR`, `ÜSSE DÖN`, `ÜSTEKİ` |
| randomizer | RASTGELE | used as a noun (portal name) |
| seed | TOHUM | |
| descent / descend | İNİŞ / İN | |
| floor | KAT | |
| run | TUR | paid run = ÜCRETLİ TUR; HUD pod `TUR {slot}/{total}` |
| pot | KASA | cash out = KASAYI AL |
| quit run | BIRAK | 56 px button |
| practice | ANTRENMAN | |
| boon | LÜTUF | |
| skin / jelly skin | KILIK / JÖLE KILIK | KILIK fits the 32 px page button (KOSTÜM does not) |
| hat | ŞAPKA | |
| trail | İZ | |
| paper | KAĞIT | written without circumflex |
| wheel / hat wheel / prize wheel | ÇARK / ŞAPKA ÇARKI / ÖDÜL ÇARKI | |
| spin | ÇEVİR (button), ÇEVİRME (count) | |
| shop | DÜKKAN | |
| tailor | TERZİ | |
| free | BEDAVA | |
| leap / jump | SIÇRAMA (game term), ZIPLA (button / key) | |
| glide | KAYMA | |
| splat (wall hit) | ÇARPMA | |
| assist | YARDIM; HUD pod `EK +%{percent}` (60 px) | |
| restart | YENİDEN; key list `BAŞTAN AL` | |
| pause | MOLA | 16 px title (110 px) |
| record / best | REKOR / EN İYİ | |
| medals | BRONZ / GÜMÜŞ / ALTIN | |
| MAX / MAXED | MAKS | |
| PX | PX | kept |
| X (multiplier) | X | `X1.5`, `3X3` |
| pad | PAD | |

## Names

Kept: INKKY, CHAMELEON, SLIMAKAZE. Abilities: BALÇIK TÜFEĞİ, BALÇIK BOMBASI. Levels: KARANLIK ZİNDAN,
YOSUNLU MADENLER, KUMTAŞI MABEDİ, BATIK TAPINAK, TOKSİK TÜNELLER, KORKUNÇ KATAKOMPLAR, BUZ KALESİ,
OBSİDYEN HÜCRE, KRİSTAL MAĞARALAR, VOLKANİK MAHZEN. Skins: MİSKET (lime), NANE, LİMON, OKYANUS, ÜZÜM, KIZIL,
AYAZ, SAKIZ, KOR, GÖKKUŞAĞI, KRONOMETRE. Upgrades: DAHA ÇOK BALÇIK, HIZ, PARLAKLIK, DUVAR GÜCÜ. Tools:
İKİNCİ NEFES (HUD pod `NEFES`), HIZLI ŞARJ, YAPIŞKAN, MIKNATIS, BALÇIK BURNU.

## For a native reviewer

- `BALÇIK` for slime: alternatives are `SLIME` (as the toy is called in Turkey) or `JÖLE`; BALÇIK was picked
  for the dungeon mood. Check it does not read as plain mud.
- `KILIK` for skin: chosen for width; `KOSTÜM` or `GÖRÜNÜM` would be the longer usual words.
- `title.tagline` SİSTEN KAÇ / YOKSA KURURSUN: the "dry trying" pun is lost.
- `result.chalice` KADEH YUTULDU!; `workshop.nose` BALÇIK BURNU (GOO NOSE pun not reproduced).
- `skin.lime` MİSKET (short for misket limonu), distinct from LİMON (lemon).
- Story: `story.level_1` (ŞAP. onomatopoeia for SPLAT), `story.level_6` (ŞÜPHE ÇEKECEK KADAR),
  `story.level_7` (TİTREMEZ / PELTE GİBİ SALLANIR for shiver / jiggle).
- Level names: alliteration kept for TOKSİK TÜNELLER, KORKUNÇ KATAKOMPLAR, KRİSTAL; the others are plain.
- `victory.unlocked` İSTEDİĞİN HER RENK: the Henry Ford joke is kept literal.
- `heatmod.race.desc` 1.3 X HEDEF SÜREDE BİTİR YA DA KURU: "par" rendered as HEDEF SÜRE (target time).
- `hud.area.random_code` LABİRENT #{n}  KOD SV{code} (SEN {own}): RASTGELE dropped for width; unclear context.
- `keys.note.*`: "arrows always move" rendered as OKLAR HEP ÇALIŞIR (arrows always work).
