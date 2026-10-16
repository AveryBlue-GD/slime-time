# French (fr) glossary

Register: informal `tu`, imperative without pronoun where possible (`CHOISIS TA COULEUR`).
All msgstr in capitals with accents (`É È À Ç Ô Û Î Ê Ï Œ`).

## Typography

- Narrow no-break space U+202F (2 px) before `! ? : ;` (`SON : OUI`, `TEMPS ÉCOULÉ !`).
- Apostrophe: typographic `’` (U+2019) everywhere.
- Percent: no space before `%` (`+30%`, `{percent}%`), same as the HUD; a deliberate UI choice for width.
- Quotes (if ever needed): `« … »` with U+202F inside.
- Layout spaces of the English (`TEMPS {time}   RECORD {best}`) kept as is.

## Terms

| English | French | Notes |
|---|---|---|
| SLIME (the hero, the meter) | SLIME (masc.) | `PLUS DE SLIME`, `LE SLIME SÈCHE` |
| goo | BAVE | `TIRE DE LA BAVE`, trail descriptions |
| trail | TRACE | trail names `TRACE D’ENCRE`…; tab `TRACES`; `SKIN GOO` = `BAVE ASSORTIE` |
| chalice | CALICE | `CALICE ENGLOUTI !` |
| meter / tank | JAUGE / CUVE | boons use `CUVE` (tank) |
| ticket / TIX | TICKET(S) / TIX | `TIX` kept as the short unit |
| coin | PIÈCE | upgrades tab `SOUS` (32 px tab) |
| maze | LABYRINTHE; short `LABY` | `LABY` on buttons / HUD (`NOUVEAU LABY`, `MÊME LABY`, `LABY ALÉATOIRE`) |
| level | NIVEAU; short `NIV.` | `CODE NIV{code}` |
| floor (Descent) | ÉTAGE | |
| pot | POT | as in poker |
| run (Descent) | PARTIE | `PARTIES PAYÉES`, `NOUVELLE PARTIE` |
| descent | DESCENTE | |
| boon | FAVEUR (fem.) | as in Hades FR |
| heat | CHALEUR; pods `CHAL.` | 50 / 52 px pods |
| hard mode | MODE DIFFICILE / DIFFICILE | |
| upgrades | AMÉLIORATIONS; button `AMÉLIORER` | 76 px choice button |
| hub | QG | `ENTRER AU QG`, `RETOUR AU QG` |
| randomizer | MODE ALÉATOIRE | |
| seed | GRAINE | |
| skin | SKIN (masc.) | `NOUVEAU SKIN` |
| jelly | GELÉE | `SKINS GELÉE`, `GELÉE : OUI` |
| hat | CHAPEAU | wheel tab `COIFFES` (44 px) |
| paper | PAPIER | |
| wheel / spin | ROUE / TOURNER, `TOUR` (a spin) | |
| tailor | TAILLEUR | |
| wardrobe | GARDE-ROBE | |
| shop | BOUTIQUE | |
| leap | BOND | |
| glide | GLISSE / GLISSADE | |
| splat | SPLAT | `SPLATCH` only in the level 1 story line |
| jump (button) | SAUT | |
| assist | AIDE | |
| practice | ENTRAÎNEMENT | |
| medal | MÉDAILLE; BRONZE / ARGENT / OR | |
| dried up | DESSÉCHÉ | |
| cash out / bank | ENCAISSER | |
| BACK | RETOUR | overflow, see doubts |
| SETTINGS / OPTIONS / MORE | RÉGLAGES / OPTIONS / PLUS | |

Kept names: `SLIME TIME`, `INKKY`, `CHAMELEON`, `SLIMAKAZE`; pad / key names (`ESC`, `START`, `A`…).

## Doubts for a native reviewer

- `common.back` `RETOUR` is 36 px for a 32 px budget (translator comment `overflow:` in the .po).
  `upgrades.tab_tools` `OUTILS` 34 > 32 (hidden tab). `upgrades.tab_coins` uses `SOUS` (colloquial
  "money") because `PIÈCES` is 34 px; check it reads well next to `TICKETS`.
- `wheel.section.hats` `COIFFES` instead of `CHAPEAUX` (48 px > 44 px).
- `LABY` (colloquial short for labyrinthe) on buttons and in the HUD.
- Level names: `DONJON DES DAMNÉS` (dark dungeon; is "damnés" fine for kids?), `TEMPLE TREMPÉ`
  (sunken shrine, playful alliteration), `FORTERESSE FIGÉE` (frozen), `SANCTUAIRE DE SABLE` (sandstone).
- Tagline pun: `FUIS LA BRUME / OU SÈCHE EN ESSAYANT` (after "mourir en essayant").
- Ford joke: `(LA COULEUR QUE TU VEUX)`; the original pun may not land in French.
- Story lines: 5 `UN SLIME DANS LA VASE` (slime-in-slime pun lost), 7 `NE GRELOTTE PAS. IL TREMBLOTE.`,
  8 `TOI, TU ES INOUBLIABLE` (oubliette pun works in French).
- Boons / heat mods: `VESSIE DE SECOURS`, `BAVE CUPIDE`, `LA BRUME MORD`, `CLOUÉ AU SOL`.
- `GOO NOSE` = `FLAIR GLUANT`; `SECOND WIND` = `REGAIN` (fits the 40 px pod); `WALL POWER` = `CASSE-MURS`.
- `TIX EN JEU {count}` for "TIX AVAILABLE" (tickets a win pays now).
- `hud.pod.paid_run` = `PAYÉE {slot}/{total}` (short for "partie payée").
