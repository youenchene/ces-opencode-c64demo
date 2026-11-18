# Documentation

| # | File | Read it when… |
|---|---|---|
| 01 | [toolchain](01-toolchain.md) | building, running, debugging, packing |
| 02 | [C64 architecture](02-c64-architecture.md) | touching memory layout, VIC banks, registers |
| 03 | [executable basics](03-executable-basics.md) | changing startup code, IRQ chain, main loop |
| 04 | [demo effects](04-demo-effects.md) | adding or tuning an effect |
| 05 | [music](05-music.md) | adding SID music |
| 06 | [demo plan](06-demo-plan.md) | understanding the demo's parts, memory map, live presentation |
| 07 | [real hardware](07-real-hardware.md) | moving the demo to a real C64 |
| 08 | [effects library](08-effects-library.md) | picking a new effect: ~60 effects sorted by effort, with recipes and sources |
| – | [effects.html](effects.html) | **visual catalogue**: GIFs of what's in the demo + animated previews of the library (`make effects-page`) |
| – | [opencode/](opencode/README.md) | preparing the live presentation: scenario, setup, rehearsal log |
| – | [references](references.md) | going deeper |

## Examples (`docs/examples/`)

Each one is a standalone PRG built by `make examples` and run with `make run-example EX=<name>`.

| File | Technique |
|---|---|
| `00_hello.asm` | Minimal executable: BASIC upstart, machine takeover, screen fill, frame sync by polling `$d012` |
| `01_raster_irq.asm` | Chained raster IRQs (screen splits) |
| `02_stable_raster_bars.asm` | Double-IRQ stable raster + 63-cycle colour bars |
| `03_smooth_scroller.asm` | `$d016` fine scroll + char shift, raster split for one row |
| `04_sprites_sine.asm` | 8 sprites on sine tables built at assemble time, X MSB handling |


### One example per library effect

`A`/`B`/`C` files match the IDs in [08-effects-library.md](08-effects-library.md): one standalone PRG per effect,
built by `make examples`, smoke-tested by `make check-examples`. "Limits" = the header has a `Limitations:` section
(simplified variant or known glitch). Timing-sensitive ones, to test on a real PAL C64 first: B07, B15, B19, B20,
C01, C03, C05, C10, C12 (C05 has a known glitch at the top of the screen).

| File | Effect | Limits |
|---|---|---|
| [`A01_copper_schemes.asm`](examples/A01_copper_schemes.asm) | Copper colour schemes |  |
| [`A02_bar_direction.asm`](examples/A02_bar_direction.asm) | Bar direction / speed |  |
| [`A03_sine_bars.asm`](examples/A03_sine_bars.asm) | Sine-moving bars |  |
| [`A04_color_cycle_text.asm`](examples/A04_color_cycle_text.asm) | Colour cycling text |  |
| [`A05_shine.asm`](examples/A05_shine.asm) | Shine / glint |  |
| [`A06_rainbow_scroller.asm`](examples/A06_rainbow_scroller.asm) | Rainbow scroller |  |
| [`A07_scroller_wobble.asm`](examples/A07_scroller_wobble.asm) | Scroller speed / direction / wobble |  |
| [`A08_beat_flash.asm`](examples/A08_beat_flash.asm) | Border / background flash |  |
| [`A09_fade.asm`](examples/A09_fade.asm) | Fade in / out | yes |
| [`A10_text_reveal.asm`](examples/A10_text_reveal.asm) | Text reveal / wipe |  |
| [`A11_typewriter.asm`](examples/A11_typewriter.asm) | Typewriter tweaks |  |
| [`A12_char_animation.asm`](examples/A12_char_animation.asm) | Char animation |  |
| [`A13_twinkle.asm`](examples/A13_twinkle.asm) | Twinkling windows / stars |  |
| [`A14_glitch.asm`](examples/A14_glitch.asm) | Glitch / noise burst |  |
| [`A15_screen_shake.asm`](examples/A15_screen_shake.asm) | Screen shake |  |
| [`A16_logo_themes.asm`](examples/A16_logo_themes.asm) | Logo colour themes |  |
| [`A17_greetings.asm`](examples/A17_greetings.asm) | Greetings list |  |
| [`B01_2x2_scroller.asm`](examples/B01_2x2_scroller.asm) | 2x2 scroller |  |
| [`B02_up_scroller.asm`](examples/B02_up_scroller.asm) | Up-scroller (credits roll) |  |
| [`B03_8x_zoom_scroller.asm`](examples/B03_8x_zoom_scroller.asm) | 8x char zoom scroller |  |
| [`B04_sprite_scroller.asm`](examples/B04_sprite_scroller.asm) | Sprite scroller | yes |
| [`B05_waving_sprite_letters.asm`](examples/B05_waving_sprite_letters.asm) | Waving sprite letters |  |
| [`B06_sprite_snake.asm`](examples/B06_sprite_snake.asm) | Sprite snake / Lissajous |  |
| [`B07_sprite_stretch.asm`](examples/B07_sprite_stretch.asm) | Sprite stretching | yes |
| [`B08_sprite_starfield.asm`](examples/B08_sprite_starfield.asm) | 8-sprite starfield |  |
| [`B09_char_starfield.asm`](examples/B09_char_starfield.asm) | Char starfield |  |
| [`B10_dycp.asm`](examples/B10_dycp.asm) | DYCP (Different Y Char Positions) |  |
| [`B11_colour_plasma.asm`](examples/B11_colour_plasma.asm) | Colour plasma | yes |
| [`B12_charset_plasma.asm`](examples/B12_charset_plasma.asm) | Charset plasma | yes |
| [`B13_fire.asm`](examples/B13_fire.asm) | Fire | yes |
| [`B14_matrix_rain.asm`](examples/B14_matrix_rain.asm) | Matrix rain |  |
| [`B15_logo_swing.asm`](examples/B15_logo_swing.asm) | Logo swing | yes |
| [`B16_fld_bounce.asm`](examples/B16_fld_bounce.asm) | FLD bounce | yes |
| [`B17_open_border.asm`](examples/B17_open_border.asm) | Open top/bottom border |  |
| [`B18_raster_split.asm`](examples/B18_raster_split.asm) | Raster split curtains | yes |
| [`B19_bars_behind_text.asm`](examples/B19_bars_behind_text.asm) | Rasterbars behind text | yes |
| [`B20_overlapping_bars.asm`](examples/B20_overlapping_bars.asm) | Overlapping bars |  |
| [`B21_charset_blend.asm`](examples/B21_charset_blend.asm) | Charset blend-in |  |
| [`B22_ecm_notewriter.asm`](examples/B22_ecm_notewriter.asm) | ECM note writer | yes |
| [`B23_dot_ball.asm`](examples/B23_dot_ball.asm) | 3D dot ball |  |
| [`B24_vector_bobs.asm`](examples/B24_vector_bobs.asm) | Vector bobs | yes |
| [`B25_tunnel.asm`](examples/B25_tunnel.asm) | Chunky tunnel (40x25 colour RAM) | yes |
| [`B26_sprite_multiplexer.asm`](examples/B26_sprite_multiplexer.asm) | Simple sprite multiplexer | yes |
| [`B27_sprite_logo.asm`](examples/B27_sprite_logo.asm) | Animated sprite logo |  |
| [`B28_part_sequencer.asm`](examples/B28_part_sequencer.asm) | Part sequencer | yes |
| [`B29_music_sync.asm`](examples/B29_music_sync.asm) | Music sync | yes |
| [`B30_rotating_heads.asm`](examples/B30_rotating_heads.asm) | Bouncing portrait sprites | yes |
| [`C01_side_border.asm`](examples/C01_side_border.asm) | Side-border opening (with sprites in the border) | yes |
| [`C02_tech_tech.asm`](examples/C02_tech_tech.asm) | Tech-tech | yes |
| [`C03_dysp.asm`](examples/C03_dysp.asm) | DYSP (Different Y Sprite Positions) in the open side border | yes |
| [`C04_fpp_stretcher.asm`](examples/C04_fpp_stretcher.asm) | FPP (Flexible Pixel Position) / stretcher | yes |
| [`C05_line_crunch.asm`](examples/C05_line_crunch.asm) | Line crunch (hardware vertical scroll, no copying) | yes |
| [`C06_fli.asm`](examples/C06_fli.asm) | FLI (Flexible Line Interpretation) picture | yes |
| [`C07_twister.asm`](examples/C07_twister.asm) | Twister (2nd-line FLI) | yes |
| [`C08_filled_vectors.asm`](examples/C08_filled_vectors.asm) | Filled 3D vectors | yes |
| [`C09_disco_floor.asm`](examples/C09_disco_floor.asm) | Perspective "disco floor" scroller | yes |
| [`C10_sprite_fpp.asm`](examples/C10_sprite_fpp.asm) | Sprite FPP (Y-expand flip-flop trick) | yes |
| [`C11_digi.asm`](examples/C11_digi.asm) | Digi samples (4-bit $d418 playback via NMI) | yes |
| [`C12_fullscreen_bitmap.asm`](examples/C12_fullscreen_bitmap.asm) | Fullscreen bitmap part | yes |

To add an example, copy the header comment style (purpose, technique, docs link), number it, and
reference it in this table and in `04-demo-effects.md`.
