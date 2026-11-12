; =============================================================================
; B08_sprite_starfield.asm - B8 8-sprite starfield
; What you see: 64 stars flying right to left at 4 speeds (the faster, the
;   brighter), passing behind a line of text.
; How:
; - the 8 sprites hold a 1-pixel shape and are re-used in 8 horizontal bands
;   of 24 lines (simple multiplexer, no sorting)
; - a raster IRQ a few lines above each band writes the 8 X, Y (band Y + 0..2)
;   and colours for that band; a sprite is free again 21 lines after its Y,
;   so bands are 24 lines apart
; - once per frame (after the last band) every star X -= speed, wrapping
;   from 0 to 343; bit 8 of X is collected per band for $d010
; - $d01b = $ff: sprites behind the text
; Docs: docs/08-effects-library.md (B8)
; Based on: codebase64 base:8_sprite_starfield, rewritten
; =============================================================================
!source "c64.asm"

SPRITE  = $2000                 ; 1-pixel shape, pointer $80
BANDS   = 8
BAND_H  = 24
FIRST_Y = $34                   ; Y of band 0
STARS   = BANDS*8

zp_band = $20
zp_flag = $21
zp_msb  = $22

        +basic_upstart

start:
        +demo_init nmi
        ldx #63                 ; sprite: one pixel top-left
        lda #0
-       sta SPRITE,x
        dex
        bpl -
        lda #$80
        sta SPRITE
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_BLUE
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+12*40,x
        dex
        bpl -
        lda #$17
        sta VIC_MEMPTR
        lda #$1b
        sta VIC_CTRL1
        ldx #7
-       lda #SPRITE/64
        sta SCREEN+$3f8,x
        dex
        bpl -
        lda #$ff
        sta SPR_PRIORITY        ; behind the text
        sta SPR_ENABLE
        jsr move_stars
        lda #0
        sta zp_band
        +set_irq irq_band, FIRST_Y-5
        lda #$01
        sta VIC_IRQ_ENABLE
        sta VIC_IRQ_STATUS
        cli

main:   lda zp_flag             ; after the last band: move all stars
        beq main
        lda #0
        sta zp_flag
        jsr move_stars
        jmp main

; ---- one IRQ per band: set the 8 sprites for this band ----------------------
irq_band:
        +irq_enter
        lda zp_band
        asl
        asl
        asl
        tay                     ; Y = first star of the band
        !for i, 0, 7 {
        lda sx_lo+i,y
        sta SPR0_X+i*2
        lda sy+i,y
        sta SPR0_Y+i*2
        lda scol+i,y
        sta SPR0_COLOR+i
        }
        ldx zp_band
        lda band_msb,x
        sta SPR_X_MSB
        inx
        cpx #BANDS
        bne +
        ldx #0                  ; last band done: next frame, move stars
        inc zp_flag
+       stx zp_band
        lda band_irq,x
        sta VIC_RASTER
        +irq_exit

; ---- X -= speed (wrap 0 -> 343), collect bit 8 per band ---------------------
move_stars:
        ldx #STARS-1
.star:  lda sx_lo,x
        sec
        sbc speed,x
        sta sx_lo,x
        lda sx_hi,x
        sbc #0
        bpl +
        lda sx_lo,x             ; < 0: + 344
        clc
        adc #<344
        sta sx_lo,x
        lda #>344
+       sta sx_hi,x
        lsr                     ; bit 8 -> carry
        rol zp_msb              ; stars 8b+7 .. 8b -> bits 7..0
        txa
        and #7
        bne +
        txa                     ; first star of a band: store its $d010
        lsr
        lsr
        lsr
        tay
        lda zp_msb
        sta band_msb,y
+       dex
        bpl .star
        rts

nmi:    rti

title:  !scr "  B8: 64 stars from 8 sprites           "
band_irq: !for b, 0, BANDS-1 { !byte FIRST_Y + b*BAND_H - 5 }
band_msb: !fill BANDS, 0
; star tables, generated at assemble time (pseudo-random X, speed 1..4)
sx_lo:  !for s, 0, STARS-1 { !byte <((s*137 + s*s*11) % 344) }
sx_hi:  !for s, 0, STARS-1 { !byte >((s*137 + s*s*11) % 344) }
sy:     !for s, 0, STARS-1 { !byte FIRST_Y + (s >> 3)*BAND_H + ((s*5 + (s >> 3)) % 3) }
speed:  !for s, 0, STARS-1 { !byte 1 + ((s*7 + (s >> 3)*3) & 3) }
; colour by speed 1..4: dark grey, grey, light grey, white (nibbles of $1fcb)
scol:   !for s, 0, STARS-1 { !byte ($1fcb >> (((s*7 + (s >> 3)*3) & 3) * 4)) & 15 }
