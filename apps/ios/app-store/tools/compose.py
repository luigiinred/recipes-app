#!/usr/bin/env python3
"""Composes raw simulator captures with a caption into App Store screenshots.

Usage: compose.py <iphone|ipad|mac> [--style dark|light]
Reads captions.json and raw/<device>/<scene>.png; writes ../images/<device>[-light]/NN-<id>.jpg.
Needs Google Chrome and ImageMagick.
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Canvas size, headline size and top offset as % of canvas width, and where the screenshot sits.
# With `margin`, the whole screen shows, that fraction of the canvas height above the bottom edge.
# Without it the screen is `fit` of the canvas width and runs off the bottom edge.
# `shot_top` is the screenshot's top as a fraction of the canvas height.
LAYOUT = {
    "iphone": dict(size=(1320, 2868), fit=0.94, shot_top=0.165, head=8.2, top=5.6, radius=8.0),
    "ipad": dict(size=(2752, 2064), margin=0.05, shot_top=0.235, head=5.2, top=4.4, radius=2.6),
    "mac": dict(size=(2880, 1800), margin=0.06, shot_top=0.215, head=4.4, top=3.4, radius=0.9),
}

PAGE = """<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: "NY"; src: url("file:///System/Library/Fonts/NewYork.ttf"); font-weight: 100 900; }
* { margin:0; padding:0; box-sizing:border-box; }
html, body { background:#000; overflow:hidden; }
.canvas { --u:%(u).4fpx; position:relative; width:%(w)dpx; height:%(h)dpx; overflow:hidden; color:#fff;
  background: radial-gradient(ellipse 70%% 42%% at 50%% 0%%, rgba(255,138,76,.20), rgba(255,138,76,0) 70%%), linear-gradient(165deg,#332924 0%%,#1f1815 100%%); }
.head { position:absolute; left:0; right:0; top:calc(var(--u)*%(top).2f); text-align:center;
  font-family:"NY","New York",Georgia,serif; font-weight:600; letter-spacing:-.012em; line-height:1.08;
  font-size:calc(var(--u)*%(head).2f); }
.head em { font-style:normal; background:linear-gradient(95deg,#ffc48a,#ff8a4c); -webkit-background-clip:text; background-clip:text; color:transparent; }
.shot { position:absolute; left:50%%; transform:translateX(-50%%); top:%(shot_top)dpx; width:%(shot_w)dpx; height:%(shot_h)dpx;
  border-radius:calc(var(--u)*%(radius).2f); background:#000 url("file://%(raw)s") center/100%% 100%% no-repeat;
  box-shadow:0 0 0 calc(var(--u)*.26) rgba(255,255,255,.16), 0 calc(var(--u)*2) calc(var(--u)*7) rgba(0,0,0,.55); }
%(style_css)s</style><div class="canvas"><h1 class="head">%(caption)s</h1><div class="shot"></div></div>"""

LIGHT_CSS = """
.canvas { color:#2b2320; background: radial-gradient(ellipse 80%% 36%% at 50%% 0%%, rgba(255,138,76,.16), rgba(255,138,76,0) 70%%), linear-gradient(180deg,#ffffff 0%%,#fff1e0 100%%); }
.head em { background:linear-gradient(95deg,#e8672a,#c9402f); -webkit-background-clip:text; background-clip:text; color:transparent; }
.shot { box-shadow:0 0 0 calc(var(--u)*.22) rgba(0,0,0,.08), 0 calc(var(--u)*2) calc(var(--u)*7) rgba(60,30,10,.22); }
"""


def compose(device, index, shot, style):
    cfg = LAYOUT[device]
    w, h = cfg["size"]
    raw = f"{HERE}/raw/{device}/{shot['raw']}.png"
    rw, rh = map(int, subprocess.check_output(["magick", "identify", "-format", "%w %h", raw]).split())
    shot_top = round(h * cfg["shot_top"])
    if "margin" in cfg:
        shot_h = h - shot_top - round(h * cfg["margin"]); shot_w = round(shot_h * rw / rh)
    else:
        shot_w = round(w * cfg["fit"]); shot_h = round(shot_w * rh / rw)
    html = PAGE % dict(u=w / 100, w=w, h=h, top=cfg["top"], head=cfg["head"], caption=shot["caption"], shot_w=shot_w, shot_h=shot_h,
                       shot_top=shot_top, radius=cfg["radius"], raw=raw, style_css=LIGHT_CSS % {} if style == "light" else "")
    out_dir = f"{HERE}/../images/{device}{'-light' if style == 'light' else ''}"
    os.makedirs(out_dir, exist_ok=True)
    out = f"{out_dir}/{index:02d}-{shot['id']}.jpg"
    with tempfile.TemporaryDirectory() as tmp:
        page = f"{tmp}/p.html"; open(page, "w").write(html)
        flat = f"{tmp}/s.png"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=3000", f"--window-size={w},{h + 200}",
                        f"--screenshot={flat}", f"file://{page}"], capture_output=True, check=True)
        subprocess.run(["magick", flat, "-crop", f"{w}x{h}+0+0", "+repage", "-background", "black", "-alpha", "remove", "-alpha", "off",
                        "-strip", "-quality", "95", "-sampling-factor", "4:4:4", out], check=True)
    print(out)


if __name__ == "__main__":
    device = sys.argv[1]
    style = sys.argv[sys.argv.index("--style") + 1] if "--style" in sys.argv else "dark"
    shots = json.load(open(f"{HERE}/captions.json"))[device]
    for index, shot in enumerate(shots, 1):
        if os.path.exists(f"{HERE}/raw/{device}/{shot['raw']}.png"):
            compose(device, index, shot, style)
        else:
            print("missing raw", shot["raw"], file=sys.stderr)
