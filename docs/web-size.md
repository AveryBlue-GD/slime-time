# Web build size (measured)

Measured 2026-10-21 on the Mac (QA must-fix 15), Godot 4.7.2 official web template (no threads), release exports:
`./tools/godot.sh --path . --headless --export-release "Web Demo" build/demo/web/index.html` and the same for "Web".
Gzip = `gzip -9` of each file, roughly what a server sends when it compresses on the fly.

| File | Web Demo | gzip | Full web game | gzip |
|---|---|---|---|---|
| `index.wasm` (the engine) | 39.51 MB | 10.05 MB | 39.51 MB | 10.05 MB |
| `index.pck` (the game) | 5.18 MB | 4.56 MB | 7.12 MB | 5.10 MB |
| `index.js` | 0.28 MB | 0.07 MB | 0.28 MB | 0.07 MB |
| html, worklets, icons | 0.08 MB | 0.04 MB | 0.08 MB | 0.04 MB |
| **Total** | **45.1 MB** | **14.8 MB** | **47.0 MB** | **15.3 MB** |

The Web Demo column was re-measured 2026-10-21 on Windows (same template, `gzip -9` in Python) after the web demo got
level 4 (Sunken Shrine) and the game got music (the three hub loops and the intro, 2.1 MB of OGG that barely
compresses); before both it was 2.57 / 2.21 MB pack, 42.4 / 12.4 MB in all. The full-game column predates the music
(add about 2.1 MB). The demo's pack is smaller than the full one because levels 5-10, their themes and ambience and
the translation catalogs are cut (`Demo.export_cut`). The engine is the same 39.5 MB for both and is 80% of the download.

## What a player waits for (estimate, not measured on a phone)

Download only, with compression, before the TAP TO PLAY gate; the browser caches it, so a second visit is quick.

| Connection | Web Demo (14.8 MB) | Without compression (45.1 MB) |
|---|---|---|
| Good 4G / 5G (~40 Mbit/s) | ~3 s | ~9 s |
| Average 4G (~15 Mbit/s) | ~8 s | ~24 s |
| Weak 4G / 3G (~4 Mbit/s) | ~30 s | ~90 s |

So compression matters more than anything else: the wasm shrinks to a quarter.

## To check on itch.io (owner, before the demo goes out)

1. Upload the web demo zip, open the page, open the browser's developer tools (Network tab), reload, and click
   `index.wasm`: the response headers should show `Content-Encoding: gzip` (or `br`) and a transferred size near
   10 MB. If it shows ~39.5 MB, itch serves it uncompressed: ask itch support, or host the web demo elsewhere
   with compression (I couldn't check itch's behaviour from here).
2. Load it once on a phone over mobile data (not Wi-Fi) and time it to the TAP TO PLAY gate.
3. The zip must not carry the stray `*.import` files Godot writes next to exported PNGs in `build/` (harmless, but
   clutter): delete them before zipping.

## Making it smaller (next steps, not done)

- **A size-optimised web template** (the biggest win): build Godot 4.7.2's web template with `scons platform=web
  target=template_release production=yes optimize=size_extra` plus a `custom.py` that turns off what the game never uses
  (`disable_3d=yes`, `module_*_enabled=no` for 3D physics, navigation 3D, OpenXR, GLTF, CSG, GridMap, text_server_adv
  -> text_server_fb, etc.). Typical result for a 2D game: the wasm drops from 39.5 MB to about 15-20 MB (gzip about 4-5 MB),
  so the demo would be around 6-7 MB compressed. Needs emscripten and an hour of build time; set it as the Web presets'
  `custom_template/release`. Test the whole game on it (fonts: the game uses bitmap fonts, so the fallback text server is fine).
- The pack: `index.pck` is already small; the demo's 5.2 MB is mostly the music (2.1 MB) and the sprites and sounds of levels 1-4.
- Loading feedback already exists: the web shell shows a progress bar, and on phones a TAP TO PLAY gate.
