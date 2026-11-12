; =============================================================================
; A02_bar_direction.asm - A2 Bar direction / speed
; What you see: copper bars that scroll up, faster, then down, then stop,
;   switching mode every 2 seconds.
; Technique:
; - stable raster bars as in 02_stable_raster_bars (63-cycle loop, DEN=0)
; - rotate_up = colors[i] = colors[i+1] (bars move up), rotate_down = the
;   reverse loop (bars move down)
; - speed = how many times the rotation runs per frame (0 = frozen)
; - the mode table (signed speed per step) is plain data: edit it to taste
; PAL only. Docs: docs/08-effects-library.md (A2)
; =============================================================================
!source "c64.asm"

BAR_LINE    = $40
BAR_COUNT   = 128
MODE_FRAMES = 100               ; 2 s per mode

zp_count    = $20               ; rotations left this frame

        +basic_upstart

start:
        +demo_init nmi
        lda #$0b                ; DEN=0: blank screen, no badlines
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        ldx #0                  ; fill the table with 4 bars (16 colours x 2 lines)
-       txa
        lsr
        and #15
        tay
        lda bar_shape,y
        sta colors,x
        inx
        bpl -
        +set_irq irq1, BAR_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda frame_flag
        beq main
        lda #0
        sta frame_flag
        dec mode_timer          ; next mode every MODE_FRAMES
        bne +
        lda #MODE_FRAMES
        sta mode_timer
        ldx mode
        inx
        cpx #MODE_COUNT
        bne ++
        ldx #0
++      stx mode
+       ldx mode
        lda modes,x             ; signed speed
        beq main                ; 0: frozen
        bmi .down
        sta zp_count
-       jsr rotate_up
        dec zp_count
        bne -
        jmp main
.down:  eor #$ff                ; negate
        clc
        adc #1
        sta zp_count
-       jsr rotate_down
        dec zp_count
        bne -
        jmp main

rotate_up:                      ; ~1.7k cycles
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

rotate_down:
        lda colors+BAR_COUNT-1
        pha
        ldx #BAR_COUNT-1
-       lda colors-1,x
        sta colors,x
        dex
        bne -
        pla
        sta colors
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
mode:       !byte 0
mode_timer: !byte MODE_FRAMES

modes:      ; lines per frame: >0 up, <0 down, 0 frozen
        !byte 1, 2, 4, 0, -1 & $ff, -3 & $ff
MODE_COUNT = * - modes

bar_shape:  ; one copper bar, blue -> white -> red -> yellow
        !byte $00,$06,$0e,$03,$01,$03,$0e,$06,$00,$09,$02,$08,$0a,$07,$01,$00

        !align 255, 0
colors: !fill BAR_COUNT, 0      ; page aligned: lda colors,x never crosses
