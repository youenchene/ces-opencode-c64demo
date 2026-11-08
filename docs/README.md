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

To add an example, copy the header comment style (purpose, technique, docs link), number it, and
reference it in this table and in `04-demo-effects.md`.
