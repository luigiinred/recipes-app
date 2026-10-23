// Shared helpers for the OpenRecipes preview compositions.
// Everything on screen is a pure function of time, so any frame can be rendered on its own, in any order.
(function () {
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, u) => a + (b - a) * u;
  const ease = {
    lin: (u) => u,
    in: (u) => u * u * u,
    out: (u) => 1 - Math.pow(1 - u, 3),
    io: (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2),
    soft: (u) => u * u * (3 - 2 * u),
    back: (u) => { const c = 1.45; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); },
    // A damped spring for things that land: overshoots once, then settles.
    spring: (u) => (u <= 0 ? 0 : u >= 1 ? 1 : 1 - Math.exp(-6.2 * u) * Math.cos(9.5 * u)),
  };
  // progress(f, a, b, easing): 0 before frame a, 1 after frame b.
  const prog = (f, a, b, e = "io") => ease[e](clamp((f - a) / (b - a)));
  // Piecewise keyframes: [[frame, value, easing-into-this-key], ...]. Values may be numbers.
  function kf(keys, f) {
    if (f <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      if (f <= keys[i][0]) {
        const [f0, v0] = keys[i - 1], [f1, v1, e] = keys[i];
        return lerp(v0, v1, ease[e || "io"]((f - f0) / (f1 - f0)));
      }
    }
    return keys[keys.length - 1][1];
  }
  // Source time for a retimed clip: segments [[outFrame0, outFrame1, srcSec0, srcSec1], ...], held outside them.
  function retime(segs, f) {
    if (f <= segs[0][0]) return segs[0][2];
    for (const [f0, f1, s0, s1] of segs) if (f <= f1) return lerp(s0, s1, (f - f0) / Math.max(1, f1 - f0));
    return segs[segs.length - 1][3];
  }
  // Deterministic value noise in [-1, 1] for hand-drawn wobble.
  function noise(x, seed = 0) {
    const h = (n) => { const s = Math.sin(n * 127.1 + seed * 311.7) * 43758.5453; return (s - Math.floor(s)) * 2 - 1; };
    const i = Math.floor(x), u = x - i, w = u * u * (3 - 2 * u);
    return lerp(h(i), h(i + 1), w);
  }
  const pad5 = (n) => String(n).padStart(5, "0");

  // Footage: 60 fps JPEG sequences cut from the simulator recordings. `show` swaps the image for a source time.
  const pending = [];
  function show(img, clip, sec, count) {
    const idx = clamp(Math.round(sec * 60), 0, count - 1);
    const src = `../footage/frames/${clip}/${pad5(idx)}.jpg`;
    if (img.dataset.src !== src) { img.dataset.src = src; img.src = src; pending.push(img.decode().catch(() => {})); }
  }
  async function settle() { const p = pending.splice(0); await Promise.all(p); }

  // Polyline helpers for the line. Points are [x, y]; the line is trimmed to a drawn length.
  function lengths(pts) { const L = [0]; for (let i = 1; i < pts.length; i++) L.push(L[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); return L; }
  function trim(pts, a, b) {
    const L = lengths(pts), total = L[L.length - 1];
    const s = clamp(a) * total, e = clamp(b) * total, out = [];
    if (e - s <= 0.01) return out;
    const at = (d) => { let i = 1; while (i < L.length - 1 && L[i] < d) i++; const u = (d - L[i - 1]) / Math.max(1e-6, L[i] - L[i - 1]); return [lerp(pts[i - 1][0], pts[i][0], u), lerp(pts[i - 1][1], pts[i][1], u)]; };
    out.push(at(s));
    for (let i = 1; i < pts.length - 1; i++) if (L[i] > s && L[i] < e) out.push(pts[i]);
    out.push(at(e));
    return out;
  }
  const toPath = (pts) => (pts.length ? "M" + pts.map((p) => p[0].toFixed(2) + " " + p[1].toFixed(2)).join("L") : "");
  // Resamples a polyline to n evenly spaced points so two shapes can be blended point by point.
  function resample(pts, n) {
    const L = lengths(pts), total = L[L.length - 1], out = [];
    for (let k = 0; k < n; k++) {
      const d = (k / (n - 1)) * total; let i = 1; while (i < L.length - 1 && L[i] < d) i++;
      const u = (d - L[i - 1]) / Math.max(1e-6, L[i] - L[i - 1]);
      out.push([lerp(pts[i - 1][0], pts[i][0], u), lerp(pts[i - 1][1], pts[i][1], u)]);
    }
    return out;
  }
  const mix = (A, B, u) => A.map((p, i) => [lerp(p[0], B[i][0], u), lerp(p[1], B[i][1], u)]);
  const circle = (cx, cy, r, n, start = -Math.PI / 2) => Array.from({ length: n }, (_, k) => { const a = start + (k / (n - 1)) * Math.PI * 2; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; });

  window.Kit = { clamp, lerp, ease, prog, kf, retime, noise, pad5, show, settle, lengths, trim, toPath, resample, mix, circle };
})();
