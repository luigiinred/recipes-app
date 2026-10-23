#!/usr/bin/env python3
"""Contact sheet of a recording with timestamps: sheet.py <mov> <start> <end> <fps> <cols> <out.png> [tile-width]"""
import subprocess, sys, tempfile, os
from PIL import Image, ImageDraw, ImageFont
mov, start, end, fps, cols, out = sys.argv[1:7]
tw = int(sys.argv[7]) if len(sys.argv) > 7 else 180
start, end, fps, cols = float(start), float(end), float(fps), int(cols)
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-to", str(end), "-i", mov, "-vf", f"fps={fps},scale={tw}:-1", f"{tmp}/%04d.png"], check=True)
    names = sorted(os.listdir(tmp)); imgs = [Image.open(f"{tmp}/{n}").convert("RGB") for n in names]
    w, h = imgs[0].size; rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), "white"); d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
    for i, im in enumerate(imgs):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(im, (x, y)); label = f"{start + i / fps:.2f}"
        d.rectangle([x + 4, y + h - 30, x + 78, y + h - 4], fill="white"); d.text((x + 8, y + h - 28), label, fill="red", font=font)
    sheet.save(out)
