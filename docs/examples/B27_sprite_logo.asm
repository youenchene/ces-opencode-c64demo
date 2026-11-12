; =============================================================================
; B27_sprite_logo.asm - B27 Animated sprite logo
; What you see: a big multicolour "OPENCODE" logo made of 8 expanded sprites,
; letters bouncing on a sine wave while the 3 colour bands cycle.
; Technique:
; - at start-up each letter of the ROM font is scaled into one sprite:
;   1 font pixel -> 1 multicolour pixel (2 bits), each font row used twice;
; - the bit pair depends on the font row, so the logo has 3 bands:
;   top = %01 ($d025), middle = %10 (sprite colour), bottom = %11 ($d026);
; - the 8 sprites are X+Y expanded and placed 40 pixels apart (320 px logo);
; - every frame: Y from a sine table per letter, colours from ramps.
; Docs: docs/08-effects-library.md (B27)
; Based on: codebase64 base:spriteintro (idea), rewritten
; =============================================================================
!source "c64.asm"

SPRITE_DATA = $2000             ; 8 sprites, $2000-$21ff
SPRITE_PTRS = SCREEN + $3f8
LOGO_X  = 28                    ; X of the first letter
LOGO_Y  = 90

dst     = $20                   ; zero page
foff    = $22                   ; font offset of the letter (code*8)
row     = $23
pp      = $24                   ; bit pair for this row
fbits   = $25                   ; font byte being expanded
outl    = $26
outh    = $27
si      = $28
tmp     = $29
phase   = $2a
frame   = $2b

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #LIGHT_GREY
        +fill_1000 COLOR_RAM
        ldx #sub_end-sub-1
-       lda sub,x
        sta SCREEN+18*40+(40-(sub_end-sub))/2,x
        dex
        bpl -

        ; ---- build the 8 sprites from the ROM font (IRQs are off) ----------
        lda #0
        tax
-       sta SPRITE_DATA,x       ; clear 512 bytes
        sta SPRITE_DATA+$100,x
        inx
        bne -
        lda #$33                ; char ROM visible at $d000
        sta CPU_PORT
        ldx #7
.spr    stx si
        lda spr_lo,x
        sta dst
        lda spr_hi,x
        sta dst+1
        lda logo,x              ; screen code 1..26 (< 32: code*8 fits a byte)
        asl
        asl
        asl
        sta foff
        lda #0
        sta row
.row    ldx row
        lda pairs,x
        sta pp
        txa
        clc
        adc foff
        tax
        lda $d000,x             ; uppercase ROM font
        sta fbits
        lda #0
        sta outl
        sta outh
        ldx #8                  ; 8 font pixels -> 16 bits
-       asl outl
        rol outh
        asl outl
        rol outh
        asl fbits
        bcc +
        lda outl
        ora pp
        sta outl
+       dex
        bne -
        lda row                 ; sprite rows 2+2r and 3+2r: offset 6r+6
        asl
        sta tmp
        asl
        adc tmp
        adc #6
        tay
        lda outh
        sta (dst),y
        iny
        lda outl
        sta (dst),y
        iny
        iny
        lda outh
        sta (dst),y
        iny
        lda outl
        sta (dst),y
        inc row
        lda row
        cmp #8
        bne .row
        ldx si
        lda #SPRITE_DATA/64
        clc
        adc si
        sta SPRITE_PTRS,x
        dex
        bpl .spr
        lda #BANK_IO_ONLY
        sta CPU_PORT

        ; ---- sprite setup ------------------------------------------------
        ldx #0
        ldy #0
-       lda xpos,x
        sta SPR0_X,y
        iny
        iny
        inx
        cpx #8
        bne -
        lda #xmsb
        sta SPR_X_MSB
        lda #$ff
        sta SPR_MULTICOLOR
        sta SPR_EXPAND_X
        sta SPR_EXPAND_Y
        sta SPR_ENABLE

main:
-       lda VIC_RASTER          ; update below the display
        cmp #$fb
        bne -
        jsr animate
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

animate:
        inc frame
        lda phase
        clc
        adc #3
        sta phase
        ldx #7                  ; letter
        ldy #14                 ; register offset
-       txa
        asl
        asl
        asl
        asl                     ; 16 sine steps between letters
        adc phase
        stx tmp
        tax
        lda sine,x
        sta SPR0_Y,y
        ldx tmp
        txa                     ; sprite colour: ramp moving across letters
        asl
        adc frame
        lsr
        and #15
        stx tmp
        tax
        lda ramp_mid,x
        ldx tmp
        sta SPR0_COLOR,x
        dey
        dey
        dex
        bpl -
        lda frame
        lsr
        lsr
        and #15
        tax
        lda ramp_top,x
        sta SPR_MC0             ; %01: top band
        lda ramp_bot,x
        sta SPR_MC1             ; %11: bottom band
        rts

nmi:    rti

logo:   !scr "opencode"         ; screen codes 1-26 = uppercase in the ROM set at $d000
sub:    !scr "8 expanded multicolour sprites"
sub_end:
pairs:  !byte 1, 1, 1, 2, 2, 3, 3, 3   ; bit pairs %01 %10 %11 per font row
spr_lo: !for i, 0, 7 { !byte <(SPRITE_DATA + i*64) }
spr_hi: !for i, 0, 7 { !byte >(SPRITE_DATA + i*64) }
xpos:   !for i, 0, 7 { !byte (LOGO_X + i*40) & 255 }
xmsb = ((LOGO_X + 6*40) > 255) * $40 + ((LOGO_X + 7*40) > 255) * $80
ramp_top: !byte 6, 6, 14, 14, 3, 3, 1, 1, 3, 3, 14, 14, 6, 6, 4, 4
ramp_mid: !byte 7, 7, 15, 15, 1, 1, 15, 7, 7, 10, 8, 8, 10, 7, 7, 7
ramp_bot: !byte 2, 2, 8, 8, 10, 10, 7, 7, 10, 10, 8, 8, 2, 2, 9, 9

        !align 255, 0
PI = 3.14159265
sine:   !for i, 0, 255 { !byte int(LOGO_Y + 0.5 + 16 * sin(i * 2 * PI / 256)) }
