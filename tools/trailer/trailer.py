"""Renders the vertical trailer drafts (9:16 Shorts / TikTok / Reels) from the real game.

Everything a draft shows is defined in tools/trailer/trailer.json:
  takes   named moments of the real game, each one Godot movie-writer run of
          res://tools/trailer/take.tscn (see take.gd for the modes and flags) at 320x180, 60 fps,
          PNG frames + the game's own audio (WAV). Same flags = same pictures (seeded).
  drafts  a list of beats (a slice of a take, how it is framed, the caption over it) and an end
          card (res://tools/trailer/card.tscn: logo + try-on stage; the words are goo_text overlays).
Steps: render the takes (skipped when their flags haven't changed; --force re-renders), render the
caption overlays and the end card's words in the logo's gooey lettering (goo_text.py) and the end
cards (card.tscn: logo + try-on stage), cut and frame every beat with ffmpeg (nearest-neighbour
upscale, 1080x1920), join them, normalise the audio and write
build/trailer/short_<ID>.mp4 + short_<ID>_sheet.png (contact sheet: one frame per beat) +
build/trailer/README.md.
Music (optional): a draft's "music" (or --music) puts a track under the game's audio and writes
build/trailer/short_<ID>_music.mp4 next to the plain cut. A tools/make_music.py trailer track
("trailer_1", "trailer_2") is rendered fitted to the draft, its final hit exactly on the end card; a file
(WAV/OGG/MP3) is used as is, shifted so its "hit" (seconds) lands on the end card. --music-only remixes
the existing short_<ID>.mp4 files (no Godot, no re-cut). See docs/marketing/music.md.

Portrait takes ("scene": "portrait" in trailer.json): tools/trailer/portrait.tscn draws a marketing-only
9:16 reconstruction of a menu (wardrobe, hat wheel, map papers) at 180x320 and saves its own frames;
the beat shows it 6x, edge to edge (no crop, no follow).

Usage (from the project root; the wrappers tools/trailer/make_trailer.ps1 / .sh add the quiet-window
arguments on Windows):
  python tools/trailer/trailer.py [--drafts A,B] [--force] [--only-takes] [--godot EXE] [--ffmpeg EXE]
      [--quiet --pos-take X,Y] [--music NAME|FILE|none] [--music-only]
Godot: --godot, else $GODOT, else the winget console binary / /Applications/Godot.app / `godot` on PATH.
ffmpeg: --ffmpeg, else $FFMPEG, else `ffmpeg` on PATH, else the winget Gyan.FFmpeg install.
Nothing here touches the player's save: every run is a res://tools/ scene with debug flags (a
throwaway, in-memory state), and the movie writer records audio without playing it.
"""
import argparse
import glob
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys

import goo_text

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, "tools", "trailer", "trailer.json")
OUT = os.path.join(ROOT, "build", "trailer")
FPS = 60
W, H = 1080, 1920
GAME = (320, 180)
PORTRAIT = (180, 320)  # portrait takes (portrait.tscn): 180x320, shown 6x
BG = "0x1a1c2c"  # UIKit.BG
GODOT_TIMEOUT = 180  # seconds per Godot run, plus 0.1 s per recorded frame
FFMPEG_TIMEOUT = 900


def file_sha1(*names):
    """sha1 of tools/trailer/<name> files: part of every cache stamp, so editing a script re-renders."""
    h = hashlib.sha1()
    for name in names:
        with open(os.path.join(ROOT, "tools", "trailer", name), "rb") as f:
            h.update(f.read())
    return h.hexdigest()


def goo_sha():
    """sha1 of everything goo_text renders with (part of the caption cache keys)."""
    h = hashlib.sha1()
    for path in goo_text.files_sha_input():
        with open(path, "rb") as f:
            h.update(f.read())
    return h.hexdigest()


def is_portrait(take):
    return take.get("scene") == "portrait"


def find_godot(explicit):
    for cand in (explicit, os.environ.get("GODOT")):
        if cand and os.path.isfile(cand):
            return cand
    local = os.environ.get("LOCALAPPDATA")
    if local:
        hits = sorted(glob.glob(os.path.join(local, "Microsoft", "WinGet", "Packages", "GodotEngine.GodotEngine*", "Godot_v4*_console.exe")), reverse=True)
        if hits:
            return hits[0]
    for cand in ("/Applications/Godot.app/Contents/MacOS/Godot", os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot")):
        if os.path.isfile(cand):
            return cand
    found = shutil.which("godot")
    if found:
        return found
    sys.exit("Godot 4.7.2 not found: pass --godot or set GODOT.")


def find_ffmpeg(explicit):
    for cand in (explicit, os.environ.get("FFMPEG")):
        if cand and os.path.isfile(cand):
            return cand
    found = shutil.which("ffmpeg")
    if found:
        return found
    local = os.environ.get("LOCALAPPDATA")
    if local:
        hits = sorted(glob.glob(os.path.join(local, "Microsoft", "WinGet", "Packages", "Gyan.FFmpeg*", "ffmpeg-*", "bin", "ffmpeg.exe")), reverse=True)
        if hits:
            return hits[0]
    sys.exit("ffmpeg not found: pass --ffmpeg, set FFMPEG or put it on PATH.")


class Runner:
    def __init__(self, args):
        self.args = args
        self.godot = None if args.music_only else find_godot(args.godot)
        self.ffmpeg = find_ffmpeg(args.ffmpeg)

    # ------------------------------------------------------------- godot

    def godot_run(self, scene, size, user_args, movie=None, frames=None, pos=None, what=""):
        """Runs Godot once; exits the script on a timeout or on any SCRIPT ERROR / ERROR in its log
        (so a broken take is never cached as good)."""
        cmd = [self.godot, "--path", ROOT]
        if movie:
            cmd += ["--write-movie", movie, "--fixed-fps", str(FPS)]
        cmd += ["--resolution", "%dx%d" % size]
        if frames:
            cmd += ["--quit-after", str(frames)]
        if pos:
            cmd += ["--position", pos]
        cmd += [scene, "--"]
        if self.args.quiet:
            cmd.append("--quiet-window")
        cmd += user_args
        override = os.path.join(ROOT, "override.cfg")
        if self.args.quiet:  # open without focus (tools/quiet_window.ps1); the game deletes it on start
            with open(override, "w", encoding="ascii") as f:
                f.write("[display]\n\nwindow/size/no_focus=true\n")
        try:
            # Movie runs go about as fast as real time; anything far beyond that is a hang.
            limit = GODOT_TIMEOUT + (frames or 0) / 10.0
            proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=limit)
        except subprocess.TimeoutExpired:
            sys.exit("godot timed out (%s)" % (what or scene))
        finally:
            if self.args.quiet and os.path.exists(override):
                os.remove(override)
        errors = [l for l in (proc.stdout + proc.stderr).splitlines() if ("SCRIPT ERROR" in l or "ERROR:" in l) and "still in use" not in l]
        if errors:
            sys.exit("godot reported errors (%s):\n     %s" % (what or scene, "\n     ".join(errors[:8])))
        return proc

    def render_take(self, take_id, take, base_args):
        out_dir = os.path.join(OUT, "takes", take_id)
        user_args = list(base_args) + ["--take=" + take["take"]] + list(take.get("args", []))             + ["--track=" + os.path.join(out_dir, "track.txt").replace("\\", "/")]
        frames = int(take["frames"])
        portrait = is_portrait(take)
        if portrait:  # (draws into its own 180x320 view and saves those frames: p%08d.png)
            user_args = list(base_args) + ["--view=" + take["take"]] + list(take.get("args", [])) \
                + ["--frames-dir=" + out_dir.replace("\\", "/")]
        script = "portrait.gd" if portrait else "take.gd"
        stamp = hashlib.sha1(json.dumps([user_args, frames, take, file_sha1(script)], sort_keys=True).encode()).hexdigest()
        stamp_file = os.path.join(out_dir, "stamp.txt")
        if not self.args.force and os.path.exists(stamp_file) and open(stamp_file).read() == stamp \
                and os.path.exists(os.path.join(out_dir, "f.wav")):
            return out_dir
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)
        print(" take %-14s %4d frames  %s" % (take_id, frames, " ".join(user_args)))
        scene = "res://tools/trailer/%s.tscn" % ("portrait" if portrait else "take")
        self.godot_run(scene, GAME, user_args, os.path.join(out_dir, "f.png"), frames, self.args.pos_take, "take " + take_id)
        if not os.path.exists(os.path.join(out_dir, "f.wav")):
            sys.exit("take %s wrote no movie" % take_id)
        if portrait:  # (the movie writer's own 320x180 frames: only its audio is used)
            for name in os.listdir(out_dir):
                if name.startswith("f") and name.endswith(".png"):
                    os.remove(os.path.join(out_dir, name))
            if not os.path.exists(os.path.join(out_dir, "p%08d.png" % (frames - 2))):
                sys.exit("take %s saved too few portrait frames" % take_id)
        with open(stamp_file, "w") as f:
            f.write(stamp)
        return out_dir

    def render_card(self, draft_id, end, base_args):
        out_dir = os.path.join(OUT, "takes", "card_" + draft_id)
        # (the tagline / CTA / store words are goo_text overlays, added in build_draft)
        user_args = list(base_args) + ["--card", "--skin=" + end.get("skin", "lime"),
                                       "--logo=%d" % end.get("logo", 0)] + list(end.get("args", []))
        frames_dir = ["--frames-dir=" + out_dir.replace("\\", "/")]
        frames = int(round(end.get("dur", 4.0) * FPS)) + 2
        look = {k: v for k, v in end.items() if k not in ("tagline", "cta", "store")}
        stamp = hashlib.sha1(json.dumps([user_args, frames, look, file_sha1("card.gd")], sort_keys=True).encode()).hexdigest()
        stamp_file = os.path.join(out_dir, "stamp.txt")
        if not self.args.force and os.path.exists(stamp_file) and open(stamp_file).read() == stamp:
            return out_dir
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)
        print(" card %s" % draft_id)
        self.godot_run("res://tools/trailer/card.tscn", GAME, user_args + frames_dir, os.path.join(out_dir, "f.png"), frames, self.args.pos_take, "card " + draft_id)
        for name in os.listdir(out_dir):  # (the movie writer's own 320x180 frames: only its audio is used)
            if name.startswith("f") and name.endswith(".png"):
                os.remove(os.path.join(out_dir, name))
        with open(stamp_file, "w") as f:
            f.write(stamp)
        return out_dir

    # ------------------------------------------------------------- ffmpeg

    def ff(self, cmd, cwd=None):
        try:
            proc = subprocess.run([self.ffmpeg, "-hide_banner", "-loglevel", "error", "-y"] + cmd, capture_output=True, text=True,
                                  timeout=FFMPEG_TIMEOUT, cwd=cwd)
        except subprocess.TimeoutExpired:
            sys.exit("ffmpeg timed out: %s" % " ".join(cmd[-3:]))
        if proc.returncode != 0:
            sys.exit("ffmpeg failed: %s\n%s" % (" ".join(cmd[-3:]), proc.stderr[-2000:]))
        return proc


CARD_TEXT_TOP = 404  # the end card's words start here on the 540x960 goo canvas (808 px: under card.gd's stage)
ZOOM = 11  # 180 x 11 = 1980 >= 1920: the game fills the frame's height, in whole game pixels
FOLLOW = 0.06  # how quickly the crop catches up with the action (per frame, smoothed both ways)


def load_track(take_dir):
    """The take's focus point per frame (take.gd --track): [(x, y)], in 320x180 game pixels."""
    pts = []
    with open(os.path.join(take_dir, "track.txt")) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 3:
                pts.append((float(parts[1]), float(parts[2])))
    return pts or [(GAME[0] / 2, GAME[1] / 2)]


def smooth(values, alpha):
    """Zero-phase exponential smoothing (forward, then backward): an eased pan with no lag or jitter."""
    out, acc = [], values[0]
    for v in values:
        acc += (v - acc) * alpha
        out.append(acc)
    acc = out[-1]
    for i in range(len(out) - 1, -1, -1):
        acc += (out[i] - acc) * alpha
        out[i] = acc
    return out


def crop_path(take_dir, beat, start, frames):
    """Per frame of the beat: (game x of the crop's left edge, screen y of the crop's top), both
    whole game pixels. The crop is `cw` game pixels wide (a bit over 1080 / zoom) and the full height."""
    zoom = int(beat.get("zoom", ZOOM))
    cw = -(-W // zoom) + 1
    if "focus" in beat:
        pts = [tuple(beat["focus"])] * (start + frames)
    else:
        pts = load_track(take_dir)
        pts += [pts[-1]] * max(0, start + frames - len(pts))
    alpha = float(beat.get("follow", FOLLOW))
    xs = smooth([p[0] for p in pts], alpha)
    ys = smooth([p[1] for p in pts], alpha)
    max_y = GAME[1] * zoom - H
    path = []
    for n in range(start, start + frames):
        xi = min(max(int(round(xs[n] - cw / 2)), 0), GAME[0] - cw)
        yi = int(round(ys[n] - H / 2 / zoom))
        path.append((xi, min(max(yi * zoom, 0), max_y)))
    return path, cw, zoom


def caption_job(draft, beat, index):
    job = {
        "lines": beat.get("caption", []),
        "sub": beat.get("sub", []),
        "color": beat.get("color", "white"),
        "sub_color": beat.get("sub_color", "white"),
        "at": beat.get("at", "top"),
        "skin": beat.get("skin", ""),
    }
    key = hashlib.sha1(json.dumps([job, goo_sha()], sort_keys=True).encode()).hexdigest()[:12]
    job["out"] = os.path.join(OUT, "captions", "cap_%s.png" % key)
    return job


def build_draft(run, cfg, draft):
    did = draft["id"]
    work = os.path.join(OUT, "work", did)
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    segments, sheet_frames, t = [], [], 0.0
    for i, beat in enumerate(draft["beats"]):
        take_dir = os.path.join(OUT, "takes", beat["take"])
        start = int(round(beat["in"] * FPS))
        frames = int(round(beat["dur"] * FPS))
        cap = beat["_caption"]
        seg = os.path.join(work, "seg_%02d.mkv" % i)
        caps = "[1:v]scale=%d:%d:flags=neighbor,format=rgba[c];[g][c]overlay=0:0:shortest=1,format=yuv420p[v]" % (W, H)
        frames_in = os.path.join(take_dir, "f%08d.png")
        if is_portrait(cfg["takes"][beat["take"]]):
            # A portrait take (180x320) fills the frame at 6x: no crop, no follow.
            frames_in = os.path.join(take_dir, "p%08d.png")
            vf = "[0:v]scale=%d:%d:flags=neighbor[g];" % (W, H) + caps
        else:
            # Full screen: crop a strip of the game (following the action), scale it up `zoom`x with
            # nearest neighbour and cut the 1080x1920 frame out of it; the crop moves in whole game
            # pixels, driven per frame by sendcmd.
            path, cw, zoom = crop_path(take_dir, beat, start, frames)
            cmds = "cmd_%02d.txt" % i
            with open(os.path.join(work, cmds), "w") as f:
                last = None
                for k, (xi, ys) in enumerate(path):
                    if (xi, ys) != last:
                        f.write("%.4f crop@a x %d, crop@b y %d;\n" % (max(k / FPS - 0.002, 0.0), xi, ys))
                        last = (xi, ys)
            vf = ("[0:v]sendcmd=f=%s,crop@a=w=%d:h=%d:x=%d:y=0,scale=%d:%d:flags=neighbor,crop@b=w=%d:h=%d:x=%d:y=%d[g];"
                  % (cmds, cw, GAME[1], path[0][0], cw * zoom, GAME[1] * zoom, W, H, (cw * zoom - W) // 2, path[0][1])) + caps
        fade = min(0.04, beat["dur"] / 4)
        af = "atrim=start=%.4f:duration=%.4f,asetpts=PTS-STARTPTS,afade=t=in:d=%.3f,afade=t=out:st=%.4f:d=%.3f,aresample=48000" % (
            beat["in"], beat["dur"], fade, beat["dur"] - fade, fade)
        if "gain" in beat:
            af += ",volume=%sdB" % beat["gain"]
        run.ff(["-framerate", str(FPS), "-start_number", str(start), "-i", frames_in,
                "-loop", "1", "-framerate", str(FPS), "-i", cap,
                "-i", os.path.join(take_dir, "f.wav"),
                "-filter_complex", vf + ";[2:a]" + af + "[a]", "-map", "[v]", "-map", "[a]",
                "-frames:v", str(frames), "-r", str(FPS),
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "10", "-c:a", "pcm_s16le", "-ac", "2", seg], cwd=work)
        segments.append(seg)
        sheet_frames.append(t + beat["dur"] * float(beat.get("sheet_at", 0.6)))
        t += beat["dur"]
    # End card: 360x640, 3x, its words in goo lettering over it (goo_text, 540x960, 2x).
    end = draft["end"]
    card_dir = os.path.join(OUT, "takes", "card_" + did)
    seg = os.path.join(work, "seg_end.mkv")
    dur = end.get("dur", 4.0)
    words = os.path.join(work, "card_text.png")
    goo_text.card_text_png(words, end.get("tagline", []), end.get("cta", []), end.get("store", []), end.get("skin", "lime"), CARD_TEXT_TOP)
    run.ff(["-framerate", str(FPS), "-i", os.path.join(card_dir, "c%08d.png"), "-i", os.path.join(card_dir, "f.wav"),
            "-loop", "1", "-framerate", str(FPS), "-i", words,
            "-filter_complex", "[0:v]scale=%d:%d:flags=neighbor[g];[2:v]scale=%d:%d:flags=neighbor,format=rgba[t];"
            "[g][t]overlay=0:0:shortest=1,format=yuv420p[v];[1:a]atrim=duration=%.3f,afade=t=out:st=%.3f:d=0.5,aresample=48000[a]" % (W, H, W, H, dur, dur - 0.5),
            "-map", "[v]", "-map", "[a]", "-frames:v", str(int(round(dur * FPS))), "-r", str(FPS),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "10", "-c:a", "pcm_s16le", "-ac", "2", seg])
    segments.append(seg)
    sheet_frames.append(t + dur * 0.7)
    t += dur
    listing = os.path.join(work, "list.txt")
    with open(listing, "w") as f:
        for s in segments:
            f.write("file '%s'\n" % s.replace("\\", "/").replace("'", "'\\''"))  # (concat quoting: ' -> '\'')
    final = os.path.join(OUT, "short_%s.mp4" % did)
    run.ff(["-f", "concat", "-safe", "0", "-i", listing,
            "-af", loudnorm(run, ["-f", "concat", "-safe", "0", "-i", listing]) + ",aresample=48000",
            "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
            "-profile:v", "high", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", final])
    # Contact sheet: one frame per beat (and the end card), 270x480 each, in rows of 6.
    for n, ts in enumerate(sheet_frames):
        run.ff(["-ss", "%.3f" % ts, "-i", final, "-frames:v", "1", "-vf", "scale=270:480:flags=neighbor", os.path.join(work, "sheet_%02d.png" % n)])
    cols = min(6, len(sheet_frames))
    rows = (len(sheet_frames) + cols - 1) // cols
    run.ff(["-framerate", "1", "-i", os.path.join(work, "sheet_%02d.png"), "-vf",
            "tile=%dx%d:padding=6:margin=6:color=0x404040" % (cols, rows), "-frames:v", "1",
            os.path.join(OUT, "short_%s_sheet.png" % did)])
    print(" wrote %s (%.1f s)" % (os.path.relpath(final, ROOT), t))
    if music_of(run, draft):
        build_music_version(run, draft, ["-f", "concat", "-safe", "0", "-i", listing], final, work)
    return t


LOUDNESS = "I=-14:TP=-1.5:LRA=11"  # the usual target for Shorts / TikTok / Reels


def measure_loudness(run, inputs):
    """ffmpeg's loudnorm analysis of `inputs` (ffmpeg input args): the parsed JSON, or None."""
    try:
        proc = subprocess.run([run.ffmpeg, "-hide_banner"] + inputs + ["-vn", "-af", "loudnorm=%s:print_format=json" % LOUDNESS,
                                                                        "-f", "null", "-"],
                              capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=FFMPEG_TIMEOUT)
    except subprocess.TimeoutExpired:
        sys.exit("ffmpeg timed out measuring loudness: %s" % " ".join(inputs[-1:]))
    text = proc.stderr
    try:
        return json.loads(text[text.rindex("{"):text.rindex("}") + 1])
    except ValueError:
        return None


def lufs(measured):
    """The integrated loudness of a measure_loudness() result, or None if missing or not finite (silence = -inf)."""
    try:
        value = float(measured["input_i"])
    except (TypeError, KeyError, ValueError):
        return None
    return value if math.isfinite(value) else None


def loudnorm(run, inputs):
    """Two-pass loudness normalisation: measure the joined draft, then apply it linearly."""
    m = measure_loudness(run, inputs)
    try:
        return ("loudnorm=%s:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true"
                % (LOUDNESS, m["input_i"], m["input_tp"], m["input_lra"], m["input_thresh"], m["target_offset"]))
    except (TypeError, KeyError):
        return "loudnorm=" + LOUDNESS


# ------------------------------------------------------------- music

MUSIC_TRACKS = ("trailer_1", "trailer_2")  # tools/make_music.py trailer tracks (fitted per draft)
GAME_LUFS = -17.0   # the game's own audio in the music cut: ducked a bit from its solo level
MUSIC_LUFS = -18.0  # the music bed under it (a draft's "music_db" moves it); the sum is then normalised to -14


def music_of(run, draft):
    """The draft's music as {"track", "hit", "db"}, or None. --music overrides trailer.json's "music"."""
    spec = run.args.music if run.args.music else draft.get("music")
    if not spec or spec == "none":
        return None
    if isinstance(spec, str):
        spec = {"track": spec}
    return {"track": spec["track"], "hit": spec.get("hit"), "db": float(spec.get("db", draft.get("music_db", 0.0)))}


def draft_times(draft):
    card = sum(b["dur"] for b in draft["beats"])
    return card, card + draft["end"].get("dur", 4.0)


def fitted_music(run, track, hit, length):
    """A make_music.py trailer track whose hit lands at `hit` s, cached under build/trailer/music/."""
    script = os.path.join(ROOT, "tools", "make_music.py")
    with open(script, "rb") as f:
        stamp = hashlib.sha1(f.read() + ("%s %.3f %.3f" % (track, hit, length)).encode()).hexdigest()[:12]
    out = os.path.join(OUT, "music", "%s_%s.wav" % (track, stamp))
    if not os.path.exists(out):
        os.makedirs(os.path.dirname(out), exist_ok=True)
        print(" music %s: hit at %.2f s, %.2f s long" % (track, hit, length))
        try:
            proc = subprocess.run([sys.executable, script, "--fit", track, "--hit", "%.3f" % hit, "--length", "%.3f" % length,
                                   "--out", out, "--ffmpeg", run.ffmpeg], capture_output=True, text=True, timeout=FFMPEG_TIMEOUT)
        except subprocess.TimeoutExpired:
            sys.exit("make_music.py timed out (%s)" % track)
        if proc.returncode != 0 or not os.path.exists(out):
            sys.exit("make_music.py failed:\n%s" % (proc.stdout + proc.stderr)[-2000:])
    return out


def build_music_version(run, draft, game_inputs, video, work):
    """short_<ID>_music.mp4: the plain cut's picture, the game's audio ducked a bit with the music under it,
    the music's hit on the end card, the sum loudness-normalised to -14 LUFS."""
    did = draft["id"]
    music = music_of(run, draft)
    card, total = draft_times(draft)
    os.makedirs(work, exist_ok=True)
    game = os.path.join(work, "game.wav")
    run.ff(game_inputs + ["-vn", "-ac", "2", "-ar", "48000", "-c:a", "pcm_f32le", game])
    track = music["track"]
    if track in MUSIC_TRACKS:
        src, offset = fitted_music(run, track, card, total), 0.0
    else:
        src = track if os.path.isabs(track) else os.path.join(ROOT, track)
        if not os.path.exists(src):
            sys.exit("draft %s: music file not found: %s" % (did, src))
        offset = card - float(music["hit"]) if music["hit"] is not None else 0.0
    gi = measure_loudness(run, ["-i", game])
    mi = measure_loudness(run, ["-i", src])
    g_i, m_i = lufs(gi), lufs(mi)  # (None: silent or unmeasured -> a fixed gain)
    g_db = GAME_LUFS - g_i if g_i is not None else -3.0
    m_db = MUSIC_LUFS + music["db"] - m_i if m_i is not None else 0.0
    shift = ("adelay=%d:all=1," % int(round(offset * 1000))) if offset > 0 else \
            ("atrim=start=%.4f,asetpts=PTS-STARTPTS," % -offset) if offset < 0 else ""
    mix = os.path.join(work, "mix.wav")
    run.ff(["-i", game, "-i", src, "-filter_complex",
            "[0:a]volume=%.2fdB[g];[1:a]aresample=48000,aformat=channel_layouts=stereo,%svolume=%.2fdB,apad,atrim=0:%.3f,"
            "afade=t=out:st=%.3f:d=0.5[m];[g][m]amix=inputs=2:normalize=0:duration=first[a]"
            % (g_db, shift, m_db, total, total - 0.5),
            "-map", "[a]", "-c:a", "pcm_f32le", mix])
    final = os.path.join(OUT, "short_%s_music.mp4" % did)
    run.ff(["-i", video, "-i", mix, "-map", "0:v", "-map", "1:a", "-c:v", "copy",
            "-af", loudnorm(run, ["-i", mix]) + ",aresample=48000", "-c:a", "aac", "-b:a", "192k",
            "-shortest", "-movflags", "+faststart", final])
    print(" wrote %s (music: %s, hit at %.2f s)" % (os.path.relpath(final, ROOT), os.path.basename(track), card))


def write_readme(run, cfg, lengths):
    """README.md for every draft that has a short_<ID>.mp4 (this run's lengths, else from trailer.json)."""
    drafts = []
    for d in cfg["drafts"]:
        if d["id"] not in lengths and not os.path.exists(os.path.join(OUT, "short_%s.mp4" % d["id"])):
            continue
        if "_music" not in d:  # (not in this run: its own trailer.json music, not --music)
            spec = d.get("music") or ""
            track = spec if isinstance(spec, str) else spec.get("track", "")
            d["_music"] = "" if track == "none" else track
        drafts.append(d)
    lines = ["# Trailer drafts (generated by tools/trailer/trailer.py; see docs/marketing/trailer.md)", "",
             "Vertical 1080x1920, 60 fps, H.264 + AAC. Audio = the game's own sound effects and level ambience",
             "(the game has no music), loudness-normalised to -14 LUFS. short_<ID>_music.mp4 = the same cut with a",
             "music mockup under it (tools/make_music.py; docs/marketing/music.md).", ""]
    for d in drafts:
        lines += ["## short_%s.mp4: %s (%.1f s)" % (d["id"], d["name"], lengths.get(d["id"], draft_times(d)[1])), "", "Hook: " + d.get("hook", ""), "",
                  "| # | time | shot | caption |", "|---|---|---|---|"]
        t = 0.0
        for i, b in enumerate(d["beats"]):
            text = " / ".join(b.get("caption", []) + b.get("sub", []))
            lines.append("| %d | %.1f-%.1f | %s | %s |" % (i + 1, t, t + b["dur"], b.get("note", cfg["takes"][b["take"]].get("note", b["take"])), text))
            t += b["dur"]
        e = d["end"]
        lines.append("| end | %.1f-%.1f | end card (logo, %s slime) | %s |" % (t, t + e.get("dur", 4.0), e.get("skin", ""),
                     " / ".join(e.get("tagline", []) + e.get("cta", []) + e.get("store", []))))
        lines += ["", "Contact sheet: short_%s_sheet.png" % d["id"], ""]
        if d.get("_music"):
            lines += ["Music cut: short_%s_music.mp4 (%s, its hit on the end card at %.1f s)" % (d["id"], d["_music"], t), ""]
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--drafts", default="", help="comma list of draft ids (default: all)")
    p.add_argument("--force", action="store_true", help="re-render takes, cards and captions")
    p.add_argument("--only-takes", action="store_true", help="render the takes and stop")
    p.add_argument("--godot")
    p.add_argument("--ffmpeg")
    p.add_argument("--quiet", action="store_true", help="open Godot's windows without focus (override.cfg no_focus)")
    p.add_argument("--pos-take", help="X,Y window position for Godot's (320x180) windows")
    p.add_argument("--music", help="music for every selected draft: a make_music.py track (trailer_1, trailer_2), "
                                   "a WAV/OGG/MP3 path, or none (default: each draft's \"music\" in trailer.json)")
    p.add_argument("--music-only", action="store_true",
                   help="only (re)make short_<ID>_music.mp4 from the existing short_<ID>.mp4 (no Godot, no re-cut)")
    args = p.parse_args()
    with open(CONFIG, encoding="utf-8") as f:
        cfg = json.load(f)
    run = Runner(args)
    wanted = [d.strip() for d in args.drafts.split(",") if d.strip()]
    drafts = [d for d in cfg["drafts"] if not wanted or d["id"] in wanted]
    if not drafts:
        sys.exit("no such draft: %s" % args.drafts)
    for d in drafts:
        m = music_of(run, d)
        d["_music"] = m["track"] if m else ""
    if args.music_only:
        for d in drafts:
            video = os.path.join(OUT, "short_%s.mp4" % d["id"])
            if not os.path.exists(video):
                sys.exit("--music-only: %s is missing; render the draft first" % os.path.relpath(video, ROOT))
            if not d["_music"]:
                print(" draft %s has no music (trailer.json \"music\" or --music)" % d["id"])
                continue
            work = os.path.join(OUT, "work", d["id"])
            shutil.rmtree(work, ignore_errors=True)
            build_music_version(run, d, ["-i", video], video, work)
        write_readme(run, cfg, {})
        shutil.rmtree(os.path.join(OUT, "work"), ignore_errors=True)
        return
    os.makedirs(os.path.join(OUT, "captions"), exist_ok=True)
    base = cfg.get("base_args", [])
    needed = []
    for d in drafts:
        for b in d["beats"]:
            if b["take"] not in cfg["takes"]:
                sys.exit("draft %s: unknown take %s" % (d["id"], b["take"]))
            if b["take"] not in needed:
                needed.append(b["take"])
    print("takes:")
    for take_id in needed:
        take = cfg["takes"][take_id]
        longest = max(b["in"] + b["dur"] for d in drafts for b in d["beats"] if b["take"] == take_id)
        if longest * FPS > int(take["frames"]):
            sys.exit("take %s is %d frames; a beat needs %d" % (take_id, take["frames"], longest * FPS))
        run.render_take(take_id, take, base)
    if args.only_takes:
        return
    jobs = []
    for d in drafts:
        for i, b in enumerate(d["beats"]):
            job = caption_job(d, b, i)
            b["_caption"] = job["out"]
            if job["out"] not in [j["out"] for j in jobs]:
                jobs.append(job)
    todo = [j for j in jobs if args.force or not os.path.exists(j["out"])]
    print("captions: %d" % len(todo))
    for j in todo:  # (the logo's goo lettering, goo_text.py; "skin" = the beat's skin colour)
        goo_text.caption_png(j["out"], j)
    print("cards:")
    for d in drafts:
        run.render_card(d["id"], d["end"], base)
    print("drafts:")
    lengths = {}
    for d in drafts:
        lengths[d["id"]] = build_draft(run, cfg, d)
    write_readme(run, cfg, lengths)
    shutil.rmtree(os.path.join(OUT, "work"), ignore_errors=True)


if __name__ == "__main__":
    main()
