"""Synthesised sound effects for Punchy. numpy only, no samples.

    python tools/gen_sfx.py

Weight comes from layering: a sub-bass drop (the body you feel), a hard
transient (plastic crack), and a material tail (rattle, ring, roar). Writes
16-bit mono 44.1 kHz WAVs to assets/sfx/. Helper style follows Toddlerfall's
generator.
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_of(dur):
    return np.arange(int(SR * dur), dtype=np.float64) / SR


def env(t, attack=0.002, power=2.0):
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    rel = np.clip(1.0 - (t - attack) / max(t[-1] - attack, 1e-5), 0, 1) ** power
    return a * rel


def expdecay(t, tau):
    return np.exp(-t / tau)


def sweep(f0, f1, t, curve=1.0):
    k = (t / max(t[-1], 1e-6)) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(n):
    return rng.uniform(-1, 1, n)


def onepole(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        out[i] = acc
    return out


def lowpass(x, cutoff, passes=2):
    for _ in range(passes):
        x = onepole(x, cutoff)
    return x


def highpass(x, cutoff):
    return x - onepole(x, cutoff)


def resonant(x, freq, q=8.0):
    w = 2 * np.pi * freq / SR
    r = np.exp(-w / (2 * q))
    a1, a2 = 2 * r * np.cos(w), -r * r
    out = np.zeros_like(x)
    for i in range(2, len(x)):
        out[i] = x[i] + a1 * out[i - 1] + a2 * out[i - 2]
    return out * (1 - r)


def pad(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def at(x, offset, dur):
    """x placed `offset` seconds into a buffer of length dur."""
    o = int(SR * offset)
    return pad(np.concatenate([np.zeros(o), x]), dur)


def softclip(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    n = min(len(x), int(SR * 0.002))
    x[:n] *= np.linspace(0, 1, n)
    x[-n * 4:] *= np.linspace(1, 0, n * 4)
    m = float(np.max(np.abs(x))) or 1.0
    x = x / m * peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("  %-16s %5.2f s" % (name, len(x) / SR))


# ----------------------------------------------------------------- building blocks
def boom(dur, f0, f1, tau):
    t = t_of(dur)
    return sweep(f0, f1, t, 0.5) * expdecay(t, tau)


def crack(dur, freq, q=4.0, tau=0.02):
    t = t_of(dur)
    return resonant(noise(len(t)), freq, q) * expdecay(t, tau)


def whoosh(dur, f_lo, f_hi, rise=0.6):
    t = t_of(dur)
    n = noise(len(t))
    # sweep a resonant band by chunking: cheap and smooth enough
    out = np.zeros_like(n)
    chunks = 24
    size = len(n) // chunks + 1
    for c in range(chunks):
        k = c / (chunks - 1)
        f = f_lo + (f_hi - f_lo) * (k / rise if k < rise else 1 - (k - rise) / (1 - rise) * 0.5)
        sl = slice(c * size, (c + 1) * size)
        out[sl] = resonant(n[sl], max(f, 80), 1.5)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return out * shape


def rattle(dur, count, f_lo, f_hi, spread=1.0):
    t = t_of(dur)
    out = np.zeros_like(t)
    for _ in range(count):
        o = rng.uniform(0, spread * dur * 0.7)
        f = rng.uniform(f_lo, f_hi)
        c = crack(0.04, f, q=6.0, tau=0.008) * rng.uniform(0.3, 1.0)
        out += at(c, o, dur)
    return out


def roar(dur, cutoff=900, crackle=0.25):
    t = t_of(dur)
    n = lowpass(noise(len(t)), cutoff)
    pops = (rng.uniform(0, 1, len(t)) > 0.9985) * rng.uniform(-1, 1, len(t))
    pops = resonant(pops, 2500, 3) * 6
    return n * 3 + pops * crackle


# ----------------------------------------------------------------- the set
def make():
    print("Punchy sfx ->", os.path.abspath(OUT))
    for i, (f0, cf) in enumerate(((120, 2600), (105, 3100), (135, 2300))):
        d = 0.32
        x = boom(d, f0, 45, 0.07) * 1.2 + crack(d, cf, 3.0, 0.012) * 0.9 + lowpass(noise(int(SR * d)), 1200) * expdecay(t_of(d), 0.03) * 1.5
        save("hit_%d" % i, softclip(x, 2.0))
    d = 0.7
    x = boom(d, 90, 32, 0.18) * 1.5 + crack(d, 1900, 2.5, 0.02) + rattle(d, 10, 1500, 4500) * 0.4
    save("hit_heavy", softclip(x, 2.5))
    d = 0.5
    t = t_of(d)
    ring = sum(np.sin(2 * np.pi * f * t) * expdecay(t, tau) for f, tau in ((880, 0.18), (1397, 0.12), (2213, 0.08), (3150, 0.05)))
    save("block", ring * 0.6 + crack(d, 4000, 2.0, 0.006) * 1.2)
    d = 0.9
    save("shatter", boom(d, 140, 50, 0.06) * 0.8 + rattle(d, 34, 1200, 5200) * 0.8 + crack(d, 2800, 3, 0.02))
    for i, (lo, hi, d) in enumerate(((500, 2400, 0.2), (600, 2800, 0.18))):
        save("swing_%d" % i, whoosh(d, lo, hi))
    save("swing_heavy", whoosh(0.32, 300, 1600, 0.7))
    save("enemy_swing", whoosh(0.28, 250, 1100, 0.7))
    d = 0.35
    t = t_of(d)
    save("warn", (np.sin(2 * np.pi * 2093 * t) + 0.6 * np.sin(2 * np.pi * 3136 * t)) * expdecay(t, 0.09))
    d = 0.6
    t = t_of(d)
    shing = (np.sin(2 * np.pi * 1760 * t) + 0.7 * np.sin(2 * np.pi * 2637 * t) + 0.4 * np.sin(2 * np.pi * 3520 * t)) * expdecay(t, 0.15)
    save("counter", shing * 0.7 + crack(d, 3500, 2, 0.01) + boom(d, 110, 40, 0.08))
    d = 0.4
    save("hurt", softclip(boom(d, 150, 60, 0.06) + crack(d, 1500, 2.0, 0.03) * 0.8, 2.0))
    save("jump", whoosh(0.16, 400, 1800, 0.4) * 0.7)
    save("double_jump", whoosh(0.32, 500, 2600, 0.5))
    d = 0.3
    save("land", boom(d, 110, 45, 0.04) + lowpass(noise(int(SR * d)), 900) * expdecay(t_of(d), 0.02) * 2)
    d = 0.5
    save("land_hard", softclip(boom(d, 85, 35, 0.12) * 1.3 + rattle(d, 6, 900, 2500) * 0.3, 2.0))
    d = 0.35
    save("dash", roar(d, 1500, 0.4) * env(t_of(d), 0.01, 1.5) + whoosh(d, 600, 2200) * 0.6)
    d = 0.7
    save("rocket", roar(d, 1100, 0.5) * env(t_of(d), 0.02, 1.2) + boom(d, 70, 40, 0.15) * 0.6)
    d = 0.9
    save("flame", roar(d, 1400, 0.6) * env(t_of(d), 0.03, 1.0) * 1.2 + boom(d, 60, 35, 0.2) * 0.5)
    d = 1.0
    save("slam", softclip(boom(d, 70, 25, 0.3) * 1.6 + roar(d, 900, 0.5) * env(t_of(d), 0.01, 2.0) * 0.6 + rattle(d, 14, 900, 3000) * 0.3, 2.5))
    d = 0.25
    t = t_of(d)
    save("grapple_fire", sweep(600, 2400, t, 0.6) * expdecay(t, 0.08) * 0.5 + whoosh(d, 900, 3000) * 0.6)
    d = 0.3
    t = t_of(d)
    save("grapple_hit", sum(np.sin(2 * np.pi * f * t) * expdecay(t, 0.05) for f in (1250, 1910, 2780)) * 0.5 + crack(d, 3000, 3, 0.008))
    for i, f in enumerate((2600, 3300)):
        save("step_%d" % i, crack(0.08, f, 5.0, 0.01) * 0.8 + boom(0.08, 160, 80, 0.015) * 0.4)
    d = 0.9
    t = t_of(d)
    chime = sum(at(np.sin(2 * np.pi * f * t_of(0.5)) * expdecay(t_of(0.5), 0.15), o, d) for f, o in ((1319, 0.0), (1568, 0.07), (2093, 0.14), (2637, 0.21)))
    save("star", chime)
    d = 0.3
    save("shot", softclip(crack(d, 1700, 2.5, 0.012) * 1.4 + boom(d, 240, 90, 0.025) * 0.7 + whoosh(d, 1500, 3500, 0.2) * 0.3, 1.8))
    d = 0.6
    save("barrier", softclip(boom(d, 70, 40, 0.2) + rattle(d, 8, 600, 1800) * 0.5, 1.8))


if __name__ == "__main__":
    make()
