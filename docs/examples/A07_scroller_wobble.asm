; =============================================================================
; A07_scroller_wobble.asm - A7 Scroller speed / direction / wobble
; What you see: the bottom-row scroller speeds up, slows down, stops and runs
;   backwards, following a sine (one full swing every ~5 s).
; Technique:
; - scroller as in 03_smooth_scroller ($d016 XSCROLL split on row 24)
; - speed = speed_sine[t], a signed value -4..+4 built with !for + sin()
; - speed > 0: xscroll -= speed, on borrow shift the row left and feed the
;   char at column 39; speed < 0: xscroll += |speed|, on overflow shift the
;   row right and feed the char at column 0
; - the text is exactly 256 bytes, so a byte index (left_pos) wraps for free
;   in both directions: column 0 shows text[left_pos], column 39 text[left_pos+39]
; Docs: docs/08-effects-library.md (A7)
; =============================================================================
!source "c64.asm"

SCROLL_ROW   = 24
ROW_ADDR     = SCREEN + SCROLL_ROW*40
SPLIT_LINE   = $30 + SCROLL_ROW*8 - 2
RESTORE_LINE = $fc

zp_t         = $20              ; sine phase
zp_left      = $21              ; text index of the char in column 0
zp_speed     = $22

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
        ldx #39
-       lda #YELLOW
        sta COLOR_RAM+SCROLL_ROW*40,x
        lda scroll_text,x       ; start with the first 40 chars visible
        sta ROW_ADDR,x
        dex
        bpl -
        ldx #title_end-title-1
-       lda title,x
        sta SCREEN+11*40+(40-(title_end-title))/2,x
        dex
        bpl -

        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_split, SPLIT_LINE
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

irq_split:
        +irq_enter
        lda scroll_x
        sta VIC_CTRL2           ; 38 columns + xscroll
        +set_irq irq_restore, RESTORE_LINE
        +irq_exit

irq_restore:
        +irq_enter
        lda #$c8                ; 40 columns, xscroll 0
        sta VIC_CTRL2
        jsr update_scroller
        +set_irq irq_split, SPLIT_LINE
        +irq_exit

update_scroller:
        inc zp_t
        ldx zp_t
        lda speed_sine,x
        beq .done               ; speed 0: standing still
        bmi .right

        sta zp_speed            ; ---- moving left
        lda scroll_x
        sec
        sbc zp_speed
        and #$07
        sta scroll_x
        bcs .done               ; no borrow: same char
        ldx #0
-       lda ROW_ADDR+1,x
        sta ROW_ADDR,x
        inx
        cpx #39
        bne -
        inc zp_left
        lda zp_left
        clc
        adc #39
        tay
        lda scroll_text,y
        sta ROW_ADDR+39
.done:  rts

.right: eor #$ff                ; ---- moving right: |speed|
        clc
        adc #1
        clc
        adc scroll_x
        cmp #8
        bcc +                   ; still inside the char
        and #$07
        sta scroll_x
        ldx #38
-       lda ROW_ADDR,x
        sta ROW_ADDR+1,x
        dex
        bpl -
        dec zp_left
        ldy zp_left
        lda scroll_text,y
        sta ROW_ADDR
        rts
+       sta scroll_x
        rts

nmi:    rti

scroll_x: !byte 0
title:  !scr "the speed follows a sine"
title_end:

        !align 255, 0
speed_sine:                     ; signed -4..+4 (int() truncates toward 0)
        !for i, 0, 255 { !byte int(4.5 * sin(float(i) * 2 * 3.14159265 / 256)) & $ff }

scroll_text:                    ; exactly 256 bytes (page aligned, wraps)
        !scr "codeurs en seine 2026 ... this scroller wobbles: its speed comes "
        !scr "from a sine table, so it accelerates, stops and runs backwards "
        !scr "... opencode wrote it in one prompt ... rouen, kindarena ...  "
        !fill 256 - (* - scroll_text), $20
