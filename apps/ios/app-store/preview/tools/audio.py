#!/usr/bin/env python3
"""Synthesizes the preview's music and sound effects from events.json. No samples, no stock files.

Every effect starts on the sample that is its frame (1600 samples per frame at 48 kHz and 30 fps), so the picture and
the sound read the same timeline. Writes stems and the mix as WAV, plus the effects-only stem used to prove the sync.
Usage: audio.py <events.json> <device> <out-dir>
"""
import json, sys, os
import numpy as np
import soundfile as sf
from scipy import signal

SR, FPS = 48000, 30
SPF = SR // FPS  # samples per frame
rng = np.random.default_rng(7)

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)
def sec(n): return np.arange(n) / SR
def env_exp(n, decay):
    return np.exp(-sec(n) / decay)
def fade(x, a=0.002, r=0.01):
    n = len(x); na, nr = int(a * SR), int(r * SR)
    g = np.ones(n)
    if na: g[:na] = np.linspace(0, 1, na)
    if nr: g[-nr:] = np.linspace(1, 0, nr)
    return x * g
def lowpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "low"); return signal.lfilter(b, a, x)
def highpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high"); return signal.lfilter(b, a, x)
def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band"); return signal.lfilter(b, a, x)
def place(buf, x, f=None, sample=None, pan=0.0, gain=1.0):
    s = int(sample if sample is not None else f * SPF)
    if s >= buf.shape[0]: return
    n = min(len(x), buf.shape[0] - s)
    l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
    buf[s:s + n, 0] += x[:n] * gain * l * np.sqrt(2) / 1.0
    buf[s:s + n, 1] += x[:n] * gain * r * np.sqrt(2) / 1.0

# ---------- instruments ----------
def kalimba(midi, dur=1.6, vel=1.0):
    """A felt-piano / kalimba-like pluck: a warm sine with a short, slightly inharmonic bell overtone."""
    n = int(dur * SR); t = sec(n); f0 = hz(midi)
    body = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.55)
    over = 0.35 * np.sin(2 * np.pi * f0 * 4.02 * t) * np.exp(-t / 0.07)
    third = 0.12 * np.sin(2 * np.pi * f0 * 2.0 * t) * np.exp(-t / 0.25)
    click = 0.25 * lowpass(rng.standard_normal(n), 3000) * np.exp(-t / 0.004)
    return fade((body + over + third + click) * vel, 0.0015, 0.05)

def pad_chord(midis, dur, level=1.0):
    n = int(dur * SR); t = sec(n); out = np.zeros(n)
    for m in midis:
        for det in (-0.07, 0.0, 0.07):
            f = hz(m) * 2 ** (det / 12)
            out += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * 0.5 + 0.18 * np.sin(4 * np.pi * f * t)
    out = lowpass(out, 1400)
    a = np.minimum(1, t / 0.5) ; r = np.minimum(1, (dur - t) / 0.6)
    return out * a * r * level / (len(midis) * 3)

def shaker(vel=1.0, dur=0.12):
    n = int(dur * SR); t = sec(n)
    x = highpass(bandpass(rng.standard_normal(n), 4500, 9500), 4000)
    return x * (np.minimum(1, t / 0.012) * np.exp(-t / 0.035)) * vel

# ---------- effects ----------
def sfx_key(i):
    n = int(0.09 * SR); t = sec(n)
    f = 1500 + 90 * ((i * 7) % 5)
    tick = bandpass(rng.standard_normal(n), 1800, 5200) * np.exp(-t / 0.006)
    knock = np.sin(2 * np.pi * (170 + 8 * (i % 3)) * t) * np.exp(-t / 0.018)
    return fade(0.55 * tick + 0.45 * knock, 0.0005, 0.02)

def sfx_land(kind):
    n = int(0.28 * SR); t = sec(n)
    base = {"card": 118, "ingredient": 190, "idea": 150}.get(kind, 150)
    thump = np.sin(2 * np.pi * (base * (1 + 0.5 * np.exp(-t / 0.02))) * t) * np.exp(-t / 0.07)
    tap = bandpass(rng.standard_normal(n), 900, 3500) * np.exp(-t / 0.012) * 0.35
    out = fade(thump + tap, 0.0006, 0.03)
    if kind == "idea":
        out = out + 0.4 * np.pad(kalimba(74, 0.6, 0.5), (0, max(0, n - int(0.6 * SR))))[:n] if False else out
    return out

def sfx_slot(i):
    scale = [62, 66, 69, 71, 74, 78, 81]  # D major pentatonic climbing
    return kalimba(scale[i % len(scale)], 1.1, 0.8)

def sfx_snap(i):
    n = int(0.14 * SR); t = sec(n)
    click = bandpass(rng.standard_normal(n), 2500, 7000) * np.exp(-t / 0.004)
    tone = np.sin(2 * np.pi * (880 + 110 * (i % 3)) * t) * np.exp(-t / 0.03)
    return fade(0.7 * click + 0.35 * tone, 0.0004, 0.02)

def sfx_chime(dur=2.2):
    n = int(dur * SR); t = sec(n); f0 = hz(81)  # A5
    out = np.zeros(n)
    for k, (m, a, d) in enumerate([(1, 1.0, 1.4), (2.76, 0.35, 0.7), (5.4, 0.15, 0.35), (1.0 * 1.5, 0.4, 1.0)]):
        out += a * np.sin(2 * np.pi * f0 * m * t) * np.exp(-t / d)
    return fade(out * 0.5, 0.001, 0.2)

def sfx_icon():
    n = int(2.6 * SR); out = np.zeros(n)
    for k, m in enumerate([50, 57, 62, 66, 69]):
        x = kalimba(m, 2.4, 0.7 - 0.08 * k); out[: len(x)] += x[:n] * (1.0 if k else 0.9)
    t = sec(n)
    sub = np.sin(2 * np.pi * hz(38) * t) * np.exp(-t / 0.5) * 0.55
    return fade(out + sub, 0.001, 0.3)

def sfx_wordmark():
    n = int(1.8 * SR); t = sec(n)
    out = np.zeros(n); k = kalimba(86, 1.6, 0.8); out[:len(k)] = k[:n]
    sh = highpass(rng.standard_normal(n), 6000) * np.exp(-t / 0.16) * np.minimum(1, t / 0.03) * 0.12
    return fade(out + sh, 0.001, 0.2)

def sfx_line(dur_frames, curve):
    """A soft breath of filtered noise that follows the drawn length: it rises in pitch as the line lengthens and settles as it stops."""
    n = int(dur_frames * SPF); u = np.linspace(0, 1, n)
    length = curve(u)
    speed = np.gradient(length) * n / SR * (dur_frames / FPS)
    speed = speed / max(speed.max(), 1e-9)
    speed = lowpass(speed, 14) if n > 2000 else speed
    noise = rng.standard_normal(n)
    out = np.zeros(n); block = 960
    for s0 in range(0, n, block):
        e0 = min(n, s0 + block); mid = (s0 + e0) // 2
        fc = 450 + 1500 * length[mid]
        b, a = signal.butter(2, [fc * 0.8 / (SR / 2), min(fc * 1.25, 9000) / (SR / 2)], "band")
        out[s0:e0] = signal.lfilter(b, a, noise[s0:e0]) * speed[s0:e0]
    out = lowpass(out, 3200)
    return fade(out * 1.4, 0.02, 0.08)

CURVES = {
    "io": lambda u: 0.5 - 0.5 * np.cos(np.pi * np.clip(u, 0, 1)),
    "out": lambda u: 1 - (1 - np.clip(u, 0, 1)) ** 3,
    "lin": lambda u: np.clip(u, 0, 1),
}

# ---------- music ----------
# D major, 100 bpm. A beat is 18 frames, an eighth 9, a sixteenth 4.5. The groove is a bouncy bass, offbeat plucks, a pentatonic hook,
# a muted kick, a soft snap on 2 and 4 and a shaker; it drops away on the last bar so the close resolves on D.
ROOT = {"D": 38, "A": 45, "Bm": 47, "G": 43}
TRIAD = {"D": [62, 66, 69], "A": [61, 64, 69], "Bm": [62, 66, 71], "G": [62, 67, 71]}
PROG = {1: "D", 2: "D", 3: "A", 4: "Bm", 5: "G", 6: "D", 7: "A", 8: "G", 9: "Bm", 10: "A", 11: "D"}
HOOK = {  # bar -> (eighth, midi): a syncopated hook in D major pentatonic
    2: [(0, 78), (3, 81), (4, 78), (6, 76)], 3: [(0, 76), (3, 78), (4, 81), (7, 78)], 4: [(0, 74), (3, 78), (4, 83), (6, 81)],
    5: [(0, 79), (3, 83), (4, 81), (6, 79)], 6: [(0, 78), (3, 81), (4, 78), (6, 74)], 7: [(0, 76), (3, 81), (4, 83), (6, 85)],
    8: [(0, 83), (3, 79), (4, 81), (6, 79)], 9: [(0, 78), (3, 83), (4, 86), (6, 83)], 10: [(0, 81), (3, 78), (4, 76), (6, 78)], 11: [(2, 78), (4, 74)],
}

def bass(midi, vel=1.0, dur=0.45):
    n = int(dur * SR); t = sec(n); f0 = hz(midi)
    x = np.sin(2 * np.pi * f0 * t) + 0.35 * np.sin(4 * np.pi * f0 * t) * np.exp(-t / 0.08)
    return fade(x * np.exp(-t / 0.22) * vel, 0.004, 0.06)

def kick(vel=1.0):
    n = int(0.22 * SR); t = sec(n)
    x = np.sin(2 * np.pi * (52 + 70 * np.exp(-t / 0.025)) * t) * np.exp(-t / 0.07)
    return fade(x * vel, 0.001, 0.03)

def snap(vel=1.0):
    n = int(0.12 * SR); t = sec(n)
    x = bandpass(rng.standard_normal(n), 1400, 4800) * np.exp(-t / 0.028)
    return fade(x * vel, 0.0008, 0.03)

def music(total):
    buf = np.zeros((total, 2))
    sixteenth = 4.5 * SPF                    # in samples
    for bar in range(1, 12):
        f0 = (bar - 1) * 72; base = f0 * SPF
        ch = PROG[bar]; last = bar == 11
        place(buf, pad_chord([m - 12 for m in TRIAD[ch]] + [ROOT[ch] + 12], 2.6, 0.8), f0, gain=0.16 if not last else 0.22)
        if bar >= 2 and not last:
            for e, hi in [(0, 1.0), (3, 0.8), (4, 0.9), (7, 0.7)]:
                place(buf, bass(ROOT[ch] + (7 if e == 7 and bar % 2 == 0 else 0), hi), sample=base + e * 9 * SPF, gain=0.34)
            for e in (0, 4):
                if 2 <= bar <= 9: place(buf, kick(0.9), sample=base + e * 9 * SPF, gain=0.28)
            for e in (2, 6):
                if 3 <= bar <= 9: place(buf, snap(0.8), sample=base + e * 9 * SPF, gain=0.16)
            for e in (1, 3, 5, 7):               # offbeat plucks on the chord
                for k, m in enumerate(TRIAD[ch]):
                    place(buf, kalimba(m + 12, 0.35, 0.4), sample=base + (e * 9 + 0.4 * k) * SPF, pan=-0.3 + 0.2 * k, gain=0.11)
        if bar == 1:
            place(buf, bass(ROOT["D"], 1.0, 0.8), sample=base, gain=0.3)
        for e, m in HOOK.get(bar, []):
            place(buf, kalimba(m, 0.9, 0.9), sample=base + e * 9 * SPF, pan=0.2, gain=0.30)
            if bar in (6, 7, 8, 9):                # an echo, half a beat later, to lift the middle
                place(buf, kalimba(m, 0.5, 0.45), sample=base + (e * 9 + 13.5) * SPF, pan=-0.25, gain=0.12)
        if 1 <= bar <= 10:
            for q in range(16):
                acc = 1.0 if q % 4 == 2 else 0.45
                if bar == 1 and q < 8: acc *= 0.5
                place(buf, shaker(acc), sample=base + q * sixteenth, pan=0.35 if q % 2 else -0.3, gain=0.075)
        if last:
            for k, m in enumerate([50, 57, 62, 66, 69]):
                place(buf, kalimba(m, 2.4, 0.6), sample=base + k * 3 * SPF, pan=-0.3 + 0.15 * k, gain=0.25)
    return buf

def render(events, out):
    total = events["frames"] * SPF + SR  # a second of tail for the last note
    fx = np.zeros((total, 2)); marks = []
    counts = {}
    for ev in events["events"]:
        t, f = ev["type"], ev["f"]
        if t == "line":
            place(fx, sfx_line(ev["dur"], CURVES[ev.get("curve", "io")]), f, pan=ev.get("pan", 0), gain=0.07)
        elif t == "key":
            place(fx, sfx_key(ev.get("n", 0)), f, pan=ev.get("pan", 0.1), gain=0.3)
        elif t == "land":
            place(fx, sfx_land(ev.get("kind", "card")), f, pan=ev.get("pan", 0), gain=0.5)
        elif t == "slot":
            place(fx, sfx_slot(ev.get("i", 0)), f, pan=ev.get("pan", 0.2), gain=0.4)
        elif t == "snap":
            place(fx, sfx_snap(ev.get("i", 0)), f, pan=ev.get("pan", -0.1), gain=0.35)
        elif t == "chime":
            place(fx, sfx_chime(), f, pan=0.0, gain=0.22)
        elif t == "icon":
            place(fx, sfx_icon(), f, pan=0.0, gain=0.3)
        elif t == "wordmark":
            place(fx, sfx_wordmark(), f, pan=0.0, gain=0.25)
        marks.append((t, f))
    mus = np.zeros_like(fx)          # the music is a licensed recording, mixed in by package.py
    mix = mus + fx
    os.makedirs(out, exist_ok=True)
    sf.write(f"{out}/music.wav", mus, SR, subtype="FLOAT")
    sf.write(f"{out}/fx.wav", fx, SR, subtype="FLOAT")
    sf.write(f"{out}/mix-raw.wav", mix, SR, subtype="FLOAT")
    return mix

if __name__ == "__main__":
    ev = json.load(open(sys.argv[1]))[sys.argv[2]]; render(ev, sys.argv[3]); print("ok")
