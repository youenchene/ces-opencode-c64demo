; =============================================================================
; B12_charset_plasma.asm - B12 Charset plasma
; What you see: a finer plasma made of dithered shades, over a colour gradient.
; How:
; - a custom charset holds 16 shade chars ($60-$6f), 4x4 Bayer ordered dither
;   from empty to almost full (generated at assemble time)
; - same sine sums as B11, but the result picks a shade char written to
;   SCREEN RAM: shade[v] = $60 + triangle(v), so values fade in and out
; - colour RAM is a fixed per-row gradient, the dither mixes it with black
; Docs: docs/08-effects-library.md (B12)
; Based on: codebase64 base:colorcycleplasma (+ the dither idea of
;   base:4x4_fli_chunky_mode), rewritten
; Limitations: ~25k cycles per screen, runs unsynced (~35 fps).
; =============================================================================
!source "c64.asm"

CHARSET = $2000                 ; VIC bank 0, outside the char ROM shadow
SHADE0  = $60                   ; first shade char

zp_i1   = $20
zp_i2   = $21
zp_pa   = $22
zp_pb   = $23
zp_pc   = $24
zp_pd   = $25

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$18                ; screen $0400, charset $2000
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #$c8
        sta VIC_CTRL2

        ; colour RAM: one colour per row (vertical gradient)
        ldx #0
-       lda row_lo,x
        sta zp_i1
        lda row_hi,x
        sta zp_i2
        lda row_col,x
        ldy #39
--      sta (zp_i1),y
        dey
        bpl --
        inx
        cpx #25
        bne -

        ; shade[i]: triangle 0..15..0 over 64 values (4 waves per 256)
        ldx #0
-       txa
        lsr
        lsr
        and #31
        cmp #16
        bcc +
        eor #31                 ; 16..31 -> 15..0
+       clc
        adc #SHADE0
        sta shade,x
        inx
        bne -

main:
        lda zp_pa               ; xbuf[x] = sin[a + 4x] + sin[b + 7x]
        sta zp_i1
        lda zp_pb
        sta zp_i2
        ldx #0
-       ldy zp_i1
        lda sine,y
        ldy zp_i2
        clc
        adc sine,y
        sta xbuf,x
        lda zp_i1
        clc
        adc #4
        sta zp_i1
        lda zp_i2
        clc
        adc #7
        sta zp_i2
        inx
        cpx #40
        bne -
        lda zp_pc               ; ybuf[y] = sin[c + 6y] + sin[d + 9y]
        sta zp_i1
        lda zp_pd
        sta zp_i2
        ldx #0
-       ldy zp_i1
        lda sine,y
        ldy zp_i2
        clc
        adc sine,y
        sta ybuf,x
        lda zp_i1
        clc
        adc #6
        sta zp_i1
        lda zp_i2
        clc
        adc #9
        sta zp_i2
        inx
        cpx #25
        bne -

!for r, 0, 24 {
        ldx #39
-       lda xbuf,x              ; 4
        adc ybuf+r              ; 4   (stray carry is invisible)
        tay                     ; 2
        lda shade,y             ; 4
        sta SCREEN+r*40,x       ; 5
        dex                     ; 2
        bpl -                   ; 3  => 24 cycles per cell
}
        inc zp_pa
        inc zp_pa
        dec zp_pb
        lda zp_pc
        clc
        adc #3
        sta zp_pc
        inc zp_pd
        jmp main

nmi:    rti

row_lo: !for r, 0, 24 { !byte <(COLOR_RAM + r*40) }
row_hi: !for r, 0, 24 { !byte >(COLOR_RAM + r*40) }
row_col: !byte 6, 6, 4, 4, 14, 14, 3, 3, 13, 13, 7, 7, 1
        !byte 7, 7, 13, 13, 3, 3, 14, 14, 4, 4, 6, 6
xbuf:   !fill 40, 0
ybuf:   !fill 25, 0

        !align 255, 0
sine:   !for i, 0, 255 { !byte int(32 + 31.5 * sin(float(i) * 2 * 3.14159265 / 256)) }
shade:  !fill 256, 0

; ---- shade chars: pixel (x,y) is set when bayer4(x&3, y&3) < level ---------
; bayer4 value = bit-interleave of (x xor y) and y, bits reversed:
;   0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5
!macro bayer_row .lvl, .y {
        !set .v = 0
        !for x, 0, 7 {
                !set .a = (x & 3) xor (.y & 3)
                !set .m = ((.a & 1) << 3) | ((.y & 1) << 2) | (.a & 2) | ((.y >> 1) & 1)
                !set .v = .v | ((.m < .lvl) << (7 - x))
        }
        !byte .v
}
        * = CHARSET + SHADE0*8
!for lvl, 0, 15 {
        !for y, 0, 7 { +bayer_row lvl, y }
}
