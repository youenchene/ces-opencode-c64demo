; =============================================================================
; A03_sine_bars.asm - A3 Sine-moving bars
; What you see: three copper bars (blue, red, green) bouncing up and down on
;   sine curves, crossing in front of each other.
; Technique:
; - stable raster bars as in 02_stable_raster_bars (63-cycle loop, DEN=0)
; - each frame the main loop clears the 128-line colour table, then plots
;   3 small gradients (15 lines) at sine[t + i*40]
; - plot order = depth: the last bar plotted is in front
; - sine table built at assemble time with !for + sin()
; PAL only. Docs: docs/08-effects-library.md (A3)
; =============================================================================
!source "c64.asm"

BAR_LINE  = $40
BAR_COUNT = 128
BAR_H     = 15                  ; lines per bar (gradient length)

zp_t      = $20                 ; sine phase
zp_grad   = $21                 ; offset of the current gradient
zp_n      = $22                 ; lines left to plot

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; DEN=0: blank screen, no badlines
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        +set_irq irq1, BAR_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        inc zp_t
        inc zp_t                ; 2 steps per frame: one bounce in ~2.5 s

        lda #0                  ; clear the table
        ldx #BAR_COUNT-1
-       sta colors,x
        dex
        bpl -

        !for i, 0, 2 {          ; plot bar i at sine[t + i*40]
        lda zp_t
        clc
        adc #i*40
        tax
        lda sine,x              ; 0..BAR_COUNT-BAR_H
        tax
        lda #i*BAR_H
        sta zp_grad
        jsr plot_bar
        }
        jmp main

; x = first line, zp_grad = gradient offset
plot_bar:
        ldy zp_grad
        lda #BAR_H
        sta zp_n
-       lda gradients,y
        sta colors,x
        inx
        iny
        dec zp_n
        bne -
        rts

nmi:    rti

; -----------------------------------------------------------------------------
; Timing-critical: one page
; -----------------------------------------------------------------------------
        !align 255, 0
irq1:
        sta save_a
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
irq2:
        txs
        ldx #$08
-       dex
        bne -
        bit $00
        lda VIC_RASTER
        cmp VIC_RASTER
        beq +
+       ldx #0
bar_loop:
        lda colors,x            ; 4
        sta BORDER              ; 4
        sta BACKGROUND          ; 4
        ldy #8                  ; 2
-       dey                     ; 39
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

save_a:     !byte 0
save_x:     !byte 0
save_y:     !byte 0
frame_flag: !byte 0

gradients:  ; 3 x BAR_H lines: blue, red, green
        !byte $06,$06,$0e,$0e,$03,$03,$01,$01,$01,$03,$03,$0e,$0e,$06,$06
        !byte $09,$02,$02,$08,$08,$0a,$07,$01,$07,$0a,$08,$08,$02,$02,$09
        !byte $0b,$05,$05,$0d,$0d,$0d,$01,$01,$01,$0d,$0d,$0d,$05,$05,$0b

        !align 255, 0
colors: !fill BAR_COUNT, 0      ; page aligned: lda colors,x never crosses

        !align 255, 0
sine:   !for i, 0, 255 { !byte int((BAR_COUNT-BAR_H)/2 + (BAR_COUNT-BAR_H)/2 * sin(float(i) * 2 * 3.14159265 / 256) + 0.5) }
