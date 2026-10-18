"""Synthesised music for Punchy: two layers of one seamless 16-bar loop.

    python tools/gen_music.py

explore.wav  pad, music-box arpeggio, soft bass -- the toy room at rest
combat.wav   taiko drums, string ostinato, brass stabs, crash -- an arena fight

Both are the same length and tempo (D minor, 100 BPM), so the game plays them
in sync and crossfades the combat layer in and out (scripts/autoload/game.gd).
numpy + scipy only.
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
BPM = 100
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LEN = int(SR * BAR * BARS)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
rng = np.random.default_rng(3)

# two bars per chord: Dm Bb F C | Dm Bb Gm A
CHORDS = [(50, "m"), (46, "M"), (53, "M"), (48, "M"), (50, "m"), (46, "M"), (43, "m"), (45, "M")]


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def triad(root, kind):
    return [root, root + (3 if kind == "m" else 4), root + 7]


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def saw(f, t):
    return 2.0 * ((t * f) % 1.0) - 1.0


def lp(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def adsr(n, a=0.01, r=0.2):
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


class Track:
    def __init__(self):
        self.buf = np.zeros(LEN + SR * 4)

    def add(self, x, at):
        i = int(at * SR)
        self.buf[i:i + len(x)] += x

    def loop(self):
        out = self.buf[:LEN].copy()
        tail = self.buf[LEN:]
        out[:len(tail)] += tail  # wrap ring-outs to the start: a seamless loop
        return out


def chord_at(bar):
    return CHORDS[(bar // 2) % len(CHORDS)]


def explore():
    tr = Track()
    seg = BAR * 2
    for c, (root, kind) in enumerate(CHORDS):
        start = c * seg
        t = t_of(seg + 1.0)
        pad = np.zeros(len(t))
        for n in triad(root + 12, kind):
            for det in (-0.08, 0.08):
                pad += saw(hz(n + det), t)
        pad = lp(pad, 900) * adsr(len(t), 0.8, 1.2) * 0.07
        tr.add(pad, start)
        for beat in (0, 2, 4, 6):
            bt = t_of(BEAT * 2)
            f = hz(root - 12)
            bass = (np.sin(2 * np.pi * f * bt) + 0.3 * np.sin(4 * np.pi * f * bt)) * np.exp(-bt / 0.6) * 0.22
            tr.add(bass, start + beat * BEAT)
    # music box: eighth-note arpeggio, two octaves up, bell-like partials
    for step in range(BARS * 8):
        bar = step // 8
        root, kind = chord_at(bar)
        notes = triad(root + 24, kind) + [root + 36]
        pattern = [0, 1, 2, 3, 2, 1, 2, 0]
        n = notes[pattern[step % 8]]
        if step % 16 in (14, 15) and rng.random() < 0.5:
            continue
        t = t_of(1.2)
        f = hz(n)
        tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.08)
        tr.add(tone * np.exp(-t / 0.45) * 0.09, step * BEAT / 2)
    return tr.loop()


def taiko(big=True):
    t = t_of(0.8)
    f0, f1 = (95, 42) if big else (180, 110)
    k = np.clip(t / 0.25, 0, 1)
    phase = np.cumsum(f0 + (f1 - f0) * k) / SR
    body = np.sin(2 * np.pi * phase) * np.exp(-t / (0.35 if big else 0.12))
    skin = lp(rng.uniform(-1, 1, len(t)), 1200) * np.exp(-t / 0.03)
    return np.tanh((body * 1.2 + skin * 0.5) * 1.8)


def combat():
    tr = Track()
    big, small = taiko(True), taiko(False)
    for bar in range(BARS):
        b0 = bar * BAR
        for beat, s in ((0, 0.55), (1.5, 0.35), (2, 0.5), (3, 0.4), (3.5, 0.3)):
            tr.add(big * s, b0 + beat * BEAT)
        for eighth in range(8):
            if eighth % 2 == 1:
                tr.add(small * (0.18 if eighth != 7 else 0.28), b0 + eighth * BEAT / 2)
        if bar % 8 == 0:
            t = t_of(3.0)
            crash = hp(rng.uniform(-1, 1, len(t)), 5000) * np.exp(-t / 0.9) * 0.12
            tr.add(crash, b0)
    # string ostinato: sixteenths on root / fifth / octave
    pattern = [0, 0, 7, 0, 0, 0, 7, 12, 0, 0, 7, 0, 12, 7, 5, 7]
    for step in range(BARS * 16):
        root, kind = chord_at(step // 16)
        n = root + 12 + pattern[step % 16]
        t = t_of(BEAT / 4 * 1.3)
        f = hz(n)
        x = (saw(f * 0.997, t) + saw(f * 1.003, t)) * adsr(len(t), 0.005, 0.05)
        tr.add(lp(x, 2200) * 0.05, step * BEAT / 4)
    # brass stabs on each chord change, filter swelling open
    for c, (root, kind) in enumerate(CHORDS):
        for hit, length in ((0.0, 1.4), (BAR * 1.5, 0.6)):
            t = t_of(length)
            x = np.zeros(len(t))
            for n in triad(root, kind) + [root + 12]:
                x += saw(hz(n), t) + saw(hz(n) * 1.004, t)
            cut = 500 + 2500 * np.exp(-t / 0.25)
            y = np.zeros(len(t))
            chunk = 512
            for i in range(0, len(t), chunk):
                y[i:i + chunk] = lp(x[i:i + chunk], float(cut[i]))  # cheap moving filter
            tr.add(y * adsr(len(t), 0.02, 0.3) * 0.06, c * BAR * 2 + hit)
    return tr.loop()


def save(name, x, gain=0.85):
    x = np.clip(x * gain, -1.0, 1.0)  # no per-file normalising: keeps the layers balanced
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("  %-10s %5.1f s" % (name, len(x) / SR))


if __name__ == "__main__":
    print("Punchy music ->", os.path.abspath(OUT))
    e = explore()
    c = combat()
    # one shared peak so the two layers keep their balance when mixed in game
    peak = max(np.max(np.abs(e)), np.max(np.abs(e + c)))
    save("explore", e / peak, 0.8)
    save("combat", c / peak, 0.8)
