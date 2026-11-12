; =============================================================================
; A01_copper_schemes.asm - A1 Copper colour schemes
; What you see: 128 lines of stable raster bars scrolling up; every ~2.5 s the
;   palette changes: fire, ice, rainbow, Rouen red & gold.
; Technique:
; - stable raster (double IRQ) + 63-cycle loop writes colors[x] to $d020/$d021
; - a scheme is 16 colours (one bar); colors[i] = scheme[((i+phase)>>1) & 15]
;   rebuilt by the main loop every frame (each colour is 2 lines high)
; - switching scheme = pointing at another 16-byte table: data only, no code
; - brightness order for your own gradients: 0,6,9,11,2,4,8,12,14,10,5,15,3,7,13,1
; Screen display is off (DEN=0): no badlines, the border fills the screen.
; PAL only. Docs: docs/08-effects-library.md (A1)
; =============================================================================
!source "c64.asm"

BAR_LINE  = $40                 ; first IRQ line (bars start 1-2 lines later)
BAR_COUNT = 128                 ; raster lines coloured
SCHEME_FRAMES = 128             ; frames per scheme

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; DEN=0: blank screen, no badlines
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        jsr build_bars
        +set_irq irq1, BAR_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag          ; wait for "bars done" from the IRQ
        beq main
        lda #0
        sta frame_flag
        inc phase               ; bars move up by half a colour per frame
        dec scheme_timer
        bne +
        lda #SCHEME_FRAMES
        sta scheme_timer
        lda scheme_ofs          ; next scheme (4 x 16 bytes)
        clc
        adc #16
        and #$3f
        sta scheme_ofs
+       jsr build_bars          ; ~3k cycles, done long before BAR_LINE
        jmp main

; colors[i] = schemes[scheme_ofs + (((i+phase)>>1) & 15)]
build_bars:
        ldx #0
-       txa
        clc
        adc phase
        lsr
        and #15
        ora scheme_ofs
        tay
        lda schemes,y
        sta colors,x
        inx
        bpl -                   ; stops at x = 128
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical: one page (no branch crosses a page boundary)
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:
        sta save_a              ; 1st IRQ: 0..7 cycles of jitter
        stx save_x
        sty save_y
        lda #<irq2
        sta IRQ_VECTOR
        lda #>irq2
        sta IRQ_VECTOR+1
        inc VIC_RASTER          ; fire again on the next line
        asl VIC_IRQ_STATUS      ; ack
        tsx
        cli                     ; irq2 hits one of these NOPs: jitter 0..1
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
        cmp VIC_RASTER          ; same line? -> removes the last cycle of jitter
        beq +
+       ldx #0
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
        bne bar_loop            ; 3  = 63
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

save_a:       !byte 0
save_x:       !byte 0
save_y:       !byte 0
frame_flag:   !byte 0
phase:        !byte 0
scheme_ofs:   !byte 0
scheme_timer: !byte SCHEME_FRAMES

        !align 255, 0
colors: !fill BAR_COUNT, 0      ; page aligned: lda colors,x never crosses

schemes:                        ; 16 colours = one bar (each shown 2 lines)
        ; fire
        !byte $00,$09,$02,$08,$0a,$07,$01,$01,$07,$0a,$08,$02,$09,$00,$00,$00
        ; ice
        !byte $00,$06,$0b,$04,$0e,$03,$0d,$01,$01,$0d,$03,$0e,$04,$0b,$06,$00
        ; rainbow
        !byte $02,$02,$08,$08,$07,$07,$0d,$05,$05,$03,$03,$0e,$0e,$06,$04,$04
        ; Rouen red & gold
        !byte $00,$09,$02,$0a,$02,$09,$00,$00,$00,$09,$08,$07,$01,$07,$08,$09
