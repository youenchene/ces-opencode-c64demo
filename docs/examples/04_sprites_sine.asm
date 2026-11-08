; =============================================================================
; 04_sprites_sine.asm - 8 hardware sprites moving on sine tables
; - sprite data defined inline with ACME '.'/'#' binary literals
; - sine table generated at assemble time with ACME float math
; - X MSB ($d010) handling for X > 255
; Docs: docs/04-demo-effects.md (#sprites, #sine-tables)
; =============================================================================
!source "c64.asm"

SPRITE_DATA = $2000             ; must be 64-byte aligned, inside the VIC bank
SPRITE_PTRS = SCREEN + $3f8     ; 8 pointers at end of screen RAM

        +basic_upstart

start:
        +demo_init nmi
        lda #BLACK
        sta BORDER
        sta BACKGROUND
        lda #$20
        +fill_1000 SCREEN

        lda #SPRITE_DATA/64     ; all 8 sprites use the same shape
        ldx #7
-       sta SPRITE_PTRS,x
        dex
        bpl -
        ldx #7
-       lda sprite_colors,x
        sta SPR0_COLOR,x
        dex
        bpl -
        lda #$ff
        sta SPR_ENABLE

main:
-       lda VIC_RASTER          ; sync to frame (line $fb, below display)
        cmp #$fb
        bne -
        jsr move_sprites
-       lda VIC_RASTER
        cmp #$fb
        beq -
        jmp main

move_sprites:
        inc phase_x
        inc phase_y
        inc phase_y
        lda #0
        sta msb
        ldx #7                  ; sprite index
        ldy #14                 ; register offset (x*2)
-       txa
        asl
        asl
        asl
        asl                     ; spacing 16 entries per sprite
        sta tmp
        clc
        adc phase_y
        stx tmp+1
        tax
        lda sine_y,x
        sta SPR0_Y,y
        lda tmp
        clc
        adc phase_x
        tax
        lda sine_x,x            ; 0..255 range, then add 24 (left border)
        clc
        adc #24
        sta SPR0_X,y
        rol msb                 ; carry = 9th bit of X
        ldx tmp+1
        dey
        dey
        dex
        bpl -
        lda msb                 ; bits were shifted in sprite 7..0 order
        sta SPR_X_MSB
        rts

nmi:    rti

phase_x: !byte 0
phase_y: !byte 0
msb:     !byte 0
tmp:     !byte 0, 0
sprite_colors: !byte 1, 15, 12, 11, 14, 6, 3, 13

        !align 255, 0
; values must stay in 0..255 (one byte). X gets +24 at runtime (carry -> MSB)
sine_x: !for i, 0, 255 { !byte int(128 + 120 * sin(float(i) * 2 * 3.14159265 / 256)) }
sine_y: !for i, 0, 255 { !byte int(130 +  70 * sin(float(i) * 2 * 3.14159265 / 256)) }

        * = SPRITE_DATA
        ; a "terminal prompt" sprite: >_   (24x21 pixels, 3 bytes per row, 63 bytes + 1 pad)
        !byte %........, %........, %........
        !byte %##......, %........, %........
        !byte %###....., %........, %........
        !byte %.###...., %........, %........
        !byte %..###..., %........, %........
        !byte %...###.., %........, %........
        !byte %....###., %........, %........
        !byte %.....###, %........, %........
        !byte %......##, %#......., %........
        !byte %.....###, %........, %........
        !byte %....###., %........, %........
        !byte %...###.., %........, %........
        !byte %..###..., %........, %........
        !byte %.###...., %........, %........
        !byte %###....., %........, %........
        !byte %##......, %........, %........
        !byte %........, %........, %........
        !byte %........, %..######, %######..
        !byte %........, %..######, %######..
        !byte %........, %........, %........
        !byte %........, %........, %........
        !byte 0
