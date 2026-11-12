; =============================================================================
; B09_char_starfield.asm - B9 Char starfield
; What you see: 50 stars drifting left at 3 speeds (parallax: slow = dark,
;   fast = white), passing behind three lines of text.
; How:
; - each star owns one char ($60 + n) whose 8 bytes are all zero except
;   one row holding a single pixel; that char sits in one screen cell
; - moving 1 pixel = ASL the pixel byte; when the pixel falls out of bit 7
;   the char moves one cell left on the screen and the byte becomes $01
; - a star is only drawn in empty cells ($20), so text stays in front
; - charset at $2000 = ROM font (codes $00-$5f) + 50 star chars
; Docs: docs/08-effects-library.md (B9)
; Based on: codebase64 base:starfield, rewritten
; =============================================================================
!source "c64.asm"

CHARSET = $2000                 ; $d018 = $18
STARS   = 50                    ; 2 per screen row
FIRST   = $60                   ; star n = char FIRST + n

zp_p    = $20                   ; 2 bytes: screen row
zp_c    = $22                   ; 2 bytes: colour RAM row
zp_n    = $24                   ; speed counter

        +basic_upstart

start:
        +demo_init nmi
        lda #$33                ; ROM lowercase font -> codes $00-$5f
        sta CPU_PORT
        ldx #0
-       !for p, 0, 2 {
        lda $d800+p*$100,x
        sta CHARSET+p*$100,x
        }
        lda #0                  ; star chars: start empty
        sta CHARSET+$300,x
        sta CHARSET+$400,x
        inx
        bne -
        lda #BANK_IO_ONLY
        sta CPU_PORT
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #WHITE
        +fill_1000 COLOR_RAM
        ldx #39
-       lda text1,x
        sta SCREEN+6*40,x
        lda text2,x
        sta SCREEN+12*40,x
        lda text3,x
        sta SCREEN+18*40,x
        dex
        bpl -
        ldx #STARS-1            ; place every star in its start cell
-       jsr draw
        dex
        bpl -
        lda #$18                ; screen $0400, charset $2000
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1

main:
-       lda VIC_RASTER          ; sync on line $fb (below the screen)
        cmp #$fb
        bne -
        jsr move_stars
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

move_stars:
        ldx #STARS-1
.star:  lda st_speed,x
        sta zp_n
        lda st_bits,x
.sh:    asl                     ; 1 pixel left
        bcc +
        jsr erase               ; fell out of bit 7: move one cell left
        dec st_col,x
        bpl ++
        lda #39
        sta st_col,x
++      jsr draw
        lda #$01                ; pixel enters at the right of the new cell
+       dec zp_n
        bne .sh
        sta st_bits,x
        ldy st_alo,x            ; write the pixel byte into the star's char
        sty .w+1
        ldy st_ahi,x
        sty .w+2
.w:     sta $ffff               ; self-modified
        dex
        bpl .star
        rts

; zp_p / zp_c = row of star X, Y = its column
row_ptr:
        ldy st_row,x
        lda row_lo,y
        sta zp_p
        sta zp_c
        lda row_hi,y
        sta zp_p+1
        eor #>(SCREEN xor COLOR_RAM) ; $04xx -> $d8xx
        sta zp_c+1
        ldy st_col,x
        rts

; clear star X's cell if it still holds the star
erase:
        jsr row_ptr
        txa
        clc
        adc #FIRST
        cmp (zp_p),y
        bne +
        lda #$20
        sta (zp_p),y
+       rts

; put star X into its cell if the cell is empty
draw:
        jsr row_ptr
        lda (zp_p),y
        cmp #$20
        bne +
        txa
        clc
        adc #FIRST
        sta (zp_p),y
        lda st_colr,x
        sta (zp_c),y
+       rts

nmi:    rti

text1:  !scr "      stars live in 50 chars ...        "
text2:  !scr "          B9: char starfield            "
text3:  !scr "    asl a byte, move a cell, repeat     "
row_lo: !for r, 0, 24 { !byte <(SCREEN + r*40) }
row_hi: !for r, 0, 24 { !byte >(SCREEN + r*40) }
; per star, generated at assemble time
st_row:   !for s, 0, STARS-1 { !byte s >> 1 }
st_col:   !for s, 0, STARS-1 { !byte (s*23 + (s & 1)*17) % 40 }
st_bits:  !for s, 0, STARS-1 { !byte 1 << (s % 7) }
st_speed: !for s, 0, STARS-1 { !byte 1 + (s*5 + (s >> 1)) % 3 }
; colour by speed 1..3: dark grey, light grey, white (nibbles of $1fb)
st_colr:  !for s, 0, STARS-1 { !byte ($1fb >> (((s*5 + (s >> 1)) % 3) * 4)) & 15 }
; address of the byte holding the pixel: char FIRST+s, row (s*3)&7
st_alo:   !for s, 0, STARS-1 { !byte <(CHARSET + (FIRST + s)*8 + ((s*3) & 7)) }
st_ahi:   !for s, 0, STARS-1 { !byte >(CHARSET + (FIRST + s)*8 + ((s*3) & 7)) }
