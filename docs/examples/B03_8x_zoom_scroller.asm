; =============================================================================
; B03_8x_zoom_scroller.asm - B3 8x char zoom scroller
; What you see: huge letters (64x64 pixels) built from solid blocks, scrolling
;   smoothly from right to left through an 8-row band with a colour gradient.
; How:
; - the ROM font is copied to RAM at start (IRQs off, $01 = $33)
; - each new screen column = one pixel column of the current letter:
;   for font row r, bit (7 - col) set -> $a0 (solid block) else $20
; - every 8 pixels of $d016 fine scroll, the 8 rows shift one char left
;   and the next pixel column is plotted at column 39 (38-column mode)
; - $d016 fine scroll applies only to the band (raster split)
; Docs: docs/08-effects-library.md (B3)
; Based on: codebase64 base:8x_scale_charset_scrolling_message, rewritten
; =============================================================================
!source "c64.asm"

FONT    = $3000                 ; RAM copy of ROM chars 0..63 (512 bytes)
BAND    = 8                     ; rows 8..15
BAND_SCR = SCREEN + BAND*40
SPLIT   = $33 + BAND*8 - 4      ; $6f: inside blank row 7
RESTORE = $33 + (BAND+8)*8 + 1  ; $b4: inside blank row 16
SPEED   = 2                     ; pixels per frame

zp_text = $20                   ; 2 bytes
zp_col  = $22                   ; pixel column 0..7 inside the letter
zp_x    = $23                   ; fine scroll 0..7
zp_font = $24                   ; 2 bytes: font data of current letter
zp_mask = $26

        +basic_upstart

start:
        +demo_init nmi
        lda #$33                ; copy ROM chars 0..63 (char ROM at $d000)
        sta CPU_PORT
        ldx #0
-       lda $d000,x
        sta FONT,x
        lda $d100,x
        sta FONT+$100,x
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_GREY
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+3*40,x
        lda info,x
        sta SCREEN+20*40,x
        !for r, 0, 7 {
        lda band_col+r          ; band colour = gradient per row
        sta COLOR_RAM+(BAND+r)*40,x
        }
        dex
        bpl -
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        jsr next_letter
        lda #7
        sta zp_x
        lda #$14                ; screen $0400, ROM uppercase ($a0 = block)
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_split, SPLIT
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli
        jmp *

; ---- above the band: fine scroll, 38 columns --------------------------------
irq_split:
        +irq_enter
        lda zp_x
        sta VIC_CTRL2
        +set_irq irq_restore, RESTORE
        +irq_exit

; ---- below the band: 40 columns, scroll the text -----------------------------
irq_restore:
        +irq_enter
        lda #$c8
        sta VIC_CTRL2
        jsr update
        +set_irq irq_split, SPLIT
        +irq_exit

update:
        lda zp_x
        sec
        sbc #SPEED
        and #7
        sta zp_x
        bcc +
        rts                     ; no borrow: still inside the current char
+       ldx #0                  ; shift the 8 band rows one char left
-       !for r, 0, 7 {
        lda BAND_SCR+r*40+1,x
        sta BAND_SCR+r*40,x
        }
        inx
        cpx #39
        bne -
        ldx zp_col              ; plot pixel column zp_col at column 39
        lda bit_mask,x
        sta zp_mask
        ldy #0
        !for r, 0, 7 {
        lda (zp_font),y         ; font row r
        iny
        and zp_mask
        beq +
        lda #$a0                ; pixel set: solid block
        !byte $2c               ; "bit abs": skip the next lda #$20
+       lda #$20
        sta BAND_SCR+r*40+39
        }
        inc zp_col
        lda zp_col
        cmp #8
        bne .done
        jsr next_letter
.done:  rts

; zp_font = FONT + letter*8, advance text, zp_col = 0
next_letter:
        ldy #0
        sty zp_col
        lda (zp_text),y
        bne +                   ; 0 = end -> wrap
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       asl                     ; letter*8 (letter < 64)
        asl
        asl
        sta zp_font
        lda #>FONT
        adc #0
        sta zp_font+1
        inc zp_text
        bne +
        inc zp_text+1
+       rts

nmi:    rti

bit_mask: !byte $80, $40, $20, $10, $08, $04, $02, $01
band_col: !byte 7, 7, 15, 1, 1, 15, 12, 11
title:  !scr "        b3: 8x char zoom scroller       "
info:   !scr "   every font pixel becomes one char    "
scroll_text:                    ; lowercase only (codes < 64), 0 = end
        !scr "opencode at codeurs en seine 2026 ... "
        !byte 0
