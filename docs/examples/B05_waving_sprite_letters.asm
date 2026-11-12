; =============================================================================
; B05_waving_sprite_letters.asm - B5 Waving sprite letters
; What you see: a text scrolling right to left, one 16x16 letter per sprite,
;   each letter bobbing on a sine wave, colours cycling along the line.
; How:
; - at start the ROM font (chars 0..63) is scaled 2x into 64 sprite shapes
;   ($2000-$2fff), so sprite pointer = $80 + screen code of the letter
; - 8 sprites 44 pixels apart; X = base - sx (sx = 0..43, 9-bit X, negative
;   X wraps to the hidden area); when sx wraps the 8-letter window shifts by
;   one letter and the pointers are rewritten
; - Y = sine[t*2 + i*20], a different phase for every letter
; Docs: docs/08-effects-library.md (B5)
; Based on: codebase64 base:waving_sprite_scroll, rewritten
; =============================================================================
!source "c64.asm"

SPRITES = $2000                 ; 64 shapes x 64 bytes, pointers $80-$bf
SPACING = 44
SPEED   = 1

zp_src  = $20                   ; 2 bytes
zp_dst  = $22                   ; 2 bytes
zp_r    = $24
zp_sx   = $25                   ; 0..SPACING-1
zp_t    = $26
zp_msb  = $27
zp_text = $28                   ; 2 bytes
zp_tmp  = $2a
win     = $30                   ; 8 bytes: letters shown by sprites 0..7

        +basic_upstart

start:
        +demo_init nmi
        jsr make_shapes         ; reads the char ROM: IRQs must be off
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+2*40,x
        dex
        bpl -
        lda #$17
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        ldx #0                  ; fill the window with the first 8 letters
-       jsr next_char
        sta win,x
        inx
        cpx #8
        bne -
        lda #$ff
        sta SPR_ENABLE

main:
-       lda VIC_RASTER          ; sync on line $fb (below the sprites)
        cmp #$fb
        bne -
        jsr move
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

move:
        inc zp_t
        lda zp_sx
        clc
        adc #SPEED
        cmp #SPACING
        bcc +
        ldx #0                  ; window: drop letter 0, read a new one
-       lda win+1,x
        sta win,x
        inx
        cpx #7
        bne -
        jsr next_char
        sta win+7
        lda #0
+       sta zp_sx
        lda #0
        sta zp_msb
        ldx #7
.spr:   txa
        asl
        tay                     ; Y = register offset (i*2)
        lda win,x
        ora #SPRITES/64         ; pointer = $80 + letter
        sta SCREEN+$3f8,x
        lda base_lo,x           ; X = base - sx
        sec
        sbc zp_sx
        sta SPR0_X,y
        lda base_hi,x
        sbc #0
        bpl +                   ; negative: + 504 -> hidden left area
        lda SPR0_X,y
        clc
        adc #<504
        sta SPR0_X,y
        lda #1
+       lsr                     ; bit 8 -> carry
        rol zp_msb              ; collected 7..0 -> bit i
        stx zp_tmp              ; Y = sine[t*2 + i*20]
        lda wave_ofs,x
        clc
        adc zp_t
        adc zp_t
        tax
        lda wave,x
        sta SPR0_Y,y
        ldx zp_tmp
        txa                     ; colour = ramp[(t/4 + i) & 15]
        sta zp_tmp
        lda zp_t
        lsr
        lsr
        clc
        adc zp_tmp
        and #15
        tay
        lda ramp,y
        sta SPR0_COLOR,x
        dex
        bpl .spr
        lda zp_msb
        sta SPR_X_MSB
        rts

; A = next letter of the text (0 = end -> wrap). Keeps X.
next_char:
        ldy #0
        lda (zp_text),y
        bne +
        lda #<scroll_text
        sta zp_text
        lda #>scroll_text
        sta zp_text+1
        lda (zp_text),y
+       inc zp_text
        bne +
        inc zp_text+1
+       rts

; ---- ROM chars 0..63 -> 16x16 letters in sprites (2x2 pixels) ----------------
make_shapes:
        lda #0
        tax
-       !for p, 0, 15 { sta SPRITES+p*$100,x }
        inx
        bne -
        lda #$33                ; char ROM at $d000
        sta CPU_PORT
        lda #<$d000
        sta zp_src
        lda #>$d000
        sta zp_src+1
        lda #<SPRITES
        sta zp_dst
        lda #>SPRITES
        sta zp_dst+1
.char:  lda #0
        sta zp_r
.row:   ldy zp_r
        lda (zp_src),y
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda row_ofs,y           ; sprite row 2r: byte offset r*6
        tay
        lda expand,x            ; left nibble -> byte 0 of rows 2r, 2r+1
        sta (zp_dst),y
        iny
        iny
        iny
        sta (zp_dst),y
        pla
        and #$0f
        tax
        lda expand,x            ; right nibble -> byte 1
        dey
        dey
        sta (zp_dst),y
        iny
        iny
        iny
        sta (zp_dst),y
        inc zp_r
        lda zp_r
        cmp #8
        bne .row
        lda zp_src              ; next char: ROM +8, sprite +64
        clc
        adc #8
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst
        clc
        adc #64
        sta zp_dst
        bcc +
        inc zp_dst+1
+       lda zp_dst+1
        cmp #>(SPRITES+64*64)
        bne .char
        lda #BANK_IO_ONLY
        sta CPU_PORT
        rts

nmi:    rti

expand:   !for n, 0, 15 { !byte ((n>>3)&1)*$c0 + ((n>>2)&1)*$30 + ((n>>1)&1)*$0c + (n&1)*$03 }
row_ofs:  !for r, 0, 7 { !byte r*6 }
base_lo:  !for i, 0, 7 { !byte <(40 + i*SPACING) }
base_hi:  !for i, 0, 7 { !byte >(40 + i*SPACING) }
wave_ofs: !for i, 0, 7 { !byte i*20 }
ramp:     !byte 6, 14, 3, 13, 1, 13, 3, 14, 2, 8, 10, 7, 1, 7, 10, 8
title:    !scr "         B5: waving sprite letters      "
scroll_text:                    ; lowercase only (codes < 64), 0 = end
        !scr "hello codeurs en seine! one sprite per letter ... "
        !byte 0

        !align 255, 0
wave:     !for i, 0, 255 { !byte int(130 + 60 * sin(float(i) * 2 * 3.14159265 / 256)) }
