; =============================================================================
; B06_sprite_snake.asm - B6 Sprite snake / Lissajous
; What you see: 8 balls chasing each other along a Lissajous curve, white
;   head, tail fading to blue; the curve slowly changes shape.
; How:
; - X = sine_x[ax - i*D], Y = sine_y[ay - i*D]: same curve, each ball a few
;   steps behind the previous one (D = tail spacing)
; - ax and ay advance at different speeds (3 and 2 per frame) -> Lissajous;
;   every 256 frames the Y speed changes (2, 3, 1...) -> new figure
; - X range 0..319 needs bit 8 in $d010; sprite 0 = head (drawn on top)
; Docs: docs/08-effects-library.md (B6), see also examples/04_sprites_sine
; =============================================================================
!source "c64.asm"

SPRITE  = $2000                 ; one ball shape, pointer $80
D       = 6                     ; phase step between two balls

zp_ax   = $20
zp_ay   = $21
zp_t    = $22                   ; frame counter (2 bytes)
zp_msb  = $24
zp_tmp  = $25

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN
        lda #GREY
        +fill_1000 COLOR_RAM
        ldx #39
-       lda title,x
        sta SCREEN+1*40,x
        dex
        bpl -
        lda #$17
        sta VIC_MEMPTR
        ldx #7
-       lda #SPRITE/64
        sta SCREEN+$3f8,x
        lda tail_col,x
        sta SPR0_COLOR,x
        dex
        bpl -
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
        bne +
        inc zp_t+1              ; every 256 frames: next Y speed
+       lda zp_ax
        clc
        adc #3
        sta zp_ax
        lda zp_t+1
        and #3
        tax
        lda zp_ay
        clc
        adc y_speed,x
        sta zp_ay
        lda #0
        sta zp_msb
        ldx #7
-       stx zp_tmp
        lda tail_ofs,x          ; i*D
        eor #$ff                ; -(i*D) = ~(i*D) + 1
        sec
        adc zp_ax
        tay                     ; Y = ax - i*D
        txa
        asl
        tax                     ; X = register offset
        lda sine_xl,y           ; 9-bit X from two tables (low byte, bit 8)
        sta SPR0_X,x
        lda sine_xh,y
        lsr                     ; bit 8 -> carry
        rol zp_msb              ; collected 7..0 -> bit i
        ldx zp_tmp
        lda tail_ofs,x
        eor #$ff
        sec
        adc zp_ay
        tay
        txa
        asl
        tax
        lda sine_y,y
        sta SPR0_Y,x
        ldx zp_tmp
        dex
        bpl -
        lda zp_msb
        sta SPR_X_MSB
        rts

nmi:    rti

y_speed:  !byte 2, 3, 1, 5
tail_ofs: !for i, 0, 7 { !byte i*D }
tail_col: !byte 1, 1, 15, 3, 14, 14, 6, 6
title:    !scr "       B6: sprite snake / lissajous     "

        !align 255, 0
; X = 176 + 150*sin -> 26..326 (sprite X, 9 bits: low byte + bit 8)
sine_xl: !for i, 0, 255 { !byte <int(176 + 150 * sin(float(i) * 2 * 3.14159265 / 256)) }
sine_xh: !for i, 0, 255 { !byte >int(176 + 150 * sin(float(i) * 2 * 3.14159265 / 256)) }
sine_y:  !for i, 0, 255 { !byte int(150 + 85 * sin(float(i) * 2 * 3.14159265 / 256)) }

        * = SPRITE              ; a 16x16 ball
        !byte %......##, %##......, 0
        !byte %....####, %####...., 0
        !byte %...#####, %#####..., 0
        !byte %..######, %######.., 0
        !byte %.###..##, %#######., 0
        !byte %.##....#, %#######., 0
        !byte %########, %########, 0
        !byte %########, %########, 0
        !byte %########, %########, 0
        !byte %########, %########, 0
        !byte %.#######, %#######., 0
        !byte %.#######, %#######., 0
        !byte %..######, %######.., 0
        !byte %...#####, %#####..., 0
        !byte %....####, %####...., 0
        !byte %......##, %##......, 0
        !fill 5*3+1, 0
