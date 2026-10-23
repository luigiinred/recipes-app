#!/usr/bin/env python3
"""Composes raw captures with a caption into App Store screenshots, in the style of the preview videos.

Usage: compose.py <iphone|ipad|mac|iphone-duo|iphone-duo-open>
Reads captions.json and raw/<device>/<scene>.png; writes ../images/<device>/NN-<id>.jpg, ending on the dark closing card.
Needs Google Chrome and ImageMagick.
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ICON = os.path.abspath(f"{HERE}/../images/icon/app-icon.png")
# Apple's device frame from Apple Design Resources, kept out of git; without it the iPhone screen is drawn as a plain rounded rectangle.
BEZEL = os.path.abspath(f"{HERE}/../preview/assets/bezel-iphone-17-pro-max-cosmic-orange.png")

# Canvas, caption size and top, where the line runs, and the screen: its top, its width or height, and corner radius as a fraction of its width.
LAYOUT = {
    "iphone": dict(size=(1320, 2868), cap=104, cap_top=150, line=468, top=560, width=1000, radius=0.12, bezel=True),
    "ipad": dict(size=(2752, 2064), cap=118, cap_top=110, line=410, top=500, height=1480, radius=0.026),
    "mac": dict(size=(2880, 1800), cap=108, cap_top=96, line=372, top=460, height=1270, radius=0.012),
    "iphone-duo": dict(size=(1398, 2034), cap=92, cap_top=92, line=330, top=400, width=1080, radius=0.067),
    "iphone-duo-open": dict(size=(2853, 2007), cap=104, cap_top=86, line=344, top=420, height=1500, radius=0.03),
}

# The devices shot: each device's own library capture as (left, top, width) fractions of the canvas, rounded by a fraction of its width.
LINEUP = {
    "iphone": dict(mac=(0.05, 0.215, 0.90), ipad=(0.03, 0.445, 0.62), iphone=(0.55, 0.515, 0.43)),
    "ipad": dict(mac=(0.04, 0.270, 0.56), ipad=(0.46, 0.410, 0.51), iphone=(0.33, 0.450, 0.175)),
    "mac": dict(mac=(0.035, 0.265, 0.52), ipad=(0.45, 0.410, 0.46), iphone=(0.30, 0.430, 0.15)),
}
LINEUP_RADIUS = dict(mac=0.012, ipad=0.037, iphone=0.085)

PAPER = dict(bg="#FFF1E0", ink="#2B2320", accent="#E8672A")
DARK = dict(bg="#2B2320", ink="#FFF1E0", accent="#FF8A4C")

PAGE = """<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: "NY"; src: url("file:///System/Library/Fonts/NewYork.ttf"); font-weight: 100 900; }
* { margin:0; padding:0; box-sizing:border-box; }
html, body { background:#000; overflow:hidden; }
.canvas { position:relative; width:%(w)dpx; height:%(h)dpx; overflow:hidden; background:%(bg)s; color:%(ink)s; }
.cap { position:absolute; left:0; right:0; top:%(cap_top)dpx; text-align:center; font-family:"NY","New York",Georgia,serif;
  font-weight:600; font-size:%(cap)dpx; line-height:1.12; letter-spacing:-.012em; }
.cap em { font-style:normal; color:%(accent)s; }
.line { position:absolute; left:0; right:0; top:%(line)dpx; height:%(line_h)dpx; background:%(accent)s; }
.shot { position:absolute; background:center/100%% 100%% no-repeat;
  box-shadow:0 0 0 %(hair)dpx rgba(43,35,32,.12), 0 %(lift)dpx %(blur)dpx rgba(60,30,10,.28); }
.phone { position:absolute; filter:drop-shadow(0 %(lift)dpx %(blur)dpx rgba(60,30,10,.28)); }
.phone .screen { position:absolute; background:#000 center/100%% 100%% no-repeat; }
.phone img { position:absolute; left:0; top:0; width:100%%; height:100%%; }
.glow { position:absolute; inset:0; background:radial-gradient(ellipse 55%% 38%% at 50%% 36%%, rgba(255,138,76,.22), rgba(255,138,76,0) 70%%); }
.icon { position:absolute; filter:drop-shadow(0 %(lift)dpx %(blur)dpx rgba(0,0,0,.5)); }
.word { position:absolute; left:0; right:0; text-align:center; font-family:"NY","New York",Georgia,serif; font-weight:600; letter-spacing:-.02em; line-height:1; }
</style><div class="canvas">%(body)s</div>"""


def size_of(path):
    return tuple(map(int, subprocess.check_output(["magick", "identify", "-format", "%w %h", path]).split()))


def screen(raw, left, top, width, height, radius):
    return (f'<div class="shot" style="left:{left}px; top:{top}px; width:{width}px; height:{height}px; '
            f'border-radius:{radius}px; background-image:url(\'file://{raw}\')"></div>')


def phone(raw, left, top, width):
    # The 1470 x 3000 frame has a 1320 x 2868 opening at (75, 66).
    k = width / 1470
    return (f'<div class="phone" style="left:{left}px; top:{top}px; width:{width}px; height:{round(3000 * k)}px">'
            f'<div class="screen" style="left:{round(75 * k)}px; top:{round(66 * k)}px; width:{round(1320 * k)}px; height:{round(2868 * k)}px; '
            f'border-radius:{round(1320 * k * 0.12)}px; background-image:url(\'file://{raw}\')"></div><img src="file://{BEZEL}"></div>')


def single(device, shot):
    cfg = LAYOUT[device]
    w, _ = cfg["size"]
    raw = f"{HERE}/raw/{device}/{shot['raw']}.png"
    if cfg.get("bezel") and os.path.exists(BEZEL):
        return phone(raw, (w - cfg["width"]) // 2, cfg["top"], cfg["width"])
    rw, rh = size_of(raw)
    if "width" in cfg:
        width = cfg["width"]; height = round(width * rh / rw)
    else:
        height = cfg["height"]; width = round(height * rw / rh)
    return screen(raw, (w - width) // 2, cfg["top"], width, height, round(width * cfg["radius"]))


def lineup(device):
    w, h = LAYOUT[device]["size"]
    html = []
    for kind in ("mac", "ipad", "iphone"):
        raw = f"{HERE}/raw/{kind}/library.png"
        rw, rh = size_of(raw)
        left, top, width = LINEUP[device][kind]
        shot_w = round(w * width)
        html.append(screen(raw, round(w * left), round(h * top), shot_w, round(shot_w * rh / rw), round(shot_w * LINEUP_RADIUS[kind])))
    return "".join(html)


def card(device, copy):
    w, h = LAYOUT[device]["size"]
    unit = min(w, h)
    icon = round(unit * 0.26)
    icon_top = round(h * 0.25)
    word_size = round(unit * 0.135)
    word_top = icon_top + icon + round(unit * 0.07)
    cap_top = word_top + word_size + round(unit * 0.09)
    return (f'<div class="glow"></div><img class="icon" src="file://{ICON}" style="left:{(w - icon) // 2}px; top:{icon_top}px; width:{icon}px; height:{icon}px">'
            f'<div class="word" style="top:{word_top}px; font-size:{word_size}px">{copy["wordmark"]}</div>'
            f'<h1 class="cap" style="top:{cap_top}px">{copy["headline"]}</h1>')


def render(device, index, shot, captions):
    cfg = LAYOUT[device]
    w, h = cfg["size"]
    if shot.get("card"):
        body, colors = card(device, captions["card"]), DARK
    else:
        shots = lineup(device) if shot.get("lineup") else single(device, shot)
        body, colors = f'<h1 class="cap">{shot["caption"]}</h1><div class="line"></div>{shots}', PAPER
    unit = min(w, h)
    html = PAGE % dict(w=w, h=h, cap=cfg["cap"], cap_top=cfg["cap_top"], line=cfg["line"], line_h=max(4, round(unit * 0.0045)),
                       hair=max(2, round(unit * 0.002)), lift=round(unit * 0.02), blur=round(unit * 0.035), body=body, **colors)
    out_dir = f"{HERE}/../images/{device}"
    os.makedirs(out_dir, exist_ok=True)
    out = f"{out_dir}/{index:02d}-{shot['id']}.jpg"
    with tempfile.TemporaryDirectory() as tmp:
        open(f"{tmp}/p.html", "w").write(html)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--disable-features=MediaRouter,DialMediaRouteProvider", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=3000", f"--window-size={w},{h + 200}",
                        f"--screenshot={tmp}/s.png", f"file://{tmp}/p.html"], capture_output=True, check=True)
        subprocess.run(["magick", f"{tmp}/s.png", "-crop", f"{w}x{h}+0+0", "+repage", "-background", "black", "-alpha", "remove", "-alpha", "off",
                        "-strip", "-quality", "95", "-sampling-factor", "4:4:4", out], check=True)
    print(out)


if __name__ == "__main__":
    device = sys.argv[1]
    captions = json.load(open(f"{HERE}/captions.json"))
    for index, shot in enumerate(captions[device], 1):
        if shot.get("card") or shot.get("lineup") or os.path.exists(f"{HERE}/raw/{device}/{shot['raw']}.png"):
            render(device, index, shot, captions)
        else:
            print("missing raw", shot["raw"], file=sys.stderr)
