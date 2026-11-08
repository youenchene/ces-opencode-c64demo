; =============================================================================
; 02_stable_raster_bars.asm - stable raster (double IRQ) + cycle-exact bars
; - screen display disabled (DEN=0) -> no badlines, every line = 63 cycles (PAL)
; - double-IRQ technique removes the 0..7 cycle IRQ entry jitter
; - 63-cycle loop changes $d020/$d021 at the same cycle of every line
; - colour table is rotated each frame (colour cycling)
; PAL only (63 cycles/line). Docs: docs/04-demo-effects.md (#stable-raster)
; =============================================================================
!source "c64.asm"

BAR_LINE  = $60                 ; first IRQ line (second IRQ fires at +1)
BAR_COUNT = 64                  ; number of raster lines coloured

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

main:   lda frame_flag          ; wait for "frame done" from the IRQ
        beq main
        lda #0
        sta frame_flag
        jsr rotate_colors       ; non-timing-critical work in main loop
        jmp main

rotate_colors:
        lda colors
        pha
        ldx #0
-       lda colors+1,x
        sta colors,x
        inx
        cpx #BAR_COUNT-1
        bne -
        pla
        sta colors+BAR_COUNT-1
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical code: keep inside one page so no branch crosses a page
; boundary (a taken branch across pages costs +1 cycle).
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:
        sta save_a              ; 1st IRQ: arrives with 0..7 cycles jitter
        stx save_x
        sty save_y
        lda #<irq2
        sta IRQ_VECTOR
        lda #>irq2
        sta IRQ_VECTOR+1
        inc VIC_RASTER          ; trigger again on the next line
        asl VIC_IRQ_STATUS      ; ack
        tsx                     ; remember stack pointer
        cli                     ; let irq2 interrupt the NOPs below
        nop                     ; 2-cycle instructions -> irq2 jitter is 0..1
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
        txs                     ; drop irq2's stack frame (we never rti from irq1)
        ldx #$08                ; burn cycles to reach the end of the line
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER          ; still the same line?  -> 1 more cycle
        beq +                   ; branch taken (3) vs not taken (2): kills last cycle of jitter
+
        ; ---- now cycle-exact: one iteration = 63 cycles ---------------------
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
        bne bar_loop            ; 3   => 4+4+4+2+39+3+2+2+3 = 63 cycles

        lda #BLACK
        sta BORDER
        sta BACKGROUND

        lda #<irq1              ; restore first handler
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

        !align 255, 0
colors: ; 64 entries: two "copper" bars blue->white and red->yellow
        !byte $06,$06,$0e,$0e,$03,$03,$01,$01,$01,$01,$03,$03,$0e,$0e,$06,$06
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $09,$09,$02,$02,$08,$08,$0a,$0a,$07,$07,$01,$01,$07,$07,$0a,$0a
        !byte $08,$08,$02,$02,$09,$09,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
