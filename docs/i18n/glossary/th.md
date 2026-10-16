# Thai (th) glossary

Register: casual game Thai, no polite particles (ครับ / ค่ะ), the player is addressed with คุณ only
where a pronoun is unavoidable (story lines, PICK YOUR COLOR). Thai has no case: Latin words inside
Thai text (SLIME TIME, LV, PX, X, key / pad names) stay in capitals. No commas inside Thai phrases; a
space marks a phrase break (as in normal Thai), `-` and `:` kept where the English uses them for layout.

**Line breaking:** U+200B ZERO WIDTH SPACE between every pair of words in every string (the web build
has no Thai dictionary breaker). Normal spaces only where English has a phrase / layout gap.

## Terms

| English | Thai | Notes |
|---|---|---|
| slime (the hero, the resource) | สไลม์ | |
| goo (trail substance) | เมือก | |
| trail (style) | รอย | INK TRAIL = รอยหมึก |
| chalice | ถ้วยทอง / ถ้วย | |
| slime meter | มาตรสไลม์ (not shown as a word yet) | |
| maze | เขาวงกต | |
| level | ด่าน | LEVEL {level} = ด่าน {level} |
| floor (Descent) | ชั้น | |
| coin | เหรียญ | |
| medal | เหรียญรางวัล | BRONZE / SILVER / GOLD = ทองแดง / เงิน / ทอง |
| ticket / TIX | ตั๋ว | TIX is written ตั๋ว as well (already short) |
| pot | กองกลาง | HUD pods abbreviate to กอง |
| heat / HEAT | ความร้อน | pods and LEVEL SELECT button abbreviate to ร้อน |
| bounty | ค่าหัว | |
| hard mode / HARD | โหมดยาก / ยาก | |
| upgrade | อัปเกรด | |
| hub | ฮับ | |
| randomizer | โหมดสุ่ม | RANDOM MAZE = เขาวงกตสุ่ม |
| descent | ดำดิ่ง | DESCEND = ดิ่งลง |
| boon | พร | |
| skin | สกิน | jelly skin = สกินเยลลี่ |
| hat | หมวก | |
| hat wheel / prize wheel | วงล้อหมวก / วงล้อรางวัล | |
| shop | ร้านค้า | |
| tailor | ช่างตัดเสื้อ | |
| paper (map) | กระดาษ | |
| wardrobe | ตู้เสื้อผ้า | |
| leap / jump | กระโดด | touch keycap: โดด (27 px) |
| glide | ไถล | |
| splat (wall hit) | ชนกำแพง | the ability SLIME SPLAT is a bomb: ระเบิดสไลม์ |
| dried up | แห้งกรอบ | "dried crisp", the deadpan death line |
| seed | ซีด | |
| save code | รหัสเซฟ | |
| assist | ตัวช่วย | |
| practice | ซ้อม | |
| paid run | รอบได้ตั๋ว | |
| cash out | รับกองกลาง | |
| restart | เริ่มใหม่ | |
| resume | เล่นต่อ | |
| locked | ล็อก | |
| MAX / MAXED | สูงสุด | |
| BACK | กลับ | |

## Kept names (transliterated)

| English | Thai |
|---|---|
| SLIME TIME | SLIME TIME (Latin, logo) |
| INKKY | อิงค์กี้ |
| CHAMELEON | คามีเลียน |
| SLIMAKAZE | สไลมาคาเซะ |

## Level names

คุกมืดมิด, เหมืองตะไคร่, วิหารหินทราย, ศาลเจ้าจมน้ำ, อุโมงค์พิษ, สุสานสยอง (alliterative ส-ส),
ป้อมน้ำแข็ง, หลุมขังออบซิเดียน, ถ้ำคริสตัล, กรุภูเขาไฟ.

## Doubts for a native reviewer

- `title.tagline` ESCAPE THE FOG / OR DRY TRYING: หนีให้พ้นหมอก / ไม่งั้นแห้งกรอบ. The pun is gone;
  it rhymes หมอก / กรอบ instead.
- `result.chalice` CHALICE CONSUMED!: ซดถ้วยเกลี้ยง! ("slurped the cup clean"). Is it funny or just odd?
- `skin.custom` / victory "ANY COLOR YOU LIKE" (Henry Ford joke): สีไหนก็ได้ตามใจ. The reference is lost.
- Story one-liners: level 7 "IT JIGGLES" = แค่ดึ๋งดึ๋ง; level 8 "YOU ARE UNFORGETTABLE" = แต่คุณน่ะลืมไม่ลง;
  level 1 SPLAT = แผละ!. Check the tone and naturalness.
- `heatmod.race.desc` BEAT 1.3 X PAR: "par" became เป้า (target). Is that clear enough?
- `workshop.wind` SECOND WIND = ฮึดเฮือกสุดท้าย, HUD pod ฮึด (workshop is switched off today).
- `workshop.nose` GOO NOSE = จมูกเมือก, `upgrade.power` WALL POWER = พลังกำแพง: these are literal.
- Level names: หลุมขังออบซิเดียน (oubliette) and กรุภูเขาไฟ (vault). Are they natural?
- The hub uses ฮับ, a loanword. ฐาน would be the alternative.
- `hud.pod.paid_run` (รอบได้ตั๋ว 888/888) is about 86 px against an 80 px budget. It may wrap to its
  allowed second line at the U+200B points.
- Widths were estimated from Noto Sans Thai advances at 11 px, not measured in-engine.
- The font subset (`tools/i18n_subset_fonts.py`) needs a rerun to pick up the characters used, for
  example ั ็ ์ ๋ and the U+200B.
