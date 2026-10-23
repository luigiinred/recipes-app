"""The iPhone story: what happens on each frame of the 792 (30 fps, 100 bpm: a beat is 18 frames, a bar 72).

Footage times are seconds into the original recording, the numbers you see when scrubbing the .mov. `retime.plan` fits a stretch of a
recording into a frame budget (motion near natural speed, waiting squeezed), and `at(clip, seconds)` finds the output frame that
shows a recording second, so sound events follow the picture.
"""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import retime

W, H = 886, 1920
SW = 700                       # a screen's display width; the footage is 1320 x 2868
SH = round(SW * 2868 / 1320)
PITCH = 1700                   # world distance between screens
TOP = 424                      # canvas y of a screen top at rest; the bezel reaches 35 px above it
GUT = SW / 2 + 54              # the line runs down the gutters beside the screens
L, R = -GUT, GUT
CLIPS = json.load(open(os.path.join(ROOT, "clips.json")))["iphone"]
BEZEL = "../assets/bezel-iphone-17-pro-max-cosmic-orange.png"

def clip_info(name):
    meta = json.load(open(os.path.join(ROOT, "footage", "frames", "iphone", name, "clip.json")))
    return {"dir": f"iphone/{name}", "count": meta["count"]}

def build():
    clips, plans = {}, {}

    def clip(name, segs):
        """segs are [out frame, out frame, recording seconds, recording seconds]; the engine wants them relative to the clip's cut point."""
        c = clip_info(name); origin = CLIPS[name]["from"]
        c["segs"] = [[a, b, round(s0 - origin, 4), round(s1 - origin, 4)] for a, b, s0, s1 in segs]
        clips[name] = c; plans[name] = segs

    def fit(name, rec_from, rec_to, f0, f1, **kw):
        clip(name, retime.plan("iphone", name, CLIPS[name]["from"], rec_from, rec_to, f0, f1, **kw))

    def at(name, sec):
        for a, b, s0, s1 in plans[name]:
            if min(s0, s1) <= sec <= max(s0, s1) and s1 != s0:
                return int(round(a + (sec - s0) / (s1 - s0) * (b - a)))
        raise ValueError(f"{name} {sec}s is not shown")

    MOVES = [(62, 82), (206, 226), (350, 370), (422, 442), (494, 514), (638, 658)]   # the camera travels to the next screen, on bar lines

    # hook: the library, a scroll through every recipe
    fit("hero", 56.2, 66.0, 0, 72)
    # save: Safari, the Share sheet, Save to Recipes, review, saved, the recipe opens and scrolls
    fit("share", 29.6, 68.0, 72, 216, holds=[33.9, 47.6, 53.0])
    # plan: the lasagna into the week from Up Next, then an idea typed in
    fit("plan", 52.4, 81.0, 216, 360, holds=[53.3, 62.3, 78.3])
    # apple intelligence: smart plan fills the empty dinners
    fit("smartplan", 38.8, 59.4, 360, 420, holds=[42.0, 46.0, 51.3])
    # tidy: the messy ingredient list, one tap on Clean Up, the sections
    # The page is flung down to the Clean Up button and back up again, in under three seconds: the flings play as quick whooshes and the
    # taps and the finished list play near natural speed.
    clip("cleanup", retime.keys([(420, 78.8), (438, 79.2), (444, 79.9), (456, 81.7), (460, 82.6), (468, 83.7), (472, 88.0), (478, 89.3), (484, 91.6),
                                 (496, 94.9), (500, 96.4), (512, 97.6), (530, 98.2)]))
    # cook: the recipe, cook mode one step at a time, a timer
    clip("cook", retime.keys([(504, 65.0), (512, 66.0), (522, 67.3), (534, 68.9), (540, 70.8), (552, 71.8), (556, 72.6), (568, 73.4), (572, 74.6),
                              (584, 75.4), (592, 77.2), (604, 78.4), (612, 79.0), (648, 81.4)]))

    stations = [{"id": "hook", "clip": "hero"}, {"id": "save", "clip": "share"}, {"id": "plan", "clip": "plan"},
                {"id": "ai", "clip": "smartplan"}, {"id": "tidy", "clip": "cleanup"}, {"id": "cook", "clip": "cook"}, {"id": "close", "clip": "cook"}]

    cap = lambda a, b, *lines, **kw: {"in": a, "out": b, "lines": list(lines), **kw}
    captions = [
        cap(4, 62, "Every recipe you find,", "<em>in one place.</em>"),
        cap(90, 198, "Save recipes from", "<em>anywhere on the web.</em>"),
        cap(234, 342, "Plan your week with", "<em>recipes or ideas.</em>"),
        cap(376, 414, "Apple Intelligence", "<em>plans the gaps.</em>"),
        cap(448, 486, "Tidy a messy recipe", "<em>in one tap.</em>"),
        cap(520, 566, "Step by step,", "<em>in large, clear type.</em>"),
        cap(580, 636, "Tap a time,", "<em>start a timer.</em>"),
        cap(736, 792, "Open source.", "<em>No account. No ads.</em>", dark=True, top=1150, size=58),
    ]
    camera = {"start": 0, "calm": [680, 750], "amp": {"x": 8, "y": 14, "rx": 2.4, "ry": 3.0},
              "moves": [{"f0": a, "f1": b, "from": k, "to": k + 1} for k, (a, b) in enumerate(MOVES)],
              "push": [[0, 56, 0.04]]}

    # the line: it never crosses the app. It runs down the gutter beside the screens and turns in under the wordmark.
    wu = 6 * PITCH - 118
    cap_y = 340 - (TOP + SH / 2)
    spine_nodes = [{"x": 330, "y": cap_y}, {"x": L, "y": cap_y}, {"x": L, "y": wu}]
    seg1 = 330 - L
    total = seg1 + (wu - cap_y)
    frac = lambda y: (seg1 + (y - cap_y)) / total
    head = [[0, 0], [6, 0, "io"], [30, frac(cap_y), "io"], [62, frac(PITCH * 0.5), "io"]]
    for k, (m0, m1) in enumerate(MOVES):
        end = frac(PITCH * (k + 1)) if k < len(MOVES) - 1 else 1.0
        if k: head.append([m0, frac(PITCH * k), "lin"])
        head.append([m1, end, "io"])
    thread = {"off": True, "width": 12, "color": "#E8672A", "colorDark": "#FF8A4C", "spine": {"nodes": spine_nodes, "head": [[0, 0]]}, "docks": [],
              "wobble": [[0, 0]], "shapes": [], "shapeN": 240, "endMorph": [[0, 0]], "endTrim": [[0, 0]]}

    close = {"station": 6, "flip": [648, 664], "flipAt": [443, 1180], "flipR": 2400, "icon": 664, "word": 716, "iconSize": 300,
             "anim": {"tile": [664, 680], "open": [668, 692], "fork": [684, 706], "spoon": [690, 712], "real": [712, 722]}, "iconX": 0, "iconY": -410,
             "wordX": 0, "wordY": -250, "ghost": {"clip": "cook", "w": 640, "h": 1391, "dy": 900, "z": -200, "opacity": 0.75}}

    ev = []
    for n, t in enumerate([67.533, 68.1, 68.783, 69.45, 70.27, 71.083, 72.233, 72.883, 73.567, 74.183]):
        ev.append({"type": "key", "f": at("plan", t), "n": n})
    ev += [
        {"type": "land", "f": at("share", 31.2), "kind": "card"},        # the share sheet settles
        {"type": "land", "f": at("share", 35.0), "kind": "card"},        # the review appears
        {"type": "land", "f": at("share", 48.4), "kind": "card"},        # "Recipe added!"
        {"type": "land", "f": at("share", 53.4), "kind": "card"},        # the recipe opens
        {"type": "land", "f": at("plan", 62.4), "kind": "ingredient"},   # the lasagna lands in Sunday dinner
        {"type": "land", "f": at("plan", 78.3), "kind": "idea"},         # "Taco night" joins the week
        {"type": "slot", "f": at("smartplan", 47.4), "i": 0},            # the review fills with Tuesday's dinner
        {"type": "slot", "f": at("smartplan", 47.4) + 5, "i": 1},        # Wednesday's
        {"type": "slot", "f": at("smartplan", 47.4) + 10, "i": 2},       # Thursday's
        {"type": "snap", "f": at("cleanup", 92.6), "i": 0},              # "For The Layers" is a section now
        {"type": "snap", "f": at("cleanup", 96.9), "i": 1},              # and "For The Sauce"
        {"type": "chime", "f": at("cook", 77.9)},                          # the timer starts
        {"type": "snap", "f": 672, "i": 2},                              # the book's pages swing open
        {"type": "land", "f": 700, "kind": "ingredient"},                # the fork lands
        {"type": "land", "f": 706, "kind": "ingredient"},                # the spoon lands
        {"type": "icon", "f": 712},                                      # the real icon settles
        {"type": "wordmark", "f": close["word"]},
    ]
    return {"width": W, "height": H, "screen": {"w": SW, "h": SH, "radius": 84, "top": TOP}, "pitch": PITCH, "stations": stations,
            "clips": clips, "camera": camera, "captions": captions, "thread": thread, "close": close,
            "style": {"bezel": BEZEL, "shadowBlur": 34, "capTop": 128, "capSize": 70, "glowY": 45, "iconShadow": 26, "wordSize": 112, "defocus": 9}, "events": ev}
