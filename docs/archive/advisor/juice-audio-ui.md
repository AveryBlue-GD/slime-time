# Slime Time: Game Feel, Audio, UI/UX and Character Audit

> Archived advisor report (2026-10-12): its juice/audio/UI items were implemented; see [../../handoff.md](../../handoff.md) history.

Advisor report. Read-only audit: no game code was changed. Files audited: `scripts/slime.gd`, `scripts/fx.gd`, `scripts/sfx.gd`, `scripts/hud.gd`, `scripts/ui/ui_kit.gd`, `scripts/ui/title.gd`, `scripts/ui/touch_controls.gd`, `scripts/ui/transition.gd`, the juice parts of `scripts/game.gd`, `tools/make_sounds.py`, plus `project.godot`.

## 0. Honesty note on sources

The search tool returned summaries, not full talk transcripts. Here is what was verified and what was not.

- **Fetched and confirmed**
  - Jan Willem Nijman's Nuclear Throne pistol-shot breakdown, via infovore.org (https://infovore.org/?p=5275): camera kick 6 px, shake value +4 per shot with fast decay, weapon kick, hit pause of about 10-20 ms, white first frame on hit, layered material plus enemy hit sounds.
  - GMTK Platformer Toolkit "Behind the Code" (https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code): coyote time (about 0.2 s suggested, with a 0.03 s floor), jump buffer counter, acceleration/deceleration/turn speeds, a gravity multiplier for snappier falls.
  - Godot web export docs (https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_web.html): the web "Sample" playback mode gives low latency without threads but does NOT support AudioEffects, reverb or procedural audio. "Stream" mode supports everything but has higher latency without threads. Autoplay is restricted, so start audio from a click, tap or key press.
  - Game Accessibility Guidelines (https://gameaccessibilityguidelines.com/basic/): remapping, text size and colorblind-safe information are the commonly cited basics. An explicit screen-shake item was not found there.
  - Godot forum/itch threads on iOS and Android web builds: fullscreen is unreliable on iPhone Safari, touch is flaky in web exports on some mobile browsers, and WebGL differs on iOS.
- **Not verified (general knowledge, labelled as such below)**
  - The full text of Vlambeer's "Art of Screenshake" and of "Juice it or lose it". Searches only confirmed the talks exist and their broad themes (tweens, squash and stretch, particles, shake, sound, "interactivity over graphics").
  - Celeste's exact timer values (I recall coyote about 0.1 s and a jump buffer of about 0.08-0.1 s; unverified).
  - Hollow Knight hit-stop durations. No primary source was found. A NESdev forum reply says under about 6 frames, and that is anecdotal.
  - Trackmania/Super Meat Boy ghost UX. Only a review mention of Meat Boy's death-ghost replay was found. The rest is general knowledge.

Everything labelled "general knowledge" below is my own judgement from experience with these games.

## 1. What the code does today (audit)

### Movement and character (`slime.gd`)

Strengths:
- Acceleration is move_toward based, with 420 acceleration and 260 friction against a speed of 72. That is a satisfying glide.
- Lane assist (`_center_in_lane`) and corner leeway (`_slip_past_corner`) are exactly the invisible forgiveness that Celeste-style games rely on.
- 8-direction animation sets cover glide, charge, launch, air, land, splat and recover. The charge pose is scrubbed with the charge value (`_show_frame("charge_...", charge/100)`), which is great anticipation.
- The jump arc height scales with distance.
- Jump pitch scales with power.
- Ricochet splats have impact-scaled volume.
- Phones vibrate on a splat.

Gaps found:
1. **No input buffering at all.** The charge only starts via `is_action_just_pressed("jump")` while `state == GLIDE` (line ~236). A jump press during LAND/RECOVER is fine because those are still GLIDE with an animation timer. But a press during `STUNNED` (0.3 s) or `AIRBORNE` is silently dropped, and so is a press during the post-splat knockback slide. Players mash the jump key right after a splat, and nothing happens for 0.3 s plus the slide. This is the single most "my input got eaten" moment in the game.
2. **No charge cancel and no release grace.** Releasing the key before any meaningful charge still launches a 1-tile hop that costs slime (`MIN_JUMP_TILES = 1.0`). A tap-hop therefore costs real resources by accident. Fine as a design choice, but there is no way to abort a charge, and no "dead zone" below which a tap does nothing.
3. **Idle is a simple wobble loop only** (`idle` anim in `make_placeholder_art.py` is a few frames of `sx/sy/shift/eyes`). There is no blink variety, no look-around, no sleepy or impatient idle after N seconds. For a blob this is where personality lives.
4. **No landing dust or squash pulse beyond the land anim.** Landing and glide are good, but there is no "turn" or "skid" reaction when reversing direction, and no start-up anticipation squash when glide begins.
5. **Squish SFX is the only glide sound** and uses `randf_range(0.85, 1.15)` pitch. Good. But `jump`, `land`, `splat` and `click` are always the same pitch (except jump by power), which makes repeated play fatiguing. `Sfx` has 3 voices per sound and no randomisation hook.

### Juice (`game.gd`, `fx.gd`)

- Splat shake is square random offsets, rounded to whole pixels, linear decay over 0.25 s, and a max of 3 px. This respects pixel snapping, which is correct.
- There is no hit-stop and no brief freeze. There is no camera kick, which Nijman's breakdown lists as a core ingredient and which is cheap. There is no slow-mo on a win or a dry-up. There is no screen flash or white frame on splat.
- `Fx.burst` is the only particle primitive. It has a fixed 0.5 s lifetime, no gravity, and no per-burst colour variety. It is used for the splat spray (18 particles) and the land puff (10).
- There is no dust or "wall-stain" accent. (Wall stains do exist, via `_stain_wall`.)
- The camera does velocity look-ahead (0.3 s, 24 px max), which is good. There is no zoom or punch-in on the chalice.

### Audio (`sfx.gd`, `make_sounds.py`, `make_ambience.py`)

- All SFX are procedurally generated at 22.05 kHz mono. `make_sounds.py` is clean: envelope, bloop, bubble, gurgle, wet_thud, sizzle, metal_ring, crunch, chime_tone, mix and seq.
- Ambience per theme is a faint seamless 24 s loop plus random distant one-shots. This is a strong design.
- **There is no music.** No title theme, no hub theme and no victory sting beyond `chalice`. Everything is on the Master bus. There is a single volume slider and a SOUND on/off toggle.
- **There is no bus structure.** SFX, ambience and UI all share Master, so you cannot duck the ambience under a splat, low-pass it on pause, or offer separate sliders.
- **The "low slime" state is visual only.** The meter pulses red at under 20% (`hud._process`), but nothing is audible. Players looking at the maze, not the HUD, never get the warning.
- Because the target is web (Godot "Web without threads"), the Godot docs mean AudioEffects (low-pass, compressor, reverb) will NOT work in the default Sample playback mode. Any bus-effect plan must be tested or built differently (see U6).
- There are no per-theme footstep or landing variations.

### UI/HUD (`hud.gd`, `ui_kit.gd`, `title.gd`, `touch_controls.gd`)

Strengths:
- The goo-frame panels, per-letter text drips and skin-coloured text are a strong, unified identity.
- The goo-wipe transition is a nice touch.
- The HUD is compact (three pods).
- Coin pop, the record banner and the area name fade are good.
- The touch controls mirror the keyboard actions.
- The rotate hint and the web-aware menu (P for pause, no QUIT) show good web awareness.

Gaps:
- **Text is 8 px.** On a 1280x720 window this is 32 px, fine. But on a phone at 320 base scaled by 2x or 3x it is about 16-24 CSS px, which is small. There is no text-size option.
- **The meter's only state signal is colour** (skin colour, then red). A red-versus-green or red-versus-orange skin difference is not an issue, but the low state relies on red plus a pulse. The pulse is a modulate brightness change of 0.5 to 1.6. This is OK, but there is no secondary cue such as an icon change or shape change, and for photosensitive players a 10 rad/s pulse is about 1.6 Hz, which is acceptable.
- **No reduce-motion or screen-shake toggle.** `controls.gd` only has sound, volume, fullscreen, remap, save code and reset. Shake is hard-wired.
- **No colorblind-related options.** The skins are cosmetic and the maze trail is skin-coloured, so the real risk is low. The main risk is the glimmer and coin-hint cues, which depend on metal colour.
- **Menu keys.** `menu` (Esc) is not remappable, by design.
- **No tutorial.** The first-run teaching is whatever messages the game shows; there is no explicit control prompt that adapts to the device (keyboard hints versus touch hints). Verify in `game.gd` message flow.
- **Title screen has no music and no idle animation of the logo.** The slime previews are at 2x idle. Good, but static otherwise.
- **Records exist (`best_times`), but no ghost, no share card, and no per-level rank feedback beyond the NEW RECORD! banner.** First clears never celebrate a time, by design.

## 2. Ranked upgrade proposals

Ranking is by impact divided by effort and risk. Effort: S under half a day, M about 1-2 days, L several days.

### Tier A: high impact, low effort

**U1. Jump input buffer and "pre-charge" during stun/airborne (S)**
- Why: the single biggest feel gap (see audit 1). GMTK and Celeste-style input forgiveness is general practice. For this game, buffer the press, or better, buffer *holding* the key.
- How: track `_jump_buffer_left`. When `is_action_just_pressed("jump")` arrives in `STUNNED`, `AIRBORNE`, or while `knocked_back`, set it to about 0.15 s. When the state returns to GLIDE, if the buffer is live and `is_action_pressed("jump")` is still true, start CHARGING at once. Optionally allow charge to begin at the tail of the stun, with the last 0.1 s of `SPLAT_STUN` and the recover animation shown as already charging. Do not auto-fire a leap from a tap. Only start the charge.
- Files: `scripts/slime.gd` (`_physics_process` block near line 236, and `State.STUNNED` exit).
- Impact: high, because it removes the "game ate my press" moment after every splat. Risk: low. Could marginally change speedrun timings, which is a feature. Add a test in `tests/test_bounce.gd`/`test_feedback.gd`. Keep `frozen` and `can_charge` guards.

**U2. Hit-stop plus camera kick on splat (S)**
- Why: Nijman's breakdown lists a 10-20 ms hit pause and a directional camera kick as standard impact layers (fetched). The existing shake is random; a kick *into* the wall direction reads as weight.
- How: in `_on_jump_landed` when `hit_wall`, set `camera.offset` to `-wall_normal * kick` (1-3 px scaled by power, integer) and fade it in `_shake_camera`. For hit-stop, a pure `Engine.time_scale = 0` freeze is risky because of the `create_timer` flows. Instead freeze only the slime sprite: pause `sprite` for 2-4 frames (about 50 ms at 60 fps on a full-power splat, 0 on small ones) by holding `_stun_left` and skipping `_animate`. Do not stop the whole tree. Use a cap so ricochets cannot stack.
- Files: `game.gd` (`_on_jump_landed`, `_on_slime_bounced`, `_shake_camera`), `slime.gd`.
- Impact: high. Risk: low if scoped to sprite and camera. Keep it off the timer (the run timer must not be affected).

**U3. Reduce-motion / shake option, plus an accessibility block in SETTINGS (S)**
- Why: remapping, text size and colourblind-safe cues are the most-requested basics (Game Accessibility Guidelines, fetched). Shake and pulsing are the motion we have.
- How: add `Progress.shake_scale` (OFF / HALF / FULL), saved in the ConfigFile. Multiply `SHAKE_MAX` and the ricochet shake by it, and set the kick (U2) to 0 when OFF. A single "REDUCE MOTION" toggle can also slow the meter pulse and the fog/mist drift and skip the title drips. `text_drips.gdshader` has a seed uniform, so a `drips_on` uniform is easy.
- Files: `progress.gd` (`_write`/`_read`, and `save_code` handling, since the code holds the save), `controls.gd`, `game.gd`.
- Impact: medium-high (inclusion and polish), Risk: the save format. It must be backwards-compatible (default to FULL), and old save codes must still load (`read_code` already validates; use `get_value(..., default)`).

**U4. Audible low-slime warning (S)**
- Why: the red pulse is only visible if you look at the HUD, and the game is played in the dark with eyes on the maze.
- How: a soft low heartbeat or "dry crackle" tick generated in `make_sounds.py` (a dull `wet_thud` at roughly 1.2 Hz that speeds up as the meter falls). Play from `game.gd` (or `hud.set_slime`) when `percent < LOW_PERCENT`, with a quiet volume, ceasing on pause or finish. Add a one-shot "crossing 20%" cue (a falling bloop).
- Files: `tools/make_sounds.py`, `scripts/sfx.gd` (`SOUNDS` list), `game.gd`, `hud.gd`.
- Impact: medium-high for tension and readability. It also doubles as a non-visual cue (accessibility). Risk: annoyance. Keep it quiet and bound it to a toggle in SETTINGS.

**U5. Pitch/volume variation inside `Sfx.play` (S)**
- Why: identical repeats cause fatigue. Layered games randomise by a few percent (general knowledge). You already do it for squish.
- How: add an optional `vary := 0.04` parameter, or a per-sound table (`land`, `splat`, `click`, `coin`: plus or minus 4%, volume plus or minus 1.5 dB). Also avoid retriggering the same stream within one frame.
- Files: `scripts/sfx.gd`.
- Impact: medium. Risk: very low. Also stack-safe with web Sample mode (pitch scale works there).

### Tier B: medium effort, high payoff

**U6. Bus layout: SFX / Ambience / Music / UI, with a per-bus slider (M)**
- Why: you cannot add music cleanly or duck ambience without buses. It also enables independent volume sliders (a common accessibility and comfort request).
- How: create `default_bus_layout.tres` with buses Master > [SFX, Ambience, Music, UI]. Set `AudioStreamPlayer.bus` in `Sfx` and in the ambience players in `game.gd`. Extend `Progress` volumes (`music_volume`, `sfx_volume`) and the save.
- **Web warning (verified from docs):** in the default web Sample playback mode, AudioEffects are unsupported. So plain buses (volume, mute) are fine, but a low-pass or compressor will silently do nothing on itch.io. Do ducking by manually tweening `volume_db` on the ambience bus (works everywhere), and use a low-pass only on desktop (or bake a "muffled" variant of the loop). Test whether setting Playback Type to Stream is acceptable for latency. Without threads it increases latency, which would hurt an action game's SFX, so prefer Sample mode and avoid effects.
- Files: new `default_bus_layout.tres`, `sfx.gd`, `game.gd`, `progress.gd`, `controls.gd`.
- Impact: medium-high, enabling U7/U8. Risk: moderate (web audio behaviour). Test on a real web build.

**U7. A sparse adaptive dark-ambient music layer (M-L)**
- Why: the game has ambience and no music. Dark ambient references (general knowledge: Inside, Limbo, Hollow Knight's quiet moments) use sparse sustained tones, long silences and slow filter movement, not melodies. This fits "low and dark, ambience faint".
- How: generate music procedurally in a new `tools/make_music.py` (reuse `bloop`/`chime_tone`/`mix`): per theme, a 40-60 s seamless loop made of a slow drone in a minor mode plus 3-5 sparse tone clusters, much quieter than SFX (about -22 to -26 dB). Adaptive without effects: ship two stems per theme (a "calm" pad and a "tense" pad with a slow tremolo) and crossfade their `volume_db` by tweening on slime meter percent (tense fades in as the meter drops under about 40%), and duck both for a few seconds after a splat or a coin. Silence on the title could be replaced by a single held tone. Keep a `Music` bus and a separate slider (U6). The chalice and victory could get a short, non-fanfare chord swell (the `chalice` sound already does this).
- Files: new `tools/make_music.py`, `assets/sounds/music_*.ogg`/`.wav`, `game.gd` (`_start_ambience`), `title.gd`/`hub.gd`.
- Impact: high for atmosphere. Risk: file size and web load time. 22.05 kHz mono loops of 45 s are about 2 MB each as WAV, so use OGG or fewer unique tracks (3 shared moods, not 10). Also risk: it must not fight the faint ambience. Ship it default-on at low volume with its own slider.

**U8. Distance/attention-based ambience ducking on key events (S-M, after U6)**
- Why: SFX layering clarity. Duck the Ambience bus 3-4 dB for about 0.3 s around splat/coin/chalice sounds, and fade ambience out during dry-up and win moments.
- How: a tween on the bus volume (not an effect). Reuse `AMBIENT_FAINT_DB`.
- Files: `game.gd`, `sfx.gd`.
- Impact: medium. Risk: low.

**U9. Character personality pack for the blob (M, art work in `make_placeholder_art.py`)**
- Why: idle, blink, anticipation and secondary motion are what make a blob read as alive (general animation principles; "squash and stretch", "anticipation", "follow-through"). The charge pose scrub already delivers anticipation, which is the best part.
- How, in priority order:
  1. A blink in the idle loop at an irregular interval (use a timer in `slime.gd` that swaps to a `blink` anim or an eye-mask frame every 3-6 s; keep `idle` as is).
  2. A long-idle behaviour after 6-8 s: a look to one side, a small yawn or a "wobble shiver" frame set.
  3. Glide start/skid frames: a 2-frame lean in the direction of travel when accelerating and a small flatten on a hard reversal.
  4. Landing squash that depends on jump distance (squash frames exist, but only one `land_*` set; scale the frame choice or add `sprite.scale` pulses). Careful: the project rules forbid sub-pixel scaling of sprites. Use integer-pixel frame swaps instead of scale.
  5. Eyes follow the facing direction on idle.
- Files: `tools/make_placeholder_art.py`, `slime_sheet.json` (regenerated), `slime.gd` (`_animate`), and the hat code (`Slime.head_point`/`head_width` read frames, so new frames are picked up automatically, but check hats on the new frames).
- Impact: high on charm. Risk: hats must still sit right on new frames (tests: `test_hats.gd`). Sheet size grows (48 animations now).

**U10. Settings: text-size / readability and a "high-contrast HUD" option (M)**
- Why: text size is the second-most-complained accessibility item (Game Accessibility Guidelines, fetched). Our fixed 8 px font is the constraint.
- How: do not scale the font (pixel rules). Instead offer: (a) a HUD scale of 1x/1.5x is not pixel-clean, so rather (b) a "large HUD" that switches pod labels to the 16 px big font where space allows, and (c) a "high contrast" option that darkens pod backgrounds and removes the text drip shader on gameplay text (`UIKit.text_material()` returns a plain material). The drips are cosmetic but can hurt legibility at phone scale.
- Files: `ui_kit.gd` (`text_material`), `hud.gd`, `controls.gd`, `progress.gd`.
- Impact: medium. Risk: layout overflow in the pods (320 px width is tight). Use the existing `tests/audit_ui.gd` to catch overflow.

### Tier C: UX, mobile/web, retention

**U11. Adaptive control hints and a first-run mini tutorial (S-M)**
- Why: a game whose core verb is "hold to charge, aim, release" needs a 10-second teach. Show it as the first level starts, as a short message on the existing panel (`hud.flash_message`), device-aware (keys versus touch icons), and dismiss it the moment the player does the thing (first charged leap). Only show on first clear count 0 (store a flag in `Progress`).
- Files: `hud.gd`, `game.gd`, `progress.gd` (flag), `touch_controls.gd` (device detection already exists).
- Impact: medium-high for new players and itch visitors. Risk: low. Keep to two lines of 8 px text. Do not put it on the hard-mode or randomizer.

**U12. Audio unlock "tap to start" on web (S)**
- Why: verified from the Godot docs, browsers restrict audio until a gesture. Our title screen already has an ENTER THE HUB button, which is a gesture, but the first sound (and any title ambience or music from U7) must start after it. Make sure no looping audio is started in the title's `_ready` on the web, and play a soft click on the first press. The `Transition` goo wipe already exists, so the first sound after the click is safe.
- Files: `title.gd`, `sfx.gd`, any new music node.
- Impact: avoids a silent first minute on Chrome/Safari. Risk: very low. Test on iOS Safari and Android Chrome.

**U13. Touch controls polish (M)**
- Why: touch is a first-class input here. Concerns from threads (not verified on our build): touch on iOS web exports and fullscreen on iPhone are unreliable, and vibration may not exist in web builds. `Input.vibrate_handheld(60)` is a no-op on the web, so Android Chrome users get no haptic unless we call `navigator.vibrate` via `JavaScriptBridge` (Android Chrome supports it, iOS Safari does not; general knowledge).
- How: (a) `JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(40)")` on splat when on web and a touch device; (b) a visible charge ring around the JUMP button that fills with the charge (the player's thumb hides the slime's charge pose), and a direction arrow when aim differs from motion; (c) an option to swap the stick/jump sides for left-handed players; (d) larger hit areas for pause (`PAUSE_RECT` is 15x13 base px, which is small but has a 5 px margin); (e) a "tap to enter fullscreen" prompt, with the iOS home-screen caveat shown on iPhone.
- Files: `touch_controls.gd`, `slime.gd`, `controls.gd`, `progress.gd`.
- Impact: medium-high for mobile players. Risk: web-specific API differences. Gate everything behind `OS.has_feature("web")` and test on real devices.

**U14. Win/lose screen and result feedback (M)**
- Why: the end of a run is the biggest emotional beat. Currently: a record banner (only when beating an existing record), REPLAY / NEXT / HUB buttons after a 0.6 s delay, and a dry-up choice. Make a clear-state recap: time, slime left (as a star or tier), splats count, coins found, and a "personal best / first clear" distinction. Show the slime left percentage as a pop with a count-up and a short chime per tier (three-step rising bloops from `make_sounds.py`).
- How: `hud.show_record` already exists. Add a compact recap panel built from the same pods, count up with tweens (0.4 s), and let any key skip it. On dry-up, add a fast restart hint ("R: TRY AGAIN") and a gentle "so close" message when the slime ran out within about 3 tiles of the chalice (needs the distance to the goal, which `game.gd` can compute).
- Files: `hud.gd`, `game.gd`, `make_sounds.py`.
- Impact: medium-high for retention. Risk: scope creep. Keep the dry-up screen fast (retry speed matters more than information).

**U15. Ghost of your best run (L)**
- Why: records exist (`best_times`) but are numbers only. A translucent "ghost slime" replaying your best run is the classic racing-game retention feature (general knowledge; the Meat Boy replay result I found is a different, death-trail idea). It suits a jelly-skinned character very well.
- How: record the slime position plus state/frame, sampled at 10-15 Hz (a few KB per level), for the best run per level. Save in a separate compact file (not the main ConfigFile, and not in save codes: the code is about 500 chars, and a ghost would blow that up). Play it back as a `Sprite` with low alpha and no collision. Make it optional ("GHOST: ON/OFF").
- Files: new `scripts/ghost.gd`, `game.gd`, `progress.gd`, `controls.gd`.
- Impact: high for speedrunners, low for casual. Risk: fog-of-war design clash (a ghost shows where the path is, i.e. it reveals the maze). Mitigate by showing the ghost only as a faint dot when inside your lit radius, or only on levels already cleared on your own save. Also web storage (IndexedDB) size, and hard-mode ghost separation.

**U16. Share/result card and save-code UX (S-M)**
- Why: the SAVE CODE panel exists (about 500 chars). Add a one-line shareable run string ("SLIME TIME L7 0:42.3 87%") with a COPY button on the result screen, which is cheap social proof for itch.io. Make the save-code panel safer: show only the first and last characters in the UI with a COPY button, and confirm before LOAD overwrites (`load_code` replaces progress; verify that a confirm exists).
- Files: `hud.gd`/new result screen, `controls.gd`, `progress.gd`.
- Impact: low-medium. Risk: low. Clipboard on web needs a user gesture (already handled for paste).

**U17. Title and menu polish (S)**
- Title: let the logo react (a slow goo drip pulse, or the two slimes blink and occasionally look at the button), and add a single held low tone or the ambience at -30 dB so the first screen is not silent. Add focus and press audio on every menu button (hover/focus tick, which `click` could provide at a lower volume via `focus_entered`), because keyboard menus currently only sound on press.
- Files: `title.gd`, `ui_kit.gd` (`make_button`).
- Impact: low-medium. Risk: very low.

**U18. Particle and FX depth pass (S-M)**
- Extend `Fx.burst` with gravity, lifetime and size parameters. Add: a coin-pickup sparkle in metal colour, a charge-up ring or glow that tightens as the charge fills, a dust puff on skid, a wall-hit "flash" frame, and trailing droplets on a full leap. Keep particle counts low for the Android WebGL target (CPUParticles2D is the right choice here, and the counts are already modest: 10-18).
- Files: `fx.gd`, `game.gd`, `slime.gd`.
- Impact: medium. Risk: web performance. Cap simultaneous bursts at about 4.

## 3. Summary table

| # | Upgrade | Effort | Impact | Main files | Key risk |
|---|---------|--------|--------|------------|----------|
| U1 | Jump input buffer (stun/air/knockback) | S | High | slime.gd | Timing changes (test) |
| U2 | Hit-stop (sprite only) + camera kick | S | High | game.gd, slime.gd | Must not touch run timer |
| U3 | Reduce motion / shake option | S | Med-High | progress.gd, controls.gd, game.gd | Save-format compatibility |
| U4 | Audible low-slime warning | S | Med-High | make_sounds.py, sfx.gd, game.gd | Annoyance, keep quiet |
| U5 | SFX pitch/volume variation | S | Medium | sfx.gd | Minimal |
| U6 | Audio buses and sliders | M | Med-High | new bus layout, sfx.gd, game.gd, progress.gd | Web Sample mode: no effects |
| U7 | Sparse adaptive dark music | M-L | High | new make_music.py, game.gd | Size, mix vs faint ambience |
| U8 | Ambience ducking via tweens | S-M | Medium | game.gd, sfx.gd | Low |
| U9 | Blob personality (blink, idles, skid) | M | High | make_placeholder_art.py, slime.gd | Hats on new frames |
| U10 | Large HUD text / high contrast | M | Medium | ui_kit.gd, hud.gd, controls.gd | Pod overflow |
| U11 | Adaptive first-run hints | S-M | Med-High | hud.gd, game.gd, progress.gd | Low |
| U12 | Web audio unlock on first gesture | S | Medium | title.gd, sfx.gd | Test on iOS/Android |
| U13 | Touch polish and web vibrate | M | Med-High | touch_controls.gd, slime.gd | Device variance |
| U14 | Result recap and near-miss messaging | M | Med-High | hud.gd, game.gd | Keep retry fast |
| U15 | Best-run ghost | L | High (niche) | new ghost.gd, game.gd | Reveals the maze; storage |
| U16 | Share string and safer save code | S-M | Low-Med | hud.gd, controls.gd | Low |
| U17 | Title/menu polish and focus sounds | S | Low-Med | title.gd, ui_kit.gd | Low |
| U18 | Particle/FX depth pass | S-M | Medium | fx.gd | Android WebGL cost |

## 4. Suggested order

1. **Week 1 (all S):** U1, U2, U5, U4, U3, U12. These fix input forgiveness, impact weight, audio fatigue, a missing audio cue and the accessibility basics.
2. **Week 2:** U6 then U8, U11, U17.
3. **Then character and mood:** U9, then U7.
4. **Mobile and retention:** U13, U14, then U15/U16 if the game gets a leaderboard audience.

## 5. Things I would NOT change

- The integer-pixel shake, the lane assist and corner leeway, the charge-pose scrub, the faint ambience level, the low and dark SFX palette, and the goo-drip type. These are the game's identity.
- Do not add coyote time: there is no ledge in a top-down maze. The equivalent forgiveness is already the lane assist and corner leeway (and U1 for input).
- Do not use whole-tree `Engine.time_scale` freezes. Many flows use `create_timer` and `Transition`, and the run timer must stay honest.
- Do not rely on Godot AudioEffects for web (verified limitation in Sample mode).

## 6. Open questions for the owner

1. Is higher SFX latency acceptable on web if Stream mode were needed for effects? My recommendation is no, so effects stay desktop-only.
2. Should splat hit-stop be allowed on hard mode and records? It does not change the logical simulation (only the sprite is held) but should be checked against `test_records.gd`.
3. Is a ghost acceptable, given that it hints at the route through a maze you are meant to discover in the dark?
