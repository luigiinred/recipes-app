// The OpenRecipes preview engine, shared by every device. A composition is a pure function of time:
// renderAt(seconds) lays out every element for that instant, waits for the footage frames to decode, and returns.
// All timing and layout come from the device's section of events.json (window.EVENTS[device]).
(function () {
  const K = window.Kit;
  const EV = window.EVENTS[window.DEVICE];
  const { clamp, lerp, ease, prog, kf, retime, noise } = K;
  const W = EV.width, H = EV.height, FPS = EV.fps;
  const S = EV.screen;
  const C = EV.close;
  const T = EV.thread;
  const $ = (id) => document.getElementById(id);
  const world = $("world"), world2 = $("world2"), hud = $("hud"), dark = $("dark"), glow = $("glow");
  const stationY = (i) => i * EV.pitch;      // world y of a screen's center
  const worldXY = (i, u, v) => [(u - 0.5) * S.w, stationY(i) + (v - 0.5) * S.h];

  // ---------- screens: one per station, placed down the world ----------
  const screens = EV.stations.map((st, i) => {
    const el = document.createElement("div");
    el.className = "screen";
    el.style.width = S.w + "px"; el.style.height = S.h + "px";
    el.innerHTML = '<div class="shadow"></div><div class="glass"><img alt=""></div>';
    if (EV.style.bezel) {                     // Apple's own device frame: the footage fits its 1320 x 2868 opening exactly
      const k = S.w / 1320, b = document.createElement("img");
      b.className = "bezel"; b.src = EV.style.bezel; b.alt = "";
      b.style.width = 1470 * k + "px"; b.style.height = 3000 * k + "px"; b.style.left = -75 * k + "px"; b.style.top = -66 * k + "px";
      el.appendChild(b);
    }
    el.querySelector(".glass").style.borderRadius = S.radius + "px";
    el.querySelector(".shadow").style.borderRadius = S.radius + "px";
    world.appendChild(el);
    return { st, el, img: el.querySelector("img"), shadow: el.querySelector(".shadow"), i };
  });

  // ---------- the line, above the dark flip so it never leaves the screen ----------
  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("class", "thread"); svg.setAttribute("width", 1); svg.setAttribute("height", 1);
  const glowPath = document.createElementNS(svgNS, "path");
  const path = document.createElementNS(svgNS, "path");
  glowPath.style.filter = "blur(9px)";
  svg.appendChild(glowPath); svg.appendChild(path);
  world2.appendChild(svg);

  // ---------- close: icon, wordmark and the ghost of a real screen, in the world so they share the camera ----------
  // The icon is built from its own layers (book, fork, spoon over the gradient) so it can assemble itself, then it hands over to the real icon file.
  const icon = document.createElement("div");
  icon.className = "close-icon";
  const IS = C.iconSize;
  icon.style.width = IS + "px"; icon.style.height = IS + "px";
  icon.innerHTML = `
    <div class="ic-tile" style="width:${IS}px;height:${IS}px;border-radius:${IS * 0.2237}px">
      <div class="ic-bg"></div>
      <div class="ic-book" style="width:${IS * 1.2}px;height:${IS * 1.2}px;left:${-IS * 0.1}px;top:${-IS * 0.1}px">
        <div class="ic-page l"></div>
        <div class="ic-page r"></div>
      </div>
      <div class="ic-fork" style="width:${IS * 1.3}px;height:${IS * 1.3}px;left:${-IS * 0.15}px;top:${-IS * 0.15}px"></div>
      <div class="ic-spoon" style="width:${IS * 1.3}px;height:${IS * 1.3}px;left:${-IS * 0.15}px;top:${-IS * 0.15}px"></div>
    </div>
    <img class="ic-real" src="../../images/icon/app-icon.png" style="width:${IS}px;height:${IS}px" alt="">`;
  const tile = icon.querySelector(".ic-tile"), pageL = icon.querySelector(".ic-page.l"), pageR = icon.querySelector(".ic-page.r");
  const fork = icon.querySelector(".ic-fork"), spoon = icon.querySelector(".ic-spoon"), real = icon.querySelector(".ic-real");
  const bookEl = icon.querySelector(".ic-book");
  const word = document.createElement("div");
  word.className = "close-word"; word.textContent = "OpenRecipes";
  const ghost = document.createElement("div");
  ghost.className = "close-ghost"; ghost.innerHTML = '<img class="gimg" alt="" style="display:block;width:100%;height:100%">';
  if (EV.style.bezel && C.ghost) {                 // the same device frame as the screens
    const k = C.ghost.w / 1320, b = document.createElement("img");
    b.className = "bezel"; b.src = EV.style.bezel; b.alt = "";
    b.style.cssText = `position:absolute;width:${1470 * k}px;height:${3000 * k}px;left:${-75 * k}px;top:${-66 * k}px;`;
    ghost.appendChild(b);
  }
  world2.appendChild(ghost); world2.appendChild(icon); world2.appendChild(word);
  const ghostImg = ghost.querySelector(".gimg");

  // ---------- captions ----------
  const caps = EV.captions.map((c) => {
    const el = document.createElement("div");
    el.className = "cap" + (c.dark ? " dark" : "");
    el.innerHTML = c.lines.map((l) => `<span class="ln"><span>${l}</span></span>`).join("");
    if (c.top !== undefined) el.style.top = c.top + "px";
    if (c.size !== undefined) el.style.fontSize = c.size + "px";
    hud.appendChild(el);
    return { c, el, lines: [...el.querySelectorAll(".ln > span")] };
  });

  // ---------- helpers ----------
  const clipOf = (st) => EV.clips[st.clip];
  const srcTime = (st, f) => retime(clipOf(st).segs, f);
  
  function stationAt(f) {
    const m = EV.camera.moves.find((m) => f >= m.f0 && f <= m.f1);
    if (m) return lerp(m.from, m.to, ease.io(clamp((f - m.f0) / (m.f1 - m.f0))));
    const last = EV.camera.moves.filter((m) => f > m.f1).pop();
    return last ? last.to : EV.camera.start;
  }

  function cameraAt(f) {
    const s = stationAt(f);
    const t = f / FPS;
    const hold = S.top + S.h / 2 - H / 2;    // where the screen's center sits, from the middle of the canvas
    const move = EV.camera.moves.find((m) => f >= m.f0 && f <= m.f1);
    const mid = move ? Math.sin(Math.PI * clamp((f - move.f0) / (move.f1 - move.f0))) : 0;
    const dir = move && move.to < move.from ? -1 : 1;
    const calm = 1 - 0.8 * prog(f, EV.camera.calm[0], EV.camera.calm[1], "io");
    const amp = EV.camera.amp;
    const cam = {
      x: amp.x * Math.sin(t * 0.7 + 1.1) * calm,
      y: s * EV.pitch - hold + (amp.y * Math.sin(t * 0.9 + 0.4) + 0.6 * amp.y * noise(t * 0.5, 3)) * calm,
      rx: (amp.rx * Math.sin(t * 0.55 + 0.2)) * calm - 5.0 * mid * dir,
      ry: (amp.ry * Math.sin(t * 0.43 + 1.4)) * calm + 2.0 * mid,
      rz: 0.45 * Math.sin(t * 0.37) * calm,
      s: 1 + 0.012 * Math.sin(t * 0.5) + 0.03 * mid,
    };
    for (const p of EV.camera.push || []) cam.s += p[2] * prog(f, p[0], p[1], "io");
    return cam;
  }

  // The line is one stroke made of three parts that share a colour and a weight: the spine runs down the gutter beside the screens,
  // docks reach across a screen to sit on a real feature of the UI while it holds still, and the end shape carries the line through
  // the cook bar, the timer ring and the wordmark's underline.
  const spineNodes = T.spine.nodes;
  function spine(f) {
    const h = kf(T.spine.head, f);
    if (h <= 0) return [];
    const pts = spineNodes.map((n) => [n.x, n.y]);
    return K.trim(pts, 0, h);
  }
  function dockSegment(d, f) {
    const y = worldXY(d.station, 0.5, kf(d.v, f))[1];
    const a = prog(f, d.in[0], d.in[1], d.ease || "io"), z = prog(f, d.out[0], d.out[1], "io");
    if (a <= 0 || z >= 1) return [];
    return [[lerp(d.x0, d.x1, z), y], [lerp(d.x0, d.x1, Math.max(a, z)), y]];
  }
  const shapes = (T.shapes || []).map((sh) => K.resample(sh, T.shapeN || 220));
  function endShape(f) {
    if (!shapes.length) return [];
    const m = kf(T.endMorph, f), a = kf(T.endTrim, f);
    if (a <= 0) return [];
    const i = Math.min(Math.floor(m), shapes.length - 1);
    const pts = i >= shapes.length - 1 ? shapes[shapes.length - 1] : K.mix(shapes[i], shapes[i + 1], ease.io(m - i));
    return K.trim(pts, 0, a);
  }
  function wobble(pts, amount, t, seed) {
    if (amount <= 0.01 || pts.length < 2) return pts;
    const L = K.lengths(pts);
    return pts.map((p, k) => [p[0] + amount * noise(L[k] / 90 + t * 0.6, seed), p[1] + amount * 0.6 * noise(L[k] / 70 + 9 + t * 0.6, seed + 4)]);
  }
  const polyline = spine;

  // ---------- the frame ----------
  async function renderAt(t) {
    const f = t * FPS;
    const cam = cameraAt(f);
    const xf = `scale(${cam.s}) rotateX(${cam.rx}deg) rotateY(${cam.ry}deg) rotateZ(${cam.rz}deg) translate3d(${-cam.x}px, ${-cam.y}px, 0)`;
    world.style.transform = xf; world2.style.transform = xf;

    // screens
    const sIdx = stationAt(f);
    for (const sc of screens) {
      const dist = Math.abs(sc.i - sIdx);
      const near = clamp(1 - dist * 0.9);
      const visible = dist < 1.7;
      sc.el.style.display = visible ? "block" : "none";
      if (!visible) continue;
      const clip = clipOf(sc.st);
      K.show(sc.img, clip.dir, srcTime(sc.st, f), clip.count);
      const blur = (1 - near) * EV.style.defocus;
      const z = -(1 - near) * 300;
      sc.el.style.transform = `translate3d(${-S.w / 2}px, ${stationY(sc.i) - S.h / 2}px, ${z}px)`;
      sc.el.style.filter = blur > 0.25 ? `blur(${blur.toFixed(2)}px)` : "none";
      sc.shadow.style.opacity = 0.3 + 0.7 * near;
    }

    // flip to dark: a circle grows from a point on the canvas
    const flip = prog(f, C.flip[0], C.flip[1], "io");
    const r = flip * C.flipR;
    dark.style.clipPath = `circle(${r.toFixed(1)}px at ${C.flipAt[0]}px ${C.flipAt[1]}px)`;
    glow.style.opacity = prog(f, C.flip[1] - 6, C.flip[1] + 24, "out");

    // the line
    if (T.off) { path.setAttribute("d", ""); glowPath.setAttribute("d", ""); }
    const wob = kf(T.wobble, f);
    let d = K.toPath(wobble(spine(f), wob, f / FPS, 5));
    for (const dk of T.docks) d += K.toPath(dockSegment(dk, f));
    const tail = endShape(f);
    if (tail.length) d += K.toPath(tail);
    const col = flip > 0.02 ? T.colorDark : T.color;
    path.setAttribute("d", T.off ? "" : d);
    path.style.strokeWidth = T.width; path.style.stroke = col;
    glowPath.setAttribute("d", T.off ? "" : d);
    glowPath.style.strokeWidth = T.width * 2.4; glowPath.style.stroke = T.colorDark; glowPath.style.opacity = 0.55 * prog(f, C.flip[1], C.flip[1] + 20, "out");

    // close: icon, wordmark, ghost
    const cy0 = stationY(C.station);
    const A = C.anim;
    const tileP = ease.spring(clamp((f - A.tile[0]) / (A.tile[1] - A.tile[0])));
    icon.style.opacity = f >= A.tile[0] - 0.01 ? 1 : 0;
    icon.style.transform = `translate3d(${C.iconX - IS / 2}px, ${cy0 + C.iconY - IS / 2}px, ${(1 - tileP) * 120}px) scale(${0.7 + 0.3 * tileP})`;
    // the book: two pages swing open around the spine, with a small lift as they go
    const open = ease.out(clamp((f - A.open[0]) / (A.open[1] - A.open[0])));
    pageL.style.transform = `rotateY(${(-1 + open) * 86}deg)`;
    pageR.style.transform = `rotateY(${(1 - open) * 86}deg)`;
    bookEl.style.transform = `translateY(${(1 - open) * 10}px) scale(${0.92 + 0.08 * Math.min(1, open)})`;
    bookEl.style.opacity = clamp((f - A.open[0]) / 3);
    // the fork and spoon fly in from outside the tile, spinning, and settle where they belong
    const fk = ease.spring(clamp((f - A.fork[0]) / (A.fork[1] - A.fork[0]))), sp = ease.spring(clamp((f - A.spoon[0]) / (A.spoon[1] - A.spoon[0])));
    const pf = clamp((f - A.fork[0]) / (A.fork[1] - A.fork[0])), ps = clamp((f - A.spoon[0]) / (A.spoon[1] - A.spoon[0]));
    fork.style.opacity = f >= A.fork[0] ? 1 : 0; spoon.style.opacity = f >= A.spoon[0] ? 1 : 0;
    fork.style.transform = `translate(${(1 - fk) * -IS * 2.6}px, ${(1 - fk) * -IS * 2.2}px) rotate(${(1 - fk) * -420}deg) scale(${1 + (1 - fk) * 0.6})`;
    spoon.style.transform = `translate(${(1 - sp) * IS * 2.6}px, ${(1 - sp) * -IS * 2.2}px) rotate(${(1 - sp) * 420}deg) scale(${1 + (1 - sp) * 0.6})`;
    // hand over to the real icon file, which carries the glass and the lighting
    const hand = prog(f, A.real[0], A.real[1], "io");
    real.style.opacity = hand; tile.style.opacity = 1 - hand * 0.999;
    const wP = ease.spring(clamp((f - C.word) / 22));
    word.style.opacity = f >= C.word - 0.01 ? clamp((f - C.word) / 5) : 0;
    word.style.transform = `translate3d(${C.wordX}px, ${cy0 + C.wordY + (1 - wP) * 40}px, 0) translateX(-50%)`;
    ghost.style.opacity = C.ghost ? prog(f, C.flip[1] - 4, C.flip[1] + 24, "out") * C.ghost.opacity : 0;
    if (C.ghost) {
      ghost.style.width = C.ghost.w + "px"; ghost.style.height = C.ghost.h + "px";
      ghost.style.transform = `translate3d(${-C.ghost.w / 2}px, ${cy0 - C.ghost.h / 2 + C.ghost.dy}px, ${C.ghost.z}px)`;
      const clip = EV.clips[C.ghost.clip];
      K.show(ghostImg, clip.dir, clip.segs[clip.segs.length - 1][3], clip.count);
    }

    // captions
    for (const cp of caps) {
      const { c, lines } = cp;
      cp.el.style.display = f >= c.in - 1 && f <= c.out + 14 ? "block" : "none";
      lines.forEach((ln, k) => {
        const inP = prog(f, c.in + 3 * k, c.in + 3 * k + 12, "out");
        const outP = prog(f, c.out + 2 * k, c.out + 2 * k + 9, "in");
        ln.style.transform = `translateY(${(1 - inP) * 118 - outP * 118}%)`;
      });
    }
    await K.settle();
  }
  window.renderAt = renderAt;
  window.__engine = { EV, cameraAt, spine, endShape, stationAt };
})();
