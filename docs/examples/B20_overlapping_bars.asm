; =============================================================================
; B20_overlapping_bars.asm - B20 Overlapping bars
; What you see: 4 copper bars turning around an invisible cylinder, passing
; in front of and behind each other.
; How:
; - bar i has angle a = t*2 + i*64: Y = sine[a], depth = sine[a + 64] (cosine)
; - every frame the colour table is cleared, the 4 bars are sorted by depth
;   (bubble sort on an index list, nearly sorted already) and drawn back to
;   front: the nearest bar is drawn last, so it covers the others
; - display: stable raster (double IRQ, as in examples/02) with the screen
;   off (DEN = 0, no badlines), one $d020/$d021 write per line, 63 cycles
; Docs: docs/08-effects-library.md (B20)
; Based on: codebase64 base:overlapping_raster_bars (idea), rewritten
; =============================================================================
!source "c64.asm"

BAR_LINE  = $48                 ; first IRQ line (second IRQ fires at +1)
BAR_COUNT = 160                 ; raster lines coloured
BAR_H     = 15                  ; bar height in lines

zp_t      = $20
zp_tmp    = $21
zp_swap   = $22
zp_n      = $23

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; DEN=0 (blank screen, no badlines), yscroll 3
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        +set_irq irq1, BAR_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag          ; wait for "bars done" from the IRQ
        beq main
        lda #0
        sta frame_flag
        jsr draw_bars
        jmp main

; ---- build the colour table -------------------------------------------------
draw_bars:
        lda #BLACK
        ldx #BAR_COUNT-1
-       sta colors,x
        dex
        cpx #$ff
        bne -
        inc zp_t
        ldx #3                  ; angle, Y and depth of each bar
-       txa
        lsr
        ror
        ror                     ; i*64 (i = 0..3)
        clc
        adc zp_t
        adc zp_t
        tay
        lda sine,y
        sta ypos,x
        tya
        clc
        adc #64                 ; cosine = depth
        tay
        lda sine,y
        sta depth,x
        dex
        bpl -
.sort:  lda #0                  ; bubble sort order[] by depth, far first
        sta zp_swap
        ldx #0
-       ldy order,x
        lda depth,y
        sta zp_tmp
        ldy order+1,x
        lda depth,y
        cmp zp_tmp
        bcs +                   ; next is nearer or equal: keep
        lda order,x             ; swap the two indexes
        pha
        tya
        sta order,x
        pla
        sta order+1,x
        inc zp_swap
+       inx
        cpx #3
        bne -
        lda zp_swap
        bne .sort
        ldx #0                  ; draw far -> near
.draw:  stx zp_n
        ldy order,x
        lda ypos,y
        sta zp_tmp
        tya                     ; gradient = bar*16
        asl
        asl
        asl
        asl
        tay
        ldx zp_tmp
        lda #BAR_H
        sta zp_tmp
-       lda grad,y
        sta colors,x
        inx
        iny
        dec zp_tmp
        bne -
        ldx zp_n
        inx
        cpx #4
        bne .draw
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical: one page (double-IRQ stable raster, see examples/02).
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:
        sta save_a              ; 1st IRQ: 0..7 cycles jitter
        stx save_x
        sty save_y
        lda #<irq2
        sta IRQ_VECTOR
        lda #>irq2
        sta IRQ_VECTOR+1
        inc VIC_RASTER          ; trigger again on the next line
        asl VIC_IRQ_STATUS      ; ack
        tsx
        cli                     ; irq2 hits during the NOPs: jitter 0..1
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
irq2:
        txs                     ; drop irq2's stack frame
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER          ; same line? -> 1 more cycle
        beq +                   ; kills the last cycle of jitter
+       ldy #11                 ; 2   58 cycles = next line, 5 cycles earlier:
-       dey                     ; 54  the writes land in the horizontal blank
        bne -                   ;     (the 8565 VIC shows a grey dot where a
        nop                     ; 2   colour register is written)
        ldx #0
bar_loop:
        lda colors,x            ; 4
        sta BORDER              ; 4
        sta BACKGROUND          ; 4
        ldy #8                  ; 2
-       dey                     ; 8*5-1 = 39
        bne -
        bit $00                 ; 3
        inx                     ; 2
        cpx #BAR_COUNT          ; 2
        bne bar_loop            ; 3   => 63 cycles
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #<irq1
        sta IRQ_VECTOR
        lda #>irq1
        sta IRQ_VECTOR+1
        lda #BAR_LINE
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
order:  !byte 0, 1, 2, 3
ypos:   !fill 4, 0
depth:  !fill 4, 0
; 4 gradients (16 bytes each, 15 used): blue, red, green, purple/grey
grad:   !byte 6, 6, 14, 14, 3, 3, 1, 1, 1, 3, 3, 14, 14, 6, 6, 0
        !byte 9, 2, 2, 8, 8, 10, 7, 1, 7, 10, 8, 8, 2, 2, 9, 0
        !byte 11, 5, 5, 13, 13, 7, 1, 1, 1, 7, 13, 13, 5, 5, 11, 0
        !byte 11, 4, 4, 12, 10, 15, 1, 1, 1, 15, 10, 12, 4, 4, 11, 0

        !align 255, 0
colors: !fill BAR_COUNT, 0
        !align 255, 0
; Y position 0..BAR_COUNT-BAR_H (and depth, read 64 entries later)
sine:   !for i, 0, 255 { !byte int(72.5 + 72 * sin(float(i) * 2 * 3.14159265 / 256)) }
