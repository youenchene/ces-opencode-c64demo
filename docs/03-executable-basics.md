# 03 — Executable basics

Example: `docs/examples/00_hello.asm` (minimal) and `docs/examples/01_raster_irq.asm` (IRQ chain).

## PRG format

A `.prg` file is a 2-byte little-endian load address followed by raw bytes. ACME writes it
with `-f cbm`. Load it with `LOAD"*",8` (it goes to `$0801`, the BASIC start), then `RUN`.

## BASIC upstart

So that `RUN` starts the machine code, the PRG begins with a tokenised BASIC line, `2026 SYS2061`:

```
$0801: .word next_line, 2026 ; .byte $9e (SYS) "2061" 0 ; next_line: .word 0
$080d: <machine code>
```

This is `+basic_upstart` in `include/c64.asm`. If you change the line text, the SYS address changes.

## Taking over the machine (`+demo_init`)

1. `sei`: no interrupts while we rewire things.
2. `lda #$7f : sta $dc0d : sta $dd0d`: disable the CIA1 timer IRQ (KERNAL) and the CIA2 NMIs.
   Read both registers to clear anything pending.
3. `$01 = $35`: bank BASIC and KERNAL out, keep I/O. We now own `$a000-$bfff` and `$e000-$ffff`,
   and the hardware vectors at `$fffa-$ffff` become RAM we write ourselves.
4. Point the NMI vector at an `rti` so RESTORE does nothing.
   (Fully killing it means making CIA2 fire one NMI and never acknowledging it; not needed here.)

## Raster IRQ setup

```asm
        lda #$1b      : sta $d011     ; raster bit 8 = 0
        lda #<handler : sta $fffe
        lda #>handler : sta $ffff
        lda #LINE     : sta $d012
        lda #$01      : sta $d01a     ; enable raster IRQ
                        sta $d019     ; ack pending
        cli
```

Handler skeleton (KERNAL off, so no automatic register save):

```asm
handler: pha : txa : pha : tya : pha        ; +irq_enter
         ...work...
         ; chain: set $fffe/$ffff + $d012 for the next zone   (+set_irq next, LINE)
         lda #$01 : sta $d019                ; ack
         pla : tay : pla : tax : pla : rti   ; +irq_exit
```

`asl $d019` is a common shorter way to acknowledge: a read-modify-write writes the value back,
which acknowledges the flags that were set.

## Main loop vs IRQs

- **IRQ**: anything tied to a raster position (register splits, colour changes, music `play`).
- **Main loop**: everything else, synced to the frame by a flag the last IRQ of the frame sets
  (`frame_flag` in `src/main.asm`). Keep the main-loop work under about 1 frame. If it takes longer, the
  next IRQs still fire (so display stays correct), but animation slows down.

## Lines above 255

To fire at line ≥ 256, set bit 7 of `$d011` together with `$d012`. Remember to clear it again for the next
IRQ. The current demo only uses lines < 256.

## Returning to BASIC

Demos usually don't. If needed: `sei`, restore `$01=$37`, `jsr $fda3` (init I/O), `jsr $ff5b` (init VIC),
`cli`, `jmp ($a002)` (BASIC warm start). For a presentation, a reset is simpler.
