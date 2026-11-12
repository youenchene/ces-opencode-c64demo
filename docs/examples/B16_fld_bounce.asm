; =============================================================================
; B16_fld_bounce.asm - B16 FLD bounce
; What you see: the whole text screen drops and bounces like a ball.
; How (Flexible Line Distance):
; - the VIC starts a char row on a "badline" (raster & 7 == YSCROLL)
; - for N lines from just above the first row, wait for each new line and
;   set YSCROLL = (line + 2) & 7, so the badline condition never matches:
;   the VIC stays idle and shows the background, the text waits N lines
; - N follows a parabola table (96 lines down to 0 and back) = a bounce
; - YSCROLL is reset to 3 at the bottom of the frame
; Docs: docs/08-effects-library.md (B16)
; Based on: codebase64 base:fld, rewritten
; Limitations: rows pushed below line $f7 are not shown (no badlines there).
; =============================================================================
!source "c64.asm"

FLD_IRQ = $31                   ; loop starts on line $32: N lines -> row 0 at $33+N
BOTTOM  = $fc

zp_i    = $20                   ; bounce table index

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        lda #BLUE
        sta BACKGROUND
        lda #0
        sta $3fff               ; idle graphics byte (shown in the FLD gap)
        lda #$17                ; ROM font, mixed case
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #0                  ; text block, 4 lines of 40 chars
-       lda text,x
        sta SCREEN+2*40,x
        lda text+120,x
        sta SCREEN+5*40,x
        lda #WHITE
        sta COLOR_RAM+2*40,x
        lda #YELLOW
        sta COLOR_RAM+5*40,x
        inx
        cpx #120
        bne -
        ldx #39                 ; a rainbow bar of solid blocks on row 0
-       lda #$a0
        sta SCREEN,x
        sta SCREEN+9*40,x
        txa
        and #15
        tay
        lda rainbow,y
        sta COLOR_RAM,x
        sta COLOR_RAM+9*40,x
        dex
        bpl -

        +set_irq irq_fld, FLD_IRQ
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- FLD: keep the badline away for N lines ---------------------------------
irq_fld:
        +irq_enter
        ldy zp_i
        ldx bounce,y
        beq .done
.line:  lda VIC_RASTER
-       cmp VIC_RASTER          ; wait for the next line (A = previous line)
        beq -
        clc
        adc #3                  ; (new line + 2) & 7 -> never this line or the next
        and #7
        ora #$18                ; DEN on, 25 rows
        sta VIC_CTRL1
        dex
        bne .line
.done:  +set_irq irq_bottom, BOTTOM
        +irq_exit

; ---- bottom: normal YSCROLL again, advance the bounce ------------------------
irq_bottom:
        +irq_enter
        lda #$1b
        sta VIC_CTRL1
        inc zp_i
        lda zp_i
        and #127
        sta zp_i
        +set_irq irq_fld, FLD_IRQ
        +irq_exit

nmi:    rti

rainbow: !byte 2, 8, 7, 5, 3, 14, 6, 4, 4, 6, 14, 3, 5, 7, 8, 2
text:   !scr "  FLD: flexible line distance.          "
        !scr "  the VIC is told every raster line     "
        !scr "  that the next char row is not yet due "
        !scr "  ... so the whole screen drops and     "
        !scr "  bounces, with zero data moved.        "
        !scr "  opencode at codeurs en seine 2026     "

        !align 127, 0
; drop in lines: 96 * (2t - 1)^2, t = 0..1 -> 96 .. 0 .. 96 (parabola)
bounce: !for i, 0, 127 { !byte int(96 * (2 * float(i) / 128 - 1) * (2 * float(i) / 128 - 1)) }
