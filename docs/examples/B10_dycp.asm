; =============================================================================
; B10_dycp.asm - B10 DYCP (Different Y Char Positions)
; What you see: a smooth scroller whose letters each bounce up and down on
;   their own position of a sine wave, inside a 48-pixel-high band.
; How:
; - band of 6 char rows: screen column c shows chars c*6 .. c*6+5, so each
;   column owns 48 consecutive bytes of the charset at $2000 (240 chars)
; - per frame and column: clear the 8 bytes drawn last frame, then copy the
;   letter's 8 font bytes at offset y = sine[c*8 + t] (0..40) in its column
; - $d016 fine scroll + $d018 charset switch only on the band (raster
;   split); the 40-letter window shifts one letter every 8 pixels
; - drawing (~9k cycles) starts right below the band, so it is finished
;   before the band is shown again: no flicker
; Docs: docs/08-effects-library.md (B10)
; Based on: C= Hacking issue 6 "Demo corner" (DYCP), rewritten
; =============================================================================
!source "c64.asm"

CHARSET = $2000                 ; 40 columns x 48 bytes ($2000-$277f)
FONT    = $3000                 ; RAM copy of ROM chars 0..63 (512 bytes)
BAND    = 9                     ; rows 9..14
H       = 6                     ; band height in chars
SPLIT   = $33 + BAND*8 - 4      ; $77: inside row 8 (black)
RESTORE = $33 + (BAND+H)*8 + 1  ; $ac: inside row 15 (black)
SPEED   = 1

zp_d    = $20                   ; 2 bytes: column data pointer
zp_f    = $22                   ; 2 bytes: font pointer
zp_t    = $24
zp_x    = $25                   ; fine scroll 0..7
zp_text = $26                   ; 2 bytes
zp_flag = $28
win     = $30                   ; 40 bytes: letters shown ($30-$57)

        +basic_upstart

start:
        +demo_init nmi
        lda #$33                ; ROM chars 0..63 -> FONT
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
        lda #0                  ; empty column charset
        tax
-       !for p, 0, 7 { sta CHARSET+p*$100,x }
        inx
        bne -
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
        txa                     ; band cell (row r, col c) = c*6 + r
        asl
        sta zp_t
        asl
        adc zp_t                ; c*6
        !for r, 0, H-1 {
        sta SCREEN+(BAND+r)*40,x
        clc
        adc #1
        }
        !for r, 0, H-1 {
        lda band_col+r          ; colour gradient down the band
        sta COLOR_RAM+(BAND+r)*40,x
        }
        lda #BLACK              ; rows 8 and 15 see both charsets during the
        sta COLOR_RAM+(BAND-1)*40,x ; split: black on black hides it
        sta COLOR_RAM+(BAND+H)*40,x
        lda #0
        sta old_y,x
        lda #$20
        sta win,x
        dex
        bpl -
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda #7
        sta zp_x
        lda #$14                ; ROM uppercase outside the band
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        +set_irq irq_split, SPLIT
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda zp_flag             ; band shown -> draw the next frame
        beq main
        lda #0
        sta zp_flag
        jsr scroll
        jsr draw
        jmp main

; ---- above the band: column charset, fine scroll, 38 columns ----------------
irq_split:
        +irq_enter
        lda zp_x
        sta VIC_CTRL2
        lda #$18
        sta VIC_MEMPTR
        +set_irq irq_restore, RESTORE
        +irq_exit

; ---- below the band: ROM font, 40 columns, start drawing --------------------
irq_restore:
        +irq_enter
        lda #$c8
        sta VIC_CTRL2
        lda #$14
        sta VIC_MEMPTR
        inc zp_flag
        +set_irq irq_split, SPLIT
        +irq_exit

; fine scroll; every 8 pixels shift the letter window
scroll:
        inc zp_t
        inc zp_t
        lda zp_x
        sec
        sbc #SPEED
        and #7
        sta zp_x
        bcs .done
        ldx #0
-       lda win+1,x
        sta win,x
        inx
        cpx #39
        bne -
        ldy #0
        lda (zp_text),y
        bne +                   ; 0 = end -> wrap
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       sta win+39
        inc zp_text
        bne .done
        inc zp_text+1
.done:  rts

; every column: erase old letter, draw it at its new Y
draw:
        ldx #39
.col:   lda col_lo,x
        sta zp_d
        lda col_hi,x
        sta zp_d+1
        ldy old_y,x             ; clear the 8 bytes drawn last frame
        lda #0
        !for k, 0, 7 {
        sta (zp_d),y
        iny
        }
        txa                     ; new y = sine[c*8 + t]
        asl
        asl
        asl
        adc zp_t                ; c*8 < 320: carry may be set, harmless
        tay
        lda sine,y
        sta old_y,x
        clc
        adc zp_d                ; zp_d += y
        sta zp_d
        bcc +
        inc zp_d+1
+       lda win,x               ; zp_f = FONT + letter*8
        asl
        asl
        asl
        sta zp_f
        lda #>FONT
        adc #0
        sta zp_f+1
        ldy #7
-       lda (zp_f),y
        sta (zp_d),y
        dey
        bpl -
        dex
        bpl .col
        rts

nmi:    rti

col_lo:   !for c, 0, 39 { !byte <(CHARSET + c*H*8) }
col_hi:   !for c, 0, 39 { !byte >(CHARSET + c*H*8) }
band_col: !byte 1, 7, 15, 10, 8, 2
old_y:    !fill 40, 0
title:    !scr "              b10: dycp                 "
info:     !scr "  every letter on its own sine offset   "
scroll_text:                    ; lowercase only (codes < 64), 0 = end
        !scr "dycp by opencode for codeurs en seine 2026 ... "
        !scr "each letter is plotted into its own column of chars ...    "
        !byte 0

        !align 255, 0
sine:     !for i, 0, 255 { !byte int(20.5 + 20 * sin(float(i) * 2 * 3.14159265 / 128)) }
