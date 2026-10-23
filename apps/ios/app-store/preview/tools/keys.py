#!/usr/bin/env python3
"""Finds the frame each typed character appears in a recording, from how far the dark text reaches to the right.

Usage: keys.py <mov> <start> <end> <x0> <x1> <y0> <y1>   (crop as fractions of the screen). Prints each rise, seconds into the .mov, at 60 fps.
"""
import subprocess, sys
import numpy as np
mov, start, end = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
x0, x1, y0, y1 = (float(v) for v in sys.argv[4:8])
probe = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", mov]).decode().strip().split(",")
W, H = int(probe[0]), int(probe[1])
cw, ch = int((x1 - x0) * W) // 2 * 2, int((y1 - y0) * H) // 2 * 2
cx, cy = int(x0 * W), int(y0 * H)
raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-to", str(end), "-i", mov, "-vf", f"fps=60,crop={cw}:{ch}:{cx}:{cy},format=rgb24", "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
frames = np.frombuffer(raw, dtype=np.uint8).reshape(-1, ch, cw, 3)
dark = frames.max(axis=3) < 100            # black text, not the red caret or the grey placeholder
reach = np.array([np.flatnonzero(d.any(axis=0))[-1] if d.any() else 0 for d in dark])
rises, last = [], 0
for i in range(len(reach)):
    if reach[i] > last + 6:
        rises.append(round(start + i / 60, 3)); last = reach[i]
print(len(rises), rises)
if "--plot" in sys.argv: print(list(reach[::6]))
