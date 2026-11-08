# 07 — Running on a real C64

## Getting the file onto the machine

| Device | What to copy | How to start |
|---|---|---|
| SD2IEC | `build/opencode.prg` (or `.d64`) | `LOAD"OPENCODE",8` / `RUN` (or browse with a file browser) |
| Kung Fu Flash / EasyFlash 3 + KFF | `opencode.prg` on the SD card | pick it in the menu (it loads instantly) |
| 1541 Ultimate / Ultimate 64 | `.prg` or `.d64` | "Run" from the menu, or load over the network with `ucodenet` / the web UI |
| Real 1541 floppy | `.d64` written with a ZoomFloppy (`d64copy`) or a 1541 Ultimate | `LOAD"*",8` / `RUN` |

The PRG is about 12 KB (charsets at `$2000-$2fff`, data from `$3000`, zero-filled gaps). It loads
instantly on Kung Fu Flash / 1541 Ultimate. A stock 1541 with no fastloader needs about 30 s, so use
`make packed` (exomizer) for that case.

## Things that differ from VICE

- **PAL vs NTSC**: the timing is for PAL (63 cycles per line). On NTSC (65 cycles) the stable bars will slant.
  Check that the machine is PAL (European C64). Detection could be added later (count raster lines).
- **VIC revisions** (6569R1/R3/R5, 8565): small differences in grey dots and light-grey colour on `$d020` writes.
  These are cosmetic.
- **Old vs new SID** (6581 vs 8580): filters and the volume of digis sound different. Test the music on both in VICE
  (`-sidmodel 0` for 6581, `-sidmodel 1` for 8580).
- **Cartridges/freezers** (Action Replay, etc.) can change memory or timing: turn them off.
- Colours look softer on a CRT. Glitches seen in VICE with "Debug border" are real on hardware too.

## Pre-show checklist

1. `make clean && make && make d64`, then `make shots` and check the summary.
2. Run the D64 in VICE with true drive emulation: `x64sc -pal -autostart build/opencode.d64`.
3. Copy it to the SD card / device and test on the real C64 the day before.
4. Bring a backup: a second SD card, plus a laptop running VICE in case the hardware fails.
