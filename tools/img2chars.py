#!/usr/bin/env python3
"""Convert a 1-bit image into a C64 character set slice + screen map (ACME source).

Usage:
  python3 tools/img2chars.py NAME INPUT [--svg-width PX] [--crop] [--optimize]
                             [--threshold N] [--first CODE] [--outdir src/gfx]

INPUT can be:
  - .txt  ASCII art, '#' = pixel on, anything else = off (one line per pixel row)
  - .png  8-bit PNG, pixel on when red channel >= threshold (default 128)
  - .svg  rendered with rsvg-convert (brew install librsvg) at --svg-width px on black

Options:
  --crop      crop to the bounding box of the lit pixels
  --optimize  try the 64 sub-cell offsets and keep the one with the fewest unique tiles

Outputs (in --outdir, default src/gfx):
  NAME.chars.asm  !byte data for char codes FIRST..255 (default 96..255, 1280 bytes).
                  Place it at CHARSET + FIRST*8. Codes 0..FIRST-1 are copied from the
                  ROM font at run time, so normal text keeps working in this charset.
                  Code $a0 is always a solid block (cursor / block logos use it).
  NAME.inc.asm    NAME_W, NAME_H, NAME_TILES constants (include near the top of the source).
  NAME.map.asm    the label NAME_map (W*H screen codes, row by row), put it with the data.
                  Empty cells use $20 (space), solid cells $a0.

Codes 91-95 are skipped by default because ACME's !scr maps "{|}~" to them.
"""
import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zlib

SPACE, SOLID = 0x20, 0xA0


def load_png(path):
    data = open(path, "rb").read()
    i, idat = 8, b""
    while i < len(data):
        length, kind = struct.unpack(">I4s", data[i:i + 8])
        chunk = data[i + 8:i + 8 + length]
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", chunk[:10])
            if depth != 8 or ctype not in (0, 2, 4, 6):
                sys.exit(f"{path}: only 8-bit grey/RGB/RGBA PNGs are supported")
        elif kind == b"IDAT":
            idat += chunk
        i += 12 + length
    bpp = {0: 1, 2: 3, 4: 2, 6: 4}[ctype]
    raw, stride, prev, o, rows = zlib.decompress(idat), w * bpp, bytearray(w * bpp), 0, []
    for _ in range(h):
        f = raw[o]
        cur = bytearray(raw[o + 1:o + 1 + stride])
        o += 1 + stride
        for x in range(stride):
            a = cur[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                cur[x] = (cur[x] + a) & 255
            elif f == 2:
                cur[x] = (cur[x] + b) & 255
            elif f == 3:
                cur[x] = (cur[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                cur[x] = (cur[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([cur[x * bpp] for x in range(w)])
        prev = cur
    return rows


def load_bitmap(path, svg_width, threshold):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".txt":
        lines = [l.rstrip("\n") for l in open(path)]
        w = max(len(l) for l in lines)
        return [[c == "#" for c in l.ljust(w)] for l in lines]
    if ext == ".svg":
        tmp = os.path.join(tempfile.mkdtemp(), "render.png")
        subprocess.run(["rsvg-convert", "-w", str(svg_width), "-b", "black", "-o", tmp, path], check=True)
        path = tmp
    return [[v >= threshold for v in row] for row in load_png(path)]


def crop(bm):
    ys = [y for y, r in enumerate(bm) if any(r)]
    xs = [x for x in range(len(bm[0])) if any(r[x] for r in bm)]
    return [r[min(xs):max(xs) + 1] for r in bm[min(ys):max(ys) + 1]]


def tiles_for(bm, ox, oy):
    h, w = len(bm), len(bm[0])
    cols, rows = (w + ox + 7) // 8, (h + oy + 7) // 8
    grid = []
    for cy in range(rows):
        line = []
        for cx in range(cols):
            t = []
            for py in range(8):
                b = 0
                for px in range(8):
                    x, y = cx * 8 + px - ox, cy * 8 + py - oy
                    b = (b << 1) | (1 if 0 <= x < w and 0 <= y < h and bm[y][x] else 0)
                t.append(b)
            line.append(tuple(t))
        grid.append(line)
    return grid


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("input")
    ap.add_argument("--svg-width", type=int, default=210)
    ap.add_argument("--threshold", type=int, default=128)
    ap.add_argument("--first", type=int, default=96)
    ap.add_argument("--crop", action="store_true")
    ap.add_argument("--optimize", action="store_true")
    ap.add_argument("--outdir", default="src/gfx")
    a = ap.parse_args()

    bm = load_bitmap(a.input, a.svg_width, a.threshold)
    if a.crop:
        bm = crop(bm)
    offsets = [(ox, oy) for oy in range(8) for ox in range(8)] if a.optimize else [(0, 0)]
    best = None
    for ox, oy in offsets:
        grid = tiles_for(bm, ox, oy)
        uniq = {t for line in grid for t in line} - {(0,) * 8, (255,) * 8}
        if best is None or len(uniq) < best[0]:
            best = (len(uniq), grid)
    _, grid = best

    pool = [c for c in range(a.first, 256) if c != SOLID and not 91 <= c <= 95]
    codes = {(0,) * 8: SPACE, (255,) * 8: SOLID}
    for line in grid:
        for t in line:
            if t not in codes:
                if not pool:
                    sys.exit(f"{a.name}: too many unique tiles (max {len([c for c in range(a.first, 256)]) - 1})")
                codes[t] = pool.pop(0)
    used = len(codes) - 2
    by_code = {c: t for t, c in codes.items()}
    by_code[SOLID] = (255,) * 8

    os.makedirs(a.outdir, exist_ok=True)
    src = os.path.relpath(a.input)
    hdr = f"; generated by tools/img2chars.py from {src} - do not edit (see `make gfx`)\n"
    with open(os.path.join(a.outdir, f"{a.name}.chars.asm"), "w") as f:
        f.write(hdr)
        f.write(f"; char codes ${a.first:02x}-$ff ({used} tiles used), place at CHARSET + ${a.first * 8:03x}\n")
        for c in range(a.first, 256):
            t = by_code.get(c, (0,) * 8)
            f.write("        !byte " + ",".join(f"${b:02x}" for b in t) + f"  ; ${c:02x}\n")
    h, w = len(grid), len(grid[0])
    with open(os.path.join(a.outdir, f"{a.name}.inc.asm"), "w") as f:
        f.write(hdr)
        f.write(f"{a.name}_W = {w}\n{a.name}_H = {h}\n{a.name}_TILES = {used}\n")
    with open(os.path.join(a.outdir, f"{a.name}.map.asm"), "w") as f:
        f.write(hdr)
        f.write(f"{a.name}_map:  ; {w}x{h}, row by row\n")
        for line in grid:
            f.write("        !byte " + ",".join(f"${codes[t]:02x}" for t in line) + "\n")
    print(f"{a.name}: {w}x{h} cells, {used} unique tiles (max {len(pool) + used})")


if __name__ == "__main__":
    main()
