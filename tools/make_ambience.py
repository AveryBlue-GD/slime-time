"""Generates a looping ambient sound bed for every level theme (no dependencies).

Run from the project root:  python tools/make_ambience.py
Writes assets/sounds/ambient_<theme>.wav (22.05 kHz, 16-bit mono, LOOP seconds, seamless).
The game plays the current theme's bed quietly under the effects (game.gd AMBIENT_VOLUME_DB).

Each bed is a quiet continuous layer (filtered noise wind/water/rumble, or a drone) plus
scattered distant events (drips, bubbles, chimes, crackles), with a simple echo so the events
sound far off in a big space. Events are placed with a fixed seed, so reruns give the same file.
"""
import math
import random

from make_sounds import RATE, bubble, mix, write

LOOP = 16.0
## Extra time rendered past the loop and cross-faded into its start, so it loops seamlessly.
TAIL = 1.5
## All beds are normalized to about this loudness (RMS), so themes sit at the same level.
TARGET_RMS = 0.11

SAMPLES = int((LOOP + TAIL) * RATE)


# ---------------------------------------------------------------- building blocks

def silence() -> list[float]:
    return [0.0] * SAMPLES


def noise_lp(smooth: float, seed: int, gain: float = 1.0) -> list[float]:
    """Noise through a one-pole low-pass (smooth near 1 = darker, rumblier)."""
    rng = random.Random(seed)
    out, y = [], 0.0
    for _ in range(SAMPLES):
        y = y * smooth + rng.uniform(-1, 1) * (1 - smooth)
        out.append(y)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * gain for s in out]


def band(low_smooth: float, high_smooth: float, seed: int, gain: float = 1.0) -> list[float]:
    """Band-passed noise: a brighter low-pass minus a darker one (wind, hiss, running water)."""
    a = noise_lp(low_smooth, seed)
    b = noise_lp(high_smooth, seed)
    out = [x - y for x, y in zip(a, b)]
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * gain for s in out]


def swell(track: list[float], rate: float, depth: float, phase: float = 0.0) -> list[float]:
    """Slow loudness changes (gusts, waves). Rates are whole cycles per loop so it stays seamless."""
    cycles = max(1, round(rate * LOOP))
    return [s * (1 - depth + depth * (0.5 + 0.5 * math.sin(2 * math.pi * (cycles * i / (LOOP * RATE)) + phase)))
            for i, s in enumerate(track)]


def drone(freqs: list[float], gain: float, wobble: float = 0.003) -> list[float]:
    """A soft sustained chord of sines, each slowly wavering."""
    out = []
    phases = [0.0] * len(freqs)
    for i in range(SAMPLES):
        t = i / RATE
        value = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * (1 + wobble * math.sin(2 * math.pi * (0.13 + 0.07 * k) * t)) / RATE
            value += math.sin(phases[k] * 2 * math.pi)
        out.append(value / len(freqs) * gain)
    return out


def drip(freq: float, gain: float) -> list[float]:
    """A water drip: a sharp plink that rises in pitch and dies fast."""
    count = int(0.09 * RATE)
    out, phase = [], 0.0
    for i in range(count):
        t = i / count
        phase += freq * (1 + 0.8 * t) / RATE
        out.append(math.sin(phase * 2 * math.pi) * gain * (1 - t) ** 3)
    return out


def chime(freq: float, gain: float, decay: float = 1.2, partials=(1.0, 2.76, 5.4)) -> list[float]:
    """A struck glassy/icy chime: inharmonic partials ringing out."""
    count = int(decay * 1.4 * RATE)
    out = []
    for i in range(count):
        t = i / RATE
        value = sum(math.sin(2 * math.pi * freq * p * t) * math.exp(-t * (2.5 + p) / decay) / (k + 1)
                    for k, p in enumerate(partials))
        out.append(value * gain * min(1.0, i / 30))
    return out


def crackle(gain: float, seed: int, length: float = 0.25) -> list[float]:
    """A short burst of crackles (embers, gravel, bones)."""
    rng = random.Random(seed)
    count = int(length * RATE)
    out = [0.0] * count
    for _ in range(rng.randint(4, 9)):
        at = rng.randrange(0, count - 200)
        for j in range(rng.randint(20, 90)):
            out[at + j] += rng.uniform(-1, 1) * gain * (1 - j / 90)
    return out


def scatter(track: list[float], sound, count: int, seed: int) -> None:
    """Adds `count` copies of sound(rng) at random times within the loop."""
    rng = random.Random(seed)
    for _ in range(count):
        clip = sound(rng)
        start = rng.randrange(0, int(LOOP * RATE))
        for j, s in enumerate(clip):
            if start + j < SAMPLES:
                track[start + j] += s


def echo(track: list[float], delay: float, feedback: float, wet: float) -> list[float]:
    """A feedback delay: events repeat, quieter each time, like in a big stone hall."""
    d = int(delay * RATE)
    buf = list(track)
    for i in range(d, SAMPLES):
        buf[i] += buf[i - d] * feedback
    return [dry * (1 - wet) + w * wet for dry, w in zip(track, buf)]


def muffle(track: list[float], smooth: float) -> list[float]:
    """Low-pass a whole layer (distance, water)."""
    out, y = [], 0.0
    for s in track:
        y = y * smooth + s * (1 - smooth)
        out.append(y)
    return out


def finish(name: str, *layers: list[float]) -> None:
    """Mixes the layers, folds the tail into the start for a seamless loop, sets the loudness."""
    full = mix(*layers)
    loop_n, tail_n = int(LOOP * RATE), int(TAIL * RATE)
    out = full[:loop_n]
    for i in range(tail_n):
        fade = i / tail_n
        out[i] = out[i] * fade + full[loop_n + i] * (1 - fade)
    rms = math.sqrt(sum(s * s for s in out) / len(out)) or 1.0
    scale = TARGET_RMS / rms
    peak = max(abs(s) for s in out) * scale
    if peak > 0.95:
        scale *= 0.95 / peak
    # write() only scales down sounds louder than full scale, so this loudness is kept.
    write(f"ambient_{name}", [s * scale for s in out])


# ---------------------------------------------------------------- the beds

def dungeon():
    """Dank Dungeon: a low draft through the halls and slow water drips echoing off stone."""
    wind = swell(band(0.96, 0.995, 1, 0.5), 0.19, 0.6)
    drips = silence()
    scatter(drips, lambda r: drip(r.uniform(900, 1500), 0.5), 9, 2)
    finish("dungeon", wind, echo(drips, 0.23, 0.45, 0.6), noise_lp(0.997, 3, 0.25))


def mossy():
    """Mossy Mines: damp, close air, steady trickles and drips, a far-off creak of old timber."""
    trickle = swell(band(0.7, 0.93, 4, 0.25), 0.25, 0.4)
    drips = silence()
    scatter(drips, lambda r: drip(r.uniform(700, 1300), 0.55), 16, 5)
    creaks = silence()
    scatter(creaks, lambda r: muffle(drone([r.uniform(70, 110), r.uniform(140, 160)], 0.3, wobble=0.04)[:int(0.8 * RATE)], 0.9), 2, 6)
    finish("mossy", trickle, echo(drips, 0.17, 0.35, 0.5), creaks, noise_lp(0.996, 7, 0.2))


def sandstone():
    """Sandstone Sanctum: dry desert wind moaning through the halls, sand hissing as it trickles."""
    wind = swell(band(0.9, 0.99, 8, 0.6), 0.12, 0.75)
    howl = swell(drone([180, 270], 0.12, wobble=0.02), 0.12, 0.8, 1.0)
    sand = silence()
    scatter(sand, lambda r: [s * (1 - j / 6000) for j, s in enumerate(band(0.2, 0.6, r.randrange(999), 0.12)[:6000])], 6, 9)
    finish("sandstone", wind, howl, sand)


def sunken():
    """Sunken Shrine: underwater hush, slow swells, bubbles drifting up from the deep."""
    water = swell(noise_lp(0.993, 10, 0.6), 0.25, 0.6)
    bubbles = silence()
    scatter(bubbles, lambda r: bubble(r.uniform(180, 420), r.uniform(0.06, 0.12), 0.4, rise=2.6), 26, 11)
    finish("sunken", water, muffle(bubbles, 0.6), drone([55, 82.5], 0.12))


def sewers():
    """Toxic Tunnels: running sewage, toxic sludge bubbling, drips plopping into the muck."""
    flow = swell(band(0.8, 0.97, 12, 0.45), 0.31, 0.3)
    sludge = silence()
    scatter(sludge, lambda r: bubble(r.uniform(90, 200), r.uniform(0.08, 0.16), 0.55, rise=1.6), 34, 13)
    drips = silence()
    scatter(drips, lambda r: drip(r.uniform(500, 900), 0.4), 8, 14)
    finish("sewers", flow, muffle(sludge, 0.5), echo(drips, 0.19, 0.4, 0.5))


def catacombs():
    """Creepy Catacombs: an eerie low moan, a cold draft, bones rattling somewhere far off."""
    moan = swell(drone([73.4, 77.8, 110], 0.28, wobble=0.01), 0.19, 0.7)
    draft = swell(band(0.95, 0.995, 15, 0.3), 0.12, 0.6, 2.0)
    bones = silence()
    scatter(bones, lambda r: crackle(0.35, r.randrange(999), 0.3), 4, 16)
    finish("catacombs", moan, draft, echo(muffle(bones, 0.4), 0.29, 0.4, 0.6))


def frozen():
    """Frozen Fortress: a thin icy wind whistling, ice shards breaking off and tinkling far away."""
    wind = swell(band(0.55, 0.9, 17, 0.35), 0.19, 0.7)
    whistle = swell(drone([880, 1320], 0.03, wobble=0.02), 0.12, 0.9, 0.5)
    shards = silence()
    scatter(shards, lambda r: [s for k in range(r.randint(2, 4))
                               for s in chime(r.uniform(1800, 3200), 0.14, 0.4)[:int(r.uniform(0.04, 0.1) * RATE)]]
            + chime(r.uniform(1500, 2600), 0.12, 0.7), 7, 18)
    finish("frozen", wind, whistle, echo(shards, 0.31, 0.45, 0.6), noise_lp(0.997, 19, 0.15))


def obsidian():
    """Obsidian Oubliette: a deep resonant hum in the black glass, the odd glassy ping."""
    hum = swell(drone([49, 98, 147], 0.35, wobble=0.004), 0.06, 0.4)
    pings = silence()
    scatter(pings, lambda r: chime(r.uniform(600, 1100), 0.12, 1.6, partials=(1.0, 2.0, 3.01)), 4, 20)
    finish("obsidian", hum, echo(pings, 0.37, 0.5, 0.6), noise_lp(0.998, 21, 0.15))


def crystal():
    """Crystal Caverns: shimmering crystal chimes (a soft pentatonic sparkle) over a gentle hum."""
    hum = drone([110, 165], 0.15, wobble=0.006)
    notes = [523, 587, 659, 784, 880, 1047, 1175]
    chimes = silence()
    scatter(chimes, lambda r: chime(r.choice(notes), 0.13, 1.8), 12, 22)
    finish("crystal", hum, echo(chimes, 0.33, 0.45, 0.55), swell(band(0.9, 0.99, 23, 0.12), 0.12, 0.6))


def volcanic():
    """Volcanic Vault: thick magma bubbling and blorping, a deep rumble, embers crackling."""
    rumble = swell(noise_lp(0.997, 24, 0.7), 0.12, 0.4)
    magma = silence()
    scatter(magma, lambda r: bubble(r.uniform(60, 130), r.uniform(0.12, 0.25), 0.6, rise=1.4), 28, 25)
    embers = silence()
    scatter(embers, lambda r: crackle(0.18, r.randrange(999), 0.2), 9, 26)
    finish("volcanic", rumble, muffle(magma, 0.45), embers)


if __name__ == "__main__":
    for bed in (dungeon, mossy, sandstone, sunken, sewers, catacombs, frozen, obsidian, crystal, volcanic):
        bed()
