// Canvas previews for docs/effects.html (inlined by tools/effects_page.py).
// These are browser SIMULATIONS of each effect in the C64 palette, not C64 code: they show what
// the effect looks like, the real implementation recipe is in docs/08-effects-library.md.
"use strict";
const W = 160, H = 100;
// VICE default palette (matches the screenshots / GIFs)
const P = ["#000000", "#ffffff", "#af2a29", "#7ef3d6", "#aa40f5", "#56ac4d", "#2c3dec", "#ffff46",
  "#b7631e", "#775300", "#ee7b95", "#626262", "#949494", "#b7ff86", "#7385ff", "#cdcdcd"];
const LUM = [0, 6, 9, 11, 2, 4, 8, 12, 14, 10, 5, 15, 3, 7, 13, 1]; // dark -> light
const darker = (c, n) => LUM[Math.max(0, LUM.indexOf(c) - n)];
const COPPER = [6, 14, 3, 1, 3, 14, 6, 0, 0, 0, 9, 8, 10, 7, 1, 7, 10, 8, 9, 0, 0, 0];
const RAINBOW = [6, 4, 14, 3, 13, 1, 13, 3, 14, 4, 6, 11, 12, 15, 12, 11];
const S = Math.sin, C = Math.cos;

function rnd(seed) { let s = seed; return () => (s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff; }
function fill(c, col, x, y, w, h) { c.fillStyle = P[col]; c.fillRect(x | 0, y | 0, w, h); }
function cls(c, col = 0) { fill(c, col, 0, 0, W, H); }
function text(c, str, x, y, col, size = 8) {
  c.font = `bold ${size}px monospace`; c.textBaseline = "top"; c.fillStyle = P[col]; c.fillText(str, x | 0, y | 0);
}
// draw text, then recolour it column by column with colFn(x)
function colourText(c, str, x, y, size, colFn, step = 2) {
  const o = document.createElement("canvas"); o.width = W; o.height = H;
  const g = o.getContext("2d"); text(g, str, x, y, 1, size);
  g.globalCompositeOperation = "source-atop";
  for (let i = 0; i < W; i += step) { g.fillStyle = P[colFn(i)]; g.fillRect(i, 0, step, H); }
  c.drawImage(o, 0, 0);
}
// 1-bit bitmap of a text, for blocky "made of chars" effects
const maskCache = {};
function textMask(str) {
  if (maskCache[str]) return maskCache[str];
  const o = document.createElement("canvas"); o.width = str.length * 6; o.height = 8;
  const g = o.getContext("2d"); g.font = "bold 8px monospace"; g.textBaseline = "top";
  g.fillStyle = "#fff"; g.fillText(str, 0, 0);
  const d = g.getImageData(0, 0, o.width, 8).data, m = [];
  for (let y = 0; y < 8; y++) { m.push([]); for (let x = 0; x < o.width; x++) m[y].push(d[(y * o.width + x) * 4 + 3] > 110); }
  return (maskCache[str] = m);
}
function skyline(c, col) {
  const r = rnd(7); let x = 0;
  while (x < W) {
    const w = 6 + (r() * 10 | 0), h = 15 + (r() * 30 | 0);
    fill(c, col, x, 80 - h, w, h);
    if (r() < .5) for (let i = 0; i < w / 2; i++) fill(c, col, x + i, 80 - h - i, w - 2 * i, 1);
    x += w + 1;
  }
  fill(c, col, 72, 20, 4, 60); for (let i = 0; i < 18; i++) fill(c, col, 74 - i / 6, 2 + i, 1 + i / 3, 1); // spire
}
function logoScene(c, t, dy = 0) {
  colourText(c, "OPENCODE", 22, 30 + dy, 22, x => RAINBOW[((x >> 2) + t) & 15]);
  text(c, "codeurs en seine", 34, 62 + dy, 15);
}
function rot(p, a, b) { // rotate point around Y then X
  let [x, y, z] = p; [x, z] = [x * C(a) - z * S(a), x * S(a) + z * C(a)]; [y, z] = [y * C(b) - z * S(b), y * S(b) + z * C(b)];
  return [x, y, z];
}
const CUBE = [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]];
const FACES = [[0, 1, 2, 3, 6], [5, 4, 7, 6, 14], [4, 0, 3, 7, 4], [1, 5, 6, 2, 3], [4, 5, 1, 0, 13], [3, 2, 6, 7, 10]];
const SCROLL = "  OPENCODE ON THE C64 * CODEURS EN SEINE 2026 * ROUEN * KINDARENA *  ";

const R = {
  bars(c, t, o) {
    const tab = o.pal || COPPER, n = tab.length;
    for (let y = 0; y < H; y++) fill(c, tab[(((y >> 1) + t * (o.speed || 1) * (o.dir || 1)) % n + n) % n], 0, y, W, 1);
  },
  sinebars(c, t, o) {
    cls(c);
    const pals = o.pals || [[6, 14, 3, 1, 3, 14, 6], [9, 8, 10, 7, 1, 7, 10, 8, 9], [11, 5, 13, 1, 13, 5, 11]];
    const bars = pals.map((p, i) => ({ p, y: 50 + 38 * S(t * .06 + i * 2.1), z: C(t * .06 + i * 2.1) }));
    if (o.depth) bars.sort((a, b) => a.z - b.z);
    for (const b of bars) b.p.forEach((col, k) => fill(c, col, 0, b.y - b.p.length + 2 * k, W, 2));
    if (o.text) { fill(c, 0, 10, 40, 140, 20); text(c, "TEXT IN FRONT", 30, 46, 1); }
  },
  textcycle(c, t, o) {
    cls(c); colourText(c, o.str || "OPENCODE", 20, 28, 22, x => (o.pal || RAINBOW)[((x >> 2) + t) & 15]);
    text(c, "the open source AI coding agent", 2, 66, 15, 7);
  },
  shine(c, t) {
    cls(c); colourText(c, "CODEURS", 12, 20, 24, x => { const d = (x + 2 * t) % 260 - 80; return d > 0 && d < 12 ? 1 : d > -4 && d < 16 ? 3 : 14; });
    text(c, "EN SEINE", 50, 58, 14, 14);
  },
  scroller(c, t, o) {
    cls(c); logoScene(c, t);
    const sp = o.wobble ? 1.5 + S(t * .05) * 1.4 : (o.speed || 1);
    R._sx = (R._sx || 0) + sp; const x = -(R._sx % (SCROLL.length * 6)) + W;
    if (o.rainbow) colourText(c, SCROLL + SCROLL, x - SCROLL.length * 6, 86, 8, xx => RAINBOW[((xx >> 2) + t) & 15]);
    else text(c, SCROLL + SCROLL, x - SCROLL.length * 6, 86, 7);
  },
  flash(c, t) {
    const f = t % 25, ramp = [1, 15, 12, 11, 0];
    cls(c, ramp[Math.min(f >> 1, 4)]); fill(c, 0, 12, 10, W - 24, H - 20); logoScene(c, t);
  },
  fade(c, t) {
    const lvl = Math.min(15, Math.abs((t % 80) - 40) - 10); // 0 = full colour
    const n = Math.max(0, lvl);
    for (let y = 0; y < H; y++) fill(c, darker(COPPER[((y >> 1) + t) % COPPER.length], n), 0, y, W, 1);
    fill(c, 0, 10, 25, 140, 50); text(c, "OPENCODE", 35, 40, darker(1, n), 16);
  },
  reveal(c, t) {
    cls(c); const lines = ["GREETINGS TO ALL", "CODEUSES & CODEURS", "AND ALL SCENERS"];
    const r = rnd(3), cells = [];
    lines.forEach((l, j) => [...l].forEach((ch, i) => cells.push({ ch, x: 8 + i * 8, y: 25 + j * 16, k: r() })));
    const n = (t % 120) / 80;
    for (const e of cells) if (e.k < n) text(c, e.ch, e.x, e.y, e.k < n - .15 ? 1 : 7);
  },
  typer(c, t) {
    cls(c); const L = ["$ opencode", "> what are you?", "  an open source AI", "  coding agent.", "> can you run on a C64?", "  you're looking at it."];
    let n = (t % 220) * 0.7 | 0, y = 4;
    for (const l of L) {
      const s = l.slice(0, Math.max(0, n)); text(c, s, 2, y, l[0] === ">" ? 14 : l[0] === "$" ? 13 : 12, 7);
      if (n >= 0 && n < l.length && (t & 8)) fill(c, 1, 2 + s.length * 4.3, y, 4, 7);
      n -= l.length; y += 12;
    }
  },
  waves(c, t) {
    cls(c); skyline(c, 12);
    for (let k = 0; k < 4; k++) for (let x = 0; x < W; x++) {
      const y = 84 + k * 4 + 1.5 * S((x + t * (2 + k)) * .15);
      fill(c, [6, 14, 3, 14][k], x, y, 1, 1);
    }
  },
  twinkle(c, t) {
    cls(c); const r = rnd(11);
    for (let i = 0; i < 40; i++) { const x = r() * W, y = r() * 40; if (((t >> 2) + i) % 7) fill(c, i % 3 ? 11 : 15, x, y, 1, 1); }
    skyline(c, 11); const w = rnd(5);
    for (let i = 0; i < 60; i++) { const x = 4 + w() * 150, y = 45 + w() * 33; fill(c, ((t >> 3) * 7 + i * 13) % 5 ? 7 : 9, x, y, 2, 2); }
    fill(c, 6, 0, 82, W, 18);
  },
  glitch(c, t) {
    cls(c); logoScene(c, t);
    if (t % 60 < 12) {
      const r = rnd(t);
      for (let i = 0; i < 8; i++) { const y = r() * H | 0, h = 2 + r() * 8 | 0, dx = (r() - .5) * 30; c.drawImage(c.canvas, 0, y, W, h, dx, y, W, h); }
      fill(c, r() * 16 | 0, 0, 0, W, 4); fill(c, r() * 16 | 0, 0, H - 4, W, 4);
    }
  },
  shake(c, t) { cls(c); const f = t % 40; logoScene(c, t, f < 12 ? Math.round(S(f * 2.2) * (12 - f) / 2) : 0); },
  greetings(c, t) {
    cls(c); const names = ["PERFORMERS", "BOOZE DESIGN", "OXYRON", "CENSOR DESIGN", "MULTISTYLE LABS"];
    const i = (t / 60 | 0) % names.length, f = t % 60, s = names[i];
    text(c, "GREETINGS", 44, 20, 14, 12);
    const vis = Math.min(s.length, f / 2 | 0); text(c, s.slice(0, vis), 80 - s.length * 4.5, 52, f > 50 ? 11 : 1, 12);
  },
  bigscroll(c, t, o) {
    cls(c); const m = textMask(SCROLL), s = o.size || 2, cols = m[0].length;
    const off = (t * (o.size > 4 ? 2 : 1)) % cols, y0 = (H - 8 * s) / 2;
    for (let y = 0; y < 8; y++) for (let x = 0; x < W / s + 1; x++)
      if (m[y][(x + off) % cols]) fill(c, o.size > 4 ? RAINBOW[(y + (t >> 1)) & 15] : 7, x * s, y0 + y * s, s - (s > 4), s - (s > 4));
  },
  upscroll(c, t) {
    cls(c); const L = ["CREDITS", "", "CODE: OPENCODE", "GFX: OPENCODE", "MUSIC: JAMMER", "", "MADE IN ROUEN", "FOR CODEURS", "EN SEINE 2026", ""];
    const y0 = -((t * .7) % (L.length * 12));
    for (let k = 0; k < 2; k++) L.forEach((l, i) => text(c, l, 80 - l.length * 3, H + y0 + (i + k * L.length) * 12 - 20, i ? 15 : 7));
  },
  waving(c, t, o) {
    cls(c, o.border ? 14 : 0); if (o.border) fill(c, 6, 12, 22, W - 24, H - 44);
    const off = t * 1.5;
    [...SCROLL].forEach((ch, i) => {
      const x = i * 10 - off % (SCROLL.length * 10); if (x < -10 || x > W) return;
      const y = o.border ? 6 + 4 * S(t * .1 + i * .6) : 45 + 25 * S(t * .08 + i * .5);
      text(c, ch, x, y, o.border ? 0 : RAINBOW[i & 15], 10);
    });
    if (o.border) text(c, "SPRITES IN THE BORDER", 22, 45, 1, 7);
  },
  snake(c, t) {
    cls(c);
    for (let i = 7; i >= 0; i--) {
      const x = 75 + 65 * S((t - i * 6) * .05), y = 45 + 38 * S((t - i * 6) * .08);
      fill(c, [1, 15, 12, 11, 14, 6, 3, 13][i], x - 4, y - 4, 9, 9); fill(c, 0, x - 2, y - 2, 2, 2);
    }
  },
  stretch(c, t, o) {
    cls(c); const m = textMask("C64"); let y = 10;
    for (let r = 0; r < 8; r++) {
      const h = o.crunch ? Math.max(1, 1 + 5 * Math.abs(S(t * .1 + r * .8))) : 1 + 4 * (1 + S(t * .07 + r * .5));
      for (let x = 0; x < m[0].length; x++) if (m[r][x]) fill(c, 13, 50 + x * 4, y, 4, h);
      y += h;
    }
  },
  starfield(c, t, o) {
    cls(c); const r = rnd(2);
    for (let i = 0; i < (o.sprites ? 8 : 70); i++) {
      const sp = o.sprites ? 1 + i * .4 : 1 + (i % 3), y = o.sprites ? 8 + i * 11 : r() * H, x0 = r() * W;
      fill(c, sp > 2.5 ? 1 : sp > 1.5 ? 15 : 11, ((x0 - t * sp) % W + W) % W, y, o.sprites ? 2 : 1, 1);
    }
    if (!o.sprites) logoScene(c, t);
  },
  dycp(c, t) {
    cls(c); const off = t * 1.2;
    [...SCROLL].forEach((ch, i) => {
      const x = i * 7 - off % (SCROLL.length * 7); if (x < -8 || x > W) return;
      text(c, ch, x, 44 + 26 * S(i * .55 + t * .09) + 10 * S(x * .04 - t * .05), 7, 9);
    });
  },
  plasma(c, t, o) {
    const s = o.full ? 4 : o.fine ? 2 : 4, ramp = [6, 4, 14, 3, 13, 1, 13, 3, 14, 4, 6, 11, 2, 10, 8, 9];
    for (let y = 0; y < H; y += s) for (let x = 0; x < W; x += s) {
      const v = S(x * .05 + t * .07) + S(y * .07 - t * .05) + S((x + y) * .04 + t * .03) + S(Math.hypot(x - 80, y - 50) * .06 - t * .08);
      fill(c, ramp[((v + 4) * 4 | 0) & 15], x, y, s, s);
    }
    if (!o.full) { fill(c, 14, 0, 0, W, 8); fill(c, 14, 0, H - 8, W, 8); }
  },
  fire(c, t) {
    const w = 40, h = 25; R._f = R._f || new Array(w * h).fill(0); const f = R._f, r = rnd(t * 7 + 1);
    for (let x = 0; x < w; x++) f[(h - 1) * w + x] = r() > .4 ? 15 : 3;
    for (let y = 0; y < h - 1; y++) for (let x = 0; x < w; x++) {
      const b = (y + 1) * w;
      f[y * w + x] = Math.max(0, ((f[b + (x + w - 1) % w] + f[b + x] + f[b + (x + 1) % w] + f[Math.min(h - 1, y + 2) * w + x]) / 4.1) | 0);
    }
    const ramp = [0, 0, 9, 9, 2, 2, 8, 8, 10, 10, 7, 7, 7, 1, 1, 1];
    for (let i = 0; i < w * h; i++) fill(c, ramp[f[i]], (i % w) * 4, (i / w | 0) * 4, 4, 4);
  },
  matrix(c, t) {
    cls(c); const r = rnd(9);
    for (let x = 0; x < W; x += 6) {
      const sp = .5 + r(), len = 6 + (r() * 10 | 0), head = ((t * sp + r() * 200) % 30 | 0);
      for (let k = 0; k < len; k++) {
        const y = head - k; if (y < 0) continue;
        text(c, String.fromCharCode(33 + ((x * 7 + y * 13 + (k ? 0 : t)) % 60)), x, y * 7 - 70 + 70, k === 0 ? 1 : k < 3 ? 13 : k < 6 ? 5 : 11, 7);
      }
    }
  },
  swing(c, t) {
    cls(c); const o = document.createElement("canvas"); o.width = W; o.height = H; const g = o.getContext("2d");
    logoScene(g, t);
    for (let y = 0; y < H; y += 8) c.drawImage(o, 0, y, W, 8, 18 * S(t * .07 + y * .05), y, W, 8);
  },
  fld(c, t) { cls(c); fill(c, 14, 0, 0, W, 6); logoScene(c, t, -20 + Math.abs(S(t * .06)) * 45 | 0); },
  border(c, t) {
    cls(c, 6); fill(c, 14, 0, 0, W, 6); fill(c, 6, 12, 6, W - 24, H - 12); logoScene(c, t);
    for (let i = 0; i < 6; i++) {
      const x = ((i * 30 + t * 1.5) % (W + 20)) - 10;
      fill(c, [1, 7, 13, 3, 10, 15][i], x, 0 + 2 * S(t * .1 + i), 10, 6);
      fill(c, [1, 7, 13, 3, 10, 15][i], W - x, H - 6 + 2 * S(t * .1 + i), 10, 6);
    }
    text(c, "OPEN BORDER", 50, 2, 0, 5);
  },
  curtains(c, t) {
    const cols = [6, 14, 3, 13, 7, 8, 2, 4];
    for (let i = 0; i < 8; i++) { const y = i * 12 + 6 * S(t * .05 + i); fill(c, cols[i], 0, y, W, 16); }
    text(c, "RASTER SPLITS", 30, 40, 1, 10);
  },
  blend(c, t) {
    cls(c); const o = document.createElement("canvas"); o.width = W; o.height = H; const g = o.getContext("2d");
    logoScene(g, 3); const d = g.getImageData(0, 0, W, H), r = rnd(4), lvl = Math.min(1, (t % 120) / 80);
    for (let i = 0; i < W * H; i++) if (r() > lvl) d.data[i * 4 + 3] = 0;
    c.putImageData(d, 0, 0);
  },
  ecm(c, t) {
    cls(c, 6); const bgs = [0, 2, 6, 9], msg = "EXTENDED COLOUR MODE NOTE WRITER *";
    for (let y = 1; y < 12; y++) for (let x = 0; x < 20; x++) {
      const k = (x + y + (t >> 3)) & 3; fill(c, bgs[k], x * 8, y * 8, 8, 8);
      text(c, msg[(x + y * 20) % msg.length], x * 8 + 1, y * 8, [1, 7, 13, 3][k]);
    }
  },
  dotball(c, t) {
    cls(c);
    for (let i = 0; i < 12; i++) for (let j = 0; j < 12; j++) {
      const a = i / 12 * Math.PI * 2, b = (j + .5) / 12 * Math.PI;
      const [x, y, z] = rot([S(b) * C(a), C(b), S(b) * S(a)], t * .04, t * .025);
      fill(c, z > .3 ? 1 : z > -.3 ? 15 : 11, 80 + x * 38, 50 + y * 38, 2, 2);
    }
  },
  bobs(c, t) {
    cls(c);
    CUBE.map(p => rot(p, t * .05, t * .03)).sort((a, b) => a[2] - b[2]).forEach(([x, y, z]) => {
      const s = 4 + z * 1.5, f = 100 / (4 - z);
      fill(c, z > 0 ? 7 : 8, 80 + x * f * .35 - s, 50 + y * f * .35 - s, 2 * s, 2 * s);
    });
  },
  rotozoom(c, t) {
    const a = t * .03, z = 1.5 + S(t * .02);
    for (let y = 0; y < H; y += 4) for (let x = 0; x < W; x += 4) {
      const u = ((x - 80) * C(a) - (y - 50) * S(a)) * z, v = ((x - 80) * S(a) + (y - 50) * C(a)) * z;
      fill(c, ((u >> 4) ^ (v >> 4)) & 1 ? 14 : ((u >> 3) & 3) ? 6 : 3, x, y, 4, 4);
    }
  },
  tunnel(c, t) {
    for (let y = 0; y < H; y += 4) for (let x = 0; x < W; x += 4) {
      const dx = x - 80, dy = y - 50, d = 400 / (Math.hypot(dx, dy) + 1), a = Math.atan2(dy, dx) / Math.PI * 8;
      const v = ((d + t * .6) | 0) ^ ((a + t * .05) | 0);
      fill(c, d > 30 ? 0 : [6, 14, 3, 1][v & 3], x, y, 4, 4);
    }
  },
  multiplex(c, t) {
    cls(c);
    for (let i = 0; i < 24; i++) {
      const band = i >> 3, x = 75 + 65 * S(t * .04 + i * .8), y = 10 + band * 30 + 8 * S(t * .1 + i);
      fill(c, RAINBOW[i & 15], x, y, 8, 8);
    }
    text(c, "24 SPRITES", 2, 2, 15, 6);
  },
  spritelogo(c, t) { cls(c); colourText(c, "OPENCODE", 6, 30, 28, x => RAINBOW[((x >> 4) + (t >> 2)) & 15], 16); },
  sequencer(c, t) {
    const part = (t / 90 | 0) % 3, f = t % 90, n = f < 8 ? 8 - f : f > 82 ? f - 82 : 0;
    if (part === 0) R.bars(c, t, {}); else if (part === 1) R.plasma(c, t, {}); else R.dotball(c, t);
    if (n) { c.fillStyle = `rgba(0,0,0,${n / 8})`; c.fillRect(0, 0, W, H); }
    text(c, ["PART 1", "PART 2", "PART 3"][part], 2, 2, 1, 7);
  },
  beat(c, t) { R.flash(c, t); const f = t % 25; fill(c, 1, 20, 92, Math.max(0, 120 - f * 10), 3); },
  sideborder(c, t) {
    cls(c, 6); logoScene(c, t);
    for (let i = 0; i < 8; i++) fill(c, RAINBOW[(i * 2) & 15], ((i * 22 + t * 2) % (W + 12)) - 12, 82, 12, 10);
    text(c, "NO SIDE BORDERS", 34, 4, 1, 7);
  },
  techtech(c, t) {
    cls(c); const o = document.createElement("canvas"); o.width = W; o.height = H; const g = o.getContext("2d");
    logoScene(g, t);
    for (let y = 0; y < H; y++) c.drawImage(o, 0, y, W, 1, 14 * S(y * .12 + t * .12), y, W, 1);
  },
  dysp(c, t) {
    cls(c, 14); fill(c, 6, 12, 10, W - 24, H - 20);
    "OPENCODE".split("").forEach((ch, i) => {
      const x = 75 + 70 * S(t * .05 + i * .45), y = 45 + 42 * S(t * .07 + i * .7);
      fill(c, RAINBOW[(i * 2) & 15], x - 5, y - 5, 11, 11); text(c, ch, x - 3, y - 4, 0);
    });
  },
  fpp(c, t) {
    cls(c); const o = document.createElement("canvas"); o.width = W; o.height = H; const g = o.getContext("2d");
    logoScene(g, t);
    for (let y = 0; y < H; y++) { const sy = 50 + (y - 50) * (0.6 + 0.4 * S(t * .05)) + 10 * S(y * .08 + t * .1); c.drawImage(o, 0, sy | 0, W, 1, 0, y, W, 1); }
  },
  vsp(c, t) {
    const off = t * 2;
    for (let y = 0; y < H; y += 8) for (let x = -8; x < W + 8; x += 8) {
      const cx = ((x + off) >> 3), col = (cx * 7 + (y >> 3) * 3) % 5 ? 6 : (cx + (y >> 3)) & 1 ? 14 : 3;
      fill(c, col, x - (off & 7), y, 8, 8);
    }
    fill(c, 0, 20, 40, 120, 18); text(c, "HARDWARE SCROLL", 34, 45, 1, 8);
  },
  fli(c) {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x += 4) {
      const v = (x / W * 8 + y / H * 8 + ((x >> 2) + y) % 2 * .5) | 0;
      fill(c, LUM[Math.min(15, v)], x, y, 4, 1);
    }
    text(c, "16 COLOURS PER 4x1", 30, 4, 1, 7);
  },
  twister(c, t) {
    cls(c);
    for (let y = 0; y < H; y++) {
      const a = t * .05 + S(t * .02 + y * .02) * 2;
      for (let k = 0; k < 4; k++) {
        const x1 = 80 + 30 * S(a + k * Math.PI / 2), x2 = 80 + 30 * S(a + (k + 1) * Math.PI / 2);
        if (x2 > x1) fill(c, [6, 14, 3, 1][k], x1, y, x2 - x1, 1);
      }
    }
  },
  filledvec(c, t) {
    cls(c); const p = CUBE.map(q => rot(q, t * .04, t * .027)), pr = q => [80 + q[0] * 26, 50 + q[1] * 26];
    for (const f of FACES) {
      const [a, b, d] = [pr(p[f[0]]), pr(p[f[1]]), pr(p[f[2]])];
      if ((b[0] - a[0]) * (d[1] - a[1]) - (b[1] - a[1]) * (d[0] - a[0]) <= 0) continue;
      c.fillStyle = P[f[4]]; c.beginPath(); f.slice(0, 4).forEach((i, k) => { const q = pr(p[i]); k ? c.lineTo(...q) : c.moveTo(...q); }); c.fill();
    }
  },
  discofloor(c, t) {
    cls(c); text(c, "OPENCODE", 50, 18, 7, 12);
    for (let y = 50; y < H; y++) {
      const z = 600 / (y - 44), s = 40 / z;
      for (let x = 0; x < W; x += 2) { const u = ((x - 80) * z / 40 + 100) | 0, v = (z + t * .3) | 0; fill(c, (u ^ v) & 1 ? 4 : 6, x, y, 2, 1); }
    }
  },
  digi(c, t) {
    cls(c); text(c, "HELLO CODEURS EN SEINE!", 12, 8, 13, 7);
    for (let x = 0; x < W; x++) {
      const v = S(x * .3 + t) * S(x * .05 + t * .3) * 25 * (0.5 + 0.5 * S(t * .1));
      fill(c, 5, x, 55 + Math.min(0, v), 1, Math.abs(v) + 1);
    }
  },
};

// map an effect id (docs/08 tables) to a renderer + options
const MAP = {
  A1: ["bars", { pal: [2, 2, 10, 10, 7, 7, 1, 7, 7, 10, 10, 2, 2, 0, 0, 0, 0] }], A2: ["bars", { speed: 3, dir: -1 }],
  A3: ["sinebars"], A4: ["textcycle"], A5: ["shine"], A6: ["scroller", { rainbow: 1 }], A7: ["scroller", { wobble: 1 }],
  A8: ["flash"], A9: ["fade"], A10: ["reveal"], A11: ["typer"], A12: ["waves"], A13: ["twinkle"], A14: ["glitch"],
  A15: ["shake"], A16: ["textcycle", { pal: [6, 6, 14, 14, 3, 3, 1, 1, 3, 3, 14, 14, 6, 6, 0, 0] }], A17: ["greetings"],
  B1: ["bigscroll", { size: 2 }], B2: ["upscroll"], B3: ["bigscroll", { size: 8 }], B4: ["waving", { border: 1 }],
  B5: ["waving"], B6: ["snake"], B7: ["stretch"], B8: ["starfield", { sprites: 1 }], B9: ["starfield"], B10: ["dycp"],
  B11: ["plasma"], B12: ["plasma", { fine: 1 }], B13: ["fire"], B14: ["matrix"], B15: ["swing"], B16: ["fld"],
  B17: ["border"], B18: ["curtains"], B19: ["sinebars", { text: 1 }], B20: ["sinebars", { depth: 1 }], B21: ["blend"],
  B22: ["ecm"], B23: ["dotball"], B24: ["bobs"], B25: ["rotozoom"], B26: ["multiplex"], B27: ["spritelogo"],
  B28: ["sequencer"], B29: ["beat"],
  C1: ["sideborder"], C2: ["techtech"], C3: ["dysp"], C4: ["fpp"], C5: ["vsp"], C6: ["fli"], C7: ["twister"],
  C8: ["filledvec"], C9: ["discofloor"], C10: ["stretch", { crunch: 1 }], C11: ["digi"], C12: ["plasma", { full: 1 }],
  T1: ["rotozoom"], T2: ["tunnel"],
};

// animate only visible canvases, 25 fps like a 2-frame C64 effect
const live = new Set();
const io = new IntersectionObserver(es => es.forEach(e => e.isIntersecting ? live.add(e.target) : live.delete(e.target)));
document.querySelectorAll("canvas[data-fx]").forEach(cv => {
  cv.width = W; cv.height = H; cv._t = 0; cv._ctx = cv.getContext("2d"); io.observe(cv);
  if (!MAP[cv.dataset.fx]) console.warn("no preview for", cv.dataset.fx);
});
let last = 0;
(function loop(ts) {
  if (ts - last > 40) {
    last = ts;
    for (const cv of live) {
      const m = MAP[cv.dataset.fx]; if (!m) continue;
      R._sx = cv._sx; R._f = cv._f; R[m[0]](cv._ctx, cv._t++, m[1] || {}); cv._sx = R._sx; cv._f = R._f;
    }
  }
  requestAnimationFrame(loop);
})(0);
