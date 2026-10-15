#!/usr/bin/env python3
"""Renders the closing "open source, no account, no ads" card, the last screenshot in each set.

Usage: card.py <iphone|ipad>
Reads the copy from captions.json ("card") and writes ../images/<device>/NN-open-source.jpg after the captured shots.
Needs Google Chrome and ImageMagick.
"""
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ICON = os.path.abspath(f"{HERE}/../images/icon/app-icon-1024.png")

# Canvas size, headline size and top offset as % of canvas width; the rest is in the same units.
LAYOUT = {
    "iphone": dict(size=(1320, 2868), head=8.2, top=5.6, icon=26.0, row="column", gap=5.0, glyph=11.0, title=6.4, body=4.3, pad=6.0),
    "ipad": dict(size=(2752, 2064), head=5.2, top=4.4, icon=11.0, row="row", gap=2.2, glyph=5.0, title=2.7, body=1.85, pad=2.6),
}

GLYPHS = {
    "code": '<polyline points="8,6 2,12 8,18"/><polyline points="16,6 22,12 16,18"/><line x1="14" y1="4" x2="10" y2="20"/>',
    "cloud": '<path d="M7 18a4 4 0 0 1-.5-7.97A6 6 0 0 1 18 9.5 4.5 4.5 0 0 1 17.5 18z"/>',
    "noads": '<circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/>',
}

PAGE = """<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: "NY"; src: url("file:///System/Library/Fonts/NewYork.ttf"); font-weight: 100 900; }
* { margin:0; padding:0; box-sizing:border-box; }
html, body { background:#000; overflow:hidden; }
.canvas { --u:%(u).4fpx; position:relative; width:%(w)dpx; height:%(h)dpx; overflow:hidden; color:#fff;
  background: radial-gradient(ellipse 70%% 42%% at 50%% 0%%, rgba(255,138,76,.20), rgba(255,138,76,0) 70%%), linear-gradient(165deg,#332924 0%%,#1f1815 100%%); }
.head { position:absolute; left:0; right:0; top:calc(var(--u)*%(top).2f); text-align:center;
  font-family:"NY","New York",Georgia,serif; font-weight:600; letter-spacing:-.012em; line-height:1.08; font-size:calc(var(--u)*%(head).2f); }
.head em { font-style:normal; background:linear-gradient(95deg,#ffc48a,#ff8a4c); -webkit-background-clip:text; background-clip:text; color:transparent; }
.body { position:absolute; left:6%%; right:6%%; top:calc(var(--u)*%(body_top).2f); bottom:calc(var(--u)*%(bottom).2f); display:flex; flex-direction:column; align-items:center; justify-content:center; gap:calc(var(--u)*%(gap).2f); }
.icon { width:calc(var(--u)*%(icon).2f); height:calc(var(--u)*%(icon).2f); border-radius:22.5%%; box-shadow:0 calc(var(--u)*.6) calc(var(--u)*2.4) rgba(0,0,0,.5); }
.rows { width:100%%; display:flex; flex-direction:%(row)s; gap:calc(var(--u)*%(gap).2f); }
.row { flex:1; display:flex; flex-direction:%(inner)s; gap:calc(var(--u)*%(gap).2f); align-items:%(align)s; padding:calc(var(--u)*%(pad).2f); border-radius:calc(var(--u)*%(radius).2f);
  background:rgba(255,255,255,.07); box-shadow:inset 0 0 0 calc(var(--u)*.16) rgba(255,255,255,.12); }
.glyph { flex:none; width:calc(var(--u)*%(glyph).2f); height:calc(var(--u)*%(glyph).2f); border-radius:28%%; display:grid; place-items:center; background:rgba(255,138,76,.16); }
.glyph svg { width:62%%; height:62%%; fill:none; stroke:#ff9a5c; stroke-width:1.7; stroke-linecap:round; stroke-linejoin:round; }
.row h2 { font-family:"NY","New York",Georgia,serif; font-weight:600; font-size:calc(var(--u)*%(title).2f); line-height:1.1; }
.row p { margin-top:calc(var(--u)*.7); font-family:-apple-system,"SF Pro Text",system-ui,sans-serif; font-size:calc(var(--u)*%(body).2f); line-height:1.32; color:rgba(255,255,255,.72); text-wrap:balance; }
</style><div class="canvas"><h1 class="head">%(headline)s</h1>
<div class="body"><img class="icon" src="file://%(icon_url)s"><div class="rows">%(rows)s</div></div></div>"""


def build(device):
    cfg = LAYOUT[device]
    w, h = cfg["size"]
    card = json.load(open(f"{HERE}/captions.json"))["card"]
    portrait = h > w
    rows = "".join(
        f'<div class="row"><div class="glyph"><svg viewBox="0 0 24 24">{GLYPHS[r["icon"]]}</svg></div><div><h2>{r["title"]}</h2><p>{r["body"]}</p></div></div>'
        for r in card["rows"])
    u = w / 100
    head_bottom = cfg["top"] + cfg["head"] * 1.08 * 2
    page = PAGE % dict(
        u=u, w=w, h=h, top=cfg["top"], head=cfg["head"], headline=card["headline"], icon_url=ICON, icon=cfg["icon"], rows=rows,
        row=cfg["row"], inner="row" if portrait else "column", align="center" if portrait else "flex-start", gap=cfg["gap"],
        glyph=cfg["glyph"], title=cfg["title"], body=cfg["body"], pad=cfg["pad"], radius=cfg["pad"] * 0.9,
        body_top=head_bottom + 2.0, bottom=cfg["top"] * 1.6)
    shots = len(json.load(open(f"{HERE}/captions.json"))[device])
    out_dir = f"{HERE}/../images/{device}"; os.makedirs(out_dir, exist_ok=True)
    out = f"{out_dir}/{shots + 1:02d}-open-source.jpg"
    with tempfile.TemporaryDirectory() as tmp:
        open(f"{tmp}/p.html", "w").write(page)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=3000", f"--window-size={w},{h + 200}",
                        f"--screenshot={tmp}/s.png", f"file://{tmp}/p.html"], capture_output=True, check=True)
        subprocess.run(["magick", f"{tmp}/s.png", "-crop", f"{w}x{h}+0+0", "+repage", "-background", "black", "-alpha", "remove", "-alpha", "off",
                        "-strip", "-quality", "95", "-sampling-factor", "4:4:4", out], check=True)
    print(out)


if __name__ == "__main__":
    for device in sys.argv[1:] or LAYOUT:
        build(device)
