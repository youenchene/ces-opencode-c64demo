# 01 — Toolchain

| Tool | Role | Install |
|---|---|---|
| ACME 0.97 | Cross-assembler (6502) | `brew install acme` |
| VICE 3.x (`x64sc`) | Cycle-exact C64 emulator | `brew install vice` |
| `c1541` (VICE) | Builds `.d64` disk images | with VICE |
| exomizer 3 (optional) | Packer/cruncher, makes a self-extracting PRG | build from source (bitbucket.org/magli143/exomizer) |
| SID player (optional) | Listen to `.sid` files | `sidplayfp`, or VICE `vsid` |
| python3 | `tools/img2chars.py`, `tools/pngsum.py` (no extra packages) | preinstalled on macOS |
| rsvg-convert (optional) | Renders `assets/*.svg` for `make gfx` | `brew install librsvg` |

## Graphics: `tools/img2chars.py`

```sh
make gfx                                                   # regenerate everything in src/gfx/
python3 tools/img2chars.py NAME INPUT [--svg-width PX] [--crop] [--optimize] [--first 96]
```

Input is `.svg`, `.png` (8-bit) or `.txt` ASCII art (`#` = pixel). Output: `src/gfx/NAME.inc.asm`
(sizes, include at the top), `NAME.chars.asm` (tiles for codes `$60-$ff`, put at charset + `$300`) and
`NAME.map.asm` (screen codes). The generated files are committed, so a normal `make` needs neither
Python nor rsvg. See `docs/06-demo-plan.md#graphics-pipeline`.

## ACME cheat sheet

```asm
!source "c64.asm"          ; include (search path: -I include)
!bin "file", size, skip    ; binary include (e.g. SID without header)
* = $0801                  ; set program counter
label:  lda #$00           ; global label
.local  rts                ; local to current zone / macro / !for block
-       dex                ; anonymous backward label, referenced with "bne -"
        beq +              ; anonymous forward label "+"
!byte 1, $02, %00000011    ; bytes ; binary can use . and # : %..##..##
!word $1234                ; little-endian 16 bit
!scr "hello"               ; SCREEN codes (for writing into screen RAM)
!text "hello"              ; raw PETSCII/ASCII (for KERNAL / comparisons)
!fill 16, $ea              ; 16 x $ea
!align 255, 0              ; pad to next page boundary
!for i, 0, 255 { !byte int(127 + 127*sin(float(i)*2*3.14159265/256)) }
!if MUSIC { ... }          ; conditional assembly (-DMUSIC=1 on command line)
!macro name .arg { ... }   ; macro definition, call with +name value
!error "msg"               ; abort assembly (use for overlap checks)
```

Useful flags (see the `Makefile`): `-f cbm` (PRG with 2-byte load address), `-l file.sym` (labels),
`-r file.lst` (listing with addresses and bytes, handy for page-crossing checks), `-DNAME=value`.

Don't use `-Wtype-mismatch`: the shared macros use plain numbers as addresses and it would warn on every line.

## VICE

```sh
x64sc -pal -autostart build/opencode.prg          # normal run
x64sc -pal -warp -autostart ...                   # warp mode
x64sc -pal -default -warp -autostartprgmode 1 \
      -limitcycles 9000000 -exitscreenshot out.png -autostart prg   # headless screenshot (exit code 1 is normal)
x64sc -moncommands build/opencode.sym ...          # load labels into the monitor
```

- `-autostartprgmode 1` injects the PRG into RAM (fast, no drive emulation).
- Monitor: `Alt+H` (or `Cmd+H` on macOS). Useful commands: `r` (registers), `m 0400` (memory dump),
  `d 0900` (disassemble), `break irq_bars1`, `chis` (CPU history, which shows the exact cycle timing),
  `io d000` (VIC registers).
- Settings → Video → "Show border" and "Debug border mode" let you see the full raster area,
  including side borders.
- Turn on the "Raster lines" debug overlay to see where your IRQs actually fire.

## Headless checking (for agents)

### Repo-local VICE MCP

`opencode.json` enables [vice-mcp](https://github.com/simen/vice-mcp) for this
repository only. Its installation lives in the git-ignored `.opencode/vice-mcp/`.
To install it again on another checkout:

```sh
git clone https://github.com/simen/vice-mcp.git .opencode/vice-mcp
git -C .opencode/vice-mcp checkout d06d2ef71d31e7b5cb4876cdb2c8e6e28c665aeb
npm --prefix .opencode/vice-mcp install
npm --prefix .opencode/vice-mcp audit fix
npm --prefix .opencode/vice-mcp run build
opencode mcp list
```

Start the emulator with its binary monitor bound to localhost before using the
MCP `connect` tool (default endpoint `127.0.0.1:6502`):

```sh
x64sc -pal -binarymonitor -binarymonitoraddress ip4://127.0.0.1:6502 \
      -autostartprgmode 1 -autostart build/opencode.prg
```

### Screenshot checks

`make shots` screenshots every PRG and prints a text summary for each raster row, using `tools/pngsum.py`:
the border colour, the dominant background colour and the number of other pixels (`fg`). A
stable raster bar should show `fg=0` on each line. If the colour changes partway through a line,
`fg` jumps to a few hundred. Text row `r` starts at screenshot y = `35 + r*8`.

## d64 and packing

```sh
make d64        # c1541 -format "opencode,oc" d64 build/opencode.d64 -write build/opencode.prg opencode
make packed     # exomizer sfx basic -o build/opencode-packed.prg build/opencode.prg
```

Packing only matters on a stock 1541 once the PRG goes over roughly 20 KB. The current demo is about 2 KB.
