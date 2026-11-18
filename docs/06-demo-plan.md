# 06 — Demo plan

Made for **Codeurs en Seine 2026**: Rouen, Kindarena, 19 November 2026 (https://www.codeursenseine.com/2026).

## Parts (looping)

| # | Part | Duration | Init / per-frame routines |
|---|---|---|---|
| 0 | **ces**: Codeurs en Seine logo + Rouen skyline | `CES_FRAMES` = 450 (9 s) | `part_ces` / `ces_update` |
| 1 | **opencode**: block logo + terminal typer | until the typer ends + `END_FRAMES` (5 s) | `part_opencode` / `logo_colors`, `typer_update` |

The copper bars and the scroller run in both parts. Switching parts clears rows 0-23 and redraws in one go
(about one frame of tearing).
`make run-d07` builds and launches a preview that stays on the `ces` part instead of switching.

The `D` references below match the [effect library](08-effects-library.md#in-the-demo--stable-references).

### Part "ces" (D07)

```
raster $12-$31  D01 copper bars (top border)
rows  1-11      D03 Codeurs en Seine logo, 22x11 cells, charset A (106 tiles), white shine sweeping across
row  12         rouen * kindarena * 19.11.2026
row  13         (empty: charset A -> B switch happens here)
rows 14-22      D04 Rouen skyline, charset B: pont Gustave-Flaubert, half-timbered houses,
                cathedrale Notre-Dame (spire, Tour Saint-Romain, Tour de Beurre), abbatiale Saint-Ouen
row  23         D04 the Seine: quay + waves, colour-cycled (water_colors)
row  24         D02 smooth scroller
```

### Part "opencode" (D08)

```
rows  1-5       D05 "OPENCODE" block logo, rainbow sweep
row   7         the open source AI coding agent
rows  9-21      D06 typer: simulated terminal session ($ opencode / > what are you? ...)
row  24         D02 smooth scroller
```

## IRQ chain (one frame)

| Line | Handler | Work |
|---|---|---|
| `$10` (+1) | `irq_bars1` → `irq_bars2` | stable raster, 32 lines of `$d020` colours |
| `$9d` | `irq_mid` | `$d018` = `$1a` (charset B), inside row 13 |
| `$f0` | `irq_split` | `$d016` = scroll_x, 38 columns |
| `$fc` | `irq_bottom` | `$d016` = `$c8`, `$d018` = `$18` (charset A), music play, `frame_flag++` |

Main loop (after `irq_bottom`): `rotate_bars`, `scroller_update`, then the current part's routines.

## Memory map

| Range | Content |
|---|---|
| `$00f0-$00fd` | zero-page pointers (scroll, typer, cursor, colour, line, blit src/dst) |
| `$0400-$07e7` | screen (VIC bank 0) |
| `$0801-$0fff` | BASIC upstart, code, IRQs (`irq_bars*` page-aligned). `!error` if code reaches `$1000` |
| `$1000-$1fff` | SID music (`MUSIC=1`), zero-filled otherwise |
| `$2000-$27ff` | charset A: `$00-$5f` ROM font (copied at start-up), `$60-$ff` Codeurs en Seine logo tiles |
| `$2800-$2fff` | charset B: `$00-$5f` ROM font, `$60-$ff` Rouen skyline tiles |
| `$3000-…` | data: `bars` (page aligned), variables, colour tables, texts, screen maps |
| `$a000-$bfff`, `$e000-$fff9` | free RAM (ROMs banked out) |

The PRG is about 12 KB because the gaps up to `$3000` are zero-filled. That's fine on Kung Fu Flash or
1541 Ultimate. On a stock 1541 it takes about 30 s, so use `make packed` (exomizer) there.
Check the real addresses in `build/opencode.sym` after each build. Update this table when adding big data.

## Graphics pipeline

```
assets/codeurs-en-seine-logo.svg --rsvg-convert 210px, crop, best offset--> src/gfx/ces_logo.*.asm
assets/rouen.txt (320x80 ASCII art, '#' = pixel)                         --> src/gfx/rouen.*.asm
```

`make gfx` runs `tools/img2chars.py`, which writes three files per image: `.inc.asm` (sizes), `.chars.asm`
(tiles, placed at charset + `$300`) and `.map.asm` (screen codes). Limit: 159 unique tiles per charset.
Edit `assets/rouen.txt` in any text editor: keep it 320 columns × 80 lines.

## Ideas for next steps (ordered by impact for the presentation)

1. Music (`MUSIC=1`) with a tune cleared for use.
2. Fade or wipe transition between the parts, using fade tables (see 04).
3. Sine-moving bars instead of plain rotation.
4. Sprite ">_" prompt bouncing (from `examples/04`), or sprite clouds/boats moving over the Seine.
5. Lit windows twinkling in the skyline (colour RAM changes only, no new tiles).
6. Open top/bottom border with sprites in it.

## Live presentation

The stage scenario (acts, exact prompts, fallbacks, setup, rehearsal log) lives in
[`docs/opencode/`](opencode/README.md).
