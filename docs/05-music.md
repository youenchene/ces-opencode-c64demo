# 05 — SID music

## How it works

Almost every C64 tune is a precompiled player and its data, relocated to a fixed address, with two entry points:

- `init` (usually the load address): call once with `A = sub-tune number`.
- `play` (usually `init+3`): call **once per frame**, from a raster IRQ.

The player takes about 1,500 to 4,000 cycles per frame (up to 4,000 for heavy tunes). In `src/main.asm` it is called from
`irq_bottom`, in the bottom border, where nothing else is timing-critical.

## Adding a tune

1. Pick a `.sid` (PSID) whose **load address is `$1000`** and that fits under `$2000`. Check the header with
   `sidplayfp -v` or a hex dump: offset `$08` = load address (0 means it's in the first 2 data bytes),
   `$0a` = init, `$0c` = play.
2. Copy it to `src/music/music.sid`.
3. `make MUSIC=1 run`.

`src/main.asm` skips `$7e` bytes (`$7c` PSID v2 header + 2-byte load address). If `init`/`play` aren't
`$1000`/`$1003`, change `MUSIC_INIT`/`MUSIC_PLAY`. If the tune loads elsewhere, move it and check that it
doesn't overlap code. An `!error` guard catches code reaching `$1000`.

The tune must fit in `$1000-$1fff` (4 KB): charset A starts at `$2000`, and an `!error` guard stops the
build if the music overlaps it. Code stays below `$1000` and data starts at `$3000`, so neither moves when
music is enabled.

## Current tune: Teh Disco (Jammer, 2006)

`src/music/music.sid` is a copy of `assets/sid/Teh_Disco.sid`. Music is on by default whenever that file
exists (`make MUSIC=0` to build without it). `make run` starts VICE with the 8580 model (`SIDMODEL=1`).
Checked: the player only touches zero page `$fb/$fc` (our pointers moved to `$20-$2d`); a 9 s VICE WAV
recording has sound throughout. `make TIMING=1` turns the border white while `play` runs: in sampled
frames it took 1 to 13 raster lines (about 60-800 cycles), well inside the bottom-border budget.

## Shortlist: modern demoscene / electro tunes (HVSC, checked November 2026)

The files are stored in `assets/sid/` (index with all addresses: `assets/sid/README.md`).
Headers read from the files on hvsc.c64.org (`MUSICIANS/...`). "ZP" lists zero-page pointers the player
uses that clash with ours (`$f0-$fd`). The scan only finds `(zp),y` pointers, so treat it as a hint.

| Tune | Composer / group | Memory | Model | Fit today? |
|---|---|---|---|---|
| **Teh Disco** (2006) | Jammer / EXON, MultiStyle Labs | `$1000-$1ea8` (3.7 KB) | 8580 | Fits the `$1000` slot. ZP `$fb $fd` |
| **Elektro Klacz** (2018) | Jammer / Triad, Genesis Project | `$1000-$202b` (4.1 KB) | 8580 | 44 bytes too big for the slot. ZP `$fb` |
| **Club Style** (2004) | Jammer / EXON, MultiStyle Labs | `$1000-$261e` (5.6 KB) | 8580 | Needs the bigger slot. ZP `$fc` |
| **Disco Proxima** (2019) | Mibri / Proxima | `$e000-$ed52` (3.4 KB) | 8580 | RAM under the KERNAL is free. Needs a copy at start-up. ZP `$fc` |
| **Galax(it)y** (1988) | Laxity / 2000 A.D. | `$1000-$17bf` (2 KB) | 6581 | Fits the `$1000` slot. ZP `$fc`. Play is `$1006` |
| **Rasters** (2019) | Jammer / Samar | `$3200-$34b4` (0.7 KB) | both | Overlaps data at `$3000`. No ZP clash |
| Synthony (1989-90) | Laxity / Flexible Arts | `$0f00-$22ff` (5 KB) | 6581 | Overlaps the code area. Play is `$1006` |

All of them are standard tunes called once per frame (VBI), so they work with `irq_bottom`. The table only
lists file data: none of these tunes has been listened to or run in the demo yet.

Left out:
- **CIA timing**: 808 Love, Age We Aceeed (LMan), Big Beat (Jammer), MOSH Technology and Super Solenoid
  Engine (Mibri) use a CIA timer, so their play routine expects a rate other than once per frame.
- **RSID, 30-40 KB**: Mo's Techno Logy, Robot Sensuality, Pixelated Neon Nights, Clubster, Microgroove
  (LMan), Hypersonic Lovers and Supercharger (Mibri). These take over the whole machine.
- **Overlaps the screen or the code area**: Echo Beat (`$0400`) and Neon Sunrise (`$0c00`).

Two small changes make most of the shortlist usable:
1. Move our zero-page pointers from `$f0-$fd` to `$20-$2d`. None of the shortlisted players uses that range,
   and BASIC/KERNAL are banked out.
2. For tunes over 4 KB, use an 8 KB music slot: `$1000-$2fff` for the music, charsets at `$3000`/`$3800`,
   and data from `$4000`. That stays in VIC bank 0, and the VIC sees char ROM only at `$1000-$1fff`.

### Rights-free alternative: an original tune

`youenchene/leeloo_s_journey` (private) already has a small 2-voice player (901 bytes, about 111 cycles per
frame, voice 3 left free for effects). It also has a score-in-JSON → PSID pipeline, a py65 register check,
and VICE WAV rendering (`x64 -sounddev wav`), so a tune can be checked without listening to it. Its style is
gentle (triangle waves). A "Codeurs en Seine" electro tune would need drums (noise and pulse) and filter
sweeps added to that player.

## Sources and licensing

- HVSC (High Voltage SID Collection), hvsc.c64.org, has nearly every C64 tune ever made.
  **For a public presentation, use a tune you have permission for**, or one released for reuse, or write your own.
- Trackers for making music: GoatTracker 2 (cross-platform), SID-Wizard (native), CheeseCutter.
  They export a relocatable PRG/SID with init and play addresses.
