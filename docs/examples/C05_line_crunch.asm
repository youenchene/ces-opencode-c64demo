; =============================================================================
; C05_line_crunch.asm - C5 Line crunch (hardware vertical scroll, no copying)
; What you see: a full text screen of 25 numbered rows that scrolls up and
;   down smoothly on a sine, without moving a single byte of screen memory.
; Technique (line crunch):
;   - each crunched raster line, the VIC sees a badline condition at cycle 12
;     ($d011 yscroll = line & 7) that is taken away again at cycle 13 by the
;     second write of "dec $d011". The VIC enters display state but there is
;     no char fetch and no row counter reset: RC stays 7, so at cycle 58 it
;     moves VC base to the next char row. 1 raster line = 1 whole char row
;   - k crunched lines move the screen up by 7*k pixels; f = 0..6 idle
;     (FLD) lines before them move it down again -> any scroll position 7k-f
;   - stable raster (double IRQ, like 02) because the crunch window is 1-2
;     cycles wide; loop = 63 cycles, no DMA (the badline never starts)
;   - VSP (horizontal version: start the badline in the middle of a line,
;     cycles 15-54, so the char fetch starts late and the screen shifts
;     sideways) is NOT used: it can corrupt memory or crash some real C64s
;     (it depends on the DRAM chips). AGSP = line crunch + VSP.
; Docs: docs/08-effects-library.md (C5)
; Based on: codebase64 base:linecrunch (and the VIC-II article by C. Bauer),
;   rewritten
; Limitations: vertical only (no VSP). In VICE the crunch works (rows 0..k-1
;   disappear, the whole screen moves on the sine without copying), but the
;   first visible row is glitched: it is shown once, then its first ~5 lines
;   are shown again before the next row (a stray real badline near the end
;   of the crunch area, not fixed yet). Rows scrolling in at the bottom come
;   from beyond the 1000-byte screen (blank here): a real scroller would
;   refresh one row every 8 pixels. Cycle-exact: checked in VICE only, needs
;   tuning on real hardware.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $31                 ; double IRQ $31/$32, stable on cycle ~25 of $33
C0        = $34                 ; first crunched line (top of the display)
!ifndef PRE { PRE = 36 }        ; stable point -> "lda" on cycle 63 of $33

k         = $20                 ; loop lines: f idle + k crunched
fine      = $21                 ; $d011 value after the crunch
phase     = $22
tmp_ptr   = $23                 ; 2 bytes

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        sta $3fff               ; idle graphics byte (FLD lines)
        lda #$20                ; screen + the 24 spare bytes after it
        ldx #0
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        inx
        bne -
        jsr fill_rows
        lda #$15
        sta VIC_MEMPTR
        lda #$c8
        sta VIC_CTRL2
        lda #$1b
        sta VIC_CTRL1
        jsr calc
        +set_irq irq1, IRQ_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc phase
        jsr calc
        lda #$fb                ; below the display: reset yscroll so that
-       cmp VIC_RASTER          ; lines $30-$33 are never badlines and the
        bne -                   ; crunch starts in idle state with RC = 7
        lda #$18 | (C0 & 7)     ; yscroll 4: no badline before line C0
        sta VIC_CTRL1
        jmp main

; scroll position P = 8..118 px from a sine: k = crunched lines (7k >= P),
; f = 7k - P idle lines BEFORE the crunch. Builds the per-line $d011 table:
;   f idle lines: yscroll never matches (FLD), k lines: yscroll = line & 7
calc:   ldy phase
        lda sine,y
        ldx #0
-       inx                     ; k = smallest with 7k >= P (k >= 1)
        sec
        sbc #7
        beq +
        bcs -
+       stx tmp_ptr             ; k (tmp_ptr is free after start-up)
        eor #$ff
        clc
        adc #1                  ; f = 0..6
        sta tmp_ptr+1
        ldx #0
        ldy tmp_ptr+1           ; f idle lines first
        beq .crunch
-       txa
        clc
        adc #C0+4
        and #7
        ora #$18
        sta d011_tab,x
        inx
        dey
        bne -
.crunch:
        ldy tmp_ptr             ; then k crunched lines
-       txa
        clc
        adc #C0
        and #7
        ora #$18
        sta d011_tab,x
        inx
        dey
        bne -
        stx k                   ; loop count f + k
        txa                     ; next line = first normal badline
        clc
        adc #C0
        and #7
        ora #$18
        sta fine
        rts

; rows: "row nn" + a coloured bar, colour per row
fill_rows:
        lda #<SCREEN
        sta tmp_ptr
        lda #>SCREEN
        sta tmp_ptr+1
        ldx #0                  ; row 0..24
.r:     txa
        pha
        ldy #0
-       lda label,y
        sta (tmp_ptr),y
        iny
        cpy #4
        bne -
        lda decimal_hi,x
        sta (tmp_ptr),y
        iny
        lda decimal_lo,x
        sta (tmp_ptr),y
        iny
        lda #$20
        sta (tmp_ptr),y
        iny
        lda #$a0                ; inverse space = solid block
-       sta (tmp_ptr),y
        iny
        cpy #40
        bne -
        lda tmp_ptr+1           ; same offset in colour RAM
        pha
        clc
        adc #>(COLOR_RAM-SCREEN)
        sta tmp_ptr+1
        lda row_col,x
        ldy #39
-       sta (tmp_ptr),y
        dey
        bpl -
        pla
        sta tmp_ptr+1
        lda tmp_ptr
        clc
        adc #40
        sta tmp_ptr
        bcc +
        inc tmp_ptr+1
+       pla
        tax
        inx
        cpx #25
        bne .r
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical code, kept inside one page
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:   sta save_a              ; 0..7 cycles jitter
        stx save_x
        sty save_y
        lda #<irq2
        sta IRQ_VECTOR
        lda #>irq2
        sta IRQ_VECTOR+1
        inc VIC_RASTER
        asl VIC_IRQ_STATUS
        tsx
        cli
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
irq2:   txs                     ; 0..1 cycle jitter
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +                   ; removes the last cycle of jitter
+                               ; ---- stable: ~cycle 25 of line $33 ----
        !if PRE & 1 { bit $ea : !for i, 1, (PRE-3)/2 { nop } } else { !for i, 1, PRE/2 { nop } }
        ldx #0                  ; 2
crunch: lda d011_tab,x          ; 4  cycles 63,1,2,3: yscroll = line & 7
        sta VIC_CTRL1           ; 4  write on 7: badline condition from now
        dec VIC_CTRL1           ; 6  writes on 12 (same) and 13 (yscroll-1):
                                ;    condition gone before cycle 14
        ldy #8                  ; 2
-       dey                     ; 39 (8*5-1)
        bne -
        inx                     ; 2
        cpx k                   ; 3
        bne crunch              ; 3  = 4+4+6+41+2+3+3 = 63
        lda fine                ; next badline after f idle lines
        sta VIC_CTRL1
        lda #<irq1
        sta IRQ_VECTOR
        lda #>irq1
        sta IRQ_VECTOR+1
        lda #IRQ_LINE
        sta VIC_RASTER
        asl VIC_IRQ_STATUS
        inc frame_flag
        lda save_a
        ldx save_x
        ldy save_y
        rti
irq_end:
!if >irq1 != >irq_end { !error "timing code crosses a page" }

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0
frame_flag: !byte 0

        !align 255, 0
d011_tab: !for i, 0, 127 { !byte $18 | ((C0 + i) & 7) }
label:  !scr "row "
decimal_hi: !for i, 0, 24 { !byte $30 + int(i / 10) }
decimal_lo: !for i, 0, 24 { !byte $30 + i - 10 * int(i / 10) }
row_col: !for i, 0, 24 { !byte [2, 8, 7, 5, 3, 14, 6, 4][i & 7] }
        !align 255, 0
sine:   !for i, 0, 255 { !byte int(63 + 55 * sin(float(i) * 2 * 3.14159265 / 256)) }
