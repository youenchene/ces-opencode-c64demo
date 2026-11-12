; =============================================================================
; A15_screen_shake.asm - A15 Screen shake
; What you see: a framed text screen that jolts up and down on a beat
; (every 25 frames = 2 beats per second), with a border flash.
; Technique:
; - $d011 bits 0-2 (YSCROLL) move the whole text screen by 0-7 pixels.
;   The normal value is 3; the shake writes 3 + offset, clamped to 0-7,
;   keeping bit 4 (screen on) and bit 3 (25 rows): ora #$18
; - a short offset table (decaying jolt) is read one entry per frame
; - written in the IRQ at line $fc (below the text, before the next frame)
; - 24-row mode would hide the top/bottom edge; here the edge is part of the show
; Docs: docs/08-effects-library.md (A15)
; =============================================================================
!source "c64.asm"

BEAT = 25                       ; frames between jolts

beat_timer = $20
shake_pos  = $21                ; index in shake_table, $ff = idle

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #BLACK
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$a0                ; frame: solid blocks...
        +fill_1000 SCREEN
        lda #DARK_GREY
        +fill_1000 COLOR_RAM
        !for r, 1, 23 {         ; ...with a hollow inside
        ldx #37
        lda #$20
-       sta SCREEN+r*40+1,x
        dex
        bpl -
        }
        ldx #text_len-1
-       lda text,x
        sta SCREEN+12*40+(40-text_len)/2,x
        lda #YELLOW
        sta COLOR_RAM+12*40+(40-text_len)/2,x
        dex
        bpl -
        lda #BEAT
        sta beat_timer
        lda #$ff
        sta shake_pos

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_frame, $fc
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

irq_frame:
        +irq_enter
        dec beat_timer          ; beat: restart the jolt
        bne +
        lda #BEAT
        sta beat_timer
        lda #0
        sta shake_pos
        lda #WHITE
        sta BORDER
+       ldx shake_pos
        bmi .idle
        lda shake_table,x
        cmp #$80                ; end marker
        beq .stop
        inc shake_pos
        clc
        adc #3                  ; offset around the normal YSCROLL (3)
        bpl +
        lda #0                  ; clamp low (negative)
+       cmp #8
        bcc +
        lda #7                  ; clamp high
+       ora #$18                ; DEN + 25 rows, raster bit 8 = 0
        sta VIC_CTRL1
        lda border_fade,x
        sta BORDER
        jmp .done
.stop:  lda #$ff
        sta shake_pos
        lda #$1b                ; back to rest
        sta VIC_CTRL1
        lda #BLACK
        sta BORDER
.idle:
.done:  +irq_exit

nmi:    rti

shake_table:                    ; signed offsets, one per frame, $80 = end
        !byte 4, <-4, 3, <-3, 2, <-2, 1, <-1, 0, $80
border_fade:
        !byte WHITE, LIGHT_GREY, GREY, DARK_GREY, DARK_GREY, BLACK, BLACK, BLACK, BLACK

text:   !scr "A15 screen shake: $d011 yscroll"
text_len = * - text
