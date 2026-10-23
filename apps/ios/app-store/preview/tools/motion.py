#!/usr/bin/env python3
"""Frame-difference activity of a recording at 60 fps, to find when things happen.

Prints bursts of motion (start, end, peak) over the whole screen, and optionally for a band of the screen
(--band y0 y1 as fractions of height). Times are seconds into the .mov.
Usage: motion.py <mov> <start> <end> [--band 0.10 0.17] [--gap 0.12] [--min 0.4]
"""
import subprocess, sys
import numpy as np

mov, start, end = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
band = (0.0, 1.0)
if "--band" in sys.argv:
    i = sys.argv.index("--band"); band = (float(sys.argv[i + 1]), float(sys.argv[i + 2]))
gap = float(sys.argv[sys.argv.index("--gap") + 1]) if "--gap" in sys.argv else 0.12
floor = float(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 0.4
W = 160
probe = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", mov]).decode().strip().split(",")
H = int(round(int(probe[1]) * W / int(probe[0])))
raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-to", str(end), "-i", mov, "-vf", f"fps=60,scale={W}:{H},format=gray", "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
frames = np.frombuffer(raw, dtype=np.uint8).reshape(-1, H, W).astype(np.float32)
y0, y1 = int(band[0] * H), int(band[1] * H)
d = np.abs(np.diff(frames[:, y0:y1], axis=0)).mean(axis=(1, 2))
t = start + (np.arange(len(d)) + 1) / 60
active = d > floor
bursts, cur = [], None
for i, a in enumerate(active):
    if a:
        if cur is None: cur = [t[i], t[i], d[i]]
        else:
            if t[i] - cur[1] > gap: bursts.append(cur); cur = [t[i], t[i], d[i]]
            else: cur[1] = t[i]; cur[2] = max(cur[2], d[i])
if cur: bursts.append(cur)
for b in bursts: print(f"{b[0]:.2f}-{b[1]:.2f}  peak {b[2]:.2f}")
