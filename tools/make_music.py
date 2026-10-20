"""Procedural music MOCKUPS for Dry Trying: hub loops and trailer tracks (no dependencies).

Nothing here is wired into the game: the files go to build/music/ (git-ignored) for listening and for
the trailer drafts (tools/trailer/trailer.py). See docs/marketing/music.md.

Run from the project root:
  python tools/make_music.py                     # every piece -> build/music/ (+ .ogg, seams/, README.md)
  python tools/make_music.py hub_A trailer_1     # only these
  python tools/make_music.py --fit trailer_1 --hit 24.4 --length 27.8 --out x.wav
      # one trailer track fitted to a video: the tempo is nudged so the final hit lands exactly at --hit
      # seconds and the ring-out lasts until --length (what tools/trailer/trailer.py calls)
ffmpeg (loudness measurement, OGG copies): --ffmpeg, else $FFMPEG, else PATH, else the winget Gyan.FFmpeg install.

Everything is synthesized here, like tools/make_sounds.py (no samples, nothing third-party, so no licensing
questions), from the game's own sound palette:
- goo drops: a marimba-like pluck (sine + a fast-dying 4x partial) that starts a little sharp and sags onto
  its pitch, like a drop of goo landing;
- a round sub bass with a gloopy pitch bend on each note ("boing" notes bend up into pitch);
- a warm, muffled goo voice for the melodies (scoops up into each note, slow vibrato);
- muffled pads (a soft saw through a two-pole low-pass, two detuned voices panned apart);
- bubbles that land on chord tones (the bubbly arpeggios);
- percussion made of a deep bloop kick, wet squelch snares and little bubble pops;
- fog (band-passed noise), a bubbling riser and a splat-and-boom stinger for the trailers.
Pitches stay low (melodies top out around C5, 523 Hz) and everything goes through a dark reverb.

Hub loops are seamless: every note's tail and the reverb tail that run past the loop end are folded back
onto the start (the same as hearing the loop play forever), so the end flows into the start. Each loop's
seam is checked numerically and written out as seams/<name>_seam.wav (the last 3 s then the first 3 s).
Loudness: hub loops -18 LUFS integrated, trailer tracks -14 LUFS, true peaks below -1 dBTP (measured with
ffmpeg's loudnorm, gain applied here, a look-ahead limiter only when a peak would pass the ceiling).
Output: 44.1 kHz, 16-bit stereo WAV (TPDF dither). Fixed seeds: reruns give the same files.
"""
import argparse
import glob
import json
import math
import os
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from array import array
from collections import deque
from functools import lru_cache
from itertools import repeat
from operator import add, mul
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "music"
SR = 44100
TAU = 2.0 * math.pi
TAIL = 6.0            # seconds rendered past the end for note and reverb tails
HUB_LUFS = -18.0
TRAILER_LUFS = -14.0
TP_MAX = -1.2         # dBTP we aim under (the spec is "below -1")
TABLE_N = 4096
MASK = TABLE_N - 1


def hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def zeros(n: int, code: str = "f") -> array:
    return array(code, bytes((4 if code == "f" else 8) * n))


def _table(amps) -> list:
    vals = [sum(a * math.sin(TAU * (k + 1) * i / TABLE_N) for k, a in enumerate(amps)) for i in range(TABLE_N)]
    peak = max(abs(v) for v in vals)
    return [v / peak for v in vals]


TABLES = {
    "warm": _table([1.0, 0.42, 0.2, 0.09, 0.04, 0.015]),                          # goo voice
    "soft": _table([1.0 / k * math.exp(-(k - 1) / 3.0) for k in range(1, 11)]),   # pad: a muffled saw
    "hollow": _table([1.0, 0.0, 0.33, 0.0, 0.12, 0.0, 0.05]),                     # pad: a soft square
}


# ---------------------------------------------------------------- instruments (mono clips, cached)

@lru_cache(maxsize=None)
def pluck(m: float, tau: float = 0.0, bright: float = 1.0) -> array:
    """A goo drop: a marimba-like pluck that lands a little sharp and sags onto its pitch."""
    f = hz(m)
    if not tau:
        tau = min(0.9, max(0.2, 0.55 * math.sqrt(196.0 / f)))
    n = int((tau * 4.0 + 0.01) * SR)
    out = zeros(n)
    d1 = math.exp(-1.0 / (tau * SR))
    d2 = math.exp(-1.0 / (tau * 0.2 * SR))
    db = math.exp(-1.0 / (0.02 * SR))
    a1, a2 = 1.0, 0.2 * bright * min(1.0, 1800.0 / (4.0 * f))
    bend, ph, inc, att = 0.045, 0.0, f / SR, 0.0025 * SR
    sin = math.sin
    for i in range(n):
        ph += inc * (1.0 + bend)
        bend *= db
        x = TAU * ph
        v = sin(x) * a1 * (1.0 + 0.12 * sin(x)) + a2 * sin(3.98 * x)
        out[i] = v * (i / att if i < att else 1.0)
        a1 *= d1
        a2 *= d2
    return out


@lru_cache(maxsize=None)
def lead(m: float, dur: float, cutoff: float = 1400.0, scoop: float = 0.06, droop: float = 0.0) -> array:
    """The goo voice: scoops up into the note, slow vibrato after a moment, muffled by a low-pass.
    `droop` sags the pitch (in semitones) over the last 40% of the note, like goo running off."""
    f = hz(m)
    tab = TABLES["warm"]
    rel = 0.16
    n = int((dur + rel) * SR)
    nd = int(dur * SR)
    out = zeros(n)
    lp = 1.0 - math.exp(-TAU * cutoff / SR)
    ds = math.exp(-1.0 / (0.03 * SR))
    dd = math.exp(-1.0 / (0.3 * SR))
    sin = math.sin
    y1 = y2 = ph = 0.0
    sc, env, sus = scoop, 0.0, 0.72
    att = 0.02 * SR
    droop_from = int(nd * 0.6)
    for i in range(n):
        t = i / SR
        vib = 1.0 + 0.0055 * sin(TAU * 5.2 * t) * min(1.0, max(0.0, (t - 0.22) / 0.3))
        bend = 1.0 - sc
        sc *= ds
        if droop and i > droop_from:
            bend *= 2.0 ** (-droop / 12.0 * min(1.0, (i - droop_from) / max(1, n - droop_from)))
        ph += f * bend * vib / SR * TABLE_N
        if i < att:
            env = i / att
        elif i < nd:
            env = sus + (env - sus) * dd
        else:
            env = max(0.0, env - sus / (rel * SR))
        y1 += lp * (tab[int(ph) & MASK] * env - y1)
        y2 += lp * (y1 - y2)
        out[i] = y2
    return out


@lru_cache(maxsize=None)
def pad_voice(m: float, dur: float, cents: float, cutoff: float = 900.0, attack: float = 0.6,
              release: float = 1.4, table: str = "soft") -> array:
    """One detuned voice of a muffled pad (two-pole low-pass)."""
    f = hz(m) * 2.0 ** (cents / 1200.0)
    tab = TABLES[table]
    n = int((dur + release) * SR)
    nd = int(dur * SR)
    na = max(1, int(min(attack, dur * 0.5) * SR))
    nr = max(1, n - nd)
    out = zeros(n)
    inc = f / SR * TABLE_N
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    ph = random.Random(int(m * 100 + cents)).random() * TABLE_N
    y1 = y2 = 0.0
    for i in range(n):
        if i < na:
            env = i / na
            env *= env
        elif i < nd:
            env = 1.0
        else:
            env = 1.0 - (i - nd) / nr
            env *= env
        ph += inc
        y1 += a * (tab[int(ph) & MASK] * env - y1)
        y2 += a * (y1 - y2)
        out[i] = y2
    return out


@lru_cache(maxsize=None)
def bass(m: float, dur: float, kind: str = "round") -> array:
    """Round sub bass with a gloopy bend: "round" drops onto the pitch, "boing" bends up into it."""
    f = hz(m)
    n = int((dur + 0.08) * SR)
    nd = int(dur * SR)
    out = zeros(n)
    bend = 0.12 if kind == "round" else -0.18
    db = math.exp(-1.0 / ((0.025 if kind == "round" else 0.04) * SR))
    dd = math.exp(-1.0 / (0.25 * SR))
    sin, tanh = math.sin, math.tanh
    norm = 1.0 / tanh(1.3)
    ph, env, sus, att = 0.0, 0.0, 0.7, 0.005 * SR
    for i in range(n):
        ph += f * (1.0 + bend) / SR
        bend *= db
        x = TAU * ph
        v = tanh(1.3 * (sin(x) + 0.35 * sin(2 * x) + 0.12 * sin(3 * x))) * norm
        if i < att:
            env = i / att
        elif i < nd:
            env = sus + (env - sus) * dd
        else:
            env = max(0.0, env - sus / (0.08 * SR))
        out[i] = v * env
    return out


@lru_cache(maxsize=None)
def bubble(m: float, tau: float = 0.045) -> array:
    """A bubble that rises onto a chord tone and pops."""
    f = hz(m)
    n = int((tau * 5 + 0.02) * SR)
    out = zeros(n)
    dr = math.exp(-1.0 / (0.02 * SR))
    da = math.exp(-1.0 / (tau * SR))
    sin = math.sin
    ph, r, amp, att = 0.0, 0.34, 1.0, 0.002 * SR
    for i in range(n):
        ph += f * (1.06 - r) / SR
        r *= dr
        out[i] = sin(TAU * ph) * amp * (i / att if i < att else 1.0)
        amp *= da
    return out


@lru_cache(maxsize=None)
def kick(top: float = 125.0, bottom: float = 44.0, tau: float = 0.16) -> array:
    """A deep bloop: a sine dropping from `top` to `bottom` Hz, with a soft wet tick on top."""
    n = int((tau * 4 + 0.02) * SR)
    out = zeros(n)
    rng = random.Random(7)
    dp = math.exp(-1.0 / (0.035 * SR))
    da = math.exp(-1.0 / (tau * SR))
    sin = math.sin
    ph, k, amp, y = 0.0, 1.0, 1.0, 0.0
    for i in range(n):
        ph += (bottom + (top - bottom) * k) / SR
        k *= dp
        click = 0.0
        if i < 200:
            y = y * 0.7 + rng.uniform(-1, 1) * 0.3
            click = y * (1 - i / 200) * 0.5
        out[i] = (sin(TAU * ph) + 0.15 * sin(2 * TAU * ph)) * amp * min(1.0, i / 40) + click
        amp *= da
    return out


@lru_cache(maxsize=None)
def squelch(seed: int, tau: float = 0.07) -> array:
    """The snare: a wet squelch (band-passed noise slap, a small bloop body and one bubble)."""
    rng = random.Random(100 + seed)
    n = int(0.36 * SR)
    out = zeros(n)
    da = math.exp(-1.0 / (tau * SR))
    db = math.exp(-1.0 / (0.05 * SR))
    sin = math.sin
    a = b = ph = 0.0
    amp, body = 1.0, 1.0
    for i in range(n):
        w = rng.uniform(-1, 1)
        a = a * 0.72 + w * 0.28
        b = b * 0.965 + w * 0.035
        pulse = 0.75 + 0.25 * sin(TAU * 38 * i / SR)
        ph += (150.0 + 90.0 * body) / SR
        out[i] = ((a - b) * 2.2 * pulse * amp + 0.55 * sin(TAU * ph) * body) * min(1.0, i / 30)
        amp *= da
        body *= db
    pop = bubble(70 + rng.uniform(-3, 3), 0.03)
    start = int(rng.uniform(0.008, 0.025) * SR)
    for j, v in enumerate(pop):
        if start + j < n:
            out[start + j] += 0.35 * v
    return out


@lru_cache(maxsize=None)
def pop(seed: int) -> array:
    """A hat made of a tiny bubble pop (around 1 kHz, never hissy)."""
    rng = random.Random(200 + seed)
    clip = array("f", bubble(83 + rng.uniform(-2.5, 2.5), 0.014))
    y = 0.0
    for i in range(min(len(clip), 300)):
        y = y * 0.55 + rng.uniform(-1, 1) * 0.45
        clip[i] += y * 0.25 * (1 - i / 300)
    return clip


@lru_cache(maxsize=None)
def gloop(m_from: float, m_to: float, dur: float, wobble: float = 0.04, rate: float = 9.0) -> array:
    """A gloopy pitch bend (fills, transitions): sine + a soft triangle, wet vibrato."""
    f0, f1 = hz(m_from), hz(m_to)
    n = int(dur * SR)
    out = zeros(n)
    sin = math.sin
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t * (1.0 + wobble * sin(TAU * rate * i / SR))
        ph += f / SR
        tri = 4.0 * abs(ph % 1.0 - 0.5) - 1.0
        env = min(1.0, i / (0.006 * SR), (n - i) / (0.4 * n))
        out[i] = (sin(TAU * ph) * 0.75 + tri * 0.25) * env
    return out


def wet_thud(seconds: float, seed: int, release: float = 0.1) -> array:
    """Noise muffled by two low-pass passes and pulsed: a soft wet slap (as in make_sounds.py)."""
    rng = random.Random(seed)
    n = int(seconds * SR)
    out = zeros(n)
    a = b = 0.0
    for i in range(n):
        a = a * 0.968 + rng.uniform(-1, 1) * 0.032
        b = b * 0.968 + a * 0.032
        env = min(1.0, i / (0.002 * SR), (n - i) / (release * SR))
        out[i] = b * 26.0 * (0.7 + 0.3 * math.sin(TAU * 38 * i / SR)) * env
    return out


def splat(seed: int = 1) -> array:
    """A big low squelch, a wet slap and bubbles spraying off (the trailer hook and hit)."""
    rng = random.Random(seed)
    out = zeros(int(1.0 * SR))
    for j, v in enumerate(gloop(64, 31, 0.32, 0.12, 18)):
        out[j] += 0.7 * v
    for j, v in enumerate(wet_thud(0.26, seed, 0.2)):
        out[j] += 0.6 * v
    for _ in range(9):
        at = int(rng.uniform(0.0, 0.3) * SR)
        for j, v in enumerate(bubble(rng.uniform(55, 74), 0.03)):
            if at + j < len(out):
                out[at + j] += 0.22 * v
    return out


def boom(seed: int = 3) -> array:
    """The stinger under the end card: a deep sub drop, a splat and goo bubbles sinking away."""
    rng = random.Random(seed)
    n = int(3.2 * SR)
    out = zeros(n)
    sin = math.sin
    ph, k, amp = 0.0, 1.0, 1.0
    dk = math.exp(-1.0 / (0.35 * SR))
    da = math.exp(-1.0 / (0.9 * SR))
    for i in range(n):
        ph += (40.0 + 60.0 * k) / SR
        k *= dk
        out[i] = (sin(TAU * ph) + 0.25 * sin(2 * TAU * ph)) * amp * min(1.0, i / 60)
        amp *= da
    for j, v in enumerate(splat(seed)):
        out[j] += 0.8 * v
    for c in range(14):
        at = int((0.08 + c / 14 * 1.6) * SR)
        for j, v in enumerate(bubble(74 - c * 1.6 + rng.uniform(-1.5, 1.5), 0.05)):
            if at + j < n:
                out[at + j] += 0.16 * v * (1 - c / 16)
    return out


def fog(seconds: float, seed: int, fade: float = 2.0) -> array:
    """A soft airy hush (band-passed noise, slow swells) with equal-power fades at both ends, so when it
    is laid from 0 to the loop end plus `fade` the folded tail crossfades into the start."""
    rng = random.Random(seed)
    n = int((seconds + fade) * SR)
    nf = int(fade * SR)
    out = zeros(n)
    a = b = 0.0
    sin = math.sin
    for i in range(n):
        w = rng.uniform(-1, 1)
        a = a * 0.9 + w * 0.1
        b = b * 0.985 + w * 0.015
        swell = 0.65 + 0.35 * sin(TAU * i / SR / 7.3) * sin(TAU * i / SR / 3.1 + 1.0)
        env = 1.0
        if i < nf:
            env = sin(0.5 * math.pi * i / nf)
        elif i >= n - nf:
            env = sin(0.5 * math.pi * (n - i) / nf)
        out[i] = (a - b) * 3.0 * swell * env
    return out


def riser(seconds: float, seed: int) -> array:
    """A bubbling build: noise opening up and bubbles climbing faster and higher."""
    rng = random.Random(seed)
    n = int(seconds * SR)
    out = zeros(n + int(0.3 * SR))
    a = b = 0.0
    for i in range(n):
        t = i / n
        c = 0.015 + 0.16 * t * t
        a = a * (1 - c) + rng.uniform(-1, 1) * c
        b = b * (1 - c) + a * c
        out[i] = b * 7.0 * t * t
    count = int(seconds * 16)
    for k in range(count):
        t = (k / count) ** 0.6
        at = int(t * n)
        for j, v in enumerate(bubble(52 + 26 * t + rng.uniform(-3, 3), 0.035)):
            if at + j < len(out):
                out[at + j] += 0.3 * v * (0.3 + 0.7 * t)
    return out


# ---------------------------------------------------------------- arrangement

BUSES = {  # name: (pan -1..1, reverb send, level trim)
    "bass": (0.0, 0.03, 0.5), "kick": (0.0, 0.05, 0.85), "snare": (0.06, 0.25, 1.5), "popL": (-0.35, 0.25, 1.8),
    "popR": (0.35, 0.25, 1.8), "pluck": (-0.2, 0.34, 1.1), "pluck2": (0.25, 0.34, 1.4), "lead": (0.04, 0.3, 1.0),
    "arpL": (-0.5, 0.45, 1.5), "arpR": (0.5, 0.45, 1.5), "padL": (-0.7, 0.45, 0.9), "padR": (0.7, 0.45, 0.9),
    "fx": (0.0, 0.4, 1.0), "fog": (0.0, 0.2, 1.0),
}


class Song:
    def __init__(self, bpm, meter, bars, swing=0.5, div=0.5, loop=True, extra=0.0, seed=1):
        self.bpm, self.meter, self.bars = bpm, meter, bars
        self.spb = 60.0 / bpm
        self.swing, self.div, self.loop = swing, div, loop
        self.length = bars * meter * self.spb + extra
        self.loop_n = int(round(self.length * SR))
        self.n = self.loop_n + int(TAIL * SR)
        self.buses = {}
        self.events = []  # (bus, start sample, clip, gain) of every note, so unput() can take some back
        self.rng = random.Random(seed)

    def sec(self, beat: float) -> float:
        """Beat position -> seconds, with swing on every second `div` subdivision."""
        if self.swing == 0.5:
            return beat * self.spb
        p = beat / self.div
        k = math.floor(p + 1e-9)
        f = max(0.0, p - k)
        pair, odd = divmod(k, 2)
        u = (odd + f) / 2.0
        sw = self.swing
        u = u / 0.5 * sw if u < 0.5 else sw + (u - 0.5) / 0.5 * (1.0 - sw)
        return (pair * 2 + u * 2) * self.div * self.spb

    def put(self, name, clip, beat=None, at=None, gain=1.0, jitter=0.004, vel=0.0):
        t = at if at is not None else self.sec(beat)
        if jitter:
            t += self.rng.uniform(-jitter, jitter)
        if vel:
            gain *= 1.0 - self.rng.uniform(0.0, vel)
        start = max(0, int(round(t * SR)))
        end = min(self.n, start + len(clip))
        if end <= start:
            return
        buf = self.buses.get(name)
        if buf is None:
            buf = self.buses[name] = zeros(self.n)
        seg = buf[start:end]
        src = clip if gain == 1.0 else map(mul, clip, repeat(gain))
        buf[start:end] = array("f", map(add, seg, src))
        self.events.append((name, start, clip, gain, beat))

    def unput(self, since: int, from_beat: float):
        """Removes the notes placed since event `since` that start at or after `from_beat`."""
        keep = []
        for ev in self.events[since:]:
            name, start, clip, gain, beat = ev
            if beat is not None and beat >= from_beat - 1e-6:
                buf = self.buses[name]
                end = min(self.n, start + len(clip))
                buf[start:end] = array("f", map(add, buf[start:end], map(mul, clip, repeat(-gain))))
            else:
                keep.append(ev)
        self.events[since:] = keep

    def beats(self, b: float) -> float:
        return round(b * self.spb, 3)


def pad_chord(s: Song, chord, beat, beats, gain=0.05, cutoff=850.0, attack=0.6, release=1.4, table="soft"):
    dur = s.beats(beats)
    for m in chord:
        s.put("padL", pad_voice(m, dur, -6.0, cutoff, attack, release, table), beat, gain=gain, jitter=0)
        s.put("padR", pad_voice(m, dur, 6.0, cutoff, attack, release, table), beat, gain=gain, jitter=0)


def play_melody(s: Song, notes, offset, instr="lead", gain=0.2, transpose=0, bus=None, **kw):
    for b, m, d in notes:
        if instr == "lead":
            clip = lead(m + transpose, s.beats(d * 0.94), **kw)
        else:
            clip = pluck(m + transpose, **kw)
        s.put(bus or instr, clip, offset + b, gain=gain, vel=0.12)


def bar_chords(prog, bar, meter):
    entry = prog[bar % len(prog)]
    if isinstance(entry, str):
        return [(entry, 0, meter)]
    return list(entry)


# ---------------------------------------------------------------- the pieces

def hub_A():
    """Cozy goo: warm, slow, swung; D Dorian."""
    s = Song(bpm=84, meter=4, bars=24, swing=0.62, seed=11)
    C = {"Dm9": (38, (53, 57, 60, 64)), "G9": (43, (53, 57, 59, 62)), "Bbmaj7": (46, (53, 57, 62, 65)),
         "A7sus": (45, (52, 55, 57, 62)), "A7": (45, (52, 55, 57, 61))}
    prog = ["Dm9", "G9", "Bbmaj7", (("A7sus", 0, 2), ("A7", 2, 2))]
    hook = [(0.5, 62, .5), (1, 65, .5), (1.5, 69, 1.5), (3, 67, .5), (3.5, 65, .5),
            (4, 62, 1.5), (5.5, 59, .5), (6, 62, 2.0),
            (8.5, 62, .5), (9, 65, .5), (9.5, 69, 1.0), (10.5, 72, .5), (11, 69, 1.0),
            (12, 67, 1.0), (13, 64, 1.0), (14, 61, 1.0), (15, 64, 1.0),
            (16.5, 62, .5), (17, 65, .5), (17.5, 69, 1.5), (19, 67, .5), (19.5, 65, .5),
            (20, 67, 1.0), (21, 71, .5), (21.5, 69, .5), (22, 67, 2.0),
            (24.5, 65, .5), (25, 69, .5), (25.5, 70, .5), (26, 69, 1.5), (27.5, 65, .5),
            (28, 64, 1.0), (29, 62, 1.0), (30, 61, 1.5), (31.5, 64, .5)]
    counter = [(0, 69, 3), (3, 67, 1), (4, 71, 2), (6, 69, 2), (8, 69, 2), (10, 72, 1), (11, 70, 1),
               (12, 69, 2), (14, 67, 1), (15, 64, 1), (16, 65, 2), (18, 64, 1), (19, 62, 1),
               (20, 62, 2), (22, 59, 2), (24, 62, 1.5), (25.5, 65, .5), (26, 69, 2),
               (28, 67, 2), (30, 64, 1), (31, 61, 1)]
    for bar in range(s.bars):
        b0 = bar * 4
        sec = "intro" if bar < 4 else "A" if bar < 12 else "B" if bar < 20 else "outro"
        nxt = C[bar_chords(prog, bar + 1, 4)[0][0]][0]
        for name, st, ln in bar_chords(prog, bar, 4):
            root, chord = C[name]
            pad_chord(s, chord, b0 + st, ln, gain=0.045 if sec != "B" else 0.05)
            if sec == "intro" or bar >= 22:
                s.put("bass", bass(root, s.beats(ln * 0.9)), b0 + st, gain=0.5)
            else:
                pat = [(0, root, 1.3, "round", 0.5), (1.5, root + 12, 0.35, "boing", 0.3),
                       (2, root + 7, 0.9, "round", 0.42), (3, root, 0.45, "round", 0.4), (3.5, nxt - 1, 0.4, "boing", 0.32)]
                for pb, m, d, kind, g in pat:
                    if st <= pb < st + ln:
                        s.put("bass", bass(m, s.beats(d), kind), b0 + pb, gain=g, vel=0.08)
            if sec == "intro":
                for k, idx in enumerate((0, 2, 1, 3)):
                    if st <= k < st + ln:
                        s.put("pluck2", pluck(chord[idx % len(chord)] + 12), b0 + k, gain=0.09, vel=0.2)
            if sec == "A":
                for pb in (1.5, 3.5):
                    if st <= pb < st + ln:
                        for m in chord[-2:]:
                            s.put("pluck2", pluck(m + 12, 0.18), b0 + pb, gain=0.05, vel=0.2)
            if sec == "B":
                for k in range(8):
                    pb = k * 0.5
                    if st <= pb < st + ln:
                        m = chord[(0, 1, 2, 3, 2, 1, 3, 2)[k] % len(chord)] + 12
                        s.put("arpL" if k % 2 else "arpR", bubble(m, 0.06), b0 + pb, gain=0.07, vel=0.3)
        # drums
        if sec == "intro":
            for k in range(4):
                s.put("popL" if k % 2 else "popR", pop(k), b0 + k + 0.5, gain=0.045, vel=0.3)
            if bar >= 2:
                s.put("kick", kick(), b0, gain=0.35)
        else:
            soft = bar >= 22
            s.put("kick", kick(), b0, gain=0.5)
            if not soft:
                s.put("kick", kick(), b0 + 2, gain=0.36)
                s.put("snare", squelch(bar % 4), b0 + 1, gain=0.2, vel=0.15)
                s.put("snare", squelch((bar + 2) % 4), b0 + 3, gain=0.22, vel=0.15)
            for k in range(8):
                s.put("popL" if k % 2 else "popR", pop(k % 5), b0 + k * 0.5, gain=0.05 if k % 2 else 0.032, vel=0.35)
            if s.rng.random() < 0.35:
                s.put("arpR", bubble(s.rng.choice((62, 65, 69)) + 12, 0.04), b0 + s.rng.choice((1.75, 2.75, 3.25)), gain=0.05)
    play_melody(s, hook, 16, "lead", gain=0.22)
    play_melody(s, counter, 48, "lead", gain=0.17)
    play_melody(s, hook[:13], 80, "pluck", gain=0.24, bus="pluck")
    s.put("fx", gloop(62, 50, s.beats(0.5)), 23 * 4 + 3.5, gain=0.12)
    meta = dict(title="Cozy Goo", mood="warm, slow, swung, cosy: the hub at rest", key="D Dorian (Dm9 - G9 - Bbmaj7 - A7sus/A7)",
                bpm=84, meter="4/4, swung 8ths", form="4-bar intro, 8-bar melody, 8-bar counter-melody with bubble arps, 4-bar outro")
    return s, meta


def hub_B():
    """Foggy lullaby: sparse, darker, a music-box goo melody in 3/4; C minor."""
    s = Song(bpm=69, meter=3, bars=28, swing=0.58, seed=22)
    C = {"Cm9": (36, (51, 55, 58, 62)), "Abmaj7": (44, (51, 55, 60, 63)), "Fm9": (41, (51, 55, 56, 60)),
         "G7sus": (43, (53, 55, 60, 62)), "G7": (43, (53, 55, 59, 62)), "Ebmaj7": (39, (50, 55, 58, 62))}
    prog = ["Cm9", "Abmaj7", "Fm9", (("G7sus", 0, 2), ("G7", 2, 1)), "Cm9", "Ebmaj7", "Abmaj7", "G7"]
    mel = [(0, 67, 2), (2, 63, 1), (3, 67, 1.5), (4.5, 68, .5), (5, 67, 1), (6, 65, 2), (8, 63, 1), (9, 62, 3),
           (12, 67, 2), (14, 63, 1), (15, 70, 1.5), (16.5, 68, .5), (17, 67, 1), (18, 65, 1), (19, 63, 1), (20, 60, 1),
           (21, 62, 2), (23, 59, 1)]
    for bar in range(s.bars):
        b0 = bar * 3
        sec = "intro" if bar < 4 else "A" if bar < 12 else "B" if bar < 20 else "dark" if bar < 24 else "return"
        for name, st, ln in bar_chords(prog, bar, 3):
            root, chord = C[name]
            pad_chord(s, chord, b0 + st, ln, gain=0.05 if sec != "dark" else 0.06, cutoff=700 if sec != "B" else 820,
                      attack=0.9, release=1.8, table="hollow" if sec == "dark" else "soft")
            if st == 0:
                s.put("bass", bass(root, s.beats(2.6)), b0, gain=0.42 if sec != "intro" else 0.32)
            elif sec in ("A", "B"):
                s.put("bass", bass(root, s.beats(0.9), "boing"), b0 + st, gain=0.25)
            if sec in ("intro", "A", "B", "return"):
                g = {"intro": 0.075, "A": 0.06, "B": 0.05, "return": 0.08}[sec]
                for k in range(6):
                    pb = k * 0.5
                    if st <= pb < st + ln:
                        m = chord[(0, 1, 2, 3, 2, 1)[k] % len(chord)] + 12
                        s.put("pluck2", pluck(m, 0.45), b0 + pb, gain=g * (1.15 if k == 0 else 1.0), vel=0.25)
        if sec in ("A", "B"):
            s.put("kick", kick(95.0, 40.0, 0.14), b0, gain=0.3)
            s.put("kick", kick(85.0, 38.0, 0.12), b0 + 0.35, gain=0.16)
            if sec == "B":
                s.put("popR", pop(bar % 5), b0 + 1.5, gain=0.035, vel=0.3)
                s.put("popL", pop((bar + 2) % 5), b0 + 2.5, gain=0.03, vel=0.3)
        if sec in ("B", "dark") and s.rng.random() < 0.6:
            name = bar_chords(prog, bar, 3)[0][0]
            m = s.rng.choice(C[name][1]) + 12
            s.put("arpL" if s.rng.random() < 0.5 else "arpR", bubble(m, 0.07), b0 + s.rng.choice((0.75, 1.25, 2.25)), gain=0.06)
    play_melody(s, mel, 12, "pluck", gain=0.26, tau=0.75)
    play_melody(s, mel, 36, "lead", gain=0.2, cutoff=1100)
    play_melody(s, [(b, m - 12, d) for b, m, d in mel if b % 3 == 0], 36, "pluck", gain=0.1, tau=0.6, bus="pluck")
    s.put("fog", fog(s.length, 31), at=0, gain=0.05, jitter=0)
    meta = dict(title="Foggy Lullaby", mood="sparse, darker, hushed; a music-box goo melody in the fog",
                key="C minor (Cm9 - Abmaj7 - Fm9 - G7sus/G7 | Cm9 - Ebmaj7 - Abmaj7 - G7)", bpm=69, meter="3/4, lightly swung",
                form="4-bar intro, 8 bars music-box melody, 8 bars goo-voice melody, 4 dark bars (pad, bass, fog), 4 bars arpeggio back in")
    return s, meta


def hub_C():
    """Bouncy hub: a bit more upbeat, boing bass and pops; F major."""
    s = Song(bpm=100, meter=4, bars=32, swing=0.57, div=0.25, seed=33)
    C = {"Fmaj7": (41, (52, 57, 60, 64)), "Dm7": (38, (53, 57, 60, 62)), "Gm7": (43, (53, 58, 62, 65)),
         "C7sus": (36, (53, 55, 58, 62)), "C7": (36, (52, 55, 58, 62)), "Bbmaj7": (46, (53, 57, 62, 65)),
         "Am7": (45, (52, 55, 60, 64))}
    prog = ["Fmaj7", "Dm7", "Gm7", (("C7sus", 0, 2), ("C7", 2, 2)), "Bbmaj7", "Am7", "Gm7", "C7"]
    mel = [(0, 69, .5), (0.5, 72, .5), (1, 69, .5), (1.5, 65, 1), (3, 67, .5), (3.5, 69, .5),
           (4, 65, 1.5), (5.5, 62, .5), (6, 65, .5), (6.5, 69, 1.5),
           (8, 70, .5), (8.5, 69, .5), (9, 67, .5), (9.5, 65, .5), (10, 67, 1.5), (11.5, 62, .5),
           (12, 65, 1), (13, 67, 1), (14, 70, 1), (15, 64, 1),
           (16, 69, 1), (17, 65, .5), (17.5, 62, .5), (18, 65, 2),
           (20, 64, .5), (20.5, 65, .5), (21, 67, .5), (21.5, 69, 1.5), (23, 72, 1),
           (24, 70, 1.5), (25.5, 69, .5), (26, 67, 1), (27, 65, 1),
           (28, 67, 1), (29, 64, 1), (30, 60, 2)]
    for bar in range(s.bars):
        b0 = bar * 4
        sec = "intro" if bar < 4 else "A" if bar < 12 else "B" if bar < 20 else "A2" if bar < 28 else "break"
        for name, st, ln in bar_chords(prog, bar, 4):
            root, chord = C[name]
            pad_chord(s, chord, b0 + st, ln, gain=0.035 if sec != "break" else 0.055, cutoff=900)
            if sec == "break":
                s.put("bass", bass(root, s.beats(ln * 0.85)), b0 + st, gain=0.45)
            else:
                pat = [(0, root, .45, "boing", .5), (1, root + 12, .3, "boing", .3), (1.5, root, .3, "round", .32),
                       (2, root + 7, .45, "boing", .42), (3, root + 12, .3, "boing", .3), (3.5, root + 7, .3, "round", .3)]
                for pb, m, d, kind, g in pat:
                    if st <= pb < st + ln:
                        s.put("bass", bass(m, s.beats(d), kind), b0 + pb, gain=g, vel=0.08)
                for pb in (1.5, 3.5):
                    if st <= pb < st + ln:
                        for m in chord[-3:]:
                            s.put("pluck2", pluck(m + 12, 0.16), b0 + pb, gain=0.045, vel=0.2)
            if sec in ("B", "A2"):
                for k in range(16):
                    pb = k * 0.25
                    if st <= pb < st + ln:
                        m = chord[(0, 1, 2, 3)[k % 4] if (k // 4) % 2 == 0 else (3, 2, 1, 0)[k % 4]] + 12
                        s.put("arpL" if k % 2 else "arpR", bubble(m, 0.04), b0 + pb, gain=0.05 if sec == "B" else 0.035, vel=0.3)
        if sec != "break":
            s.put("kick", kick(), b0, gain=0.5)
            s.put("kick", kick(), b0 + 1.75, gain=0.28)
            s.put("kick", kick(), b0 + 2.5, gain=0.4)
            s.put("snare", squelch(bar % 4), b0 + 1, gain=0.22, vel=0.12)
            s.put("snare", squelch((bar + 1) % 4), b0 + 3, gain=0.24, vel=0.12)
            if bar % 4 == 3:
                s.put("snare", squelch(2, 0.04), b0 + 3.75, gain=0.1)
        for k in range(8 if sec != "break" else 4):
            pb = k * 0.5 if sec != "break" else k + 0.5
            s.put("popL" if k % 2 else "popR", pop(k % 5), b0 + pb, gain=0.045 if k % 2 else 0.03, vel=0.35)
            if sec != "break" and k % 2:
                s.put("popL", pop((k + 2) % 5), b0 + pb + 0.25, gain=0.018, vel=0.4)
    play_melody(s, mel, 16, "lead", gain=0.2, cutoff=1500)
    play_melody(s, mel, 48, "pluck", gain=0.22, bus="pluck")
    play_melody(s, mel, 80, "lead", gain=0.18, cutoff=1500)
    play_melody(s, mel, 80, "pluck", gain=0.11, transpose=-12, bus="pluck", tau=0.35)
    s.put("fx", gloop(65, 53, s.beats(0.5)), 31 * 4 + 3.5, gain=0.12)
    meta = dict(title="Bouncy Hub", mood="a bit more upbeat: boing bass, squelch snares, bubble pops, a hummable hook",
                key="F major (Fmaj7 - Dm7 - Gm7 - C7sus/C7 | Bbmaj7 - Am7 - Gm7 - C7)", bpm=100, meter="4/4, swung 16ths",
                form="4-bar groove intro, 8-bar goo-voice hook, 8 bars goo drops + bubble arps, 8 bars hook doubled, 4-bar breakdown")
    return s, meta


TRAILERS = {
    "trailer_1": dict(title="Goo Rush", mood="energetic: a goo hook, a bubbling build, a bouncy drop, a splat hit",
                      key="D minor (build Dm9 - Bbmaj7 - Gm9 - A7, drop Dm - Bb - F - C)", bpm=112, swing=0.5),
    "trailer_2": dict(title="Fog Pulse", mood="moody: a lullaby hook, a heartbeat build, a half-time drop, a deep boom",
                      key="C minor (Cm9 - Abmaj7 - Ebmaj7 - G7)", bpm=92, swing=0.55),
}


def trailer(name: str, hit: float, ring: float):
    """A trailer track fitted to a video: hook (bar 0), build, drop, then the hit exactly at `hit` s and a
    ring-out of `ring` s. The tempo is nudged (a few BPM) so a whole number of bars ends on the hit."""
    conf = TRAILERS[name]
    bar_len = 4 * 60.0 / conf["bpm"]
    bars = max(5, int(round(hit / bar_len)))
    bpm = bars * 4 * 60.0 / hit
    s = Song(bpm=bpm, meter=4, bars=bars, swing=conf["swing"], loop=False, extra=ring, seed=44 if name == "trailer_1" else 55)
    rest = bars - 1
    build = max(2, (rest * 2) // 5)
    drop0 = 1 + build
    hb = bars * 4  # the hit, in beats
    moody = name == "trailer_2"
    if not moody:
        C = {"Dm9": (38, (53, 57, 60, 64)), "Bbmaj7": (46, (53, 57, 62, 65)), "Gm9": (43, (53, 57, 58, 62)),
             "A7": (45, (52, 55, 57, 61)), "Dm": (38, (53, 57, 62, 64)), "Bb": (46, (53, 58, 60, 62)),
             "F": (41, (53, 57, 60, 65)), "C": (36, (52, 55, 60, 62))}
        build_prog, drop_prog = ["Dm9", "Bbmaj7", "Gm9", "A7"], ["Dm", "Bb", "F", "C"]
        mel = [(0, 62, .5), (0.5, 65, .5), (1, 69, 1.0), (2.5, 67, .5), (3, 65, .5), (3.5, 64, .5),
               (4, 62, 1.5), (5.5, 65, .5), (6, 62, .5), (6.5, 58, 1.0), (7.5, 60, .5),
               (8, 60, .5), (8.5, 65, .5), (9, 69, 1), (10.5, 72, .5), (11, 69, .5), (11.5, 67, .5),
               (12, 67, 1.0), (13, 64, 1), (14, 67, .5), (14.5, 64, .5), (15, 62, 1)]
        # Hook: "blup blup bloooop" + a splat, then bubbles climbing into the build.
        s.put("fx", splat(5), 0, gain=0.5, jitter=0)
        s.put("kick", kick(), 0, gain=0.6, jitter=0)
        s.put("bass", bass(38, s.beats(2.0)), 0, gain=0.5, jitter=0)
        for b, m, d, dr in ((0, 62, .5, 0), (0.5, 65, .5, 0), (1, 69, 1.4, 2.0)):
            s.put("lead", lead(m, s.beats(d), 1600, 0.06, dr), b, gain=0.26, jitter=0)
            s.put("pluck", pluck(m), b, gain=0.2, jitter=0)
        for k, m in enumerate((62, 65, 69, 74, 69, 74)):
            s.put("arpL" if k % 2 else "arpR", bubble(m, 0.05), 2.5 + k * 0.25, gain=0.09)
        tail_root, tail_chord, tail_top = 38, (50, 57, 62, 64, 69), (62, 69)
    else:
        C = {"Cm9": (36, (51, 55, 58, 62)), "Abmaj7": (44, (51, 55, 60, 63)), "Ebmaj7": (39, (50, 55, 58, 62)),
             "G7": (43, (53, 55, 59, 62))}
        build_prog = drop_prog = ["Cm9", "Abmaj7", "Ebmaj7", "G7"]
        mel = [(0, 67, 1.5), (1.5, 63, .5), (2, 67, .5), (2.5, 68, .5), (3, 67, 1),
               (4, 63, 2), (6, 60, 1), (7, 63, 1),
               (8, 62, 1.5), (9.5, 63, .5), (10, 65, 1), (11, 67, 1),
               (12, 67, 1), (13, 65, .5), (13.5, 63, .5), (14, 62, 2)]
        # Hook: a deep heartbeat thud, a music-box "G - Eb - C" and the goo voice sagging under it.
        s.put("kick", kick(90.0, 36.0, 0.25), 0, gain=0.7, jitter=0)
        s.put("kick", kick(80.0, 34.0, 0.2), 0.4, gain=0.4, jitter=0)
        s.put("bass", bass(36, s.beats(3.5)), 0, gain=0.45, jitter=0)
        for b, m in ((0, 67), (0.75, 63), (1.5, 60)):
            s.put("pluck", pluck(m, 0.8), b, gain=0.3, jitter=0)
        s.put("lead", lead(58, s.beats(2.0), 1100, 0.1, 1.5), 2, gain=0.22, jitter=0)
        pad_chord(s, C["Cm9"][1], 0, 4, gain=0.05, cutoff=600, attack=0.4)
        tail_root, tail_chord, tail_top = 36, (48, 55, 58, 62, 63), (60, 67)
        s.put("fog", fog(s.length, 77), at=0, gain=0.05, jitter=0)
    # Build: pads opening up, arpeggios getting busier, the kick filling in, a riser and a snare roll.
    for k in range(build):
        bar = 1 + k
        b0 = bar * 4
        last = k == build - 1
        frac = (k + 1) / build
        name = build_prog[k % 4]
        root, chord = C[name]
        pad_chord(s, chord, b0, 3.5 if last else 4, gain=0.05, cutoff=450 + 900 * frac, attack=0.3, release=0.6 if last else 1.2)
        s.put("bass", bass(root, s.beats(3.3 if last else 3.8)), b0, gain=0.42)
        step = 0.25 if last else 0.5
        for j in range(int((3.5 if last else 4) / step)):
            m = chord[(0, 1, 2, 3, 2, 1, 3, 2)[j % 8] % len(chord)] + 12
            s.put("pluck2", pluck(m, 0.22), b0 + j * step, gain=0.05 + 0.06 * frac, vel=0.2)
        if moody:
            for q in ((0,) if frac < 0.6 else (0, 2)) if not last else (0, 1, 2, 3):
                s.put("kick", kick(90.0, 38.0, 0.16), b0 + q, gain=0.5)
                s.put("kick", kick(80.0, 36.0, 0.12), b0 + q + 0.4, gain=0.25)
        else:
            for q in ((0, 2) if frac < 0.6 else (0, 1, 2, 3)):
                if not (last and q > 3):
                    s.put("kick", kick(), b0 + q, gain=0.5)
        if last:
            for j in range(8):
                s.put("snare", squelch(j % 4, 0.05), b0 + 1.5 + j * 0.25, gain=0.06 + 0.03 * j)
    rb = max(1, min(build, 2))
    s.put("fx", riser(s.sec(rb * 4) - 0.05, 9), at=s.sec((drop0 - rb) * 4), gain=0.18, jitter=0)
    # Drop: the full groove under the hook melody, until the hit.
    for k in range(bars - drop0):
        bar = drop0 + k
        b0 = bar * 4
        last = bar == bars - 1
        name = drop_prog[k % 4]
        root, chord = C[name]
        pad_chord(s, chord, b0, 3.4 if last else 4, gain=0.035, cutoff=1000, attack=0.15, release=0.5 if not last else 0.15)
        mark = len(s.events) if last else None
        if moody:
            s.put("bass", bass(root, s.beats(1.4)), b0, gain=0.5)
            s.put("bass", bass(root + 12, s.beats(0.4), "boing"), b0 + 1.5, gain=0.3)
            s.put("bass", bass(root, s.beats(1.4)), b0 + 2, gain=0.42)
            s.put("bass", bass(root + 7, s.beats(0.4), "boing"), b0 + 3.5, gain=0.3)
            s.put("kick", kick(110.0, 40.0, 0.18), b0, gain=0.5)
            s.put("kick", kick(110.0, 40.0, 0.18), b0 + 2.75, gain=0.32)
            s.put("snare", squelch(k % 4, 0.09), b0 + 2, gain=0.3)
            for j in range(8):
                s.put("popL" if j % 2 else "popR", pop(j % 5), b0 + j * 0.5, gain=0.05 if j % 2 else 0.03, vel=0.3)
            for j in range(16):
                m = chord[(0, 2, 1, 3)[j % 4] % len(chord)] + 12
                s.put("arpL" if j % 2 else "arpR", bubble(m, 0.04), b0 + j * 0.25, gain=0.04, vel=0.3)
            s.put("pluck2", pluck(chord[-1] + 12, 0.3), b0 + 1, gain=0.08)
            s.put("pluck2", pluck(chord[-2] + 12, 0.3), b0 + 3, gain=0.07)
        else:
            for j, (pb, m, d, kind, g) in enumerate(((0, root, .45, "round", .5), (0.5, root, .2, "round", .28),
                                                     (1, root + 12, .3, "boing", .34), (1.5, root, .2, "round", .28),
                                                     (2, root, .45, "round", .46), (2.5, root + 7, .2, "boing", .3),
                                                     (3, root + 12, .3, "boing", .34), (3.5, root + 7, .2, "round", .28))):
                s.put("bass", bass(m, s.beats(d), kind), b0 + pb, gain=g, vel=0.06)
            for q in range(4):
                s.put("kick", kick(), b0 + q, gain=0.45)
            s.put("snare", squelch(k % 4), b0 + 1, gain=0.26, vel=0.1)
            s.put("snare", squelch((k + 1) % 4), b0 + 3, gain=0.28, vel=0.1)
            for j in range(8):
                s.put("popL" if j % 2 else "popR", pop(j % 5), b0 + j * 0.5, gain=0.055 if j % 2 else 0.03, vel=0.3)
            for j in range(16):
                m = chord[(0, 1, 2, 3, 2, 1, 2, 3)[j % 8] % len(chord)] + 12
                s.put("arpL" if j % 2 else "arpR", bubble(m, 0.04), b0 + j * 0.25, gain=0.045, vel=0.3)
            for pb in (0.5, 1.5, 2.5, 3.5):
                for m in chord[-2:]:
                    s.put("pluck2", pluck(m + 12, 0.14), b0 + pb, gain=0.04, vel=0.2)
        if last:
            # A half-beat gap of silence right before the hit, so the stinger lands.
            s.unput(mark, b0 + 3.5)
            for j in range(2):
                s.put("snare", squelch(j % 4, 0.04), b0 + 3 + j * 0.25, gain=0.12 + 0.06 * j)
    for b, m, d in mel:
        for rep in range(0, bars - drop0, 4):
            at = drop0 * 4 + rep * 4 + b
            if at + d <= hb - 0.5:
                s.put("lead", lead(m, s.beats(d * 0.94), 1500 if not moody else 1150), at, gain=0.22, vel=0.1)
    # The hit (exactly on the end card) and the ring-out.
    hit_s = s.sec(hb)
    s.put("fx", boom(), at=hit_s, gain=0.75, jitter=0)
    s.put("bass", bass(tail_root, ring * 0.6), at=hit_s, gain=0.45, jitter=0)
    for m in tail_chord:
        s.put("pluck", pluck(m, 0.9), at=hit_s, gain=0.12, jitter=0)
    for m in tail_top:
        s.put("lead", lead(m, ring * 0.5, 1200, 0.05, 0.0), at=hit_s + 0.02, gain=0.12, jitter=0)
    for m in tail_chord[1:]:
        s.put("padL", pad_voice(m, round(ring * 0.4, 3), -6.0, 800.0, 0.05, ring * 0.55), at=hit_s, gain=0.05, jitter=0)
        s.put("padR", pad_voice(m, round(ring * 0.4, 3), 6.0, 800.0, 0.05, ring * 0.55), at=hit_s, gain=0.05, jitter=0)
    meta = dict(title=conf["title"], mood=conf["mood"], key=conf["key"], bpm=round(bpm, 2), meter="4/4",
                form="hook (bar 1), build (%d bars), drop (%d bars), hit at %.2f s, ring-out %.1f s" % (build, bars - drop0, hit, ring),
                hit=round(hit_s, 3))
    return s, meta


PIECES = {"hub_A": hub_A, "hub_B": hub_B, "hub_C": hub_C, "trailer_1": None, "trailer_2": None}
DEFAULT_HIT, DEFAULT_RING = 24.4, 3.6   # draft A's end card starts at 24.4 s


# ---------------------------------------------------------------- mixing

def lowpass_hp(x: array, lp_hz: float, hp_hz: float) -> array:
    """One-pole low-pass at lp_hz, minus a one-pole low-pass at hp_hz (= band-limited)."""
    a = 1.0 - math.exp(-TAU * lp_hz / SR)
    b = 1.0 - math.exp(-TAU * hp_hz / SR)
    out = zeros(len(x), "d")
    y = z = 0.0
    for i, v in enumerate(x):
        y += a * (v - y)
        z += b * (y - z)
        out[i] = y - z
    return out


def comb(x: array, d: int, g: float) -> array:
    """Feedback comb y[n] = x[n] + g y[n-d], computed a block of d samples at a time."""
    y = array("d", x[:d])
    for s in range(d, len(x), d):
        y.extend(map(add, x[s:s + d], map(mul, y[s - d:s], repeat(g))))
    return y


def allpass(x: array, d: int, g: float) -> array:
    y = array("d", (-g * v for v in x[:d]))
    for s in range(d, len(x), d):
        y.extend(-g * a + b + g * c for a, b, c in zip(x[s:s + d], x[s - d:s], y[s - d:s]))
    return y


def reverb(send: array, room: float = 0.8, spread: int = 0) -> array:
    """A dark Schroeder reverb (six combs, two all-passes); `spread` offsets the delays per channel."""
    combs = (1557, 1617, 1491, 1422, 1277, 1356)
    acc = None
    for d in combs:
        c = comb(send, d + spread, room)
        acc = c if acc is None else array("d", map(add, acc, c))
    acc = array("d", map(mul, acc, repeat(1.0 / len(combs))))
    for d in (556, 441):
        acc = allpass(acc, d + spread, 0.5)
    return acc


def rms(x) -> float:
    return math.sqrt(sum(v * v for v in x) / max(1, len(x)))


def mixdown(s: Song, wet: float = 0.32, room: float = 0.8, verbose: bool = False):
    n = s.n
    L, R, S = zeros(n, "d"), zeros(n, "d"), zeros(n, "d")
    for name, buf in s.buses.items():
        pan, send, trim = BUSES[name]
        gl = math.cos((pan + 1) * math.pi / 4) * math.sqrt(2) * trim
        gr = math.sin((pan + 1) * math.pi / 4) * math.sqrt(2) * trim
        send *= trim
        L = array("d", map(add, L, map(mul, buf, repeat(gl))))
        R = array("d", map(add, R, map(mul, buf, repeat(gr))))
        if send:
            S = array("d", map(add, S, map(mul, buf, repeat(send))))
        if verbose:
            print("   %-7s rms %6.1f dB" % (name, 20 * math.log10(max(1e-9, rms(buf[::7])))))
    pre = int(0.022 * SR)
    S = lowpass_hp(S, 2600.0, 160.0)
    S = zeros(pre, "d") + S[:n - pre]
    wl, wr = reverb(S, room, 0), reverb(S, room, 23)
    k = wet * rms(S[::5]) / max(1e-9, rms(wl[::5]))
    L = array("d", map(add, L, map(mul, wl, repeat(k))))
    R = array("d", map(add, R, map(mul, wr, repeat(k))))
    # High-pass (rumble / DC; linear, so it is safe before the loop fold). Trailers get a steeper 40 Hz one:
    # phones can't play that low and it would only eat headroom at -14 LUFS.
    L, R = highpass(L, 28.0 if s.loop else 40.0), highpass(R, 28.0 if s.loop else 40.0)
    if not s.loop:
        L, R = highpass(L, 40.0), highpass(R, 40.0)
    if s.loop:
        L, R = fold(L, s.loop_n), fold(R, s.loop_n)
    return L, R


def highpass(x: array, f: float) -> array:
    a = 1.0 - math.exp(-TAU * f / SR)
    out = zeros(len(x), "d")
    y = 0.0
    for i, v in enumerate(x):
        y += a * (v - y)
        out[i] = v - y
    return out


def fold(x: array, n: int) -> array:
    """Wrap everything past the loop end back onto the start: the steady state of the loop played forever."""
    out = array("d", x[:n])
    for k in range(1, (len(x) + n - 1) // n):
        part = x[k * n:(k + 1) * n]
        out[:len(part)] = array("d", map(add, out[:len(part)], part))
    return out


# ---------------------------------------------------------------- mastering

def find_ffmpeg(explicit=None):
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


def write_float_wav(path, L, R):
    data = array("f", bytes(8 * len(L)))
    data[0::2] = array("f", L)
    data[1::2] = array("f", R)
    with open(path, "wb") as f:
        size = len(data) * 4
        f.write(b"RIFF" + struct.pack("<I", 36 + size) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 3, 2, SR, SR * 8, 8, 32))
        f.write(b"data" + struct.pack("<I", size))
        f.write(data.tobytes())


def write_pcm16(path, L, R, seed=1):
    rng = random.Random(seed)
    r = rng.random
    def q(v):
        x = int(round(v * 32767.0 + r() - r()))
        return 32767 if x > 32767 else -32768 if x < -32768 else x
    data = array("h", bytes(4 * len(L)))
    data[0::2] = array("h", map(q, L))
    data[1::2] = array("h", map(q, R))
    with open(path, "wb") as f:
        size = len(data) * 2
        f.write(b"RIFF" + struct.pack("<I", 36 + size) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 2, SR, SR * 4, 4, 16))
        f.write(b"data" + struct.pack("<I", size))
        f.write(data.tobytes())
    return data


def measure(ffmpeg, path):
    """(integrated LUFS, true peak dBTP) via ffmpeg's loudnorm analysis."""
    proc = subprocess.run([ffmpeg, "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    text = proc.stderr
    m = json.loads(text[text.rindex("{"):text.rindex("}") + 1])
    return float(m["input_i"]), float(m["input_tp"])


def sliding_min(x, radius):
    out = [0.0] * len(x)
    dq = deque()
    n = len(x)
    for i in range(n + radius):
        if i < n:
            v = x[i]
            while dq and x[dq[-1]] >= v:
                dq.pop()
            dq.append(i)
        c = i - radius
        if c >= 0:
            while dq[0] < c - radius:
                dq.popleft()
            out[c] = x[dq[0]]
    return out


def limit(L, R, ceiling, loop, look=0.003, release=0.08):
    """Look-ahead peak limiter. For loops it runs on the loop with a second of wrap-around on each side."""
    n = len(L)
    pad = min(n, SR) if loop else 0
    if loop:
        L2, R2 = L[n - pad:] + L + L[:pad], R[n - pad:] + R + R[:pad]
    else:
        L2, R2 = L, R
    need = [ceiling / p if p > ceiling else 1.0 for p in map(max, map(abs, L2), map(abs, R2))]
    w = int(look * SR)
    m = sliding_min(need, w)
    rc = 1.0 - math.exp(-1.0 / (release * SR))
    g, gs = 1.0, [0.0] * len(m)
    for i, v in enumerate(m):
        g = v if v < g else g + (v - g) * rc
        gs[i] = g
    h = max(1, w // 2)
    csum = [0.0]
    for v in gs:
        csum.append(csum[-1] + v)
    sm = [(csum[min(len(gs), i + h + 1)] - csum[max(0, i - h)]) / (min(len(gs), i + h + 1) - max(0, i - h)) for i in range(len(gs))]
    L2 = array("d", map(mul, L2, sm))
    R2 = array("d", map(mul, R2, sm))
    return (L2[pad:pad + n], R2[pad:pad + n]) if loop else (L2, R2)


def master(L, R, target, loop, ffmpeg, tmp):
    """Gain to `target` LUFS, keep true peaks under TP_MAX (limiting only if needed). Returns L, R, limited dB."""
    path = os.path.join(tmp, "measure.wav")
    reduction = 0.0
    ceiling_db = TP_MAX - 0.5
    for _ in range(8):
        write_float_wav(path, L, R)
        lufs, tp = measure(ffmpeg, path)
        g = target - lufs
        if abs(g) > 0.05:
            k = 10 ** (g / 20)
            L = array("d", map(mul, L, repeat(k)))
            R = array("d", map(mul, R, repeat(k)))
            tp += g
        if tp <= TP_MAX and abs(g) < 0.15:
            break
        if tp > TP_MAX:
            sp = 20 * math.log10(max(max(map(abs, L)), max(map(abs, R))))
            margin = max(0.0, tp - sp)
            ceiling = 10 ** ((ceiling_db - margin) / 20)
            L, R = limit(L, R, ceiling, loop)
            reduction = max(reduction, sp - (ceiling_db - margin))
            ceiling_db -= 0.1
    return L, R, reduction


def seam_check(data: array, loop_n: int, name: str):
    """How big the step from the loop's last sample to its first is, next to the music's own steps."""
    worst, typical = 0, []
    for ch in (0, 1):
        x = data[ch::2]
        worst = max(worst, abs(x[0] - x[loop_n - 1]))
        steps = sorted(abs(x[i] - x[i - 1]) for i in range(1, loop_n, 37))
        typical.append(steps[int(len(steps) * 0.999)])
        near = [abs(x[i % loop_n] - x[(i - 1) % loop_n]) for i in range(loop_n - 441, loop_n + 441)]
        mean_near = sum(near) / len(near)
        mean_all = sum(steps) / len(steps)
    return {"seam_step_lsb": worst, "p999_step_lsb": max(typical),
            "seam_window_vs_track": round(mean_near / max(1e-9, mean_all), 2)}


# ---------------------------------------------------------------- render

def render(name, ffmpeg, out_wav, hit=None, ring=None, extras=True, verbose=False):
    t0 = time.time()
    if name.startswith("trailer"):
        s, meta = trailer(name, hit or DEFAULT_HIT, ring or DEFAULT_RING)
        target = TRAILER_LUFS
    else:
        s, meta = PIECES[name]()
        target = HUB_LUFS
    L, R = mixdown(s, verbose=verbose)
    if not s.loop:
        n = int(round(s.length * SR))
        L, R = L[:n], R[:n]
        fade = int(0.7 * SR)
        for i in range(fade):
            k = (fade - i) / fade
            L[n - fade + i] *= k * k
            R[n - fade + i] *= k * k
    with tempfile.TemporaryDirectory() as tmp:
        L, R, reduction = master(L, R, target, s.loop, ffmpeg, tmp)
    data = write_pcm16(out_wav, L, R, seed=len(name))
    lufs, tp = measure(ffmpeg, str(out_wav))
    stats = dict(name=name, seconds=round(len(L) / SR, 2), lufs=lufs, tp=tp, limited_db=round(reduction, 2),
                 render_s=round(time.time() - t0, 1), loop=s.loop, **meta)
    if s.loop:
        stats.update(seam_check(data, len(L), name))
        if extras:
            seam_dir = OUT / "seams"
            seam_dir.mkdir(parents=True, exist_ok=True)
            k = 3 * SR * 2
            seam = data[-k:] + data[:k]
            with open(seam_dir / ("%s_seam.wav" % name), "wb") as f:
                size = len(seam) * 2
                f.write(b"RIFF" + struct.pack("<I", 36 + size) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 2, SR, SR * 4, 4, 16))
                f.write(b"data" + struct.pack("<I", size))
                f.write(seam.tobytes())
    if extras:
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(out_wav), "-c:a", "libvorbis", "-q:a", "5",
                        str(out_wav.with_suffix(".ogg"))], check=True, timeout=600)
    print("wrote %s  %.1f s  %.1f LUFS  %.1f dBTP  (%.0f s)" % (out_wav.name, stats["seconds"], lufs, tp, stats["render_s"]), flush=True)
    return stats


def _job(args):
    name, ffmpeg = args
    return render(name, ffmpeg, OUT / ("%s.wav" % name))


def write_readme(stats):
    lines = ["# Music mockups (generated by tools/make_music.py; see docs/marketing/music.md)", "",
             "Procedural, synthesized from scratch (no samples, nothing third-party). 44.1 kHz 16-bit stereo WAV, plus an",
             "OGG copy of each for quick listening. **Mockups only: none of this is in the game.**", "",
             "| file | length | tempo | key | loudness | true peak |", "|---|---|---|---|---|---|"]
    for st in stats:
        lines.append("| %s.wav | %.1f s%s | %s BPM, %s | %s | %.1f LUFS | %.1f dBTP |" % (
            st["name"], st["seconds"], " (loop)" if st["loop"] else "", st["bpm"], st["meter"], st["key"].replace(" | ", "; "),
            st["lufs"], st["tp"]))
    lines.append("")
    for st in stats:
        lines += ["## %s.wav: %s" % (st["name"], st["title"]), "", "- Mood: " + st["mood"], "- Form: " + st["form"]]
        if st["loop"]:
            lines.append("- Seamless loop: the step from the last sample to the first is %d LSB, against %d LSB for the"
                         " music's own 99.9th-percentile sample step; the steps around the seam average %.2fx the track's."
                         " Listen to `seams/%s_seam.wav` (the last 3 s, then the first 3 s)." % (
                             st["seam_step_lsb"], st["p999_step_lsb"], st["seam_window_vs_track"], st["name"]))
        else:
            lines.append("- The hit (for the end card) lands at %.2f s. The trailer pipeline renders a copy fitted to each"
                         " draft's end card instead (`python tools/make_music.py --fit ...`)." % st["hit"])
        if st["limited_db"] > 0.05:
            lines.append("- Peak limiting: up to %.1f dB on the loudest peaks." % st["limited_db"])
        lines.append("")
    (OUT / "README.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pieces", nargs="*", help="hub_A hub_B hub_C trailer_1 trailer_2 (default: all)")
    p.add_argument("--fit", help="render one trailer track fitted to a video (needs --hit, --length, --out)")
    p.add_argument("--hit", type=float, help="seconds: where the final hit lands (the end card's start)")
    p.add_argument("--length", type=float, help="seconds: the video's length (ring-out = length - hit)")
    p.add_argument("--out", help="output WAV for --fit")
    p.add_argument("--ffmpeg")
    p.add_argument("--verbose", action="store_true", help="print each bus's level")
    p.add_argument("-j", "--jobs", type=int, default=0)
    args = p.parse_args()
    ffmpeg = find_ffmpeg(args.ffmpeg)
    if args.fit:
        if args.fit not in TRAILERS or args.hit is None or args.length is None or not args.out:
            sys.exit("--fit needs a trailer name (%s), --hit, --length and --out" % ", ".join(TRAILERS))
        st = render(args.fit, ffmpeg, Path(args.out), hit=args.hit, ring=max(1.5, args.length - args.hit), extras=False, verbose=args.verbose)
        print(json.dumps({k: st[k] for k in ("lufs", "tp", "bpm", "hit", "seconds")}))
        return
    names = args.pieces or list(PIECES)
    bad = [n for n in names if n not in PIECES]
    if bad:
        sys.exit("unknown piece(s): %s (have %s)" % (", ".join(bad), ", ".join(PIECES)))
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = args.jobs or min(len(names), max(1, (os.cpu_count() or 2) // 2))
    if jobs > 1 and not args.verbose:
        from multiprocessing import Pool
        with Pool(jobs) as pool:
            results = pool.map(_job, [(n, ffmpeg) for n in names])
    else:
        results = [render(n, ffmpeg, OUT / ("%s.wav" % n), verbose=args.verbose) for n in names]
    stats_path = OUT / "stats.json"
    old = json.loads(stats_path.read_text(encoding="utf-8")) if stats_path.exists() else {}
    old.update({st["name"]: st for st in results})
    stats_path.write_text(json.dumps(old, indent=1), encoding="utf-8")
    write_readme([old[n] for n in PIECES if n in old])


if __name__ == "__main__":
    main()
