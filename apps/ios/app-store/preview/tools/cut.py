#!/usr/bin/env python3
"""Cuts the clips named in clips.json out of the raw recordings as 60 fps JPEG sequences for the composition.

clips.json: {"<device>": {"<clip>": {"src": "<raw scene>", "from": s, "to": e, "width": px}}}. Frames land in footage/frames/<device>/<clip>/.
Usage: cut.py <device> [clip ...]
"""
import json, os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
device = sys.argv[1]
spec = json.load(open(os.path.join(ROOT, "clips.json")))[device]
for name in sys.argv[2:] or spec:
    c = spec[name]
    out = os.path.join(ROOT, "footage", "frames", device, name)
    shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
    src = os.path.join(ROOT, "footage", "raw", device, c["src"] + ".mov")
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-ss", str(c["from"]), "-to", str(c["to"]), "-i", src,
                           "-vf", f"fps=60,scale={c.get('width', 1000)}:-2:flags=lanczos", "-q:v", "3", "-start_number", "0", f"{out}/%05d.jpg"])
    n = len(os.listdir(out))
    json.dump({"count": n, "from": c["from"], "to": c["to"]}, open(os.path.join(out, "clip.json"), "w"))
    print(f"{device}/{name}: {n} frames, {c['to'] - c['from']:.2f}s from {c['src']}")
