#!/usr/bin/env python3
"""Capture an animated GIF of a PRG running in VICE (no dependencies besides x64sc).

Usage:
  python3 tools/capture_gif.py PRG OUT.gif --start CYCLES [--frames 12] [--step 2]
                               [--crop X,Y,W,H] [--scale 1] [--sidmodel 1] [--jobs 8]

VICE has no "record GIF" option, so each frame is a separate headless run of x64sc stopped at
START + i*STEP*19656 cycles (19656 = one PAL frame) with -exitscreenshot. Runs are parallel.
--step is in video frames (2 = 25 fps playback). Screenshots are 384x272 (PAL, borders included):
text row r starts at y = 35 + r*8, column c at x = 32 + c*8.
"""
import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zlib

PAL_FRAME = 63 * 312
sys.path.insert(0, os.path.dirname(__file__))


def load_png(path):
    data = open(path, "rb").read()
    i, idat = 8, b""
    while i < len(data):
        length, kind = struct.unpack(">I4s", data[i:i + 8])
        chunk = data[i + 8:i + 8 + length]
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", chunk[:10])
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
        rows.append([tuple(cur[x * bpp:x * bpp + 3]) for x in range(w)])
        prev = cur
    return w, h, rows


def lzw(indices, min_size=8):
    """GIF LZW: returns the packed sub-block bytes."""
    clear, eoi = 1 << min_size, (1 << min_size) + 1
    out, bitbuf, nbits = bytearray(), 0, 0

    def emit(code, size):
        nonlocal bitbuf, nbits
        bitbuf |= code << nbits
        nbits += size
        while nbits >= 8:
            out.append(bitbuf & 255)
            bitbuf >>= 8
            nbits -= 8

    table = {(i,): i for i in range(clear)}
    size, nxt = min_size + 1, eoi + 1
    emit(clear, size)
    w = ()
    for k in indices:
        wk = w + (k,)
        if wk in table:
            w = wk
            continue
        emit(table[w], size)
        if nxt < 4096:
            table[wk] = nxt
            nxt += 1
            if nxt > (1 << size) and size < 12:
                size += 1
        else:
            emit(clear, size)
            table = {(i,): i for i in range(clear)}
            size, nxt = min_size + 1, eoi + 1
        w = (k,)
    if w:
        emit(table[w], size)
    emit(eoi, size)
    if nbits:
        out.append(bitbuf & 255)
    blocks = bytearray()
    for i in range(0, len(out), 255):
        blocks += bytes([len(out[i:i + 255])]) + out[i:i + 255]
    return bytes(blocks) + b"\0"


def write_gif(path, frames, w, h, delay_cs):
    palette = sorted({px for f in frames for row in f for px in row})
    if len(palette) > 256:
        sys.exit("too many colours for a GIF")
    index = {c: i for i, c in enumerate(palette)}
    pal = b"".join(bytes(c) for c in palette) + b"\0\0\0" * (256 - len(palette))
    g = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0xF7, 0, 0) + pal)
    g += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\0\0\0"  # loop forever
    for f in frames:
        g += b"\x21\xf9\x04\x04" + struct.pack("<H", delay_cs) + b"\0\0"
        g += b"\x2c" + struct.pack("<HHHHB", 0, 0, w, h, 0) + b"\x08"
        g += lzw([index[px] for row in f for px in row])
    g += b"\x3b"
    open(path, "wb").write(g)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("prg")
    ap.add_argument("out")
    ap.add_argument("--start", type=int, required=True, help="cycles before the first frame")
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--step", type=int, default=2, help="video frames between captures")
    ap.add_argument("--crop", default=None, help="X,Y,W,H in screenshot pixels")
    ap.add_argument("--scale", type=int, default=1, help="integer downscale (2 = half size)")
    ap.add_argument("--sidmodel", default="1")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--x64", default="x64sc")
    a = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="capgif")
    shots = [os.path.join(tmp, f"f{i:03d}.png") for i in range(a.frames)]
    cmds = [[a.x64, "-console", "-pal", "-default", "+sound", "-warp", "+autostart-delay-random",
             "-autostartprgmode", "1", "-limitcycles", str(a.start + i * a.step * PAL_FRAME),
             "-exitscreenshot", s, "-autostart", a.prg] for i, s in enumerate(shots)]
    for i in range(0, len(cmds), a.jobs):
        procs = [subprocess.Popen(c, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                 for c in cmds[i:i + a.jobs]]
        for p in procs:
            p.wait()
    frames = []
    for s in shots:
        if not os.path.exists(s):
            sys.exit(f"VICE did not write {s}")
        w, h, rows = load_png(s)
        x, y, cw, ch = map(int, a.crop.split(",")) if a.crop else (0, 0, w, h)
        rows = [r[x:x + cw] for r in rows[y:y + ch]]
        if a.scale > 1:
            rows = [r[::a.scale] for r in rows[::a.scale]]
        frames.append(rows)
    fh, fw = len(frames[0]), len(frames[0][0])
    write_gif(a.out, frames, fw, fh, max(2, round(a.step * 2)))  # 1 PAL frame = 2 cs
    print(f"{a.out}: {fw}x{fh}, {a.frames} frames")


if __name__ == "__main__":
    main()
