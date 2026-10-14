# Web release QA (itch.io, every device class)

Date: 2026-10-14. Godot 4.7.2 (`web_nothreads_release` template), branch state after `cbceb26`. Fixes are in
`ee69d60` (rotate cover), `4e86c23` (save code copy/paste on itch) and `faf70e9` (custom HTML shell). Tests:
`./tools/test_all.sh` → `suites: 57 failed: 0`. The real saves were not touched (`SlimeTime_R1/save.cfg` does not exist
on this Mac; the pre-release save's md5 `6e9f56da…` is unchanged).

## Status (2026-10-14, after the release fix pass)

- **O3 fixed:** the rotate cover now says ROTATE YOUR DEVICE (iPads in portrait). Same layout, one letter longer.
- **O4 fixed (disabled, not hidden):** where the browser has no Fullscreen API for page elements (iPhone Safari:
  `document.fullscreenEnabled` / `webkitFullscreenEnabled` false), SETTINGS shows FULLSCREEN as a disabled (dried-goo)
  button (`Progress.fullscreen_available`, `controls.gd`). Layout and focus order unchanged; desktop and Android unchanged.
  Not verified on a real iPhone.
- Release fixes that affect the web build too (see [qa-release-report.md](qa-release-report.md) Status): pasted codes and
  the save are checked by an allow-list before parsing (no code execution, no crash, no hang), saves are written
  atomically (temp + rename; checked in the browser: IndexedDB holds `/userfs/SlimeTime_R1/save.cfg` with the new data,
  no `.tmp` left), an unreadable save is kept as `save.corrupt.cfg`, codes pasted with invisible characters / quotes load.
- Still open (owner decisions or engine limits): O1 tap targets, O2 loading screen, O5 context loss, O6 download size,
  O7 Ctrl+C in the code box.

## 1. Environment and method

- **Build:** `Godot --headless --export-release "Web" /private/tmp/claude-501/webtest/index.html`, re-exported after
  every fix. Served from `127.0.0.1:8765` by a small no-cache static server (`/private/tmp/claude-501/qa_tools/serve.py`).
- **Browser:** the Claude desktop app's built-in browser pane (Chromium 152, macOS, Apple M3, DPR 2) with its viewport
  emulation (`mobile` preset = Pixel 8 UA + 5 touch points; any width < 768 also emulates touch).
- **itch-like page:** `/private/tmp/claude-501/webtest/itch_wrapper.html`: a long scrolling page with the game in an
  iframe (`allowfullscreen`, itch's real `allow=` list incl. `autoplay; fullscreen *; gamepad`), 960x540 by default,
  `?mode=fill` for the mobile "fill the screen" variant, and a Fullscreen button on the iframe like itch's.
  **Loading the game from `127.0.0.1` inside a page served from `localhost` makes it cross-origin**, exactly like
  itch (`itch.io` page, game on `html-classic.itch.zone`). That is what exposed the clipboard bug below.
- **Probe (test only, never shipped):** `index_probe.html` = the exported `index.html` + `probe.js` in `<head>`:
  rAF frame deltas, `PerformanceObserver('longtask')`, the wasm heap size (from the instantiated module), AudioContext
  states, IndexedDB read/edit helpers, synthetic touch/key helpers, `?args=` (engine/game args), `?noidb=1` (IndexedDB
  blocked), `?nogl=1` (no WebGL 2), a frame gate to freeze/step the main loop, and `pump()` which drives frames by hand
  at 60 Hz and records the CPU time of each main-loop iteration. A `postMessage` bridge runs probe code in the
  cross-origin frame.
- **Caveat about the pane:** while the pane is hidden the browser throttles `requestAnimationFrame` to about 1 Hz (it
  reports `visibilityState: hidden`), so wall-clock frame rates are only meaningful inside a running script. Frame
  costs below therefore come from `pump()` (CPU per frame at a forced 60 Hz) and from rAF deltas taken while frames
  were flowing; long tasks are measured by the browser and are unaffected.

## 2. Results by scenario

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Boot, loading screen | PASS | localhost, no cache: overlay gone 0.36-0.92 s after navigation; download is 44.7 MB raw / ~14 MB gzipped (see perf doc F1/F2), so on itch the download dominates (~11 s at 10 Mbit/s). Default Godot splash on #242424 with a progress bar; no "click to start" screen (`focus_canvas_on_start`). |
| 2 | Console on a clean load | PASS | Only the 3 engine info lines (version, `WebGL 2.0 … Compatibility`, `Emscripten 4.0.20, single-threaded`). `GL_INVALID_FRAMEBUFFER_OPERATION … zero size` warnings appeared only once while the pane itself was 0 px wide (harmless, capped by Chrome). `Blocked call to navigator.vibrate` errors appeared only with synthetic (untrusted) input; real keys/taps grant user activation. The `Unrecognized feature: 'monetization'/'xr'/'web-share'` warnings come from itch's own `allow=` list, not the game. |
| 3 | First-launch story trailer | PASS | Plays on a fresh IndexedDB; a click/tap advances a shot, Esc/P skips; `story_seen=1` reaches IndexedDB. |
| 4 | Canvas size / integer scaling | PASS | Canvas always equals the viewport, no scrollbars (scrollW/H = viewport). Integer scale (device px): 1280x720 → 8 (fills), 1920x1080 → 12 (fills), 2560x1080 ultrawide → 12 (pillarbox), 1024x768 → 6 (letterbox), 768x1024 → 4, 375x812/390x844/360x740 portrait → 2-3, 740x360 / 812x375 landscape → 4, itch 960x540 iframe → 6 (fills exactly), itch fill mode 390x844 → 2. Resizing while running re-fits on the next frame. |
| 5 | Rotate-your-phone cover | **FAIL → FIXED** | Portrait touch: cover shows. **Bug W1:** turning to landscape left the cover up (until a finger touched), and turning to portrait mid-game never showed it. After the fix: 360x740 → 740x360 hides it, back to portrait shows it, game paused under it, taps behind it do nothing. |
| 6 | Touch controls only on touch | PASS | Mobile emulation: joystick + JUMP + pause shown in a level; synthetic touch drag moved the slime. Desktop: not shown. A key press hides them (by design). |
| 7 | Tap targets | RISK (no change) | On a landscape phone a game pixel is 2 CSS px: menu buttons are ~240x28 px (Apple asks 44 pt, Material 48 dp); STORY on the title ~20 px tall. JUMP is ~76 px wide, the pause button with its margin ~50x46 px. Usable, but small for big thumbs. Changing it is a visual change (owner decision). |
| 8 | Page scroll / zoom / selection / context menu | PASS | Inside the itch-like iframe, arrows/Space/PageDown never scrolled the parent (canvas focused, Godot `preventDefault`s keys), also with focus forced onto the iframe's body. The engine blocks the canvas context menu; `touch-action: none`. The new shell adds `overscroll-behavior: none` (pull-to-refresh), `user-select: none`, `-webkit-touch-callout: none`, no tap highlight. |
| 9 | Keyboard focus | PASS | The canvas has focus right after start even in a cross-origin iframe; a click on the canvas refocuses it. New: the canvas takes the focus back when the frame regains focus with nothing focused. |
| 10 | Audio unlock | PASS | Godot resumes its AudioContext on input: suspended → running after one click and after one key. (The pane allows autoplay, so the locked first state itself was simulated with `suspend()`.) No autoplay errors. |
| 11 | Pause / Esc / P | PASS | In a level: Esc pauses, Esc resumes, P pauses, P resumes, no double toggles. In real fullscreen the browser keeps Esc (exits fullscreen) and does not send it to the page, so P is the web pause key (the settings hint already says so). |
| 12 | Fullscreen | PASS (request) | F11 is the browser's own. SETTINGS > FULLSCREEN calls `canvas.requestFullscreen()` with user activation (hooked and logged). The pane cannot enter fullscreen at all (even the wrapper's own button), so the end state was not observable here. itch's own fullscreen button fullscreens the iframe; the game re-fits (same as any resize). iPhone Safari has no Fullscreen API for a canvas: the button does nothing there. |
| 13 | SAVE CODE COPY in itch's iframe | **FAIL → FIXED** | **Bug W2:** `navigator.clipboard.writeText` is refused in a cross-origin iframe without `clipboard-write` ("blocked because of a permissions policy") but the panel said COPIED!. Fixed: COPY now uses a hidden text box + `execCommand('copy')` (copy event carried the whole 547-char code), then `writeText`, then the browser's prompt with the code (each fallback verified by stubbing the earlier step). |
| 14 | PASTE / Ctrl+V in itch's iframe | **FAIL (phones) → FIXED** | `readText` is refused the same way; the old fallback said "CLICK THE BOX AND PRESS CTRL+V", impossible on a phone. The page `paste` event path works (a synthetic ClipboardEvent filled the box: PASTED - PRESS LOAD). Fixed: PASTE now falls back to the browser's prompt (long-press → Paste works in it); verified: PASTED - PRESS LOAD. |
| 15 | Save persistence across reload | PASS | `story_seen`, settings and an edited `levels_cleared=10` survived reloads (IndexedDB `/userfs/SlimeTime_R1/save.cfg`). A key press → save in IndexedDB took 53 ms. |
| 16 | Save flushed when the tab is hidden/closed | **FAIL → FIXED** | **Bug W3:** frame-stepped: the frame that handles SOUND writes the file in memory, IndexedDB is only updated at the start of the next frame, and a hidden tab gets no more frames. With the shell's flush, a `visibilitychange` (hidden) right after that frame put `sound_on=true` in IndexedDB within 400 ms; the game ran on normally after. |
| 17 | IndexedDB blocked (third-party storage blocked, some privacy modes) | PASS + message added | The game runs and plays without saving (`?noidb=1`). New: a top bar says progress won't be kept and points to SAVE CODE; OK hides it and returns the keyboard. Note: normal incognito/private windows keep IndexedDB (in memory). |
| 18 | WebGL context lost | **Improved** | Engine behavior: `alert("WebGL context lost, please reload the page")`, then a dead black canvas (Godot 4 cannot restore; `restoreContext()` stays black). Now a cover with RELOAD (flushes, then reloads); the reload came back with the saved state. |
| 19 | Missing WebGL 2 / old browser | **Improved** | `?nogl=1`: the stock "Error / features missing" box now starts with a plain-language explanation (needs WebGL 2, update the browser / iOS 15+, hardware acceleration). A browser that can't parse the engine script gets a message instead of a black page. |
| 20 | Return after a long background pause | PASS | Level 10, main loop frozen 25.8 s with a direction held, then one frame: run timer 0:32.1 → 0:32.3 (the 8-physics-step cap), slime moved a few px, no fling or wall tunnelling. Timer and movement live in `_physics_process`; `_process` users (hub idle anims, hat wheel, chalice glow, story) clamp or consume bounded steps. |
| 21 | Memory | PASS | wasm heap: 32 MB at boot → 46 MB title/hub → 80 MB after level 10; then flat at 80 MB over 15 restarts of hard level 10 and 10 title↔hub round trips (heap never grew). JS heap 31-44 MB. |
| 22 | Frame cost (CPU per frame, M3, 1280x800 at DPR 2) | PASS | title 0.9 ms (rainbow 1.0), hub 0.6 ms (rainbow 1.6), settings rainbow 1.6, story intro 1.25 (p99 1.9), level 10 rainbow + fog + trail 1.8 ms (p99 2.5). rAF while frames flowed: hub and level 10 at 60 fps, p99 17.6-17.7 ms. Estimated mid-range Android (4-6x slower wasm): 5-11 ms per frame, still 60 fps. |
| 23 | Scene-load hitches | OK / note | Long tasks: level 10 load 127 + 146 ms, hard level 10 (36x20) 148 + 199 ms, a level restart 71-76 ms, story start 39 ms, title/hub < 50 ms after first use. Native randomizer 36x20 generation: mean 12.5 ms, worst 30.7 ms (wasm ~2-4x). All under the goo cover; on a mid phone expect 0.4-0.8 s on the biggest mazes. Caching ideas are in [perf/startup-memory-web.md](perf/startup-memory-web.md) F3/F4. |

## 3. Bugs

Fixed (each re-exported and re-verified in the browser; desktop/native behavior unchanged):

- **W1 Rotate cover stuck** (`scripts/ui/rotate_hint.gd`). Repro (old build): mobile emulation 360x740, load, turn to
  740x360: the cover stays until a tap; turn back to portrait mid-level: no cover, the level keeps running. Cause:
  stretch mode `viewport` keeps the root viewport 320x180, so `size_changed` never fires on a browser resize. Fix: the
  window size is checked each frame; while covered the tree is paused (story/level don't run on unseen, taps don't
  reach hidden buttons) and the pause state is restored after. Tests: `test_touch.gd` (+5 checks).
- **W2 COPY silently failed on itch** (`scripts/ui/controls.gd`). Repro (old build): itch-like cross-origin iframe →
  SETTINGS > SAVE CODE > COPY → "COPIED!" but `writeText` was rejected by the permissions policy. Players would lose
  their backup codes. Fix described in row 13. Tests: `test_save_code.gd` (+3 checks).
- **W3 Save not flushed on hide** (`tools/web_shell.html`). Repro: freeze the main loop right after a frame that saved;
  IndexedDB keeps the old save until the tab is shown again (and phones kill background tabs). Fix: the shell wraps
  `requestAnimationFrame` and runs the pending frame at once on `visibilitychange`→hidden and `pagehide`, so Godot's
  own sync starts. Verified by frame stepping.
- **W4 PASTE impossible on phones on itch** (`controls.gd`): browser prompt fallback (row 14).
- **W5 Unfriendly failure screens** (`web_shell.html`): context lost alert, missing WebGL 2, unreadable engine script,
  failed start, IndexedDB blocked: all now have a plain message (rows 17-19).

Open (not changed; owner decisions or engine limits):

- **O1 Tap targets** below the 44 pt / 48 dp guidance on phones (row 7): a visual change.
- **O2 Loading screen shows the Godot logo** on grey (`application/boot_splash` not set; same on desktop). A game splash
  and a dark background color would look more finished: visual change.
- **O3 Rotate cover text says PHONE on iPads** in portrait (an iPad could play letterboxed in portrait). Wording/visual.
- **O4 FULLSCREEN button does nothing on iPhone** (no Fullscreen API for elements on iPhone Safari); the label stays OFF.
  Could be hidden on iOS: visual change. itch's own fullscreen button has the same limit there.
- **O5 Context loss is unrecoverable in Godot 4** (engine). The cover + RELOAD is the mitigation.
- **O6 Download size** 14 MB gzipped (perf doc F1: a 2D-only custom template would roughly halve the wasm). Check on
  itch that `.wasm`/`.pck` are served compressed (perf doc F2).
- **O7 Ctrl+C inside the code box** still goes through Godot's clipboard (refused on itch); the COPY button works.

## 4. Risk by device class

| Device / browser | Risk | Notes |
|---|---|---|
| Windows / macOS / Linux, Chrome or Edge | Low | Everything above was run in Chromium. Integer scaling leaves black bars on odd window sizes (by design). |
| Firefox desktop | Low-medium | WebGL 2 fine. `execCommand('copy')` is only allowed inside the click handler there, so COPY falls back to `writeText` (Firefox has no clipboard permissions policy, allowed with the click's activation); worst case the prompt. `readText` shows Firefox's own Paste button. Untested here. |
| Safari desktop (macOS 13+) | Medium | WebGL 2 (Safari 15+). Clipboard calls outside the click handler may be refused → the prompt fallbacks. Audio resumes on input. Untested here. |
| Android Chrome | Low-medium | Touch controls, rotate cover, flush on hide, PASTE/COPY fallbacks all exercised in emulation. Run-time-indexed shader arrays were already removed for Android GPUs. Real GPU, thermal and memory behavior unverified. |
| iPhone Safari (iOS 15+) | Medium | WebGL 2 needs iOS 15+. No element fullscreen (O4). Audio needs a tap (Godot resumes it on input; it also resumes after an interruption on the next tap). The dynamic toolbar resizes the canvas (handled by the adaptive canvas). Long-press callout and double-tap zoom are off (`touch-action: none`, callout CSS). iOS may drop the WebGL context of a background tab under memory pressure → the RELOAD cover (saves are flushed on hide). Background tabs are suspended → the flush fix matters most here. |
| iPad Safari | Medium | Reports a Mac UA with touch: touch controls show, portrait gets the PHONE cover (O3). Landscape fits at 6x on 1024x768 (letterboxed). |
| Old devices / no WebGL 2 | — | Friendly message instead of a technical one. |

## 5. Not testable without real devices

Real touch latency and multi-touch (joystick + JUMP together), the actual audio-unlock gesture rules (the pane allows
autoplay), real fullscreen on desktop and Android, iOS Safari as a whole (WebKit, toolbar resize, background tab
eviction, context loss), GPU performance on phones, thermal throttling, the real itch page (its click-to-play overlay,
gzip on its CDN, `html-classic.itch.zone` storage partitioning), Firefox and Safari clipboard prompts.

## 6. Five-minute phone checklist (owner)

Upload the new web zip to itch, then on an Android phone (Chrome) and an iPhone (Safari):

1. Open the game page in portrait: the ROTATE YOUR DEVICE cover shows. Turn sideways: it goes away at once (no tap). Turn back mid-level: the cover returns and the level is paused under it.
2. Fresh start: the story plays sideways; a tap advances, sound plays after the first tap.
3. Play 30 s of level 1 with the joystick and JUMP (hold to charge); the pause button (top right) pauses.
4. SETTINGS > SAVE CODE > COPY: it says COPIED! (or shows a pop-up with the code to copy). Paste it in a notes app: the whole `SLIME2-…` code is there.
5. PASTE: a pop-up asks for the code (long-press → Paste) or it fills directly: PASTED - PRESS LOAD.
6. Change SOUND, then immediately switch to another app for a minute, come back (or reload): the setting kept.
7. Leave the tab in the background 5+ minutes, return: no jump in the level timer beyond a fraction of a second, and if the graphics were reset a RELOAD button appears (progress kept).
8. Try itch's fullscreen button (Android) and SETTINGS > FULLSCREEN (Android; disabled on iPhone).
9. On a desktop: click the game on the itch page, arrows and Space don't scroll the page; P pauses; Esc pauses (and only exits fullscreen when fullscreen).
