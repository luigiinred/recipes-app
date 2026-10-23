#!/usr/bin/env python3
"""Proves the sound lands on the picture: detects onsets in rendered audio and compares them with events.json.

The music runs all the time, so the onsets are measured on the effects stem, put through the same AAC encode as the video, and decoded.
A second check measures the finished MP4's mix with a spectral-flux detector and matches each event to the nearest onset.
Usage: verify_sync.py <events.json> <device> <fx.wav> <video.mp4>
"""
import json, subprocess, sys, tempfile, os
import numpy as np
import soundfile as sf
from scipy import signal

events_path, device, fx_path, mp4 = sys.argv[1:5]
ev = json.load(open(events_path))[device]
SR, FPS = 48000, 30
events = [e for e in ev["events"] if e["type"] != "line"]    # a drawn line swells in softly: it has no single onset

def decode(path, tmp):
    wav = os.path.join(tmp, "d.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-vn", "-ac", "1", "-ar", str(SR), wav], check=True)
    x, _ = sf.read(wav); return x

with tempfile.TemporaryDirectory() as tmp:
    # 1. each effect rendered alone (so no other sound's tail is in the way), through AAC, then its first audible sample against its frame
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import audio
    offs = []
    for i, e in enumerate(events):
        solo = {"frames": ev["frames"], "events": [e]}
        buf = np.zeros((ev["frames"] * audio.SPF + SR, 2))
        out = os.path.join(tmp, f"solo{i}")
        audio.render(solo, out)
        fx, _ = sf.read(os.path.join(out, "fx.wav")); fx = fx / max(1e-9, np.abs(fx).max()) * 0.5
        w = os.path.join(tmp, f"s{i}.wav"); sf.write(w, fx, SR)
        m = os.path.join(tmp, f"s{i}.m4a")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "aac", "-b:a", "256k", "-ar", "48000", m], check=True)
        x = decode(m, tmp)
        f0 = e["f"] * SR // FPS
        lo, hi = max(0, f0 - int(0.06 * SR)), f0 + int(0.15 * SR)
        seg = np.abs(x[lo:hi]); thr = 0.05 * max(seg.max(), 1e-6)
        k = int(np.argmax(seg > thr)) if (seg > thr).any() else None
        offs.append(None if k is None else (lo + k - f0) / SR * 1000)
    ok = [o for o in offs if o is not None]
    print(f"each effect alone, after AAC: {len(ok)}/{len(events)} heard; first audible sample vs its frame: median {np.median(ok):+.1f} ms, "
          f"min {min(ok):+.1f} ms, max {max(ok):+.1f} ms (one frame is {1000 / FPS:.1f} ms)")
    for e, o in zip(events, offs):
        if o is None or abs(o) > 1000 / FPS: print(f"  OUTSIDE: {e['type']} f{e['f']}: {o}")
    # 2. the finished mix: spectral flux onsets
    y = decode(mp4, tmp)
    n = 512
    f, t, S = signal.stft(y, SR, nperseg=1024, noverlap=1024 - n)
    mag = np.abs(S); flux = np.maximum(0, np.diff(mag, axis=1)).sum(axis=0); tt = t[1:]
    flux = flux / (np.median(flux) + 1e-9)
    peaks, _ = signal.find_peaks(flux, height=6, distance=int(0.04 * SR / n))
    onset_t = tt[peaks]
    res = []
    for e in events:
        target = e["f"] / FPS
        near = onset_t[np.abs(onset_t - target) < 0.06]
        if len(near): res.append((near[np.argmin(np.abs(near - target))] - target) * 1000)
    print(f"finished mix: {len(res)}/{len(events)} events matched to a spectral onset within 60 ms; median {np.median(res):+.1f} ms, "
          f"worst {max(res, key=abs):+.1f} ms")
