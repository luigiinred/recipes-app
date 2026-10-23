"""Retimes a footage clip into a frame budget: real motion plays near natural speed, idle waiting is squeezed.

`plan(name, rec_from, rec_to, f0, f1)` returns segments [out frame, out frame, recording seconds, recording seconds] covering frames f0..f1
(three frames each, so the engine interpolates smoothly). Activity comes from the cut frame sequence in footage/frames/iphone/<name>.
`holds` are recording seconds that should stay near natural speed even when nothing moves (a tap, a landing).
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
_cache = {}

def activity(device, name):
    key = (device, name)
    if key in _cache: return _cache[key]
    folder = os.path.join(ROOT, "footage", "frames", device, name)
    files = sorted(f for f in os.listdir(folder) if f.endswith(".jpg"))
    cache = os.path.join(folder, "activity.npy")
    if os.path.exists(cache):
        a = np.load(cache)
    else:
        prev, out = None, [0.0]
        for f in files:
            im = np.asarray(Image.open(os.path.join(folder, f)).convert("L").resize((90, 160)), dtype=np.float32)
            if prev is not None: out.append(float(np.abs(im - prev).mean()))
            prev = im
        a = np.array(out); np.save(cache, a)
    _cache[key] = a
    return a

def plan(device, name, origin, rec_from, rec_to, f0, f1, holds=(), idle_speed=14.0, min_active=0.7, thresh=0.35):
    a = activity(device, name)
    i0, i1 = int((rec_from - origin) * 60), int((rec_to - origin) * 60)
    act = (a[i0:i1] > thresh).astype(float)
    k = np.ones(18) / 18                                   # a bit under a third of a second of grace around motion
    act = (np.convolve(act, k, mode="same") > 0.01).astype(float)
    for h in holds:
        j = int((h - rec_from) * 60)
        act[max(0, j - 24):j + 24] = 1.0
    n = len(act)
    total_out = (f1 - f0) / 30.0
    A = act.sum() / 60.0; I = (1 - act).sum() / 60.0
    v_a = A / max(1e-6, total_out - I / idle_speed) if total_out > I / idle_speed else 99.0
    v_a = max(min_active, v_a)
    speed = np.where(act > 0, v_a, idle_speed)
    speed = np.convolve(np.pad(speed, 15, mode="edge"), np.ones(31) / 31, mode="valid")[:n]   # ease between the two speeds
    # walk the recording at these speeds, then scale so that exactly (rec_to - rec_from) is covered in the budget
    def walk(scale):
        t, pts = 0.0, []
        for fr in range(f1 - f0 + 1):
            pts.append(t)
            r = speed[min(n - 1, int(t * 60))] * scale
            t += r / 30.0
        return pts
    lo, hi = 0.01, 5.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if walk(mid)[-1] < rec_to - rec_from: lo = mid
        else: hi = mid
    pts = walk((lo + hi) / 2)
    segs = []
    for fr in range(0, f1 - f0, 3):
        e = min(fr + 3, f1 - f0)
        segs.append([f0 + fr, f0 + e, round(float(rec_from + pts[fr]), 4), round(float(rec_from + pts[e]), 4)])
    return segs


def keys(points, step=3):
    """Segments through chosen (output frame, recording second) points, joined by a smooth monotone curve.

    The slope between points is the playback speed, so a gentle ramp into a fast stretch is just a matter of where the points sit.
    """
    from scipy.interpolate import PchipInterpolator
    fr = [p[0] for p in points]; sec = [p[1] for p in points]
    f = PchipInterpolator(fr, sec)
    out = []
    for a in range(fr[0], fr[-1], step):
        b = min(a + step, fr[-1])
        out.append([a, b, round(float(f(a)), 4), round(float(f(b)), 4)])
    return out
