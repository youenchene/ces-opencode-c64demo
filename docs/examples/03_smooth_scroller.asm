; =============================================================================
; 03_smooth_scroller.asm - 1x1 hardware smooth scroller on the bottom row
; - $d016 XSCROLL (0-7) gives pixel scrolling, then the row is shifted by 1 char
; - raster split: XSCROLL only applied to the scroller row (row 24),
;   rest of the screen stays still
; - 38-column mode hides the char appearing/disappearing at the edges
; Docs: docs/04-demo-effects.md (#smooth-scroller)
; =============================================================================
!source "c64.asm"

SCROLL_ROW   = 24
ROW_ADDR     = SCREEN + SCROLL_ROW*40
SPLIT_LINE   = $30 + SCROLL_ROW*8 - 2   ; a bit above the row's first raster line ($f3)
RESTORE_LINE = $fc                      ; after the last visible row
SPEED        = 1                        ; pixels/frame (1..7)

zp_text      = $fb                      ; 2-byte pointer into scroll text

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$17
        sta VIC_MEMPTR
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39
        lda #YELLOW
-       sta COLOR_RAM+SCROLL_ROW*40,x
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

; ---- just above the scroller row: apply fine scroll, 38 columns -------------
irq_split:
        +irq_enter
        lda scroll_x
        sta VIC_CTRL2           ; bit3=0 -> 38 cols, bits0-2 = xscroll
        +set_irq irq_restore, RESTORE_LINE
        +irq_exit

; ---- below the scroller: restore $d016, run the per-frame logic --------------
irq_restore:
        +irq_enter
        lda #$c8                ; 40 cols, xscroll 0
        sta VIC_CTRL2
        jsr update_scroller
        +set_irq irq_split, SPLIT_LINE
        +irq_exit

update_scroller:
        lda scroll_x
        sec
        sbc #SPEED
        and #$07
        sta scroll_x
        bcs .done               ; no borrow -> still inside the current char
        ldx #0                  ; borrow: shift whole row 1 char left
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
scroll_text:
        !scr "hello C64 sceners! this smooth scroller is driven by $d016 ... "
        !scr "the opencode agent wrote it in a few seconds ...      "
        !byte 0
