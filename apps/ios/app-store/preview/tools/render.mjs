#!/usr/bin/env node
// Renders a HyperFrames composition to a film-camera look: 8 sub-frames per output frame on a 180-degree shutter,
// blended in linear light. HyperFrames' own renderer takes one sample per frame, so this drives the same
// composition page directly: it seeks the page to a time, screenshots it, and blends the samples.
//
// Usage: render.mjs <composition-dir> <out-dir> [--from N] [--to N] [--workers N] [--subframes 8] [--shutter 0.5] [--fps 30]
// Writes <out-dir>/NNNNN.png, one blended frame each. The composition page must define window.renderAt(seconds): Promise.
import puppeteer from "puppeteer-core";
import sharp from "sharp";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const dir = path.resolve(args[0]);
const out = path.resolve(args[1]);
const opt = (name, fallback) => { const i = args.indexOf(`--${name}`); return i < 0 ? fallback : args[i + 1]; };
const fps = Number(opt("fps", 30));
const subframes = Number(opt("subframes", 8));
const shutter = Number(opt("shutter", 0.5));
const workers = Number(opt("workers", 6));
const events = JSON.parse(fs.readFileSync(path.join(dir, "..", "events.json"), "utf8"));
const device = path.basename(dir);
const total = events[device].frames;
const from = Number(opt("from", 0));
const to = Math.min(Number(opt("to", total - 1)), total - 1);
const step = Number(opt("step", 1));
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
fs.mkdirSync(out, { recursive: true });

const decode = new Float32Array(256);
for (let i = 0; i < 256; i++) { const c = i / 255; decode[i] = c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }
const ENC = 4096; const encode = new Uint8Array(ENC + 1);
for (let i = 0; i <= ENC; i++) { const l = i / ENC; const c = l <= 0.0031308 ? l * 12.92 : 1.055 * l ** (1 / 2.4) - 0.055; encode[i] = Math.round(Math.min(1, Math.max(0, c)) * 255); }

async function worker(id, frames) {
  const browser = await puppeteer.launch({
    executablePath: CHROME, headless: "new",
    args: ["--no-sandbox", "--force-color-profile=srgb", "--allow-file-access-from-files", "--disable-web-security", "--hide-scrollbars", "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
           "--use-angle=metal", "--enable-gpu-rasterization", "--ignore-gpu-blocklist", "--enable-zero-copy"],
  });
  const page = await browser.newPage();
  const W = events[device].width, H = events[device].height;
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
  page.on("pageerror", (e) => console.error(`[w${id}] page error:`, e.message));
  await page.goto(pathToFileURL(path.join(dir, "index.html")).href, { waitUntil: "load" });
  await page.evaluate(() => document.fonts.ready);
  for (const f of frames) {
    const acc = new Float32Array(W * H * 3);
    for (let k = 0; k < subframes; k++) {
      // The shutter is open for `shutter` of the frame, centered on the frame time.
      const t = (f + ((k + 0.5) / subframes - 0.5) * shutter) / fps;
      await page.evaluate((t) => window.renderAt(Math.max(0, t)), t);
      const png = await page.screenshot({ type: "png", omitBackground: false });
      const { data, info } = await sharp(png).removeAlpha().raw().toBuffer({ resolveWithObject: true });
      for (let i = 0; i < data.length; i++) acc[i] += decode[data[i]];
    }
    const rgb = Buffer.alloc(W * H * 3);
    for (let i = 0; i < acc.length; i++) rgb[i] = encode[Math.round((acc[i] / subframes) * ENC)];
    await sharp(rgb, { raw: { width: W, height: H, channels: 3 } }).png({ compressionLevel: 3 }).toFile(path.join(out, String(f).padStart(5, "0") + ".png"));
  }
  await browser.close();
}

const all = []; for (let f = from; f <= to; f += step) all.push(f);
const buckets = Array.from({ length: workers }, () => []);
all.forEach((f, i) => buckets[i % workers].push(f));
const t0 = Date.now();
let done = 0;
const tick = setInterval(() => { done = fs.readdirSync(out).length; process.stderr.write(`\r${done}/${all.length} frames, ${((Date.now() - t0) / 1000).toFixed(0)}s`); }, 3000);
await Promise.all(buckets.filter((b) => b.length).map((b, i) => worker(i, b)));
clearInterval(tick);
console.error(`\nrendered ${all.length} frames in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
