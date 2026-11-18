# 08 — Effects library (quick-apply catalogue)

A wide list of C64 demoscene effects, sorted by **how fast they can be added to this demo**, with a recipe
for each. It complements `04-demo-effects.md`, which covers the effects already implemented here in depth.

Sources: the Codebase64 wiki (the community's demo-coding wiki, `https://codebase64.net`, pages
`vic:demo_programming`, `vic`, `base:sprites`), C= Hacking "Demo corner" articles, and the CSDb top lists
(see the end of this file). Codebase64 content is **CC BY-NC-SA 4.0**: read it, rewrite the routine in our
ACME style, and credit the article in the code comment. Don't paste listings verbatim.

**Every A/B/C recipe has a runnable example**: `docs/examples/<ID>_*.asm` (IDs zero-padded: A8 → `A08_beat_flash.asm`).
Read it before integrating an effect into `src/main.asm`; check its `Limitations:` header.

Link format: `cb:base:fld` means `https://codebase64.net/doku.php?id=base:fld`.

## In the demo — stable references

Use the `D` IDs in issue reports and live prompts for effects and full-screen parts that already run
in `src/main.asm`. Use the A/B/C IDs below for recipes and variants. To add a demo effect, give it the
next unused `D` ID here and in its source comment, add a `make gifs` capture, then run `make effects-page`.
Don't renumber or reuse IDs. The next unused ID is `D09`.

Run `make run` to launch **D07**, the only screen, with the copper bars and scroller running.

| ID (preview) | Effect or part | What you see | Code in `src/main.asm` | Capture |
|---|---|---|---|---|
| [D01](effects.html#D01) | Stable raster copper bars | Colour gradients roll through the top border, one colour per raster line. | `irq_bars1`, `irq_bars2`, `rotate_bars` | `copper-bars.gif` |
| [D02](effects.html#D02) | 1x1 smooth scroller | The bottom text row scrolls left while the rest of the screen stays still. | `irq_split`, `scroller_update` | `scroller.gif` |
| [D03](effects.html#D03) | Charset logo + shine sweep | A white glint crosses the Codeurs en Seine logo. | `part_ces`, `ces_shine` | `ces-shine.gif` |
| [D04](effects.html#D04) | Charset split + water shimmer | A second charset shows the Rouen skyline while blue tones cycle across the Seine. | `irq_mid`, `water_colors` | `rouen-seine.gif` |
| [D07](effects.html#D07) | Part "ces" (full screen) | Codeurs en Seine logo and date above the Rouen skyline, with copper bars and scroller. | `part_ces`, `ces_update` | `demo-ces.gif` |

## How to read the tiers

| Tier | Meaning | Live on stage? |
|---|---|---|
| **A** | Data or colour-RAM change only. Fits an existing hook (`main_loop`, a part's per-frame routine). No new IRQ, no cycle counting. | Yes: one short prompt |
| **B** | New routine (roughly 30-150 lines) or a new raster IRQ in the chain, but jitter-tolerant (changes happen in the border or between text rows). | Prepare beforehand, maybe show one tweak live |
| **C** | Cycle-exact code (stable raster on every line, badline-aware), new VIC bank, or big precalculation. | No: prepare on a branch, test on real hardware |

Columns: **CPU** is a rough per-frame cost (PAL frame = 19,656 cycles; our current free time is about
12-14k cycles per frame). **Where** says where it plugs in our code (`docs/06-demo-plan.md`).

---

## Tier A — one-prompt effects

| # | Effect | What you see | How | CPU | Where |
|---|---|---|---|---|---|
| A1 | Copper colour schemes | Bars change palette (fire, ice, rainbow, Rouen red & gold) | Edit the `bars` table. Brightness order: `0,6,9,11,2,4,8,12,14,10,5,15,3,7,13,1` | 0 | `bars` |
| A2 | Bar direction / speed | Bars scroll up, down, or faster | Rotate the table the other way, or call `rotate_bars` twice per frame | ~1k | `rotate_bars` |
| A3 | Sine-moving bars | Several bars bounce on sine curves | Clear a 32-byte table, then plot 2-3 small gradients at `sine[t+i*40]`. Table built with `!for` + `sin()` | ~1.5k | replaces `rotate_bars` |
| A4 | Colour cycling text | Any text row cycles a gradient | Write `gradient[(x+phase)&15]` to `$d800+row*40+x` | ~0.6k / row | part routine |
| A5 | Shine / glint | A white band crosses a logo | Same as A4, with a gradient that is mostly one colour (see `ces_shine`) | ~2.5k | done |
| A6 | Rainbow scroller | Scroller letters cycle colours | A4 applied to row 24 | ~0.6k | `scroller_update` |
| A7 | Scroller speed / direction / wobble | Faster, reverse, or speed follows a sine | `sbc #speed`, or speed = `sine[t]>>5`. Reverse = shift right and feed at column 0 | 0 | `scroller_update` |
| A8 | Border / background flash | Screen flashes on a beat | Set `$d020`/`$d021` to white, decay through a fade table over 6-8 frames. Trigger from a frame counter (beat table) | ~50 | `irq_bottom` |
| A9 | Fade in / out | Smooth transitions between parts | Fade tables `fade[c]` → darker colour, applied to colour RAM over 8-16 frames (Veto's colour ramps: `cb:vic`) | ~4k while fading | part switch |
| A10 | Text reveal / wipe | Text appears column by column, or randomly | Colour RAM starts black; per frame, set N cells to their real colour (column order or a random-permutation table) | small | part init |
| A11 | Typewriter tweaks | Different speed, colours, extra lines | Adjust the print delay and text stream | 0 | standalone example |
| A12 | Char animation | Waves, blinking windows, a waving flag | Rewrite 8 bytes of one charset char per frame (e.g. ROL the water char bytes) | ~100 | `rouen` charset B |
| A13 | Twinkling windows / stars | Skyline windows and stars flicker | Random colour-RAM cell from a table set to yellow, another to dark, each frame | ~100 | `ces_update` |
| A14 | Glitch / noise burst | Short "signal lost" moment | For 5-10 frames: random `$d016` xscroll and `$d020` per frame, garbage colours on a few rows | small | part switch |
| A15 | Screen shake | Whole screen jolts on a beat | Change `$d011` YSCROLL bits (keep bit 4 and bit 3) for a few frames; clamp to 0-7 | 0 | `irq_bottom` |
| A16 | Logo colour themes | A logo in brand colours | Edit the palette or the demo's `shine_gradient` | 0 | data |
| A17 | Greetings list | Rotating group/sponsor names | Text table + A10 wipe every N seconds | small | new mini-part |

## Tier B — small routines, jitter-tolerant

| # | Effect | What you see | How | CPU | Source |
|---|---|---|---|---|---|
| B1 | 2x2 scroller | Big scroller, letters 2 chars wide/high | Each letter = 4 chars from a 2x2 charset. Shift every 2 steps of the fine scroll | ~2k | `cb:base:2x2_sidescroll` |
| B2 | Up-scroller (credits roll) | Text scrolls upwards | `$d011` YSCROLL 7→0, then move rows up one char line (double buffer to avoid tearing) | ~3k on move | `cb:base:1x1_upscroll`, `cb:base:2x2_upscroll_with_space_linefeed` |
| B3 | 8x char zoom scroller | Huge letters made of chars | Read ROM font bits, plot $a0/$20 per bit into a 8-row band | ~4k | `cb:base:8x_scale_charset_scrolling_message`, `cb:base:realtime_8x_char_zoom` |
| B4 | Sprite scroller | Scroller in sprites, can go in the border | ROL a sprite strip, one bit per frame per row | ~3k | `cb:base:scrolltext_using_sprites` |
| B5 | Waving sprite letters | One letter per sprite on a sine | Sprite pointers = letter shapes; Y from sine table | ~1k | `cb:base:waving_sprite_scroll`, our `examples/04` |
| B6 | Sprite snake / Lissajous | 8 sprites chase each other | Two sine tables with different speeds (our `examples/04`) | ~1k | done as example |
| B7 | Sprite stretching | Sprites grow taller line by line | Toggle `$d017` per raster line while the sprite is shown (needs per-line IRQ or a loop in the border) | ~1 line each | `cb:base:stretching_sprites` |
| B8 | 8-sprite starfield | Stars moving sideways | 8 one-pixel sprites, multiplexed down the screen at different speeds | ~2k | `cb:base:8_sprite_starfield` |
| B9 | Char starfield | Parallax stars behind text | Stars = pixels in a few chars, ROL the char bytes; or switch `$d018` between 8 pre-shifted charsets | ~0.5k | `cb:base:rol_starfield_using_d018`, `cb:base:starfield` |
| B10 | DYCP | Scroller letters each bounce on their own sine | Plot each letter's 8 bytes into a 2-char-high column charset at Y = `sine[x+t]` | ~6-8k | C= Hacking 6 "Demo corner" (`cb:magazines:chacking6`) |
| B11 | Colour plasma | Smooth flowing colours | Colour RAM = `pal[sin1[x+a]+sin2[y+b]+sin3[x+y+c]]`, half the screen per frame or a 20x12 window | ~10k full screen | `cb:base:colorcycleplasma` |
| B12 | Charset plasma | Finer plasma with shading | Screen = plasma index, charset of 8-16 dither shades | ~8k | same + `cb:base:4x4_fli_chunky_mode` idea |
| B13 | Fire | Burning flames rising | 4x4 chunky pixels in chars, average 3 neighbours + decay, random bottom row | ~8k | `cb:base:4x4_charset_fire_with_lots_of_colors` |
| B14 | Matrix rain | Falling green glyphs | Per-column drop position; head white, tail fades through `13,5,11` | ~2k | — |
| B15 | Logo swing | Logo sways left/right | Per char-row `$d016` change in a raster IRQ (char rows only, so jitter is harmless if done in the row's last line) | ~0.5k | `cb:base:logo_swing` |
| B16 | FLD bounce | Logo/screen drops and bounces | Delay the badline by rewriting `$d011` each line for N lines; N follows a bounce table | N lines | `cb:base:fld` |
| B17 | Open top/bottom border | Sprites in the top and bottom borders | At line `$f9` set 24 rows (`$d011` bit 3 = 0), back to 25 before line `$fc` | ~0 | `cb:base:removing_the_top_bottom_border` |
| B18 | Raster split curtains | Coloured background bands behind text | `$d021` changes at a few lines via raster IRQs (between text rows) | ~0.2k | `cb:base:horizontal_raster_split` |
| B19 | Rasterbars behind text | Bars visible through text background | `$d021` per line with a stable loop, but only on non-badlines; simplest with bars in the border or with DEN=0 areas | many lines | `cb:base:rasterbars_with_screen_on` |
| B20 | Overlapping bars | Bars passing in front/behind each other | Draw bars into the table back to front, sorted by a depth sine | ~2k | `cb:base:overlapping_raster_bars` |
| B21 | Charset blend-in | Logo/picture dissolves in pixel by pixel | AND/OR random masks onto the charset bytes over frames | ~2k | `cb:base:8x8_charset_pixel-blend-in` |
| B22 | ECM note writer | Text with 4 background colours, flashing | Extended Colour Mode (`$d011` bit 6), cycle `$d021-$d024` | ~0 | `cb:base:colour_flashing_notewriter_style` |
| B23 | 3D dot ball / dot scroll | Rotating sphere or text made of dots | Precalculate rotated points (no multiply at run time), plot into a charset canvas, double buffer | ~10k | `cb:base:3d_dot_scroll`, `cb:base:dots_and_plots` |
| B24 | Vector bobs | 3D object made of sprites | 8 sprites (or multiplexed) at precalculated 3D projected positions | ~2k | precalc in Python |
| B25 | Rotozoomer / tunnel (chunky) | Rotating, zooming texture or tunnel | Precalculated u/v lookup tables in a 40x25 or 20x12 char window, colour RAM output | ~10-15k, 25 fps | — |
| B26 | Simple sprite multiplexer | 16-24 sprites on screen | Re-use sprites lower down in raster IRQs, fixed Y bands (no sorting) | ~1k | `cb:base:sprite_multiplexing` |
| B27 | Animated sprite logo | Big multicolour logo built from sprites | 8 sprites expanded side by side, colours cycled | ~0.2k | `cb:base:spriteintro` |
| B28 | Part sequencer | Many parts with timed transitions | Table `(frames, init, frame)` (see 04, "Parts") | ~0 | `main_loop` |
| B29 | Music sync | Flashes and bounces hit the beat | Beat table of frame numbers, or read voice 3 envelope `$d41c` if the tune uses voice 3 for drums | ~0 | `irq_bottom` |
| B30 | Bouncing portrait sprites | Two cut-out portraits spin like wheels and bounce off the screen edges | Swap sprite pointers through 16 precalculated poses and reverse velocity at the edges | ~1k | `tools/faces2sprites.py` |

### B30 — Bouncing portrait sprites

Etienne Reith and Yann Petit spin in opposite directions and bounce off all four
display edges. Each head uses four double-size sprites (all eight in total); the
head bounds can overlap without a collision. This is a standalone effect, not
part of the main demo loop.

Run it with `make run-example EX=B30_rotating_heads`. See the
[ACME example](examples/B30_rotating_heads.asm) and the
[PAL VICE preview](effects.html#B30).

## Tier C — cycle-exact / heavy (prepare off-stage)

| # | Effect | What you see | Why it's hard | Source |
|---|---|---|---|---|
| C1 | Side-border opening | Graphics/sprites across the full width | `$d016` toggle on an exact cycle on **every** line, sprite and badline aware | `cb:base:removing_the_sideborders`, `cb:base:sprites_in_bottom_sideborder` |
| C2 | Tech-tech | Logo waves pixel by pixel per raster line | Per-line `$d016` + charset/screen switch, stable raster | `cb:magazines:chacking7`, `cb:base:techtech_fli` |
| C3 | DYSP | Sprite letters moving on independent X/Y sines across the border | Per-line sprite register writes with a cycle table | `cb:base:dysp_d017`, `cb:base:dysp_cycle_table` |
| C4 | FPP / stretcher | Picture stretched and bent vertically | Repeat or pick any graphics line per raster line | `cb:base:fpp`, `cb:base:fli-fpp-scroller` |
| C5 | Line crunch / VSP / AGSP | Hardware scroll of the whole screen with no copying | VIC timing quirks; VSP crashes some real machines | `cb:base:linecrunch`, `cb:base:horizontal_screen_positioning_hsp`, `cb:base:agsp_any_given_screen_position` |
| C6 | FLI / AFLI pictures | Pictures with far more colours | `$d018`/`$d011` every line, 16 KB data, own VIC bank | `cb:base:fli`, `cb:base:fli_displayer` |
| C7 | Twister / X-rotator / waving carpet | Rotating bar of graphics | 2nd-line FLI tricks | `cb:base:twisters_x-rotators_and_waving_carpets` |
| C8 | Filled 3D vectors | Solid rotating objects | Fast line + fill routines, double-buffered charset or bitmap | `cb:base:filling_the_vectors`, `cb:base:spritevectors` |
| C9 | Perspective "disco floor" scroller | Scroller on a 3D floor | Per-line tables | `cb:base:discofloor_scroller_as_being_used_in_aechzzeit` |
| C10 | Sprite crunching / sprite FPP | Bigger or distorted sprites | Exact `$d017` writes inside the sprite DMA | `cb:base:sprite-crunching`, `cb:base:sprite_fpp` |
| C11 | Digi samples | Speech/drum samples ("hello codeurs en seine!") | 4-bit writes to `$d418` at 4-8 kHz via NMI; sounds different on 6581/8580 | `cb:base:sid_programming` |
| C12 | Fullscreen bitmap demo parts | Effects running over the whole bitmap | Combination of C1 + bitmap speedcode | `cb:base:fullscreen`, `cb:base:speedcode` |

## Best picks for this demo (impact vs. effort)

1. **A3 sine-moving bars + A8 beat flash + B29 music sync**: instantly "demoscene", almost free.
2. **B17 open top/bottom border** with **B5 waving sprite letters** spelling `OPENCODE` in the border.
3. **B10 DYCP** for the scroller: the classic look, and it shows what "6502 by an AI agent" means.
4. **A9 fades + A14 glitch** as an intro transition into the "ces" screen.
5. **B11 plasma** or **B13 fire** as a third short part.
6. **A12/A13** on the Rouen skyline: flowing Seine chars, lit windows.

Live prompts that stay safe: anything in Tier A, plus parameter changes in Tier B (sine speed, colours, texts).

## Where to look in productions

From the CSDb top lists (November 2026), good references to watch in VICE for ideas:

- Top demos: *Next Level*, *The Lab*, *The Hat*, *Breadbin of Horror*, *13:37*, *Mojo*, *Next Round*,
  *Edge of Disgrace*, *Codeboys & Endians*, *Coma Light 13*.
- Top one-file demos (closest to our format): *Subway Arts*, *Nine*, *Rodents in the Attic*, *Layers*,
  *Party Elk 2*, *Robot - Not Human*, *Copper Booze*.
- Top groups: Performers, Booze Design, Oxyron, Censor Design, MultiStyle Labs.

Download them from `https://csdb.dk` (search the title). The CSDb forum (`https://csdb.dk/forums/`) and the
Codebase64 "Demo world records and world firsts" page (`cb:vic:demo:demo_world_records_and_world_firsts`)
explain who invented which effect.
