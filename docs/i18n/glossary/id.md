# Indonesian (id) glossary

Bahasa Indonesia, casual game register: `KAMU` / `-MU` when a sentence needs the player
(`KAMU LOLOS!`, `PROGRESMU`), bare imperatives on buttons and hints (`PILIH`, `TEKAN UNTUK MEMBELI`).
No Malay-only words. Everything in capitals; Western digits, `.` decimals. Straight quotes; `!` / `?`
without a space; `2X` style for "twice". Widths measured with the slimy font (`pixel.fnt` xadvance)
against every `budget: max Npx` and the real button / tile sizes.

## Terms

| English | Indonesian | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated (logo) |
| slime (hero, meter, substance) | SLIME | the word Indonesian players use; `TAMBAH SLIME` = MORE SLIME |
| goo | LENDIR | trail / ability material |
| chalice | CAWAN | `CAWAN DILAHAP!` = CHALICE CONSUMED! |
| tank (slime capacity) | TANGKI | |
| ticket / TIX | TIKET | TIX written in full |
| coin | KOIN | |
| maze | LABIRIN | random maze = `LABIRIN ACAK` |
| level | LEVEL | as players say it |
| floor (Descent) | LANTAI | best floor = `REKOR LANTAI {n}` |
| story | CERITA | |
| hard mode / HARD | MODE SULIT / SULIT | |
| HEAT | PANAS | |
| upgrade | UPGRADE | common gamer loanword (no plural -S) |
| hub | MARKAS | (base) `MASUK MARKAS` |
| randomizer | PENGACAK | |
| Descent | KEDALAMAN | mode name ("the depths"); DESCEND = `TURUN` |
| pot | POT | prize-pot sense |
| cash out | CAIRKAN | |
| run | RUN | roguelike term, kept |
| paid run | RUN HADIAH | |
| boon | BERKAH | |
| skin | SKIN | |
| jelly (skin) | JELI | |
| hat | TOPI | |
| trail | JEJAK | |
| paper (map paper) | KERTAS | |
| wheel / prize wheel | RODA / RODA HADIAH | |
| shop | TOKO | |
| tailor | PENJAHIT | |
| jump / leap | LOMPAT / LOMPATAN | |
| glide | LUNCUR | |
| splat (hitting a wall after a leap) | BENTURAN | |
| medal | MEDALI | PERUNGGU / PERAK / EMAS |
| record / best | REKOR / TERBAIK | |
| seed | SEED | kept |
| save code | KODE SIMPAN | |
| progress | PROGRES | |
| dried up | KERING | |
| ON / OFF | NYALA / MATI | |
| BACK | BALIK | 32 px budget (`KEMBALI` is 40 px) |
| MAX / MAXED | MAKS | |
| assist | BANTUAN (HUD pod: BANTU) | |
| attempt | PERCOBAAN | |
| practice | LATIHAN | |
| pause | JEDA | |
| pad (gamepad) | PAD | |

Kept names: `INKKY`, `CHAMELEON`, `SLIMAKAZE` letter for letter. Units: `S`, `PX`, `X1.5`, `3X3`, `%` kept.

## Names

- Levels: TAMBANG BERLUMUT, SUAKA BATU PASIR, KUIL KARAM, TEROWONGAN TOKSIK, KATAKOMBE KELAM,
  BENTENG BEKU, SEL OBSIDIAN, GUA KRISTAL, LIANG LAHAR, PENJARA GELAP (alliteration: KUIL KARAM,
  TEROWONGAN TOKSIK, KATAKOMBE KELAM, BENTENG BEKU, LIANG LAHAR).
- Skins: JERUK NIPIS, MINT, LEMON, SAMUDRA, ANGGUR, MERAH TUA, EMBUN BEKU, PERMEN KARET, BARA,
  PELANGI, STOPWATCH.

## Doubts for a native reviewer

- Tagline `KABUR DARI KABUT` / `ATAU MATI KERING`: KABUR/KABUT wordplay replaces the dry/die pun;
  check `MATI KERING` is fine for kids.
- `UPGRADE`, `RUN`, `SEED`, `SKIN`, `POT` kept as gamer loanwords; `POT` may read as "flower pot".
- `KEDALAMAN` (Descent), `MARKAS` (hub), `BERKAH` (boon), `PENGACAK` (randomizer): invented game terms.
- `GOO NOSE` -> `HIDUNG LENDIR` (no pun); `SLIMAKAZE` kept.
- Heat modifier `FOG BITES` -> `KABUT BUAS` ("fierce fog"; the bite is lost), 58 px in a ~56 px slot.
- Story line 1 `PLOK.` for SPLAT (onomatopoeia); line 7 `SLIME BERGOYANG` (jiggles); line 8
  `KAMU TAK TERLUPAKAN`.
- `ANY COLOR YOU LIKE` -> `WARNA APA PUN SESUKAMU`: Henry Ford joke not known; literal meaning kept.
- `REPLAY MAZE`, `REPLAY`, `RESTART` all `ULANGI` (never shown together).
- Overflow: `LOMPAT` (JUMP) is 36 px; the tutorial keycap allows 27 px and the touch button 34 px.
  No shorter natural word (`LONCAT` is the same width). Marked `# overflow:` in id.po; layout fix needed
  or accept the English `JUMP` there.
- `RUN HADIAH {slot}/{total}` HUD pod fits 80 px only with 1-digit values (real values are 1-3).
- `SULIT: LABIRIN BARU, TANPA UPGRADE, KABUT KEMBALI` drops "MODE" to fit the 268 px checkbox.
