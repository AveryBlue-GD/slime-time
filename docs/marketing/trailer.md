# Trailer drafts (vertical Shorts) and how to re-render them

Started 2026-10-20 for the social-media push (TikTok / YouTube Shorts / Reels). All footage is the real game:
real levels played by the autopilot or by scripted inputs, and real menus. The wardrobe, hat wheel and map
papers beats use portrait rebuilds of those screens, made from the game's own pieces (see "Portrait screens").
Marketing context: [advisor/demo.md](../advisor/demo.md) (the Shorts feed the web demo and the Steam page).

## Output

`build/trailer/` (git-ignored, never committed):

- `short_A.mp4`, `short_B.mp4`, `short_C.mp4`: 1080x1920, 60 fps, H.264 High yuv420p, AAC 192k, `+faststart`.
- `short_<ID>_sheet.png`: contact sheet, one frame per beat plus the end card.
- `README.md`: each draft's beats, timings and captions (generated).
- `takes/` (raw takes: PNG frames + WAV, reused while their flags are unchanged; portrait takes keep `p%08d.png`),
  `captions/` (caption overlays).

Audio is the game's own audio: level ambience plus sound effects (glide, leap, splat, chalice, wheel clicks,
unlock jingle). **The game has no music.** The drafts are loudness-normalised (two-pass `loudnorm`, -14 LUFS,
-1.5 dBTP).

Music cuts (2026-10-20, mockups): a draft with `"music"` in `trailer.json` also gets `short_<ID>_music.mp4`,
the same picture with a procedural track from `tools/make_music.py` under the game audio, its final hit on the
end card. `-Music NAME|FILE|none` overrides it; `-MusicOnly` remakes only the music cuts from the existing
`short_<ID>.mp4` (no Godot). Details: [music.md](music.md).

## Re-render

```
.\tools\trailer\make_trailer.ps1 [-Drafts A,B] [-Force] [-OnlyTakes]        # Windows (PowerShell)
./tools/trailer/make_trailer.sh [--drafts A,B] [--force] [--only-takes]      # macOS / Linux
```

From Git Bash on Windows, never run the `.ps1` directly (Windows opens it in Notepad). Use
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/trailer/make_trailer.ps1`.
A full run from scratch takes about 3 minutes. Re-runs only re-render takes whose flags changed. Use `-Force` after
editing `take.gd` / `card.gd`, because the cache only knows the flags.

Needs Godot 4.7.2 (same lookup as `tools/godot.*`, or `GODOT`), Python 3 and ffmpeg (`FFMPEG`, else PATH, else
the winget `Gyan.FFmpeg` install). On Windows, Godot's small 320x180 windows open on the right-most monitor without
focus (`tools/quiet_window.ps1`). The movie writer swaps in Godot's dummy audio driver and mixes the sound into the
WAV, so nothing plays on the speakers. Don't add `--audio-driver Dummy` yourself: it's unnecessary, and the WAV is
what we need.

Save safety: every run is a `res://tools/` scene with `--story-complete` (a clean in-memory postgame state: story
beaten on both modes, every coin found) and other debug flags. The real save is
never read or written.

## How it works

| File | Role |
|---|---|
| `tools/trailer/trailer.json` | **what to shoot**: `takes` (named game moments + flags) and `drafts` (beats + end card) |
| `tools/trailer/take.tscn` / `take.gd` | the director: plays one take (modes `play`, `hops`, `skins`, `hats`, `trails`, `wheel`, `hub`, `maps`, `title`, `win`; flags in the header comment) |
| `tools/trailer/portrait.tscn` / `portrait.gd` (+ `portrait_stage.gd`) | marketing-only 9:16 rebuilds of the wardrobe, hat wheel and map papers at 180x320 (views `skins`, `wheel`, `papers`; flags in the header comment). The game never loads them |
| `tools/trailer/goo_text.py` | captions and the end card's words in the logo's gooey lettering (pure Python, no Godot) |
| `tools/trailer/card.tscn` / `card.gd` | the animated end card: the logo in the skin's colors over the skins-screen try-on stage (its words come from `goo_text.py`) |
| `tools/trailer/trailer.py` | renders takes (movie writer, PNG + WAV), captions and cards, then cuts, frames and joins with ffmpeg, adds the contact sheets and README |
| `make_trailer.ps1` / `.sh` | wrappers (quiet windows on Windows) |

Takes are recorded at the game's native 320x180, 60 fps (`--write-movie f.png`, lossless). The global RNG is seeded,
so a take renders the same every time.

**Full screen (owner, 2026-10-20).** Every beat fills the 9:16 frame edge to edge; there are no bands or borders.
The game is scaled up **11x with nearest neighbour** (180 x 11 = 1980, so the game's height fills the 1920-px frame).
That shows a strip about 98 x 175 game pixels, or 6 x 11 tiles. The strip **follows the action**: `take.gd
--track` writes the focus point for every drawn frame (the slime; the try-on slime in the wardrobe; the hat wheel
once it opens). `trailer.py` smooths that path both ways (an eased pan with no lag and no jitter, `FOLLOW` = 0.06
per frame, per beat `"follow"`) and moves the crop in **whole game pixels** through ffmpeg `sendcmd`. A beat can pin
the view with `"focus": [x, y]` (320x180 pixels) or zoom further in with `"zoom": 12+`.

**No HUD (owner, 2026-10-20).** `take.gd` hides the game's whole HUD on every frame: meter, coins, timer, level
and area banners, story line, prompts, dry-up and win panels, NEW RECORD. `--keep-hud` shows it for a beat that is
about it. Menu takes also hide the chrome the crop would cut or the caption would sit on (`_tidy`): every label
and button in the wardrobe except the skin tiles, the hat wheel's header row, and the map view's title and bottom
bar.

**Captions** (owner, 2026-10-20) use the DRY TRYING logo's own lettering: `goo_text.py` calls
`tools/make_title.py`'s `render_text()` (the logo's code: 5x7 cells drawn as thick capsule strokes with goo
drips, light / mid / dark goo shades, white gloss dashes, the dark outline and the 2-px drop shadow). Letters are
the logo's where it has them, else the game font's 5x7 glyphs (`make_font.py`: A-Z, 0-9, `? ! . , : ; = + ' -`
and more; the zero is drawn as an O, since the slashed one reads as an O-slash this big). The goo is recoloured
the way the game's skin shader recolours the logo (`Skins.shades` of the caption colour); white and gold stay
as before. Drips and lumps are seeded from the text, so a caption renders the same every time.
They're drawn on a 540x960 canvas (2x: one logo pixel = 2x2 frame pixels; a letter is 66x84 px on the frame)
in a column from x 20 to 456 (clear of the right ~15% button rail), word-wrapped to as many lines as needed (a
lone short last word takes the one before it along), each line centred. They start at y 68 (`"at": "top"`,
136 px, under the status bar) or y 600 (`"low"`), and the block always ends above y 768 (the bottom 20%).
One line takes ~33 px per letter, so about 13 letters fit a line; 2 lines end by frame y ~400, 3 by ~520.

`tools/make_title.py` was only refactored for this (`render()` = `render_text(TEXT, ...)`): the logo PNGs come
out byte-identical (checked by regenerating and comparing md5s).

The end card is its own 360x640 canvas (3x), which fills the frame: the 303-px logo at y 120 and the try-on
stage at y 212; the tagline (white), CTA (the skin's colour) and store line (dim) are goo text from frame
y 808 down, laid over it by `trailer.py`.

### Portrait screens (marketing only)

The landscape menus cropped to 9:16 lost most of the screen, so the wardrobe, wheel and papers beats use
`portrait.tscn` takes (`"scene": "portrait"` in `trailer.json`): a 180x320 view (x6 = 1080x1920, the same chunky
pixels as the game) built from the real pieces: UIKit's theme, the menu backdrop, GooBox frames, the skins
screen's tiles and slime previews (skin shader, jelly), SkinShowcase's routine, HatWheel itself (its drawing,
odds-sized wedges, rare slivers spread round, flapper, a real seeded spin), Hat sprites, MapView on the real
papers and the PAPERS page's tiles. Nothing in the game uses them. It saves its own frames (`p%08d.png`) while the
movie run paces the frames and records the audio; the beat shows the frame at 6x with no crop or follow.

- `skins`: the try-on stage on top (a 3x slime acting out the showcase routine), the status line, the 13 skin
  tiles in rows of 5, JELLY: OFF / ON. RAINBOW and STOPWATCH only as the locked silhouettes, with the screen's
  own locked lines. Takes `skins` (flip every skin, then JELLY on), `skins_hook` (`--top=90 --no-jelly`, under
  B's 3-line hook caption), `skins_gold` (the STOPWATCH silhouette, "LOCKED - EARN ALL 30 MEDALS").
- `wheel`: the wheel filling the width in a goo frame, a ticket spin (`--spin-at`), and the won hat popping onto
  the slime on a small stage under it ("YOU WON THE COWBOY HAT!").
- `papers`: L4's map (Sunken Shrine) big on the worn paper, the paper's name and "% UNCOVERED", and the four
  PAPERS tiles, flipping PARCHMENT, BLUEPRINT, NIGHT, GOLD LEAF.

Content starts at `--top` (70 default: under a 2-line caption; papers 62; 90 under 3 lines).

## Changing text and beats

Edit `tools/trailer/trailer.json`:

- A beat is `{"take", "in" (s into the take), "dur" (s), "caption": [lines], "sub": [small lines], "color",
  "at": "top"|"low"|y, optional "focus": [x, y], "follow", "zoom" (>= 11)}`. Colors: `white`, `gold`, a skin id (`lime`, `ocean`,
  ... `shadow` = INKKY) or `#rrggbb`.
- A take is `{"take": mode, "frames", "args": [...], "note"}`; a portrait take adds `"scene": "portrait"` and
  `"take"` is then the view (`skins`, `wheel`, `papers`). Args are the game's debug flags (`--level=N`,
  `--skin=ID`, `--hard`, `--random --seed=N`, `--trail=ID`, `--tickets=N`, `--medals=...`) plus the take flags
  (`--keep-hud`, `--focus=X,Y`, `--skip=CELLS`, `--leap=N`, `--meter=P`, `--record`, `--jelly`, `--own-hats=all`, `--hat=ID`,
  `--cycle=...`, `--every=F`, ...).
- The end card is `{"dur", "skin", "args": ["--jelly"], "tagline": [...], "cta": [...], "store": [...], "logo": 0-11}`.
  **`store` is the empty slot for the store link** (e.g. `["WISHLIST ON STEAM"]`).
- To find the right `in` time, render with `-OnlyTakes` and look at `build/trailer/takes/<id>/f%08d.png`
  (frame = seconds x 60).

Text rules: keep it short and simple, because it will be translated for other markets. In the goo lettering a
line holds about 13 letters, so keep a caption to 1-2 wrapped lines (3 only over gameplay or a `--top=90` take). Only claim numbers that are true; recount if the content changes.
Counts as of 2026-10-20:

- **Skins:** 13 = 10 level skins + CHAMELEON (any color) + RAINBOW + STOPWATCH (all 30 gold medals). Each has an
  opaque and a jelly version: 26 looks.
- **Hats:** 12 (plus none).
- **Trails:** 6 without HEAT / DESCENT (skin goo, ink, glow, gold, candy, starry). The ABYSS trail is DESCENT-only
  (switched off, D11). The EMBER trail is HEAT-only, so leave it out.
- **Map papers:** 4.
- **Looks:** 26 x 13 x 6 = 2,028, so "1000+ ways to dress your slime" is true.

The per-level skin rule (CLAUDE.md) applies. Each story level wears its first-run skin (Lime L1 ... Ember L10).
**Rainbow and Stopwatch rule (owner, 2026-10-20): promo material never shows the RAINBOW or STOPWATCH skins in
colour.** They appear only as the skins screen's locked silhouettes (the "more to unlock" tease): in the wardrobe
modes `take.gd` takes one story coin out of the count (the opaque rainbow locks itself), the Stopwatch stays locked
because not every medal is gold, and the jelly rainbow (it opens with hard level 10, like Ember's and Chameleon's
jelly, which stay unlocked) gets the screen's locked silhouette look drawn on its tile and preview; a
take asked to wear either one wears its level's first-run skin instead; `card.gd` and `tools/promo/cover.gd` never
use the rainbow material. Random mazes wear their theme's level skin (seed 4242 = Volcanic Vault = Ember). The
RAINBOW HAT is a hat and may appear.

## The no-HEAT rule

The Shorts must not show or mention HEAT: no HEAT screens, flame modifiers, heat numbers or the word. The takes
avoid it like this: hard mode is shown mid-run only (no hard-mode win panel), no HEAT panel, the trails page isn't used, and
the EMBER trail (whose unlock text names HEAT) is never focused. Check the contact sheets after any change. Also
keep DESCENT out while it's switched off (D11).

## The drafts (2026-10-20)

- **A, "Can you escape before you dry up?"** (~28 s): goo splash into the dark Dark Dungeon, the slime runs dry,
  10 themed mazes, a charged leap into the dark, the chalice, then the endgame (random mazes, hard mode, records),
  then the cosmetics grind (skins, jelly, hat wheel, trails, map papers), then the end card.
- **B, "1000+ ways to dress your slime"** (~27 s): the wardrobe flipping every skin, jelly, 12 hats popping off a
  leaping slime, ANIMATED HATS (owner, 2026-10-20: a close 13x take of the RAINCLOUD hovering and raining over Lime
  on L1, then the PROPELLER CAP spinning on Mint on L2; takes `rain_hat`, `prop_hat`), the wheel, trails, papers;
  then "earn them all" over gameplay, tickets, hard mode.
- **C, "Beat the story... then the real game starts"** (~22 s): story, then the postgame loop: endless mazes,
  tickets, hat wheel, hard mode = jelly skins, gold medals, the secret STOPWATCH skin (a locked silhouette), "ONE MORE RUN?".

Known rough edges: B's hook caption ("1000+ WAYS TO / DRESS YOUR SLIME") wraps to 3 goo lines. The mid-level shots (`--skip`) start the slime partway along the route, so less of the trail
is lit than in a real run. The hat hops on level 1 happen in a sparse part of the maze. The trails beat is
gameplay only, because the trails page is too small to read on a phone.

## Later: the horizontal 45-60 s trailer

- Same pipeline: add a `"canvas": "16:9"` mode to `trailer.py` (1920x1080 = the 320x180 game at 6x, no crop,
  no follow) and captions on a 320x180 overlay at 6x.
- Structure: cold open in the dark (a 2-3 s hook), the core loop (glide, light, meter, leap, splat), a level
  montage with each theme's own skin, the story beat (the intro cutscene, `tests/demo_story.tscn`), the chalice and
  medals, a hard pivot to the postgame (randomizer, hard mode, jelly), the cosmetics wall, then logo + store CTA.
- The horizontal cut is where music matters most. Use a `tools/make_music.py` track (it can be fitted to any
  hit time, [music.md](music.md)), or commission / license one, then cut to its beats.
- Consider a slow full-bright overview of a finished level (`tests/demo_overview.tscn`) as the "look how big this
  maze was" reveal.
