# AGENTS.md

A Commodore 64 demo (demoscene style) written in 6502 assembly that presents **opencode** at
**Codeurs en Seine 2026** (Rouen, Kindarena, 19 November 2026, https://www.codeursenseine.com/2026).
It must run on a **real PAL C64**, loaded from a 1541 / SD2IEC / Kung Fu Flash.
It is also the subject of a live presentation where opencode edits the demo on stage with a
fast model. Keep every change small, quick to build and easy to verify.

The demo shows one screen, **"ces" (D07)**: Codeurs en Seine logo and Rouen skyline over the Seine.
Copper bars and the scroller are always on.

## Preview a part

`Init demo with "Part "ces" (full screen)" (D07) screen and  launch vice.` is a preview request.
Run `make run PART=ces` without editing files. Use plain `make run` for the stage build.

## Layout

| Path | Content |
|---|---|
| `src/main.asm` | The demo (single file, ACME syntax). Entry point of `make`. |
| `src/gfx/*.asm` | **Generated** charset graphics (`make gfx`). Don't edit by hand: edit `assets/` and regenerate. |
| `src/music/` | Optional `music.sid` (PSID, load $1000), enabled with `make MUSIC=1`. |
| `assets/` | Graphic sources: `codeurs-en-seine-logo.svg` (official white logo), `rouen.txt` (320x80 ASCII-art skyline, `#` = pixel). |
| `assets/sid/` | Candidate SID tunes from HVSC (electro shortlist + classics). `assets/sid/README.md` lists load/init/play addresses, SID model, zero-page clashes and whether each fits. Copyrighted: don't ship without permission. |
| `include/c64.asm` | Shared hardware constants and macros (`basic_upstart`, `demo_init`, `set_irq`, `irq_enter/exit`, `fill_1000`). |
| `docs/` | All documentation, **read the relevant file before coding**. Index: `docs/README.md`. |
| `docs/examples/` | Standalone examples: `00-04` basics, plus one per library effect (`A01`…`C12`, IDs from `docs/08`). Read the matching one before integrating an effect; check its `Limitations:` header. Built by `make examples`. |
| `tools/img2chars.py` | Converts SVG/PNG/ASCII art into a charset slice + screen map (see its docstring). |
| `tools/pngsum.py` | Turns a VICE screenshot into a text summary, used for headless checks. |
| `build/` | Generated output (git-ignored). |

## Commands

```sh
make              # demo + examples -> build/opencode.prg, build/examples/*.prg
make run          # launch demo in VICE (x64sc, PAL)
make run PART=ces        # open D07 in VICE (separate preview build)
make check-part PART=ces # two headless captures, no other examples
make run-example EX=02_stable_raster_bars
make d64          # build/opencode.d64 for real hardware
make shots        # headless: screenshot each PRG after ~9M cycles + text summary
make check-examples  # headless smoke test of every docs/examples PRG (blank / static / ok)
make gfx          # regenerate src/gfx/*.asm from assets/ (needs rsvg-convert for the SVG)
make MUSIC=1      # include src/music/music.sid
```

Toolchain: `acme` 0.97 (`brew install acme`), VICE 3.x (`x64sc`, `c1541`), `python3`,
optionally `rsvg-convert` (`brew install librsvg`). Details: `docs/01-toolchain.md`.

## Rules

- **Assembler is ACME.** Don't mix in KickAssembler or ca65 syntax (`.byte`, `.macro`, `:label`).
  ACME: `!byte`, `!word`, `!scr` (screen codes), `!text` (PETSCII), `!for`, `!if`, `!macro`/`+macro`,
  anonymous labels `-`/`+`, local labels `.name` (scoped to the zone or macro).
- **Target is PAL** (312 lines, 63 cycles per line, 985248 Hz). Cycle-counted code assumes PAL.
- **The KERNAL is banked out** (`$01=$35`). Never call KERNAL routines after `+demo_init`.
  IRQs go through `$fffe/$ffff`, so handlers must save and restore A/X/Y themselves (`+irq_enter`/`+irq_exit`).
- **Timing-critical code** (stable raster, cycle loops) must sit in one page (`!align 255,0`), and any
  table read with `,x` inside it must not cross a page. Write the cycle count in comments, for example `; 4`.
- Work in the main loop is synced on `frame_flag`, which `irq_bottom` sets once per frame. Anything
  that writes `$d016` or the scroller row must run after line `$fc` and before `SPLIT_LINE`.
- IRQ chain per frame: `irq_bars1/2` (`$10`) → `irq_mid` (`$9d`, charset B) → `irq_split` (`$f0`)
  → `irq_bottom` (`$fc`, charset A, music, `frame_flag`). Each handler sets up the next one.
- **Memory map** (`src/main.asm`): code `$0801-$0fff` (an `!error` guard enforces it), music
  `$1000-$1fff`, charset A `$2000`, charset B `$2800`, **all data from `$3000`**, zero page `$20-$21`, `$2a-$2d`.
  New tables and texts go after `DATA_START`, not in the code area. Before adding big data, read
  `docs/02-c64-architecture.md` (VIC banks) and update the map in `docs/06-demo-plan.md`.
- **Charsets**: codes `$00-$5f` are the ROM font (copied at start-up), `$60-$ff` are graphic tiles,
  `$a0` is always a solid block. Charset A is used above row 13 and B below, so **row 13 must only
  hold text or spaces**. Each charset has at most 159 tiles; `tools/img2chars.py` fails if an image needs more.
- In texts, use `!scr` (screen codes). **Avoid `@`** (screen code 0 ends the text) and `{|}~`
  (codes `$5b-$5e`). Lowercase and uppercase letters, digits and normal punctuation are fine.
- Keep the PRG small and loadable with `LOAD"*",8` then `RUN` (BASIC upstart at `$0801`, `SYS 2061`).

## Checking a change (do this every time)

1. `make` must finish with no errors or warnings.
2. Run `make check-part PART=ces` for live edits. Run `make shots` for the full rehearsal
   or toolchain/IRQ changes; inspect the fresh D07 capture for uniform bars, logo, skyline, and scroller.
3. Timing-sensitive changes: check `build/opencode.lst` for page crossings
   (high byte of the address before and after a loop).
4. Only the user can test on real hardware. Say so when a change depends on timing.
5. **Automated VICE runs always use `-console`** (no window). Never open a VICE window during checks:
   it steals focus from the user. Open a window via `make run` or `make run-example` only when asked.

## Documentation map

- `docs/01-toolchain.md`: ACME, VICE, c1541, exomizer, debugging with the VICE monitor
- `docs/02-c64-architecture.md`: memory map, banking, VIC-II, SID, CIA, timing
- `docs/03-executable-basics.md`: PRG format, BASIC upstart, taking over the machine, IRQ setup
- `docs/04-demo-effects.md`: catalogue of demo effects and how they work (with examples)
- `docs/05-music.md`: SID music integration
- `docs/06-demo-plan.md`: the demo's structure and memory map
- `docs/opencode/`: the live presentation scenario (prompts, fallback branches, setup, rehearsal log)
- `docs/07-real-hardware.md`: moving the demo to a real C64
- `docs/effects.html`: generated visual catalogue. When adding a demo effect, follow the stable `D` reference
  workflow in `docs/08-effects-library.md` and regenerate with `make gifs` then `make effects-page`.
- `docs/08-effects-library.md`: effects catalogue by tier (A = one prompt, B = small routine, C = cycle-exact), with recipes and Codebase64 links
- `docs/references.md`: external references
