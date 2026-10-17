# German (de) glossary

Informal `du`, ALL CAPS, `SS` for ß (`GROSS`, `SCHLIESST`, `HEISS`). Buttons use the infinitive or a
noun (`NEUSTART`, `KAUFEN`, `FERTIG`); hints use the short `du`-imperative (`SCHAFF`, `WÄHL`, `TRAG`).
German compounds run long, so shorter synonyms win over hyphen-splitting (`HÜPF` for JUMP, `LOS!` for
PLAY on the 32 px button). Quotes `„…“` (none used yet). The English ` - ` dash is kept. Plurals: 2 forms;
where the code does not pluralize, the number stays in a neutral spot (`ALLE {count} LABYRINTHE`).
Widths measured with `assets/fonts/pixel.fnt` (sum of advances, `{x}` = 888, big font x2) against the
`#. budget` lines and the `# i18n:` width notes in the code.

## Terms

| English | German | Notes |
|---|---|---|
| SLIME TIME | SLIME TIME | Latin, never translated; `Slime Time` in the mixed-case browser dialogs |
| slime (hero, meter, substance) | SCHLEIM | `MEHR SCHLEIM`, `SCHLEIM IM SCHLEIM` (story 5), m. (`ER WABBELT`) |
| goo | GLIBBER | `SPUCKT GLIBBER`, `SKIN-GLIBBER`, `GLIBBERNASE` |
| chalice | KELCH | `KELCH VERSCHLUCKT!`, `KELCHGOLD`, `KELCHGESPÜR` |
| ticket / TIX | TICKET(S) / TIX | `TIX` only where English has TIX |
| coin | MÜNZE | coin bag = MÜNZBEUTEL, in hand = IM BEUTEL |
| maze | LABYRINTH | random maze = ZUFALLSLABYRINTH; NEW MAZE button = NEU WÜRFELN (76 px) |
| level / LV / L | LEVEL / LV | `LEVEL {level}/{total}`; plural LEVELS |
| hard mode / HARD | SCHWERER MODUS / SCHWER | `AUF SCHWER` = on hard |
| HEAT | HITZE | |
| upgrade(s) | UPGRADE(S) | common in German games, short |
| hub | HUB | `ZUM HUB` |
| randomizer | ZUFALLSMODUS | |
| seed | SEED | |
| descent / descend | ABSTIEG / ABSTEIGEN | |
| floor (Descent) | EBENE | |
| run (Descent) | LAUF | paid run = TICKETLAUF, HUD pod `TIX-LAUF` (80 px) |
| pot | POTT | |
| cash out / bank | AUSZAHLEN | |
| boon | SEGEN | |
| practice | ÜBUNG | |
| skin / jelly skin | SKIN / GELEE-SKIN | `GELEE: AN / AUS` |
| hat | HUT | hat wheel = HUTRAD, also the "prize wheel" |
| wardrobe | KLEIDERSCHRANK | |
| tailor | SCHNEIDER | |
| shop | SHOP | |
| story (mode) | STORY | kept like LEVEL / SHOP / UPGRADES (gaming loanword): `title.story`, `hub.station.story`, `hub.coins.total`; open owner question (re-review low), not an oversight |
| trail | SPUR | |
| paper (map) | PAPIER | |
| spin | DREHEN / DREH | `GRATIS DREHEN` on the 84 px button |
| leap / jump (action) | SPRUNG | key list, pad note |
| JUMP (touch key, keycap) | HÜPF | 27 / 34 px; `HÜPF TIPPEN`, `HÜPF SCHLIESST` |
| glide | GLEITEN | |
| splat (hitting a wall) | PLATSCHER | `PLATSCHER-KOSTEN` |
| medal / record / best | MEDAILLE / REKORD / BESTZEIT | `BISHER GOLD` = best medal |
| attempt | VERSUCH | |
| assist | HILFE | |
| restart | NEUSTART | |
| back | ZURÜCK | 36 px vs 32 px budget, see doubts |
| locked | GESPERRT | |
| par (time) | SOLLZEIT | |
| on / off | AN / AUS | |
| MAX / MAXED | MAX | |

## Names

- Kept: `SLIME TIME`, `INKKY`, `CHAMELEON`, `SLIMAKAZE`.
- Abilities: SCHLEIMFLINTE, SCHLEIMBOMBE, SLIMAKAZE.
- Skins: LIMETTE, MINZE, ZITRONE, OZEAN, TRAUBE, KARMIN, FROST, INKKY, KAUGUMMI, GLUT, REGENBOGEN, STOPPUHR, CHAMELEON.
- Levels: DUNKLER DUNGEON, MOOSIGE MINEN, SANDSTEINTEMPEL, VERSUNKENER SCHREIN, TOXISCHE TUNNEL, GRUSELGRUFT,
  FROSTIGE FESTUNG, OBSIDIANVERLIES, KRISTALLHÖHLEN, VULKANGEWÖLBE (alliteration kept where it came naturally).
- Hats: KEIN HUT, ZYLINDER, MÜTZE, PARTYHUT, BASECAP, COWBOYHUT, KOCHMÜTZE, ZAUBERHUT, WIKINGERHELM,
  PROPELLERMÜTZE, KRONE, REGENBOGENHUT.
- Upgrades: MEHR SCHLEIM, TEMPO, HELLIGKEIT, WANDKRAFT. Workshop: ZWEITER ATEM (HUD pod `ATEM`), SCHNELLLADEN,
  KLEBRIG, MAGNET, GLIBBERNASE.

## Doubts for a native reviewer

- `common.back` ZURÜCK (36 px) and `upgrades.tab_coins` MÜNZEN (36 px) exceed the 32 px budget (they still fit
  inside the 40 px buttons); marked `# overflow:` in the .po. No natural shorter word found.
- `title.tagline.1/2` ENTKOMM DEM NEBEL / ODER VERTROCKNE: the dry / die pun is lost; "or dry up" keeps the threat.
- `result.chalice` KELCH VERSCHLUCKT! (swallowed) for "consumed": checks the tone.
- `result.choice.new_maze` NEU WÜRFELN ("reroll") instead of a literal "new labyrinth" (too wide for 76 px);
  `result.seed_paid` points to it.
- `result.choice.next_level` and `.continue` are both WEITER (NÄCHSTES LEVEL is 81 px > 76).
- `levels.hard_mode` "NEBEL HOLT AUF" (fog catches up) for FOG RETURNS, and NEUE WEGE for new mazes (268 px).
- Story lines 2 (DU BALD AUCH), 7 (ER WABBELT), 8 (DICH VERGISST KEINER): deadpan rewrites, please check rhythm.
- `upgrade.power` WANDKRAFT: meaning of WALL POWER not fully clear from context.
- `theme.catacombs` GRUSELGRUFT (crypt instead of catacombs, for the alliteration); `theme.sandstone` SANDSTEINTEMPEL.
- `paper.blueprint` BLAUPAUSE and `paper.goldleaf` BLATTGOLD (dropped "paper" for width).
- `wheel.worn` AN, `wheel.owned` DEINS: very short, confirm they read well next to the item.
- `language.title` (SPRACHE) is filled for the new key that the working-tree code has but the committed
  messages.pot does not yet.
- Fix pass F4: `skins.wearing` is (AKTIV), not (AUFGESETZT): the key is shared by hats and trails.
