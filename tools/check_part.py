#!/usr/bin/env python3
"""Smoke-test one direct-start PAL build with two fresh VICE screenshots."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from capture_gif import PAL_FRAME, load_png


BLACK = (0, 0, 0)


def capture(x64, prg, path, frame):
    result = subprocess.run(
        [x64, "-console", "-pal", "-default", "+sound", "-warp",
         "+autostart-delay-random", "-autostartprgmode", "1",
         "-limitcycles", str(6_000_000 + frame * PAL_FRAME),
         "-exitscreenshot", str(path), "-autostart", str(prg)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    if not path.is_file():
        raise ValueError(f"VICE did not save {path.name} (exit {result.returncode}):\n{result.stdout}")
    width, height, rows = load_png(path)
    if (width, height) != (384, 272):
        raise ValueError(f"Expected a 384×272 PAL capture, got {width}×{height}")
    return rows


def check_frame(rows, top_bars):
    top = rows[:35]
    if top_bars:
        if not any(row[2] != BLACK for row in top):
            raise ValueError("D07 top bars are missing")
        if any(len(set(row[32:352])) != 1 for row in top):
            raise ValueError("D07 top bars change colour within a scanline")
    elif any(pixel != BLACK for row in top for pixel in row):
        raise ValueError("Expected a black top border")

    if not any(pixel != BLACK for row in rows[227:235] for pixel in row[40:344]):
        raise ValueError("Bottom scroller is not visible")

    picture = [row[32:352] for row in rows[35:227]]
    if not any(pixel != BLACK for row in picture for pixel in row):
        raise ValueError("Picture area is blank")
    return picture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prg", type=Path)
    parser.add_argument("--x64", default="x64sc")
    parser.add_argument("--top-bars", action="store_true")
    args = parser.parse_args()

    try:
        with TemporaryDirectory(dir=args.prg.parent) as tmp:
            paths = [Path(tmp) / f"{args.prg.stem}-{i}.png" for i in (1, 2)]
            with ThreadPoolExecutor(max_workers=2) as pool:
                shots = [pool.submit(capture, args.x64, args.prg, path, frame)
                         for path, frame in zip(paths, (0, 23))]
                pictures = [check_frame(shot.result(), args.top_bars) for shot in shots]
            if pictures[0] == pictures[1]:
                raise ValueError("Picture area did not change between captures")
            for path in paths:
                path.replace(args.prg.parent / path.name)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"{args.prg.stem}: {exc}\n")
    print(f"{args.prg.stem}: picture changes, scroller visible, top border correct")
    print(f"Captures: {args.prg.parent / paths[0].name}, {args.prg.parent / paths[1].name}")


if __name__ == "__main__":
    main()
