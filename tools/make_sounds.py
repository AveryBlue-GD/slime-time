"""Generates the game's slimy sound effects as WAV files (no dependencies).

Run from the project root:  python tools/make_sounds.py
Writes assets/sounds/<name>.wav (22.05 kHz, 16-bit mono). Tweak the recipes below and rerun.

Wet sounds are built from "bubbles" (a sine whose pitch sweeps up fast while it dies away, like
a bubble popping in liquid), gloopy pitch bends with wobble, and noise that's heavily muffled
so it reads as a wet thud rather than a hiss.
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
RATE = 22050


def envelope(i: int, count: int, attack: float, release: float) -> float:
    t = i / RATE
    left = (count - i) / RATE
    return min(1.0, t / attack if attack else 1.0, left / release if release else 1.0)


def bloop(freq_start: float, freq_end: float, seconds: float, volume=0.5, wobble=0.0, wobble_rate=7.0,
          attack=0.004, release=0.05, shape="sine") -> list[float]:
    """A gloopy pitch bend; `wobble` adds a wet vibrato."""
    samples, phase = [], 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = i / count
        freq = freq_start * (freq_end / freq_start) ** t
        freq *= 1.0 + wobble * math.sin(i / RATE * 2 * math.pi * wobble_rate)
        phase += freq / RATE
        if shape == "sine":
            value = math.sin(phase * 2 * math.pi)
        else:  # soft triangle: rounder than square, a little brighter than sine
            value = 4 * abs(phase % 1.0 - 0.5) - 1
        samples.append(value * volume * envelope(i, count, attack, release))
    return samples


def bubble(freq: float, seconds=0.05, volume=0.5, rise=2.2) -> list[float]:
    """One bubble pop: pitch sweeps up by `rise` times while the sound decays fast."""
    samples, phase = [], 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = i / count
        phase += freq * (1.0 + (rise - 1.0) * t * t) / RATE
        samples.append(math.sin(phase * 2 * math.pi) * volume * (1.0 - t) ** 2.5 * min(1.0, i / 40))
    return samples


def gurgle(seconds: float, count: int, low: float, high: float, volume=0.35, seed=1, falling=False) -> list[float]:
    """A run of random bubbles spread over `seconds` (pitches drift down when `falling`)."""
    rng = random.Random(seed)
    track = [0.0] * int(seconds * RATE)
    for k in range(count):
        start = int(rng.uniform(0, seconds * 0.85) * RATE) if not falling else int(k / count * seconds * 0.85 * RATE)
        top = high - (high - low) * (k / count) if falling else rng.uniform(low, high)
        pop = bubble(rng.uniform(low, top) if not falling else top, rng.uniform(0.03, 0.07), volume * rng.uniform(0.6, 1.0))
        for j, s in enumerate(pop):
            if start + j < len(track):
                track[start + j] += s
    return track


def wet_thud(seconds: float, volume=0.4, seed=1, release=0.1) -> list[float]:
    """Noise muffled by two low-pass passes and pulsed, so it sounds like a soft wet slap."""
    rng = random.Random(seed)
    samples, a, b = [], 0.0, 0.0
    count = int(seconds * RATE)
    for i in range(count):
        a = a * 0.94 + rng.uniform(-1, 1) * 0.06
        b = b * 0.94 + a * 0.06
        pulse = 0.7 + 0.3 * math.sin(i / RATE * 2 * math.pi * 38)
        samples.append(b * 14.0 * volume * pulse * envelope(i, count, 0.002, release))
    return samples


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def seq(*parts: list[float]) -> list[float]:
    return [s for part in parts for s in part]


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(s) for s in samples))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * 30000)) for s in samples))
    print(f"wrote assets/sounds/{name}.wav ({len(samples) / RATE:.2f}s)")


SOUNDS = {
    # Soft wet step while gliding: a little downward blup plus a tiny bubble.
    "squish": lambda: mix(bloop(320, 150, 0.07, 0.35, release=0.05), bubble(520, 0.04, 0.15)),
    # Charging: a wobbling, rising gurgle (stopped on release).
    "charge": lambda: mix(bloop(140, 420, 1.5, 0.25, wobble=0.09, wobble_rate=6, attack=0.06, release=0.05),
                          gurgle(1.5, 18, 300, 900, 0.12, seed=4)),
    # Jump: a stretchy upward bloop with a pop as the slime lets go.
    "jump": lambda: mix(bloop(180, 560, 0.16, 0.45, wobble=0.05, release=0.06), bubble(700, 0.05, 0.25)),
    # Landing: a plop.
    "land": lambda: mix(bloop(280, 90, 0.12, 0.5, release=0.08), wet_thud(0.1, 0.3, seed=5, release=0.08)),
    # Splat: a big squelch, a slap, and goo bubbles spraying off.
    "splat": lambda: mix(bloop(420, 60, 0.26, 0.45, wobble=0.12, wobble_rate=22, release=0.15),
                         wet_thud(0.22, 0.5, seed=7, release=0.18),
                         gurgle(0.3, 9, 250, 800, 0.25, seed=8)),
    # Chalice: a bubbly rising arpeggio.
    "chalice": lambda: seq(*(mix(bloop(f, f * 1.02, 0.1, 0.3, shape="tri", release=0.04), bubble(f * 2, 0.04, 0.12))
                             for f in (523, 659, 784, 1047)),
                           bloop(1047, 1060, 0.3, 0.3, wobble=0.02, shape="tri", release=0.25)),
    # Unlock: sparkly bubbles drifting up.
    "unlock": lambda: mix(seq(*(bloop(f, f * 1.03, 0.07, 0.28, shape="tri", release=0.03) for f in (1175, 1568, 1319, 1760, 2093)),
                              bloop(2093, 2093, 0.3, 0.2, wobble=0.015, release=0.28)),
                          gurgle(0.65, 10, 900, 1800, 0.12, seed=9)),
    # Drying up: a sad, sagging gurgle whose bubbles get lower and fewer.
    "dry": lambda: mix(bloop(380, 80, 0.8, 0.3, wobble=0.06, wobble_rate=5, release=0.35),
                       gurgle(0.8, 8, 150, 600, 0.25, seed=11, falling=True)),
    # Menu click: a single bubble pop.
    "click": lambda: bubble(620, 0.05, 0.45, rise=1.8),
    # Pause: two soft bloops, down then lower.
    "pause": lambda: seq(bloop(520, 400, 0.07, 0.35, release=0.03), bloop(380, 260, 0.09, 0.35, release=0.05)),
}


if __name__ == "__main__":
    for sound_name, recipe in SOUNDS.items():
        write(sound_name, recipe())
