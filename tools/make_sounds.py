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


def sizzle(seconds: float, volume=0.3, seed=1) -> list[float]:
    """Steam hissing off: bright crackly noise that thins out and fades."""
    rng = random.Random(seed)
    samples, a = [], 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = i / count
        a = a * 0.5 + rng.uniform(-1, 1) * 0.5  # only lightly smoothed: a bright hiss
        spit = 1.0 if rng.random() < 0.08 * (1 - t) else 0.35  # little spits of steam
        samples.append(a * volume * spit * (1 - t) ** 1.5 * min(1.0, i / 200))
    return samples


def metal_ring(freqs, seconds: float, volume=0.15, droop=0.2) -> list[float]:
    """A struck bit of metal (inharmonic partials) whose pitch sags by `droop` as it rings out,
    like it's being eaten away."""
    count = int(seconds * RATE)
    phases = [0.0] * len(freqs)
    samples = []
    for i in range(count):
        t = i / count
        value = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * (1.0 - droop * t) / RATE
            value += math.sin(2 * math.pi * phases[k]) / (k + 1)
        samples.append(value * volume * math.exp(-t * 5.0) * min(1.0, i / 40))
    return samples


def crunch(seconds: float, volume=0.4, seed=1) -> list[float]:
    """A dry crust cracking: a cluster of short, sharp clicks."""
    rng = random.Random(seed)
    count = int(seconds * RATE)
    samples = [0.0] * count
    for _ in range(rng.randint(8, 12)):
        at = rng.randrange(0, count - 150)
        length = rng.randint(30, 120)
        for j in range(length):
            samples[at + j] += rng.uniform(-1, 1) * volume * (1 - j / length) ** 2
    return samples


def chime_tone(freq: float, seconds: float, volume=0.4) -> list[float]:
    """A small bell tone: a pure tone plus a quieter octave, ringing out fast."""
    count = int(seconds * RATE)
    return [(math.sin(2 * math.pi * freq * i / RATE) + 0.35 * math.sin(4 * math.pi * freq * i / RATE))
            * volume * math.exp(-i / RATE * 9) * min(1.0, i / 30) for i in range(count)]


def wind(seconds: float, volume=0.4, seed=1, low=0.03, high=0.22) -> list[float]:
    """Air rushing past: noise through a one-pole low-pass whose cutoff swells from `low` to
    `high` and back, so it rises into a whoosh and falls away."""
    rng = random.Random(seed)
    samples, a, b = [], 0.0, 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = i / count
        cut = low + (high - low) * math.sin(math.pi * t) ** 2
        a = a * (1 - cut) + rng.uniform(-1, 1) * cut
        b = b * (1 - cut) + a * cut
        samples.append(b * 6.0 * volume * math.sin(math.pi * t) ** 1.5)
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


## Pitched low and wet to suit the dungeon: nothing too bright or bouncy.
SOUNDS = {
    # Soft wet step while gliding: a low downward blup plus a tiny bubble.
    "squish": lambda: mix(bloop(220, 105, 0.08, 0.35, release=0.05), bubble(360, 0.04, 0.12)),
    # Charging: a low, wobbling, rising gurgle (stopped on release).
    "charge": lambda: mix(bloop(90, 260, 1.5, 0.25, wobble=0.08, wobble_rate=5, attack=0.08, release=0.05),
                          gurgle(1.5, 16, 180, 520, 0.11, seed=4)),
    # Jump: a heavy, stretchy heave off the floor (a short low rise and a wet unstick).
    "jump": lambda: mix(bloop(115, 240, 0.17, 0.42, wobble=0.04, release=0.07),
                        wet_thud(0.09, 0.18, seed=3, release=0.07), bubble(340, 0.05, 0.14)),
    # Landing: a deep plop.
    "land": lambda: mix(bloop(200, 62, 0.13, 0.5, release=0.09), wet_thud(0.11, 0.32, seed=5, release=0.09)),
    # Splat: a big low squelch, a slap, and goo bubbles spraying off.
    "splat": lambda: mix(bloop(300, 45, 0.28, 0.45, wobble=0.12, wobble_rate=18, release=0.16),
                         wet_thud(0.24, 0.5, seed=7, release=0.2),
                         gurgle(0.3, 9, 160, 500, 0.22, seed=8)),
    # Chalice consumed: two gulps as the slime swallows it, then a low, eerie minor chord swells
    # and fades (A minor, triangle tones with a slow wobble) over sinking bubbles.
    "chalice": lambda: seq(
        bloop(240, 120, 0.12, 0.45, wobble=0.05, release=0.05),
        bloop(200, 85, 0.16, 0.45, wobble=0.05, release=0.08),
        mix(*(bloop(f, f * 0.995, 1.1, 0.16, wobble=0.012, wobble_rate=4.5, attack=0.18, release=0.7, shape="tri")
              for f in (110, 220, 262, 330)),
            gurgle(1.0, 10, 120, 360, 0.12, seed=12, falling=True))),
    # Unlock: mellow bubbles drifting up (a gentle rising phrase, not a fanfare).
    "unlock": lambda: mix(seq(*(bloop(f, f * 1.01, 0.09, 0.26, shape="tri", release=0.04) for f in (294, 349, 392, 440, 523)),
                              bloop(523, 520, 0.35, 0.2, wobble=0.012, release=0.32)),
                          gurgle(0.75, 10, 300, 800, 0.1, seed=9)),
    # Drying up: steam sizzles off the slime, a sad whine sags away, the last bubbles slow down
    # and pop, and the crust cracks as it hardens.
    "dry": lambda: mix(sizzle(1.1, 0.32, seed=21),
                       bloop(520, 140, 1.0, 0.3, wobble=0.07, wobble_rate=5, attack=0.03, release=0.4),
                       gurgle(0.9, 9, 160, 520, 0.24, seed=11, falling=True),
                       [0.0] * int(0.95 * RATE) + crunch(0.35, 0.45, seed=22)),
    # Coin: acid eating into soluble metal: a sharp crackling hiss that eats away, a faint metallic
    # ring that warps down and dies as the coin dissolves, and a fizz of tiny bubbles.
    "coin": lambda: mix(sizzle(0.8, 0.42, seed=51),
                        metal_ring((540, 1310, 2090), 0.55, 0.12, droop=0.25),
                        [0.0] * int(0.06 * RATE) + gurgle(0.6, 22, 700, 1500, 0.06, seed=52)),
    # Upgrade bought: the slime swells with power (a low wobbling surge), a climbing phrase of
    # round tones settles on a held note with a soft ring on top, and bubbles rise through it.
    # The upgrades screen pitches it up a little per level bought.
    "upgrade": lambda: mix(bloop(110, 300, 0.3, 0.34, wobble=0.06, wobble_rate=9, attack=0.03, release=0.1),
                           [0.0] * int(0.12 * RATE) + seq(
                               *(bloop(f, f * 1.01, 0.07, 0.24, shape="tri", release=0.03) for f in (196, 247, 294)),
                               bloop(392, 394, 0.42, 0.22, wobble=0.015, wobble_rate=6, shape="tri", release=0.36)),
                           [0.0] * int(0.33 * RATE) + chime_tone(784, 0.4, 0.1),
                           gurgle(0.6, 12, 260, 700, 0.08, seed=61)),
    # Gold skin, gliding: a little jingle of coins.
    "jingle": lambda: mix(chime_tone(784, 0.12, 0.3), [0.0] * int(0.03 * RATE) + chime_tone(1047, 0.12, 0.22),
                          [0.0] * int(0.06 * RATE) + chime_tone(880, 0.14, 0.18)),
    # A wall giving way (dev wall power): stone crunching apart and rubble pattering down.
    "crumble": lambda: mix(wet_thud(0.35, 0.5, seed=31, release=0.25), crunch(0.5, 0.5, seed=32),
                           bloop(160, 50, 0.3, 0.3, release=0.2)),
    # Menu click: a single low bubble pop.
    "click": lambda: bubble(420, 0.05, 0.45, rise=1.7),
    # Low slime heartbeat: two dull, muffled thumps ("lub-dub"), quiet and low.
    "heartbeat": lambda: seq(mix(bloop(78, 46, 0.11, 0.55, release=0.07), wet_thud(0.08, 0.25, seed=71, release=0.06)),
                             [0.0] * int(0.09 * RATE),
                             mix(bloop(66, 40, 0.1, 0.4, release=0.07), wet_thud(0.07, 0.18, seed=72, release=0.06))),
    # Crossing into low slime: a sagging, sad bloop with a couple of dying bubbles.
    "lowwarn": lambda: mix(bloop(340, 120, 0.4, 0.4, wobble=0.05, wobble_rate=6, release=0.2),
                           gurgle(0.4, 4, 200, 420, 0.14, seed=73, falling=True)),
    # Story intro: a long dark whoosh of air as the slime falls through the mountain.
    "whoosh": lambda: mix(wind(1.6, 0.6, seed=81), bloop(150, 55, 1.6, 0.18, wobble=0.03, wobble_rate=3,
                                                         attack=0.4, release=0.8)),
    # Story intro: the floor splitting: a deep thud and stone cracking apart in a ragged run.
    "crack": lambda: mix(wet_thud(0.3, 0.45, seed=82, release=0.22), crunch(0.45, 0.5, seed=83),
                         [0.0] * int(0.12 * RATE) + crunch(0.4, 0.35, seed=84), bloop(110, 40, 0.4, 0.3, release=0.3)),
    # Story intro: an adventurer's armor clanking as they run (dull, low metal).
    "clank": lambda: mix(metal_ring((260, 618, 990), 0.22, 0.2, droop=0.04), crunch(0.08, 0.25, seed=85)),
    # Story finale: the sun comes up: a soft low swell under three slow, mellow bell notes.
    "sunrise": lambda: mix(bloop(98, 99, 2.2, 0.16, wobble=0.01, wobble_rate=3, attack=0.7, release=1.2, shape="tri"),
                           bloop(147, 148, 2.2, 0.1, attack=0.9, release=1.2, shape="tri"),
                           chime_tone(392, 1.2, 0.2), [0.0] * int(0.35 * RATE) + chime_tone(494, 1.2, 0.17),
                           [0.0] * int(0.7 * RATE) + chime_tone(587, 1.4, 0.15)),
    # Pause: two soft bloops, down then lower.
    "pause": lambda: seq(bloop(360, 280, 0.08, 0.35, release=0.03), bloop(260, 180, 0.1, 0.35, release=0.05)),
}


if __name__ == "__main__":
    for sound_name, recipe in SOUNDS.items():
        write(sound_name, recipe())
