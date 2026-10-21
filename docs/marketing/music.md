# Music mockups (hub loops and trailer tracks)

Started 2026-10-20. The owner asked for "a mockup of some music to play in the hub and through the trailers".
**These are mockups only. Nothing is wired into the game**: no scene, script or asset uses them, and the files live
in `build/music/` (git-ignored). The game still has no music.

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

## Later: wiring hub music into the game (not done)

This is what it would take, behind a test flag like the other unfinished features:

- **Flag.** `Economy.HUB_MUSIC_TEST := false`, plus a debug flag such as `--music` in `Progress`'s game args.
  `tools/i18n_extract.py --check` doesn't care about it, because there's no text.
- **Asset.** Pick one loop and export it as OGG Vorbis into `assets/music/` with loop enabled on import.
  Godot's OGG loops are seamless, and the file is already a whole-bar loop. Keep the generator in `tools/`
  like the other `make_*.py` scripts.
- **Audio bus.** Today there is only the Master bus: `Progress.apply_volume()` sets bus 0, and `Sfx` plays
  everything there. Add a `default_bus_layout.tres` with `Music` and `SFX` buses under Master, so music can be
  turned down without touching the effects. Optionally, duck `Music` a few dB with a compressor sidechained
  from `SFX`.
- **Player.** Put a `Music` node in the `Sfx` autoload, or a small new autoload: one `AudioStreamPlayer` on the
  `Music` bus. It should keep playing across the hub and its sub-screens (skins, maps, level select), so it
  isn't restarted by each scene change.
- **Fades on scene changes.** Fade out (about 0.5-1 s, a `Tween` on `volume_db`) when entering a level, since
  levels have their own ambience beds. Fade back in on returning to the hub. The natural place is the
  `Transition` autoload's scene changes (check that every hub/level change goes through it). Decide whether
  `PlatformEvents` focus loss should pause the music too.
- **Setting.** Add a MUSIC volume slider next to the existing volume (`[settings] music_volume`, default
  around 0.6). That needs a save-key addition (load default when missing, no save-version bump) and
  `Loc.t()` text with an i18n hint. On web, audio starts after the first input, as today.
- **Tests.** Check that the player exists and follows the flag, that the volume is saved and loaded, and that
  the music fades on hub -> level -> hub. Measure the hub's frame time on web/Android with the OGG decoding.
