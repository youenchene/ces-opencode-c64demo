; =============================================================================
; A06_rainbow_scroller.asm - A6 Rainbow scroller
; What you see: the bottom-row smooth scroller, with a rainbow flowing
;   through its letters; a title in the middle of the screen.
; Technique:
; - scroller as in 03_smooth_scroller ($d016 XSCROLL split on row 24)
; - A4 colour cycling applied to the scroller row: colour RAM of row 24 =
;   rainbow[(x + phase) & 15]; the colours stay put while letters move, so
;   each letter changes colour as it travels
; - colours are updated in the bottom IRQ, together with the scroller
; Docs: docs/08-effects-library.md (A6)
; =============================================================================
!source "c64.asm"

SCROLL_ROW   = 24
ROW_ADDR     = SCREEN + SCROLL_ROW*40
COL_ADDR     = COLOR_RAM + SCROLL_ROW*40
SPLIT_LINE   = $30 + SCROLL_ROW*8 - 2   ; just above the scroller row
RESTORE_LINE = $fc                      ; below the last visible row
SPEED        = 2                        ; pixels per frame (1..7)

zp_text      = $20                      ; 2-byte pointer into the text
zp_phase     = $22

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17                ; ROM font lower/upper case
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_GREY
        +fill_1000 COLOR_RAM
        ldx #title_end-title-1
-       lda title,x
        sta SCREEN+11*40+(40-(title_end-title))/2,x
        dex
        bpl -

        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_split, SPLIT_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- just above the scroller row: fine scroll, 38 columns --------------------
irq_split:
        +irq_enter
        lda scroll_x
        sta VIC_CTRL2           ; bit3=0 -> 38 columns, bits0-2 = xscroll
        +set_irq irq_restore, RESTORE_LINE
        +irq_exit

; ---- below the scroller: restore $d016, scroll, colour cycle -----------------
irq_restore:
        +irq_enter
        lda #$c8                ; 40 columns, xscroll 0
        sta VIC_CTRL2
        jsr update_scroller
        jsr rainbow
        +set_irq irq_split, SPLIT_LINE
        +irq_exit

rainbow:                        ; ~0.6k cycles
        inc zp_phase
        ldx #39
-       txa
        clc
        adc zp_phase
        and #15
        tay
        lda rainbow_colors,y
        sta COL_ADDR,x
        dex
        bpl -
        rts

update_scroller:
        lda scroll_x
        sec
        sbc #SPEED
        and #$07
        sta scroll_x
        bcs .done               ; no borrow: still inside the current char
        ldx #0                  ; borrow: shift the row 1 char left
-       lda ROW_ADDR+1,x
        sta ROW_ADDR,x
        inx
        cpx #39
        bne -
        ldy #0
        lda (zp_text),y
        bne +                   ; 0 = end of text -> wrap
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       sta ROW_ADDR+39         ; new char enters on the right
        inc zp_text
        bne .done
        inc zp_text+1
.done:  rts

nmi:    rti

scroll_x: !byte 7
rainbow_colors:
        !byte $02,$02,$08,$08,$07,$07,$0d,$05,$05,$03,$03,$0e,$0e,$06,$04,$04
title:  !scr "rainbow scroller"
title_end:
scroll_text:
        !scr "codeurs en seine 2026 ... a rainbow runs through the scroller, "
        !scr "only colour ram changes ... greetings from opencode ...        "
        !byte 0
