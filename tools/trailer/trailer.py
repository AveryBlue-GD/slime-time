"""Renders the vertical trailer drafts (9:16 Shorts / TikTok / Reels) from the real game.

Everything a draft shows is defined in tools/trailer/trailer.json:
  takes   named moments of the real game, each one Godot movie-writer run of
          res://tools/trailer/take.tscn (see take.gd for the modes and flags) at 320x180, 60 fps,
          PNG frames + the game's own audio (WAV). Same flags = same pictures (seeded).
  drafts  a list of beats (a slice of a take, how it is framed, the caption over it) and an end
          card (res://tools/trailer/card.tscn, logo + tagline + CTA).
Steps: render the takes (skipped when their flags haven't changed; --force re-renders), render the
caption overlays and end cards in the game's font (card.tscn), cut and frame every beat with ffmpeg
(nearest-neighbour upscale, 1080x1920), join them, normalise the audio and write
build/trailer/short_<ID>.mp4 + short_<ID>_sheet.png (contact sheet: one frame per beat) +
build/trailer/README.md.

Usage (from the project root; the wrappers tools/trailer/make_trailer.ps1 / .sh add the quiet-window
arguments on Windows):
  python tools/trailer/trailer.py [--drafts A,B] [--force] [--only-takes] [--godot EXE] [--ffmpeg EXE]
      [--quiet --pos-take X,Y]
Godot: --godot, else $GODOT, else the winget console binary / /Applications/Godot.app / `godot` on PATH.
ffmpeg: --ffmpeg, else $FFMPEG, else `ffmpeg` on PATH, else the winget Gyan.FFmpeg install.
Nothing here touches the player's save: every run is a res://tools/ scene with debug flags (a
throwaway, in-memory state), and the movie writer records audio without playing it.
"""
import argparse
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, "tools", "trailer", "trailer.json")
OUT = os.path.join(ROOT, "build", "trailer")
FPS = 60
W, H = 1080, 1920
CANVAS = 4  # caption overlays are drawn at 270x480 and scaled 4x
GAME = (320, 180)
BG = "0x1a1c2c"  # UIKit.BG
GODOT_TIMEOUT = 180  # seconds per Godot run, plus 0.1 s per recorded frame
CAPTION_FRAMES_MAX = 20000  # the captions run's --quit-after guard
FFMPEG_TIMEOUT = 900


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
        self.godot = find_godot(args.godot)
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
        user_args = list(base_args) + ["--take=" + take["take"]] + list(take.get("args", []))
        frames = int(take["frames"])
        stamp = hashlib.sha1(json.dumps([user_args, frames]).encode()).hexdigest()
        stamp_file = os.path.join(out_dir, "stamp.txt")
        if not self.args.force and os.path.exists(stamp_file) and open(stamp_file).read() == stamp \
                and os.path.exists(os.path.join(out_dir, "f.wav")):
            return out_dir
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)
        print(" take %-14s %4d frames  %s" % (take_id, frames, " ".join(user_args)))
        self.godot_run("res://tools/trailer/take.tscn", GAME, user_args, os.path.join(out_dir, "f.png"), frames, self.args.pos_take, "take " + take_id)
        if not os.path.exists(os.path.join(out_dir, "f.wav")):
            sys.exit("take %s wrote no movie" % take_id)
        with open(stamp_file, "w") as f:
            f.write(stamp)
        return out_dir

    def render_card(self, draft_id, end, base_args):
        out_dir = os.path.join(OUT, "takes", "card_" + draft_id)
        user_args = list(base_args) + ["--card", "--skin=" + end.get("skin", "lime"),
                                       "--tagline=" + "|".join(end.get("tagline", [])),
                                       "--cta=" + "|".join(end.get("cta", [])),
                                       "--store=" + "|".join(end.get("store", [])),
                                       "--logo=%d" % end.get("logo", 0)] + list(end.get("args", []))
        frames_dir = ["--frames-dir=" + out_dir.replace("\\", "/")]
        frames = int(round(end.get("dur", 4.0) * FPS)) + 2
        stamp = hashlib.sha1(json.dumps([user_args, frames]).encode()).hexdigest()
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

    def render_captions(self, jobs, base_args):
        todo = [j for j in jobs if self.args.force or not os.path.exists(j["out"])]
        if not todo:
            return
        path = os.path.join(OUT, "captions", "jobs.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(todo, f, indent=1)
        print(" captions: %d" % len(todo))
        # --quit-after is only a guard (card.gd quits by itself after the last caption).
        self.godot_run("res://tools/trailer/card.tscn", GAME, list(base_args) + ["--captions=" + path],
                       frames=CAPTION_FRAMES_MAX, pos=self.args.pos_take, what="captions")
        missing = [j["out"] for j in todo if not os.path.exists(j["out"])]
        if missing:
            sys.exit("captions not written: %s" % missing[:3])

    # ------------------------------------------------------------- ffmpeg

    def ff(self, cmd):
        try:
            proc = subprocess.run([self.ffmpeg, "-hide_banner", "-loglevel", "error", "-y"] + cmd, capture_output=True, text=True, timeout=FFMPEG_TIMEOUT)
        except subprocess.TimeoutExpired:
            sys.exit("ffmpeg timed out: %s" % " ".join(cmd[-3:]))
        if proc.returncode != 0:
            sys.exit("ffmpeg failed: %s\n%s" % (" ".join(cmd[-3:]), proc.stderr[-2000:]))
        return proc


def frame_rect(beat):
    """The game picture's place on the 270x480 caption canvas: (x, y, w, h) in canvas pixels."""
    zoom = int(beat.get("zoom", 4))
    crop_w = min(GAME[0], W // zoom)
    w_px, h_px = crop_w * zoom, GAME[1] * zoom
    x = (W - w_px) // 2 // CANVAS
    y = int(round((H / 2 - h_px / 2) / CANVAS))
    return [x, y, w_px // CANVAS, h_px // CANVAS], crop_w, zoom


def caption_job(draft, beat, index):
    rect, _, _ = frame_rect(beat)
    job = {
        "frame": rect,
        "frame_color": beat.get("frame_color", beat.get("color", "white")),
        "lines": beat.get("caption", []),
        "sub": beat.get("sub", []),
        "color": beat.get("color", "white"),
        "sub_color": beat.get("sub_color", "white"),
        "at": beat.get("at", "top"),
        "skin": beat.get("skin", ""),
    }
    key = hashlib.sha1(json.dumps(job, sort_keys=True).encode()).hexdigest()[:12]
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
        rect, crop_w, zoom = frame_rect(beat)
        crop_x = int(beat.get("x", (GAME[0] - crop_w) // 2))
        start = int(round(beat["in"] * FPS))
        frames = int(round(beat["dur"] * FPS))
        cap = beat["_caption"]
        seg = os.path.join(work, "seg_%02d.mkv" % i)
        gx, gy = rect[0] * CANVAS, rect[1] * CANVAS
        vf = ("[0:v]crop=%d:%d:%d:0,scale=%d:%d:flags=neighbor[g];"
              "color=c=%s:s=%dx%d:r=%d[bg];[bg][g]overlay=%d:%d:shortest=1[b];"
              "[1:v]scale=%d:%d:flags=neighbor,format=rgba[c];[b][c]overlay=0:0:shortest=1,format=yuv420p[v]"
              % (crop_w, GAME[1], crop_x, crop_w * zoom, GAME[1] * zoom, BG, W, H, FPS, gx, gy, W, H))
        fade = min(0.04, beat["dur"] / 4)
        af = "atrim=start=%.4f:duration=%.4f,asetpts=PTS-STARTPTS,afade=t=in:d=%.3f,afade=t=out:st=%.4f:d=%.3f,aresample=48000" % (
            beat["in"], beat["dur"], fade, beat["dur"] - fade, fade)
        if "gain" in beat:
            af += ",volume=%sdB" % beat["gain"]
        run.ff(["-framerate", str(FPS), "-start_number", str(start), "-i", os.path.join(take_dir, "f%08d.png"),
                "-loop", "1", "-framerate", str(FPS), "-i", cap,
                "-i", os.path.join(take_dir, "f.wav"),
                "-filter_complex", vf + ";[2:a]" + af + "[a]", "-map", "[v]", "-map", "[a]",
                "-frames:v", str(frames), "-r", str(FPS),
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "10", "-c:a", "pcm_s16le", "-ac", "2", seg])
        segments.append(seg)
        sheet_frames.append(t + beat["dur"] * float(beat.get("sheet_at", 0.6)))
        t += beat["dur"]
    # End card: 360x640, 3x.
    end = draft["end"]
    card_dir = os.path.join(OUT, "takes", "card_" + did)
    seg = os.path.join(work, "seg_end.mkv")
    dur = end.get("dur", 4.0)
    run.ff(["-framerate", str(FPS), "-i", os.path.join(card_dir, "c%08d.png"), "-i", os.path.join(card_dir, "f.wav"),
            "-filter_complex", "[0:v]scale=%d:%d:flags=neighbor,format=yuv420p[v];[1:a]atrim=duration=%.3f,afade=t=out:st=%.3f:d=0.5,aresample=48000[a]" % (W, H, dur, dur - 0.5),
            "-map", "[v]", "-map", "[a]", "-frames:v", str(int(round(dur * FPS))), "-r", str(FPS),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "10", "-c:a", "pcm_s16le", "-ac", "2", seg])
    segments.append(seg)
    sheet_frames.append(t + dur * 0.7)
    t += dur
    listing = os.path.join(work, "list.txt")
    with open(listing, "w") as f:
        for s in segments:
            f.write("file '%s'\n" % s.replace("\\", "/"))
    final = os.path.join(OUT, "short_%s.mp4" % did)
    run.ff(["-f", "concat", "-safe", "0", "-i", listing,
            "-af", loudnorm(run, listing) + ",aresample=48000",
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
    return t


LOUDNESS = "I=-14:TP=-1.5:LRA=11"  # the usual target for Shorts / TikTok / Reels


def loudnorm(run, listing):
    """Two-pass loudness normalisation: measure the joined draft, then apply it linearly."""
    proc = subprocess.run([run.ffmpeg, "-hide_banner", "-f", "concat", "-safe", "0", "-i", listing, "-vn",
                           "-af", "loudnorm=%s:print_format=json" % LOUDNESS, "-f", "null", "-"],
                          capture_output=True, text=True, timeout=FFMPEG_TIMEOUT)
    text = proc.stderr
    try:
        m = json.loads(text[text.rindex("{"):text.rindex("}") + 1])
        return ("loudnorm=%s:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true"
                % (LOUDNESS, m["input_i"], m["input_tp"], m["input_lra"], m["input_thresh"], m["target_offset"]))
    except (ValueError, KeyError):
        return "loudnorm=" + LOUDNESS


def write_readme(cfg, drafts, lengths):
    lines = ["# Trailer drafts (generated by tools/trailer/trailer.py; see docs/marketing/trailer.md)", "",
             "Vertical 1080x1920, 60 fps, H.264 + AAC. Audio = the game's own sound effects and level ambience",
             "(the game has no music), loudness-normalised to -14 LUFS.", ""]
    for d in drafts:
        lines += ["## short_%s.mp4: %s (%.1f s)" % (d["id"], d["name"], lengths[d["id"]]), "", "Hook: " + d.get("hook", ""), "",
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
    args = p.parse_args()
    with open(CONFIG, encoding="utf-8") as f:
        cfg = json.load(f)
    run = Runner(args)
    wanted = [d.strip() for d in args.drafts.split(",") if d.strip()]
    drafts = [d for d in cfg["drafts"] if not wanted or d["id"] in wanted]
    if not drafts:
        sys.exit("no such draft: %s" % args.drafts)
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
    # A caption colored "skin" takes the beat's skin (card.gd colors it from --skin).
    by_skin = {}
    for j in jobs:
        by_skin.setdefault(j.pop("skin") or "lime", []).append(j)
    for skin, js in by_skin.items():
        run.render_captions(js, base + ["--skin=" + skin])
    print("cards:")
    for d in drafts:
        run.render_card(d["id"], d["end"], base)
    print("drafts:")
    lengths = {}
    for d in drafts:
        lengths[d["id"]] = build_draft(run, cfg, d)
    write_readme(cfg, drafts, lengths)
    shutil.rmtree(os.path.join(OUT, "work"), ignore_errors=True)


if __name__ == "__main__":
    main()
