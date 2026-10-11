"""Generates the level ambience (no dependencies).

Run from the project root:  python tools/make_ambience.py

Every theme has a continuous, seamless loop (assets/sounds/ambient_<theme>.wav). The Sunken
Shrine's waves and the Sandstone Sanctum's sandstorm are played fairly loud; the rest are very
faint and built from tones, resonance and water textures rather than plain noise: a moaning
draft, an underground stream, a ghostly choir, a singing icy wind, a glassy hum, shimmering
crystals, a magma rumble (game.gd AMBIENT_BED_DB).
On top of that each theme has a few distant one-off sounds the game plays now and then at
random (game.gd AMBIENT_EVENT_GAP):
- assets/sounds/ambient_<theme>_<n>.wav  (n = 0, 1, 2, ...)

Events get a long echo so they sound far off in a big space. Everything uses fixed seeds, so
reruns give the same files. 22.05 kHz, 16-bit mono.
"""
import math
import random
from pathlib import Path

from make_sounds import OUT, RATE, bubble, mix, write

## Continuous beds: loop length, and extra time rendered and cross-faded into the start.
LOOP = 24.0
TAIL = 2.0
BED_RMS = 0.11
## One-off events are normalized to this peak (the game sets their final, quiet level).
EVENT_PEAK = 0.8


# ---------------------------------------------------------------- building blocks

def noise_lp(n: int, smooth: float, seed: int) -> list[float]:
    """Noise through a one-pole low-pass (smooth near 1 = darker, rumblier), peak 1."""
    rng = random.Random(seed)
    out, y = [], 0.0
    for _ in range(n):
        y = y * smooth + rng.uniform(-1, 1) * (1 - smooth)
        out.append(y)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak for s in out]


def band(n: int, low_smooth: float, high_smooth: float, seed: int) -> list[float]:
    """Band-passed noise: a brighter low-pass minus a darker one, peak 1."""
    out = [a - b for a, b in zip(noise_lp(n, low_smooth, seed), noise_lp(n, high_smooth, seed))]
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak for s in out]


def lowpass(track: list[float], smooth: float) -> list[float]:
    out, y = [], 0.0
    for s in track:
        y = y * smooth + s * (1 - smooth)
        out.append(y)
    return out


def echo(track: list[float], delay: float, feedback: float, wet: float, tail: float) -> list[float]:
    """Feedback delay with `tail` seconds of room for the repeats to ring out."""
    track = track + [0.0] * int(tail * RATE)
    d = int(delay * RATE)
    buf = list(track)
    for i in range(d, len(buf)):
        buf[i] += buf[i - d] * feedback
    return [dry * (1 - wet) + w * wet for dry, w in zip(track, buf)]


def place(track: list[float], clip: list[float], at: float, gain: float = 1.0) -> None:
    start = int(at * RATE)
    for j, s in enumerate(clip):
        if 0 <= start + j < len(track):
            track[start + j] += s * gain


def tone(freq_from: float, freq_to: float, seconds: float, gain: float, attack: float, release: float,
         vibrato: float = 0.0, harmonics=(1.0,)) -> list[float]:
    """A gliding tone with optional vibrato and harmonics (amplitudes per harmonic)."""
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = freq_from * (freq_to / freq_from) ** t
        f *= 1 + vibrato * math.sin(2 * math.pi * 5.5 * i / RATE)
        phase += f / RATE
        value = sum(a * math.sin(2 * math.pi * phase * (k + 1)) for k, a in enumerate(harmonics))
        env = min(1.0, i / (attack * RATE) if attack else 1.0, (n - i) / (release * RATE) if release else 1.0)
        out.append(value * gain * env)
    return out


def chime(freq: float, gain: float, decay: float, partials=(1.0, 2.76, 5.4)) -> list[float]:
    """A struck glassy/icy chime: inharmonic partials ringing out."""
    n = int(decay * 1.4 * RATE)
    return [sum(math.sin(2 * math.pi * freq * p * i / RATE) * math.exp(-(i / RATE) * (2.5 + p) / decay) / (k + 1)
                for k, p in enumerate(partials)) * gain * min(1.0, i / 30) for i in range(n)]


def drip(freq: float, gain: float) -> list[float]:
    n = int(0.09 * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += freq * (1 + 0.8 * t) / RATE
        out.append(math.sin(phase * 2 * math.pi) * gain * (1 - t) ** 3)
    return out


def crackle(seconds: float, gain: float, seed: int, pops: int = 7) -> list[float]:
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out = [0.0] * n
    for _ in range(pops):
        at = rng.randrange(0, max(1, n - 120))
        for j in range(rng.randint(20, 100)):
            if at + j < n:
                out[at + j] += rng.uniform(-1, 1) * gain * (1 - j / 100)
    return out


def blank(seconds: float) -> list[float]:
    return [0.0] * int(seconds * RATE)


# ---------------------------------------------------------------- one-off events

def drips(seed: int) -> list[float]:
    """A few drips into a pool, ringing off the stone."""
    rng = random.Random(seed)
    clip = blank(1.2)
    for k in range(rng.randint(1, 3)):
        place(clip, drip(rng.uniform(800, 1400), 0.6), k * rng.uniform(0.25, 0.45))
    return echo(clip, 0.21, 0.45, 0.6, 1.5)


def stone_scrape(seed: int) -> list[float]:
    """Somewhere far away, a heavy stone shifts."""
    n = int(1.4 * RATE)
    grind = band(n, 0.9, 0.99, seed)
    env = [math.sin(math.pi * i / n) ** 2 for i in range(n)]
    return echo(lowpass([g * e * 0.7 for g, e in zip(grind, env)], 0.6), 0.27, 0.4, 0.5, 1.5)


def timber_creak(seed: int) -> list[float]:
    """An old mine beam creaking under the weight."""
    rng = random.Random(seed)
    base = rng.uniform(70, 110)
    creak = tone(base, base * rng.uniform(1.15, 1.35), rng.uniform(0.6, 1.0), 0.6, 0.15, 0.25,
                 vibrato=0.04, harmonics=(1.0, 0.6, 0.4, 0.25))
    return echo(lowpass(creak, 0.5), 0.19, 0.35, 0.4, 1.0)


def pebbles(seed: int) -> list[float]:
    """A little trickle of loose stones."""
    return echo(lowpass(crackle(0.8, 0.6, seed, pops=10), 0.4), 0.17, 0.35, 0.45, 1.0)


def sludge(seed: int) -> list[float]:
    """Thick toxic sludge burping up a few fat bubbles."""
    rng = random.Random(seed)
    clip = blank(1.4)
    for k in range(rng.randint(2, 4)):
        place(clip, bubble(rng.uniform(80, 170), rng.uniform(0.1, 0.18), 0.7, rise=1.5), k * rng.uniform(0.15, 0.35))
    return echo(lowpass(clip, 0.45), 0.19, 0.35, 0.4, 1.0)


def faint_scream(seed: int) -> list[float]:
    """A very distant, ghostly wail: a voice-like "aah" rising and falling, smeared by echo."""
    rng = random.Random(seed)
    start = rng.uniform(480, 620)
    rise = tone(start, start * rng.uniform(1.4, 1.6), 0.9, 0.5, 0.35, 0.05, vibrato=0.035,
                harmonics=(1.0, 0.7, 0.5, 0.25, 0.12))
    fall = tone(start * 1.5, start * rng.uniform(0.75, 0.9), 1.3, 0.5, 0.05, 0.9, vibrato=0.045,
                harmonics=(1.0, 0.7, 0.5, 0.25, 0.12))
    voice = rise + fall
    breath = band(len(voice), 0.5, 0.9, seed + 1)
    env = [min(1.0, i / (0.4 * RATE), (len(voice) - i) / (0.9 * RATE)) for i in range(len(voice))]
    wail = [v + b * 0.12 * e for v, b, e in zip(voice, breath, env)]
    return echo(lowpass(wail, 0.75), 0.33, 0.55, 0.75, 2.5)


def bone_rattle(seed: int) -> list[float]:
    return echo(lowpass(crackle(0.5, 0.7, seed, pops=8), 0.3), 0.29, 0.4, 0.6, 1.5)


def icicle_drop(seed: int) -> list[float]:
    """An icicle snaps off, falls, and shatters with a spray of tinkling shards."""
    rng = random.Random(seed)
    clip = blank(1.8)
    place(clip, crackle(0.06, 0.5, seed, pops=3), 0.0)  # the snap
    fall = rng.uniform(0.35, 0.6)
    place(clip, chime(rng.uniform(2000, 2800), 0.5, 0.5), fall)  # the hit
    for k in range(rng.randint(5, 8)):  # shards skittering away
        place(clip, chime(rng.uniform(2400, 4200), 0.25, 0.2), fall + 0.03 + k * rng.uniform(0.03, 0.09))
    place(clip, [s * 0.6 for s in crackle(0.3, 0.5, seed + 2, pops=9)], fall)
    return echo(clip, 0.31, 0.45, 0.6, 1.5)


def ice_groan(seed: int) -> list[float]:
    """The ice sheet groaning as it shifts."""
    rng = random.Random(seed)
    base = rng.uniform(55, 80)
    groan = tone(base, base * rng.uniform(0.7, 0.85), 1.5, 0.6, 0.3, 0.5, vibrato=0.06, harmonics=(1.0, 0.5, 0.35))
    return echo(lowpass(groan, 0.6), 0.37, 0.45, 0.5, 1.8)


def glass_ping(seed: int) -> list[float]:
    rng = random.Random(seed)
    return echo(chime(rng.uniform(600, 1100), 0.6, 1.6, partials=(1.0, 2.0, 3.01)), 0.37, 0.5, 0.6, 2.0)


def glass_crack(seed: int) -> list[float]:
    """Black glass cracking: a sharp tick and a short splintering run."""
    clip = crackle(0.25, 0.7, seed, pops=6)
    return echo(clip, 0.33, 0.45, 0.6, 1.5)


def crystal_chimes(seed: int) -> list[float]:
    """A few crystals ringing together (pentatonic, so it always sounds sweet)."""
    rng = random.Random(seed)
    notes = [523, 587, 659, 784, 880, 1047, 1175]
    clip = blank(2.4)
    for k in range(rng.randint(2, 4)):
        place(clip, chime(rng.choice(notes), 0.45, 1.6), k * rng.uniform(0.12, 0.3))
    return echo(clip, 0.33, 0.45, 0.5, 1.5)


CRYSTAL_NOTES = [392, 440, 523, 587, 659, 784, 880, 1047]


def crystal_run(seed: int) -> list[float]:
    """A run of crystals ringing one after another, rising or falling."""
    rng = random.Random(seed)
    first = rng.randrange(0, 4)
    notes = CRYSTAL_NOTES[first:first + rng.randint(3, 5)]
    if rng.random() < 0.5:
        notes = notes[::-1]
    clip = blank(3.0)
    step = rng.uniform(0.12, 0.22)
    for k, f in enumerate(notes):
        place(clip, chime(f, 0.4, rng.uniform(1.2, 1.8)), k * step)
    return echo(clip, 0.33, 0.45, 0.5, 1.5)


def crystal_bell(seed: int) -> list[float]:
    """One big crystal humming a long, deep note."""
    rng = random.Random(seed)
    f = rng.choice(CRYSTAL_NOTES[:3]) / 2
    return echo(chime(f, 0.7, 3.0, partials=(1.0, 2.0, 2.76, 4.1)), 0.41, 0.4, 0.45, 2.0)


def crystal_cluster(seed: int) -> list[float]:
    """Several crystals struck at once, a soft shimmering chord."""
    rng = random.Random(seed)
    clip = blank(3.0)
    for f in rng.sample(CRYSTAL_NOTES, rng.randint(2, 3)):
        place(clip, chime(f, 0.35, rng.uniform(1.8, 2.4)), rng.uniform(0.0, 0.04))
    return echo(clip, 0.37, 0.45, 0.5, 1.5)


def magma_blorp(seed: int) -> list[float]:
    """Thick magma heaving up a big slow bubble that bursts with a pop."""
    rng = random.Random(seed)
    clip = blank(1.6)
    for k in range(rng.randint(1, 3)):
        place(clip, bubble(rng.uniform(50, 110), rng.uniform(0.2, 0.35), 0.8, rise=1.4), k * rng.uniform(0.2, 0.4))
    place(clip, crackle(0.2, 0.3, seed, pops=4), rng.uniform(0.2, 0.6))
    return echo(lowpass(clip, 0.4), 0.23, 0.3, 0.35, 1.0)


def embers(seed: int) -> list[float]:
    return echo(crackle(0.5, 0.45, seed, pops=10), 0.21, 0.3, 0.35, 0.8)


def steam_hiss(seed: int) -> list[float]:
    n = int(1.2 * RATE)
    hiss = band(n, 0.2, 0.7, seed)
    env = [min(1.0, i / (0.05 * RATE)) * (1 - i / n) ** 2 for i in range(n)]
    return echo([h * e * 0.5 for h, e in zip(hiss, env)], 0.23, 0.3, 0.35, 0.8)


def bubble_stream(seed: int) -> list[float]:
    rng = random.Random(seed)
    clip = blank(1.6)
    for k in range(rng.randint(5, 9)):
        place(clip, bubble(rng.uniform(220, 480), rng.uniform(0.05, 0.1), 0.5, rise=2.6), k * rng.uniform(0.08, 0.18))
    return lowpass(clip, 0.55)


def sand_trickle(seed: int) -> list[float]:
    n = int(1.4 * RATE)
    sand = band(n, 0.2, 0.6, seed)
    env = [math.sin(math.pi * i / n) for i in range(n)]
    return [s * e * 0.4 for s, e in zip(sand, env)]


## Each theme's one-off sounds: (recipe, seed) pairs, written as ambient_<theme>_<n>.wav. Every
## recipe randomizes itself from its seed, so the same recipe with another seed is a new variant.
EVENTS = {
    "dungeon": [(drips, 1), (drips, 2), (stone_scrape, 3), (drips, 4), (stone_scrape, 101), (drips, 102),
                (pebbles, 103)],
    "mossy": [(drips, 5), (timber_creak, 6), (pebbles, 7), (timber_creak, 8), (drips, 104), (pebbles, 105),
              (timber_creak, 106)],
    "sandstone": [(sand_trickle, 9), (stone_scrape, 10), (sand_trickle, 107), (stone_scrape, 108), (pebbles, 109),
                  (sand_trickle, 110)],
    "sunken": [(bubble_stream, 11), (bubble_stream, 12), (drips, 13), (bubble_stream, 111), (drips, 112),
               (bubble_stream, 113)],
    "sewers": [(sludge, 14), (sludge, 15), (drips, 16), (sludge, 17), (drips, 114), (sludge, 115), (pebbles, 116)],
    "catacombs": [(faint_scream, 18), (bone_rattle, 19), (faint_scream, 20), (stone_scrape, 21), (bone_rattle, 117),
                  (faint_scream, 118), (bone_rattle, 119)],
    "frozen": [(icicle_drop, 22), (icicle_drop, 23), (ice_groan, 24), (icicle_drop, 25), (ice_groan, 120),
               (icicle_drop, 121), (icicle_drop, 122)],
    "obsidian": [(glass_ping, 26), (glass_crack, 27), (glass_ping, 28), (glass_crack, 123), (glass_ping, 124),
                 (stone_scrape, 125)],
    "crystal": [(crystal_chimes, 29), (crystal_run, 30), (crystal_bell, 31), (crystal_cluster, 126),
                (crystal_run, 127), (crystal_chimes, 128), (crystal_bell, 129)],
    "volcanic": [(magma_blorp, 32), (magma_blorp, 33), (embers, 34), (steam_hiss, 35), (magma_blorp, 130),
                 (embers, 131), (steam_hiss, 132)],
}


# ---------------------------------------------------------------- continuous beds

def waves() -> list[float]:
    """Waves rolling in somewhere beyond the walls: each one a deep swell that builds, breaks with
    a heavy, muffled crash and washes back out. Everything is kept low and soft (heavily
    low-passed), more felt than heard."""
    n = BED_N
    rng = random.Random(40)
    swell_noise = noise_lp(n, 0.995, 41)   # the deep body of the water
    crash_noise = noise_lp(n, 0.97, 42)    # the break: a bit fuller, still dark
    wash_noise = noise_lp(n, 0.93, 43)     # the wash running back over the sand
    count = 4  # waves per loop
    period = LOOP / count
    strengths = [rng.uniform(0.65, 1.0) for _ in range(count)]
    out = []
    for i in range(n):
        t_ = i / RATE
        k = int(t_ // period) % count
        p = (t_ % period) / period  # 0..1 through this wave
        build = (p / 0.45) ** 2 if p < 0.45 else math.exp(-(p - 0.45) * 4)
        crash = math.exp(-((p - 0.47) / 0.07) ** 2)
        wash = 0.0 if p < 0.48 else math.exp(-(p - 0.48) * 2.8) * (1 - math.exp(-(p - 0.48) * 30))
        out.append((swell_noise[i] * (0.25 + 0.75 * build) + crash_noise[i] * crash * 0.8
                    + wash_noise[i] * wash * 0.35) * strengths[k])
    return lowpass(lowpass(out, 0.6), 0.6)


def sandstorm() -> list[float]:
    """A sandstorm blowing past outside: wind howling through the gaps in the stone (noise rung
    through resonant filters, so it moans in pitch as each gust rises and falls) over a low
    rushing roar of sand. Kept low in pitch, no hiss."""
    n = BED_N
    rng = random.Random(50)
    gusts = [(rng.uniform(0, LOOP), rng.uniform(1.8, 3.8), rng.uniform(0.5, 1.0)) for _ in range(6)]

    def gust(t_: float) -> float:
        g = 0.35 + 0.15 * slow(t_, 2)
        for at, width, amp in gusts:
            d = min(abs(t_ - at), abs(t_ - at - LOOP), abs(t_ - at + LOOP))
            g += amp * math.exp(-(d / width) ** 2)
        return min(g, 1.4)

    howl = resonant(noise_lp(n, 0.5, 51), lambda t_: 85 + 110 * gust(t_), 0.06)
    whine = resonant(noise_lp(n, 0.5, 52), lambda t_: 170 + 120 * gust(t_ + 0.7), 0.05)
    roar = noise_lp(n, 0.985, 53)
    out = []
    for i in range(n):
        g = gust(i / RATE)
        out.append(howl[i] * g * 0.55 + whine[i] * g * g * 0.18 + roar[i] * (0.3 + 0.4 * g))
    return lowpass(lowpass(out, 0.7), 0.7)


BED_N = int((LOOP + TAIL) * RATE)


def resonant(track: list[float], center, damping: float) -> list[float]:
    """State-variable band-pass whose center frequency follows center(t) (Hz). Low damping
    makes it ring, turning noise into a pitched moan or whistle."""
    low = band_ = 0.0
    out = []
    for i, x in enumerate(track):
        f = 2 * math.sin(math.pi * min(center(i / RATE), RATE / 6) / RATE)
        low += f * band_
        high = x - low - damping * band_
        band_ += f * high
        out.append(band_)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak for s in out]


def slow(t: float, cycles: int, phase: float = 0.0) -> float:
    """A slow 0..1 wave with a whole number of cycles per loop (so it loops seamlessly)."""
    return 0.5 + 0.5 * math.sin(2 * math.pi * cycles * t / LOOP + phase)


def pad(freqs: list[float], gain: float, harmonics=(1.0,), vibrato=0.003, twinkle=0) -> list[float]:
    """Sustained tones; `twinkle` gives each its own slow fade in and out (shimmer)."""
    out, phases = [], [0.0] * len(freqs)
    for i in range(BED_N):
        t = i / RATE
        value = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * (1 + vibrato * math.sin(2 * math.pi * (0.11 + 0.05 * k) * t)) / RATE
            level = slow(t, twinkle + k % 3, k * 1.7) if twinkle else 1.0
            value += level * sum(a * math.sin(2 * math.pi * phases[k] * (h + 1)) for h, a in enumerate(harmonics))
        out.append(value / len(freqs) * gain)
    return out


def babble(rate: float, low: float, high: float, seed: int, smooth: float) -> list[float]:
    """Running water: a constant stream of tiny bubbles."""
    rng = random.Random(seed)
    out = [0.0] * BED_N
    for _ in range(int(rate * (LOOP + TAIL))):
        place(out, bubble(rng.uniform(low, high), rng.uniform(0.03, 0.07), rng.uniform(0.2, 0.5), rise=2.0),
              rng.uniform(0, LOOP + TAIL))
    return lowpass(out, smooth)


def dungeon_air() -> list[float]:
    """A draft moaning through the corridors over a low, cold drone."""
    moan = resonant(noise_lp(BED_N, 0.6, 60), lambda t: 170 + 140 * slow(t, 3), 0.1)
    return mix([m * (0.4 + 0.6 * slow(i / RATE, 2, 1.0)) for i, m in enumerate(moan)], pad([73.4, 110], 0.35))


def mine_stream() -> list[float]:
    """An underground stream babbling somewhere behind the rock."""
    return mix(babble(40, 220, 620, 61, 0.65), pad([55], 0.25))


def sewer_flow() -> list[float]:
    """Sewage sloshing through the pipes, and the pipes' low hum."""
    hum = pad([60, 120], 0.3, vibrato=0.0)
    return mix(babble(50, 110, 340, 62, 0.55), [h * (0.6 + 0.4 * slow(i / RATE, 4)) for i, h in enumerate(hum)])


def ghost_choir() -> list[float]:
    """A distant ghostly choir holding a minor chord, its vowels slowly shifting."""
    out = []
    phases = [0.0, 0.0, 0.0]
    freqs = [146.8, 174.6, 220.0]
    for i in range(BED_N):
        t = i / RATE
        vowel = slow(t, 2)  # "ooh" (few harmonics) <-> "aah" (more)
        value = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f * (1 + 0.006 * math.sin(2 * math.pi * (4.8 + k * 0.4) * t)) / RATE
            ph = phases[k] * 2 * math.pi
            value += math.sin(ph) + (0.2 + 0.5 * vowel) * math.sin(2 * ph) + 0.3 * vowel * math.sin(3 * ph)
        out.append(value / 3 * (0.5 + 0.5 * slow(t, 3, 0.7)))
    breath = resonant(noise_lp(BED_N, 0.3, 63), lambda t: 700, 0.3)
    return mix(lowpass(out, 0.6), [b * 0.12 for b in breath])


def icy_wind() -> list[float]:
    """Cold wind moaning over the ice: a low, hollow whistle drifting in pitch, a faint frosty shimmer."""
    whistle = resonant(noise_lp(BED_N, 0.4, 64), lambda t: 260 + 180 * slow(t, 3) + 50 * slow(t, 7, 2.0), 0.04)
    gust = [w * (0.3 + 0.7 * slow(i / RATE, 2)) for i, w in enumerate(whistle)]
    return lowpass(mix(gust, pad([440, 659], 0.12, twinkle=2)), 0.4)


def glass_hum() -> list[float]:
    """The black glass humming: deep tones beating slowly against each other."""
    return pad([55, 55.6, 110.3, 165], 0.6, harmonics=(1.0, 0.25))


def crystal_shimmer() -> list[float]:
    """Crystals faintly ringing in sympathy: a high, twinkling chord over a soft root."""
    return mix(pad([262, 330, 392, 523, 659], 0.5, twinkle=3), pad([131], 0.25))


def magma_rumble() -> list[float]:
    """Deep below, magma rolling: a low roaring rumble and slow, heavy bubbling."""
    roar = resonant(noise_lp(BED_N, 0.5, 65), lambda t: 70 + 40 * slow(t, 2), 0.15)
    rng = random.Random(66)
    blorps = [0.0] * BED_N
    for _ in range(int(3 * (LOOP + TAIL))):
        place(blorps, bubble(rng.uniform(45, 90), rng.uniform(0.15, 0.3), 0.5, rise=1.3), rng.uniform(0, LOOP + TAIL))
    return mix(roar, lowpass(blorps, 0.5), pad([38], 0.3, vibrato=0.02))


def write_bed(name: str, track: list[float]) -> None:
    """Folds the tail into the start (seamless loop) and sets the loudness."""
    loop_n, tail_n = int(LOOP * RATE), int(TAIL * RATE)
    out = track[:loop_n]
    for i in range(tail_n):
        fade = i / tail_n
        out[i] = out[i] * fade + track[loop_n + i] * (1 - fade)
    rms = math.sqrt(sum(s * s for s in out) / len(out)) or 1.0
    scale = BED_RMS / rms
    peak = max(abs(s) for s in out) * scale
    if peak > 0.95:
        scale *= 0.95 / peak
    write(name, [s * scale for s in out])


def write_event(name: str, clip: list[float]) -> None:
    peak = max(abs(s) for s in clip) or 1.0
    write(name, [s / peak * EVENT_PEAK for s in clip])


if __name__ == "__main__":
    for old in Path(OUT).glob("ambient_*.wav"):  # clear out files from earlier recipes
        old.unlink()
    beds = {"sunken": waves, "sandstone": sandstorm, "dungeon": dungeon_air, "mossy": mine_stream,
            "sewers": sewer_flow, "catacombs": ghost_choir, "frozen": icy_wind, "obsidian": glass_hum,
            "crystal": crystal_shimmer, "volcanic": magma_rumble}
    for theme, recipe in beds.items():
        write_bed(f"ambient_{theme}", recipe())
    for theme, events in EVENTS.items():
        for k, (recipe, seed) in enumerate(events):
            write_event(f"ambient_{theme}_{k}", recipe(seed))
