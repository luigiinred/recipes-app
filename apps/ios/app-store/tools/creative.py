#!/usr/bin/env python3
"""Renders the product page header, search result and universal creative assets to ../images/creative/.

Usage: creative.py [header|search|universal ...]   (needs Google Chrome and ImageMagick)
Sizes follow Apple's creative asset specifications: opaque, no alpha.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ICON = os.path.abspath(f"{HERE}/../images/icon/app-icon.png")
PHOTOS = [f"file://{HERE}/seed/photos/{n}.jpg" for n in
          ["pesto-pasta", "butternut-soup", "red-curry", "cookies", "pappardelle", "shakshuka", "fig-toast", "lemon-loaf", "braised-beef", "clams", "noodle-soup", "pancakes", "lentil-salad", "fried-rice"]]
TARGETS = {"header": (3840, 1646), "search": (3840, 2560), "universal": (5244, 2950)}

PAGE = """<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: "NY"; src: url("file:///System/Library/Fonts/NewYork.ttf"); font-weight: 100 900; }
* { margin:0; padding:0; box-sizing:border-box; }
html, body { background:#000; overflow:hidden; }
.canvas { --u:%(u).4fpx; position:relative; width:%(w)dpx; height:%(h)dpx; overflow:hidden; background:#1f1815; }
.mosaic { position:absolute; inset:calc(var(--u)*-1); display:grid; grid-template-columns:repeat(%(cols)d,1fr); grid-template-rows:repeat(2,1fr); gap:calc(var(--u)*.6); transform:rotate(-4deg) scale(1.12); }
.mosaic i { background-size:cover; background-position:center; }
.shade { position:absolute; inset:0; background: radial-gradient(ellipse 52%% 62%% at 50%% 50%%, rgba(31,24,21,.92), rgba(31,24,21,.62) 70%%, rgba(31,24,21,.45)); }
.lockup { position:absolute; left:0; right:0; top:50%%; transform:translateY(-50%%); text-align:center; color:#fff; }
.icon { width:calc(var(--u)*%(icon).2f); height:calc(var(--u)*%(icon).2f); filter:drop-shadow(0 calc(var(--u)*.8) calc(var(--u)*1.6) rgba(0,0,0,.5)); }
h1 { margin-top:calc(var(--u)*%(gap).2f); font-family:"NY","New York",Georgia,serif; font-weight:600; letter-spacing:-.012em; line-height:1.06; font-size:calc(var(--u)*%(head).2f); }
h1 em { font-style:normal; background:linear-gradient(95deg,#ffc48a,#ff8a4c); -webkit-background-clip:text; background-clip:text; color:transparent; }
</style><div class="canvas"><div class="mosaic">%(tiles)s</div><div class="shade"></div>
<div class="lockup"><img class="icon" src="%(icon_url)s"><h1>Your recipes,<br><em>beautifully kept.</em></h1></div></div>"""


def build(name):
    w, h = TARGETS[name]
    wide = w / h > 2
    cols = 6 if wide else 4
    tiles = "".join(f'<i style="background-image:url({PHOTOS[i % len(PHOTOS)]})"></i>' for i in range(cols * 2))
    page = PAGE % dict(u=w / 100, w=w, h=h, cols=cols, tiles=tiles, icon_url=f"file://{ICON}",
                       icon=8.5 if wide else 11.0, gap=2.4 if wide else 3.2, head=4.2 if wide else 5.4)
    out_dir = f"{HERE}/../images/creative"; os.makedirs(out_dir, exist_ok=True)
    out = f"{out_dir}/{name}.png"
    with tempfile.TemporaryDirectory() as tmp:
        open(f"{tmp}/p.html", "w").write(page)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=6000", f"--window-size={w},{h + 200}",
                        f"--screenshot={tmp}/s.png", f"file://{tmp}/p.html"], capture_output=True, check=True)
        subprocess.run(["magick", f"{tmp}/s.png", "-crop", f"{w}x{h}+0+0", "+repage", "-background", "black", "-alpha", "remove",
                        "-alpha", "off", "-strip", "-define", "png:color-type=2", out], check=True)
    print(out)


if __name__ == "__main__":
    for name in sys.argv[1:] or TARGETS:
        build(name)
