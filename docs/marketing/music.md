# Music mockups (hub loops and trailer tracks)

Started 2026-10-20 as mockups ("a mockup of some music to play in the hub and through the trailers"). Since
2026-10-21 **the hub and the story intro play music in the game** (see "In the game" below); the trailer tracks are
for the videos only. The listening copies live in `build/music/` (git-ignored); the game's copies in `assets/music/`.

## What it is

`tools/make_music.py` synthesizes every note in pure Python, the same way `tools/make_sounds.py` makes the sound
effects. There are no samples, no third-party audio and no dependencies (numpy isn't installed, so it isn't
used), so there are no licensing questions. The instruments are built from the game's own sound palette:

| instrument | built like |
|---|---|
| goo drops (plucks, music box) | a marimba-like pluck: sine plus a fast-dying ~4x partial; it lands a little sharp and sags onto its pitch |
| sub bass | a round sine with soft harmonics and saturation; "round" notes drop onto their pitch, "boing" notes bend up into it |
| goo voice (melodies) | a warm wavetable that scoops up into each note, with delayed slow vibrato, behind a two-pole low-pass |
| pads | a soft saw (or a hollow square) behind a two-pole low-pass; two voices detuned +/-6 cents and panned apart |
| bubbly arpeggios | `bubble()`-style rising pops that land on chord tones |
| percussion | a deep bloop kick, a wet squelch snare (band-passed noise slap + bloop body + a bubble), bubble-pop hats |
| trailer FX | fog (band-passed noise), a bubbling riser, a splat, and a sub "boom" stinger with sinking bubbles |

Taste rules (handoff: "keep pitches low and dark and ambience faint"): melodies top out around C5 (523 Hz), the
bubble pops sit near 1 kHz, nothing is bright or hissy, and everything goes through a dark reverb (the send is
band-limited to 160 Hz-2.6 kHz). Measured: energy above 2 kHz is about 21-28 dB below the total. The sound is
cosy rather than spooky: mostly minor-ish keys with warm 7th and 9th chords, a gentle swing, and real
progressions with a melodic hook.

## The pieces

| file | length | tempo / meter | key, progression | mood |
|---|---|---|---|---|
| `hub_A.wav` "Cozy Goo" | 68.6 s loop | 84 BPM, 4/4, swung 8ths | D Dorian: Dm9 - G9 - Bbmaj7 - A7sus/A7 | warm and slow; a goo-voice hook, then a counter-melody over bubble arps |
| `hub_B.wav` "Foggy Lullaby" | 73.0 s loop | 69 BPM, 3/4, light swing | C minor: Cm9 - Abmaj7 - Fm9 - G7sus/G7, Cm9 - Ebmaj7 - Abmaj7 - G7 | sparser and darker; a music-box goo melody, a soft heartbeat kick, four near-empty bars |
| `hub_C.wav` "Bouncy Hub" | 76.8 s loop | 100 BPM, 4/4, swung 16ths | F major: Fmaj7 - Dm7 - Gm7 - C7sus/C7, Bbmaj7 - Am7 - Gm7 - C7 | more upbeat; boing bass, squelch snares, a hummable hook, a breakdown before the loop |
| `story_intro.wav` "Down We Go" | 25.4 s, plays once | ~104 BPM 8ths, free sections | D minor: Dm - Bbmaj7 - Gm9, A7sus - dim, Dm - C - Bb - A (lament), Dm9 - G9 - Dm9 | soft storybook, one section per intro shot (below) |
| `trailer_1.wav` "Goo Rush" | 28.0 s | ~108 BPM (fitted) | D minor: build Dm9 - Bbmaj7 - Gm9 - A7, drop Dm - Bb - F - C | energetic: a "blup blup bloooop" hook with a splat, a bubbling build, a bouncy drop, a gap, the hit |
| `trailer_2.wav` "Fog Pulse" | 28.0 s | ~89 BPM (fitted) | C minor: Cm9 - Abmaj7 - Ebmaj7 - G7 | moody: a lullaby hook over a heartbeat thud, a heartbeat build, a half-time drop, a deep boom |

Every piece comes as a 44.1 kHz 16-bit stereo WAV (TPDF dither) plus an `.ogg` copy for quick listening.
`build/music/README.md` lists the measured numbers and `stats.json` holds them.

- **Loudness.** The hub loops are -18.0 LUFS integrated with true peaks of -3.5 to -4.4 dBTP. They sit under the
  sound effects and need no limiting. The trailer tracks are -14.0 LUFS at -1.2 to -1.4 dBTP. A look-ahead
  limiter catches their loudest peaks (the hook splat, the hit and the drop's kicks; up to 5-7 dB). All levels
  are measured with ffmpeg's `loudnorm`, and the gain is applied in the script.
- **Seamless loops.** The hub loops render their note and reverb tails past the loop end, then fold them back
  onto the start. The result is exactly what the loop sounds like when played forever, so the end flows into
  the start. Checks, all in the 16-bit files:
  - The jump from the last sample to the first is 95-236 LSB, against 676-3367 LSB for each track's own
    99.9th-percentile sample step.
  - A click test (the second difference within +/-60 samples of the seam) reads lower at the seam than at a
    typical bar start in the same loop.
  - Listen to `build/music/seams/<name>_seam.wav`: the last 3 s, then the first 3 s.
- **Trailer structure.** Bar 1 is the hook. Then come the build (about 40% of the rest), the drop and a half-beat
  of silence. The hit lands exactly on the end card, followed by a ring-out (a splat, a sub boom, the tonic chord
  and bubbles sinking away) that fades out at the end of the video. The tempo is nudged by a few BPM so a
  whole number of bars ends on the hit. That way the same track fits any draft length.

## Regenerate

```
python tools/make_music.py                    # everything (about 1 minute, pieces render in parallel)
python tools/make_music.py hub_B trailer_2    # only these
python tools/make_music.py --game               # the game's pieces, also as OGG into assets/music/ (then re-import)
python tools/make_music.py --fit trailer_1 --hit 20.8 --length 24.2 --out build/x.wav   # fitted to a video
python tools/make_music.py --verbose hub_A    # also print each bus's level (for re-balancing)
```

On the Mac use `python3`. ffmpeg comes from `--ffmpeg`, `$FFMPEG`, PATH or the winget Gyan.FFmpeg install.
Fixed seeds mean reruns give the same files. Nothing plays on the speakers.

To change the music, edit `tools/make_music.py`:

- The pieces are the functions `hub_A()`, `hub_B()`, `hub_C()` and `trailer()`. Melodies are lists of
  `(beat, MIDI note, length in beats)` and chords are `{name: (bass note, pad notes)}`.
- `BUSES` holds each instrument's pan, reverb send and level trim, so that is the place to re-balance.
- `HUB_LUFS`, `TRAILER_LUFS` and `TP_MAX` set the loudness targets.
- `TRAILERS` holds the trailer tempos and moods. `DEFAULT_HIT` / `DEFAULT_RING` set the stand-alone trailer
  files' timing.

## The Shorts with music

`tools/trailer/trailer.json` gives each draft a `"music"`:

| draft | track | why |
|---|---|---|
| A "Can you escape before you dry up?" | `trailer_2` (moody) | tension: dark mazes, running dry |
| B "1000+ ways to dress your slime" | `trailer_1` (energetic) | playful cosmetics montage |
| C "Beat the story... then the real game starts" | `trailer_1` (energetic) | the "one more run" loop |

The pipeline writes `build/trailer/short_A_music.mp4`, `short_B_music.mp4` and `short_C_music.mp4` next to the
plain cuts. They use the same picture (the video stream is copied, not re-encoded). For each one:

1. The music is rendered fitted to the draft, so its hit lands on the end card's first frame (A 24.4 s, B 20.8 s,
   C 18.9 s). The fitted renders are cached in `build/trailer/music/` and keyed by `make_music.py`'s contents.
2. The game audio is set to -17 LUFS ("ducked a bit") and the music to -18 LUFS (just under the effects).
   They are mixed and fade out over the last 0.5 s.
3. The mix gets the drafts' usual two-pass `loudnorm` (-14 LUFS, -1.5 dBTP).

Measured: A -14.1 / B -14.0 / C -14.1 LUFS, true peaks -1.3 to -1.5 dBTP. In C a game sound (a hop) falls in
the music's half-beat gap right before the card.

```
.\tools\trailer\make_trailer.ps1 -MusicOnly                 # remake only the music cuts from the existing short_<ID>.mp4 (no Godot)
.\tools\trailer\make_trailer.ps1 -Music trailer_2           # every selected draft with this track (also -Music none)
.\tools\trailer\make_trailer.ps1                            # the full run: plain cuts + music cuts
./tools/trailer/make_trailer.sh --music-only                # macOS / Linux (same flags, lower-case)
python tools/trailer/trailer.py --music-only                # direct (no Godot is started in this mode)
```

To swap music:

- Change a draft's `"music"` to `"trailer_1"` or `"trailer_2"`, or to a file: `{"track": "path/to/song.wav",
  "hit": 31.2}`. The path is relative to the project root, and `hit` is the second in that file that should
  land on the end card; the file is shifted to match, so leave it out to start the file at 0.
- To change the balance, add `"db": 2` (music 2 dB louder) to the music spec, or add `"music_db": 2` to the draft.
- Remove `"music"` from a draft to drop its music cut. `GAME_LUFS` / `MUSIC_LUFS` in `trailer.py` set the
  default balance.

## In the game

- **Files.** `python tools/make_music.py --game` renders `hub_A`, `hub_B`, `hub_C` and `story_intro` and writes
  them as OGG Vorbis (quality 3, 2 MB in all) to `assets/music/hub_a.ogg`, `hub_b.ogg`, `hub_c.ogg`,
  `story_intro.ogg`; then re-import. They are not in `Demo.export_cut()`, so every demo export ships them
  (`tests/test_music.gd` checks it; the demo packs were checked to contain them).
- **Player.** The `Music` autoload (`scripts/music.gd`), one `AudioStreamPlayer` on the `Music` bus (SETTINGS'
  MUSIC slider, `[settings] music_volume`; the effects are on the `SFX` bus, the SFX slider; both made under Master
  by `Progress.ensure_bus`), silent while `Progress.sound_on` is off. It follows scene changes (`SceneTree.scene_changed`, and `Transition.go` as its wipe starts):
  - the hub and its screens (`Music.HUB_SCENES`: hub, level select, skins, maps, upgrades): if no hub loop is
    playing, one of the three is picked at random (never the one picked last time) and fades in over 1.5 s,
    looping; it carries on across these screens;
  - the settings pages and the story (`KEEP_SCENES`) keep whatever is playing;
  - anything else (a level, the title, the victory and demo end screens) fades it out over 0.6 s.
  The hub loops play at -3 dB (mastered to -18 LUFS) under the sound effects.
- **The story intro.** `StoryScreen` starts `story_intro` with the intro (only the intro: the finale has no
  music) and fades it out over 0.8 s at the end or on Esc. Its sections start on the intro's shots
  (`INTRO_SHOTS` in `make_music.py` = the cumulative `Story.INTRO` times; the test checks they match, so change
  both together and re-render). When the player skips ahead (or a Reduce Motion still holds longer), each new
  shot jumps the music to its section if it has drifted more than 0.3 s. Mastered to -21 LUFS, played at 0 dB.
  The beats:
  1. run (0-4.6 s): a soft, scurrying goo-drop ostinato over Dm, a bass pulse, a two-note "uh-oh" when the
     slime panics;
  2. chase (4.6-8.6 s): three bubble glints for the adventurers' gold dreams, then the ostinato slows into a
     music-box lullaby (the slime dreams of a nap) over Bbmaj7 and Gm9;
  3. crack (8.6-12.5 s): it thins to a hollow A7sus; each crack is a deep goo thud, the second turns the pad
     diminished; when the floor breaks a gloop drops away and it goes nearly silent;
  4. fall (12.5-17.3 s): a lament bass (D - C - Bb - A) under a goo voice sinking a step per chord and bubbles
     raining downward; it clears out just before the splat;
  5. splat (17.3-23.7 s): the splat sound alone, then a Dm9 rolled on goo drops and the hub's hook (from
     "Cozy Goo"), slow, on the music box, settling on Dm9 as two bubbles rise.
- **Not done yet:** ducking under effects, title-screen music.
