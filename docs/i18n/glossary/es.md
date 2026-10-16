# Spanish (es) glossary

Latin-American neutral Spanish, one Spanish for every country: `tú` (no `vosotros`, no voseo, no
`usted`), no Spain-only words (`presiona`, not `pulsa`; `piso`, not `planta`; `costo`, not `coste`).
ALL CAPS with accents kept (`Á É Í Ó Ú Ñ Ü`), opening `¡ ¿`. Buttons are infinitives (`REINICIAR`,
`COMPRAR`); hints and prompts use the `tú` imperative (`ELIGE UNA`, `TOCA SALTAR`). Straight
apostrophes never needed. Western digits, `.` decimals. Plurals: form 0 = 1, form 1 = everything
else (0, 2+). Widths measured with the slimy font advances (`assets/fonts/pixel.fnt`, 16 px titles x2).

## Kept names

| English | Spanish |
|---|---|
| SLIME TIME | SLIME TIME |
| INKKY | INKKY |
| CHAMELEON | CHAMELEON |
| SLIMAKAZE | SLIMAKAZE |

## Terms

| English | Spanish | Note |
|---|---|---|
| slime (creature and meter resource) | SLIME (el slime) | widely known word in LatAm; `MÁS SLIME` |
| goo | BABA | trail, shots, goo drops |
| chalice | CÁLIZ | CHALICE CONSUMED = ¡CÁLIZ ENGULLIDO! |
| ticket / TIX | BOLETO / BOL. | LatAm word (Wonka's "boleto dorado"); BOL. only where English says TIX |
| coin | MONEDA | |
| maze | LABERINTO; MAPA on 76 px buttons | NEW MAZE = NUEVO MAPA, REPLAY MAZE = REPETIR MAPA |
| random maze | LABERINTO AL AZAR | |
| randomizer | ALEATORIZADOR | |
| level / L | NIVEL / NV | `CODE LV` = CÓDIGO NV |
| floor (Descent) | PISO | |
| descent / descend | DESCENSO / BAJAR | |
| pot | POZO | as in "pozo acumulado"; also fits the dungeon |
| cash out / bank half | COBRAR / COBRA LA MITAD | |
| run (Descent) | PARTIDA / DESCENSO | QUIT RUN = ABANDONAR, NEW RUN = OTRO DESCENSO |
| paid run | CON PREMIO | PAID RUNS = PARTIDAS CON PREMIO |
| practice | PRÁCTICA | |
| hard / hard mode | DIFÍCIL / MODO DIFÍCIL | |
| heat | CALOR | |
| upgrade | MEJORA | |
| tools (tab) | KIT | fits 32 px |
| hub | BASE | ENTER THE HUB = IR A LA BASE |
| skin | SKIN (el skin) | gamer word; masculine |
| jelly | GELATINA | |
| hat | GORRO | SOMBREROS did not fit the 44 px section label; kept everywhere for consistency |
| hat wheel / wheel | RULETA DE GORROS / RULETA | prize wheel = RULETA DE PREMIOS |
| spin | GIRAR / GIRO | |
| tailor | SASTRE | |
| wardrobe | ROPERO | |
| shop | TIENDA | |
| trail | RASTRO | |
| paper (map) | PAPEL | |
| map table | MESA DE MAPAS | |
| leap / jump | SALTO / SALTAR | |
| glide | DESLIZ | |
| splat (hitting a wall mid-leap) | CHOQUE / CHOCAR | |
| boon | BENDICIÓN | |
| medal | MEDALLA (BRONCE, PLATA, ORO) | |
| best / record | MEJOR / RÉCORD | |
| seed | SEMILLA | |
| attempt | INTENTO | |
| assist | AYUDA | |
| dry up | SECARSE (TE SECASTE) | |
| fog | NIEBLA | |
| save code | CÓDIGO DE GUARDADO | |
| ON / OFF | SÍ / NO | |
| MAXED / MAX | AL MÁXIMO / MÁX. | |
| back | ATRÁS | VOLVER did not fit 32 px |
| pad | CONTROL | not MANDO (Spain) |
| units | S, PX, X, % kept | |

## Names chosen

Levels: MAZMORRA OSCURA, MINAS MUSGOSAS, SANTUARIO DE ARENISCA, TEMPLO HUNDIDO, TÚNELES TÓXICOS,
CATACUMBAS TENEBROSAS, FORTALEZA HELADA, CELDA DE OBSIDIANA, CAVERNAS DE CRISTAL, BÓVEDA VOLCÁNICA.
Skins: LIMA, MENTA, LIMÓN, OCÉANO, UVA, CARMESÍ, ESCARCHA, INKKY, CHICLE, BRASA, ARCOÍRIS,
CRONÓMETRO, CHAMELEON. Upgrades: MÁS SLIME, VELOCIDAD, BRILLO, FUERZA DE MURO. Workshop: SEGUNDO
AIRE (HUD pod AIRE), CARGA RÁPIDA, PEGAJOSO, IMÁN, OLFATO BABOSO. Abilities: RIFLE DE SLIME, BOMBA
DE SLIME, SLIMAKAZE.

## Overflows (translator comments `# overflow:` in es.po)

- `upgrades.tab_coins` MONEDAS 42 px > 32: no natural short word; the tab needs to grow.
- `common.buy` COMPRAR 42 px > 40 (1 px of ink over).
- `tutorial.jump` SALTO 30 px > 27: no 4-letter word for JUMP.
- `upgrades.tab_tickets` BOLETOS 42 px fits the real 44 px tab (the normalized budget line says 32,
  English TICKETS is 40 there too).

## Doubts for a native reviewer

- `title.tagline` ESCAPA DE LA NIEBLA / O SÉCATE EN EL INTENTO: plays on "morir en el intento"; check it reads well.
- `result.chalice` ¡CÁLIZ ENGULLIDO!: "consumed" made funnier (gulped down).
- `heatmod.grounded.name` CASTIGADO: pun on a grounded kid (no leaps); could read as just "punished".
- `levels.hard_mode` "NIEBLA VIVA" for FOG RETURNS (the full "LA NIEBLA VUELVE" did not fit 268 px).
- `result.choice.new_maze` / `replay_maze` use MAPA (LABERINTO does not fit 76 px); the
  `result.seed_paid` hint says NUEVO MAPA to match the button.
- `ability.kaze.desc` EMBESTIDA for WALL DASH (dash into the first wall).
- `boon.sense.name` RADAR DE CÁLIZ, `boon.bladder.name` VEJIGA EXTRA, `workshop.nose` OLFATO BABOSO
  (GOO NOSE pun), `boon.slick.name` RESBALOSO (LatAm form, Spain says resbaladizo).
- `skin.lime` LIMA / `skin.lemon` LIMÓN: in Mexico "limón" is the green fruit; colours may confuse there.
- `hat.*` GORRO as the hat word (space); SOMBRERO DE COPA / SOMBRERO VAQUERO keep "sombrero" in their names.
- Story lines: 2 (LOS MINEROS HUYERON. TÚ TAMBIÉN LO HARÍAS.), 5 (UN SLIME ENTRE SLIME), 7
  (NO TIRITA. SE BAMBOLEA.) and 1 (PLAF as the splat sound).
- `ticket` = BOLETO: Argentina / Chile might prefer TICKET; BOLETO kept as the most neutral.
