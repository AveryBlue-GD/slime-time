# Marketing: what's here

Everything for the Dry Trying marketing push. Facts and rules come from [brief.md](brief.md) first; if a file below
disagrees with it, brief.md wins.

| File | What it is |
|---|---|
| [brief.md](brief.md) | the pitch, the facts, the rules for every post (source of truth) |
| [rules.md](rules.md) | the short rule card for marketing threads |
| [steam-page.md](steam-page.md) | Steam store page copy: short and long description, tags, capsule notes |
| [posts-4-weeks.md](posts-4-weeks.md) | four weeks of posts per platform, hooks, hashtags, Chinese lines |
| [outreach.md](outreach.md) | creator and press outreach list and email templates |
| [marketing-kit.md](marketing-kit.md) | the timeline (Steam fee, Next Fest, itch demo) and the asset checklist |
| [trailer.md](trailer.md) | how the vertical Shorts are made and edited (`tools/trailer/trailer.json`) |
| [music.md](music.md) | the code-made music mockups (`tools/make_music.py`) |
| [../steam-setup.md](../steam-setup.md) | the Steam app, GodotSteam, presets and depots (owner steps) |
| [../web-size.md](../web-size.md) | the web demo's download size and how to check itch serves it compressed |
| [../qa/qa-report.md](../qa/qa-report.md) | the pre-demo QA report (must-fixes, before release, nice to have) |

## The rendered assets (not in git)

One command re-renders them all from the current game, to fixed file names, so links and uploads never change:

```bash
./tools/marketing/refresh.sh            # music, Shorts, Steam art
./tools/marketing/refresh.sh --zh       # ... plus the Chinese Shorts for Douyin / Bilibili
./tools/marketing/refresh.sh --only steam   # just one group: music, shorts or steam
```

| Folder | Files |
|---|---|
| `build/music/` | `hub_A.wav` `hub_B.wav` `hub_C.wav` `trailer_1.wav` `trailer_2.wav` (+ `.ogg`) |
| `build/trailer/` | `short_A.mp4` `short_B.mp4` `short_C.mp4`, `short_<ID>_music.mp4`, `short_<ID>_sheet.png`; with `--zh` also `short_<ID>_zh.mp4`, `_zh_music.mp4`, `_zh_sheet.png` |
| `build/promo/steam/` | `header_capsule_920x430.png` `small_capsule_462x174.png` `main_capsule_1232x706.png` `vertical_capsule_748x896.png` `library_capsule_600x900.png` `library_hero_3840x1240.png` `library_logo_1280.png`, `screenshot_1_dark_dungeon.png` ... `screenshot_6_skins.png` (1920x1080) |
| `build/promo/steam/demo/` | the five capsules again with the DEMO sticker, for the demo app |

Needs Godot 4.7.2 and ffmpeg (`brew install ffmpeg` on the Mac). The itch.io cover and screenshots are separate:
`./tools/promo/make_promo.sh`.

## How the Steam art follows the rules

- Each level is shown in its own skin: header Frost (L7), small Lime (L1), main Ocean (L4), vertical Bubblegum (L9),
  library Mint (L2), hero Ember (L10); screenshots L1 Lime, L4 Ocean, L6 Crimson, L7 Frost, L10 Ember.
- RAINBOW and STOPWATCH only as the skins screen's black silhouettes (`--promo` keeps them locked). No HEAT anywhere.
- Steam allows only the art and the game's name on capsules, so there is no tagline on them; the library hero has no text.
- Renderer: `tools/promo/capsule.tscn` (one viewport per size, the level played by the autopilot, the logo centred on
  its ink). Change a shot's level, skin or frame in `tools/promo/make_steam_art.sh`.

## Chinese captions

`tools/trailer/captions_zh.json` maps each English caption to its Chinese line (from the table in
[posts-4-weeks.md](posts-4-weeks.md)); the glyphs are `tools/trailer/goo_cjk/` (Fusion Pixel 12px, SIL OFL 1.1, its
licence is in that folder). A new caption needs a row in the JSON; a new Chinese character needs the glyphs
regenerated (`tools/trailer/goo_cjk/README.md`). Have a native speaker check a cut before posting.
