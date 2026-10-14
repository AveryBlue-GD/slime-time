# Updating the itch.io page from a Mac

Step-by-step for publishing a new build. Nothing here runs on its own: you do the export and the upload.
(Background, fresh-start policy and platform notes: [itch-release.md](itch-release.md). Real-phone checklist:
[qa-web-report.md](qa-web-report.md).)

## 0. Before you build

1. `cd ~/code/slime-time && git checkout v2 && git pull`
2. `./tools/test_all.sh 2>&1 | tail -3` (about 4 minutes) - it must say `failed: 0`.
3. Replace placeholders you care about in `export_presets.cfg` (Windows company/product/version strings, macOS
   bundle id `com.slimetime.game`) and decide the version number you will show on itch.
4. Optional but wise: play `./tools/play.sh` (real save, fresh epoch) and run the 5-minute phone checklist in
   `docs/qa-web-report.md` on a real iPhone and Android phone against a restricted/draft itch page (step 3).

## 1. Export (builds go to the git-ignored `build/` folder)

Terminal (needs the 4.7.2 export templates, already installed):

```bash
cd ~/code/slime-time
rm -rf build/web && mkdir -p build/web
./tools/godot.sh --path . --headless --export-release "Web" build/web/index.html
ls build/web          # index.html, index.js, index.wasm, index.pck, ...
```

Or in the editor: open `/Applications/Godot.app`, import the project, Project > Export > "Web" > untick
"Export With Debug" > Export Project (save as `build/web/index.html`).

Desktop builds (optional):

```bash
./tools/godot.sh --path . --headless --export-release "Windows Desktop" build/windows/SlimeTime.exe
./tools/godot.sh --path . --headless --export-release "macOS" build/macos/SlimeTime.zip
```

## 2. Zip the web build (index.html must be at the top level of the zip)

```bash
cd build/web && rm -f ../SlimeTime-Web-itch.zip && zip -r ../SlimeTime-Web-itch.zip . -x ".DS_Store" && cd ../..
unzip -l build/SlimeTime-Web-itch.zip | head      # index.html must NOT be inside a folder
```

## 3. Upload on itch.io (dashboard)

1. itch.io > top-right menu > Dashboard > your game > **Edit game**.
2. **Kind of project:** HTML.
3. **Uploads:** delete the old web zip (so nobody loads the old build), then **Upload files** and pick
   `SlimeTime-Web-itch.zip`. Tick **This file will be played in the browser**.
4. **Embed options:** viewport **960 x 540** (the game is 16:9), tick **Mobile friendly**, **Fullscreen button**,
   leave **SharedArrayBuffer off** (the build is single-threaded), scrollbars off, orientation landscape if offered.
5. **Visibility:** set it to **Draft** (or Restricted) while you test, then **Public** when happy.
6. Optional desktop downloads: upload the Windows zip and `SlimeTime.zip` (macOS) as separate files and tick the
   right platform boxes. On the macOS file's description add the Gatekeeper note (right-click > Open, or
   `xattr -dr com.apple.quarantine "Slime Time.app"`), because the app is ad-hoc signed, not notarized.
7. **Save**, then **View page** and test it in a private window: fresh start with the story trailer, level 1,
   hub, map table, SAVE CODE, fullscreen, reload (save persists).

## 4. Page text and images

- Tagline: update the old one (it still had the "!"): `ESCAPE THE FOG / OR DRY TRYING`.
- Description: what the game is, controls (WASD/arrows glide, Space leap, F interact, Esc/P pause), the hub,
  randomizer tickets, hard mode, the trail map; mention it saves in the browser.
- Tags, genre (Puzzle / Action), "Made with Godot", pricing (free, or "$0 or donate"), accessibility notes
  (Reduce Motion, remappable keys, fog brightness).
- Cover image and screenshots: the old promo images are stale. Re-rendering them is deliberate release work
  (`tools/promo/`); ask Claude when you want that done.
- A short devlog post for the update.

## 5. Faster updates with butler (optional, after the first upload)

```bash
# install: https://itch.io/docs/butler/installing.html  (then)
butler login
butler push build/SlimeTime-Web-itch.zip YOUR-USER/YOUR-GAME:html5 --userversion 1.0.0
```

The channel name decides what itch treats the upload as; after the first push, open the dashboard and make sure
the file still has **This file will be played in the browser** ticked. Check the exact channel naming rules in the
butler docs before relying on this.

## 6. After publishing

- Open the page on a phone (portrait, then rotate) and on a desktop browser; confirm the first load is acceptable.
- Check itch serves the files compressed (the build is about 14 MB gzipped, 45 MB raw).
- If something breaks, the previous zip can be re-uploaded; saves are unaffected (they live in the browser under
  `SlimeTime_R1`).
- To wipe everyone's saves in a future release, follow "Bumping the epoch" in itch-release.md.
