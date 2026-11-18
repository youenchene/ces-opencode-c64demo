# 04 — Demo effects catalogue

Each entry covers what it is, how it works, what it costs, and where it is implemented in this repo.
Status: ✅ = example and/or used in `src/main.asm`, 📝 = described only (a good candidate for a live edit).
For issue reports and live prompts, use the [stable demo references](08-effects-library.md#in-the-demo--stable-references).

PAL budget reminder: 19,656 cycles per frame, 63 per line, about 23 on a badline.

---

## Raster IRQ splits ✅ {#raster-irq}

`docs/examples/01_raster_irq.asm`, used in `src/main.asm` (`irq_split`, `irq_bottom`).

Ask the VIC for an interrupt at line N (`$d012`). The handler changes registers (colours, scroll,
charset, mode), then re-programs `$d012` and `$fffe` for the next zone. A chain of handlers splits the
screen into independent areas. Jitter: 7 to 14 cycles after the line starts, which is fine for
changes made in the border or between text rows.

## Stable raster (double IRQ) ✅ {#stable-raster}

`docs/examples/02_stable_raster_bars.asm`, `src/main.asm` (`irq_bars1`/`irq_bars2`).

Needed for anything that has to land on an exact cycle (colour changes mid-line, open side borders).

1. IRQ 1 at line N: set the vector to IRQ 2 and `$d012 = N+1`, acknowledge, `tsx`, `cli`, then a run of `nop`s.
2. IRQ 2 interrupts a `nop` (2 cycles), so the jitter is now 0 or 1 cycle. `txs` drops the stack frame.
3. Burn cycles until the end of the line, then `lda $d012 : cmp $d012 : beq +` → `+`. If the line changed between
   the two reads, the branch isn't taken (2 cycles instead of 3), which absorbs the last cycle.
4. From here the code is cycle-exact. A loop of exactly **63 cycles** changes `$d020` at the same
   position on every line.

Pitfalls: a page crossing inside the timed code (`!align`), badlines (do the loop in the border or with
DEN=0, or use a per-line timing table), sprites on those lines (each steals cycles), NTSC (65 cycles).

## Raster bars / colour cycling ✅ {#raster-bars}

A colour table written to `$d020`/`$d021` once per line, rotated every frame by the main loop. Variants:
sine-moved bars (draw several bar "sprites" into a cleared table at `sine[t+i]`), bars behind text
(change `$d021` only), "copper" gradients using brightness-sorted palettes:
`0,6,9,11,2,4,8,12,14,10,5,15,3,7,13,1` (dark → light, approximately).

## Smooth scroller (1×1) ✅ {#smooth-scroller}

`docs/examples/03_smooth_scroller.asm`, `src/main.asm` (`scroller_update`).

Lower `$d016` XSCROLL from 7 to 0, one pixel per frame. When it wraps, shift the 40 chars of the row left
by one and add the next text char on the right. Use 38-column mode (`$d016` bit 3 = 0) to hide the edges.
A raster split around the row keeps the rest of the screen still. The shift must happen when the beam is
not on that row (we do it after line `$fc`).

Variants 📝: 2×2 scroller (4 chars per letter, double width); bigger fonts (8×8 chars per letter,
built from a charset); **sine scroller** (per-column Y offset, done with sprites or by plotting a
charset); colour-cycled scroller (rotate `$d800` colours).

## Text typer ✅

Standalone recipe [A11](examples/A11_typewriter.asm). Prints one char every N frames
from a byte stream. A blinking reverse-space cursor makes it look like a terminal.

## Shine sweep and water shimmer ✅

`ces_shine`, `water_colors`. Same idea as the logo rainbow: only colour RAM changes, through a gradient
table indexed by `(column + row + phase)`. A 64-entry table that is mostly one colour with a short white band
makes a glint crossing the logo now and then. A 16-entry blue table cycling along row 23 makes the Seine flow.

## Colour-cycled logo ✅

Standalone recipe [A16](examples/A16_logo_themes.asm). Draw a logo with reverse spaces (`$a0`)
and animate it by changing only colour RAM, using the same principle as the demo's shine sweep.

## Sprites and sine tables ✅ {#sprites}

`docs/examples/04_sprites_sine.asm`. 8 sprites, positions read from 256-byte sine tables generated
**at assemble time** with ACME's `!for` and `sin()`. X goes above 255 through `$d010`, so collect
each sprite's carry. Phases differ per sprite (`i*16`) to make a "snake". {#sine-tables}

Sprite multiplexing 📝: re-use the 8 sprites lower down the screen by rewriting Y and the pointers in a raster IRQ
just after each sprite ends. That gives 16, 24 or more sprites (sorting needed when they move freely).

## FLD (Flexible Line Distance) 📝

Every line, before the badline would happen, write `$d011` with a YSCROLL that doesn't match
`(line & 7)`. The VIC postpones the text row, which pushes the screen down by whole lines without moving
any memory. This makes "bouncing logo" effects. It needs a loop that is stable to within one line.

## Open borders 📝

- **Top/bottom**: at line 249 (`$f9`) switch to 24 rows (`$d011` bit 3 = 0), and switch back to 25 before line 0.
  The VIC misses its "border on" comparison, so sprites become visible in the top and bottom borders.
- **Side borders**: switch `$d016` to 38 columns and back at an exact cycle on **every** line.
  This needs a stable raster and sprite-aware timing.

## Charset graphics (tile conversion) ✅ {#charset-graphics}

`src/main.asm` part "ces", `tools/img2chars.py`. Any 1-bit picture is cut into 8×8 cells. Identical cells
are shared, each unique cell becomes a character, and the picture is stored as a screen map of
character codes. A 22×11 logo uses only 106 characters instead of a 9 KB bitmap, and colour comes
per cell from colour RAM (that's how the shine and the water shimmer cost almost nothing). Tricks used:

- Keep the ROM font in codes `$00-$5f` (copied from char ROM with `$01=$33` at start-up, IRQs off), so text
  still works on the same screen.
- `--optimize` tries the 64 sub-cell offsets and keeps the one with the fewest unique tiles.
- Empty cells → space, full cells → `$a0`, so they cost nothing.

## Charset split ✅ {#charset-split}

`irq_mid` / `irq_bottom`. Writing `$d018` in a raster IRQ switches charset partway down the screen, which
doubles the number of tiles (A above row 13, B below). Because both charsets contain the same font, doing
the switch inside a text-only row hides the IRQ jitter completely: no stable raster needed.

## Character-set effects 📝

- Custom font for texts (replace codes `$00-$5f` after the ROM copy).
- **Plasma**: per-char colour (`$d800`) = `sin1[x+a] + sin2[y+b] + sin3[x+y+c]`, or a plasma that rewrites
  the charset. 40×25 = 1000 colour writes per frame is too much for one frame, so update half per
  frame or use a smaller area.
- Char-based rotozoomer / tunnel: precalculated lookup tables, charset with 8 or 16 shades.

## Bouncing portrait sprites ✅

`docs/examples/B30_rotating_heads.asm` uses four double-size hires sprites per
cutout portrait. Sprite pointer swaps play 16 in-plane rotation poses, one every
four PAL frames. Each portrait moves every frame and reverses at the display edges.

## Bitmap effects 📝


Hi-res (320×200) or multicolour bitmap (160×200, 4 colours per 4×8 cell): `$d011` bit 5, `$d018` bit 3,
plus a 9 KB bitmap and screen. Good for a static opencode logo picture converted with a tool (for example
`png2prg`, `Pixcen`, `SpritePad/CharPad` for chars and sprites). Mind the VIC bank (see 02).

## Fades 📝

Fade tables (`fade_out[colour] -> darker colour`) applied to `$d020`, `$d021` and colour RAM over 8 to 16 frames.
They give clean part transitions.

## Vector / 3D 📝

Precalculated rotated points (no multiply at run time), lines drawn into a charset "canvas" with
double buffering. Expensive: aim for 25 fps.

## Parts and transitions (demo structure)

The demo shows one screen. If you add several parts, see [B28](examples/B28_part_sequencer.asm)
for a table of `(frames, init_routine, frame_routine)`. Keep the IRQ chain identical across parts
when possible so switching doesn't glitch the display.
