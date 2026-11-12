; =============================================================================
; C01_side_border.asm - C1 Side-border opening (with sprites in the border)
; What you see: a band of 8 expanded sprites scrolling right across the FULL
;   384-pixel width, sliding through the left and right borders, between two
;   areas of normal text with closed borders.
; Technique:
;   - double-IRQ stable raster (like 02) a few lines above the band
;   - on every band line: dec/inc $d016 so the 38-column switch happens on the
;     exact cycle where the VIC compares the right border edge (cycle 56): it
;     misses both compares (40-col at x=344, 38-col at x=335) -> border stays
;     open until the next line
;   - badlines are suppressed in the band (FLD style: $d011 yscroll never
;     equals raster&7), so each line has a constant cycle budget
;   - all 8 sprites are on every band line. The RMW "dec $d016" does its 2
;     writes during the BA cycles 55-56 before the sprite DMA (writes are not
;     halted, reads are); the CPU then stalls until cycle 11 -> 46 CPU cycles
;     per band line (cycles 11..56)
; Docs: docs/08-effects-library.md (C1)
; Based on: codebase64 base:removing_the_sideborders by HCL and
;   base:sprites_in_bottom_sideborder, rewritten
; Limitations: in VICE the border is open on 43 raster lines (screenshot
;   y=109..151, sprites visible in both side borders); elsewhere it is closed.
;   The band height is fixed to the sprite height (42 lines,
;   Y-expanded). Lines with a different sprite count would need other timing.
;   Timing tuned in VICE (x64sc); untested on real hardware.
; =============================================================================
!source "c64.asm"

IRQ_LINE  = $7a                 ; 1st IRQ; band starts a few lines later
!ifndef SPR_Y { SPR_Y = $7d }   ; sprite Y (all 8 sprites, Y-expanded)
!ifndef PRE   { PRE   = 56 }    ; cycles between stable point and band loop
!ifndef PAD   { PAD   = 19 }    ; padding so a band line = 46 CPU cycles
BAND      = 42                  ; lines in the band (21 * 2, Y-expanded)
SPRDATA   = $2000               ; sprite shape (pointer $80)

phase     = $20                 ; zero page
msb       = $21
tmp       = $22                 ; 2 bytes

        +basic_upstart

start:
        +demo_init nmi
        lda #BLUE
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        sta $3fff               ; idle graphics byte (shown in FLD lines)
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39                 ; text rows above and below the band
-       lda text1,x
        sta SCREEN+5*40,x
        sta SCREEN+20*40,x
        lda text2,x
        sta SCREEN+7*40,x
        sta SCREEN+18*40,x
        dex
        bpl -
        lda #$1b
        sta VIC_CTRL1
        lda #$c8
        sta VIC_CTRL2
        lda #$15                ; screen $0400, ROM font
        sta VIC_MEMPTR

        ldx #7                  ; 8 sprites: same shape, own colour
-       lda #SPRDATA/64
        sta SCREEN+$3f8,x
        lda spr_col,x
        sta SPR0_COLOR,x
        dex
        bpl -
        ldx #14
-       lda #SPR_Y
        sta SPR0_Y,x
        dex
        dex
        bpl -
        lda #$ff
        !ifdef NOSPR { lda #0 }
        sta SPR_ENABLE
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y
        jsr move

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
        inc phase
        jsr move
        jmp main

; X of sprite i = (phase*1 + 48*i) mod 504 -> eight 48-px sprites tile the
; 384-px visible width (screenshot x = sprite X + 8)
move:   lda #0
        sta msb
        lda phase
        sta tmp
        lda #0
        sta tmp+1
        ldx #0                  ; register offset (2*i)
-       lda tmp
        sta SPR0_X,x
        lda tmp+1
        lsr                     ; bit 0 of high byte -> carry
        ror msb                 ; sprites shifted in 0..7 -> msb ends correct
        lda tmp                 ; tmp += 48, wrap at 504
        clc
        adc #48
        sta tmp
        bcc +
        inc tmp+1
+       lda tmp+1
        beq +
        lda tmp
        cmp #<504
        bcc +
        sbc #<504
        sta tmp
        lda #0
        sta tmp+1
+       inx
        inx
        cpx #16
        bne -
        lda msb
        sta SPR_X_MSB
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
+                               ; ---- stable from here ----
        ; delay to put the first "dec $d016" on cycle 51..56 of the 1st band line
        !if PRE & 1 { bit $ea   ; 3
                      !for i, 1, (PRE-3)/2 { nop } } else { !for i, 1, PRE/2 { nop } }
        ldx #0                  ; 2
band:   lda d011_tab,x          ; 4   FLD: no badline in the band
        sta VIC_CTRL1           ; 4
        dec VIC_CTRL2           ; 6   38 columns exactly at the right edge
        inc VIC_CTRL2           ; 6   back to 40 columns
        !if PAD & 1 { bit $ea   ; 3
                      !for i, 1, (PAD-3)/2 { nop } } else { !for i, 1, PAD/2 { nop } }
        inx                     ; 2
        cpx #BAND               ; 2
        bne band                ; 3   = 27 + PAD = 46 (+17 lost to sprites)

        lda #$1b                ; normal display again (screen resumes lower)
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

save_a: !byte 0
save_x: !byte 0
save_y: !byte 0
frame_flag: !byte 0

        !align 255, 0
; yscroll = (line+4)&7: never equal to raster&7 on the next line
d011_tab:
        !for i, 0, BAND-1 { !byte $18 | ((IRQ_LINE + 4 + i + 4) & 7) }

spr_col: !byte 1, 7, 13, 3, 15, 10, 14, 5
text1:  !scr "   side borders open only in the band   "
text2:  !scr "----------------------------------------"

        * = SPRDATA             ; rounded block with a stripe
        !byte %..######, %########, %######..
        !fill 3*4, $ff
        !byte %########, %........, %########
        !byte %########, %........, %########
        !fill 3*7, $ff
        !byte %########, %........, %########
        !byte %########, %........, %########
        !fill 3*4, $ff
        !byte %..######, %########, %######..
        !byte 0
