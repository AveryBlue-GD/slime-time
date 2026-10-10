"""Generates the game's retro sound effects as WAV files (no dependencies).

Run from the project root:  python tools/make_sounds.py
Writes assets/sounds/<name>.wav (22.05 kHz, 16-bit mono). Tweak the recipes below and rerun.
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
RATE = 22050


def tone(freq_start: float, freq_end: float, seconds: float, wave_shape="square", volume=0.5,
         attack=0.005, release=0.05, vibrato=0.0) -> list[float]:
    """A pitch slide from freq_start to freq_end with a quick attack and release."""
    samples, phase = [], 0.0
    count = int(seconds * RATE)
    for i in range(count):
        t = i / count
        freq = freq_start * (freq_end / freq_start) ** t
        freq *= 1.0 + vibrato * math.sin(i / RATE * 2 * math.pi * 9)
        phase += freq / RATE
        p = phase % 1.0
        value = {
            "square": 1.0 if p < 0.5 else -1.0,
            "triangle": 4 * abs(p - 0.5) - 1,
            "sine": math.sin(phase * 2 * math.pi),
        }[wave_shape]
        samples.append(value * volume * envelope(i, count, attack, release))
    return samples


def noise(seconds: float, volume=0.5, smoothing=0.5, attack=0.002, release=0.1, seed=1) -> list[float]:
    """Low-passed white noise: smoothing near 1 = dull thud, near 0 = hiss."""
    rng = random.Random(seed)
    samples, last = [], 0.0
    count = int(seconds * RATE)
    for i in range(count):
        last = last * smoothing + rng.uniform(-1, 1) * (1 - smoothing)
        samples.append(last * volume * 2.5 * envelope(i, count, attack, release))
    return samples


def envelope(i: int, count: int, attack: float, release: float) -> float:
    t = i / RATE
    left = (count - i) / RATE
    return min(1.0, t / attack if attack else 1.0, left / release if release else 1.0)


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def seq(*parts: list[float]) -> list[float]:
    return [s for part in parts for s in part]


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))
    print(f"wrote assets/sounds/{name}.wav ({len(samples) / RATE:.2f}s)")


SOUNDS = {
    # Soft wet blip while gliding (played every few frames of the glide cycle).
    "squish": lambda: mix(noise(0.06, 0.25, smoothing=0.85, release=0.04, seed=3),
                          tone(180, 120, 0.06, "sine", 0.2, release=0.04)),
    # Rising hum while the jump charges (stopped on release).
    "charge": lambda: tone(160, 520, 1.5, "triangle", 0.22, attack=0.05, release=0.05, vibrato=0.02),
    "jump": lambda: tone(220, 700, 0.14, "square", 0.25, release=0.06),
    "land": lambda: mix(noise(0.1, 0.35, smoothing=0.9, release=0.08, seed=5), tone(140, 70, 0.1, "sine", 0.4)),
    "splat": lambda: mix(noise(0.22, 0.5, smoothing=0.7, release=0.18, seed=7), tone(320, 70, 0.2, "square", 0.18)),
    "chalice": lambda: seq(*(tone(f, f, 0.09, "square", 0.22, release=0.03) for f in (523, 659, 784, 1047)),
                           tone(1047, 1047, 0.25, "triangle", 0.25, release=0.2)),
    "unlock": lambda: seq(*(tone(f, f * 1.01, 0.06, "triangle", 0.25, release=0.03) for f in (1175, 1568, 1319, 1760, 2093)),
                          tone(2093, 2093, 0.3, "sine", 0.2, release=0.28)),
    "dry": lambda: tone(420, 90, 0.7, "square", 0.2, release=0.3, vibrato=0.04),
    "click": lambda: tone(880, 880, 0.03, "square", 0.15, release=0.015),
    "pause": lambda: seq(tone(660, 660, 0.05, "square", 0.15, release=0.02), tone(440, 440, 0.07, "square", 0.15, release=0.04)),
}


if __name__ == "__main__":
    for sound_name, recipe in SOUNDS.items():
        write(sound_name, recipe())
