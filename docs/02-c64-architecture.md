# 02 — C64 architecture (what a demo coder needs)

## CPU: 6510 at ~1 MHz

- PAL: **985,248 Hz**, **312 raster lines × 63 cycles = 19,656 cycles/frame**, 50 Hz.
- NTSC (not targeted): 1,022,727 Hz, 263 lines × 65 cycles.
- Registers: A, X, Y (8-bit), SP (page `$01xx`), status flags NV-BDIZC.
- Cycle costs to know by heart: `nop`/`inx`/`dex` 2; `lda #` 2; `lda zp` 3; `lda abs` 4;
  `lda abs,x` 4 (+1 if it crosses a page); `sta abs` 4; `sta abs,x` 5; `inc abs` 6;
  `jsr`/`rts` 6; `rti` 6; branch: 2 not taken, 3 taken, 4 taken across a page; `bit zp` 3.
- An interrupt costs 7 cycles, plus up to 7 more spent finishing the current instruction (this is the jitter).

## Memory map (64 KB)

| Range | Default | Notes |
|---|---|---|
| `$0000-$00ff` | Zero page | `$00/$01` = CPU port. Use `$02-$ff` freely once the KERNAL is off (this repo uses `$f0-$ff`). |
| `$0100-$01ff` | Stack | |
| `$0400-$07e7` | Screen RAM | 1000 bytes; sprite pointers at `$07f8-$07ff` |
| `$0801-…` | BASIC program start | where our PRG loads |
| `$a000-$bfff` | BASIC ROM | RAM underneath |
| `$d000-$dfff` | I/O (VIC, SID, colour RAM, CIAs) | or char ROM, or RAM |
| `$d800-$dbe7` | Colour RAM | 4-bit, fixed, cannot be relocated |
| `$e000-$ffff` | KERNAL ROM | RAM underneath; vectors `$fffa` NMI, `$fffc` RESET, `$fffe` IRQ |

### `$01` banking (CPU port)

| `$01` | `$a000` | `$d000` | `$e000` | Use |
|---|---|---|---|---|
| `$37` | BASIC | I/O | KERNAL | power-on |
| `$36` | RAM | I/O | KERNAL | keep KERNAL, free `$a000` |
| `$35` | RAM | I/O | RAM | **demo default**: I/O visible, everything else RAM |
| `$34` | RAM | RAM | RAM | full RAM; I/O invisible, so keep IRQs off |
| `$33` | RAM | Char ROM | RAM | copy the ROM font into RAM |

The VIC always sees **char ROM** at `$1000-$1fff` and `$9000-$9fff` of its bank (banks 0 and 2).
That's why the music at `$1000` doesn't clash with the default font, and why custom
charsets/sprites in bank 0 can't go there.

## VIC-II ($d000)

- **VIC bank** (16 KB the VIC can see): `$dd00` bits 0-1, inverted: `%11`=$0000, `%10`=$4000,
  `%01`=$8000, `%00`=$c000. Screen, charset, bitmap and sprites must all sit in that bank.
- `$d018`: bits 4-7 = screen offset / `$400`; bits 1-3 = charset offset / `$800`
  (bitmap: bit 3 = bitmap at +`$2000`). `$17` = screen `$0400` + ROM lower/upper case.
- `$d011`: bit 7 = raster bit 8, bit 6 ECM, bit 5 bitmap, bit 4 display enable (DEN), bit 3 = 25/24 rows,
  bits 0-2 = YSCROLL. Default `$1b`.
- `$d016`: bit 4 multicolour, bit 3 = 40/38 columns, bits 0-2 = XSCROLL. Default `$c8`.
- `$d012`: read = current raster line (low 8 bits), write = IRQ compare line.
- `$d019`/`$d01a`: IRQ status (write 1 to acknowledge) / enable (bit 0 = raster).
- Raster geometry (PAL): visible display rows from line `$33` (51) to `$fa` (250).
  Text row `r` starts at line `$33 + r*8` (with YSCROLL=3). Top border ~ lines 16-50, bottom 251-299.
- **Badlines**: on the first line of each text row (when `(line & 7) == YSCROLL` and DEN is on), the VIC
  steals **40 cycles** to fetch characters, leaving only about 23 for the CPU. Sprites steal about 2 cycles
  each on lines where they are displayed. That's why cycle-exact loops run in the border or with DEN=0,
  or are tuned per line (see "FLD" and "stable raster" in 04).
- Sprites: 8 hardware sprites of 24×21 px, data blocks of 64 bytes, pointer = address/64, pointers at
  screen+`$3f8`. Registers: X/Y `$d000-$d00f`, X bit 8 `$d010`, enable `$d015`, colours `$d027-$d02e`,
  multicolour `$d01c` + `$d025/$d026`, expand `$d017/$d01d`, priority `$d01b`.
- Colours: 0 black, 1 white, 2 red, 3 cyan, 4 purple, 5 green, 6 blue, 7 yellow, 8 orange, 9 brown,
  10 light red, 11 dark grey, 12 grey, 13 light green, 14 light blue, 15 light grey.

## SID ($d400)

3 voices (`$d400`, `$d407`, `$d40e`: freq lo/hi, pulse lo/hi, control, AD, SR), filter
`$d415-$d417`, volume + filter mode `$d418`. Music is almost always a precompiled player
(`init` + `play` called once per frame). See 05.

## CIA

- CIA1 `$dc00`: keyboard matrix, joystick port 2 (`$dc00`), port 1 (`$dc01`); timer IRQ (KERNAL 60 Hz).
- CIA2 `$dd00`: VIC bank bits, serial bus; its interrupts go to the **NMI** (also triggered by the RESTORE key).
- `$dc0d`/`$dd0d` = interrupt control: write `$7f` to disable all, read to acknowledge.

Space bar check (for a "press space" exit): `lda #$7f : sta $dc00 : lda $dc01 : and #$10 : beq pressed`.
