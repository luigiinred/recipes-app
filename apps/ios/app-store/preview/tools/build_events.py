#!/usr/bin/env python3
"""Builds events.json, events.js and each device's index.html from the stories in story_<device>.py.

events.json is the one timeline: scene and camera timing, captions, footage retiming, the line's route, and every sound event, all in
frames at 30 fps. The pictures (shared/engine.js) and the sound (tools/audio.py) both read it, so the two cannot drift apart.
Usage: build_events.py [device ...]
"""
import importlib, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)

FPS, BPM, FRAMES = 30, 100, 792
BEAT, BAR = 18, 72

def derive_sound_from_line(thread, events):
    """Every stretch where the line is being drawn is one sound event over those frames: the spine growing, a dock reaching out, the end shape."""
    def stretches(keys):
        for (f0, v0, *_), (f1, v1, *rest) in zip(keys, keys[1:]):
            if v1 > v0 + 1e-6 and f1 > f0:
                yield int(round(f0)), int(round(f1 - f0))
    for f, dur in stretches(thread["spine"]["head"]):
        events.append({"type": "line", "f": f, "dur": dur, "curve": "io", "pan": -0.35})
    for d in thread["docks"]:
        events.append({"type": "line", "f": d["in"][0], "dur": d["in"][1] - d["in"][0], "curve": "io", "pan": 0.0})
    for f, dur in stretches(thread.get("endTrim", [])):
        events.append({"type": "line", "f": f, "dur": dur, "curve": "io", "pan": 0.0})

def build(device):
    story = importlib.import_module(f"story_{device}")
    ev = story.build()
    ev.update({"fps": FPS, "bpm": BPM, "frames": FRAMES, "beat": BEAT, "bar": BAR})
    derive_sound_from_line(ev["thread"], ev["events"])
    ev["events"].sort(key=lambda e: (e["f"], e["type"]))
    for e in ev["events"]:
        assert 0 <= e["f"] < FRAMES, e
    return ev

def page(device, ev):
    t = open(os.path.join(ROOT, "shared", "template.html")).read()
    st = ev["style"]
    sub = {"__DEVICE__": device, "__W__": ev["width"], "__H__": ev["height"], "__CX__": ev["width"] / 2, "__CY__": ev["height"] / 2,
           "__SHADOWBLUR__": st["shadowBlur"], "__CAPTOP__": st["capTop"], "__CAPSIZE__": st["capSize"], "__GLOWY__": st["glowY"],
           "__ICON__": ev["close"]["iconSize"], "__ICONSHADOW__": st["iconShadow"], "__ICONSHADOW2__": st["iconShadow"] * 1.5, "__WORDSIZE__": st["wordSize"], "__BAND__": ev["screen"]["top"] - 66}
    for k, v in sub.items(): t = t.replace(k, str(v))
    return t

if __name__ == "__main__":
    devices = sys.argv[1:] or ["iphone"]
    path = os.path.join(ROOT, "events.json")
    data = json.load(open(path)) if os.path.exists(path) else {}
    for d in devices:
        data[d] = build(d)
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
        open(os.path.join(ROOT, d, "index.html"), "w").write(page(d, data[d]))
    json.dump(data, open(path, "w"), indent=1)
    open(os.path.join(ROOT, "events.js"), "w").write("window.EVENTS = " + json.dumps(data) + ";\n")
    print("events:", {d: len(data[d]["events"]) for d in data})
