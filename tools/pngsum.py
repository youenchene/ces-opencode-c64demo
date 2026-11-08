#!/usr/bin/env python3
"""Text summary of a VICE screenshot (no dependencies).

Usage: python3 tools/pngsum.py build/shots/opencode.png [...]

For every group of identical raster rows it prints:
  y  <border colour at x=2>  bg=<dominant colour of the inner area>  fg=<pixels != bg>
Lets an agent check, without seeing the image, that:
  - raster bars are stable (one colour per line, nothing changing partway through a line),
  - text/logo/scroller rows contain pixels (fg>0) where expected,
  - split colours change at the expected lines.
VICE screenshots are 384x272 (PAL, borders included). Text row r starts at y = 35 + r*8.
"""
import struct
import sys
import zlib


def load(path):
    data = open(path, "rb").read()
    i, idat = 8, b""
    while i < len(data):
        length, kind = struct.unpack(">I4s", data[i:i + 8])
        chunk = data[i + 8:i + 8 + length]
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", chunk[:10])
            assert depth == 8 and ctype in (0, 2, 4, 6), "only 8-bit non-palette PNGs"
        elif kind == b"IDAT":
            idat += chunk
        i += 12 + length
    raw, bpp = zlib.decompress(idat), {0: 1, 2: 3, 4: 2, 6: 4}[ctype]
    stride, rows, prev, o = w * bpp, [], bytearray(w * bpp), 0
    for _ in range(h):
        f = raw[o]
        o += 1
        cur = bytearray(raw[o:o + stride])
        o += stride
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
        rows.append(cur)
        prev = cur
    if bpp != 4:  # normalise to RGBA rows
        rows = [bytearray(b for x in range(w) for b in
                          ((r[x * bpp],) * 3 if bpp < 3 else tuple(r[x * bpp:x * bpp + 3])) + (255,))
                for r in rows]
    return w, h, rows


for path in sys.argv[1:]:
    w, h, rows = load(path)
    print("==", path, f"{w}x{h}")
    last = None
    for y in range(h):
        r = rows[y]
        px = [tuple(r[x * 4:x * 4 + 3]) for x in range(w)]
        inner = px[32:352]
        bg = max(set(inner), key=inner.count)
        fg = sum(1 for q in inner if q != bg)
        s = f"border={px[2]} bg={bg} fg={fg}"
        if s != last:
            print(f"{y:3d} {s}")
            last = s
